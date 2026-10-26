//! CSS Backgrounds3 §4.1: typed physical corner-radius pairs.
//!
//! Parsing and quad expansion reuse shape_components. Computation resolves
//! each length independently; percentages and overlap reduction need geometry
//! only at used-value time and stay unresolved here.
//! Q177: all five -webkit names use this same grammar and serialization.
//! Ruling/probes: tmp/analysis/integrator-probes-1024c/ (2026-10-24).
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const parts = @import("shape_components.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

/// A corner's horizontal and vertical radii. The initial zero pair needs no
/// allocation or immortal mutable singleton. Pair axes are owned references.
pub const Corner = union(enum) {
    zero,
    pair: *Pair,

    /// Borrow both typed scalars and retain them in a new immutable pair.
    /// Only two px zeros fold to the initial sentinel: 0% stays a percentage.
    pub fn create(allocator: Allocator, horizontal: Value, vertical: Value) Allocator.Error!Corner {
        const zero = Value.px(0);
        if (horizontal.eql(zero) and vertical.eql(zero)) return .zero;
        const pair = try allocator.create(Pair);
        pair.* = .{ .allocator = allocator, .axes = .{ horizontal, vertical } };
        horizontal.retain();
        vertical.retain();
        return .{ .pair = pair };
    }

    /// Borrow the horizontal and vertical scalars while this corner is held.
    pub fn axes(self: Corner) [2]Value {
        return switch (self) {
            .zero => .{ Value.px(0), Value.px(0) },
            .pair => |pair| pair.axes,
        };
    }

    /// Retain this corner; the immutable initial sentinel has no owner.
    pub fn ref(self: Corner) void {
        switch (self) {
            .zero => {},
            .pair => |pair| _ = pair.refs.fetchAdd(1, .monotonic),
        }
    }

    /// Release this corner, using the pair's original storage allocator.
    pub fn unref(self: Corner) void {
        switch (self) {
            .zero => {},
            .pair => |pair| {
                if (pair.refs.fetchSub(1, .acq_rel) != 1) return;
                for (pair.axes) |axis| axis.release();
                pair.allocator.destroy(pair);
            },
        }
    }

    /// Compare both typed axes, including the percentage/length distinction.
    pub fn eql(self: Corner, other: Corner) bool {
        const a = self.axes();
        const b = other.axes();
        return a[0].eql(b[0]) and a[1].eql(b[1]);
    }

    /// CSSOM §6.7.2 step 2: omit the second axis only when equivalent.
    pub fn serialize(self: Corner, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        const components = self.axes();
        try properties.serializeValue(.margin_left, components[0], out, allocator);
        if (!components[0].eql(components[1])) {
            try out.append(allocator, ' ');
            try properties.serializeValue(.margin_left, components[1], out, allocator);
        }
    }

    /// Backgrounds3 §4.1 computed value: compute each length-percentage
    /// through the existing owner context, which captures the winning source.
    /// Values4 §10.12 clamps outer math through its parsed nonnegative range.
    pub fn compute(self: Corner, allocator: Allocator, context: anytype) Allocator.Error!Corner {
        if (self == .zero) return .zero;
        const components = self.axes();
        const horizontal = try context.length(components[0]);
        defer horizontal.release();
        const vertical = try context.length(components[1]);
        defer vertical.release();
        return create(allocator, horizontal, vertical);
    }

    /// Forward the geometry policy unchanged through both axes (Q97).
    pub fn needsUnavailableMetrics(self: Corner, geometry_length: bool) bool {
        for (self.axes()) |axis| if (axis.needsUnavailableMetrics(geometry_length)) return true;
        return false;
    }

    /// True when either axis needs the winning element's tree counts.
    pub fn needsTreeCounts(self: Corner) bool {
        for (self.axes()) |axis| if (axis.needsTreeCounts()) return true;
        return false;
    }

    /// True when either axis needs the winning declaration's random base.
    pub fn needsRandomBase(self: Corner) bool {
        for (self.axes()) |axis| if (axis.needsRandomBase()) return true;
        return false;
    }
};

/// Private storage owned by Corner. Its allocator is independent of the
/// allocator a caller supplies for serialization or computed output.
const Pair = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    axes: [2]Value,
};

/// Backgrounds3 §4.1 corner grammar: one or two nonnegative typed scalars.
/// The declaration parser checks the remaining tokens and CSS-wide syntax.
pub fn parseCorner(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    // 1. Parse the horizontal radius using the shared strict scalar grammar.
    const horizontal = try parts.length(options, stream, false, true) orelse return null;
    defer horizontal.release();
    // 2. If omitted, the vertical radius is copied from the horizontal one.
    const vertical = try parts.length(options, stream, false, true);
    defer if (vertical) |owned| owned.release();
    // 3. The immutable corner retains both borrowed axes before we drop them.
    return .{ .corner_radius = try Corner.create(options.allocator, horizontal, vertical orelse horizontal) };
}

/// Backgrounds3 §4.1 shorthand: independently expand both quads in TL, TR,
/// BR, BL order. Output remains unchanged on grammar rejection or OOM.
pub fn parseShorthand(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    // 1. Shared radius parses the horizontal quad, optional slash/vertical
    // quad and omitted-axis copying. Each of its eight references is owned.
    const radii = try parts.radius(options, stream) orelse return false;
    defer for (radii) |quad| parts.releaseQuad(quad);
    if (!stream.atEnd()) return false;

    // 2. Reserve before constructing pairs; no append can fail after transfer.
    const longhands = properties.Shorthand.border_radius.longhands();
    std.debug.assert(longhands.len == 4);
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    var corners: [4]Corner = undefined;
    var count: usize = 0;
    errdefer for (corners[0..count]) |corner| corner.unref();
    while (count < corners.len) : (count += 1) {
        corners[count] = try Corner.create(options.allocator, radii[0][count], radii[1][count]);
    }

    // 3. Transfer each new corner, then drop all shared-parser references.
    for (longhands, corners) |longhand, corner| out.appendAssumeCapacity(.{
        .longhand = longhand,
        .value = .{ .value = .{ .corner_radius = corner } },
    });
    return true;
}

/// CSSOM §6.7.2 steps 1–2: serialize the independently shortest horizontal
/// and vertical quads. Equal axes omit the slash and the whole vertical quad.
/// Both specified and computed serialization use the same pair grammar.
pub fn serializeShorthand(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    if (assigned.len != 4) return false;
    var radii: parts.Radius = undefined;
    // 1. Confirm all four corners are representable before writing anything.
    // CSS-wide/pending shorthand handling stays in properties' shared wrapper.
    for (assigned, 0..) |assignment, i| {
        if (assignment != .value or assignment.value != .corner_radius) return false;
        const components = assignment.value.corner_radius.axes();
        radii[0][i] = components[0];
        radii[1][i] = components[1];
    }
    // 2. The shared quad serializer omits repeated components, preserving type.
    try parts.serializeQuad(radii[0], out, allocator);
    if (!parts.quadEql(radii[0], radii[1])) {
        try out.appendSlice(allocator, " / ");
        try parts.serializeQuad(radii[1], out, allocator);
    }
    return true;
}

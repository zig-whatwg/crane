//! CSS Images 4 §6.1: image-resolution's owned specified/computed value.
//! CSS Values 4 §7.4: nonnegative resolutions compute in canonical dppx.
//!
//! Q146 (2026-10-24) leaves snap rounding as a FOLLOW-UP: §6.1's prose
//! says "one image pixel to an integer number of device pixels", but the
//! 300dpi-at-96dpi example gives 288dpi, "3 image pixels map to 1 device
//! pixel". These are reciprocal constraints. Preserve snap and normalize
//! the resolution without rounding; no device or image-loader input is used.

const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const images = @import("image_values.zig");
const math = @import("math_values.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const StyleValue = values.Value;

// A math operand is explicitly pending, never a literal with an inactive
// default number. Computation replaces it with a canonical literal.
const Component = union(enum) {
    literal: images.Resolution,
    math: StyleValue,

    fn retain(self: Component) void {
        if (self == .math) self.math.retain();
    }

    fn release(self: Component) void {
        if (self == .math) self.math.release();
    }

    fn eql(self: Component, other: Component) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;
        return switch (self) {
            .literal => |literal| literal.number == other.literal.number and literal.unit == other.literal.unit,
            .math => |value| value.eql(other.math),
        };
    }

    fn serialize(self: Component, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .literal => |literal| {
                // Resolution's serializer is private to image_values. Reuse
                // its public data and the same CSSOM number serializer.
                try values.appendNumber(literal.number, out, allocator);
                try out.appendSlice(allocator, @tagName(literal.unit));
            },
            .math => |value| try value.calculation.serialize(out, allocator),
        }
    }
};

const Descriptor = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    from_image: bool,
    snap: bool,
    resolution: ?Component,

    fn ref(self: *Descriptor) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    fn unref(self: *Descriptor) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.resolution) |component| component.release();
        self.allocator.destroy(self);
    }
};

/// An allocation-free initial 1dppx, or an immutable counted descriptor.
/// Each copy must be retained while another owner holds the same descriptor.
pub const Value = union(enum) {
    initial,
    owned: *Descriptor,

    /// Retain this value for a declaration, computed style, or inherited copy.
    pub fn retain(self: Value) void {
        if (self == .owned) self.owned.ref();
    }

    /// Release this value through the descriptor's original allocator.
    pub fn release(self: Value) void {
        if (self == .owned) self.owned.unref();
    }

    /// Structural equality preserves authored resolution units and math.
    pub fn eql(self: Value, other: Value) bool {
        if (self == .initial or other == .initial) return self == .initial and other == .initial;
        const a = self.owned;
        const b = other.owned;
        if (a == b) return true;
        if (a.from_image != b.from_image or a.snap != b.snap) return false;
        if (a.resolution) |component| return if (b.resolution) |other_component| component.eql(other_component) else false;
        return b.resolution == null;
    }

    /// CSSOM canonical order follows Images 4 §6.1: from-image, resolution, snap.
    pub fn serialize(self: Value, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (self == .initial) return out.appendSlice(allocator, "1dppx");
        const descriptor = self.owned;
        if (descriptor.from_image) try out.appendSlice(allocator, "from-image");
        if (descriptor.resolution) |component| {
            if (descriptor.from_image) try out.append(allocator, ' ');
            try component.serialize(out, allocator);
        }
        if (descriptor.snap) try out.appendSlice(allocator, " snap");
    }

    /// Forward tree dependencies before cascade builds its winning context.
    pub fn needsTreeCounts(self: Value) bool {
        return if (self.mathOperand()) |value| value.needsTreeCounts() else false;
    }

    /// Fixed random expressions need no externally supplied random base.
    pub fn needsRandomBase(self: Value) bool {
        return if (self.mathOperand()) |value| value.needsRandomBase() else false;
    }

    /// A resolution is a scalar, even if nested math contains lengths.
    /// It cannot preserve unavailable font metrics as geometry lengths can.
    pub fn needsUnavailableMetrics(self: Value, geometry_length: bool) bool {
        _ = geometry_length;
        return if (self.mathOperand()) |value| value.needsUnavailableMetrics(false) else false;
    }

    /// Compute using the cascade's actual winning Source and math inputs.
    /// Values 4 §§7.4,10.12 normalize units and clamp only the outer math
    /// result. Images 4 §6.1's keywords survive, with Q146's no-rounding rule.
    /// The borrowed context never escapes. Inheritance retains the resulting
    /// value directly rather than evaluating it in the descendant's context.
    pub fn compute(self: Value, allocator: Allocator, context: math.Context) Allocator.Error!Value {
        if (self == .initial) return .initial;
        const descriptor = self.owned;
        const component = descriptor.resolution orelse {
            self.retain();
            return self;
        };
        const resolution: images.Resolution = switch (component) {
            .literal => |literal| blk: {
                if (literal.unit == .dppx) {
                    self.retain();
                    return self;
                }
                break :blk .{ .number = literal.dppx(), .unit = .dppx };
            },
            .math => |value| blk: {
                const expression = try value.calculation.compute(allocator, context);
                defer expression.unref();
                // The cascade preflights all three dependency queries. A
                // strict resolution grammar then has a complete scalar.
                const number = expression.computedNumber().?;
                std.debug.assert(number.unit == .dppx);
                break :blk .{ .number = number.value, .unit = .dppx };
            },
        };
        return create(allocator, descriptor.from_image, descriptor.snap, .{ .literal = resolution });
    }

    // Takes a borrowed operand and retains it only after allocation succeeds.
    // Every failure leaves the caller's reference unchanged.
    fn create(allocator: Allocator, from_image: bool, snap: bool, resolution: ?Component) Allocator.Error!Value {
        std.debug.assert(from_image or resolution != null);
        if (resolution) |component| {
            if (component == .math) std.debug.assert(component.math == .calculation);
            if (!from_image and !snap and component == .literal and
                component.literal.unit == .dppx and component.literal.number == 1) return .initial;
        }
        const descriptor = try allocator.create(Descriptor);
        descriptor.* = .{
            .allocator = allocator,
            .from_image = from_image,
            .snap = snap,
            .resolution = resolution,
        };
        if (resolution) |component| component.retain();
        return .{ .owned = descriptor };
    }

    fn mathOperand(self: Value) ?StyleValue {
        if (self == .initial) return null;
        const component = self.owned.resolution orelse return null;
        return if (component == .math) component.math else null;
    }
};

/// Parse the complete Images 4 §6.1 grammar:
/// [ from-image || <resolution> ] && snap?. Snap may precede or follow the
/// inner group, but cannot separate its two components. Invalid input returns
/// null; math and descriptor allocation failures propagate without leaks.
pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?StyleValue {
    var snap = takeKeyword(stream, "snap");
    var from_image = false;
    var resolution: ?Component = null;
    defer if (resolution) |component| component.release();

    if (takeKeyword(stream, "from-image")) {
        from_image = true;
        resolution = try parseComponent(options, stream);
    } else {
        resolution = (try parseComponent(options, stream)) orelse return null;
        from_image = takeKeyword(stream, "from-image");
    }
    if (!snap) snap = takeKeyword(stream, "snap");
    if (!stream.atEnd()) return null;
    return .{ .image_resolution = try Value.create(options.allocator, from_image, snap, resolution) };
}

fn takeKeyword(stream: *properties.Stream, name: []const u8) bool {
    const token = stream.peek();
    if (token.token_type != .ident or !tokenizer.nameEql(token.value, name)) return false;
    _ = stream.next();
    return true;
}

fn parseComponent(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Component {
    const token = stream.peek();
    if (math.isFunction(token)) {
        // Preserve options.random_scope: the existing parser owns the
        // declaration's random identities, type checking, and EOF recovery.
        const value = (try properties.mathValue(options, stream, .{ .kind = .resolution, .minimum = 0 })) orelse return null;
        return .{ .math = value };
    }
    if (token.token_type != .dimension) return null;
    const number = token.numeric_value orelse return null;
    // Values 4 §7.4 always excludes negative resolutions. Q146 records the
    // contrary upstream snap -8dpcm expectation as a stale WPT follow-up.
    if (!std.math.isFinite(number) or number < 0) return null;
    const unit = token.unit orelse return null;
    inline for (.{ "x", "dppx", "dpi", "dpcm" }) |name| {
        if (tokenizer.nameEql(unit, name)) {
            _ = stream.next();
            return .{ .literal = .{ .number = number, .unit = @field(@FieldType(images.Resolution, "unit"), name) } };
        }
    }
    return null;
}

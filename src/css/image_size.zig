//! CSS Backgrounds3 §2.9: the typed <bg-size> shared by masks/backgrounds.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const components = @import("shape_components.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const Size = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    axes: [2]Value,

    pub fn create(allocator: Allocator, axes: [2]Value) Allocator.Error!*Size {
        const self = try allocator.create(Size);
        self.* = .{ .allocator = allocator, .axes = axes };
        for (axes) |v| v.retain();
        return self;
    }
    pub fn ref(self: *Size) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Size) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.axes) |v| v.release();
        self.allocator.destroy(self);
    }
    pub fn needsUnavailableMetrics(self: *const Size, geometry_length: bool) bool {
        for (self.axes) |value| if (value.needsUnavailableMetrics(geometry_length)) return true;
        return false;
    }

    pub fn needsTreeCounts(self: *const Size) bool {
        for (self.axes) |value| if (value.needsTreeCounts()) return true;
        return false;
    }

    pub fn needsRandomBase(self: *const Size) bool {
        for (self.axes) |value| if (value.needsRandomBase()) return true;
        return false;
    }

    pub fn eql(self: *const Size, other: *const Size) bool {
        return self == other or (self.axes[0].eql(other.axes[0]) and self.axes[1].eql(other.axes[1]));
    }
    pub fn serialize(self: *const Size, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try properties.serializeValue(.margin_left, self.axes[0], out, allocator);
        if (self.axes[0].isKeyword(.auto) and self.axes[1].isKeyword(.auto)) return;
        try out.append(allocator, ' ');
        try properties.serializeValue(.margin_left, self.axes[1], out, allocator);
    }
    pub fn compute(self: *const Size, allocator: Allocator, context: anytype) Allocator.Error!*Size {
        var axes: [2]Value = undefined;
        var count: usize = 0;
        defer for (axes[0..count]) |v| v.release();
        while (count < 2) : (count += 1) axes[count] = if (self.axes[count].isKeyword(.auto)) Value.kw(.auto) else try context.length(self.axes[count]);
        return create(allocator, axes);
    }
};

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    if (components.keyword(stream, "cover")) return .{ .image_keyword = .cover };
    if (components.keyword(stream, "contain")) return .{ .image_keyword = .contain };
    const x = (try component(options, stream)) orelse return null;
    defer x.release();
    const y = (try component(options, stream)) orelse Value.kw(.auto);
    defer y.release();
    return .{ .image_size = try Size.create(options.allocator, .{ x, y }) };
}

fn component(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    if (components.keyword(stream, "auto")) return Value.kw(.auto);
    return components.length(options, stream, false, true);
}

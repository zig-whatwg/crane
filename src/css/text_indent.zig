//! CSS Text3 §8.1: indentation length-percentage and the two independent flags.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const Flags = packed struct {
    hanging: bool = false,
    each_line: bool = false,
};

pub const Indent = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    offset: Value,
    flags: Flags,

    /// Retains the borrowed scalar only after allocation succeeds.
    pub fn create(allocator: Allocator, offset: Value, flags: Flags) Allocator.Error!*Indent {
        const self = try allocator.create(Indent);
        self.* = .{ .allocator = allocator, .offset = offset, .flags = flags };
        offset.retain();
        return self;
    }
    pub fn ref(self: *Indent) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Indent) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.offset.release();
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const Indent, other: *const Indent) bool {
        return self == other or (std.meta.eql(self.flags, other.flags) and self.offset.eql(other.offset));
    }
    pub fn serialize(self: *const Indent, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try properties.serializeValue(.margin_left, self.offset, out, allocator);
        if (self.flags.hanging) try out.appendSlice(allocator, " hanging");
        if (self.flags.each_line) try out.appendSlice(allocator, " each-line");
    }
};

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    var offset: ?Value = null;
    defer if (offset) |v| v.release();
    var flags: Flags = .{};
    for (0..3) |_| {
        const t = stream.peek();
        if (!flags.hanging and t.token_type == .ident and tokenizer.nameEql(t.value, "hanging")) {
            _ = stream.next();
            flags.hanging = true;
        } else if (!flags.each_line and t.token_type == .ident and tokenizer.nameEql(t.value, "each-line")) {
            _ = stream.next();
            flags.each_line = true;
        } else if (offset == null) {
            const v = (try properties.parseLonghand(options, .margin_left, stream)) orelse return null;
            // margin's scalar grammar differs only by its auto alternative.
            // The shared parser supplies the signed length-percentage and,
            // once the math prerequisite is merged, its typed calculations.
            if (v.isKeyword(.auto)) {
                v.release();
                return null;
            }
            offset = v;
        } else break;
    }
    const v = offset orelse return null;
    if (!flags.hanging and !flags.each_line) {
        v.retain();
        return v;
    }
    return .{ .indent = try Indent.create(options.allocator, v, flags) };
}

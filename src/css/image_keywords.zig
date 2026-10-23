//! Image/background/mask keywords kept separate from unrelated CSS keywords.
const std = @import("std");
const properties = @import("properties.zig");
const tokenizer = @import("tokenizer.zig");

pub const Keyword = enum {
    cover,
    contain,
    repeat,
    space,
    round,
    no_repeat,
    stretch,
    border_box,
    padding_box,
    content_box,
    fill_box,
    stroke_box,
    view_box,
    no_clip,
    alpha,
    luminance,
    match_source,
    add,
    subtract,
    intersect,
    exclude,
    fill,

    pub fn name(self: Keyword) []const u8 {
        return switch (self) {
            .no_repeat => "no-repeat",
            .border_box => "border-box",
            .padding_box => "padding-box",
            .content_box => "content-box",
            .fill_box => "fill-box",
            .stroke_box => "stroke-box",
            .view_box => "view-box",
            .no_clip => "no-clip",
            .match_source => "match-source",
            inline else => |k| @tagName(k),
        };
    }
    pub fn parse(stream: *properties.Stream, allowed: []const Keyword) ?Keyword {
        const t = stream.peek();
        if (t.token_type != .ident) return null;
        for (allowed) |k| if (tokenizer.nameEql(t.value, k.name())) {
            _ = stream.next();
            return k;
        };
        return null;
    }
};

pub const Repeat = struct {
    x: Keyword,
    y: Keyword,
    /// Border-image uses stretch/repeat/round/space; only background/mask
    /// repeat uses the repeat-x/y shorthand aliases.
    border: bool = false,
    pub fn serialize(self: Repeat, out: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        if (!self.border) {
            if (self.x == .repeat and self.y == .no_repeat) return out.appendSlice(allocator, "repeat-x");
            if (self.x == .no_repeat and self.y == .repeat) return out.appendSlice(allocator, "repeat-y");
        }
        try out.appendSlice(allocator, self.x.name());
        if (self.x != self.y) {
            try out.append(allocator, ' ');
            try out.appendSlice(allocator, self.y.name());
        }
    }
    pub fn parse(stream: *properties.Stream, border: bool) ?Repeat {
        const t = stream.peek();
        if (!border and t.token_type == .ident) {
            if (tokenizer.nameEql(t.value, "repeat-x")) {
                _ = stream.next();
                return .{ .x = .repeat, .y = .no_repeat };
            }
            if (tokenizer.nameEql(t.value, "repeat-y")) {
                _ = stream.next();
                return .{ .x = .no_repeat, .y = .repeat };
            }
        }
        const allowed: []const Keyword = if (border) &.{ .stretch, .repeat, .round, .space } else &.{ .repeat, .space, .round, .no_repeat };
        const x = Keyword.parse(stream, allowed) orelse return null;
        return .{ .x = x, .y = Keyword.parse(stream, allowed) orelse x, .border = border };
    }
};

//! CSS Anchor Position 1 §§3.1.2–3.1.3: position-area's two-axis value.
//! Axis compatibility is checked before canonical ordering. No layout or DOM
//! state participates in either specified or computed serialization.
const std = @import("std");
const tokenizer = @import("tokenizer.zig");

const Axis = enum { general, horizontal, vertical, block, inline_axis, self_block, self_inline, ambiguous, self_ambiguous };
pub const Keyword = enum {
    center,
    span_all,
    left,
    right,
    span_left,
    span_right,
    x_start,
    x_end,
    span_x_start,
    span_x_end,
    self_x_start,
    self_x_end,
    span_self_x_start,
    span_self_x_end,
    top,
    bottom,
    span_top,
    span_bottom,
    y_start,
    y_end,
    span_y_start,
    span_y_end,
    self_y_start,
    self_y_end,
    span_self_y_start,
    span_self_y_end,
    block_start,
    block_end,
    span_block_start,
    span_block_end,
    inline_start,
    inline_end,
    span_inline_start,
    span_inline_end,
    self_block_start,
    self_block_end,
    span_self_block_start,
    span_self_block_end,
    self_inline_start,
    self_inline_end,
    span_self_inline_start,
    span_self_inline_end,
    start,
    end,
    span_start,
    span_end,
    self_start,
    self_end,
    span_self_start,
    span_self_end,

    fn name(self: Keyword) []const u8 {
        return switch (self) {
            inline else => |k| comptime blk: {
                const tag = @tagName(k);
                var bytes: [tag.len]u8 = undefined;
                for (tag, 0..) |c, i| bytes[i] = if (c == '_') '-' else c;
                const result = bytes;
                break :blk &result;
            },
        };
    }
    fn axis(self: Keyword) Axis {
        return switch (self) {
            .center, .span_all => .general,
            .left, .right, .span_left, .span_right, .x_start, .x_end, .span_x_start, .span_x_end, .self_x_start, .self_x_end, .span_self_x_start, .span_self_x_end => .horizontal,
            .top, .bottom, .span_top, .span_bottom, .y_start, .y_end, .span_y_start, .span_y_end, .self_y_start, .self_y_end, .span_self_y_start, .span_self_y_end => .vertical,
            .block_start, .block_end, .span_block_start, .span_block_end => .block,
            .inline_start, .inline_end, .span_inline_start, .span_inline_end => .inline_axis,
            .self_block_start, .self_block_end, .span_self_block_start, .span_self_block_end => .self_block,
            .self_inline_start, .self_inline_end, .span_self_inline_start, .span_self_inline_end => .self_inline,
            .start, .end, .span_start, .span_end => .ambiguous,
            .self_start, .self_end, .span_self_start, .span_self_end => .self_ambiguous,
        };
    }
    fn repeated(self: Keyword) bool {
        return switch (self.axis()) {
            .general, .ambiguous, .self_ambiguous => true,
            else => false,
        };
    }
    fn secondAxis(self: Keyword) bool {
        return switch (self.axis()) {
            .vertical, .inline_axis, .self_inline => true,
            else => false,
        };
    }
    fn firstAxis(self: Keyword) bool {
        return !self.repeated() and !self.secondAxis();
    }
    fn short(self: Keyword) Keyword {
        return switch (self) {
            .block_start, .inline_start => .start,
            .block_end, .inline_end => .end,
            .span_block_start, .span_inline_start => .span_start,
            .span_block_end, .span_inline_end => .span_end,
            .self_block_start, .self_inline_start => .self_start,
            .self_block_end, .self_inline_end => .self_end,
            .span_self_block_start, .span_self_inline_start => .span_self_start,
            .span_self_block_end, .span_self_inline_end => .span_self_end,
            else => self,
        };
    }
    fn expanded(self: Keyword, second: bool) Keyword {
        return switch (self) {
            .start => if (second) .inline_start else .block_start,
            .end => if (second) .inline_end else .block_end,
            .span_start => if (second) .span_inline_start else .span_block_start,
            .span_end => if (second) .span_inline_end else .span_block_end,
            .self_start => if (second) .self_inline_start else .self_block_start,
            .self_end => if (second) .self_inline_end else .self_block_end,
            .span_self_start => if (second) .span_self_inline_start else .span_self_block_start,
            .span_self_end => if (second) .span_self_inline_end else .span_self_block_end,
            else => self,
        };
    }
};
const by_name = blk: {
    @setEvalBranchQuota(100_000);
    const fields = @typeInfo(Keyword).@"enum".fields;
    var entries: [fields.len]struct { []const u8, Keyword } = undefined;
    for (fields, 0..) |f, i| {
        const k: Keyword = @enumFromInt(f.value);
        entries[i] = .{ k.name(), k };
    }
    break :blk std.StaticStringMap(Keyword).initComptime(entries);
};
fn keyword(token: tokenizer.Token) ?Keyword {
    if (token.token_type != .ident) return null;
    if (std.mem.indexOfScalar(u8, token.value, '\\') != null) {
        inline for (@typeInfo(Keyword).@"enum".fields) |f| {
            const k: Keyword = @enumFromInt(f.value);
            if (tokenizer.nameEql(token.value, k.name())) return k;
        }
        return null;
    }
    var lower: [64]u8 = undefined;
    if (token.value.len > lower.len) return null;
    return by_name.get(std.ascii.lowerString(lower[0..token.value.len], token.value));
}

pub const Area = struct {
    first: Keyword,
    second: Keyword,

    pub fn consume(stream: anytype) ?Area {
        var first = keyword(stream.peek()) orelse return null;
        _ = stream.next();
        var second = keyword(stream.peek()) orelse {
            const other: Keyword = if (first.repeated()) first else .span_all;
            return if (first.secondAxis()) .{ .first = other, .second = first } else .{ .first = first, .second = other };
        };
        _ = stream.next();
        const a = first.axis();
        const b = second.axis();
        const compatible = a == .general or b == .general or
            (a == .horizontal and b == .vertical) or (a == .vertical and b == .horizontal) or
            (a == .block and b == .inline_axis) or (a == .inline_axis and b == .block) or
            (a == .self_block and b == .self_inline) or (a == .self_inline and b == .self_block) or
            (a == b and (a == .ambiguous or a == .self_ambiguous));
        if (!compatible) return null;
        if (first.secondAxis() or second.firstAxis()) std.mem.swap(Keyword, &first, &second);
        return .{ .first = first, .second = second };
    }

    pub fn computed(self: Area) Area {
        // §3.1.3 plus CSSOM's shortest round-tripping representation: when
        // the other axis is span-all, retain/expand the unambiguous long form.
        if (self.first == .span_all) return .{ .first = self.first, .second = self.second.expanded(true) };
        if (self.second == .span_all) return .{ .first = self.first.expanded(false), .second = self.second };
        return .{ .first = self.first.short(), .second = self.second.short() };
    }

    pub fn eql(self: Area, other: Area) bool {
        return self.first == other.first and self.second == other.second;
    }

    pub fn serialize(self: Area, out: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        if (self.first == .span_all and !self.second.repeated()) return out.appendSlice(allocator, self.second.name());
        try out.appendSlice(allocator, self.first.name());
        if (self.first == self.second or (self.second == .span_all and !self.first.repeated())) return;
        try out.append(allocator, ' ');
        try out.appendSlice(allocator, self.second.name());
    }
};

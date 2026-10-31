//! CSS Box Alignment 3 §§4–7: compact typed alignment values.
//! Parsing keeps the spelling of flex-*; computation alone maps to flow-*
//! (CSSWG #14052, 2026-08-05). Row118 Q34 defers the one-day-old parse-time
//! alias change in spec 3110cd02e77f until WPT and implementers move.
const std = @import("std");
const tokenizer = @import("tokenizer.zig");

pub const Mode = enum { align_content, justify_content, align_items, justify_items, align_self, justify_self };
pub const Word = enum {
    auto,
    normal,
    stretch,
    baseline,
    center,
    start,
    end,
    self_start,
    self_end,
    flex_start,
    flex_end,
    flow_start,
    flow_end,
    left,
    right,
    space_between,
    space_around,
    space_evenly,
    anchor_center,
    legacy,
    first,
    last,
    safe,
    unsafe,

    pub fn name(self: Word) []const u8 {
        return switch (self) {
            inline else => |word| comptime blk: {
                var text: [@tagName(word).len]u8 = undefined;
                @memcpy(&text, @tagName(word));
                for (&text) |*c| if (c.* == '_') {
                    c.* = '-';
                };
                const name_text = text;
                break :blk &name_text;
            },
        };
    }
    const names = blk: {
        // Zig 0.17: @typeInfo is struct-of-arrays; rebuild the old field list.
        const fields = zig017_fields: {
            const zig017_info = @typeInfo(Word).@"enum";
            var zig017_out: [zig017_info.field_names.len]struct { name: [:0]const u8, value: comptime_int } = undefined;
            for (zig017_info.field_names, zig017_info.field_values, 0..) |zig017_n, zig017_v, zig017_i| zig017_out[zig017_i] = .{ .name = zig017_n, .value = zig017_v };
            break :zig017_fields zig017_out;
        };
        var items: [fields.len]struct { []const u8, Word } = undefined;
        for (fields, 0..) |field, i| {
            const value: Word = @enumFromInt(field.value);
            items[i] = .{ value.name(), value };
        }
        break :blk std.StaticStringMap(Word).initComptime(items);
    };
    fn parse(token: tokenizer.Token) ?Word {
        if (token.token_type != .ident) return null;
        if (names.get(token.value)) |word| return word;
        inline for (@typeInfo(Word).@"enum".field_values) |field_value| {
            const word: Word = @enumFromInt(field_value);
            if (tokenizer.nameEql(token.value, word.name())) return word;
        }
        return null;
    }
};

pub const Value = struct {
    position: Word,
    modifier: ?Word = null,

    pub fn eql(self: Value, other: Value) bool {
        return self.position == other.position and self.modifier == other.modifier;
    }

    pub fn consume(stream: anytype, mode: Mode) ?Value {
        const first = Word.parse(stream.peek()) orelse return null;
        const self = mode == .align_self or mode == .justify_self;
        const content = mode == .align_content or mode == .justify_content;
        const justify = mode == .justify_content or mode == .justify_items or mode == .justify_self;
        // §7.1: legacy && [left | right | center], or legacy on its own.
        if (mode == .justify_items and first == .legacy) {
            _ = stream.next();
            if (Word.parse(stream.peek())) |second| switch (second) {
                .left, .right, .center => {
                    _ = stream.next();
                    return .{ .position = second, .modifier = .legacy };
                },
                else => {},
            };
            return .{ .position = .legacy };
        }
        if (first == .normal or first == .stretch or (first == .auto and self)) {
            _ = stream.next();
            return .{ .position = first };
        }
        // §4.2: all three engines require the modifier before baseline,
        // despite the long-standing && grammar (row118 D30).
        if (mode != .justify_content and (first == .baseline or first == .first or first == .last)) {
            _ = stream.next();
            if (first != .baseline) {
                if (Word.parse(stream.peek()) != .baseline) return null;
                _ = stream.next();
            }
            return .{ .position = .baseline, .modifier = if (first == .last) .last else null };
        }
        if (content) switch (first) {
            .space_between, .space_around, .space_evenly => {
                _ = stream.next();
                return .{ .position = first };
            },
            else => {},
        };
        // §4.4: the overflow modifier precedes a positional value. Self
        // alignment also accepts normal (CSSWG #12920); anchor-center is
        // the Anchor Position 1 §4.2 extension, including safe positioning.
        const modifier: ?Word = if (first == .safe or first == .unsafe) first else null;
        if (modifier != null) _ = stream.next();
        const position = Word.parse(stream.peek()) orelse return null;
        const valid = switch (position) {
            .center, .start, .end, .flex_start, .flex_end, .flow_start, .flow_end => true,
            .self_start, .self_end => !content,
            .left, .right => justify,
            .normal, .anchor_center => self,
            else => false,
        };
        if (!valid) return null;
        _ = stream.next();
        if (mode == .justify_items and modifier == null and Word.parse(stream.peek()) == .legacy) {
            if (position != .left and position != .right and position != .center) return null;
            _ = stream.next();
            return .{ .position = position, .modifier = .legacy };
        }
        return .{ .position = position, .modifier = modifier };
    }

    pub fn computed(self: Value, parent: ?Value) Value {
        // §7.1: lone legacy references a parent's legacy alignment; it
        // otherwise computes to normal, including on the root.
        if (self.position == .legacy) {
            if (parent) |p| if (p.modifier == .legacy) return p;
            return .{ .position = .normal };
        }
        var result = self;
        result.position = switch (self.position) {
            .flex_start => .flow_start,
            .flex_end => .flow_end,
            else => self.position,
        };
        return result;
    }

    pub fn serialize(self: Value, out: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        if (self.modifier) |modifier| {
            try out.appendSlice(allocator, modifier.name());
            try out.append(allocator, ' ');
        }
        try out.appendSlice(allocator, self.position.name());
    }
};

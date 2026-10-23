//! CSS Anchor Position 1 §6.1: typed position-try fallback options.
//! The arena belongs to this immutable value, never a document or hot path.
const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const serialize_mod = @import("serialize.zig");
const Area = @import("position_area.zig").Area;
const Allocator = std.mem.Allocator;

pub const Tactic = enum {
    flip_block,
    flip_inline,
    flip_start,
    flip_x,
    flip_y,
    fn name(self: Tactic) []const u8 {
        return switch (self) {
            .flip_block => "flip-block",
            .flip_inline => "flip-inline",
            .flip_start => "flip-start",
            .flip_x => "flip-x",
            .flip_y => "flip-y",
        };
    }
    fn parse(token: tokenizer.Token) ?Tactic {
        if (token.token_type != .ident) return null;
        inline for (@typeInfo(Tactic).@"enum".fields) |field| {
            const tactic: Tactic = @enumFromInt(field.value);
            if (tokenizer.nameEql(token.value, tactic.name())) return tactic;
        }
        return null;
    }
};
const Named = struct { name: ?[]const u8 = null, tactics: [5]Tactic = undefined, count: u3 = 0 };
const Option = union(enum) { area: Area, named: Named };
pub const Fallbacks = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,
    options: []const Option,

    pub fn parse(allocator: Allocator, stream: anytype) Allocator.Error!?*Fallbacks {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const a = arena.allocator();
        var options: std.ArrayList(Option) = .empty;
        while (true) {
            var named: Named = .{};
            // <dashed-ident> and <try-tactic> are each contiguous components
            // of ||. In particular flip-x --foo flip-y is not that grammar.
            named.name = try dashedName(a, stream);
            while (Tactic.parse(stream.peek())) |tactic| {
                for (named.tactics[0..named.count]) |old| if (old == tactic) return null;
                named.tactics[named.count] = tactic;
                named.count += 1;
                _ = stream.next();
            }
            if (named.name == null) named.name = try dashedName(a, stream);
            const option: Option = if (named.name != null or named.count > 0)
                .{ .named = named }
            else
                .{ .area = Area.consume(stream) orelse return null };
            try options.append(a, option);
            if (stream.peek().token_type != .comma) break;
            _ = stream.next();
        }
        if (!stream.atEnd()) return null;
        const self = try allocator.create(Fallbacks);
        self.* = .{ .allocator = allocator, .arena = arena, .options = options.items };
        arena = std.heap.ArenaAllocator.init(allocator);
        return self;
    }
    pub fn ref(self: *Fallbacks) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Fallbacks) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.arena.deinit();
        self.allocator.destroy(self);
    }
    pub fn eql(a: *const Fallbacks, b: *const Fallbacks) bool {
        if (a == b) return true;
        if (a.options.len != b.options.len) return false;
        for (a.options, b.options) |x, y| {
            if (std.meta.activeTag(x) != std.meta.activeTag(y)) return false;
            switch (x) {
                .area => |area| if (!area.eql(y.area)) return false,
                .named => |n| {
                    const other = y.named;
                    if ((n.name == null) != (other.name == null) or n.count != other.count) return false;
                    if (n.name) |name| if (!std.mem.eql(u8, name, other.name.?)) return false;
                    if (!std.mem.eql(Tactic, n.tactics[0..n.count], other.tactics[0..other.count])) return false;
                },
            }
        }
        return true;
    }
    pub fn serialize(self: *const Fallbacks, computed: bool, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        for (self.options, 0..) |option, i| {
            if (i > 0) try out.appendSlice(allocator, ", ");
            switch (option) {
                .area => |area| try (if (computed) area.computed() else area).serialize(out, allocator),
                .named => |n| {
                    if (n.name) |name| {
                        const escaped = try serialize_mod.serializeIdentifier(allocator, name);
                        defer allocator.free(escaped);
                        try out.appendSlice(allocator, escaped);
                    }
                    for (n.tactics[0..n.count], 0..) |tactic, j| {
                        if (n.name != null or j > 0) try out.append(allocator, ' ');
                        try out.appendSlice(allocator, tactic.name());
                    }
                },
            }
        }
    }
};

/// Values 4 §4.3: -- itself is a dashed-ident (unlike a custom-property name).
/// The returned decoded name belongs to allocator; failure consumes no token.
pub fn dashedName(allocator: Allocator, stream: anytype) Allocator.Error!?[]const u8 {
    const token = stream.peek();
    if (token.token_type != .ident) return null;
    const decoded = try tokenizer.decode(allocator, token.value);
    if (!std.mem.startsWith(u8, decoded, "--")) {
        allocator.free(decoded);
        return null;
    }
    _ = stream.next();
    return decoded;
}

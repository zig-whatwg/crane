//! runtime.BrowserScope: a Browser's per-Browser state, as supplements made
//! on first use and ended with the scope (docs/instances.md, rule 2).

const std = @import("std");
const runtime = @import("runtime");
const BrowserScope = runtime.BrowserScope;
const testing = std.testing;

/// Records the order supplements end in.
var ended: [4]u8 = undefined;
var ended_count: usize = 0;

fn Supplement(comptime tag: u8) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        /// Something of its own to free, so a leak shows.
        owned: []u8,
        uses: u32 = 0,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator, .owned = allocator.alloc(u8, 16) catch &.{} };
        }

        pub fn deinit(self: *Self) void {
            ended[ended_count] = tag;
            ended_count += 1;
            self.allocator.free(self.owned);
        }
    };
}

test "a supplement is made on first use, the same one after, and ends with the scope - the last made first" {
    ended_count = 0;
    var scope = BrowserScope.init(testing.allocator);
    try testing.expect(scope.existing(Supplement('a')) == null);
    const a = try scope.of(Supplement('a'));
    a.uses += 1;
    const b = try scope.of(Supplement('b'));
    try testing.expect(@intFromPtr(b) != @intFromPtr(a));
    // The same type: the same supplement.
    const again = try scope.of(Supplement('a'));
    try testing.expectEqual(a, again);
    try testing.expectEqual(@as(u32, 1), again.uses);
    try testing.expectEqual(a, scope.existing(Supplement('a')).?);
    scope.deinit();
    try testing.expectEqualStrings("ba", ended[0..ended_count]);
}

const Asker = struct {
    scope: *BrowserScope,
    got: ?*Supplement('t') = null,

    fn run(self: *Asker) void {
        var i: usize = 0;
        while (i < 1000) : (i += 1) self.got = self.scope.of(Supplement('t')) catch null;
    }
};

test "two threads asking at once get one supplement" {
    ended_count = 0;
    var scope = BrowserScope.init(testing.allocator);
    var first: Asker = .{ .scope = &scope };
    var second: Asker = .{ .scope = &scope };
    const t1 = try std.Thread.spawn(.{}, Asker.run, .{&first});
    const t2 = try std.Thread.spawn(.{}, Asker.run, .{&second});
    t1.join();
    t2.join();
    try testing.expect(first.got != null);
    try testing.expectEqual(first.got.?, second.got.?);
    scope.deinit();
    try testing.expectEqual(@as(usize, 1), ended_count);
}

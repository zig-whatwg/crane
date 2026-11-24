//! What a page's collectors keep (chrome-devtools-mcp's PageCollector,
//! src/collectors/PageCollector.ts at chrome-devtools-mcp-v1.13.0): items in
//! navigations, the newest first, the current one taking what comes; a new
//! document in the main frame starts a navigation, and only the last
//! `max_navigations` (DEFAULT_MAX_NAVIGATION_SAVED, 3) are kept. Each item
//! has a stable id, from 1, per collector (createIdGenerator).

const std = @import("std");
const Allocator = std.mem.Allocator;

/// DEFAULT_MAX_NAVIGATION_SAVED.
pub const default_max_navigations: usize = 3;

/// `T` has `id: u32` and `deinit(*T, Allocator)`.
pub fn Collector(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Index 0 is the current navigation.
        navigations: std.ArrayList(std.ArrayList(*T)) = .empty,
        next_id: u32 = 1,
        /// maxResourcesPerNavigation: the oldest of the current navigation
        /// go first past it.
        max_per_navigation: usize,
        max_navigations: usize = default_max_navigations,

        pub fn deinit(self: *Self, allocator: Allocator) void {
            for (self.navigations.items) |*navigation| {
                for (navigation.items) |item| destroy(allocator, item);
                navigation.deinit(allocator);
            }
            self.navigations.deinit(allocator);
        }

        fn destroy(allocator: Allocator, item: *T) void {
            item.deinit(allocator);
            allocator.destroy(item);
        }

        fn current(self: *Self, allocator: Allocator) !*std.ArrayList(*T) {
            if (self.navigations.items.len == 0) try self.navigations.append(allocator, .empty);
            return &self.navigations.items[0];
        }

        /// Take `item` (OWNED, allocated with `allocator`) into the current
        /// navigation with the next id.
        pub fn add(self: *Self, allocator: Allocator, item: *T) !void {
            errdefer destroy(allocator, item);
            const navigation = try self.current(allocator);
            item.id = self.next_id;
            self.next_id = if (self.next_id == std.math.maxInt(u32)) 0 else self.next_id + 1;
            try navigation.append(allocator, item);
            if (navigation.items.len > self.max_per_navigation) {
                const extra = navigation.items.len - self.max_per_navigation;
                for (navigation.items[0..extra]) |old| destroy(allocator, old);
                navigation.replaceRangeAssumeCapacity(0, extra, &.{});
            }
        }

        /// splitAfterNavigation: a new current navigation; with `keep_from`,
        /// the current one's items from that index on move into it (the
        /// network collector's navigation request and what followed it).
        pub fn split(self: *Self, allocator: Allocator, keep_from: ?usize) !void {
            var fresh: std.ArrayList(*T) = .empty;
            errdefer fresh.deinit(allocator);
            if (keep_from) |from| {
                const old = try self.current(allocator);
                try fresh.appendSlice(allocator, old.items[from..]);
                old.shrinkRetainingCapacity(from);
            }
            try self.navigations.insert(allocator, 0, fresh);
            while (self.navigations.items.len > self.max_navigations) {
                var dropped = self.navigations.pop().?;
                for (dropped.items) |item| destroy(allocator, item);
                dropped.deinit(allocator);
            }
        }

        /// getData: the current navigation's items, or with
        /// `include_preserved` every kept navigation's, oldest first.
        pub fn data(self: *Self, arena: Allocator, include_preserved: bool) ![]*T {
            if (self.navigations.items.len == 0) return &.{};
            if (!include_preserved) return arena.dupe(*T, self.navigations.items[0].items);
            var out: std.ArrayList(*T) = .empty;
            var index = self.navigations.items.len;
            while (index > 0) {
                index -= 1;
                try out.appendSlice(arena, self.navigations.items[index].items);
            }
            return out.items;
        }

        /// The current navigation's items (borrowed).
        pub fn currentItems(self: *Self) []*T {
            if (self.navigations.items.len == 0) return &.{};
            return self.navigations.items[0].items;
        }

        /// getById: null when no kept navigation has it.
        pub fn byId(self: *Self, id: u32) ?*T {
            for (self.navigations.items) |navigation| {
                for (navigation.items) |item| if (item.id == id) return item;
            }
            return null;
        }
    };
}

test "a collector keeps three navigations, ids from 1, and the newest navigation is the current one" {
    const Item = struct {
        id: u32 = 0,
        value: u32,
        fn deinit(self: *@This(), allocator: Allocator) void {
            _ = .{ self, allocator };
        }
    };
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var c: Collector(Item) = .{ .max_per_navigation = 2 };
    defer c.deinit(allocator);
    for (0..3) |v| {
        const item = try allocator.create(Item);
        item.* = .{ .value = @intCast(v) };
        try c.add(allocator, item);
    }
    // Past two per navigation, the oldest went.
    const first = try c.data(arena, false);
    try std.testing.expectEqual(@as(usize, 2), first.len);
    try std.testing.expectEqual(@as(u32, 2), first[0].id);
    for (0..3) |_| try c.split(allocator, null);
    const item = try allocator.create(Item);
    item.* = .{ .value = 9 };
    try c.add(allocator, item);
    try std.testing.expectEqual(@as(usize, 1), (try c.data(arena, false)).len);
    // The first navigation is no longer kept.
    try std.testing.expectEqual(@as(usize, 1), (try c.data(arena, true)).len);
    try std.testing.expect(c.byId(2) == null);
    try std.testing.expectEqual(@as(u32, 4), c.byId(4).?.id);
}

//! runtime.InstanceRegistry: an impl's internal state per instance, in the
//! instance's Browser's side table (instances B1) - found from the instance's
//! address, so two Browsers' entries never meet, and one Browser's sweep or
//! end never touches another's.

const std = @import("std");
const runtime = @import("runtime");
const tombstones = @import("webidl").utils.tombstones;

const testing = std.testing;
const BrowserScope = runtime.BrowserScope;

const no_methods = .{};
const vtable: runtime.VTable = .{ .name = "Registered", .deinit = null, .methods_ptr = &no_methods };

/// A state that owns memory, as an element's attributes do.
const Owning = struct {
    bytes: ?[]u8 = null,

    pub fn deinit(self: *Owning) void {
        if (self.bytes) |bytes| testing.allocator.free(bytes);
        self.bytes = null;
    }
};

/// Any tag: each test's scopes are its own, and only this type uses it there.
const Registry = runtime.InstanceRegistry(.dom_string_map, Owning);

fn register(scope: *BrowserScope, text: []const u8) !*runtime.Instance {
    const instance = try scope.slab.alloc(&vtable);
    const state = try Registry.createIn(instance, &scope.arena);
    state.bytes = try testing.allocator.dupe(u8, text);
    return instance;
}

test "two Browsers' registries share nothing: each one's sweep and end leave the other's states" {
    var a = BrowserScope.init(testing.allocator);
    var a_ended = false;
    defer if (!a_ended) a.deinit();
    var b = BrowserScope.init(testing.allocator);
    defer b.deinit();

    const in_a = try register(&a, "a");
    const in_b = try register(&b, "b");
    try testing.expectEqualStrings("a", Registry.get(in_a).?.bytes.?);
    try testing.expectEqualStrings("b", Registry.get(in_b).?.bytes.?);
    try testing.expectEqual(@as(usize, 1), Registry.count(&a));
    try testing.expectEqual(@as(usize, 1), Registry.count(&b));

    // A's teardown sweep: A's states, and only A's.
    Registry.deinitAllAndClear(&a);
    try testing.expectEqual(@as(usize, 0), Registry.count(&a));
    try testing.expect(!Registry.contains(in_a));
    try testing.expectEqualStrings("b", Registry.get(in_b).?.bytes.?);

    // A's end.
    a.deinit();
    a_ended = true;
    try testing.expectEqualStrings("b", Registry.get(in_b).?.bytes.?);

    Registry.get(in_b).?.deinit();
    Registry.remove(in_b);
    try testing.expectEqual(@as(usize, 0), Registry.count(&b));
}

// The runner's churn: a page's worth of objects at addresses never used
// before is registered and then released, forty times over, while a few
// stay registered throughout. Each page is checked at its first insert.
test "a page's worth of states registered and released, page after page, leaves half the unused slots free" {
    const pages = 40;
    const per_page = 4096;
    const resident = 64;
    const Plain = struct { value: u32 };
    const PlainRegistry = runtime.InstanceRegistry(.css_style_declaration, Plain);

    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    var state: Plain = .{ .value = 1 };

    // Addresses never used before: the objects stay allocated, only their
    // entries come and go.
    for (0..resident) |_| try PlainRegistry.set(try scope.slab.alloc(&vtable), &state);
    var page_objects: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer page_objects.deinit(testing.allocator);
    for (0..pages) |page| {
        page_objects.clearRetainingCapacity();
        for (0..per_page) |i| {
            const instance = try scope.slab.alloc(&vtable);
            try page_objects.append(testing.allocator, instance);
            try PlainRegistry.set(instance, &state);
            if (i == 0 and page > 0) {
                const table = scope.existingTable(.css_style_declaration, PlainRegistry.Table).?;
                const counts = tombstones.slotCounts(&table.map);
                if (!counts.halfOfUnusedFree()) {
                    std.debug.print("page {d}: {d} of {d} slots free, {d} live\n", .{ page, counts.free, counts.capacity, counts.live });
                    return error.TombstonesFilledTheTable;
                }
            }
        }
        for (page_objects.items) |instance| PlainRegistry.remove(instance);
    }
    try testing.expectEqual(@as(usize, resident), PlainRegistry.count(&scope));
}

//! runtime.window_holders: the allowlist that decides whether a torn-down
//! Window's slab slot may go back (lane winslot1). Its default is the safe
//! answer - a holder kind no table lists is unsafe, and one unsafe kind
//! keeps every Window's slot - and the switch stays off until the commit
//! that lists the last kind flips it, with this file.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const window_holders = runtime.window_holders;
const Holder = window_holders.Holder;

test "a holder kind no table lists is unsafe" {
    for (std.enums.values(Holder)) |holder| try testing.expect(!window_holders.safeForReusedSlotIn(&.{}, holder));
}

test "one kind left out keeps every Window's slot" {
    const all = comptime std.enums.values(Holder);
    inline for (0..all.len) |left_out| {
        const table = comptime blk: {
            var t: [all.len - 1]Holder = undefined;
            var k: usize = 0;
            for (all, 0..) |holder, i| {
                if (i == left_out) continue;
                t[k] = holder;
                k += 1;
            }
            break :blk t;
        };
        try testing.expect(!window_holders.reusableWith(&table));
    }
    try testing.expect(window_holders.reusableWith(all));
}

test "every holder kind is safe, so a torn-down Window's slot goes back" {
    // Was false until the commit that listed the last kind.
    try testing.expect(window_holders.reusable);
}

const delegates = .{};
const window_vtable = runtime.VTable{ .name = "Window", .deinit = null, .methods_ptr = &delegates };

test "a Link reads gone once its Window's teardown starts or its slot is reissued" {
    var slab = runtime.SlabAllocator.init(testing.allocator);
    defer slab.deinit();
    var realm = try runtime.ContextData.init(testing.allocator, .{});
    defer realm.deinit();

    const window = try slab.alloc(&window_vtable);
    window.ctx = &realm;
    const link = window_holders.Link.of(window);
    try testing.expectEqual(@as(?*runtime.Instance, window), link.get());
    try testing.expect(link.is(window));

    // Its teardown began: gone, though its slot is still its own.
    try testing.expect(runtime.instance_lifecycle.markCleanupStarted(window));
    try testing.expectEqual(@as(?*runtime.Instance, null), link.get());
    try testing.expect(link.is(window));

    // Its slot back, then issued again: gone, and never the newcomer.
    slab.free(window);
    try testing.expectEqual(@as(?*runtime.Instance, null), link.get());
    try testing.expect(!link.is(window));
    const newcomer = try slab.alloc(&window_vtable);
    newcomer.ctx = &realm;
    try testing.expectEqual(@intFromPtr(window), @intFromPtr(newcomer));
    try testing.expectEqual(@as(?*runtime.Instance, null), link.get());
    try testing.expect(!link.is(newcomer));
    slab.free(newcomer);
}

test "a Link to a Window whose realm can no longer run script reads gone" {
    var slab = runtime.SlabAllocator.init(testing.allocator);
    defer slab.deinit();
    var realm = try runtime.ContextData.init(testing.allocator, .{});
    defer realm.deinit();
    // A realm of an agent whose engine context the collector took
    // (protocol_realms.realmCollected): no engine, an agent.
    var agent_marker: u8 = 0;
    realm.agent = @ptrCast(&agent_marker);
    const window = try slab.alloc(&window_vtable);
    window.ctx = &realm;
    const link = window_holders.Link.of(window);
    try testing.expectEqual(@as(?*runtime.Instance, null), link.get());
    realm.agent = null;
    slab.free(window);
}

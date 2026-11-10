//! A Browser reserves its heap at its start and releases it at its end
//! (lane h1, phase H1 of tmp/redesign/node-memory-architecture.md as amended
//! by node-memory-plan-v2.md): Browser.init calls BrowserScope.reserveHeap
//! once the scope's address is final, after the agent's Math.random seed is
//! drawn. The heap's own tests: tests/runtime/, tests/html/ and
//! tests/platform/ h1_*_test.zig.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;

fn heapOf(browser: *Browser) *@TypeOf(browser.scope.*).Heap.BrowserHeap {
    return browser.scope.heap.?;
}

test "a Browser's start reserves its heap, named as its scope's; two Browsers' heaps are disjoint" {
    const a = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer a.deinit();
    const b = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer b.deinit();
    const Scope = @TypeOf(a.scope.*);
    const Heap = Scope.Heap;
    const ha = heapOf(a);
    const hb = heapOf(b);
    try testing.expectEqual(a.scope, Scope.ofHeap(ha));
    try testing.expectEqual(b.scope, Scope.ofHeap(hb));
    try testing.expectEqual(@as(usize, 0), ha.window_base % @as(usize, @intCast(Heap.layout.window_bytes)));
    try testing.expect(ha.window_base != hb.window_base);
    try testing.expectEqual(ha, Heap.heapOf(@ptrFromInt(ha.at(Heap.layout.first_node_offset))));
    // Its generations start at the heap's seed (oss R12): every object the
    // Browser has made so far was stamped at or after it.
    try testing.expect(a.scope.slab.next_generation >= ha.generation_seed);
    try testing.expect(ha.generation_seed != hb.generation_seed);
}

test "a seeded Browser replays its generation seed from its random stream" {
    // The testing platform's per-Browser stream (PlatformBrowserOptions
    // .random_seed): the agent's Math.random seed is drawn first, then the
    // heap's, so the same seed gives the same generations.
    const a = try Browser.init(testing.allocator, .{ .snapshot_path = "", .platform = .{ .random_seed = 0x5eed } });
    defer a.deinit();
    const b = try Browser.init(testing.allocator, .{ .snapshot_path = "", .platform = .{ .random_seed = 0x5eed } });
    defer b.deinit();
    const c = try Browser.init(testing.allocator, .{ .snapshot_path = "", .platform = .{ .random_seed = 0x5eee } });
    defer c.deinit();
    try testing.expectEqual(heapOf(a).generation_seed, heapOf(b).generation_seed);
    try testing.expect(heapOf(a).generation_seed != heapOf(c).generation_seed);
}

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

/// VmSize from /proc/self/status, in bytes (Linux).
fn vmSize() ?usize {
    if (comptime @import("builtin").os.tag != .linux) return null;
    var buf: [4096]u8 = undefined;
    const fd = std.c.open("/proc/self/status", .{ .ACCMODE = .RDONLY, .CLOEXEC = true });
    if (fd < 0) return null;
    defer _ = std.c.close(fd);
    const n = std.c.read(fd, &buf, buf.len);
    if (n <= 0) return null;
    const text = buf[0..@intCast(n)];
    const at = std.mem.indexOf(u8, text, "VmSize:") orelse return null;
    var fields = std.mem.tokenizeAny(u8, text[at + "VmSize:".len ..], " \t\n");
    const kb = std.fmt.parseInt(usize, fields.next() orelse return null, 10) catch return null;
    return kb * 1024;
}

test "a Browser that cannot reserve its heap fails Browser.init with OutOfMemory, leaving nothing behind (Linux RLIMIT_AS)" {
    // macOS does not enforce RLIMIT_AS on mmap.
    if (comptime @import("builtin").os.tag != .linux) return error.SkipZigTest;
    // The engine starts with the first Browser (its sandbox and cages are
    // the process's), so start one, end it, then limit the address space to
    // a little more than the process holds: less than the ladder's smallest
    // rung (a 256 MiB cage and its metadata).
    const first = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
    const Scope = @TypeOf(first.scope.*);
    first.deinit();
    Scope.Heap.releaseKeptReservations();
    // Beside another Browser (the many-Browsers variant's busy one) the limit
    // would fail that Browser's allocations too.
    if (Scope.liveCount() != 0) return error.SkipZigTest;
    const in_use = vmSize() orelse return error.SkipZigTest;
    var old: std.c.rlimit = undefined;
    try testing.expectEqual(@as(c_int, 0), std.c.getrlimit(.AS, &old));
    var limit = old;
    limit.cur = in_use + 48 * 1024 * 1024;
    try testing.expectEqual(@as(c_int, 0), std.c.setrlimit(.AS, &limit));
    const result = Browser.init(testing.allocator, .{ .snapshot_path = "" });
    _ = std.c.setrlimit(.AS, &old);
    if (result) |browser| {
        browser.deinit();
        return error.TestUnexpectedResult;
    } else |err| try testing.expectEqual(error.OutOfMemory, err);
    // testing.allocator fails the test if anything Browser.init allocated
    // before the reservation is left; and no scope is left alive.
    try testing.expectEqual(@as(usize, 0), Scope.liveCount());
}

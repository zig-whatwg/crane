//! A test executable whose tests read memory after freeing it, built with
//! the Crane test runner (tests/test_runner/) and run - one process per
//! test - by tools/test_launcher/child.zig's tests (lane poison2): each read
//! after a free must fail its test by name, reading the poison or faulting
//! on it, because every allocator a test checks memory with poisons what it
//! frees (tests/test_runner/poisoning.zig); and with CRANE_POISON_FREES=0,
//! the run's off switch, each must read the old bytes and pass - which is
//! what a read after a free did under a DebugAllocator, the blind spot.
//! Not part of any suite: build.zig compiles it only for the launcher's tests.

const std = @import("std");
const testing = std.testing;
const poisoning = @import("root").poisoning;

/// What a test keeps a pointer to: a value, and a pointer to follow.
const Node = struct { value: u64, next: *const u64 };

const value: u64 = 0x1122_3344_5566_7788;
const target: u64 = 42;

/// Makes a Node, destroys it, and returns the pointer kept past the
/// destroy. A neighbour in the same size class stays live, so the page
/// the slot is on stays mapped and the read is of the slot itself.
fn destroyedNode(allocator: std.mem.Allocator, neighbour: **Node) !*volatile Node {
    neighbour.* = try allocator.create(Node);
    neighbour.*.* = .{ .value = 1, .next = &target };
    const node = try allocator.create(Node);
    node.* = .{ .value = value, .next = &target };
    allocator.destroy(node);
    return node;
}

test "std.testing.allocator: reads a field through a pointer kept past its destroy" {
    var neighbour: *Node = undefined;
    const kept = try destroyedNode(testing.allocator, &neighbour);
    defer testing.allocator.destroy(neighbour);
    try testing.expectEqual(value, kept.value);
}

test "std.testing.allocator: follows a pointer read from a destroyed struct" {
    var neighbour: *Node = undefined;
    const kept = try destroyedNode(testing.allocator, &neighbour);
    defer testing.allocator.destroy(neighbour);
    const next = kept.next;
    try testing.expectEqual(target, next.*);
}

test "a test's own DebugAllocator: reads a field through a pointer kept past its destroy" {
    var gpa: poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leaked");
    const a = gpa.allocator();
    var neighbour: *Node = undefined;
    const kept = try destroyedNode(a, &neighbour);
    defer a.destroy(neighbour);
    try testing.expectEqual(value, kept.value);
}

test "a test's own DebugAllocator: reads a slice's bytes after its free" {
    var gpa: poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leaked");
    const a = gpa.allocator();
    const neighbour = try a.alloc(u8, 40);
    defer a.free(neighbour);
    const bytes = try a.alloc(u8, 40);
    @memset(bytes, 0x11);
    const kept: [*]volatile u8 = bytes.ptr;
    // rawFree: Allocator.free writes `undefined` (0xaa in Debug) first, which
    // would hide what the allocator itself leaves.
    a.rawFree(bytes, .@"1", @returnAddress());
    try testing.expectEqual(@as(u8, 0x11), kept[0]);
}

test "reads only live memory" {
    const node = try testing.allocator.create(Node);
    defer testing.allocator.destroy(node);
    node.* = .{ .value = value, .next = &target };
    try testing.expectEqual(value, node.value);
    try testing.expectEqual(target, node.next.*);
}

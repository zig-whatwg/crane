//! Poison on free: what every allocator a Crane test, or the WPT correctness
//! runner, checks memory with does to the memory it frees, and the one
//! switch that turns it off for a run (lanes crashes8 and poison2).
//!
//! A read after a free shows only if something changed the freed bytes.
//! Zig 0.17's std.heap.DebugAllocator changes nothing: it never hands a
//! freed small slot out again and never writes to it, and `Allocator.destroy`
//! writes nothing either (`Allocator.free` writes `undefined`, 0xaa in Debug
//! code). So a struct freed inside its own step kept its exact bytes, and a
//! read after the free found the right values: two service-worker
//! use-after-frees passed every gate of the correctness runner and crashed
//! every time on libc malloc, which writes its free list into a freed block
//! (docs/lessons/testing-the-debug-allocator-never-reuses-or-poisons-a-freed-slot.md).
//!
//! The allocators, and how each poisons:
//!
//! - `std.testing.allocator`, every test's: a `std.heap.SafeAllocator` the
//!   Crane test runner (runner.zig) makes per test, as Zig's own runner does,
//!   with `.check_write_after_free` on. Its free writes 0x55 over every
//!   allocation in a bucket (one under 3/4 of a bucket: 12 KiB with 16 KiB
//!   pages) and checks, when the bucket is released and at `deinit`, that
//!   nothing wrote to it since ("write after free", a panic); a larger
//!   allocation goes back to the page allocator, which unmaps it. std does
//!   the work; the runner keeps the option on unless `CRANE_POISON_FREES=0`.
//! - a test's own allocator - a race test gives each Browser one, so the two
//!   do not take turns on the shared one (tests/AGENTS.md): `DebugAllocator`
//!   below, std's DebugAllocator with `Poisoning`'s writes in front.
//! - the WPT correctness runner's sweep allocator (tests/wpt_runner/
//!   runner_allocator.zig): `Poisoning` in front of its DebugAllocator.
//!
//! And memory no Zig allocator sees - v8_wrapper.cpp's new and delete,
//! `std.heap.c_allocator` - is libc's: the test launcher sets libc's own
//! scribbling for every test child (tools/test_launcher/child.zig,
//! `testEnvironment`).
//!
//! `CRANE_POISON_FREES=0` turns all of it off for one run (`enabled`): to
//! see whether a failure depends on it, never to make a test pass.
//!
//! std-only. The Crane test runner imports it as a file beside it and
//! exports it, so a test reaches it as `@import("root").poisoning`; the WPT
//! runner imports it as the module "poisoning" (build.zig).

const std = @import("std");
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

/// The variable that turns poisoning off for one run: `CRANE_POISON_FREES=0`.
pub const env_var = "CRANE_POISON_FREES";

/// Poisoning is on unless the environment says otherwise.
pub const by_default = true;

/// Whether `CRANE_POISON_FREES`'s value asks for poisoning: unset is
/// `by_default`; set, on when non-empty and not starting with '0' (as
/// `CRANE_LEAK_TRACES`).
pub fn enabled(value: ?[]const u8) bool {
    const v = value orelse return by_default;
    return v.len != 0 and v[0] != '0';
}

/// The byte `Poisoning` writes over every small block before it is freed.
/// 0xdd, "dead" (the MSVC debug heap's fill for freed blocks): read back as
/// a pointer, 0xdddd_dddd_dddd_dddd is not a canonical address on arm64 or
/// x86-64, so a pointer read from freed memory faults at its first use; an
/// enum tag or an optional's flag read from it is out of range or set.
/// Not SafeAllocator's 0x55, so a fault address says which allocator freed
/// the block.
pub const byte: u8 = 0xdd;

/// The largest block `Poisoning` overwrites: the DebugAllocator's largest
/// small size class at its default page size on these hosts (128 KiB pages:
/// 32 KiB). A larger block is a large allocation, which the DebugAllocator
/// unmaps when it is freed - a later read faults anyway - so writing it
/// first would cost time and catch nothing more.
pub const limit: usize = 32 * 1024;

/// A front for any allocator: every small block is overwritten with `byte`
/// as it is freed (lane crashes8, for the WPT runner's sweep allocator).
///
/// Thread-safe as the child is: the block is the caller's until the child's
/// `free`, so the write happens before the child's lock. A free whose length
/// is wrong (larger than the block) writes past it before the DebugAllocator
/// reports the mismatch; that report still comes.
pub const Poisoning = struct {
    child: Allocator,

    pub fn allocator(self: *Poisoning) Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };

    fn alloc(ctx: *anyopaque, len: usize, alignment: Alignment, ret: usize) ?[*]u8 {
        const self: *Poisoning = @ptrCast(@alignCast(ctx));
        return self.child.rawAlloc(len, alignment, ret);
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret: usize) bool {
        const self: *Poisoning = @ptrCast(@alignCast(ctx));
        return poisonedResize(self.child, memory, alignment, new_len, ret);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret: usize) ?[*]u8 {
        const self: *Poisoning = @ptrCast(@alignCast(ctx));
        return poisonedRemap(self.child, memory, alignment, new_len, ret);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: Alignment, ret: usize) void {
        const self: *Poisoning = @ptrCast(@alignCast(ctx));
        poisonedFree(self.child, memory, alignment, ret);
    }
};

/// A small block shrunk in place keeps its slot: its tail is freed memory
/// from now on, and is poisoned like a free.
fn poisonedResize(child: Allocator, memory: []u8, alignment: Alignment, new_len: usize, ret: usize) bool {
    if (!child.rawResize(memory, alignment, new_len, ret)) return false;
    poisonTail(memory, new_len);
    return true;
}

fn poisonedRemap(child: Allocator, memory: []u8, alignment: Alignment, new_len: usize, ret: usize) ?[*]u8 {
    const moved = child.rawRemap(memory, alignment, new_len, ret) orelse return null;
    if (moved == memory.ptr) poisonTail(memory, new_len);
    return moved;
}

fn poisonedFree(child: Allocator, memory: []u8, alignment: Alignment, ret: usize) void {
    if (memory.len <= limit) @memset(memory, byte);
    child.rawFree(memory, alignment, ret);
}

fn poisonTail(memory: []u8, new_len: usize) void {
    if (new_len >= memory.len or memory.len > limit) return;
    @memset(memory[new_len..], byte);
}

/// A test's own leak-checking allocator: a drop-in for
/// `std.heap.DebugAllocator(config)` - `.init`, `allocator()`, `deinit()` -
/// whose frees are poisoned (`Poisoning`'s writes) unless the run turned
/// poisoning off. Leak and double-free detection are the DebugAllocator's,
/// unchanged: `deinit` is its `deinit`.
///
/// For the allocator a test makes for itself - one per Browser in a race
/// test, so the Browsers do not take turns on std.testing.allocator's
/// per-allocation stack traces (docs/lessons/testing-a-shared-test-
/// allocator-makes-two-browsers-take-turns.md) - in place of a bare
/// std.heap.DebugAllocator, which poisons nothing: tests/infra/
/// test_allocators_test.zig fails a test file that makes one.
///
/// Like the DebugAllocator, it must not move once `allocator()` has been
/// called: the allocator points into it.
pub fn DebugAllocator(comptime config: std.heap.DebugAllocatorConfig) type {
    return struct {
        debug: std.heap.DebugAllocator(config) = .init,

        const Self = @This();

        pub const init: Self = .{};

        /// The allocator to give a Browser: the DebugAllocator's own when the
        /// run turned poisoning off (`processPoisons`), else this one, which
        /// writes `byte` over each small block before the DebugAllocator
        /// frees it. Writes nothing to `self`, so any thread may call it.
        pub fn allocator(self: *Self) Allocator {
            if (!processPoisons()) return self.debug.allocator();
            return .{ .ptr = self, .vtable = &vtable };
        }

        /// The DebugAllocator's check: `.leak` when anything is still live
        /// (each leak logged, as before).
        pub fn deinit(self: *Self) std.heap.Check {
            return self.debug.deinit();
        }

        const vtable: Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };

        fn childOf(ctx: *anyopaque) Allocator {
            const self: *Self = @ptrCast(@alignCast(ctx));
            return self.debug.allocator();
        }

        fn alloc(ctx: *anyopaque, len: usize, alignment: Alignment, ret: usize) ?[*]u8 {
            return childOf(ctx).rawAlloc(len, alignment, ret);
        }

        fn resize(ctx: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret: usize) bool {
            return poisonedResize(childOf(ctx), memory, alignment, new_len, ret);
        }

        fn remap(ctx: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret: usize) ?[*]u8 {
            return poisonedRemap(childOf(ctx), memory, alignment, new_len, ret);
        }

        fn free(ctx: *anyopaque, memory: []u8, alignment: Alignment, ret: usize) void {
            poisonedFree(childOf(ctx), memory, alignment, ret);
        }
    };
}

/// The stack frames a `ChurnAllocator` records per allocation: none. Set it
/// to 7 (std.testing.allocator's) and rerun one test alone to see where each
/// block a churn test leaked was allocated; `ChurnAllocator.deinit` says so
/// when it finds one.
pub const churn_stack_trace_frames: usize = 0;

/// The allocator for a CHURN test - one that allocates and frees 100,000
/// times or more in a loop to show memory stays flat - in place of
/// std.testing.allocator (tests/AGENTS.md, "Tests come first"). That one
/// captures 7 frames at every allocation and every free, and on aarch64
/// macOS the capture runs the DWARF self-unwinder frame by frame: a `sample`
/// of the million-createElement churn on chat2 (lane nd2 batch 3,
/// 2026-11-11) put 9,880 of its 10,394 samples (95%) under
/// SafeAllocator.captureStackTrace - 148 s there, 213 s on chat.local, 27 s
/// on server1, against the launcher's 300 s. This is `DebugAllocator`
/// (poisoned frees, the leak check) recording no stack traces
/// (`churn_stack_trace_frames`), named after its test so a leak it finds
/// says which test to rerun with frames.
///
/// Like `DebugAllocator`, it must not move once `allocator()` has been
/// called.
pub const ChurnAllocator = struct {
    debug: DebugAllocator(.{ .stack_trace_frames = churn_stack_trace_frames }) = .init,
    /// The test, for the leak report.
    name: []const u8,

    pub fn init(name: []const u8) ChurnAllocator {
        return .{ .name = name };
    }

    pub fn allocator(self: *ChurnAllocator) Allocator {
        return self.debug.allocator();
    }

    /// The leak check: error.Leaked when anything is still live, after the
    /// DebugAllocator's own report of each block.
    pub fn deinit(self: *ChurnAllocator) error{Leaked}!void {
        if (self.debug.deinit() == .ok) return;
        if (churn_stack_trace_frames == 0) {
            std.log.err("{s}: leaked (each block listed above, without stack traces); to see where each was allocated, set churn_stack_trace_frames to 7 in tests/test_runner/poisoning.zig and rerun this test alone", .{self.name});
        } else {
            std.log.err("{s}: leaked (each block listed above, with its stack trace)", .{self.name});
        }
        return error.Leaked;
    }
};

/// Whether this process poisons: under the Crane test runner, its
/// `poison_frees` - decided once in its `main` from `CRANE_POISON_FREES`,
/// before the first test and the first thread, and only read after, so a
/// test's threads and the many-Browsers variant's busy Browser read it
/// without a race; elsewhere (Zig's own test runner), always.
pub fn processPoisons() bool {
    const root = @import("root");
    if (@hasDecl(root, "poison_frees")) return root.poison_frees;
    return true;
}

const testing = std.testing;

test "a freed small block reads back as poison, a live neighbour keeps its bytes" {
    // A child that never unmaps or reuses, so the freed bytes can be read
    // back here.
    var buffer: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    var poisoning: Poisoning = .{ .child = fixed.allocator() };
    const a = poisoning.allocator();
    const freed = try a.alloc(u8, 24);
    const neighbour = try a.alloc(u8, 24);
    @memset(freed, 0x11);
    @memset(neighbour, 0x22);
    a.free(freed);
    for (freed) |b| try testing.expectEqual(byte, b);
    for (neighbour) |b| try testing.expectEqual(@as(u8, 0x22), b);
    a.free(neighbour);
}

test "a pointer read from a freed struct is not a canonical address" {
    const Linked = struct { next: ?*u64, value: u64 };
    var buffer: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    var poisoning: Poisoning = .{ .child = fixed.allocator() };
    const a = poisoning.allocator();
    var target: u64 = 7;
    const node = try a.create(Linked);
    node.* = .{ .next = &target, .value = 1 };
    const bytes: [*]const u8 = @ptrCast(node);
    a.destroy(node);
    // What a stale `node.next` reads: every byte poison - an address with
    // its top bits set, which arm64 and x86-64 both fault on.
    const stale = std.mem.readInt(usize, bytes[0..@sizeOf(usize)], .little);
    try testing.expectEqual(@as(usize, 0xdddd_dddd_dddd_dddd), stale);
}

test "a block shrunk in place has its tail poisoned; a large block is left to the unmap" {
    var buffer: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    var poisoning: Poisoning = .{ .child = fixed.allocator() };
    const a = poisoning.allocator();
    const block = try a.alloc(u8, 32);
    @memset(block, 0x33);
    try testing.expect(a.resize(block, 8));
    for (block[0..8]) |b| try testing.expectEqual(@as(u8, 0x33), b);
    for (block[8..]) |b| try testing.expectEqual(byte, b);
    a.free(block[0..8]);

    // Over the limit: the DebugAllocator's large allocations, unmapped on
    // free - poisoning them first would only cost.
    var big_buffer: [limit + 64]u8 = undefined;
    var big_fixed = std.heap.FixedBufferAllocator.init(&big_buffer);
    var big_poisoning: Poisoning = .{ .child = big_fixed.allocator() };
    const b = big_poisoning.allocator();
    const big = try b.alloc(u8, limit + 1);
    @memset(big, 0x44);
    // rawFree: Allocator.free writes `undefined` first in a Debug build.
    b.rawFree(big, .@"1", @returnAddress());
    try testing.expectEqual(@as(u8, 0x44), big[0]);
}

test "the poison limit is the DebugAllocator's largest small block: larger ones are unmapped when freed" {
    // DebugAllocator's default page size on these hosts is 128 KiB
    // (max(page_size_max, 128 KiB)), and its small size classes run up to
    // 2^(log2(page_size) - 2) bytes (minimum_slots_per_bucket_log2 = 1):
    // 32 KiB. Anything larger is a large allocation.
    const page_size = @max(std.heap.page_size_max, 128 * 1024);
    try testing.expectEqual(@as(usize, page_size / 4), limit);
}

test "CRANE_POISON_FREES: on by default, off when set to 0 or empty" {
    try testing.expect(by_default);
    try testing.expect(enabled(null) == by_default);
    try testing.expect(!enabled("0"));
    try testing.expect(!enabled(""));
    try testing.expect(enabled("1"));
    try testing.expect(enabled("yes"));
}

/// A struct as a test keeps a pointer to: a value and a pointer.
const Node = struct { value: u64, next: *const u64 };

/// `allocator` creates a Node, destroys it, and returns what a read through
/// the kept pointer finds - while a neighbour in the same size class keeps
/// the slot's page mapped, so the read is of the slot, not of an unmapped
/// page.
fn readAfterDestroy(allocator: Allocator, target: *const u64) !Node {
    const neighbour = try allocator.create(Node);
    defer allocator.destroy(neighbour);
    const node = try allocator.create(Node);
    node.* = .{ .value = 0x1122_3344_5566_7788, .next = target };
    const kept: *volatile Node = node;
    allocator.destroy(node);
    return kept.*;
}

test "a test's DebugAllocator: a struct read after its destroy is poison, under the Crane test runner's switch" {
    const target: u64 = 42;
    var gpa: DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leaked");
    const got = try readAfterDestroy(gpa.allocator(), &target);
    if (processPoisons()) {
        try testing.expectEqual(@as(u64, 0xdddd_dddd_dddd_dddd), got.value);
        try testing.expectEqual(@as(usize, 0xdddd_dddd_dddd_dddd), @intFromPtr(got.next));
    } else {
        // CRANE_POISON_FREES=0: the DebugAllocator's own, which leaves the
        // bytes as they were.
        try testing.expectEqual(@as(u64, 0x1122_3344_5566_7788), got.value);
    }
}

test "std's DebugAllocator alone leaves a destroyed struct's bytes as they were - why the drop-in exists" {
    const target: u64 = 42;
    var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leaked");
    const got = try readAfterDestroy(gpa.allocator(), &target);
    try testing.expectEqual(@as(u64, 0x1122_3344_5566_7788), got.value);
    try testing.expectEqual(&target, got.next);
}

test "std.testing.allocator: a struct read after its destroy is SafeAllocator's 0x55, under the Crane test runner's switch" {
    const target: u64 = 42;
    const got = try readAfterDestroy(testing.allocator, &target);
    try testing.expectEqual(processPoisons(), testing.allocator_instance.check_write_after_free);
    if (processPoisons()) {
        try testing.expectEqual(@as(u64, 0x5555_5555_5555_5555), got.value);
        try testing.expectEqual(@as(usize, 0x5555_5555_5555_5555), @intFromPtr(got.next));
    }
}

test "a test's DebugAllocator: a block shrunk in place has its tail poisoned, and a clean run deinits clean" {
    var gpa: DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    const a = gpa.allocator();
    const kept = try a.create(u64);
    const block = try a.alloc(u8, 64);
    @memset(block, 0x33);
    // 64 to 40 stays in the DebugAllocator's 64-byte size class: in place.
    try testing.expect(a.resize(block, 40));
    for (block[0..40]) |b| try testing.expectEqual(@as(u8, 0x33), b);
    if (processPoisons()) for (block[40..]) |b| try testing.expectEqual(byte, b);
    a.free(block[0..40]);
    a.destroy(kept);
    try testing.expectEqual(std.heap.Check.ok, gpa.deinit());
}

test "a churn allocator records no stack traces, checks for leaks and names its test" {
    try testing.expectEqual(@as(usize, 0), churn_stack_trace_frames);
    var churn = ChurnAllocator.init("poisoning: a churn allocator");
    const a = churn.allocator();
    for (0..100_000) |i| {
        const block = try a.alloc(u8, 1 + i % 64);
        a.free(block);
    }
    try churn.deinit();
}

test "a test's DebugAllocator: allocations from many threads, each freed on another" {
    var gpa: DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    const a = gpa.allocator();
    const Worker = struct {
        fn make(alloc: Allocator, out: *[64]*Node) void {
            for (out) |*o| o.* = alloc.create(Node) catch unreachable;
        }
        fn free(alloc: Allocator, in: *[64]*Node) void {
            for (in) |p| alloc.destroy(p);
        }
    };
    var made: [4][64]*Node = undefined;
    var threads: [4]std.Thread = undefined;
    for (&threads, &made) |*t, *m| t.* = try std.Thread.spawn(.{}, Worker.make, .{ a, m });
    for (threads) |t| t.join();
    for (&threads, &made) |*t, *m| t.* = try std.Thread.spawn(.{}, Worker.free, .{ a, m });
    for (threads) |t| t.join();
    try testing.expectEqual(std.heap.Check.ok, gpa.deinit());
}

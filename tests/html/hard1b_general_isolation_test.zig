//! Allocator hardening, batch B, red tests B3, B5 and B4' (the B1 merge's):
//! a Browser's general memory is its own, checked on every free, and
//! counted at its end (tmp/plans/allocator-hardening-design.md, 3.2-3.3 and
//! section 7 batch B items 1, 2 and 5).
//!
//! - B3: a general block Browser A frees is never issued to Browser B on the
//!   same thread (glibc's tcache is per thread, not per Browser; xzone's
//!   buckets are per process).
//! - B5: a double, an interior, a wrong-size and another Browser's free in
//!   the general partitions are caught - through the heap's test hook
//!   (`checks = .report`), where production panics - in every build (libc's
//!   checks are partial, and differ by OS).
//! - B4': a general block left alive at the Browser's end is in its heap's
//!   leak report, so a test that leaks one still fails once
//!   std.testing.allocator no longer sees the block (design 10.2).
//!
//! Each FAILS today on its first assertion: the block is in the host
//! allocator's memory, outside the Browser's reservation.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const Heap = runtime.BrowserScope.Heap;
const heap_engine = runtime.heap;

fn inReservation(heap: *const Heap.BrowserHeap, ptr: *const anyopaque) bool {
    const address = @intFromPtr(ptr);
    return address >= heap.reserved.base and address - heap.reserved.base < heap.reserved.size;
}

const Side = struct {
    page: helpers.Page,
    heap: *Heap.BrowserHeap,
    engine: *heap_engine.Engine,
    allocator: std.mem.Allocator,

    fn open() !Side {
        const page = try helpers.Page.open();
        errdefer page.close();
        const heap = page.browser.scope.heap orelse return error.NoHeap;
        // A rung with no general pools keeps general memory on the host's
        // allocator (design 4.2): nothing here applies.
        if (!heap.general_pools) return error.SkipZigTest;
        const context = page.browser.current_context orelse return error.NoPage;
        const document = context.document_instance orelse return error.NoDocument;
        return .{
            .page = page,
            .heap = heap,
            .engine = try page.browser.scope.heapEngine(),
            .allocator = runtime.allocatorOf(document),
        };
    }

    fn close(self: Side) void {
        self.page.close();
    }
};

const Pointers = struct { next: ?*anyopaque, prev: ?*anyopaque, count: usize, flags: usize };

fn crossBrowser() !void {
    const a = try Side.open();
    defer a.close();
    const b = try Side.open();
    defer b.close();

    // A pointer-bearing class and a bytes class, each freed in A and then
    // asked for in B: B's block is B's, never the one A gave back.
    const in_a = try a.allocator.create(Pointers);
    if (!inReservation(a.heap, in_a)) {
        // Today: the host allocator's block; given back so only this fails.
        a.allocator.destroy(in_a);
        return error.GeneralBlockOutsideTheHeap;
    }
    const freed_pointers: usize = @intFromPtr(in_a);
    a.allocator.destroy(in_a);
    const in_b = try b.allocator.create(Pointers);
    defer b.allocator.destroy(in_b);
    try testing.expect(inReservation(b.heap, in_b));
    try testing.expect(@intFromPtr(in_b) != freed_pointers);

    const text_a = try a.allocator.alloc(u8, 48);
    try testing.expect(inReservation(a.heap, text_a.ptr));
    const freed_text: usize = @intFromPtr(text_a.ptr);
    a.allocator.free(text_a);
    const text_b = try b.allocator.alloc(u8, 48);
    defer b.allocator.free(text_b);
    try testing.expect(inReservation(b.heap, text_b.ptr));
    try testing.expect(@intFromPtr(text_b.ptr) != freed_text);
}

test "B3: a general block Browser A frees is never issued to Browser B on the same thread" {
    try helpers.onFreshThread(crossBrowser);
}

fn invalidFrees() !void {
    const a = try Side.open();
    defer a.close();
    const b = try Side.open();
    defer b.close();
    a.engine.checks = .report;
    b.engine.checks = .report;
    defer a.engine.checks = .panic;
    defer b.engine.checks = .panic;

    const words = try a.allocator.alloc(usize, 8);
    if (!inReservation(a.heap, words.ptr)) {
        // Today: the host allocator's block, whose checks are its own;
        // given back so only this fails.
        a.allocator.free(words);
        return error.GeneralBlockOutsideTheHeap;
    }
    const bytes = std.mem.sliceAsBytes(words);
    const alignment: std.mem.Alignment = .of(usize);
    // Interior: one word in.
    a.allocator.rawFree(bytes[8..], alignment, @returnAddress());
    try testing.expectEqual(@as(?heap_engine.Violation, .invalid_free), a.engine.takeViolation());
    // The block's start, another class's size.
    a.allocator.rawFree(bytes.ptr[0..4096], alignment, @returnAddress());
    try testing.expectEqual(@as(?heap_engine.Violation, .wrong_size), a.engine.takeViolation());
    // Through another Browser's allocator.
    b.allocator.free(words);
    try testing.expectEqual(@as(?heap_engine.Violation, .other_heap), b.engine.takeViolation());
    // None of them freed it: its own free works, once; the second is caught.
    a.allocator.free(words);
    try testing.expectEqual(@as(?heap_engine.Violation, null), a.engine.takeViolation());
    a.allocator.free(words);
    try testing.expectEqual(@as(?heap_engine.Violation, .double_free), a.engine.takeViolation());

    // The bytes partition checks its frees the same way.
    const text = try a.allocator.alloc(u8, 40);
    try testing.expect(inReservation(a.heap, text.ptr));
    a.allocator.free(text);
    try testing.expectEqual(@as(?heap_engine.Violation, null), a.engine.takeViolation());
    a.allocator.free(text);
    try testing.expectEqual(@as(?heap_engine.Violation, .double_free), a.engine.takeViolation());
}

test "B5: a double, an interior, a wrong-size and another Browser's free in the general partitions are caught" {
    try helpers.onFreshThread(invalidFrees);
}

fn leakCounted() !void {
    const side = try Side.open();
    var leaked: usize = 0;
    {
        errdefer side.close();
        // A block made and never freed: the test's own leak, on purpose.
        const block = try side.allocator.alloc(u8, 64);
        if (!inReservation(side.heap, block.ptr)) {
            // Today: the host allocator's block, which its own leak check
            // would name; give it back so only this assertion fails.
            side.allocator.free(block);
            return error.GeneralBlockOutsideTheHeap;
        }
        side.page.browser.scope.heap_leak_count_out = &leaked;
    }
    side.close();
    try testing.expectEqual(@as(usize, 1), leaked);
}

test "B4': a general block left alive at the Browser's end is in its heap's leak report" {
    try helpers.onFreshThread(leakCounted);
}

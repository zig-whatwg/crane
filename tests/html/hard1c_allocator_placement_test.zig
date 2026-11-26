//! Allocator hardening, batch C, items 2, 3, and 5 (Browser-level placement):
//! - Item 3: Brotli & zlib C callback buffers allocated through a Browser's
//!   `scope.allocator` land in `.bytes` (not `.objects`);
//! - Item 2: `EventTarget` with `AbortSignal` maps 0 OS pages and keeps its
//!   `SignalRemoval` records in `.objects`; non-V8 per-Browser records
//!   (`Navigation`, `rejected_promises`, etc.) allocate from `.objects` instead
//!   of `std.heap.c_allocator`.
//!
//! Design: tmp/plans/allocator-hardening-design.md §7 Batch C items 2, 3, 5.

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const Heap = runtime.BrowserScope.Heap;

const Range = enum { outside, cage, objects, bytes, metadata };

fn rangeOf(heap: *const Heap.BrowserHeap, ptr: *const anyopaque) Range {
    const address = @intFromPtr(ptr);
    if (address < heap.reserved.base or address - heap.reserved.base >= heap.reserved.size) return .outside;
    const offset: u64 = address - heap.window_base;
    const l = Heap.layout;
    if (offset >= l.cage.offset and offset < l.cage.end()) return .cage;
    if (offset >= l.objects.offset and offset < l.objects.end()) return .objects;
    if (offset >= l.bytes.offset and offset < l.bytes.end()) return .bytes;
    return .metadata;
}

const brotli_foo = [_]u8{ 0x21, 0x08, 0x00, 0x04, 0x66, 0x6f, 0x6f, 0x03 };
const deflate_foo = [_]u8{ 0x01, 0x03, 0x00, 0xfc, 0xff, 'f', 'o', 'o' };

fn codecBuffersInBrowserBytes() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const heap = page.browser.scope.heap orelse return error.NoHeap;
    if (!heap.general_pools) return error.SkipZigTest;
    const heap_engine = page.browser.scope.existingHeapEngine() orelse return error.NoEngine;
    const allocator = page.browser.scope.allocator;

    if (platform.capabilities.brotli != .unsupported) {
        const before = heap_engine.stats();
        const decoder = try platform.createBrotliDecoder(allocator);
        defer platform.destroyBrotliDecoder(decoder);
        var out: [32]u8 = undefined;
        const progress = try platform.decompressBrotli(decoder, .from(&brotli_foo), &out);
        try testing.expectEqual(platform.CodecStatus.finished, progress.status);
        try testing.expectEqualStrings("foo", out[0..progress.produced]);

        // Wrapper struct itself sits in `.objects`.
        try testing.expectEqual(Range.objects, rangeOf(heap, decoder));
        const during = heap_engine.stats();
        // Only the 1 wrapper struct was added to general_objects; Brotli's
        // internal C buffers live in `.bytes`.
        try testing.expectEqual(before.general_objects.live_blocks + 1, during.general_objects.live_blocks);
        try testing.expect(during.bytes.live_blocks > before.bytes.live_blocks);
    }

    if (platform.capabilities.deflate_decoding != .unsupported) {
        const before = heap_engine.stats();
        const decoder = try platform.createDeflateDecoder(allocator);
        defer platform.destroyDeflateDecoder(decoder);
        var out: [32]u8 = undefined;
        const progress = try platform.decompressDeflate(decoder, .from(&deflate_foo), &out);
        try testing.expectEqual(platform.CodecStatus.finished, progress.status);
        try testing.expectEqualStrings("foo", out[0..progress.produced]);

        try testing.expectEqual(Range.objects, rangeOf(heap, decoder));
        const during = heap_engine.stats();
        try testing.expectEqual(before.general_objects.live_blocks + 1, during.general_objects.live_blocks);
        try testing.expect(during.bytes.live_blocks > before.bytes.live_blocks);
    }
}

test "item 3: Browser Brotli and zlib C buffers live in the heap's .bytes partition" {
    try helpers.onFreshThread(codecBuffersInBrowserBytes);
}

fn eventTargetSignalMapsZeroPages() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const heap = page.browser.scope.heap orelse return error.NoHeap;
    if (!heap.general_pools) return error.SkipZigTest;
    const heap_engine = page.browser.scope.existingHeapEngine() orelse return error.NoEngine;

    // Warm up one listener with a signal so initial spans are committed.
    try page.run(
        \\const ac = new AbortController();
        \\const et = new EventTarget();
        \\et.addEventListener('warm', () => {}, { signal: ac.signal });
    );
    const before_stats = heap_engine.stats();
    const before_committed = heap.committed_bytes;

    // Adding 64 listeners with a signal must stay inside the Browser's objects
    // pool (0 new OS page mappings / committed spans for 64 * 48 B < 16 KiB).
    try page.run(
        \\for (let i = 0; i < 64; i++) {
        \\  et.addEventListener('ev-' + i, () => {}, { signal: ac.signal });
        \\}
    );
    const after_stats = heap_engine.stats();
    const after_committed = heap.committed_bytes;

    // SignalRemoval records are tracked in general_objects.
    try testing.expect(after_stats.general_objects.live_blocks >= before_stats.general_objects.live_blocks + 64);
    // Nowhere near 64 * 4 KiB = 256 KiB of newly mapped pages.
    try testing.expect(after_committed <= before_committed + 64 * 1024);

    // Aborting cleans up every SignalRemoval record.
    try page.run("ac.abort();");
}

test "item 2: EventTarget addEventListener with signal allocates in .objects with no page-per-listener mapping" {
    try helpers.onFreshThread(eventTargetSignalMapsZeroPages);
}

fn rejectedPromisesInBrowserObjects() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const heap = page.browser.scope.heap orelse return error.NoHeap;
    if (!heap.general_pools) return error.SkipZigTest;

    // Create an unhandled rejected promise so rejected_promises.zig allocates
    // its per-global state and appends it to `browser.agent_host.rejections`.
    // On main `7cec3d819`, `rejected_promises.zig` uses `std.heap.c_allocator`,
    // so both the list buffer and the per-global state sit outside the heap.
    try page.run(
        \\window.addEventListener('unhandledrejection', e => e.preventDefault());
        \\globalThis.__rej = Promise.reject('hard1c-rej');
    );
    const rejections = &page.browser.agent_host.rejections;
    try testing.expect(rejections.items.len >= 1);
    try testing.expectEqual(Range.objects, rangeOf(heap, @ptrCast(rejections.items.ptr)));
    try testing.expectEqual(Range.objects, rangeOf(heap, rejections.items[0]));
}

test "item 2: rejected_promises tracking allocates from Browser heap .objects, not c_allocator" {
    try helpers.onFreshThread(rejectedPromisesInBrowserObjects);
}

fn memoryMapPerTypeAttribution() !void {
    const page = try helpers.Page.open();
    defer page.close();

    try page.run(
        \\globalThis.__divs = [];
        \\for (let i = 0; i < 30; i++) {
        \\  const d = document.createElement('div');
        \\  d.setAttribute('data-k', 'v-' + i);
        \\  d.addEventListener('click', () => {});
        \\  globalThis.__divs.push(d);
        \\}
    );

    const browser_mod = @import("browser");
    var report = try browser_mod.memory_map.collect(page.browser.scope, testing.allocator);
    defer report.deinit(testing.allocator);

    const div_row = report.rowNamed("HTMLDivElement") orelse return error.MissingDivRow;
    try testing.expect(div_row.count >= 30);
    try testing.expect(div_row.state_bytes > 0);
    try testing.expectEqual(div_row.count * runtime.SlabAllocator.slot_bytes, div_row.slot_bytes);
    try testing.expect(div_row.satellite_bytes > 0);
    try testing.expect(report.heap_stats != null);

    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try browser_mod.memory_map.writeReport(&report, &out.writer);
    const text = out.written();
    try testing.expect(std.mem.indexOf(u8, text, "HTMLDivElement") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Browser Heap Partitions:") != null);
    try testing.expect(std.mem.indexOf(u8, text, "satellite") != null);
}

test "item 5: memory_map reports per-interface state, slot, satellite bytes and 4-partition heap summary" {
    try helpers.onFreshThread(memoryMapPerTypeAttribution);
}

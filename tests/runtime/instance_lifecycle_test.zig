//! What the lifecycle registry remembers about an instance after its cleanup.
//!
//! A DOM node is torn down twice over when its context goes: once by its
//! tree (`Node.deinit` walking the children of a node whose wrapper the cache
//! frees) and once by its own wrapper-cache entry. The cache skips an entry
//! whose instance `isCleanupStarted`, and every type's deinit guards itself with
//! `markCleanupStarted`. Both depend on the registry still answering "cleaned
//! up" after `markCleanupComplete`, for as long as the slot is not reissued.
//!
//! It did not: `markCleanupComplete` removed the record, so the cache's check
//! found an instance that looked untouched, and an iframe's deinit ran twice -
//! freeing its IFrameIntegration block twice. The arena then handed that block
//! to the next page's Window state AND to a DocumentType, whose zeroing wiped
//! the Window's browsing context (a SEGV at 0x20 in BrowsingContext.initChild).
//! The flags live in the instance's slab slot (instances B1): they belong to
//! the instance's Browser, survive the instance's free, and start empty when
//! the slab issues the slot again.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const lifecycle = runtime.instance_lifecycle;

const no_methods = .{};
const vtable: runtime.VTable = .{ .name = "Lifecycle", .deinit = null, .methods_ptr = &no_methods };

test "a completed cleanup is still a started one, until the slot is reused" {
    var slab = runtime.SlabAllocator.init(testing.allocator);
    defer slab.deinit();
    const instance = try slab.alloc(&vtable);

    try testing.expect(lifecycle.markCleanupStarted(instance));
    lifecycle.markCleanupComplete(instance);

    // What the wrapper cache and every type's guard read.
    try testing.expect(lifecycle.isCleanupStarted(instance));
    try testing.expect(lifecycle.isCleanedUp(instance));
    try testing.expect(!lifecycle.markCleanupStarted(instance));

    // And after the slot is freed: a teardown that still holds the address
    // reads "cleaned up", not "untouched".
    slab.free(instance);
    try testing.expect(lifecycle.isCleanupStarted(instance));
    try testing.expect(lifecycle.isCleanedUp(instance));
}

test "a reissued slot starts fresh" {
    var slab = runtime.SlabAllocator.init(testing.allocator);
    defer slab.deinit();
    const instance = try slab.alloc(&vtable);

    try testing.expect(lifecycle.markCleanupStarted(instance));
    lifecycle.markCleanupComplete(instance);
    lifecycle.markAttachedToDOM(instance);
    slab.free(instance);

    // The slab clears the flags of the slot it hands out.
    const again = try slab.alloc(&vtable);
    try testing.expectEqual(instance, again);
    try testing.expect(!lifecycle.isCleanupStarted(again));
    try testing.expect(!lifecycle.isAttachedToDOM(again));
    try testing.expect(lifecycle.markCleanupStarted(again));
}

test "flags are each instance's own, and never change its generation" {
    var slab = runtime.SlabAllocator.init(testing.allocator);
    defer slab.deinit();
    const first = try slab.alloc(&vtable);
    const second = try slab.alloc(&vtable);
    const generation = runtime.SlabAllocator.generationOf(first);

    lifecycle.markGCWeakCallbackPending(first);
    lifecycle.markAttachedToDOM(first);
    try testing.expect(lifecycle.hasGCWeakCallbackPending(first));
    try testing.expect(!lifecycle.hasGCWeakCallbackPending(second));
    try testing.expect(lifecycle.shouldCleanup(second));
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(first));
    lifecycle.clearGCWeakCallbackPending(first);
    lifecycle.markDetachedFromDOM(first);
    try testing.expect(!lifecycle.hasGCWeakCallbackPending(first));
    try testing.expect(!lifecycle.isAttachedToDOM(first));
}

// Lane unwrapped1: the wrap mark (`wrapped`), which a realm's end reads to
// free the storage of nodes no wrapper ever reached.

test "a wrap mark is sticky until the slab issues the slot again" {
    var slab = runtime.SlabAllocator.init(testing.allocator);
    defer slab.deinit();
    const instance = try slab.alloc(&vtable);
    const generation = runtime.SlabAllocator.generationOf(instance);

    try testing.expect(!lifecycle.wasWrapped(instance));
    lifecycle.markWrapped(instance);
    try testing.expect(lifecycle.wasWrapped(instance));
    // Nothing else clears it - not a cleanup, not the free - and it never
    // touches the generation or the other flags.
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(instance));
    try testing.expect(lifecycle.markCleanupStarted(instance));
    lifecycle.markCleanupComplete(instance);
    try testing.expect(lifecycle.wasWrapped(instance));
    try testing.expect(lifecycle.isCleanedUp(instance));
    slab.free(instance);
    try testing.expect(lifecycle.wasWrapped(instance));

    const again = try slab.alloc(&vtable);
    try testing.expectEqual(instance, again);
    try testing.expect(!lifecycle.wasWrapped(again));
}

test "the DEFAULT: an engine that does not track wraps proves no instance unwrapped" {
    var slab = runtime.SlabAllocator.init(testing.allocator);
    defer slab.deinit();
    const instance = try slab.alloc(&vtable);

    // Unmarked, on an engine that does not mark (JavaScriptCore, QuickJS,
    // the test adapter): the missing mark proves nothing, so nothing may be
    // freed on its strength - a realm's end keeps the slot (the safe answer).
    try testing.expect(!lifecycle.provablyUnwrapped(false, instance));
    lifecycle.markWrapped(instance);
    try testing.expect(!lifecycle.provablyUnwrapped(false, instance));

    // On an engine that marks every wrap, only an unmarked instance is.
    const unmarked = try slab.alloc(&vtable);
    try testing.expect(lifecycle.provablyUnwrapped(true, unmarked));
    try testing.expect(!lifecycle.provablyUnwrapped(true, instance));
}

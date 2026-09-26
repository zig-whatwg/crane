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

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const lifecycle = runtime.instance_lifecycle;

test "a completed cleanup is still a started one, until the slot is reused" {
    defer lifecycle.clearAll();
    var instance: runtime.Instance = undefined;

    try testing.expect(lifecycle.markCleanupStarted(&instance));
    lifecycle.markCleanupComplete(&instance);

    // What the wrapper cache and every type's guard read.
    try testing.expect(lifecycle.isCleanupStarted(&instance));
    try testing.expect(lifecycle.isCleanedUp(&instance));
    try testing.expect(!lifecycle.markCleanupStarted(&instance));
}

test "a reissued slot starts fresh" {
    defer lifecycle.clearAll();
    var instance: runtime.Instance = undefined;

    try testing.expect(lifecycle.markCleanupStarted(&instance));
    lifecycle.markCleanupComplete(&instance);

    // Instance.init resets the flags of the address it hands out.
    lifecycle.reset(&instance);
    try testing.expect(!lifecycle.isCleanupStarted(&instance));
    try testing.expect(lifecycle.markCleanupStarted(&instance));
}

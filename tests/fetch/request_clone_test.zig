//! Fetch §2.2.5 "clone a request": the copy is a request of its own.
//!
//! `fetch()` hands the fetch a clone of requestObject's request, because the
//! fetch now outlives the call - and the Request object it came from may be
//! collected first. So a clone must own everything its `deinit` frees.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const InternalRequest = fetch.internal.InternalRequest;

test "a clone owns its integrity metadata, so both requests can be freed" {
    const original = try InternalRequest.init(testing.allocator, "https://example.com/script.js");
    // What the Request constructor does with `integrity`: an owned copy.
    original.integrity_metadata = try testing.allocator.dupe(u8, "sha256-abc");

    const copy = try original.clone();
    try testing.expectEqualStrings("sha256-abc", copy.integrity_metadata);
    try testing.expect(copy.integrity_metadata.ptr != original.integrity_metadata.ptr);

    // Each frees its own; with a shared slice the second is a double free.
    original.deinit();
    copy.deinit();
}

test "a clone of a request without integrity metadata has none" {
    const original = try InternalRequest.init(testing.allocator, "https://example.com/");
    defer original.deinit();
    const copy = try original.clone();
    defer copy.deinit();
    try testing.expectEqual(@as(usize, 0), copy.integrity_metadata.len);
}

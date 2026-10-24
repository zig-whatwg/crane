//! A request and its clone own parsed entries, including after the store ends.
const std = @import("std");
const fetch = @import("fetch");
const file = @import("file");
const testing = std.testing;

test "xw1 request clones keep opaque blob identity and bytes after revocation and store destruction" {
    const a = testing.allocator;
    var store = file.BlobURLStore.init(a);
    var store_live = true;
    defer if (store_live) store.deinit();
    const key = "null https://xw1.test 1 c -";
    const blob = try file.BlobData.init(a, "held by requests", "text/plain");
    defer blob.deinit();
    const url = try store.createObjectURLWithOrigin(blob, key, 12, null);
    defer a.free(url);
    const original = try fetch.internal.InternalRequest.init(a, url);
    defer original.deinit();
    const entry = store.capture(url) orelse return error.NoEntry;
    original.setCapturedBlobEntry(entry);
    entry.release();
    try fetch.internal.populateRequestFromClient(original, .{ .origin = "null", .origin_nonce = 12, .storage_key = key });
    const copy = try original.clone();
    defer copy.deinit();
    try testing.expect(try copy.currentUrlIsSameOrigin());
    copy.origin_nonce = 13;
    try testing.expect(!try copy.currentUrlIsSameOrigin());
    try copy.setOrigin("null");
    try testing.expect(copy.origin_nonce == null);
    try testing.expect(!try copy.currentUrlIsSameOrigin());
    copy.origin_nonce = 12;
    store.revokeObjectURL(url, key);
    store.deinit();
    store_live = false;
    const data = try copy.blob_url_entry.?.read(a, .{ .environment = key });
    defer data.deinit(a);
    try testing.expectEqualStrings("held by requests", data.bytes);
    try testing.expect(try copy.currentUrlIsSameOrigin());
    // A redirect/current URL change must stop consulting the old blob entry.
    try copy.addUrl("https://elsewhere.test/");
    try testing.expect(!try copy.currentUrlIsSameOrigin());
    original.setCapturedBlobEntry(null);
    try testing.expect(!try original.currentUrlIsSameOrigin());
}

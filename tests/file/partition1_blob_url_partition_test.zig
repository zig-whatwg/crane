//! Lane partition1: the blob URL store checks storage keys (File API 8.3.2
//! "check for same-partition blob URL usage"): an entry records its
//! creator's storage key for non-storage purposes - serialized, origin,
//! top-level site, has-cross-site-ancestor - and only an environment with an
//! equal key obtains its blob (Fetch scheme fetch "blob") or revokes it
//! (revokeObjectURL step 5), except a top-level navigation and a top-level
//! self-fetch (File API "obtain a blob object", Fetch scheme fetch "blob"
//! step 6), which are not checked.

const std = @import("std");
const testing = std.testing;
const file = @import("file");

const first_party = "https://web-platform.test:8443 https://web-platform.test 0";
/// The same origin in an iframe of a page on another site.
const third_party = "https://web-platform.test:8443 https://not-web-platform.test 1";
/// Another origin of the same site, first-party.
const other_origin = "https://www1.web-platform.test:8443 https://web-platform.test 0";

fn expectResolves(store: *file.BlobURLStore, url: []const u8, access: file.BlobURLStore.Access) !void {
    const data = store.resolve(url, access) orelse return error.TestExpectedBlob;
    data.deinit();
}

fn expectRefused(store: *file.BlobURLStore, url: []const u8, access: file.BlobURLStore.Access) !void {
    const data = store.resolve(url, access);
    defer if (data) |d| d.deinit();
    try testing.expect(data == null);
}

test "a blob URL's blob is obtained only under its creator's storage key" {
    var store = file.BlobURLStore.init(testing.allocator);
    defer store.deinit();
    const blob = try file.BlobData.init(testing.allocator, "blob data", "text/plain");
    defer blob.deinit();
    const url = try store.createObjectURL(blob, first_party, null);
    defer testing.allocator.free(url);

    // The URL names the key's origin.
    try testing.expect(std.mem.startsWith(u8, url, "blob:https://web-platform.test:8443/"));
    try expectResolves(&store, url, .{ .environment = first_party });
    // One origin, another partition: a frame of it under another site.
    try expectRefused(&store, url, .{ .environment = third_party });
    // Another origin of the same site.
    try expectRefused(&store, url, .{ .environment = other_origin });
    // Unchecked: a top-level navigation, a top-level self-fetch.
    try expectResolves(&store, url, .top_level_navigation);
    try expectResolves(&store, url, .top_level_self_fetch);
    try testing.expect(store.hasEntry(url));
}

test "revokeObjectURL from another partition, or another origin, silently revokes nothing" {
    var store = file.BlobURLStore.init(testing.allocator);
    defer store.deinit();
    const blob = try file.BlobData.init(testing.allocator, "blob data", "text/plain");
    defer blob.deinit();
    const url = try store.createObjectURL(blob, first_party, null);
    defer testing.allocator.free(url);

    store.revokeObjectURL(url, third_party);
    try expectResolves(&store, url, .{ .environment = first_party });
    store.revokeObjectURL(url, other_origin);
    try expectResolves(&store, url, .{ .environment = first_party });

    store.revokeObjectURL(url, first_party);
    try expectRefused(&store, url, .{ .environment = first_party });
    try expectRefused(&store, url, .top_level_navigation);
    try testing.expect(!store.hasEntry(url));
}

test "a third-party creator's blob URL resolves in its own partition, not the first party's" {
    var store = file.BlobURLStore.init(testing.allocator);
    defer store.deinit();
    const blob = try file.BlobData.init(testing.allocator, "blob data", "text/plain");
    defer blob.deinit();
    const url = try store.createObjectURL(blob, third_party, null);
    defer testing.allocator.free(url);
    try expectResolves(&store, url, .{ .environment = third_party });
    try expectRefused(&store, url, .{ .environment = first_party });
    // cross-partition-self-fetch: the blob document it opens at the top
    // level fetches itself.
    try expectResolves(&store, url, .top_level_self_fetch);
}

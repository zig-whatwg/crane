//! Service Workers 6.3.2 preserves the parsed import URL across its fetch hook.
const std = @import("std");
const html = @import("html_core");
const file = @import("file");
const scripts = html.workers.script_fetch;

test "xw1 service import fetch retains the entry captured before an earlier import revoked it" {
    try std.testing.expect(@hasField(scripts.ServiceWorkerFetchOptions, "blob_url_entry"));
    if (comptime !@hasField(scripts.ServiceWorkerFetchOptions, "blob_url_entry")) return;
    const a = std.testing.allocator;
    var store = file.BlobURLStore.init(a);
    defer store.deinit();
    const blob = try file.BlobData.init(a, "self.imported = true;", "text/javascript");
    defer blob.deinit();
    const key = "https://xw1.test https://xw1.test 0";
    const url = try store.createObjectURL(blob, key, null);
    defer a.free(url);
    // The complete list of URLs is parsed before any import runs.
    const parsed_entry = store.capture(url) orelse return error.NoEntry;
    defer parsed_entry.release();
    // Another script/environment revokes the store mapping before this
    // imported script reaches Service Workers 6.3.2's fetch step 9.
    store.revokeObjectURL(url, key);
    const request = try scripts.serviceWorkerScriptRequest(a, url, .{
        .kind = .imported_script,
        .origin = "https://xw1.test",
        .storage_key = key,
        .blob_url_entry = parsed_entry,
        .blob_url_captured = true,
    });
    defer request.deinit();
    try std.testing.expect(request.blob_url_captured);
    try std.testing.expect(request.blob_url_entry == parsed_entry);
    try std.testing.expectEqualStrings(key, request.blob_storage_key.?);
    const data = try request.blob_url_entry.?.read(a, .{ .environment = request.blob_storage_key.? });
    defer data.deinit(a);
    try std.testing.expectEqualStrings("self.imported = true;", data.bytes);
    try std.testing.expectEqual(.none, request.service_workers_mode);
    try std.testing.expectEqual(.script, request.destination);
}

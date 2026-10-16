const std = @import("std");
const fetch = @import("fetch");
const Request = fetch.internal.InternalRequest;
const Client = fetch.internal.RequestClient;

test "XHR client top-level site is owned by each populated and cloned request" {
    if (!@hasField(Client, "top_level_site")) return error.TestUnexpectedResult;
    const allocator = std.testing.allocator;
    const request = try Request.init(allocator, "https://sub.example/path");
    defer request.deinit();
    var site = [_]u8{'a'};
    try fetch.internal.populateRequestFromClient(request, .{ .top_level_site = &site });
    site[0] = 'b';
    try std.testing.expectEqualStrings("a", request.network_partition_key.?);
    const copy = try request.clone();
    defer copy.deinit();
    try std.testing.expectEqualStrings("a", copy.network_partition_key.?);
    try std.testing.expect(copy.network_partition_key.?.ptr != request.network_partition_key.?.ptr);
    try fetch.internal.populateRequestFromClient(request, .{ .top_level_site = "c" });
    try std.testing.expectEqualStrings("a", request.network_partition_key.?);
}

test "XHR partition capture allocation failure leaves the request unpartitioned" {
    if (!@hasField(Client, "top_level_site")) return error.TestUnexpectedResult;
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const request = try Request.init(failing.allocator(), "https://example.test/");
    defer request.deinit();
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, fetch.internal.populateRequestFromClient(request, .{ .top_level_site = "https://example.test" }));
    try std.testing.expect(request.network_partition_key == null);
}

// The XHR-specific saved-client copy is tested in tests/xhr, where xhr is linked.

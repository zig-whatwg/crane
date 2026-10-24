//! A failed component update must leave the caller's URL valid and owned.
const std = @import("std");
const testing = std.testing;
const url = @import("url");
const parser = url.parser.basic_url_parser;

fn mutate(allocator: std.mem.Allocator, address: []const u8, state: url.parser.parser_state.ParserState, input: []const u8) !void {
    var record = try parser.parse(allocator, address, null);
    defer record.deinit();
    var original = try parser.parse(testing.allocator, address, null);
    defer original.deinit();
    _ = parser.parseWithStateOverride(allocator, input, null, state, &record) catch |err| {
        // equals serializes both records byte for byte, including fragments.
        // Assertion allocations must not consume the failing allocator.
        try testing.expect(try url.equivalence.equals(testing.allocator, &original, &record, false));
        return err;
    };
    try testing.expect(!try url.equivalence.equals(testing.allocator, &original, &record, false));
}

test "state override preserves every old URL field on allocation failure" {
    for ([_][]const u8{
        "https://user:password@child.test:8443/one/two?old=value#saved",
        "custom:opaque?old=value#saved",
        "file:///one/two?old=value#saved",
    }) |address| {
        try testing.checkAllAllocationFailures(testing.allocator, mutate, .{ address, .query, "new=query#still-query" });
        try testing.checkAllAllocationFailures(testing.allocator, mutate, .{ address, .fragment, "new fragment" });
    }
    const address = "https://user:password@child.test:8443/one/two?old=value#saved";
    try testing.checkAllAllocationFailures(testing.allocator, mutate, .{ address, .host, "replacement.test:9443" });
    try testing.checkAllAllocationFailures(testing.allocator, mutate, .{ address, .path_start, "/new/path" });
}

test "component updates preserve a URL's existing opaque blob entry" {
    const Payload = struct { retains: usize = 0, releases: usize = 0 };
    const Callbacks = struct {
        fn retain(ptr: *anyopaque) void {
            const payload: *Payload = @ptrCast(@alignCast(ptr));
            payload.retains += 1;
        }
        fn release(ptr: *anyopaque) void {
            const payload: *Payload = @ptrCast(@alignCast(ptr));
            payload.releases += 1;
        }
        fn read(_: *anyopaque, _: std.mem.Allocator) error{OutOfMemory}!url.blob_url.BlobURLEntry.Data {
            return error.OutOfMemory;
        }
    };
    var payload: Payload = .{};
    {
        var record = try parser.parse(testing.allocator, "blob:https://example.test/id#old", null);
        defer record.deinit();
        const entry = try url.blob_url.BlobURLEntry.create(testing.allocator, "https://example.test", null, &payload, .{
            .retain = &Callbacks.retain,
            .release = &Callbacks.release,
            .read = &Callbacks.read,
        });
        record.blob_url_entry = entry;
        _ = try parser.parseWithStateOverride(testing.allocator, "new", null, .fragment, &record);
        try testing.expect(record.blob_url_entry == entry);
        try testing.expectEqualStrings("new", record.fragment().?);
    }
    try testing.expectEqual(@as(usize, 1), payload.retains);
    try testing.expectEqual(@as(usize, 1), payload.releases);
}

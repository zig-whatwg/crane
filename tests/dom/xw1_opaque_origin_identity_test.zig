//! Opaque identities cross an agent boundary only as values.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const testing = std.testing;
const OriginRecord = dom.origin_record.OriginRecord;

test "xw1 opaque identity is copied across threads without sharing an OriginRecord" {
    try testing.expect(@hasDecl(OriginRecord, "opaqueNonce"));
    if (comptime !@hasDecl(OriginRecord, "opaqueNonce")) return;
    var browser = runtime.BrowserScope.init(testing.allocator);
    defer browser.deinit();
    const creator = try OriginRecord.create(testing.allocator, "null");
    defer creator.release();
    const nonce = (try creator.opaqueNonce(&browser)).?;
    var other_browser = runtime.BrowserScope.init(testing.allocator);
    defer other_browser.deinit();
    const unrelated = try OriginRecord.create(testing.allocator, "null");
    defer unrelated.release();
    try testing.expect(nonce != (try unrelated.opaqueNonce(&other_browser)).?);
    const same = try OriginRecord.create(testing.allocator, "null");
    defer same.release();
    same.importOpaqueNonce(nonce);
    try testing.expect(dom.origin_record.sameOrigin(.{ .serialized = "null", .record = creator }, .{ .serialized = "null", .record = same }));
    try testing.expect(dom.origin_record.sameOriginDomain(.{ .serialized = "null", .record = creator }, .{ .serialized = "null", .record = same }));
    try testing.expect(!dom.origin_record.sameOrigin(.{ .serialized = "null", .record = creator }, .{ .serialized = "null", .record = unrelated }));
    const distinct = try OriginRecord.create(testing.allocator, "null");
    defer distinct.release();
    try testing.expect(nonce != (try distinct.opaqueNonce(&browser)).?);
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(value: u128, out: *anyerror!void) void {
            out.* = imported(value);
        }
        fn imported(value: u128) !void {
            const copy = try OriginRecord.create(testing.allocator, "null");
            defer copy.release();
            copy.importOpaqueNonce(value);
            try testing.expect(copy.isOnOwnerThread());
            try testing.expectEqual(value, (try copy.opaqueNonce(null)).?);
        }
    }.run, .{ nonce, &result });
    thread.join();
    try result;
}

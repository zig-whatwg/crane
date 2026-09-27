//! HTML "report an exception" for a realm whose host owns it
//! (runtime.ContextData.report_exception): a worker's realm - its host fires
//! the ErrorEvent at the WorkerGlobalScope and, unhandled, at the Worker -
//! gets the error information, after the muted-errors and omitError steps,
//! and html/report_exception.zig fires nothing itself.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const report_exception = @import("html").report_exception;

/// What the realm's host was handed.
const Seen = struct {
    var count: usize = 0;
    var reported_to: ?*runtime.ContextData = null;
    var message: [64]u8 = undefined;
    var message_len: usize = 0;
    var filename: [64]u8 = undefined;
    var filename_len: usize = 0;
    var lineno: u32 = 0;
    var colno: u32 = 0;
    var had_value: bool = false;

    fn report(realm: *runtime.ContextData, info: *const runtime.ErrorInfo) void {
        count += 1;
        reported_to = realm;
        message_len = @min(info.message.len, message.len);
        @memcpy(message[0..message_len], info.message[0..message_len]);
        filename_len = @min(info.filename.len, filename.len);
        @memcpy(filename[0..filename_len], info.filename[0..filename_len]);
        lineno = info.lineno;
        colno = info.colno;
        had_value = info.error_value != null;
    }
};

const mock_methods: u8 = 0;
const mock_vtable = runtime.VTable{ .name = "MockGlobalScope", .deinit = null, .methods_ptr = &mock_methods };

test "a realm whose host owns reporting is handed the error information" {
    var realm = try runtime.ContextData.init(testing.allocator, .{});
    defer realm.deinit();
    realm.report_exception = Seen.report;
    // The realm's global object; report_exception reads only its realm.
    var global = runtime.Instance{ .vtable = &mock_vtable, .state = undefined, .ctx = &realm };

    Seen.count = 0;
    const thrown = runtime.JSValue{ .number = 7 };
    const info = runtime.ErrorInfo{ .message = "Uncaught 7", .filename = "https://example.test/w.js", .lineno = 3, .colno = 4, .error_value = thrown };
    _ = report_exception.reportErrorInfo(&global, &info, .{});
    try testing.expectEqual(@as(usize, 1), Seen.count);
    try testing.expectEqual(&realm, Seen.reported_to.?);
    try testing.expectEqualStrings("Uncaught 7", Seen.message[0..Seen.message_len]);
    try testing.expectEqualStrings("https://example.test/w.js", Seen.filename[0..Seen.filename_len]);
    try testing.expectEqual(@as(u32, 3), Seen.lineno);
    try testing.expectEqual(@as(u32, 4), Seen.colno);
    try testing.expect(Seen.had_value);

    // Step 4, muted errors: "Script error." and nothing about the exception.
    _ = report_exception.reportErrorInfo(&global, &info, .{ .muted = true });
    try testing.expectEqual(@as(usize, 2), Seen.count);
    try testing.expectEqualStrings("Script error.", Seen.message[0..Seen.message_len]);
    try testing.expectEqualStrings("", Seen.filename[0..Seen.filename_len]);
    try testing.expectEqual(@as(u32, 0), Seen.lineno);
    try testing.expect(!Seen.had_value);

    // Step 5, omitError: everything but the value.
    _ = report_exception.reportErrorInfo(&global, &info, .{ .omit_error = true });
    try testing.expectEqual(@as(usize, 3), Seen.count);
    try testing.expectEqualStrings("Uncaught 7", Seen.message[0..Seen.message_len]);
    try testing.expect(!Seen.had_value);
}

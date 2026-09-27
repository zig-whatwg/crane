//! The realm hooks the worker host installs on a worker's realm
//! (runtime.ContextData): `end_of_task`, and `report_exception` - HTML "report
//! an exception" for an exception nothing else reports, such as one thrown by
//! an event listener, which fires an ErrorEvent at the WorkerGlobalScope and,
//! unhandled, at the Worker with `error` null.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const worker_host = @import("html").worker_host;

test "a realm has no report_exception until its host installs one" {
    var realm = try runtime.ContextData.init(testing.allocator, .{});
    defer realm.deinit();
    try testing.expect(realm.report_exception == null);
    try testing.expect(realm.end_of_task == null);
}

test "the worker host's hooks are what its realm carries" {
    var realm = try runtime.ContextData.init(testing.allocator, .{});
    defer realm.deinit();
    worker_host.installRealmHooks(&realm);
    try testing.expectEqual(@as(?*const fn (*runtime.ContextData, *const runtime.ErrorInfo) void, &worker_host.reportExceptionOfRealm), realm.report_exception);
    try testing.expectEqual(@as(?*const fn (*runtime.ContextData) void, &worker_host.endTaskOfRealm), realm.end_of_task);
}

test "reporting into a realm no worker runs is a no-op" {
    var realm = try runtime.ContextData.init(testing.allocator, .{});
    defer realm.deinit();
    worker_host.installRealmHooks(&realm);
    const info = runtime.ErrorInfo{ .message = "thrown", .filename = "w.js", .lineno = 1, .colno = 1, .error_value = null };
    realm.report_exception.?(&realm, &info);
}

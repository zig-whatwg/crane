//! The outside settings' cookie jar accompanies the top-level worker fetch.
//! HTML "fetch a classic worker script" step 1, Fetch 3.1.1 and 3.1.2.
const std = @import("std");
const fetch = @import("fetch");
const cookies = fetch.algorithms.cookies;
const cookiestore = @import("cookiestore");
const script_fetch = @import("html_core").workers.script_fetch;

fn roundTrip(shared: bool, module: bool) !void {
    const allocator = std.testing.allocator;
    var jar = cookiestore.CookieJar.init(allocator);
    defer jar.deinit();
    var options: script_fetch.WorkerScriptFetchOptions = .{
        .requesting_origin = "https://tt4.test",
        .shared = shared,
        .worker_type = if (module) .module else .classic,
    };
    // Keep the test executable on the pre-fix tree: without the client
    // input, its response is discarded and the round trip fails below.
    if (@hasField(script_fetch.WorkerScriptFetchOptions, "cookie_jar")) options.cookie_jar = &jar;
    const request = try script_fetch.workerScriptRequest(allocator, "https://tt4.test/worker.js", options);
    defer request.deinit();
    var headers = fetch.internal.HeaderList.init(allocator);
    defer headers.deinit();
    try headers.append("Set-Cookie", "worker_report=ready; Path=/; Secure; HttpOnly; SameSite=Strict");
    // Both calls go through the existing LOCKING http_integration APIs.
    try cookies.storeResponseCookies(allocator, request, &headers);
    const header = (try cookies.requestCookieHeader(allocator, request)) orelse return error.WorkerResponseCookieMissing;
    defer allocator.free(header);
    try std.testing.expectEqualStrings("worker_report=ready", header);
    try std.testing.expectEqual(@as(?*cookiestore.CookieJar, &jar), request.cookie_jar);
}

test "dedicated classic worker response cookie reaches its creator's jar" {
    try roundTrip(false, false);
}

test "shared classic worker response cookie reaches its creator's jar" {
    try roundTrip(true, false);
}

test "module worker root response cookie reaches its creator's jar" {
    try roundTrip(false, true);
    try roundTrip(true, true);
}

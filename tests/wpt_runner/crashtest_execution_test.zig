//! Real-browser execution tests for WPT crashtests (`WptBrowser.runCrashtest`).
//!
//! Exercises the real Browser + V8 + WPT's upstream `executors/test-wait.js`:
//! - plain load -> OK (wptreport PASS, no subtests)
//! - `<html class="test-wait">` waits for `TestRendered` and class removal -> OK
//! - `<html class="test-wait">` removed asynchronously -> OK
//! - `<html class="test-wait">` never removed -> TIMEOUT
//! - permission overrides from an earlier test are reset before a crashtest
//! - an already-expired deadline after load returns TIMEOUT without injecting `test-wait.js`

const std = @import("std");
const testing = std.testing;

const WptBrowser = @import("wpt_browser.zig").WptBrowser;
const permissions = @import("permissions");

const wpt_root = "tests/wpt";
const test_wait_rel = "tests/wpt/tools/wptrunner/wptrunner/executors/test-wait.js";

fn requireWptTestWait() !void {
    std.Io.Dir.cwd().access(std.testing.io, test_wait_rel, .{}) catch return error.SkipZigTest;
}

test "runCrashtest: plain HTML page finishes OK with crashtest=true and no subtests" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "crashtests/plain-crash.html",
        "data:text/html,<!doctype html><html><body><p>ok</p></body></html>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);
    try testing.expectEqual(@as(usize, 0), result.subtests.items.len);
}

test "runCrashtest: test-wait class waits for TestRendered and removal before finishing OK" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "crashtests/test-rendered-crash.html",
        "data:text/html,<!doctype html><html class=\"test-wait\"><script>" ++
            "window.__seen_test_rendered = false;" ++
            "document.documentElement.addEventListener('TestRendered', function() {" ++
            "  window.__seen_test_rendered = true;" ++
            "  document.documentElement.classList.remove('test-wait');" ++
            "});" ++
            "</script><body></body></html>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);
    try testing.expectEqual(@as(usize, 0), result.subtests.items.len);

    const ctx = wb.browser.current_context orelse return error.NoContext;
    const seen = try ctx.evaluateScriptToString("window.__seen_test_rendered === true", allocator);
    defer allocator.free(seen);
    try testing.expectEqualStrings("true", seen);
}

test "runCrashtest: test-wait class removed asynchronously finishes OK" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "crashtests/async-wait-crash.html",
        "data:text/html,<!doctype html><html class=\"test-wait\"><script>" ++
            "setTimeout(function() {" ++
            "  window.__async_done = true;" ++
            "  document.documentElement.classList.remove('test-wait');" ++
            "}, 30);" ++
            "</script><body></body></html>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expect(result.crashtest);

    const ctx = wb.browser.current_context orelse return error.NoContext;
    const done = try ctx.evaluateScriptToString("window.__async_done === true", allocator);
    defer allocator.free(done);
    try testing.expectEqualStrings("true", done);
}

test "runCrashtest: test-wait class never removed returns TIMEOUT" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "crashtests/hang-crash.html",
        "data:text/html,<!doctype html><html class=\"test-wait\"><body>stuck</body></html>",
        250,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.timeout, result.status);
    try testing.expect(result.crashtest);
    try testing.expect(result.message != null);
}

test "runCrashtest: resets permission overrides left by a previous test" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    const store = try wb.browser.scope.of(permissions.BrowserStore);
    const batch = try store.set("https://example.test", .{ .name = .geolocation }, .granted);
    batch.release();
    try testing.expectEqual(
        @as(?permissions.PermissionState, .granted),
        store.overrides.get("https://example.test", .{ .name = .geolocation }),
    );

    var result = try wb.runCrashtest(
        "crashtests/perm-reset-crash.html",
        "data:text/html,<!doctype html><html><body>ok</body></html>",
        5_000,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.ok, result.status);
    try testing.expectEqual(
        @as(?permissions.PermissionState, null),
        store.overrides.get("https://example.test", .{ .name = .geolocation }),
    );
}

test "runCrashtest: expired deadline after load returns TIMEOUT without injecting test-wait.js" {
    try requireWptTestWait();
    const allocator = testing.allocator;

    const wb = try WptBrowser.init(allocator, wpt_root, false);
    defer wb.deinit();

    var result = try wb.runCrashtest(
        "crashtests/expired-deadline-crash.html",
        "data:text/html,<!doctype html><html><body>slow</body></html>",
        0,
    );
    defer result.deinit(allocator);

    try testing.expectEqual(.timeout, result.status);
    try testing.expect(result.crashtest);

    const ctx = wb.browser.current_context orelse return error.NoContext;
    const injected = try ctx.evaluateScriptToString("typeof window.__wptrunner_url", allocator);
    defer allocator.free(injected);
    try testing.expectEqualStrings("undefined", injected);
}

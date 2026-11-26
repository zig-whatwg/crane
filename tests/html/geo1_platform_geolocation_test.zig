//! Platform position source, watchPosition PlatformEvent.position pushes,
//! [[cachedPosition]] (maximumAge / enableHighAccuracy), timeout cancellation,
//! §12 emulation override precedence, and zero-leak teardown tests (lane geo1).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const html = @import("html");
const platform = @import("platform");
const Browser = browser_mod.Browser;

fn browserPlatformOf(browser: *Browser) !*platform.BrowserPlatform {
    const realm = browser.getRealm() orelse return error.NoRealm;
    return html.platform_state.of(realm) orelse error.NoBrowserPlatform;
}

fn evaluateString(browser: *Browser, script: []const u8) ![]u8 {
    const ctx = browser.current_context orelse return error.NoContext;
    return ctx.evaluateScriptToString(script, testing.allocator);
}

test "default platform source with granted geolocation permission yields POSITION_UNAVAILABLE" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "https://example.test/" });

    const bp = try browserPlatformOf(browser);
    platform.adapter.setGeolocationPermission(bp, .granted);

    const setup = try evaluateString(browser,
        \\globalThis.out = [];
        \\navigator.geolocation.getCurrentPosition(
        \\  () => globalThis.out.push('ok'),
        \\  (e) => globalThis.out.push('err:' + e.code)
        \\);
        \\'armed'
    );
    defer testing.allocator.free(setup);
    try testing.expectEqualStrings("armed", setup);

    _ = try browser.runEventLoopBlocking(50);

    const out = try evaluateString(browser, "globalThis.out.join('|')");
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("err:2", out);
}

test "scripted platform position source delivers coordinates and enforces stationary heading === null" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "https://example.test/" });

    const bp = try browserPlatformOf(browser);
    platform.adapter.setGeolocationPermission(bp, .granted);
    platform.adapter.setGeolocationMode(bp, .{ .fixed = .{
        .error_code = .none,
        .latitude = 40.7128,
        .longitude = -74.006,
        .accuracy = 12.5,
        .altitude = 33.0,
        .altitude_accuracy = 4.0,
        .heading = 180.0,
        .speed = 5.5,
    } });

    const setup1 = try evaluateString(browser,
        \\globalThis.p1 = null;
        \\navigator.geolocation.getCurrentPosition(
        \\  (pos) => { globalThis.p1 = pos.coords; },
        \\  () => { globalThis.p1 = 'err'; }
        \\);
        \\'ok'
    );
    defer testing.allocator.free(setup1);
    _ = try browser.runEventLoopBlocking(50);

    const out1 = try evaluateString(browser,
        \\[p1.latitude, p1.longitude, p1.accuracy, p1.altitude, p1.altitudeAccuracy, p1.heading, p1.speed].join('|')
    );
    defer testing.allocator.free(out1);
    try testing.expectEqualStrings("40.7128|-74.006|12.5|33|4|180|5.5", out1);

    // Stationary (speed === 0) must normalize heading to null per W3C Geolocation §10.
    platform.adapter.setGeolocationMode(bp, .{ .fixed = .{
        .error_code = .none,
        .latitude = 40.7128,
        .longitude = -74.006,
        .accuracy = 5.0,
        .heading = 90.0,
        .speed = 0.0,
    } });
    const setup2 = try evaluateString(browser,
        \\globalThis.p2 = null;
        \\navigator.geolocation.getCurrentPosition(
        \\  (pos) => { globalThis.p2 = pos.coords; },
        \\  () => { globalThis.p2 = 'err'; }
        \\);
        \\'ok'
    );
    defer testing.allocator.free(setup2);
    _ = try browser.runEventLoopBlocking(50);

    const out2 = try evaluateString(browser, "String(p2.heading) + '|' + String(p2.speed)");
    defer testing.allocator.free(out2);
    try testing.expectEqualStrings("null|0", out2);
}

test "watchPosition receives PlatformEvent.position pushes and clearWatch releases platform watch" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "https://example.test/" });

    const bp = try browserPlatformOf(browser);
    platform.adapter.setGeolocationPermission(bp, .granted);
    platform.adapter.setGeolocationMode(bp, .{ .fixed = .{
        .error_code = .none,
        .latitude = 1.0,
        .longitude = 2.0,
        .accuracy = 10.0,
    } });

    const setup = try evaluateString(browser,
        \\globalThis.watchLog = [];
        \\globalThis.wid = navigator.geolocation.watchPosition(
        \\  (pos) => globalThis.watchLog.push(pos.coords.latitude + ',' + pos.coords.longitude),
        \\  (err) => globalThis.watchLog.push('err:' + err.code)
        \\);
        \\String(globalThis.wid > 0)
    );
    defer testing.allocator.free(setup);
    try testing.expectEqualStrings("true", setup);

    _ = try browser.runEventLoopBlocking(50);
    try testing.expectEqual(@as(usize, 1), platform.adapter.activeGeolocationWatchCount(bp));

    // Push a live platform position update via PlatformEvent.position.
    const pushed = platform.adapter.pushGeolocationWatch(bp, .{
        .error_code = .none,
        .latitude = 3.5,
        .longitude = 4.5,
        .accuracy = 8.0,
    });
    try testing.expectEqual(@as(usize, 1), pushed);
    _ = try browser.runEventLoopBlocking(50);

    const log = try evaluateString(browser, "globalThis.watchLog.join('|')");
    defer testing.allocator.free(log);
    try testing.expectEqualStrings("1,2|3.5,4.5", log);

    // clearWatch releases the underlying platform watch.
    const cleared = try evaluateString(browser, "navigator.geolocation.clearWatch(globalThis.wid); 'cleared'");
    defer testing.allocator.free(cleared);
    try testing.expectEqual(@as(usize, 0), platform.adapter.activeGeolocationWatchCount(bp));
}

test "maximumAge reuses [[cachedPosition]] and enableHighAccuracy mismatch bypasses cache" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "https://example.test/" });

    const bp = try browserPlatformOf(browser);
    platform.adapter.setGeolocationPermission(bp, .granted);
    platform.adapter.setGeolocationMode(bp, .{ .fixed = .{
        .error_code = .none,
        .latitude = 10.0,
        .longitude = 20.0,
        .accuracy = 50.0,
    } });

    // First call populates [[cachedPosition]] with enableHighAccuracy: false.
    const s1 = try evaluateString(browser,
        \\globalThis.cLog = [];
        \\navigator.geolocation.getCurrentPosition(
        \\  (p) => globalThis.cLog.push(p.coords.latitude),
        \\  (e) => globalThis.cLog.push('e:' + e.code),
        \\  { enableHighAccuracy: false }
        \\);
        \\'1'
    );
    defer testing.allocator.free(s1);
    _ = try browser.runEventLoopBlocking(50);
    try testing.expectEqual(@as(usize, 1), platform.adapter.geolocationRequestCalls(bp));

    // Change platform position, then call with maximumAge: 60000 and enableHighAccuracy: false.
    // Must reuse cached (10.0) without calling platform.currentPosition again.
    platform.adapter.setGeolocationMode(bp, .{
        .fixed = .{
            .error_code = .none,
            .latitude = 99.0 - 10.0, // 89.0
            .longitude = 30.0,
            .accuracy = 5.0,
        },
    });
    const s2 = try evaluateString(browser,
        \\navigator.geolocation.getCurrentPosition(
        \\  (p) => globalThis.cLog.push(p.coords.latitude),
        \\  (e) => globalThis.cLog.push('e:' + e.code),
        \\  { maximumAge: 60000, enableHighAccuracy: false }
        \\);
        \\'2'
    );
    defer testing.allocator.free(s2);
    _ = try browser.runEventLoopBlocking(50);
    try testing.expectEqual(@as(usize, 1), platform.adapter.geolocationRequestCalls(bp));

    // Request with enableHighAccuracy: true must NOT reuse low-accuracy cache.
    const s3 = try evaluateString(browser,
        \\navigator.geolocation.getCurrentPosition(
        \\  (p) => globalThis.cLog.push(p.coords.latitude),
        \\  (e) => globalThis.cLog.push('e:' + e.code),
        \\  { maximumAge: 60000, enableHighAccuracy: true }
        \\);
        \\'3'
    );
    defer testing.allocator.free(s3);
    _ = try browser.runEventLoopBlocking(50);
    try testing.expectEqual(@as(usize, 2), platform.adapter.geolocationRequestCalls(bp));

    const out = try evaluateString(browser, "globalThis.cLog.join('|')");
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("10|10|89", out);
}

test "slow platform source expires with TIMEOUT and cancels pending platform request" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "https://example.test/" });

    const bp = try browserPlatformOf(browser);
    platform.adapter.setGeolocationPermission(bp, .granted);
    platform.adapter.setGeolocationMode(bp, .pending);

    const setup = try evaluateString(browser,
        \\globalThis.tOut = [];
        \\navigator.geolocation.getCurrentPosition(
        \\  () => globalThis.tOut.push('ok'),
        \\  (e) => globalThis.tOut.push('err:' + e.code),
        \\  { timeout: 25 }
        \\);
        \\'armed'
    );
    defer testing.allocator.free(setup);

    _ = try browser.runEventLoopBlocking(120);

    const out = try evaluateString(browser, "globalThis.tOut.join('|')");
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("err:3", out);
    try testing.expectEqual(@as(usize, 0), platform.adapter.pendingGeolocationRequestCount(bp));
}

test "emulation override wins over platform source and clear falls back to platform source" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "https://example.test/" });

    const bp = try browserPlatformOf(browser);
    platform.adapter.setGeolocationPermission(bp, .granted);
    platform.adapter.setGeolocationMode(bp, .{ .fixed = .{
        .error_code = .none,
        .latitude = 10.0,
        .longitude = 20.0,
        .accuracy = 15.0,
    } });

    const bc = browser.current_context.?.browsing_context.?;

    // Set §12 emulation override (same path CDP Emulation.setGeolocationOverride calls).
    html.geolocation.setEmulatedPositionData(bc, 42, .{ .coordinates = .{
        .latitude = 52.5,
        .longitude = 13.4,
        .accuracy = 0.0,
    } });

    const s1 = try evaluateString(browser,
        \\globalThis.ovLog = [];
        \\globalThis.ovWatch = navigator.geolocation.watchPosition(
        \\  (p) => globalThis.ovLog.push('w:' + p.coords.latitude + ',' + p.coords.longitude),
        \\  (e) => globalThis.ovLog.push('we:' + e.code)
        \\);
        \\'1'
    );
    defer testing.allocator.free(s1);
    _ = try browser.runEventLoopBlocking(50);

    // Updating the override notifies active watches; setting position_unavailable delivers code 2.
    html.geolocation.setEmulatedPositionData(bc, 42, .{ .coordinates = .{
        .latitude = 37.7749,
        .longitude = -122.4194,
        .accuracy = 0.0,
    } });
    _ = try browser.runEventLoopBlocking(50);

    html.geolocation.setEmulatedPositionData(bc, 42, .position_unavailable);
    _ = try browser.runEventLoopBlocking(50);

    // Clear override -> next getCurrentPosition falls back to platform source (10, 20).
    html.geolocation.setEmulatedPositionData(bc, 0, null);
    const s2 = try evaluateString(browser,
        \\navigator.geolocation.clearWatch(globalThis.ovWatch);
        \\navigator.geolocation.getCurrentPosition(
        \\  (p) => globalThis.ovLog.push('p:' + p.coords.latitude + ',' + p.coords.longitude),
        \\  (e) => globalThis.ovLog.push('pe:' + e.code)
        \\);
        \\'2'
    );
    defer testing.allocator.free(s2);
    _ = try browser.runEventLoopBlocking(50);

    const out = try evaluateString(browser, "globalThis.ovLog.join('|')");
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("w:52.5,13.4|w:37.7749,-122.4194|we:2|p:10,20", out);
}

test "Browser teardown with pending platform requests and active watches leaks nothing" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "https://example.test/" });

    const bp = try browserPlatformOf(browser);
    platform.adapter.setGeolocationPermission(bp, .granted);
    platform.adapter.setGeolocationMode(bp, .pending);

    const setup = try evaluateString(browser,
        \\navigator.geolocation.getCurrentPosition(() => {}, () => {}, { timeout: 60000 });
        \\navigator.geolocation.watchPosition(() => {}, () => {}, { timeout: 60000 });
        \\navigator.geolocation.watchPosition(() => {}, () => {});
        \\'active'
    );
    defer testing.allocator.free(setup);
    try testing.expectEqualStrings("active", setup);

    // Let StartTasks run so requests are live in both Registry and testing GeolocationSource.
    _ = try browser.runEventLoopBlocking(20);
    try testing.expect(platform.adapter.activeGeolocationWatchCount(bp) >= 2);
    try testing.expect(platform.adapter.pendingGeolocationRequestCount(bp) >= 3);
    // defer browser.deinit() cleans up all pending replies, timers, callbacks, and watches.
}

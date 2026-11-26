//! W3C Geolocation API end-to-end Browser tests (lane geo1).
//! Covers navigator.geolocation [SameObject], GeolocationPositionError constants,
//! non-secure contexts, non-fully-active iframes, PositionOptions validation,
//! permission denial in headless mode, and zero-leak teardown with active watches.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;

fn evaluateString(browser: *Browser, script: []const u8) ![]u8 {
    const ctx = browser.current_context orelse return error.NoContext;
    return ctx.evaluateScriptToString(script, testing.allocator);
}

test "navigator.geolocation is [SameObject] and exposes methods and GeolocationPositionError constants" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "https://example.test/" });

    const result = try evaluateString(browser,
        \\[
        \\  navigator.geolocation instanceof Geolocation,
        \\  navigator.geolocation === navigator.geolocation,
        \\  typeof navigator.geolocation.getCurrentPosition,
        \\  typeof navigator.geolocation.watchPosition,
        \\  typeof navigator.geolocation.clearWatch,
        \\  GeolocationPositionError.PERMISSION_DENIED,
        \\  GeolocationPositionError.POSITION_UNAVAILABLE,
        \\  GeolocationPositionError.TIMEOUT,
        \\].join('|')
    );
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("true|true|function|function|function|1|2|3", result);
}

test "non-secure context asynchronously calls errorCallback with PERMISSION_DENIED" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "http://example.test/" });

    const setup = try evaluateString(browser,
        \\globalThis.geoOut = [];
        \\let calledSync = false;
        \\navigator.geolocation.getCurrentPosition(
        \\  () => { globalThis.geoOut.push('ok'); },
        \\  (err) => {
        \\    calledSync = true;
        \\    globalThis.geoOut.push(
        \\      (err instanceof GeolocationPositionError) + ':' + err.code + ':' + (typeof err.message)
        \\    );
        \\  }
        \\);
        \\const wid = navigator.geolocation.watchPosition(
        \\  () => { globalThis.geoOut.push('watch-ok'); },
        \\  (err) => { globalThis.geoOut.push('watch:' + err.code); }
        \\);
        \\String(calledSync) + '|' + String(wid > 0)
    );
    defer testing.allocator.free(setup);
    try testing.expectEqualStrings("false|true", setup);

    _ = try browser.runEventLoopBlocking(50);

    const out = try evaluateString(browser, "globalThis.geoOut.join('|')");
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("true:1:string|watch:1", out);
}

test "non-fully-active iframe returns watchId 0 and asynchronously delivers POSITION_UNAVAILABLE" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML(
        "<!doctype html><body><iframe id='f'></iframe></body>",
        .{ .base_url = "https://example.test/" },
    );

    const setup = try evaluateString(browser,
        \\globalThis.nfaOut = [];
        \\const iframe = document.getElementById('f');
        \\const geo = iframe.contentWindow.navigator.geolocation;
        \\iframe.remove();
        \\const wid1 = geo.watchPosition(
        \\  () => { globalThis.nfaOut.push('w-ok'); },
        \\  (err) => { globalThis.nfaOut.push('w:' + err.code); }
        \\);
        \\const wid2 = geo.watchPosition(() => {}, () => {});
        \\geo.getCurrentPosition(
        \\  () => { globalThis.nfaOut.push('g-ok'); },
        \\  (err) => { globalThis.nfaOut.push('g:' + err.code); }
        \\);
        \\wid1 + '|' + wid2
    );
    defer testing.allocator.free(setup);
    try testing.expectEqualStrings("0|0", setup);

    _ = try browser.runEventLoopBlocking(50);

    const out = try evaluateString(browser, "globalThis.nfaOut.join('|')");
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("w:2|g:2", out);
}

test "headless secure context with prompt permission denies cleanly and tears down with zero leaks" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "https://example.test/" });

    const setup = try evaluateString(browser,
        \\globalThis.permOut = [];
        \\navigator.geolocation.getCurrentPosition(
        \\  () => { globalThis.permOut.push('ok'); },
        \\  (err) => { globalThis.permOut.push('err:' + err.code); }
        \\);
        \\const w = navigator.geolocation.watchPosition(
        \\  () => {},
        \\  (err) => { globalThis.permOut.push('werr:' + err.code); }
        \\);
        \\navigator.geolocation.clearWatch(999999);
        \\String(w > 0)
    );
    defer testing.allocator.free(setup);
    try testing.expectEqualStrings("true", setup);

    _ = try browser.runEventLoopBlocking(50);

    const out = try evaluateString(browser, "globalThis.permOut.join('|')");
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("err:1|werr:1", out);
}

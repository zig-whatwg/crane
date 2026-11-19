//! WebIDL 3.7: "For every interface that is exposed in a given realm ... a
//! corresponding property exists on the realm's global object" - and for an
//! interface that is not, none does. "Exposed" step 1: "If construct's
//! exposure set is not *, and realm.[[GlobalObject]] does not implement an
//! interface that is in construct's exposure set, then return false." A
//! Window implements Window, so an interface exposed only to workers,
//! service workers or worklets has no interface object on it.
//!
//! Chrome, Firefox and Safari expose none of these on Window (wpt.fyi
//! 2358bd4835: html/dom/idlharness.https.html "WorkerGlobalScope interface:
//! existence and properties of interface object", service-workers/
//! idlharness.https.any.html "FetchEvent interface: ...", FileAPI/
//! idlharness.html "FileReaderSync interface: ...": PASS in all three).
const std = @import("std");
const browser_mod = @import("browser");
const testing = std.testing;

fn exercise() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const present = try page.evaluateScriptToString(
        \\[
        \\  'WorkerGlobalScope', 'DedicatedWorkerGlobalScope', 'SharedWorkerGlobalScope',
        \\  'ServiceWorkerGlobalScope', 'WorkerNavigator', 'WorkerLocation', 'FileReaderSync',
        \\  'Clients', 'Client', 'WindowClient', 'ExtendableEvent', 'FetchEvent', 'InstallEvent',
        \\  'ExtendableMessageEvent', 'ExtendableCookieChangeEvent', 'WorkletGlobalScope',
        \\  'AudioWorkletGlobalScope', 'PaintWorkletGlobalScope',
        \\].filter((name) => name in globalThis).join()
    , testing.allocator);
    defer testing.allocator.free(present);
    try testing.expectEqualStrings("", present);
    // What a Window does expose is still there.
    const exposed = try page.evaluateScriptToString(
        \\['Worker', 'SharedWorker', 'Document', 'ServiceWorker', 'FileReader', 'EventTarget', 'ReadableStream']
        \\  .filter((name) => typeof globalThis[name] !== 'function').join()
    , testing.allocator);
    defer testing.allocator.free(exposed);
    try testing.expectEqualStrings("", exposed);
}

test "a Window realm has no interface object for an interface it does not expose" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

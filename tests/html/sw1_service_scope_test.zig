//! importScripts() dispatches to Service Workers' fetch hook only in a
//! service worker's realm (worker_host.fetchClassicWorkerImportedScript's
//! first statement, `serviceScopeOf`): every other realm answers null from
//! its realm record's kind, before anything else is read, so a window's and
//! a dedicated or shared worker's importScripts() take the path they always
//! took. (The importScripts() behaviour of dedicated and shared workers is
//! pinned end to end by tests/wpt/crane/sw1-import-scripts-workers.html.)

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const html = @import("html");

test "a window realm is no service worker's: serviceScopeOf answers null" {
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    const realm = page.realm orelse return error.NoPageRealm;
    try testing.expect(html.worker_host.serviceScopeOf(realm) == null);
}

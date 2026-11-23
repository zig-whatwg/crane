//! HTML 8.9.1.4 NavigatorLanguage: navigator.languages is "a frozen array of
//! valid BCP 47 language tags ... ordered by preference with the most
//! preferred language first" - the most preferred being navigator.language -
//! and "the same object must be returned until the user agent needs to
//! return different values". All three browsers (wpt.fyi 2358bd4835,
//! html/dom/idlharness: "window.navigator must inherit property languages
//! with the proper type").
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const result = try browser.evaluateScript(
        \\(() => {
        \\  const languages = navigator.languages;
        \\  return Array.isArray(languages) && Object.isFrozen(languages) && languages.length >= 1 &&
        \\    languages[0] === navigator.language && navigator.languages === languages;
        \\})()
    );
    defer result.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    try std.testing.expect(engine.toBoolean(realm, result.borrow()));
}

test "navigator.languages is one frozen array, navigator.language first" {
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

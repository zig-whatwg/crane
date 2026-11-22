//! The console takes the Chrome switches of Playwright's own launch
//! (`executablePath`, decision D8's pipe; lane cdpr): playwright-core
//! chromium.ts _innerDefaultArgs for a launch that is not persistent passes
//! --no-startup-window - the browser starts with no window, the client makes
//! its tabs - beside --remote-debugging-pipe and --user-data-dir.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const repl = @import("repl");

test "Playwright's launch: --no-startup-window with the pipe and a profile directory" {
    var bad: []const u8 = "";
    const options = try repl.parseOptions(&.{
        "--disable-field-trial-config",
        "--disable-background-networking",
        "--enable-automation",
        "--headless",
        "--hide-scrollbars",
        "--mute-audio",
        "--no-startup-window",
        "--user-data-dir=/tmp/playwright_chromiumdev_profile-x",
        "--remote-debugging-pipe",
    }, &bad);
    try testing.expect(options.remoteDebugging());
    try testing.expect(options.remote_debugging_pipe);
    try testing.expect(options.no_startup_window);
    try testing.expectEqualStrings("/tmp/playwright_chromiumdev_profile-x", options.user_data_dir.?);
}

test "a window by default: Puppeteer's launch has no --no-startup-window" {
    var bad: []const u8 = "";
    const options = try repl.parseOptions(&.{ "--remote-debugging-port=0", "about:blank" }, &bad);
    try testing.expect(!options.no_startup_window);
}

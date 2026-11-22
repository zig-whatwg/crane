//! The console takes Chrome's switches (decision D2; lane cdpt): what
//! Puppeteer's launch passes (PUPPETEER_EXECUTABLE_PATH) and chromedriver's
//! (goog:chromeOptions.args) - remote debugging on a port or the pipe, the
//! allowed origins, the profile directory, --headless - and, with remote
//! debugging asked for, every other Chrome switch accepted and ignored.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const repl = @import("repl");

test "Puppeteer's command line: the switches the console needs, the rest ignored, the URL kept" {
    var bad: []const u8 = "";
    // puppeteer-core 25.11.0 ChromeLauncher's defaults, abridged.
    const options = try repl.parseOptions(&.{
        "--allow-pre-commit-input",
        "--disable-background-networking",
        "--disable-features=Translate,AcceptCHFrame",
        "--enable-automation",
        "--headless=new",
        "--hide-scrollbars",
        "--mute-audio",
        "--no-sandbox",
        "about:blank",
        "--remote-debugging-port=0",
        "--user-data-dir=/tmp/puppeteer_dev_profile-x",
    }, &bad);
    try testing.expect(options.remoteDebugging());
    try testing.expectEqual(@as(?u16, 0), options.remote_debugging_port);
    try testing.expect(options.headless);
    try testing.expectEqualStrings("/tmp/puppeteer_dev_profile-x", options.user_data_dir.?);
    try testing.expectEqualStrings("about:blank", options.url);
}

test "the pipe, the allowed origins, and a port that is no number" {
    var bad: []const u8 = "";
    const pipe = try repl.parseOptions(&.{ "--remote-debugging-pipe", "--remote-allow-origins=http://localhost:3000,*" }, &bad);
    try testing.expect(pipe.remote_debugging_pipe);
    try testing.expect(pipe.remote_debugging_port == null);
    try testing.expectEqualStrings("http://localhost:3000,*", pipe.remote_allow_origins.?);
    try testing.expectError(error.InvalidPort, repl.parseOptions(&.{"--remote-debugging-port=nine"}, &bad));
}

test "without remote debugging an unknown switch is still refused" {
    var bad: []const u8 = "";
    try testing.expectError(error.UnknownOption, repl.parseOptions(&.{"--no-sandbox"}, &bad));
    try testing.expectEqualStrings("--no-sandbox", bad);
}

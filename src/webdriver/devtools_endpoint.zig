//! A WebDriver session's Chrome DevTools Protocol endpoint: New Session's
//! `se:cdp` capability (tmp/plans/cdp-part1-design.md 2.1, entry point 2;
//! decision D2).
//!
//! Selenium 4's Grid and chromedriver hand a client the session's CDP
//! WebSocket URL as the `se:cdp` capability, and chromedriver its
//! `goog:chromeOptions.debuggerAddress` (host:port); Playwright's
//! `SELENIUM_REMOTE_URL` route connects over CDP to the first, or the second
//! when the first is absent (playwright-core chromium.ts
//! launchWithSeleniumHub). The session and the CDP connection drive the same
//! Browser - the session's, on its BrowserHost thread. Built without CDP
//! (-Dcdp=false), New Session answers no `se:cdp`, and asking for one is
//! "built without CDP support".

const std = @import("std");
const devtools = @import("devtools");
const browser_mod = @import("browser");

pub const Endpoint = struct {
    server: if (devtools.enabled) ?*devtools.Server else void = if (devtools.enabled) null else {},

    /// Serve CDP for `host`'s Browser on a free loopback port. `allocator`
    /// must be thread-safe.
    pub fn start(self: *Endpoint, allocator: std.mem.Allocator, host: *browser_mod.BrowserHost) !void {
        if (comptime !devtools.enabled) return error.CdpNotBuilt;
        self.server = try devtools.Server.start(allocator, .{
            .port = 0,
            .default_host = host,
        });
    }

    /// `ws://127.0.0.1:<port>/devtools/browser/<id>`, into `buffer`; null
    /// when the endpoint did not start.
    pub fn url(self: *const Endpoint, buffer: []u8) ?[]const u8 {
        if (comptime !devtools.enabled) return null;
        const server = self.server orelse return null;
        return server.browserUrl(buffer);
    }

    /// `127.0.0.1:<port>` (chromedriver's debuggerAddress), into `buffer`.
    pub fn debuggerAddress(self: *const Endpoint, buffer: []u8) ?[]const u8 {
        if (comptime !devtools.enabled) return null;
        const server = self.server orelse return null;
        return std.fmt.bufPrint(buffer, "127.0.0.1:{d}", .{server.port}) catch null;
    }

    /// Stop serving (before the session's Browser stops).
    pub fn stop(self: *Endpoint) void {
        if (comptime !devtools.enabled) return;
        if (self.server) |server| server.stop();
        self.server = null;
    }
};

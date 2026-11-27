//! Crane Public High-Level Zig API
//!
//! Downstream Zig projects import this module via `crane.module("crane")`:
//!
//! ```zig
//! const crane = @import("crane");
//!
//! var rt = try crane.initRuntime(.{});
//! defer rt.deinit();
//!
//! var b = try crane.Browser.create(allocator, .{});
//! defer b.deinit();
//!
//! try b.navigate("data:text/html,<title>Hello</title>");
//! var res = try b.eval("\"ran \" + (6 * 7)");
//! defer res.deinit();
//! ```
//!
//! Every operation drives Crane through its real browser paths (`browser.Process`,
//! `browser.BrowserHost`, `devtools.Server`, and `devtools.mcp.http.HttpServer`).
//! Advanced callers can also access the re-exported `browser`, `capi`, `devtools`,
//! `engine`, and `platform` modules directly.

const std = @import("std");

pub const browser = @import("browser");
pub const capi = browser.capi;
pub const devtools = @import("devtools");
pub const engine = @import("engine");
pub const platform = @import("platform");

/// Whether CDP and built-in MCP servers were compiled into this build (`-Dcdp=true`).
pub const cdp_enabled: bool = devtools.enabled;

pub const BrowserConfig = browser.BrowserConfig;
pub const TabId = browser.Browser.TabId;
pub const Readiness = browser.BrowserHost.Readiness;
pub const NavigateOptions = browser.BrowserHost.NavigateOptions;
pub const EvaluateOptions = browser.Browser.EvaluateOptions;

/// Default timeout for `Browser.eval`, in milliseconds.
pub const default_eval_timeout_ms: u64 = 30_000;

pub const RuntimeOptions = browser.process.Options;

/// Process-wide Crane runtime handle returned by `initRuntime`.
/// Call `deinit` once after all `Browser` instances have been destroyed.
pub const Runtime = struct {
    process: browser.Process,

    pub fn deinit(self: *Runtime) void {
        self.process.deinit();
    }

    /// Whether agents are restored from a prebuilt engine heap snapshot.
    pub fn hasSnapshot(_: *const Runtime) bool {
        return browser.Process.hasSnapshot();
    }
};

/// Initialize the Crane process runtime once, before creating any `Browser` or
/// spawning threads that will run Crane.
///
/// Attaches the main thread's alternate signal stack, initializes engine
/// per-process state before thread creation, starts the platform and JavaScript
/// engine, initializes networking, and installs DOM hooks.
pub fn initRuntime(options: RuntimeOptions) browser.process.Error!Runtime {
    _ = platform.attachSignalStack();
    engine.initializeBeforeThreadCreation();
    return .{
        .process = try browser.Process.init(options),
    };
}

/// Result of evaluating JavaScript in a `Browser` tab (`Browser.eval`).
pub const EvalResult = struct {
    allocator: std.mem.Allocator,
    kind: @FieldType(browser.BrowserHost.EvaluateResult, "kind"),
    /// WebDriver BiDi `script.RemoteValue` JSON, or exception details JSON when
    /// `isException()` is true.
    json: []u8,

    pub fn deinit(self: *EvalResult) void {
        self.allocator.free(self.json);
    }

    /// True if evaluation threw an uncaught exception or rejected an awaited promise.
    pub fn isException(self: *const EvalResult) bool {
        return self.kind == .exception;
    }

    /// Decode a `"string"` BiDi RemoteValue into an owned UTF-8 slice, or return
    /// `null` if the evaluation threw or produced a non-string value.
    pub fn stringValue(self: *const EvalResult, allocator: std.mem.Allocator) !?[]u8 {
        if (self.kind != .success) return null;
        var parsed = std.json.parseFromSlice(std.json.Value, allocator, self.json, .{}) catch return null;
        defer parsed.deinit();
        if (parsed.value != .object) return null;
        const kind = parsed.value.object.get("type") orelse return null;
        if (kind != .string or !std.mem.eql(u8, kind.string, "string")) return null;
        const val = parsed.value.object.get("value") orelse return null;
        if (val != .string) return null;
        return try allocator.dupe(u8, val.string);
    }
};

pub const CdpOptions = struct {
    /// TCP port to listen on (`0` lets the OS pick an ephemeral free port).
    port: u16 = 0,
    /// Allowed WebSocket `Origin` headers (e.g. `&.{ "*" }`).
    allowed_origins: []const []const u8 = &.{},
    /// Directory where `DevToolsActivePort` is written (`null`: nowhere).
    user_data_dir: ?[]const u8 = null,
    /// User-Agent reported by `/json/version`.
    user_agent: []const u8 = "",
};

/// Connection details returned by `Browser.startCdp`.
pub const CdpInfo = struct {
    port: u16,
    url_buf: [160]u8 = undefined,
    url_len: usize = 0,

    /// Browser WebSocket URL (`ws://127.0.0.1:<port>/devtools/browser/<id>`).
    pub fn browserUrl(self: *const CdpInfo) []const u8 {
        return self.url_buf[0..self.url_len];
    }
};

pub const McpOptions = if (cdp_enabled) devtools.mcp.http.Options else struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 0,
};

/// Connection details returned by `Browser.startMcp`.
/// `bearer_token` and `cert_fingerprint` are borrowed from the running MCP
/// server and stay valid until `stopMcp` or `deinit`.
pub const McpInfo = struct {
    port: u16,
    tls: bool,
    bearer_token: []const u8,
    cert_fingerprint: ?[]const u8,
};

const CdpServerPtr = if (cdp_enabled) *devtools.Server else *anyopaque;
const McpServerPtr = if (cdp_enabled) *devtools.mcp.http.HttpServer else *anyopaque;

/// An isolated headless Crane browser running on its own event-loop thread.
pub const Browser = struct {
    allocator: std.mem.Allocator,
    host: *browser.BrowserHost,
    tab: TabId,
    cdp_server: ?CdpServerPtr = null,
    mcp_server: ?McpServerPtr = null,
    owns_cdp_for_mcp: bool = false,

    /// Start a new isolated browser instance.
    /// `allocator` must be thread-safe (e.g. `std.heap.c_allocator`,
    /// `std.heap.smp_allocator`, or `std.testing.allocator`).
    pub fn create(allocator: std.mem.Allocator, config: BrowserConfig) !Browser {
        const bh = try browser.BrowserHost.start(allocator, config);
        errdefer bh.stop();

        const tab = try resolveInitialTab(bh);
        return .{
            .allocator = allocator,
            .host = bh,
            .tab = tab,
        };
    }

    /// Stop any active MCP/CDP servers, close all tabs, join the browser
    /// thread, and release all resources.
    pub fn deinit(self: *Browser) void {
        self.stopMcp();
        self.stopCdp();
        self.host.stop();
    }

    /// Navigate the active tab to `target_url` as browser UI and wait until
    /// the document finishes loading (`Readiness.complete`).
    pub fn navigate(self: *Browser, target_url: []const u8) !void {
        const final_url = try self.host.navigate(self.allocator, self.tab, target_url, .{ .wait = .complete });
        self.allocator.free(final_url);
    }

    /// Navigate the active tab with explicit readiness/timeout options and
    /// return the active document's final URL (caller owns the returned slice).
    pub fn navigateWithOptions(self: *Browser, target_url: []const u8, options: NavigateOptions) ![]u8 {
        return self.host.navigate(self.allocator, self.tab, target_url, options);
    }

    /// Evaluate JavaScript in the active tab with default options and timeout.
    /// Caller must call `result.deinit()`.
    pub fn eval(self: *Browser, script: []const u8) !EvalResult {
        return self.evalWithOptions(script, .{}, default_eval_timeout_ms);
    }

    /// Evaluate JavaScript in the active tab with explicit options and timeout.
    /// Caller must call `result.deinit()`.
    pub fn evalWithOptions(self: *Browser, script: []const u8, options: EvaluateOptions, timeout_ms: u64) !EvalResult {
        const res = try self.host.evaluate(self.allocator, self.tab, script, options, timeout_ms);
        return .{
            .allocator = self.allocator,
            .kind = res.kind,
            .json = res.json,
        };
    }

    /// Return the active document's `document.title` as an owned UTF-8 slice
    /// (free with `self.allocator.free(...)`).
    pub fn title(self: *Browser) ![]u8 {
        const tabs = try self.host.listTabs(self.allocator);
        defer browser.Browser.freeTabs(self.allocator, tabs);
        for (tabs) |info| {
            if (info.id == self.tab) {
                return try self.allocator.dupe(u8, info.title);
            }
        }
        return error.NoSuchTab;
    }

    /// Return the active document's URL as an owned UTF-8 slice
    /// (free with `self.allocator.free(...)`).
    pub fn url(self: *Browser) ![]u8 {
        return self.host.tabUrl(self.allocator, self.tab);
    }

    /// Access the underlying `browser.BrowserHost` for multi-tab management,
    /// event listeners, dialog handling, and advanced host operations.
    pub fn browserHost(self: *Browser) *browser.BrowserHost {
        return self.host;
    }

    /// Start the Chrome DevTools Protocol remote-debugging server on this browser.
    /// Returns `error.CdpDisabled` when built with `-Dcdp=false`.
    pub fn startCdp(self: *Browser, options: CdpOptions) !CdpInfo {
        if (comptime !cdp_enabled) {
            return error.CdpDisabled;
        } else {
            if (self.cdp_server != null) return error.AlreadyStarted;
            const srv = try devtools.Server.start(self.allocator, .{
                .port = options.port,
                .allowed_origins = options.allowed_origins,
                .user_data_dir = options.user_data_dir,
                .user_agent = options.user_agent,
                .default_host = self.host,
            });
            self.cdp_server = srv;
            self.owns_cdp_for_mcp = false;

            var info: CdpInfo = .{ .port = srv.port };
            const ws_url = srv.browserUrl(&info.url_buf);
            info.url_len = ws_url.len;
            return info;
        }
    }

    /// Stop the CDP server (and any MCP server attached to it). Idempotent.
    pub fn stopCdp(self: *Browser) void {
        if (comptime cdp_enabled) {
            if (self.mcp_server != null) self.stopMcp();
            if (self.cdp_server) |srv| {
                srv.stop();
                self.cdp_server = null;
                self.owns_cdp_for_mcp = false;
            }
        }
    }

    /// Start the built-in Streamable HTTP MCP server on this browser.
    /// Returns `error.CdpDisabled` when built with `-Dcdp=false`.
    pub fn startMcp(self: *Browser, options: McpOptions) !McpInfo {
        if (comptime !cdp_enabled) {
            return error.CdpDisabled;
        } else {
            if (self.mcp_server != null) return error.AlreadyStarted;

            var started_internal_cdp = false;
            const dt_server = self.cdp_server orelse blk: {
                const srv = try devtools.Server.start(self.allocator, .{
                    .default_host = self.host,
                });
                self.cdp_server = srv;
                self.owns_cdp_for_mcp = true;
                started_internal_cdp = true;
                break :blk srv;
            };
            errdefer if (started_internal_cdp) {
                dt_server.stop();
                self.cdp_server = null;
                self.owns_cdp_for_mcp = false;
            };

            const http_srv = try devtools.mcp.http.HttpServer.start(self.allocator, dt_server, options);
            self.mcp_server = http_srv;
            return .{
                .port = http_srv.boundPort(),
                .tls = http_srv.isTls(),
                .bearer_token = http_srv.bearerToken(),
                .cert_fingerprint = http_srv.certFingerprint(),
            };
        }
    }

    /// Stop the Streamable HTTP MCP server (and its internal CDP bridge if
    /// `startMcp` started it). Idempotent.
    pub fn stopMcp(self: *Browser) void {
        if (comptime cdp_enabled) {
            if (self.mcp_server) |http_srv| {
                http_srv.stop();
                self.mcp_server = null;
            }
            if (self.owns_cdp_for_mcp) {
                if (self.cdp_server) |srv| {
                    srv.stop();
                    self.cdp_server = null;
                }
                self.owns_cdp_for_mcp = false;
            }
        }
    }
};

fn resolveInitialTab(bh: *browser.BrowserHost) !TabId {
    const Query = struct {
        tab: ?TabId = null,
        fn run(ctx: ?*anyopaque, b: *browser.Browser) void {
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            self.tab = b.activeTab() orelse b.hostTraversableId();
        }
    };
    var q: Query = .{};
    try bh.call(&q, Query.run);
    return q.tab orelse try bh.createTab(.{});
}

test "crane.Browser navigates, reads title and url, and evaluates JavaScript" {
    const allocator = std.testing.allocator;
    var b = try Browser.create(allocator, .{});
    defer b.deinit();

    try b.navigate("data:text/html,<title>Crane API</title><script>globalThis.answer = 6 * 7;</script>");

    const page_title = try b.title();
    defer allocator.free(page_title);
    try std.testing.expectEqualStrings("Crane API", page_title);

    const page_url = try b.url();
    defer allocator.free(page_url);
    try std.testing.expect(std.mem.startsWith(u8, page_url, "data:text/html,"));

    var res = try b.eval("\"ran \" + globalThis.answer");
    defer res.deinit();
    try std.testing.expect(!res.isException());

    const text = (try res.stringValue(allocator)) orelse return error.ExpectedStringResult;
    defer allocator.free(text);
    try std.testing.expectEqualStrings("ran 42", text);

    var thrown = try b.eval("throw new Error('boom')");
    defer thrown.deinit();
    try std.testing.expect(thrown.isException());
}

test "crane.Browser starts and stops CDP and MCP servers cleanly when CDP is enabled" {
    const allocator = std.testing.allocator;
    var b = try Browser.create(allocator, .{});
    defer b.deinit();

    if (comptime cdp_enabled) {
        const cdp = try b.startCdp(.{ .port = 0 });
        try std.testing.expect(cdp.port > 0);
        try std.testing.expect(std.mem.startsWith(u8, cdp.browserUrl(), "ws://127.0.0.1:"));

        const mcp = try b.startMcp(.{ .port = 0 });
        try std.testing.expect(mcp.port > 0);
        try std.testing.expect(!mcp.tls);
        try std.testing.expectEqual(@as(usize, 64), mcp.bearer_token.len);
        try std.testing.expect(mcp.cert_fingerprint == null);

        b.stopMcp();
        b.stopCdp();
    } else {
        try std.testing.expectError(error.CdpDisabled, b.startCdp(.{ .port = 0 }));
        try std.testing.expectError(error.CdpDisabled, b.startMcp(.{ .port = 0 }));
    }
}

test "crane re-exports public modules and initRuntime signature" {
    _ = browser;
    _ = capi;
    _ = devtools;
    _ = &initRuntime;
    _ = &Runtime.deinit;
}

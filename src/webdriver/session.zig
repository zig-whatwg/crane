//! WebDriver Session Management
//!
//! Each WebDriver session is a Browser on a thread of its own
//! (browser.BrowserHost; the instances design's batch B6, lane cdph): its
//! event loop runs for the session's life, and every command reaches it as
//! a command posted to that loop - so a CDP connection to the same Browser
//! (the session's `se:cdp`) drives it beside WebDriver. The session's window
//! handles are its Browser's tab ids (WebDriver BiDi: a window handle is the
//! top-level browsing context's navigable id). Sessions share nothing.

const std = @import("std");
const Allocator = std.mem.Allocator;
const protocol = @import("protocol.zig");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const BrowserHost = browser_mod.BrowserHost;

/// WebDriver Session
///
/// Drives one Browser, on its own thread, for WebDriver commands.
pub const Session = struct {
    allocator: Allocator,
    id: []const u8,
    host: *BrowserHost,
    /// The session's current top-level browsing context (W3C WebDriver
    /// 11.1): the tab its commands address. Null once it was closed and no
    /// other was switched to.
    current_tab: ?Browser.TabId,
    timeouts: protocol.Timeouts,

    /// Create a new session with a fresh Browser on a thread of its own.
    /// `allocator` must be thread-safe (the Browser's thread allocates from
    /// it).
    pub fn init(allocator: Allocator) !*Session {
        const session = try allocator.create(Session);
        errdefer allocator.destroy(session);

        // Generate session ID
        const id = try protocol.generateSessionId(allocator);
        errdefer allocator.free(id);

        const host = BrowserHost.start(allocator, .{
            .persist_storage = false, // Don't persist storage for test sessions
            .snapshot_path = "", // Disable snapshot for faster startup in tests
        }) catch |err| {
            std.log.err("Failed to create browser: {}", .{err});
            return error.SessionNotCreated;
        };
        errdefer host.stop();

        // The Browser's first page is the session's first top-level
        // browsing context.
        const tabs = try host.listTabs(allocator);
        defer Browser.freeTabs(allocator, tabs);

        session.* = .{
            .allocator = allocator,
            .id = id,
            .host = host,
            .current_tab = if (tabs.len > 0) tabs[0].id else null,
            .timeouts = .{
                .script = protocol.Timeouts.default_script,
                .pageLoad = protocol.Timeouts.default_page_load,
                .implicit = protocol.Timeouts.default_implicit,
            },
        };

        return session;
    }

    /// Clean up session resources: the Browser ends, every tab closed
    /// without prompting.
    pub fn deinit(self: *Session) void {
        self.host.stop();
        self.allocator.free(self.id);
        self.allocator.destroy(self);
    }

    fn currentTab(self: *Session) !Browser.TabId {
        return self.current_tab orelse error.NoSuchWindow;
    }

    fn pageLoadTimeout(self: *Session) u64 {
        return self.timeouts.pageLoad orelse protocol.Timeouts.default_page_load;
    }

    /// W3C WebDriver "Navigate To": navigate the current top-level browsing
    /// context to `url` as the browser's UI does (HTML navigate with user
    /// involvement "browser UI" - the same traversable, its history kept),
    /// then wait for the navigation to complete - the page load strategy
    /// "normal": the new document's readiness "complete" - within the
    /// session page load timeout (error.Timeout: "timeout").
    pub fn navigate(self: *Session, url: []const u8) !void {
        std.log.info("Session {s}: navigating to {s}", .{ self.id, url });
        const tab = try self.currentTab();
        const landed = self.host.navigate(self.allocator, tab, url, .{ .wait = .complete, .timeout_ms = self.pageLoadTimeout() }) catch |err| return mapTabError(err);
        self.allocator.free(landed);
    }

    /// W3C WebDriver "Back": traverse the history by a delta -1, then wait
    /// for the navigation to complete.
    pub fn back(self: *Session) !void {
        const tab = try self.currentTab();
        _ = self.host.traverseHistoryAndWait(tab, -1, .{ .wait = .complete, .timeout_ms = self.pageLoadTimeout() }) catch |err| return mapTabError(err);
    }

    /// W3C WebDriver "Forward": traverse the history by a delta +1, then
    /// wait for the navigation to complete.
    pub fn forward(self: *Session) !void {
        const tab = try self.currentTab();
        _ = self.host.traverseHistoryAndWait(tab, 1, .{ .wait = .complete, .timeout_ms = self.pageLoadTimeout() }) catch |err| return mapTabError(err);
    }

    /// W3C WebDriver "Refresh": reload the current top-level browsing
    /// context as the browser's reload button does, then wait for the
    /// navigation to complete.
    pub fn refresh(self: *Session) !void {
        const tab = try self.currentTab();
        const landed = self.host.reload(self.allocator, tab, .{ .wait = .complete, .timeout_ms = self.pageLoadTimeout() }) catch |err| return mapTabError(err);
        self.allocator.free(landed);
    }

    /// Get current URL. OWNED by `allocator`.
    pub fn getUrl(self: *Session, allocator: Allocator) ![]u8 {
        const tab = try self.currentTab();
        return self.host.tabUrl(allocator, tab) catch |err| mapTabError(err);
    }

    /// Get page title. OWNED by `allocator`.
    pub fn getTitle(self: *Session, allocator: Allocator) ![]const u8 {
        return try self.executeScriptReturningString(allocator, "document.title || ''");
    }

    /// W3C WebDriver "Get Window Handle": the current top-level browsing
    /// context's, OWNED by `allocator`.
    pub fn windowHandle(self: *Session, allocator: Allocator) ![]u8 {
        const tab = try self.currentTab();
        // Still open?
        const url = self.host.tabUrl(allocator, tab) catch |err| return mapTabError(err);
        allocator.free(url);
        return std.fmt.allocPrint(allocator, "{d}", .{tab});
    }

    /// W3C WebDriver "Get Window Handles": every open top-level browsing
    /// context's, in order. OWNED by `allocator` (each, and the list).
    pub fn windowHandles(self: *Session, allocator: Allocator) ![][]u8 {
        const tabs = try self.host.listTabs(allocator);
        defer Browser.freeTabs(allocator, tabs);
        var handles: std.ArrayListUnmanaged([]u8) = .empty;
        errdefer {
            for (handles.items) |h| allocator.free(h);
            handles.deinit(allocator);
        }
        for (tabs) |tab| try handles.append(allocator, try std.fmt.allocPrint(allocator, "{d}", .{tab.id}));
        return handles.toOwnedSlice(allocator);
    }

    /// W3C WebDriver "Switch To Window": the open top-level browsing context
    /// named `handle` becomes current (error.NoSuchWindow when none is).
    pub fn switchToWindow(self: *Session, handle: []const u8) !void {
        const id = std.fmt.parseInt(Browser.TabId, handle, 10) catch return error.NoSuchWindow;
        // "If handle is equal to the associated window handle for some
        // top-level browsing context": open, and this session's Browser's.
        const url = self.host.tabUrl(self.allocator, id) catch return error.NoSuchWindow;
        self.allocator.free(url);
        self.current_tab = id;
        self.host.activateTab(id) catch {};
    }

    /// W3C WebDriver "Close Window": close the current top-level browsing
    /// context (HTML close, prompting to unload as the user's close does) and
    /// answer the handles left; none left ends the session (`ended`).
    pub fn closeWindow(self: *Session, allocator: Allocator) !struct { handles: [][]u8, ended: bool } {
        const tab = try self.currentTab();
        self.host.closeTab(tab, .{ .prompt_unload = true }) catch |err| return mapTabError(err);
        self.current_tab = null;
        const handles = try self.windowHandles(allocator);
        return .{ .handles = handles, .ended = handles.len == 0 };
    }

    /// W3C WebDriver "New Window": a new top-level browsing context, not
    /// made current (type hint "tab"). Its handle, OWNED by `allocator`.
    pub fn newWindow(self: *Session, allocator: Allocator) ![]u8 {
        const id = try self.host.createTab(.{ .background = true });
        return std.fmt.allocPrint(allocator, "{d}", .{id});
    }

    /// Execute synchronous JavaScript and return its result as a JSON string
    /// (W3C WebDriver "Execute Script": the script is a function body whose
    /// return value is the result).
    pub fn executeScript(self: *Session, allocator: Allocator, script: []const u8, args: ?std.json.Value) !?[]const u8 {
        _ = args; // TODO(webdriver): handle args (JSON deserialization of arguments, web element references)

        // The function body's return value, as JSON.
        const wrapped = try std.fmt.allocPrint(allocator,
            \\(function() {{
            \\    var __result = (function() {{ {s} }})();
            \\    return JSON.stringify(__result === undefined ? null : __result);
            \\}})()
        , .{script});
        defer allocator.free(wrapped);

        return try self.executeScriptReturningString(allocator, wrapped);
    }

    /// W3C WebDriver "Execute Async Script": the script is a function body
    /// called with a resolving function as its last argument; the result is
    /// what it is called with (the spec's promise, awaited on the Browser's
    /// own loop - no polling), within the session script timeout.
    pub fn executeAsyncScript(self: *Session, allocator: Allocator, script: []const u8, args: ?std.json.Value) !?[]const u8 {
        _ = args; // TODO(webdriver): handle args (JSON deserialization of arguments, web element references)

        const wrapped = try std.fmt.allocPrint(allocator,
            \\new Promise(function (resolve, reject) {{
            \\    (function() {{ {s} }}).apply(null, [resolve]);
            \\}}).then(function (result) {{ return JSON.stringify(result === undefined ? null : result); }})
        , .{script});
        defer allocator.free(wrapped);

        const tab = try self.currentTab();
        const timeout = self.timeouts.script orelse protocol.Timeouts.default_script;
        const answer = self.host.evaluate(allocator, tab, wrapped, .{ .await_promise = true }, timeout) catch |err| return switch (err) {
            error.Timeout => error.ScriptTimeout,
            else => mapTabError(err),
        };
        defer answer.deinit(allocator);
        if (answer.kind == .exception) return error.JavascriptError;
        return try stringOfRemoteValue(allocator, answer.json);
    }

    /// Evaluate `script` in the current top-level browsing context and
    /// return its completion value when it is a string, OWNED by
    /// `allocator`.
    fn executeScriptReturningString(self: *Session, allocator: Allocator, script: []const u8) ![]const u8 {
        const tab = try self.currentTab();
        const answer = self.host.evaluate(allocator, tab, script, .{}, self.timeouts.script orelse protocol.Timeouts.default_script) catch |err| return mapTabError(err);
        defer answer.deinit(allocator);
        if (answer.kind == .exception) {
            std.log.err("Script execution error: {s}", .{answer.json});
            return error.JavascriptError;
        }
        return stringOfRemoteValue(allocator, answer.json);
    }

    /// The string a BiDi RemoteValue's JSON carries ({"type":"string",
    /// "value":...}); "null" for any other value.
    fn stringOfRemoteValue(allocator: Allocator, json: []const u8) ![]u8 {
        const parsed = std.json.parseFromSlice(struct { type: []const u8, value: ?std.json.Value = null }, allocator, json, .{ .ignore_unknown_fields = true }) catch return error.JavascriptError;
        defer parsed.deinit();
        if (std.mem.eql(u8, parsed.value.type, "string")) {
            if (parsed.value.value) |value| switch (value) {
                .string => |text| return allocator.dupe(u8, text),
                else => {},
            };
        }
        return allocator.dupe(u8, "null");
    }

    /// A tab error as WebDriver's: a closed or unknown tab is "no such
    /// window", a wait past its timeout "timeout".
    fn mapTabError(err: anyerror) anyerror {
        return switch (err) {
            error.NoSuchTab, error.NoSuchTraversable, error.BrowserGone => error.NoSuchWindow,
            else => err,
        };
    }
};

/// Session manager - maintains active sessions
pub const SessionManager = struct {
    allocator: Allocator,
    sessions: std.StringHashMap(*Session),

    pub fn init(allocator: Allocator) SessionManager {
        return .{
            .allocator = allocator,
            .sessions = std.StringHashMap(*Session).init(allocator),
        };
    }

    pub fn deinit(self: *SessionManager) void {
        var it = self.sessions.valueIterator();
        while (it.next()) |session| {
            session.*.deinit();
        }
        self.sessions.deinit();
    }

    pub fn createSession(self: *SessionManager) !*Session {
        const session = try Session.init(self.allocator);
        errdefer session.deinit();

        try self.sessions.put(session.id, session);
        return session;
    }

    pub fn getSession(self: *SessionManager, id: []const u8) ?*Session {
        return self.sessions.get(id);
    }

    pub fn deleteSession(self: *SessionManager, id: []const u8) bool {
        if (self.sessions.fetchRemove(id)) |entry| {
            entry.value.deinit();
            return true;
        }
        return false;
    }
};

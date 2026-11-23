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
    /// New Session's `se:cdp`: CDP for this session's Browser
    /// (devtools_endpoint.zig).
    cdp: @import("devtools_endpoint.zig").Endpoint = .{},
    /// Send Alert Text's text for the open prompt (OWNED), which Accept Alert
    /// answers it with.
    alert_text: ?[]u8 = null,

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
        // The session answers its Browser's user prompts (W3C WebDriver 16:
        // a prompt stays open until a command handles it), so it claims each
        // as it opens: the platform's dialog does not answer it.
        host.call(session, addPromptListener) catch {};

        return session;
    }

    fn promptListener(self: *Session) browser_mod.host_events.Listener {
        return .{ .context = self, .on_event = onBrowserEvent };
    }

    fn addPromptListener(ctx: ?*anyopaque, b: *Browser) void {
        const self: *Session = @ptrCast(@alignCast(ctx.?));
        b.addListener(self.promptListener()) catch {};
    }

    fn removePromptListener(ctx: ?*anyopaque, b: *Browser) void {
        const self: *Session = @ptrCast(@alignCast(ctx.?));
        b.removeListener(self.promptListener());
    }

    /// On the Browser's thread: a prompt opening is claimed.
    fn onBrowserEvent(context: *anyopaque, event: *const browser_mod.host_events.Event) void {
        _ = context;
        switch (event.*) {
            .dialog_opening => |opening| opening.claim.* = true,
            else => {},
        }
    }

    /// Clean up session resources: the Browser ends, every tab closed
    /// without prompting.
    pub fn deinit(self: *Session) void {
        // An open prompt is dismissed first: the Browser's thread is paused
        // on it, and everything below runs there.
        if (self.host.userPromptOf(self.allocator) catch null) |info| {
            defer info.deinit(self.allocator);
            _ = self.host.answerUserPrompt(info.tab, false, "");
        }
        // The CDP endpoint first: its sessions detach while the Browser runs.
        self.cdp.stop();
        self.host.call(self, removePromptListener) catch {};
        if (self.alert_text) |text| self.allocator.free(text);
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
        const landed = self.host.navigate(self.allocator, tab, url, .{ .wait = .complete, .timeout_ms = self.pageLoadTimeout() }) catch |err| switch (err) {
            // The page opened a prompt while it loaded: the navigation
            // command is done, the prompt left for the next command.
            error.UserPromptOpen => return,
            else => return mapTabError(err),
        };
        self.allocator.free(landed);
    }

    /// W3C WebDriver "Back": traverse the history by a delta -1, then wait
    /// for the navigation to complete.
    pub fn back(self: *Session) !void {
        const tab = try self.currentTab();
        _ = self.host.traverseHistoryAndWait(tab, -1, .{ .wait = .complete, .timeout_ms = self.pageLoadTimeout() }) catch |err| switch (err) {
            error.UserPromptOpen => return,
            else => return mapTabError(err),
        };
    }

    /// W3C WebDriver "Forward": traverse the history by a delta +1, then
    /// wait for the navigation to complete.
    pub fn forward(self: *Session) !void {
        const tab = try self.currentTab();
        _ = self.host.traverseHistoryAndWait(tab, 1, .{ .wait = .complete, .timeout_ms = self.pageLoadTimeout() }) catch |err| switch (err) {
            error.UserPromptOpen => return,
            else => return mapTabError(err),
        };
    }

    /// W3C WebDriver "Refresh": reload the current top-level browsing
    /// context as the browser's reload button does, then wait for the
    /// navigation to complete.
    pub fn refresh(self: *Session) !void {
        const tab = try self.currentTab();
        const landed = self.host.reload(self.allocator, tab, .{ .wait = .complete, .timeout_ms = self.pageLoadTimeout() }) catch |err| switch (err) {
            error.UserPromptOpen => return,
            else => return mapTabError(err),
        };
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
        const answer = self.host.evaluate(allocator, tab, wrapped, .{ .await_promise = true }, timeout) catch |err| switch (err) {
            error.Timeout => return error.ScriptTimeout,
            // A prompt the script opened: null, the prompt left open.
            error.UserPromptOpen => return try allocator.dupe(u8, "null"),
            else => return mapTabError(err),
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
        const answer = self.host.evaluate(allocator, tab, script, .{}, self.timeouts.script orelse protocol.Timeouts.default_script) catch |err| switch (err) {
            // A prompt the script opened: the command returns null, the
            // prompt open for the next command to handle (W3C WebDriver 13).
            error.UserPromptOpen => return allocator.dupe(u8, "null"),
            else => return mapTabError(err),
        };
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

    // ------------------------------------------------------------------
    // User prompts (W3C WebDriver 16)
    // ------------------------------------------------------------------

    /// The open prompt of the session's Browser, OWNED, or null.
    fn openPrompt(self: *Session) ?browser_mod.host_events.UserPromptInfo {
        return self.host.userPromptOf(self.allocator) catch null;
    }

    /// "Handle any user prompts" (16.2) with the unhandled prompt behaviour
    /// "dismiss and notify", the default: an open prompt is dismissed and
    /// the command fails with "unexpected alert open".
    pub fn handleUserPrompts(self: *Session) !void {
        const info = self.openPrompt() orelse return;
        defer info.deinit(self.allocator);
        _ = self.host.answerUserPrompt(info.tab, false, "");
        self.clearAlertText();
        return error.UnexpectedAlertOpen;
    }

    fn clearAlertText(self: *Session) void {
        if (self.alert_text) |text| self.allocator.free(text);
        self.alert_text = null;
    }

    /// Dismiss Alert (16.3): an alert is acknowledged, a confirm or prompt
    /// answered "cancel". error.NoSuchAlert with none open.
    pub fn dismissAlert(self: *Session) !void {
        const info = self.openPrompt() orelse return error.NoSuchAlert;
        defer info.deinit(self.allocator);
        self.clearAlertText();
        if (!self.host.answerUserPrompt(info.tab, info.kind == .alert, "")) return error.NoSuchAlert;
    }

    /// Accept Alert (16.4): OK - a prompt with the text Send Alert Text
    /// gave, else its default.
    pub fn acceptAlert(self: *Session) !void {
        const info = self.openPrompt() orelse return error.NoSuchAlert;
        defer info.deinit(self.allocator);
        const text: []const u8 = if (info.kind == .prompt) (self.alert_text orelse info.default_prompt) else "";
        const answered = self.host.answerUserPrompt(info.tab, true, text);
        self.clearAlertText();
        if (!answered) return error.NoSuchAlert;
    }

    /// Get Alert Text (16.5): the open prompt's message, OWNED.
    pub fn alertText(self: *Session, allocator: Allocator) ![]u8 {
        const info = self.openPrompt() orelse return error.NoSuchAlert;
        defer info.deinit(self.allocator);
        return allocator.dupe(u8, info.message);
    }

    /// Send Alert Text (16.6): only a prompt takes text ("element not
    /// interactable" for an alert or confirm); kept for Accept Alert.
    pub fn sendAlertText(self: *Session, text: []const u8) !void {
        const info = self.openPrompt() orelse return error.NoSuchAlert;
        defer info.deinit(self.allocator);
        if (info.kind != .prompt) return error.ElementNotInteractable;
        const copy = try self.allocator.dupe(u8, text);
        self.clearAlertText();
        self.alert_text = copy;
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

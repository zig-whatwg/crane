//! A session on a page target, on its Browser's thread.
//!
//! Flat sessions (tmp/plans/cdp-part1-design.md 2.3): every message names its
//! session, a target may have several sessions, and each has its own domain
//! state - Vitest's `cdp()` attaches a second session to a page Playwright
//! already drives. Chrome keeps the same per-session split: a
//! DevToolsSession per client per agent host, each with its own handlers
//! (content/browser/devtools/devtools_session.cc; Blink's per-session agents,
//! third_party/blink/renderer/core/inspector/devtools_session.cc).
//!
//! The devtools thread allocates a PageSession and posts its attach, its
//! messages and its detach to the Browser through the host's command queue,
//! in that order; everything here runs on the Browser thread, between tasks.
//! Handlers (src/devtools/domains/) see the fields and methods below.

const std = @import("std");
const Allocator = std.mem.Allocator;
const json_rpc = @import("json_rpc.zig");
const dispatch_mod = @import("dispatch.zig");
const ids = @import("ids.zig");
const outbound = @import("outbound.zig");
const host_bridge = @import("host_bridge.zig");
const page_domains = @import("domains/page_domains.zig");
const BrowserSide = @import("browser_side.zig").BrowserSide;

const log = std.log.scoped(.devtools);

pub const PageSession = struct {
    /// Thread-safe (the session is made on the devtools thread and freed on
    /// the Browser thread).
    allocator: Allocator,
    /// The session's id and its connection's FIFO.
    link: *outbound.SessionLink,
    /// The message a handler's `fail` set, for the dispatcher.
    failure: dispatch_mod.Failure = .{},
    /// The Browser's devtools record (null until attached).
    side: ?*BrowserSide = null,
    /// The Browser this session's page lives in (null until attached).
    browser: ?*host_bridge.Browser = null,
    /// The page's tab: its top-level BrowsingContext id.
    tab: host_bridge.TabId,
    /// The target's id: the tab's main frame id.
    target_id: ids.Token,
    /// Each domain's per-session state (domains/page_domains.zig States).
    states: page_domains.States = .{},
    attached: bool = false,

    /// Devtools thread: a session for `tab`, not yet attached. `link` is
    /// retained.
    pub fn allocate(allocator: Allocator, link: *outbound.SessionLink, tab: host_bridge.TabId, target_id: ids.Token) Allocator.Error!*PageSession {
        const self = try allocator.create(PageSession);
        self.* = .{ .allocator = allocator, .link = link.retain(), .tab = tab, .target_id = target_id };
        return self;
    }

    /// Free a session that never attached (its Browser went first).
    pub fn discard(self: *PageSession) void {
        std.debug.assert(!self.attached);
        self.link.end();
        self.link.release();
        self.allocator.destroy(self);
    }

    /// Browser thread: attach to `side`'s Browser. Each handler module's
    /// `sessionStarted(session)` runs.
    pub fn attach(self: *PageSession, side: *BrowserSide, browser: *host_bridge.Browser) Allocator.Error!void {
        try side.sessions.append(side.allocator, self);
        self.side = side;
        self.browser = browser;
        self.attached = true;
        inline for (@typeInfo(page_domains.Handlers).@"struct".decl_names) |name| {
            const H = @field(page_domains.Handlers, name);
            if (comptime @hasDecl(H, "sessionStarted")) H.sessionStarted(self);
        }
    }

    /// Browser thread: detach and free. Each handler module's
    /// `sessionEnded(session)` runs first: it clears the session's overrides
    /// (Chrome clears a session's emulation when it detaches) and drops the
    /// replies it kept.
    pub fn detach(self: *PageSession) void {
        if (self.attached) {
            inline for (@typeInfo(page_domains.Handlers).@"struct".decl_names) |name| {
                const H = @field(page_domains.Handlers, name);
                if (comptime @hasDecl(H, "sessionEnded")) H.sessionEnded(self);
            }
            if (self.side) |side| {
                for (side.sessions.items, 0..) |s, i| if (s == self) {
                    _ = side.sessions.swapRemove(i);
                    break;
                };
            }
            self.attached = false;
        }
        self.link.end();
        self.link.release();
        self.allocator.destroy(self);
    }

    /// Browser thread: one message from the client. Parsed into an arena
    /// that lives for the call.
    pub fn handleMessage(self: *PageSession, raw: []const u8) void {
        var arena_state = std.heap.ArenaAllocator.init(self.allocator);
        defer arena_state.deinit();
        const parsed = json_rpc.parse(arena_state.allocator(), raw) catch {
            dispatch_mod.sendError(self.link, null, @backingInt(json_rpc.Code.internal_error), "Out of memory", null);
            return;
        };
        switch (parsed) {
            .failure => |f| dispatch_mod.sendError(self.link, f.id, @backingInt(f.code), f.message, null),
            .command => |command| dispatch_mod.dispatch(page_domains.Handlers, self, arena_state.allocator(), &command),
        }
    }

    // ------------------------------------------------------------------
    // For handlers
    // ------------------------------------------------------------------

    /// Send event `E` (a generated event: `protocol.Page.frameNavigated`).
    pub fn emit(self: *PageSession, comptime E: type, params: E.Params) void {
        const message = json_rpc.encodeEvent(self.allocator, E, params, self.link.sessionId()) catch {
            log.warn("out of memory sending {s}", .{E.method});
            return;
        };
        self.link.send(message);
    }

    /// Send a message V8's inspector made, with this session's id added.
    pub fn sendRaw(self: *PageSession, message: []const u8) void {
        const with_id = json_rpc.appendSessionId(self.allocator, message, self.link.sessionId()) catch return;
        self.link.send(with_id);
    }

    /// Fail the current command with Chrome's message for it (-32000):
    /// `return session.fail("No frame with given id found");`
    pub fn fail(self: *PageSession, message: []const u8) error{Protocol} {
        return self.failure.set(.server_error, message);
    }

    /// As `fail`, with another code (-32602 for a bad argument value).
    pub fn failWithCode(self: *PageSession, code: json_rpc.Code, message: []const u8) error{Protocol} {
        return self.failure.set(code, message);
    }

    /// The frame id of `navigable_id` (a BrowsingContext id) in this Browser.
    pub fn frameId(self: *const PageSession, navigable_id: u64) ids.Token {
        return ids.frameId(self.side.?.token, navigable_id);
    }

    /// The navigable a frame id names, if it is one of this Browser's.
    pub fn navigableOf(self: *const PageSession, frame_id: []const u8) ?u64 {
        const ref = ids.parseFrameId(frame_id) orelse return null;
        if (ref.browser_token != self.side.?.token) return null;
        return ref.navigable_id;
    }

    /// Release the tab's start hold (Target.setAutoAttach
    /// {waitForDebuggerOnStart}): its first navigation starts. Runtime's
    /// runIfWaitingForDebugger reaches this, from the handler or from V8's
    /// inspector client hook.
    /// The devtools thread counts the tab's waiting sessions and releases the
    /// hold (life1's `release`) when the last one has run: Chrome's
    /// TargetHandler throttle resumes a paused target when every client it
    /// reported waiting has answered.
    pub fn runIfWaitingForDebugger(self: *PageSession) void {
        const side = self.side orelse return;
        var id: [32]u8 = @splat(0);
        const own = self.link.sessionId();
        @memcpy(id[0..own.len], own);
        side.sink.post(side.sink.context, side, .{ .run_if_waiting = .{ .tab = self.tab, .session_id = id } });
    }

    /// Every attached page session of this Browser (this one included):
    /// compare each one's `tab`, or use `side.sessionsOn(tab, buffer)`.
    pub fn browserSessions(self: *const PageSession) []const *PageSession {
        return if (self.side) |side| side.sessions.items else &.{};
    }
};

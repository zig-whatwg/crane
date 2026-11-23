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
const held_commands = @import("held_commands.zig");
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
    /// The current command's arena, set by the dispatcher: a handler's
    /// result may be allocated from it (it lives until the answer is sent;
    /// an async handler copies what it keeps).
    arena: ?Allocator = null,
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
    /// Fetch.enable is in force (written on the Browser thread, read by the
    /// devtools thread, which answers the Fetch commands that decide a
    /// held request: fetch_interception.zig).
    fetch_enabled: std.atomic.Value(bool) = .init(false),
    /// The client's messages held while the tab navigates, in arrival
    /// order, each OWNED (held_commands.zig: Chrome's suspended
    /// DevToolsSession keeps them in pending_messages_).
    held: std.ArrayListUnmanaged([]u8) = .empty,
    /// The posted session message that sends them on, if one is posted; a
    /// detach cancels it.
    release: ?*ReleaseTask = null,

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
        // What it held is dropped, unanswered, as Chrome drops a closed
        // session's pending messages; its release, if posted, finds no
        // session.
        if (self.release) |task| task.session = null;
        self.release = null;
        for (self.held.items) |raw| self.allocator.free(raw);
        self.held.deinit(self.allocator);
        self.link.end();
        self.link.release();
        self.allocator.destroy(self);
    }

    /// Browser thread: one message from the client. Parsed into an arena
    /// that lives for the call. While the tab navigates, a command the page
    /// would answer waits until the navigation ends (`holds`).
    pub fn handleMessage(self: *PageSession, raw: []const u8) void {
        self.handle(raw, true);
    }

    fn handle(self: *PageSession, raw: []const u8, may_hold: bool) void {
        var arena_state = std.heap.ArenaAllocator.init(self.allocator);
        defer arena_state.deinit();
        const parsed = json_rpc.parse(arena_state.allocator(), raw) catch {
            dispatch_mod.sendError(self.link, null, @backingInt(json_rpc.Code.internal_error), "Out of memory", null);
            return;
        };
        switch (parsed) {
            .failure => |f| dispatch_mod.sendError(self.link, f.id, @backingInt(f.code), f.message, null),
            .command => |command| {
                if (may_hold and self.holds(&command, arena_state.allocator(), raw)) return;
                dispatch_mod.dispatch(page_domains.Handlers, self, arena_state.allocator(), &command);
            },
        }
    }

    /// Hold `raw`, `command`'s text, if the tab navigates and the command is
    /// one its page answers (held_commands.holds) - or if earlier ones still
    /// wait for their release, so that they go first. One whose params
    /// Chrome decodes in the browser and that do not decode is not held: the
    /// dispatcher answers it at once, as Chrome's does (`arena` holds the
    /// decode). Chrome: DevToolsSession::DispatchProtocolMessageInternal,
    /// then the browser handlers, then FallThrough (devtools_session.cc).
    fn holds(self: *PageSession, command: *const json_rpc.Command, arena: Allocator, raw: []const u8) bool {
        const method = command.method;
        const mode = self.holdMode() orelse return false;
        if (!held_commands.holds(mode, method)) return false;
        if (held_commands.decodedInBrowser(method) and !dispatch_mod.paramsDecode(page_domains.Handlers, arena, command)) return false;
        const copy = self.allocator.dupe(u8, raw) catch return false;
        self.held.append(self.allocator, copy) catch {
            self.allocator.free(copy);
            return false;
        };
        // A held Runtime.runIfWaitingForDebugger resumes its waiting target
        // now all the same (DispatchProtocolMessageInternal runs
        // `runtime_resume_` for kResumeMethod before it dispatches
        // anything): the navigation the tab waits with is the one its
        // commands wait for. Its answer comes after, as any held command's;
        // the handler's own resume then finds nothing waiting.
        if (std.mem.eql(u8, method, "Runtime.runIfWaitingForDebugger")) self.runIfWaitingForDebugger();
        return true;
    }

    /// The mode the session holds in: its tab's navigations' while one is
    /// in flight; `all` while held commands still wait for their release
    /// (Chrome sends them the moment the navigation finishes, before any
    /// command that comes after - here their release is a session message
    /// of its own); null when nothing holds.
    fn holdMode(self: *const PageSession) ?held_commands.Mode {
        if (self.side) |side| if (side.navigations.modeOf(self.tab)) |mode| return mode;
        if (self.held.items.len > 0) return .all;
        return null;
    }

    /// Browser thread: the tab's navigations ended - send what this session
    /// holds, from a session message of its own (posted now: from inside a
    /// navigation's commit, the commands run after it, in the new document).
    pub fn scheduleRelease(self: *PageSession) void {
        if (!self.attached or self.held.items.len == 0 or self.release != null) return;
        const side = self.side orelse return;
        const task = self.allocator.create(ReleaseTask) catch {
            log.warn("out of memory releasing held commands", .{});
            return;
        };
        task.* = .{ .session = self, .allocator = self.allocator };
        self.release = task;
        // On failure `drop` ran: no release is posted (the Browser ends, and
        // its uninstall detaches this session).
        _ = host_bridge.postSessionMessage(side.host, task, ReleaseTask.run, ReleaseTask.drop);
    }

    /// The release of a session's held commands: they go to their handlers
    /// in the order they came (Chrome's ResumeSendingMessagesToAgent sends
    /// every pending message at once) - unless the tab is navigating again
    /// by then, when they wait for that navigation too. Commands that came
    /// while they went follow them.
    pub const ReleaseTask = struct {
        /// Null once the session detached.
        session: ?*PageSession,
        allocator: Allocator,

        fn run(context: ?*anyopaque, browser: *host_bridge.Browser) void {
            _ = browser;
            const task: *ReleaseTask = @ptrCast(@alignCast(context.?));
            defer task.allocator.destroy(task);
            const first = task.session orelse return;
            if (first.holdNavigating()) {
                first.release = null;
                return;
            }
            // The batch is what is held now: it goes whole, even if one of
            // its commands starts a navigation (Chrome sent them all to the
            // page before it could).
            var batch = first.held.items.len;
            while (true) {
                const session = task.session orelse return;
                if (session.held.items.len == 0) break;
                if (batch == 0) {
                    if (session.holdNavigating()) break;
                    batch = session.held.items.len;
                }
                const raw = session.held.orderedRemove(0);
                batch -= 1;
                const allocator = session.allocator;
                defer allocator.free(raw);
                // A handler may detach the session (inside a debugger pause's
                // nested loop): the detach clears `task.session`.
                session.handle(raw, false);
            }
            if (task.session) |session| session.release = null;
        }

        fn drop(context: ?*anyopaque) void {
            const task: *ReleaseTask = @ptrCast(@alignCast(context.?));
            if (task.session) |session| session.release = null;
            task.allocator.destroy(task);
        }
    };

    /// Whether the tab has a navigation in flight (not counting held
    /// commands still waiting for their release).
    fn holdNavigating(self: *const PageSession) bool {
        const side = self.side orelse return false;
        return side.navigations.modeOf(self.tab) != null;
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

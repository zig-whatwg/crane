//! HTML 8.9.1 "Simple dialogs" and 8.9.2's printing steps: alert(),
//! confirm(), prompt(), beforeunload's prompt to unload, and print() - the
//! checks, WebDriver BiDi's user prompt opened and closed (told to the
//! Browser's hook, html_core navigation/user_prompts.zig), and the pause
//! until the dialog is answered (runtime.BrowserPause, policy `.dialog`: no
//! task, timer or other page message runs meanwhile).
//!
//! Who answers: a host that claimed the prompt as it opened - a CDP session
//! with Page enabled (Page.handleJavaScriptDialog, which lane cdpt's devtools
//! thread answers while this thread is paused), a WebDriver session (Accept
//! Alert, Dismiss Alert, its unhandled prompt behaviour) - through the
//! prompt's `DialogAnswer`, from any thread; else the platform's own dialog
//! (platform.runSimpleDialog: on the headless platforms "cannot show", which
//! answers at once - alert returns, confirm false, prompt null - what the
//! console and the WPT runner always got). This replaces the window's legacy
//! UI backend (ui_backend.showAlert/Confirm/Prompt/Print), which answered
//! without the steps, the pause or any host (lane cdph, the integrator's
//! ruling 7:46 PM ET 2026-11-21).
//!
//! Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#simple-dialogs
//!       https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#printing

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const platform = @import("platform");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html_core = @import("html_core");
const platform_state = @import("platform_state.zig");
const user_activation = @import("user_activation.zig");

const user_prompts = html_core.navigation.user_prompts;
pub const Kind = user_prompts.Kind;

const log = std.log.scoped(.simple_dialogs);

/// What an open prompt came to. `text` OWNED by the allocator `run` took.
pub const Answer = struct {
    accepted: bool,
    text: ?[]u8 = null,
};

/// One Browser's open prompt - at most one: the Browser's thread is paused
/// while it is open. A supplement of the Browser's scope, so it outlives
/// every prompt and a late answer from another thread finds it. Every field
/// is read and written under `mutex`.
pub const PendingPrompt = struct {
    allocator: Allocator,
    mutex: std.Io.Mutex = .init,
    /// Which prompt is open (0: none); each opening takes the next.
    serial: u64 = 0,
    next_serial: u64 = 1,
    tab: u64 = 0,
    navigable: u64 = 0,
    kind: Kind = .alert,
    /// OWNED copies, for a host that reads the prompt from another thread
    /// (WebDriver's Get Alert Text).
    message: []u8 = &.{},
    default_prompt: []u8 = &.{},
    answered: bool = false,
    accepted: bool = false,
    /// OWNED.
    text: ?[]u8 = null,
    /// The Browser's pause, woken by an answer.
    pause: ?*runtime.BrowserPause = null,

    pub fn init(allocator: Allocator) PendingPrompt {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *PendingPrompt) void {
        self.clearLocked();
    }

    fn lock(self: *PendingPrompt) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
    }

    fn unlock(self: *PendingPrompt) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    fn clearLocked(self: *PendingPrompt) void {
        if (self.message.len > 0) self.allocator.free(self.message);
        if (self.default_prompt.len > 0) self.allocator.free(self.default_prompt);
        if (self.text) |t| self.allocator.free(t);
        self.message = &.{};
        self.default_prompt = &.{};
        self.text = null;
        self.serial = 0;
        self.answered = false;
        self.accepted = false;
    }

    /// Open a prompt: its serial.
    fn begin(self: *PendingPrompt, tab: u64, navigable: u64, kind: Kind, message: []const u8, default_prompt: []const u8) Allocator.Error!u64 {
        const message_copy = if (message.len > 0) try self.allocator.dupe(u8, message) else &.{};
        errdefer if (message_copy.len > 0) self.allocator.free(message_copy);
        const default_copy = if (default_prompt.len > 0) try self.allocator.dupe(u8, default_prompt) else &.{};
        self.lock();
        defer self.unlock();
        self.clearLocked();
        self.serial = self.next_serial;
        self.next_serial += 1;
        self.tab = tab;
        self.navigable = navigable;
        self.kind = kind;
        self.message = message_copy;
        self.default_prompt = default_copy;
        return self.serial;
    }

    /// The prompt `serial` is answered: copies `text`, wakes the pause.
    /// False when it was answered already or is no longer open.
    fn answerSerial(self: *PendingPrompt, serial: u64, accept: bool, text: []const u8) bool {
        const copy: ?[]u8 = self.allocator.dupe(u8, text) catch null;
        self.lock();
        if (self.serial == 0 or self.serial != serial or self.answered) {
            self.unlock();
            if (copy) |c| self.allocator.free(c);
            return false;
        }
        self.answered = true;
        self.accepted = accept;
        self.text = copy;
        const pause = self.pause;
        self.unlock();
        if (pause) |p| p.notify();
        return true;
    }

    /// `DialogAnswer.answer`: the open prompt is answered. Any thread.
    fn answerOpen(context: *anyopaque, accept: bool, text: []const u8) bool {
        const self: *PendingPrompt = @ptrCast(@alignCast(context));
        self.lock();
        const serial = self.serial;
        self.unlock();
        if (serial == 0) return false;
        return self.answerSerial(serial, accept, text);
    }

    /// The host's door to the open prompt (`Opening.answer`).
    pub fn dialogAnswer(self: *PendingPrompt) user_prompts.DialogAnswer {
        return .{ .context = self, .answer = answerOpen };
    }

    fn isAnswered(self: *PendingPrompt, serial: u64) bool {
        self.lock();
        defer self.unlock();
        return self.serial != serial or self.answered;
    }

    /// Close prompt `serial`: its answer, `text` moved into `allocator`.
    fn finish(self: *PendingPrompt, allocator: Allocator) Answer {
        self.lock();
        defer self.unlock();
        var answer: Answer = .{ .accepted = self.answered and self.accepted };
        if (self.text) |t| {
            answer.text = allocator.dupe(u8, t) catch null;
        }
        self.clearLocked();
        return answer;
    }

    /// What a host reads of the open prompt, copied into `allocator`; null
    /// with none open. Any thread.
    pub fn snapshot(self: *PendingPrompt, allocator: Allocator) Allocator.Error!?Info {
        self.lock();
        defer self.unlock();
        if (self.serial == 0 or self.answered) return null;
        const message = try allocator.dupe(u8, self.message);
        errdefer allocator.free(message);
        return .{
            .tab = self.tab,
            .navigable = self.navigable,
            .kind = self.kind,
            .message = message,
            .default_prompt = try allocator.dupe(u8, self.default_prompt),
        };
    }
};

/// An open prompt as a host reads it (`PendingPrompt.snapshot`).
pub const Info = struct {
    tab: u64,
    navigable: u64,
    kind: Kind,
    /// OWNED.
    message: []u8,
    default_prompt: []u8,

    pub fn deinit(self: Info, allocator: Allocator) void {
        allocator.free(self.message);
        allocator.free(self.default_prompt);
    }
};

/// `scope`'s pending-prompt record, made on first use.
pub fn pendingOf(scope: *runtime.BrowserScope) ?*PendingPrompt {
    return scope.of(PendingPrompt) catch null;
}

/// HTML "cannot show simple dialogs" for `window`.
pub fn cannotShow(window: *runtime.Instance) bool {
    // 1. The associated Document's active sandboxing flag set has the
    // sandboxed modals flag.
    if (interfaces.Window.get_document(window)) |document| {
        if (dom.document_scripts.activeSandboxingFlags(document).modals) return true;
    } else |_| return true;
    // 2. "If window's relevant agent's event loop's termination nesting
    // level is nonzero, then optionally return true": Chrome, Firefox and
    // Safari all ignore a dialog opened from beforeunload, pagehide or
    // unload (Blink's "Blocked alert() during unload"), so Crane returns
    // true here.
    if (html_core.navigation.termination_nesting.active(dom.agent_hosts.of(window.ctx))) return true;
    // 3. (No user option to ignore every dialog.)
    return false;
}

/// Infra "normalize newlines": CR LF and lone CR become LF. OWNED.
fn normalizeNewlines(allocator: Allocator, text: []const u8) Allocator.Error![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, text.len);
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text[i] == '\r') {
            out.appendAssumeCapacity('\n');
            if (i + 1 < text.len and text[i + 1] == '\n') i += 1;
        } else out.appendAssumeCapacity(text[i]);
    }
    return out.toOwnedSlice(allocator);
}

/// Show a simple dialog of `kind` for `window` and pause until it is
/// answered: what alert's steps 3-7, confirm's 2-9, prompt's 2-10 and the
/// beforeunload prompt share. "Optionally truncate" keeps the message
/// whole. The caller ran "cannot show simple dialogs" (step 1) itself, as
/// each method answers it differently. `allocator` takes the answer's text.
pub fn show(allocator: Allocator, window: *runtime.Instance, kind: Kind, message: []const u8, default_prompt: []const u8) Answer {
    const realm = window.ctx;
    const scope = realm.browserScope() orelse return .{ .accepted = false };
    const pending = pendingOf(scope) orelse return .{ .accepted = false };
    const pause = scope.of(runtime.BrowserPause) catch return .{ .accepted = false };
    const bc = dom.browser_state.browsingContextOf(window);
    const navigable: u64 = if (bc) |b| b.id else 0;
    const tab: u64 = if (bc) |b| b.getTop().id else 0;

    // Normalize newlines (and optionally truncate: Crane shows it whole).
    const normalized = normalizeNewlines(allocator, message) catch return .{ .accepted = false };
    defer allocator.free(normalized);
    const default_normalized = normalizeNewlines(allocator, default_prompt) catch return .{ .accepted = false };
    defer allocator.free(default_normalized);

    pending.pause = pause;
    const serial = pending.begin(tab, navigable, kind, normalized, default_normalized) catch return .{ .accepted = false };

    // WebDriver BiDi "user prompt opened": the Browser's hosts hear it; one
    // that will answer claims it. Its handler is "none" - shown to the user,
    // who is that host or the platform (no BiDi session configures another).
    var claim = false;
    const url = documentUrl(allocator, window);
    defer allocator.free(url);
    const opening: user_prompts.Opening = .{
        .tab = tab,
        .navigable = navigable,
        .kind = kind,
        .message = normalized,
        .default_prompt = default_normalized,
        .url = url,
        .answer = pending.dialogAnswer(),
        .claim = &claim,
    };
    if (bc) |b| user_prompts.opened(b.navigables, &opening);
    // Nobody claimed it: the platform's own dialog answers.
    if (!claim) askPlatform(realm, window, pending, serial, kind, normalized, default_normalized);

    // Pause until the user - the claiming host, or the platform - responds.
    const Waiting = struct {
        pending: *PendingPrompt,
        serial: u64,
        fn met(context: *anyopaque) bool {
            const self: *@This() = @ptrCast(@alignCast(context));
            return self.pending.isAnswered(self.serial);
        }
    };
    var waiting: Waiting = .{ .pending = pending, .serial = serial };
    pause.pauseUntil(.{ .context = &waiting, .met = Waiting.met }, .dialog);

    const answer = pending.finish(allocator);
    // WebDriver BiDi "user prompt closed".
    const closing: user_prompts.Closed = .{
        .tab = tab,
        .navigable = navigable,
        .kind = kind,
        .accepted = answer.accepted,
        .user_input = answer.text orelse "",
    };
    if (bc) |b| user_prompts.closed(b.navigables, &closing);
    return answer;
}

fn documentUrl(allocator: Allocator, window: *runtime.Instance) []u8 {
    const document = interfaces.Window.get_document(window) catch return allocator.dupe(u8, "about:blank") catch &.{};
    const url = interfaces.Document.get_URL(document) catch return allocator.dupe(u8, "about:blank") catch &.{};
    defer document.ctx.allocator.free(url);
    return allocator.dupe(u8, url) catch &.{};
}

/// The platform's dialog for prompt `serial`; its Reply - on any thread,
/// maybe before this returns - answers it. Without the capability, or with
/// no Browser platform, the dialog cannot be shown: it is answered as
/// dismissed at once.
fn askPlatform(realm: runtime.Context, window: *runtime.Instance, pending: *PendingPrompt, serial: u64, kind: Kind, message: []const u8, default_prompt: []const u8) void {
    if (platform.capabilities.simple_dialogs == .unsupported) {
        _ = pending.answerSerial(serial, false, "");
    } else {
        const browser = platform_state.of(realm) orelse {
            _ = pending.answerSerial(serial, false, "");
            return;
        };
        var parts = (platform_state.requester(realm, user_activation.hasTransientActivation(window)) catch null) orelse {
            _ = pending.answerSerial(serial, false, "");
            return;
        };
        defer parts.deinit();
        const token = pending.allocator.create(ReplyToken) catch {
            _ = pending.answerSerial(serial, false, "");
            return;
        };
        token.* = .{ .pending = pending, .serial = serial };
        const requester = parts.requester();
        platform.runSimpleDialog(browser, &requester, &.{
            .kind = switch (kind) {
                .alert => .alert,
                .confirm => .confirm,
                .prompt => .prompt,
                .beforeunload => .beforeunload,
            },
            .message = .from(message),
            .default_value = .from(default_prompt),
        }, .{ .context = token, .deliver = ReplyToken.deliver, .drop = ReplyToken.drop });
    }
}

/// The platform's Reply for one prompt: freed by its one call.
const ReplyToken = struct {
    pending: *PendingPrompt,
    serial: u64,

    fn deliver(context: *anyopaque, value: *const platform.DialogResult) callconv(.c) void {
        const self: *ReplyToken = @ptrCast(@alignCast(context));
        defer self.pending.allocator.destroy(self);
        _ = self.pending.answerSerial(self.serial, value.accepted, value.text.slice());
    }

    /// No answer from the platform: the dialog is dismissed.
    fn drop(context: *anyopaque) callconv(.c) void {
        const self: *ReplyToken = @ptrCast(@alignCast(context));
        defer self.pending.allocator.destroy(self);
        _ = self.pending.answerSerial(self.serial, false, "");
    }
};

// ============================================================================
// The methods' steps
// ============================================================================

/// alert(message) steps 1-7.
pub fn alert(window: *runtime.Instance, message: []const u8) void {
    if (cannotShow(window)) return;
    const answer = show(window.ctx.allocator, window, .alert, message, "");
    if (answer.text) |t| window.ctx.allocator.free(t);
}

/// confirm(message) steps 1-10: whether the user responded positively.
pub fn confirm(window: *runtime.Instance, message: []const u8) bool {
    if (cannotShow(window)) return false;
    const answer = show(window.ctx.allocator, window, .confirm, message, "");
    if (answer.text) |t| window.ctx.allocator.free(t);
    return answer.accepted;
}

/// prompt(message, default) steps 1-11: the string the user responded
/// with, or null when they aborted. OWNED by `window.ctx.allocator`.
pub fn prompt(window: *runtime.Instance, message: []const u8, default_prompt: []const u8) ?[]u8 {
    if (cannotShow(window)) return null;
    const answer = show(window.ctx.allocator, window, .prompt, message, default_prompt);
    if (!answer.accepted) {
        if (answer.text) |t| window.ctx.allocator.free(t);
        return null;
    }
    return answer.text orelse window.ctx.allocator.dupe(u8, "") catch null;
}

/// HTML "prompt to unload" a document whose beforeunload asked for it: the
/// beforeunload dialog, paused on; true when the user chose to stay
/// (unloading is canceled).
pub fn promptToUnload(window: *runtime.Instance) bool {
    // The beforeunload steps checked the sandboxed modals flag themselves;
    // the termination nesting level is no condition of this prompt.
    const answer = show(window.ctx.allocator, window, .beforeunload, "", "");
    if (answer.text) |t| window.ctx.allocator.free(t);
    return !answer.accepted;
}

/// The printing steps for `document` (8.9.2): beforeprint at its relevant
/// global and its child navigables' windows, the platform's print dialog
/// paused on, then afterprint.
pub fn printingSteps(document: *runtime.Instance) void {
    // 1. (Crane displays nothing of its own.)
    // 2. The sandboxed modals flag: no dialog, no events.
    if (dom.document_scripts.activeSandboxingFlags(document).modals) return;
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return;
    // 3. beforeprint at the document's relevant global and its children's.
    fireAtTree(document, "beforeprint");
    // 4. Offer a physical form, and pause while the user decides.
    if (platform.capabilities.printing != .unsupported) {
        if (platform_state.of(window.ctx)) |browser| {
            if (window.ctx.browserScope()) |scope| if (scope.of(runtime.BrowserPause)) |pause| {
                var parts = (platform_state.requester(window.ctx, user_activation.hasTransientActivation(window)) catch null);
                if (parts) |*p| {
                    defer p.deinit();
                    const printing = window.ctx.allocator.create(PrintReply) catch null;
                    if (printing) |reply| {
                        reply.* = .{ .pause = pause, .allocator = window.ctx.allocator };
                        reply.refs.store(2, .monotonic);
                        const requester = p.requester();
                        platform.printDocument(browser, &requester, .{ .context = reply, .deliver = PrintReply.deliver, .drop = PrintReply.drop });
                        pause.pauseUntil(.{ .context = reply, .met = PrintReply.met }, .dialog);
                        reply.release();
                    }
                }
            } else |_| {};
        }
    }
    // 5. afterprint.
    fireAtTree(document, "afterprint");
}

/// The print dialog's answer, shared by the pause and the platform's Reply.
const PrintReply = struct {
    pause: *runtime.BrowserPause,
    allocator: Allocator,
    done: std.atomic.Value(bool) = .init(false),
    refs: std.atomic.Value(u32) = .init(0),

    fn met(context: *anyopaque) bool {
        const self: *PrintReply = @ptrCast(@alignCast(context));
        return self.done.load(.acquire);
    }

    fn finish(self: *PrintReply) void {
        self.done.store(true, .release);
        self.pause.notify();
        self.release();
    }

    fn release(self: *PrintReply) void {
        if (self.refs.fetchSub(1, .acq_rel) == 1) self.allocator.destroy(self);
    }

    fn deliver(context: *anyopaque, value: *const platform.Unit) callconv(.c) void {
        _ = value;
        finish(@ptrCast(@alignCast(context)));
    }

    fn drop(context: *anyopaque) callconv(.c) void {
        finish(@ptrCast(@alignCast(context)));
    }
};

/// Fire `event_type` at `document`'s relevant global and at each child
/// navigable's active window, parents first.
fn fireAtTree(document: *runtime.Instance, comptime event_type: []const u8) void {
    var documents = dom.navigables.inclusiveDescendantDocuments(document, std.heap.page_allocator);
    defer documents.deinit(std.heap.page_allocator);
    for (documents.items) |entry| {
        if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
        const window = (interfaces.Document.get_defaultView(entry.document) catch null) orelse continue;
        dom.navigables.fireSimpleEvent(window, event_type);
    }
}

test "newlines are normalized: CR LF and lone CR become LF" {
    const out = try normalizeNewlines(std.testing.allocator, "a\r\nb\rc\nd");
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("a\nb\nc\nd", out);
}

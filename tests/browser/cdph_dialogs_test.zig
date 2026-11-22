//! Simple dialogs and printing through HTML 8.9.1-8.9.2 (lane cdph):
//! alert/confirm/prompt answered by the platform when no host claims them
//! (headless: "cannot show" - alert returns, confirm false, prompt null, as
//! before), or by a host that claimed the dialog as it opened, from another
//! thread, while the Browser's thread is paused on it; the opening and
//! closing told to the host (WebDriver BiDi user prompt opened/closed);
//! beforeunload's prompt to unload; print()'s beforeprint/afterprint and its
//! print-when-loaded flag.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const BrowserHost = browser_mod.BrowserHost;
const host_events = browser_mod.host_events;

/// A poisoning leak-checker (tests/AGENTS.md: never a bare std.heap.DebugAllocator).
const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true, .stack_trace_frames = 0 });

fn evaluateString(browser: *Browser, script: []const u8) ![]u8 {
    const ctx = browser.current_context orelse return error.NoContext;
    return ctx.evaluateScriptToString(script, testing.allocator);
}

test "with no host claiming a dialog, the platform answers: alert returns, confirm is false, prompt is null" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "http://example.test/" });
    const result = try evaluateString(browser, "alert('a'); [confirm('c'), prompt('p', 'd')].join('|')");
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("false|null", result);
}

/// A host on the Browser's thread that claims every dialog and records what
/// it heard; the test thread answers.
const Claimer = struct {
    opened: std.atomic.Value(u32) = .init(0),
    closed: std.atomic.Value(u32) = .init(0),
    last_kind: std.atomic.Value(u8) = .init(0),
    closed_accepted: std.atomic.Value(bool) = .init(false),

    fn listener(self: *Claimer) host_events.Listener {
        return .{ .context = self, .on_event = onEvent };
    }

    fn onEvent(context: *anyopaque, event: *const host_events.Event) void {
        const self: *Claimer = @ptrCast(@alignCast(context));
        switch (event.*) {
            .dialog_opening => |opening| {
                opening.claim.* = true;
                self.last_kind.store(@backingInt(opening.kind), .release);
                _ = self.opened.fetchAdd(1, .acq_rel);
                // The test thread waits on the count (waitForPrompt).
                testing.io.futexWake(u32, &self.opened.raw, std.math.maxInt(u32));
            },
            .dialog_closed => |closed| {
                self.closed_accepted.store(closed.accepted, .release);
                _ = self.closed.fetchAdd(1, .acq_rel);
            },
            else => {},
        }
    }

    fn add(ctx: ?*anyopaque, b: *Browser) void {
        const self: *Claimer = @ptrCast(@alignCast(ctx.?));
        b.addListener(self.listener()) catch {};
    }

    fn remove(ctx: ?*anyopaque, b: *Browser) void {
        const self: *Claimer = @ptrCast(@alignCast(ctx.?));
        b.removeListener(self.listener());
    }
};

/// Wait (5 s) until `claimer` has heard a dialog open - its listener wakes
/// the count it bumps, no polling - then the open dialog's info.
fn waitForPrompt(host: *BrowserHost, claimer: *Claimer, allocator: std.mem.Allocator) !host_events.UserPromptInfo {
    var tries: u32 = 0;
    while (claimer.opened.load(.acquire) == 0) : (tries += 1) {
        if (tries == 50) return error.Timeout;
        const timeout: std.Io.Timeout = .{ .duration = .{ .raw = .fromMilliseconds(100), .clock = .awake } };
        testing.io.futexWaitTimeout(u32, &claimer.opened.raw, 0, timeout) catch {};
    }
    // Opened is told before the Browser's thread pauses, with the prompt
    // already recorded (simple_dialogs.show: begin, then the hook).
    return (try host.userPromptOf(allocator)) orelse error.NoPrompt;
}

test "a claimed prompt pauses the Browser's thread until a host answers it from another thread" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    var claimer: Claimer = .{};
    try host.call(&claimer, Claimer.add);
    defer host.call(&claimer, Claimer.remove) catch {};

    const tab = try host.createTab(.{});
    // The script opens a prompt: the evaluation ends with the dialog open
    // (the Browser's thread is paused on it).
    try testing.expectError(error.UserPromptOpen, host.evaluate(allocator, tab, "globalThis.answer = prompt('Your name?', 'nobody')", .{}, 5_000));
    const info = try waitForPrompt(host, &claimer, allocator);
    defer info.deinit(allocator);
    try testing.expectEqual(tab, info.tab);
    try testing.expectEqualStrings("Your name?", info.message);
    try testing.expectEqualStrings("nobody", info.default_prompt);
    try testing.expect(host.answerUserPrompt(tab, true, "Crane"));
    // Answered once: a second answer finds nothing open.
    try testing.expect(!host.answerUserPrompt(tab, false, ""));

    const answer = try host.evaluate(allocator, tab, "answer", .{}, 5_000);
    defer answer.deinit(allocator);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"Crane\"}", answer.json);
    try testing.expectEqual(@as(u32, 1), claimer.opened.load(.acquire));
    try testing.expectEqual(@as(u32, 1), claimer.closed.load(.acquire));
    try testing.expect(claimer.closed_accepted.load(.acquire));
}

test "a claimed confirm answered cancel is false; newlines in its message are normalized" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    var claimer: Claimer = .{};
    try host.call(&claimer, Claimer.add);
    defer host.call(&claimer, Claimer.remove) catch {};
    const tab = try host.createTab(.{});

    try testing.expectError(error.UserPromptOpen, host.evaluate(allocator, tab, "globalThis.ok = confirm('one\\r\\ntwo')", .{}, 5_000));
    const info = try waitForPrompt(host, &claimer, allocator);
    defer info.deinit(allocator);
    try testing.expectEqualStrings("one\ntwo", info.message);
    try testing.expect(host.answerUserPrompt(tab, false, ""));
    const ok = try host.evaluate(allocator, tab, "ok", .{}, 5_000);
    defer ok.deinit(allocator);
    try testing.expectEqualStrings("{\"type\":\"boolean\",\"value\":false}", ok.json);
}

test "a dialog opened from beforeunload, pagehide or unload is not shown" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML(
        \\<!doctype html><script>
        \\addEventListener('pagehide', () => { localStorage.seen = String(confirm('stay?')); });
        \\</script>
    , .{ .base_url = "http://example.test/a.html" });
    try browser.navigateWithOptions("about:blank", .window, .{ .skip_load = true });
    try browser.current_context.?.loadHTML("<!doctype html>", .{ .base_url = "http://example.test/b.html" });
    const seen = try evaluateString(browser, "localStorage.seen");
    defer testing.allocator.free(seen);
    // Cannot show simple dialogs while the termination nesting level is
    // nonzero: confirm returned false at once.
    try testing.expectEqualStrings("false", seen);
}

test "print() fires beforeprint and afterprint, and waits for the load when called before it" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    try browser.current_context.?.loadHTML(
        \\<!doctype html><script>
        \\globalThis.log = [];
        \\addEventListener('beforeprint', () => log.push('before:' + document.readyState));
        \\addEventListener('afterprint', () => log.push('after'));
        \\print();
        \\log.push('called');
        \\</script>
    , .{ .base_url = "http://example.test/print.html" });
    try browser.runEventLoop(200);
    // Not ready for post-load tasks when called: the print when loaded flag;
    // "the end" step 12 ran the printing steps.
    const log_text = try evaluateString(browser, "log.join(',')");
    defer testing.allocator.free(log_text);
    try testing.expect(std.mem.startsWith(u8, log_text, "called,before:"));
    try testing.expect(std.mem.endsWith(u8, log_text, ",after"));
    // Called after the load: at once.
    const now = try evaluateString(browser, "log = []; print(); log.join(',')");
    defer testing.allocator.free(now);
    try testing.expectEqualStrings("before:complete,after", now);
}

/// A host on the Browser's thread that claims every dialog and answers it
/// as it opens - accept: "leave" for a prompt to unload - counting the
/// prompts to unload (a DialogAnswer may be called from the callback).
const Answerer = struct {
    beforeunload: std.atomic.Value(u32) = .init(0),

    fn listener(self: *Answerer) host_events.Listener {
        return .{ .context = self, .on_event = onEvent };
    }

    fn onEvent(context: *anyopaque, event: *const host_events.Event) void {
        const self: *Answerer = @ptrCast(@alignCast(context));
        switch (event.*) {
            .dialog_opening => |opening| {
                opening.claim.* = true;
                if (opening.kind == .beforeunload) _ = self.beforeunload.fetchAdd(1, .acq_rel);
                _ = opening.answer.call(true, "");
            },
            else => {},
        }
    }

    fn add(ctx: ?*anyopaque, b: *Browser) void {
        const self: *Answerer = @ptrCast(@alignCast(ctx.?));
        b.addListener(self.listener()) catch {};
    }

    fn remove(ctx: ?*anyopaque, b: *Browser) void {
        const self: *Answerer = @ptrCast(@alignCast(ctx.?));
        b.removeListener(self.listener());
    }
};

test "a frame's navigation prompts to unload once for its document and its child's (one unloadPromptShown per check)" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    var answerer: Answerer = .{};
    try host.call(&answerer, Answerer.add);
    defer host.call(&answerer, Answerer.remove) catch {};
    const tab = try host.createTab(.{});

    // A frame whose document has a frame of its own, both same origin with
    // the page (srcdoc), each with a beforeunload handler that asks.
    const built = try host.evaluate(allocator, tab,
        \\globalThis.outer = document.createElement('iframe');
        \\outer.srcdoc = '<iframe srcdoc="<p>inner</p>"></iframe>';
        \\new Promise((resolve) => { outer.onload = resolve; document.body.append(outer); }).then(() => {
        \\  const ask = (e) => e.preventDefault();
        \\  outer.contentWindow.addEventListener('beforeunload', ask);
        \\  outer.contentWindow.frames[0].addEventListener('beforeunload', ask);
        \\  globalThis.navigated = new Promise((resolve) => { outer.onload = () => resolve(outer.contentDocument.body.textContent); });
        \\  return outer.contentWindow.frames.length;
        \\})
    , .{ .await_promise = true }, 5_000);
    defer built.deinit(allocator);
    try testing.expectEqualStrings("{\"type\":\"number\",\"value\":1}", built.json);
    // A user's activation reaches the page and its same-origin frames (HTML
    // "activation notification" step 4): both documents have sticky
    // activation, so both handlers' asks may be shown.
    const activated = try host.evaluate(allocator, tab, "1", .{ .user_activation = true }, 5_000);
    defer activated.deinit(allocator);

    // Navigate the outer frame: navigate step 24.1 checks if unloading is
    // canceled for its document and its child's. The outer's handler shows
    // the prompt (answered "leave"); the inner's is told one was shown
    // (steps to fire beforeunload step 6: unloadPromptShown is false) and
    // shows none. The prompt ends the evaluation waiting on the tab.
    try testing.expectError(error.UserPromptOpen, host.evaluate(allocator, tab, "outer.srcdoc = '<p>next</p>'; navigated", .{ .await_promise = true }, 5_000));
    const next = try host.evaluate(allocator, tab, "navigated", .{ .await_promise = true }, 5_000);
    defer next.deinit(allocator);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"next\"}", next.json);
    try testing.expectEqual(@as(u32, 1), answerer.beforeunload.load(.acquire));
}

test "a traversal that takes two frames to other documents prompts to unload once (one unloadPromptShown per check)" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    var answerer: Answerer = .{};
    try host.call(&answerer, Answerer.add);
    defer host.call(&answerer, Answerer.remove) catch {};
    const tab = try host.createTab(.{});

    // Two same-origin frames (srcdoc), each then navigated once (a new
    // session history step each), each new document with a beforeunload
    // handler that asks.
    const built = try host.evaluate(allocator, tab,
        \\const frame = (text) => new Promise((resolve) => { const f = document.createElement('iframe'); f.srcdoc = text; f.onload = () => resolve(f); document.body.append(f); });
        \\const renavigate = (f, text) => new Promise((resolve) => { f.onload = () => resolve(f); f.srcdoc = text; });
        \\(async () => {
        \\  globalThis.A = await frame('<p>a1</p>');
        \\  globalThis.B = await frame('<p>b1</p>');
        \\  await renavigate(A, '<p>a2</p>');
        \\  await renavigate(B, '<p>b2</p>');
        \\  const ask = (e) => e.preventDefault();
        \\  A.contentWindow.addEventListener('beforeunload', ask);
        \\  B.contentWindow.addEventListener('beforeunload', ask);
        \\  const a2 = A.contentDocument, b2 = B.contentDocument;
        \\  globalThis.restored = () => new Promise((resolve) => { const check = () => (A.contentDocument !== a2 && B.contentDocument !== b2) ? resolve('restored') : setTimeout(check, 10); check(); });
        \\  return history.length;
        \\})()
    , .{ .await_promise = true }, 5_000);
    defer built.deinit(allocator);
    try testing.expectEqualStrings("{\"type\":\"number\",\"value\":3}", built.json);
    const activated = try host.evaluate(allocator, tab, "1", .{ .user_activation = true }, 5_000);
    defer activated.deinit(allocator);

    // Back two steps: both frames cross documents ("apply the history step"
    // step 4's navigablesCrossingDocuments), the page does not, so "check if
    // unloading is canceled" fires beforeunload at both in step 7 with one
    // unloadPromptShown: A's prompt ("leave"), none for B.
    try testing.expectError(error.UserPromptOpen, host.evaluate(allocator, tab, "history.go(-2); restored()", .{ .await_promise = true }, 5_000));
    const back = try host.evaluate(allocator, tab, "restored()", .{ .await_promise = true }, 5_000);
    defer back.deinit(allocator);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"restored\"}", back.json);
    try testing.expectEqual(@as(u32, 1), answerer.beforeunload.load(.acquire));
}

test "a beforeunload handler with sticky activation asks the user; a claimed prompt answered 'stay' cancels the close" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    var claimer: Claimer = .{};
    try host.call(&claimer, Claimer.add);
    defer host.call(&claimer, Claimer.remove) catch {};
    const tab = try host.createTab(.{});
    // A user's activation (BiDi userActivation), then a handler that asks.
    const armed = try host.evaluate(allocator, tab, "addEventListener('beforeunload', (e) => e.preventDefault()); 1", .{ .user_activation = true }, 5_000);
    defer armed.deinit(allocator);

    const Closer = struct {
        host: *BrowserHost,
        tab: u64,
        result: anyerror!void = {},
        fn run(self: *@This()) void {
            self.result = self.host.closeTab(self.tab, .{ .prompt_unload = true });
        }
    };
    var closer: Closer = .{ .host = host, .tab = tab };
    const thread = try std.Thread.spawn(.{}, Closer.run, .{&closer});
    const info = try waitForPrompt(host, &claimer, allocator);
    defer info.deinit(allocator);
    try testing.expectEqual(@as(u8, @backingInt(host_events.DialogKind.beforeunload)), claimer.last_kind.load(.acquire));
    // "Stay on the page": the close is canceled.
    try testing.expect(host.answerUserPrompt(tab, false, ""));
    thread.join();
    try testing.expectError(error.CloseCanceled, closer.result);
}

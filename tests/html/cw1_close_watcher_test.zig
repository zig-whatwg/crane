//! Lane closewatch1: HTML 6.10's close watcher manager, through the
//! CloseWatcher interface, popovers and the Escape close request.
//!
//! - grouping: close watchers made without an intervening activation share a
//!   group, and one close request closes the whole group, last first
//!   (close-watcher/user-activation/nn-CloseWatcher.html);
//! - an activation lets the next watcher start a group of its own, and a
//!   cancel that prevents the close consumes history-action activation, so the
//!   next request cannot be prevented (n-activate-preventDefault.html);
//! - a canceled Escape keydown is not a close request (esc-key/keydown.html);
//! - a CloseWatcher script dropped still hears a close request: the manager
//!   keeps it (Blink traces its watchers from LocalDOMWindow), and lets it go
//!   once it closed;
//! - a cancel listener that destroys its watcher, or removes the frame whose
//!   Window owns it, ends the request without a close event and without a
//!   use-after-free (frame-removal.html);
//! - Escape hides a showing popover through its close watcher (HTML 6.12 show
//!   step 15.10);
//! - two Browsers on two threads, each with its own manager.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;

fn openWith(allocator: std.mem.Allocator, body: []const u8) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(body, .{ .base_url = "http://example.test/close-watchers" });
    _ = try browser.runEventLoopBlocking(20);
    try run(browser,
        \\globalThis.events = [];
        \\globalThis.record = (watcher, name) => {
        \\  watcher.addEventListener('cancel', e => events.push(name + ' cancel[' + e.cancelable + ']'));
        \\  watcher.addEventListener('close', () => events.push(name + ' close'));
        \\  return watcher;
        \\};
    );
    return browser;
}

fn open() !*browser_mod.Browser {
    return openWith(testing.allocator, "<!doctype html><body></body>");
}

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    page.runScript(source) catch |err| {
        std.debug.print("script failed: {s}\n", .{source});
        return err;
    };
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const value = try browser.evaluateScript(source);
    defer value.release();
    if (!engine.toBoolean(browser.getRealm().?, value.borrow())) {
        const page = browser.current_context orelse return error.NoPage;
        const seen = page.evaluateScriptToString("JSON.stringify(events)", testing.allocator) catch null;
        defer if (seen) |text| testing.allocator.free(text);
        std.debug.print("expected true: {s} (events: {s})\n", .{ source, seen orelse "?" });
        return error.TestExpectedTrue;
    }
}

fn document(browser: *browser_mod.Browser) !*runtime.Instance {
    const page = browser.current_context orelse return error.NoPage;
    return page.document_instance orelse error.NoDocument;
}

/// A user's Escape key press: keydown, then keyup.
fn escape(browser: *browser_mod.Browser) !void {
    var keyboard: html.user_input.Keyboard = .{};
    const doc = try document(browser);
    const key: html.user_input.Key = .{ .key = "Escape", .code = "Escape", .key_code = 27 };
    html.user_input.keyDown(&keyboard, doc, key, .{});
    html.user_input.keyUp(&keyboard, doc, key, .{});
}

/// An activation notification, as an activation-triggering input event makes.
fn activate(browser: *browser_mod.Browser) !void {
    html.user_activation.notifyActivation(try document(browser));
}

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
}

fn watchersWithoutActivationShareAGroup() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, "record(new CloseWatcher(), 'a'); record(new CloseWatcher(), 'b');");
    try escape(browser);
    try expectTrue(browser, "events.join() === 'b cancel[false],b close,a cancel[false],a close'");
    // Nothing left to close.
    try run(browser, "events.length = 0;");
    try escape(browser);
    try expectTrue(browser, "events.length === 0");
}

test "close watchers made without activation share a group that one close request closes" {
    try onFreshThread(watchersWithoutActivationShareAGroup);
}

fn activationAllowsANewGroupAndPreventingConsumesIt() !void {
    const browser = try open();
    defer browser.deinit();
    try activate(browser);
    try run(browser,
        \\globalThis.a = record(new CloseWatcher(), 'a');
        \\a.addEventListener('cancel', e => e.preventDefault());
    );
    try activate(browser);
    try run(browser, "record(new CloseWatcher(), 'b');");
    // b has a group of its own: only b closes, and it could have been
    // prevented.
    try escape(browser);
    try expectTrue(browser, "events.join() === 'b cancel[true],b close'");
    // a prevents its close while the page has history-action activation...
    try run(browser, "events.length = 0;");
    try escape(browser);
    try expectTrue(browser, "events.join() === 'a cancel[true]'");
    // ...which that consumed: the next request cannot be prevented.
    try run(browser, "events.length = 0;");
    try escape(browser);
    try expectTrue(browser, "events.join() === 'a cancel[false],a close'");
}

test "an activation lets the next close watcher start a group, and a prevented cancel consumes history-action activation" {
    try onFreshThread(activationAllowsANewGroupAndPreventingConsumesIt);
}

fn canceledEscapeKeydownIsNoCloseRequest() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\record(new CloseWatcher(), 'a');
        \\globalThis.cancelKeys = e => e.preventDefault();
        \\document.addEventListener('keydown', cancelKeys);
    );
    try escape(browser);
    try expectTrue(browser, "events.length === 0");
    try run(browser, "document.removeEventListener('keydown', cancelKeys);");
    try escape(browser);
    try expectTrue(browser, "events.join() === 'a cancel[false],a close'");
}

test "a canceled Escape keydown does not close a close watcher" {
    try onFreshThread(canceledEscapeKeydownIsNoCloseRequest);
}

fn droppedWatcherStillCloses() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.weak = (() => {
        \\  const watcher = new CloseWatcher();
        \\  watcher.onclose = () => events.push('closed');
        \\  return new WeakRef(watcher);
        \\})();
        \\0;
    );
    _ = try browser.runEventLoopBlocking(1);
    // No script reference: the manager keeps the active watcher.
    try collect(browser);
    try expectTrue(browser, "weak.deref() !== undefined");
    _ = try browser.runEventLoopBlocking(1);
    try escape(browser);
    try expectTrue(browser, "events.join() === 'closed'");
    // Closed, it is destroyed: nothing keeps it now.
    _ = try browser.runEventLoopBlocking(1);
    try collect(browser);
    try expectTrue(browser, "weak.deref() === undefined");
}

test "a CloseWatcher script dropped still closes on a close request, then is collectable" {
    try onFreshThread(droppedWatcherStillCloses);
}

fn cancelListenerEndsTheRequest() !void {
    const browser = try open();
    defer browser.deinit();
    // The cancel listener destroys the watcher: no close event.
    try run(browser,
        \\const destroyed = record(new CloseWatcher(), 'd');
        \\destroyed.oncancel = () => destroyed.destroy();
        \\destroyed.requestClose();
        \\if (events.join() !== 'd cancel[true]') throw new Error('destroy in cancel: ' + events.join());
        \\events.length = 0;
    );
    // The cancel listener removes the frame whose Window owns the watcher:
    // its document is no longer fully active, so no close event.
    try run(browser,
        \\globalThis.frame = document.createElement('iframe');
        \\document.body.append(frame);
    );
    _ = try browser.runEventLoopBlocking(50);
    try run(browser,
        \\const framed = record(new frame.contentWindow.CloseWatcher(), 'f');
        \\framed.oncancel = () => frame.remove();
        \\framed.requestClose();
        \\if (events.join() !== 'f cancel[true]') throw new Error('frame removal in cancel: ' + events.join());
    );
    _ = try browser.runEventLoopBlocking(20);
}

test "a cancel listener that destroys its watcher or removes its frame ends the request" {
    try onFreshThread(cancelListenerEndsTheRequest);
}

fn escapeHidesAShowingPopover() !void {
    const browser = try openWith(testing.allocator, "<!doctype html><body><div id=p popover></div></body>");
    defer browser.deinit();
    try run(browser,
        \\globalThis.popover = document.getElementById('p');
        \\popover.addEventListener('beforetoggle', e => events.push('before ' + e.newState));
        \\popover.showPopover();
    );
    _ = try browser.runEventLoopBlocking(20);
    try run(browser, "events.length = 0;");
    try escape(browser);
    try expectTrue(browser, "!popover.matches(':popover-open') && events.join() === 'before closed'");
}

test "Escape hides a showing popover through its close watcher" {
    try onFreshThread(escapeHidesAShowingPopover);
}

fn closeWatcherOnItsOwnBrowser(failure: *?anyerror) void {
    closeWatcherOnItsOwnBrowserInner() catch |err| {
        failure.* = err;
    };
}

fn closeWatcherOnItsOwnBrowserInner() !void {
    // Each Browser its own leak-checking allocator (AGENTS.md: the shared
    // test allocator makes two Browsers take turns).
    var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer if (debug_allocator.deinit() == .leak) @panic("leak");
    const browser = try openWith(debug_allocator.allocator(), "<!doctype html><body></body>");
    defer browser.deinit();
    var round: usize = 0;
    while (round < 5) : (round += 1) {
        try run(browser, "events.length = 0; record(new CloseWatcher(), 'a'); record(new CloseWatcher(), 'b');");
        try escape(browser);
        try expectTrue(browser, "events.join() === 'b cancel[false],b close,a cancel[false],a close'");
    }
}

test "two Browsers on two threads each have their own close watcher manager" {
    var failures: [2]?anyerror = .{ null, null };
    var threads: [2]std.Thread = undefined;
    for (&threads, &failures) |*thread, *failure| thread.* = try std.Thread.spawn(.{}, closeWatcherOnItsOwnBrowser, .{failure});
    for (threads) |thread| thread.join();
    for (failures) |failure| if (failure) |err| return err;
}

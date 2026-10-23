//! Lane closewatch1: the dialog element's close watcher (HTML 4.11.4 "set
//! the dialog close watcher", the dialog setup and cleanup steps, "request
//! to close" a dialog) and its queued events (queue a dialog toggle event
//! task; close the dialog step 13's close event), on the close watcher
//! manager and node_holds.ElementTask.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const runtime = @import("runtime");
const dom = @import("dom");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><dialog id=d>hello</dialog><button id=b commandfor=d command=request-close value=fromButton></button></body>", .{ .base_url = "http://example.test/dialogs" });
    _ = try browser.runEventLoopBlocking(20);
    try run(browser,
        \\globalThis.events = [];
        \\globalThis.dialog = document.getElementById('d');
        \\dialog.addEventListener('cancel', e => events.push('cancel[' + e.cancelable + ']'));
        \\dialog.addEventListener('close', () => events.push('close'));
        \\dialog.addEventListener('toggle', e => events.push('toggle ' + e.oldState + '>' + e.newState));
    );
    return browser;
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

fn escape(browser: *browser_mod.Browser) !void {
    var keyboard: html.user_input.Keyboard = .{};
    const page = browser.current_context orelse return error.NoPage;
    const document = page.document_instance orelse return error.NoDocument;
    const key: html.user_input.Key = .{ .key = "Escape", .code = "Escape", .key_code = 27 };
    html.user_input.keyDown(&keyboard, document, key, .{});
    html.user_input.keyUp(&keyboard, document, key, .{});
}

fn turn(browser: *browser_mod.Browser) !void {
    _ = try browser.runEventLoopBlocking(20);
}

fn books(browser: *browser_mod.Browser) !*dom.node_holds.ElementTasks {
    return dom.node_holds.ElementTasks.existingOf(browser.getRealm().?) orelse error.NoElementTasks;
}

fn escapeClosesAModalDialog() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, "dialog.showModal();");
    try turn(browser);
    try run(browser, "events.length = 0;");
    try escape(browser);
    // The close event is queued on the user interaction task source.
    try expectTrue(browser, "!dialog.open && events.join() === 'cancel[false]'");
    try turn(browser);
    try expectTrue(browser, "events.join() === 'cancel[false],toggle open>closed,close'");
    // Closed: the watcher is gone, so another Escape does nothing.
    try run(browser, "events.length = 0;");
    try escape(browser);
    try turn(browser);
    try expectTrue(browser, "events.length === 0");
    const tasks = try books(browser);
    try testing.expectEqual(tasks.holds_taken, tasks.holds_released);
}

test "Escape closes a modal dialog through its close watcher, with queued toggle and close events" {
    try onFreshThread(escapeClosesAModalDialog);
}

fn requestCloseCanBePrevented() !void {
    const browser = try open();
    defer browser.deinit();
    // requestClose() asks with requireHistoryActionActivation false: the
    // cancel event is cancelable, and preventing it keeps the dialog open.
    try run(browser,
        \\dialog.showModal();
        \\const prevent = e => e.preventDefault();
        \\dialog.addEventListener('cancel', prevent, { once: true });
        \\events.length = 0;
        \\dialog.requestClose('kept');
        \\if (!dialog.open) throw new Error('a prevented requestClose closed the dialog');
        \\if (dialog.returnValue !== '') throw new Error('returnValue set by a prevented request');
        \\dialog.requestClose('done');
        \\if (dialog.open) throw new Error('requestClose did not close');
        \\if (dialog.returnValue !== 'done') throw new Error('returnValue ' + dialog.returnValue);
    );
    try turn(browser);
    // The showModal toggle task had not run: the close's coalesces with it.
    try expectTrue(browser, "events.join() === 'cancel[true],cancel[true],toggle closed>closed,close'");
}

test "requestClose fires a cancelable cancel, honours preventDefault, and closes with its return value" {
    try onFreshThread(requestCloseCanBePrevented);
}

fn nonModalAndClosedByNone() !void {
    const browser = try open();
    defer browser.deinit();
    // A non-modal dialog's watcher is disabled (computed closed-by None):
    // Escape leaves it open, but requestClose force-enables it.
    try run(browser, "dialog.show();");
    try turn(browser);
    try run(browser, "events.length = 0;");
    try escape(browser);
    try turn(browser);
    try expectTrue(browser, "dialog.open && events.length === 0");
    try run(browser, "dialog.requestClose(); if (dialog.open) throw new Error('requestClose left a non-modal dialog open');");
    try turn(browser);
    try expectTrue(browser, "events.join() === 'cancel[true],toggle open>closed,close'");
    // closedby=none on a modal dialog: Escape is ignored.
    try run(browser, "events.length = 0; dialog.setAttribute('closedby', 'none'); dialog.showModal();");
    try turn(browser);
    try run(browser, "events.length = 0;");
    try escape(browser);
    try turn(browser);
    try expectTrue(browser, "dialog.open && events.length === 0");
    try run(browser, "dialog.close();");
    try turn(browser);
}

test "a non-modal or closedby=none dialog ignores Escape but requestClose still closes" {
    try onFreshThread(nonModalAndClosedByNone);
}

fn removalDestroysTheWatcherAndTogglesCoalesce() !void {
    const browser = try open();
    defer browser.deinit();
    // showModal then close in one job: one coalesced toggle event.
    try run(browser, "dialog.showModal(); dialog.close(); dialog.showModal();");
    try turn(browser);
    // The close event task was queued before the last toggle task.
    try expectTrue(browser, "events.join() === 'close,toggle closed>open'");
    // Removing an open dialog runs its cleanup steps: no watcher is left.
    try run(browser, "events.length = 0; dialog.remove();");
    try escape(browser);
    try turn(browser);
    try expectTrue(browser, "events.length === 0");
    const tasks = try books(browser);
    try testing.expectEqual(tasks.holds_taken, tasks.holds_released);
    try testing.expectEqual(tasks.queued, tasks.ended);
}

test "removing an open dialog destroys its close watcher, and its toggle events coalesce" {
    try onFreshThread(removalDestroysTheWatcherAndTogglesCoalesce);
}

fn commandRequestCloseCarriesItsSource() !void {
    const browser = try open();
    defer browser.deinit();
    // HTML command steps step 3: request to close with the button's
    // optional value and the button as source. The source reaches the
    // events that carry one - beforetoggle and toggle (ToggleEvent.source);
    // cancel and close are plain Events.
    try run(browser,
        \\dialog.addEventListener('beforetoggle', e => events.push('before ' + (e.source ? e.source.id : null)));
        \\dialog.addEventListener('toggle', e => events.push('source ' + (e.source ? e.source.id : null)));
        \\dialog.showModal();
    );
    try turn(browser);
    try run(browser, "events.length = 0; document.getElementById('b').click();");
    try expectTrue(browser, "!dialog.open && dialog.returnValue === 'fromButton' && events.join() === 'cancel[true],before b'");
    try turn(browser);
    try expectTrue(browser, "events.join() === 'cancel[true],before b,toggle open>closed,source b,close'");
    // The IDL requestClose has no source.
    try run(browser, "dialog.showModal();");
    try turn(browser);
    try run(browser, "events.length = 0; dialog.requestClose();");
    try turn(browser);
    try expectTrue(browser, "events.join() === 'cancel[true],before null,toggle open>closed,source null,close'");
}

test "a command button's request-close passes the button as source; requestClose() passes none" {
    try onFreshThread(commandRequestCloseCarriesItsSource);
}

//! The wrapper redesign's P6 for a NODE that holds nodes (tmp/redesign/
//! wrapper-redesign-design.md 4.4 "Holders"; the integrator's (a)): an open
//! modal dialog keeps its previously focused element for script - HTML
//! "close the dialog" focuses it again - and Blink's HTMLDialogElement::Trace
//! visits previously_focused_element_ (Chromium 131.0.6778.0). Crane asks a
//! node holder for what it holds where the walk visits it
//! (NodeBase.traces_held, dom.wrapper_tracing): a dialog in the top layer is
//! held by the top layer's counted hold, so the walk of its document visits
//! it - wrapped by script or not.
//!
//! The dialog is opened and closed natively, so script never wraps it; the
//! saved element is detached and dropped by script, so only the dialog's
//! hold reaches it. With no node edge (P7 deleted them; P6 ran this with
//! runtime.lifetime's test-only `tree_edges` off) its wrapper and expando
//! survive collections while the dialog is open, and go once the dialog
//! closed.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    for (0..3) |_| try engine.runInRealm(realm, Collect.steps, agent);
}

fn holds(page: anytype, source: []const u8) !bool {
    const answer = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(answer);
    const ok = std.mem.eql(u8, answer, "true");
    if (!ok) std.debug.print("does not hold ({s}): {s}\n", .{ answer, source });
    return ok;
}

fn dialogKeepsItsSavedFocus() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><dialog id=d><p>dialog</p></dialog></body>", .{ .base_url = "http://example.test/dialog" });
    const document = page.document_instance orelse return error.NoDocument;
    const dialog = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("d"))) orelse return error.NoDialog;

    try page.runScript(
        \\(() => {
        \\  const f = document.body.appendChild(document.createElement('input'));
        \\  f.wr = 'f';
        \\  f.focus();
        \\  window.ref = new WeakRef(f);
        \\})();
    );
    try testing.expect(try holds(page, "String(document.activeElement === window.ref.deref())"));
    // Opened natively: script never sees the dialog.
    interfaces.HTMLDialogElement.call_showModal(dialog) catch |err| {
        std.debug.print("showModal failed: {s}\n", .{@errorName(err)});
        return err;
    };
    const wrapped_by_opening = engine.hasWrapper(dialog);
    if (wrapped_by_opening) std.debug.print("note: opening the dialog wrapped it\n", .{});
    try testing.expect(try interfaces.HTMLDialogElement.get_open(dialog));
    // The saved element leaves the document; script keeps only the WeakRef.
    try page.runScript("window.ref.deref().remove();");
    try collect(browser);
    try testing.expect(try holds(page, "String(window.ref.deref() !== undefined && window.ref.deref().wr === 'f' && !window.ref.deref().isConnected)"));

    // Closed: the dialog lets the element go (its focusing steps do nothing
    // for an element out of the document), and nothing else reaches it.
    interfaces.HTMLDialogElement.call_close(dialog, .{ .was_passed = false, .value = undefined }) catch |err| {
        std.debug.print("close failed: {s}\n", .{@errorName(err)});
        return err;
    };
    try collect(browser);
    try testing.expect(try holds(page, "String(window.ref.deref() === undefined)"));
}

test "wr6, production since P7 (no node edge): an open modal dialog script never wrapped keeps its detached saved focus's wrapper, and lets it go when closed" {
    try onFreshThread(dialogKeepsItsSavedFocus);
}

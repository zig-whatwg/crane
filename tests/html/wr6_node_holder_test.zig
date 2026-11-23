//! The wrapper redesign's P6 for a NODE that holds nodes (tmp/redesign/
//! wrapper-redesign-design.md 4.4 "Holders"; the integrator's (a)) - as it
//! stands for a dialog's previously focused element since refcount step 7b
//! (lane rc7b): the dialog holds it WEAKLY, as WebKit's HTMLDialogElement
//! (`WeakPtr<Element> m_previouslyFocusedElement`) and Gecko's (`nsWeakPtr
//! mPreviouslyFocusedElement`, reference only) do; Blink traces it. A counted
//! hold was a node holding a node of its own tree - another dialog, or the
//! dialog itself - which the counts could never free once a realm's end
//! stopped freeing whatever counted. HTML "close the dialog" focuses the
//! element only while it is there; an element out of the document could not
//! take focus anyway.
//!
//! The dialog is opened and closed natively, so script never wraps it; the
//! saved element is detached and dropped by script, so nothing keeps it: its
//! wrapper goes with the collections while the dialog is still open, and the
//! dialog's close then focuses nothing and throws nothing.
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
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
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
    // The saved element leaves the document; script keeps only the WeakRef,
    // and the dialog's weak link keeps nothing: the collections take it while
    // the dialog is open.
    try page.runScript("window.ref.deref().remove();");
    try collect(browser);
    _ = try browser.runEventLoopBlocking(10);
    try collect(browser);
    try testing.expect(try holds(page, "String(window.ref.deref() === undefined)"));

    // Closed: no element to give focus back to, and nothing throws.
    interfaces.HTMLDialogElement.call_close(dialog, .{ .was_passed = false, .value = undefined }) catch |err| {
        std.debug.print("close failed: {s}\n", .{@errorName(err)});
        return err;
    };
    try testing.expect(!(try interfaces.HTMLDialogElement.get_open(dialog)));
}

test "wr6, since refcount step 7b: an open modal dialog holds its detached saved focus weakly - its wrapper goes while the dialog is open, and the close focuses nothing" {
    try onFreshThread(dialogKeepsItsSavedFocus);
}

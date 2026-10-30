//! Lane refcount8, refcount step 5i (tmp/plans/refcount-design.md 1.3): a
//! document's registries never count their nodes. Each is raw and
//! unregistered when its node goes, or a WEAK link - and a weak link reads a
//! node of a GARBAGE tree as gone (design 1.4, "weak references see garbage
//! at once"), so once step 7 flags garbage trees no registry can hand one of
//! their nodes back out before its teardown slice frees it. Shadow mode
//! flags no production tree; these tests flag a root by hand (unit tests run
//! the walk: dom.refcount.weak_refs_see_garbage) and pin that each registry
//! reads none, then reads the node again once the flag is gone.
//!
//! And the script lists: raw, each element counted by its queue's execution
//! hold (refcount step 5d) - the pending parsing-blocking script too, which
//! an inline script waiting on a script-blocking style sheet took no hold for.
const std = @import("std");
const h = @import("refcount_holders_helpers.zig");
const dom = h.dom;
const runtime = h.runtime;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn instanceOf(base: *dom.NodeBase) *runtime.Instance {
    return @ptrCast(@alignCast(base.owner_instance.?));
}

fn evaluate(page: h.Page, source: []const u8) ![]u8 {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.evaluateScriptToString(source, std.testing.allocator);
}

fn expectAnswer(page: h.Page, source: []const u8, expected: []const u8) !void {
    const answer = try evaluate(page, source);
    defer std.testing.allocator.free(answer);
    if (!std.mem.eql(u8, answer, expected)) std.debug.print("{s}\n  expected {s}, got {s}\n", .{ source, expected, answer });
    try std.testing.expectEqualStrings(expected, answer);
}

test "unit tests run the weak links' garbage check" {
    try std.testing.expect(dom.refcount.weak_refs_see_garbage);
}

fn targetElementIsWeak() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.p = document.createElement('p'); 0;");
    const p = try page.node("p");
    const document = instanceOf(try page.node("document"));
    dom.target_element.set(document, instanceOf(p));
    try std.testing.expectEqual(@as(?*runtime.Instance, instanceOf(p)), dom.target_element.get(document));
    // `p` is the root of its own (detached) tree: flag it garbage.
    p.rc_flags.garbage = true;
    const while_garbage = dom.target_element.get(document);
    p.rc_flags.garbage = false;
    try std.testing.expect(while_garbage == null);
    try std.testing.expectEqual(@as(?*runtime.Instance, instanceOf(p)), dom.target_element.get(document));
    dom.target_element.set(document, null);
}

test "a document's target element is a weak link: an element of a garbage tree reads as none" {
    try onFreshThread(targetElementIsWeak);
}

fn focusedAreaIsWeak() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.input = document.createElement('input'); 0;");
    const input = try page.node("input");
    const document = instanceOf(try page.node("document"));
    dom.focused_area.set(document, instanceOf(input));
    try std.testing.expect(dom.focused_area.get(document).?.isLive());
    input.rc_flags.garbage = true;
    const while_garbage = dom.focused_area.get(document).?.isLive();
    input.rc_flags.garbage = false;
    try std.testing.expect(!while_garbage);
    try std.testing.expect(dom.focused_area.get(document).?.isLive());
    dom.focused_area.set(document, null);
}

test "a document's focused area is a weak link: an element of a garbage tree is not live" {
    try onFreshThread(focusedAreaIsWeak);
}

fn formNamesAreWeak() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.form = document.createElement('form');
        \\form.innerHTML = '<input name=a>';
        \\globalThis.input = form.a;
        \\input.name = 'b';
        \\0;
    );
    // `form.b` is the named-element cache's candidate; `form.a` the past
    // names map's entry (the element was found under `a` before).
    try expectAnswer(page, "[form.b === input, form.a === input].join()", "true,true");
    const form = try page.node("form");
    form.rc_flags.garbage = true;
    const answer = evaluate(page, "[form.b === input, form.a === input].join()");
    form.rc_flags.garbage = false;
    const while_garbage = try answer;
    defer std.testing.allocator.free(while_garbage);
    try std.testing.expectEqualStrings("false,false", while_garbage);
    try expectAnswer(page, "[form.b === input, form.a === input].join()", "true,true");
}

test "a form's named elements and past names are weak links: a garbage tree's element reads as none" {
    try onFreshThread(formNamesAreWeak);
}

/// Turn the page's event loop until `done` (a script expression) is true.
fn runUntil(page: h.Page, comptime done: []const u8) !void {
    var turns: usize = 0;
    while (turns < 200) : (turns += 1) {
        page.run("if (!(" ++ done ++ ")) throw new Error('not yet');") catch {
            _ = try page.browser.runEventLoopBlocking(10);
            continue;
        };
        return;
    }
    return error.NeverDone;
}

fn pendingInlineScriptIsHeld() !void {
    const browser = try h.browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const context = browser.current_context orelse return error.NoPage;
    // A parser-made style sheet link is script-blocking while it loads; the
    // inline script after it waits as the pending parsing-blocking script
    // (HTML prepare the script element 36.2).
    try context.loadHTML(
        \\<!doctype html><head><link rel=stylesheet href="data:text/css,p%7Bcolor:red%7D"><script>globalThis.ran = 1;</script></head><body></body>
    , .{ .base_url = "about:blank" });
    const page: h.Page = .{ .browser = browser };
    try expectAnswer(page, "String(typeof globalThis.ran)", "undefined");
    try page.run("globalThis.s = document.scripts[0]; 0;");
    const s = try page.node("s");
    // Its wrapper's, and the pending script's execution hold.
    try expectCount(2, s, "the pending parsing-blocking script");
    try runUntil(page, "globalThis.ran === 1");
    try expectCount(1, s, "executed: the hold went with it");
}

test "an inline script waiting on a script-blocking style sheet is held while it is the pending parsing-blocking script" {
    try onFreshThread(pendingInlineScriptIsHeld);
}

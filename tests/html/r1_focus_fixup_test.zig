//! Lane rendering1 B3: the focus fixup's rendering opportunity (HTML update
//! the rendering step 17). This is the SCHEDULING half: with no animation
//! frame callback, no autofocus candidate and no pending CSS, a focused
//! element that stops being focusable gets the rendering opportunity whose
//! fixup designates the viewport. Whether that fixup also fires blur is the
//! fixup's own half (html.focus.focusedAreaOf, Codex row 129): these cases
//! read only the designation (document.activeElement), never a blur.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn pumpUntil(page: helpers.Page, condition: []const u8, turns: usize) !void {
    var turn: usize = 0;
    while (turn < turns) : (turn += 1) {
        _ = try page.browser.runEventLoopBlocking(5);
        const value = try page.evaluate(condition);
        defer std.testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
    }
    const value = try page.evaluate(condition);
    defer std.testing.allocator.free(value);
    std.debug.print("condition never held: {s} -> {s}\n", .{ condition, value });
    return error.ConditionNeverHeld;
}

/// Pump until no rendering opportunity is armed: the frames the page's
/// load asked for (its reveal) have run, so a later fixup frame is the
/// focus's own.
fn settle(page: helpers.Page) !void {
    var turns: usize = 0;
    while (turns < 100) : (turns += 1) {
        _ = try page.browser.runEventLoopBlocking(5);
        if (page.browser.event_loop.?.frames.timer_id == null) return;
    }
    return error.FramesNeverSettled;
}

fn focusRuleHidesTheFocusedElement() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try settle(page);
    // shadow-dom/focus/focus-shadowhost-display-none.html's first case: the
    // change that focuses the host is the one that hides it.
    try page.run(
        \\const style = document.createElement('style');
        \\style.textContent = '#host:focus { display: none }';
        \\document.head.appendChild(style);
        \\globalThis.host = document.body.appendChild(document.createElement('div'));
        \\host.id = 'host';
        \\host.tabIndex = 0;
        \\host.focus();
        \\globalThis.focusedAtOnce = document.activeElement === host;
    );
    const at_once = try page.evaluate("String(focusedAtOnce)");
    defer std.testing.allocator.free(at_once);
    try std.testing.expectEqualStrings("true", at_once);
    // No animation frame was asked for: the fixup's frame comes anyway.
    try pumpUntil(page, "document.activeElement === document.body", 100);
}

test "a :focus rule that hides the focused element gets the fixup's frame without rAF" {
    try helpers.onFreshThread(focusRuleHidesTheFocusedElement);
}

fn disablingTheFocusedElement() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try settle(page);
    try page.run(
        \\globalThis.button = document.body.appendChild(document.createElement('button'));
        \\button.focus();
        \\globalThis.framed = false;
        \\requestAnimationFrame(() => requestAnimationFrame(() => { framed = true; }));
    );
    // The frames the focus asked for have run and found it focusable.
    try pumpUntil(page, "framed && document.activeElement === button", 100);
    // A later mutation makes it unfocusable, with no frame requested by
    // script: the watched document asks for the fixup's frame.
    try page.run("button.disabled = true;");
    try pumpUntil(page, "document.activeElement === document.body", 100);
}

test "disabling the focused element later gets the fixup's frame without rAF" {
    try helpers.onFreshThread(disablingTheFocusedElement);
}

fn idleWithNothingFocused() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.input = document.body.appendChild(document.createElement('input'));
        \\input.focus();
        \\input.blur();
    );
    var turns: usize = 0;
    while (turns < 10) : (turns += 1) _ = try page.browser.runEventLoopBlocking(20);
    // Mutations of a document with nothing focused ask for no frame.
    try page.run("for (let i = 0; i < 100; i++) document.body.appendChild(document.createElement('p'));");
    const loop = page.browser.event_loop.?;
    try std.testing.expect(loop.frames.timer_id == null);
}

test "mutations of a document with nothing focused ask for no frame" {
    try helpers.onFreshThread(idleWithNothingFocused);
}

fn watchArmsFiresOnceAndRestsUnarmed() !void {
    const dom = @import("dom");
    const page = try helpers.Page.open();
    defer page.close();
    try settle(page);
    const document = page.browser.current_context.?.document_instance.?;
    const frames = &page.browser.event_loop.?.frames;
    const counts = dom.refcount.documentCounts(document) orelse return error.NoCounts;
    // Unarmed: nothing focused, a mutation asks for no frame.
    try std.testing.expect(!counts.version.rendering_watch);
    try page.run("document.body.appendChild(document.createElement('p'));");
    try std.testing.expect(!counts.version.rendering_watch);
    try std.testing.expect(frames.timer_id == null);
    // A focused element arms it (and asks for its own frame); let that frame
    // run - its fixup finds the element focusable and arms it again.
    try page.run("globalThis.input = document.body.appendChild(document.createElement('input')); input.focus();");
    try std.testing.expect(counts.version.rendering_watch);
    try settle(page);
    try std.testing.expect(counts.version.rendering_watch);
    try std.testing.expectEqual(@as(usize, 0), frames.requests.items.len);
    // The next mutation fires it exactly once: a frame is requested and the
    // bit is spent; further mutations before that frame ask for nothing more.
    const version = dom.refcount.treeVersion(document).?;
    try page.run("document.body.appendChild(document.createElement('p'));");
    try std.testing.expect(!counts.version.rendering_watch);
    try std.testing.expect(frames.timer_id != null);
    try std.testing.expectEqual(@as(usize, 1), frames.requests.items.len);
    try page.run("for (let i = 0; i < 10; i++) document.body.appendChild(document.createElement('p'));");
    try std.testing.expectEqual(@as(usize, 1), frames.requests.items.len);
    try std.testing.expect(dom.refcount.treeVersion(document).? > version);
    // Blurred: the viewport is focused, and the watch rests.
    try page.run("input.blur();");
    try std.testing.expect(!counts.version.rendering_watch);
}

test "the rendering watch arms on a focused element, fires once per frame, and rests unarmed" {
    try helpers.onFreshThread(watchArmsFiresOnceAndRestsUnarmed);
}

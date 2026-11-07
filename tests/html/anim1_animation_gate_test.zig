//! Lane anim1 (C2): the step-16 gate covers CSS animations too
//! (dom.style.engine, tmp/plans/anim1b3-design.md section 7). An animation
//! exists only where animation-name names a @keyframes rule, and
//! animation-name is neither inherited nor animatable, so a document whose
//! sheets and style attributes declare no animation-* (and no transition-*)
//! gets no style update at its rendering opportunities, and a document that
//! declares one does - and its mutations ask for one. Each case starts from
//! a settled loop, so an unrelated frame cannot pass it.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn settle(page: helpers.Page) !void {
    var turns: usize = 0;
    while (turns < 100) : (turns += 1) {
        _ = try page.browser.runEventLoopBlocking(5);
        if (page.browser.event_loop.?.frames.timer_id == null) return;
    }
    return error.FramesNeverSettled;
}

fn styleAttributeOpensTheGate() !void {
    const dom = @import("dom");
    const page = try helpers.Page.open();
    defer page.close();
    try settle(page);
    const document = page.browser.current_context.?.document_instance.?;
    const counts = dom.refcount.documentCounts(document) orelse return error.NoCounts;
    try page.run(
        \\globalThis.div = document.body.appendChild(document.createElement('div'));
        \\getComputedStyle(div).opacity;
    );
    try settle(page);
    try std.testing.expect(!dom.style.engine.declaresAnimations(document));
    try std.testing.expect(!counts.version.rendering_watch);
    try page.run("div.style.animationName = 'spin';");
    try std.testing.expect(dom.style.engine.declaresAnimations(document));
    try std.testing.expect(counts.version.rendering_watch);
    try std.testing.expect(page.browser.event_loop.?.frames.timer_id != null);
}

test "a style attribute that declares an animation opens the gate and watches the document" {
    try helpers.onFreshThread(styleAttributeOpensTheGate);
}

fn sheetOpensTheGate() !void {
    const dom = @import("dom");
    const page = try helpers.Page.open();
    defer page.close();
    try settle(page);
    const document = page.browser.current_context.?.document_instance.?;
    try std.testing.expect(!dom.style.engine.declaresAnimations(document));
    try page.run(
        \\const style = document.createElement('style');
        \\document.head.appendChild(style);
        \\style.sheet.insertRule('@keyframes spin { to { opacity: 0 } }');
        \\style.sheet.insertRule('.spin { animation-name: spin }', 1);
    );
    try std.testing.expect(dom.style.engine.declaresAnimations(document));
}

test "a sheet rule that declares an animation opens the gate" {
    try helpers.onFreshThread(sheetOpensTheGate);
}

fn frameStartsSheetAnimation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try settle(page);
    // An animation declared by a sheet starts at the next rendering
    // opportunity with no style read: the step-16 style update makes it,
    // and its pending play task completes there (start time resolved).
    try page.run(
        \\const style = document.createElement('style');
        \\style.textContent = '@keyframes anim1-gate { to { opacity: 0 } } .anim1-gate { animation: anim1-gate 100s }';
        \\document.head.appendChild(style);
        \\globalThis.div = document.body.appendChild(document.createElement('div'));
        \\div.className = 'anim1-gate';
    );
    // A running animation keeps asking for frames: pump a few turns
    // instead of settling.
    var turns: usize = 0;
    while (turns < 20) : (turns += 1) _ = try page.browser.runEventLoopBlocking(20);
    try page.run(
        \\const animations = div.getAnimations();
        \\if (animations.length !== 1) throw new Error('animations: ' + animations.length);
        \\if (animations[0].startTime === null) throw new Error('the frame did not start it');
    );
}

test "a sheet-declared animation starts at the next rendering opportunity" {
    try helpers.onFreshThread(frameStartsSheetAnimation);
}

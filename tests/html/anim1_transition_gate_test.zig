//! Lane anim1 (C1): the CSS transitions gate of HTML update the rendering
//! step 16 (dom.style.engine, tmp/plans/anim1b2-design.md section 2). Only a
//! document that declares a transition - a sheet or a style attribute - gets
//! the step-16 style update, and only its mutations ask for a rendering
//! opportunity (the lesson "frames on demand need every owner whose state
//! shows at a rendering opportunity to ask for one"): each case starts from a
//! settled loop, so an unrelated frame cannot pass it.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

/// Pump until no rendering opportunity is armed: the frames the page's load
/// asked for (its reveal) have run.
fn settle(page: helpers.Page) !void {
    var turns: usize = 0;
    while (turns < 100) : (turns += 1) {
        _ = try page.browser.runEventLoopBlocking(5);
        if (page.browser.event_loop.?.frames.timer_id == null) return;
    }
    return error.FramesNeverSettled;
}

fn noDeclarationNoFrame() !void {
    const dom = @import("dom");
    const page = try helpers.Page.open();
    defer page.close();
    try settle(page);
    const document = page.browser.current_context.?.document_instance.?;
    try page.run(
        \\globalThis.div = document.body.appendChild(document.createElement('div'));
        \\getComputedStyle(div).opacity;
        \\div.style.opacity = '0.5';
        \\div.setAttribute('style', 'opacity: 0.25; color: green');
    );
    try std.testing.expect(!dom.style.engine.declaresAnimations(document));
    try std.testing.expect(page.browser.event_loop.?.frames.timer_id == null);
}

test "a document that declares no transition gets no step-16 update and asks for no frame" {
    try helpers.onFreshThread(noDeclarationNoFrame);
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
    try std.testing.expect(!counts.version.rendering_watch);
    // CSSOM writes the attribute: "handle attribute changes" sees the value.
    try page.run("div.style.transition = 'opacity 1s';");
    try std.testing.expect(dom.style.engine.declaresAnimations(document));
    try std.testing.expect(counts.version.rendering_watch);
    try std.testing.expect(page.browser.event_loop.?.frames.timer_id != null);
    // After that frame the watch is armed again: the next mutation asks.
    try settle(page);
    try std.testing.expect(counts.version.rendering_watch);
    try page.run("div.style.opacity = '0';");
    try std.testing.expect(page.browser.event_loop.?.frames.timer_id != null);
}

test "a style attribute that declares a transition opens the gate and watches the document" {
    try helpers.onFreshThread(styleAttributeOpensTheGate);
}

fn sheetOpensTheGate() !void {
    const dom = @import("dom");
    const page = try helpers.Page.open();
    defer page.close();
    try settle(page);
    const document = page.browser.current_context.?.document_instance.?;
    try page.run(
        \\const style = document.createElement('style');
        \\document.head.appendChild(style);
        \\style.sheet.insertRule('.fade { transition: opacity 1s }');
    );
    try std.testing.expect(dom.style.engine.declaresAnimations(document));
}

test "a sheet rule that declares a transition opens the gate" {
    try helpers.onFreshThread(sheetOpensTheGate);
}

fn blurKeepsTheWatch() !void {
    const dom = @import("dom");
    const page = try helpers.Page.open();
    defer page.close();
    try settle(page);
    const document = page.browser.current_context.?.document_instance.?;
    const counts = dom.refcount.documentCounts(document) orelse return error.NoCounts;
    try page.run(
        \\globalThis.input = document.body.appendChild(document.createElement('input'));
        \\input.style.transition = 'opacity 1s';
    );
    try settle(page);
    try page.run("input.focus(); input.blur();");
    // One watch, two reasons: the blur drops the focus reason only.
    try std.testing.expect(counts.version.rendering_watch);
}

test "a blur keeps the rendering watch of a document that declares transitions" {
    try helpers.onFreshThread(blurKeepsTheWatch);
}

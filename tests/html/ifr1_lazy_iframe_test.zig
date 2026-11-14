//! Lane ifr1: iframe lazy loading (HTML 2.5.7, "process the iframe
//! attributes" steps 1.2 and 2.6) through the document's lazy load
//! intersection observer (dom.lazy_load_observer), as headless Crane answers
//! it: a frame that is not being rendered intersects nothing, one that is
//! intersects at the next rendering opportunity - and the lifetimes: a lazy
//! frame removed, or its document torn down, while observed leaves nothing
//! behind under std.testing.allocator.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const dom = @import("dom");
const runtime = @import("runtime");

fn pump(page: helpers.Page, turns: usize) !void {
    var turn: usize = 0;
    while (turn < turns) : (turn += 1) _ = try page.browser.runEventLoopBlocking(5);
}

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

fn expectValue(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const value = try page.evaluate(source);
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualStrings(expected, value);
}

fn document(page: helpers.Page) *runtime.Instance {
    return page.browser.current_context.?.document_instance.?;
}

const make_hidden_lazy_frame =
    \\globalThis.loads = 0;
    \\globalThis.frame = document.createElement('iframe');
    \\frame.loading = 'lazy';
    \\frame.hidden = true;
    \\frame.srcdoc = '<p id=p>lazy</p>';
    \\frame.onload = () => loads++;
    \\frame.name = 'lazyframe';
    \\document.body.appendChild(frame);
;

fn hiddenFrameWaitsUntilShown() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(make_hidden_lazy_frame);
    try std.testing.expect(dom.lazy_load_observer.hasTargets(document(page)));
    // Not being rendered: no rendering opportunity loads it.
    try pump(page, 20);
    try expectValue(page, "String(loads)", "0");
    try expectValue(page, "String(frame.contentDocument.getElementById('p'))", "null");
    // Shown: the next rendering opportunity's step 19 runs its resumption
    // steps, which navigate to the srcdoc.
    try page.run("frame.hidden = false");
    try pumpUntil(page, "loads === 1 && frame.contentDocument.getElementById('p') !== null", 400);
    try std.testing.expect(!dom.lazy_load_observer.hasTargets(document(page)));
    // The steps ran once: later frames load nothing more.
    try pump(page, 10);
    try expectValue(page, "String(loads)", "1");
}

test "a lazy iframe that is not being rendered waits, and loads once it is shown" {
    try helpers.onFreshThread(hiddenFrameWaitsUntilShown);
}

fn eagerRunsTheResumptionSteps() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(make_hidden_lazy_frame);
    try pump(page, 5);
    try expectValue(page, "String(loads)", "0");
    // "When the loading attribute's state is changed to the Eager state":
    // the resumption steps run, though the frame is still hidden.
    try page.run("frame.removeAttribute('loading')");
    try std.testing.expect(!dom.lazy_load_observer.hasTargets(document(page)));
    try pumpUntil(page, "loads === 1 && frame.contentDocument.getElementById('p') !== null", 400);
}

test "a lazy iframe set to eager runs its lazy load resumption steps" {
    try helpers.onFreshThread(eagerRunsTheResumptionSteps);
}

fn navigationCancelsTheResumptionSteps() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(make_hidden_lazy_frame);
    try page.run("window.open('about:blank#fragment', 'lazyframe');");
    // Navigate step 11: the frame is no longer observed, and its resumption
    // steps are gone - showing it navigates nothing.
    try std.testing.expect(!dom.lazy_load_observer.hasTargets(document(page)));
    try page.run("frame.hidden = false");
    try pump(page, 20);
    try expectValue(page, "String(frame.contentDocument.getElementById('p'))", "null");
    try expectValue(page, "frame.contentWindow.location.href", "about:blank#fragment");
}

test "navigating a lazy iframe cancels its lazy load resumption steps" {
    try helpers.onFreshThread(navigationCancelsTheResumptionSteps);
}

fn removedFrameIsLetGo() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(make_hidden_lazy_frame);
    try std.testing.expect(dom.lazy_load_observer.hasTargets(document(page)));
    // One check while connected arms the watch; the removal asks for the
    // next, which drops the removed frame.
    try pump(page, 5);
    try page.run("globalThis.weak = new WeakRef(frame); frame.remove(); frame = null;");
    try pump(page, 10);
    try std.testing.expect(!dom.lazy_load_observer.hasTargets(document(page)));
    try page.turn();
    try page.run("collectNow()");
    try page.turn();
    try page.run("if (weak.deref() !== undefined) throw new Error('the removed lazy frame was kept')");
}

test "a lazy iframe removed while observed is dropped and collectable" {
    try helpers.onFreshThread(removedFrameIsLetGo);
}

fn teardownWhileObserved() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(make_hidden_lazy_frame);
    try std.testing.expect(dom.lazy_load_observer.hasTargets(document(page)));
    // Page.close tears the document down with the target in its list and
    // the frame's resumption steps set: std.testing.allocator fails the
    // test if either is left.
}

test "a document torn down while its lazy iframe is observed leaves nothing" {
    try helpers.onFreshThread(teardownWhileObserved);
}

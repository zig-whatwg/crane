//! A select's queued update of its descendant selectedcontent elements: a
//! microtask that holds the select and runs while its update is pending.
const std = @import("std");
const dom = @import("dom");
const html = @import("html");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const helpers = @import("edges_node_holders_helpers.zig");

fn queueAllocationTrial(allocator: std.mem.Allocator, select: *runtime.Instance) anyerror!void {
    try html.forms.selected_content.queueUpdate(allocator, select);
    try engine.performMicrotaskCheckpoint(select.ctx.agent.?);
}

fn queueAllocationFailures() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<select id=s><button><selectedcontent id=c></selectedcontent></button><option>one</option></select>'");
    const document = page.browser.current_context.?.document_instance.?;
    const select = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("s"))).?;
    // A failed queue leaves the pending flag false, so the next trial queues.
    try std.testing.checkAllAllocationFailures(std.testing.allocator, queueAllocationTrial, .{select});
    try std.testing.expect(!dom.form_controls.selectedcontentPending(select));
}

fn queuedAtTeardown() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<select id=s><button><selectedcontent id=c></selectedcontent></button><option>one</option></select>'");
    const document = page.browser.current_context.?.document_instance.?;
    const select = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("s"))).?;
    try html.forms.selected_content.queueUpdate(std.testing.allocator, select);
    // No checkpoint: Browser teardown must drop the job and release the hold.
}

fn capturedNodesSurvive() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<select id=s><button><selectedcontent id=c></selectedcontent></button><option>one</option></select>';
        \\globalThis.selectWeak = new WeakRef(document.getElementById('s'));
        \\globalThis.contentWeak = new WeakRef(document.getElementById('c'));
    );
    try page.turn(); // End WeakRef's creation job before exercising the keeps.
    const document = page.browser.current_context.?.document_instance.?;
    const select = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("s"))).?;
    try html.forms.selected_content.queueUpdate(std.testing.allocator, select);
    try page.run(
        \\document.getElementById('s').remove();
        \\TestUtils.gc();
        \\if (!selectWeak.deref() || !contentWeak.deref()) throw new Error('the queued select or its content was collected');
        \\contentWeak.deref().textContent = 'old';
        \\globalThis.observedCapturedUpdate = false;
        \\queueMicrotask(() => {
        \\  if (contentWeak.deref().textContent !== 'one') throw new Error('the detached select was not updated');
        \\  observedCapturedUpdate = true;
        \\});
    );
    try page.turn();
    try page.run("if (!observedCapturedUpdate) throw new Error('observer microtask did not run')");
}

/// HTML "queue an update of a select's descendant selectedcontent
/// elements": the microtask updates while the select's pending flag is set,
/// and does nothing once an update ran in the meantime.
fn queuedUpdateRunsOnlyWhilePending() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<select id=a><button><selectedcontent id=c></selectedcontent></button><option>one</option><option>two</option></select>';
        \\const a = document.getElementById('a');
        \\const content = document.getElementById('c');
    );
    const document = page.browser.current_context.?.document_instance.?;
    const select = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("a"))).?;
    try html.forms.selected_content.queueUpdate(std.testing.allocator, select);
    try std.testing.expect(dom.form_controls.selectedcontentPending(select));
    // Queued once: a second request while pending queues nothing more.
    try html.forms.selected_content.queueUpdate(std.testing.allocator, select);
    try page.run(
        \\content.textContent = 'seed';
        \\queueMicrotask(() => { if (content.textContent !== 'one') throw new Error('pending update did not run first'); });
    );
    try page.turn();
    try std.testing.expect(!dom.form_controls.selectedcontentPending(select));

    try html.forms.selected_content.queueUpdate(std.testing.allocator, select);
    try page.run(
        \\a.options[1].selected = true;
        \\if (content.textContent !== 'two') throw new Error('selected setter did not update at once');
        \\content.textContent = 'after';
        \\queueMicrotask(() => { if (content.textContent !== 'after') throw new Error('a stale microtask updated'); });
    );
    try page.turn();
    try page.run("if (content.textContent !== 'after') throw new Error('a stale microtask updated later')");
}

fn removedSelectSurvives() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<select id=s><button><selectedcontent></selectedcontent></button><option>one</option><option>two</option></select>';
        \\const content = document.querySelector('selectedcontent');
        \\let select = document.getElementById('s');
        \\select.options[0].remove();
        \\if (select.value !== 'two' || content.textContent !== 'one') throw new Error('removing steps ordering');
        \\select.remove();
        \\select = null;
        \\collectNow();
    );
    try page.turn();
    try page.run("if (content.textContent !== 'two') throw new Error('detached select was not updated after collection')");
}

test "a queued selectedcontent update runs only while the select's update is pending" {
    try helpers.onFreshThread(queuedUpdateRunsOnlyWhilePending);
}

test "selectedcontent update keeps a detached select through collection" {
    try helpers.onFreshThread(removedSelectSurvives);
}

test "selectedcontent continuation frees its allocation on every failure" {
    try helpers.onFreshThread(queueAllocationFailures);
}

test "realm teardown drops a selectedcontent continuation and its captured select" {
    try helpers.onFreshThread(queuedAtTeardown);
}

test "a queued selectedcontent update keeps a removed select and its content through GC" {
    try helpers.onFreshThread(capturedNodesSurvive);
}

//! Option and selectedcontent moving steps update clones in microtasks.
const std = @import("std");
const dom = @import("dom");
const html = @import("html");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const helpers = @import("edges_node_holders_helpers.zig");

fn queueAllocationTrial(allocator: std.mem.Allocator, select: *runtime.Instance, content: *runtime.Instance) anyerror!void {
    if (comptime !@hasDecl(html.forms.selected_content, "queueUpdate")) return error.SelectedcontentMicrotasksNotImplemented;
    try html.forms.selected_content.queueUpdate(allocator, select, content);
    try engine.performMicrotaskCheckpoint(select.ctx.agent.?);
}

fn queueAllocationFailures() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<select id=s><button><selectedcontent id=c></selectedcontent></button><option>one</option></select>'");
    const document = page.browser.current_context.?.document_instance.?;
    const select = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("s"))).?;
    const content = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("c"))).?;
    try std.testing.checkAllAllocationFailures(std.testing.allocator, queueAllocationTrial, .{ select, content });
}

fn queuedAtTeardown() !void {
    if (comptime !@hasDecl(html.forms.selected_content, "queueUpdate")) return error.SelectedcontentMicrotasksNotImplemented;
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<select id=s><button><selectedcontent id=c></selectedcontent></button><option>one</option></select>'");
    const document = page.browser.current_context.?.document_instance.?;
    const select = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("s"))).?;
    const content = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("c"))).?;
    try html.forms.selected_content.queueUpdate(std.testing.allocator, select, content);
    // No checkpoint: Browser teardown must drop the job and release both holds.
}

fn capturedNodesSurvive() !void {
    if (comptime !@hasDecl(html.forms.selected_content, "queueUpdate")) return error.SelectedcontentMicrotasksNotImplemented;
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
    const content = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("c"))).?;
    try html.forms.selected_content.queueUpdate(std.testing.allocator, select, content);
    try page.run(
        \\document.getElementById('c').remove();
        \\document.getElementById('s').remove();
        \\TestUtils.gc();
        \\if (!selectWeak.deref() || !contentWeak.deref()) throw new Error('queued captures were collected');
        \\contentWeak.deref().textContent = 'old';
        \\globalThis.observedCapturedUpdate = false;
        \\queueMicrotask(() => {
        \\  if (contentWeak.deref().textContent !== 'one') throw new Error('captured detached content was not updated');
        \\  observedCapturedUpdate = true;
        \\});
    );
    try page.turn();
    try page.run("if (!observedCapturedUpdate) throw new Error('observer microtask did not run')");
}

fn capturedOrderAndDisabledness() !void {
    if (comptime !@hasDecl(html.forms.selected_content, "queueUpdate")) return error.SelectedcontentMicrotasksNotImplemented;
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<select id=a><button></button><option>one</option></select><select id=b><button></button><option>two</option></select><selectedcontent id=c>seed</selectedcontent>';
        \\const a = document.getElementById('a');
        \\const b = document.getElementById('b');
        \\const content = document.getElementById('c');
    );
    const document = page.browser.current_context.?.document_instance.?;
    const first = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("a"))).?;
    const second = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("b"))).?;
    const content = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("c"))).?;
    try page.run("content.remove()");
    try std.testing.expect(!dom.selected_content.isDisabled(content));
    try html.forms.selected_content.queueUpdate(std.testing.allocator, first, content);
    try page.run(
        \\if (content.textContent !== 'seed') throw new Error('clone changed before checkpoint');
        \\queueMicrotask(() => { if (content.textContent !== 'one') throw new Error('first captured select'); });
    );
    try html.forms.selected_content.queueUpdate(std.testing.allocator, second, content);
    try page.run("queueMicrotask(() => { if (content.textContent !== 'two') throw new Error('second captured select'); })");
    try page.turn();
    try page.run("if (content.textContent !== 'two') throw new Error('last captured update missing')");

    try html.forms.selected_content.queueUpdate(std.testing.allocator, first, content);
    try page.run("b.options[0].append(content); content.remove(); content.textContent = 'disabled'");
    // Removal does not recalculate the flag set by insertion under an option.
    try std.testing.expect(dom.selected_content.isDisabled(content));
    try page.turn();
    try page.run("if (content.textContent !== 'disabled') throw new Error('removed disabled content was updated')");

    try page.run("b.firstElementChild.append(content); content.textContent = 'seed'");
    try std.testing.expect(!dom.selected_content.isDisabled(content));
    try html.forms.selected_content.queueUpdate(std.testing.allocator, first, content);
    try page.turn();
    try page.run("if (content.textContent !== 'one') throw new Error('current owner replaced the captured select')");
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

test "selectedcontent microtasks preserve captured select order and stored disabledness" {
    try helpers.onFreshThread(capturedOrderAndDisabledness);
}

test "selectedcontent update keeps a detached select through collection" {
    try helpers.onFreshThread(removedSelectSurvives);
}

test "selectedcontent continuation frees its allocation on every failure" {
    try helpers.onFreshThread(queueAllocationFailures);
}

test "realm teardown drops a selectedcontent continuation and both captured nodes" {
    try helpers.onFreshThread(queuedAtTeardown);
}

test "selectedcontent microtask retains separately detached captured nodes through GC" {
    try helpers.onFreshThread(capturedNodesSurvive);
}

//! Dialog registration must end on removal and document teardown.
const helpers = @import("edges_node_holders_helpers.zig");
const dom = @import("dom");
const html = @import("html");
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

fn allocationTrial(allocator: std.mem.Allocator, document: *runtime.Instance, first: *runtime.Instance, second: *runtime.Instance) !void {
    var state = dom.top_layer.State.init(allocator, document);
    defer state.deinit();
    try state.addOpenDialog(first);
    try state.addOpenDialog(second);
    try state.addOpenDialog(first);
    try std.testing.expectEqual(@as(usize, 2), state.open_dialogs.items.len);
    try std.testing.expect(state.lastOpenDialog() == second);
    state.setDialogPointerdownTarget(first);
    state.removeOpenDialog(first);
    try std.testing.expect(state.dialog_pointerdown_target.get() == first);
    state.setDialogPointerdownTarget(null);
    try std.testing.expect(state.dialog_pointerdown_target.get() == null);
    try std.testing.expect(state.lastOpenDialog() == second);
    state.removeOpenDialog(second);
    try std.testing.expect(state.lastOpenDialog() == null);
}

fn allocationFailures() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<dialog id=a></dialog><dialog id=b></dialog>'");
    const document = page.browser.current_context.?.document_instance.?;
    const first = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("a"))).?;
    const second = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("b"))).?;
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationTrial, .{ document, first, second });
}

fn removedDialogCollects() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.removedDialog = (() => {
        \\  const dialog = document.body.appendChild(document.createElement('dialog'));
        \\  dialog.closedBy = 'any';
        \\  dialog.show();
        \\  dialog.remove();
        \\  if (!dialog.open) throw new Error('removal changed the open attribute');
        \\  return new WeakRef(dialog);
        \\})();
    );
    try page.turn();
    try page.run("collectNow()");
    try page.turn();
    try page.run("if (removedDialog.deref() !== undefined) throw new Error('removed open dialog retained')");
}

fn lightDismissAndRemoval() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id=outside>Outside</button><dialog id=d closedby=any><button id=inside>Inside</button></dialog>';
        \\const dialog = document.getElementById('d');
        \\dialog.show();
    );
    const document = page.browser.current_context.?.document_instance.?;
    const outside = (try dom.selector_matching.querySelector(document, "#outside")).?;
    var pointer: html.user_input.Pointer = .{};
    html.user_input.pointerMove(&pointer, outside, .{});
    html.user_input.pointerDown(&pointer, 0, .{});
    try page.run("if (!dialog.open) throw new Error('dismissed on pointerdown')");
    html.user_input.pointerUp(&pointer, 0, .{});
    try page.run("if (dialog.open) throw new Error('outside pointerup did not dismiss')");
    try page.run("dialog.show()");
    const inside = (try dom.selector_matching.querySelector(document, "#inside")).?;
    html.user_input.pointerMove(&pointer, inside, .{});
    html.user_input.pointerDown(&pointer, 0, .{});
    const state = (try dom.top_layer.ofDocument(document, false)).?;
    try std.testing.expect(state.dialog_pointerdown_target.get() != null);
    try page.run("dialog.remove(); collectNow()");
    try std.testing.expect(state.dialog_pointerdown_target.get() == null);
    try std.testing.expect(state.lastOpenDialog() == null);
    html.user_input.pointerMove(&pointer, outside, .{});
    html.user_input.pointerUp(&pointer, 0, .{});
    try page.run("if (!dialog.open) throw new Error('removed dialog was closed by stale pointer state')");
    try page.run("document.body.append(dialog)");
    try std.testing.expect(state.lastOpenDialog() != null);
    html.user_input.pointerMove(&pointer, (try dom.selector_matching.querySelector(document, "#inside")).?, .{});
    html.user_input.pointerDown(&pointer, 0, .{});
    html.user_input.pointerUp(&pointer, 0, .{});
    try std.testing.expect(state.dialog_pointerdown_target.get() == null);
    try page.run("if (!dialog.open) throw new Error('inside click closed reinserted dialog')");
}

fn pendingAtTeardown() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<dialog id=d closedby=any><button id=inside>Inside</button></dialog>';
        \\document.getElementById('d').show();
    );
    const document = page.browser.current_context.?.document_instance.?;
    const inside = (try dom.selector_matching.querySelector(document, "#inside")).?;
    var pointer: html.user_input.Pointer = .{};
    html.user_input.pointerMove(&pointer, inside, .{});
    html.user_input.pointerDown(&pointer, 0, .{});
    // Page.close exercises open-list and pointerdown cleanup without pointerup.
}

test "an opened then removed dialog is collectible after its queued events" {
    try helpers.onFreshThread(removedDialogCollects);
}

test "dialog light dismiss pairs pointer events and discards removed targets" {
    try helpers.onFreshThread(lightDismissAndRemoval);
}

test "document teardown releases an open dialog and pending pointerdown target" {
    try helpers.onFreshThread(pendingAtTeardown);
}

test "dialog registrations have stable holds and free every failed allocation" {
    try helpers.onFreshThread(allocationFailures);
}

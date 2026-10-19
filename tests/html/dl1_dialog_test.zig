//! HTML dialog lifecycle and the modal focus exclusion without layout.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const focus = @import("html").focus;
const helpers = @import("edges_node_holders_helpers.zig");

fn values() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const dialog = document.createElement('dialog');
        \\if (dialog.returnValue !== '') throw new Error('initial returnValue');
        \\dialog.returnValue = 'kept';
        \\dialog.close('ignored');
        \\if (dialog.returnValue !== 'kept') throw new Error('closed close changed returnValue');
        \\if (dialog.closedBy !== 'none') throw new Error('nonmodal auto closedBy');
        \\for (const [value, expected] of [['AnY', 'any'], ['CLOSEREQUEST', 'closerequest'], ['NONE', 'none'], ['invalid', 'none'], ['', 'none']]) {
        \\  dialog.closedBy = value;
        \\  if (dialog.closedBy !== expected || dialog.getAttribute('closedby') !== value) throw new Error('closedBy ' + value);
        \\}
        \\dialog.show();
        \\if (!dialog.open || dialog.matches(':modal')) throw new Error('detached show');
        \\dialog.show();
        \\dialog.close();
        \\if (dialog.open || dialog.returnValue !== 'kept') throw new Error('absent returnValue');
        \\dialog.show();
        \\dialog.close('');
        \\if (dialog.returnValue !== '') throw new Error('empty returnValue');
    );
}

fn modalFocus() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id="outside">outside</button><div inert><dialog id="dialog"><button id="inside">inside</button><button id="inertInside" inert>inert</button></dialog></div>';
        \\document.getElementById('outside').focus();
        \\document.getElementById('dialog').showModal();
    );
    const document = page.browser.current_context.?.document_instance.?;
    const outside = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("outside"))).?;
    const inside = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("inside"))).?;
    const inert_inside = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("inertInside"))).?;
    try std.testing.expect(!focus.isFocusableArea(outside));
    try std.testing.expect(focus.isFocusableArea(inside));
    try std.testing.expect(!focus.isFocusableArea(inert_inside));
    try page.run(
        \\const dialog = document.getElementById('dialog');
        \\if (!dialog.matches(':modal') || !dialog.matches(':open')) throw new Error('modal/open selector');
        \\if (document.activeElement.id !== 'inside') throw new Error('opening focus');
        \\document.getElementById('outside').focus();
        \\if (document.activeElement.id !== 'inside') throw new Error('modal allowed outside focus');
        \\dialog.close();
        \\if (document.activeElement.id !== 'outside') throw new Error('closing focus restore');
        \\if (dialog.matches(':modal, :open')) throw new Error('closed selector');
    );
    try std.testing.expect(focus.isFocusableArea(outside));
}

fn reentrancy() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const dialog = document.body.appendChild(document.createElement('dialog'));
        \\let before = 0;
        \\dialog.addEventListener('beforetoggle', event => {
        \\  ++before;
        \\  if (event.oldState !== 'closed' || event.newState !== 'open' || !event.cancelable) throw new Error('opening event');
        \\  event.preventDefault();
        \\}, {once: true});
        \\dialog.showModal();
        \\if (before !== 1 || dialog.open) throw new Error('opening cancellation');
        \\dialog.show();
        \\dialog.addEventListener('beforetoggle', event => {
        \\  if (event.oldState !== 'open' || event.newState !== 'closed' || event.cancelable) throw new Error('closing event');
        \\  event.preventDefault();
        \\}, {once: true});
        \\dialog.close('accepted');
        \\if (dialog.open || dialog.returnValue !== 'accepted') throw new Error('close is not cancelable');
        \\dialog.addEventListener('beforetoggle', () => { dialog.open = true; }, {once: true});
        \\dialog.showModal();
        \\if (!dialog.open || dialog.matches(':modal')) throw new Error('opening revalidation');
        \\dialog.addEventListener('beforetoggle', () => { dialog.open = false; }, {once: true});
        \\dialog.close('ignored');
        \\if (dialog.returnValue !== 'accepted') throw new Error('closing revalidation');
    );
}

fn popoverAncestor() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id=popover popover><dialog id=inside tabindex=0></dialog></div><dialog id=outside tabindex=0></dialog>';
        \\const popover = document.getElementById('popover');
        \\const inside = document.getElementById('inside');
        \\const outside = document.getElementById('outside');
        \\for (const method of ['show', 'showModal']) {
        \\  popover.showPopover();
        \\  inside[method]();
        \\  if (!popover.matches(':popover-open')) throw new Error('dialog hid its popover ancestor');
        \\  inside.close();
        \\  outside[method]();
        \\  if (popover.matches(':popover-open')) throw new Error('dialog left an unrelated popover open');
        \\  outside.close();
        \\}
    );
}

fn fallbackFocus() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<dialog id=dialog></dialog>';
        \\document.getElementById('dialog').showModal();
        \\if (document.activeElement.id !== 'dialog') throw new Error('empty dialog fallback');
    );
}

fn plainDialogFocus() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id=outside>outside</button><dialog id=dialog open></dialog>';
        \\const outside = document.getElementById('outside');
        \\const dialog = document.getElementById('dialog');
        \\outside.focus();
        \\if (document.activeElement !== outside) throw new Error('focus setup');
        \\dialog.focus();
        \\if (document.activeElement !== dialog) throw new Error('plain dialog focus method');
        \\dialog.tabIndex = -1;
        \\outside.focus();
        \\dialog.focus();
        \\if (document.activeElement !== dialog) throw new Error('negative tabindex still allows focus method');
    );
}

fn sequentialDefaults() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<dialog id=dialog open></dialog>'");
    const document = page.browser.current_context.?.document_instance.?;
    const dialog = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("dialog"))).?;
    try std.testing.expect(focus.isFocusableArea(dialog));
    // Golden rule 2 / row85 Q12: Firefox and Safari give a plain dialog
    // the default sequential tabindex 0; Chrome alone excludes it.
    try std.testing.expect(focus.isSequentiallyFocusable(dialog));
    try page.run("document.getElementById('dialog').tabIndex = 0");
    try std.testing.expect(focus.isSequentiallyFocusable(dialog));
    try page.run("document.getElementById('dialog').tabIndex = -1");
    try std.testing.expect(focus.isFocusableArea(dialog));
    try std.testing.expect(!focus.isSequentiallyFocusable(dialog));
    try page.run("document.getElementById('dialog').removeAttribute('tabindex'); document.getElementById('dialog').contentEditable = 'true'");
    try std.testing.expect(focus.isSequentiallyFocusable(dialog));
    try page.run(
        \\const dialog = document.getElementById('dialog');
        \\dialog.removeAttribute('contenteditable');
        \\dialog.inert = true;
    );
    try std.testing.expect(!focus.isFocusableArea(dialog));
    try page.run("dialog.inert = false; dialog.remove()");
    try std.testing.expect(!focus.isFocusableArea(dialog));
}

test "dialog values distinguish absent return value and computed closedBy" {
    try helpers.onFreshThread(values);
}

test "modal dialog excludes outside focus and restores the previous focus" {
    try helpers.onFreshThread(modalFocus);
}

test "dialog beforetoggle cancellation and state revalidation" {
    try helpers.onFreshThread(reentrancy);
}

test "showing a dialog hides popovers up to its popover ancestor" {
    try helpers.onFreshThread(popoverAncestor);
}

test "an empty modal dialog receives fallback focus" {
    try helpers.onFreshThread(fallbackFocus);
}

test "focus method reaches a plain dialog without a tabindex" {
    try helpers.onFreshThread(plainDialogFocus);
}

test "plain dialogs follow browser-majority sequential focus defaults" {
    try helpers.onFreshThread(sequentialDefaults);
}

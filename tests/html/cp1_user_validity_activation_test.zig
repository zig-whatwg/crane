//! Probe Q24, 2026-10-27: Firefox 158 + Safari 27 mark successful
//! scripted activation; Chrome 156 differs. All three leave checked writes
//! and canceled clicks unmarked. Use a fresh form and radio group per case.
const helpers = @import("edges_node_holders_helpers.zig");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const input = @import("html").user_input;

fn exercise(comptime kind: []const u8, comptime action: []const u8, comptime marked: bool) !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const form = document.body.appendChild(document.createElement('form'));
        \\const el = form.appendChild(document.createElement('input'));
        \\el.required = true;
        \\el.name = 'group';
    ++ "el.type = '" ++ kind ++ "';" ++
        \\const other = form.appendChild(document.createElement('input'));
        \\other.type = el.type;
        \\other.name = el.name;
        \\if (el.matches(':user-valid, :user-invalid')) throw new Error('initial flag');
    ++ action ++
        \\if (el.matches(':user-valid') !==
    ++ (if (marked) "true" else "false") ++ ") throw new Error('user validity after action');" ++
        \\if (el.matches(':user-invalid')) throw new Error('unexpected user-invalid');
        \\if (other.matches(':user-valid, :user-invalid')) throw new Error('group member was not activated');
    );
}

fn clickCheckbox() !void {
    try exercise("checkbox", "el.click();", true);
}
fn dispatchCheckbox() !void {
    try exercise("checkbox", "el.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));", true);
}
fn setCheckbox() !void {
    try exercise("checkbox", "el.checked = true;", false);
}
fn cancelCheckbox() !void {
    try exercise("checkbox", "el.addEventListener('click', e => e.preventDefault()); el.click(); if (el.checked) throw new Error('cancellation');", false);
}
fn clickRadio() !void {
    try exercise("radio", "el.click();", true);
}
fn dispatchRadio() !void {
    try exercise("radio", "el.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));", true);
}
fn setRadio() !void {
    try exercise("radio", "el.checked = true;", false);
}
fn cancelRadio() !void {
    try exercise("radio", "el.addEventListener('click', e => e.preventDefault()); el.click(); if (el.checked) throw new Error('cancellation');", false);
}

test "checkbox click sets user validity" {
    try helpers.onFreshThread(clickCheckbox);
}
test "checkbox dispatched click sets user validity" {
    try helpers.onFreshThread(dispatchCheckbox);
}
// Preservation pins: both were already unmarked before the owner flag.
test "checkbox checked write leaves user validity unset" {
    try helpers.onFreshThread(setCheckbox);
}
test "checkbox canceled click leaves user validity unset" {
    try helpers.onFreshThread(cancelCheckbox);
}
test "radio click sets user validity" {
    try helpers.onFreshThread(clickRadio);
}
test "radio dispatched click sets user validity" {
    try helpers.onFreshThread(dispatchRadio);
}
// Preservation pins: a setter and canceled activation are not user commits.
test "radio checked write leaves user validity unset" {
    try helpers.onFreshThread(setRadio);
}
test "radio canceled click leaves user validity unset" {
    try helpers.onFreshThread(cancelRadio);
}

fn hoverBoundaryOrder() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<div id=a></div><div id=b></div>';");
    const document = page.browser.current_context.?.document_instance.?;
    const a = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("a"))).?;
    const b = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("b"))).?;
    var pointer: input.Pointer = .{};
    input.pointerMove(&pointer, a, .{});
    try page.run(
        \\const a = document.getElementById('a');
        \\const b = document.getElementById('b');
        \\if (!a.matches(':hover') || b.matches(':hover')) throw new Error('initial hover');
        \\globalThis.cp1BoundaryLog = [];
        \\for (const type of ['pointerout', 'pointerleave', 'mouseout', 'mouseleave']) {
        \\  a.addEventListener(type, event => cp1BoundaryLog.push(
        \\    [event.type, a.matches(':hover'), b.matches(':hover')].join(':')));
        \\}
        \\for (const type of ['pointerover', 'pointerenter', 'mouseover', 'mouseenter']) {
        \\  b.addEventListener(type, event => cp1BoundaryLog.push(
        \\    [event.type, a.matches(':hover'), b.matches(':hover')].join(':')));
        \\}
    );
    input.pointerMove(&pointer, b, .{});
    try page.run(
        \\const expected = ['pointerout', 'pointerleave', 'mouseout', 'mouseleave',
        \\  'pointerover', 'pointerenter', 'mouseover', 'mouseenter']
        \\  .map(type => type + ':false:true').join(',');
        \\if (cp1BoundaryLog.join(',') !== expected)
        \\  throw new Error('hover boundary ordering: ' + cp1BoundaryLog.join(','));
    );
}

test "hover designation precedes leaving boundary callbacks and remains set on entry" {
    try helpers.onFreshThread(hoverBoundaryOrder);
}

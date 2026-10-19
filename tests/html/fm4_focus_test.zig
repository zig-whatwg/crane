//! Radio navigation and label focus, through the existing focus/input APIs.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

fn expectFocus(page: helpers.Page, id: []const u8) !void {
    const actual = try page.evaluate("document.activeElement.id");
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(id, actual);
}

fn documentOf(page: helpers.Page) *runtime.Instance {
    return page.browser.current_context.?.document_instance.?;
}

fn press(page: helpers.Page, key: []const u8, modifiers: html.user_input.Modifiers) void {
    var keyboard: html.user_input.Keyboard = .{};
    html.user_input.keyDown(&keyboard, documentOf(page), .{ .key = key }, modifiers);
    html.user_input.keyUp(&keyboard, documentOf(page), .{ .key = key }, modifiers);
}

fn labelFocus() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id="control"><label id="label" for="control">Label</label><button id="elsewhere">Elsewhere</button>';
        \\label.focus();
    );
    try expectFocus(page, "control");
    try page.run("label.tabIndex = -1; label.focus()");
    try expectFocus(page, "label");
    try page.run("label.setAttribute('tabindex', ''); control.blur(); label.focus()");
    try expectFocus(page, "control");
    try page.run("label.tabIndex = 0; label.style.display = 'none'; control.blur(); label.focus()");
    try expectFocus(page, "control");
    try page.run("elsewhere.focus(); control.disabled = true; label.focus()");
    try expectFocus(page, "elsewhere");
}

fn radioTab() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id="start"><form><input type="radio" name="r" id="a"><button id="middle"></button><input type="radio" name="r" id="b"><input type="radio" name="r" id="c"></form><input id="end">';
        \\start.focus();
    );
    press(page, "Tab", .{});
    try expectFocus(page, "a");
    press(page, "Tab", .{});
    try expectFocus(page, "middle");
    press(page, "Tab", .{});
    try expectFocus(page, "end");
    press(page, "Tab", .{ .shift = true });
    try expectFocus(page, "middle");
    press(page, "Tab", .{ .shift = true });
    try expectFocus(page, "a");
    try page.run("b.checked = true; start.focus()");
    press(page, "Tab", .{});
    try expectFocus(page, "middle");
    press(page, "Tab", .{});
    try expectFocus(page, "b");
    press(page, "Tab", .{});
    try expectFocus(page, "end");
    try page.run("b.disabled = true; start.focus()");
    press(page, "Tab", .{});
    try expectFocus(page, "a");
    try page.run("a.focus(); b.disabled = false; c.checked = true");
    press(page, "Tab", .{});
    try expectFocus(page, "middle");
    press(page, "Tab", .{});
    try expectFocus(page, "c");
}

fn radioKeys() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<form><input type="radio" name="r" id="a"><input type="radio" name="r" id="hidden" style="display:none"><input type="radio" name="r" id="b"></form>';
        \\a.focus();
    );
    press(page, "ArrowDown", .{});
    try expectFocus(page, "b");
    try page.run("if (!b.checked || hidden.checked) throw Error('wrong radio checked')");
    press(page, "ArrowDown", .{ .ctrl = true });
    try expectFocus(page, "b");
    press(page, "ArrowDown", .{ .alt = true });
    try expectFocus(page, "b");
    press(page, "ArrowDown", .{ .meta = true });
    try expectFocus(page, "b");
    press(page, "ArrowDown", .{});
    try expectFocus(page, "a");
    // Native-only bound regression: no arbitrary 256-member limit.
    try page.run(
        \\document.body.innerHTML = '<form id="many"></form>';
        \\for (let i = 0; i < 300; ++i) { const r = document.createElement('input'); r.type = 'radio'; r.name = 'many'; r.id = 'r' + i; many.append(r); }
        \\document.getElementById('r298').focus();
    );
    press(page, "ArrowDown", .{});
    try expectFocus(page, "r299");
    press(page, "ArrowDown", .{});
    try expectFocus(page, "r0");
    press(page, "ArrowUp", .{});
    try expectFocus(page, "r299");
}

fn labelClick() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id="control"><label id="label" for="control">Label</label>';
        \\globalThis.labelOrder = [];
        \\control.addEventListener('focus', () => labelOrder.push('focus'));
        \\control.addEventListener('click', () => labelOrder.push('click'));
        \\label.click();
    );
    try expectFocus(page, "control");
    try page.run("if (labelOrder.join() !== 'focus,click') throw Error('wrong label activation order')");
}

fn labelControlRemovedDuringFocus() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id="control"><label id="label" for="control">Label</label>';
        \\globalThis.labelOrder = [];
        \\document.getElementById('control').addEventListener('click', () => labelOrder.push('click'));
        \\document.getElementById('control').addEventListener('focus', event => {
        \\  labelOrder.push('focus');
        \\  event.currentTarget.remove();
        \\  document.getElementById('label').remove();
        \\  TestUtils.gc();
        \\});
    );
    const control = (try interfaces.Document.call_getElementById(documentOf(page), runtime.DOMString.initInterned("control"))) orelse return error.MissingControl;
    const control_ref = html.user_input.Weak.of(control);
    try page.run("document.getElementById('label').click()");
    try expectFocus(page, "");
    try std.testing.expect(control_ref.get() == control);
    try page.run("if (labelOrder.join() !== 'focus,click') throw Error('live removed label control missed click'); TestUtils.gc()");
}

fn radioGroupBoundaries() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<form id="first"><input type="radio" name="r" id="a"></form><form id="second"><input type="radio" name="r" id="other"></form><input type="radio" name="R" form="first" id="different"><input type="radio" name="r" form="first" disabled id="disabled"><div inert><input type="radio" name="r" form="first" id="inert"></div><input type="radio" name="r" form="first" tabindex="-1" id="outside"><input type="radio" id="nameless"><input type="radio" id="also-nameless">';
        \\a.focus();
    );
    // The external form-associated member belongs to the first group;
    // tabindex=-1 excludes it from Tab, but not from arrow navigation.
    press(page, "ArrowDown", .{});
    try expectFocus(page, "outside");
    press(page, "ArrowUp", .{});
    try expectFocus(page, "a");
    try page.run("document.getElementById('nameless').focus()");
    press(page, "ArrowDown", .{});
    try expectFocus(page, "nameless");
}

fn radioRemovedDuringFocus() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input type="radio" name="r" id="a"><input type="radio" name="r" id="b">';
        \\globalThis.radioClicks = 0;
        \\document.getElementById('b').addEventListener('click', () => ++radioClicks);
        \\document.getElementById('b').addEventListener('focus', event => {
        \\  event.currentTarget.remove();
        \\  TestUtils.gc();
        \\});
        \\a.focus();
    );
    const radio = (try interfaces.Document.call_getElementById(documentOf(page), runtime.DOMString.initInterned("b"))) orelse return error.MissingRadio;
    const radio_ref = html.user_input.Weak.of(radio);
    press(page, "ArrowDown", .{});
    try expectFocus(page, "");
    // Q12: the focus dispatch keeps this removed radio live. The same
    // native identity/generation before and after the key brackets its
    // click; Blink likewise clicks the detached candidate it still holds.
    try std.testing.expect(radio_ref.get() == radio);
    try page.run("if (radioClicks !== 1) throw Error('live removed radio missed its click'); TestUtils.gc()");
}

fn labelRemovedDuringClick() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id="control"><label id="label" for="control">Label</label>';
        \\document.getElementById('control').addEventListener('click', event => {
        \\  event.currentTarget.remove();
        \\  document.getElementById('label').remove();
        \\  TestUtils.gc();
        \\});
        \\document.getElementById('label').click();
        \\TestUtils.gc();
    );
    try expectFocus(page, "");
}

test "labels forward focus only when the label is not focusable" {
    try helpers.onFreshThread(labelFocus);
}

test "radio groups occupy one sequential focus stop with dynamic checkedness" {
    try helpers.onFreshThread(radioTab);
}

test "radio arrows skip unfocusable members and modifier shortcuts without a group size cap" {
    try helpers.onFreshThread(radioKeys);
}

test "label activation focuses the associated control before its click" {
    try helpers.onFreshThread(labelClick);
}

test "label activation survives removal and GC during the control click" {
    try helpers.onFreshThread(labelRemovedDuringClick);
}

test "radio arrows respect name, form owner and full focusability" {
    try helpers.onFreshThread(radioGroupBoundaries);
}

test "radio activation survives removal and GC during focus" {
    try helpers.onFreshThread(radioRemovedDuringFocus);
}

test "label activation clicks the still-live control removed by its focus listener" {
    try helpers.onFreshThread(labelControlRemovedDuringFocus);
}

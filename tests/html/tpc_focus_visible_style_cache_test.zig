//! A focused element's computed style is cached like any other (lane tpc,
//! 2026-11-22): :focus-visible's inputs that are not tree mutations - the
//! input modality, a focus() call's focusVisible, designMode - move a
//! revision the style engine pulls (StyleEngine.observeFocusVisible), so
//! repeated reads inside a focused editing host resolve nothing again, and a
//! modality flip still recomputes. Before, matching :focus-visible marked a
//! focused element's style volatile, and every style read in an editing
//! host - every editing command's queries - resolved its lineage again.
//!
//! The measure is the element's cached style serial (ElementStyle.cached
//! .serial): each resolution gives the element a new one.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const input = @import("html").user_input;
const helpers = @import("edges_node_holders_helpers.zig");

fn element(page: helpers.Page, id: []const u8) !*runtime.Instance {
    const document = page.browser.current_context.?.document_instance.?;
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.NoElement;
}

/// The element's cached style serial, 0 with none.
fn serialOf(e: *runtime.Instance) u64 {
    const state = dom.style.element_style.of(e) orelse return 0;
    const cached = state.cached orelse return 0;
    return cached.serial;
}

fn cachedInFocusedHost() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.innerHTML = '<style>#host:focus-visible { color: rgb(0, 128, 0) } p { margin-left: 3px }</style>';
        \\document.body.innerHTML = '<div id=host contenteditable><p id=para>foo</p></div>';
        \\document.getElementById('host').focus();
        \\if (getComputedStyle(document.getElementById('para')).color !== 'rgb(0, 128, 0)') throw new Error('the focused editing host is focus-visible');
    );
    const host = try element(page, "host");
    const para = try element(page, "para");
    const host_serial = serialOf(host);
    const para_serial = serialOf(para);
    try std.testing.expect(host_serial != 0 and para_serial != 0);
    // Read again, nothing changed: both are cache hits.
    try page.run(
        \\for (let i = 0; i < 3; i++) {
        \\  if (getComputedStyle(document.getElementById('para')).marginLeft !== '3px') throw new Error('para');
        \\  if (getComputedStyle(document.getElementById('host')).color !== 'rgb(0, 128, 0)') throw new Error('host');
        \\}
    );
    try std.testing.expectEqual(host_serial, serialOf(host));
    try std.testing.expectEqual(para_serial, serialOf(para));
}

test "repeated computed-style reads inside a focused editing host are cache hits" {
    try helpers.onFreshThread(cachedInFocusedHost);
}

fn modalityFlipRecomputes() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.innerHTML = '<style>#b { color: rgb(255, 0, 0) } #b:focus-visible { color: rgb(0, 128, 0) }</style>';
        \\document.body.innerHTML = '<div id=b tabindex=0>b</div>';
    );
    const button = try element(page, "b");
    // A pointer press focuses the div: no focus ring (Blink's heuristic). A
    // div, not a button: a form control's style reads control state, which
    // is volatile on its own.
    var pointer: input.Pointer = .{};
    input.pointerMove(&pointer, button, .{});
    input.pointerDown(&pointer, 0, .{});
    input.pointerUp(&pointer, 0, .{});
    try page.run(
        \\if (document.activeElement !== document.getElementById('b')) throw new Error('the press focused the div');
        \\if (getComputedStyle(document.getElementById('b')).color !== 'rgb(255, 0, 0)') throw new Error('pointer focus: ' + getComputedStyle(document.getElementById('b')).color);
    );
    const pointer_serial = serialOf(button);
    // A key press flips the modality with the focus unchanged: the cached
    // style is stale and must be resolved again.
    const document = page.browser.current_context.?.document_instance.?;
    var keyboard: input.Keyboard = .{};
    input.keyDown(&keyboard, document, .{ .key = "Shift", .code = "ShiftLeft", .key_code = 16 }, .{});
    input.keyUp(&keyboard, document, .{ .key = "Shift", .code = "ShiftLeft", .key_code = 16 }, .{});
    try page.run(
        \\if (document.activeElement !== document.getElementById('b')) throw new Error('the key kept the focus');
        \\if (getComputedStyle(document.getElementById('b')).color !== 'rgb(0, 128, 0)') throw new Error('keyboard modality: ' + getComputedStyle(document.getElementById('b')).color);
    );
    try std.testing.expect(serialOf(button) != pointer_serial);
    // And a read with nothing changed since is a hit again.
    const keyboard_serial = serialOf(button);
    try page.run("getComputedStyle(document.getElementById('b')).color;");
    try std.testing.expectEqual(keyboard_serial, serialOf(button));
}

test "a modality flip recomputes a focused element's :focus-visible style; a read after it hits the cache" {
    try helpers.onFreshThread(modalityFlipRecomputes);
}

fn designModeSwitchRecomputes() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // designMode makes every element editable: :read-write's answer moves
    // with no tree mutation, and so does :focus-visible's for a focused
    // element that then takes text input.
    try page.run(
        \\document.head.innerHTML = '<style>#d { color: rgb(255, 0, 0) } #d:read-write { color: rgb(0, 128, 0) }</style>';
        \\document.body.innerHTML = '<div id=d>d</div>';
        \\if (getComputedStyle(document.getElementById('d')).color !== 'rgb(255, 0, 0)') throw new Error('read-only before');
        \\document.designMode = 'on';
        \\if (getComputedStyle(document.getElementById('d')).color !== 'rgb(0, 128, 0)') throw new Error('designMode on: ' + getComputedStyle(document.getElementById('d')).color);
        \\document.designMode = 'off';
        \\if (getComputedStyle(document.getElementById('d')).color !== 'rgb(255, 0, 0)') throw new Error('designMode off again: ' + getComputedStyle(document.getElementById('d')).color);
    );
}

test "a designMode switch recomputes cached styles that read editability (:read-write)" {
    try helpers.onFreshThread(designModeSwitchRecomputes);
}

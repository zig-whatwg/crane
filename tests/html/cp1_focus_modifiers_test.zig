//! Selectors 4 section 9.4, Q124: modifier shortcuts preserve pointer modality.
//! Exercise the real input path and warmed computed styles on a fresh thread.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const input = @import("html").user_input;
const helpers = @import("edges_node_holders_helpers.zig");

fn exercise(key: []const u8, modifiers: input.Modifiers, visible: bool) !void {
    // Page.open uses std.testing.allocator; teardown remains leak checked.
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.head.innerHTML = '<style>#target { color: rgb(255, 0, 0); } #target:focus-visible { color: rgb(0, 128, 0); }</style>';
        \\document.body.innerHTML = '<button id="target">Target</button>';
        \\globalThis.cp1Target = document.getElementById('target');
        \\globalThis.cp1Events = [];
        \\cp1Target.addEventListener('keydown', () => cp1Events.push('down'));
        \\cp1Target.addEventListener('keyup', () => cp1Events.push('up'));
    );
    const document = page.browser.current_context.?.document_instance.?;
    const target = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("target"))).?;
    var pointer: input.Pointer = .{};
    input.pointerMove(&pointer, target, .{});
    input.pointerDown(&pointer, 0, .{});
    input.pointerUp(&pointer, 0, .{});
    try page.run(
        \\if (document.activeElement !== cp1Target || !cp1Target.matches(':focus')) throw new Error('pointer focus');
        \\if (cp1Target.matches(':focus-visible')) throw new Error('pointer starts focus-visible');
        \\if (getComputedStyle(cp1Target).color !== 'rgb(255, 0, 0)') throw new Error('warm pointer style');
    );
    var keyboard: input.Keyboard = .{};
    input.keyDown(&keyboard, document, .{ .key = key }, modifiers);
    input.keyUp(&keyboard, document, .{ .key = key }, modifiers);
    try page.run(
        \\if (document.activeElement !== cp1Target || !cp1Target.matches(':focus')) throw new Error('key changed focus');
        \\if (cp1Events.join() !== 'down,up') throw new Error('key dispatch changed');
    );
    const actual = try page.evaluate("String(cp1Target.matches(':focus-visible')) + '|' + getComputedStyle(cp1Target).color");
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(if (visible) "true|rgb(0, 128, 0)" else "false|rgb(255, 0, 0)", actual);
}

fn check(comptime key: []const u8, comptime modifiers: input.Modifiers, comptime visible: bool) !void {
    try helpers.onFreshThread(struct {
        fn run() !void {
            try exercise(key, modifiers, visible);
        }
    }.run);
}

test "Control alone preserves pointer focus modality" {
    try check("Control", .{ .ctrl = true }, false);
}

test "Alt alone preserves pointer focus modality" {
    try check("Alt", .{ .alt = true }, false);
}

test "Meta alone preserves pointer focus modality" {
    try check("Meta", .{ .meta = true }, false);
}

test "modifier shortcuts preserve pointer modality with Shift" {
    try check("k", .{ .ctrl = true, .shift = true }, false);
    try check("k", .{ .alt = true, .shift = true }, false);
    try check("k", .{ .meta = true, .shift = true }, false);
}

test "an ordinary key changes pointer focus to visible keyboard focus" {
    try check("k", .{}, true);
}

test "Shift alone changes pointer focus to visible keyboard focus" {
    try check("Shift", .{ .shift = true }, true);
}

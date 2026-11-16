//! Lane quick2: picking options of a native (appearance:auto) list box with
//! a mouse and with a touch tap. All three browsers: a plain click selects
//! only the clicked option, Ctrl+click (Cmd+click on a Mac) toggles it, and
//! Shift+click selects a range; in a single-select list box a click selects
//! the option. A touch tap toggles the option in a multiple list box, as
//! Chrome does (html/semantics/forms/the-select-element/
//! select-listbox-touch.optional.html).
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

const user_input = html.user_input;

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    std.testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("{s}\n", .{source});
        return err;
    };
}

fn byId(page: helpers.Page, id: []const u8) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    const document = context.document_instance orelse return error.NoDocument;
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.NoElement;
}

fn open() !helpers.Page {
    const page = try helpers.Page.open();
    errdefer page.close();
    try page.run(
        \\document.body.innerHTML = `<select multiple id=m><option id=m1>1</option><option id=m2>2</option><option id=m3>3</option><option id=m4 disabled>4</option></select>
        \\<select size=3 id=s><option id=s1>1</option><option id=s2>2</option></select>`;
        \\globalThis.sel = (id) => [...document.getElementById(id).options].map(o => o.selected ? 1 : 0).join('');
        \\globalThis.changes = 0;
        \\m.addEventListener('change', () => changes++);
    );
    return page;
}

fn click(mouse: *user_input.Pointer, target: *runtime.Instance, modifiers: user_input.Modifiers) void {
    user_input.pointerMove(mouse, target, modifiers);
    user_input.pointerDown(mouse, 0, modifiers);
    user_input.pointerUp(mouse, 0, modifiers);
}

fn mouseClicksPick() !void {
    const page = try open();
    defer page.close();
    var mouse: user_input.Pointer = .{};
    click(&mouse, try byId(page, "m1"), .{});
    try expectScript(page, "sel('m')", "1000");
    click(&mouse, try byId(page, "m2"), .{});
    try expectScript(page, "sel('m')", "0100");
    // The toggle modifier: Ctrl here (Cmd on a Mac platform string).
    const platform = @import("platform").identity.navigator_platform.slice();
    const toggle: user_input.Modifiers = if (std.mem.startsWith(u8, platform, "Mac")) .{ .meta = true } else .{ .ctrl = true };
    click(&mouse, try byId(page, "m3"), toggle);
    try expectScript(page, "sel('m')", "0110");
    click(&mouse, try byId(page, "m2"), toggle);
    try expectScript(page, "sel('m')", "0010");
    // A disabled option is not picked.
    click(&mouse, try byId(page, "m4"), .{});
    try expectScript(page, "sel('m')", "0010");
    // Single-select list box.
    click(&mouse, try byId(page, "s2"), .{});
    try expectScript(page, "sel('s')", "01");
}

test "a mouse click picks a native list box's option: only it, or toggled with the toggle modifier" {
    try helpers.onFreshThread(mouseClicksPick);
}

fn shiftClickSelectsARange() !void {
    const page = try open();
    defer page.close();
    var mouse: user_input.Pointer = .{};
    click(&mouse, try byId(page, "m1"), .{});
    click(&mouse, try byId(page, "m3"), .{ .shift = true });
    try expectScript(page, "sel('m')", "1110");
}

test "Shift+click selects the range from the last option clicked without Shift" {
    try helpers.onFreshThread(shiftClickSelectsARange);
}

fn touchTapToggles() !void {
    const page = try open();
    defer page.close();
    var finger: user_input.Pointer = .{ .pointer_id = 2, .pointer_type = .touch };
    for ([_][]const u8{ "m1", "m2", "m2" }) |id| {
        finger.touch_hit = user_input.Weak.of(try byId(page, id));
        finger.touch_change = .pressed;
        user_input.touchFrame(&.{&finger}, .{});
        finger.touch_change = .released;
        user_input.touchFrame(&.{&finger}, .{});
    }
    try expectScript(page, "sel('m')", "1000");
}

test "a touch tap toggles an option of a multiple list box (Chrome)" {
    try helpers.onFreshThread(touchTapToggles);
}

//! Lane forms1 (C4): HTML 4.10.7 "send select update notifications" - when
//! the user picks (or, in a `multiple` list box, toggles) an option, a task
//! queued on the user interaction task source sets the select's user
//! validity, updates its descendant selectedcontent elements, and fires
//! input (bubbles, composed) and then change (bubbles) at it.
//! customizable-select-listbox/selectedcontent-listbox.html (Chrome passes)
//! clicks a list-box option and reads the selectedcontent.
const std = @import("std");
const html = @import("html");
const dom = @import("dom");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const user_input = html.user_input;

fn documentOf(page: helpers.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

fn element(document: *runtime.Instance, selector: []const u8) !*runtime.Instance {
    return (try dom.selector_matching.querySelector(document, selector)) orelse error.NoElement;
}

fn click(pointer: *user_input.Pointer, target: *runtime.Instance) void {
    user_input.pointerMove(pointer, target, .{});
    user_input.pointerDown(pointer, 0, .{});
    user_input.pointerUp(pointer, 0, .{});
}

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    std.testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("{s}\n", .{source});
        return err;
    };
}

const setup =
    \\const style = document.createElement('style');
    \\style.textContent = 'select, ::picker(select) { appearance: base-select }';
    \\document.head.append(style);
    \\document.body.innerHTML = '<select id=s size=4><optgroup><legend><selectedcontent></selectedcontent></legend></optgroup><option id=one selected>one</option><option id=two>two</option></select>';
    \\globalThis.log = [];
    \\const select = document.getElementById('s');
    \\select.addEventListener('input', (e) => log.push('input ' + e.bubbles + ' ' + e.composed + ' ' + document.querySelector('selectedcontent').innerHTML));
    \\select.addEventListener('change', (e) => log.push('change ' + e.bubbles + ' ' + e.composed));
;

fn listBoxPick() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup);
    try expectScript(page, "document.querySelector('selectedcontent').innerHTML", "one");
    try page.run("document.getElementById('one').selected = false;");
    try expectScript(page, "document.querySelector('selectedcontent').innerHTML", "");
    const document = try documentOf(page);
    var pointer = user_input.Pointer{};
    click(&pointer, try element(document, "#one"));
    // Picked at once (selectedness, dirtiness) ...
    try expectScript(page, "String(document.getElementById('one').selected)", "true");
    // ... notified by the queued task.
    try expectScript(page, "document.querySelector('selectedcontent').innerHTML + '|' + log.join(',')", "|");
    try page.turn();
    try expectScript(page, "document.querySelector('selectedcontent').innerHTML", "one");
    try expectScript(page, "log.join(',')", "input true true one,change true false");
    try expectScript(page, "String(document.getElementById('s').matches(':user-valid'))", "true");
}

test "picking a list-box option queues the select update notifications" {
    try helpers.onFreshThread(listBoxPick);
}

fn dropDownPick() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const style = document.createElement('style');
        \\style.textContent = 'select, ::picker(select) { appearance: base-select }';
        \\document.head.append(style);
        \\document.body.innerHTML = '<select id=s><button><selectedcontent></selectedcontent></button><option id=one>one</option><option id=two>two</option></select>';
        \\globalThis.log = [];
        \\const select = document.getElementById('s');
        \\select.addEventListener('input', () => log.push('input ' + document.querySelector('selectedcontent').innerHTML));
        \\select.addEventListener('change', () => log.push('change ' + select.value));
    );
    const document = try documentOf(page);
    var pointer = user_input.Pointer{};
    click(&pointer, try element(document, "#s"));
    try expectScript(page, "String(document.getElementById('s').matches(':open'))", "true");
    click(&pointer, try element(document, "#two"));
    // "pick an option" step 7 hides the picker at once.
    try expectScript(page, "String(document.getElementById('s').matches(':open'))", "false");
    try page.turn();
    try expectScript(page, "document.querySelector('selectedcontent').innerHTML + '|' + log.join(',')", "two|input two,change two");
}

test "picking a drop-down option hides the picker and queues the notifications" {
    try helpers.onFreshThread(dropDownPick);
}

fn multipleToggle() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const style = document.createElement('style');
        \\style.textContent = 'select { appearance: base-select }';
        \\document.head.append(style);
        \\document.body.innerHTML = '<select id=s multiple><option id=one>one</option><option id=two>two</option></select>';
        \\globalThis.log = [];
        \\document.getElementById('s').addEventListener('change', () => log.push('change ' + document.getElementById('one').selected));
    );
    const document = try documentOf(page);
    var pointer = user_input.Pointer{};
    click(&pointer, try element(document, "#one"));
    try expectScript(page, "String(document.getElementById('one').selected) + '|' + log.join(',')", "true|");
    try page.turn();
    try expectScript(page, "log.join(',')", "change true");
}

test "toggling a multiple list-box option queues the notifications" {
    try helpers.onFreshThread(multipleToggle);
}

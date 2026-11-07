//! Lane forms1 (C7c): execCommand("insertText"/"insertHTML") with a focused
//! text control inserts into the control, cut to its maxlength at a
//! code-point boundary (Chrome, Safari); constraints/input-maxlength-emoji.html.
//! With an editing host focused instead, insertHTML is unchanged.
const std = @import("std");
const html = @import("html");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const user_input = html.user_input;

fn documentOf(page: helpers.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

fn press(page: helpers.Page, key: []const u8, text: ?[]const u8) !void {
    var keyboard: user_input.Keyboard = .{};
    const document = try documentOf(page);
    user_input.keyDown(&keyboard, document, .{ .key = key, .text = text }, .{});
    user_input.keyUp(&keyboard, document, .{ .key = key, .text = text }, .{});
}

fn typeText(page: helpers.Page, text: []const u8) !void {
    var it = (try std.unicode.Utf8View.init(text)).iterator();
    while (it.nextCodepointSlice()) |character| try press(page, character, character);
}

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    std.testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("{s}\n", .{source});
        return err;
    };
}

fn execCommandInControl() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id=i maxlength=10><textarea id=t>ac</textarea>';
        \\globalThis.events = [];
        \\const i = document.getElementById('i');
        \\i.addEventListener('beforeinput', (e) => events.push('beforeinput'));
        \\i.addEventListener('input', (e) => events.push('input'));
        \\i.focus();
    );
    // U+1F468 ZWJ U+1F469 ZWJ U+1F467 ZWJ U+1F466: 11 code units; the last
    // code point does not fit in 10, and a surrogate pair is never split.
    try expectScript(page, "String(document.execCommand('insertHTML', false, '\\u{1F468}\\u200D\\u{1F469}\\u200D\\u{1F467}\\u200D\\u{1F466}'))", "true");
    try expectScript(page, "document.getElementById('i').value === '\\u{1F468}\\u200D\\u{1F469}\\u200D\\u{1F467}\\u200D' ? 'cut' : JSON.stringify(document.getElementById('i').value)", "cut");
    try expectScript(page, "events.join(',')", "beforeinput,input");
    try expectScript(page, "const t = document.getElementById('t'); t.focus(); t.setSelectionRange(1, 1); document.execCommand('insertText', false, 'b'); t.value + '|' + t.selectionStart", "abc|2");
    // insertHTML into a text control inserts the markup's text.
    try expectScript(page, "const i2 = document.getElementById('i'); i2.value = ''; i2.focus(); document.execCommand('insertHTML', false, '<b>bo</b>ld'); i2.value", "bold");
}

test "execCommand inserts into a focused text control within its maxlength" {
    try helpers.onFreshThread(execCommandInControl);
}

fn editingHostUnchanged() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<input id=i><div contenteditable id=host>ab</div>';
        \\const host = document.getElementById('host');
        \\host.focus();
        \\getSelection().collapse(host.firstChild, 1);
    );
    // No text control is focused: insertHTML still inserts the markup.
    try expectScript(page, "String(document.execCommand('insertHTML', false, '<b>x</b>')) + '|' + document.getElementById('host').innerHTML + '|' + document.getElementById('i').value", "true|a<b>x</b>b|");
}

test "with an editing host focused, insertHTML still inserts its markup there" {
    try helpers.onFreshThread(editingHostUnchanged);
}

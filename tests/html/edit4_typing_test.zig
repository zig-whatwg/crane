//! Lane edit4: typing style after a deletion.
//!
//! A04 - typing after a Backspace/Delete join beside a link keeps the
//! link's inner style but not the link or the link's own style
//! (editing/other/typing-around-link-element-after-joining-paragraphs.html,
//! wpt.fyi 2358bd4835). Mechanism by mechanism (golden rule 2): (1) the
//! typed text is bold - Firefox 160 and Safari 27.2 yes, Chrome 157 only
//! when no <br> was deleted with the join, so the majority says yes; (2)
//! where the <b> goes - Firefox a new <b> after the link, Safari a <b>
//! around the link and the text, Chrome (when it is bold) as Firefox: no
//! majority across the 16 rows, so the spec decides, and the Editing spec's
//! state override makes a new <b> around the typed text (Firefox's result,
//! the test's expectation). The link and the color its own style attribute
//! sets are not carried (all three): Blink removes the style the enclosing
//! anchor adds from the typing style it saves before a deletion
//! (DeleteSelectionCommand::SaveTypingStyleState).
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

fn press(page: helpers.Page, key: html.user_input.Key) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    html.user_input.keyDown(&keyboard, document, key, .{});
    html.user_input.keyUp(&keyboard, document, key, .{});
}

const backspace: html.user_input.Key = .{ .key = "Backspace", .code = "Backspace", .key_code = 8 };
const delete_key: html.user_input.Key = .{ .key = "Delete", .code = "Delete", .key_code = 46 };
const key_x: html.user_input.Key = .{ .key = "X", .code = "KeyX", .key_code = 88, .text = "X" };
const key_y: html.user_input.Key = .{ .key = "Y", .code = "KeyY", .key_code = 89, .text = "Y" };

const a_open = "<a href=\"about:blank\" style=\"color:rgb(0, 0, 255)\">";
const span_open = "<span style=\"color:rgb(255, 0, 0)\">";

const JoinCase = struct { markup: []const u8, backspace: bool, expected: []const u8 };

const join_cases = [_]JoinCase{
    // PPF (Chrome and Firefox pass).
    .{ .markup = "<p>" ++ a_open ++ "<b>foo</b></a></p><p>" ++ span_open ++ "[]bar</span></p>", .backspace = true, .expected = "<p>" ++ a_open ++ "<b>foo</b></a><b>XY</b>" ++ span_open ++ "bar</span></p>" },
    .{ .markup = "<p>" ++ a_open ++ "<b>foo[]</b></a></p><p>" ++ span_open ++ "bar</span></p>", .backspace = false, .expected = "<p>" ++ a_open ++ "<b>foo</b></a><b>XY</b>" ++ span_open ++ "bar</span></p>" },
    // FPF (Firefox passes; Safari bolds the text another way).
    .{ .markup = "<p>" ++ a_open ++ "<b>foo</b></a><br></p><p>" ++ span_open ++ "[]bar</span></p>", .backspace = true, .expected = "<p>" ++ a_open ++ "<b>foo</b></a><b>XY</b>" ++ span_open ++ "bar</span></p>" },
    .{ .markup = "<p>" ++ a_open ++ "<b>foo</b><br></a></p><p>" ++ span_open ++ "[]bar</span></p>", .backspace = true, .expected = "<p>" ++ a_open ++ "<b>foo</b></a><b>XY</b>" ++ span_open ++ "bar</span></p>" },
    .{ .markup = a_open ++ "<b>foo</b></a><br><p>" ++ span_open ++ "[]bar</span></p>", .backspace = true, .expected = a_open ++ "<b>foo</b></a><b>XY</b>" ++ span_open ++ "bar</span>" },
    .{ .markup = "<p>" ++ a_open ++ "<b>foo[]</b></a><br></p><p>" ++ span_open ++ "bar</span></p>", .backspace = false, .expected = "<p>" ++ a_open ++ "<b>foo</b></a><b>XY</b>" ++ span_open ++ "bar</span></p>" },
    // Without the inner <b> nothing is carried (all three; passing today).
    .{ .markup = "<p>" ++ a_open ++ "foo</a></p><p>" ++ span_open ++ "[]bar</span></p>", .backspace = true, .expected = "<p>" ++ a_open ++ "foo</a>XY" ++ span_open ++ "bar</span></p>" },
    .{ .markup = "<p>" ++ a_open ++ "foo[]</a><br></p><p>" ++ span_open ++ "bar</span></p>", .backspace = false, .expected = "<p>" ++ a_open ++ "foo</a>XY" ++ span_open ++ "bar</span></p>" },
};

fn typingAfterJoinBesideALink() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    var failures: usize = 0;
    for (join_cases) |case| {
        const setup = try std.fmt.allocPrint(std.testing.allocator, "document.getElementById('host').focus(); setupHost({f});", .{std.json.fmt(case.markup, .{})});
        defer std.testing.allocator.free(setup);
        try page.run(setup);
        press(page, if (case.backspace) backspace else delete_key);
        press(page, key_x);
        press(page, key_y);
        const actual = try page.evaluate("hostHTML().replace(/: /g, ':').replace(/;\"/g, '\"')");
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, actual, case.expected)) {
            std.debug.print("{s} in {s}: expected {s}, got {s}\n", .{ if (case.backspace) "Backspace" else "Delete", case.markup, case.expected, actual });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "typing after a join beside a link keeps its inner <b>, not the link or its color (Firefox + Safari; the spec's new <b>)" {
    try helpers.onFreshThread(typingAfterJoinBesideALink);
}

// A05 - Enter in a contenteditable=true element nested in a plaintext-only
// host inserts a line break (Firefox 160 and Safari 27.2; Chrome 157 makes
// a paragraph): editing/plaintext-only/nested-with-contenteditable-true.html,
// FPP at wpt.fyi 2358bd4835. Behind a contenteditable=false element the
// nested host is on its own: a paragraph (all three).
const enter: html.user_input.Key = .{ .key = "Enter", .code = "Enter", .key_code = 13, .text = "\r" };

const EnterCase = struct { markup: []const u8, focus_nested: bool, expected: []const u8 };

const enter_cases = [_]EnterCase{
    .{ .markup = "<div contenteditable=\"\"><p>a[b]c</p></div>", .focus_nested = false, .expected = "<div contenteditable=\"\"><p>a<br>c</p></div>" },
    .{ .markup = "<div contenteditable=\"true\"><p>a[b]c</p></div>", .focus_nested = true, .expected = "<div contenteditable=\"true\"><p>a<br>c</p></div>" },
    .{ .markup = "<div contenteditable=\"false\"><div contenteditable=\"\"><p>a[b]c</p></div></div>", .focus_nested = false, .expected = "<div contenteditable=\"false\"><div contenteditable=\"\"><p>a</p><p>c</p></div></div>" },
};

fn enterInNestedHost() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    var failures: usize = 0;
    for (enter_cases) |case| {
        const setup = try std.fmt.allocPrint(std.testing.allocator,
            \\(() => {{
            \\  const host = document.getElementById('host');
            \\  host.setAttribute('contenteditable', 'plaintext-only');
            \\  host.focus();
            \\  setupHost({f});
            \\  if ({}) host.querySelector('[contenteditable=true],[contenteditable=""]').focus();
            \\}})()
        , .{ std.json.fmt(case.markup, .{}), case.focus_nested });
        defer std.testing.allocator.free(setup);
        try page.run(setup);
        press(page, enter);
        const actual = try page.evaluate("hostHTML()");
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, actual, case.expected)) {
            std.debug.print("Enter in {s}: expected {s}, got {s}\n", .{ case.markup, case.expected, actual });
            failures += 1;
        }
    }
    try page.run("document.getElementById('host').setAttribute('contenteditable', '');");
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "Enter in a contenteditable=true element nested in a plaintext-only host inserts a line break (Firefox + Safari)" {
    try helpers.onFreshThread(enterInNestedHost);
}

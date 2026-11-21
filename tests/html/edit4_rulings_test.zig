//! Lane edit4: the user's rulings of 2026-11-21 (~2:25 PM ET) on the
//! editing map's B decisions.
//!
//! B2 - Enter with the caret in table structure outside a cell (col,
//! colgroup, tbody, tr) puts the paragraph in the table's first cell, as
//! Chrome 157 and Safari 27.2 do (editing/other/insertparagraph-in-non-
//! splittable-element.html).
//! B5 - formatBlock's value over several blocks of one name is that name
//! (the spec, Firefox 160 and the data; editing/run/formatblock.html).
//! B6 - Backspace/Delete's beforeinput target range at a child block's
//! boundary: before the block (Firefox 160 and the test; editing/other/
//! delete-without-unwrapping-first-line-of-child-block.html).
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

const enter: html.user_input.Key = .{ .key = "Enter", .code = "Enter", .key_code = 13, .text = "\r" };
const backspace: html.user_input.Key = .{ .key = "Backspace", .code = "Backspace", .key_code = 8 };
const delete_key: html.user_input.Key = .{ .key = "Delete", .code = "Delete", .key_code = 46 };
const key_x: html.user_input.Key = .{ .key = "X", .code = "KeyX", .key_code = 88, .text = "X" };

fn tableStructure() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    const Case = struct { markup: []const u8, selector: []const u8, expected: []const u8 };
    const cases = [_]Case{
        .{ .markup = "<div><table><colgroup><col></colgroup><tbody><tr><td>abc</td></tr></tbody></table></div>", .selector = "col", .expected = "<div><table><colgroup><col></colgroup><tbody><tr><td><br>abc</td></tr></tbody></table></div>" },
        .{ .markup = "<div><table><colgroup><col></colgroup><tbody><tr><td>abc</td></tr></tbody></table></div>", .selector = "colgroup", .expected = "<div><table><colgroup><col></colgroup><tbody><tr><td><br>abc</td></tr></tbody></table></div>" },
        .{ .markup = "<div><table><tbody><tr><td>abc</td></tr></tbody></table></div>", .selector = "tbody", .expected = "<div><table><tbody><tr><td><br>abc</td></tr></tbody></table></div>" },
        .{ .markup = "<div><table><tbody><tr><td>abc</td></tr></tbody></table></div>", .selector = "tr", .expected = "<div><table><tbody><tr><td><br>abc</td></tr></tbody></table></div>" },
    };
    var failures: usize = 0;
    for (cases) |case| {
        const setup = try std.fmt.allocPrint(std.testing.allocator, "(() => {{ const host = document.getElementById('host'); host.focus(); host.innerHTML = {f}; getSelection().collapse(host.querySelector({f}), 0); }})()", .{ std.json.fmt(case.markup, .{}), std.json.fmt(case.selector, .{}) });
        defer std.testing.allocator.free(setup);
        try page.run(setup);
        press(page, enter);
        const actual = try page.evaluate("hostHTML()");
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, actual, case.expected)) {
            std.debug.print("Enter in {s} of {s}: expected {s}, got {s}\n", .{ case.selector, case.markup, case.expected, actual });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "Enter in table structure outside a cell puts the paragraph in the first cell (B2: Chrome + Safari)" {
    try helpers.onFreshThread(tableStructure);
}

fn formatBlockValue() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run("document.getElementById('host').focus();");
    // Before: two p's share "p"; an h1 and an h2 share nothing; a dt and a
    // dd are their dl (Chrome, Safari and the data).
    try harness.expectEval(page, "setupHost('<p>[foo<p>bar]'); document.queryCommandValue('formatblock')", "p");
    try harness.expectEval(page, "setupHost('<h1>[foo</h1><h2>bar]</h2>'); document.queryCommandValue('formatblock')", "");
    try harness.expectEval(page, "setupHost('<dl><dt>[foo<dd>bar]</dl>'); document.queryCommandValue('formatblock')", "dl");
    // After formatBlock over several blocks: the new blocks' name (all
    // three browsers report it).
    try harness.expectEval(page, "runCommands('<h1>[foo</h1><h2>bar]</h2>', [['formatblock', '<div>']]); document.queryCommandValue('formatblock')", "div");
    try harness.expectEval(page, "runCommands('<p>[foo<p>bar]', [['formatblock', '<dd>']]); document.queryCommandValue('formatblock')", "dd");
    try harness.expectEval(page, "runCommands('<table><tbody><tr><td>foo<td>{bar}<td>baz</table>', [['formatblock', '<p>']]); document.queryCommandValue('formatblock')", "p");
    // One block: unchanged.
    try harness.expectEval(page, "setupHost('<p>f[o]o</p>'); document.queryCommandValue('formatblock')", "p");
}

test "formatBlock's value over several blocks of one name is that name (B5: spec + Firefox)" {
    try helpers.onFreshThread(formatBlockValue);
}

const seen_script =
    \\globalThis.seen = [];
    \\document.getElementById('host').addEventListener('beforeinput', (e) => {
    \\  for (const r of e.getTargetRanges()) seen.push(e.inputType + ':' + r.startContainer.nodeName + ',' + r.startOffset + '-' + r.endContainer.nodeName + ',' + r.endOffset);
    \\  e.preventDefault();
    \\});
;

fn targetRangesAtChildBlock() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try page.run(seen_script);
    const Case = struct { markup: []const u8, key: html.user_input.Key, expected: []const u8 };
    const cases = [_]Case{
        // Over a selection: the end goes before the child block.
        .{ .markup = "abc<br>{<br><div id=\"child\">]def<br>ghi</div>", .key = backspace, .expected = "deleteContentBackward:DIV,2-DIV,3" },
        .{ .markup = "<br>[abc<br><div id=\"child\">]def<br>ghi</div>", .key = delete_key, .expected = "deleteContentForward:#text,0-DIV,3" },
        // Typing over it keeps the end in the child (Chrome and Firefox).
        .{ .markup = "<br>[abc<br><div id=\"child\">]def<br>ghi</div>", .key = key_x, .expected = "insertText:#text,0-#text,0" },
        // A caret: the line break the key removes before the block.
        .{ .markup = "abc<br><br><div id=\"child\">[]def<br>ghi</div>", .key = backspace, .expected = "deleteContentBackward:DIV,2-DIV,3" },
        .{ .markup = "<b>abc<br><br></b><div id=\"child\">[]def<br>ghi</div>", .key = backspace, .expected = "deleteContentBackward:B,2-B,3" },
        .{ .markup = "<b><br></b><div id=\"child\">[]def<br>ghi</div>", .key = backspace, .expected = "deleteContentBackward:DIV,0-DIV,1" },
        .{ .markup = "abc<br>{}<br><div id=\"child\">def<br>ghi</div>", .key = delete_key, .expected = "deleteContentForward:DIV,2-DIV,3" },
        .{ .markup = "<b>{}<br></b><div id=\"child\">def<br>ghi</div>", .key = delete_key, .expected = "deleteContentForward:DIV,0-DIV,1" },
    };
    var failures: usize = 0;
    for (cases) |case| {
        const setup = try std.fmt.allocPrint(std.testing.allocator, "seen.length = 0; document.getElementById('host').focus(); setupHost({f});", .{std.json.fmt(case.markup, .{})});
        defer std.testing.allocator.free(setup);
        try page.run(setup);
        press(page, case.key);
        const actual = try page.evaluate("seen.join('|')");
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, actual, case.expected)) {
            std.debug.print("{s} at {s}: expected {s}, got {s}\n", .{ case.key.key, case.markup, case.expected, actual });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "Backspace/Delete target ranges at a child block's boundary end before the block (B6: Firefox)" {
    try helpers.onFreshThread(targetRangesAtChildBlock);
}

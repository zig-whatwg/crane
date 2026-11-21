//! Lane edit4 (A01): execCommand fires `input` at the editing host for every
//! command that runs, whether or not it changed the DOM tree - Blink's
//! Editor::AppliedEditing and WebKit's Editor::appliedEditing dispatch it
//! for each applied command (Chrome 157 and Safari 27.2 pass these rows of
//! editing/event.html, wpt.fyi 2358bd4835; Firefox 160 and the Editing
//! spec's step 7 fire it only when the action modified the tree). A command
//! whose argument is refused before it runs fires nothing (createLink "",
//! fontSize ""/"quasit", formatBlock "": all three browsers).
//!
//! formatBlock with a value that is a valid qualified name but not a
//! formattable block name ("quasit") returns false and still fires input:
//! Blink's ExecuteFormatBlock parses the name, applies a FormatBlockCommand
//! (which changes nothing) and returns DidApply() (Chrome 157 probe; Safari
//! 27.2 passes the row too).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

const setup_script =
    \\document.body.innerHTML = '<div id=wrap></div>';
    \\globalThis.inputsAfter = (command, value) => {
    \\  const wrap = document.getElementById('wrap');
    \\  wrap.innerHTML = '<div contenteditable>foo<b>bar</b>baz</div>';
    \\  const host = wrap.firstChild;
    \\  const range = document.createRange();
    \\  range.setStart(host.querySelector('b').firstChild, 0);
    \\  range.setEnd(host.querySelector('b'), 1);
    \\  getSelection().removeAllRanges();
    \\  getSelection().addRange(range);
    \\  const seen = [];
    \\  host.addEventListener('input', (e) => seen.push(e.target === host ? 'host' : 'other'));
    \\  const returned = document.execCommand(command, false, value);
    \\  return command + ' ' + JSON.stringify(value) + ': ' + returned + ' ' + seen.length + (seen.length ? ' ' + seen.join('') : '');
    \\};
;

const Case = struct { command: []const u8, value: []const u8, expected: []const u8 };

const cases = [_]Case{
    // Ran, changed nothing: input anyway (Chrome + Safari; Firefox too for
    // "quasit" colours and justifyLeft).
    .{ .command = "backColor", .value = "", .expected = "backColor \"\": true 1 host" },
    .{ .command = "backColor", .value = "quasit", .expected = "backColor \"quasit\": true 1 host" },
    .{ .command = "fontName", .value = "serif", .expected = "fontName \"serif\": true 1 host" },
    .{ .command = "foreColor", .value = "", .expected = "foreColor \"\": true 1 host" },
    .{ .command = "foreColor", .value = "quasit", .expected = "foreColor \"quasit\": true 1 host" },
    .{ .command = "hiliteColor", .value = "", .expected = "hiliteColor \"\": true 1 host" },
    .{ .command = "hiliteColor", .value = "quasit", .expected = "hiliteColor \"quasit\": true 1 host" },
    .{ .command = "unlink", .value = "", .expected = "unlink \"\": true 1 host" },
    .{ .command = "unlink", .value = "quasit", .expected = "unlink \"quasit\": true 1 host" },
    .{ .command = "justifyLeft", .value = "", .expected = "justifyLeft \"\": true 1 host" },
    .{ .command = "outdent", .value = "", .expected = "outdent \"\": true 1 host" },
    // A qualified name that is not a block to format with: false, input.
    .{ .command = "formatBlock", .value = "quasit", .expected = "formatBlock \"quasit\": false 1 host" },
    // Refused before it runs: no input (all three browsers).
    .{ .command = "formatBlock", .value = "", .expected = "formatBlock \"\": false 0" },
    .{ .command = "createLink", .value = "", .expected = "createLink \"\": false 0" },
    .{ .command = "fontSize", .value = "", .expected = "fontSize \"\": false 0" },
    .{ .command = "fontSize", .value = "quasit", .expected = "fontSize \"quasit\": false 0" },
    // Changed the tree: input, as before.
    .{ .command = "backColor", .value = "green", .expected = "backColor \"green\": true 1 host" },
};

fn inputAfterEveryAppliedCommand() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(setup_script);
    var failures: usize = 0;
    for (cases) |case| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "inputsAfter({f}, {f})", .{ std.json.fmt(case.command, .{}), std.json.fmt(case.value, .{}) });
        defer std.testing.allocator.free(source);
        const actual = try page.evaluate(source);
        defer std.testing.allocator.free(actual);
        if (!std.mem.eql(u8, actual, case.expected)) {
            std.debug.print("expected {s}, got {s}\n", .{ case.expected, actual });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "execCommand fires input for every command that runs, changed or not (Chrome + Safari)" {
    try helpers.onFreshThread(inputAfterEveryAppliedCommand);
}

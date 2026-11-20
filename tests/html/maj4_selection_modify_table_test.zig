//! Selection.modify("move", "backward", "character") from the paragraph
//! after a table walks back through the cell's text and out of the table to
//! the paragraph before it, as forward walks out the other way
//! (selection/selection-modify-across-*-table*.html, character granularity:
//! Chrome, Firefox and Safari reach the paragraph at wpt.fyi 2358bd4835).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

const walk_script =
    \\globalThis.where = (n, o) => (n.nodeType === 3 ? JSON.stringify(n.data.trim()) : n.localName) + '@' + o;
    \\globalThis.walk = (direction, from, to) => {
    \\  const start = document.querySelector(from);
    \\  getSelection().collapse(start.firstChild, direction == 'backward' ? 0 : start.firstChild.length);
    \\  const target = document.querySelector(to);
    \\  const path = [];
    \\  for (let i = 0; i < 10; i++) {
    \\    getSelection().modify('move', direction, 'character');
    \\    path.push(where(getSelection().focusNode, getSelection().focusOffset));
    \\    if (target.contains(getSelection().focusNode)) return 'reached ' + path.join(' ');
    \\  }
    \\  return 'stuck ' + path.join(' ');
    \\};
;

/// The WPT files' markup: white-space between the blocks and `table`, the
/// table element as each file writes it.
fn markup(comptime table: []const u8) []const u8 {
    return "document.body.innerHTML = '\\n  <p>preceding paragraph1</p>\\n  " ++ table ++ "\\n  <p>preceding paragraph2</p>\\n';";
}

fn walkOutOfTable(comptime table: []const u8, editable: bool) !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(walk_script);
    try page.run(markup(table));
    if (editable) try page.run("document.body.setAttribute('contenteditable', 'true');");
    const back = try page.evaluate("walk('backward', 'p + table + p', 'p')");
    defer std.testing.allocator.free(back);
    const forward = try page.evaluate("walk('forward', 'p', 'p + table + p')");
    defer std.testing.allocator.free(forward);
    if (!std.mem.startsWith(u8, back, "reached ") or !std.mem.startsWith(u8, forward, "reached ")) {
        std.debug.print("{s} (editable {}):\n  backward {s}\n  forward {s}\n", .{ table, editable, back, forward });
        return error.StuckInTable;
    }
}

const minimum = "<table><td>cell1</td></table>";
const caption = "<table><caption>caption</caption><td>cell1</td></table>";
const col = "<table><colgroup><col><col></colgroup><tr><td>cell1</td><td>cell2</td></tr></table>";
const thead = "<table><thead><tr><th>head1</th><th>head2</th></tr></thead><tbody><tr><td>cell1</td><td>cell2</td></tr></tbody></table>";
const tfoot_after = "<table><tbody><tr><td>cell1</td><td>cell2</td></tr></tbody><tfoot><tr><th>foot1</th><th>foot2</th></tr></tfoot></table>";
const tfoot_before = "<table><tfoot><tr><th>foot1</th><th>foot2</th></tr></tfoot><tbody><tr><td>cell1</td><td>cell2</td></tr></tbody></table>";

fn minimumTable() !void {
    try walkOutOfTable(minimum, false);
    try walkOutOfTable(minimum, true);
}

test "modify by character walks out of a minimal table both ways" {
    try helpers.onFreshThread(minimumTable);
}

fn tablesWithSections() !void {
    var failed = false;
    inline for (.{ caption, col, thead, tfoot_after, tfoot_before }) |table| {
        for ([_]bool{ false, true }) |editable| {
            walkOutOfTable(table, editable) catch {
                failed = true;
            };
        }
    }
    if (failed) return error.StuckInTable;
}

test "modify by character walks out of a table with a caption, col, thead or tfoot both ways" {
    try helpers.onFreshThread(tablesWithSections);
}

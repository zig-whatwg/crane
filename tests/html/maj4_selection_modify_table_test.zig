//! Selection.modify("move", "backward", "character") from the paragraph
//! after a table walks back through the cell's text and out of the table to
//! the paragraph before it, as forward walks out the other way
//! (selection/selection-modify-across-*-table*.html, character granularity:
//! Chrome, Firefox and Safari reach the paragraph at wpt.fyi 2358bd4835).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

const walk_script =
    \\globalThis.where = (n, o) => (n.nodeType === 3 ? JSON.stringify(n.data.trim()) : n.localName) + '@' + o;
    \\globalThis.walk = (direction, from, to, limit) => {
    \\  const start = document.querySelector(from);
    \\  getSelection().collapse(start.firstChild, direction == 'backward' ? 0 : start.firstChild.length);
    \\  const target = document.querySelector(to);
    \\  const path = [];
    \\  for (let i = 0; i < limit; i++) {
    \\    getSelection().modify('move', direction, 'character');
    \\    path.push(where(getSelection().focusNode, getSelection().focusOffset));
    \\    if (target.contains(getSelection().focusNode)) return 'reached ' + path.join(' ');
    \\  }
    \\  return 'stuck ' + path.join(' ');
    \\};
;

/// The WPT files' body markup (white-space included) and each file's step
/// limit.
fn markup(comptime table: []const u8) []const u8 {
    return "document.body.innerHTML = '\\n  <p>preceding paragraph1</p>\\n  " ++ table ++ "\\n  <p>preceding paragraph2</p>\\n';";
}

/// Both walks, as the WPT file makes them: the paths, or error.StuckInTable
/// with both printed.
fn walks(comptime table: []const u8, editable: bool, comptime limit: u32) ![2][]u8 {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(walk_script);
    try page.run(markup(table));
    if (editable) try page.run("document.body.setAttribute('contenteditable', 'true');");
    const limit_text = std.fmt.comptimePrint("{d}", .{limit});
    const back = try page.evaluate("walk('backward', 'p + table + p', 'p', " ++ limit_text ++ ")");
    errdefer std.testing.allocator.free(back);
    const forward = try page.evaluate("walk('forward', 'p', 'p + table + p', " ++ limit_text ++ ")");
    errdefer std.testing.allocator.free(forward);
    if (!std.mem.startsWith(u8, back, "reached ") or !std.mem.startsWith(u8, forward, "reached ")) {
        std.debug.print("{s} (editable {}):\n  backward {s}\n  forward {s}\n", .{ table, editable, back, forward });
        return error.StuckInTable;
    }
    return .{ back, forward };
}

const minimum = "<table><td>cell1</td></table>";
const caption = "<table><caption>caption</caption><td>cell1</td></table>";
const col = "<table>\\n    <colgroup>\\n      <col>\\n      <col>\\n    </colgroup>\\n    <tr><td>cell1</td><td>cell2</td></tr>\\n  </table>";
const thead = "<table>\\n    <thead>\\n      <tr><th>head1</th><th>head2</th></tr>\\n    </thead>\\n    <tbody>\\n      <tr><td>cell1</td><td>cell2</td></tr>\\n    </tbody>\\n  </table>";
const tfoot_after = "<table>\\n    <tbody>\\n      <tr><td>cell1</td><td>cell2</td></tr>\\n    </tbody>\\n    <tfoot>\\n      <tr><th>foot1</th><th>foot2</th></tr>\\n    </tfoot>\\n  </table>";
const tfoot_before = "<table>\\n    <tfoot>\\n      <tr><th>foot1</th><th>foot2</th></tr>\\n    </tfoot>\\n    <tbody>\\n      <tr><td>cell1</td><td>cell2</td></tr>\\n    </tbody>\\n  </table>";

fn minimumTable() !void {
    for ([_]bool{ false, true }) |editable| {
        const paths = try walks(minimum, editable, 10);
        defer for (paths) |path| std.testing.allocator.free(path);
        // Chrome's paths (probed headless at 157): after the table, the
        // cell's text, before the table, the paragraph - and back.
        try std.testing.expectEqualStrings("reached body@4 \"cell1\"@5 \"cell1\"@4 \"cell1\"@3 \"cell1\"@2 \"cell1\"@1 \"cell1\"@0 body@3 \"preceding paragraph1\"@20", paths[0]);
        try std.testing.expectEqualStrings("reached body@3 \"cell1\"@0 \"cell1\"@1 \"cell1\"@2 \"cell1\"@3 \"cell1\"@4 \"cell1\"@5 body@4 \"preceding paragraph2\"@0", paths[1]);
    }
}

test "modify by character walks out of a minimal table both ways, through after and before the table" {
    try helpers.onFreshThread(minimumTable);
}

fn tablesWithSections() !void {
    var failed = false;
    inline for (.{ .{ caption, 20 }, .{ col, 15 }, .{ thead, 30 }, .{ tfoot_after, 30 }, .{ tfoot_before, 30 } }) |case| {
        for ([_]bool{ false, true }) |editable| {
            if (walks(case[0], editable, case[1])) |paths| {
                for (paths) |path| std.testing.allocator.free(path);
            } else |_| failed = true;
        }
    }
    if (failed) return error.StuckInTable;
}

test "modify by character walks out of a table with a caption, col, thead or tfoot both ways" {
    try helpers.onFreshThread(tablesWithSections);
}

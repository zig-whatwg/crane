//! Lane orphanleak: a table's, a table section's and a row's own state - the
//! rows, tBodies and cells collections, made when script first asks - needs
//! an exit when the element is an ORPHAN: its wrapper collected while it was
//! in its tree, then the tree dropped while nothing wrapped it, so nothing
//! deinits it before its Browser ends
//! (docs/lessons/architecture-an-orphan-s-state-needs-a-sweep-or-the-arena.md).
//!
//! The Browser runs on std.testing.allocator, so a block left at its end
//! fails the test. Each test runs on a thread of its own: tests/html is one
//! executable, and a Browser's agent belongs to the thread that made it.
const helpers = @import("edges_node_holders_helpers.zig");

fn collectionsOrphaned() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<table><thead><tr><th>h</tr></thead><tbody><tr><td>1<td>2</tr></tbody>' +
        \\                 '<tfoot><tr><td>f</tr></tfoot></table>';
        \\(() => {
        \\  const table = host.firstChild;
        \\  if (table.rows.length !== 3 || table.tBodies.length !== 1) throw new Error('table collections');
        \\  if (table.tHead.rows.length !== 1 || table.tBodies[0].rows.length !== 1 || table.tFoot.rows.length !== 1) throw new Error('section rows');
        \\  if (table.rows[1].cells.length !== 2) throw new Error('row cells');
        \\})();
    );
    try page.turn();
    try page.run("collectNow();");
    try page.run(
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
    );
}

test "table collections made by script, wrappers collected, tree dropped, leave nothing" {
    try helpers.onFreshThread(collectionsOrphaned);
}

fn retainedTableKeepsRows() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<table><tr><td>1</tr></table>';
        \\const table = host.firstChild;
        \\const rows = table.rows;
        \\host.innerHTML = '';
        \\if (rows.length !== 1 || table.rows !== rows) throw new Error('lost its rows');
    );
}

test "a retained table keeps its live rows after its tree is dropped" {
    try helpers.onFreshThread(retainedTableKeepsRows);
}

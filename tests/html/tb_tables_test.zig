//! HTML table collection ordering and mutations, without a JS engine.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const tables = @import("html").tables;
const t = std.testing;

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(t.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(t.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(t.allocator, &context);
    defer interfaces.Document.deinit(document);
    const table = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("table"), .notPassed());
    defer dom.node_creation.destroyUninserted(table);
    const rows = try interfaces.HTMLTableElement.get_rows(table);
    const bodies = try interfaces.HTMLTableElement.get_tBodies(table);
    try t.expectEqual(rows, try interfaces.HTMLTableElement.get_rows(table));
    try t.expectEqual(bodies, try interfaces.HTMLTableElement.get_tBodies(table));
    try t.expectEqual(@as(u32, 0), try interfaces.HTMLCollection.get_length(rows));
    try interfaces.HTMLTableElement.call_deleteRow(table, -1);
    try t.expectError(error.IndexSizeError, interfaces.HTMLTableElement.call_insertRow(table, .passed(-2)));
    try t.expectError(error.IndexSizeError, interfaces.HTMLTableElement.call_deleteRow(table, 0));
    const foot = try interfaces.HTMLTableElement.call_createTFoot(table);
    const body = try interfaces.HTMLTableElement.call_createTBody(table);
    const head = try interfaces.HTMLTableElement.call_createTHead(table);
    const caption = try interfaces.HTMLTableElement.call_createCaption(table);
    try t.expectEqual(caption, (try interfaces.Node.get_firstChild(table)).?);
    try t.expectEqual(head, (try interfaces.Node.get_nextSibling(caption)).?);
    try t.expectEqual(head, try interfaces.HTMLTableElement.call_createTHead(table));
    try t.expectError(error.HierarchyRequestError, interfaces.HTMLTableElement.set_tHead(table, foot));
    try t.expectEqual(head, (try interfaces.HTMLTableElement.get_tHead(table)).?);
    const f = try interfaces.HTMLTableSectionElement.call_insertRow(foot, .notPassed());
    const b = try interfaces.HTMLTableSectionElement.call_insertRow(body, .notPassed());
    const h = try interfaces.HTMLTableSectionElement.call_insertRow(head, .notPassed());
    const direct = try tables.createElement(table, "tr");
    try tables.insert(table, direct, body);
    for ([_]*runtime.Instance{ h, direct, b, f }, 0..) |row, index| {
        try t.expectEqual(row, (try interfaces.HTMLCollection.call_item(rows, @intCast(index))).?);
        try t.expectEqual(@as(i32, @intCast(index)), try interfaces.HTMLTableRowElement.get_rowIndex(row));
    }
    try t.expectEqual(@as(i32, 1), try interfaces.HTMLTableRowElement.get_sectionRowIndex(direct));
    const section_rows = try interfaces.HTMLTableSectionElement.get_rows(head);
    try tables.insert(head, b, null);
    try t.expectEqual(@as(u32, 2), try interfaces.HTMLCollection.get_length(section_rows));
    try t.expectEqual(@as(i32, 1), try interfaces.HTMLTableRowElement.get_sectionRowIndex(b));
    const cells = try interfaces.HTMLTableRowElement.get_cells(h);
    const cell = try interfaces.HTMLTableRowElement.call_insertCell(h, .notPassed());
    const first = try interfaces.HTMLTableRowElement.call_insertCell(h, .passed(0));
    try t.expectEqual(first, (try interfaces.HTMLCollection.call_item(cells, 0)).?);
    try t.expectEqual(@as(i32, 1), try interfaces.HTMLTableCellElement.get_cellIndex(cell));
    try t.expectError(error.IndexSizeError, interfaces.HTMLTableRowElement.call_insertCell(h, .passed(3)));
    try interfaces.HTMLTableRowElement.call_deleteCell(h, -1);
    dom.node_creation.destroyUninserted(cell);
    try t.expectEqual(@as(u32, 1), try interfaces.HTMLCollection.get_length(cells));
    const last = try interfaces.HTMLTableElement.call_insertRow(table, .notPassed());
    try t.expectEqual(foot, (try interfaces.Node.get_parentNode(last)).?);
    try interfaces.HTMLTableElement.call_deleteRow(table, -1);
    dom.node_creation.destroyUninserted(last);
    try t.expectEqual(@as(u32, 4), try interfaces.HTMLCollection.get_length(rows));
    try interfaces.HTMLTableElement.call_deleteCaption(table);
    dom.node_creation.destroyUninserted(caption);
    try t.expectEqual(null, try interfaces.HTMLTableElement.get_caption(table));
}

test "table collections share HTML order and stay live across moves and indexed edits" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

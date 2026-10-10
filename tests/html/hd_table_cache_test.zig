//! Table caches must follow their root's current document after adoption.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const t = std.testing;

fn append(document: *runtime.Instance, parent: *runtime.Instance, name: []const u8) !*runtime.Instance {
    const child = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
    errdefer dom.node_creation.destroyUninserted(child);
    _ = try interfaces.Node.call_appendChild(parent, child);
    return child;
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(t.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(t.allocator, .{});
    defer context.deinit();
    for ([_]dom.live_collections.TableFilter{ .bodies, .table_rows, .section_rows, .row_cells }) |kind| {
        const source = try interfaces.Document.init(t.allocator, &context);
        defer interfaces.Document.deinit(source);
        const destination = try interfaces.Document.init(t.allocator, &context);
        defer interfaces.Document.deinit(destination);
        const table = try append(source, source, "table");
        const section = try append(source, table, "tbody");
        const row = try append(source, section, "tr");
        const cell = try append(source, row, "td");
        const collection = switch (kind) {
            .bodies => try interfaces.HTMLTableElement.get_tBodies(table),
            .table_rows => try interfaces.HTMLTableElement.get_rows(table),
            .section_rows => try interfaces.HTMLTableSectionElement.get_rows(section),
            .row_cells => try interfaces.HTMLTableRowElement.get_cells(row),
        };
        const parent = switch (kind) {
            .bodies => table,
            .table_rows, .section_rows => section,
            .row_cells => row,
        };
        const first = switch (kind) {
            .bodies => section,
            .table_rows, .section_rows => row,
            .row_cells => cell,
        };
        const name: []const u8 = switch (kind) {
            .bodies => "tbody",
            .table_rows, .section_rows => "tr",
            .row_cells => "th",
        };
        try t.expectEqual(@as(u32, 1), try interfaces.HTMLCollection.get_length(collection));
        try t.expectEqual(first, (try interfaces.HTMLCollection.call_item(collection, 0)).?);
        _ = try interfaces.Document.call_adoptNode(destination, table);
        _ = try interfaces.Node.call_appendChild(destination, table);
        try t.expectEqual(destination, (try interfaces.Node.get_ownerDocument(table)).?);
        const second = try append(destination, parent, name);
        try t.expectEqual(@as(u32, 2), try interfaces.HTMLCollection.get_length(collection));
        try t.expectEqual(second, (try interfaces.HTMLCollection.call_item(collection, 1)).?);
        _ = try interfaces.Node.call_removeChild(parent, first);
        defer dom.node_creation.destroyUninserted(first);
        try t.expectEqual(@as(u32, 1), try interfaces.HTMLCollection.get_length(collection));
        try t.expectEqual(second, (try interfaces.HTMLCollection.call_item(collection, 0)).?);
        try t.expectEqual(null, try interfaces.HTMLCollection.call_item(collection, 1));
    }
}

test "all table collection kinds invalidate after adoption and removal" {
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

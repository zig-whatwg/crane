//! Table cell indices and scope reflection through the public interfaces.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const t = std.testing;

fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
}

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(t.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(t.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(t.allocator, &context);
    defer interfaces.Document.deinit(document);
    const row = try element(document, "tr");
    defer dom.node_creation.destroyUninserted(row);
    const td = try element(document, "td");
    var inserted = false;
    defer if (!inserted) dom.node_creation.destroyUninserted(td);
    try t.expectEqual(@as(i32, -1), try interfaces.HTMLTableCellElement.get_cellIndex(td));
    _ = try interfaces.Node.call_appendChild(row, td);
    inserted = true;
    const foreign = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("urn:test"), runtime.DOMString.initInterned("td"), .notPassed());
    _ = try interfaces.Node.call_appendChild(row, foreign);
    const th = try element(document, "th");
    _ = try interfaces.Node.call_appendChild(row, th);
    try t.expectEqual(@as(i32, 0), try interfaces.HTMLTableCellElement.get_cellIndex(td));
    try t.expectEqual(@as(i32, 1), try interfaces.HTMLTableCellElement.get_cellIndex(th));
    _ = try interfaces.Node.call_insertBefore(row, th, td);
    try t.expectEqual(@as(i32, 0), try interfaces.HTMLTableCellElement.get_cellIndex(th));
    try t.expectEqual(@as(i32, 1), try interfaces.HTMLTableCellElement.get_cellIndex(td));
    for ([_][]const u8{ "ROW", "col", "ROWGROUP", "colgroup", "row ", "auto" }, [_][]const u8{ "row", "col", "rowgroup", "colgroup", "", "" }) |input, expected| {
        try interfaces.HTMLTableCellElement.set_scope(td, runtime.DOMString.initInterned(input));
        var scope = try interfaces.HTMLTableCellElement.get_scope(td);
        defer scope.deinit(t.allocator);
        try t.expectEqualStrings(expected, scope.asSlice());
        const attribute = (try interfaces.Element.call_getAttribute(td, runtime.DOMString.initInterned("scope"))).?;
        try t.expectEqualStrings(input, attribute.asSlice());
    }
}

test "table cell index follows HTML siblings and scope recognizes only enumerated values" {
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

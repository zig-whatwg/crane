//! HTML's selected File objects survive entry-list construction unchanged.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn selectedFiles() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    const form = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("form"), .notPassed());
    defer dom.node_creation.destroyUninserted(form);
    const input = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("input"), .notPassed());
    _ = try interfaces.Node.call_appendChild(form, input);
    try interfaces.HTMLInputElement.set_type(input, runtime.DOMString.initInterned("file"));
    try interfaces.HTMLInputElement.set_name(input, runtime.DOMString.initInterned("upload"));
    const first = try interfaces.File.init(testing.allocator, &context);
    defer runtime.Instance.deinit(first);
    const second = try interfaces.File.init(testing.allocator, &context);
    defer runtime.Instance.deinit(second);
    const files = (try interfaces.HTMLInputElement.get_files(input)).?;
    try dom.file_lists.append(files, first);
    try dom.file_lists.append(files, second);
    const data = try interfaces.FormData.call_constructor(&context, .notPassed(), .notPassed());
    defer runtime.Instance.deinit(data);
    try dom.form_submission.constructEntryList(form, null, data);
    const entries = interfaces.FormData.getEntriesForIterable(data).?;
    try testing.expectEqual(@as(usize, 2), entries.len);
    try testing.expectEqualStrings("upload", entries[0].name);
    try testing.expectEqualStrings("upload", entries[1].name);
    try testing.expectEqual(first, entries[0].value.file);
    try testing.expectEqual(second, entries[1].value.file);
    try dom.file_lists.clear(files);
    try testing.expectEqual(first, entries[0].value.file);
    try testing.expectEqual(second, entries[1].value.file);
}

test "form entry list preserves each selected File in order, independently of selection" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            selectedFiles() catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

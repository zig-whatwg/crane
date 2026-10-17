//! Cached live label lists in the engine-free path must release their holds.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer interfaces.Document.deinit(document);
    inline for (.{
        .{ "input", interfaces.HTMLInputElement },
        .{ "button", interfaces.HTMLButtonElement },
        .{ "select", interfaces.HTMLSelectElement },
        .{ "textarea", interfaces.HTMLTextAreaElement },
        .{ "progress", interfaces.HTMLProgressElement },
        .{ "meter", interfaces.HTMLMeterElement },
        .{ "output", interfaces.HTMLOutputElement },
    }) |case| {
        const label = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("label"), .notPassed());
        defer dom.node_creation.destroyUninserted(label);
        const control = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(case[0]), .notPassed());
        _ = try interfaces.Node.call_appendChild(label, control);
        const labels = if (comptime std.mem.eql(u8, case[0], "input")) (try case[1].get_labels(control)).? else try case[1].get_labels(control);
        const again = if (comptime std.mem.eql(u8, case[0], "input")) (try case[1].get_labels(control)).? else try case[1].get_labels(control);
        try testing.expectEqual(labels, again);
        try testing.expectEqual(@as(u32, 1), try interfaces.NodeList.get_length(labels));
        try testing.expectEqual(label, (try interfaces.NodeList.call_item(labels, 0)).?);
        if (comptime std.mem.eql(u8, case[0], "input")) {
            try interfaces.HTMLInputElement.set_type(control, runtime.DOMString.initInterned("hidden"));
            try testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.HTMLInputElement.get_labels(control));
            try testing.expectEqual(@as(u32, 0), try interfaces.NodeList.get_length(labels));
            try interfaces.HTMLInputElement.set_type(control, runtime.DOMString.initInterned("text"));
            try testing.expectEqual(labels, (try interfaces.HTMLInputElement.get_labels(control)).?);
        }
    }
}

test "all native labelable controls cache live labels without engine-free leaks" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

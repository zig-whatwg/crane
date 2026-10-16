//! HTML 4.10.20: all selection offsets measure the API value in UTF-16,
//! including the lone surrogate code units represented by WTF-8.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn exercise() !void {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(allocator, &context);
    defer interfaces.Document.deinit(document);
    const area = try interfaces.Document.call_createElementNS(document, .initInterned("http://www.w3.org/1999/xhtml"), .initInterned("textarea"), .notPassed());
    defer dom.node_creation.destroyUninserted(area);
    const samples = [_]struct { text: []const u8, units: u32 }{
        .{ .text = "a\xED\xA0\x80b", .units = 3 },
        .{ .text = "a\xED\xB0\x80b", .units = 3 },
        .{ .text = "\xED\xA0\x80\xED\xA0\x80", .units = 2 },
        .{ .text = "a\r\n\xED\xA0\x80b", .units = 4 },
        .{ .text = "a\xF0\x9F\x98\x80b", .units = 4 },
    };
    for (samples) |sample| {
        try interfaces.HTMLTextAreaElement.set_value(area, .initInterned(sample.text));
        try interfaces.HTMLTextAreaElement.call_setSelectionRange(area, 100, 100, .notPassed());
        try std.testing.expectEqual(sample.units, try interfaces.HTMLTextAreaElement.get_selectionStart(area));
        try std.testing.expectEqual(sample.units, try interfaces.HTMLTextAreaElement.get_selectionEnd(area));
    }
}

test "textarea selection clamps WTF-8 to normalized UTF-16 code units" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise() catch |err| {
                result.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

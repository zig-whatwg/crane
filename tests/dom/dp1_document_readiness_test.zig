//! HTML §3.1.5: current document readiness is initially complete.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");

test "dp1 standalone Document constructor starts complete" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();

    const document = try interfaces.Document.call_constructor(&context);
    defer interfaces.Document.deinit(document);
    try std.testing.expectEqual(enums.DocumentReadyState._complete_, try interfaces.Document.get_readyState(document));
}

test "dp1 document readiness is a construction fact for both interfaces" {
    try std.testing.expect(interfaces.Document.takesConstructionArg("ready_state"));
    try std.testing.expect(interfaces.XMLDocument.takesConstructionArg("ready_state"));
    if (comptime interfaces.Document.takesConstructionArg("ready_state")) {
        const allocator = std.testing.allocator;
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(allocator);
        defer runtime.deinitializeRuntime();
        var context = try runtime.ContextData.init(allocator, .{});
        defer context.deinit();
        inline for (.{ interfaces.Document, interfaces.XMLDocument }) |Interface| {
            for ([_]enums.DocumentReadyState{ ._loading_, ._complete_ }) |state| {
                const document = try Interface.initWith(allocator, &context, .{ .ready_state = state });
                defer Interface.deinit(document);
                try std.testing.expectEqual(state, try interfaces.Document.get_readyState(document));
            }
        }
    }
}

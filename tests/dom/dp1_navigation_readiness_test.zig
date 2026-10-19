//! Integration pin: apply with explicit navigation loading and the complete default.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");

test "dp1 document defaults complete and navigation explicitly starts loading" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    inline for (.{ interfaces.Document, interfaces.XMLDocument }) |Interface| {
        const standalone = try Interface.init(allocator, &context);
        defer Interface.deinit(standalone);
        try std.testing.expectEqual(enums.DocumentReadyState._complete_, try interfaces.Document.get_readyState(standalone));
        const navigation = try Interface.initWith(allocator, &context, .{ .ready_state = ._loading_ });
        defer Interface.deinit(navigation);
        try std.testing.expectEqual(enums.DocumentReadyState._loading_, try interfaces.Document.get_readyState(navigation));
    }
}

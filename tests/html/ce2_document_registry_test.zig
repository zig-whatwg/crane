//! HTML 4.13.4: scoped registry initialization persists on its document.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn exercise() !void {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.init(testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(document);
    const registry = try interfaces.CustomElementRegistry.call_constructor(&context);
    defer runtime.Instance.deinit(registry);
    const other = try interfaces.CustomElementRegistry.call_constructor(&context);
    defer runtime.Instance.deinit(other);
    const global = try interfaces.CustomElementRegistry.init(testing.allocator, &context);
    defer runtime.Instance.deinit(global);

    try testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Document.get_customElementRegistry(document));
    try testing.expectError(error.NotSupportedError, interfaces.CustomElementRegistry.call_initialize(global, document));
    try interfaces.CustomElementRegistry.call_initialize(registry, document);
    try testing.expectEqual(@as(?*runtime.Instance, registry), try interfaces.Document.get_customElementRegistry(document));
    try interfaces.CustomElementRegistry.call_initialize(other, document);
    try testing.expectEqual(@as(?*runtime.Instance, registry), try interfaces.Document.get_customElementRegistry(document));

    // A global registry created without an engine belongs to its document.
    const native_document = try interfaces.Document.init(testing.allocator, &context);
    defer dom.node_creation.destroyUninserted(native_document);
    const owned_global = try dom.custom_elements.ensureGlobalRegistry(native_document);
    try testing.expectEqual(owned_global, try dom.custom_elements.ensureGlobalRegistry(native_document));
    try testing.expectEqual(@as(?*runtime.Instance, owned_global), try interfaces.Document.get_customElementRegistry(native_document));
}

test "CE2 registry: initialize sets a null document association exactly once" {
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

//! PermissionStatus construction uses EventTarget's generated parent chain.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

test "permissions getters cache per navigator and statuses are EventTargets" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx = try runtime.ContextData.init(allocator, .{});
    defer ctx.deinit();

    const navigator = try interfaces.Navigator.init(allocator, &ctx);
    defer interfaces.Navigator.deinit(navigator);
    const permissions = try interfaces.Navigator.get_permissions(navigator);
    defer interfaces.Permissions.deinit(permissions);
    try std.testing.expectEqual(permissions, try interfaces.Navigator.get_permissions(navigator));

    const worker = try interfaces.WorkerNavigator.init(allocator, &ctx);
    defer interfaces.WorkerNavigator.deinit(worker);
    const worker_permissions = try interfaces.WorkerNavigator.get_permissions(worker);
    defer interfaces.Permissions.deinit(worker_permissions);
    try std.testing.expectEqual(worker_permissions, try interfaces.WorkerNavigator.get_permissions(worker));
    try std.testing.expect(permissions != worker_permissions);

    const status = try interfaces.PermissionStatus.init(allocator, &ctx);
    defer interfaces.PermissionStatus.deinit(status);
    try std.testing.expectEqualStrings("", (try interfaces.PermissionStatus.get_name(status)).asSlice());
    try std.testing.expectEqual(._prompt_, try interfaces.PermissionStatus.get_state(status));
    try std.testing.expectEqual(null, try interfaces.PermissionStatus.get_onchange(status));

    // Construction facts go through the generated interface, not an impl
    // helper or a write into another type's private state.
    const initialized = try interfaces.PermissionStatus.initWith(allocator, &ctx, .{
        .permission_state = .granted,
    });
    defer interfaces.PermissionStatus.deinit(initialized);
    try std.testing.expectEqualStrings("", (try interfaces.PermissionStatus.get_name(initialized)).asSlice());
    try std.testing.expectEqual(._granted_, try interfaces.PermissionStatus.get_state(initialized));
}

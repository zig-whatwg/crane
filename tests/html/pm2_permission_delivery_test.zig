const std = @import("std");
const runtime = @import("runtime");
const permissions = @import("permissions");

test "permission targets re-evaluate repeated overrides after an earlier inactive update" {
    const Target = struct {
        updates: usize = 0,
        active: bool = false,
        state: permissions.PermissionState = .prompt,
        const methods = .{};
        const vtable: runtime.VTable = .{
            .name = "pm2-permission-target",
            .deinit = null,
            .methods_ptr = &methods,
            .state_size = @sizeOf(@This()),
            .state_align = @alignOf(@This()),
        };

        fn update(instance: *runtime.Instance, next: permissions.PermissionState) void {
            const self = instance.getState(@This());
            self.updates += 1;
            if (self.active) self.state = next;
        }
    };
    var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("permission target leaked");
    const allocator = gpa.allocator();
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    realm.browser_scope = &scope;
    const target = try runtime.Instance.init(allocator, Target, &Target.vtable, &realm);
    defer target.deinit();
    target.getState(Target).* = .{};
    const store = try scope.of(permissions.BrowserStore);
    const descriptor = permissions.PermissionDescriptor.simple(.geolocation);
    _ = try store.listen(target, "https://pm2.test", descriptor, .prompt, Target.update);
    defer store.unlisten(target);

    const first = try store.set("https://pm2.test", descriptor, .granted);
    defer first.release();
    try std.testing.expect(first.isDone());
    try std.testing.expectEqual(.prompt, target.getState(Target).state);
    target.getState(Target).active = true;
    const second = try store.set("https://pm2.test", descriptor, .granted);
    defer second.release();
    try std.testing.expect(second.isDone());
    try std.testing.expectEqual(@as(usize, 2), target.getState(Target).updates);
    try std.testing.expectEqual(.granted, target.getState(Target).state);
}

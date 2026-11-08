//! Lane flaky5: the Browser's automation overrides reset between tests.
//!
//! permissions/permissions-cg.https.html timed out in generation 210's sweep
//! because the file its runner process ran two files earlier,
//! permissions/event-model.https.html, ends with geolocation set to
//! "granted" and never resets it: one Browser serves every file of a runner
//! process, so permissions-cg's own set_permission("granted") changed
//! nothing and no change event came. wptrunner's Chrome executor resets the
//! overrides before every test (ChromeDriverTestharnessProtocolPart.
//! reset_browser_state: CDP Browser.resetPermissions), which Chromium's
//! PermissionControllerImpl::ResetPermissionOverrides implements: the
//! overrides are gone, and every subscription whose status changed is told
//! (NotifyChangedSubscriptions).
const std = @import("std");
const runtime = @import("runtime");
const permissions = @import("permissions");

const Target = struct {
    updates: usize = 0,
    state: permissions.PermissionState = .prompt,
    const methods = .{};
    const vtable: runtime.VTable = .{
        .name = "flaky5-permission-target",
        .deinit = null,
        .methods_ptr = &methods,
        .state_size = @sizeOf(@This()),
        .state_align = @alignOf(@This()),
    };

    fn update(instance: *runtime.Instance, next: permissions.PermissionState) void {
        const self = instance.getState(@This());
        self.updates += 1;
        self.state = next;
    }
};

test "a reset of the automation overrides leaves the store without them" {
    var gpa: @import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("permission store leaked");
    const allocator = gpa.allocator();
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    const store = try scope.of(permissions.BrowserStore);
    const geolocation = permissions.PermissionDescriptor.simple(.geolocation);
    const camera = permissions.PermissionDescriptor.simple(.camera);

    // What permissions/event-model.https.html leaves behind.
    const set = try store.set("https://web-platform.test:8443", geolocation, .granted);
    set.release();
    const other = try store.set("https://www1.web-platform.test:8443", camera, .denied);
    other.release();
    try std.testing.expectEqual(.granted, store.get("https://web-platform.test:8443", geolocation).?);

    const reset = try store.resetOverrides();
    defer reset.release();
    try std.testing.expect(reset.isDone());
    try std.testing.expectEqual(null, store.get("https://web-platform.test:8443", geolocation));
    try std.testing.expectEqual(null, store.get("https://www1.web-platform.test:8443", camera));

    // permissions-cg's own step then changes the state again.
    const again = try store.set("https://web-platform.test:8443", geolocation, .granted);
    again.release();
    try std.testing.expectEqual(.granted, store.get("https://web-platform.test:8443", geolocation).?);
}

test "a reset tells every status its state without the override, as Chromium's NotifyChangedSubscriptions does" {
    var gpa: @import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(gpa.deinit() == .ok) catch @panic("permission target leaked");
    const allocator = gpa.allocator();
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    realm.browser_scope = &scope;
    const store = try scope.of(permissions.BrowserStore);
    const geolocation = permissions.PermissionDescriptor.simple(.geolocation);

    // A secure context's status (its platform default "prompt") and an
    // insecure one's ("denied"), both overridden to "granted".
    const secure = try runtime.Instance.init(allocator, Target, &Target.vtable, &realm);
    defer secure.deinit();
    secure.getState(Target).* = .{};
    try std.testing.expectEqual(.prompt, try store.listen(secure, "https://flaky5.test", geolocation, .prompt, Target.update));
    defer store.unlisten(secure);
    const insecure = try runtime.Instance.init(allocator, Target, &Target.vtable, &realm);
    defer insecure.deinit();
    insecure.getState(Target).* = .{ .state = .denied };
    try std.testing.expectEqual(.denied, try store.listen(insecure, "http://flaky5.test", geolocation, .denied, Target.update));
    defer store.unlisten(insecure);

    const granted = try store.set("https://flaky5.test", geolocation, .granted);
    granted.release();
    const granted_insecure = try store.set("http://flaky5.test", geolocation, .granted);
    granted_insecure.release();
    try std.testing.expectEqual(.granted, secure.getState(Target).state);
    try std.testing.expectEqual(.granted, insecure.getState(Target).state);

    const reset = try store.resetOverrides();
    defer reset.release();
    try std.testing.expect(reset.isDone());
    try std.testing.expectEqual(.prompt, secure.getState(Target).state);
    try std.testing.expectEqual(.denied, insecure.getState(Target).state);
    try std.testing.expectEqual(@as(usize, 2), secure.getState(Target).updates);
    try std.testing.expectEqual(@as(usize, 2), insecure.getState(Target).updates);
}

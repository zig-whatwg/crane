const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const permissions = @import("permissions");
const Browser = @import("browser").Browser;
const engine = @import("engine");

const permission_key = "https://pm2-key.example.test";

fn constructorAtFailures(allocator: std.mem.Allocator) !void {
    var scope = runtime.BrowserScope.init(allocator);
    defer scope.deinit();
    var realm = try runtime.ContextData.init(allocator, .{});
    defer realm.deinit();
    realm.browser_scope = &scope;

    var key: ?[]u8 = try allocator.dupe(u8, permission_key);
    defer if (key) |owned| allocator.free(owned);
    const original = key.?;
    const status = interfaces.PermissionStatus.initWith(allocator, &realm, .{
        .permission_descriptor = permissions.PermissionDescriptor.simple(.geolocation),
        .permission_state = permissions.PermissionState.prompt,
        .permission_key_owner = &key,
    }) catch |err| {
        // A failure anywhere in the generated parent/own chain leaves the
        // caller's allocation untouched. The caller's defer still owns it.
        try std.testing.expect(key != null);
        try std.testing.expectEqual(original.ptr, key.?.ptr);
        try std.testing.expectEqualStrings(permission_key, key.?);
        return err;
    };
    defer interfaces.PermissionStatus.deinit(status);
    try std.testing.expectEqual(null, key);
    try std.testing.expectEqualStrings("geolocation", (try interfaces.PermissionStatus.get_name(status)).asSlice());
    try std.testing.expectEqual(._prompt_, try interfaces.PermissionStatus.get_state(status));
}

fn constructorFailures() !void {
    if (comptime interfaces.PermissionStatus.takesConstructionArg("permission_key_owner")) {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(std.testing.allocator);
        defer runtime.deinitializeRuntime();
        try std.testing.checkAllAllocationFailures(std.testing.allocator, constructorAtFailures, .{});
    } else {
        return error.MissingPermissionKeyOwnerConstruction;
    }
}

fn unusedDelivery(_: *runtime.Instance, _: permissions.PermissionState) void {}

fn listenAtFailures(allocator: std.mem.Allocator, listener: *runtime.Instance, different_allocator: bool) !void {
    var store = permissions.BrowserStore.init(allocator);
    defer store.deinit();
    const key_allocator = if (different_allocator) std.testing.allocator else allocator;
    var key: ?[]u8 = try key_allocator.dupe(u8, permission_key);
    defer if (key) |owned| key_allocator.free(owned);
    const original_pointer = key.?.ptr;
    const state = store.listenOwned(listener, key.?, key_allocator, permissions.PermissionDescriptor.simple(.geolocation), .prompt, unusedDelivery) catch |err| {
        // listenOwned consumes on success only. Failure must not free the
        // incoming bytes; both this read and the deferred free remain valid.
        try std.testing.expectEqualStrings(permission_key, key.?);
        return err;
    };
    key = null;
    try std.testing.expectEqual(.prompt, state);
    if (different_allocator) {
        try std.testing.expect(store.entries.items[0].key.ptr != original_pointer);
    } else {
        try std.testing.expectEqual(original_pointer, store.entries.items[0].key.ptr);
    }
    store.unlisten(listener);
    // Removing an already removed subscription cannot free the key twice.
    store.unlisten(listener);
}

fn listenerFailuresFor(comptime different_allocator: bool) !void {
    if (comptime @hasDecl(permissions.BrowserStore, "listenOwned")) {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(std.testing.allocator);
        defer runtime.deinitializeRuntime();
        var realm = try runtime.ContextData.init(std.testing.allocator, .{});
        defer realm.deinit();
        const listener = try interfaces.PermissionStatus.init(std.testing.allocator, &realm);
        defer interfaces.PermissionStatus.deinit(listener);
        try std.testing.checkAllAllocationFailures(std.testing.allocator, listenAtFailures, .{ listener, different_allocator });
    } else {
        return error.MissingOwnedPermissionRegistration;
    }
}

fn listenerFailures() !void {
    try listenerFailuresFor(false);
}

fn differentAllocatorFailures() !void {
    try listenerFailuresFor(true);
}

fn realQueryAllocator() !void {
    if (comptime @hasDecl(permissions.BrowserStore, "listenOwned")) {
        const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        const page_url = "https://pm2-key.example.test/page.html";
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        try browser.current_context.?.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
        const realm = browser.getRealm().?;
        const store = try realm.browser_scope.?.of(permissions.BrowserStore);
        // The origin settings hook allocates with this realm allocator, as
        // does PermissionStatus.initWith. These actual allocator identities
        // select listenOwned's move path for the real query below.
        try std.testing.expect(realm.allocator.ptr == store.allocator.ptr);
        try std.testing.expect(realm.allocator.vtable == store.allocator.vtable);
        const result = try browser.evaluateScript("globalThis.pm2Status = null; navigator.permissions.query({name:'geolocation'}).then(status => globalThis.pm2Status = status)");
        result.release();
        var settled = false;
        for (0..500) |_| {
            const answer = try browser.evaluateScript("pm2Status !== null");
            settled = engine.toBoolean(realm, answer.borrow());
            answer.release();
            if (settled) break;
            _ = try browser.runEventLoopBlocking(10);
        }
        try std.testing.expect(settled);
        try std.testing.expectEqual(@as(usize, 1), store.entries.items.len);
        try std.testing.expectEqualStrings(permission_key, store.entries.items[0].key);
    } else {
        return error.MissingOwnedPermissionRegistration;
    }
}

fn onThread(comptime body: fn () anyerror!void) !void {
    const Thread = struct {
        fn run(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Thread.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "permission key construction transfers on success and keeps caller ownership on every allocation failure" {
    try onThread(constructorFailures);
}

test "owned permission registration consumes its key only on success under allocation failure" {
    try onThread(listenerFailures);
}

test "owned permission registration copies a different allocator's key and consumes it only on success" {
    try onThread(differentAllocatorFailures);
}

test "a real Browser permission query uses the owned-key move path" {
    try onThread(realQueryAllocator);
}

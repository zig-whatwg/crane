const std = @import("std");
const permissions = @import("permissions");
const Store = permissions.OverrideStore;
const Descriptor = permissions.PermissionDescriptor;

test "permission overrides are scoped to their store key and descriptor" {
    var first = Store.init(std.testing.allocator);
    defer first.deinit();
    var second = Store.init(std.testing.allocator);
    defer second.deinit();

    const geo = Descriptor.simple(.geolocation);
    try std.testing.expectEqual(null, first.get("https://example.test", geo));
    try std.testing.expect(try first.set("https://example.test", geo, .granted));
    try std.testing.expectEqual(.granted, first.get("https://example.test", geo).?);
    try std.testing.expectEqual(null, second.get("https://example.test", geo));
    try std.testing.expectEqual(null, first.get("https://other.test", geo));
    try std.testing.expectEqual(null, first.get("https://example.test", Descriptor.simple(.camera)));
    try std.testing.expect(!try first.set("https://example.test", geo, .granted));
    try std.testing.expect(try first.set("https://example.test", geo, .prompt));
    try std.testing.expectEqual(.prompt, first.get("https://example.test", geo).?);
}

test "permission overrides own keys and repeated replacement does not allocate" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var store = Store.init(failing.allocator());
    defer store.deinit();
    const key = try std.testing.allocator.dupe(u8, "https://original.test");
    defer std.testing.allocator.free(key);
    const geo = Descriptor.simple(.geolocation);
    _ = try store.set(key, geo, .granted);
    @memset(key, 'x');
    failing.fail_index = failing.alloc_index;
    for (0..100) |_| {
        _ = try store.set("https://original.test", geo, .denied);
        _ = try store.set("https://original.test", geo, .granted);
    }
    try std.testing.expectEqual(.granted, store.get("https://original.test", geo).?);
    try std.testing.expectEqual(null, store.get(key, geo));
    try std.testing.expect(!failing.has_induced_failure);
}

test "permission descriptor defaults and strength preserve MIDI constraints" {
    var store = Store.init(std.testing.allocator);
    defer store.deinit();
    const origin = "https://music.test";
    _ = try store.set(origin, Descriptor.midi(false), .prompt);
    try std.testing.expectEqual(.prompt, store.get(origin, Descriptor.simple(.midi)).?);
    try std.testing.expectEqual(null, store.get(origin, Descriptor.midi(true)));

    _ = try store.set(origin, Descriptor.midi(true), .granted);
    try std.testing.expectEqual(.granted, store.get(origin, Descriptor.midi(false)).?);
    _ = try store.set(origin, Descriptor.midi(false), .denied);
    try std.testing.expectEqual(.denied, store.get(origin, Descriptor.midi(true)).?);
    _ = try store.set(origin, Descriptor.midi(true), .prompt);
    try std.testing.expectEqual(.prompt, store.get(origin, Descriptor.midi(false)).?);
    _ = try store.set(origin, Descriptor.midi(true), .granted);
    _ = try store.set(origin, Descriptor.midi(false), .prompt);
    try std.testing.expectEqual(.prompt, store.get(origin, Descriptor.midi(true)).?);
}

test "camera and push descriptor strength have opposite boolean directions" {
    var store = Store.init(std.testing.allocator);
    defer store.deinit();
    const origin = "https://media.test";
    _ = try store.set(origin, Descriptor.camera(true), .granted);
    try std.testing.expectEqual(.granted, store.get(origin, Descriptor.camera(false)).?);
    _ = try store.set(origin, Descriptor.push(false), .granted);
    try std.testing.expectEqual(.granted, store.get(origin, Descriptor.push(true)).?);
    _ = try store.set(origin, Descriptor.push(true), .denied);
    try std.testing.expectEqual(.denied, store.get(origin, Descriptor.push(false)).?);
}

fn allocationScenario(allocator: std.mem.Allocator) !void {
    var store = Store.init(allocator);
    defer store.deinit();
    const geo = Descriptor.simple(.geolocation);
    _ = try store.set("https://existing.test", geo, .granted);
    _ = store.set("https://new.test", Descriptor.midi(true), .denied) catch |err| {
        try std.testing.expectEqual(.granted, store.get("https://existing.test", geo).?);
        try std.testing.expectEqual(null, store.get("https://new.test", Descriptor.midi(true)));
        return err;
    };
    try std.testing.expectEqual(.denied, store.get("https://new.test", Descriptor.midi(true)).?);
}

test "permission override allocation failure leaves prior entries intact" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationScenario, .{});
}

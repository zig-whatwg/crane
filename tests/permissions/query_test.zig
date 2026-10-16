const std = @import("std");
const permissions = @import("permissions");

test "permission query support is an allowlist with unsupported default" {
    const names = [_][]const u8{ "geolocation", "notifications", "push", "persistent-storage", "midi", "storage-access", "screen-wake-lock", "camera", "microphone" };
    for (names) |name| {
        const supported = permissions.query.supportedName(name) orelse return error.TestExpectedSupportedName;
        try std.testing.expectEqualStrings(name, supported.toString());
    }
    for ([_][]const u8{ "", "not-a-permission", "accelerometer", "clipboard-read", "device-info", "bluetooth", "xr-spatial-tracking", "local-network", "loopback-network", "Geolocation", "geolocation\x00" }) |name| {
        try std.testing.expectEqual(null, permissions.query.supportedName(name));
    }
}

test "permission default denies insecure contexts and prompts secure contexts" {
    try std.testing.expectEqual(permissions.PermissionState.denied, permissions.query.defaultState(false));
    try std.testing.expectEqual(permissions.PermissionState.prompt, permissions.query.defaultState(true));
}

test "storage access query hides a denied permission state" {
    try std.testing.expectEqual(permissions.PermissionState.prompt, permissions.query.resultState(.storage_access, .denied));
    try std.testing.expectEqual(permissions.PermissionState.granted, permissions.query.resultState(.storage_access, .granted));
    try std.testing.expectEqual(permissions.PermissionState.denied, permissions.query.resultState(.geolocation, .denied));
}

//! Permissions API Core Types
//!
//! W3C Permissions API
//! Spec: https://www.w3.org/TR/permissions/
//!
//! This module defines the core types for the Permissions API.

const std = @import("std");

// ============================================================================
// Permission Names
// ============================================================================

/// Standard permission names
/// Spec: W3C Permissions § 3
pub const PermissionName = enum {
    // Geolocation API
    geolocation,

    // Notifications API
    notifications,

    // Push API
    push,

    // MIDI API
    midi,

    // Media Capture and Streams
    camera,
    microphone,
    speaker_selection,

    // Media Devices
    device_info,

    // Background Fetch API
    background_fetch,

    // Background Sync API
    background_sync,
    periodic_background_sync,

    // Bluetooth API
    bluetooth,

    // Storage API
    persistent_storage,
    storage_access,
    top_level_storage_access,

    // Sensors
    accelerometer,
    gyroscope,
    magnetometer,
    ambient_light_sensor,

    // Clipboard API
    clipboard_read,
    clipboard_write,

    // Screen Capture API
    display_capture,

    // NFC API
    nfc,

    // Idle Detection API
    idle_detection,

    // Screen Wake Lock API
    screen_wake_lock,

    // Window Management API
    window_management,

    // Local Font Access API
    local_fonts,

    /// Convert from string to PermissionName
    pub fn fromString(name: []const u8) ?PermissionName {
        const map = std.StaticStringMap(PermissionName).initComptime(.{
            .{ "geolocation", .geolocation },
            .{ "notifications", .notifications },
            .{ "push", .push },
            .{ "midi", .midi },
            .{ "camera", .camera },
            .{ "microphone", .microphone },
            .{ "speaker-selection", .speaker_selection },
            .{ "device-info", .device_info },
            .{ "background-fetch", .background_fetch },
            .{ "background-sync", .background_sync },
            .{ "periodic-background-sync", .periodic_background_sync },
            .{ "bluetooth", .bluetooth },
            .{ "persistent-storage", .persistent_storage },
            .{ "storage-access", .storage_access },
            .{ "top-level-storage-access", .top_level_storage_access },
            .{ "accelerometer", .accelerometer },
            .{ "gyroscope", .gyroscope },
            .{ "magnetometer", .magnetometer },
            .{ "ambient-light-sensor", .ambient_light_sensor },
            .{ "clipboard-read", .clipboard_read },
            .{ "clipboard-write", .clipboard_write },
            .{ "display-capture", .display_capture },
            .{ "nfc", .nfc },
            .{ "idle-detection", .idle_detection },
            .{ "screen-wake-lock", .screen_wake_lock },
            .{ "window-management", .window_management },
            .{ "local-fonts", .local_fonts },
        });
        return map.get(name);
    }

    /// Convert to string
    pub fn toString(self: PermissionName) []const u8 {
        return switch (self) {
            .geolocation => "geolocation",
            .notifications => "notifications",
            .push => "push",
            .midi => "midi",
            .camera => "camera",
            .microphone => "microphone",
            .speaker_selection => "speaker-selection",
            .device_info => "device-info",
            .background_fetch => "background-fetch",
            .background_sync => "background-sync",
            .periodic_background_sync => "periodic-background-sync",
            .bluetooth => "bluetooth",
            .persistent_storage => "persistent-storage",
            .storage_access => "storage-access",
            .top_level_storage_access => "top-level-storage-access",
            .accelerometer => "accelerometer",
            .gyroscope => "gyroscope",
            .magnetometer => "magnetometer",
            .ambient_light_sensor => "ambient-light-sensor",
            .clipboard_read => "clipboard-read",
            .clipboard_write => "clipboard-write",
            .display_capture => "display-capture",
            .nfc => "nfc",
            .idle_detection => "idle-detection",
            .screen_wake_lock => "screen-wake-lock",
            .window_management => "window-management",
            .local_fonts => "local-fonts",
        };
    }
};

// ============================================================================
// Permission State
// ============================================================================

/// Permission state values
/// Spec: W3C Permissions § 4.1
pub const PermissionState = enum {
    /// User has granted permission
    granted,
    /// User has denied permission
    denied,
    /// User has not yet made a decision (default)
    prompt,

    /// Convert from string
    pub fn fromString(state: []const u8) ?PermissionState {
        if (std.mem.eql(u8, state, "granted")) return .granted;
        if (std.mem.eql(u8, state, "denied")) return .denied;
        if (std.mem.eql(u8, state, "prompt")) return .prompt;
        return null;
    }

    /// Convert to string
    pub fn toString(self: PermissionState) []const u8 {
        return switch (self) {
            .granted => "granted",
            .denied => "denied",
            .prompt => "prompt",
        };
    }
};

// ============================================================================
// Permission Descriptor
// ============================================================================

/// Extra data for specific permission types
/// Spec: W3C Permissions § 5
pub const PermissionExtra = union(enum) {
    /// No extra data
    none: void,

    /// Push permission: userVisibleOnly
    push: struct {
        user_visible_only: bool = false,
    },

    /// MIDI permission: sysex
    midi: struct {
        sysex: bool = false,
    },

    /// Camera permission: panTiltZoom
    camera: struct {
        pan_tilt_zoom: bool = false,
    },

    /// Clipboard read: allowWithoutGesture
    clipboard_read: struct {
        allow_without_gesture: bool = false,
    },

    /// Clipboard write: allowWithoutGesture
    clipboard_write: struct {
        allow_without_gesture: bool = false,
    },
};

/// Permission descriptor
/// Spec: W3C Permissions § 5
pub const PermissionDescriptor = struct {
    /// Permission name
    name: PermissionName,

    /// Extra permission-specific options
    extra: PermissionExtra = .{ .none = {} },

    /// Create a simple descriptor with just a name
    pub fn simple(name: PermissionName) PermissionDescriptor {
        return .{ .name = name };
    }

    /// Create a push descriptor with userVisibleOnly
    pub fn push(user_visible_only: bool) PermissionDescriptor {
        return .{
            .name = .push,
            .extra = .{ .push = .{ .user_visible_only = user_visible_only } },
        };
    }

    /// Create a MIDI descriptor with sysex
    pub fn midi(sysex: bool) PermissionDescriptor {
        return .{
            .name = .midi,
            .extra = .{ .midi = .{ .sysex = sysex } },
        };
    }

    /// Create a camera descriptor with panTiltZoom
    pub fn camera(pan_tilt_zoom: bool) PermissionDescriptor {
        return .{
            .name = .camera,
            .extra = .{ .camera = .{ .pan_tilt_zoom = pan_tilt_zoom } },
        };
    }
};

// ============================================================================
// Origin
// ============================================================================

/// Origin for permission isolation
/// Spec: HTML § 7.5
pub const Origin = struct {
    scheme: []const u8,
    host: []const u8,
    port: ?u16,

    allocator: ?std.mem.Allocator = null,

    /// Create with borrowed strings
    pub fn createBorrowed(scheme: []const u8, host: []const u8, port: ?u16) Origin {
        return .{
            .scheme = scheme,
            .host = host,
            .port = port,
        };
    }

    /// Create with copied strings
    pub fn create(allocator: std.mem.Allocator, scheme: []const u8, host: []const u8, port: ?u16) !Origin {
        return .{
            .scheme = try allocator.dupe(u8, scheme),
            .host = try allocator.dupe(u8, host),
            .port = port,
            .allocator = allocator,
        };
    }

    /// Check if two origins are equal
    pub fn eql(self: Origin, other: Origin) bool {
        if (!std.ascii.eqlIgnoreCase(self.scheme, other.scheme)) return false;
        if (!std.ascii.eqlIgnoreCase(self.host, other.host)) return false;

        // Compare ports (null means default port)
        const self_port = self.port orelse getDefaultPort(self.scheme);
        const other_port = other.port orelse getDefaultPort(other.scheme);
        return self_port == other_port;
    }

    /// Serialize to string (scheme://host:port)
    pub fn serialize(self: Origin, allocator: std.mem.Allocator) ![]u8 {
        if (self.port) |p| {
            return std.fmt.allocPrint(allocator, "{s}://{s}:{d}", .{ self.scheme, self.host, p });
        } else {
            return std.fmt.allocPrint(allocator, "{s}://{s}", .{ self.scheme, self.host });
        }
    }

    pub fn deinit(self: *Origin) void {
        if (self.allocator) |alloc| {
            alloc.free(self.scheme);
            alloc.free(self.host);
        }
    }

    fn getDefaultPort(scheme: []const u8) ?u16 {
        if (std.ascii.eqlIgnoreCase(scheme, "http")) return 80;
        if (std.ascii.eqlIgnoreCase(scheme, "https")) return 443;
        if (std.ascii.eqlIgnoreCase(scheme, "ws")) return 80;
        if (std.ascii.eqlIgnoreCase(scheme, "wss")) return 443;
        return null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "PermissionName.fromString" {
    try std.testing.expectEqual(PermissionName.geolocation, PermissionName.fromString("geolocation").?);
    try std.testing.expectEqual(PermissionName.camera, PermissionName.fromString("camera").?);
    try std.testing.expect(PermissionName.fromString("invalid") == null);
}

test "PermissionName.toString" {
    try std.testing.expectEqualStrings("geolocation", PermissionName.geolocation.toString());
    try std.testing.expectEqualStrings("clipboard-read", PermissionName.clipboard_read.toString());
}

test "PermissionState" {
    try std.testing.expectEqual(PermissionState.granted, PermissionState.fromString("granted").?);
    try std.testing.expectEqualStrings("denied", PermissionState.denied.toString());
}

test "PermissionDescriptor.simple" {
    const desc = PermissionDescriptor.simple(.geolocation);
    try std.testing.expectEqual(PermissionName.geolocation, desc.name);
}

test "PermissionDescriptor.push" {
    const desc = PermissionDescriptor.push(true);
    try std.testing.expectEqual(PermissionName.push, desc.name);
    try std.testing.expect(desc.extra.push.user_visible_only);
}

test "Origin.eql" {
    const o1 = Origin.createBorrowed("https", "example.com", 443);
    const o2 = Origin.createBorrowed("https", "example.com", null);
    const o3 = Origin.createBorrowed("http", "example.com", 80);

    try std.testing.expect(o1.eql(o2)); // 443 = default for https
    try std.testing.expect(!o1.eql(o3)); // different scheme
}

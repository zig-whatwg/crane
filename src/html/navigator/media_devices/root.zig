//! MediaDevices API
//!
//! Spec: Media Capture and Streams
//! https://w3c.github.io/mediacapture-main/
//!
//! This module implements the MediaDevices interface which provides
//! access to media input devices through a pluggable backend.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Media device kinds
pub const MediaDeviceKind = enum {
    audioinput,
    audiooutput,
    videoinput,
};

/// Media device info
pub const MediaDeviceInfo = struct {
    device_id: []const u8,
    kind: MediaDeviceKind,
    label: []const u8,
    group_id: []const u8,
};

/// Media stream constraints
pub const MediaStreamConstraints = struct {
    video: bool = false,
    audio: bool = false,
};

/// Media track supported constraints
pub const MediaTrackSupportedConstraints = struct {
    width: bool = true,
    height: bool = true,
    aspect_ratio: bool = true,
    frame_rate: bool = true,
    facing_mode: bool = true,
    resize_mode: bool = true,
    sample_rate: bool = true,
    sample_size: bool = true,
    echo_cancellation: bool = true,
    auto_gain_control: bool = true,
    noise_suppression: bool = true,
    latency: bool = true,
    channel_count: bool = true,
    device_id: bool = true,
    group_id: bool = true,
    background_blur: bool = true,
};

/// Error types for MediaDevices operations
pub const MediaDevicesError = error{
    /// User denied permission
    NotAllowedError,
    /// Device not found
    NotFoundError,
    /// Device in use
    NotReadableError,
    /// Constraints cannot be satisfied
    OverconstrainedError,
    /// General abort
    AbortError,
    /// Out of memory
    OutOfMemory,
};

/// Backend interface for media devices
pub const MediaDevicesBackend = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        enumerateDevices: *const fn (context: *anyopaque, allocator: Allocator) MediaDevicesError![]MediaDeviceInfo,
        getUserMedia: *const fn (context: *anyopaque, constraints: MediaStreamConstraints) MediaDevicesError!void,
        getSupportedConstraints: *const fn (context: *anyopaque) MediaTrackSupportedConstraints,
    };

    pub fn enumerateDevices(self: *const MediaDevicesBackend, allocator: Allocator) MediaDevicesError![]MediaDeviceInfo {
        return self.vtable.enumerateDevices(self.context, allocator);
    }

    pub fn getUserMedia(self: *const MediaDevicesBackend, constraints: MediaStreamConstraints) MediaDevicesError!void {
        return self.vtable.getUserMedia(self.context, constraints);
    }

    pub fn getSupportedConstraints(self: *const MediaDevicesBackend) MediaTrackSupportedConstraints {
        return self.vtable.getSupportedConstraints(self.context);
    }
};

/// MediaDevices interface implementation
/// Spec: MediaDevices interface
pub const MediaDevices = struct {
    allocator: Allocator,
    backend: ?*MediaDevicesBackend,

    const Self = @This();

    pub fn init(allocator: Allocator, backend: ?*MediaDevicesBackend) Self {
        return .{
            .allocator = allocator,
            .backend = backend,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Enumerate available media devices
    /// Spec: enumerateDevices()
    pub fn enumerateDevices(self: *Self) MediaDevicesError![]MediaDeviceInfo {
        if (self.backend) |backend| {
            return backend.enumerateDevices(self.allocator);
        }
        // No backend - return empty list
        return &[_]MediaDeviceInfo{};
    }

    /// Request access to media devices
    /// Spec: getUserMedia(constraints)
    pub fn getUserMedia(self: *Self, constraints: MediaStreamConstraints) MediaDevicesError!void {
        if (self.backend) |backend| {
            return backend.getUserMedia(constraints);
        }
        // No backend - permission denied
        return MediaDevicesError.NotAllowedError;
    }

    /// Get supported constraints
    /// Spec: getSupportedConstraints()
    pub fn getSupportedConstraints(self: *Self) MediaTrackSupportedConstraints {
        if (self.backend) |backend| {
            return backend.getSupportedConstraints();
        }
        return .{};
    }
};

// ============================================================================
// Tests
// ============================================================================

test "MediaDevices - init without backend" {
    const allocator = std.testing.allocator;

    var media = MediaDevices.init(allocator, null);
    defer media.deinit();

    // Should return empty device list
    const devices = try media.enumerateDevices();
    try std.testing.expectEqual(@as(usize, 0), devices.len);

    // Should return permission denied for getUserMedia
    const result = media.getUserMedia(.{ .video = true });
    try std.testing.expectError(MediaDevicesError.NotAllowedError, result);
}

test "MediaDevices - getSupportedConstraints" {
    const allocator = std.testing.allocator;

    var media = MediaDevices.init(allocator, null);
    defer media.deinit();

    const constraints = media.getSupportedConstraints();
    try std.testing.expect(constraints.width);
    try std.testing.expect(constraints.height);
}

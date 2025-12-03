//! Geolocation API
//!
//! Spec: Geolocation API
//! https://w3c.github.io/geolocation/
//!
//! This module implements the Geolocation interface which provides
//! access to location data through a pluggable backend.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Position options
pub const PositionOptions = struct {
    /// Enable high accuracy mode
    enable_high_accuracy: bool = false,

    /// Maximum age of cached position (milliseconds)
    maximum_age: u32 = 0,

    /// Timeout for position request (milliseconds)
    timeout: u32 = 0xFFFFFFFF,
};

/// Geolocation coordinates
pub const GeolocationCoordinates = struct {
    /// Latitude in decimal degrees
    latitude: f64,

    /// Longitude in decimal degrees
    longitude: f64,

    /// Accuracy in meters
    accuracy: f64,

    /// Altitude in meters (optional)
    altitude: ?f64 = null,

    /// Altitude accuracy in meters (optional)
    altitude_accuracy: ?f64 = null,

    /// Heading in degrees (optional)
    heading: ?f64 = null,

    /// Speed in meters per second (optional)
    speed: ?f64 = null,
};

/// Geolocation position
pub const GeolocationPosition = struct {
    /// Position coordinates
    coords: GeolocationCoordinates,

    /// Timestamp when position was acquired
    timestamp: i64,
};

/// Geolocation position error codes
pub const PositionErrorCode = enum(u16) {
    /// User denied the request for Geolocation
    permission_denied = 1,
    /// Location information is unavailable
    position_unavailable = 2,
    /// The request timed out
    timeout = 3,
};

/// Geolocation position error
pub const GeolocationPositionError = struct {
    code: PositionErrorCode,
    message: []const u8,
};

/// Callback types
pub const PositionCallback = *const fn (position: GeolocationPosition) void;
pub const PositionErrorCallback = *const fn (err: GeolocationPositionError) void;

/// Watch ID for position watching
pub const WatchId = i32;

/// Backend interface for geolocation
/// Embedders implement this to provide real location data
pub const GeolocationBackend = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        getCurrentPosition: *const fn (
            context: *anyopaque,
            success_callback: PositionCallback,
            error_callback: ?PositionErrorCallback,
            options: PositionOptions,
        ) void,

        watchPosition: *const fn (
            context: *anyopaque,
            success_callback: PositionCallback,
            error_callback: ?PositionErrorCallback,
            options: PositionOptions,
        ) WatchId,

        clearWatch: *const fn (context: *anyopaque, watch_id: WatchId) void,
    };

    pub fn getCurrentPosition(
        self: *const GeolocationBackend,
        success_callback: PositionCallback,
        error_callback: ?PositionErrorCallback,
        options: PositionOptions,
    ) void {
        self.vtable.getCurrentPosition(self.context, success_callback, error_callback, options);
    }

    pub fn watchPosition(
        self: *const GeolocationBackend,
        success_callback: PositionCallback,
        error_callback: ?PositionErrorCallback,
        options: PositionOptions,
    ) WatchId {
        return self.vtable.watchPosition(self.context, success_callback, error_callback, options);
    }

    pub fn clearWatch(self: *const GeolocationBackend, watch_id: WatchId) void {
        self.vtable.clearWatch(self.context, watch_id);
    }
};

/// Geolocation interface implementation
/// Spec: Geolocation API
pub const Geolocation = struct {
    allocator: Allocator,
    backend: ?*GeolocationBackend,

    const Self = @This();

    pub fn init(allocator: Allocator, backend: ?*GeolocationBackend) Self {
        return .{
            .allocator = allocator,
            .backend = backend,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
        // No cleanup needed for stub
    }

    /// Get the current position
    /// Spec: getCurrentPosition(successCallback, errorCallback, options)
    pub fn getCurrentPosition(
        self: *Self,
        success_callback: PositionCallback,
        error_callback: ?PositionErrorCallback,
        options: PositionOptions,
    ) void {
        if (self.backend) |backend| {
            backend.getCurrentPosition(success_callback, error_callback, options);
        } else {
            // No backend - return permission denied
            if (error_callback) |cb| {
                cb(.{
                    .code = .permission_denied,
                    .message = "Geolocation is not supported",
                });
            }
        }
    }

    /// Watch the position
    /// Spec: watchPosition(successCallback, errorCallback, options)
    pub fn watchPosition(
        self: *Self,
        success_callback: PositionCallback,
        error_callback: ?PositionErrorCallback,
        options: PositionOptions,
    ) WatchId {
        if (self.backend) |backend| {
            return backend.watchPosition(success_callback, error_callback, options);
        } else {
            // No backend - return error and invalid watch ID
            if (error_callback) |cb| {
                cb(.{
                    .code = .permission_denied,
                    .message = "Geolocation is not supported",
                });
            }
            return -1;
        }
    }

    /// Clear a position watch
    /// Spec: clearWatch(watchId)
    pub fn clearWatch(self: *Self, watch_id: WatchId) void {
        if (self.backend) |backend| {
            backend.clearWatch(watch_id);
        }
    }
};

// ============================================================================
// Stub Backend
// ============================================================================

/// Stub backend that always returns permission denied
pub const StubGeolocationBackend = struct {
    backend: GeolocationBackend,

    const Self_ = @This();

    pub fn init() Self_ {
        return .{
            .backend = .{
                .context = undefined,
                .vtable = &vtable,
            },
        };
    }

    pub fn getBackend(self: *Self_) *GeolocationBackend {
        self.backend.context = self;
        return &self.backend;
    }

    fn getCurrentPosition(
        _: *anyopaque,
        _: PositionCallback,
        error_callback: ?PositionErrorCallback,
        _: PositionOptions,
    ) void {
        if (error_callback) |cb| {
            cb(.{
                .code = .permission_denied,
                .message = "Geolocation permission denied",
            });
        }
    }

    fn watchPosition(
        _: *anyopaque,
        _: PositionCallback,
        error_callback: ?PositionErrorCallback,
        _: PositionOptions,
    ) WatchId {
        if (error_callback) |cb| {
            cb(.{
                .code = .permission_denied,
                .message = "Geolocation permission denied",
            });
        }
        return -1;
    }

    fn clearWatch(_: *anyopaque, _: WatchId) void {}

    const vtable = GeolocationBackend.VTable{
        .getCurrentPosition = getCurrentPosition,
        .watchPosition = watchPosition,
        .clearWatch = clearWatch,
    };
};

// ============================================================================
// Tests
// ============================================================================

test "Geolocation - init without backend" {
    const allocator = std.testing.allocator;

    var geo = Geolocation.init(allocator, null);
    defer geo.deinit();

    // Should return invalid watch ID when no backend
    const watch_id = geo.watchPosition(
        struct {
            fn cb(_: GeolocationPosition) void {}
        }.cb,
        null,
        .{},
    );
    try std.testing.expectEqual(@as(WatchId, -1), watch_id);
}

test "Geolocation - with stub backend" {
    const allocator = std.testing.allocator;

    var stub = StubGeolocationBackend.init();
    var geo = Geolocation.init(allocator, stub.getBackend());
    defer geo.deinit();

    geo.getCurrentPosition(
        struct {
            fn success(_: GeolocationPosition) void {}
        }.success,
        struct {
            fn onError(_: GeolocationPositionError) void {}
        }.onError,
        .{},
    );
}

//! Web Bluetooth API
//!
//! Spec: Web Bluetooth
//! https://webbluetoothcg.github.io/web-bluetooth/
//!
//! This module implements the Bluetooth interface which provides
//! access to Bluetooth devices through a pluggable backend.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Bluetooth device
pub const BluetoothDevice = struct {
    id: []const u8,
    name: ?[]const u8,
};

/// Request device options
pub const RequestDeviceOptions = struct {
    accept_all_devices: bool = false,
};

/// Error types for Bluetooth operations
pub const BluetoothError = error{
    /// User denied permission
    NotAllowedError,
    /// Device not found
    NotFoundError,
    /// Network error
    NetworkError,
    /// Operation aborted
    AbortError,
    /// Bluetooth not available
    NotSupportedError,
    /// Out of memory
    OutOfMemory,
};

/// Backend interface for Bluetooth
pub const BluetoothBackend = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        getAvailability: *const fn (context: *anyopaque) bool,
        getDevices: *const fn (context: *anyopaque, allocator: Allocator) BluetoothError![]BluetoothDevice,
        requestDevice: *const fn (context: *anyopaque, options: RequestDeviceOptions) BluetoothError!BluetoothDevice,
    };

    pub fn getAvailability(self: *const BluetoothBackend) bool {
        return self.vtable.getAvailability(self.context);
    }

    pub fn getDevices(self: *const BluetoothBackend, allocator: Allocator) BluetoothError![]BluetoothDevice {
        return self.vtable.getDevices(self.context, allocator);
    }

    pub fn requestDevice(self: *const BluetoothBackend, options: RequestDeviceOptions) BluetoothError!BluetoothDevice {
        return self.vtable.requestDevice(self.context, options);
    }
};

/// Bluetooth interface implementation
/// Spec: Bluetooth interface
/// [SecureContext] required
pub const Bluetooth = struct {
    allocator: Allocator,
    backend: ?*BluetoothBackend,

    const Self = @This();

    pub fn init(allocator: Allocator, backend: ?*BluetoothBackend) Self {
        return .{
            .allocator = allocator,
            .backend = backend,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Check if Bluetooth is available
    /// Spec: getAvailability()
    pub fn getAvailability(self: *Self) bool {
        if (self.backend) |backend| {
            return backend.getAvailability();
        }
        return false;
    }

    /// Get previously paired devices
    /// Spec: getDevices()
    pub fn getDevices(self: *Self) BluetoothError![]BluetoothDevice {
        if (self.backend) |backend| {
            return backend.getDevices(self.allocator);
        }
        return &[_]BluetoothDevice{};
    }

    /// Request a device
    /// Spec: requestDevice(options)
    pub fn requestDevice(self: *Self, options: RequestDeviceOptions) BluetoothError!BluetoothDevice {
        if (self.backend) |backend| {
            return backend.requestDevice(options);
        }
        return BluetoothError.NotSupportedError;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Bluetooth - init without backend" {
    const allocator = std.testing.allocator;

    var bluetooth = Bluetooth.init(allocator, null);
    defer bluetooth.deinit();

    // Should return not available
    try std.testing.expect(!bluetooth.getAvailability());

    // Should return empty device list
    const devices = try bluetooth.getDevices();
    try std.testing.expectEqual(@as(usize, 0), devices.len);

    // Should return not supported
    const result = bluetooth.requestDevice(.{});
    try std.testing.expectError(BluetoothError.NotSupportedError, result);
}

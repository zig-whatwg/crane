//! WebUSB API
//!
//! Spec: WebUSB API
//! https://wicg.github.io/webusb/
//!
//! This module implements the USB interface which provides
//! access to USB devices through a pluggable backend.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// USB device filter
pub const USBDeviceFilter = struct {
    vendor_id: ?u16 = null,
    product_id: ?u16 = null,
    class_code: ?u8 = null,
    subclass_code: ?u8 = null,
    protocol_code: ?u8 = null,
    serial_number: ?[]const u8 = null,
};

/// USB device request options
pub const USBDeviceRequestOptions = struct {
    filters: []const USBDeviceFilter = &[_]USBDeviceFilter{},
    exclusion_filters: []const USBDeviceFilter = &[_]USBDeviceFilter{},
};

/// USB device
pub const USBDevice = struct {
    usb_version_major: u8,
    usb_version_minor: u8,
    usb_version_subminor: u8,
    device_class: u8,
    device_subclass: u8,
    device_protocol: u8,
    vendor_id: u16,
    product_id: u16,
    device_version_major: u8,
    device_version_minor: u8,
    device_version_subminor: u8,
    manufacturer_name: ?[]const u8,
    product_name: ?[]const u8,
    serial_number: ?[]const u8,
    opened: bool,
};

/// Error types for USB operations
pub const USBError = error{
    /// User denied permission
    NotAllowedError,
    /// Device not found
    NotFoundError,
    /// Device busy or not readable
    NotReadableError,
    /// Security error
    SecurityError,
    /// Network error
    NetworkError,
    /// Out of memory
    OutOfMemory,
};

/// Backend interface for USB
pub const USBBackend = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        getDevices: *const fn (context: *anyopaque, allocator: Allocator) USBError![]USBDevice,
        requestDevice: *const fn (context: *anyopaque, options: USBDeviceRequestOptions) USBError!USBDevice,
    };

    pub fn getDevices(self: *const USBBackend, allocator: Allocator) USBError![]USBDevice {
        return self.vtable.getDevices(self.context, allocator);
    }

    pub fn requestDevice(self: *const USBBackend, options: USBDeviceRequestOptions) USBError!USBDevice {
        return self.vtable.requestDevice(self.context, options);
    }
};

/// USB interface implementation
/// Spec: USB interface
/// [SecureContext] required
pub const USB = struct {
    allocator: Allocator,
    backend: ?*USBBackend,

    const Self = @This();

    pub fn init(allocator: Allocator, backend: ?*USBBackend) Self {
        return .{
            .allocator = allocator,
            .backend = backend,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Get previously authorized devices
    /// Spec: getDevices()
    pub fn getDevices(self: *Self) USBError![]USBDevice {
        if (self.backend) |backend| {
            return backend.getDevices(self.allocator);
        }
        return &[_]USBDevice{};
    }

    /// Request a device
    /// Spec: requestDevice(options)
    pub fn requestDevice(self: *Self, options: USBDeviceRequestOptions) USBError!USBDevice {
        if (self.backend) |backend| {
            return backend.requestDevice(options);
        }
        return USBError.NotAllowedError;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "USB - init without backend" {
    const allocator = std.testing.allocator;

    var usb = USB.init(allocator, null);
    defer usb.deinit();

    // Should return empty device list
    const devices = try usb.getDevices();
    try std.testing.expectEqual(@as(usize, 0), devices.len);

    // Should return permission denied
    const result = usb.requestDevice(.{});
    try std.testing.expectError(USBError.NotAllowedError, result);
}

//! WebHID API
//!
//! Spec: WebHID API
//! https://wicg.github.io/webhid/
//!
//! This module implements the HID interface which provides
//! access to Human Interface Devices through a pluggable backend.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// HID device filter
pub const HIDDeviceFilter = struct {
    vendor_id: ?u32 = null,
    product_id: ?u16 = null,
    usage_page: ?u16 = null,
    usage: ?u16 = null,
};

/// HID device request options
pub const HIDDeviceRequestOptions = struct {
    filters: []const HIDDeviceFilter,
    exclusion_filters: []const HIDDeviceFilter = &[_]HIDDeviceFilter{},
};

/// HID report info
pub const HIDReportInfo = struct {
    report_id: u8,
};

/// HID collection info
pub const HIDCollectionInfo = struct {
    usage_page: u16,
    usage: u16,
    type_code: u8,
    children: []const HIDCollectionInfo = &[_]HIDCollectionInfo{},
    input_reports: []const HIDReportInfo = &[_]HIDReportInfo{},
    output_reports: []const HIDReportInfo = &[_]HIDReportInfo{},
    feature_reports: []const HIDReportInfo = &[_]HIDReportInfo{},
};

/// HID device
pub const HIDDevice = struct {
    opened: bool,
    vendor_id: u16,
    product_id: u16,
    product_name: []const u8,
    collections: []const HIDCollectionInfo,
};

/// Error types for HID operations
pub const HIDError = error{
    /// User denied permission
    NotAllowedError,
    /// Device not found
    NotFoundError,
    /// Device busy
    InvalidStateError,
    /// Network error
    NetworkError,
    /// Out of memory
    OutOfMemory,
};

/// Backend interface for HID
pub const HIDBackend = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        getDevices: *const fn (context: *anyopaque, allocator: Allocator) HIDError![]HIDDevice,
        requestDevice: *const fn (context: *anyopaque, options: HIDDeviceRequestOptions) HIDError![]HIDDevice,
    };

    pub fn getDevices(self: *const HIDBackend, allocator: Allocator) HIDError![]HIDDevice {
        return self.vtable.getDevices(self.context, allocator);
    }

    pub fn requestDevice(self: *const HIDBackend, options: HIDDeviceRequestOptions) HIDError![]HIDDevice {
        return self.vtable.requestDevice(self.context, options);
    }
};

/// HID interface implementation
/// Spec: HID interface
/// [SecureContext] required
pub const HID = struct {
    allocator: Allocator,
    backend: ?*HIDBackend,

    const Self = @This();

    pub fn init(allocator: Allocator, backend: ?*HIDBackend) Self {
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
    pub fn getDevices(self: *Self) HIDError![]HIDDevice {
        if (self.backend) |backend| {
            return backend.getDevices(self.allocator);
        }
        return &[_]HIDDevice{};
    }

    /// Request devices
    /// Spec: requestDevice(options)
    pub fn requestDevice(self: *Self, options: HIDDeviceRequestOptions) HIDError![]HIDDevice {
        if (self.backend) |backend| {
            return backend.requestDevice(options);
        }
        return HIDError.NotAllowedError;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "HID - init without backend" {
    const allocator = std.testing.allocator;

    var hid = HID.init(allocator, null);
    defer hid.deinit();

    // Should return empty device list
    const devices = try hid.getDevices();
    try std.testing.expectEqual(@as(usize, 0), devices.len);

    // Should return permission denied
    const result = hid.requestDevice(.{ .filters = &[_]HIDDeviceFilter{} });
    try std.testing.expectError(HIDError.NotAllowedError, result);
}

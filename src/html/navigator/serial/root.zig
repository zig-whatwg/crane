//! Web Serial API
//!
//! Spec: Web Serial API
//! https://wicg.github.io/serial/
//!
//! This module implements the Serial interface which provides
//! access to serial ports through a pluggable backend.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Serial port filter
pub const SerialPortFilter = struct {
    usb_vendor_id: ?u16 = null,
    usb_product_id: ?u16 = null,
};

/// Serial port request options
pub const SerialPortRequestOptions = struct {
    filters: []const SerialPortFilter = &[_]SerialPortFilter{},
};

/// Parity type
pub const ParityType = enum {
    none,
    even,
    odd,
};

/// Flow control type
pub const FlowControlType = enum {
    none,
    hardware,
};

/// Serial options
pub const SerialOptions = struct {
    baud_rate: u32,
    data_bits: u8 = 8,
    stop_bits: u8 = 1,
    parity: ParityType = .none,
    buffer_size: u32 = 255,
    flow_control: FlowControlType = .none,
};

/// Serial port info
pub const SerialPortInfo = struct {
    usb_vendor_id: ?u16,
    usb_product_id: ?u16,
};

/// Serial port
pub const SerialPort = struct {
    connected: bool,

    pub fn getInfo(_: *const SerialPort) SerialPortInfo {
        return .{
            .usb_vendor_id = null,
            .usb_product_id = null,
        };
    }
};

/// Error types for Serial operations
pub const SerialError = error{
    /// User denied permission
    NotAllowedError,
    /// Port not found
    NotFoundError,
    /// Port already open
    InvalidStateError,
    /// Network error
    NetworkError,
    /// Out of memory
    OutOfMemory,
};

/// Backend interface for Serial
pub const SerialBackend = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        getPorts: *const fn (context: *anyopaque, allocator: Allocator) SerialError![]SerialPort,
        requestPort: *const fn (context: *anyopaque, options: SerialPortRequestOptions) SerialError!SerialPort,
    };

    pub fn getPorts(self: *const SerialBackend, allocator: Allocator) SerialError![]SerialPort {
        return self.vtable.getPorts(self.context, allocator);
    }

    pub fn requestPort(self: *const SerialBackend, options: SerialPortRequestOptions) SerialError!SerialPort {
        return self.vtable.requestPort(self.context, options);
    }
};

/// Serial interface implementation
/// Spec: Serial interface
/// [SecureContext] required
pub const Serial = struct {
    allocator: Allocator,
    backend: ?*SerialBackend,

    const Self = @This();

    pub fn init(allocator: Allocator, backend: ?*SerialBackend) Self {
        return .{
            .allocator = allocator,
            .backend = backend,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Get previously authorized ports
    /// Spec: getPorts()
    pub fn getPorts(self: *Self) SerialError![]SerialPort {
        if (self.backend) |backend| {
            return backend.getPorts(self.allocator);
        }
        return &[_]SerialPort{};
    }

    /// Request a port
    /// Spec: requestPort(options)
    pub fn requestPort(self: *Self, options: SerialPortRequestOptions) SerialError!SerialPort {
        if (self.backend) |backend| {
            return backend.requestPort(options);
        }
        return SerialError.NotAllowedError;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Serial - init without backend" {
    const allocator = std.testing.allocator;

    var serial = Serial.init(allocator, null);
    defer serial.deinit();

    // Should return empty port list
    const ports = try serial.getPorts();
    try std.testing.expectEqual(@as(usize, 0), ports.len);

    // Should return permission denied
    const result = serial.requestPort(.{});
    try std.testing.expectError(SerialError.NotAllowedError, result);
}

//! Battery Status API
//!
//! Spec: Battery Status API
//! https://w3c.github.io/battery/
//!
//! This module implements the BatteryManager interface which provides
//! information about system battery through a pluggable backend.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Error types for Battery operations
pub const BatteryError = error{
    /// Battery status not available
    NotSupportedError,
    /// User denied permission
    NotAllowedError,
    /// Out of memory
    OutOfMemory,
};

/// Backend interface for Battery
pub const BatteryBackend = struct {
    context: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        isCharging: *const fn (context: *anyopaque) bool,
        getChargingTime: *const fn (context: *anyopaque) f64,
        getDischargingTime: *const fn (context: *anyopaque) f64,
        getLevel: *const fn (context: *anyopaque) f64,
    };

    pub fn isCharging(self: *const BatteryBackend) bool {
        return self.vtable.isCharging(self.context);
    }

    pub fn getChargingTime(self: *const BatteryBackend) f64 {
        return self.vtable.getChargingTime(self.context);
    }

    pub fn getDischargingTime(self: *const BatteryBackend) f64 {
        return self.vtable.getDischargingTime(self.context);
    }

    pub fn getLevel(self: *const BatteryBackend) f64 {
        return self.vtable.getLevel(self.context);
    }
};

/// BatteryManager interface implementation
/// Spec: BatteryManager interface
/// [SecureContext] required
pub const BatteryManager = struct {
    allocator: Allocator,
    backend: ?*BatteryBackend,

    const Self = @This();

    pub fn init(allocator: Allocator, backend: ?*BatteryBackend) Self {
        return .{
            .allocator = allocator,
            .backend = backend,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Check if battery is charging
    /// Spec: charging attribute
    pub fn isCharging(self: *Self) bool {
        if (self.backend) |backend| {
            return backend.isCharging();
        }
        // Default: assume charging (plugged in)
        return true;
    }

    /// Get time to full charge (in seconds)
    /// Spec: chargingTime attribute
    /// Returns Infinity if not charging or unknown
    pub fn getChargingTime(self: *Self) f64 {
        if (self.backend) |backend| {
            return backend.getChargingTime();
        }
        // Default: return 0 (fully charged)
        return 0;
    }

    /// Get time to empty (in seconds)
    /// Spec: dischargingTime attribute
    /// Returns Infinity if charging or unknown
    pub fn getDischargingTime(self: *Self) f64 {
        if (self.backend) |backend| {
            return backend.getDischargingTime();
        }
        // Default: return Infinity (not discharging)
        return std.math.inf(f64);
    }

    /// Get battery level (0.0 to 1.0)
    /// Spec: level attribute
    pub fn getLevel(self: *Self) f64 {
        if (self.backend) |backend| {
            return backend.getLevel();
        }
        // Default: full battery
        return 1.0;
    }
};

// ============================================================================
// Stub Backend
// ============================================================================

/// Stub backend that simulates a full battery
pub const StubBatteryBackend = struct {
    backend: BatteryBackend,

    const Self_ = @This();

    pub fn init() Self_ {
        return .{
            .backend = .{
                .context = undefined,
                .vtable = &vtable,
            },
        };
    }

    pub fn getBackend(self: *Self_) *BatteryBackend {
        self.backend.context = self;
        return &self.backend;
    }

    fn isCharging(_: *anyopaque) bool {
        return true;
    }

    fn getChargingTime(_: *anyopaque) f64 {
        return 0;
    }

    fn getDischargingTime(_: *anyopaque) f64 {
        return std.math.inf(f64);
    }

    fn getLevel(_: *anyopaque) f64 {
        return 1.0;
    }

    const vtable = BatteryBackend.VTable{
        .isCharging = isCharging,
        .getChargingTime = getChargingTime,
        .getDischargingTime = getDischargingTime,
        .getLevel = getLevel,
    };
};

// ============================================================================
// Tests
// ============================================================================

test "BatteryManager - init without backend" {
    const allocator = std.testing.allocator;

    var battery = BatteryManager.init(allocator, null);
    defer battery.deinit();

    // Default values
    try std.testing.expect(battery.isCharging());
    try std.testing.expectEqual(@as(f64, 0), battery.getChargingTime());
    try std.testing.expect(std.math.isInf(battery.getDischargingTime()));
    try std.testing.expectEqual(@as(f64, 1.0), battery.getLevel());
}

test "BatteryManager - with stub backend" {
    const allocator = std.testing.allocator;

    var stub = StubBatteryBackend.init();
    var battery = BatteryManager.init(allocator, stub.getBackend());
    defer battery.deinit();

    try std.testing.expect(battery.isCharging());
    try std.testing.expectEqual(@as(f64, 1.0), battery.getLevel());
}

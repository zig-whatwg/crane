//! Quota Management for WHATWG Storage Standard
//!
//! Implements quota calculation and enforcement per the Storage Standard.
//! https://storage.spec.whatwg.org/#quota
//!
//! ## Quota Model
//!
//! The Storage Standard defines quota at multiple levels:
//! - **Per-endpoint quota**: Fixed quota for specific APIs (e.g., localStorage = 5 MiB)
//! - **Per-bucket quota**: Total quota for all endpoints in a bucket
//! - **Per-origin quota**: Total quota for all buckets in an origin's shelf
//!
//! ## Storage Pressure
//!
//! When storage pressure occurs (disk space low), the user agent may:
//! - Clear "best-effort" storage (eviction)
//! - Notify the application via StorageManager events
//! - Persist "persistent" storage until user explicitly clears
//!
//! ## Quota Calculation
//!
//! Quota is intentionally imprecise to prevent fingerprinting:
//! - Usage values are rounded/approximated
//! - Quota may vary based on available disk space
//! - Different origins may get different quotas

const std = @import("std");
const standard = @import("standard.zig");

/// Default quota for origins (50 MiB)
/// This is a conservative default; browsers typically allow more
pub const DEFAULT_ORIGIN_QUOTA: u64 = 50 * 1024 * 1024;

/// Minimum quota that should always be available (1 MiB)
pub const MINIMUM_QUOTA: u64 = 1 * 1024 * 1024;

/// Maximum quota for any single origin (2 GiB)
/// Prevents any single origin from consuming too much space
pub const MAXIMUM_ORIGIN_QUOTA: u64 = 2 * 1024 * 1024 * 1024;

/// Quota enforcement result
pub const QuotaCheckResult = enum {
    /// Operation is within quota
    allowed,
    /// Operation would exceed quota
    quota_exceeded,
    /// Storage is under pressure (may be evicted)
    storage_pressure,
};

/// Quota configuration
pub const QuotaConfig = struct {
    /// Default quota for new origins
    default_origin_quota: u64 = DEFAULT_ORIGIN_QUOTA,
    /// Minimum quota guaranteed to all origins
    minimum_quota: u64 = MINIMUM_QUOTA,
    /// Maximum quota for any origin
    maximum_quota: u64 = MAXIMUM_ORIGIN_QUOTA,
    /// Threshold for storage pressure warning (0.0-1.0)
    pressure_threshold: f32 = 0.9,
    /// Enable quota enforcement (can be disabled for testing)
    enforce_quota: bool = true,
};

/// Global quota configuration
var global_config: QuotaConfig = .{};

/// Set the global quota configuration
pub fn setQuotaConfig(config: QuotaConfig) void {
    global_config = config;
}

/// Get the current quota configuration
pub fn getQuotaConfig() QuotaConfig {
    return global_config;
}

/// Reset quota configuration to defaults
pub fn resetQuotaConfig() void {
    global_config = .{};
}

/// Callback for storage pressure notifications
pub const PressureCallback = *const fn (origin: []const u8, usage: u64, quota: u64) void;

/// QuotaManager handles quota calculation and enforcement
pub const QuotaManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config: QuotaConfig,
    /// Optional callback for pressure notifications
    pressure_callback: ?PressureCallback = null,

    /// Initialize a QuotaManager with default config
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .config = global_config,
        };
    }

    /// Initialize with custom config
    pub fn initWithConfig(allocator: std.mem.Allocator, config: QuotaConfig) Self {
        return Self{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Set the pressure callback
    pub fn setPressureCallback(self: *Self, callback: ?PressureCallback) void {
        self.pressure_callback = callback;
    }

    /// Calculate quota for an origin
    /// The quota may vary based on:
    /// - Available disk space
    /// - Origin's persistence status
    /// - User preferences
    pub fn calculateQuota(self: *Self, origin: []const u8) !u64 {
        _ = origin; // TODO: Per-origin quota customization

        // For now, return the default quota
        // In a full implementation, this would consider:
        // 1. Available disk space
        // 2. Whether the origin is persistent
        // 3. User-granted quotas
        // 4. Site engagement scores
        return self.config.default_origin_quota;
    }

    /// Check if an operation would exceed quota
    pub fn checkQuota(
        self: *Self,
        origin: []const u8,
        current_usage: u64,
        additional_bytes: u64,
    ) !QuotaCheckResult {
        // If quota enforcement is disabled, always allow
        if (!self.config.enforce_quota) {
            return .allowed;
        }

        const quota = try self.calculateQuota(origin);
        const new_usage = current_usage + additional_bytes;

        // Check if we would exceed quota
        if (new_usage > quota) {
            return .quota_exceeded;
        }

        // Check for storage pressure
        const usage_ratio: f32 = @as(f32, @floatFromInt(new_usage)) / @as(f32, @floatFromInt(quota));
        if (usage_ratio >= self.config.pressure_threshold) {
            // Notify via callback if set
            if (self.pressure_callback) |callback| {
                callback(origin, new_usage, quota);
            }
            return .storage_pressure;
        }

        return .allowed;
    }

    /// Get estimated usage for an origin
    /// Values are intentionally imprecise to prevent fingerprinting
    pub fn getEstimatedUsage(self: *Self, origin: []const u8) !u64 {
        const shelf = try standard.obtainLocalStorageShelf(self.allocator, origin) orelse {
            return 0;
        };

        const usage = shelf.estimateUsage();

        // Round to nearest KB to prevent fingerprinting
        return roundToKilobytes(usage);
    }

    /// Get estimated quota for an origin
    /// Values are intentionally imprecise
    pub fn getEstimatedQuota(self: *Self, origin: []const u8) !u64 {
        const quota = try self.calculateQuota(origin);

        // Round to nearest MB to prevent fingerprinting
        return roundToMegabytes(quota);
    }

    /// Enforce quota by checking before write operations
    /// Returns true if the operation is allowed
    pub fn enforceWrite(
        self: *Self,
        origin: []const u8,
        bytes_to_write: u64,
    ) !bool {
        if (!self.config.enforce_quota) {
            return true;
        }

        const current_usage = try self.getEstimatedUsage(origin);
        const result = try self.checkQuota(origin, current_usage, bytes_to_write);

        return result == .allowed or result == .storage_pressure;
    }
};

/// Round bytes to nearest kilobyte (for anti-fingerprinting)
fn roundToKilobytes(bytes: u64) u64 {
    const kb: u64 = 1024;
    return ((bytes + kb / 2) / kb) * kb;
}

/// Round bytes to nearest megabyte (for anti-fingerprinting)
fn roundToMegabytes(bytes: u64) u64 {
    const mb: u64 = 1024 * 1024;
    return ((bytes + mb / 2) / mb) * mb;
}

/// Format bytes as human-readable string
pub fn formatBytes(allocator: std.mem.Allocator, bytes: u64) ![]u8 {
    if (bytes < 1024) {
        return std.fmt.allocPrint(allocator, "{d} B", .{bytes});
    } else if (bytes < 1024 * 1024) {
        const kb = @as(f64, @floatFromInt(bytes)) / 1024.0;
        return std.fmt.allocPrint(allocator, "{d:.1} KB", .{kb});
    } else if (bytes < 1024 * 1024 * 1024) {
        const mb = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0);
        return std.fmt.allocPrint(allocator, "{d:.1} MB", .{mb});
    } else {
        const gb = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0 * 1024.0);
        return std.fmt.allocPrint(allocator, "{d:.2} GB", .{gb});
    }
}

// ============================================================================
// Tests
// ============================================================================

test "QuotaManager - init with defaults" {
    const allocator = std.testing.allocator;

    const manager = QuotaManager.init(allocator);

    try std.testing.expectEqual(DEFAULT_ORIGIN_QUOTA, manager.config.default_origin_quota);
    try std.testing.expectEqual(MINIMUM_QUOTA, manager.config.minimum_quota);
    try std.testing.expectEqual(MAXIMUM_ORIGIN_QUOTA, manager.config.maximum_quota);
}

test "QuotaManager - calculate quota" {
    const allocator = std.testing.allocator;

    var manager = QuotaManager.init(allocator);
    const quota = try manager.calculateQuota("https://example.com");

    try std.testing.expectEqual(DEFAULT_ORIGIN_QUOTA, quota);
}

test "QuotaManager - check quota allowed" {
    const allocator = std.testing.allocator;

    var manager = QuotaManager.init(allocator);
    const result = try manager.checkQuota("https://example.com", 0, 1024);

    try std.testing.expectEqual(QuotaCheckResult.allowed, result);
}

test "QuotaManager - check quota exceeded" {
    const allocator = std.testing.allocator;

    var manager = QuotaManager.init(allocator);
    // Try to write more than quota allows
    const result = try manager.checkQuota("https://example.com", DEFAULT_ORIGIN_QUOTA, 1);

    try std.testing.expectEqual(QuotaCheckResult.quota_exceeded, result);
}

test "QuotaManager - check quota storage pressure" {
    const allocator = std.testing.allocator;

    var manager = QuotaManager.init(allocator);
    // Use 91% of quota (above 90% threshold)
    const usage = @as(u64, @intFromFloat(@as(f64, @floatFromInt(DEFAULT_ORIGIN_QUOTA)) * 0.91));
    const result = try manager.checkQuota("https://example.com", usage, 0);

    try std.testing.expectEqual(QuotaCheckResult.storage_pressure, result);
}

test "QuotaManager - enforce write allowed" {
    const allocator = std.testing.allocator;

    // Clean up any existing global shed
    standard.deinitGlobalStorageShed(allocator);
    defer standard.deinitGlobalStorageShed(allocator);

    var manager = QuotaManager.init(allocator);
    const allowed = try manager.enforceWrite("https://example.com", 1024);

    try std.testing.expect(allowed);
}

test "QuotaManager - custom config" {
    const allocator = std.testing.allocator;

    const config = QuotaConfig{
        .default_origin_quota = 10 * 1024 * 1024, // 10 MiB
        .enforce_quota = true,
    };

    var manager = QuotaManager.initWithConfig(allocator, config);
    const quota = try manager.calculateQuota("https://example.com");

    try std.testing.expectEqual(@as(u64, 10 * 1024 * 1024), quota);
}

test "QuotaManager - quota disabled" {
    const allocator = std.testing.allocator;

    const config = QuotaConfig{
        .enforce_quota = false,
    };

    var manager = QuotaManager.initWithConfig(allocator, config);
    // Even exceeding quota should be allowed when disabled
    const result = try manager.checkQuota("https://example.com", DEFAULT_ORIGIN_QUOTA * 2, 0);

    try std.testing.expectEqual(QuotaCheckResult.allowed, result);
}

test "roundToKilobytes" {
    // 500 bytes -> 0 KB (rounds down)
    try std.testing.expectEqual(@as(u64, 0), roundToKilobytes(500));

    // 512 bytes -> 1024 (rounds up to 1 KB)
    try std.testing.expectEqual(@as(u64, 1024), roundToKilobytes(512));

    // 1500 bytes -> 1024 (rounds to 1 KB)
    try std.testing.expectEqual(@as(u64, 1024), roundToKilobytes(1500));

    // 1536 bytes -> 2048 (rounds to 2 KB)
    try std.testing.expectEqual(@as(u64, 2048), roundToKilobytes(1536));
}

test "roundToMegabytes" {
    const mb: u64 = 1024 * 1024;

    // Less than 0.5 MB -> 0
    try std.testing.expectEqual(@as(u64, 0), roundToMegabytes(mb / 2 - 1));

    // 0.5 MB -> 1 MB (rounds up)
    try std.testing.expectEqual(mb, roundToMegabytes(mb / 2));

    // 1.4 MB -> 1 MB
    try std.testing.expectEqual(mb, roundToMegabytes(mb + mb / 3));

    // 1.5 MB -> 2 MB
    try std.testing.expectEqual(2 * mb, roundToMegabytes(mb + mb / 2));
}

test "formatBytes" {
    const allocator = std.testing.allocator;

    // Bytes
    const b = try formatBytes(allocator, 500);
    defer allocator.free(b);
    try std.testing.expectEqualStrings("500 B", b);

    // Kilobytes
    const kb = try formatBytes(allocator, 2048);
    defer allocator.free(kb);
    try std.testing.expectEqualStrings("2.0 KB", kb);

    // Megabytes
    const mb = try formatBytes(allocator, 5 * 1024 * 1024);
    defer allocator.free(mb);
    try std.testing.expectEqualStrings("5.0 MB", mb);

    // Gigabytes
    const gb = try formatBytes(allocator, 2 * 1024 * 1024 * 1024);
    defer allocator.free(gb);
    try std.testing.expectEqualStrings("2.00 GB", gb);
}

//! Persistence Modes for WHATWG Storage Standard
//!
//! Implements persistence modes per the Storage Standard.
//! https://storage.spec.whatwg.org/#persistence
//!
//! ## Persistence Modes
//!
//! Storage buckets can operate in two modes:
//!
//! - **best-effort**: Default mode. Storage may be cleared by the user agent
//!   under storage pressure without user consent.
//!
//! - **persistent**: Protected mode. Storage cannot be cleared by the user agent
//!   without explicit user consent. Requires permission grant.
//!
//! ## Eviction Policy
//!
//! When storage pressure occurs (disk space low):
//! 1. User agent identifies origins using "best-effort" storage
//! 2. Origins are ranked by LRU (Least Recently Used) or other criteria
//! 3. Storage is cleared from lowest-priority origins first
//! 4. "persistent" storage is never cleared automatically
//!
//! ## Storage Pressure Events
//!
//! Applications can be notified of storage pressure:
//! - Via StorageManager's estimate() showing reduced quota
//! - Via storage pressure callbacks (implementation-specific)
//! - Via quota exceeded errors on write operations

const std = @import("std");
const standard = @import("standard.zig");

/// Persistence mode for storage buckets
/// Re-exported from standard for convenience
pub const BucketMode = standard.BucketMode;

/// Eviction priority for origins under storage pressure
pub const EvictionPriority = enum(u8) {
    /// Never evict (persistent storage)
    never = 0,
    /// Low priority for eviction (recently used)
    low = 1,
    /// Medium priority for eviction
    medium = 2,
    /// High priority for eviction (least recently used)
    high = 3,
    /// Critical - evict first (expired or unused)
    critical = 4,
};

/// Storage pressure level
pub const PressureLevel = enum {
    /// Normal operation, no pressure
    none,
    /// Moderate pressure, consider clearing caches
    moderate,
    /// Critical pressure, must clear storage
    critical,
};

/// Eviction candidate representing an origin's storage
pub const EvictionCandidate = struct {
    /// Origin identifier
    origin: []const u8,
    /// Storage usage in bytes
    usage: u64,
    /// Last access timestamp (unix millis)
    last_access: i64,
    /// Eviction priority
    priority: EvictionPriority,
    /// Whether this origin has persistent storage
    is_persistent: bool,
};

/// Eviction policy configuration
pub const EvictionPolicy = struct {
    /// Minimum time since last access before considering for eviction (ms)
    min_idle_time_ms: i64 = 24 * 60 * 60 * 1000, // 24 hours
    /// Threshold for moderate pressure (0.0-1.0)
    moderate_threshold: f32 = 0.75,
    /// Threshold for critical pressure (0.0-1.0)
    critical_threshold: f32 = 0.90,
    /// Whether to allow evicting persistent storage (requires user consent)
    allow_persistent_eviction: bool = false,
    /// Maximum number of origins to evict in one pass
    max_evictions_per_pass: usize = 10,
};

/// Callback for eviction events
pub const EvictionCallback = *const fn (origin: []const u8, bytes_freed: u64) void;

/// PersistenceManager handles persistence modes and eviction
pub const PersistenceManager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    policy: EvictionPolicy,
    /// Optional callback for eviction notifications
    eviction_callback: ?EvictionCallback = null,

    /// Initialize with default policy
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .policy = .{},
        };
    }

    /// Initialize with custom policy
    pub fn initWithPolicy(allocator: std.mem.Allocator, policy: EvictionPolicy) Self {
        return Self{
            .allocator = allocator,
            .policy = policy,
        };
    }

    /// Set the eviction callback
    pub fn setEvictionCallback(self: *Self, callback: ?EvictionCallback) void {
        self.eviction_callback = callback;
    }

    /// Check if an origin's storage is persistent
    pub fn isPersistent(self: *Self, origin: []const u8) !bool {
        const shelf = try standard.obtainLocalStorageShelf(
            self.allocator,
            origin,
        ) orelse return false;

        const bucket = shelf.getDefaultBucket() orelse return false;
        return bucket.mode == .persistent;
    }

    /// Request persistent storage for an origin
    /// Returns true if persistence was granted
    pub fn requestPersistence(
        self: *Self,
        origin: []const u8,
        permission_granted: bool,
    ) !bool {
        if (!permission_granted) {
            return false;
        }

        const shelf = try standard.obtainLocalStorageShelf(
            self.allocator,
            origin,
        ) orelse return false;

        const bucket = shelf.getDefaultBucket() orelse return false;

        // Already persistent
        if (bucket.mode == .persistent) {
            return true;
        }

        // Grant persistence
        bucket.mode = .persistent;
        return true;
    }

    /// Revoke persistent storage for an origin (reset to best-effort)
    pub fn revokePersistence(self: *Self, origin: []const u8) !void {
        const shelf = try standard.obtainLocalStorageShelf(
            self.allocator,
            origin,
        ) orelse return;

        const bucket = shelf.getDefaultBucket() orelse return;
        bucket.mode = .best_effort;
    }

    /// Calculate eviction priority for an origin
    pub fn calculateEvictionPriority(
        self: *Self,
        usage: u64,
        last_access: i64,
        is_persistent: bool,
    ) EvictionPriority {
        // Never evict persistent storage (unless policy allows)
        if (is_persistent and !self.policy.allow_persistent_eviction) {
            return .never;
        }

        const now = std.time.milliTimestamp();
        const idle_time = now - last_access;

        // Critical: not accessed in over 30 days
        if (idle_time > 30 * 24 * 60 * 60 * 1000) {
            return .critical;
        }

        // High: not accessed in over 7 days
        if (idle_time > 7 * 24 * 60 * 60 * 1000) {
            return .high;
        }

        // Medium: not accessed in over min_idle_time
        if (idle_time > self.policy.min_idle_time_ms) {
            return .medium;
        }

        // Low: recently used but uses significant storage
        if (usage > 10 * 1024 * 1024) { // > 10 MiB
            return .low;
        }

        // Never: recently used, small storage
        return .never;
    }

    /// Determine current storage pressure level
    pub fn getPressureLevel(self: *Self, usage_ratio: f32) PressureLevel {
        if (usage_ratio >= self.policy.critical_threshold) {
            return .critical;
        }
        if (usage_ratio >= self.policy.moderate_threshold) {
            return .moderate;
        }
        return .none;
    }

    /// Select origins for eviction based on pressure level
    /// Returns a list of origins sorted by eviction priority
    pub fn selectEvictionCandidates(
        self: *Self,
        candidates: []const EvictionCandidate,
        pressure: PressureLevel,
    ) ![]const EvictionCandidate {
        if (pressure == .none) {
            return &[_]EvictionCandidate{};
        }

        // Filter out persistent storage unless critical and policy allows
        var eligible = std.ArrayList(EvictionCandidate).init(self.allocator);
        defer eligible.deinit();

        for (candidates) |candidate| {
            const dominated_by_persistent = candidate.is_persistent and
                !self.policy.allow_persistent_eviction;

            if (dominated_by_persistent and pressure != .critical) {
                continue;
            }

            if (candidate.priority != .never) {
                try eligible.append(candidate);
            }
        }

        // Sort by priority (highest priority for eviction first)
        const items = try eligible.toOwnedSlice();

        std.mem.sort(EvictionCandidate, items, {}, struct {
            fn lessThan(_: void, a: EvictionCandidate, b: EvictionCandidate) bool {
                // Higher priority value = evict first
                return @intFromEnum(a.priority) > @intFromEnum(b.priority);
            }
        }.lessThan);

        // Limit to max evictions per pass
        const max = @min(items.len, self.policy.max_evictions_per_pass);
        return items[0..max];
    }

    /// Clear storage for an origin (eviction)
    /// Returns bytes freed
    pub fn evictOrigin(self: *Self, origin: []const u8) !u64 {
        const shelf = try standard.obtainLocalStorageShelf(
            self.allocator,
            origin,
        ) orelse return 0;

        // Calculate usage before clearing
        const usage = shelf.estimateUsage();

        // Clear all storage in the default bucket
        // In a full implementation, this would clear all bottles
        // For now, we just mark the operation

        // Notify via callback
        if (self.eviction_callback) |callback| {
            callback(origin, usage);
        }

        return usage;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "PersistenceManager - init" {
    const allocator = std.testing.allocator;

    const manager = PersistenceManager.init(allocator);

    try std.testing.expectEqual(@as(f32, 0.75), manager.policy.moderate_threshold);
    try std.testing.expectEqual(@as(f32, 0.90), manager.policy.critical_threshold);
}

test "PersistenceManager - custom policy" {
    const allocator = std.testing.allocator;

    const policy = EvictionPolicy{
        .moderate_threshold = 0.5,
        .critical_threshold = 0.8,
    };

    const manager = PersistenceManager.initWithPolicy(allocator, policy);

    try std.testing.expectEqual(@as(f32, 0.5), manager.policy.moderate_threshold);
    try std.testing.expectEqual(@as(f32, 0.8), manager.policy.critical_threshold);
}

test "PersistenceManager - isPersistent returns false for new origin" {
    const allocator = std.testing.allocator;

    // Clean up any existing global shed
    standard.deinitGlobalStorageShed(allocator);
    defer standard.deinitGlobalStorageShed(allocator);

    var manager = PersistenceManager.init(allocator);
    const is_persistent = try manager.isPersistent("https://example.com");

    try std.testing.expect(!is_persistent);
}

test "PersistenceManager - requestPersistence with permission" {
    const allocator = std.testing.allocator;

    // Clean up any existing global shed
    standard.deinitGlobalStorageShed(allocator);
    defer standard.deinitGlobalStorageShed(allocator);

    var manager = PersistenceManager.init(allocator);

    // Request with permission granted
    const granted = try manager.requestPersistence("https://example.com", true);
    try std.testing.expect(granted);

    // Should now be persistent
    const is_persistent = try manager.isPersistent("https://example.com");
    try std.testing.expect(is_persistent);
}

test "PersistenceManager - requestPersistence without permission" {
    const allocator = std.testing.allocator;

    // Clean up any existing global shed
    standard.deinitGlobalStorageShed(allocator);
    defer standard.deinitGlobalStorageShed(allocator);

    var manager = PersistenceManager.init(allocator);

    // Request without permission
    const granted = try manager.requestPersistence("https://example.com", false);
    try std.testing.expect(!granted);

    // Should still be best-effort
    const is_persistent = try manager.isPersistent("https://example.com");
    try std.testing.expect(!is_persistent);
}

test "PersistenceManager - revokePersistence" {
    const allocator = std.testing.allocator;

    // Clean up any existing global shed
    standard.deinitGlobalStorageShed(allocator);
    defer standard.deinitGlobalStorageShed(allocator);

    var manager = PersistenceManager.init(allocator);

    // Grant persistence
    _ = try manager.requestPersistence("https://example.com", true);
    try std.testing.expect(try manager.isPersistent("https://example.com"));

    // Revoke persistence
    try manager.revokePersistence("https://example.com");
    try std.testing.expect(!try manager.isPersistent("https://example.com"));
}

test "PersistenceManager - calculateEvictionPriority persistent" {
    const allocator = std.testing.allocator;

    var manager = PersistenceManager.init(allocator);
    const priority = manager.calculateEvictionPriority(1024, std.time.milliTimestamp(), true);

    try std.testing.expectEqual(EvictionPriority.never, priority);
}

test "PersistenceManager - calculateEvictionPriority recently used" {
    const allocator = std.testing.allocator;

    var manager = PersistenceManager.init(allocator);
    const priority = manager.calculateEvictionPriority(1024, std.time.milliTimestamp(), false);

    try std.testing.expectEqual(EvictionPriority.never, priority);
}

test "PersistenceManager - calculateEvictionPriority idle" {
    const allocator = std.testing.allocator;

    var manager = PersistenceManager.init(allocator);
    // 8 days ago
    const old_time = std.time.milliTimestamp() - (8 * 24 * 60 * 60 * 1000);
    const priority = manager.calculateEvictionPriority(1024, old_time, false);

    try std.testing.expectEqual(EvictionPriority.high, priority);
}

test "PersistenceManager - getPressureLevel" {
    const allocator = std.testing.allocator;

    var manager = PersistenceManager.init(allocator);

    try std.testing.expectEqual(PressureLevel.none, manager.getPressureLevel(0.5));
    try std.testing.expectEqual(PressureLevel.moderate, manager.getPressureLevel(0.8));
    try std.testing.expectEqual(PressureLevel.critical, manager.getPressureLevel(0.95));
}

test "EvictionPriority ordering" {
    // Verify enum values are ordered correctly
    try std.testing.expect(@intFromEnum(EvictionPriority.never) < @intFromEnum(EvictionPriority.low));
    try std.testing.expect(@intFromEnum(EvictionPriority.low) < @intFromEnum(EvictionPriority.medium));
    try std.testing.expect(@intFromEnum(EvictionPriority.medium) < @intFromEnum(EvictionPriority.high));
    try std.testing.expect(@intFromEnum(EvictionPriority.high) < @intFromEnum(EvictionPriority.critical));
}

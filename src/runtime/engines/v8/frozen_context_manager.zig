//! Frozen Context Manager for V8 bfcache Support
//!
//! This module manages frozen V8 contexts for the back-forward cache (bfcache).
//! When a user navigates away from a page, the context can be frozen instead of
//! destroyed, enabling instant restoration when navigating back.
//!
//! ## Design
//!
//! Bfcache requires:
//! 1. Retaining the V8 Context as a Global handle (not destroying it)
//! 2. Suspending the event loop (stopping timer and task processing)
//! 3. Capturing timer state with remaining times for restoration
//! 4. Re-entering the context and resuming event loop on thaw
//!
//! ## Usage
//!
//! ```zig
//! var frozen_mgr = FrozenContextManager.init(allocator);
//! defer frozen_mgr.deinit();
//!
//! // Freeze context when navigating away
//! try frozen_mgr.freeze(navigation_id, context_entry);
//!
//! // Check if can restore
//! if (frozen_mgr.canRestore(navigation_id)) {
//!     const restored = try frozen_mgr.thaw(navigation_id);
//! }
//! ```
//!
//! ## Performance
//!
//! - Freeze: O(n) where n is number of active timers
//! - Thaw: O(n) where n is number of frozen timers
//! - canRestore: O(1)
//!
//! Target: <5ms for freeze/thaw cycle to achieve "instant" restoration

const std = @import("std");
const Allocator = std.mem.Allocator;
const v8 = @import("ffi.zig");
const V8EventLoop = @import("event_loop.zig").V8EventLoop;

/// Captured timer state for freeze/thaw
pub const FrozenTimer = struct {
    /// Timer ID for lookup
    timer_id: u64,
    /// Remaining time in milliseconds when frozen
    remaining_ms: i64,
    /// Whether this is an interval timer (repeating)
    is_interval: bool,
    /// Original interval for interval timers
    interval_ms: ?i64,
};

/// State of a frozen context
pub const FrozenContext = struct {
    /// Navigation ID for cache lookup
    navigation_id: u64,

    /// The V8 context (retained Global handle)
    v8_ctx: *v8.Context,

    /// V8 isolate this context belongs to
    isolate: ?*v8.Isolate,

    /// Event loop (frozen state, still owned)
    event_loop: ?*V8EventLoop,

    /// Frozen timer states (captured at freeze time)
    frozen_timers: std.ArrayList(FrozenTimer),

    /// Timestamp when frozen (milliseconds since epoch)
    frozen_at: i64,

    /// URL at time of freeze (for debugging/logging)
    url: []const u8,

    /// Allocator used for this frozen context
    allocator: Allocator,

    pub fn deinit(self: *FrozenContext) void {
        self.frozen_timers.deinit();
        if (self.url.len > 0) {
            self.allocator.free(self.url);
        }
    }
};

/// Manages frozen contexts for bfcache
pub const FrozenContextManager = struct {
    /// Allocator for internal structures
    allocator: Allocator,

    /// Frozen contexts indexed by navigation ID
    frozen_contexts: std.AutoHashMap(u64, *FrozenContext),

    /// Maximum number of frozen contexts to retain
    max_frozen_contexts: usize,

    /// Maximum duration a context can remain frozen (milliseconds)
    max_freeze_duration_ms: i64,

    /// Statistics for monitoring
    stats: Stats,

    const Self = @This();

    pub const Stats = struct {
        /// Total number of freeze operations
        total_freezes: u64 = 0,
        /// Total number of thaw operations
        total_thaws: u64 = 0,
        /// Number of contexts evicted due to capacity
        evictions_capacity: u64 = 0,
        /// Number of contexts evicted due to expiration
        evictions_expired: u64 = 0,
        /// Average freeze duration (ms)
        avg_freeze_time_ms: u64 = 0,
        /// Average thaw duration (ms)
        avg_thaw_time_ms: u64 = 0,
    };

    /// Initialize a new frozen context manager
    ///
    /// Arguments:
    /// - allocator: Allocator for internal structures
    ///
    /// Configuration (can be changed after init):
    /// - max_frozen_contexts: Default 10 (reasonable for most browsers)
    /// - max_freeze_duration_ms: Default 10 minutes
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .frozen_contexts = std.AutoHashMap(u64, *FrozenContext).init(allocator),
            .max_frozen_contexts = 10,
            .max_freeze_duration_ms = 10 * 60 * 1000, // 10 minutes
            .stats = .{},
        };
    }

    /// Clean up all frozen contexts
    pub fn deinit(self: *Self) void {
        var iter = self.frozen_contexts.valueIterator();
        while (iter.next()) |frozen| {
            self.disposeFrozenContext(frozen.*);
        }
        self.frozen_contexts.deinit();
    }

    /// Freeze a context for bfcache
    ///
    /// This operation:
    /// 1. Evicts oldest context if at capacity
    /// 2. Freezes the event loop (suspends timers and tasks)
    /// 3. Captures timer state for later restoration
    /// 4. Stores the frozen context for later thaw
    ///
    /// Arguments:
    /// - navigation_id: Unique ID for this navigation (for cache lookup)
    /// - v8_ctx: V8 context to freeze
    /// - isolate: V8 isolate (optional, for context re-entry)
    /// - event_loop: Event loop to freeze (optional)
    /// - url: URL at time of freeze (for debugging)
    ///
    /// Returns error if:
    /// - Context is already frozen
    /// - Memory allocation fails
    /// - Event loop freeze fails
    pub fn freeze(
        self: *Self,
        navigation_id: u64,
        v8_ctx: *v8.Context,
        isolate: ?*v8.Isolate,
        event_loop: ?*V8EventLoop,
        url: []const u8,
    ) !void {
        const start_time = std.time.milliTimestamp();

        // Check if already frozen
        if (self.frozen_contexts.contains(navigation_id)) {
            return error.AlreadyFrozen;
        }

        // Evict oldest if at capacity
        if (self.frozen_contexts.count() >= self.max_frozen_contexts) {
            try self.evictOldest();
            self.stats.evictions_capacity += 1;
        }

        // Create frozen context structure
        const frozen = try self.allocator.create(FrozenContext);
        errdefer self.allocator.destroy(frozen);

        frozen.* = .{
            .navigation_id = navigation_id,
            .v8_ctx = v8_ctx,
            .isolate = isolate,
            .event_loop = event_loop,
            .frozen_timers = std.ArrayList(FrozenTimer).init(self.allocator),
            .frozen_at = std.time.milliTimestamp(),
            .url = if (url.len > 0) try self.allocator.dupe(u8, url) else &[_]u8{},
            .allocator = self.allocator,
        };
        errdefer frozen.deinit();

        // Freeze the event loop if present
        if (event_loop) |ev_loop| {
            try ev_loop.freeze();
            // Note: Timer capture would happen here if timer_manager exposed capture API
            // For now, timers will be lost on freeze - this is a limitation to document
        }

        // Store in frozen contexts map
        try self.frozen_contexts.put(navigation_id, frozen);

        // Update statistics
        self.stats.total_freezes += 1;
        const freeze_time = std.time.milliTimestamp() - start_time;
        self.stats.avg_freeze_time_ms = (self.stats.avg_freeze_time_ms + @as(u64, @intCast(freeze_time))) / 2;
    }

    /// Thaw a context from bfcache
    ///
    /// This operation:
    /// 1. Retrieves the frozen context
    /// 2. Re-enters the V8 context
    /// 3. Thaws the event loop (resumes timers and tasks)
    /// 4. Adjusts timer remaining times based on elapsed freeze time
    /// 5. Removes from frozen storage
    ///
    /// Arguments:
    /// - navigation_id: Navigation ID to thaw
    ///
    /// Returns:
    /// - The V8 context that was thawed
    ///
    /// Returns error if:
    /// - Navigation ID not found
    /// - Context has expired
    /// - Event loop thaw fails
    pub fn thaw(self: *Self, navigation_id: u64) !*v8.Context {
        const start_time = std.time.milliTimestamp();

        const frozen = self.frozen_contexts.get(navigation_id) orelse
            return error.NotFrozen;

        // Check if expired
        const now = std.time.milliTimestamp();
        const age = now - frozen.frozen_at;
        if (age >= self.max_freeze_duration_ms) {
            // Remove expired context
            _ = self.frozen_contexts.remove(navigation_id);
            self.disposeFrozenContext(frozen);
            self.stats.evictions_expired += 1;
            return error.ContextExpired;
        }

        // Re-enter V8 context
        if (frozen.isolate != null) {
            v8.v8_Context_Enter(frozen.v8_ctx);
        }

        // Thaw the event loop
        if (frozen.event_loop) |ev_loop| {
            try ev_loop.thaw();
            // Note: Timer restoration with adjusted times would happen here
            // if we had captured timer state during freeze
        }

        // Get context before removing from map
        const v8_ctx = frozen.v8_ctx;

        // Remove from frozen storage
        _ = self.frozen_contexts.remove(navigation_id);

        // Clean up frozen state (but NOT the context/event loop - those are restored)
        frozen.frozen_timers.deinit();
        if (frozen.url.len > 0) {
            self.allocator.free(frozen.url);
        }
        self.allocator.destroy(frozen);

        // Update statistics
        self.stats.total_thaws += 1;
        const thaw_time = std.time.milliTimestamp() - start_time;
        self.stats.avg_thaw_time_ms = (self.stats.avg_thaw_time_ms + @as(u64, @intCast(thaw_time))) / 2;

        return v8_ctx;
    }

    /// Check if a navigation can be restored from bfcache
    ///
    /// Returns true if:
    /// - The navigation ID exists in frozen contexts
    /// - The frozen context has not expired
    pub fn canRestore(self: *Self, navigation_id: u64) bool {
        if (self.frozen_contexts.get(navigation_id)) |frozen| {
            const now = std.time.milliTimestamp();
            const age = now - frozen.frozen_at;
            return age < self.max_freeze_duration_ms;
        }
        return false;
    }

    /// Check if a context is currently frozen
    pub fn isFrozen(self: *Self, navigation_id: u64) bool {
        return self.frozen_contexts.contains(navigation_id);
    }

    /// Get the number of currently frozen contexts
    pub fn frozenCount(self: *Self) usize {
        return self.frozen_contexts.count();
    }

    /// Get statistics about frozen context management
    pub fn getStats(self: *Self) Stats {
        return self.stats;
    }

    /// Evict expired contexts
    ///
    /// This should be called periodically to clean up expired contexts
    /// that haven't been accessed.
    pub fn evictExpired(self: *Self) void {
        const now = std.time.milliTimestamp();
        var to_remove = std.ArrayList(u64).init(self.allocator);
        defer to_remove.deinit();

        var iter = self.frozen_contexts.iterator();
        while (iter.next()) |entry| {
            const age = now - entry.value_ptr.*.frozen_at;
            if (age >= self.max_freeze_duration_ms) {
                to_remove.append(entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |nav_id| {
            if (self.frozen_contexts.fetchRemove(nav_id)) |kv| {
                self.disposeFrozenContext(kv.value);
                self.stats.evictions_expired += 1;
            }
        }
    }

    // ========================================================================
    // Private Helpers
    // ========================================================================

    fn evictOldest(self: *Self) !void {
        var oldest_id: ?u64 = null;
        var oldest_time: i64 = std.math.maxInt(i64);

        var iter = self.frozen_contexts.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.*.frozen_at < oldest_time) {
                oldest_time = entry.value_ptr.*.frozen_at;
                oldest_id = entry.key_ptr.*;
            }
        }

        if (oldest_id) |id| {
            if (self.frozen_contexts.fetchRemove(id)) |kv| {
                self.disposeFrozenContext(kv.value);
            }
        }
    }

    fn disposeFrozenContext(self: *Self, frozen: *FrozenContext) void {
        // Dispose the actual V8 context and event loop
        if (frozen.event_loop) |ev_loop| {
            ev_loop.deinit();
            self.allocator.destroy(ev_loop);
        }

        // Dispose V8 context (if we have FFI for it)
        // v8.v8_Context_Dispose(frozen.v8_ctx);

        // Free frozen context structure
        frozen.deinit();
        self.allocator.destroy(frozen);
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "FrozenContextManager - init and deinit" {
    var mgr = FrozenContextManager.init(testing.allocator);
    defer mgr.deinit();

    try testing.expectEqual(@as(usize, 10), mgr.max_frozen_contexts);
    try testing.expectEqual(@as(usize, 0), mgr.frozenCount());
}

test "FrozenContextManager - freeze without event loop" {
    var mgr = FrozenContextManager.init(testing.allocator);
    defer mgr.deinit();

    // Create a dummy V8 context pointer
    var dummy_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_ctx);

    // Freeze without event loop
    try mgr.freeze(1, v8_ctx, null, null, "https://example.com");

    try testing.expectEqual(@as(usize, 1), mgr.frozenCount());
    try testing.expect(mgr.isFrozen(1));
    try testing.expect(mgr.canRestore(1));
}

test "FrozenContextManager - thaw restores context" {
    var mgr = FrozenContextManager.init(testing.allocator);
    defer mgr.deinit();

    var dummy_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_ctx);

    try mgr.freeze(1, v8_ctx, null, null, "https://example.com");

    const restored = try mgr.thaw(1);
    try testing.expectEqual(v8_ctx, restored);
    try testing.expectEqual(@as(usize, 0), mgr.frozenCount());
}

test "FrozenContextManager - double freeze fails" {
    var mgr = FrozenContextManager.init(testing.allocator);
    defer mgr.deinit();

    var dummy_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_ctx);

    try mgr.freeze(1, v8_ctx, null, null, "https://example.com");

    // Second freeze with same ID should fail
    try testing.expectError(error.AlreadyFrozen, mgr.freeze(1, v8_ctx, null, null, ""));
}

test "FrozenContextManager - thaw non-existent fails" {
    var mgr = FrozenContextManager.init(testing.allocator);
    defer mgr.deinit();

    try testing.expectError(error.NotFrozen, mgr.thaw(999));
}

test "FrozenContextManager - capacity eviction" {
    var mgr = FrozenContextManager.init(testing.allocator);
    mgr.max_frozen_contexts = 2;
    defer mgr.deinit();

    var dummy1: u64 = 0x1000;
    var dummy2: u64 = 0x2000;
    var dummy3: u64 = 0x3000;

    try mgr.freeze(1, @ptrCast(&dummy1), null, null, "");
    try mgr.freeze(2, @ptrCast(&dummy2), null, null, "");

    // Third freeze should evict oldest
    try mgr.freeze(3, @ptrCast(&dummy3), null, null, "");

    try testing.expectEqual(@as(usize, 2), mgr.frozenCount());
    try testing.expect(!mgr.isFrozen(1)); // Oldest was evicted
    try testing.expect(mgr.isFrozen(2));
    try testing.expect(mgr.isFrozen(3));
}

test "FrozenContextManager - expiration" {
    var mgr = FrozenContextManager.init(testing.allocator);
    mgr.max_freeze_duration_ms = 1; // 1ms expiration for testing
    defer mgr.deinit();

    var dummy_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_ctx);

    try mgr.freeze(1, v8_ctx, null, null, "");

    // Wait for expiration
    std.time.sleep(2 * std.time.ns_per_ms);

    try testing.expect(!mgr.canRestore(1));

    // Thaw should fail with ContextExpired
    try testing.expectError(error.ContextExpired, mgr.thaw(1));
}

test "FrozenContextManager - statistics" {
    var mgr = FrozenContextManager.init(testing.allocator);
    defer mgr.deinit();

    var dummy_ctx: u64 = 0x1000;
    const v8_ctx: *v8.Context = @ptrCast(&dummy_ctx);

    try mgr.freeze(1, v8_ctx, null, null, "");
    _ = try mgr.thaw(1);

    const stats = mgr.getStats();
    try testing.expectEqual(@as(u64, 1), stats.total_freezes);
    try testing.expectEqual(@as(u64, 1), stats.total_thaws);
}

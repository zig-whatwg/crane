//! Arena Pool for Zero-Fragmentation Memory Management
//!
//! This module provides a pool of reusable `ArenaAllocator` instances for
//! request/transaction memory management. Each arena provides bump-allocation
//! (very fast) with bulk deallocation on release.
//!
//! ## Why Arena Pooling?
//!
//! - **Zero fragmentation**: All allocations within a request freed together
//! - **Fast allocation**: O(1) bump pointer allocation
//! - **Memory reuse**: Arenas retain capacity after reset
//! - **Thread-safe**: Mutex-protected acquire/release
//!
//! ## Usage Pattern
//!
//! Each IndexedDB transaction or HTTP request acquires an arena:
//!
//! ```zig
//! var pool = try ArenaPool.init(allocator, 8);
//! defer pool.deinit();
//!
//! // Per-request:
//! var arena = try pool.acquire();
//! defer pool.release(arena);
//!
//! // Fast allocations within request
//! const data = try arena.allocator().alloc(u8, 1024);
//! // No need to free - bulk freed on release
//! ```
//!
//! ## Performance Characteristics
//!
//! - **acquire()**: O(1) when pool has available arenas, O(1) amortized otherwise
//! - **release()**: O(1) (reset + push to free list)
//! - **allocation**: O(1) bump pointer
//! - **Memory**: Arenas retain capacity, reducing reallocation
//!
//! ## Thread Safety
//!
//! The pool is thread-safe via mutex. Individual arenas are NOT thread-safe
//! and should only be used by the acquiring thread.
//!

const std = @import("std");

/// Configuration for arena pool
pub const Config = struct {
    /// Initial number of arenas to pre-allocate
    initial_capacity: usize = 8,

    /// Maximum arenas to keep in pool (0 = unlimited)
    /// When releasing, if pool exceeds this, arena is destroyed instead
    max_pool_size: usize = 0,

    /// Whether to reset arenas with retain_capacity or free_all
    /// retain_capacity: Faster, uses more memory
    /// free_all: Slower, uses less memory
    retain_capacity_on_reset: bool = true,
};

/// Statistics for arena pool
pub const Stats = struct {
    /// Total arenas ever created
    total_created: usize = 0,

    /// Currently available in pool
    available: usize = 0,

    /// Currently in use
    in_use: usize = 0,

    /// Total acquire calls
    acquire_count: u64 = 0,

    /// Total release calls
    release_count: u64 = 0,

    /// Arenas destroyed due to max_pool_size
    overflow_destroyed: u64 = 0,
};

/// A pool of reusable arena allocators
///
/// Provides fast, thread-safe arena acquisition and release with automatic
/// reset on return. Ideal for per-request or per-transaction memory management.
pub const ArenaPool = struct {
    /// All arenas ever created (for cleanup)
    arenas: std.ArrayListUnmanaged(*std.heap.ArenaAllocator),

    /// Available arenas (free list)
    available: std.ArrayListUnmanaged(*std.heap.ArenaAllocator),

    /// Upstream allocator for creating arenas
    upstream: std.mem.Allocator,

    /// Configuration
    config: Config,

    /// Thread safety
    mutex: std.Thread.Mutex,

    /// Statistics
    stats: Stats,

    const Self = @This();

    /// Initialize a new arena pool
    ///
    /// Pre-allocates `config.initial_capacity` arenas for immediate use.
    pub fn init(upstream: std.mem.Allocator, config: Config) !Self {
        var pool = Self{
            .arenas = .{},
            .available = .{},
            .upstream = upstream,
            .config = config,
            .mutex = .{},
            .stats = .{},
        };

        // Pre-allocate initial arenas
        for (0..config.initial_capacity) |_| {
            const arena = try pool.createArena();
            try pool.available.append(upstream, arena);
        }

        pool.stats.available = config.initial_capacity;

        return pool;
    }

    /// Initialize with default configuration
    pub fn initDefault(upstream: std.mem.Allocator) !Self {
        return init(upstream, .{});
    }

    /// Deinitialize pool and free all arenas
    pub fn deinit(self: *Self) void {
        // Destroy all arenas
        for (self.arenas.items) |arena| {
            arena.deinit();
            self.upstream.destroy(arena);
        }

        self.arenas.deinit(self.upstream);
        self.available.deinit(self.upstream);
    }

    /// Acquire an arena from the pool
    ///
    /// Returns an available arena or creates a new one if pool is empty.
    /// Thread-safe.
    pub fn acquire(self: *Self) !*std.heap.ArenaAllocator {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.stats.acquire_count += 1;

        if (self.available.items.len > 0) {
            const arena = self.available.pop().?;
            self.stats.available -= 1;
            self.stats.in_use += 1;
            return arena;
        }

        // Pool empty, create new arena
        const arena = try self.createArena();
        self.stats.in_use += 1;
        return arena;
    }

    /// Release an arena back to the pool
    ///
    /// Resets the arena (freeing all allocations) and returns it to the pool.
    /// Thread-safe.
    pub fn release(self: *Self, arena: *std.heap.ArenaAllocator) void {
        // Reset arena outside lock (potentially slow)
        if (self.config.retain_capacity_on_reset) {
            _ = arena.reset(.retain_capacity);
        } else {
            _ = arena.reset(.free_all);
        }

        self.mutex.lock();
        defer self.mutex.unlock();

        self.stats.release_count += 1;
        self.stats.in_use -= 1;

        // Check if we should return to pool or destroy
        if (self.config.max_pool_size > 0 and
            self.available.items.len >= self.config.max_pool_size)
        {
            // Pool at max capacity, destroy arena
            arena.deinit();
            self.upstream.destroy(arena);
            self.stats.overflow_destroyed += 1;

            // Remove from arenas list
            for (self.arenas.items, 0..) |a, i| {
                if (a == arena) {
                    _ = self.arenas.swapRemove(i);
                    break;
                }
            }
            self.stats.total_created -= 1;
        } else {
            // Return to pool
            self.available.append(self.upstream, arena) catch {
                // If append fails, destroy the arena
                arena.deinit();
                self.upstream.destroy(arena);
            };
            self.stats.available += 1;
        }
    }

    /// Get current statistics
    pub fn getStats(self: *Self) Stats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats;
    }

    /// Get number of available arenas
    pub fn availableCount(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.available;
    }

    /// Get number of arenas in use
    pub fn inUseCount(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats.in_use;
    }

    // ========================================================================
    // Internal
    // ========================================================================

    fn createArena(self: *Self) !*std.heap.ArenaAllocator {
        const arena = try self.upstream.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(self.upstream);

        try self.arenas.append(self.upstream, arena);
        self.stats.total_created += 1;

        return arena;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ArenaPool - basic acquire/release cycle" {
    var pool = try ArenaPool.initDefault(std.testing.allocator);
    defer pool.deinit();

    // Acquire arena
    var arena = try pool.acquire();

    // Allocate some memory
    const data = try arena.allocator().alloc(u8, 1024);
    try std.testing.expect(data.len == 1024);

    // Release (no need to free data - arena handles it)
    pool.release(arena);

    // Stats should be updated
    const stats = pool.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.acquire_count);
    try std.testing.expectEqual(@as(u64, 1), stats.release_count);
}

test "ArenaPool - pool grows when exhausted" {
    var pool = try ArenaPool.init(std.testing.allocator, .{ .initial_capacity = 2 });
    defer pool.deinit();

    // Acquire all initial arenas
    const arena1 = try pool.acquire();
    const arena2 = try pool.acquire();

    // Pool should grow
    const arena3 = try pool.acquire();

    const stats = pool.getStats();
    try std.testing.expectEqual(@as(usize, 3), stats.total_created);
    try std.testing.expectEqual(@as(usize, 3), stats.in_use);
    try std.testing.expectEqual(@as(usize, 0), stats.available);

    // Release all
    pool.release(arena1);
    pool.release(arena2);
    pool.release(arena3);

    const stats2 = pool.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats2.in_use);
    try std.testing.expectEqual(@as(usize, 3), stats2.available);
}

test "ArenaPool - arena memory is reused" {
    var pool = try ArenaPool.initDefault(std.testing.allocator);
    defer pool.deinit();

    // First cycle
    const arena1 = try pool.acquire();
    _ = try arena1.allocator().alloc(u8, 1024);
    pool.release(arena1);

    // Second cycle - should get same arena
    const arena2 = try pool.acquire();
    try std.testing.expect(arena1 == arena2);

    pool.release(arena2);
}

test "ArenaPool - max_pool_size limits pool" {
    var pool = try ArenaPool.init(std.testing.allocator, .{
        .initial_capacity = 1,
        .max_pool_size = 2,
    });
    defer pool.deinit();

    // Acquire 3 arenas
    const arena1 = try pool.acquire();
    const arena2 = try pool.acquire();
    const arena3 = try pool.acquire();

    try std.testing.expectEqual(@as(usize, 3), pool.getStats().total_created);

    // Release all - only 2 should be kept
    pool.release(arena1);
    pool.release(arena2);
    pool.release(arena3);

    const stats = pool.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.available);
    try std.testing.expectEqual(@as(u64, 1), stats.overflow_destroyed);
}

test "ArenaPool - no memory leaks" {
    var pool = try ArenaPool.initDefault(std.testing.allocator);
    defer pool.deinit();

    // Stress test
    for (0..100) |_| {
        var arena = try pool.acquire();
        _ = try arena.allocator().alloc(u8, 4096);
        pool.release(arena);
    }

    // If we get here without leaks, test passes
    // std.testing.allocator will catch leaks
}

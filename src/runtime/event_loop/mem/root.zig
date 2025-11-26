//! Event Loop Memory Management
//!
//! This module provides memory management infrastructure for the production event loop:
//!
//! - **jemalloc**: Optional jemalloc integration for fragmentation resistance
//! - **arena_pool**: Pool of reusable arena allocators (Phase 1.1)
//! - **slab**: Fixed-block slab allocator for I/O buffers (Phase 1.2)
//!
//! ## Memory Hierarchy
//!
//! ```
//! ┌─────────────────────────────────────────────────┐
//! │              jemalloc (root)                     │
//! │         ↓ low fragmentation ↓                   │
//! ├─────────────────────────────────────────────────┤
//! │           ArenaPool (transactions)              │
//! │    ↓ fast alloc, bulk free, zero frag ↓         │
//! ├─────────────────────────────────────────────────┤
//! │           SlabAllocator (I/O buffers)           │
//! │     ↓ fixed blocks, stable addresses ↓          │
//! └─────────────────────────────────────────────────┘
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const mem = @import("mem");
//!
//! // Get best available root allocator
//! const root_allocator = mem.getRootAllocator();
//!
//! // Create arena pool for transactions
//! var pool = try mem.ArenaPool.init(root_allocator, 8);
//! defer pool.deinit();
//!
//! // Acquire arena for a transaction
//! var arena = try pool.acquire();
//! defer pool.release(arena);
//!
//! // Allocate within transaction (bulk freed on release)
//! const data = try arena.allocator().alloc(u8, 1024);
//! ```
//!

const std = @import("std");

pub const jemalloc = @import("jemalloc.zig");

/// Arena pool for transaction/request memory management
pub const arena_pool = @import("arena_pool.zig");
pub const ArenaPool = arena_pool.ArenaPool;
pub const ArenaPoolConfig = arena_pool.Config;
pub const ArenaPoolStats = arena_pool.Stats;

// TODO(Phase 1.2): Slab allocator
// pub const slab = @import("slab.zig");
// pub const SlabAllocator = slab.SlabAllocator;

/// Get the best available root allocator
///
/// Priority:
/// 1. jemalloc (if available and linked)
/// 2. Zig's page allocator (fallback)
///
/// For production use, build with `-Djemalloc=true` to get jemalloc.
pub fn getRootAllocator() std.mem.Allocator {
    return jemalloc.allocator() orelse std.heap.page_allocator;
}

/// Memory statistics
pub const MemoryStats = struct {
    /// Root allocator stats (from jemalloc if available)
    root: jemalloc.Stats = .{},

    /// Arena pool stats (TODO: Phase 1.1)
    arena_pool: struct {
        total_arenas: usize = 0,
        available_arenas: usize = 0,
        total_allocated: usize = 0,
    } = .{},

    /// Slab allocator stats (TODO: Phase 1.2)
    slab: struct {
        total_slabs: usize = 0,
        free_blocks: usize = 0,
        used_blocks: usize = 0,
    } = .{},
};

/// Get current memory statistics
pub fn getStats() MemoryStats {
    return MemoryStats{
        .root = jemalloc.getStats(),
    };
}

// ============================================================================
// Tests
// ============================================================================

test "getRootAllocator returns valid allocator" {
    const alloc = getRootAllocator();

    // Should be able to allocate and free
    const ptr = try alloc.alloc(u8, 64);
    defer alloc.free(ptr);

    try std.testing.expect(ptr.len == 64);
}

test "getStats returns valid struct" {
    const stats = getStats();
    _ = stats;
}

test "ArenaPool accessible from root" {
    var pool = try ArenaPool.initDefault(std.testing.allocator);
    defer pool.deinit();

    const arena = try pool.acquire();
    pool.release(arena);
}

test {
    // Run child module tests
    _ = jemalloc;
    _ = arena_pool;
}

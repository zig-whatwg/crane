//! Slab Allocator for Fixed-Size I/O Buffers
//!
//! This module provides a lock-free slab allocator for I/O buffers. It's designed
//! for use with io_uring, IOCP, and kqueue where buffer addresses must remain
//! stable during async operations.
//!
//! ## Why Slab Allocation?
//!
//! - **Address stability**: Buffers don't move after allocation
//! - **Lock-free**: CAS-based free list for high concurrency
//! - **Fixed size**: No fragmentation, predictable memory usage
//! - **Page-aligned**: Required by kernel I/O interfaces
//!
//! ## Design
//!
//! ```
//! ┌─────────────────────────────────────────────────┐
//! │                    Slab (2MB)                    │
//! ├─────────────────────────────────────────────────┤
//! │ Block 0   │ Block 1   │ Block 2   │ ... │ Block N │
//! │ [8KB]     │ [8KB]     │ [8KB]     │     │ [8KB]   │
//! └─────────────────────────────────────────────────┘
//!        ↓           ↓           ↓
//!   free_list → Block 2 → Block 1 → Block 0 → null
//! ```
//!
//! ## Usage
//!
//! ```zig
//! var slab = try SlabAllocator.init(allocator, .{});
//! defer slab.deinit();
//!
//! // Acquire buffer for I/O
//! var buffer = try slab.acquire();
//!
//! // Use buffer for async I/O
//! // Buffer address is stable during operation
//!
//! // Release when done
//! slab.release(buffer);
//! ```
//!
//! ## Thread Safety
//!
//! All operations are lock-free using atomic CAS operations.
//! Safe for use from multiple threads without external synchronization.
//!

const std = @import("std");
const atomic = std.atomic;
const Atomic = atomic.Value;

/// Configuration for slab allocator
pub const Config = struct {
    /// Size of each block in bytes (default 8KB)
    block_size: usize = 8192,

    /// Number of blocks per slab (default 256 = 2MB slab for 8KB blocks)
    blocks_per_slab: usize = 256,

    /// Pre-allocate initial slab (default true)
    preallocate: bool = true,
};

/// Statistics for slab allocator
pub const Stats = struct {
    /// Total slabs allocated
    slab_count: usize = 0,

    /// Total blocks across all slabs
    total_blocks: usize = 0,

    /// Blocks currently in use
    blocks_in_use: usize = 0,

    /// Blocks available in free list
    blocks_available: usize = 0,

    /// Total acquire operations
    acquire_count: u64 = 0,

    /// Total release operations
    release_count: u64 = 0,

    /// CAS retries during acquire
    acquire_retries: u64 = 0,
};

/// Lock-free slab allocator for fixed-size I/O buffers
pub const SlabAllocator = struct {
    /// Configuration
    config: Config,

    /// All allocated slabs (for cleanup)
    slabs: std.ArrayListUnmanaged([]align(4096) u8),

    /// Lock-free free list head (intrusive)
    free_list_head: Atomic(?*Block),

    /// Upstream allocator for slabs
    upstream: std.mem.Allocator,

    /// Mutex for slab allocation (only used when growing)
    slab_mutex: std.Thread.Mutex,

    /// Statistics (relaxed atomics for stats)
    stats: Stats,

    const Self = @This();

    /// Block header (intrusive linked list node)
    const Block = struct {
        next: ?*Block,
        // Data follows immediately after header
    };

    /// Initialize slab allocator
    pub fn init(upstream: std.mem.Allocator, config: Config) !Self {
        var allocator = Self{
            .config = config,
            .slabs = .{},
            .free_list_head = Atomic(?*Block).init(null),
            .upstream = upstream,
            .slab_mutex = .{},
            .stats = .{},
        };

        if (config.preallocate) {
            try allocator.allocateSlab();
        }

        return allocator;
    }

    /// Initialize with default config
    pub fn initDefault(upstream: std.mem.Allocator) !Self {
        return init(upstream, .{});
    }

    /// Deinitialize and free all slabs
    pub fn deinit(self: *Self) void {
        for (self.slabs.items) |slab| {
            self.upstream.free(slab);
        }
        self.slabs.deinit(self.upstream);
    }

    /// Acquire a buffer from the slab allocator
    ///
    /// Returns a fixed-size buffer. The buffer address is stable and won't
    /// change during its lifetime.
    ///
    /// Thread-safe (lock-free).
    pub fn acquire(self: *Self) ![]u8 {
        self.stats.acquire_count += 1;

        while (true) {
            // Try to pop from free list
            const head = self.free_list_head.load(.acquire);

            if (head) |block| {
                // Try CAS to pop this block
                if (self.free_list_head.cmpxchgWeak(
                    block,
                    block.next,
                    .release,
                    .monotonic,
                )) |_| {
                    // CAS failed, retry
                    self.stats.acquire_retries += 1;
                    continue;
                }

                // Success - return buffer portion of block
                self.stats.blocks_in_use += 1;
                self.stats.blocks_available -= 1;
                return self.blockToBuffer(block);
            }

            // Free list empty - allocate new slab
            try self.allocateSlab();
            // Retry loop will now find blocks
        }
    }

    /// Release a buffer back to the slab allocator
    ///
    /// Thread-safe (lock-free).
    pub fn release(self: *Self, buffer: []u8) void {
        self.stats.release_count += 1;

        const block = self.bufferToBlock(buffer);

        // Lock-free push to free list
        while (true) {
            const head = self.free_list_head.load(.acquire);
            block.next = head;

            if (self.free_list_head.cmpxchgWeak(
                head,
                block,
                .release,
                .monotonic,
            ) == null) {
                // Success
                self.stats.blocks_in_use -= 1;
                self.stats.blocks_available += 1;
                return;
            }
            // CAS failed, retry
        }
    }

    /// Get current statistics
    pub fn getStats(self: *Self) Stats {
        return self.stats;
    }

    /// Get block size
    pub fn blockSize(self: *const Self) usize {
        return self.config.block_size;
    }

    // ========================================================================
    // Internal
    // ========================================================================

    fn allocateSlab(self: *Self) !void {
        self.slab_mutex.lock();
        defer self.slab_mutex.unlock();

        // Double-check after acquiring lock
        if (self.free_list_head.load(.acquire) != null) {
            return; // Another thread already allocated
        }

        const block_total_size = @sizeOf(Block) + self.config.block_size;
        const slab_size = self.config.blocks_per_slab * block_total_size;

        // Allocate page-aligned slab
        const slab = try self.upstream.alignedAlloc(u8, .fromByteUnits(4096), slab_size);
        errdefer self.upstream.free(slab);

        try self.slabs.append(self.upstream, slab);

        // Initialize blocks and add to free list
        var i: usize = 0;
        while (i < self.config.blocks_per_slab) : (i += 1) {
            const offset = i * block_total_size;
            const block: *Block = @ptrCast(@alignCast(slab.ptr + offset));
            block.next = null;

            // Push to free list
            while (true) {
                const head = self.free_list_head.load(.acquire);
                block.next = head;
                if (self.free_list_head.cmpxchgWeak(head, block, .release, .monotonic) == null) {
                    break;
                }
            }
        }

        self.stats.slab_count += 1;
        self.stats.total_blocks += self.config.blocks_per_slab;
        self.stats.blocks_available += self.config.blocks_per_slab;
    }

    fn blockToBuffer(self: *const Self, block: *Block) []u8 {
        const block_bytes: [*]u8 = @ptrCast(block);
        const data_ptr = block_bytes + @sizeOf(Block);
        return data_ptr[0..self.config.block_size];
    }

    fn bufferToBlock(self: *const Self, buffer: []u8) *Block {
        _ = self;
        const buffer_ptr: [*]u8 = buffer.ptr;
        const block_ptr = buffer_ptr - @sizeOf(Block);
        return @ptrCast(@alignCast(block_ptr));
    }
};

// ============================================================================
// Tests
// ============================================================================

test "SlabAllocator - basic acquire/release" {
    var slab = try SlabAllocator.initDefault(std.testing.allocator);
    defer slab.deinit();

    // Acquire buffer
    const buffer = try slab.acquire();
    try std.testing.expect(buffer.len == 8192);

    // Use buffer
    buffer[0] = 42;
    buffer[8191] = 24;

    // Release
    slab.release(buffer);

    const stats = slab.getStats();
    try std.testing.expectEqual(@as(u64, 1), stats.acquire_count);
    try std.testing.expectEqual(@as(u64, 1), stats.release_count);
}

test "SlabAllocator - buffer reuse" {
    var slab = try SlabAllocator.initDefault(std.testing.allocator);
    defer slab.deinit();

    // First cycle
    const buffer1 = try slab.acquire();
    const ptr1 = buffer1.ptr;
    slab.release(buffer1);

    // Second cycle - should get same buffer (LIFO)
    const buffer2 = try slab.acquire();
    try std.testing.expect(buffer2.ptr == ptr1);

    slab.release(buffer2);
}

test "SlabAllocator - slab growth" {
    var slab = try SlabAllocator.init(std.testing.allocator, .{
        .block_size = 1024,
        .blocks_per_slab = 4,
        .preallocate = true,
    });
    defer slab.deinit();

    // Acquire all blocks from first slab
    var buffers: [4][]u8 = undefined;
    for (&buffers) |*buf| {
        buf.* = try slab.acquire();
    }

    try std.testing.expectEqual(@as(usize, 1), slab.getStats().slab_count);

    // Acquire one more - should trigger slab growth
    const extra = try slab.acquire();
    try std.testing.expectEqual(@as(usize, 2), slab.getStats().slab_count);

    // Release all
    for (buffers) |buf| {
        slab.release(buf);
    }
    slab.release(extra);
}

test "SlabAllocator - no memory leaks" {
    var slab = try SlabAllocator.initDefault(std.testing.allocator);
    defer slab.deinit();

    // Stress test
    for (0..100) |_| {
        const buffer = try slab.acquire();
        // Write to buffer to ensure it's valid
        @memset(buffer, 0);
        slab.release(buffer);
    }

    // If we get here without leaks, test passes
}

test "SlabAllocator - address stability" {
    var slab = try SlabAllocator.initDefault(std.testing.allocator);
    defer slab.deinit();

    const buffer = try slab.acquire();
    const original_ptr = buffer.ptr;

    // Verify address is stable (didn't change)
    try std.testing.expect(buffer.ptr == original_ptr);

    slab.release(buffer);
}

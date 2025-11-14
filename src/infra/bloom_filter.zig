//! Bloom Filter for fast membership testing
//!
//! A space-efficient probabilistic data structure used to test whether an element
//! is a member of a set. False positive matches are possible, but false negatives
//! are not – in other words, a query returns either "possibly in set" or 
//! "definitely not in set".
//!
//! This implementation uses a fixed-size bit array with multiple hash functions.
//! Optimized for CSS class and ID matching where we want fast negative lookups.

const std = @import("std");

/// Fixed-size bloom filter for string membership testing
/// 
/// Uses 256 bits (32 bytes) and 3 hash functions for a good balance of:
/// - Memory usage (32 bytes per filter)
/// - False positive rate (~2.5% with typical class lists)
/// - Hash computation overhead
pub const BloomFilter = struct {
    bits: [32]u8 = [_]u8{0} ** 32,

    const Self = @This();
    const NUM_BITS = 256;
    const NUM_HASHES = 3;

    /// Create an empty bloom filter
    pub fn init() Self {
        return .{};
    }

    /// Add a string to the bloom filter
    pub fn add(self: *Self, item: []const u8) void {
        const h1 = hash1(item);
        const h2 = hash2(item);
        const h3 = hash3(item);

        self.setBit(h1 % NUM_BITS);
        self.setBit(h2 % NUM_BITS);
        self.setBit(h3 % NUM_BITS);
    }

    /// Test if a string might be in the set
    /// Returns true if possibly present, false if definitely not present
    pub fn contains(self: *const Self, item: []const u8) bool {
        const h1 = hash1(item);
        const h2 = hash2(item);
        const h3 = hash3(item);

        return self.getBit(h1 % NUM_BITS) and
               self.getBit(h2 % NUM_BITS) and
               self.getBit(h3 % NUM_BITS);
    }

    /// Clear all bits (reset to empty state)
    pub fn clear(self: *Self) void {
        @memset(&self.bits, 0);
    }

    /// Set a specific bit
    fn setBit(self: *Self, index: usize) void {
        const byte_idx = index / 8;
        const bit_idx = @as(u3, @intCast(index % 8));
        self.bits[byte_idx] |= (@as(u8, 1) << bit_idx);
    }

    /// Get a specific bit
    fn getBit(self: *const Self, index: usize) bool {
        const byte_idx = index / 8;
        const bit_idx = @as(u3, @intCast(index % 8));
        return (self.bits[byte_idx] & (@as(u8, 1) << bit_idx)) != 0;
    }

    /// Hash function 1: FNV-1a hash
    fn hash1(data: []const u8) u32 {
        var h: u32 = 2166136261;
        for (data) |byte| {
            h ^= byte;
            h *%= 16777619;
        }
        return h;
    }

    /// Hash function 2: DJB2 hash
    fn hash2(data: []const u8) u32 {
        var h: u32 = 5381;
        for (data) |byte| {
            h = ((h << 5) +% h) +% byte;
        }
        return h;
    }

    /// Hash function 3: SDBM hash
    fn hash3(data: []const u8) u32 {
        var h: u32 = 0;
        for (data) |byte| {
            h = byte +% (h << 6) +% (h << 16) -% h;
        }
        return h;
    }
};

// ============================================================================
// Tests
// ============================================================================







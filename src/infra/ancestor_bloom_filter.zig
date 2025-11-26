//! Ancestor Bloom Filter for CSS Selector Matching
//!
//! A counting bloom filter optimized for CSS selector matching, modeled after
//! Firefox's Stylo implementation. Used for fast-rejection of selectors before
//! expensive ancestor tree traversal.
//!
//! ## Design (Firefox-inspired)
//!
//! - **4096 entries** (12-bit keys) for excellent false positive rate
//! - **8-bit counters** for counting filter (supports add/remove)
//! - **2 hash functions** extracted from single 24-bit hash
//! - **<1% false positive rate** with typical selector usage
//!
//! ## Usage
//!
//! The filter maintains ancestor element hashes during tree traversal:
//! ```zig
//! var filter = AncestorBloomFilter.init();
//!
//! // Walking down the tree
//! filter.add(hashElement(parent));
//! filter.add(hashElement(grandparent));
//!
//! // Fast rejection check before expensive matching
//! if (!filter.mightContain(selector_hash)) {
//!     return false; // Definitely no match!
//! }
//!
//! // Walking back up (counting filter supports removal)
//! filter.remove(hashElement(parent));
//! ```
//!
//! ## References
//!
//! - Firefox Stylo: servo/components/selectors/bloom.rs
//! - CSS Selectors Level 4: https://drafts.csswg.org/selectors-4/

const std = @import("std");

/// 4096-entry counting bloom filter for ancestor element filtering.
///
/// Uses 12-bit keys (4096 entries) and 8-bit counters to track ancestor
/// element hashes. The counting design allows adding and removing elements
/// as we traverse up and down the DOM tree.
pub const AncestorBloomFilter = struct {
    /// 8-bit counters for each hash bucket.
    /// Uses saturating arithmetic to prevent overflow.
    counters: [ARRAY_SIZE]u8 = [_]u8{0} ** ARRAY_SIZE,

    const Self = @This();

    /// 12-bit keys = 4096 entries (matching Firefox's design)
    const KEY_SIZE: u5 = 12;
    const ARRAY_SIZE: usize = 1 << KEY_SIZE; // 4096
    const BLOOM_HASH_MASK: u32 = ARRAY_SIZE - 1; // 0xFFF

    /// Create an empty ancestor bloom filter.
    pub fn init() Self {
        return .{};
    }

    /// Add an element hash to the filter.
    ///
    /// Uses two hash functions extracted from the 32-bit input:
    /// - hash1: lower 12 bits
    /// - hash2: bits 12-23
    ///
    /// Counters use saturating addition to prevent overflow.
    pub fn add(self: *Self, hash: u32) void {
        const h1 = hash1(hash);
        const h2 = hash2(hash);
        self.counters[h1] +|= 1; // Saturating add
        self.counters[h2] +|= 1;
    }

    /// Remove an element hash from the filter.
    ///
    /// Counters use saturating subtraction. Only call this for elements
    /// that were previously added.
    pub fn remove(self: *Self, hash: u32) void {
        const h1 = hash1(hash);
        const h2 = hash2(hash);
        self.counters[h1] -|= 1; // Saturating sub
        self.counters[h2] -|= 1;
    }

    /// Check if an element hash might be in the filter.
    ///
    /// Returns:
    /// - `false`: Element is **definitely not** in the ancestors (fast path!)
    /// - `true`: Element **might** be in the ancestors (need to verify)
    ///
    /// False positives are possible, but false negatives are not.
    pub fn mightContain(self: *const Self, hash: u32) bool {
        const h1 = hash1(hash);
        const h2 = hash2(hash);
        return self.counters[h1] != 0 and self.counters[h2] != 0;
    }

    /// Check if the filter is empty (no elements added).
    pub fn isEmpty(self: *const Self) bool {
        for (self.counters) |c| {
            if (c != 0) return false;
        }
        return true;
    }

    /// Clear all entries from the filter.
    pub fn clear(self: *Self) void {
        @memset(&self.counters, 0);
    }

    /// Get the number of non-zero buckets (for debugging).
    pub fn countNonZeroBuckets(self: *const Self) usize {
        var count: usize = 0;
        for (self.counters) |c| {
            if (c != 0) count += 1;
        }
        return count;
    }

    // ========================================================================
    // Hash Functions
    // ========================================================================

    /// Hash function 1: Extract lower 12 bits
    fn hash1(h: u32) u12 {
        return @truncate(h & BLOOM_HASH_MASK);
    }

    /// Hash function 2: Extract bits 12-23
    fn hash2(h: u32) u12 {
        return @truncate((h >> KEY_SIZE) & BLOOM_HASH_MASK);
    }
};

/// Hash a string for use with AncestorBloomFilter.
///
/// Uses FNV-1a hash which provides good distribution for short strings
/// like element tag names, IDs, and class names.
pub fn hashString(s: []const u8) u32 {
    var h: u32 = 2166136261; // FNV offset basis
    for (s) |byte| {
        h ^= byte;
        h *%= 16777619; // FNV prime
    }
    return h;
}

/// Hash a string (lowercase version) for case-insensitive matching.
///
/// Used for HTML tag names which are case-insensitive.
pub fn hashStringLower(s: []const u8) u32 {
    var h: u32 = 2166136261; // FNV offset basis
    for (s) |byte| {
        const lower = std.ascii.toLower(byte);
        h ^= lower;
        h *%= 16777619; // FNV prime
    }
    return h;
}

// ============================================================================
// Precomputed Ancestor Hashes
// ============================================================================

/// Precomputed hashes from a selector for fast bloom filter rejection.
///
/// During selector parsing, we collect up to 4 hashes from non-rightmost
/// selector components. This enables O(1) rejection check before any
/// tree traversal.
pub const AncestorHashes = struct {
    /// Up to 4 precomputed hashes from selector components.
    /// Zero means no hash at that position.
    hashes: [4]u32 = [_]u32{0} ** 4,

    /// Number of valid hashes (0-4).
    len: u8 = 0,

    const Self = @This();

    /// Create empty ancestor hashes.
    pub fn init() Self {
        return .{};
    }

    /// Add a hash from a selector component.
    pub fn addHash(self: *Self, hash: u32) void {
        if (self.len < 4 and hash != 0) {
            self.hashes[self.len] = hash;
            self.len += 1;
        }
    }

    /// Add hash from a tag name (lowercase for case-insensitivity).
    pub fn addTagName(self: *Self, tag_name: []const u8) void {
        self.addHash(hashStringLower(tag_name));
    }

    /// Add hash from an ID.
    pub fn addId(self: *Self, id: []const u8) void {
        self.addHash(hashString(id));
    }

    /// Add hash from a class name.
    pub fn addClass(self: *Self, class_name: []const u8) void {
        self.addHash(hashString(class_name));
    }

    /// Check if selector might match given the ancestor bloom filter.
    ///
    /// Returns:
    /// - `false`: Selector **definitely won't** match (fast rejection!)
    /// - `true`: Selector **might** match (need full evaluation)
    pub fn mayMatch(self: *const Self, filter: *const AncestorBloomFilter) bool {
        // If no ancestor requirements, might match
        if (self.len == 0) return true;

        // Check all precomputed hashes
        for (self.hashes[0..self.len]) |hash| {
            if (!filter.mightContain(hash)) {
                return false; // Fast rejection!
            }
        }
        return true;
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "AncestorBloomFilter - basic add and check" {
    var filter = AncestorBloomFilter.init();

    const hash1 = hashString("div");
    const hash2 = hashString("span");

    // Initially empty
    try testing.expect(filter.isEmpty());
    try testing.expect(!filter.mightContain(hash1));
    try testing.expect(!filter.mightContain(hash2));

    // Add div
    filter.add(hash1);
    try testing.expect(!filter.isEmpty());
    try testing.expect(filter.mightContain(hash1));
    try testing.expect(!filter.mightContain(hash2));

    // Add span
    filter.add(hash2);
    try testing.expect(filter.mightContain(hash1));
    try testing.expect(filter.mightContain(hash2));
}

test "AncestorBloomFilter - counting (add/remove)" {
    var filter = AncestorBloomFilter.init();

    const hash = hashString("article");

    // Add twice
    filter.add(hash);
    filter.add(hash);
    try testing.expect(filter.mightContain(hash));

    // Remove once - should still be present
    filter.remove(hash);
    try testing.expect(filter.mightContain(hash));

    // Remove again - should be gone
    filter.remove(hash);
    try testing.expect(!filter.mightContain(hash));
}

test "AncestorBloomFilter - clear" {
    var filter = AncestorBloomFilter.init();

    filter.add(hashString("div"));
    filter.add(hashString("span"));
    filter.add(hashString("article"));
    try testing.expect(!filter.isEmpty());

    filter.clear();
    try testing.expect(filter.isEmpty());
}

test "AncestorBloomFilter - no false negatives" {
    var filter = AncestorBloomFilter.init();

    // Add many elements
    const elements = [_][]const u8{ "html", "body", "div", "main", "article", "section", "header", "nav" };
    for (elements) |elem| {
        filter.add(hashString(elem));
    }

    // All should return true (no false negatives)
    for (elements) |elem| {
        try testing.expect(filter.mightContain(hashString(elem)));
    }
}

test "AncestorHashes - collection" {
    var hashes = AncestorHashes.init();
    try testing.expectEqual(@as(u8, 0), hashes.len);

    hashes.addTagName("div");
    try testing.expectEqual(@as(u8, 1), hashes.len);

    hashes.addId("myId");
    try testing.expectEqual(@as(u8, 2), hashes.len);

    hashes.addClass("container");
    try testing.expectEqual(@as(u8, 3), hashes.len);

    hashes.addClass("active");
    try testing.expectEqual(@as(u8, 4), hashes.len);

    // Max 4 hashes
    hashes.addClass("extra");
    try testing.expectEqual(@as(u8, 4), hashes.len);
}

test "AncestorHashes - mayMatch" {
    var filter = AncestorBloomFilter.init();
    filter.add(hashStringLower("div"));
    filter.add(hashString("myId"));

    // Matching hashes
    var matching = AncestorHashes.init();
    matching.addTagName("div");
    try testing.expect(matching.mayMatch(&filter));

    // Non-matching hashes
    var non_matching = AncestorHashes.init();
    non_matching.addTagName("span"); // Not in filter
    try testing.expect(!non_matching.mayMatch(&filter));

    // Empty hashes always match (no requirements)
    var empty = AncestorHashes.init();
    try testing.expect(empty.mayMatch(&filter));
}

test "hashString - consistency" {
    const h1 = hashString("test");
    const h2 = hashString("test");
    const h3 = hashString("other");

    try testing.expectEqual(h1, h2);
    try testing.expect(h1 != h3);
}

test "hashStringLower - case insensitivity" {
    const h1 = hashStringLower("DIV");
    const h2 = hashStringLower("div");
    const h3 = hashStringLower("Div");

    try testing.expectEqual(h1, h2);
    try testing.expectEqual(h2, h3);
}

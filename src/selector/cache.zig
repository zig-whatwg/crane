//! CSS Selector Caching
//!
//! Provides caching infrastructure for parsed CSS selectors, inspired by
//! browser implementations (WebKit caches up to 512 selectors).
//!
//! ## Why Cache?
//!
//! Parsing CSS selectors is expensive. Applications often use the same
//! selectors repeatedly (e.g., in loops, event handlers, or component code).
//! Caching parsed selectors avoids redundant parsing.
//!
//! ## Cache Types
//!
//! - `SelectorQueryCache` - LRU cache for parsed SelectorList by string key
//! - `NthIndexCache` - Cache for :nth-child() index calculations per element
//! - `HasSelectorCache` - Cache for :has() match results per element+selector
//!
//! ## References
//!
//! - WebKit SelectorQueryCache: Source/WebCore/dom/SelectorQuery.cpp
//! - Firefox NthIndexCache: servo/components/selectors/nth_index_cache.rs

const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");
const SelectorList = parser.SelectorList;

// ============================================================================
// Selector Query Cache
// ============================================================================

/// LRU cache for parsed CSS selectors.
///
/// Caches parsed `SelectorList` objects by their source string, avoiding
/// redundant parsing for frequently-used selectors.
///
/// Capacity: 512 entries (matching WebKit)
pub const SelectorQueryCache = struct {
    allocator: Allocator,
    entries: std.StringHashMap(CacheEntry),
    lru_head: ?*CacheEntry = null,
    lru_tail: ?*CacheEntry = null,
    size: usize = 0,

    const Self = @This();
    const MAX_ENTRIES: usize = 512;

    /// A cached selector entry with LRU tracking.
    pub const CacheEntry = struct {
        key: []const u8, // Owned copy of selector string
        selector_list: SelectorList,
        prev: ?*CacheEntry = null,
        next: ?*CacheEntry = null,
    };

    /// Create a new selector query cache.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .entries = std.StringHashMap(CacheEntry).init(allocator),
        };
    }

    /// Clean up the cache, freeing all entries.
    pub fn deinit(self: *Self) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            var selector_list = entry.value_ptr.selector_list;
            selector_list.deinit();
            self.allocator.free(entry.value_ptr.key);
        }
        self.entries.deinit();
    }

    /// Get a cached selector list by string, returning null if not cached.
    ///
    /// Moves the entry to the front of the LRU list if found.
    pub fn get(self: *Self, selector_string: []const u8) ?*const SelectorList {
        if (self.entries.getPtr(selector_string)) |entry| {
            self.moveToFront(entry);
            return &entry.selector_list;
        }
        return null;
    }

    /// Add a parsed selector list to the cache.
    ///
    /// The cache takes ownership of the selector list. If the cache is full,
    /// the least recently used entry is evicted.
    pub fn put(self: *Self, selector_string: []const u8, selector_list: SelectorList) !void {
        // Check if already cached
        if (self.entries.contains(selector_string)) {
            // Update existing entry
            const entry = self.entries.getPtr(selector_string).?;
            entry.selector_list.deinit();
            entry.selector_list = selector_list;
            self.moveToFront(entry);
            return;
        }

        // Evict LRU if at capacity
        if (self.size >= MAX_ENTRIES) {
            try self.evictLRU();
        }

        // Create owned copy of key
        const owned_key = try self.allocator.dupe(u8, selector_string);
        errdefer self.allocator.free(owned_key);

        // Create new entry
        const entry = CacheEntry{
            .key = owned_key,
            .selector_list = selector_list,
        };

        try self.entries.put(owned_key, entry);
        self.size += 1;

        // Add to front of LRU list
        const entry_ptr = self.entries.getPtr(owned_key).?;
        self.addToFront(entry_ptr);
    }

    /// Get the number of cached entries.
    pub fn count(self: *const Self) usize {
        return self.size;
    }

    /// Clear all cached entries.
    pub fn clear(self: *Self) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            var selector_list = entry.value_ptr.selector_list;
            selector_list.deinit();
            self.allocator.free(entry.value_ptr.key);
        }
        self.entries.clearRetainingCapacity();
        self.lru_head = null;
        self.lru_tail = null;
        self.size = 0;
    }

    // ========================================================================
    // LRU List Operations
    // ========================================================================

    fn moveToFront(self: *Self, entry: *CacheEntry) void {
        if (self.lru_head == entry) return; // Already at front

        // Remove from current position
        self.removeFromList(entry);

        // Add to front
        self.addToFront(entry);
    }

    fn addToFront(self: *Self, entry: *CacheEntry) void {
        entry.prev = null;
        entry.next = self.lru_head;

        if (self.lru_head) |head| {
            head.prev = entry;
        }
        self.lru_head = entry;

        if (self.lru_tail == null) {
            self.lru_tail = entry;
        }
    }

    fn removeFromList(self: *Self, entry: *CacheEntry) void {
        if (entry.prev) |prev| {
            prev.next = entry.next;
        } else {
            self.lru_head = entry.next;
        }

        if (entry.next) |next| {
            next.prev = entry.prev;
        } else {
            self.lru_tail = entry.prev;
        }

        entry.prev = null;
        entry.next = null;
    }

    fn evictLRU(self: *Self) !void {
        const tail = self.lru_tail orelse return;

        // Remove from LRU list
        self.removeFromList(tail);

        // Free resources
        var selector_list = tail.selector_list;
        selector_list.deinit();
        const key = tail.key;

        // Remove from hash map
        _ = self.entries.remove(key);
        self.allocator.free(key);

        self.size -= 1;
    }
};

// ============================================================================
// Nth-Index Cache
// ============================================================================

/// Cache for :nth-child() index calculations.
///
/// Computing sibling indices is O(siblings) and happens frequently when
/// matching multiple elements against :nth-child selectors. This cache
/// stores computed indices per element to avoid redundant traversal.
///
/// ## Usage
///
/// ```zig
/// var cache = NthIndexCache.init(allocator);
/// defer cache.deinit();
///
/// // Check cache first
/// if (cache.getNthChild(element_ptr)) |cached_index| {
///     return matchesNthPattern(cached_index, pattern);
/// }
///
/// // Compute and cache
/// const index = computeNthChild(element);
/// cache.putNthChild(element_ptr, index);
/// ```
pub const NthIndexCache = struct {
    allocator: Allocator,
    nth_child: std.AutoHashMap(usize, i32),
    nth_last_child: std.AutoHashMap(usize, i32),
    nth_of_type: std.AutoHashMap(NthOfTypeKey, i32),
    nth_last_of_type: std.AutoHashMap(NthOfTypeKey, i32),

    const Self = @This();

    /// Key for nth-of-type caches (element pointer + tag name hash).
    pub const NthOfTypeKey = struct {
        element_ptr: usize,
        tag_name_hash: u64,
    };

    /// Create a new nth-index cache.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .nth_child = std.AutoHashMap(usize, i32).init(allocator),
            .nth_last_child = std.AutoHashMap(usize, i32).init(allocator),
            .nth_of_type = std.AutoHashMap(NthOfTypeKey, i32).init(allocator),
            .nth_last_of_type = std.AutoHashMap(NthOfTypeKey, i32).init(allocator),
        };
    }

    /// Clean up the cache.
    pub fn deinit(self: *Self) void {
        self.nth_child.deinit();
        self.nth_last_child.deinit();
        self.nth_of_type.deinit();
        self.nth_last_of_type.deinit();
    }

    // ========================================================================
    // nth-child cache
    // ========================================================================

    /// Get cached nth-child index for an element.
    pub fn getNthChild(self: *const Self, element_ptr: usize) ?i32 {
        return self.nth_child.get(element_ptr);
    }

    /// Cache an nth-child index for an element.
    pub fn putNthChild(self: *Self, element_ptr: usize, index: i32) void {
        self.nth_child.put(element_ptr, index) catch {};
    }

    // ========================================================================
    // nth-last-child cache
    // ========================================================================

    /// Get cached nth-last-child index for an element.
    pub fn getNthLastChild(self: *const Self, element_ptr: usize) ?i32 {
        return self.nth_last_child.get(element_ptr);
    }

    /// Cache an nth-last-child index for an element.
    pub fn putNthLastChild(self: *Self, element_ptr: usize, index: i32) void {
        self.nth_last_child.put(element_ptr, index) catch {};
    }

    // ========================================================================
    // nth-of-type cache
    // ========================================================================

    /// Get cached nth-of-type index for an element.
    pub fn getNthOfType(self: *const Self, element_ptr: usize, tag_name_hash: u64) ?i32 {
        return self.nth_of_type.get(.{ .element_ptr = element_ptr, .tag_name_hash = tag_name_hash });
    }

    /// Cache an nth-of-type index for an element.
    pub fn putNthOfType(self: *Self, element_ptr: usize, tag_name_hash: u64, index: i32) void {
        self.nth_of_type.put(.{ .element_ptr = element_ptr, .tag_name_hash = tag_name_hash }, index) catch {};
    }

    // ========================================================================
    // nth-last-of-type cache
    // ========================================================================

    /// Get cached nth-last-of-type index for an element.
    pub fn getNthLastOfType(self: *const Self, element_ptr: usize, tag_name_hash: u64) ?i32 {
        return self.nth_last_of_type.get(.{ .element_ptr = element_ptr, .tag_name_hash = tag_name_hash });
    }

    /// Cache an nth-last-of-type index for an element.
    pub fn putNthLastOfType(self: *Self, element_ptr: usize, tag_name_hash: u64, index: i32) void {
        self.nth_last_of_type.put(.{ .element_ptr = element_ptr, .tag_name_hash = tag_name_hash }, index) catch {};
    }

    // ========================================================================
    // Utility
    // ========================================================================

    /// Clear all cached indices.
    pub fn clear(self: *Self) void {
        self.nth_child.clearRetainingCapacity();
        self.nth_last_child.clearRetainingCapacity();
        self.nth_of_type.clearRetainingCapacity();
        self.nth_last_of_type.clearRetainingCapacity();
    }

    /// Get total number of cached entries.
    pub fn count(self: *const Self) usize {
        return self.nth_child.count() +
            self.nth_last_child.count() +
            self.nth_of_type.count() +
            self.nth_last_of_type.count();
    }
};

// ============================================================================
// Has Selector Cache
// ============================================================================

/// Cache for :has() pseudo-class match results.
///
/// The :has() pseudo-class requires descendant/sibling traversal which is
/// expensive. Caching results per element+selector avoids redundant work.
pub const HasSelectorCache = struct {
    allocator: Allocator,
    results: std.AutoHashMap(HasCacheKey, HasResult),

    const Self = @This();

    /// Key for has-selector cache (element pointer + selector hash).
    pub const HasCacheKey = struct {
        element_ptr: usize,
        selector_hash: u64,
    };

    /// Cached result for :has() matching.
    pub const HasResult = enum {
        /// Element matches the :has() selector.
        matches,
        /// Element does not match the :has() selector.
        fails,
        /// Entire subtree does not match (can skip children).
        fails_subtree,
    };

    /// Create a new has-selector cache.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .results = std.AutoHashMap(HasCacheKey, HasResult).init(allocator),
        };
    }

    /// Clean up the cache.
    pub fn deinit(self: *Self) void {
        self.results.deinit();
    }

    /// Get cached :has() result.
    pub fn get(self: *const Self, element_ptr: usize, selector_hash: u64) ?HasResult {
        const key = HasCacheKey{
            .element_ptr = element_ptr,
            .selector_hash = selector_hash,
        };
        return self.results.get(key);
    }

    /// Cache a :has() result.
    pub fn put(self: *Self, element_ptr: usize, selector_hash: u64, result: HasResult) void {
        const key = HasCacheKey{
            .element_ptr = element_ptr,
            .selector_hash = selector_hash,
        };
        self.results.put(key, result) catch {};
    }

    /// Clear all cached results.
    pub fn clear(self: *Self) void {
        self.results.clearRetainingCapacity();
    }

    /// Get the number of cached results.
    pub fn count(self: *const Self) usize {
        return self.results.count();
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "SelectorQueryCache - basic operations" {
    const allocator = testing.allocator;
    var cache = SelectorQueryCache.init(allocator);
    defer cache.deinit();

    try testing.expectEqual(@as(usize, 0), cache.count());
    try testing.expect(cache.get("div") == null);
}

test "NthIndexCache - basic operations" {
    const allocator = testing.allocator;
    var cache = NthIndexCache.init(allocator);
    defer cache.deinit();

    // Verify empty cache
    try testing.expect(cache.nth_child.count() == 0);
}

test "HasSelectorCache - basic operations" {
    const allocator = testing.allocator;
    var cache = HasSelectorCache.init(allocator);
    defer cache.deinit();

    try testing.expectEqual(@as(usize, 0), cache.count());
    try testing.expect(cache.get(0x12345678, 0xABCD) == null);

    cache.put(0x12345678, 0xABCD, .matches);
    try testing.expectEqual(@as(usize, 1), cache.count());
    try testing.expectEqual(HasSelectorCache.HasResult.matches, cache.get(0x12345678, 0xABCD).?);

    cache.put(0x12345678, 0xABCD, .fails);
    try testing.expectEqual(HasSelectorCache.HasResult.fails, cache.get(0x12345678, 0xABCD).?);

    cache.clear();
    try testing.expectEqual(@as(usize, 0), cache.count());
}

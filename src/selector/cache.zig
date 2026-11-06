//! CSS Selector Caching
//!
//! Provides caching infrastructure for parsed CSS selectors, inspired by
//! browser implementations (Blink keeps 256 per document, WebKit 512).
//!
//! ## Why Cache?
//!
//! Parsing CSS selectors is expensive. Applications often use the same
//! selectors repeatedly (e.g., in loops, event handlers, or component code).
//! Caching parsed selectors avoids redundant parsing.
//!
//! ## Cache Types
//!
//! - `SelectorQueryCache` - a document's parsed selectors by their text (Blink's bound and eviction)
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

/// A document's parsed selectors, by their text (lane perf2): Blink's
/// SelectorQueryCache (third_party/blink/renderer/core/css/
/// selector_query.cc, SelectorQueryCache::Add), which querySelector,
/// querySelectorAll, matches() and closest() parse through, so a selector a
/// page queries in a loop is parsed once.
///
/// - Keyed by the selector's text alone, as Blink's is: parsing a
///   querySelector argument reads nothing of the document (no namespace
///   prefixes, no nesting), and what matching needs of it - the document
///   being an HTML document, its mode - is read at match time.
/// - Only a valid selector is kept: an invalid one throws each time it is
///   asked for (Blink parses again and throws again).
/// - At most `max_entries` (Blink's kMaximumSelectorQueryCacheSize, 256).
///   Full, it removes the FIRST entry its table iterates before adding
///   (Blink: `entries_.erase(entries_.begin())` - its HashMap's first, an
///   arbitrary entry, not the least recently used one).
/// - Each entry OWNS the text its list was parsed from: a SelectorList's
///   names are slices of its source (docs/lessons/
///   debugging-a-parsed-selector-borrows-its-source-text.md), so the entry
///   parses its own copy, never the caller's string.
/// - Entries are heap blocks: a `*const SelectorList` from `getOrParse` is
///   valid until the next `getOrParse` of a text not kept (which may evict
///   it) or `deinit`. Matching runs no script, so no query starts another
///   while it holds one.
pub const SelectorQueryCache = struct {
    allocator: Allocator,
    /// By the entry's own text (the key slices `Entry.source`).
    // tombstones: removals are evictions, one per insert past the bound, so the table never holds more than max_entries + its tombstones; std rehashes on growth
    entries: std.StringHashMapUnmanaged(*Entry) = .empty,

    /// Blink's kMaximumSelectorQueryCacheSize.
    pub const max_entries: usize = 256;

    pub const Entry = struct {
        /// The selector's text, owned: the key, and what `list` borrows.
        source: []u8,
        list: SelectorList,
    };

    pub fn init(allocator: Allocator) SelectorQueryCache {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *SelectorQueryCache) void {
        var it = self.entries.valueIterator();
        while (it.next()) |entry| self.destroyEntry(entry.*);
        self.entries.deinit(self.allocator);
        self.entries = .empty;
    }

    fn destroyEntry(self: *SelectorQueryCache, entry: *Entry) void {
        entry.list.deinit();
        self.allocator.free(entry.source);
        self.allocator.destroy(entry);
    }

    /// The kept parse of `source`, or `source` parsed now and kept. A parse
    /// error is returned and nothing is kept.
    pub fn getOrParse(self: *SelectorQueryCache, source: []const u8) parser.ParserError!*const SelectorList {
        if (self.entries.get(source)) |entry| return &entry.list;
        const entry = try self.allocator.create(Entry);
        errdefer self.allocator.destroy(entry);
        const owned = try self.allocator.dupe(u8, source);
        errdefer self.allocator.free(owned);
        entry.* = .{ .source = owned, .list = try parser.parseSelectorList(self.allocator, owned) };
        errdefer entry.list.deinit();
        if (self.entries.count() >= max_entries) self.evictFirst();
        try self.entries.putNoClobber(self.allocator, owned, entry);
        return &entry.list;
    }

    /// Blink's eviction: the entry the table lists first.
    fn evictFirst(self: *SelectorQueryCache) void {
        var it = self.entries.iterator();
        const first = it.next() orelse return;
        const entry = first.value_ptr.*;
        self.entries.removeByPtr(first.key_ptr);
        self.destroyEntry(entry);
    }

    /// Whether `source` is kept.
    pub fn contains(self: *const SelectorQueryCache, source: []const u8) bool {
        return self.entries.contains(source);
    }

    /// The number of kept selectors.
    pub fn count(self: *const SelectorQueryCache) usize {
        return self.entries.count();
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

test "SelectorQueryCache parses a text once and keeps only valid selectors" {
    var cache = SelectorQueryCache.init(testing.allocator);
    defer cache.deinit();
    try testing.expectEqual(@as(usize, 0), cache.count());
    const first = try cache.getOrParse("div > .a");
    try testing.expectEqual(first, try cache.getOrParse("div > .a"));
    try testing.expectEqual(@as(usize, 1), cache.count());
    try testing.expectEqual(@as(usize, 1), first.selectors.len);
    // Invalid: an error each time, nothing kept.
    for (0..2) |_| {
        if (cache.getOrParse("a[")) |_| return error.TestUnexpectedResult else |_| {}
    }
    try testing.expectEqual(@as(usize, 1), cache.count());
}

test "SelectorQueryCache keeps its own copy of the text it parsed" {
    var cache = SelectorQueryCache.init(testing.allocator);
    defer cache.deinit();
    const text = try testing.allocator.dupe(u8, "#main .item");
    const list = try cache.getOrParse(text);
    // The caller's string goes (the test allocator overwrites it): the kept
    // list still names #main and .item.
    testing.allocator.free(text);
    const compound = list.selectors[0].compound;
    try testing.expectEqualStrings("item", compound.simple_selectors[0].Class.class_name);
    try testing.expect(cache.contains("#main .item"));
}

test "SelectorQueryCache keeps at most Blink's 256, one evicted per new text past it" {
    var cache = SelectorQueryCache.init(testing.allocator);
    defer cache.deinit();
    var buffer: [32]u8 = undefined;
    for (0..300) |i| _ = try cache.getOrParse(try std.fmt.bufPrint(&buffer, ".c{d}", .{i}));
    try testing.expectEqual(SelectorQueryCache.max_entries, cache.count());
    // The newest is always kept.
    try testing.expect(cache.contains(".c299"));
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

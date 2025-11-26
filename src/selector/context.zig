//! CSS Selector Matching Context
//!
//! Provides the matching context for CSS selector evaluation, including
//! ancestor bloom filter for fast rejection and caching infrastructure.
//!
//! ## Design
//!
//! The MatchingContext is created for each querySelector call and maintains:
//! - Ancestor bloom filter (pushed/popped as we traverse the tree)
//! - Nth-index cache (computed sibling indices)
//! - Has-selector cache (:has() match results)
//! - Scoping root for :scope pseudo-class
//!
//! ## Browser Inspiration
//!
//! - Firefox Stylo: servo/components/selectors/context.rs
//! - WebKit: Source/WebCore/css/SelectorChecker.h

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const AncestorBloomFilter = infra.AncestorBloomFilter;
const AncestorHashes = infra.AncestorHashes;
const hashString = infra.hashString;
const hashStringLower = infra.hashStringLower;
const cache = @import("cache.zig");
const NthIndexCache = cache.NthIndexCache;
const HasSelectorCache = cache.HasSelectorCache;
const quirks = @import("quirks");
const QuirksMode = quirks.QuirksMode;

// ============================================================================
// Matching Context
// ============================================================================

/// Context for CSS selector matching operations.
///
/// Maintains state that's shared across a single querySelector/querySelectorAll
/// call, including the ancestor bloom filter for fast rejection.
pub const MatchingContext = struct {
    allocator: Allocator,

    /// Bloom filter tracking ancestor element hashes.
    /// Used for fast rejection before expensive tree traversal.
    ancestor_filter: AncestorBloomFilter,

    /// Cache for :nth-child() index calculations.
    nth_cache: NthIndexCache,

    /// Cache for :has() match results.
    has_cache: HasSelectorCache,

    /// Scoping root for :scope pseudo-class.
    /// If null, :scope matches the document root.
    scoping_root: ?*const anyopaque = null,

    /// Current depth in the DOM tree (for debugging/limits).
    depth: usize = 0,

    /// Document's quirks mode for selector quirks.
    ///
    /// Per WHATWG Quirks spec §4, in quirks mode the :active/:hover
    /// pseudo-classes only match links when used alone.
    quirks_mode: QuirksMode = .no_quirks,

    const Self = @This();

    /// Maximum tree depth to prevent stack overflow on pathological DOMs.
    const MAX_DEPTH: usize = 512;

    /// Create a new matching context.
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .ancestor_filter = AncestorBloomFilter.init(),
            .nth_cache = NthIndexCache.init(allocator),
            .has_cache = HasSelectorCache.init(allocator),
        };
    }

    /// Create a matching context with a specific quirks mode.
    pub fn initWithQuirksMode(allocator: Allocator, mode: QuirksMode) Self {
        var ctx = init(allocator);
        ctx.quirks_mode = mode;
        return ctx;
    }

    /// Create a matching context with a scoping root for :scope.
    pub fn initWithScope(allocator: Allocator, scoping_root: *const anyopaque) Self {
        var ctx = init(allocator);
        ctx.scoping_root = scoping_root;
        return ctx;
    }

    /// Create a matching context with both scoping root and quirks mode.
    pub fn initWithScopeAndQuirks(allocator: Allocator, scoping_root: *const anyopaque, mode: QuirksMode) Self {
        var ctx = init(allocator);
        ctx.scoping_root = scoping_root;
        ctx.quirks_mode = mode;
        return ctx;
    }

    // ========================================================================
    // Quirks Mode Operations
    // ========================================================================

    /// Check if the :active/:hover quirk should be applied.
    ///
    /// Per WHATWG Quirks spec §4, in quirks mode, compound selectors using
    /// :active or :hover must not match elements that would not also match
    /// :any-link, if the selector has no other selectors.
    pub fn hasActiveHoverQuirk(self: *const Self) bool {
        return self.quirks_mode.hasSelectorQuirks();
    }

    /// Check if in quirks mode.
    pub fn isQuirksMode(self: *const Self) bool {
        return self.quirks_mode.isQuirks();
    }

    /// Clean up the matching context.
    pub fn deinit(self: *Self) void {
        self.nth_cache.deinit();
        self.has_cache.deinit();
    }

    // ========================================================================
    // Ancestor Filter Operations
    // ========================================================================

    /// Push an ancestor element onto the filter.
    ///
    /// Call this when descending into a child element. Adds the element's
    /// ID, classes, and tag name to the bloom filter.
    pub fn pushAncestor(self: *Self, element: anytype) void {
        self.depth += 1;

        // Add tag name (lowercase for case-insensitivity)
        if (@hasField(@TypeOf(element.*), "tag_name")) {
            self.ancestor_filter.add(hashStringLower(element.tag_name));
        }

        // Add ID if present
        if (@hasDecl(@TypeOf(element.*), "getAttribute")) {
            if (element.getAttribute("id")) |id| {
                self.ancestor_filter.add(hashString(id));
            }

            // Add classes if present
            if (element.getAttribute("class")) |class_attr| {
                var it = std.mem.tokenizeScalar(u8, class_attr, ' ');
                while (it.next()) |class_name| {
                    self.ancestor_filter.add(hashString(class_name));
                }
            }
        }
    }

    /// Pop an ancestor element from the filter.
    ///
    /// Call this when ascending back up from a child element. Removes the
    /// element's ID, classes, and tag name from the bloom filter.
    pub fn popAncestor(self: *Self, element: anytype) void {
        if (self.depth > 0) self.depth -= 1;

        // Remove tag name
        if (@hasField(@TypeOf(element.*), "tag_name")) {
            self.ancestor_filter.remove(hashStringLower(element.tag_name));
        }

        // Remove ID if present
        if (@hasDecl(@TypeOf(element.*), "getAttribute")) {
            if (element.getAttribute("id")) |id| {
                self.ancestor_filter.remove(hashString(id));
            }

            // Remove classes if present
            if (element.getAttribute("class")) |class_attr| {
                var it = std.mem.tokenizeScalar(u8, class_attr, ' ');
                while (it.next()) |class_name| {
                    self.ancestor_filter.remove(hashString(class_name));
                }
            }
        }
    }

    /// Check if a selector's ancestor requirements might be satisfied.
    ///
    /// Uses precomputed hashes from the selector to quickly reject
    /// selectors that definitely won't match.
    pub fn mayMatchAncestors(self: *const Self, hashes: *const AncestorHashes) bool {
        return hashes.mayMatch(&self.ancestor_filter);
    }

    // ========================================================================
    // Depth Checking
    // ========================================================================

    /// Check if we've exceeded the maximum tree depth.
    pub fn isDepthExceeded(self: *const Self) bool {
        return self.depth >= MAX_DEPTH;
    }

    // ========================================================================
    // Cache Operations
    // ========================================================================

    /// Clear all caches (call between independent queries if reusing context).
    pub fn clearCaches(self: *Self) void {
        self.nth_cache.clear();
        self.has_cache.clear();
    }

    /// Clear the ancestor filter (call when starting a new traversal).
    pub fn resetAncestorFilter(self: *Self) void {
        self.ancestor_filter.clear();
        self.depth = 0;
    }
};

// ============================================================================
// Match Result (for backtracking optimization)
// ============================================================================

/// Result of a selector match attempt with backtracking hints.
///
/// Browsers use rich match results to optimize failure recovery.
/// Instead of just "matched" or "not matched", we indicate where
/// matching can be retried.
pub const MatchResult = enum {
    /// Selector matched successfully.
    matched,

    /// Failed, but might match a later sibling (for + and ~ combinators).
    not_matched_restart_later_sibling,

    /// Failed, but might match a different descendant (for space combinator).
    not_matched_restart_descendant,

    /// Failed completely, no point retrying in this subtree.
    not_matched_globally,

    /// Convert to boolean for simple matching.
    pub fn isMatch(self: MatchResult) bool {
        return self == .matched;
    }

    /// Check if we should continue trying siblings.
    pub fn shouldTrySiblings(self: MatchResult) bool {
        return self == .not_matched_restart_later_sibling;
    }

    /// Check if we should continue trying descendants.
    pub fn shouldTryDescendants(self: MatchResult) bool {
        return self == .not_matched_restart_descendant or
            self == .not_matched_restart_later_sibling;
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "MatchingContext - init and deinit" {
    const allocator = testing.allocator;
    var ctx = MatchingContext.init(allocator);
    defer ctx.deinit();

    try testing.expect(ctx.ancestor_filter.isEmpty());
    try testing.expectEqual(@as(usize, 0), ctx.depth);
    try testing.expect(ctx.scoping_root == null);
}

test "MatchingContext - depth tracking" {
    const allocator = testing.allocator;
    var ctx = MatchingContext.init(allocator);
    defer ctx.deinit();

    // Mock element type for testing
    const MockElement = struct {
        tag_name: []const u8,

        pub fn getAttribute(_: *const @This(), _: []const u8) ?[]const u8 {
            return null;
        }
    };

    var elem = MockElement{ .tag_name = "div" };

    ctx.pushAncestor(&elem);
    try testing.expectEqual(@as(usize, 1), ctx.depth);

    ctx.pushAncestor(&elem);
    try testing.expectEqual(@as(usize, 2), ctx.depth);

    ctx.popAncestor(&elem);
    try testing.expectEqual(@as(usize, 1), ctx.depth);

    ctx.popAncestor(&elem);
    try testing.expectEqual(@as(usize, 0), ctx.depth);
}

test "MatchingContext - ancestor filter" {
    const allocator = testing.allocator;
    var ctx = MatchingContext.init(allocator);
    defer ctx.deinit();

    // Mock element with tag name
    const MockElement = struct {
        tag_name: []const u8,

        pub fn getAttribute(_: *const @This(), _: []const u8) ?[]const u8 {
            return null;
        }
    };

    var div = MockElement{ .tag_name = "div" };
    var span = MockElement{ .tag_name = "span" };

    // Push div
    ctx.pushAncestor(&div);
    try testing.expect(ctx.ancestor_filter.mightContain(hashStringLower("div")));
    try testing.expect(!ctx.ancestor_filter.mightContain(hashStringLower("span")));

    // Push span
    ctx.pushAncestor(&span);
    try testing.expect(ctx.ancestor_filter.mightContain(hashStringLower("div")));
    try testing.expect(ctx.ancestor_filter.mightContain(hashStringLower("span")));

    // Pop span
    ctx.popAncestor(&span);
    try testing.expect(ctx.ancestor_filter.mightContain(hashStringLower("div")));
    try testing.expect(!ctx.ancestor_filter.mightContain(hashStringLower("span")));
}

test "MatchResult - boolean conversion" {
    try testing.expect(MatchResult.matched.isMatch());
    try testing.expect(!MatchResult.not_matched_globally.isMatch());
    try testing.expect(!MatchResult.not_matched_restart_later_sibling.isMatch());
}

test "MatchResult - retry hints" {
    try testing.expect(!MatchResult.matched.shouldTrySiblings());
    try testing.expect(MatchResult.not_matched_restart_later_sibling.shouldTrySiblings());
    try testing.expect(!MatchResult.not_matched_globally.shouldTrySiblings());

    try testing.expect(!MatchResult.matched.shouldTryDescendants());
    try testing.expect(MatchResult.not_matched_restart_later_sibling.shouldTryDescendants());
    try testing.expect(MatchResult.not_matched_restart_descendant.shouldTryDescendants());
    try testing.expect(!MatchResult.not_matched_globally.shouldTryDescendants());
}

test "MatchingContext - quirks mode" {
    const allocator = testing.allocator;

    // Default should be no-quirks mode
    var ctx_default = MatchingContext.init(allocator);
    defer ctx_default.deinit();
    try testing.expect(!ctx_default.isQuirksMode());
    try testing.expect(!ctx_default.hasActiveHoverQuirk());

    // Quirks mode
    var ctx_quirks = MatchingContext.initWithQuirksMode(allocator, .quirks);
    defer ctx_quirks.deinit();
    try testing.expect(ctx_quirks.isQuirksMode());
    try testing.expect(ctx_quirks.hasActiveHoverQuirk());

    // Limited quirks mode (no selector quirks)
    var ctx_limited = MatchingContext.initWithQuirksMode(allocator, .limited_quirks);
    defer ctx_limited.deinit();
    try testing.expect(!ctx_limited.isQuirksMode());
    try testing.expect(!ctx_limited.hasActiveHoverQuirk());
}

//! Fast Path Optimizations for CSS Selectors
//!
//! Provides optimized query strategies for common selector patterns.
//! Browsers use these fast paths to avoid full tree traversal when possible.
//!
//! ## Fast Paths
//!
//! - **ID selector**: Use getElementById() for O(1) lookup
//! - **Class selector**: Use getElementsByClassName()-like iteration
//! - **Tag name selector**: Use getElementsByTagName()-like iteration
//!
//! ## References
//!
//! - WebKit SelectorQuery.cpp: Multiple fast path implementations
//! - Firefox Stylo: Rule hashing by ID/class/tag

const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");
const SelectorList = parser.SelectorList;
const ComplexSelector = parser.ComplexSelector;
const CompoundSelector = parser.CompoundSelector;
const SimpleSelector = parser.SimpleSelector;

// ============================================================================
// Selector Analysis
// ============================================================================

/// Type of fast path available for a selector.
pub const FastPathType = enum {
    /// No fast path available - use full matching
    none,

    /// Selector has a single ID - use getElementById
    single_id,

    /// Selector has a single class - use class-based iteration
    single_class,

    /// Selector has a single tag name - use tag-based iteration
    single_tag,

    /// Multiple selectors or complex pattern - use full matching
    complex,
};

/// Analysis result for a selector, including fast path info.
pub const SelectorAnalysis = struct {
    /// Type of fast path to use
    fast_path: FastPathType,

    /// For ID fast path: the ID to look up
    id: ?[]const u8 = null,

    /// For class fast path: the class name to filter by
    class_name: ?[]const u8 = null,

    /// For tag fast path: the tag name to filter by
    tag_name: ?[]const u8 = null,

    /// Whether there are additional selectors to verify after fast path
    needs_verification: bool = false,
};

/// Analyze a selector list to determine the best query strategy.
pub fn analyzeSelector(selector_list: *const SelectorList) SelectorAnalysis {
    // Multiple selectors in list - no simple fast path
    if (selector_list.selectors.len != 1) {
        return .{ .fast_path = .complex };
    }

    const complex = &selector_list.selectors[0];

    // Relative selectors need special handling
    if (complex.is_relative) {
        return .{ .fast_path = .none };
    }

    // Analyze the subject compound (rightmost)
    return analyzeCompound(&complex.compound, complex.combinators.len > 0);
}

/// Analyze a single compound selector for fast path opportunities.
fn analyzeCompound(compound: *const CompoundSelector, has_ancestors: bool) SelectorAnalysis {
    var result = SelectorAnalysis{ .fast_path = .none };
    var has_id = false;
    var has_class = false;
    var has_tag = false;
    var simple_count: usize = 0;

    for (compound.simple_selectors) |*simple| {
        simple_count += 1;
        switch (simple.*) {
            .Id => |id_sel| {
                has_id = true;
                result.id = id_sel.id;
            },
            .Class => |class_sel| {
                has_class = true;
                result.class_name = class_sel.class_name;
            },
            .Type => |type_sel| {
                has_tag = true;
                result.tag_name = type_sel.tag_name;
            },
            .Universal => {
                // Universal doesn't narrow search
            },
            else => {
                // Attribute, pseudo-class, pseudo-element - no fast path
                return .{ .fast_path = .none };
            },
        }
    }

    // Determine best fast path
    if (has_id) {
        result.fast_path = .single_id;
        // Need verification if there are other simple selectors or ancestors
        result.needs_verification = simple_count > 1 or has_ancestors;
    } else if (has_class and !has_ancestors and simple_count == 1) {
        result.fast_path = .single_class;
    } else if (has_tag and !has_ancestors and simple_count == 1) {
        result.fast_path = .single_tag;
    } else {
        result.fast_path = .none;
    }

    return result;
}

/// Extract the ID from a selector if it has one (for getElementById optimization).
pub fn extractIdFromSelector(selector_list: *const SelectorList) ?[]const u8 {
    if (selector_list.selectors.len != 1) return null;

    const complex = &selector_list.selectors[0];
    return extractIdFromCompound(&complex.compound);
}

/// Extract ID from a compound selector.
fn extractIdFromCompound(compound: *const CompoundSelector) ?[]const u8 {
    for (compound.simple_selectors) |*simple| {
        if (simple.* == .Id) {
            return simple.Id.id;
        }
    }
    return null;
}

/// Check if a selector is a "simple" selector (single compound, no combinators).
pub fn isSimpleSelector(selector_list: *const SelectorList) bool {
    if (selector_list.selectors.len != 1) return false;
    const complex = &selector_list.selectors[0];
    return complex.combinators.len == 0 and !complex.is_relative;
}

/// Check if a selector has only an ID (e.g., "#myId" with no other selectors).
pub fn isIdOnlySelector(selector_list: *const SelectorList) bool {
    if (!isSimpleSelector(selector_list)) return false;

    const compound = &selector_list.selectors[0].compound;
    return compound.simple_selectors.len == 1 and
        compound.simple_selectors[0] == .Id;
}

/// Check if a selector has only a class (e.g., ".myClass" with no other selectors).
pub fn isClassOnlySelector(selector_list: *const SelectorList) bool {
    if (!isSimpleSelector(selector_list)) return false;

    const compound = &selector_list.selectors[0].compound;
    return compound.simple_selectors.len == 1 and
        compound.simple_selectors[0] == .Class;
}

/// Check if a selector has only a tag name (e.g., "div" with no other selectors).
pub fn isTagOnlySelector(selector_list: *const SelectorList) bool {
    if (!isSimpleSelector(selector_list)) return false;

    const compound = &selector_list.selectors[0].compound;
    return compound.simple_selectors.len == 1 and
        compound.simple_selectors[0] == .Type;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = parser.Parser;

fn parseSelector(allocator: Allocator, input: []const u8) !SelectorList {
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    return try p.parse();
}

test "analyzeSelector - ID selector" {
    const allocator = testing.allocator;

    var selector = try parseSelector(allocator, "#myId");
    defer selector.deinit();

    const analysis = analyzeSelector(&selector);
    try testing.expectEqual(FastPathType.single_id, analysis.fast_path);
    try testing.expectEqualStrings("myId", analysis.id.?);
    try testing.expect(!analysis.needs_verification);
}

test "analyzeSelector - ID with tag" {
    const allocator = testing.allocator;

    var selector = try parseSelector(allocator, "div#myId");
    defer selector.deinit();

    const analysis = analyzeSelector(&selector);
    try testing.expectEqual(FastPathType.single_id, analysis.fast_path);
    try testing.expectEqualStrings("myId", analysis.id.?);
    try testing.expect(analysis.needs_verification); // Need to verify tag
}

test "analyzeSelector - ID with ancestor" {
    const allocator = testing.allocator;

    var selector = try parseSelector(allocator, "div #myId");
    defer selector.deinit();

    const analysis = analyzeSelector(&selector);
    try testing.expectEqual(FastPathType.single_id, analysis.fast_path);
    try testing.expectEqualStrings("myId", analysis.id.?);
    try testing.expect(analysis.needs_verification); // Need to verify ancestor
}

test "analyzeSelector - class only" {
    const allocator = testing.allocator;

    var selector = try parseSelector(allocator, ".myClass");
    defer selector.deinit();

    const analysis = analyzeSelector(&selector);
    try testing.expectEqual(FastPathType.single_class, analysis.fast_path);
    try testing.expectEqualStrings("myClass", analysis.class_name.?);
}

test "analyzeSelector - tag only" {
    const allocator = testing.allocator;

    var selector = try parseSelector(allocator, "div");
    defer selector.deinit();

    const analysis = analyzeSelector(&selector);
    try testing.expectEqual(FastPathType.single_tag, analysis.fast_path);
    try testing.expectEqualStrings("div", analysis.tag_name.?);
}

test "analyzeSelector - complex (attribute)" {
    const allocator = testing.allocator;

    var selector = try parseSelector(allocator, "div[data-id]");
    defer selector.deinit();

    const analysis = analyzeSelector(&selector);
    try testing.expectEqual(FastPathType.none, analysis.fast_path);
}

test "isIdOnlySelector" {
    const allocator = testing.allocator;

    var id_only = try parseSelector(allocator, "#myId");
    defer id_only.deinit();
    try testing.expect(isIdOnlySelector(&id_only));

    var id_with_tag = try parseSelector(allocator, "div#myId");
    defer id_with_tag.deinit();
    try testing.expect(!isIdOnlySelector(&id_with_tag));
}

test "extractIdFromSelector" {
    const allocator = testing.allocator;

    var selector = try parseSelector(allocator, "div#myId.active");
    defer selector.deinit();

    const id = extractIdFromSelector(&selector);
    try testing.expectEqualStrings("myId", id.?);
}

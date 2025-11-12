//! CSS Selector Matcher (Selectors Level 4)
//!
//! This module implements selector matching for CSS Selectors Level 4 as used by
//! WHATWG DOM querySelector/querySelectorAll. The matcher evaluates parsed selector
//! AST against DOM elements, determining if elements match selector criteria.
//!
//! ## WHATWG Specification
//!
//! Relevant specification sections:
//! - **§1.3 Selectors**: https://dom.spec.whatwg.org/#selectors
//! - **§4.2.6 Mixin ParentNode**: https://dom.spec.whatwg.org/#parentnode (querySelector)
//! - **§4.9 Interface Element**: https://dom.spec.whatwg.org/#interface-element (matches)
//!
//! ## CSS Selectors Specification
//!
//! - **Selectors Level 4**: https://drafts.csswg.org/selectors-4/
//! - **§3 Selector Syntax**: https://drafts.csswg.org/selectors-4/#selector-syntax
//! - **§17 Pseudo-classes**: https://drafts.csswg.org/selectors-4/#pseudo-classes
//!
//! ## Core Features
//!
//! ### Match Element Against Selector
//! Test if an element matches a parsed selector:
//! ```zig
//! const allocator = std.heap.page_allocator;
//! var elem = Element.init(allocator, "div");
//! defer elem.deinit();
//!
//! // Parse selector
//! const tokenizer = Tokenizer.init("div.container");
//! var parser = Parser.init(allocator, tokenizer);
//! defer parser.deinit();
//! const selector_list = try parser.parse();
//!
//! // Match element
//! const matcher = Matcher.init(allocator);
//! const matches = try matcher.matches(&elem, &selector_list);
//! // matches == true
//! ```
//!
//! ## Matcher Architecture
//!
//! ### Match Evaluation Flow
//! ```
//! matches(elem, SelectorList)
//!   └─> matchesComplexSelector(elem, ComplexSelector)
//!        └─> matchesCompoundSelector(elem, CompoundSelector)
//!             └─> matchesSimpleSelector(elem, SimpleSelector)
//!                  ├─> matchesType()
//!                  ├─> matchesClass()
//!                  ├─> matchesId()
//!                  ├─> matchesAttribute()
//!                  └─> matchesPseudoClass()
//! ```
//!
//! ### Right-to-Left Matching
//! Combinators evaluated right-to-left (standard CSS matching):
//! ```
//! Selector: "article > header h1.title"
//!
//! Step 1: elem matches "h1.title"? (rightmost)
//! Step 2: elem's ancestor matches "header"? (descendant combinator)
//! Step 3: ancestor's parent matches "article"? (child combinator)
//! ```
//!
//! Right-to-left matching enables early exit:
//! - If rightmost selector fails, no need to check ancestors
//! - Efficient for large selector lists
//! - Standard browser implementation strategy

const std = @import("std");
const Allocator = std.mem.Allocator;
const dom = @import("dom");
const Element = dom.ElementWithBase;
const NodeBase = dom.NodeBase;
const parser = @import("parser.zig");
const SelectorList = parser.SelectorList;
const ComplexSelector = parser.ComplexSelector;
const CompoundSelector = parser.CompoundSelector;
const SimpleSelector = parser.SimpleSelector;
const Combinator = parser.Combinator;
const AttributeSelector = parser.AttributeSelector;
const AttributeMatcher = parser.AttributeMatcher;
const PseudoClassSelector = parser.PseudoClassSelector;
const PseudoClassKind = parser.PseudoClassKind;
const NthPattern = parser.NthPattern;

// ============================================================================
// Matcher Errors
// ============================================================================

pub const MatcherError = error{
    OutOfMemory,
};

// ============================================================================
// Matcher
// ============================================================================

pub const Matcher = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Matcher {
        return .{ .allocator = allocator };
    }

    /// Check if element matches selector list (OR semantics)
    pub fn matches(self: *const Matcher, element: *Element, selector_list: *const SelectorList) MatcherError!bool {
        // Selector list is comma-separated (OR)
        // Element matches if it matches ANY selector in list
        for (selector_list.selectors) |*selector| {
            if (try self.matchesComplexSelector(element, selector)) {
                return true;
            }
        }
        return false;
    }

    /// Check if element matches complex selector (combinator chain)
    fn matchesComplexSelector(self: *const Matcher, element: *Element, complex: *const ComplexSelector) MatcherError!bool {
        // Right-to-left matching (standard CSS strategy)
        // Parser gives us: "div > p" as compound="div", combinators=[{Child, "p"}]
        // But we need to match from right: element must match "p", parent must match "div"

        // No combinators - element must match the only compound
        if (complex.combinators.len == 0) {
            return try self.matchesCompoundSelector(element, &complex.compound);
        }

        // With combinators: element must match rightmost compound (last in array)
        const rightmost = &complex.combinators[complex.combinators.len - 1].compound;
        if (!try self.matchesCompoundSelector(element, rightmost)) {
            return false;
        }

        // Match combinators right-to-left (iterate backwards)
        var current_element = element;
        var i: usize = complex.combinators.len;
        while (i > 0) {
            i -= 1;
            const pair = &complex.combinators[i];
            const matched = try self.matchesCombinator(current_element, pair.combinator, if (i == 0) &complex.compound else &complex.combinators[i - 1].compound);
            if (matched == null) return false;
            current_element = matched.?;
        }

        return true;
    }

    /// Match combinator between element and target compound selector
    /// Returns the element that matched the compound selector if successful
    fn matchesCombinator(
        self: *const Matcher,
        element: *Element,
        combinator: Combinator,
        compound: *const CompoundSelector,
    ) MatcherError!?*Element {
        return switch (combinator) {
            .Child => try self.matchesChildCombinator(element, compound),
            .Descendant => try self.matchesDescendantCombinator(element, compound),
            .NextSibling => try self.matchesNextSiblingCombinator(element, compound),
            .SubsequentSibling => try self.matchesSubsequentSiblingCombinator(element, compound),
        };
    }

    /// Match child combinator (>)
    fn matchesChildCombinator(
        self: *const Matcher,
        element: *Element,
        compound: *const CompoundSelector,
    ) MatcherError!?*Element {
        // Element's parent must match compound selector
        const parent_node = element.base.parent_node orelse return null;
        if (parent_node.node_type != NodeBase.ELEMENT_NODE) return null;

        const parent_element: *Element = @ptrCast(parent_node);
        if (try self.matchesCompoundSelector(parent_element, compound)) {
            return parent_element;
        }
        return null;
    }

    /// Match descendant combinator (space)
    fn matchesDescendantCombinator(
        self: *const Matcher,
        element: *Element,
        compound: *const CompoundSelector,
    ) MatcherError!?*Element {
        // Any ancestor must match compound selector
        var current = element.base.parent_node;
        while (current) |ancestor_node| {
            if (ancestor_node.node_type == NodeBase.ELEMENT_NODE) {
                const ancestor_element: *Element = @ptrCast(ancestor_node);
                if (try self.matchesCompoundSelector(ancestor_element, compound)) {
                    return ancestor_element;
                }
            }
            current = ancestor_node.parent_node;
        }
        return null;
    }

    /// Match next sibling combinator (+)
    fn matchesNextSiblingCombinator(
        self: *const Matcher,
        element: *Element,
        compound: *const CompoundSelector,
    ) MatcherError!?*Element {
        // Previous sibling must match compound selector
        const prev_node = getPreviousSibling(element) orelse return null;
        if (prev_node.node_type != NodeBase.ELEMENT_NODE) return null;

        const prev_element: *Element = @ptrCast(prev_node);
        if (try self.matchesCompoundSelector(prev_element, compound)) {
            return prev_element;
        }
        return null;
    }

    /// Match subsequent sibling combinator (~)
    fn matchesSubsequentSiblingCombinator(
        self: *const Matcher,
        element: *Element,
        compound: *const CompoundSelector,
    ) MatcherError!?*Element {
        // Any previous sibling must match compound selector
        var current = getPreviousSibling(element);
        while (current) |sibling_node| {
            if (sibling_node.node_type == NodeBase.ELEMENT_NODE) {
                const sibling_element: *Element = @ptrCast(sibling_node);
                if (try self.matchesCompoundSelector(sibling_element, compound)) {
                    return sibling_element;
                }
            }
            current = getPreviousSibling(@ptrCast(sibling_node));
        }
        return null;
    }

    /// Check if element matches compound selector (AND semantics)
    fn matchesCompoundSelector(self: *const Matcher, element: *Element, compound: *const CompoundSelector) MatcherError!bool {
        // Compound selector is multiple simple selectors (AND)
        // Element matches if it matches ALL simple selectors
        for (compound.simple_selectors) |*simple| {
            if (!try self.matchesSimpleSelector(element, simple)) {
                return false;
            }
        }
        return true;
    }

    /// Check if element matches simple selector
    fn matchesSimpleSelector(self: *const Matcher, element: *Element, simple: *const SimpleSelector) MatcherError!bool {
        return switch (simple.*) {
            .Universal => true,
            .Type => |type_sel| self.matchesType(element, type_sel.tag_name),
            .Class => |class_sel| self.matchesClass(element, class_sel.class_name),
            .Id => |id_sel| self.matchesId(element, id_sel.id),
            .Attribute => |*attr_sel| self.matchesAttribute(element, attr_sel),
            .PseudoClass => |*pseudo_sel| try self.matchesPseudoClass(element, pseudo_sel),
            .PseudoElement => false, // Pseudo-elements don't match elements in querySelector
        };
    }

    /// Match type selector
    fn matchesType(self: *const Matcher, element: *Element, tag_name: []const u8) bool {
        _ = self;
        return std.mem.eql(u8, element.tag_name, tag_name);
    }

    /// Match class selector
    fn matchesClass(self: *const Matcher, element: *Element, class_name: []const u8) bool {
        _ = self;
        // TODO: Add bloom filter optimization when available on ElementWithBase
        const class_attr = element.getAttribute("class") orelse return false;
        return hasClass(class_attr, class_name);
    }

    /// Match ID selector
    fn matchesId(self: *const Matcher, element: *Element, id: []const u8) bool {
        _ = self;
        const id_attr = element.getAttribute("id") orelse return false;
        return std.mem.eql(u8, id_attr, id);
    }

    /// Match attribute selector
    fn matchesAttribute(self: *const Matcher, element: *Element, attr_sel: *const AttributeSelector) bool {
        _ = self;
        const value = element.getAttribute(attr_sel.name) orelse {
            // Attribute not present
            return false;
        };

        return switch (attr_sel.matcher) {
            .Presence => true,
            .Exact => |m| matchAttributeExact(value, m.value, attr_sel.case_sensitive),
            .Prefix => |m| matchAttributePrefix(value, m.value, attr_sel.case_sensitive),
            .Suffix => |m| matchAttributeSuffix(value, m.value, attr_sel.case_sensitive),
            .Substring => |m| matchAttributeSubstring(value, m.value, attr_sel.case_sensitive),
            .Includes => |m| matchAttributeIncludes(value, m.value, attr_sel.case_sensitive),
            .DashMatch => |m| matchAttributeDashMatch(value, m.value, attr_sel.case_sensitive),
        };
    }

    /// Match pseudo-class selector
    fn matchesPseudoClass(self: *const Matcher, element: *Element, pseudo: *const PseudoClassSelector) MatcherError!bool {
        return switch (pseudo.kind) {
            .FirstChild => matchesFirstChild(element),
            .LastChild => matchesLastChild(element),
            .OnlyChild => matchesOnlyChild(element),
            .FirstOfType => matchesFirstOfType(element),
            .LastOfType => matchesLastOfType(element),
            .OnlyOfType => matchesOnlyOfType(element),
            .Empty => matchesEmpty(element),
            .Root => matchesRoot(element),
            .NthChild => |pattern| matchesNthChild(element, pattern),
            .NthLastChild => |pattern| matchesNthLastChild(element, pattern),
            .NthOfType => |pattern| matchesNthOfType(element, pattern),
            .NthLastOfType => |pattern| matchesNthLastOfType(element, pattern),
            .Not => |selector_list| !try self.matches(element, selector_list),
            .Is, .Where => |selector_list| try self.matches(element, selector_list),
            .Has => |selector_list| try self.matchesHas(element, selector_list),
            // User action pseudo-classes - not supported in querySelector
            // (these require runtime state tracking)
            .AnyLink, .Link, .Visited, .Hover, .Active, .Focus, .FocusVisible, .FocusWithin => false,
            // Input pseudo-classes - not supported without HTML library
            .Enabled, .Disabled, .ReadOnly, .ReadWrite, .Checked => false,
        };
    }

    /// Match :has() pseudo-class (element has descendant matching selector)
    fn matchesHas(self: *const Matcher, element: *Element, selector_list: *const SelectorList) MatcherError!bool {
        // Check if any descendant matches selector list
        for (0..element.base.child_nodes.size()) |i| {
            const child_node = element.base.child_nodes.get(i) orelse continue;
            if (child_node.node_type == NodeBase.ELEMENT_NODE) {
                const child_element: *Element = @ptrCast(child_node);
                // Check if child matches
                if (try self.matches(child_element, selector_list)) {
                    return true;
                }
                // Recursively check child's descendants
                if (try self.matchesHas(child_element, selector_list)) {
                    return true;
                }
            }
        }
        return false;
    }
};

// ============================================================================
// Helper Functions - Tree Navigation
// ============================================================================

/// Get next sibling of an element
fn getNextSibling(element: *const Element) ?*NodeBase {
    const parent = element.base.parent_node orelse return null;

    // Find element's index in parent's children
    for (0..parent.child_nodes.size()) |i| {
        const child = parent.child_nodes.get(i) orelse continue;
        if (child == &element.base) {
            // Found element, return next sibling if exists
            if (i + 1 < parent.child_nodes.size()) {
                return parent.child_nodes.get(i + 1);
            }
            return null;
        }
    }

    return null; // Element not found in parent (should not happen)
}

/// Get previous sibling of an element
fn getPreviousSibling(element: *const Element) ?*NodeBase {
    const parent = element.base.parent_node orelse return null;

    // Find element's index in parent's children
    for (0..parent.child_nodes.size()) |i| {
        const child = parent.child_nodes.get(i) orelse continue;
        if (child == &element.base) {
            // Found element, return previous sibling if exists
            if (i > 0) {
                return parent.child_nodes.get(i - 1);
            }
            return null;
        }
    }

    return null; // Element not found in parent (should not happen)
}

// ============================================================================
// Helper Functions - String Matching
// ============================================================================

/// Check if class attribute contains specific class name
fn hasClass(class_attr: []const u8, class_name: []const u8) bool {
    // Class attribute is space-separated list
    var it = std.mem.tokenizeScalar(u8, class_attr, ' ');
    while (it.next()) |class| {
        if (std.mem.eql(u8, class, class_name)) {
            return true;
        }
    }
    return false;
}

/// Attribute matcher: exact match
fn matchAttributeExact(value: []const u8, target: []const u8, case_sensitive: bool) bool {
    if (case_sensitive) {
        return std.mem.eql(u8, value, target);
    } else {
        return std.ascii.eqlIgnoreCase(value, target);
    }
}

/// Attribute matcher: prefix match
fn matchAttributePrefix(value: []const u8, target: []const u8, case_sensitive: bool) bool {
    if (value.len < target.len) return false;
    if (case_sensitive) {
        return std.mem.startsWith(u8, value, target);
    } else {
        return std.ascii.startsWithIgnoreCase(value, target);
    }
}

/// Attribute matcher: suffix match
fn matchAttributeSuffix(value: []const u8, target: []const u8, case_sensitive: bool) bool {
    if (value.len < target.len) return false;
    if (case_sensitive) {
        return std.mem.endsWith(u8, value, target);
    } else {
        return std.ascii.endsWithIgnoreCase(value, target);
    }
}

/// Attribute matcher: substring match
fn matchAttributeSubstring(value: []const u8, target: []const u8, case_sensitive: bool) bool {
    if (target.len == 0) return false;
    if (case_sensitive) {
        return std.mem.indexOf(u8, value, target) != null;
    } else {
        // Case-insensitive substring search
        // Simple implementation - could be optimized
        if (value.len < target.len) return false;
        var i: usize = 0;
        while (i <= value.len - target.len) : (i += 1) {
            if (std.ascii.eqlIgnoreCase(value[i .. i + target.len], target)) {
                return true;
            }
        }
        return false;
    }
}

/// Attribute matcher: includes match (whitespace-separated word)
fn matchAttributeIncludes(value: []const u8, target: []const u8, case_sensitive: bool) bool {
    var it = std.mem.tokenizeScalar(u8, value, ' ');
    while (it.next()) |word| {
        if (case_sensitive) {
            if (std.mem.eql(u8, word, target)) return true;
        } else {
            if (std.ascii.eqlIgnoreCase(word, target)) return true;
        }
    }
    return false;
}

/// Attribute matcher: dash match (language code matching)
fn matchAttributeDashMatch(value: []const u8, target: []const u8, case_sensitive: bool) bool {
    // Matches if value is exactly target or starts with target followed by "-"
    if (case_sensitive) {
        if (std.mem.eql(u8, value, target)) return true;
        if (value.len > target.len and value[target.len] == '-') {
            return std.mem.eql(u8, value[0..target.len], target);
        }
    } else {
        if (std.ascii.eqlIgnoreCase(value, target)) return true;
        if (value.len > target.len and value[target.len] == '-') {
            return std.ascii.eqlIgnoreCase(value[0..target.len], target);
        }
    }
    return false;
}

// ============================================================================
// Structural Pseudo-Class Helpers
// ============================================================================

/// Match :first-child
fn matchesFirstChild(element: *Element) bool {
    const parent = element.base.parent_node orelse return false;
    // First child must be first element node
    for (0..parent.child_nodes.size()) |i| {
        const child = parent.child_nodes.get(i) orelse continue;
        if (child.node_type == NodeBase.ELEMENT_NODE) {
            return child == &element.base;
        }
    }
    return false;
}

/// Match :last-child
fn matchesLastChild(element: *Element) bool {
    const parent = element.base.parent_node orelse return false;
    // Last child must be last element node
    var i = parent.child_nodes.size();
    while (i > 0) {
        i -= 1;
        const child = parent.child_nodes.get(i) orelse continue;
        if (child.node_type == NodeBase.ELEMENT_NODE) {
            return child == &element.base;
        }
    }
    return false;
}

/// Match :only-child
fn matchesOnlyChild(element: *Element) bool {
    const parent = element.base.parent_node orelse return false;
    // Count element children
    var count: usize = 0;
    for (0..parent.child_nodes.size()) |i| {
        const child = parent.child_nodes.get(i) orelse continue;
        if (child.node_type == NodeBase.ELEMENT_NODE) {
            count += 1;
            if (count > 1) return false;
        }
    }
    return count == 1;
}

/// Match :first-of-type
fn matchesFirstOfType(element: *Element) bool {
    // Find first element sibling with same tag name
    const parent = element.base.parent_node orelse return false;
    for (0..parent.child_nodes.size()) |i| {
        const child = parent.child_nodes.get(i) orelse continue;
        if (child.node_type == NodeBase.ELEMENT_NODE) {
            const elem: *Element = @ptrCast(child);
            if (std.mem.eql(u8, elem.tag_name, element.tag_name)) {
                return elem == element;
            }
        }
    }
    return false;
}

/// Match :last-of-type
fn matchesLastOfType(element: *Element) bool {
    // Find last element sibling with same tag name
    const parent = element.base.parent_node orelse return false;
    var i = parent.child_nodes.size();
    while (i > 0) {
        i -= 1;
        const child = parent.child_nodes.get(i) orelse continue;
        if (child.node_type == NodeBase.ELEMENT_NODE) {
            const elem: *Element = @ptrCast(child);
            if (std.mem.eql(u8, elem.tag_name, element.tag_name)) {
                return elem == element;
            }
        }
    }
    return false;
}

/// Match :only-of-type
fn matchesOnlyOfType(element: *Element) bool {
    // Count elements with same tag name
    const parent = element.base.parent_node orelse return false;
    var count: usize = 0;
    for (0..parent.child_nodes.size()) |i| {
        const child = parent.child_nodes.get(i) orelse continue;
        if (child.node_type == NodeBase.ELEMENT_NODE) {
            const elem: *Element = @ptrCast(child);
            if (std.mem.eql(u8, elem.tag_name, element.tag_name)) {
                count += 1;
                if (count > 1) return false;
            }
        }
    }
    return count == 1;
}

/// Match :empty
fn matchesEmpty(element: *Element) bool {
    // Element is empty if it has no child nodes
    return element.base.child_nodes.size() == 0;
}

/// Match :root
fn matchesRoot(element: *Element) bool {
    // Root element has no parent or parent is document
    const parent = element.base.parent_node orelse return true;
    return parent.node_type == NodeBase.DOCUMENT_NODE;
}

/// Match :nth-child(an+b)
fn matchesNthChild(element: *Element, pattern: NthPattern) bool {
    const index = getChildIndex(element) orelse return false;
    return matchesNthPattern(index, pattern);
}

/// Match :nth-last-child(an+b)
fn matchesNthLastChild(element: *Element, pattern: NthPattern) bool {
    const index = getChildIndexFromLast(element) orelse return false;
    return matchesNthPattern(index, pattern);
}

/// Match :nth-of-type(an+b)
fn matchesNthOfType(element: *Element, pattern: NthPattern) bool {
    const index = getChildIndexOfType(element) orelse return false;
    return matchesNthPattern(index, pattern);
}

/// Match :nth-last-of-type(an+b)
fn matchesNthLastOfType(element: *Element, pattern: NthPattern) bool {
    const index = getChildIndexOfTypeFromLast(element) orelse return false;
    return matchesNthPattern(index, pattern);
}

/// Get element's index among all child elements (1-based)
fn getChildIndex(element: *Element) ?usize {
    const parent = element.base.parent_node orelse return null;
    var index: usize = 1;
    for (0..parent.child_nodes.size()) |i| {
        const child = parent.child_nodes.get(i) orelse continue;
        if (child == &element.base) return index;
        if (child.node_type == NodeBase.ELEMENT_NODE) {
            index += 1;
        }
    }
    return null;
}

/// Get element's index from last among all child elements (1-based)
fn getChildIndexFromLast(element: *Element) ?usize {
    const parent = element.base.parent_node orelse return null;
    var index: usize = 1;
    var i = parent.child_nodes.size();
    while (i > 0) {
        i -= 1;
        const child = parent.child_nodes.get(i) orelse continue;
        if (child == &element.base) return index;
        if (child.node_type == NodeBase.ELEMENT_NODE) {
            index += 1;
        }
    }
    return null;
}

/// Get element's index among siblings of same type (1-based)
fn getChildIndexOfType(element: *Element) ?usize {
    const parent = element.base.parent_node orelse return null;
    var index: usize = 1;
    for (0..parent.child_nodes.size()) |i| {
        const child = parent.child_nodes.get(i) orelse continue;
        if (child == &element.base) return index;
        if (child.node_type == NodeBase.ELEMENT_NODE) {
            const elem: *Element = @ptrCast(child);
            if (std.mem.eql(u8, elem.tag_name, element.tag_name)) {
                index += 1;
            }
        }
    }
    return null;
}

/// Get element's index from last among siblings of same type (1-based)
fn getChildIndexOfTypeFromLast(element: *Element) ?usize {
    const parent = element.base.parent_node orelse return null;
    var index: usize = 1;
    var i = parent.child_nodes.size();
    while (i > 0) {
        i -= 1;
        const child = parent.child_nodes.get(i) orelse continue;
        if (child == &element.base) return index;
        if (child.node_type == NodeBase.ELEMENT_NODE) {
            const elem: *Element = @ptrCast(child);
            if (std.mem.eql(u8, elem.tag_name, element.tag_name)) {
                index += 1;
            }
        }
    }
    return null;
}

/// Check if index matches nth pattern (an+b)
fn matchesNthPattern(index: usize, pattern: NthPattern) bool {
    const n = @as(i32, @intCast(index));

    // Special case: a=0 (constant)
    if (pattern.a == 0) {
        return n == pattern.b;
    }

    // General case: an+b
    // Check if (n - b) is divisible by a and non-negative
    const diff = n - pattern.b;
    if (diff < 0) return false;
    if (@mod(diff, pattern.a) != 0) return false;
    return true;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const infra = @import("infra");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Parser = @import("parser.zig").Parser;

/// Helper to create element for testing
fn createTestElement(allocator: Allocator, tag_name: []const u8) !*Element {
    const elem = try allocator.create(Element);
    elem.* = Element.init(allocator, tag_name);
    return elem;
}

/// Helper to destroy test element
fn destroyTestElement(allocator: Allocator, elem: *Element) void {
    elem.deinit();
    allocator.destroy(elem);
}

test "Matcher: type selector (div)" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    const input = "div";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}

test "Matcher: type selector mismatch" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    const input = "span";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(!result);
}

// TODO: Enable when ArrayList.init bug in element_with_base.zig is fixed
// test "Matcher: class selector" {
//     const allocator = testing.allocator;
//     const elem = try createTestElement(allocator, "div");
//     defer destroyTestElement(allocator, elem);
//
//     try elem.setAttribute("class", "container active");
//
//     const input = ".container";
//     var tokenizer = Tokenizer.init(allocator, input);
//     var p = Parser.init(allocator, &tokenizer);
//     defer p.deinit();
//
//     const selector_list = try p.parse();
//     const matcher = Matcher.init(allocator);
//     const result = try matcher.matches(elem, &selector_list);
//
//     try testing.expect(result);
// }

test "Matcher: ID selector" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    try elem.setId("main");

    const input = "#main";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}

// TODO: Enable when ArrayList.init bug in element_with_base.zig is fixed
// test "Matcher: compound selector (div.container)" {
//     const allocator = testing.allocator;
//     const elem = try createTestElement(allocator, "div");
//     defer destroyTestElement(allocator, elem);
//
//     try elem.setAttribute("class", "container");
//
//     const input = "div.container";
//     var tokenizer = Tokenizer.init(allocator, input);
//     var p = Parser.init(allocator, &tokenizer);
//     defer p.deinit();
//
//     const selector_list = try p.parse();
//     const matcher = Matcher.init(allocator);
//     const result = try matcher.matches(elem, &selector_list);
//
//     try testing.expect(result);
// }

// TODO: Enable when ArrayList.init bug in element_with_base.zig is fixed
// test "Matcher: attribute selector [href]" {
//     const allocator = testing.allocator;
//     const elem = try createTestElement(allocator, "a");
//     defer destroyTestElement(allocator, elem);
//
//     try elem.setAttribute("href", "https://example.com");
//
//     const input = "[href]";
//     var tokenizer = Tokenizer.init(allocator, input);
//     var p = Parser.init(allocator, &tokenizer);
//     defer p.deinit();
//
//     const selector_list = try p.parse();
//     const matcher = Matcher.init(allocator);
//     const result = try matcher.matches(elem, &selector_list);
//
//     try testing.expect(result);
// }

test "Matcher: :empty pseudo-class" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    const input = "div:empty";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result); // Empty div should match
}

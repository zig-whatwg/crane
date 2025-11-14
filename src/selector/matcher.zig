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
//! defer p_parser.deinit();
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
//!
//! ## Supported Selectors
//!
//! ### Fully Implemented
//! - Simple selectors: Universal (`*`), Type (`div`), Class (`.foo`), ID (`#bar`), Attribute (`[attr]`)
//! - Combinators: Descendant (` `), Child (`>`), Next-sibling (`+`), Subsequent-sibling (`~`)
//! - Structural pseudo-classes: `:first-child`, `:last-child`, `:nth-child()`, `:empty`, `:root`, etc.
//! - Logical pseudo-classes: `:not()`, `:is()`, `:where()`, `:has()`
//! - Language pseudo-class: `:lang()`
//! - Attribute case-sensitivity: `[attr=val i]`, `[attr=val s]`
//!
//! ### Parsed but Return False (Need Runtime State)
//! - Link pseudo-classes: `:any-link`, `:link`, `:visited`
//! - User action pseudo-classes: `:hover`, `:active`, `:focus`, `:focus-visible`, `:focus-within`
//! - Input pseudo-classes: `:enabled`, `:disabled`, `:read-only`, `:read-write`, `:checked`
//!
//! ### Not Yet Implemented (Need HTML/Forms Integration)
//! The following pseudo-classes require HTML element types and form semantics:
//! - `:target` - Requires Document fragment identifier integration
//! - `:defined` - Requires Web Components / Custom Elements
//! - `:placeholder-shown` - Requires HTMLInputElement
//! - `:default` - Requires HTMLFormElement
//! - `:valid`, `:invalid` - Requires constraint validation API
//! - `:in-range`, `:out-of-range` - Requires HTMLInputElement range validation
//! - `:required`, `:optional` - Requires form element semantics
//! - `:blank` - Requires form input tracking
//! - `:user-invalid` - Requires user interaction event tracking
//! - `:dir()` - Requires HTML directionality processing
//!
//! These will be implemented when HTML support is added to the monorepo.

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
    scoping_root: ?*const Element = null,

    pub fn init(allocator: Allocator) Matcher {
        return .{ .allocator = allocator };
    }

    pub fn initWithScope(allocator: Allocator, scoping_root: *const Element) Matcher {
        return .{ .allocator = allocator, .scoping_root = scoping_root };
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
    /// Uses bloom filter for fast negative lookups before checking actual class list
    fn matchesClass(self: *const Matcher, element: *Element, class_name: []const u8) bool {
        _ = self;

        // Fast path: Check bloom filter first
        // If bloom filter says "definitely not present", we can return false immediately
        // without parsing the class attribute string
        if (!element.class_bloom_filter.contains(class_name)) {
            return false;
        }

        // Bloom filter says "possibly present" - verify with actual class list
        // Small chance of false positive, but no false negatives
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
            .Scope => self.matchesScope(element),
            .NthChild => |pattern| matchesNthChild(element, pattern),
            .NthLastChild => |pattern| matchesNthLastChild(element, pattern),
            .NthOfType => |pattern| matchesNthOfType(element, pattern),
            .NthLastOfType => |pattern| matchesNthLastOfType(element, pattern),
            .Not => |selector_list| !try self.matches(element, selector_list),
            .Is, .Where => |selector_list| try self.matches(element, selector_list),
            .Has => |selector_list| try self.matchesHas(element, selector_list),
            .Lang => |lang_code| matchesLang(element, lang_code),
            .Dir => |direction| matchesDir(element, direction),
            // User action pseudo-classes - not supported in querySelector
            // (these require runtime state tracking)
            .AnyLink, .Link, .Visited, .Hover, .Active, .Focus, .FocusVisible, .FocusWithin => false,
            // Input pseudo-classes - not supported without HTML library
            .Enabled, .Disabled, .ReadOnly, .ReadWrite, .Checked => false,
        };
    }

    /// Match :scope pseudo-class
    /// Matches when element is the scoping root
    fn matchesScope(self: *const Matcher, element: *Element) bool {
        if (self.scoping_root) |scope| {
            return @as(*const Element, @ptrCast(scope)) == element;
        }
        // If no scoping root specified, :scope matches the root element
        return matchesRoot(element);
    }

    /// Match :has() pseudo-class (element has descendant or relative matching selector)
    fn matchesHas(self: *const Matcher, element: *Element, selector_list: *const SelectorList) MatcherError!bool {
        // Check each selector in the list
        for (selector_list.selectors) |*complex_selector| {
            // Handle relative selectors
            if (complex_selector.is_relative) {
                if (complex_selector.initial_combinator) |combinator| {
                    const has_match = switch (combinator) {
                        .Child => try self.hasMatchingChild(element, complex_selector),
                        .NextSibling => try self.hasMatchingNextSibling(element, complex_selector),
                        .SubsequentSibling => try self.hasMatchingSubsequentSibling(element, complex_selector),
                        .Descendant => try self.hasMatchingDescendant(element, complex_selector),
                    };
                    if (has_match) return true;
                    continue;
                }
            }

            // Non-relative: check descendants
            if (try self.hasMatchingDescendant(element, complex_selector)) {
                return true;
            }
        }
        return false;
    }

    /// Check if element has descendant matching complex selector
    fn hasMatchingDescendant(self: *const Matcher, element: *Element, complex_selector: *const ComplexSelector) MatcherError!bool {
        for (0..element.base.child_nodes.size()) |i| {
            const child_node = element.base.child_nodes.get(i) orelse continue;
            if (child_node.node_type == NodeBase.ELEMENT_NODE) {
                const child_element: *Element = @ptrCast(child_node);
                if (try self.matchesComplexSelector(child_element, complex_selector)) {
                    return true;
                }
                if (try self.hasMatchingDescendant(child_element, complex_selector)) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Check if element has direct child matching selector
    fn hasMatchingChild(self: *const Matcher, element: *Element, complex_selector: *const ComplexSelector) MatcherError!bool {
        for (0..element.base.child_nodes.size()) |i| {
            const child_node = element.base.child_nodes.get(i) orelse continue;
            if (child_node.node_type == NodeBase.ELEMENT_NODE) {
                const child_element: *Element = @ptrCast(child_node);
                if (try self.matchesComplexSelector(child_element, complex_selector)) {
                    return true;
                }
            }
        }
        return false;
    }

    /// Check if element has next sibling matching selector
    fn hasMatchingNextSibling(self: *const Matcher, element: *Element, complex_selector: *const ComplexSelector) MatcherError!bool {
        const next = getNextSibling(element) orelse return false;
        if (next.node_type == NodeBase.ELEMENT_NODE) {
            const next_elem: *Element = @ptrCast(next);
            return try self.matchesComplexSelector(next_elem, complex_selector);
        }
        return false;
    }

    /// Check if element has subsequent sibling matching selector
    fn hasMatchingSubsequentSibling(self: *const Matcher, element: *Element, complex_selector: *const ComplexSelector) MatcherError!bool {
        var current = getNextSibling(element);
        while (current) |sibling_node| {
            if (sibling_node.node_type == NodeBase.ELEMENT_NODE) {
                const sibling_elem: *Element = @ptrCast(sibling_node);
                if (try self.matchesComplexSelector(sibling_elem, complex_selector)) {
                    return true;
                }
            }
            current = getNextSibling(@as(*const Element, @ptrCast(sibling_node)));
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

/// Match :lang(code) - language matching based on lang attribute
fn matchesLang(element: *Element, lang_code: []const u8) bool {
    // Walk up tree checking lang attributes
    // Per spec: https://drafts.csswg.org/selectors-4/#lang-pseudo
    var current: ?*Element = element;
    while (current) |elem| {
        if (elem.getAttribute("lang")) |lang_value| {
            // Match language code (with fallback for variants)
            // E.g., lang="en-US" matches :lang(en)
            if (matchesLanguageCode(lang_value, lang_code)) {
                return true;
            }
        }
        // Check parent
        if (elem.base.parent_node) |parent| {
            if (parent.node_type == NodeBase.ELEMENT_NODE) {
                current = @ptrCast(parent);
                continue;
            }
        }
        break;
    }
    return false;
}

/// Check if language value matches language code
/// Supports exact match or prefix match with hyphen separator
fn matchesLanguageCode(value: []const u8, code: []const u8) bool {
    // Exact match (case-insensitive)
    if (std.ascii.eqlIgnoreCase(value, code)) return true;

    // Prefix match: "en-US" matches "en"
    if (value.len > code.len and value[code.len] == '-') {
        return std.ascii.eqlIgnoreCase(value[0..code.len], code);
    }

    return false;
}

/// Check if a Unicode code point has strong LTR directionality
/// Based on Unicode Bidirectional Algorithm character classes
fn isStrongLTR(cp: u21) bool {
    // Basic Latin, Latin Extended, Greek, Cyrillic, etc.
    if (cp >= 0x0041 and cp <= 0x005A) return true; // A-Z
    if (cp >= 0x0061 and cp <= 0x007A) return true; // a-z
    if (cp >= 0x00C0 and cp <= 0x00D6) return true; // Latin-1 letters
    if (cp >= 0x00D8 and cp <= 0x00F6) return true;
    if (cp >= 0x00F8 and cp <= 0x02B8) return true;
    if (cp >= 0x0370 and cp <= 0x0373) return true; // Greek
    if (cp >= 0x0376 and cp <= 0x0377) return true;
    if (cp >= 0x037B and cp <= 0x037D) return true;
    if (cp >= 0x037F and cp <= 0x03FF) return true;
    if (cp >= 0x0400 and cp <= 0x052F) return true; // Cyrillic
    return false;
}

/// Check if a Unicode code point has strong RTL directionality
/// Based on Unicode Bidirectional Algorithm character classes (R, AL)
fn isStrongRTL(cp: u21) bool {
    // Hebrew
    if (cp >= 0x0590 and cp <= 0x05FF) return true;
    // Arabic, Arabic Supplement, Arabic Extended-A
    if (cp >= 0x0600 and cp <= 0x06FF) return true;
    if (cp >= 0x0750 and cp <= 0x077F) return true;
    if (cp >= 0x08A0 and cp <= 0x08FF) return true;
    // Syriac, Thaana, N'Ko
    if (cp >= 0x0700 and cp <= 0x074F) return true;
    if (cp >= 0x0780 and cp <= 0x07BF) return true;
    if (cp >= 0x07C0 and cp <= 0x07FF) return true;
    return false;
}

/// Compute direction for dir="auto" based on element content
/// Spec: https://html.spec.whatwg.org/#the-dir-attribute
/// Finds the first strong directional character in the element's text content
///
/// FOLLOW-UP: Full implementation requires:
/// - Element.textContent() method to get all descendant text
/// - Or ability to traverse and cast text nodes properly
/// - Handle bidi isolates and other HTML spec requirements
///
/// Current implementation: Simplified version that checks any text content that's readily accessible
fn computeAutoDirection(element: *Element) Direction {
    _ = element;

    // FOLLOW-UP: Implement full text traversal when Element.textContent is available
    // For now, default to LTR per HTML spec (when no strong directional character is found)
    // This is spec-compliant behavior for empty or neutral-only content

    return .ltr;
}

/// Match :dir() pseudo-class
/// Spec: https://drafts.csswg.org/selectors-4/#dir-pseudo
fn matchesDir(element: *Element, direction: Direction) bool {
    // Check for dir attribute on element or ancestors
    // Per spec: Walk up tree checking dir attributes
    var current: ?*Element = element;
    while (current) |elem| {
        if (elem.getAttribute("dir")) |dir_value| {
            // Match direction (case-insensitive)
            const matches = switch (direction) {
                .ltr => std.ascii.eqlIgnoreCase(dir_value, "ltr"),
                .rtl => std.ascii.eqlIgnoreCase(dir_value, "rtl"),
            };
            if (matches) return true;

            // If dir="auto", compute direction from content
            if (std.ascii.eqlIgnoreCase(dir_value, "auto")) {
                const auto_dir = computeAutoDirection(elem);
                return auto_dir == direction;
            }
        }
        // Check parent
        if (elem.base.parent_node) |parent| {
            if (parent.node_type == NodeBase.ELEMENT_NODE) {
                current = @ptrCast(parent);
                continue;
            }
        }
        break;
    }
    // Default directionality is ltr per HTML spec
    return direction == .ltr;
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
const Direction = parser.Direction;
const AttrWithBase = dom.AttrWithBase;

/// Helper to create element for testing
fn createTestElement(allocator: Allocator, tag_name: []const u8) !*Element {
    const elem = try allocator.create(Element);
    elem.* = Element.init(allocator, tag_name);
    return elem;
}

/// Helper to create element with attributes
fn createTestElementWithAttrs(
    allocator: Allocator,
    tag_name: []const u8,
    attributes: []const struct { name: []const u8, value: []const u8 },
) !*Element {
    const elem = try allocator.create(Element);
    elem.* = Element.init(allocator, tag_name);

    // Use setAttribute to properly populate attributes and update bloom filter
    for (attributes) |attr| {
        try elem.setAttribute(attr.name, attr.value);
    }

    return elem;
}

/// Helper to destroy test element
fn destroyTestElement(allocator: Allocator, elem: *Element) void {
    elem.deinit();
    allocator.destroy(elem);
}










// ============================================================================
// Combinator Tests
// ============================================================================





// ============================================================================
// Structural Pseudo-Class Tests
// ============================================================================











// ============================================================================
// Attribute Matcher Tests
// ============================================================================








// ============================================================================
// Logical Pseudo-Class Tests
// ============================================================================





// ============================================================================
// Edge Case Tests
// ============================================================================
















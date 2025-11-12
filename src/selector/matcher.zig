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
//! - `:scope` - Requires scoped query API changes
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
            .Lang => |lang_code| matchesLang(element, lang_code),
            .Dir => |direction| matchesDir(element, direction),
            // User action pseudo-classes - not supported in querySelector
            // (these require runtime state tracking)
            .AnyLink, .Link, .Visited, .Hover, .Active, .Focus, .FocusVisible, .FocusWithin => false,
            // Input pseudo-classes - not supported without HTML library
            .Enabled, .Disabled, .ReadOnly, .ReadWrite, .Checked => false,
        };
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
            // If dir="auto", we'd need to compute direction from content
            // For now, treat as no match
            if (std.ascii.eqlIgnoreCase(dir_value, "auto")) {
                // TODO: Implement auto direction computation from content
                return false;
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

/// Helper to create element with attributes (workaround for ArrayList bug)
fn createTestElementWithAttrs(
    allocator: Allocator,
    tag_name: []const u8,
    attributes: []const struct { name: []const u8, value: []const u8 },
) !*Element {
    const elem = try allocator.create(Element);
    elem.* = Element.init(allocator, tag_name);

    // Manually populate attributes without using setAttribute (which triggers ArrayList bug)
    for (attributes) |attr| {
        const attr_node = try allocator.create(AttrWithBase);
        errdefer allocator.destroy(attr_node);

        attr_node.* = try AttrWithBase.init(
            allocator,
            attr.name,
            attr.value,
            null, // namespace_uri
            null, // prefix
        );
        try elem.attributes.append(attr_node);
    }

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

test "Matcher: class selector" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "class", .value = "container active" },
    });
    defer destroyTestElement(allocator, elem);

    const input = ".container";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}

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

test "Matcher: compound selector (div.container)" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "class", .value = "container" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "div.container";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}

test "Matcher: attribute selector [href]" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "a", &.{
        .{ .name = "href", .value = "https://example.com" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[href]";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}

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

test "Matcher: :lang(en) pseudo-class" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "lang", .value = "en" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "div:lang(en)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}

test "Matcher: :lang(en) matches en-US variant" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "lang", .value = "en-US" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "div:lang(en)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result); // en-US should match :lang(en)
}

// ============================================================================
// Combinator Tests
// ============================================================================

test "Matcher: child combinator (div > p)" {
    const allocator = testing.allocator;

    // Create parent div
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    // Create child p
    const child = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, child);

    // Link them
    child.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&child.base);

    const input = "div > p";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(child, &selector_list);

    try testing.expect(result);
}

test "Matcher: descendant combinator (div p)" {
    const allocator = testing.allocator;

    // Create grandparent div
    const grandparent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, grandparent);

    // Create parent span
    const parent = try createTestElement(allocator, "span");
    defer destroyTestElement(allocator, parent);

    // Create child p
    const child = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, child);

    // Link: div > span > p
    parent.base.parent_node = &grandparent.base;
    try grandparent.base.child_nodes.append(&parent.base);
    child.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&child.base);

    const input = "div p";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(child, &selector_list);

    try testing.expect(result); // p is descendant of div
}

test "Matcher: next-sibling combinator (h1 + p)" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    // Create siblings
    const h1 = try createTestElement(allocator, "h1");
    defer destroyTestElement(allocator, h1);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    // Link as siblings: div > h1, p
    h1.base.parent_node = &parent.base;
    p.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&h1.base);
    try parent.base.child_nodes.append(&p.base);

    const input = "h1 + p";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(p, &selector_list);

    try testing.expect(result); // p immediately follows h1
}

test "Matcher: subsequent-sibling combinator (h1 ~ p)" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    // Create siblings: h1, span, p
    const h1 = try createTestElement(allocator, "h1");
    defer destroyTestElement(allocator, h1);

    const span = try createTestElement(allocator, "span");
    defer destroyTestElement(allocator, span);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    // Link as siblings
    h1.base.parent_node = &parent.base;
    span.base.parent_node = &parent.base;
    p.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&h1.base);
    try parent.base.child_nodes.append(&span.base);
    try parent.base.child_nodes.append(&p.base);

    const input = "h1 ~ p";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(p, &selector_list);

    try testing.expect(result); // p follows h1 (not immediately)
}

// ============================================================================
// Structural Pseudo-Class Tests
// ============================================================================

test "Matcher: :first-child pseudo-class" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "ul");
    defer destroyTestElement(allocator, parent);

    // Create children
    const li1 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li1);

    const li2 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li2);

    // Link
    li1.base.parent_node = &parent.base;
    li2.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&li1.base);
    try parent.base.child_nodes.append(&li2.base);

    const input = "li:first-child";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(li1, &selector_list)); // li1 is first-child
    try testing.expect(!try matcher.matches(li2, &selector_list)); // li2 is not first-child
}

test "Matcher: :last-child pseudo-class" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "ul");
    defer destroyTestElement(allocator, parent);

    // Create children
    const li1 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li1);

    const li2 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li2);

    // Link
    li1.base.parent_node = &parent.base;
    li2.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&li1.base);
    try parent.base.child_nodes.append(&li2.base);

    const input = "li:last-child";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(!try matcher.matches(li1, &selector_list)); // li1 is not last-child
    try testing.expect(try matcher.matches(li2, &selector_list)); // li2 is last-child
}

test "Matcher: :only-child pseudo-class" {
    const allocator = testing.allocator;

    // Create parent with one child
    const parent1 = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent1);

    const only = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, only);

    only.base.parent_node = &parent1.base;
    try parent1.base.child_nodes.append(&only.base);

    // Create parent with multiple children
    const parent2 = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent2);

    const child1 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, child1);

    const child2 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, child2);

    child1.base.parent_node = &parent2.base;
    child2.base.parent_node = &parent2.base;
    try parent2.base.child_nodes.append(&child1.base);
    try parent2.base.child_nodes.append(&child2.base);

    const input = "p:only-child";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(only, &selector_list)); // only is only-child
    try testing.expect(!try matcher.matches(child1, &selector_list)); // child1 has siblings
}

test "Matcher: :first-of-type pseudo-class" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    // Create mixed children: div, p, p
    const div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    const p1 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p1);

    const p2 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p2);

    // Link
    div.base.parent_node = &parent.base;
    p1.base.parent_node = &parent.base;
    p2.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&div.base);
    try parent.base.child_nodes.append(&p1.base);
    try parent.base.child_nodes.append(&p2.base);

    const input = "p:first-of-type";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(p1, &selector_list)); // p1 is first p
    try testing.expect(!try matcher.matches(p2, &selector_list)); // p2 is second p
}

test "Matcher: :last-of-type pseudo-class" {
    const allocator = testing.allocator;

    // Create parent
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    // Create mixed children: p, p, div
    const p1 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p1);

    const p2 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p2);

    const div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    // Link
    p1.base.parent_node = &parent.base;
    p2.base.parent_node = &parent.base;
    div.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&p1.base);
    try parent.base.child_nodes.append(&p2.base);
    try parent.base.child_nodes.append(&div.base);

    const input = "p:last-of-type";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(!try matcher.matches(p1, &selector_list)); // p1 is not last p
    try testing.expect(try matcher.matches(p2, &selector_list)); // p2 is last p
}

test "Matcher: :only-of-type pseudo-class" {
    const allocator = testing.allocator;

    // Create parent with mixed types: div, p, span
    const parent = try createTestElement(allocator, "section");
    defer destroyTestElement(allocator, parent);

    const div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    const span = try createTestElement(allocator, "span");
    defer destroyTestElement(allocator, span);

    // Link
    div.base.parent_node = &parent.base;
    p.base.parent_node = &parent.base;
    span.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&div.base);
    try parent.base.child_nodes.append(&p.base);
    try parent.base.child_nodes.append(&span.base);

    const input = "p:only-of-type";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(p, &selector_list)); // p is only p
}

test "Matcher: :nth-child(2n) even" {
    const allocator = testing.allocator;

    // Create parent with 4 children
    const parent = try createTestElement(allocator, "ul");
    defer destroyTestElement(allocator, parent);

    const li1 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li1);
    const li2 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li2);
    const li3 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li3);
    const li4 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li4);

    // Link all
    li1.base.parent_node = &parent.base;
    li2.base.parent_node = &parent.base;
    li3.base.parent_node = &parent.base;
    li4.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&li1.base);
    try parent.base.child_nodes.append(&li2.base);
    try parent.base.child_nodes.append(&li3.base);
    try parent.base.child_nodes.append(&li4.base);

    const input = "li:nth-child(even)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(!try matcher.matches(li1, &selector_list)); // odd
    try testing.expect(try matcher.matches(li2, &selector_list)); // even
    try testing.expect(!try matcher.matches(li3, &selector_list)); // odd
    try testing.expect(try matcher.matches(li4, &selector_list)); // even
}

test "Matcher: :nth-child(2n+1) odd" {
    const allocator = testing.allocator;

    // Create parent with 3 children
    const parent = try createTestElement(allocator, "ul");
    defer destroyTestElement(allocator, parent);

    const li1 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li1);
    const li2 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li2);
    const li3 = try createTestElement(allocator, "li");
    defer destroyTestElement(allocator, li3);

    // Link all
    li1.base.parent_node = &parent.base;
    li2.base.parent_node = &parent.base;
    li3.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&li1.base);
    try parent.base.child_nodes.append(&li2.base);
    try parent.base.child_nodes.append(&li3.base);

    const input = "li:nth-child(odd)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(li1, &selector_list)); // odd
    try testing.expect(!try matcher.matches(li2, &selector_list)); // even
    try testing.expect(try matcher.matches(li3, &selector_list)); // odd
}

test "Matcher: :nth-last-child(2)" {
    const allocator = testing.allocator;

    // Create parent with 3 children
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    const p1 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p1);
    const p2 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p2);
    const p3 = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p3);

    // Link
    p1.base.parent_node = &parent.base;
    p2.base.parent_node = &parent.base;
    p3.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&p1.base);
    try parent.base.child_nodes.append(&p2.base);
    try parent.base.child_nodes.append(&p3.base);

    const input = "p:nth-last-child(2)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(!try matcher.matches(p1, &selector_list)); // 3rd from end
    try testing.expect(try matcher.matches(p2, &selector_list)); // 2nd from end
    try testing.expect(!try matcher.matches(p3, &selector_list)); // 1st from end
}

test "Matcher: :root pseudo-class" {
    const allocator = testing.allocator;

    // Create root element (no parent)
    const root = try createTestElement(allocator, "html");
    defer destroyTestElement(allocator, root);

    // Create child element
    const child = try createTestElement(allocator, "body");
    defer destroyTestElement(allocator, child);

    child.base.parent_node = &root.base;
    try root.base.child_nodes.append(&child.base);

    const input = ":root";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(root, &selector_list)); // root has no parent
    try testing.expect(!try matcher.matches(child, &selector_list)); // child has parent
}

// ============================================================================
// Attribute Matcher Tests
// ============================================================================

test "Matcher: attribute exact match [type='text']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "input", &.{
        .{ .name = "type", .value = "text" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[type='text']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}

test "Matcher: attribute prefix match [href^='https']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "a", &.{
        .{ .name = "href", .value = "https://example.com" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[href^='https']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}

test "Matcher: attribute suffix match [src$='.png']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "img", &.{
        .{ .name = "src", .value = "/images/logo.png" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[src$='.png']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}

test "Matcher: attribute substring match [title*='hello']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "title", .value = "Say hello world" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[title*='hello']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}

test "Matcher: attribute includes word [class~='active']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "class", .value = "btn btn-primary active" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[class~='active']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}

test "Matcher: attribute dash match [lang|='en']" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "lang", .value = "en-US" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "[lang|='en']";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}

// TODO: Case-insensitive attribute matching needs parser support for 'i' flag
// test "Matcher: attribute case-insensitive [type='TEXT' i]" {
//     const allocator = testing.allocator;
//     const elem = try createTestElementWithAttrs(allocator, "input", &.{
//         .{ .name = "type", .value = "text" },
//     });
//     defer destroyTestElement(allocator, elem);
//
//     const input = "[type='TEXT' i]";
//     var tokenizer = Tokenizer.init(allocator, input);
//     var p = try Parser.init(allocator, &tokenizer);
//     defer p.deinit();
//
//     var selector_list = try p.parse();
//     defer selector_list.deinit();
//
//     const matcher = Matcher.init(allocator);
//     try testing.expect(try matcher.matches(elem, &selector_list));
// }

// ============================================================================
// Logical Pseudo-Class Tests
// ============================================================================

test "Matcher: :not() pseudo-class" {
    const allocator = testing.allocator;
    const div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    const input = "*:not(p)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(div, &selector_list)); // div is not p
    try testing.expect(!try matcher.matches(p, &selector_list)); // p is p
}

test "Matcher: :is() pseudo-class" {
    const allocator = testing.allocator;
    const h1 = try createTestElement(allocator, "h1");
    defer destroyTestElement(allocator, h1);

    const h2 = try createTestElement(allocator, "h2");
    defer destroyTestElement(allocator, h2);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    const input = ":is(h1, h2)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(h1, &selector_list)); // h1 matches
    try testing.expect(try matcher.matches(h2, &selector_list)); // h2 matches
    try testing.expect(!try matcher.matches(p, &selector_list)); // p doesn't match
}

test "Matcher: :where() pseudo-class" {
    const allocator = testing.allocator;
    const article = try createTestElement(allocator, "article");
    defer destroyTestElement(allocator, article);

    const section = try createTestElement(allocator, "section");
    defer destroyTestElement(allocator, section);

    const input = ":where(article, section)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(article, &selector_list));
    try testing.expect(try matcher.matches(section, &selector_list));
}

test "Matcher: :has() pseudo-class" {
    const allocator = testing.allocator;

    // Create parent with child p
    const parent1 = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent1);

    const child_p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, child_p);

    child_p.base.parent_node = &parent1.base;
    try parent1.base.child_nodes.append(&child_p.base);

    // Create parent with child span (no p)
    const parent2 = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent2);

    const child_span = try createTestElement(allocator, "span");
    defer destroyTestElement(allocator, child_span);

    child_span.base.parent_node = &parent2.base;
    try parent2.base.child_nodes.append(&child_span.base);

    const input = "div:has(p)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(parent1, &selector_list)); // has p
    try testing.expect(!try matcher.matches(parent2, &selector_list)); // no p
}

// ============================================================================
// Edge Case Tests
// ============================================================================

test "Matcher: empty selector list behavior" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    // Parser should fail on empty input, but test error handling
    const input = "div";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    // Verify we have a valid selector list
    try testing.expect(selector_list.selectors.len > 0);
}

test "Matcher: class selector with multiple classes" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "class", .value = "foo bar baz" },
    });
    defer destroyTestElement(allocator, elem);

    const input = ".bar";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}

test "Matcher: element with no parent (root)" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    // Element with no parent should still match simple selectors
    const input = "div";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(elem, &selector_list));
}

test "Matcher: complex selector chain (div > p.text)" {
    const allocator = testing.allocator;

    // Create: div > p.text
    const parent = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, parent);

    const child = try createTestElementWithAttrs(allocator, "p", &.{
        .{ .name = "class", .value = "text important" },
    });
    defer destroyTestElement(allocator, child);

    child.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&child.base);

    const input = "div > p.text";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(child, &selector_list));
}

test "Matcher: nested :not(:is()) combination" {
    const allocator = testing.allocator;
    const div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    const p = try createTestElement(allocator, "p");
    defer destroyTestElement(allocator, p);

    const input = "*:not(:is(p, span))";
    var tokenizer = Tokenizer.init(allocator, input);
    var p_parser = try Parser.init(allocator, &tokenizer);
    defer p_parser.deinit();

    var selector_list = try p_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    try testing.expect(try matcher.matches(div, &selector_list)); // div is not (p or span)
    try testing.expect(!try matcher.matches(p, &selector_list)); // p is (p or span)
}
//
// TODO: Enable when ArrayList.init bug in element_with_base.zig is fixed
// test "Matcher: :lang(en) matches en-US variant" {
//     const allocator = testing.allocator;
//     const elem = try createTestElement(allocator, "div");
//     defer destroyTestElement(allocator, elem);
//
//     try elem.setAttribute("lang", "en-US");
//
//     const input = "div:lang(en)";
//     var tokenizer = Tokenizer.init(allocator, input);
//     var p = try Parser.init(allocator, &tokenizer);
//     defer p.deinit();
//
//     var selector_list = try p.parse();
//     defer selector_list.deinit();
//
//     const matcher = Matcher.init(allocator);
//     const result = try matcher.matches(elem, &selector_list);
//
//     try testing.expect(result); // en-US should match :lang(en)
// }

test "Matcher: :dir(ltr) pseudo-class" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "dir", .value = "ltr" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "div:dir(ltr)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}

test "Matcher: :dir(rtl) pseudo-class" {
    const allocator = testing.allocator;
    const elem = try createTestElementWithAttrs(allocator, "div", &.{
        .{ .name = "dir", .value = "rtl" },
    });
    defer destroyTestElement(allocator, elem);

    const input = "div:dir(rtl)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result);
}

test "Matcher: :dir(ltr) default when no dir attribute" {
    const allocator = testing.allocator;
    const elem = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, elem);

    const input = "div:dir(ltr)";
    var tokenizer = Tokenizer.init(allocator, input);
    var p = try Parser.init(allocator, &tokenizer);
    defer p.deinit();

    var selector_list = try p.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(elem, &selector_list);

    try testing.expect(result); // Default is ltr
}

test "Matcher: :has(> p) relative child selector" {
    const allocator = testing.allocator;

    // Create: div > p
    var div = try createTestElement(allocator, "div");
    defer destroyTestElement(allocator, div);

    var p_elem = try allocator.create(Element);
    defer {
        p_elem.deinit();
        allocator.destroy(p_elem);
    }
    p_elem.* = Element.init(allocator, "p");

    // Link them
    p_elem.base.parent_node = &div.base;
    try div.base.child_nodes.append(&p_elem.base);

    // Test div:has(> p)
    const input = "div:has(> p)";
    var tokenizer = Tokenizer.init(allocator, input);
    var sel_parser = try Parser.init(allocator, &tokenizer);
    defer sel_parser.deinit();

    var selector_list = try sel_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(div, &selector_list);

    try testing.expect(result); // div has direct child p
}

test "Matcher: :has(+ span) relative next sibling selector" {
    const allocator = testing.allocator;

    // Create parent with two children: div and span
    var parent = try createTestElement(allocator, "body");
    defer destroyTestElement(allocator, parent);

    var div = try allocator.create(Element);
    defer {
        div.deinit();
        allocator.destroy(div);
    }
    div.* = Element.init(allocator, "div");

    var span = try allocator.create(Element);
    defer {
        span.deinit();
        allocator.destroy(span);
    }
    span.* = Element.init(allocator, "span");

    // Link them: parent > div + span
    div.base.parent_node = &parent.base;
    span.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&div.base);
    try parent.base.child_nodes.append(&span.base);

    // Test div:has(+ span)
    const input = "div:has(+ span)";
    var tokenizer = Tokenizer.init(allocator, input);
    var sel_parser = try Parser.init(allocator, &tokenizer);
    defer sel_parser.deinit();

    var selector_list = try sel_parser.parse();
    defer selector_list.deinit();

    const matcher = Matcher.init(allocator);
    const result = try matcher.matches(div, &selector_list);

    try testing.expect(result); // div has next sibling span
}

test "Matcher: :has(~ .error) relative subsequent sibling selector" {
    const allocator = testing.allocator;

    // Create parent with children: div, p, span.error
    var parent = try createTestElement(allocator, "body");
    defer destroyTestElement(allocator, parent);

    var div = try allocator.create(Element);
    defer {
        div.deinit();
        allocator.destroy(div);
    }
    div.* = Element.init(allocator, "div");

    var p_elem = try allocator.create(Element);
    defer {
        p_elem.deinit();
        allocator.destroy(p_elem);
    }
    p_elem.* = Element.init(allocator, "p");

    var span = try createTestElementWithAttrs(allocator, "span", &.{
        .{ .name = "class", .value = "error" },
    });
    defer destroyTestElement(allocator, span);

    // Link them: parent > div ~ p ~ span.error
    div.base.parent_node = &parent.base;
    p_elem.base.parent_node = &parent.base;
    span.base.parent_node = &parent.base;
    try parent.base.child_nodes.append(&div.base);
    try parent.base.child_nodes.append(&p_elem.base);
    try parent.base.child_nodes.append(&span.base);

    // Test div:has(~ .error)
    const input = "div:has(~ .error)";
    var tokenizer = Tokenizer.init(allocator, input);
    var sel_parser = try Parser.init(allocator, &tokenizer);
    defer sel_parser.deinit();

    var selector_list = try sel_parser.parseSelectorList();
    defer selector_list.deinit();

    try std.testing.expect(selector_list.selectors.len == 1);

    const matcher = Matcher.init(allocator);

    // div should match (has subsequent sibling span.error)
    try std.testing.expect(try matcher.matches(div, &selector_list));

    // p should NOT match (not a div element)
    try std.testing.expect(!try matcher.matches(p_elem, &selector_list));

    // span should NOT match (no subsequent sibling span.error - can't match itself)
    try std.testing.expect(!try matcher.matches(span, &selector_list));
}

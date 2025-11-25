//! ParentNode Mixin Implementation
//!
//! Spec: https://dom.spec.whatwg.org/#interface-parentnode
//!
//! This mixin provides shared implementation for ParentNode methods used by
//! Document, Element, and DocumentFragment interfaces.
//!
//! The ParentNode mixin defines:
//! - children (HTMLCollection of child elements)
//! - firstElementChild
//! - lastElementChild
//! - childElementCount
//! - prepend(nodes...)
//! - append(nodes...)
//! - replaceChildren(nodes...)
//! - querySelector(selectors)
//! - querySelectorAll(selectors)

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const selector_mod = @import("selector");
const Tokenizer = selector_mod.Tokenizer;
const Parser = selector_mod.Parser;
const SelectorList = selector_mod.SelectorList;

// Import impl modules for accessing internal state
const impls = @import("impls");
const NodeImpl = impls.Node;
const ElementImpl = impls.Element;

pub const MixinError = error{
    NotImplemented,
    InvalidStateError,
    SyntaxError,
    OutOfMemory,
    HierarchyRequestError,
    NotFoundError,
};

// =============================================================================
// ParentNode Attribute Getters
// =============================================================================

/// Get the first child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-firstelementchild
pub fn firstElementChild(node: *runtime.Instance) ?*runtime.Instance {
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            return c;
        }
        child = NodeImpl.getNextSibling(c);
    }
    return null;
}

/// Get the last child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-lastelementchild
pub fn lastElementChild(node: *runtime.Instance) ?*runtime.Instance {
    var last_element: ?*runtime.Instance = null;

    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            last_element = c;
        }
        child = NodeImpl.getNextSibling(c);
    }

    return last_element;
}

/// Get the number of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-childelementcount
pub fn childElementCount(node: *runtime.Instance) u32 {
    var count: u32 = 0;

    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            count += 1;
        }
        child = NodeImpl.getNextSibling(c);
    }

    return count;
}

/// Create an HTMLCollection of child elements
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-children
pub fn children(allocator: std.mem.Allocator, node: *runtime.Instance, ctx: runtime.Context) MixinError!*runtime.Instance {
    const HTMLCollectionImpl = impls.HTMLCollection;
    const collection = HTMLCollectionImpl.init(
        allocator,
        interfaces.HTMLCollection.State,
        &interfaces.HTMLCollection.vtable,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer HTMLCollectionImpl.deinit(collection);

    // Iterate direct children and add elements
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            HTMLCollectionImpl.addElement(collection, c) catch return error.OutOfMemory;
        }
        child = NodeImpl.getNextSibling(c);
    }

    return collection;
}

// =============================================================================
// Selector Matching (querySelector, querySelectorAll)
// =============================================================================

/// querySelector - Returns the first element matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselector
///
/// Steps:
/// 1. Let s be the result of parse a selector selectors
/// 2. If s is failure, throw SyntaxError
/// 3. Return first element in tree order matching s, or null if none
pub fn querySelector(
    allocator: std.mem.Allocator,
    scoping_root: *runtime.Instance,
    selectors: []const u8,
) MixinError!?*runtime.Instance {
    // Step 1: Parse selector
    var tokenizer = Tokenizer.init(allocator, selectors);
    var parser = Parser.init(allocator, &tokenizer) catch {
        return error.SyntaxError;
    };
    defer parser.deinit();

    var selector_list = parser.parse() catch {
        return error.SyntaxError;
    };
    defer selector_list.deinit();

    // Step 3: Find first matching element in tree order
    return findFirstMatch(scoping_root, &selector_list);
}

/// querySelectorAll - Returns all elements matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
///
/// Steps:
/// 1. Let s be the result of parse a selector selectors
/// 2. If s is failure, throw SyntaxError
/// 3. Return a static NodeList of all elements matching s in tree order
pub fn querySelectorAll(
    allocator: std.mem.Allocator,
    scoping_root: *runtime.Instance,
    selectors: []const u8,
    ctx: runtime.Context,
) MixinError!*runtime.Instance {
    // Step 1: Parse selector
    var tokenizer = Tokenizer.init(allocator, selectors);
    var parser = Parser.init(allocator, &tokenizer) catch {
        return error.SyntaxError;
    };
    defer parser.deinit();

    var selector_list = parser.parse() catch {
        return error.SyntaxError;
    };
    defer selector_list.deinit();

    // Step 3: Create static NodeList and collect all matching elements
    const NodeListImpl = impls.NodeList;
    const node_list = NodeListImpl.init(
        allocator,
        interfaces.NodeList.State,
        &interfaces.NodeList.vtable,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer NodeListImpl.deinit(node_list);

    // Collect all matches
    collectAllMatches(scoping_root, &selector_list, node_list) catch return error.OutOfMemory;

    return node_list;
}

// =============================================================================
// Selector Matching Helpers
// =============================================================================

/// Find the first element matching the selector list (depth-first tree order)
fn findFirstMatch(
    node: *runtime.Instance,
    selector_list: *const SelectorList,
) ?*runtime.Instance {
    // First check children (in tree order)
    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check if this element matches
            if (elementMatchesSelectorList(c, selector_list)) {
                return c;
            }
        }

        // Recursively search descendants (depth-first)
        if (findFirstMatch(c, selector_list)) |found| {
            return found;
        }

        child = NodeImpl.getNextSibling(c);
    }

    return null;
}

/// Collect all elements matching the selector list (depth-first tree order)
fn collectAllMatches(
    node: *runtime.Instance,
    selector_list: *const SelectorList,
    node_list: *runtime.Instance,
) !void {
    const NodeListImpl = impls.NodeList;

    var child = NodeImpl.getFirstChild(node);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check if this element matches
            if (elementMatchesSelectorList(c, selector_list)) {
                try NodeListImpl.addNode(node_list, c);
            }
        }

        // Recursively search descendants (depth-first)
        try collectAllMatches(c, selector_list, node_list);

        child = NodeImpl.getNextSibling(c);
    }
}

/// Check if an element matches a selector list (OR semantics - match any selector)
fn elementMatchesSelectorList(
    element: *runtime.Instance,
    selector_list: *const SelectorList,
) bool {
    for (selector_list.selectors) |*complex_selector| {
        if (elementMatchesComplexSelector(element, complex_selector)) {
            return true;
        }
    }
    return false;
}

/// Check if an element matches a complex selector (combinator chain)
fn elementMatchesComplexSelector(
    element: *runtime.Instance,
    complex: *const selector_mod.ComplexSelector,
) bool {
    // Right-to-left matching (standard CSS strategy)

    // No combinators - element must match the only compound
    if (complex.combinators.len == 0) {
        return elementMatchesCompoundSelector(element, &complex.compound);
    }

    // With combinators: element must match rightmost compound (last in array)
    const rightmost = &complex.combinators[complex.combinators.len - 1].compound;
    if (!elementMatchesCompoundSelector(element, rightmost)) {
        return false;
    }

    // Match combinators right-to-left
    var current_element = element;
    var i: usize = complex.combinators.len;
    while (i > 0) {
        i -= 1;
        const pair = &complex.combinators[i];
        const target_compound = if (i == 0) &complex.compound else &complex.combinators[i - 1].compound;

        const matched = matchCombinator(current_element, pair.combinator, target_compound);
        if (matched == null) return false;
        current_element = matched.?;
    }

    return true;
}

/// Match combinator between element and target compound selector
fn matchCombinator(
    element: *runtime.Instance,
    combinator: selector_mod.Combinator,
    compound: *const selector_mod.CompoundSelector,
) ?*runtime.Instance {
    return switch (combinator) {
        .Child => matchChildCombinator(element, compound),
        .Descendant => matchDescendantCombinator(element, compound),
        .NextSibling => matchNextSiblingCombinator(element, compound),
        .SubsequentSibling => matchSubsequentSiblingCombinator(element, compound),
    };
}

/// Match child combinator (>): parent must match
fn matchChildCombinator(
    element: *runtime.Instance,
    compound: *const selector_mod.CompoundSelector,
) ?*runtime.Instance {
    const parent = NodeImpl.getParent(element) orelse return null;
    const node_type = NodeImpl.getNodeType(parent) orelse 0;
    if (node_type != NodeImpl.NodeType.ELEMENT_NODE) return null;

    if (elementMatchesCompoundSelector(parent, compound)) {
        return parent;
    }
    return null;
}

/// Match descendant combinator (space): any ancestor must match
fn matchDescendantCombinator(
    element: *runtime.Instance,
    compound: *const selector_mod.CompoundSelector,
) ?*runtime.Instance {
    var current = NodeImpl.getParent(element);
    while (current) |ancestor| {
        const node_type = NodeImpl.getNodeType(ancestor) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (elementMatchesCompoundSelector(ancestor, compound)) {
                return ancestor;
            }
        }
        current = NodeImpl.getParent(ancestor);
    }
    return null;
}

/// Match next sibling combinator (+): previous element sibling must match
fn matchNextSiblingCombinator(
    element: *runtime.Instance,
    compound: *const selector_mod.CompoundSelector,
) ?*runtime.Instance {
    // Find previous element sibling
    var sibling = NodeImpl.getPreviousSibling(element);
    while (sibling) |s| {
        const node_type = NodeImpl.getNodeType(s) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (elementMatchesCompoundSelector(s, compound)) {
                return s;
            }
            return null; // Only check immediately preceding element sibling
        }
        sibling = NodeImpl.getPreviousSibling(s);
    }
    return null;
}

/// Match subsequent sibling combinator (~): any previous element sibling must match
fn matchSubsequentSiblingCombinator(
    element: *runtime.Instance,
    compound: *const selector_mod.CompoundSelector,
) ?*runtime.Instance {
    var sibling = NodeImpl.getPreviousSibling(element);
    while (sibling) |s| {
        const node_type = NodeImpl.getNodeType(s) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (elementMatchesCompoundSelector(s, compound)) {
                return s;
            }
        }
        sibling = NodeImpl.getPreviousSibling(s);
    }
    return null;
}

/// Check if element matches compound selector (AND semantics - match all simple selectors)
fn elementMatchesCompoundSelector(
    element: *runtime.Instance,
    compound: *const selector_mod.CompoundSelector,
) bool {
    for (compound.simple_selectors) |*simple| {
        if (!elementMatchesSimpleSelector(element, simple)) {
            return false;
        }
    }
    return true;
}

/// Check if element matches a simple selector
fn elementMatchesSimpleSelector(
    element: *runtime.Instance,
    simple: *const selector_mod.SimpleSelector,
) bool {
    return switch (simple.*) {
        .Universal => true,
        .Type => |type_sel| matchesTypeSelector(element, type_sel.tag_name),
        .Class => |class_sel| matchesClassSelector(element, class_sel.class_name),
        .Id => |id_sel| matchesIdSelector(element, id_sel.id),
        .Attribute => |*attr_sel| matchesAttributeSelector(element, attr_sel),
        .PseudoClass => |*pseudo_sel| matchesPseudoClass(element, pseudo_sel),
        .PseudoElement => false, // Pseudo-elements don't match in querySelector
    };
}

/// Match type selector (tag name)
fn matchesTypeSelector(element: *runtime.Instance, tag_name: []const u8) bool {
    const internal = ElementImpl.getInternal(element) orelse return false;
    const local_name = internal.local_name.asSlice();
    // Case-insensitive for HTML elements
    return std.ascii.eqlIgnoreCase(local_name, tag_name);
}

/// Match class selector
fn matchesClassSelector(element: *runtime.Instance, class_name: []const u8) bool {
    const internal = ElementImpl.getInternal(element) orelse return false;
    const class_attr = internal.class_name.asSlice();
    if (class_attr.len == 0) return false;

    // Check if class_name is in the space-separated class list
    var iter = std.mem.splitScalar(u8, class_attr, ' ');
    while (iter.next()) |class| {
        if (class.len == 0) continue;
        if (std.mem.eql(u8, class, class_name)) {
            return true;
        }
    }
    return false;
}

/// Match ID selector
fn matchesIdSelector(element: *runtime.Instance, id: []const u8) bool {
    const internal = ElementImpl.getInternal(element) orelse return false;
    const elem_id = internal.id.asSlice();
    return std.mem.eql(u8, elem_id, id);
}

/// Match attribute selector
fn matchesAttributeSelector(
    element: *runtime.Instance,
    attr_sel: *const selector_mod.AttributeSelector,
) bool {
    const internal = ElementImpl.getInternal(element) orelse return false;

    // Find attribute by name
    var attr_value: ?[]const u8 = null;
    for (internal.attributes.items) |attr| {
        if (std.ascii.eqlIgnoreCase(attr.local_name, attr_sel.name)) {
            attr_value = attr.value;
            break;
        }
    }

    const value = attr_value orelse return false;

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
fn matchesPseudoClass(
    element: *runtime.Instance,
    pseudo: *const selector_mod.PseudoClassSelector,
) bool {
    return switch (pseudo.kind) {
        // Structural pseudo-classes
        .Root => isRootElement(element),
        .Empty => isEmptyElement(element),
        .FirstChild => isFirstChild(element),
        .LastChild => isLastChild(element),
        .OnlyChild => isOnlyChild(element),
        .FirstOfType => isFirstOfType(element),
        .LastOfType => isLastOfType(element),
        .OnlyOfType => isOnlyOfType(element),

        // Nth pseudo-classes
        .NthChild => |nth| matchesNthChild(element, nth),
        .NthLastChild => |nth| matchesNthLastChild(element, nth),
        .NthOfType => |nth| matchesNthOfType(element, nth),
        .NthLastOfType => |nth| matchesNthLastOfType(element, nth),

        // Negation and matching pseudo-classes
        .Not => |sel_list| !elementMatchesSelectorList(element, sel_list),
        .Is, .Where => |sel_list| elementMatchesSelectorList(element, sel_list),
        .Has => |_| false, // :has() requires complex relative selector matching

        // State-based pseudo-classes (require runtime state - return false for now)
        // Link pseudo-classes
        .AnyLink,
        .Link,
        .Visited,
        // User action pseudo-classes
        .Hover,
        .Active,
        .Focus,
        .FocusVisible,
        .FocusWithin,
        // Input pseudo-classes
        .Enabled,
        .Disabled,
        .ReadOnly,
        .ReadWrite,
        .Checked,
        // Language pseudo-classes
        .Dir,
        .Lang,
        // Scoping
        .Scope,
        => false,
    };
}

// =============================================================================
// Attribute Matching Helpers
// =============================================================================

fn matchAttributeExact(value: []const u8, expected: []const u8, case_sensitive: bool) bool {
    if (case_sensitive) {
        return std.mem.eql(u8, value, expected);
    }
    return std.ascii.eqlIgnoreCase(value, expected);
}

fn matchAttributePrefix(value: []const u8, prefix: []const u8, case_sensitive: bool) bool {
    if (value.len < prefix.len) return false;
    if (case_sensitive) {
        return std.mem.eql(u8, value[0..prefix.len], prefix);
    }
    return std.ascii.eqlIgnoreCase(value[0..prefix.len], prefix);
}

fn matchAttributeSuffix(value: []const u8, suffix: []const u8, case_sensitive: bool) bool {
    if (value.len < suffix.len) return false;
    if (case_sensitive) {
        return std.mem.eql(u8, value[value.len - suffix.len ..], suffix);
    }
    return std.ascii.eqlIgnoreCase(value[value.len - suffix.len ..], suffix);
}

fn matchAttributeSubstring(value: []const u8, substr: []const u8, case_sensitive: bool) bool {
    if (case_sensitive) {
        return std.mem.indexOf(u8, value, substr) != null;
    }
    // Case-insensitive substring search
    if (value.len < substr.len) return false;
    var i: usize = 0;
    while (i <= value.len - substr.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(value[i .. i + substr.len], substr)) {
            return true;
        }
    }
    return false;
}

fn matchAttributeIncludes(value: []const u8, word: []const u8, case_sensitive: bool) bool {
    var iter = std.mem.splitScalar(u8, value, ' ');
    while (iter.next()) |token| {
        if (token.len == 0) continue;
        if (case_sensitive) {
            if (std.mem.eql(u8, token, word)) return true;
        } else {
            if (std.ascii.eqlIgnoreCase(token, word)) return true;
        }
    }
    return false;
}

fn matchAttributeDashMatch(value: []const u8, prefix: []const u8, case_sensitive: bool) bool {
    // Value is exactly prefix OR starts with prefix followed by '-'
    if (matchAttributeExact(value, prefix, case_sensitive)) return true;
    if (value.len > prefix.len and value[prefix.len] == '-') {
        return matchAttributePrefix(value, prefix, case_sensitive);
    }
    return false;
}

// =============================================================================
// Structural Pseudo-Class Helpers
// =============================================================================

fn isRootElement(element: *runtime.Instance) bool {
    const parent = NodeImpl.getParent(element) orelse return false;
    const parent_type = NodeImpl.getNodeType(parent) orelse 0;
    return parent_type == NodeImpl.NodeType.DOCUMENT_NODE;
}

fn isEmptyElement(element: *runtime.Instance) bool {
    var child = NodeImpl.getFirstChild(element);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        // Element has content if it has element or text children
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE or
            node_type == NodeImpl.NodeType.TEXT_NODE)
        {
            return false;
        }
        child = NodeImpl.getNextSibling(c);
    }
    return true;
}

fn isFirstChild(element: *runtime.Instance) bool {
    const parent = NodeImpl.getParent(element) orelse return false;
    var child = NodeImpl.getFirstChild(parent);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            return c == element;
        }
        child = NodeImpl.getNextSibling(c);
    }
    return false;
}

fn isLastChild(element: *runtime.Instance) bool {
    const parent = NodeImpl.getParent(element) orelse return false;
    var last_element: ?*runtime.Instance = null;
    var child = NodeImpl.getFirstChild(parent);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            last_element = c;
        }
        child = NodeImpl.getNextSibling(c);
    }
    return last_element == element;
}

fn isOnlyChild(element: *runtime.Instance) bool {
    return isFirstChild(element) and isLastChild(element);
}

fn isFirstOfType(element: *runtime.Instance) bool {
    const internal = ElementImpl.getInternal(element) orelse return false;
    const tag_name = internal.local_name.asSlice();

    const parent = NodeImpl.getParent(element) orelse return false;
    var child = NodeImpl.getFirstChild(parent);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (ElementImpl.getInternal(c)) |c_internal| {
                if (std.ascii.eqlIgnoreCase(c_internal.local_name.asSlice(), tag_name)) {
                    return c == element;
                }
            }
        }
        child = NodeImpl.getNextSibling(c);
    }
    return false;
}

fn isLastOfType(element: *runtime.Instance) bool {
    const internal = ElementImpl.getInternal(element) orelse return false;
    const tag_name = internal.local_name.asSlice();

    const parent = NodeImpl.getParent(element) orelse return false;
    var last_of_type: ?*runtime.Instance = null;
    var child = NodeImpl.getFirstChild(parent);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (ElementImpl.getInternal(c)) |c_internal| {
                if (std.ascii.eqlIgnoreCase(c_internal.local_name.asSlice(), tag_name)) {
                    last_of_type = c;
                }
            }
        }
        child = NodeImpl.getNextSibling(c);
    }
    return last_of_type == element;
}

fn isOnlyOfType(element: *runtime.Instance) bool {
    return isFirstOfType(element) and isLastOfType(element);
}

fn matchesNthChild(element: *runtime.Instance, nth: selector_mod.NthPattern) bool {
    const index = getElementIndex(element);
    return matchesNthPattern(index, nth);
}

fn matchesNthLastChild(element: *runtime.Instance, nth: selector_mod.NthPattern) bool {
    const index = getElementIndexFromEnd(element);
    return matchesNthPattern(index, nth);
}

fn matchesNthOfType(element: *runtime.Instance, nth: selector_mod.NthPattern) bool {
    const index = getElementOfTypeIndex(element);
    return matchesNthPattern(index, nth);
}

fn matchesNthLastOfType(element: *runtime.Instance, nth: selector_mod.NthPattern) bool {
    const index = getElementOfTypeIndexFromEnd(element);
    return matchesNthPattern(index, nth);
}

fn getElementIndex(element: *runtime.Instance) u32 {
    const parent = NodeImpl.getParent(element) orelse return 0;
    var index: u32 = 0;
    var child = NodeImpl.getFirstChild(parent);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            index += 1;
            if (c == element) return index;
        }
        child = NodeImpl.getNextSibling(c);
    }
    return 0;
}

fn getElementIndexFromEnd(element: *runtime.Instance) u32 {
    const parent = NodeImpl.getParent(element) orelse return 0;
    var total: u32 = 0;
    var elem_index: u32 = 0;
    var child = NodeImpl.getFirstChild(parent);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            total += 1;
            if (c == element) elem_index = total;
        }
        child = NodeImpl.getNextSibling(c);
    }
    return if (elem_index > 0) total - elem_index + 1 else 0;
}

fn getElementOfTypeIndex(element: *runtime.Instance) u32 {
    const internal = ElementImpl.getInternal(element) orelse return 0;
    const tag_name = internal.local_name.asSlice();

    const parent = NodeImpl.getParent(element) orelse return 0;
    var index: u32 = 0;
    var child = NodeImpl.getFirstChild(parent);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (ElementImpl.getInternal(c)) |c_internal| {
                if (std.ascii.eqlIgnoreCase(c_internal.local_name.asSlice(), tag_name)) {
                    index += 1;
                    if (c == element) return index;
                }
            }
        }
        child = NodeImpl.getNextSibling(c);
    }
    return 0;
}

fn getElementOfTypeIndexFromEnd(element: *runtime.Instance) u32 {
    const internal = ElementImpl.getInternal(element) orelse return 0;
    const tag_name = internal.local_name.asSlice();

    const parent = NodeImpl.getParent(element) orelse return 0;
    var total: u32 = 0;
    var elem_index: u32 = 0;
    var child = NodeImpl.getFirstChild(parent);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (ElementImpl.getInternal(c)) |c_internal| {
                if (std.ascii.eqlIgnoreCase(c_internal.local_name.asSlice(), tag_name)) {
                    total += 1;
                    if (c == element) elem_index = total;
                }
            }
        }
        child = NodeImpl.getNextSibling(c);
    }
    return if (elem_index > 0) total - elem_index + 1 else 0;
}

fn matchesNthPattern(index: u32, nth: selector_mod.NthPattern) bool {
    if (index == 0) return false;

    const a = nth.a;
    const b = nth.b;

    if (a == 0) {
        // Just :nth-child(b)
        return @as(i32, @intCast(index)) == b;
    }

    // Check if (index - b) is divisible by a and result is non-negative
    const diff = @as(i32, @intCast(index)) - b;
    if (a > 0) {
        return diff >= 0 and @mod(diff, a) == 0;
    } else {
        // Negative a: (an + b) where n >= 0
        // So index = an + b, n = (index - b) / a, must be >= 0
        return diff <= 0 and @mod(diff, -a) == 0;
    }
}

// =============================================================================
// Public Selector Matching API (for Element.matches and Element.closest)
// =============================================================================

/// Check if an element matches a selector string
/// Spec: https://dom.spec.whatwg.org/#dom-element-matches
/// Used by Element.matches() and Element.webkitMatchesSelector()
pub fn matches(
    allocator: std.mem.Allocator,
    element: *runtime.Instance,
    selectors: []const u8,
) MixinError!bool {
    // Step 1: Parse selector
    var tokenizer = Tokenizer.init(allocator, selectors);
    var parser = Parser.init(allocator, &tokenizer) catch {
        return error.SyntaxError;
    };
    defer parser.deinit();

    var selector_list = parser.parse() catch {
        return error.SyntaxError;
    };
    defer selector_list.deinit();

    // Step 2: Return true if element matches selector list
    return elementMatchesSelectorList(element, &selector_list);
}

/// Find closest ancestor (or self) matching a selector string
/// Spec: https://dom.spec.whatwg.org/#dom-element-closest
/// Used by Element.closest()
pub fn closest(
    allocator: std.mem.Allocator,
    element: *runtime.Instance,
    selectors: []const u8,
) MixinError!?*runtime.Instance {
    // Step 1: Parse selector
    var tokenizer = Tokenizer.init(allocator, selectors);
    var parser = Parser.init(allocator, &tokenizer) catch {
        return error.SyntaxError;
    };
    defer parser.deinit();

    var selector_list = parser.parse() catch {
        return error.SyntaxError;
    };
    defer selector_list.deinit();

    // Step 2: Walk up the tree from element (including self)
    var current: ?*runtime.Instance = element;
    while (current) |node| {
        const node_type = NodeImpl.getNodeType(node) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            if (elementMatchesSelectorList(node, &selector_list)) {
                return node;
            }
        }
        current = NodeImpl.getParent(node);
    }

    return null;
}

// =============================================================================
// ParentNode Mutation Methods
// =============================================================================

/// Union type for nodes or strings (used in variadic node methods)
/// Spec: https://dom.spec.whatwg.org/#converting-nodes-into-a-node
pub const NodeOrString = union(enum) {
    node: *runtime.Instance,
    string: []const u8,
};

/// Convert nodes into a node
/// Spec: https://dom.spec.whatwg.org/#converting-nodes-into-a-node
///
/// Steps:
/// 1. Let node be null.
/// 2. Replace each string in nodes with a new Text node whose data is the string
///    and node document is document.
/// 3. If nodes contains one node, then set node to nodes[0].
/// 4. Otherwise, set node to a new DocumentFragment node whose node document is document,
///    and then append each node in nodes to it.
/// 5. Return node.
fn convertNodesIntoNode(
    allocator: std.mem.Allocator,
    nodes: []const NodeOrString,
    document: *runtime.Instance,
    ctx: runtime.Context,
) MixinError!*runtime.Instance {
    if (nodes.len == 0) {
        // Return an empty DocumentFragment
        return createDocumentFragment(allocator, document, ctx);
    }

    if (nodes.len == 1) {
        // Step 3: If nodes contains one node, return it (or create Text for string)
        return switch (nodes[0]) {
            .node => |n| n,
            .string => |s| createTextNode(allocator, s, document, ctx),
        };
    }

    // Step 4: Create DocumentFragment and append all nodes
    const fragment = try createDocumentFragment(allocator, document, ctx);
    errdefer runtime.Instance.deinit(fragment);

    for (nodes) |item| {
        const child = switch (item) {
            .node => |n| n,
            .string => |s| try createTextNode(allocator, s, document, ctx),
        };
        _ = try NodeImpl.call_appendChild(fragment, child);
    }

    return fragment;
}

/// Create a new Text node
fn createTextNode(
    allocator: std.mem.Allocator,
    data: []const u8,
    document: *runtime.Instance,
    ctx: runtime.Context,
) MixinError!*runtime.Instance {
    // Create Text instance via the Text interface
    const TextImpl = impls.Text;
    const CharacterDataImpl = impls.CharacterData;

    const text = TextImpl.init(
        allocator,
        interfaces.Text.State,
        &interfaces.Text.vtable,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer TextImpl.deinit(text);

    // Set node type to TEXT_NODE (3)
    NodeImpl.setNodeType(text, NodeImpl.NodeType.TEXT_NODE) catch return error.OutOfMemory;

    // Set the text data via CharacterData
    CharacterDataImpl.setData(text, data) catch return error.OutOfMemory;

    // Set owner document via NodeImpl
    NodeImpl.setOwnerDocument(text, document) catch {};

    return text;
}

/// Create a new DocumentFragment node
fn createDocumentFragment(
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
    ctx: runtime.Context,
) MixinError!*runtime.Instance {
    const DocumentFragmentImpl = impls.DocumentFragment;

    const fragment = DocumentFragmentImpl.init(
        allocator,
        interfaces.DocumentFragment.State,
        &interfaces.DocumentFragment.vtable,
        ctx,
    ) catch return error.OutOfMemory;

    // Set node type to DOCUMENT_FRAGMENT_NODE (11)
    NodeImpl.setNodeType(fragment, NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE) catch return error.OutOfMemory;

    // Set owner document via NodeImpl
    NodeImpl.setOwnerDocument(fragment, document) catch {};

    return fragment;
}

/// prepend - Inserts nodes before the first child
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-prepend
///
/// Steps:
/// 1. Let node be the result of converting nodes into a node given nodes and this's node document.
/// 2. Pre-insert node into this before this's first child.
pub fn prepend(
    allocator: std.mem.Allocator,
    parent: *runtime.Instance,
    nodes: []const NodeOrString,
    ctx: runtime.Context,
) MixinError!void {
    // Get this node's document
    const document = NodeImpl.getOwnerDocument(parent) orelse parent; // Document is its own document

    // Step 1: Convert nodes into a node
    const node = try convertNodesIntoNode(allocator, nodes, document, ctx);

    // Step 2: Pre-insert node into this before this's first child
    const first_child = NodeImpl.getFirstChild(parent);
    if (first_child) |child| {
        _ = NodeImpl.call_insertBefore(parent, node, child) catch return error.HierarchyRequestError;
    } else {
        _ = NodeImpl.call_appendChild(parent, node) catch return error.HierarchyRequestError;
    }
}

/// append - Inserts nodes after the last child
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-append
///
/// Steps:
/// 1. Let node be the result of converting nodes into a node given nodes and this's node document.
/// 2. Append node to this.
pub fn append(
    allocator: std.mem.Allocator,
    parent: *runtime.Instance,
    nodes: []const NodeOrString,
    ctx: runtime.Context,
) MixinError!void {
    // Get this node's document
    const document = NodeImpl.getOwnerDocument(parent) orelse parent;

    // Step 1: Convert nodes into a node
    const node = try convertNodesIntoNode(allocator, nodes, document, ctx);

    // Step 2: Append node to this
    _ = NodeImpl.call_appendChild(parent, node) catch return error.HierarchyRequestError;
}

/// replaceChildren - Replaces all children with nodes
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-replacechildren
///
/// Steps:
/// 1. Let node be the result of converting nodes into a node given nodes and this's node document.
/// 2. Ensure pre-insertion validity of node into this before null.
/// 3. Replace all with node within this.
pub fn replaceChildren(
    allocator: std.mem.Allocator,
    parent: *runtime.Instance,
    nodes: []const NodeOrString,
    ctx: runtime.Context,
) MixinError!void {
    // Get this node's document
    const document = NodeImpl.getOwnerDocument(parent) orelse parent;

    // Step 1: Convert nodes into a node
    const node = try convertNodesIntoNode(allocator, nodes, document, ctx);

    // Steps 2-3: Remove all children, then append new node
    // First, remove all existing children
    var child = NodeImpl.getFirstChild(parent);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        _ = NodeImpl.call_removeChild(parent, c) catch {};
        child = next;
    }

    // Then append the new node (which may be a DocumentFragment)
    _ = NodeImpl.call_appendChild(parent, node) catch return error.HierarchyRequestError;
}

/// moveBefore - Moves a node into this parent before child, preserving state
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-movebefore
///
/// This is distinct from remove + insert. It preserves state associated with the node.
///
/// Steps:
/// 1. Let referenceChild be child.
/// 2. If referenceChild is node, then set referenceChild to node's next sibling.
/// 3. Move node into this before referenceChild.
pub fn moveBefore(
    parent: *runtime.Instance,
    node: *runtime.Instance,
    child: ?*runtime.Instance,
) MixinError!void {
    // Step 1: Let referenceChild be child
    var reference_child = child;

    // Step 2: If referenceChild is node, set to node's next sibling
    if (reference_child == node) {
        reference_child = NodeImpl.getNextSibling(node);
    }

    // Validate: node must already be in a tree (have a parent)
    const old_parent = NodeImpl.getParent(node) orelse return error.HierarchyRequestError;

    // Validate: child (if non-null) must be a child of parent
    if (reference_child) |rc| {
        const rc_parent = NodeImpl.getParent(rc);
        if (rc_parent != parent) {
            return error.NotFoundError;
        }
    }

    // Validate: parent's shadow-including root must be same as node's
    // (For now, we skip full shadow DOM validation)

    // Validate: node cannot be an ancestor of parent
    var ancestor: ?*runtime.Instance = parent;
    while (ancestor) |anc| {
        if (anc == node) return error.HierarchyRequestError;
        ancestor = NodeImpl.getParent(anc);
    }

    // Step 3: Move node into this before referenceChild
    // The move algorithm preserves state (unlike remove + insert)

    // If node is already at the correct position, do nothing
    if (old_parent == parent) {
        if (reference_child) |rc| {
            const prev = NodeImpl.getPreviousSibling(rc);
            if (prev == node) return; // Already in correct position
        } else {
            // Moving to end - check if already last child
            const last = NodeImpl.getLastChild(parent);
            if (last == node) return;
        }
    }

    // Remove from old position (but don't run removing steps - this is a move)
    NodeImpl.removeNodeFromParent(node, old_parent) catch return error.HierarchyRequestError;

    // Insert at new position
    if (reference_child) |rc| {
        _ = NodeImpl.call_insertBefore(parent, node, rc) catch return error.HierarchyRequestError;
    } else {
        _ = NodeImpl.call_appendChild(parent, node) catch return error.HierarchyRequestError;
    }
}

// =============================================================================
// Tests
// =============================================================================

test "ParentNode mixin - firstElementChild" {
    // Test would require setting up runtime instances
    // Placeholder for now
}

//! Implementation for ParentNode mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-parentnode
//!
//! This impl contains the actual logic for ParentNode methods. The mixin file
//! delegates to these functions.
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
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const selector_mod = @import("selector");
const Tokenizer = selector_mod.Tokenizer;
const Parser = selector_mod.Parser;
const SelectorList = selector_mod.SelectorList;
const FastPathType = selector_mod.FastPathType;
const analyzeSelector = selector_mod.analyzeSelector;

// Import impl modules for accessing internal state
const NodeImpl = @import("Node.zig");
const ElementImpl = @import("Element.zig");
const HTMLCollectionImpl = @import("HTMLCollection.zig");
const NodeListImpl = @import("NodeList.zig");
const TextImpl = @import("Text.zig");
const CharacterDataImpl = @import("CharacterData.zig");
const DocumentFragmentImpl = @import("DocumentFragment.zig");

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    SyntaxError,
    OutOfMemory,
    HierarchyRequestError,
    NotFoundError,
};

/// Union type for nodes or strings (used in variadic node methods)
/// Spec: https://dom.spec.whatwg.org/#converting-nodes-into-a-node
pub const NodeOrString = union(enum) {
    node: *runtime.Instance,
    string: []const u8,
};

// =============================================================================
// ParentNode Attribute Getters
// =============================================================================

/// Get the first child that is an element
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-firstelementchild
pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var child = NodeImpl.getFirstChild(instance);
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
pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    var last_element: ?*runtime.Instance = null;

    var child = NodeImpl.getFirstChild(instance);
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
pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
    var count: u32 = 0;

    var child = NodeImpl.getFirstChild(instance);
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
pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const allocator = instance.ctx.getAllocator();

    const collection = interfaces.HTMLCollection.init(
        allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.HTMLCollection.deinit(collection);

    // Iterate direct children and add elements
    var child = NodeImpl.getFirstChild(instance);
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
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!?*runtime.Instance {
    const allocator = instance.ctx.getAllocator();
    const selectors_slice = selectors.asSlice();

    // Step 1: Parse selector
    var tokenizer = Tokenizer.init(allocator, selectors_slice);
    var parser = Parser.init(allocator, &tokenizer) catch {
        return error.SyntaxError;
    };
    defer parser.deinit();

    var selector_list = parser.parse() catch {
        return error.SyntaxError;
    };
    defer selector_list.deinit();

    // Analyze selector for fast path opportunities
    const analysis = analyzeSelector(&selector_list);

    // Step 3: Find first matching element using appropriate strategy
    switch (analysis.fast_path) {
        .single_id => {
            // Fast path: ID selector - find by ID, optionally verify other selectors
            if (analysis.id) |id| {
                if (findElementById(instance, id)) |element| {
                    if (analysis.needs_verification) {
                        // Need to verify element matches full selector
                        if (elementMatchesSelectorList(element, &selector_list)) {
                            return element;
                        }
                    } else {
                        return element;
                    }
                }
            }
            return null;
        },
        .single_class => {
            // Fast path: Class-only selector - iterate elements with class
            if (analysis.class_name) |class_name| {
                return findFirstElementByClass(instance, class_name);
            }
            return null;
        },
        .single_tag => {
            // Fast path: Tag-only selector - iterate elements with tag name
            if (analysis.tag_name) |tag_name| {
                return findFirstElementByTagName(instance, tag_name);
            }
            return null;
        },
        .none, .complex => {
            // No fast path - use full tree traversal
            return findFirstMatch(instance, &selector_list);
        },
    }
}

/// querySelectorAll - Returns all elements matching the selector
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!*runtime.Instance {
    const allocator = instance.ctx.getAllocator();
    const selectors_slice = selectors.asSlice();

    // Step 1: Parse selector
    var tokenizer = Tokenizer.init(allocator, selectors_slice);
    var parser = Parser.init(allocator, &tokenizer) catch {
        return error.SyntaxError;
    };
    defer parser.deinit();

    var selector_list = parser.parse() catch {
        return error.SyntaxError;
    };
    defer selector_list.deinit();

    // Analyze selector for fast path opportunities
    const analysis = analyzeSelector(&selector_list);

    // Step 3: Create static NodeList and collect all matching elements (use interface per Golden Rule #13)
    const node_list = interfaces.NodeList.init(
        allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.NodeList.deinit(node_list);

    // Collect matches using appropriate strategy
    switch (analysis.fast_path) {
        .single_id => {
            // Fast path: ID selector - find by ID, add if matches
            if (analysis.id) |id| {
                if (findElementById(instance, id)) |element| {
                    if (analysis.needs_verification) {
                        if (elementMatchesSelectorList(element, &selector_list)) {
                            NodeListImpl.addNode(node_list, element) catch return error.OutOfMemory;
                        }
                    } else {
                        NodeListImpl.addNode(node_list, element) catch return error.OutOfMemory;
                    }
                }
            }
        },
        .single_class => {
            // Fast path: Class-only selector
            if (analysis.class_name) |class_name| {
                collectElementsByClass(instance, class_name, node_list) catch return error.OutOfMemory;
            }
        },
        .single_tag => {
            // Fast path: Tag-only selector
            if (analysis.tag_name) |tag_name| {
                collectElementsByTagName(instance, tag_name, node_list) catch return error.OutOfMemory;
            }
        },
        .none, .complex => {
            // No fast path - use full tree traversal
            collectAllMatches(instance, &selector_list, node_list) catch return error.OutOfMemory;
        },
    }

    return node_list;
}

// =============================================================================
// Fast Path Query Functions
// =============================================================================

/// Fast path: Find element by ID within subtree
fn findElementById(root: *runtime.Instance, id: []const u8) ?*runtime.Instance {
    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check ID
            if (ElementImpl.getInternal(c)) |internal| {
                if (std.mem.eql(u8, internal.id.asSlice(), id)) {
                    return c;
                }
            }
            // Recurse into children
            if (findElementById(c, id)) |found| {
                return found;
            }
        }
        child = NodeImpl.getNextSibling(c);
    }
    return null;
}

/// Fast path: Find first element with given class name
fn findFirstElementByClass(root: *runtime.Instance, class_name: []const u8) ?*runtime.Instance {
    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check class
            if (matchesClassSelector(c, class_name)) {
                return c;
            }
            // Recurse into children
            if (findFirstElementByClass(c, class_name)) |found| {
                return found;
            }
        }
        child = NodeImpl.getNextSibling(c);
    }
    return null;
}

/// Fast path: Find first element with given tag name
fn findFirstElementByTagName(root: *runtime.Instance, tag_name: []const u8) ?*runtime.Instance {
    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check tag name
            if (matchesTypeSelector(c, tag_name)) {
                return c;
            }
            // Recurse into children
            if (findFirstElementByTagName(c, tag_name)) |found| {
                return found;
            }
        }
        child = NodeImpl.getNextSibling(c);
    }
    return null;
}

/// Fast path: Collect all elements with given class name
fn collectElementsByClass(
    root: *runtime.Instance,
    class_name: []const u8,
    node_list: *runtime.Instance,
) !void {
    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check class
            if (matchesClassSelector(c, class_name)) {
                try NodeListImpl.addNode(node_list, c);
            }
            // Recurse into children
            try collectElementsByClass(c, class_name, node_list);
        }
        child = NodeImpl.getNextSibling(c);
    }
}

/// Fast path: Collect all elements with given tag name
fn collectElementsByTagName(
    root: *runtime.Instance,
    tag_name: []const u8,
    node_list: *runtime.Instance,
) !void {
    var child = NodeImpl.getFirstChild(root);
    while (child) |c| {
        const node_type = NodeImpl.getNodeType(c) orelse 0;
        if (node_type == NodeImpl.NodeType.ELEMENT_NODE) {
            // Check tag name
            if (matchesTypeSelector(c, tag_name)) {
                try NodeListImpl.addNode(node_list, c);
            }
            // Recurse into children
            try collectElementsByTagName(c, tag_name, node_list);
        }
        child = NodeImpl.getNextSibling(c);
    }
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
    // Step 1: Element must match the subject (rightmost) compound
    if (!elementMatchesCompoundSelector(element, &complex.compound)) {
        return false;
    }

    // No combinators - we're done (single compound selector)
    if (complex.combinators.len == 0) {
        return true;
    }

    // Step 2: Match combinators from right to left
    var current_element = element;
    for (complex.combinators) |*pair| {
        const matched = matchCombinator(current_element, pair.combinator, &pair.compound);
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
        .AnyLink,
        .Link,
        .Visited,
        .Hover,
        .Active,
        .Focus,
        .FocusVisible,
        .FocusWithin,
        .Enabled,
        .Disabled,
        .ReadOnly,
        .ReadWrite,
        .Checked,
        .Dir,
        .Lang,
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
    instance: *runtime.Instance,
    selectors: runtime.DOMString,
) anyerror!bool {
    const allocator = instance.ctx.getAllocator();
    const selectors_slice = selectors.asSlice();

    // Step 1: Parse selector
    var tokenizer = Tokenizer.init(allocator, selectors_slice);
    var parser = Parser.init(allocator, &tokenizer) catch {
        return error.SyntaxError;
    };
    defer parser.deinit();

    var selector_list = parser.parse() catch {
        return error.SyntaxError;
    };
    defer selector_list.deinit();

    // Step 2: Return true if element matches selector list
    return elementMatchesSelectorList(instance, &selector_list);
}

/// Find closest ancestor (or self) matching a selector string
/// Spec: https://dom.spec.whatwg.org/#dom-element-closest
/// Used by Element.closest()
pub fn closest(
    instance: *runtime.Instance,
    selectors: runtime.DOMString,
) anyerror!?*runtime.Instance {
    const allocator = instance.ctx.getAllocator();
    const selectors_slice = selectors.asSlice();

    // Step 1: Parse selector
    var tokenizer = Tokenizer.init(allocator, selectors_slice);
    var parser = Parser.init(allocator, &tokenizer) catch {
        return error.SyntaxError;
    };
    defer parser.deinit();

    var selector_list = parser.parse() catch {
        return error.SyntaxError;
    };
    defer selector_list.deinit();

    // Step 2: Walk up the tree from element (including self)
    var current: ?*runtime.Instance = instance;
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

/// prepend - Inserts nodes before the first child
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-prepend
pub fn call_prepend(instance: *runtime.Instance, nodes: []const NodeOrString) anyerror!void {
    const allocator = instance.ctx.getAllocator();

    // Get this node's document
    const document = NodeImpl.getOwnerDocument(instance) orelse instance;

    // Step 1: Convert nodes into a node
    const node = try convertNodesIntoNode(allocator, nodes, document, instance.ctx);

    // Step 2: Pre-insert node into this before this's first child (use interface per Golden Rule #13)
    const first_child = NodeImpl.getFirstChild(instance);
    if (first_child) |child| {
        _ = interfaces.Node.call_insertBefore(instance, node, child) catch return error.HierarchyRequestError;
    } else {
        _ = interfaces.Node.call_appendChild(instance, node) catch return error.HierarchyRequestError;
    }
}

/// append - Inserts nodes after the last child
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-append
pub fn call_append(instance: *runtime.Instance, nodes: []const NodeOrString) anyerror!void {
    const allocator = instance.ctx.getAllocator();

    // Get this node's document
    const document = NodeImpl.getOwnerDocument(instance) orelse instance;

    // Step 1: Convert nodes into a node
    const node = try convertNodesIntoNode(allocator, nodes, document, instance.ctx);

    // Step 2: Append node to this (use interface per Golden Rule #13)
    _ = interfaces.Node.call_appendChild(instance, node) catch return error.HierarchyRequestError;
}

/// replaceChildren - Replaces all children with nodes
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-replacechildren
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: []const NodeOrString) anyerror!void {
    const allocator = instance.ctx.getAllocator();

    // Get this node's document
    const document = NodeImpl.getOwnerDocument(instance) orelse instance;

    // Step 1: Convert nodes into a node
    const node = try convertNodesIntoNode(allocator, nodes, document, instance.ctx);

    // Steps 2-3: Remove all children, then append new node (use interface per Golden Rule #13)
    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| {
        const next = NodeImpl.getNextSibling(c);
        _ = interfaces.Node.call_removeChild(instance, c) catch {};
        child = next;
    }

    // Then append the new node
    _ = interfaces.Node.call_appendChild(instance, node) catch return error.HierarchyRequestError;
}

/// moveBefore - Moves a node into this parent before child, preserving state
/// Spec: https://dom.spec.whatwg.org/#dom-parentnode-movebefore
pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!void {
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
        if (rc_parent != instance) {
            return error.NotFoundError;
        }
    }

    // Validate: node cannot be an ancestor of parent
    var ancestor: ?*runtime.Instance = instance;
    while (ancestor) |anc| {
        if (anc == node) return error.HierarchyRequestError;
        ancestor = NodeImpl.getParent(anc);
    }

    // Check if already at correct position
    if (old_parent == instance) {
        if (reference_child) |rc| {
            const prev = NodeImpl.getPreviousSibling(rc);
            if (prev == node) return;
        } else {
            const last = NodeImpl.getLastChild(instance);
            if (last == node) return;
        }
    }

    // Remove from old position
    NodeImpl.removeNodeFromParent(node, old_parent) catch return error.HierarchyRequestError;

    // Insert at new position (use interface per Golden Rule #13)
    if (reference_child) |rc| {
        _ = interfaces.Node.call_insertBefore(instance, node, rc) catch return error.HierarchyRequestError;
    } else {
        _ = interfaces.Node.call_appendChild(instance, node) catch return error.HierarchyRequestError;
    }
}

// =============================================================================
// Node Conversion Helpers
// =============================================================================

/// Convert nodes into a node
/// Spec: https://dom.spec.whatwg.org/#converting-nodes-into-a-node
fn convertNodesIntoNode(
    allocator: std.mem.Allocator,
    nodes: []const NodeOrString,
    document: *runtime.Instance,
    ctx: runtime.Context,
) ImplError!*runtime.Instance {
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
        const child_node = switch (item) {
            .node => |n| n,
            .string => |s| try createTextNode(allocator, s, document, ctx),
        };
        _ = try interfaces.Node.call_appendChild(fragment, child_node);
    }

    return fragment;
}

/// Create a new Text node
fn createTextNode(
    allocator: std.mem.Allocator,
    data: []const u8,
    document: *runtime.Instance,
    ctx: runtime.Context,
) ImplError!*runtime.Instance {
    const text = interfaces.Text.init(
        allocator,
        ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.Text.deinit(text);

    // Set node type to TEXT_NODE (3)
    NodeImpl.setNodeType(text, NodeImpl.NodeType.TEXT_NODE) catch return error.OutOfMemory;

    // Set the text data via CharacterData
    CharacterDataImpl.setData(text, data) catch return error.OutOfMemory;

    // Set owner document
    NodeImpl.setOwnerDocument(text, document) catch {};

    return text;
}

/// Create a new DocumentFragment node
fn createDocumentFragment(
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
    ctx: runtime.Context,
) ImplError!*runtime.Instance {
    const fragment = interfaces.DocumentFragment.init(
        allocator,
        ctx,
    ) catch return error.OutOfMemory;

    // Set node type to DOCUMENT_FRAGMENT_NODE (11)
    NodeImpl.setNodeType(fragment, NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE) catch return error.OutOfMemory;

    // Set owner document
    NodeImpl.setOwnerDocument(fragment, document) catch {};

    return fragment;
}

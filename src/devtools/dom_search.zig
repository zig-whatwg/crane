//! DOM.performSearch's matching (lane cdpd1, batch 2): Blink's
//! InspectorDOMAgent::performSearch at Chrome 157.0.8103.78
//! (third_party/blink/renderer/core/inspector/inspector_dom_agent.cc;
//! Apple/Google BSD - reproduced, not copied). Three passes over each
//! inspected document, into one ordered set of nodes:
//!
//! 1. the query as a selector, on the document and on each shadow root
//!    (NextNodeWithShadowDOMInMind's walk; user-agent shadow roots only on
//!    request - Crane's form controls have none a page can reach);
//! 2. a plain-text search: a text, comment or CDATA node whose value holds
//!    the query (ASCII case-insensitive, WTF's DeprecatedFindIgnoringCase);
//!    an element whose name matches the query's tag form ("<div>" exactly,
//!    "<di" a prefix, "iv>" a suffix, else a substring), or one of whose
//!    attribute names holds the query, or whose value matches the quoted or
//!    unquoted query (157's attribute_value_matcher: equal when quoted, a
//!    substring otherwise);
//! 3. the query as an XPath expression, an ordered snapshot, an attribute
//!    result standing for its owner element.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

/// The search's results: Blink's HeapLinkedHashSet - each node once, in the
/// order first found.
pub const Results = struct {
    nodes: std.ArrayListUnmanaged(*runtime.Instance) = .empty,
    seen: std.AutoHashMapUnmanaged(usize, void) = .empty,

    pub fn deinit(self: *Results, allocator: Allocator) void {
        self.nodes.deinit(allocator);
        self.seen.deinit(allocator);
    }

    fn insert(self: *Results, allocator: Allocator, node: *runtime.Instance) Allocator.Error!void {
        const got = try self.seen.getOrPut(allocator, @intFromPtr(node));
        if (got.found_existing) return;
        try self.nodes.append(allocator, node);
    }
};

/// The query's tag form (157: kSubstring, kExact, kPrefix, kSuffix) and its
/// attribute form.
const Query = struct {
    whole: []const u8,
    tag: []const u8,
    tag_match: enum { substring, exact, prefix, suffix },
    attribute: []const u8,
    exact_attribute: bool,

    fn of(query: []const u8) Query {
        var tag = query;
        var start_tag = false;
        if (std.mem.startsWith(u8, tag, "</")) {
            tag = tag[2..];
            start_tag = true;
        } else if (std.mem.startsWith(u8, tag, "<")) {
            tag = tag[1..];
            start_tag = true;
        }
        var end_tag = false;
        if (std.mem.endsWith(u8, tag, ">")) {
            tag = tag[0 .. tag.len - 1];
            end_tag = true;
        }
        var attribute = query;
        var start_quote = false;
        if (std.mem.startsWith(u8, attribute, "\"")) {
            attribute = attribute[1..];
            start_quote = true;
        }
        var end_quote = false;
        if (std.mem.endsWith(u8, attribute, "\"")) {
            attribute = attribute[0 .. attribute.len - 1];
            end_quote = true;
        }
        return .{
            .whole = query,
            .tag = tag,
            .tag_match = if (!start_tag and !end_tag) .substring else if (start_tag and end_tag) .exact else if (start_tag) .prefix else .suffix,
            .attribute = attribute,
            .exact_attribute = start_quote and end_quote,
        };
    }

    fn elementNameMatches(self: Query, name: []const u8) bool {
        return switch (self.tag_match) {
            .substring => containsIgnoringCase(name, self.tag),
            .exact => std.ascii.eqlIgnoreCase(name, self.tag),
            .prefix => std.ascii.startsWithIgnoreCase(name, self.tag),
            .suffix => std.ascii.endsWithIgnoreCase(name, self.tag),
        };
    }

    fn attributeValueMatches(self: Query, value: []const u8) bool {
        if (self.exact_attribute) return std.ascii.eqlIgnoreCase(value, self.attribute);
        return containsIgnoringCase(value, self.attribute);
    }
};

/// WTF's DeprecatedFindIgnoringCase != kNotFound (ASCII case folding).
fn containsIgnoringCase(haystack: []const u8, needle: []const u8) bool {
    return std.ascii.findIgnoreCase(haystack, needle) != null;
}

/// Search `documents` for `query` (already whitespace-trimmed, as the
/// protocol's caller sends it), into `results`.
pub fn search(allocator: Allocator, documents: []const *runtime.Instance, query: []const u8, include_user_agent_shadow_dom: bool, results: *Results) Allocator.Error!void {
    _ = include_user_agent_shadow_dom;
    const q = Query.of(query);
    // Selector evaluation: the document, then each shadow root.
    for (documents) |document| {
        try selectInto(allocator, document, query, results);
        const document_element = documentElementOf(document) orelse continue;
        var node: ?*runtime.Instance = document_element;
        while (node) |n| : (node = nextWithShadowRoots(n, document_element)) {
            if (n.implements(interfaces.ShadowRoot.State)) try selectInto(allocator, n, query, results);
        }
    }
    // Manual plain text search.
    for (documents) |document| {
        const document_element = documentElementOf(document) orelse continue;
        var node: ?*runtime.Instance = document_element;
        while (node) |n| : (node = nextWithShadowRoots(n, document_element)) {
            switch (interfaces.Node.get_nodeType(n) catch 0) {
                // TEXT, COMMENT, CDATA_SECTION
                3, 8, 4 => {
                    const value = dom.character_data.dataOf(n) orelse continue;
                    if (containsIgnoringCase(value, query)) try results.insert(allocator, n);
                },
                1 => {
                    var name = interfaces.Node.get_nodeName(n) catch continue;
                    defer name.deinit(n.ctx.allocator);
                    if (q.elementNameMatches(name.asSlice())) {
                        try results.insert(allocator, n);
                        continue;
                    }
                    const count = dom.element_attributes.count(n);
                    for (0..count) |i| {
                        const attribute = dom.element_attributes.at(n, i) orelse continue;
                        if (containsIgnoringCase(attribute.local_name, query) or q.attributeValueMatches(attribute.value)) {
                            try results.insert(allocator, n);
                            break;
                        }
                    }
                },
                else => {},
            }
        }
    }
    // XPath evaluation.
    for (documents) |document| try xpathInto(allocator, document, query, results);
}

fn documentElementOf(document: *runtime.Instance) ?*runtime.Instance {
    return interfaces.Document.get_documentElement(document) catch null;
}

/// `root`.querySelectorAll(query), each match into `results`; a query that
/// is no selector finds nothing.
fn selectInto(allocator: Allocator, root: *runtime.Instance, query: []const u8, results: *Results) Allocator.Error!void {
    var selectors = runtime.DOMString.initDupe(allocator, query) catch return error.OutOfMemory;
    defer selectors.deinit(allocator);
    const list = interfaces.ParentNode.call_querySelectorAll(root, selectors) catch return;
    const generation = runtime.SlabAllocator.generationOf(list);
    defer list.releaseIfUnwrapped(generation);
    const length = interfaces.NodeList.get_length(list) catch 0;
    var i: u32 = 0;
    while (i < length) : (i += 1) {
        const node = (interfaces.NodeList.call_item(list, i) catch null) orelse continue;
        try results.insert(allocator, node);
    }
}

/// XPathEvaluator.evaluate(query, document, null, ORDERED_NODE_SNAPSHOT_TYPE)
/// - an expression that does not parse or evaluate to nodes finds nothing;
/// an Attr result stands for its owner element.
fn xpathInto(allocator: Allocator, document: *runtime.Instance, query: []const u8, results: *Results) Allocator.Error!void {
    var expression = runtime.DOMString.initDupe(allocator, query) catch return error.OutOfMemory;
    defer expression.deinit(allocator);
    const ordered_node_snapshot_type: u16 = 7;
    const result = interfaces.Document.call_evaluate(document, expression, document, .notPassed(), .passed(ordered_node_snapshot_type), .notPassed()) catch return;
    const generation = runtime.SlabAllocator.generationOf(result);
    defer result.releaseIfUnwrapped(generation);
    const length = interfaces.XPathResult.get_snapshotLength(result) catch return;
    var i: u32 = 0;
    while (i < length) : (i += 1) {
        var node = (interfaces.XPathResult.call_snapshotItem(result, i) catch return) orelse continue;
        if ((interfaces.Node.get_nodeType(node) catch 0) == 2) {
            node = (interfaces.Attr.get_ownerElement(node) catch null) orelse continue;
        }
        try results.insert(allocator, node);
    }
}

/// NextNodeWithShadowDOMInMind: `current`'s shadow root, else its first
/// child, else the next sibling of it or of an ancestor - a shadow root's
/// "next" being its host's first child - within `stay_within`.
fn nextWithShadowRoots(current: *runtime.Instance, stay_within: *runtime.Instance) ?*runtime.Instance {
    if ((interfaces.Node.get_nodeType(current) catch 0) == 1) {
        if (dom.shadow_hosts.rootForHost(current)) |root| return root;
    }
    if (interfaces.Node.get_firstChild(current) catch null) |child| return child;
    var node: ?*runtime.Instance = current;
    while (node) |n| {
        if (n == stay_within) return null;
        const is_shadow_root = n.implements(interfaces.ShadowRoot.State);
        if (is_shadow_root) {
            const host = interfaces.ShadowRoot.get_host(n) catch return null;
            if (interfaces.Node.get_firstChild(host) catch null) |child| return child;
        }
        if (interfaces.Node.get_nextSibling(n) catch null) |sibling| return sibling;
        node = if (is_shadow_root) (interfaces.ShadowRoot.get_host(n) catch null) else (interfaces.Node.get_parentNode(n) catch null);
    }
    return null;
}

test "a query's tag form and attribute form, as Blink 157 reads them" {
    const exact = Query.of("<div>");
    try std.testing.expect(exact.tag_match == .exact and std.mem.eql(u8, exact.tag, "div"));
    try std.testing.expect(exact.elementNameMatches("DIV") and !exact.elementNameMatches("DIVX"));
    const prefix = Query.of("</sp");
    try std.testing.expect(prefix.tag_match == .prefix and prefix.elementNameMatches("SPAN"));
    const suffix = Query.of("an>");
    try std.testing.expect(suffix.tag_match == .suffix and suffix.elementNameMatches("SPAN"));
    const quoted = Query.of("\"a\"");
    try std.testing.expect(quoted.exact_attribute and quoted.attributeValueMatches("A") and !quoted.attributeValueMatches("ab"));
    const bare = Query.of("a");
    try std.testing.expect(!bare.exact_attribute and bare.attributeValueMatches("cat"));
}

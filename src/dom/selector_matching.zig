//! Matching parsed selectors (src/selector/) against the DOM's elements:
//! DOM's querySelector, querySelectorAll, matches, webkitMatchesSelector
//! and closest.
//!
//! Spec:
//! - DOM 1.3 "scope-match a selectors string", 4.9 matches() / closest()
//! - Selectors 4 17.3 "match a selector against an element", 17.5 "match a
//!   selector against a tree" (specs/w3c/selectors-4.md)
//! - HTML 4.16.2 "Case-sensitivity of selectors" (specs/whatwg/html.md)
//! - CSS Scoping 3.1.1: for selectors matched in a shadow tree, the shadow
//!   host is the featureless parent of the tree's top-level elements.
//!
//! The walk follows the tree's own links (NodeBase) and reads an element's
//! names, ID, classes and attributes in place (dom.element_data); runtime
//! state - focus, form controls, custom states - comes through the owners'
//! hooks. No impl is named here (AGENTS.md "The impls boundary").
//!
//! Complex selectors match right to left with Stylo's failure results
//! (servo/components/selectors/matching.rs, matches_complex_selector_internal):
//! a failed combinator step says how far back to restart, which keeps
//! `a b c d` linear in depth rather than exponential.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const selector = @import("selector");
const NodeBase = @import("node_base.zig").NodeBase;
const instance_bridge = @import("instance_bridge.zig");
const element_data = @import("element_data.zig");
const attribute_values = @import("attribute_values.zig");
/// A reader's view of an element's data: its attributes' ids decode with its
/// Browser's tables (lane nd2 batch 2). Passed by value.
const ElementData = element_data.View;
const AttributeEntry = element_data.AttributeEntry;
const html_pseudo_classes = @import("html_pseudo_classes.zig");
const focus_matching = @import("focus_matching.zig");
const custom_elements = @import("custom_elements.zig");
const target_element = @import("target_element.zig");
const document_internals = @import("document_internals.zig");

const SelectorList = selector.SelectorList;
const ComplexSelector = selector.ComplexSelector;
const CompoundSelector = selector.CompoundSelector;
const SimpleSelector = selector.SimpleSelector;
const Combinator = selector.Combinator;
const AttributeSelector = selector.AttributeSelector;
const PseudoClassKind = selector.PseudoClassKind;
const NthPattern = selector.NthPattern;

const debug_checks = @import("builtin").mode == .debug;

const ELEMENT_NODE: u16 = 1;
const DOCUMENT_NODE: u16 = 9;
const DOCUMENT_FRAGMENT_NODE: u16 = 11;
const TEXT_NODE: u16 = 3;
const CDATA_SECTION_NODE: u16 = 4;

const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";
const xml_namespace = "http://www.w3.org/XML/1998/namespace";

pub const Error = error{ SyntaxError, OutOfMemory };

// ============================================================================
// DOM entry points
// ============================================================================

/// DOM querySelector(selectors): the first element, in tree order, among
/// `scope`'s descendants that scope-matches `selectors`; null when none.
///
/// The selector comes parsed from the document's cache (`Selectors`), and
/// one with an ID selector finds its candidates through the tree scope's ID
/// map (`IdPlan`): the general walk's answer, without walking the tree.
pub fn querySelector(scope: *runtime.Instance, selectors: []const u8) Error!?*runtime.Instance {
    const scope_node = instance_bridge.getNodeBase(scope) orelse return querySelectorGeneral(scope, selectors);
    var matcher = Matcher.initForQuery(scope_node, scope);
    // DOM "scope-match a selectors string" steps 1-2: parse, or throw.
    var parsed = try Selectors.get(matcher.document, scope.ctx.getAllocator(), selectors);
    defer parsed.deinit();
    const list = parsed.list();
    var nth_cache = NthIndexCache{ .allocator = scope.ctx.getAllocator() };
    defer nth_cache.deinit();
    matcher.nth_cache = &nth_cache;
    const fast = FastPath.of(list);
    var first: ?*NodeBase = null;
    const Sink = struct {
        fn take(out: *?*NodeBase, node: *NodeBase) error{OutOfMemory}!bool {
            out.* = node;
            return false;
        }
    };
    if (try forEachById(&matcher, scope_node, list, fast, &first, Sink.take)) return if (first) |node| instanceOf(node) else null;
    var walk = Walk.init(scope_node);
    while (walk.next()) |node| {
        if (matcher.matchesForQuery(node, list, fast)) return instanceOf(node);
    }
    return null;
}

/// DOM querySelectorAll(selectors): every element among `scope`'s
/// descendants that scope-matches `selectors`, in tree order, appended to
/// `out` as tree nodes. Parsed and searched as `querySelector` is.
pub fn querySelectorAll(allocator: std.mem.Allocator, scope: *runtime.Instance, selectors: []const u8, out: *std.ArrayList(*NodeBase)) Error!void {
    const scope_node = instance_bridge.getNodeBase(scope) orelse return querySelectorAllGeneral(allocator, scope, selectors, out);
    var matcher = Matcher.initForQuery(scope_node, scope);
    var parsed = try Selectors.get(matcher.document, scope.ctx.getAllocator(), selectors);
    defer parsed.deinit();
    const list = parsed.list();
    var nth_cache = NthIndexCache{ .allocator = allocator };
    defer nth_cache.deinit();
    matcher.nth_cache = &nth_cache;
    const fast = FastPath.of(list);
    const Sink = struct {
        list: *std.ArrayList(*NodeBase),
        allocator: std.mem.Allocator,
        fn take(self: *const @This(), node: *NodeBase) error{OutOfMemory}!bool {
            try self.list.append(self.allocator, node);
            return true;
        }
    };
    const sink: Sink = .{ .list = out, .allocator = allocator };
    if (try forEachById(&matcher, scope_node, list, fast, &sink, Sink.take)) return;
    var walk = Walk.init(scope_node);
    while (walk.next()) |node| {
        if (matcher.matchesForQuery(node, list, fast)) try out.append(allocator, node);
    }
}

/// DOM matches(selectors) / webkitMatchesSelector(selectors): whether
/// `element` matches, with `element` the scoping root. Parsed through the
/// document's cache.
pub fn matches(element: *runtime.Instance, selectors: []const u8) Error!bool {
    const node = instance_bridge.getNodeBase(element) orelse return matchesGeneral(element, selectors);
    const matcher = Matcher.initForQuery(node, element);
    // Steps 1-2: parse, or throw a SyntaxError.
    var parsed = try Selectors.get(matcher.document, element.ctx.getAllocator(), selectors);
    defer parsed.deinit();
    if (node.node_type != ELEMENT_NODE) return false;
    // Step 3: match against this, with scoping root this.
    return matcher.matchesList(.{ .node = node }, parsed.list());
}

/// DOM closest(selectors): the first of `element`'s inclusive ancestor
/// elements, nearest first, that matches, with `element` the scoping root.
/// Parsed through the document's cache.
pub fn closest(element: *runtime.Instance, selectors: []const u8) Error!?*runtime.Instance {
    const node = instance_bridge.getNodeBase(element) orelse return closestGeneral(element, selectors);
    const matcher = Matcher.initForQuery(node, element);
    var parsed = try Selectors.get(matcher.document, element.ctx.getAllocator(), selectors);
    defer parsed.deinit();
    const list = parsed.list();
    // Steps 3-4: "this's inclusive ancestors that are elements, in reverse
    // tree order".
    var current: ?*NodeBase = node;
    while (current) |candidate| : (current = candidate.parent_node) {
        if (candidate.node_type != ELEMENT_NODE) continue;
        if (matcher.matchesList(.{ .node = candidate }, list)) return instanceOf(candidate);
    }
    return null;
}

/// A query's parsed selector: the one `document` keeps for the text
/// (dom.tree_ordered_map's `selectorCache`: Blink's SelectorQueryCache,
/// selector_query.cc SelectorQueryCache::Add - 256 per document, keyed by
/// the text alone), or, when the document keeps none (none at all, or one
/// whose teardown began), a parse of this call's own. Parse errors are DOM's
/// SyntaxError either way, and are never kept.
const Selectors = struct {
    kept: ?*const SelectorList = null,
    own: SelectorList = undefined,

    fn get(document: ?*runtime.Instance, allocator: std.mem.Allocator, text: []const u8) Error!Selectors {
        if (document) |doc| if (@import("tree_ordered_map.zig").selectorCache(doc)) |cache| {
            const kept = cache.getOrParse(text) catch |err| return switch (err) {
                error.OutOfMemory => error.OutOfMemory,
                else => error.SyntaxError,
            };
            return .{ .kept = kept };
        };
        return .{ .own = try parse(allocator, text) };
    }

    /// Borrowed until `deinit`; a kept one until the document's cache next
    /// takes a text it does not keep (no query starts while this one runs:
    /// matching runs no script).
    fn list(self: *const Selectors) *const SelectorList {
        return self.kept orelse &self.own;
    }

    fn deinit(self: *Selectors) void {
        if (self.kept == null) self.own.deinit();
    }
};

/// The ID path of querySelector and querySelectorAll (lane perf2), after
/// Blink's SelectorQuery (third_party/blink/renderer/core/css/
/// selector_query.cc, Execute's ID lookup; before its 2025 rewrite,
/// SelectorQuery::ExecuteWithId and CanUseIdLookup): a one-selector list
/// with an ID selector in a compound needs its candidates only from where
/// the element with that ID is, which the tree scope's ID map
/// (dom.tree_ordered_map) knows without walking the tree. The subject is
/// matched by the full matcher either way, so the answer is the general
/// walk's (tests/dom/perf2_query_fast_paths_test.zig).
///
/// Blink's conditions, all of them:
/// - one complex selector in the list, not relative;
/// - not quirks mode: IDs then match ASCII case-insensitively and the map's
///   keys are exact (Blink: "querySelector is case-insensitive" there);
/// - the scope is in a tree scope (Blink IsInTreeScope): its tree's root is
///   a Document or a ShadowRoot, whose map holds every element of that tree
///   with the ID;
/// - the ID is the RIGHTMOST compound's that has one (Blink
///   last_compound_with_id_selector_, "the one on the lowest level").
/// Then:
/// - ID in the subject compound: the elements with the ID, in tree order,
///   that are descendants of the scope - one through the map's first, several
///   through its ordered list (Blink GetAllElementsById);
/// - ID in an earlier compound: with several elements that ID, the general
///   walk (Blink: nested same-ID elements make it a trap); with one, E, every
///   match descends from E - or, when the combinator right of E's compound
///   is a sibling combinator, from E's parent - so the walk is of that
///   subtree when E is in the scope (Blink's older ExecuteWithId, its
///   selector_id_affected_by_sibling_combinator_ start at the parent), and
///   of the whole scope otherwise; with none, nothing matches.
/// `forEachById` returns false when the ID path does not apply, and the
/// caller walks.
const IdPlan = struct {
    id: []const u8,
    subject: bool,
    sibling: bool,

    fn of(list: *const SelectorList, matcher: *const Matcher) ?IdPlan {
        if (matcher.quirks) return null;
        if (list.selectors.len != 1) return null;
        const complex = &list.selectors[0];
        if (complex.is_relative) return null;
        if (idIn(&complex.compound)) |id| return .{ .id = id, .subject = true, .sibling = false };
        for (complex.combinators, 0..) |*pair, i| {
            if (idIn(&pair.compound)) |id| {
                // The combinator between this compound and the one on its right.
                const right = complex.combinators[i].combinator;
                return .{ .id = id, .subject = false, .sibling = right == .NextSibling or right == .SubsequentSibling };
            }
        }
        return null;
    }

    /// The compound's own ID selector (not one inside a pseudo-class's
    /// argument): every element the compound matches has that ID.
    fn idIn(compound: *const CompoundSelector) ?[]const u8 {
        for (compound.simple_selectors) |*simple| switch (simple.*) {
            .Id => |id| return id.id,
            else => {},
        };
        return null;
    }
};

/// Run `take(context, node)` on each match the ID path finds, in tree
/// order, until it returns false; true when the ID path applied (the caller
/// is done), false when the caller must walk (`IdPlan`).
fn forEachById(matcher: *const Matcher, scope_node: *NodeBase, list: *const SelectorList, fast: FastPath, context: anytype, comptime take: anytype) error{OutOfMemory}!bool {
    const plan = IdPlan.of(list, matcher) orelse return false;
    const tree_ordered_map = @import("tree_ordered_map.zig");
    const elements = tree_ordered_map.idElements(rootOf(scope_node), plan.id, plan.subject) orelse return false;
    if (elements.count == 0) return true;
    if (plan.subject) {
        if (elements.count == 1) {
            const node = instance_bridge.getNodeBase(elements.first orelse return false) orelse return false;
            if (isDescendant(node, scope_node) and matcher.matchesForQuery(node, list, fast)) _ = try take(context, node);
            return true;
        }
        // The maps checked every link when they handed the list out
        // (tree_ordered_map orderedFrom), and matching changes no tree.
        for (elements.ordered) |link| {
            const node = instance_bridge.getNodeBase(link.get() orelse continue) orelse continue;
            if (!isDescendant(node, scope_node) or !matcher.matchesForQuery(node, list, fast)) continue;
            if (!try take(context, node)) return true;
        }
        return true;
    }
    if (elements.count > 1) return false;
    const id_node = instance_bridge.getNodeBase(elements.first orelse return false) orelse return false;
    var start = scope_node;
    if (isDescendant(id_node, scope_node)) {
        start = if (plan.sibling) id_node.parent_node.? else id_node;
    }
    var walk = Walk.init(start);
    while (walk.next()) |node| {
        if (matcher.matchesForQuery(node, list, fast) and !try take(context, node)) return true;
    }
    return true;
}

/// Whether `node` is a descendant of `ancestor` (not `ancestor` itself).
fn isDescendant(node: *NodeBase, ancestor: *NodeBase) bool {
    var at = node.parent_node;
    while (at) |parent| : (at = parent.parent_node) {
        if (parent == ancestor) return true;
    }
    return false;
}

// The general paths: a fresh parse, and every descendant of the scope
// walked. What the fast paths answer exactly as (tests/dom/
// perf2_query_fast_paths_test.zig compares them on the same inputs).

/// querySelector by the general path.
pub fn querySelectorGeneral(scope: *runtime.Instance, selectors: []const u8) Error!?*runtime.Instance {
    const scope_node = instance_bridge.getNodeBase(scope) orelse return null;
    // DOM "scope-match a selectors string" steps 1-2. The parsed selector
    // lives for this call only: parse it on the stack while it fits.
    var parse_memory_buffer: [parse_stack_bytes]u8 = undefined;
    var parse_memory: std.heap.BufferFirstAllocator = .init(&parse_memory_buffer, scope.ctx.getAllocator());
    var list = try parse(parse_memory.allocator(), selectors);
    defer list.deinit();
    var nth_cache = NthIndexCache{ .allocator = scope.ctx.getAllocator() };
    defer nth_cache.deinit();
    var matcher = Matcher.initForQuery(scope_node, scope);
    matcher.nth_cache = &nth_cache;
    const fast = FastPath.of(&list);
    var walk = Walk.init(scope_node);
    while (walk.next()) |node| {
        if (matcher.matchesForQuery(node, &list, fast)) return instanceOf(node);
    }
    return null;
}

/// querySelectorAll by the general path.
pub fn querySelectorAllGeneral(allocator: std.mem.Allocator, scope: *runtime.Instance, selectors: []const u8, out: *std.ArrayList(*NodeBase)) Error!void {
    const scope_node = instance_bridge.getNodeBase(scope) orelse return;
    var parse_memory_buffer: [parse_stack_bytes]u8 = undefined;
    var parse_memory: std.heap.BufferFirstAllocator = .init(&parse_memory_buffer, scope.ctx.getAllocator());
    var list = try parse(parse_memory.allocator(), selectors);
    defer list.deinit();
    var nth_cache = NthIndexCache{ .allocator = allocator };
    defer nth_cache.deinit();
    var matcher = Matcher.initForQuery(scope_node, scope);
    matcher.nth_cache = &nth_cache;
    const fast = FastPath.of(&list);
    var walk = Walk.init(scope_node);
    while (walk.next()) |node| {
        if (matcher.matchesForQuery(node, &list, fast)) try out.append(allocator, node);
    }
}

/// matches() by the general path.
pub fn matchesGeneral(element: *runtime.Instance, selectors: []const u8) Error!bool {
    // Steps 1-2: parse, or throw a SyntaxError.
    var parse_memory_buffer: [parse_stack_bytes]u8 = undefined;
    var parse_memory: std.heap.BufferFirstAllocator = .init(&parse_memory_buffer, element.ctx.getAllocator());
    var list = try parse(parse_memory.allocator(), selectors);
    defer list.deinit();
    const node = instance_bridge.getNodeBase(element) orelse return false;
    if (node.node_type != ELEMENT_NODE) return false;
    // Step 3: match against this, with scoping root this.
    const matcher = Matcher.initForQuery(node, element);
    return matcher.matchesList(.{ .node = node }, &list);
}

/// closest() by the general path.
pub fn closestGeneral(element: *runtime.Instance, selectors: []const u8) Error!?*runtime.Instance {
    var parse_memory_buffer: [parse_stack_bytes]u8 = undefined;
    var parse_memory: std.heap.BufferFirstAllocator = .init(&parse_memory_buffer, element.ctx.getAllocator());
    var list = try parse(parse_memory.allocator(), selectors);
    defer list.deinit();
    const node = instance_bridge.getNodeBase(element) orelse return null;
    const matcher = Matcher.initForQuery(node, element);
    // Steps 3-4: "this's inclusive ancestors that are elements, in reverse
    // tree order".
    var current: ?*NodeBase = node;
    while (current) |candidate| : (current = candidate.parent_node) {
        if (candidate.node_type != ELEMENT_NODE) continue;
        if (matcher.matchesList(.{ .node = candidate }, &list)) return instanceOf(candidate);
    }
    return null;
}

/// The stack the entry points parse a selector into before falling back to
/// the realm's allocator: a typical selector list's tree fits, so a query
/// allocates nothing to parse (every call parses; WebKit, Blink and Gecko
/// cache the parse per document instead).
const parse_stack_bytes = 8192;

// ============================================================================
// The style engine's matching (src/dom/style/)
// ============================================================================

/// What a style match read beyond the tree: whether any pseudo-class it
/// evaluated answers from per-element state that can change with no DOM
/// mutation - a control's checkedness or value, a custom element's
/// definition or states, a dialog's or popover's open state, a media
/// element's playback (tmp/plans/style-design.md section 5.3). A style that
/// read such state is not reused. Blink records the same during matching
/// (Element's "affected by" flags) to invalidate precisely; this records it
/// to not cache at all. The document singletons (focus, hover, active,
/// target) are not recorded: the style engine keys its cache on them.
pub const StateReads = struct {
    @"volatile": bool = false,
};

/// Matching a style rule's selectors against one element (Selectors 4 17.3
/// "match a selector against an element", with no scoping root: `:scope`
/// is the root element, as for a style sheet's rules).
pub const StyleMatcher = struct {
    matcher: Matcher,

    /// For `element`, in the tree it is in - its document, or the shadow
    /// tree it is in (whose host is featureless to it, CSS Scoping 3.1.1).
    pub fn init(element: *runtime.Instance, reads: *StateReads) ?StyleMatcher {
        const node = instance_bridge.getNodeBase(element) orelse return null;
        var root = node;
        while (root.parent_node) |parent| root = parent;
        const root_instance = instanceOf(root) orelse return null;
        var matcher = Matcher.init(root, root_instance);
        matcher.state_reads = reads;
        return .{ .matcher = matcher };
    }

    /// For the shadow host `host`, matched against the rules of its shadow
    /// root `shadow`'s style sheets: seen from inside, the host is
    /// featureless (CSS Scoping 3.1.1) - only :host, :host() and the logical
    /// combinations of them match it - and nothing is above it.
    pub fn initForHost(host: *runtime.Instance, shadow: *runtime.Instance, reads: *StateReads) ?StyleMatcher {
        _ = instance_bridge.getNodeBase(host) orelse return null;
        const shadow_node = instance_bridge.getNodeBase(shadow) orelse return null;
        var matcher = Matcher.init(shadow_node, shadow);
        matcher.state_reads = reads;
        return .{ .matcher = matcher };
    }

    /// Whether `complex`, a rule of the host's shadow tree (`initForHost`),
    /// matches the host `host` itself.
    pub fn matchesHost(self: *StyleMatcher, host: *runtime.Instance, complex: *const ComplexSelector, pseudo: ?[]const u8) bool {
        const node = instance_bridge.getNodeBase(host) orelse return false;
        if (complex.compound.hasPseudoElement() != (pseudo != null)) return false;
        self.matcher.pseudo_target = pseudo;
        defer self.matcher.pseudo_target = null;
        return self.matcher.matchesComplex(.{ .node = node, .featureless = true }, complex);
    }

    /// Whether `complex`, a rule of the shadow tree `slot` is in (the
    /// matcher is `init(slot)`), matches `element` - or its `pseudo` - as
    /// ::slotted() (CSS Scoping 3.2.2): `element` is assigned, after
    /// flattening, to `slot`. In the subject compound, the simple selectors
    /// before ::slotted() and the combinators to its left match the slot in
    /// its tree; its argument and what follows it match `element`.
    pub fn matchesSlotted(self: *StyleMatcher, element: *runtime.Instance, slot: *runtime.Instance, complex: *const ComplexSelector, pseudo: ?[]const u8) bool {
        const node = instance_bridge.getNodeBase(element) orelse return false;
        const slot_node = instance_bridge.getNodeBase(slot) orelse return false;
        return self.matchesAround(node, slot_node, complex, "slotted", pseudo, &.{});
    }

    /// Whether `complex`, a rule of the tree `host` is in (the matcher is
    /// `init(host)`), matches `element` - or its `pseudo` - as ::part() (CSS
    /// Shadow Parts 4.1): `element` is in `host`'s shadow tree and its part
    /// names include every name ::part() lists. The simple selectors before
    /// ::part() and the combinators match the host; what follows ::part()
    /// matches `element`. `exposed` includes names forwarded by exportparts.
    pub fn matchesPart(self: *StyleMatcher, element: *runtime.Instance, host: *runtime.Instance, complex: *const ComplexSelector, pseudo: ?[]const u8, exposed: []const []const u8) bool {
        const node = instance_bridge.getNodeBase(element) orelse return false;
        const host_node = instance_bridge.getNodeBase(host) orelse return false;
        return self.matchesAround(node, host_node, complex, "part", pseudo, exposed);
    }

    /// ::slotted() and ::part(): the subject compound split at the
    /// pseudo-element named `name` - its left part matched against `outer`
    /// (the slot, the host) and its argument, part names and right part
    /// against `element` - then the combinators from `outer`.
    fn matchesAround(self: *StyleMatcher, element: *NodeBase, outer: *NodeBase, complex: *const ComplexSelector, name: []const u8, pseudo: ?[]const u8, exposed: []const []const u8) bool {
        if (element.node_type != ELEMENT_NODE or outer.node_type != ELEMENT_NODE) return false;
        const simples = complex.compound.simple_selectors;
        const at = for (simples, 0..) |*simple, i| {
            if (simple.* == .PseudoElement and std.mem.eql(u8, simple.PseudoElement.name, name)) break i;
        } else return false;
        const outer_data = dataOf(outer) orelse return false;
        for (simples[0..at]) |*simple| {
            if (!self.matcher.matchesSimple(outer, outer_data, simple)) return false;
        }
        // The pseudo-element's own condition, then the rest of the compound,
        // matched against `element` in its own tree.
        const root = rootOf(element);
        const root_instance = instanceOf(root) orelse return false;
        var inner = Matcher.init(root, root_instance);
        inner.state_reads = self.matcher.state_reads;
        const data = dataOf(element) orelse return false;
        const own = &simples[at].PseudoElement;
        if (own.argument) |list| if (!inner.matchesList(.{ .node = element }, list)) return false;
        if (own.part_names.len != 0 and !hasPartNames(exposed, own.part_names)) return false;
        // A sub-pseudo-element (::slotted(x)::before) is what `pseudo` asks
        // for, exactly when one is asked for.
        var sub: ?[]const u8 = null;
        for (simples[at + 1 ..]) |*simple| switch (simple.*) {
            .PseudoElement => |p| sub = p.name,
            else => if (!inner.matchesSimple(element, data, simple)) return false,
        };
        if ((sub == null) != (pseudo == null)) return false;
        if (sub) |own_sub| if (!std.ascii.eqlIgnoreCase(own_sub, pseudo.?)) return false;
        if (complex.combinators.len == 0) return true;
        return self.matcher.matchCombinators(complex, 0, .{ .node = outer }) == .matched;
    }

    /// Whether `complex` matches `element` - or, with `pseudo`, that
    /// pseudo-element of it: the subject compound must name the
    /// pseudo-element exactly when one is asked for.
    pub fn matches(self: *StyleMatcher, element: *runtime.Instance, complex: *const ComplexSelector, pseudo: ?[]const u8) bool {
        const node = instance_bridge.getNodeBase(element) orelse return false;
        if (node.node_type != ELEMENT_NODE) return false;
        if (complex.compound.hasPseudoElement() != (pseudo != null)) return false;
        self.matcher.pseudo_target = pseudo;
        defer self.matcher.pseudo_target = null;
        return self.matcher.matchesComplex(.{ .node = node }, complex);
    }
};

/// CSS Shadow Parts 4.1: the exposed set holds every selector name.
/// The engine supplies the set for this host; all other matching stays here.
fn hasPartNames(exposed: []const []const u8, names: []const []const u8) bool {
    for (names) |wanted| {
        const found = for (exposed) |name| {
            if (std.mem.eql(u8, name, wanted)) break true;
        } else false;
        if (!found) return false;
    }
    return true;
}

/// The root of `node`'s tree.
fn rootOf(node: *NodeBase) *NodeBase {
    var root = node;
    while (root.parent_node) |parent| root = parent;
    return root;
}

/// Section 5.3's table: whether `kind`, evaluated on an element with
/// `data`, can change its answer with no tree mutation (for elements where
/// it can matter at all, so that a universal UA rule such as `:autofill`
/// does not make every style volatile).
fn readsVolatileState(kind: PseudoClassKind, data: ElementData) bool {
    const local = data.localName();
    const html = namespaceIs(data, html_namespace);
    const custom = std.mem.indexOfScalar(u8, local, '-') != null or data.findAttribute(null, "is") != null;
    return switch (kind) {
        // A control's checkedness, value, validity and autofill state; a
        // form-associated custom element's validity.
        .Checked, .Indeterminate, .Default, .Valid, .Invalid, .UserValid, .UserInvalid, .InRange, .OutOfRange, .PlaceholderShown, .Autofill, .ReadOnly, .ReadWrite => custom or (html and isFormish(local)),
        .Defined, .State => custom,
        // A details element's open state is its attribute (a mutation); a
        // dialog's, a select's and an input's picker are not.
        .Open => html and (std.mem.eql(u8, local, "dialog") or std.mem.eql(u8, local, "select") or std.mem.eql(u8, local, "input")),
        .PopoverOpen => data.findAttribute(null, "popover") != null,
        .Modal => html and std.mem.eql(u8, local, "dialog"),
        .Playing, .Paused, .Seeking, .Buffering, .Stalled, .Muted, .VolumeLocked => html and (std.mem.eql(u8, local, "audio") or std.mem.eql(u8, local, "video")),
        // dir=auto on a text control reads its value.
        .Dir => html and (std.mem.eql(u8, local, "input") or std.mem.eql(u8, local, "textarea")),
        else => false,
    };
}

/// HTML 4.10.7 / 15.5.16: an HTML select renders as a list box when it has
/// the `multiple` attribute or a display size above 1, and as a drop-down
/// box otherwise (Blink HTMLSelectElement::UsesMenuList). The display size
/// is the size attribute's non-negative integer, 1 when it does not parse.
pub const SelectKind = enum { none, drop_down, list_box };

pub fn selectKindOf(data: ElementData) SelectKind {
    if (!std.mem.eql(u8, data.localName(), "select") or !namespaceIs(data, html_namespace)) return .none;
    if (data.findAttribute(null, "multiple") != null) return .list_box;
    if (data.findAttribute(null, "size")) |size| {
        const n = std.fmt.parseInt(u32, std.mem.trim(u8, size.value, " \t\n\r\x0c"), 10) catch 0;
        if (n > 1) return .list_box;
    }
    return .drop_down;
}

fn isFormish(local: []const u8) bool {
    for ([_][]const u8{ "input", "select", "textarea", "button", "option", "optgroup", "fieldset", "form", "output", "object", "progress", "meter", "datalist" }) |name| {
        if (std.mem.eql(u8, local, name)) return true;
    }
    return false;
}

/// Selectors 4 17.1 "parse a selector"; failure is DOM's SyntaxError.
pub fn parse(allocator: std.mem.Allocator, selectors: []const u8) Error!SelectorList {
    return selector.parse(allocator, selectors) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.SyntaxError,
    };
}

// ============================================================================
// Tree walking
// ============================================================================

/// The element descendants of a root, in tree order (not into shadow trees
/// or template contents, which are not children).
const Walk = struct {
    root: *NodeBase,
    current: ?*NodeBase,

    fn init(root: *NodeBase) Walk {
        return .{ .root = root, .current = root };
    }

    fn next(self: *Walk) ?*NodeBase {
        while (true) {
            const node = self.current orelse return null;
            self.current = following(node, self.root);
            const candidate = self.current orelse return null;
            if (candidate.node_type == ELEMENT_NODE) return candidate;
        }
    }
};

/// The node after `node` in tree order within `root`'s inclusive
/// descendants, or null.
fn following(node: *NodeBase, root: *NodeBase) ?*NodeBase {
    if (node.first_child) |child| return child;
    var current = node;
    while (current != root) {
        if (current.next_sibling) |sibling| return sibling;
        current = current.parent_node orelse return null;
    }
    return null;
}

fn instanceOf(node: *NodeBase) ?*runtime.Instance {
    return @ptrCast(@alignCast(node.ownerInstance() orelse return null));
}

fn dataOf(node: *NodeBase) ?ElementData {
    return element_data.of(instanceOf(node) orelse return null);
}

fn isShadowRoot(node: *NodeBase) bool {
    if (node.node_type != DOCUMENT_FRAGMENT_NODE) return false;
    const instance = instanceOf(node) orelse return false;
    return instance.vtable == &interfaces.ShadowRoot.vtable;
}

/// A shadow root's host, as a tree node; null when the host is gone.
fn hostOf(shadow: *NodeBase) ?*NodeBase {
    const instance = instanceOf(shadow) orelse return null;
    const host = interfaces.ShadowRoot.get_host(instance) catch return null;
    return instance_bridge.getNodeBase(host);
}

fn previousElementSibling(node: *NodeBase) ?*NodeBase {
    var sibling = node.previousSibling();
    while (sibling) |s| : (sibling = s.previousSibling()) {
        if (s.node_type == ELEMENT_NODE) return s;
    }
    return null;
}

fn nextElementSibling(node: *NodeBase) ?*NodeBase {
    var sibling = node.next_sibling;
    while (sibling) |s| : (sibling = s.next_sibling) {
        if (s.node_type == ELEMENT_NODE) return s;
    }
    return null;
}

fn namespaceIs(data: ElementData, ns: []const u8) bool {
    const own = data.namespaceSlice() orelse return false;
    return std.mem.eql(u8, own, ns);
}

/// Two elements have the same expanded name: local name and namespace
/// (Selectors 4 13.4 "same type"). Their name records' `matches` (Blink's
/// QualifiedName::Matches): one pointer compare for two elements of a
/// known name (lane nd2 N2).
fn sameType(a: ElementData, b: ElementData) bool {
    return a.name.matches(b.name);
}

// ============================================================================
// Matching
// ============================================================================

/// What a selector is matched against: an element, or - in a shadow tree -
/// the shadow host seen from inside, which is featureless (Selectors 4
/// 3.2.1): only :host and :host() match it.
const Subject = struct {
    node: *NodeBase,
    featureless: bool = false,
};

/// Stylo's SelectorMatchingResult: how far a failed match tells the
/// combinator loops above it to back off.
const Result = enum {
    matched,
    not_matched_restart_from_closest_later_sibling,
    not_matched_restart_from_closest_descendant,
    not_matched_globally,
};

/// One query's matching state: its scoping root and what it decides once
/// for the whole tree (every candidate shares the scope's node document).
const Matcher = struct {
    /// The scoping root (DOM: the node querySelector was called on, or the
    /// element of matches() and closest()).
    scope: *NodeBase,
    /// The node document, and whether it is an HTML document (HTML 4.16.2)
    /// in quirks mode (Selectors 4 6.6/6.7: IDs and classes match ASCII
    /// case-insensitively in quirks mode).
    document: ?*runtime.Instance,
    html_document: bool,
    quirks: bool,
    /// The shadow root whose tree the selector is matched in, and its host.
    shadow_root: ?*NodeBase = null,
    shadow_host: ?*NodeBase = null,
    /// :has(): the element relative selectors are anchored at.
    anchor: ?*NodeBase = null,
    /// The query's child indices (querySelector and querySelectorAll; null
    /// for matches() and closest(), which look at one element).
    nth_cache: ?*NthIndexCache = null,
    /// The style engine's matching (`StyleMatcher`): the pseudo-element the
    /// subject compound must name - null for the element itself - and where
    /// the per-element dynamic state a match read is recorded.
    pseudo_target: ?[]const u8 = null,
    state_reads: ?*StateReads = null,
    /// A DOM query (querySelector, querySelectorAll, matches, closest): class
    /// checks compare ids and fill the compiled selector's class operands
    /// (`hasClass`). The style engine's matching - whose rules' selectors no
    /// query cache owns - compares bytes.
    class_ids: bool = false,

    fn init(scope: *NodeBase, scope_instance: *runtime.Instance) Matcher {
        const document: ?*runtime.Instance = if (scope.node_type == DOCUMENT_NODE)
            scope_instance
        else
            interfaces.Node.get_ownerDocument(scope_instance) catch null;
        var matcher = Matcher{
            .scope = scope,
            .document = document,
            .html_document = if (document) |doc| document_internals.getDocumentType(doc) == .html else false,
            .quirks = if (document) |doc| document_internals.getMode(doc) == .quirks else false,
        };
        var root = scope;
        while (root.parent_node) |parent| root = parent;
        if (isShadowRoot(root)) {
            matcher.shadow_root = root;
            matcher.shadow_host = hostOf(root);
        }
        return matcher;
    }

    /// `init`, for a DOM query's matching (`class_ids`).
    fn initForQuery(scope: *NodeBase, scope_instance: *runtime.Instance) Matcher {
        var matcher = init(scope, scope_instance);
        matcher.class_ids = true;
        return matcher;
    }

    /// querySelector's candidates are the scope's descendants. A selector of
    /// one simple selector takes a fast path that answers exactly as the full
    /// matcher would, without its per-element machinery.
    fn matchesForQuery(self: *const Matcher, node: *NodeBase, list: *const SelectorList, fast: FastPath) bool {
        return switch (fast) {
            .none => self.matchesList(.{ .node = node }, list),
            .filtered => |filter| self.passesFilter(node, filter) and self.matchesList(.{ .node = node }, list),
            .all => true,
            .tag => |tag| if (dataOf(node)) |data| self.matchesType(data, tag.name, tag.lower_name, .any) else false,
            .class => |name| if (dataOf(node)) |data| self.hasClass(data, name) else false,
            .id => |id| if (dataOf(node)) |data| self.idIs(data, id) else false,
            .attribute => |attribute| if (dataOf(node)) |data| self.matchesAttribute(data, attribute) else false,
        };
    }

    /// A one-selector list's subject compound starts with this type, class or
    /// ID selector: an element failing it fails the selector, so it is
    /// rejected without the full matcher (WebKit's SelectorDataList does the
    /// same with the rightmost compound).
    fn passesFilter(self: *const Matcher, node: *NodeBase, filter: SubjectFilter) bool {
        const data = dataOf(node) orelse return false;
        return switch (filter) {
            .tag => |tag| self.matchesType(data, tag.name, tag.lower_name, .any),
            .class => |name| self.hasClass(data, name),
            .id => |id| self.idIs(data, id),
        };
    }

    /// "Match a selector against an element": any complex selector of the
    /// list.
    fn matchesList(self: *const Matcher, subject: Subject, list: *const SelectorList) bool {
        for (list.selectors) |*complex| {
            if (self.matchesComplex(subject, complex)) return true;
        }
        return false;
    }

    fn matchesComplex(self: *const Matcher, subject: Subject, complex: *const ComplexSelector) bool {
        // The subject compound first: most elements fail it, and then no
        // combinator is walked.
        if (!self.matchesCompound(subject, &complex.compound)) return false;
        if (complex.combinators.len == 0 and !complex.is_relative) return true;
        return self.matchCombinators(complex, 0, subject) == .matched;
    }

    /// Selectors 4 17.3 "match a complex selector against an element", from
    /// the compound at `index` (0 is the subject, k the compound left of
    /// combinator k-1) against `subject`, then the combinators to its left.
    /// A relative selector's last step is its anchor (3.4).
    fn matchChain(self: *const Matcher, complex: *const ComplexSelector, index: usize, subject: Subject) Result {
        const compound = if (index == 0) &complex.compound else &complex.combinators[index - 1].compound;
        if (!self.matchesCompound(subject, compound)) return .not_matched_restart_from_closest_later_sibling;
        return self.matchCombinators(complex, index, subject);
    }

    /// The rest of matchChain, once the compound at `index` matched `subject`.
    fn matchCombinators(self: *const Matcher, complex: *const ComplexSelector, index: usize, subject: Subject) Result {
        if (index == complex.combinators.len) {
            if (!complex.is_relative) return .matched;
            return self.matchAnchor(complex.initial_combinator orelse .Descendant, subject);
        }
        const combinator = complex.combinators[index].combinator;
        var candidate = self.relatedElement(combinator, subject) orelse return candidateNotFound(combinator);
        while (true) {
            const result = self.matchChain(complex, index + 1, candidate);
            switch (result) {
                .matched, .not_matched_globally => return result,
                else => {},
            }
            switch (combinator) {
                .NextSibling => return result,
                .Child => return .not_matched_restart_from_closest_descendant,
                .SubsequentSibling => if (result == .not_matched_restart_from_closest_descendant) return result,
                .Descendant => {},
            }
            candidate = self.relatedElement(combinator, candidate) orelse return candidateNotFound(combinator);
        }
    }

    /// A relative selector's leftmost compound matched `subject`: does the
    /// anchor relate to it by `combinator`? The anchor is one more compound,
    /// matched by identity, reached through the same loop.
    fn matchAnchor(self: *const Matcher, combinator: Combinator, subject: Subject) Result {
        const anchor = self.anchor orelse return .not_matched_globally;
        var candidate = self.relatedElement(combinator, subject) orelse return candidateNotFound(combinator);
        while (true) {
            if (!candidate.featureless and candidate.node == anchor) return .matched;
            switch (combinator) {
                .NextSibling => return .not_matched_restart_from_closest_later_sibling,
                .Child => return .not_matched_restart_from_closest_descendant,
                .SubsequentSibling, .Descendant => {},
            }
            candidate = self.relatedElement(combinator, candidate) orelse return candidateNotFound(combinator);
        }
    }

    /// Stylo: no element to try is a global failure for an ancestor
    /// combinator, and sends a sibling combinator back to the closest
    /// descendant combinator.
    fn candidateNotFound(combinator: Combinator) Result {
        return switch (combinator) {
            .NextSibling, .SubsequentSibling => .not_matched_restart_from_closest_descendant,
            .Child, .Descendant => .not_matched_globally,
        };
    }

    /// The element `combinator` relates to `from` - for a combinator that
    /// tries several, called again on its last answer for the next one
    /// (descendant: the next ancestor; subsequent sibling: the next earlier
    /// sibling).
    fn relatedElement(self: *const Matcher, combinator: Combinator, from: Subject) ?Subject {
        return switch (combinator) {
            .Child, .Descendant => self.parentElement(from),
            .NextSibling, .SubsequentSibling => if (from.featureless) null else if (previousElementSibling(from.node)) |s| Subject{ .node = s } else null,
        };
    }

    /// The parent element for combinators: in the shadow tree being matched,
    /// a top-level element's parent is the featureless host (CSS Scoping
    /// 3.1.1), and nothing is above the host.
    fn parentElement(self: *const Matcher, from: Subject) ?Subject {
        if (from.featureless) return null;
        const parent = from.node.parent_node orelse return null;
        if (parent.node_type == ELEMENT_NODE) return .{ .node = parent };
        if (self.shadow_root) |root| if (parent == root) {
            if (self.shadow_host) |host| return .{ .node = host, .featureless = true };
        };
        return null;
    }

    // ========================================================================
    // Compounds and simple selectors
    // ========================================================================

    fn matchesCompound(self: *const Matcher, subject: Subject, compound: *const CompoundSelector) bool {
        if (subject.featureless) return self.matchesFeaturelessCompound(subject, compound);
        // `*` alone matches every element, with no element data to read.
        if (compound.simple_selectors.len == 1 and compound.simple_selectors[0] == .Universal and
            compound.simple_selectors[0].Universal.namespace == .any) return true;
        const data = dataOf(subject.node) orelse return false;
        for (compound.simple_selectors) |*simple| {
            if (!self.matchesSimple(subject.node, data, simple)) return false;
        }
        // Quirks Mode 4.1: in quirks mode such a compound "must not match
        // elements that would not also match the :any-link selector".
        if (compound.active_hover_quirk and self.quirks) {
            const element = instanceOf(subject.node) orelse return false;
            return html_pseudo_classes.matches(element, .any_link);
        }
        return true;
    }

    /// Selectors 4 3.2.1: a compound matches a featureless element only if
    /// every simple selector in it is allowed to - here :host and :host(),
    /// and the logical combinations of them.
    fn matchesFeaturelessCompound(self: *const Matcher, subject: Subject, compound: *const CompoundSelector) bool {
        for (compound.simple_selectors) |*simple| {
            const kind = switch (simple.*) {
                // Selectors 4 3.2.1: a default namespace never prevents
                // an otherwise matching featureless host.
                .NamespaceURI => continue,
                // CSS Scoping 3.1.1: `:host::before` styles the host's
                // ::before - the pseudo-element the style engine resolves
                // (pseudo_target), as matchesSimple accepts it for an
                // ordinary subject. Chrome, Firefox and Safari apply it
                // (css/css-shadow/keyframes-006.html).
                .PseudoElement => |pseudo| {
                    const wanted = self.pseudo_target orelse return false;
                    if (!std.ascii.eqlIgnoreCase(wanted, pseudo.name)) return false;
                    continue;
                },
                .PseudoClass => |pseudo| pseudo.kind,
                else => return false,
            };
            const ok = switch (kind) {
                .Host => |argument| if (argument) |list| self.hostMatches(subject.node, list) else true,
                .Is, .Where => |list| self.matchesList(subject, list),
                else => false,
            };
            if (!ok) return false;
        }
        return true;
    }

    fn matchesSimple(self: *const Matcher, node: *NodeBase, data: ElementData, simple: *const SimpleSelector) bool {
        return switch (simple.*) {
            // CSSOM's unresolved AST never reaches matching: stylesheet
            // build resolves it; DOM parsing lowers & to :where(:scope).
            .Nesting => false,
            .Universal => |universal| universal.namespace == .any or data.namespaceSlice() == null,
            .Type => |type_selector| self.matchesType(data, type_selector.tag_name, type_selector.lower_name, type_selector.namespace),
            .Class => |*class| self.hasClass(data, class),
            .Id => |id| self.idIs(data, id.id),
            .Attribute => |*attribute| self.matchesAttribute(data, attribute),
            .NamespaceURI => |constraint| std.mem.eql(u8, data.namespaceSlice() orelse "", constraint.uri),
            .NamespacedAttribute => |attribute| self.matchesNamespacedAttribute(data, &attribute.attribute, attribute.uri),
            .PseudoClass => |*pseudo| self.matchesPseudoClassRead(node, data, pseudo.kind),
            // A pseudo-element is no element of the tree - except to the
            // style engine resolving that pseudo-element's style, for which
            // the compound's other simple selectors match its originating
            // element.
            .PseudoElement => |pseudo| if (self.pseudo_target) |wanted| std.ascii.eqlIgnoreCase(wanted, pseudo.name) else false,
        };
    }

    /// HTML 4.16.2: an HTML element in an HTML document compares the type
    /// selector converted to ASCII lowercase; every other element its
    /// original case. Both are identical-to comparisons.
    fn matchesType(self: *const Matcher, data: ElementData, name: []const u8, lower_name: []const u8, namespace: selector.NamespaceConstraint) bool {
        if (namespace == .none and data.namespaceSlice() != null) return false;
        const local = data.localName();
        // A name written in lowercase is both forms: no namespace test.
        if (lower_name.ptr == name.ptr) return std.mem.eql(u8, local, name);
        const wanted = if (self.html_document and namespaceIs(data, html_namespace)) lower_name else name;
        return std.mem.eql(u8, local, wanted);
    }

    /// Selectors 4 6.6: one of the element's classes (its class attribute
    /// split on ASCII whitespace) is `name`.
    ///
    /// A DOM query (`class_ids`) reads the class value's token list and
    /// compares ids (lane nd2 batch 3): the element's class value is a record
    /// id whose flags say whether it is one token (then it is its own class:
    /// one compare, no table read), else its record's ClassNames hold its
    /// tokens' ids, split once per distinct value (Blink's
    /// ElementData::ClassNames().Contains(selector.Value()), a scan of the
    /// SpaceSplitString's vector). In quirks mode both sides are the ASCII
    /// lowercase (Blink's SetClassFoldingCase and SetValue(value,
    /// match_lower_case)). The style engine's matching compares bytes.
    fn hasClass(self: *const Matcher, data: ElementData, class: *const selector.ClassSelector) bool {
        if (!self.class_ids) return self.hasClassBytes(data, class.class_name);
        const id = data.classId();
        if (id == .empty) return false;
        // A class value means its Browser made its values table.
        const table = attribute_values.classTable(data.scope) orelse return false;
        const operand = self.classOperand(table, class) orelse return self.hasClassBytes(data, class.class_name);
        const found = if (self.quirks) table.hasFoldedToken(id, operand) else table.hasToken(id, operand);
        return found catch self.hasClassBytes(data, class.class_name);
    }

    /// The class selector's name as an id of `table` - the compiled
    /// selector's cached one while it is valid (parser.ClassOperand: no
    /// record an operand named has been freed since), else read again - or
    /// null for a name kept as bytes (or no memory to read it).
    fn classOperand(self: *const Matcher, table: *attribute_values.Table, class: *const selector.ClassSelector) ?attribute_values.ValueId {
        // The cell is the compiled selector's own, written on this thread
        // only (the document's selector cache, or this query's parse).
        const cell: *selector.ClassOperand = @constCast(&class.operand);
        if (cell.table == @as(*const anyopaque, table) and cell.frees == table.operand_frees and cell.folded == self.quirks) {
            if (cell.bytes) return null;
            const cached: attribute_values.ValueId = @fromBackingInt(cell.id);
            return cached;
        }
        const id = table.operandOf(class.class_name, self.quirks) catch return null;
        // Read after operandOf, whose release may have freed other records.
        cell.* = .{
            .table = table,
            .frees = table.operand_frees,
            .id = if (id) |i| @backingInt(i) else 0,
            .folded = self.quirks,
            .bytes = id == null,
        };
        return id;
    }

    /// The byte compare (the style engine's matching, a name too long to
    /// keep as an id, no memory for a token list): Selectors 4 6.6 over the
    /// value's bytes.
    fn hasClassBytes(self: *const Matcher, data: ElementData, name: []const u8) bool {
        const classes = data.classValue();
        // A pass over a class value's bytes (attribute_values.Table.class_scans).
        if (debug_checks and classes.len > 0) {
            if (attribute_values.classTable(data.scope)) |table| table.class_scans += 1;
        }
        return classListHas(classes, name, self.quirks);
    }

    fn idIs(self: *const Matcher, data: ElementData, id: []const u8) bool {
        const own = data.idValue();
        return if (self.quirks) std.ascii.eqlIgnoreCase(own, id) else std.mem.eql(u8, own, id);
    }

    /// Selectors 4 6 and 6.4, HTML 4.16.2: an attribute in the selector's
    /// namespace whose name matches - the lowercase name for an attribute of
    /// an HTML element in an HTML document, the name as written otherwise -
    /// and whose value matches.
    ///
    /// Deviation: HTML 4.16.2 compares "the names of attributes that
    /// themselves have namespaces" in their original case; Chrome, Firefox
    /// and Safari all compare the lowercase for those too on an HTML element
    /// in an HTML document (dom/nodes/ParentNode-querySelector-All.html,
    /// `[*|TiTlE]` matching a `title` set with setAttributeNS: PASS in all
    /// three at wpt.fyi cc74d2669f; Gecko's AttrSelectorWithOptionalNamespace
    /// picks `local_name_lower` by the element alone).
    fn matchesAttribute(self: *const Matcher, data: ElementData, attribute: *const AttributeSelector) bool {
        // Whether the element is an HTML element in an HTML document decides
        // the name only when the selector's name has upper case, and the
        // value only for HTML's list without a modifier: read it then.
        const name_cased = attribute.lower_name.ptr != attribute.name.ptr;
        const name_html = name_cased and self.html_document and namespaceIs(data, html_namespace);
        const wanted = if (name_html) attribute.lower_name else attribute.name;
        if (attribute.namespace == .none) {
            // At most one attribute in no namespace has the name.
            const entry = data.findAttribute(null, wanted) orelse return false;
            const value_html = name_html or (attribute.html_case_insensitive_value and attribute.case == .default and
                self.html_document and namespaceIs(data, html_namespace));
            return matchesValue(attribute, &entry, value_html);
        }
        var it = data.attributeIterator();
        while (it.next()) |entry| {
            if (attribute.namespace == .none and entry.namespace_uri != null) continue;
            if (!std.mem.eql(u8, entry.local_name, wanted)) continue;
            // The value's case rule, read only for an attribute that is there.
            const value_html = name_html or (attribute.html_case_insensitive_value and attribute.case == .default and
                self.html_document and namespaceIs(data, html_namespace));
            if (matchesValue(attribute, &entry, value_html)) return true;
        }
        return false;
    }

    /// CSS Namespaces 3 section 6: a named prefix constrains the attribute's
    /// expanded name. This path is entered only by the new resolved-URI arm.
    fn matchesNamespacedAttribute(self: *const Matcher, data: ElementData, attribute: *const AttributeSelector, uri: []const u8) bool {
        const name_cased = attribute.lower_name.ptr != attribute.name.ptr;
        const name_html = name_cased and self.html_document and namespaceIs(data, html_namespace);
        const wanted = if (name_html) attribute.lower_name else attribute.name;
        const entry = data.findAttribute(if (uri.len == 0) null else uri, wanted) orelse return false;
        const value_html = name_html or (attribute.html_case_insensitive_value and attribute.case == .default and
            self.html_document and namespaceIs(data, html_namespace));
        return matchesValue(attribute, &entry, value_html);
    }

    // ========================================================================
    // Pseudo-classes
    // ========================================================================

    /// matchesPseudoClass, recording for the style engine whether the
    /// answer read state that can change without a tree mutation.
    fn matchesPseudoClassRead(self: *const Matcher, node: *NodeBase, data: ElementData, kind: PseudoClassKind) bool {
        if (self.state_reads) |reads| {
            if (kind == .FocusVisible) {
                // Selectors 4 9.4: modality can change without focus or a
                // tree mutation. Only focused elements read that state:
                // the universal UA rule must not make every style volatile.
                const element = instanceOf(node) orelse return false;
                if (!focus_matching.matchesFocus(element)) return false;
                reads.@"volatile" = true;
                return focus_matching.matchesFocusVisible(element);
            }
            if (!reads.@"volatile" and readsVolatileState(kind, data)) reads.@"volatile" = true;
        }
        return self.matchesPseudoClass(node, data, kind);
    }

    fn matchesPseudoClass(self: *const Matcher, node: *NodeBase, data: ElementData, kind: PseudoClassKind) bool {
        const element = instanceOf(node) orelse return false;
        return switch (kind) {
            // 13.1: "the root of the document".
            .Root => if (node.parent_node) |parent| parent.node_type == DOCUMENT_NODE else false,
            .Empty => isEmpty(node),
            // 13.3/13.4: among the element's inclusive siblings - an element
            // with no parent is its own only sibling (all three engines,
            // css/selectors/child-indexed-pseudo-class.html).
            .FirstChild => previousElementSibling(node) == null,
            .LastChild => nextElementSibling(node) == null,
            .OnlyChild => previousElementSibling(node) == null and nextElementSibling(node) == null,
            .FirstOfType => self.typeIndex(node, data, false) == 1,
            .LastOfType => self.typeIndex(node, data, true) == 1,
            .OnlyOfType => self.typeIndex(node, data, false) == 1 and self.typeIndex(node, data, true) == 1,
            .NthChild => |pattern| self.matchesNthChild(node, pattern, false),
            .NthLastChild => |pattern| self.matchesNthChild(node, pattern, true),
            .NthOfType => |pattern| matchesNth(self.typeIndex(node, data, false), pattern),
            .NthLastOfType => |pattern| matchesNth(self.typeIndex(node, data, true), pattern),

            .Not => |list| !self.matchesList(.{ .node = node }, list),
            .Is, .Where => |list| self.matchesList(.{ .node = node }, list),
            .Has => |list| self.matchesHas(node, list),
            .Scope => self.matchesScope(node),
            // Only the featureless host matches it (matchesFeaturelessCompound).
            .Host => false,
            .Lang => |ranges| self.matchesLang(node, ranges),

            .Dir => |direction| switch (direction) {
                .ltr => html_pseudo_classes.matches(element, .dir_ltr),
                .rtl => html_pseudo_classes.matches(element, .dir_rtl),
                .other => false,
            },
            // HTML 4.16.3, through the states the Document keeps
            // (dom.pointer_states): only selectors using them pay for them.
            .Hover => html_pseudo_classes.matches(element, .hover),
            .Active => html_pseudo_classes.matches(element, .active),
            // The focus state of the element's top-level traversable
            // (html.focus), through the hook Document installs.
            .Focus => focus_matching.matchesFocus(element),
            .FocusWithin => focus_matching.matchesFocusWithin(element),
            .FocusVisible => focus_matching.matchesFocusVisible(element),
            // HTML 4.13.7.5: the identifier is in the element's states set.
            .State => |name| custom_elements.matchesState(element, name),
            .Defined => custom_elements.isDefined(element),
            // Selectors 4 8.2 / HTML: the document's target element.
            .Target => if (self.document) |document| target_element.get(document) == element else false,
            .AnyLink, .Link => html_pseudo_classes.matches(element, .any_link),
            .Visited => html_pseudo_classes.matches(element, .visited),
            .Enabled => html_pseudo_classes.matches(element, .enabled),
            .Disabled => html_pseudo_classes.matches(element, .disabled),
            .ReadOnly => html_pseudo_classes.matches(element, .read_only),
            .ReadWrite => html_pseudo_classes.matches(element, .read_write),
            .Checked => html_pseudo_classes.matches(element, .checked),
            .Valid => html_pseudo_classes.matches(element, .valid),
            .Invalid => html_pseudo_classes.matches(element, .invalid),
            .Default => html_pseudo_classes.matches(element, .default),
            .Indeterminate => html_pseudo_classes.matches(element, .indeterminate),
            .Required => html_pseudo_classes.matches(element, .required),
            .Optional => html_pseudo_classes.matches(element, .optional),
            .InRange => html_pseudo_classes.matches(element, .in_range),
            .OutOfRange => html_pseudo_classes.matches(element, .out_of_range),
            .PlaceholderShown => html_pseudo_classes.matches(element, .placeholder_shown),
            .Autofill => html_pseudo_classes.matches(element, .autofill),
            .UserValid => html_pseudo_classes.matches(element, .user_valid),
            .UserInvalid => html_pseudo_classes.matches(element, .user_invalid),
            .Open => html_pseudo_classes.matches(element, .open),
            .PopoverOpen => html_pseudo_classes.matches(element, .popover_open),
            .Modal => html_pseudo_classes.matches(element, .modal),
            .Playing => html_pseudo_classes.matches(element, .playing),
            .Paused => html_pseudo_classes.matches(element, .paused),
            .Seeking => html_pseudo_classes.matches(element, .seeking),
            .Buffering => html_pseudo_classes.matches(element, .buffering),
            .Stalled => html_pseudo_classes.matches(element, .stalled),
            .Muted => html_pseudo_classes.matches(element, .muted),
            .VolumeLocked => html_pseudo_classes.matches(element, .volume_locked),
            .Heading => |levels| html_pseudo_classes.matches(element, .{ .heading = levels }),
            // The UA sheet's :-internal-list-box (HTML 15.5.16).
            .InternalListBox => selectKindOf(data) == .list_box,
        };
    }

    /// Selectors 4 8.4 :scope - the scoping root when it is an element. A
    /// document scoping root makes it its document element; a
    /// DocumentFragment or shadow root one matches nothing, as in all three
    /// engines (css/selectors/scope-selector.html: `:scope > div` in a
    /// shadow root or fragment finds nothing) - the spec's "virtual scoping
    /// root" that would be the parent of the fragment's top-level elements
    /// ships nowhere.
    fn matchesScope(self: *const Matcher, node: *NodeBase) bool {
        if (self.scope == node) return true;
        if (self.scope.node_type == DOCUMENT_NODE) return node.parent_node == self.scope;
        return false;
    }

    /// CSS Scoping 3.2.1 :host(<compound>): the host matches the compound,
    /// as an ordinary element.
    fn hostMatches(self: *const Matcher, host: *NodeBase, list: *const SelectorList) bool {
        return self.matchesList(.{ .node = host }, list);
    }

    /// Selectors 4 4.5 :has(): one of the relative selectors matches an
    /// element when anchored at `node`. A relative selector starting with a
    /// descendant or child combinator can only match inside `node`'s
    /// subtree; one starting with a sibling combinator only among its later
    /// siblings and their subtrees.
    fn matchesHas(self: *const Matcher, node: *NodeBase, list: *const SelectorList) bool {
        var anchored = self.*;
        anchored.anchor = node;
        for (list.selectors) |*relative| {
            const combinator = relative.initial_combinator orelse .Descendant;
            const simple_chain = relative.combinators.len == 0;
            switch (combinator) {
                .Descendant, .Child => {
                    if (simple_chain and combinator == .Child) {
                        var child = node.first_child;
                        while (child) |c| : (child = c.next_sibling) {
                            if (c.node_type == ELEMENT_NODE and anchored.matchesComplex(.{ .node = c }, relative)) return true;
                        }
                        continue;
                    }
                    var walk = Walk.init(node);
                    while (walk.next()) |candidate| {
                        if (anchored.matchesComplex(.{ .node = candidate }, relative)) return true;
                    }
                },
                .NextSibling, .SubsequentSibling => {
                    var sibling = nextElementSibling(node);
                    while (sibling) |s| : (sibling = nextElementSibling(s)) {
                        if (anchored.matchesComplex(.{ .node = s }, relative)) return true;
                        if (!simple_chain) {
                            var walk = Walk.init(s);
                            while (walk.next()) |candidate| {
                                if (anchored.matchesComplex(.{ .node = candidate }, relative)) return true;
                            }
                        }
                        if (simple_chain and combinator == .NextSibling) break;
                    }
                },
            }
        }
        return false;
    }

    /// 13.3.1 :nth-child(An+B [of S]): the element's 1-based index among its
    /// inclusive siblings - only those matching S, which the element must
    /// match too, with "of S".
    fn matchesNthChild(self: *const Matcher, node: *NodeBase, pattern: NthPattern, from_end: bool) bool {
        if (pattern.of) |of| {
            if (!self.matchesList(.{ .node = node }, of)) return false;
            var index: i64 = 1;
            var sibling = if (from_end) nextElementSibling(node) else previousElementSibling(node);
            while (sibling) |s| : (sibling = if (from_end) nextElementSibling(s) else previousElementSibling(s)) {
                if (self.matchesList(.{ .node = s }, of)) index += 1;
            }
            return matchesNth(index, pattern);
        }
        if (self.cachedIndices(node)) |indices| return matchesNth(if (from_end) indices.last_child else indices.child, pattern);
        var index: i64 = 1;
        var sibling = if (from_end) nextElementSibling(node) else previousElementSibling(node);
        while (sibling) |s| : (sibling = if (from_end) nextElementSibling(s) else previousElementSibling(s)) index += 1;
        return matchesNth(index, pattern);
    }

    /// The element's index among its inclusive siblings, and of its type,
    /// from either end - O(1) through the query's cache once its parent has
    /// many children. Null to count directly: a short sibling list, no
    /// cache (matches(), closest()), or no memory for one.
    fn cachedIndices(self: *const Matcher, node: *NodeBase) ?NthIndexCache.Indices {
        const cache = self.nth_cache orelse return null;
        if (cache.map.get(node)) |indices| return indices;
        const parent = node.parent_node orelse return null;
        if (!hasManyElementChildren(parent)) return null;
        cache.fill(parent) catch return null;
        return cache.map.get(node);
    }

    /// 13.4: the element's 1-based index among its inclusive siblings of the
    /// same type, from the first (or the last).
    fn typeIndex(self: *const Matcher, node: *NodeBase, data: ElementData, from_end: bool) i64 {
        if (self.cachedIndices(node)) |indices| return if (from_end) indices.last_of_type else indices.of_type;
        return countTypeIndex(node, data, from_end);
    }

    /// Selectors 4 7.2 :lang(): the element's content language matches one
    /// of the ranges by extended filtering (RFC 4647 3.3.2), ASCII
    /// case-insensitively.
    fn matchesLang(self: *const Matcher, node: *NodeBase, ranges: []const []const u8) bool {
        _ = self;
        const language = languageOf(node);
        for (ranges) |range| {
            if (languageRangeMatches(language, range)) return true;
        }
        return false;
    }
};

// ============================================================================
// Helpers
// ============================================================================

/// HTML 4.16.2 and Selectors 4 6.1-6.3: the attribute's value against the
/// selector's. `i` is ASCII case-insensitive and `s` identical-to; without
/// one, an attribute (in no namespace) on HTML's list of an HTML element in
/// an HTML document compares ASCII case-insensitively.
fn matchesValue(attribute: *const AttributeSelector, entry: *const AttributeEntry, html: bool) bool {
    const insensitive = switch (attribute.case) {
        .insensitive => true,
        .sensitive => false,
        .default => attribute.html_case_insensitive_value and html and entry.namespace_uri == null,
    };
    const value = entry.value;
    return switch (attribute.matcher) {
        .Presence => true,
        .Exact => |m| eql(value, m.value, insensitive),
        // 6.2: "If "val" is the empty string then the selector does not
        // represent anything."
        .Prefix => |m| m.value.len != 0 and value.len >= m.value.len and eql(value[0..m.value.len], m.value, insensitive),
        .Suffix => |m| m.value.len != 0 and value.len >= m.value.len and eql(value[value.len - m.value.len ..], m.value, insensitive),
        .Substring => |m| m.value.len != 0 and contains(value, m.value, insensitive),
        // 6.1 [att~=val]: a whitespace-separated word; "If "val" contains
        // whitespace, it will never represent anything ... nor if it is the
        // empty string."
        .Includes => |m| blk: {
            if (m.value.len == 0 or std.mem.indexOfAny(u8, m.value, " \t\n\r\x0C") != null) break :blk false;
            var words = std.mem.tokenizeAny(u8, value, " \t\n\r\x0C");
            while (words.next()) |word| if (eql(word, m.value, insensitive)) break :blk true;
            break :blk false;
        },
        // [att|=val]: exactly val, or val immediately followed by "-".
        .DashMatch => |m| eql(value, m.value, insensitive) or
            (value.len > m.value.len and value[m.value.len] == '-' and eql(value[0..m.value.len], m.value, insensitive)),
    };
}

fn eql(a: []const u8, b: []const u8, insensitive: bool) bool {
    return if (insensitive) std.ascii.eqlIgnoreCase(a, b) else std.mem.eql(u8, a, b);
}

fn contains(haystack: []const u8, needle: []const u8, insensitive: bool) bool {
    if (!insensitive) return std.mem.indexOf(u8, haystack, needle) != null;
    return std.ascii.findIgnoreCase(haystack, needle) != null;
}

/// Whether the class attribute value `classes`, split on ASCII whitespace
/// (DOM's ordered set parser), holds `name`.
fn classListHas(classes: []const u8, name: []const u8, insensitive: bool) bool {
    if (name.len == 0 or classes.len < name.len) return false;
    if (insensitive) {
        var words = std.mem.tokenizeAny(u8, classes, " \t\n\r\x0C");
        while (words.next()) |word| if (std.ascii.eqlIgnoreCase(word, name)) return true;
        return false;
    }
    // Find `name` where whitespace or an end bounds it on both sides: a
    // substring search, no tokenizing (the common class attribute holds one
    // or two names).
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, classes, from, name)) |at| {
        const end = at + name.len;
        if ((at == 0 or isAsciiWhitespace(classes[at - 1])) and (end == classes.len or isAsciiWhitespace(classes[end]))) {
            // A name holding whitespace (`.a\ b`) is no token, though its
            // bytes may appear bounded by whitespace ("a b"): Blink's token
            // vector never holds it. Checked on a hit only.
            for (name) |c| if (isAsciiWhitespace(c)) return false;
            return true;
        }
        from = at + 1;
    }
    return false;
}

fn isAsciiWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0x0C;
}

/// How querySelector tests each candidate: a selector of exactly one simple
/// selector directly (a type selector in any namespace, a class, an ID, an
/// attribute selector, or `*`); a one-selector list through a filter on its
/// subject's first simple selector, then the full matcher; anything else
/// through the full matcher.
const FastPath = union(enum) {
    none,
    filtered: SubjectFilter,
    all,
    tag: SubjectFilter.Tag,
    class: *const selector.ClassSelector,
    id: []const u8,
    attribute: *const AttributeSelector,

    fn of(list: *const SelectorList) FastPath {
        if (list.selectors.len != 1) return .none;
        const complex = &list.selectors[0];
        if (complex.is_relative) return .none;
        const compound = &complex.compound;
        if (complex.combinators.len == 0 and compound.simple_selectors.len == 1 and !compound.active_hover_quirk) {
            const first = &compound.simple_selectors[0];
            switch (first.*) {
                .Universal => |universal| if (universal.namespace == .any) return .all,
                .Type => |t| if (t.namespace == .any) return .{ .tag = .{ .name = t.tag_name, .lower_name = t.lower_name } },
                .Class => |*c| return .{ .class = c },
                .Id => |id| return .{ .id = id.id },
                .Attribute => |*attribute| return .{ .attribute = attribute },
                else => {},
            }
        }
        return if (SubjectFilter.of(compound)) |filter| .{ .filtered = filter } else .none;
    }
};

/// The first simple selector of a subject compound, when it is one an
/// element can be rejected by cheaply.
const SubjectFilter = union(enum) {
    tag: Tag,
    class: *const selector.ClassSelector,
    id: []const u8,

    const Tag = struct { name: []const u8, lower_name: []const u8 };

    fn of(compound: *const CompoundSelector) ?SubjectFilter {
        if (compound.simple_selectors.len == 0) return null;
        const first = &compound.simple_selectors[0];
        return switch (first.*) {
            .Type => |t| if (t.namespace == .any) .{ .tag = .{ .name = t.tag_name, .lower_name = t.lower_name } } else null,
            .Class => |*c| .{ .class = c },
            .Id => |id| .{ .id = id.id },
            else => null,
        };
    }
};

/// 13.2 :empty: no element child and no text (Selectors 3's "text nodes
/// ... must be considered" content; comments and processing instructions
/// are not).
fn isEmpty(node: *NodeBase) bool {
    var child = node.first_child;
    while (child) |c| : (child = c.next_sibling) {
        switch (c.node_type) {
            ELEMENT_NODE, TEXT_NODE, CDATA_SECTION_NODE => return false,
            else => {},
        }
    }
    return true;
}

/// The element's 1-based index among its inclusive siblings of the same
/// type, from the first (or the last), counted.
fn countTypeIndex(node: *NodeBase, data: ElementData, from_end: bool) i64 {
    var index: i64 = 1;
    var sibling = if (from_end) nextElementSibling(node) else previousElementSibling(node);
    while (sibling) |s| : (sibling = if (from_end) nextElementSibling(s) else previousElementSibling(s)) {
        const other = dataOf(s) orelse continue;
        if (sameType(data, other)) index += 1;
    }
    return index;
}

/// One query's child indices (Stylo's NthIndexCache, Blink's
/// NthIndexCache): counting an element's earlier siblings for each element
/// of a long sibling list is quadratic in its length, so the first element
/// asked about in such a list fills the indices of all its siblings in one
/// pass. The tree does not change during a query.
const NthIndexCache = struct {
    allocator: std.mem.Allocator,
    map: std.AutoHashMapUnmanaged(*NodeBase, Indices) = .empty,

    const Indices = struct {
        child: i64,
        last_child: i64,
        of_type: i64,
        last_of_type: i64,
    };

    fn deinit(self: *NthIndexCache) void {
        self.map.deinit(self.allocator);
    }

    /// Every element child of `parent`, indexed: forward for the positions
    /// and the running per-type counts, then backward from the totals.
    fn fill(self: *NthIndexCache, parent: *NodeBase) std.mem.Allocator.Error!void {
        var types: std.HashMapUnmanaged(TypeKey, i64, TypeKey.Context, std.hash_map.default_max_load_percentage) = .empty;
        defer types.deinit(self.allocator);
        var total: i64 = 0;
        var child = parent.first_child;
        while (child) |c| : (child = c.next_sibling) {
            if (c.node_type != ELEMENT_NODE) continue;
            const key = TypeKey.of(c);
            const seen = try types.getOrPut(self.allocator, key);
            if (!seen.found_existing) seen.value_ptr.* = 0;
            seen.value_ptr.* += 1;
            total += 1;
            try self.map.put(self.allocator, c, .{ .child = total, .last_child = 0, .of_type = seen.value_ptr.*, .last_of_type = 0 });
        }
        child = parent.first_child;
        while (child) |c| : (child = c.next_sibling) {
            if (c.node_type != ELEMENT_NODE) continue;
            const indices = self.map.getPtr(c).?;
            indices.last_child = total - indices.child + 1;
            indices.last_of_type = types.get(TypeKey.of(c)).? - indices.of_type + 1;
        }
    }

    /// An element's type: its local name and namespace (13.4).
    const TypeKey = struct {
        local: []const u8,
        namespace: []const u8,

        fn of(node: *NodeBase) TypeKey {
            const data = dataOf(node) orelse return .{ .local = "", .namespace = "" };
            return .{ .local = data.localName(), .namespace = data.namespaceSlice() orelse "" };
        }

        const Context = struct {
            pub fn hash(_: Context, key: TypeKey) u64 {
                var hasher = std.hash.Wyhash.init(0);
                hasher.update(key.local);
                hasher.update("\x00");
                hasher.update(key.namespace);
                return hasher.final();
            }
            pub fn eql(_: Context, a: TypeKey, b: TypeKey) bool {
                return std.mem.eql(u8, a.local, b.local) and std.mem.eql(u8, a.namespace, b.namespace);
            }
        };
    };
};

/// Whether `parent` has enough element children for the cache to pay: below
/// that, counting siblings directly costs less than filling it.
fn hasManyElementChildren(parent: *NodeBase) bool {
    var count: usize = 0;
    var child = parent.first_child;
    while (child) |c| : (child = c.next_sibling) {
        if (c.node_type != ELEMENT_NODE) continue;
        count += 1;
        if (count >= 32) return true;
    }
    return false;
}

/// CSS Syntax 3 6: the index is An+B for some integer n >= 0.
pub fn matchesNth(index: i64, pattern: NthPattern) bool {
    const a: i64 = pattern.a;
    const b: i64 = pattern.b;
    if (a == 0) return index == b;
    const diff = index - b;
    // n = diff / a must be a non-negative integer.
    if (@rem(diff, a) != 0) return false;
    return @divTrunc(diff, a) >= 0;
}

/// HTML 3.2.6.2: the language of an element - the first of its xml:lang
/// (XML namespace), its lang in no namespace (HTML and SVG elements), its
/// shadow root's host's language, its parent element's, then its document's
/// pragma-set default. HTTP Content-Language is not recorded yet, so the
/// final fallback is the empty string (unknown).
fn languageOf(start: *NodeBase) []const u8 {
    var current: ?*NodeBase = start;
    while (current) |node| {
        if (node.node_type == ELEMENT_NODE) {
            if (dataOf(node)) |data| {
                if (element_data.getAttributeByNamespaceAndLocalName(data, xml_namespace, "lang")) |attr| return attr.value;
                if (namespaceIs(data, html_namespace) or namespaceIs(data, svg_namespace)) {
                    if (element_data.getAttributeByNamespaceAndLocalName(data, null, "lang")) |attr| return attr.value;
                }
            }
        }
        const parent = node.parent_node orelse break;
        if (isShadowRoot(parent)) {
            current = hostOf(parent);
        } else if (parent.node_type == ELEMENT_NODE) {
            current = parent;
        } else break;
    }
    const instance = instanceOf(start) orelse return "";
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return "";
    return @import("document_language.zig").get(document) orelse "";
}

/// Selectors 4 7.2 and RFC 4647 3.3.2 "Extended Filtering", ASCII
/// case-insensitive. A wildcard range does not match an untagged language
/// (the empty string); the empty range matches only that.
pub fn languageRangeMatches(language: []const u8, range: []const u8) bool {
    if (range.len == 0) return language.len == 0;
    if (language.len == 0) return false;
    var range_tags = std.mem.splitScalar(u8, range, '-');
    var tags = std.mem.splitScalar(u8, language, '-');
    // 1-2: the first subtags match, or the range's is "*".
    const first_range = range_tags.next().?;
    const first_tag = tags.next().?;
    if (!std.mem.eql(u8, first_range, "*") and !std.ascii.eqlIgnoreCase(first_range, first_tag)) return false;
    var tag = tags.next();
    // 3: each remaining range subtag.
    while (range_tags.next()) |subtag| {
        // A: "*" matches zero or more subtags.
        if (std.mem.eql(u8, subtag, "*")) continue;
        while (true) {
            // B: no more language subtags: fail.
            const current = tag orelse return false;
            // C: equal subtags: on to the next of both.
            if (std.ascii.eqlIgnoreCase(subtag, current)) {
                tag = tags.next();
                break;
            }
            // D: a singleton subtag in the language: fail.
            if (current.len == 1) return false;
            // E: skip the language subtag and try again.
            tag = tags.next();
        }
    }
    // 4: the range's subtags are exhausted: match.
    return true;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "An+B: index is An+B for some n >= 0" {
    try testing.expect(matchesNth(3, .{ .a = 4, .b = -1 }));
    try testing.expect(matchesNth(7, .{ .a = 4, .b = -1 }));
    try testing.expect(!matchesNth(4, .{ .a = 4, .b = -1 }));
    try testing.expect(matchesNth(1, .{ .a = -1, .b = 3 }));
    try testing.expect(matchesNth(3, .{ .a = -1, .b = 3 }));
    try testing.expect(!matchesNth(4, .{ .a = -1, .b = 3 }));
    try testing.expect(matchesNth(5, .{ .a = 0, .b = 5 }));
    try testing.expect(!matchesNth(1, .{ .a = 0, .b = 0 }));
    try testing.expect(matchesNth(2, .{ .a = 2, .b = 0 }));
    try testing.expect(!matchesNth(1, .{ .a = 2, .b = 0 }));
}

test "extended filtering per RFC 4647 3.3.2, as :lang() uses it" {
    try testing.expect(languageRangeMatches("en", "en"));
    try testing.expect(languageRangeMatches("en-US", "en"));
    try testing.expect(languageRangeMatches("EN-us", "en-US"));
    try testing.expect(!languageRangeMatches("en", "en-US"));
    try testing.expect(!languageRangeMatches("fr", "en"));
    // Implicit wildcards between subtags.
    try testing.expect(languageRangeMatches("de-Latn-DE", "de-DE"));
    try testing.expect(languageRangeMatches("de-DE-1996", "de-DE"));
    try testing.expect(!languageRangeMatches("de-x-DE", "de-DE"));
    // A leading wildcard.
    try testing.expect(languageRangeMatches("de-CH", "*-CH"));
    try testing.expect(languageRangeMatches("und", "*"));
    try testing.expect(!languageRangeMatches("", "*"));
    // The empty range matches only an untagged language.
    try testing.expect(languageRangeMatches("", ""));
    try testing.expect(!languageRangeMatches("en", ""));
}

test "class lists: a whole name bounded by ASCII whitespace or an end" {
    try testing.expect(classListHas("row", "row", false));
    try testing.expect(classListHas("a\trow\nb", "row", false));
    try testing.expect(!classListHas("rows narrow", "row", false));
    try testing.expect(classListHas("narrow row", "row", false));
    try testing.expect(!classListHas("", "row", false));
    try testing.expect(classListHas("A ROW", "row", true));
    try testing.expect(!classListHas("ROW", "row", false));
    // A name with whitespace is no class (Blink: no token holds it).
    try testing.expect(!classListHas("a b", "a b", false));
    try testing.expect(!classListHas("x a\tb", "a\tb", true));
}

test "attribute values: empty operands never match, ~= splits on ASCII whitespace" {
    const entry = AttributeEntry{ .namespace_uri = null, .prefix = null, .local_name = "class", .value = "a\tb" };
    var attribute = AttributeSelector{ .name = "class", .lower_name = "class", .matcher = .{ .Prefix = .{ .value = "" } } };
    try testing.expect(!matchesValue(&attribute, &entry, true));
    attribute.matcher = .{ .Suffix = .{ .value = "" } };
    try testing.expect(!matchesValue(&attribute, &entry, true));
    attribute.matcher = .{ .Substring = .{ .value = "" } };
    try testing.expect(!matchesValue(&attribute, &entry, true));
    attribute.matcher = .{ .Includes = .{ .value = "b" } };
    try testing.expect(matchesValue(&attribute, &entry, true));
    attribute.matcher = .{ .Includes = .{ .value = "a b" } };
    try testing.expect(!matchesValue(&attribute, &entry, true));
}

test "HTML's case-insensitive value list applies only to HTML elements in HTML documents" {
    const entry = AttributeEntry{ .namespace_uri = null, .prefix = null, .local_name = "type", .value = "HEY\u{CF}" };
    var attribute = AttributeSelector{ .name = "type", .lower_name = "type", .matcher = .{ .Prefix = .{ .value = "hey" } }, .html_case_insensitive_value = true };
    try testing.expect(matchesValue(&attribute, &entry, true));
    try testing.expect(!matchesValue(&attribute, &entry, false));
    // ASCII case-insensitive: Ï is not ï.
    attribute.matcher = .{ .Prefix = .{ .value = "hey\u{EF}" } };
    try testing.expect(!matchesValue(&attribute, &entry, true));
    // `s` overrides the list.
    attribute.matcher = .{ .Prefix = .{ .value = "hey" } };
    attribute.case = .sensitive;
    try testing.expect(!matchesValue(&attribute, &entry, true));
}

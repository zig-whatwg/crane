//! The style engine of a Document (Blink's StyleEngine): which style sheets
//! apply to it, in CSSOM's "final CSS style sheets" order, and the computed
//! style of each of its elements, resolved when something asks.
//!
//! Sheets. The elements that own sheets (style and link) register as
//! candidates while they are connected - Blink's AddStyleSheetCandidateNode
//! / RemoveStyleSheetCandidateNode - and bump `sheets_version` whenever
//! their sheet changes. The active sheets are rebuilt from the candidates,
//! in tree order, the first time style is asked for after a change: each
//! enabled sheet whose media matches (CSSOM 6.2 and the "add a CSS style
//! sheet" disabled-flag steps), its @import sheets substituted where their
//! rules stand (Cascade 5 6.1), with the author layers ordered per 6.4.3.
//!
//! Computed style. WebKit's Element::resolveComputedStyle shape: walk the
//! element's flat-tree ancestors, resolve from the rootmost one whose
//! cached style is missing, stale or volatile, downward, caching each in
//! the element's own ElementStyle. A cached style is valid while its key
//! still holds (design section 5.1) - the document's DOM tree version
//! (which every mutation already moves), the engine's generation (sheets,
//! their contents, the media environment) and the document's focus, hover,
//! active and target elements - unless matching read per-element dynamic
//! state (5.3), which makes it volatile. All of it is pulled when a style
//! is read: no mutation path runs any of this code.
//!
//! Shadow trees (CSS Scoping 3): each connected shadow tree's sheets are a
//! scope of their own - matched against the tree's elements, their :host
//! rules against the host - ordered by tree context (Cascade 5 6.1: for
//! normal declarations the outer context wins, for important ones the
//! inner); the document's sheets do not apply in a shadow tree. Slot
//! assignment, which can change with no mutation, moves `slot_version`,
//! part of every cached style's key. ::slotted() rules of a slot's tree
//! apply to the elements assigned to the slot, after flattening, and
//! ::part() rules of a host's tree to the elements of its shadow tree with
//! those part names (stated: exportparts forwards nothing yet).
//!
//! Spec: https://drafts.csswg.org/cssom-1/#css-style-sheet-collections
//! Spec: https://drafts.csswg.org/css-cascade-5/#value-stages
//! Spec: https://drafts.csswg.org/css-scoping-1/#flattening

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const css = @import("css");
const NodeBase = @import("../node_base.zig").NodeBase;
const instance_bridge = @import("../instance_bridge.zig");
const element_data = @import("../element_data.zig");
const refcount = @import("../refcount.zig");
const document_internals = @import("../document_internals.zig");
const focused_area = @import("../focused_area.zig");
const pointer_states = @import("../pointer_states.zig");
const target_element = @import("../target_element.zig");
const slot_helpers = @import("../slot_helpers.zig");
const custom_elements = @import("../custom_elements.zig");
const navigable_container = @import("../navigable_container.zig");
const selector_matching = @import("../selector_matching.zig");
const hooks = @import("hooks.zig");
const sheet_mod = @import("sheet.zig");
const ua_sheet = @import("ua_sheet.zig");
const element_style = @import("element_style.zig");

const ComputedStyle = css.computed_style.ComputedStyle;
const MediaValues = css.media_queries.MediaValues;
const Matched = css.cascade.Matched;
const SheetRecord = sheet_mod.SheetRecord;
const Contents = sheet_mod.Contents;
const ElementStyle = element_style.ElementStyle;
const Key = element_style.Key;

const html_namespace = "http://www.w3.org/1999/xhtml";
const svg_namespace = "http://www.w3.org/2000/svg";
const mathml_namespace = "http://www.w3.org/1998/Math/MathML";

pub const Error = Allocator.Error;

/// A registered sheet owner: an element that may have a sheet.
const Owner = struct {
    element: *runtime.Instance,
    generation: u64,

    fn live(self: Owner) bool {
        return runtime.SlabAllocator.generationOf(self.element) == self.generation;
    }
};

/// One sheet in the cascade, in final order.
const ActiveSheet = struct {
    /// Held while the active sheets are: a sheet removed since they were
    /// built is still here, and freed, when they are next rebuilt.
    record: *SheetRecord,
    contents: *Contents,
    contents_version: u64,
    /// Order of appearance base: the sheet's index, shifted past every rule
    /// position in it.
    order_base: u32,
    /// Each of the sheet's layers' place in the document's author layer
    /// order.
    layer_order: []u16,
    /// The layer an `@import ... layer(...)` put the whole sheet in.
    import_layer: ?u16,
};

/// A shadow tree's sheets in the cascade (CSS Scoping 3: a shadow root's
/// style sheets apply to its tree, :host rules to its host, ::slotted rules
/// to what its slots are assigned).
const Scope = struct {
    /// The shadow root, as a tree node.
    root: *NodeBase,
    /// Its shadow-including depth: 1 for a shadow tree in the document, 2
    /// for one inside it (Cascade 5 6.1 "Context").
    depth: u16,
    sheets: std.ArrayList(ActiveSheet) = .empty,

    fn deinit(self: *Scope, allocator: Allocator) void {
        freeSheets(allocator, &self.sheets);
    }
};

fn freeSheets(allocator: Allocator, sheets: *std.ArrayList(ActiveSheet)) void {
    for (sheets.items) |s| {
        allocator.free(s.layer_order);
        s.record.unref();
    }
    sheets.deinit(allocator);
}

const Active = struct {
    sheets_version: u64,
    media: MediaValues,
    quirks: bool,
    /// The document tree's sheets.
    sheets: std.ArrayList(ActiveSheet) = .empty,
    /// Each connected shadow tree's that has any.
    scopes: std.ArrayList(Scope) = .empty,
    /// Every top-level sheet the build looked at - the disabled ones and
    /// those whose media did not match too - with the version it saw, held:
    /// a sheet enabled again or edited moves its version.
    watched: std.ArrayList(Watched) = .empty,

    const Watched = struct { record: *SheetRecord, version: u64 };

    fn deinit(self: *Active, allocator: Allocator) void {
        freeSheets(allocator, &self.sheets);
        for (self.scopes.items) |*scope| scope.deinit(allocator);
        self.scopes.deinit(allocator);
        for (self.watched.items) |w| w.record.unref();
        self.watched.deinit(allocator);
    }

    /// The sheets of the shadow tree whose root is `root`, if it has any.
    fn scopeOf(self: *Active, root: *NodeBase) ?*Scope {
        for (self.scopes.items) |*scope| if (scope.root == root) return scope;
        return null;
    }

    /// `record` was looked at.
    fn watch(self: *Active, allocator: Allocator, record: *SheetRecord) Error!void {
        try self.watched.append(allocator, .{ .record = record, .version = record.contents_version });
        record.ref();
    }

    /// Whether every sheet's rules and flags are the ones it was built from.
    fn contentsCurrent(self: *const Active) bool {
        for (self.sheets.items) |s| if (s.record.contents_version != s.contents_version) return false;
        for (self.scopes.items) |scope| for (scope.sheets.items) |s| if (s.record.contents_version != s.contents_version) return false;
        for (self.watched.items) |w| if (w.record.contents_version != w.version) return false;
        return true;
    }
};

pub const StyleEngine = struct {
    allocator: Allocator,
    owners: std.ArrayList(Owner) = .empty,
    /// CSSOM View 4.2: the MediaQueryList objects whose document this is,
    /// in the order they were created - raw back links each list removes in
    /// its own teardown, the generation a teardown net. The engine never
    /// keeps a list alive.
    media_query_lists: std.ArrayList(Owner) = .empty,
    /// Shadow roots whose adoptedStyleSheets were set (a shadow tree with no
    /// style element is a scope only through them): raw back links with
    /// their generation, never holds.
    adopting_roots: std.ArrayList(Owner) = .empty,
    /// Moves whenever a slot's assigned nodes change (DOM "assign
    /// slottables"): part of each cached style's key, since a slotted
    /// element inherits from its slot.
    slot_version: u64 = 1,
    /// Moves on every change to the set of sheets or one of their flags
    /// (owners connecting and disconnecting, media, disabled, title).
    sheets_version: u64 = 1,
    active: ?Active = null,
    /// Moves every time the active sheets are rebuilt: part of each cached
    /// style's key.
    generation: u64 = 1,
    /// A style read of this document is resolving: nothing it reaches may
    /// read style again (the active sheets and the lineage's caches are in
    /// use). Checked in Debug builds (`enterResolution`).
    resolving: bool = false,
    /// HTML 4.2.5.1, "the page's supported color schemes": the color scheme
    /// support the first valid color-scheme meta element names
    /// (`Support.none` for null), as of the last style read that found
    /// `page_color_schemes_dirty` set. The engine is embedded in Document's
    /// state, so both bytes sit in this struct's tail padding: see
    /// tests/dom/style_engine_size_test.zig before adding a field.
    page_color_schemes: css.color_scheme.Support = .none,
    /// A color-scheme meta element was inserted into or removed from the
    /// document, or changed its name or content, since `page_color_schemes`
    /// was found ("user agents must re-run the above algorithm"): the next
    /// style read runs it, once for a whole batch of changes (Blink's
    /// Document::ColorSchemeMetaChanged and WebKit's
    /// metaElementColorSchemeChanged walk on every change). Set at first:
    /// nothing has run it for this document.
    page_color_schemes_dirty: bool = true,

    pub fn init(allocator: Allocator) StyleEngine {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *StyleEngine) void {
        if (self.active) |*a| a.deinit(self.allocator);
        self.active = null;
        self.owners.deinit(self.allocator);
        self.media_query_lists.deinit(self.allocator);
        self.adopting_roots.deinit(self.allocator);
    }

    /// The shadow root `root` adopted style sheets.
    pub fn addAdoptingRoot(self: *StyleEngine, root: *runtime.Instance) Error!void {
        for (self.adopting_roots.items) |o| if (o.element == root and o.live()) return;
        try self.adopting_roots.append(self.allocator, .{ .element = root, .generation = runtime.SlabAllocator.generationOf(root) });
    }

    /// A style read begins. Re-entering one - matching or a hook reaching
    /// computedStyle for the same document while it resolves - would rebuild
    /// the active sheets and replace cached styles under the outer read
    /// (Codex row 61 Q16): a Debug build stops there.
    fn enterResolution(self: *StyleEngine) void {
        if (builtin.mode == .Debug and self.resolving) @panic("dom.style.computedStyle re-entered while it resolves the same document");
        self.resolving = true;
    }

    /// A MediaQueryList whose document this is was made (matchMedia).
    pub fn addMediaQueryList(self: *StyleEngine, list: *runtime.Instance) Error!void {
        try self.media_query_lists.append(self.allocator, .{ .element = list, .generation = runtime.SlabAllocator.generationOf(list) });
    }

    /// The MediaQueryList `list` is going.
    pub fn removeMediaQueryList(self: *StyleEngine, list: *runtime.Instance) void {
        var i: usize = 0;
        while (i < self.media_query_lists.items.len) {
            const entry = self.media_query_lists.items[i];
            if (entry.element == list or !entry.live()) {
                _ = self.media_query_lists.orderedRemove(i);
                continue;
            }
            i += 1;
        }
    }

    /// `element` (a style or link element of this document) may own a
    /// sheet. Idempotent.
    pub fn addOwner(self: *StyleEngine, element: *runtime.Instance) Error!void {
        for (self.owners.items) |o| if (o.element == element and o.live()) {
            self.sheetsChanged();
            return;
        };
        try self.owners.append(self.allocator, .{ .element = element, .generation = runtime.SlabAllocator.generationOf(element) });
        self.sheetsChanged();
    }

    /// `element` no longer owns a sheet in this document.
    pub fn removeOwner(self: *StyleEngine, element: *runtime.Instance) void {
        var i: usize = 0;
        while (i < self.owners.items.len) {
            const o = self.owners.items[i];
            if (o.element == element or !o.live()) {
                _ = self.owners.swapRemove(i);
                continue;
            }
            i += 1;
        }
        self.sheetsChanged();
    }

    /// HTML 4.2.5.1's re-run trigger for the page's supported color schemes
    /// (HTMLMetaElement's own steps call it): the next style read finds
    /// them again.
    pub fn pageColorSchemesChanged(self: *StyleEngine) void {
        self.page_color_schemes_dirty = true;
    }

    /// A sheet of this document was made, removed or changed one of its
    /// flags: the active sheets are rebuilt when style is next read.
    pub fn sheetsChanged(self: *StyleEngine) void {
        self.sheets_version +%= 1;
    }

    /// The active sheets, rebuilt first if anything they depend on moved.
    fn ensureActive(self: *StyleEngine, document: *runtime.Instance) Error!*Active {
        const media = hooks.mediaValues(document);
        const quirks = isQuirks(document);
        if (self.active) |*a| {
            if (a.sheets_version == self.sheets_version and a.quirks == quirks and a.media.eql(media) and a.contentsCurrent()) return a;
            a.deinit(self.allocator);
            self.active = null;
        }
        var built: Active = .{ .sheets_version = self.sheets_version, .media = media, .quirks = quirks };
        errdefer built.deinit(self.allocator);
        try self.buildActive(document, &built);
        self.active = built;
        self.generation +%= 1;
        return &self.active.?;
    }

    /// CSSOM 6.2's final CSS style sheets of the document, enabled and
    /// matching.
    fn buildActive(self: *StyleEngine, document: *runtime.Instance, active: *Active) Error!void {
        // Owners in tree order (registration order is not tree order).
        var owners: std.ArrayList(*runtime.Instance) = .empty;
        defer owners.deinit(self.allocator);
        // A sheet in a shadow tree is that tree's, not the document's.
        var shadow_owners: std.ArrayList(*runtime.Instance) = .empty;
        defer shadow_owners.deinit(self.allocator);
        for (self.owners.items) |o| {
            if (!o.live()) continue;
            const node = instance_bridge.getNodeBase(o.element) orelse continue;
            if (!node.is_connected) continue;
            var root = node;
            while (root.parent_node) |p| root = p;
            if (root.node_type != NodeBase.DOCUMENT_NODE) {
                if (isShadowRoot(root)) try shadow_owners.append(self.allocator, o.element);
                continue;
            }
            try owners.append(self.allocator, o.element);
        }
        sortTreeOrder(owners.items);
        sortTreeOrder(shadow_owners.items);
        try self.buildScopes(document, active, shadow_owners.items);

        // CSSOM "add a CSS style sheet" steps 4-6: the preferred CSS style
        // sheet set name is the first titled, non-alternate sheet's title;
        // a titled sheet is enabled only when its title is that name. (The
        // spec sets it as sheets are added; tree order stands in, stated.)
        var preferred: ?[]const u8 = null;
        for (owners.items) |owner| {
            const record = hooks.sheetOf(owner) orelse continue;
            if (record.disabled) continue;
            if (record.title.len != 0 and !record.alternate and preferred == null) preferred = record.title;
        }

        var layers = LayerTree.init(self.allocator);
        defer layers.deinit();
        var pending: std.ArrayList(Pending) = .empty;
        defer pending.deinit(self.allocator);
        for (owners.items) |owner| {
            const record = hooks.sheetOf(owner) orelse continue;
            try active.watch(self.allocator, record);
            if (record.disabled) continue;
            if (record.title.len != 0) {
                const p = preferred orelse continue;
                if (!std.mem.eql(u8, p, record.title)) continue;
            }
            if (!record.mediaMatches(&active.media)) continue;
            try self.addSheet(document, record, null, &active.media, &layers, &pending, 0);
        }
        // CSSOM 6.2 "final CSS style sheets" 2: "The contents of
        // DocumentOrShadowRoot's adoptedStyleSheets' backing list, in array
        // order" - each enabled one whose media matches.
        if (hooks.adoptedSheetsOf(document)) |adopted| for (adopted.records.items) |record| {
            try active.watch(self.allocator, record);
            if (record.disabled or !record.mediaMatches(&active.media)) continue;
            try self.addSheet(document, record, null, &active.media, &layers, &pending, 0);
        };
        try self.finishSheets(&layers, &pending, &active.sheets);
    }

    /// Order the layers of one tree's sheets, then make each sheet's map.
    fn finishSheets(self: *StyleEngine, layers: *LayerTree, pending: *std.ArrayList(Pending), out: *std.ArrayList(ActiveSheet)) Error!void {
        try layers.order();
        for (pending.items, 0..) |p, index| {
            const map = try self.allocator.alloc(u16, p.contents.layers.items.len);
            errdefer self.allocator.free(map);
            for (p.layer_nodes, 0..) |node, i| map[i] = layers.nodes.items[node].rank;
            self.allocator.free(p.layer_nodes);
            p.record.ref();
            errdefer p.record.unref();
            try out.append(self.allocator, .{
                .record = p.record,
                .contents = p.contents,
                .contents_version = p.record.contents_version,
                .order_base = @as(u32, @intCast(index + 1)) << 20,
                .layer_order = map,
                .import_layer = if (p.import_layer_node) |n| layers.nodes.items[n].rank else null,
            });
        }
        pending.clearRetainingCapacity();
    }

    /// Each connected shadow tree's sheets: its style and link elements'
    /// (`owners`, in tree order) - enabled, media matching; a shadow tree has
    /// no style sheet sets (HTML gives a sheet a title only in a document
    /// tree) - then its adoptedStyleSheets. Each tree has its own layer
    /// order (Cascade 5 6.4.3: layers are per tree context).
    fn buildScopes(self: *StyleEngine, document: *runtime.Instance, active: *Active, owners: []const *runtime.Instance) Error!void {
        var roots: std.ArrayList(*NodeBase) = .empty;
        defer roots.deinit(self.allocator);
        for (owners) |owner| {
            var root = instance_bridge.getNodeBase(owner).?;
            while (root.parent_node) |p| root = p;
            if (std.mem.indexOfScalar(*NodeBase, roots.items, root) == null) try roots.append(self.allocator, root);
        }
        var i: usize = 0;
        while (i < self.adopting_roots.items.len) {
            const o = self.adopting_roots.items[i];
            if (!o.live()) {
                _ = self.adopting_roots.swapRemove(i);
                continue;
            }
            i += 1;
            const root = instance_bridge.getNodeBase(o.element) orelse continue;
            if (!root.is_connected and !hostConnected(root)) continue;
            if (root.node_type == NodeBase.DOCUMENT_NODE) continue;
            if (std.mem.indexOfScalar(*NodeBase, roots.items, root) == null) try roots.append(self.allocator, root);
        }
        for (roots.items) |root| {
            var layers = LayerTree.init(self.allocator);
            defer layers.deinit();
            var pending: std.ArrayList(Pending) = .empty;
            defer pending.deinit(self.allocator);
            for (owners) |owner| {
                var owner_root = instance_bridge.getNodeBase(owner).?;
                while (owner_root.parent_node) |p| owner_root = p;
                if (owner_root != root) continue;
                const record = hooks.sheetOf(owner) orelse continue;
                try active.watch(self.allocator, record);
                if (record.disabled or !record.mediaMatches(&active.media)) continue;
                try self.addSheet(document, record, null, &active.media, &layers, &pending, 0);
            }
            if (instanceOf(root)) |root_instance| if (hooks.adoptedSheetsOf(root_instance)) |adopted| for (adopted.records.items) |record| {
                try active.watch(self.allocator, record);
                if (record.disabled or !record.mediaMatches(&active.media)) continue;
                try self.addSheet(document, record, null, &active.media, &layers, &pending, 0);
            };
            if (pending.items.len == 0) continue;
            try active.scopes.append(self.allocator, .{ .root = root, .depth = shadowDepth(root) });
            try self.finishSheets(&layers, &pending, &active.scopes.items[active.scopes.items.len - 1].sheets);
        }
    }

    const Pending = struct {
        record: *SheetRecord,
        contents: *Contents,
        layer_nodes: []usize,
        import_layer_node: ?usize,
    };

    /// `record` and, before its own rules, its imports (Cascade 5 6.1:
    /// "as if their style sheets were substituted in place of the @import
    /// rule").
    fn addSheet(self: *StyleEngine, document: *runtime.Instance, record: *SheetRecord, parent_layer: ?usize, media: *const MediaValues, layers: *LayerTree, pending: *std.ArrayList(Pending), depth: usize) Error!void {
        if (depth > 16) return;
        var url_context = record.urlContext(document);
        const contents = try record.contentsOf(record.parseOptions(&url_context));
        // The sheet's layer declarations, in order, under `parent_layer`.
        const layer_nodes = try self.allocator.alloc(usize, contents.layers.items.len);
        var layer_nodes_owned = true;
        defer if (layer_nodes_owned) self.allocator.free(layer_nodes);
        for (contents.layers.items, 0..) |name, i| layer_nodes[i] = try layers.declare(parent_layer, name);
        for (contents.imports.items) |import_rule| {
            const child = import_rule.child orelse continue;
            if (!import_rule.media.matches(media)) continue;
            const child_layer: ?usize = if (import_rule.layer) |l| layer_nodes[l] else parent_layer;
            try self.addSheet(document, child, child_layer, media, layers, pending, depth + 1);
        }
        try pending.append(self.allocator, .{ .record = record, .contents = contents, .layer_nodes = layer_nodes, .import_layer_node = parent_layer });
        layer_nodes_owned = false;
    }
};

/// Cascade 5 6.4.3's layer order as a tree: layers sorted by first
/// declaration, nested layers grouped within their parent, and a parent's
/// own (implicit sub-layer) rules after its nested layers.
const LayerTree = struct {
    allocator: Allocator,
    nodes: std.ArrayList(Node) = .empty,

    const Node = struct {
        /// The full dotted name.
        name: []const u8,
        parent: ?usize,
        children: std.ArrayList(usize) = .empty,
        rank: u16 = 0,
    };

    fn init(allocator: Allocator) LayerTree {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *LayerTree) void {
        for (self.nodes.items) |*n| {
            n.children.deinit(self.allocator);
            self.allocator.free(n.name);
        }
        self.nodes.deinit(self.allocator);
    }

    /// The node for layer `name` (dotted) under `parent`, declared now if
    /// new; each dotted prefix is declared too.
    fn declare(self: *LayerTree, parent: ?usize, name: []const u8) Error!usize {
        var current = parent;
        var it = std.mem.splitScalar(u8, name, '.');
        while (it.next()) |segment| {
            const prefix = if (current) |c| self.nodes.items[c].name else "";
            const full = if (prefix.len == 0) try self.allocator.dupe(u8, segment) else try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, segment });
            var found: ?usize = null;
            for (self.nodes.items, 0..) |n, i| if (n.parent == current and std.mem.eql(u8, n.name, full)) {
                found = i;
            };
            if (found) |f| {
                self.allocator.free(full);
                current = f;
                continue;
            }
            self.nodes.append(self.allocator, .{ .name = full, .parent = current }) catch |err| {
                self.allocator.free(full);
                return err;
            };
            const index = self.nodes.items.len - 1;
            if (current) |c| try self.nodes.items[c].children.append(self.allocator, index);
            current = index;
        }
        return current.?;
    }

    /// Rank every layer: post-order, children before their parent.
    fn order(self: *LayerTree) Error!void {
        var rank: u16 = 0;
        for (self.nodes.items, 0..) |n, i| if (n.parent == null) self.visit(i, &rank);
    }

    fn visit(self: *LayerTree, index: usize, rank: *u16) void {
        for (self.nodes.items[index].children.items) |child| self.visit(child, rank);
        self.nodes.items[index].rank = rank.*;
        rank.* +|= 1;
    }
};

fn isQuirks(document: *runtime.Instance) bool {
    return document_internals.getMode(document) == .quirks;
}

/// Whether `a` precedes `b` in shadow-including tree order.
fn precedes(a: *NodeBase, b: *NodeBase) bool {
    if (a == b) return false;
    var chain_a: [256]*NodeBase = undefined;
    var chain_b: [256]*NodeBase = undefined;
    const la = ancestorChain(a, &chain_a);
    const lb = ancestorChain(b, &chain_b);
    // Walk down from the roots while they agree.
    var i: usize = 0;
    while (i < la and i < lb and chain_a[la - 1 - i] == chain_b[lb - 1 - i]) i += 1;
    if (i == la) return true; // a is an ancestor of b
    if (i == lb) return false;
    const sa = chain_a[la - 1 - i];
    const sb = chain_b[lb - 1 - i];
    var s = sa.next_sibling;
    while (s) |sib| : (s = sib.next_sibling) if (sib == sb) return true;
    return false;
}

fn ancestorChain(node: *NodeBase, out: *[256]*NodeBase) usize {
    var n: usize = 0;
    var current: ?*NodeBase = node;
    while (current) |c| : (current = c.parent_node) {
        if (n == out.len) break;
        out[n] = c;
        n += 1;
    }
    return n;
}

// ============================================================================
// Computed style
// ============================================================================

fn instanceOf(node: *NodeBase) ?*runtime.Instance {
    return @ptrCast(@alignCast(node.owner_instance orelse return null));
}

fn isShadowRoot(node: *NodeBase) bool {
    if (node.node_type != NodeBase.DOCUMENT_FRAGMENT_NODE) return false;
    const instance = instanceOf(node) orelse return false;
    return instance.vtable == &interfaces.ShadowRoot.vtable;
}

const FlatParent = union(enum) {
    /// The root element: no parent element.
    root,
    element: *NodeBase,
    /// Not in the flat tree (a shadow host's unassigned child), or not in
    /// a document.
    none,
};

/// CSS Scoping 2.1 "the flat tree": a slotted element's parent is its
/// slot, a shadow root's child's is the host, every other element's its
/// parent element.
fn flatParent(node: *NodeBase, slotted: *bool) FlatParent {
    slotted.* = false;
    if (slot_helpers.slottable(node)) |s| if (s.state.assignedSlot()) |slot| {
        slotted.* = true;
        return .{ .element = slot };
    };
    const parent = node.parent_node orelse return .none;
    switch (parent.node_type) {
        NodeBase.DOCUMENT_NODE => return .root,
        NodeBase.ELEMENT_NODE => {
            // A host's light child is in the flat tree only through a slot.
            if (parent.is_shadow_host) return .none;
            return .{ .element = parent };
        },
        NodeBase.DOCUMENT_FRAGMENT_NODE => {
            if (!isShadowRoot(parent)) return .none;
            const host = interfaces.ShadowRoot.get_host(instanceOf(parent) orelse return .none) catch return .none;
            return .{ .element = instance_bridge.getNodeBase(host) orelse return .none };
        },
        else => return .none,
    }
}

/// Whether the shadow root `root`'s host is connected.
fn hostConnected(root: *NodeBase) bool {
    if (!isShadowRoot(root)) return false;
    const host = interfaces.ShadowRoot.get_host(instanceOf(root) orelse return false) catch return false;
    const node = instance_bridge.getNodeBase(host) orelse return false;
    return node.is_connected;
}

/// The number of shadow roots on `root`'s shadow-including ancestor chain,
/// itself included: 0 for the document.
fn shadowDepth(root: *NodeBase) u16 {
    var depth: u16 = 0;
    var current: *NodeBase = root;
    while (isShadowRoot(current)) {
        depth +|= 1;
        const host = interfaces.ShadowRoot.get_host(instanceOf(current) orelse break) catch break;
        var next = instance_bridge.getNodeBase(host) orelse break;
        while (next.parent_node) |p| next = p;
        current = next;
    }
    return depth;
}

/// The document's singleton states, by address and generation.
fn singletonKey(document: *runtime.Instance) [5]u64 {
    var key: [5]u64 = .{0} ** 5;
    if (focused_area.get(document)) |d| if (d.isLive()) {
        key[0] = @intFromPtr(d.element) ^ d.generation;
    };
    const states = [_]pointer_states.State{ .hovered, .pointed, .activated };
    for (states, 0..) |state, i| {
        if (pointer_states.get(document, state)) |e| key[1 + i] = @intFromPtr(e) ^ runtime.SlabAllocator.generationOf(e);
    }
    if (target_element.get(document)) |e| key[4] = @intFromPtr(e) ^ runtime.SlabAllocator.generationOf(e);
    return key;
}

/// What resolving one lineage shares.
const Resolution = struct {
    allocator: Allocator,
    document: *runtime.Instance,
    engine: *StyleEngine,
    active: *Active,
    key: Key,
    root_font_size: f64 = 16,
    /// The page color scheme (CSS Color Adjustment 1 2.1) and the user's
    /// preferred one, found once per style read.
    page_color_scheme: css.color_scheme.Scheme = .light,
    preferred_color_scheme: css.color_scheme.Scheme = .light,
    matched: std.ArrayList(Matched) = .empty,
    candidates: std.ArrayList(u32) = .empty,

    fn deinit(self: *Resolution) void {
        self.matched.deinit(self.allocator);
        self.candidates.deinit(self.allocator);
    }
};

/// The computed style of `element` - or of its pseudo-element `pseudo`
/// (lowercase, without colons) - resolved now if its cached one is not
/// valid. Borrowed: valid until the next style read of the element. Null
/// for an element that has no style: not connected, not in the flat tree,
/// or before a Document installed its engine.
pub fn computedStyle(element: *runtime.Instance, pseudo: ?[]const u8) Error!?*const ComputedStyle {
    const node = instance_bridge.getNodeBase(element) orelse return null;
    if (node.node_type != NodeBase.ELEMENT_NODE or !node.is_connected) return null;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return null;
    const engine = hooks.engineOf(document) orelse return null;
    engine.enterResolution();
    defer engine.resolving = false;
    const active = try engine.ensureActive(document);
    var res: Resolution = .{
        .allocator = engine.allocator,
        .document = document,
        .engine = engine,
        .active = active,
        .key = .{ .tree_version = refcount.treeVersion(document) orelse 0, .generation = engine.generation, .slot_version = engine.slot_version, .singletons = singletonKey(document) },
    };
    defer res.deinit();
    // CSS Color Adjustment 1 2.1: "the page color scheme is determined by
    // finding the used color scheme, given the preferred color scheme and
    // the page's supported color schemes". The preference is the host's, as
    // prefers-color-scheme reads it; a change to it moves the media values,
    // and with them the generation every cached style is keyed on.
    res.preferred_color_scheme = if (active.media.prefers_color_scheme == .dark) .dark else .light;
    res.page_color_scheme = css.color_scheme.used(engine.page_color_schemes, res.preferred_color_scheme);

    // The flat-tree lineage, the element first.
    var lineage: std.ArrayList(LineageEntry) = .empty;
    defer lineage.deinit(engine.allocator);
    var current: *NodeBase = node;
    while (true) {
        var slotted = false;
        const parent = flatParent(current, &slotted);
        try lineage.append(engine.allocator, .{ .node = current, .slotted = slotted });
        switch (parent) {
            .root => break,
            .none => return null,
            .element => |p| current = p,
        }
    }

    // From the root down: reuse each valid cache, resolve the rest.
    var parent_style: ?*const ComputedStyle = null;
    var parent_volatile = false;
    var i = lineage.items.len;
    while (i > 0) {
        i -= 1;
        const entry = lineage.items[i];
        const e = instanceOf(entry.node) orelse return null;
        const state = element_style.of(e) orelse return null;
        const must_resolve = parent_volatile or blk: {
            const cached = state.cached orelse break :blk true;
            break :blk cached.@"volatile" or !cached.key.eql(res.key);
        };
        if (must_resolve) {
            var reads: selector_matching.StateReads = .{};
            const style = try resolveOne(&res, e, entry.node, state, null, parent_style, i == lineage.items.len - 1, &reads);
            state.setCached(.{ .style = style, .key = res.key, .@"volatile" = reads.@"volatile" or parent_volatile });
        }
        const cached = state.cached.?;
        if (i == lineage.items.len - 1) res.root_font_size = cached.style.get(.font_size).length.value;
        parent_style = cached.style;
        parent_volatile = cached.@"volatile";
    }
    const state = element_style.existingOf(element) orelse return null;
    const own = state.cached orelse return null;
    const p = pseudo orelse return own.style;
    if (!hasPseudoElement(element, p)) return null;

    // A pseudo-element's style inherits from its originating element's.
    if (state.pseudoCached(p)) |cached| {
        if (!cached.cached.@"volatile" and !own.@"volatile" and cached.cached.key.eql(res.key)) return cached.cached.style;
    }
    var reads: selector_matching.StateReads = .{};
    const style = try resolveOne(&res, element, node, state, p, own.style, false, &reads);
    try state.setPseudoCached(p, .{ .style = style, .key = res.key, .@"volatile" = reads.@"volatile" or own.@"volatile" });
    return state.pseudoCached(p).?.cached.style;
}

/// Whether `element` has the pseudo-element `name` at all. CSS Forms'
/// ::picker(select) is a drop-down box's picker: a select that is a list
/// box (`multiple`, or a display size above 1) has none, and its computed
/// declarations are empty (CSSOM 7.2 step 5's null obj). Chrome, the one
/// engine shipping ::picker, answers so
/// (customizable-select/select-picker-pseudo-box-type.html).
fn hasPseudoElement(element: *runtime.Instance, name: []const u8) bool {
    if (!std.mem.eql(u8, name, "picker")) return true;
    const data = element_data.of(element) orelse return false;
    if (!std.mem.eql(u8, data.local_name.asSlice(), "select")) return false;
    if (data.findAttribute(null, "multiple") != null) return false;
    if (data.findAttribute(null, "size")) |size| {
        const n = std.fmt.parseInt(u32, std.mem.trim(u8, size.value, " \t\n\r\x0c"), 10) catch 0;
        if (n > 1) return false;
    }
    return true;
}

const LineageEntry = struct {
    node: *NodeBase,
    slotted: bool,
};

/// The cascade for one element (or pseudo-element), its parent's style
/// computed.
fn resolveOne(res: *Resolution, element: *runtime.Instance, node: *NodeBase, state: *ElementStyle, pseudo: ?[]const u8, parent: ?*const ComputedStyle, is_root: bool, reads: *selector_matching.StateReads) Error!*ComputedStyle {
    res.matched.clearRetainingCapacity();
    try collectMatched(res, element, node, state, pseudo, reads);
    return css.cascade.cascade(.{
        .allocator = element.ctx.allocator,
        .parent = parent,
        .root_font_size = if (is_root) 16 else res.root_font_size,
        .viewport_width = res.active.media.width,
        .viewport_height = res.active.media.height,
        .is_root = is_root and pseudo == null,
        .page_color_scheme = res.page_color_scheme,
        .preferred_color_scheme = res.preferred_color_scheme,
    }, res.matched.items);
}

/// Cascade 5 section 5: every declaration block that applies to the
/// element, with where it enters the cascade.
fn collectMatched(res: *Resolution, element: *runtime.Instance, node: *NodeBase, state: *ElementStyle, pseudo: ?[]const u8, reads: *selector_matching.StateReads) Error!void {
    const data = element_data.of(element) orelse return;
    const ns = data.namespaceSlice();
    const is_html = if (ns) |n| std.mem.eql(u8, n, html_namespace) else false;

    // The keys the rule buckets file rules under.
    var lower_buffer: [64]u8 = undefined;
    const local = data.local_name.asSlice();
    const local_lower = if (local.len <= lower_buffer.len) std.ascii.lowerString(lower_buffer[0..local.len], local) else local;
    var names_storage: [32][]const u8 = undefined;
    var name_buffers: [32][48]u8 = undefined;
    var name_count: usize = 0;
    var it = data.attributeIterator();
    while (it.next()) |entry| {
        if (entry.namespace_uri != null or name_count == names_storage.len) continue;
        const n = entry.local_name;
        if (n.len > 48) continue;
        names_storage[name_count] = std.ascii.lowerString(name_buffers[name_count][0..n.len], n);
        name_count += 1;
    }
    const keys: sheet_mod.ElementKeys = .{
        .id = data.id.asSlice(),
        .class_name = data.class_name.asSlice(),
        .local_name_lower = local_lower,
        .attribute_names = names_storage[0..name_count],
    };

    var matcher = selector_matching.StyleMatcher.init(element, reads) orelse return;
    const quirks = res.active.quirks;

    // The UA origin, and HTML's presentational hints.
    if (ua_sheet.get()) |ua| {
        try matchContents(res, &matcher, element, keys, ua.rules, pseudo, is_html, quirks, .{ .origin = .user_agent }, null, null);
        if (quirks) try matchContents(res, &matcher, element, keys, ua.quirks, pseudo, is_html, quirks, .{ .origin = .user_agent, .order = 1 << 20 }, null, null);
        try matchContents(res, &matcher, element, keys, ua.hints, pseudo, is_html, quirks, .{ .origin = .presentational_hint }, null, .zero);
    }

    // The author origin (CSS Scoping 3): the sheets of the element's own
    // tree - the document's, or its shadow tree's - in that tree's context.
    var root = node;
    while (root.parent_node) |p| root = p;
    var own_depth: u16 = 0;
    if (root.node_type == NodeBase.DOCUMENT_NODE) {
        for (res.active.sheets.items) |*s| {
            try matchContents(res, &matcher, element, keys, s.contents, pseudo, is_html, quirks, .{ .origin = .author, .order = s.order_base }, s, null);
        }
    } else if (res.active.scopeOf(root)) |scope| {
        own_depth = scope.depth;
        for (scope.sheets.items) |*s| {
            try matchContents(res, &matcher, element, keys, s.contents, pseudo, is_html, quirks, .{ .origin = .author, .order = s.order_base, .tree_depth = scope.depth }, s, null);
        }
    } else if (isShadowRoot(root)) own_depth = shadowDepth(root);
    // A shadow host: its shadow tree's :host rules, the host featureless
    // there (3.1.1), in the shadow tree's - inner - context.
    if (node.is_shadow_host) if (custom_elements.shadowRootOf(element)) |shadow| if (instance_bridge.getNodeBase(shadow)) |shadow_node| {
        if (res.active.scopeOf(shadow_node)) |scope| if (selector_matching.StyleMatcher.initForHost(element, shadow, reads)) |host_matcher| {
            var m = host_matcher;
            for (scope.sheets.items) |*s| {
                try matchHostRules(res, &m, element, s.contents, pseudo, quirks, .{ .origin = .author, .order = s.order_base, .tree_depth = scope.depth }, s);
            }
        };
    };

    // ::slotted() (CSS Scoping 3.2.2): the rules of the tree of each slot
    // the element is assigned to, after flattening - a slot assigned to a
    // slot of an outer shadow tree passes its slottables on - each in that
    // slot's tree's (inner) context.
    var assigned = node;
    var hops: usize = 0;
    while (slot_helpers.slottable(assigned)) |slottable| : (hops += 1) {
        if (hops == 64) break;
        const slot = slottable.state.assignedSlot() orelse break;
        const slot_instance = instanceOf(slot) orelse break;
        var slot_root = slot;
        while (slot_root.parent_node) |p| slot_root = p;
        if (res.active.scopeOf(slot_root)) |scope| if (selector_matching.StyleMatcher.init(slot_instance, reads)) |slot_matcher| {
            var m = slot_matcher;
            for (scope.sheets.items) |*s| {
                try matchAroundRules(res, &m, .slotted, element, slot_instance, s.contents, pseudo, .{ .origin = .author, .order = s.order_base, .tree_depth = scope.depth }, s);
            }
        };
        assigned = slot;
    }
    // ::part() (CSS Shadow Parts 4.1): an element of a shadow tree with part
    // names takes the ::part() rules of its host's tree, in that (outer)
    // context. Stated: names forwarded by exportparts are not exposed further.
    if (data.findAttribute(null, "part") != null and isShadowRoot(root)) part: {
        const host = interfaces.ShadowRoot.get_host(instanceOf(root) orelse break :part) catch break :part;
        const host_node = instance_bridge.getNodeBase(host) orelse break :part;
        var host_root = host_node;
        while (host_root.parent_node) |p| host_root = p;
        var part_matcher = selector_matching.StyleMatcher.init(host, reads) orelse break :part;
        if (host_root.node_type == NodeBase.DOCUMENT_NODE) {
            for (res.active.sheets.items) |*s| {
                try matchAroundRules(res, &part_matcher, .part, element, host, s.contents, pseudo, .{ .origin = .author, .order = s.order_base }, s);
            }
        } else if (res.active.scopeOf(host_root)) |scope| {
            for (scope.sheets.items) |*s| {
                try matchAroundRules(res, &part_matcher, .part, element, host, s.contents, pseudo, .{ .origin = .author, .order = s.order_base, .tree_depth = scope.depth }, s);
            }
        }
    }

    // Element-attached declarations: the style attribute (CSS Style
    // Attributes, Cascade 5 6.1 "Element-Attached Styles").
    if (pseudo == null and ns != null) {
        const n = ns.?;
        if (std.mem.eql(u8, n, html_namespace) or std.mem.eql(u8, n, svg_namespace) or std.mem.eql(u8, n, mathml_namespace)) {
            if (try inlineBlock(element, state, quirks)) |block| {
                try res.matched.append(res.allocator, .{ .block = block, .source = .{ .origin = .author, .element_attached = true, .tree_depth = own_depth } });
            }
        }
    }
}

const SpecificityOverride = enum { zero };

/// A shadow tree's rules that can match its host: those filed with no key
/// (a featureless host has no id, class or type to file them under).
fn matchHostRules(res: *Resolution, matcher: *selector_matching.StyleMatcher, host: *runtime.Instance, contents: *const Contents, pseudo: ?[]const u8, quirks: bool, base: css.cascade.Source, active_sheet: *const ActiveSheet) Error!void {
    _ = quirks;
    const candidates = if (pseudo != null) contents.buckets.pseudo.items else contents.buckets.universal.items;
    for (candidates) |index| {
        const rule = &contents.rules.items[index];
        if (!contents.conditionHolds(rule.condition, &res.active.media)) continue;
        if (!matcher.matchesHost(host, rule.complex, pseudo)) continue;
        var source = base;
        source.order = base.order + rule.position;
        source.specificity = rule.specificity;
        if (rule.layer) |l| source.layer = active_sheet.layer_order[l] else if (active_sheet.import_layer) |l| source.layer = l;
        try res.matched.append(res.allocator, .{ .block = rule.block, .source = source });
    }
}

const AroundKind = enum { slotted, part };

/// A sheet's ::slotted() or ::part() rules that match `element` through
/// `outer` - the slot it is assigned to, the host whose part it is.
fn matchAroundRules(res: *Resolution, matcher: *selector_matching.StyleMatcher, kind: AroundKind, element: *runtime.Instance, outer: *runtime.Instance, contents: *const Contents, pseudo: ?[]const u8, base: css.cascade.Source, active_sheet: *const ActiveSheet) Error!void {
    const candidates = switch (kind) {
        .slotted => contents.buckets.slotted.items,
        .part => contents.buckets.part.items,
    };
    for (candidates) |index| {
        const rule = &contents.rules.items[index];
        if (!contents.conditionHolds(rule.condition, &res.active.media)) continue;
        const matched = switch (kind) {
            .slotted => matcher.matchesSlotted(element, outer, rule.complex, pseudo),
            .part => matcher.matchesPart(element, outer, rule.complex, pseudo),
        };
        if (!matched) continue;
        var source = base;
        source.order = base.order + rule.position;
        source.specificity = rule.specificity;
        if (rule.layer) |l| source.layer = active_sheet.layer_order[l] else if (active_sheet.import_layer) |l| source.layer = l;
        try res.matched.append(res.allocator, .{ .block = rule.block, .source = source });
    }
}

fn matchContents(res: *Resolution, matcher: *selector_matching.StyleMatcher, element: *runtime.Instance, keys: sheet_mod.ElementKeys, contents: *const Contents, pseudo: ?[]const u8, is_html: bool, quirks: bool, base: css.cascade.Source, active_sheet: ?*const ActiveSheet, specificity: ?SpecificityOverride) Error!void {
    if (contents.html_only and !is_html) return;
    res.candidates.clearRetainingCapacity();
    try contents.collectCandidates(keys, pseudo != null, quirks, &res.candidates, res.allocator);
    for (res.candidates.items) |index| {
        const rule = &contents.rules.items[index];
        if (!contents.conditionHolds(rule.condition, &res.active.media)) continue;
        if (!matcher.matches(element, rule.complex, pseudo)) continue;
        var source = base;
        source.order = base.order + rule.position;
        source.specificity = if (specificity != null) .{} else rule.specificity;
        if (active_sheet) |s| {
            if (rule.layer) |l| source.layer = s.layer_order[l] else if (s.import_layer) |l| source.layer = l;
        }
        try res.matched.append(res.allocator, .{ .block = rule.block, .source = source });
    }
}

/// The element's style attribute's declarations (parsed on first use
/// after a change), or null when it has none or CSP blocked it.
fn inlineBlock(element: *runtime.Instance, state: *ElementStyle, quirks: bool) Error!?*const css.declarations.DeclarationBlock {
    switch (state.inline_state) {
        .blocked => return null,
        .parsed => return if (state.inline_block) |*b| b else null,
        .unparsed => {},
    }
    const data = element_data.of(element) orelse return null;
    const value = if (data.findAttribute(null, "style")) |entry| entry.value else {
        state.inline_state = .parsed;
        if (state.inline_block) |*b| b.clear();
        return null;
    };
    try reparseInline(element, state, value, quirks);
    return if (state.inline_block) |*b| b else null;
}

/// Parse `value` into the element's inline declaration block.
pub fn reparseInline(element: *runtime.Instance, state: *ElementStyle, value: []const u8, quirks: bool) Error!void {
    const document = interfaces.Node.get_ownerDocument(element) catch null;
    var url_context: sheet_mod.UrlContext = .{ .instance = document orelse element, .base = "" };
    const options: css.properties.ParseOptions = .{ .allocator = state.allocator, .quirks = quirks, .url_resolver = if (document != null) url_context.resolver() else null };
    if (state.inline_block) |*b| {
        try b.setCssText(options, value);
    } else {
        state.inline_block = try css.declarations.DeclarationBlock.parse(options, value);
    }
    state.inline_state = .parsed;
}

/// HTML "being rendered", as a layout-less Crane answers it (ruling Q4):
/// the element is connected, in a document with a browsing context, in the
/// flat tree, and neither it nor any flat-tree ancestor has `display:
/// none`; an element with `display: contents` has no box of its own (it is
/// "delegating its rendering to its children").
pub fn isBeingRendered(element: *runtime.Instance) Error!bool {
    return renderedInFlatTree(element, false);
}

/// HTML 6.6.2 also accepts an element delegating rendering to its children.
/// Accepting its own display:contents does not bypass a hidden ancestor.
pub fn isBeingRenderedOrDelegating(element: *runtime.Instance) Error!bool {
    return renderedInFlatTree(element, true);
}

fn renderedInFlatTree(element: *runtime.Instance, comptime accepts_contents: bool) Error!bool {
    const node = instance_bridge.getNodeBase(element) orelse return false;
    if (node.node_type != NodeBase.ELEMENT_NODE or !node.is_connected) return false;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    const view = interfaces.Document.get_defaultView(document) catch null;
    if (view == null) return false;
    const style = (try computedStyle(element, null)) orelse return false;
    if (!accepts_contents and style.display().box == .contents) return false;
    var current: *NodeBase = node;
    while (true) {
        const e = instanceOf(current) orelse return false;
        const s = (try computedStyle(e, null)) orelse return false;
        if (s.display().box == .none) return false;
        var slotted = false;
        switch (flatParent(current, &slotted)) {
            .root => return true,
            .none => return false,
            .element => |p| current = p,
        }
    }
}

/// CSSOM 7.2 step 5's condition on `element`, but the flat tree's (which
/// computedStyle's null answers): connected, and its shadow-including root
/// has a browsing context whose container, if any, is being rendered.
pub fn hasComputedStyle(element: *runtime.Instance) Error!bool {
    const node = instance_bridge.getNodeBase(element) orelse return false;
    if (!node.is_connected) return false;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return false;
    if (navigable_container.of(window)) |container| {
        if (container != element and !try isBeingRendered(container)) return false;
    }
    // In the flat tree: computedStyle answers null otherwise, without this
    // resolving the style twice.
    return true;
}

/// DOM "assign slottables" changed `slot`'s assigned nodes: every cached
/// style of its document is resolved again (a slotted element inherits
/// from its slot).
pub fn slotAssignmentChanged(slot: *NodeBase) void {
    const instance = instanceOf(slot) orelse return;
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return;
    const engine = hooks.engineOf(document) orelse return;
    engine.slot_version +%= 1;
}

/// The engine of `document`, for the owners' registration.
pub fn engineOf(document: *runtime.Instance) ?*StyleEngine {
    return hooks.engineOf(document);
}

/// CSSOM 6.2 "document or shadow root CSS style sheets" of `scope` - a
/// Document or a ShadowRoot - appended to `out`: the CSS style sheets
/// associated with it, in tree order (style and link elements whose root is
/// `scope` and that have a sheet - disabled ones and ones whose media does
/// not match included). Borrowed: valid until the sheets next change.
/// (Crane has no style sheets from HTTP Link headers.)
pub fn scopeSheets(scope: *runtime.Instance, out: *std.ArrayList(*SheetRecord), allocator: Allocator) Error!void {
    const scope_node = instance_bridge.getNodeBase(scope) orelse return;
    const document = if (scope_node.node_type == NodeBase.DOCUMENT_NODE) scope else ((interfaces.Node.get_ownerDocument(scope) catch null) orelse return);
    const engine = hooks.engineOf(document) orelse return;
    var owners: std.ArrayList(*runtime.Instance) = .empty;
    defer owners.deinit(allocator);
    for (engine.owners.items) |o| {
        if (!o.live()) continue;
        const node = instance_bridge.getNodeBase(o.element) orelse continue;
        if (!node.is_connected) continue;
        var root = node;
        while (root.parent_node) |p| root = p;
        if (root != scope_node) continue;
        if (hooks.sheetOf(o.element) == null) continue;
        try owners.append(allocator, o.element);
    }
    sortTreeOrder(owners.items);
    for (owners.items) |owner| try out.append(allocator, hooks.sheetOf(owner).?);
}

fn sortTreeOrder(items: []*runtime.Instance) void {
    std.mem.sort(*runtime.Instance, items, {}, struct {
        fn lessThan(_: void, a: *runtime.Instance, b: *runtime.Instance) bool {
            const na = instance_bridge.getNodeBase(a) orelse return false;
            const nb = instance_bridge.getNodeBase(b) orelse return false;
            return precedes(na, nb);
        }
    }.lessThan);
}

/// CSSOM View 4.2 "evaluate media queries and report changes" for
/// `document` (HTML update the rendering, step "for each doc of docs,
/// evaluate media queries and report changes for doc"): "For each
/// MediaQueryList object target that has doc as its document, in the order
/// they were created, oldest first", the list reports its own change
/// (`hooks.reportMediaQueryList`: it fires `change` if its matches state
/// changed since the last time). A listener can make or drop lists, so the
/// lists are taken first, and each is checked to be live before it runs.
pub fn reportMediaQueryChanges(document: *runtime.Instance) void {
    const engine = hooks.engineOf(document) orelse return;
    if (engine.media_query_lists.items.len == 0) return;
    const lists = engine.allocator.dupe(Owner, engine.media_query_lists.items) catch return;
    defer engine.allocator.free(lists);
    for (lists) |entry| {
        if (!entry.live()) continue;
        hooks.reportMediaQueryList(entry.element);
    }
}

test "layer order: first declaration, nested within the parent, children before the parent's own" {
    var tree = LayerTree.init(std.testing.allocator);
    defer tree.deinit();
    const type_layer = try tree.declare(null, "reset.type");
    const reset = try tree.declare(null, "reset");
    const framework = try tree.declare(null, "framework");
    const theme = try tree.declare(framework, "theme");
    try tree.order();
    try std.testing.expectEqual(@as(u16, 0), tree.nodes.items[type_layer].rank);
    try std.testing.expectEqual(@as(u16, 1), tree.nodes.items[reset].rank);
    try std.testing.expectEqual(@as(u16, 2), tree.nodes.items[theme].rank);
    try std.testing.expectEqual(@as(u16, 3), tree.nodes.items[framework].rank);
}

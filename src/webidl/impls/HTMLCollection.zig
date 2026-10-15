//! Implementation for HTMLCollection interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-htmlcollection
//! WHATWG DOM Standard §4.2.7
//!
//! An HTMLCollection is a live collection of elements. It's used for
//! document.getElementsByTagName, document.getElementsByClassName, etc.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const HTMLCollection = interfaces.HTMLCollection;
const dom = @import("dom");
const live_collections = dom.live_collections;
const node_holds = dom.node_holds;

pub const State = HTMLCollection.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for HTMLCollection implementation
/// HTMLCollection is always a live collection that reflects DOM changes
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Materialized entries carry generations because a valid cache spans reads.
    elements: infra.List(live_collections.Link),
    cache: live_collections.IndexCache = .{},
    cacheable: bool = true,

    /// Root node for live collection updates
    root: ?*runtime.Instance = null,

    /// The root's slab generation when the collection was made live. A
    /// collection script keeps can outlive its root; a mismatch means the
    /// root is gone and the collection is empty, never a read of freed memory.
    root_generation: u64 = 0,
    /// The collection HOLDS its root (refcount design 5h; WebKit's
    /// collections keep `Ref<ContainerNode> m_ownerNode`, Blink's
    /// LiveNodeListBase a traced `Member<ContainerNode> owner_node_`): one
    /// counted reference for its life, and its wrapper keeps the root's
    /// opaque root (`live_collections.root_slot`). Script that keeps only
    /// `root.getElementsByClassName('x')` keeps the root and its tree.
    root_hold: node_holds.MemberHold = .{},
    document_filter: live_collections.DocumentFilter = .images,
    fieldset_controls: bool = false,
    selected_options_only: bool = false,
    table_filter: live_collections.TableFilter = .bodies,

    /// How a LIVE collection rebuilds its elements from `root`: set by the
    /// producer (`makeLive`) and run when its version guard misses. Null for
    /// a static list filled by `addElement`.
    refill: ?Refill = null,

    /// Filter function for matching elements (for getElementsByClassName, etc.)
    filter_tag: ?runtime.DOMString = null,
    filter_class: ?runtime.DOMString = null,
    /// getElementsByTagName(NS)'s filter (`NameFilter`); its strings are owned.
    name_filter: NameFilter = .{},

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .elements = infra.List(live_collections.Link).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.elements.deinit();
        self.name_filter.deinit(self.allocator);
        if (self.filter_tag) |*tag| {
            tag.deinit(self.allocator);
        }
        if (self.filter_class) |*class| {
            class.deinit(self.allocator);
        }
    }
};

/// Rebuild a live collection from its root: add each element, in tree order,
/// with `addElement`. The collection has been cleared before it is called.
/// False means an incomplete refill, which must not be cached.
pub const Refill = *const fn (collection: *runtime.Instance, root: *runtime.Instance) bool;

/// Make `collection` LIVE over `root`: DOM's "a collection ... is live, it
/// reflects changes to its root". `refill` runs now and on each cache miss.
///
/// Collections were snapshots, and `children` is [SameObject] - the interface
/// caches the first one - so `el.children` answered with whatever the element
/// held the first time it was read, for the element's whole life.
fn makeLive(collection: *runtime.Instance, root: *runtime.Instance, refill: Refill) void {
    const internal = getInternal(collection) orelse return;
    internal.root = root;
    internal.root_generation = runtime.SlabAllocator.generationOf(root);
    internal.root_hold.take(collection, root, live_collections.root_slot);
    internal.refill = refill;
    _ = refresh(collection, internal);
}

/// `dom.live_collections`' element-children filter: `children` (DOM
/// ParentNode) is "an HTMLCollection collection rooted at this matching only
/// element children".
fn makeElementChildren(collection: *runtime.Instance, root: *runtime.Instance) void {
    makeLive(collection, root, &refillElementChildren);
}

/// HTML 3.1.7 document tree accessors: the generated SameObject cache owns
/// the document-to-list edge; the collection holds the document (`makeLive`).
fn makeDocumentElements(collection: *runtime.Instance, document: *runtime.Instance, filter: live_collections.DocumentFilter) void {
    const internal = getInternal(collection) orelse return;
    internal.document_filter = filter;
    makeLive(collection, document, &refillDocumentElements);
}

fn refillDocumentElements(collection: *runtime.Instance, document: *runtime.Instance) bool {
    const internal = getInternal(collection) orelse return false;
    var node = interfaces.Node.get_firstChild(document) catch return false;
    while (node) |element| : (node = nextInTreeOrder(element, document)) {
        if (matchesDocumentFilter(element, internal.document_filter) catch return false)
            addElement(collection, element) catch return false;
    }
    return true;
}

fn matchesDocumentFilter(element: *runtime.Instance, filter: live_collections.DocumentFilter) !bool {
    if ((try interfaces.Node.get_nodeType(element)) != interfaces.Node.get_ELEMENT_NODE()) return false;
    var namespace = (try interfaces.Element.get_namespaceURI(element)) orelse return false;
    defer namespace.deinit(element.ctx.allocator);
    if (!std.mem.eql(u8, namespace.asSlice(), "http://www.w3.org/1999/xhtml")) return false;
    var name = try interfaces.Element.get_localName(element);
    defer name.deinit(element.ctx.allocator);
    const local = name.asSlice();
    const matched = switch (filter) {
        .images => std.mem.eql(u8, local, "img"),
        .embeds => std.mem.eql(u8, local, "embed"),
        .forms => std.mem.eql(u8, local, "form"),
        .scripts => std.mem.eql(u8, local, "script"),
        .links => std.mem.eql(u8, local, "a") or std.mem.eql(u8, local, "area"),
        .anchors => std.mem.eql(u8, local, "a"),
    };
    if (!matched) return false;
    // HTML's link and anchor filters ask for PRESENCE, including an empty
    // value, and only a null-namespace href/name attribute counts.
    const attribute: []const u8 = switch (filter) {
        .links => "href",
        .anchors => "name",
        else => return true,
    };
    var value = try interfaces.Element.call_getAttributeNS(element, null, runtime.DOMString.initInterned(attribute));
    defer if (value) |*present| present.deinit(element.ctx.allocator);
    return value != null;
}

fn makeFormControls(collection: *runtime.Instance, root: *runtime.Instance, fieldset: bool) void {
    const internal = getInternal(collection) orelse return;
    internal.fieldset_controls = fieldset;
    // Form owner association is not covered by a document tree version.
    internal.cacheable = false;
    makeLive(collection, root, &refillFormControls);
}

fn makeSelectOptions(collection: *runtime.Instance, select: *runtime.Instance, selected_only: bool) void {
    const internal = getInternal(collection) orelse return;
    internal.selected_options_only = selected_only;
    // selectedOptions also depends on IDL selectedness, not just attributes.
    internal.cacheable = !selected_only;
    makeLive(collection, select, &refillSelectOptions);
}

fn liveRoot(collection: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(collection) orelse return null;
    return @import("html").forms.liveChild(internal.root, internal.root_generation);
}

fn makeTable(collection: *runtime.Instance, root: *runtime.Instance, filter: live_collections.TableFilter) void {
    const internal = getInternal(collection) orelse return;
    internal.table_filter = filter;
    // HTML 4.9 table membership depends only on the tree. The shared
    // document version also invalidates named reads after attribute changes.
    internal.cacheable = true;
    makeLive(collection, root, &refillTable);
}

fn refillTable(collection: *runtime.Instance, root: *runtime.Instance) bool {
    const internal = getInternal(collection) orelse return false;
    if (liveRoot(collection) == null) return false;
    const Visitor = struct {
        fn append(target: *runtime.Instance, element: *runtime.Instance) anyerror!void {
            try addElement(target, element);
        }
    };
    @import("html").tables.forEach(root, internal.table_filter, collection, Visitor.append) catch return false;
    return true;
}

fn refillSelectOptions(collection: *runtime.Instance, select: *runtime.Instance) bool {
    const internal = getInternal(collection) orelse return false;
    if (liveRoot(collection) == null) return false;
    const multiple = interfaces.HTMLSelectElement.get_multiple(select) catch return false;
    // Resolve single-select selectedness once, not once per option: O(options).
    const selected_index = if (internal.selected_options_only and !multiple)
        interfaces.HTMLSelectElement.get_selectedIndex(select) catch return false
    else
        -1;
    const Visitor = struct {
        collection: *runtime.Instance,
        selected_only: bool,
        multiple: bool,
        selected_index: i32,
        index: usize = 0,
        fn append(self: *@This(), option: *runtime.Instance) anyerror!void {
            const index = self.index;
            self.index += 1;
            if (self.selected_only) {
                if (self.multiple) {
                    if (!(try interfaces.HTMLOptionElement.get_selected(option))) return;
                } else if (self.selected_index < 0 or index != @as(usize, @intCast(self.selected_index))) return;
            }
            try addElement(self.collection, option);
        }
    };
    var visitor = Visitor{ .collection = collection, .selected_only = internal.selected_options_only, .multiple = multiple, .selected_index = selected_index };
    @import("html").forms.options.forEach(select, &visitor, Visitor.append) catch return false;
    return true;
}

fn refillFormControls(collection: *runtime.Instance, owner: *runtime.Instance) bool {
    const internal = getInternal(collection) orelse return false;
    const forms = @import("html").form_associated;
    const root = if (internal.fieldset_controls) owner else forms.rootOf(owner);
    var node: ?*runtime.Instance = if (internal.fieldset_controls) forms.nextInTree(owner, owner, false) else root;
    while (node) |element| : (node = forms.nextInTree(element, root, false)) {
        if (!forms.isListed(element)) continue;
        if (!internal.fieldset_controls and forms.formOwner(element) != owner) continue;
        if (!internal.fieldset_controls and forms.isInput(element)) {
            var buffer: [16]u8 = undefined;
            if (std.mem.eql(u8, forms.inputType(element, &buffer), "image")) continue;
        }
        addElement(collection, element) catch return false;
    }
    return true;
}

/// The element children of `root`, in tree order - read through the Node
/// interface, which is the only way this impl may see another type's state.
fn refillElementChildren(collection: *runtime.Instance, root: *runtime.Instance) bool {
    const element_node = interfaces.Node.get_ELEMENT_NODE();
    var child = interfaces.Node.get_firstChild(root) catch return false;
    while (child) |c| {
        if ((interfaces.Node.get_nodeType(c) catch 0) == element_node) {
            addElement(collection, c) catch return false;
        }
        child = interfaces.Node.get_nextSibling(c) catch return false;
    }
    return true;
}

/// The filters of DOM's "list of elements with qualified name" and "list of
/// elements with namespace and local name" (getElementsByTagName and
/// getElementsByTagNameNS), fixed when the collection is made: the spec
/// reads whether root's node document is an HTML document in its steps, so
/// a list made in an HTML document keeps lowercasing for HTML elements after
/// its root moves to an XML one (dom/nodes/Element-getElementsByTagName-
/// change-document-HTMLNess.html).
const NameFilter = struct {
    mode: Mode = .none,
    /// The qualified name or the local name, as given; owned.
    name: ?[]u8 = null,
    /// The qualified name in ASCII lowercase, for `.html_qualified`; owned.
    lower: ?[]u8 = null,
    /// The namespace, for `.namespace` and `.both` (null: no namespace); owned.
    namespace: ?[]u8 = null,

    const Mode = enum {
        none,
        /// Every descendant element ("*", or "*" and "*").
        any,
        /// Qualified name `name` (not an HTML document).
        qualified,
        /// An HTML element whose qualified name is `lower`, or any other
        /// whose qualified name is `name` (an HTML document).
        html_qualified,
        /// Local name `name`, any namespace (namespace "*").
        local,
        /// Namespace `namespace`, any local name (local name "*").
        namespace,
        /// Namespace `namespace` and local name `name`.
        both,
    };

    fn deinit(self: *NameFilter, allocator: std.mem.Allocator) void {
        if (self.name) |name| allocator.free(name);
        if (self.lower) |lower| allocator.free(lower);
        if (self.namespace) |namespace| allocator.free(namespace);
        self.* = .{};
    }

    fn matches(self: *const NameFilter, names: dom.node_creation.ElementNames) bool {
        return switch (self.mode) {
            .none => false,
            .any => true,
            .qualified => qualifiedNameIs(names, self.name.?),
            .html_qualified => if (sameOptional(names.namespace, html_namespace))
                qualifiedNameIs(names, self.lower.?)
            else
                qualifiedNameIs(names, self.name.?),
            .local => std.mem.eql(u8, names.local_name, self.name.?),
            .namespace => sameOptional(names.namespace, self.namespace),
            .both => sameOptional(names.namespace, self.namespace) and std.mem.eql(u8, names.local_name, self.name.?),
        };
    }
};

const html_namespace: []const u8 = "http://www.w3.org/1999/xhtml";

/// Whether the element's qualified name - "prefix:local" with a prefix,
/// else its local name - is `wanted`, compared without building it.
fn qualifiedNameIs(names: dom.node_creation.ElementNames, wanted: []const u8) bool {
    const prefix = names.prefix orelse return std.mem.eql(u8, names.local_name, wanted);
    return wanted.len == prefix.len + 1 + names.local_name.len and
        std.mem.startsWith(u8, wanted, prefix) and wanted[prefix.len] == ':' and
        std.mem.endsWith(u8, wanted, names.local_name);
}

fn sameOptional(a: ?[]const u8, b: ?[]const u8) bool {
    if (a) |left| return if (b) |right| std.mem.eql(u8, left, right) else false;
    return b == null;
}

/// `dom.live_collections`' qualified-name filter: DOM's "list of elements
/// with qualified name `qualifiedName`" for `root`.
///
/// Spec: https://dom.spec.whatwg.org/#concept-getelementsbytagname
fn makeQualifiedName(collection: *runtime.Instance, root: *runtime.Instance, qualified_name: []const u8) error{OutOfMemory}!void {
    const internal = getInternal(collection) orelse return;
    internal.name_filter.deinit(internal.allocator);
    // 1. "If qualifiedName is U+002A (*), then return an HTMLCollection
    //    rooted at root, whose filter matches only descendant elements."
    if (std.mem.eql(u8, qualified_name, "*")) {
        internal.name_filter.mode = .any;
    } else {
        const name = try internal.allocator.dupe(u8, qualified_name);
        internal.name_filter.name = name;
        // 2. "Otherwise, if root's node document is an HTML document":
        //    an HTML element's qualified name is compared with qualifiedName
        //    in ASCII lowercase, any other's with qualifiedName as given.
        if (inHtmlDocument(root)) {
            const lower = try internal.allocator.alloc(u8, qualified_name.len);
            internal.name_filter.lower = std.ascii.lowerString(lower, qualified_name);
            internal.name_filter.mode = .html_qualified;
        } else {
            // 3. "Otherwise ... whose qualified name is qualifiedName."
            internal.name_filter.mode = .qualified;
        }
    }
    makeLive(collection, root, &refillNames);
}

/// `dom.live_collections`' namespace-and-local-name filter: DOM's "list of
/// elements with namespace `namespace` and local name `localName`".
///
/// Spec: https://dom.spec.whatwg.org/#concept-getelementsbytagnamens
fn makeNamespaceLocalName(collection: *runtime.Instance, root: *runtime.Instance, namespace_in: ?[]const u8, local_name: []const u8) error{OutOfMemory}!void {
    const internal = getInternal(collection) orelse return;
    internal.name_filter.deinit(internal.allocator);
    // 1. "If namespace is the empty string, then set it to null."
    const namespace: ?[]const u8 = if (namespace_in) |ns| (if (ns.len == 0) null else ns) else null;
    const any_namespace = if (namespace) |ns| std.mem.eql(u8, ns, "*") else false;
    const any_local = std.mem.eql(u8, local_name, "*");
    if (any_namespace and any_local) {
        // 2. Both "*": every descendant element.
        internal.name_filter.mode = .any;
    } else if (any_namespace) {
        // 3. Namespace "*": local name localName.
        internal.name_filter.name = try internal.allocator.dupe(u8, local_name);
        internal.name_filter.mode = .local;
    } else {
        if (namespace) |ns| internal.name_filter.namespace = try internal.allocator.dupe(u8, ns);
        if (any_local) {
            // 4. Local name "*": namespace namespace.
            internal.name_filter.mode = .namespace;
        } else {
            // 5. Namespace namespace and local name localName.
            internal.name_filter.name = try internal.allocator.dupe(u8, local_name);
            internal.name_filter.mode = .both;
        }
    }
    makeLive(collection, root, &refillNames);
}

/// Whether `root`'s node document is an HTML document.
fn inHtmlDocument(root: *runtime.Instance) bool {
    const document = live_collections.nodeDocument(root) orelse return false;
    return dom.document_internals.getDocumentType(document) == .html;
}

/// `root`'s descendant elements, in tree order, that the name filter
/// matches. The walk follows the tree's own links, and reads each element's
/// names borrowed (dom.node_creation.elementNames), so a refill copies
/// nothing per element.
fn refillNames(collection: *runtime.Instance, root: *runtime.Instance) bool {
    const internal = getInternal(collection) orelse return false;
    const root_base = dom.instance_bridge.getNodeBase(@ptrCast(root)) orelse return false;
    var current = root_base.first_child;
    while (current) |node| : (current = nextBaseInTreeOrder(node, root_base)) {
        if (node.node_type != dom.NodeBase.ELEMENT_NODE) continue;
        const element: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse continue));
        const names = dom.node_creation.elementNames(element) orelse continue;
        if (!internal.name_filter.matches(names)) continue;
        addElement(collection, element) catch return false;
    }
    return true;
}

/// The tree node after `node` in tree order within `root`'s descendants.
fn nextBaseInTreeOrder(node: *dom.NodeBase, root: *dom.NodeBase) ?*dom.NodeBase {
    if (node.first_child) |child| return child;
    var current = node;
    while (current != root) {
        if (current.next_sibling) |sibling| return sibling;
        current = current.parent_node orelse return null;
    }
    return null;
}

/// `dom.live_collections`' class-names filter: DOM's "list of elements with
/// class names `classNames`" for `root`, for a non-empty set of classes.
///
/// Spec: https://dom.spec.whatwg.org/#concept-getelementsbyclassname
/// "3. Return an HTMLCollection rooted at root, whose filter matches
///  descendant elements that have all their classes in classes."
///
/// The class names are kept as given and parsed on each refill: the ordered
/// set parser's tokens are the ASCII-whitespace-separated pieces, and a
/// duplicate changes nothing about "all their classes".
fn makeClassNames(collection: *runtime.Instance, root: *runtime.Instance, class_names: []const u8) error{OutOfMemory}!void {
    const internal = getInternal(collection) orelse return;
    if (internal.filter_class) |*old| old.deinit(internal.allocator);
    internal.filter_class = try runtime.DOMString.initDupe(internal.allocator, class_names);
    makeLive(collection, root, &refillClassNames);
}

/// `root`'s descendant elements, in tree order, that have every class the
/// collection's class names name. "The comparisons for the classes must be
/// done in an ASCII case-insensitive manner if root's node document's mode is
/// "quirks"; otherwise in an identical to manner" - read at each refill, as
/// the comparison is made.
fn refillClassNames(collection: *runtime.Instance, root: *runtime.Instance) bool {
    const internal = getInternal(collection) orelse return false;
    const class_names = if (internal.filter_class) |c| c.asSlice() else return false;
    const quirks = isQuirksMode(root);
    const element_node = interfaces.Node.get_ELEMENT_NODE();

    // Tree order over root's descendants (root itself is not one).
    var node = interfaces.Node.get_firstChild(root) catch return false;
    while (node) |n| {
        if ((interfaces.Node.get_nodeType(n) catch 0) == element_node and (hasAllClasses(n, class_names, quirks) catch return false)) {
            addElement(collection, n) catch return false;
        }
        node = nextInTreeOrder(n, root);
    }
    return true;
}

/// The node after `node` in tree order within `root`'s descendants, or null.
fn nextInTreeOrder(node: *runtime.Instance, root: *runtime.Instance) ?*runtime.Instance {
    if (interfaces.Node.get_firstChild(node) catch null) |child| return child;
    var current = node;
    while (current != root) {
        if (interfaces.Node.get_nextSibling(current) catch null) |sibling| return sibling;
        current = (interfaces.Node.get_parentNode(current) catch null) orelse return null;
    }
    return null;
}

/// Whether `element`'s classes - its class attribute's value run through the
/// ordered set parser - include every token of `class_names`.
fn hasAllClasses(element: *runtime.Instance, class_names: []const u8, quirks: bool) !bool {
    // A borrowed view of the attribute's value.
    const value = (try interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("class"))) orelse return false;
    const classes = value.asSlice();
    var wanted = std.mem.tokenizeAny(u8, class_names, ascii_whitespace);
    while (wanted.next()) |name| {
        if (!hasClass(classes, name, quirks)) return false;
    }
    return true;
}

fn hasClass(classes: []const u8, name: []const u8, quirks: bool) bool {
    var it = std.mem.tokenizeAny(u8, classes, ascii_whitespace);
    while (it.next()) |class| {
        const same = if (quirks) std.ascii.eqlIgnoreCase(class, name) else std.mem.eql(u8, class, name);
        if (same) return true;
    }
    return false;
}

/// Infra's ASCII whitespace: TAB, LF, FF, CR, SPACE (not VT).
const ascii_whitespace = "\t\n\x0C\r ";

/// Whether `root`'s node document is in quirks mode: its compatMode is
/// "BackCompat" exactly when its mode is "quirks".
fn isQuirksMode(root: *runtime.Instance) bool {
    const document = if ((interfaces.Node.get_nodeType(root) catch 0) == interfaces.Node.get_DOCUMENT_NODE())
        root
    else
        (interfaces.Node.get_ownerDocument(root) catch null) orelse return false;
    var mode = interfaces.Document.get_compatMode(document) catch return false;
    defer mode.deinit(root.ctx.allocator);
    return std.mem.eql(u8, mode.asSlice(), "BackCompat");
}

/// Bring a live collection up to date with its root. True when its
/// elements are known to match an unmoved tree version
/// (live_collections.IndexCache.fresh), false when they must each be
/// checked in full. Either way an element is read through
/// live_collections.Link.get.
fn refresh(instance: *runtime.Instance, internal: *InternalState) bool {
    const refill = internal.refill orelse return false;
    const root = internal.root orelse return false;
    // Nothing changed since the last full check: one registry read.
    const root_base = internal.root_hold.liveBase();
    if (internal.cacheable) if (root_base) |base| if (internal.cache.fresh(base)) return true;
    const link = live_collections.Link{ .instance = root, .generation = internal.root_generation };
    if (link.get() == null) {
        internal.cache = .{};
        clear(instance);
        return false;
    }
    if (internal.cacheable) {
        const document = live_collections.nodeDocument(root);
        const version = if (document) |doc| live_collections.treeVersion(doc) else null;
        const valid = internal.cache.begin(link, document, version);
        if (root_base) |base| internal.cache.keyDocument(base);
        if (valid) return true;
    }
    clear(instance);
    // A failed refill must never become a cached partial result.
    if (!refill(instance, root)) {
        internal.cache = .{};
        internal.cache.length = @intCast(internal.elements.size());
        return false;
    }
    internal.cache.length = @intCast(internal.elements.size());
    // Just refilled under a tree version: every element is alive.
    return internal.cache.version != null;
}

/// Named reads already inspect the whole buffer. Validate it before exposing
/// any element; item() checks just its own entry to keep indexed loops linear.
fn refreshNamed(instance: *runtime.Instance, internal: *InternalState) void {
    if (refresh(instance, internal)) return;
    for (internal.elements.toSlice()) |link| {
        if (link.get() == null) {
            internal.cache = .{};
            _ = refresh(instance, internal);
            return;
        }
    }
}

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Other impls make a collection live through dom.live_collections.
    live_collections.install(.{ .element_children = &makeElementChildren, .class_names = &makeClassNames, .qualified_name = &makeQualifiedName, .namespace_local_name = &makeNamespaceLocalName, .document_elements = &makeDocumentElements, .form_controls = &makeFormControls, .select_options = &makeSelectOptions, .table = &makeTable, .root = &liveRoot });
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const state = instance.getState(State);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    // Initialize length to 0
    state.own.length = 0;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.root_hold.release(instance, live_collections.root_slot);
        internal.deinit();

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for length
/// Spec: https://dom.spec.whatwg.org/#dom-htmlcollection-length
/// Returns the number of elements in the collection.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    _ = refresh(instance, internal);
    return @intCast(internal.elements.size());
}

/// Operation: item(index)
/// Spec: https://dom.spec.whatwg.org/#dom-htmlcollection-item
/// Returns the element at the given index, or null if out of bounds.
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    _ = refresh(instance, internal);
    // Return null for out of bounds per spec
    const link = internal.elements.get(index) orelse return null;
    if (link.get()) |element| {
        internal.cache.remember(index, element);
        return element;
    }
    internal.cache = .{};
    _ = refresh(instance, internal);
    const replacement = internal.elements.get(index) orelse return null;
    const element = replacement.get() orelse return null;
    internal.cache.remember(index, element);
    return element;
}

/// Operation: namedItem(name)
/// Spec: https://dom.spec.whatwg.org/#dom-htmlcollection-nameditem
/// Returns the first element with the given id or name attribute.
///
/// The namedItem(name) method steps are to return the first element in the
/// collection for which at least one of the following is true:
/// - it has an ID which is name;
/// - it is in the HTML namespace and has a name attribute whose value is name;
/// or null if there is no such element.
pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    refreshNamed(instance, internal);
    const name_slice = name.asSlice();

    // Empty name returns null
    if (name_slice.len == 0) return null;

    // Iterate through elements looking for matching id or name attribute
    const elements = internal.elements.toSlice();
    const Element = interfaces.Element;

    for (elements) |link| {
        const element = link.get() orelse continue;
        // Check id attribute first
        var id = try Element.get_id(element);
        defer id.deinit(internal.allocator);
        if (std.mem.eql(u8, id.asSlice(), name_slice)) {
            return element;
        }

        // Check name attribute for HTML namespace elements
        // Per spec: "it is in the HTML namespace and has a name attribute whose value is name"
        var name_attr = Element.call_getAttribute(element, runtime.DOMString.initInterned("name")) catch null;
        if (name_attr) |*attr| {
            defer attr.deinit(internal.allocator);
            if (std.mem.eql(u8, attr.asSlice(), name_slice)) {
                return element;
            }
        }
    }

    return null;
}

// ============================================================================
// Internal helper functions (for DOM implementation)
// ============================================================================

/// Add an element to the collection
pub fn addElement(instance: *runtime.Instance, element: *runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    try internal.elements.append(live_collections.Link.to(element));

    // Update length in state
    const state = instance.getState(State);
    state.own.length = @intCast(internal.elements.size());
}

/// Clear all elements from the collection
pub fn clear(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.elements.clear();

    // Update length in state
    const state = instance.getState(State);
    state.own.length = 0;
}

/// Get supported property names for named property enumeration
/// Per WebIDL spec §3.9.3, returns the id and name attributes of elements
///
/// The supported property names are the values of:
/// - id attribute of each element in tree order
/// - name attribute of each HTML namespace element in tree order
/// with earlier values taking precedence (no duplicates)
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    const internal = getInternal(instance) orelse return &[_]runtime.DOMString{};
    refreshNamed(instance, internal);

    const elements = internal.elements.toSlice();
    if (elements.len == 0) return &[_]runtime.DOMString{};

    const Element = interfaces.Element;

    // Use ArrayList to collect unique names
    var names: std.ArrayListUnmanaged(runtime.DOMString) = .empty;
    errdefer {
        for (names.items) |*n| n.deinit(allocator);
        names.deinit(allocator);
    }

    // Collect id and name attributes from elements in tree order
    for (elements) |link| {
        const element = link.get() orelse continue;
        // Check id attribute
        var id = Element.get_id(element) catch continue;
        const id_slice = id.asSlice();
        if (id_slice.len > 0) {
            // Check if already in list
            var found = false;
            for (names.items) |existing| {
                if (std.mem.eql(u8, existing.asSlice(), id_slice)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                // Clone the id for our list
                const cloned = try runtime.DOMString.initDupe(allocator, id_slice);
                try names.append(allocator, cloned);
            }
        }
        id.deinit(internal.allocator);

        // Check name attribute for HTML namespace elements
        var name_attr = Element.call_getAttribute(element, runtime.DOMString.initInterned("name")) catch null;
        if (name_attr) |*attr| {
            defer attr.deinit(internal.allocator);
            const attr_slice = attr.asSlice();
            if (attr_slice.len > 0) {
                // Check if already in list
                var found = false;
                for (names.items) |existing| {
                    if (std.mem.eql(u8, existing.asSlice(), attr_slice)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    const cloned = try runtime.DOMString.initDupe(allocator, attr_slice);
                    try names.append(allocator, cloned);
                }
            }
        }
    }

    return names.toOwnedSlice(allocator);
}

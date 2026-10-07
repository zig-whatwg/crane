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
const live_collections = @import("dom").live_collections;

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

    /// The list of elements
    elements: infra.List(*runtime.Instance),

    /// Root node for live collection updates
    root: ?*runtime.Instance = null,

    /// The root's slab generation when the collection was made live. A
    /// collection script keeps can outlive its root; a mismatch means the
    /// root is gone and the collection is empty, never a read of freed memory.
    root_generation: u64 = 0,
    form_root_traced: bool = false,
    fieldset_controls: bool = false,

    /// How a LIVE collection rebuilds its elements from `root`: set by the
    /// producer (`makeLive`) and run before every read. Null for a static
    /// list filled by `addElement`.
    refill: ?Refill = null,

    /// Filter function for matching elements (for getElementsByClassName, etc.)
    filter_tag: ?runtime.DOMString = null,
    filter_class: ?runtime.DOMString = null,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .elements = infra.List(*runtime.Instance).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.elements.deinit();
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
pub const Refill = *const fn (collection: *runtime.Instance, root: *runtime.Instance) void;

/// Make `collection` LIVE over `root`: DOM's "a collection ... is live, it
/// reflects changes to its root". `refill` runs now and before every read.
///
/// Collections were snapshots, and `children` is [SameObject] - the interface
/// caches the first one - so `el.children` answered with whatever the element
/// held the first time it was read, for the element's whole life.
fn makeLive(collection: *runtime.Instance, root: *runtime.Instance, refill: Refill) void {
    const internal = getInternal(collection) orelse return;
    internal.root = root;
    internal.root_generation = runtime.SlabAllocator.generationOf(root);
    internal.refill = refill;
    refresh(collection, internal);
}

/// `dom.live_collections`' element-children filter: `children` (DOM
/// ParentNode) is "an HTMLCollection collection rooted at this matching only
/// element children".
fn makeElementChildren(collection: *runtime.Instance, root: *runtime.Instance) void {
    makeLive(collection, root, &refillElementChildren);
}

fn makeFormControls(collection: *runtime.Instance, root: *runtime.Instance, fieldset: bool) void {
    const internal = getInternal(collection) orelse return;
    internal.fieldset_controls = fieldset;
    if (collection.ctx.hasEngine()) {
        @import("engine").traceChild(collection, root, .{ .name = "formControlsRoot" });
        internal.form_root_traced = true;
    }
    makeLive(collection, root, &refillFormControls);
}

fn refillFormControls(collection: *runtime.Instance, owner: *runtime.Instance) void {
    const internal = getInternal(collection) orelse return;
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
        addElement(collection, element) catch return;
    }
}

/// The element children of `root`, in tree order - read through the Node
/// interface, which is the only way this impl may see another type's state.
fn refillElementChildren(collection: *runtime.Instance, root: *runtime.Instance) void {
    const element_node = interfaces.Node.get_ELEMENT_NODE();
    var child = interfaces.Node.get_firstChild(root) catch return;
    while (child) |c| {
        if ((interfaces.Node.get_nodeType(c) catch 0) == element_node) {
            addElement(collection, c) catch return;
        }
        child = interfaces.Node.get_nextSibling(c) catch return;
    }
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
fn refillClassNames(collection: *runtime.Instance, root: *runtime.Instance) void {
    const internal = getInternal(collection) orelse return;
    const class_names = if (internal.filter_class) |c| c.asSlice() else return;
    const quirks = isQuirksMode(root);
    const element_node = interfaces.Node.get_ELEMENT_NODE();

    // Tree order over root's descendants (root itself is not one).
    var node = interfaces.Node.get_firstChild(root) catch return;
    while (node) |n| {
        if ((interfaces.Node.get_nodeType(n) catch 0) == element_node and hasAllClasses(n, class_names, quirks)) {
            addElement(collection, n) catch return;
        }
        node = nextInTreeOrder(n, root);
    }
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
fn hasAllClasses(element: *runtime.Instance, class_names: []const u8, quirks: bool) bool {
    // A borrowed view of the attribute's value.
    const value = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("class")) catch return false) orelse return false;
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

/// Bring a live collection up to date with its root.
fn refresh(instance: *runtime.Instance, internal: *InternalState) void {
    const refill = internal.refill orelse return;
    const root = internal.root orelse return;
    clear(instance);
    if (runtime.SlabAllocator.generationOf(root) != internal.root_generation) return;
    refill(instance, root);
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
    live_collections.install(.{ .element_children = &makeElementChildren, .class_names = &makeClassNames, .form_controls = &makeFormControls });
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
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
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
        if (internal.form_root_traced) @import("engine").forgetTracedChild(instance, .{ .name = "formControlsRoot" });
        internal.deinit();

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for length
/// Spec: https://dom.spec.whatwg.org/#dom-htmlcollection-length
/// Returns the number of elements in the collection.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    refresh(instance, internal);
    return @intCast(internal.elements.size());
}

/// Operation: item(index)
/// Spec: https://dom.spec.whatwg.org/#dom-htmlcollection-item
/// Returns the element at the given index, or null if out of bounds.
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    refresh(instance, internal);
    // Return null for out of bounds per spec
    return internal.elements.get(index);
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
    refresh(instance, internal);
    const name_slice = name.asSlice();

    // Empty name returns null
    if (name_slice.len == 0) return null;

    // Iterate through elements looking for matching id or name attribute
    const elements = internal.elements.toSlice();
    const Element = interfaces.Element;

    for (elements) |element| {
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
    try internal.elements.append(element);

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

/// Set the root for live collection updates
pub fn setRoot(instance: *runtime.Instance, root: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.root = root;
}

/// Get the elements as a slice (for iteration)
pub fn getElements(instance: *runtime.Instance) []const *runtime.Instance {
    const internal = getInternal(instance) orelse return &[_]*runtime.Instance{};
    refresh(instance, internal);
    return internal.elements.toSlice();
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
    refresh(instance, internal);

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
    for (elements) |element| {
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

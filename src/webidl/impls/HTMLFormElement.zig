//! Implementation for HTMLFormElement interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const fetch_body = @import("fetch_body.zig");
const same_object = @import("same_object.zig");
const HTMLFormElement = interfaces.HTMLFormElement;

// Form submission (below call_submit).
const encoding_mod = @import("encoding");
const basic_parser = @import("basic_parser");
const url_serializer = @import("url_serializer");
const encode_sets = @import("encode_sets");
const log = std.log.scoped(.forms);

const dom = @import("dom");
const TaskHold = dom.node_holds.TaskHold;
const form_associated = @import("html").form_associated;
const forms = @import("html").forms;
const attributeValue = form_associated.attributeValue;
const hasAttribute = form_associated.hasAttribute;
const isElementNamed = form_associated.isElementNamed;
const parentOf = form_associated.parentOf;
const nextInTree = form_associated.nextInTree;

pub const State = HTMLFormElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = runtime.InstanceRegistry(.html_form_element, InternalState);

/// Internal state for HTMLFormElement implementation
pub const InternalState = struct {
    /// What the tree names now: each name's candidates (`NamedElements`).
    named: NamedElements = .{},
    /// HTML's past names map (`PastNames`).
    past_names: PastNames = .{},
    elements: ?*runtime.Instance = null,
    elements_generation: u64 = 0,
    elements_traced: bool = false,
    /// HTML § 4.10.22.3 "planned navigation": the token of the form's last
    /// planned navigation while its task is still queued, or 0 for null.
    planned_navigation: u64 = 0,
    /// Every planned navigation of the form whose task is still queued (see
    /// planNavigationWith: a submit() call does not cancel the ones before
    /// it, as it does in the spec text). Allocated with
    /// `pending_allocator`.
    pending_navigations: std.ArrayListUnmanaged(PendingNavigation) = .empty,
    pending_allocator: ?std.mem.Allocator = null,
    /// § 4.10.22.3 "constructing entry list", initially false.
    constructing_entry_list: bool = false,
    /// § 4.10.22.3 "firing submission events", initially false.
    firing_submission_events: bool = false,
    /// § 4.10.22 "locked for reset", initially false.
    locked_for_reset: bool = false,

    pub fn deinit(self: *InternalState) void {
        self.named.deinit();
        self.past_names.deinit();
        if (self.pending_allocator) |allocator| self.pending_navigations.deinit(allocator);
        self.pending_navigations = .empty;
    }
};

const Link = dom.live_collections.Link;

/// HTML "the form element": every name the form's tree gives it now - the
/// candidates of "determining the value of a named property" steps 1-2, by
/// name, which are also the names of the supported property names' steps 2,
/// 3 and 6 - read in one walk and kept while the node document's tree
/// version stands. Every mutation and adoption moves the version, and so do
/// the two changes of form association that are not mutations
/// (dom.refcount.formAssociationChanged), so a form owner read under the
/// version is still the owner. A property read on a form asks "is P a
/// supported property name?" for one P first ([LegacyOverrideBuiltIns]:
/// `form.submit` too): one hash lookup here, no walk (codex-lpo review M1).
/// WebKit's HTMLFormElement keeps its listed elements and its collection's
/// named-element cache, Blink its listed_elements_, rebuilt when dirtied;
/// Crane computes form owners, so the version is the dirty bit.
const NamedElements = struct {
    /// The names and the map, rebuilt whole; null until the first read.
    arena: ?std.heap.ArenaAllocator = null,
    map: std.StringHashMapUnmanaged(Candidates) = .empty,
    /// The node document and version the map was read under (the same keys
    /// and freshness check as a live collection's).
    key: dom.live_collections.IndexCache = .{},

    fn deinit(self: *NamedElements) void {
        if (self.arena) |*arena| arena.deinit();
        self.* = .{};
    }
};

/// A name's candidates in tree order: the first listed element (step 1)
/// and whether there are more, the first img (step 2) and whether there are
/// more. Weak links, as a live collection's cache holds its elements
/// (live_collections.IndexCache.fresh): while the version stands no
/// candidate has left the form's tree - a removal moves it before a node can
/// be freed - and the tree lives while the form does (the tree is the unit
/// of lifetime, refcount design D1). Each is still read through Link.get,
/// the teardown net.
const Candidates = struct {
    control: ?Link = null,
    more_controls: bool = false,
    image: ?Link = null,
    more_images: bool = false,
};

/// HTML "the form element": the past names map - "a mapping of names to
/// elements ... used to persist names of controls even when they change
/// names" - with each entry's age, its order of addition (supported
/// property names step 5). An entry's element has this form as its owner:
/// "if an element listed in a form element's past names map changes form
/// owner, then its entries must be removed from that map", which
/// `ownerChanged` does at the change, told by dom.form_past_names (the
/// agent's forms with entries). So the element is in the form's tree for as
/// long as its entry stands, and is held as the tree holds it: a weak link,
/// never a counted reference from node state to another node (refcount
/// design D1: "node relations outside the tree ... are WeakRef or raw
/// pointers"; WebKit's m_pastNamesMap holds WeakPtrs). Link.get is the
/// teardown net. The entries are freed with the form, and at its realm's
/// end with it.
const PastNames = struct {
    allocator: ?std.mem.Allocator = null,
    entries: std.ArrayListUnmanaged(PastEntry) = .empty,
    /// The next entry's age.
    next_age: u64 = 0,
    /// Whether the agent's registry lists this form (it drops a form left
    /// with no entries, and the form adds itself again with its next one).
    registered: bool = false,

    fn deinit(self: *PastNames) void {
        if (self.allocator) |allocator| {
            for (self.entries.items) |entry| allocator.free(entry.name);
            self.entries.deinit(allocator);
        }
        self.* = .{};
    }

    /// The element `name` maps to, if its entry stands.
    fn get(self: *const PastNames, name: []const u8) ?*runtime.Instance {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.name, name)) return entry.element.getWeak();
        }
        return null;
    }

    fn remove(self: *PastNames, index: usize) void {
        const entry = self.entries.orderedRemove(index);
        if (self.allocator) |allocator| allocator.free(entry.name);
    }
};

const PastEntry = struct {
    /// Owned by PastNames.allocator.
    name: []u8,
    element: Link,
    /// The element's tree node, read through `element` first.
    base: *dom.NodeBase,
    age: u64,
    /// Whether the element has a form attribute (kept current by
    /// `ownerChanged`): then an ID entering, leaving or changing in its tree
    /// can give it another owner, wherever the change is.
    form_attribute: bool,
};

/// A planned navigation of a form whose task has not run yet.
const PendingNavigation = struct {
    token: u64,
    /// The id of the navigable (html_core BrowsingContext) the target named
    /// at submission, or 0 when it named a new one or none was found.
    navigable: u64,
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The form's algorithms other element types run (a submit button's
    // activation, FormData's constructor): installed before anyone can hold
    // a form.
    @import("dom").form_submission.install(submission_algorithms);
    // A form removed from its tree while script held no wrapper of it is an
    // orphan nothing deinits: the states no deinit reached free their named
    // elements, past names and pending navigations at their Browser's end
    // (dom.orphan_states, lane orphanleak). Its entry in the agent's list of
    // forms with past names (dom.form_past_names) is a weak link the list
    // drops at its next change - the form then answers that it has none -
    // and the list itself ends with the Browser's agent host, right after.
    @import("dom").orphan_states.installRegistrySweep(Registry);
}

/// HTMLFormElement's own construction steps: the generated chain runs HTMLElement's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    _ = args;
    // Initialize HTMLFormElement's own internal state in registry
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = .{};
}

/// HTMLFormElement's own teardown: the generated chain runs HTMLElement's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        if (internal.elements_traced) engine.forgetTracedChild(instance, .{ .name = "elements" });
        if (!internal.elements_traced) if (liveChild(internal.elements, internal.elements_generation)) |collection| runtime.Instance.deinit(collection);
        internal.deinit();
    }
    Registry.remove(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLFormElement.init(ctx.allocator, ctx);
    errdefer HTMLFormElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

// ---------------------------------------------------------------------------
// Reflected content attributes
//
// https://html.spec.whatwg.org/multipage/forms.html#the-form-element
//
// These were all `return error.NotImplemented`, which V8 turns into a thrown
// exception - so `form.method` THREW rather than returning its default. Every
// form test died on the first property read.
//
// Plain [Reflect] attributes (acceptCharset, name, noValidate, target, rel)
// and the [ReflectSetter] action setter are the generated interface's own
// (src/webidl/dom/reflection.zig). What is left here is not plain:
//   * action     - a URL getter with the document URL as its fallback
//   * enumerated - "limited to only known values": an unrecognised value maps
//                  to the INVALID VALUE DEFAULT, and a missing attribute to the
//                  MISSING VALUE DEFAULT, which are not always the same thing
// ---------------------------------------------------------------------------

/// Enumerated reflection. `known` is matched ASCII-case-insensitively; anything
/// unmatched yields `invalid_default`, and an absent attribute `missing_default`.
fn reflectEnumerated(
    instance: *runtime.Instance,
    comptime attr: []const u8,
    comptime known: []const []const u8,
    comptime missing_default: []const u8,
    comptime invalid_default: []const u8,
) anyerror!runtime.DOMString {
    const elem_internal = dom.element_data.of(instance) orelse return error.InvalidState;
    const entry = elem_internal.findAttribute(null, attr) orelse
        return runtime.DOMString.initInterned(missing_default);

    inline for (known) |candidate| {
        if (std.ascii.eqlIgnoreCase(entry.value, candidate)) {
            return runtime.DOMString.initInterned(candidate);
        }
    }
    return runtime.DOMString.initInterned(invalid_default);
}

/// Getter for action
pub fn get_action(instance: *runtime.Instance) anyerror!runtime.USVString {
    // Not plain reflection. Per spec the action IDL attribute reflects the
    // content attribute, EXCEPT that on getting, a missing attribute OR an
    // empty one returns the node document's URL instead. The empty-string case
    // is the one that surprises: action="" is not "", it is the document URL.
    const elem_internal = dom.element_data.of(instance) orelse return error.InvalidState;

    if (elem_internal.findAttribute(null, "action")) |entry| {
        if (entry.value.len != 0) {
            // action getter steps 3-5: encoding-parse/serialize, or return
            // the original content converted to a scalar value string.
            return dom.reflection.get(runtime.USVString, instance, .{ .name = "action", .url = true });
        }
    }

    // Step 2: missing/empty means the document URL, not its base URL.
    if (try interfaces.Node.get_ownerDocument(instance)) |doc| {
        return interfaces.Document.get_URL(doc) catch
            try instance.ctx.allocator.dupe(u8, "");
    }
    return try instance.ctx.allocator.dupe(u8, "");
}

/// Getter for autocomplete
pub fn get_autocomplete(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Missing and invalid both default to "on".
    return reflectEnumerated(instance, "autocomplete", &.{ "on", "off" }, "on", "on");
}

/// Getter for enctype
pub fn get_enctype(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return reflectEnumerated(
        instance,
        "enctype",
        &.{ "application/x-www-form-urlencoded", "multipart/form-data", "text/plain" },
        "application/x-www-form-urlencoded",
        "application/x-www-form-urlencoded",
    );
}

/// Getter for encoding
pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // `encoding` is a historical alias for `enctype` and reflects the SAME
    // content attribute.
    return get_enctype(instance);
}

/// Getter for method
pub fn get_method(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // Missing and invalid both default to "get".
    return reflectEnumerated(instance, "method", &.{ "get", "post", "dialog" }, "get", "get");
}

/// Getter for elements
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-elements
pub fn get_elements(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = Registry.get(instance) orelse return error.InvalidState;
    if (liveChild(internal.elements, internal.elements_generation)) |collection| return collection;
    const collection = try interfaces.HTMLFormControlsCollection.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(collection);
    try @import("dom").live_collections.formControls(collection, instance, false);
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, collection, .{ .name = "elements" });
        internal.elements_traced = true;
    }
    internal.elements = collection;
    internal.elements_generation = runtime.SlabAllocator.generationOf(collection);
    return collection;
}

/// A [SameObject] child kept beside the owner's traced edge to it: the
/// child while it is still the one made - its slot not freed or reissued,
/// not torn down. The edge is what keeps it; a child whose edge was lost
/// reads as gone and is made again, never a freed or reissued object
/// (PR-N1, the 2026-10-03 lesson).
fn liveChild(child: ?*runtime.Instance, generation: u64) ?*runtime.Instance {
    const value = child orelse return null;
    if (runtime.SlabAllocator.generationOf(value) != generation or runtime.instance_lifecycle.isCleanedUp(value)) return null;
    return value;
}

/// Getter for length
/// Spec: the number of elements in the form's elements collection.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const collection = try get_elements(instance);
    return interfaces.HTMLCollection.get_length(collection);
}

/// HTML "the form element", determining the value of an indexed property:
/// the corresponding item of form.elements. The binding checks support first.
pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
    return (try interfaces.HTMLCollection.call_item(try get_elements(instance), index)) orelse error.IndexSizeError;
}

/// HTML "the form element", determining the value of a named property:
///   1. candidates: the listed elements whose form owner is the form with an
///      id or name of `name`, except image buttons, in tree order;
///   2. if none, the img elements whose form owner is the form with one;
///   3. if none, and `name` is in the past names map, its element;
///   4. more than one: candidates, a live RadioNodeList;
///   5. exactly one: map `name` to it in the past names map, replacing the
///      entry of that name;
///   6. return it.
/// Like WebKit HTMLFormElement::namedItem, current controls precede images.
pub fn call_getter__1(instance: *runtime.Instance, name: runtime.DOMString) anyerror!runtime.JSValue {
    const key = name.asSlice();
    if (key.len == 0) return runtime.JSValue.jsUndefined;
    const internal = Registry.get(instance) orelse return runtime.JSValue.jsUndefined;
    const named = try namedElements(instance, internal);
    if (named.map.get(key)) |candidates| {
        if (candidates.control) |first| {
            // Step 4: the live control list holds the form's elements.
            if (candidates.more_controls) {
                const list = try interfaces.RadioNodeList.init(instance.ctx.allocator, instance.ctx);
                errdefer runtime.Instance.deinit(list);
                try dom.node_lists.namedControls(list, try get_elements(instance), key);
                return .{ .instance = list };
            }
            if (first.getWeak()) |element| return single(instance, internal, key, element);
        }
        if (candidates.image) |first| {
            // Step 4: the live image list holds the form (codex-lpo Q6).
            if (candidates.more_images) {
                const list = try interfaces.RadioNodeList.init(instance.ctx.allocator, instance.ctx);
                errdefer runtime.Instance.deinit(list);
                try dom.node_lists.namedFormImages(list, instance, key);
                return .{ .instance = list };
            }
            if (first.getWeak()) |element| return single(instance, internal, key, element);
        }
    }
    // Step 3: no candidate, and the past names map has the name.
    if (internal.past_names.get(key)) |element| return .{ .instance = element };
    return runtime.JSValue.jsUndefined;
}

/// Steps 5-6 for the one candidate `element`.
fn single(instance: *runtime.Instance, internal: *InternalState, name: []const u8, element: *runtime.Instance) runtime.JSValue {
    // Out of memory, the map keeps what it had: the value is still the
    // candidate, and no entry is half made.
    recordPastName(instance, internal, name, element) catch {};
    return .{ .instance = element };
}

/// Step 5: map `name` to `element`, replacing the entry of that name (a new
/// entry: its age starts again). Only where the agent can say when an
/// element changes owner - a realm with no agent host keeps no past names
/// (html.form_past_names.registryOf). The form joins the agent's list
/// before the entry is made, so no entry is ever unwatched.
fn recordPastName(instance: *runtime.Instance, internal: *InternalState, name: []const u8, element: *runtime.Instance) !void {
    const past = &internal.past_names;
    for (past.entries.items) |*existing| {
        if (!std.mem.eql(u8, existing.name, name)) continue;
        // Replaced: a new entry, the newest. A form with an entry is in the
        // agent's list already. The same element again, already the newest,
        // changes nothing - the common case, a page reading form.x in a loop.
        if (existing.element.get() == element) {
            if (existing.age + 1 != past.next_age) {
                existing.age = past.next_age;
                past.next_age += 1;
            }
            return;
        }
        const base = dom.instance_bridge.getNodeBase(@ptrCast(element)) orelse return;
        existing.element = Link.to(element);
        existing.base = base;
        existing.age = past.next_age;
        existing.form_attribute = hasAttribute(element, "form");
        past.next_age += 1;
        return;
    }
    const registry = @import("html").form_past_names.registryOf(instance.ctx) orelse return;
    const base = dom.instance_bridge.getNodeBase(@ptrCast(element)) orelse return;
    if (!past.registered) {
        try registry.add(instance);
        past.registered = true;
    }
    const allocator = past.allocator orelse instance.ctx.allocator;
    past.allocator = allocator;
    const owned = try allocator.dupe(u8, name);
    errdefer allocator.free(owned);
    try past.entries.append(allocator, .{
        .name = owned,
        .element = Link.to(element),
        .base = base,
        .age = past.next_age,
        .form_attribute = hasAttribute(element, "form"),
    });
    past.next_age += 1;
}

/// dom.form_submission's past_names_owner_change: remove each entry whose
/// element `change` gave an owner other than `form` - checked only for the
/// entries the change can reach (form_associated.formOwner's inputs: the
/// element's ancestors and connectedness, the form's tree, the element's
/// parser association and form attribute, the IDs of its tree). Answers
/// whether entries remain.
fn ownerChanged(form: *runtime.Instance, change: @import("dom").form_submission.OwnerChange) bool {
    const internal = Registry.get(form) orelse return false;
    const past = &internal.past_names;
    // A moved subtree reaches an entry when its element or the form is in
    // it (their ancestors, connectedness, parser association), or when the
    // element has a form attribute and the subtree an ID. The common moved
    // node is a childless element - a parser append, an appendChild of a
    // new node - which reaches only an entry for itself: a comparison per
    // entry, no walk.
    var moved: ?*dom.NodeBase = null;
    var leaf = false;
    var form_moved = false;
    var moved_has_id: ?bool = null;
    if (change == .subtree) {
        moved = dom.instance_bridge.getNodeBase(@ptrCast(change.subtree));
        if (moved) |node| {
            leaf = node.first_child == null and dom.custom_elements.shadowRootOf(change.subtree) == null;
            if (!leaf) if (dom.instance_bridge.getNodeBase(@ptrCast(form))) |form_base| {
                form_moved = dom.node_holds.isUnderRoot(form_base, node, null);
            };
            // A childless node is the form itself or not an ancestor of it.
            if (leaf) form_moved = change.subtree == form;
        }
    }
    var index: usize = 0;
    while (index < past.entries.items.len) {
        const entry = &past.entries.items[index];
        const reached = switch (change) {
            .subtree => |node_instance| reached: {
                const node = moved orelse break :reached true;
                if (form_moved or entry.element.instance == node_instance) break :reached true;
                if (!leaf) {
                    _ = entry.element.get() orelse break :reached true;
                    if (dom.node_holds.isUnderRoot(entry.base, node, null)) break :reached true;
                }
                if (!entry.form_attribute) break :reached false;
                if (moved_has_id == null) moved_has_id = subtreeHasId(node);
                break :reached moved_has_id.?;
            },
            .form_attribute => |changed| reached: {
                if (entry.element.instance != changed) break :reached false;
                if (entry.element.get() != null) entry.form_attribute = hasAttribute(changed, "form");
                break :reached true;
            },
            .id_attribute => entry.form_attribute,
            .association => |associated| entry.element.instance == associated,
        };
        if (reached) {
            const element = entry.element.get() orelse {
                past.remove(index);
                continue;
            };
            if (form_associated.formOwner(element) != form) {
                past.remove(index);
                continue;
            }
        }
        index += 1;
    }
    if (past.entries.items.len == 0) {
        past.registered = false;
        return false;
    }
    return true;
}

/// Whether `root` or one of its descendants is an element with a non-empty
/// ID. Shadow trees are other trees: an ID there is first in no light-tree
/// element's tree, and an element of that tree is under `root` itself.
fn subtreeHasId(root: *dom.NodeBase) bool {
    var current: ?*dom.NodeBase = root;
    while (current) |node| : (current = nextInSubtree(node, root)) {
        if (node.node_type != dom.NodeBase.ELEMENT_NODE) continue;
        const element: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse continue));
        const data = dom.element_data.of(element) orelse continue;
        if (dom.element_data.getAttributeValue(data, "id", null).len != 0) return true;
    }
    return false;
}

/// The node after `node` in tree order within `root`'s subtree.
fn nextInSubtree(node: *dom.NodeBase, root: *dom.NodeBase) ?*dom.NodeBase {
    if (node.first_child) |child| return child;
    var current = node;
    while (current != root) {
        if (current.next_sibling) |sibling| return sibling;
        current = current.parent_node orelse return null;
    }
    return null;
}

/// HTML "the form element", supported property names, steps 1-8, past names
/// included (step 4), as owned strings: the caller's array, the caller's
/// strings (review-codex-lpo-m1 S2). A fresh walk: only enumeration builds
/// the list, and a form's names are left out of its own keys (below); every
/// question about one name is `isSupportedPropertyName`'s.
/// Browser deviation (codex-lpo Q7): WebKit's
/// HTMLFormElement::supportedPropertyNames and Gecko's GetSupportedNames are
/// empty; Blink has NamedPropertyQuery but no enumerator. See
/// https://github.com/whatwg/html/issues/1731. The generated
/// Meta.named_properties_in_own_keys = false excludes these names from ownKeys;
/// this full list supports named lookup. [LegacyUnenumerableNamedProperties]
/// also makes each named property's descriptor non-enumerable.
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    const internal = Registry.get(instance) orelse return error.InvalidState;
    var names: std.ArrayListUnmanaged(runtime.DOMString) = .empty;
    errdefer {
        for (names.items) |*name| name.deinit(allocator);
        names.deinit(allocator);
    }
    const past = internal.past_names.entries.items;
    const root = form_associated.rootOf(instance);
    var node: ?*runtime.Instance = root;
    // Steps 1-5: the walk is tree order; for each element, id, then name,
    // then its past names oldest first. An element with past names is this
    // form's (they go when it changes owner).
    while (node) |element| : (node = nextInTree(element, root, false)) {
        const data = dom.element_data.of(element) orelse continue;
        const image = element.stateAs(interfaces.HTMLImageElement.State) != null;
        const has_past = for (past) |entry| {
            if (entry.element.get() == element) break true;
        } else false;
        if (!image and !has_past and !isNamedControl(element)) continue;
        if (form_associated.formOwner(element) != instance) continue;
        if (image or isNamedControl(element)) {
            for ([_][]const u8{ "id", "name" }) |attribute| {
                try appendName(&names, allocator, dom.element_data.getAttributeValue(data, attribute, null));
            }
        }
        if (!has_past) continue;
        // Its entries by age, oldest first.
        var last_age: ?u64 = null;
        while (true) {
            var next: ?*const PastEntry = null;
            for (past) |*entry| {
                if (entry.element.get() != element) continue;
                if (last_age) |age| if (entry.age <= age) continue;
                if (next == null or entry.age < next.?.age) next = entry;
            }
            const entry = next orelse break;
            last_age = entry.age;
            try appendName(&names, allocator, entry.name);
        }
    }
    return names.toOwnedSlice(allocator);
}

/// Steps 6-8 for one sourced name: none for the empty string or a repeat.
fn appendName(names: *std.ArrayListUnmanaged(runtime.DOMString), allocator: std.mem.Allocator, value: []const u8) !void {
    if (value.len == 0) return;
    for (names.items) |previous| {
        if (std.mem.eql(u8, previous.asSlice(), value)) return;
    }
    var copy = try runtime.DOMString.initDupe(allocator, value);
    errdefer copy.deinit(allocator);
    try names.append(allocator, copy);
}

/// WebIDL 3.9.7 step 1 for one name: whether `name` is one of the supported
/// property names - a current candidate's id or name, or a past name -
/// without building the list (WebKit's HTMLFormElement::
/// isSupportedPropertyName, Blink's HasNamedElements). The binding asks it
/// on every property read of a form.
pub fn isSupportedPropertyName(instance: *runtime.Instance, name: runtime.DOMString) anyerror!bool {
    const key = name.asSlice();
    // Step 6: no empty name.
    if (key.len == 0) return false;
    const internal = Registry.get(instance) orelse return false;
    const named = try namedElements(instance, internal);
    if (named.map.contains(key)) return true;
    return internal.past_names.get(key) != null;
}

fn isNamedControl(element: *runtime.Instance) bool {
    if (!form_associated.isListed(element)) return false;
    if (form_associated.isInput(element)) {
        var buffer: [16]u8 = undefined;
        if (std.mem.eql(u8, form_associated.inputType(element, &buffer), "image")) return false;
    }
    return true;
}

/// The form's `NamedElements`, read again when the tree version moved: one
/// walk of the form's tree, under the version it read.
fn namedElements(instance: *runtime.Instance, internal: *InternalState) !*const NamedElements {
    const named = &internal.named;
    const base = dom.instance_bridge.getNodeBase(@ptrCast(instance));
    if (named.arena != null) if (base) |node| if (named.key.fresh(node)) return named;

    named.deinit();
    const document = dom.live_collections.nodeDocument(instance);
    const version = if (document) |doc| dom.live_collections.treeVersion(doc) else null;
    var arena = std.heap.ArenaAllocator.init(instance.ctx.allocator);
    errdefer arena.deinit();
    const allocator = arena.allocator();
    var map: std.StringHashMapUnmanaged(Candidates) = .empty;
    const root = form_associated.rootOf(instance);
    var node: ?*runtime.Instance = root;
    while (node) |element| : (node = nextInTree(element, root, false)) {
        const data = dom.element_data.of(element) orelse continue;
        const image = element.stateAs(interfaces.HTMLImageElement.State) != null;
        if (!image and !isNamedControl(element)) continue;
        if (form_associated.formOwner(element) != instance) continue;
        const id = dom.element_data.getAttributeValue(data, "id", null);
        const name = dom.element_data.getAttributeValue(data, "name", null);
        try addCandidate(&map, allocator, id, element, image);
        // An element is one candidate, whichever of its names matches.
        if (!std.mem.eql(u8, name, id)) try addCandidate(&map, allocator, name, element, image);
    }
    named.arena = arena;
    named.map = map;
    // The version the walk read; none - no document version, the document
    // tearing down - keeps the map for this read only.
    _ = named.key.begin(Link.to(instance), document, version);
    if (base) |node_base| named.key.keyDocument(node_base);
    return named;
}

fn addCandidate(map: *std.StringHashMapUnmanaged(Candidates), allocator: std.mem.Allocator, value: []const u8, element: *runtime.Instance, image: bool) !void {
    if (value.len == 0) return;
    const slot = try map.getOrPut(allocator, value);
    if (!slot.found_existing) {
        // The arena's copy; a failure frees the whole arena, map included.
        slot.key_ptr.* = try allocator.dupe(u8, value);
        slot.value_ptr.* = .{};
    }
    const candidates = slot.value_ptr;
    if (image) {
        if (candidates.image == null) candidates.image = Link.to(element) else candidates.more_images = true;
    } else {
        if (candidates.control == null) candidates.control = Link.to(element) else candidates.more_controls = true;
    }
}

/// Setter for autocomplete
pub fn set_autocomplete(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("autocomplete"), .{ .domstring = value });
}

/// Setter for enctype
pub fn set_enctype(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("enctype"), .{ .domstring = value });
}

/// Setter for encoding
pub fn set_encoding(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // Alias for enctype - same content attribute, not a separate one.
    try set_enctype(instance, value);
}

/// Setter for method
pub fn set_method(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try interfaces.Element.call_setAttribute(instance, runtime.DOMString.initInterned("method"), .{ .domstring = value });
}

/// Operation: requestSubmit
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-requestsubmit
///
/// 1. If submitter is not null, then:
///    1. If submitter is not a submit button, then throw a TypeError.
///    2. If submitter's form owner is not this form element, then throw a
///       "NotFoundError" DOMException.
/// 2. Otherwise, set submitter to this form element.
/// 3. Submit this form element, from submitter.
pub fn call_requestSubmit(instance: *runtime.Instance, submitter: webidl.Opt(?*runtime.Instance)) anyerror!void {
    const given: ?*runtime.Instance = if (submitter.was_passed) submitter.value else null;
    if (given) |element| {
        if (!form_associated.isSubmitButton(element)) return error.TypeError;
        if (form_associated.formOwner(element) != instance) return error.NotFoundError;
        return submit(instance, element, .{});
    }
    try submit(instance, instance, .{});
}

/// Operation: reset
/// Spec: https://html.spec.whatwg.org/multipage/forms.html#dom-form-reset
///
/// 1. If this's locked for reset is true, then return.
/// 2. Set this's locked for reset to true.
/// 3. Reset this.
/// 4. Set this's locked for reset to false.
pub fn call_reset(instance: *runtime.Instance) anyerror!void {
    const internal = Registry.get(instance) orelse return;
    if (internal.locked_for_reset) return;
    internal.locked_for_reset = true;
    // Looked up again: the reset event's listeners can run anything.
    defer if (Registry.get(instance)) |after| {
        after.locked_for_reset = false;
    };
    try resetForm(instance);
}

/// Operation: checkValidity
pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
    return validateControls(instance);
}

fn validateControls(form: *runtime.Instance) !bool {
    // HTML 4.10.21.2 steps 1–4: snapshot every invalid candidate before
    // firing any events. In script realms, owned roots keep each control
    // alive if an earlier invalid listener detaches it and collects garbage.
    const allocator = form.ctx.allocator;
    const realm = form.ctx;
    var invalid: std.ArrayList(engine.Owned) = .empty;
    var any_invalid = false;
    defer {
        for (invalid.items) |held| held.release();
        invalid.deinit(allocator);
    }
    const root = form_associated.rootOf(form);
    var node: ?*runtime.Instance = root;
    while (node) |element| : (node = nextInTree(element, root, false)) {
        if (form_associated.formOwner(element) != form) continue;
        if (form_associated.isFormAssociatedCustom(element)) {
            const internals = try @import("dom").custom_elements.ensureInternals(element);
            if (!(try interfaces.ElementInternals.get_willValidate(internals))) continue;
            if (try interfaces.ValidityState.get_valid(try interfaces.ElementInternals.get_validity(internals))) continue;
        } else {
            const candidate = if (form_associated.isInput(element))
                try interfaces.HTMLInputElement.get_willValidate(element)
            else if (isElementNamed(element, "button"))
                try interfaces.HTMLButtonElement.get_willValidate(element)
            else if (isElementNamed(element, "select"))
                try interfaces.HTMLSelectElement.get_willValidate(element)
            else if (form_associated.isTextArea(element))
                try interfaces.HTMLTextAreaElement.get_willValidate(element)
            else
                false;
            if (!candidate or @import("html").forms.isValid(@import("dom").form_controls.validityFlags(element))) continue;
        }
        any_invalid = true;
        // No engine means no listener can run: keep only the result, making
        // no event that releaseIfUnwrapped would leave ownerless. This follows
        // validateCustomControls's pre-event break in base 63d0e68b2a.
        if (!realm.hasEngine()) continue;
        const held = try engine.retainValue(realm, .{ .instance = element });
        invalid.append(allocator, held) catch |err| {
            held.release();
            return err;
        };
    }
    // Steps 5–7: fire invalid at the saved list, even if a preceding listener
    // repaired a later control. Canceling the event does not change the result.
    for (invalid.items) |held| {
        if (!realm.hasEngine()) break;
        const element = engine.convertToPlatformObject(realm, held.value) orelse continue;
        const event = try interfaces.Event.call_constructor(realm, runtime.DOMString.initInterned("invalid"), .passed(.{ .cancelable = true }));
        const generation = runtime.SlabAllocator.generationOf(event);
        defer event.releaseIfUnwrapped(generation);
        _ = try @import("dom").fire_event.dispatchTrusted(element, event);
    }
    return !any_invalid;
}

/// Operation: submit
///
/// HTML § 4.10.22.3: "submit this from this, with submitted from submit()
/// method set to true" - so no submit event and no constraint validation.
pub fn call_submit(instance: *runtime.Instance) anyerror!void {
    try submit(instance, instance, .{ .from_submit_method = true });
}

/// Installed into dom.form_submission when a form is made.
const submission_algorithms: @import("dom").form_submission.Implementation = .{
    .submit = &submitFromHook,
    .reset = &resetForm,
    .construct_entry_list = &constructEntryListInto,
    .past_names_owner_change = &ownerChanged,
    .cancel_planned_navigations = &cancelPlannedNavigationsOf,
};

/// dom.form_submission: HTML "stop loading" the navigable whose active
/// document is `document` cancels the planned navigation of each of its
/// forms whose task has not run - every one still queued, as Blink's
/// LocalFrame::CancelFormSubmission (from FrameLoader::StopAllLoaders) and
/// WebKit's NavigationScheduler cancel (from FrameLoader::stopAllLoaders)
/// drop the frame's pending submission. The queued tasks find their tokens
/// gone and do nothing (runPlannedNavigation).
fn cancelPlannedNavigationsOf(document: *runtime.Instance) void {
    var registered = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return;
    while (registered.next()) |entry| {
        const form: *runtime.Instance = @ptrCast(@alignCast(entry.instance));
        const owner = interfaces.Node.get_ownerDocument(form) catch continue;
        if (owner != document) continue;
        entry.internal.pending_navigations.clearRetainingCapacity();
        entry.internal.planned_navigation = 0;
    }
}

fn submitFromHook(form: *runtime.Instance, submitter: *runtime.Instance, user_involvement: @import("dom").form_submission.UserInvolvement) anyerror!void {
    try submit(form, submitter, .{ .user_involvement = user_involvement });
}

// ============================================================================
// Resetting a form (HTML § 4.10.23)
// ============================================================================

/// "When a form element form is reset, run these steps:
/// 1. Let reset be the result of firing an event named reset at form, with
///    the bubbles and cancelable attributes initialized to true.
/// 2. If reset is true, then invoke the reset algorithm of each resettable
///    element whose form owner is form."
fn resetForm(form: *runtime.Instance) anyerror!void {
    const event = try interfaces.Event.call_constructor(
        form.ctx,
        runtime.DOMString.initInterned("reset"),
        webidl.Opt(dictionaries.EventInit).passed(.{ .bubbles = true, .cancelable = true }),
    );
    // A listener can keep the event; only one nothing wrapped is freed here.
    const generation = runtime.SlabAllocator.generationOf(event);
    const reset = blk: {
        defer event.releaseIfUnwrapped(generation);
        break :blk try @import("dom").fire_event.dispatchTrusted(form, event);
    };
    if (!reset) return;

    // Step 2: snapshot resettable controls in tree order before any resets.
    // Blink's Reset and WebKit's reset copy and hold this list: an earlier
    // reset may change the tree, but every original control still resets.
    const allocator = form.ctx.allocator;
    const realm = form.ctx;
    const Control = union(enum) {
        held: engine.Owned,
        native: struct { instance: *runtime.Instance, generation: u64 },
    };
    var controls: std.ArrayListUnmanaged(Control) = .empty;
    defer {
        for (controls.items) |control| if (control == .held) control.held.release();
        controls.deinit(allocator);
    }
    const root = form_associated.rootOf(form);
    var node: ?*runtime.Instance = root;
    while (node) |n| : (node = nextInTree(n, root, false)) {
        if (!form_associated.isElement(n)) continue;
        const resettable = form_associated.isInput(n) or form_associated.isSelect(n) or
            form_associated.isTextArea(n) or n.stateAs(interfaces.HTMLOutputElement.State) != null or form_associated.isFormAssociatedCustom(n);
        if (!resettable) continue;
        if (form_associated.formOwner(n) != form) continue;
        if (realm.hasEngine()) {
            const held = try engine.retainValue(realm, .{ .instance = n });
            controls.append(allocator, .{ .held = held }) catch |err| {
                held.release();
                return err;
            };
        } else {
            try controls.append(allocator, .{ .native = .{ .instance = n, .generation = runtime.SlabAllocator.generationOf(n) } });
        }
    }
    const form_controls = @import("dom").form_controls;
    for (controls.items) |control| switch (control) {
        .held => |held| {
            if (!realm.hasEngine()) break;
            const element = engine.convertToPlatformObject(realm, held.value) orelse continue;
            form_controls.reset(element);
        },
        .native => |native| {
            // Engine-free resets cannot run script. Generation is only the
            // teardown net; moving a control does not remove it from the list.
            const element = @import("html").forms.liveChild(native.instance, native.generation) orelse continue;
            form_controls.reset(element);
        },
    };
}

// ============================================================================
// Form submission (HTML § 4.10.22.3 - § 4.10.22.5)
//
// Everything below reaches other elements through their interfaces and the
// shared form-associated algorithms (form_associated.zig). Stated
// deviations:
//
//   * "Submit as entity body" encodes multipart/form-data through Fetch's
//     FormData extraction: UTF-8 whatever the form's encoding.
//   * An Image Button's selected coordinate is always (0, 0): nothing is
//     rendered, so no activation selects one.
// ============================================================================

/// An entry (§ 4.10.22.4): a name and a value, both scalar value strings in
/// UTF-8. A File value is represented by its name, which is all the
/// application/x-www-form-urlencoded serializer reads of it.
const Entry = struct {
    name: []u8,
    value: []u8,
    /// A file control's entry: its value is a File, represented by its name.
    is_file: bool = false,
    file: ?*runtime.Instance = null,
    file_root: ?engine.Owned = null,
};

const EntryList = std.ArrayListUnmanaged(Entry);

fn freeEntries(allocator: std.mem.Allocator, entries: *EntryList) void {
    for (entries.items) |entry| {
        allocator.free(entry.name);
        allocator.free(entry.value);
        if (entry.file_root) |held| held.release();
    }
    entries.deinit(allocator);
}

/// Copy a string a getter handed over, and free the getter's copy with the
/// allocator it was made in (the element's context allocator).
fn takeString(allocator: std.mem.Allocator, owner: *runtime.Instance, s: runtime.DOMString) ![]u8 {
    var owned = s;
    defer owned.deinit(owner.ctx.allocator);
    return allocator.dupe(u8, owned.asSlice());
}

/// § 4.10.10: an option is disabled if it has a `disabled` attribute or is a
/// child of a disabled optgroup.
fn isDisabledOption(option: *runtime.Instance) bool {
    if (hasAttribute(option, "disabled")) return true;
    const parent = parentOf(option) orelse return false;
    return isElementNamed(parent, "optgroup") and hasAttribute(parent, "disabled");
}

fn hasAncestorNamed(node: *runtime.Instance, comptime name: []const u8) bool {
    var ancestor = parentOf(node);
    while (ancestor) |a| : (ancestor = parentOf(a)) {
        if (isElementNamed(a, name)) return true;
    }
    return false;
}

/// § 4.10.7 "get the list of options" of a select: its option descendants in
/// tree order, not looking inside a select, hr, option or datalist, nor
/// inside an optgroup that is itself inside an optgroup.
const forEachOption = @import("html").forms.options.forEach;

/// § 4.10.22.5 "Picking an encoding for the form".
fn pickEncoding(allocator: std.mem.Allocator, form: *runtime.Instance, document: *runtime.Instance) !*const encoding_mod.Encoding {
    // Step 1: Let encoding be the document's character encoding.
    var chosen: *const encoding_mod.Encoding = encoding_mod.UTF_8;
    {
        var charset = try interfaces.Document.get_characterSet(document);
        defer charset.deinit(document.ctx.allocator);
        if (encoding_mod.getEncoding(charset.asSlice())) |e| chosen = e;
    }
    // Step 2: If the form element has an accept-charset attribute:
    if (try attributeValue(allocator, form, "accept-charset")) |input| {
        defer allocator.free(input);
        // 2.2-2.4: the labels, split on ASCII whitespace, that name an encoding.
        var labels = std.mem.tokenizeAny(u8, input, " \t\n\x0C\r");
        var candidate: ?*const encoding_mod.Encoding = null;
        while (labels.next()) |label| {
            if (encoding_mod.getEncoding(label)) |e| {
                candidate = e;
                break;
            }
        }
        // 2.5-2.6: the first of them, or UTF-8 if there are none.
        chosen = candidate orelse encoding_mod.UTF_8;
    }
    // Step 3: "get an output encoding".
    return encoding_mod.getOutputEncoding(chosen);
}

/// Whether `element` is a submittable element: button, input, select or
/// textarea, and form-associated custom elements.
fn isSubmittable(element: *runtime.Instance) bool {
    return form_associated.isButton(element) or form_associated.isInput(element) or
        form_associated.isSelect(element) or form_associated.isTextArea(element) or form_associated.isFormAssociatedCustom(element);
}

/// § 4.10.22.4 "construct the entry list" given form, submitter (null when
/// the form is its own submitter) and encoding. Null when the form is
/// already constructing one.
fn constructEntryList(allocator: std.mem.Allocator, form: *runtime.Instance, submitter: ?*runtime.Instance, encoding: *const encoding_mod.Encoding) !?EntryList {
    // 1. If form's constructing entry list is true, then return null.
    const internal = Registry.get(form) orelse return null;
    if (internal.constructing_entry_list) return null;
    // 2. Set form's constructing entry list to true.
    internal.constructing_entry_list = true;
    // 8, however this leaves (the formdata event's listeners can run
    // anything, so the state is looked up again).
    defer if (Registry.get(form)) |after| {
        after.constructing_entry_list = false;
    };

    // 4. Let entry list be a new empty entry list.
    var entries: EntryList = .empty;
    errdefer freeEntries(allocator, &entries);

    // 3, 5. The submittable elements whose form owner is form, in tree order.
    // A control can be associated from anywhere in the form's tree through
    // its form attribute, so the whole tree is walked.
    const root = form_associated.rootOf(form);
    var next: ?*runtime.Instance = root;
    while (next) |field| : (next = nextInTree(field, root, false)) {
        if (!form_associated.isElement(field) or !isSubmittable(field)) continue;
        if (form_associated.formOwner(field) != form) continue;
        try appendFieldEntries(allocator, &entries, field, submitter, encoding);
    }

    // No engine means no listener can run or change the entries. Skip the
    // script-only FormData/event that releaseIfUnwrapped would leave ownerless,
    // as validateCustomControls skips events in base 63d0e68b2a; step 9 returns
    // the entries directly because there was no observable intermediate list.
    if (!form.ctx.hasEngine()) return entries;

    // 6. Let form data be a new FormData object associated with entry list.
    const form_data = try entryListFormData(form, entries.items);
    const form_data_generation = runtime.SlabAllocator.generationOf(form_data);
    defer form_data.releaseIfUnwrapped(form_data_generation);

    // 7. Fire an event named formdata at form using FormDataEvent, with the
    //    formData attribute initialized to form data and the bubbles
    //    attribute initialized to true.
    {
        const event = try interfaces.FormDataEvent.call_constructor(
            form.ctx,
            runtime.DOMString.initInterned("formdata"),
            .{ .base = .{ .bubbles = true }, .formData = form_data },
        );
        const generation = runtime.SlabAllocator.generationOf(event);
        defer event.releaseIfUnwrapped(generation);
        _ = try @import("dom").fire_event.dispatchTrusted(form, event);
    }

    // 9. Return a clone of entry list - as the formdata event's listeners
    //    left it, through form data.
    freeEntries(allocator, &entries);
    entries = .empty;
    try appendDataToEntries(allocator, &entries, form_data);
    return entries;
}

/// Step 5's substeps for one field: append its entries, if any.
fn appendFieldEntries(allocator: std.mem.Allocator, entries: *EntryList, field: *runtime.Instance, submitter: ?*runtime.Instance, encoding: *const encoding_mod.Encoding) !void {
    var type_buffer: [16]u8 = undefined;
    const input_type: []const u8 = if (form_associated.isInput(field)) form_associated.inputType(field, &type_buffer) else "";
    const is_input = form_associated.isInput(field);

    // 5.1: a datalist ancestor; disabled; a button that is not submitter; an
    // unchecked checkbox or radio button.
    if (hasAncestorNamed(field, "datalist") or form_associated.isDisabled(field)) return;
    if (form_associated.isButtonControl(field) and field != submitter) return;
    if (is_input and (eql(input_type, "checkbox") or eql(input_type, "radio")) and
        !(try interfaces.HTMLInputElement.get_checked(field))) return;

    // Step 5.3: FACE constructs its entries before the name-attribute check.
    if (form_associated.isFormAssociatedCustom(field)) {
        const data = try interfaces.FormData.call_constructor(field.ctx, .notPassed(), .notPassed());
        const generation = runtime.SlabAllocator.generationOf(data);
        defer data.releaseIfUnwrapped(generation);
        try @import("dom").custom_elements.appendFormEntries(field, data);
        try appendDataToEntries(allocator, entries, data);
        return;
    }

    // 5.2: an Image Button (the submitter, per 5.1): name.x and name.y, the
    // selected coordinate.
    if (is_input and eql(input_type, "image")) {
        const given = (try attributeValue(allocator, field, "name")) orelse try allocator.dupe(u8, "");
        defer allocator.free(given);
        const prefix: []const u8 = if (given.len > 0) try std.fmt.allocPrint(allocator, "{s}.", .{given}) else "";
        defer if (prefix.len > 0) allocator.free(prefix);
        const name_x = try std.fmt.allocPrint(allocator, "{s}x", .{prefix});
        defer allocator.free(name_x);
        const name_y = try std.fmt.allocPrint(allocator, "{s}y", .{prefix});
        defer allocator.free(name_y);
        const coordinate = @import("html").forms.image_coordinate.selected(field);
        try appendEntry(allocator, entries, name_x, try std.fmt.allocPrint(allocator, "{d}", .{coordinate.x}));
        try appendEntry(allocator, entries, name_y, try std.fmt.allocPrint(allocator, "{d}", .{coordinate.y}));
        return;
    }

    // 5.4-5.5: no name attribute, or an empty one.
    const name = (try attributeValue(allocator, field, "name")) orelse return;
    defer allocator.free(name);
    if (name.len == 0) return;

    if (form_associated.isSelect(field)) {
        // 5.6: each option in the list of options whose selectedness is true
        // and that is not disabled. (Not `selectedOptions`: it is
        // [SameObject] and cached.)
        const Visit = struct {
            allocator: std.mem.Allocator,
            entries: *EntryList,
            name: []const u8,
            fn option(self: @This(), element: *runtime.Instance) anyerror!void {
                if (!(try interfaces.HTMLOptionElement.get_selected(element))) return;
                if (isDisabledOption(element)) return;
                const value = try takeString(self.allocator, element, try interfaces.HTMLOptionElement.get_value(element));
                try appendEntry(self.allocator, self.entries, self.name, value);
            }
        };
        try forEachOption(field, Visit{ .allocator = allocator, .entries = entries, .name = name }, Visit.option);
    } else if (is_input and (eql(input_type, "checkbox") or eql(input_type, "radio"))) {
        // 5.7: the value attribute, or "on".
        const value = (try attributeValue(allocator, field, "value")) orelse try allocator.dupe(u8, "on");
        try appendEntry(allocator, entries, name, value);
    } else if (is_input and eql(input_type, "file")) {
        // HTML 4.10.22.4 step 5.8: append each selected File unchanged and
        // in order. The entry list holds it by the existing File-entry rule.
        // Blink FileInputType::AppendToFormData uses the same File objects.
        const selected = try interfaces.HTMLInputElement.get_files(field);
        const count = if (selected) |list| try interfaces.FileList.get_length(list) else 0;
        if (count != 0) {
            for (0..count) |index| {
                const file = (try interfaces.FileList.call_item(selected.?, @intCast(index))) orelse continue;
                try appendFileEntry(allocator, entries, field.ctx, name, file);
            }
        } else if (field.ctx.hasEngine()) {
            const parts = try engine.createSequenceOfValues(field.ctx, &.{});
            defer parts.release();
            const file = try interfaces.File.call_constructor(field.ctx, parts.value, "", .passed(.{
                .base = .{ .type = runtime.DOMString.initInterned("application/octet-stream") },
            }));
            const generation = runtime.SlabAllocator.generationOf(file);
            defer file.releaseIfUnwrapped(generation);
            const held = try engine.retainValue(field.ctx, .{ .instance = file });
            errdefer held.release();
            try appendEntry(allocator, entries, name, try allocator.dupe(u8, ""));
            const added = &entries.items[entries.items.len - 1];
            added.is_file = true;
            added.file = file;
            added.file_root = held;
        } else {
            // Engine-free entry construction retains its native filename
            // representation; creating an ECMAScript sequence needs an engine.
            try appendEntry(allocator, entries, name, try allocator.dupe(u8, ""));
            entries.items[entries.items.len - 1].is_file = true;
        }
    } else if (is_input and eql(input_type, "hidden") and std.ascii.eqlIgnoreCase(name, "_charset_")) {
        // 5.9: the encoding's name.
        try appendEntry(allocator, entries, name, try allocator.dupe(u8, encoding.name));
    } else {
        // 5.10: the value of the field element.
        const value = if (form_associated.isTextArea(field))
            try forms.textarea_value.submissionValue(allocator, field)
        else if (form_associated.isButton(field))
            try takeString(allocator, field, try interfaces.HTMLButtonElement.get_value(field))
        else
            try takeString(allocator, field, try interfaces.HTMLInputElement.get_value(field));
        try appendEntry(allocator, entries, name, value);
    }

    // 5.11: a dirname attribute that is not empty, on an auto-directionality
    // form-associated element: its directionality, under the dirname.
    if (form_associated.isAutoDirectionalityFormAssociated(field)) {
        if (try attributeValue(allocator, field, "dirname")) |dirname| {
            defer allocator.free(dirname);
            if (dirname.len > 0) {
                const dir: []const u8 = switch (form_associated.directionality(field)) {
                    .ltr => "ltr",
                    .rtl => "rtl",
                };
                try appendEntry(allocator, entries, dirname, try allocator.dupe(u8, dir));
            }
        }
    }
}

/// dom.form_submission's "construct the entry list": FormData(form,
/// submitter)'s steps 1.1-1.4, appending the clone to `form_data`.
fn constructEntryListInto(form: *runtime.Instance, submitter: ?*runtime.Instance, form_data: *runtime.Instance) anyerror!void {
    // 1.1: a submitter must be a submit button whose form owner is form.
    if (submitter) |element| {
        if (!form_associated.isSubmitButton(element)) return error.TypeError;
        if (form_associated.formOwner(element) != form) return error.NotFoundError;
    }
    // 1.2-1.3: the entry list with the default encoding, UTF-8; null (a
    // form already constructing one) throws.
    const allocator = form.ctx.allocator;
    var entries = (try constructEntryList(allocator, form, submitter, encoding_mod.UTF_8)) orelse return error.InvalidStateError;
    defer freeEntries(allocator, &entries);
    // 1.4: set this's entry list to it.
    for (entries.items) |entry| try appendEntryToData(form_data, entry);
}

// HTML 4.10.22.4: cloning an entry list keeps each File object unchanged.
fn appendDataToEntries(allocator: std.mem.Allocator, entries: *EntryList, data: *runtime.Instance) !void {
    for (interfaces.FormData.getEntriesForIterable(data) orelse &.{}) |entry| {
        switch (entry.value) {
            .usvstring => |value| try appendEntry(allocator, entries, entry.name, try allocator.dupe(u8, value)),
            .file => |file| try appendFileEntry(allocator, entries, data.ctx, entry.name, file),
        }
    }
}

// The same hold as cloning a FormData entry list: the filename is owned by
// the entry, and the File's wrapper is held for exactly the entry list's life.
fn appendFileEntry(allocator: std.mem.Allocator, entries: *EntryList, ctx: runtime.Context, name: []const u8, file: *runtime.Instance) !void {
    const held: ?engine.Owned = if (ctx.hasEngine()) try engine.retainValue(ctx, .{ .instance = file }) else null;
    errdefer if (held) |root| root.release();
    const filename = try takeString(allocator, file, try interfaces.File.get_name(file));
    try appendEntry(allocator, entries, name, filename);
    const added = &entries.items[entries.items.len - 1];
    added.is_file = true;
    added.file = file;
    added.file_root = held;
}

fn appendEntryToData(data: *runtime.Instance, entry: Entry) !void {
    if (entry.file) |file| {
        try interfaces.FormData.call_append__1(data, entry.name, file, .notPassed());
    } else {
        try interfaces.FormData.call_append(data, entry.name, entry.value);
    }
}

fn eql(a: []const u8, comptime b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

/// "Create an entry" and append it. Takes ownership of `value`.
fn appendEntry(allocator: std.mem.Allocator, entries: *EntryList, name: []const u8, value: []u8) !void {
    errdefer allocator.free(value);
    const name_copy = try allocator.dupe(u8, name);
    errdefer allocator.free(name_copy);
    try entries.append(allocator, .{ .name = name_copy, .value = value });
}

/// § 4.10.22.6 "convert to a list of name-value pairs", steps 2.1 and 2.3:
/// every CR not followed by LF and every LF not preceded by CR becomes CRLF.
fn normalizeNewlines(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        switch (s[i]) {
            '\r' => {
                try out.appendSlice(allocator, "\r\n");
                if (i + 1 < s.len and s[i + 1] == '\n') i += 1;
            },
            '\n' => try out.appendSlice(allocator, "\r\n"),
            else => |c| try out.append(allocator, c),
        }
    }
    return out.toOwnedSlice(allocator);
}

/// URL's application/x-www-form-urlencoded percent-encode set.
fn inFormUrlencodedSet(byte: u8) bool {
    return encode_sets.shouldEncode(byte, .form_urlencoded);
}

/// URL § 5.2 "application/x-www-form-urlencoded serializer", given the pairs
/// of `entries` (converted as above) and `encoding`.
fn serializeEntries(allocator: std.mem.Allocator, entries: []const Entry, encoding: *const encoding_mod.Encoding) ![]u8 {
    var output: std.ArrayListUnmanaged(u8) = .empty;
    errdefer output.deinit(allocator);
    for (entries) |entry| {
        const name = try normalizeNewlines(allocator, entry.name);
        defer allocator.free(name);
        const value = try normalizeNewlines(allocator, entry.value);
        defer allocator.free(value);
        // Step 3.4: "&" between tuples.
        if (output.items.len > 0) try output.append(allocator, '&');
        // Steps 3.2-3.3 and 3.5.
        try encoding_mod.percentEncodeAfterEncoding(allocator, &output, encoding, name, inFormUrlencodedSet, true);
        try output.append(allocator, '=');
        try encoding_mod.percentEncodeAfterEncoding(allocator, &output, encoding, value, inFormUrlencodedSet, true);
    }
    return output.toOwnedSlice(allocator);
}

/// The optional arguments of § 4.10.22.3 "submit".
const SubmitOptions = struct {
    /// "submitted from submit() method".
    from_submit_method: bool = false,
    /// "userInvolvement" - "none" by default.
    user_involvement: @import("dom").form_submission.UserInvolvement = .none,
};

/// A form "cannot navigate" if it is not connected, or its node document is
/// not fully active. (Only the first is checked: a document that is not
/// fully active has no navigable for the planned navigation to reach.)
fn cannotNavigate(form: *runtime.Instance) bool {
    return !(interfaces.Node.get_isConnected(form) catch false);
}

/// The value of a submit button's form-submission attribute (`formaction`,
/// `formmethod`, ...) when `submitter` is a submit button that has it, owned;
/// null otherwise - the form's own attribute then applies.
fn submitterAttribute(allocator: std.mem.Allocator, submitter: *runtime.Instance, form: *runtime.Instance, comptime name: []const u8) !?[]u8 {
    if (submitter == form or !form_associated.isSubmitButton(submitter)) return null;
    return attributeValue(allocator, submitter, name);
}

/// A method or formmethod keyword's state; invalid values are GET.
fn methodState(value: []const u8) []const u8 {
    if (std.ascii.eqlIgnoreCase(value, "post")) return "post";
    if (std.ascii.eqlIgnoreCase(value, "dialog")) return "dialog";
    return "get";
}

/// An enctype or formenctype keyword's state; invalid values are
/// application/x-www-form-urlencoded.
fn enctypeState(value: []const u8) []const u8 {
    if (std.ascii.eqlIgnoreCase(value, "multipart/form-data")) return "multipart/form-data";
    if (std.ascii.eqlIgnoreCase(value, "text/plain")) return "text/plain";
    return "application/x-www-form-urlencoded";
}

/// § 4.10.22.3 "submit" `form` from `submitter` - a submit button, or the
/// form itself.
fn submit(form: *runtime.Instance, submitter: *runtime.Instance, options: SubmitOptions) !void {
    const allocator = form.ctx.allocator;

    // 1. If form cannot navigate, then return.
    if (cannotNavigate(form)) return;
    // 2. If form's constructing entry list is true, then return.
    if (Registry.get(form)) |internal| {
        if (internal.constructing_entry_list) return;
    }
    // 3. Let form document be form's node document.
    const document = (try interfaces.Node.get_ownerDocument(form)) orelse return;
    // 4. "If form document's active sandboxing flag set has its sandboxed
    // forms browsing context flag set, then return."
    if (@import("dom").document_scripts.activeSandboxingFlags(document).forms) return;

    // 5. If submitted from submit() method is false:
    if (!options.from_submit_method) {
        const internal = Registry.get(form) orelse return;
        // 5.1-5.2: firing submission events.
        if (internal.firing_submission_events) return;
        internal.firing_submission_events = true;
        // 5.4: statically validate all native and form-associated custom
        // controls; a headless host has no additional validation UI.
        defer if (Registry.get(form)) |after| {
            after.firing_submission_events = false;
        };
        const no_validate = hasAttribute(form, "novalidate") or
            (submitter != form and hasAttribute(submitter, "formnovalidate"));
        if (!no_validate and !(try validateControls(form))) return;

        // 5.5: submitterButton is null if submitter is form.
        const submitter_button: ?*runtime.Instance = if (submitter == form) null else submitter;
        // 5.6: fire submit, a SubmitEvent with submitter, bubbling and
        // cancelable.
        const should_continue = blk: {
            // 5.7, however the dispatch ends.
            defer if (Registry.get(form)) |after| {
                after.firing_submission_events = false;
            };
            const event = try interfaces.SubmitEvent.call_constructor(
                form.ctx,
                runtime.DOMString.initInterned("submit"),
                webidl.Opt(dictionaries.SubmitEventInit).passed(.{
                    .base = .{ .bubbles = true, .cancelable = true },
                    .submitter = submitter_button,
                }),
            );
            const generation = runtime.SlabAllocator.generationOf(event);
            defer event.releaseIfUnwrapped(generation);
            break :blk try @import("dom").fire_event.dispatchTrusted(form, event);
        };
        // 5.8: If shouldContinue is false, then return.
        if (!should_continue) return;
        // Deviation from the spec text, where every submission replaces the
        // form's planned navigation ("plan to navigate" step 3): the browsers
        // cancel the form's last planned navigation here, once the submit
        // event lets the submission go on, and only for a submission that
        // fires it (a submit button, implicit submission, requestSubmit()).
        // A submit() call cancels nothing (planNavigationWith). Blink:
        // HTMLFormElement::PrepareForSubmission runs cancel_last_submission_
        // before ScheduleFormSubmission, which submitFromJavaScript calls
        // directly; WebKit: HTMLFormElement::submitIfPossible cancels
        // m_plannedFormSubmission, which submitFromJavaScript only overwrites.
        // The cancellation comes before the connected check, as in both.
        // form-submission-0/form-double-submit.html pins this one.
        cancelLastPlannedNavigation(form);
        // 5.9: dispatching submit could have changed this.
        if (cannotNavigate(form)) return;
    }

    // 6. Let encoding be the result of picking an encoding for the form.
    const encoding = try pickEncoding(allocator, form, document);
    // 7. Let entry list be the result of constructing the entry list with
    //    form, submitter and encoding. (8: it is not null - nothing between
    //    step 2 and here constructs one.)
    var entries = (try constructEntryList(allocator, form, if (submitter == form) null else submitter, encoding)) orelse return;
    defer freeEntries(allocator, &entries);
    // 9. The formdata event could have changed this.
    if (cannotNavigate(form)) return;

    // 10. Let method be the submitter element's method: its formmethod
    //     attribute's state if it is a submit button that has one, else the
    //     form's method attribute's state.
    const method: []const u8 = blk: {
        if (try submitterAttribute(allocator, submitter, form, "formmethod")) |value| {
            defer allocator.free(value);
            break :blk methodState(value);
        }
        const value = (try attributeValue(allocator, form, "method")) orelse break :blk "get";
        defer allocator.free(value);
        break :blk methodState(value);
    };
    // 11. dialog closes the nearest dialog ancestor; nothing navigates.
    if (eql(method, "dialog")) {
        var ancestor = parentOf(form);
        while (ancestor) |subject| : (ancestor = parentOf(subject)) {
            if (subject.stateAs(interfaces.HTMLDialogElement.State) == null) continue;
            var result = try @import("html").dialog.submissionResult(allocator, submitter);
            defer if (result.wasPassed()) result.value.deinit(allocator);
            try dom.dialog.close(subject, result, null);
            return;
        }
        return;
    }

    // 12-13: action - the submitter's formaction or the form's action - or
    // the form document's URL when it is empty.
    const document_url = try interfaces.Document.get_URL(document);
    defer document.ctx.allocator.free(document_url);
    const action_attribute = (try submitterAttribute(allocator, submitter, form, "formaction")) orelse
        try attributeValue(allocator, form, "action");
    defer if (action_attribute) |a| allocator.free(a);
    const action: []const u8 = if (action_attribute) |a| (if (a.len > 0) a else document_url) else document_url;

    // 14–15: encoding-parse relative to the SUBMITTER's node document.
    // The existing shared algorithm preserves legacy query encodings.
    const encoded_action = (try @import("dom").encoding_parse.encodingParseAndSerialize(submitter, action)) orelse return;
    defer submitter.ctx.allocator.free(encoded_action);
    var parsed_action = basic_parser.parse(allocator, encoded_action, null) catch return;
    defer parsed_action.deinit();

    // 17. Let enctype be the submitter element's enctype.
    const enctype: []const u8 = blk: {
        if (try submitterAttribute(allocator, submitter, form, "formenctype")) |value| {
            defer allocator.free(value);
            break :blk enctypeState(value);
        }
        const value = (try attributeValue(allocator, form, "enctype")) orelse break :blk "application/x-www-form-urlencoded";
        defer allocator.free(value);
        break :blk enctypeState(value);
    };

    // 18-20: formTarget - a submit button's formtarget attribute - then the
    // target, "getting an element's target" given the submitter's form owner
    // (form) and formTarget. The navigable for it is chosen when the planned
    // navigation runs (dom.navigables), which opens a new one for "_blank"
    // or a name nothing has.
    const form_target = try submitterAttribute(allocator, submitter, form, "formtarget");
    defer if (form_target) |t| allocator.free(t);
    const target = try elementTarget(allocator, form, form_target, document);
    errdefer allocator.free(target);

    // 21 and "plan to navigate": capture the form's link types now. Later
    // rel/target mutations cannot change an already planned navigation.
    const rel = try attributeValue(allocator, form, "rel");
    defer if (rel) |value| allocator.free(value);
    const policy = forms.targetPolicy(rel orelse "", target);

    // 26. The scheme and method pick the behaviour.
    const scheme = parsed_action.scheme();
    const is_get = eql(method, "get");
    const mutate = is_get and (eql(scheme, "http") or eql(scheme, "https") or eql(scheme, "data") or eql(scheme, "file"));
    if (!is_get and (eql(scheme, "http") or eql(scheme, "https"))) {
        // "Submit as entity body": a POST resource of the entry list encoded
        // by enctype, planned to the parsed action as it is. The entry list
        // goes with it, as a FormData, for the navigate event (navigate's
        // formDataEntryList).
        // The target goes with the errdefer above on every error return:
        // freed here as well, a failed step freed it twice.
        const form_data = try entryListFormData(form, entries.items);
        const form_data_generation = runtime.SlabAllocator.generationOf(form_data);
        var post = entityBody(allocator, enctype, form_data, entries.items, encoding) catch |err| {
            form_data.releaseIfUnwrapped(form_data_generation);
            return err;
        };
        errdefer post.deinit(allocator);
        errdefer form_data.releaseIfUnwrapped(form_data_generation);
        const url = try url_serializer.serialize(allocator, &parsed_action, false);
        planNavigationWith(form, submitter, url, target, post, form_data, policy, options.user_involvement);
        return;
    }
    if (eql(scheme, "mailto")) {
        // "Mail with headers" / "Mail as body": no mail client to hand to.
        allocator.free(target);
        return;
    }
    if (mutate) {
        // "Mutate action URL": pairs, serialized with encoding, become the query.
        const query = try serializeEntries(allocator, entries.items, encoding);
        defer allocator.free(query);
        try parsed_action.setQuery(query);
    }
    // Otherwise "get action URL": parsed action as it is.

    const url = try url_serializer.serialize(allocator, &parsed_action, false);
    planNavigation(form, submitter, url, target, policy, options.user_involvement);
}

/// HTML "get an element's target" given the form and a target override
/// (the submitter's formtarget): the override if given, else the form's
/// target attribute, else the target of the document's first base element
/// that has one, else ""; one with an ASCII tab or newline and a "<" in it is
/// "_blank" (dangling markup). Owned.
fn elementTarget(allocator: std.mem.Allocator, form: *runtime.Instance, override: ?[]const u8, document: *runtime.Instance) ![]u8 {
    const given = if (override) |t| try allocator.dupe(u8, t) else (try attributeValue(allocator, form, "target")) orelse blk: {
        const base = (interfaces.Document.call_querySelector(document, runtime.DOMString.initInterned("base[target]")) catch null) orelse
            break :blk try allocator.dupe(u8, "");
        break :blk (try attributeValue(allocator, base, "target")) orelse try allocator.dupe(u8, "");
    };
    if (std.mem.indexOfAny(u8, given, "\t\n\r") != null and std.mem.indexOfScalar(u8, given, '<') != null) {
        allocator.free(given);
        return allocator.dupe(u8, "_blank");
    }
    return given;
}

/// A POST resource (HTML "POST resource"): its request body and request
/// content-type. Owned.
const PostResource = struct {
    body: []u8,
    content_type: []u8,

    fn deinit(self: *PostResource, allocator: std.mem.Allocator) void {
        allocator.free(self.body);
        allocator.free(self.content_type);
    }
};

/// "Submit as entity body": "Switch on enctype" - the body and mimeType for
/// the entry list, given the submitter's enctype.
fn entityBody(allocator: std.mem.Allocator, enctype: []const u8, form_data: *runtime.Instance, entries: []const Entry, encoding: *const encoding_mod.Encoding) !PostResource {
    if (eql(enctype, "multipart/form-data")) return multipartBody(allocator, form_data, encoding);
    if (eql(enctype, "text/plain")) {
        // "Let body be the result of running the text/plain encoding
        // algorithm with pairs. Set body to the result of encoding body using
        // encoding. Let mimeType be `text/plain`."
        const body = try textPlainBody(allocator, entries, encoding);
        errdefer allocator.free(body);
        return .{ .body = body, .content_type = try allocator.dupe(u8, "text/plain") };
    }
    // application/x-www-form-urlencoded: "Let body be the result of running
    // the application/x-www-form-urlencoded serializer with pairs and
    // encoding. Set body to the result of encoding body. Let mimeType be
    // `application/x-www-form-urlencoded`."
    const body = try serializeEntries(allocator, entries, encoding);
    errdefer allocator.free(body);
    return .{ .body = body, .content_type = try allocator.dupe(u8, "application/x-www-form-urlencoded") };
}

/// HTML multipart encoding shares Fetch's FormData serializer and boundary.
/// File bytes stay unchanged; names and string fields use the form's encoding.
fn multipartBody(allocator: std.mem.Allocator, form_data: *runtime.Instance, encoding: *const encoding_mod.Encoding) !PostResource {
    var extracted = fetch_body.extractFormData(allocator, form_data, encoding) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.TypeError => error.TypeError,
    };
    defer extracted.deinit();
    const body_object = extracted.body orelse return error.TypeError;
    const body = try allocator.dupe(u8, body_object.getBytes());
    errdefer allocator.free(body);
    const content_type = extracted.content_type orelse return error.TypeError;
    extracted.content_type = null;
    return .{ .body = body, .content_type = content_type };
}

/// A FormData over the entry list - a new one in the form's realm, with the
/// entries appended. Nothing holds it yet.
fn entryListFormData(form: *runtime.Instance, entries: []const Entry) !*runtime.Instance {
    const form_data = try interfaces.FormData.call_constructor(form.ctx, webidl.Opt(*runtime.Instance).notPassed(), webidl.Opt(?*runtime.Instance).notPassed());
    errdefer form_data.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(form_data));
    for (entries) |entry| try appendEntryToData(form_data, entry);
    return form_data;
}

/// "The text/plain encoding algorithm" over the entry list's pairs ("convert
/// to a list of name-value pairs": a file's name for a File, newlines as
/// CRLF), then encoded with `encoding`: "1. Let result be the empty string.
/// 2. For each pair in pairs: append pair's name, "=", pair's value, then a
/// U+000D CR U+000A LF pair to result. 3. Return result."
fn textPlainBody(allocator: std.mem.Allocator, entries: []const Entry, encoding: *const encoding_mod.Encoding) ![]u8 {
    var text: std.ArrayListUnmanaged(u8) = .empty;
    defer text.deinit(allocator);
    for (entries) |entry| {
        const name = try normalizeNewlines(allocator, entry.name);
        defer allocator.free(name);
        const value = try normalizeNewlines(allocator, entry.value);
        defer allocator.free(value);
        try text.appendSlice(allocator, name);
        try text.append(allocator, '=');
        try text.appendSlice(allocator, value);
        try text.appendSlice(allocator, "\r\n");
    }
    if (eql(encoding.name, "UTF-8")) return allocator.dupe(u8, text.items);
    const units = try std.unicode.utf8ToUtf16LeAlloc(allocator, text.items);
    defer allocator.free(units);
    const encoded = encoding_mod.hooks.encode(allocator, units, encoding) catch return error.OutOfMemory;
    defer allocator.free(encoded);
    return allocator.dupe(u8, encoded);
}

/// A planned navigation (§ 4.10.22.3 "plan to navigate"): the queued task's
/// data. The task KEEPS the form, the submitter and the form document until
/// it runs or is dropped (dom.node_holds.TaskHold: WebKit's planned form
/// submission keeps its form and submitter by Ref, Blink's FormSubmission
/// traces form_ and submit_button_); its planned-navigation token says
/// whether it still navigates. Each hold reads null only after a teardown
/// freed its node (the realm's end) - a net, never the behaviour.
const PlannedNavigation = struct {
    form: TaskHold = .{},
    /// The submit algorithm's submitter - the form itself for submit():
    /// "plan to navigate" step 4.2 navigates with sourceElement set to it
    /// (the navigate event's sourceElement).
    submitter: TaskHold = .{},
    token: u64,
    url: []const u8,
    target: []const u8,
    noopener: bool,
    noreferrer: bool,
    user_involvement: @import("dom").navigation_api.UserInvolvement,
    /// Submit step 22's condition, taken when the form was submitted: the
    /// form document had not completely loaded.
    source_not_completely_loaded: bool,
    /// The form document at submission: "the rules for choosing a navigable"
    /// (submit step 22) start from its node navigable. The form may be in
    /// another document by the time the task runs - the navigation still
    /// goes to the navigable chosen at submission.
    form_document: TaskHold = .{},
    /// The POST resource of a submission "as entity body"; null for GET.
    post: ?PostResource = null,
    /// With it, the entry list as a FormData, kept alive until the planned
    /// navigation runs.
    form_data: ?*runtime.Instance = null,
    form_data_pin: same_object.Pin = .{},
    allocator: std.mem.Allocator,

    /// The task's one end, run or dropped: every hold is released here,
    /// exactly once.
    fn destroy(self: *PlannedNavigation) void {
        self.form.release();
        self.submitter.release();
        self.form_document.release();
        self.allocator.free(self.url);
        self.allocator.free(self.target);
        if (self.post) |*post| post.deinit(self.allocator);
        self.form_data_pin.release();
        self.allocator.destroy(self);
    }
};

/// Source of planned-navigation tokens: never reused, never zero.
threadlocal var next_navigation_token: u64 = 1;

/// "Plan to navigate" to `url`. Takes ownership of `url` and `target`.
fn planNavigation(form: *runtime.Instance, submitter: *runtime.Instance, url: []const u8, target: []const u8, policy: forms.TargetPolicy, user_involvement: @import("dom").form_submission.UserInvolvement) void {
    planNavigationWith(form, submitter, url, target, null, null, policy, user_involvement);
}

/// "Plan to navigate" to `url`, given a POST resource and the entry list's
/// FormData, or neither. Takes ownership of `url`, `target` and `post`; a
/// `form_data` nothing else holds goes with the task.
fn planNavigationWith(form: *runtime.Instance, submitter: *runtime.Instance, url: []const u8, target: []const u8, post: ?PostResource, form_data: ?*runtime.Instance, policy: forms.TargetPolicy, user_involvement: @import("dom").form_submission.UserInvolvement) void {
    const allocator = form.ctx.allocator;
    const task = allocator.create(PlannedNavigation) catch {
        allocator.free(url);
        allocator.free(target);
        if (post) |resource| {
            var owned = resource;
            owned.deinit(allocator);
        }
        if (form_data) |fd| fd.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(fd));
        return;
    };
    // Submit step 22: "If form document equals targetNavigable's active
    // document, and form document has not yet completely loaded, then set
    // historyHandling to "replace"" - the load state now, at submission.
    const document = interfaces.Node.get_ownerDocument(form) catch null;
    const not_loaded = if (document) |d| !@import("dom").document_lifecycle.isCompletelyLoaded(d) else false;
    task.* = .{
        .token = next_navigation_token,
        .url = url,
        .target = target,
        .noopener = policy.noopener,
        .noreferrer = policy.noreferrer,
        .user_involvement = switch (user_involvement) {
            .none => .none,
            .activation => .activation,
            .browser_ui => .browser_ui,
        },
        .source_not_completely_loaded = not_loaded,
        .post = post,
        .form_data = form_data,
        .allocator = allocator,
    };
    task.form.take(form);
    task.submitter.take(submitter);
    if (document) |d| task.form_document.take(d);
    if (form_data) |fd| task.form_data_pin.hold(fd);
    next_navigation_token += 1;

    const internal = Registry.get(form) orelse return task.destroy();
    const event_loop = form.ctx.getOptionalEventLoop() orelse return task.destroy();
    // Steps 3 and 5, as the browsers do them (golden rule 2). The spec text
    // removes the form's planned navigation from its task queue whatever it
    // targets, so three submit() calls aimed at three frames navigate only
    // the last; Chrome 154, Firefox 157 and Safari 27 navigate all three
    // (form-submission-0/form-double-submit-multiple-targets.html, 1/1 in
    // each, wpt.fyi run cc74d2669f). In Blink a scheduled form submission
    // replaces only the earlier one aimed at the same frame -
    // Frame::ScheduleFormSubmission keeps one form_submit_navigation_task_
    // per frame - and the form cancels its last one only from
    // PrepareForSubmission (cancelLastPlannedNavigation, above). WebKit
    // matches: FrameLoader::submitForm schedules on the target frame's
    // NavigationScheduler, and only submitIfPossible cancels the form's
    // planned submission. So: an earlier plan of this form aimed at the same
    // navigable is replaced; the others stay queued. Not modelled, stated:
    // a plan of ANOTHER form aimed at the same navigable is not replaced here
    // - its navigation replaces the earlier one's ongoing navigation instead.
    const navigable = targetNavigableId(document, target);
    if (navigable != 0) {
        var i: usize = 0;
        while (i < internal.pending_navigations.items.len) {
            if (internal.pending_navigations.items[i].navigable == navigable) {
                _ = internal.pending_navigations.orderedRemove(i);
            } else i += 1;
        }
    }
    if (internal.pending_allocator == null) internal.pending_allocator = allocator;
    internal.pending_navigations.append(internal.pending_allocator.?, .{ .token = task.token, .navigable = navigable }) catch return task.destroy();
    internal.planned_navigation = task.token;
    // Step 4: queue a task that navigates.
    event_loop.queueTask(.{ .callback = &runPlannedNavigation, .context = task, .drop = &dropPlannedNavigation });
}

/// A closing queue still releases everything the task owns, its holds
/// included (`destroy`).
fn dropPlannedNavigation(data: ?*anyopaque) void {
    const task: *PlannedNavigation = @ptrCast(@alignCast(data orelse return));
    task.destroy();
}

/// Removes the planned navigation `token` from the form's queued ones;
/// whether it was there (its task may run).
fn takePendingNavigation(internal: *InternalState, token: u64) bool {
    for (internal.pending_navigations.items, 0..) |pending, i| {
        if (pending.token != token) continue;
        _ = internal.pending_navigations.orderedRemove(i);
        return true;
    }
    return false;
}

/// Blink's cancel_last_submission_, WebKit's m_plannedFormSubmission->cancel():
/// the form's last planned navigation, if its task has not run, does not.
fn cancelLastPlannedNavigation(form: *runtime.Instance) void {
    const internal = Registry.get(form) orelse return;
    if (internal.planned_navigation == 0) return;
    _ = takePendingNavigation(internal, internal.planned_navigation);
    internal.planned_navigation = 0;
}

/// The id of the navigable `target` names from `document`'s node navigable
/// at submission - its html_core BrowsingContext's - or 0 for "_blank", a
/// name no frame has (a new or existing popup: the window open steps choose
/// it when the plan runs) or a document with no navigable. Only identifies
/// the navigable; the plan's task still chooses it (navigateSteps).
fn targetNavigableId(document: ?*runtime.Instance, target: []const u8) u64 {
    const doc = document orelse return 0;
    if (std.ascii.eqlIgnoreCase(target, "_blank")) return 0;
    const window = (interfaces.Document.get_defaultView(doc) catch null) orelse return 0;
    const own = @import("dom").browser_state.browsingContextOf(window) orelse return 0;
    if (target.len == 0 or std.ascii.eqlIgnoreCase(target, "_self")) return own.id;
    if (std.ascii.eqlIgnoreCase(target, "_parent")) return (own.parent orelse own).id;
    if (std.ascii.eqlIgnoreCase(target, "_top")) {
        var top = own;
        var depth: usize = 0;
        while (top.parent) |parent| : (depth += 1) {
            if (depth >= 64) break;
            top = parent;
        }
        return top.id;
    }
    const named = @import("dom").navigables.findByName(doc, target) orelse return 0;
    const browsing_context = @import("dom").browser_state.browsingContextOf(named) orelse return 0;
    return browsing_context.id;
}

fn runPlannedNavigation(data: ?*anyopaque) void {
    const task: *PlannedNavigation = @ptrCast(@alignCast(data orelse return));
    defer task.destroy();

    // The task keeps the form; it reads null only after its realm's end.
    const form = task.form.get() orelse return;
    const internal = Registry.get(form) orelse return;
    // A later plan aimed at the same navigable, or a submission that fired
    // the submit event, cancelled this one (planNavigationWith).
    if (!takePendingNavigation(internal, task.token)) return;
    // Step 4.1: Set the form's planned navigation to null - if this task is
    // still the form's last one.
    if (internal.planned_navigation == task.token) internal.planned_navigation = 0;

    // A task is entered from the event loop, not from script: it runs as a
    // task of the form's realm, which enters it. A realm with no engine
    // behind it any more (its page has gone) runs nothing, and the task has
    // no one to report to: it is dropped, as a task of a document that is
    // not fully active is.
    engine.runTaskInRealm(form.ctx, navigateSteps, task) catch {};
}

/// Step 4.2 of the planned navigation's task, inside the form's realm.
fn navigateSteps(data: ?*anyopaque) void {
    const task: *PlannedNavigation = @ptrCast(@alignCast(data orelse return));

    // Step 4.2: "Navigate targetNavigable to url using the form element's
    // node document, with historyHandling set to historyHandling" - which
    // submit step 22 made "replace" when the form document is the target's
    // active document and has not completely loaded. The rules for choosing
    // a navigable and the navigation are the navigables' (dom.navigables).
    //
    // Submit step 22 chooses targetNavigable at submission, from the form
    // document's node navigable; Crane chooses when the task runs, but from
    // that same document, so a form moved to another document before its
    // task still navigates the navigable it was submitted in
    // (form-submission-0/reparent-form-during-planned-navigation-task; Chrome
    // and Safari pass it). The navigation uses the form's node document now.
    const form = task.form.get() orelse return;
    const document = (interfaces.Node.get_ownerDocument(form) catch null) orelse return;
    const form_document = task.form_document.get();
    const navigables = @import("dom").navigables;
    navigables.navigateByTarget(document, .{
        .target = task.target,
        .noopener = task.noopener,
        .noreferrer = task.noreferrer,
        .current_document = if (form_document != document) form_document else null,
        .url = task.url,
        .source_not_completely_loaded = task.source_not_completely_loaded,
        // "Plan to navigate" step 4.2: "with ... sourceElement set to
        // submitter" - the submit button that was clicked or passed to
        // requestSubmit(), or the form itself, kept by the task.
        .source_element = task.submitter.get(),
        .user_involvement = task.user_involvement,
        .post_resource = if (task.post) |post| .{ .body = post.body, .content_type = post.content_type } else null,
        .form_data = task.form_data,
        // "Navigate" with cspNavigationType "form-submission".
        .csp_navigation_type = .form_submission,
    });
}

/// Operation: reportValidity
pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
    return validateControls(instance);
}

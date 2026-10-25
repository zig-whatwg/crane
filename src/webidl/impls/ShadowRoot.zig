//! Implementation for ShadowRoot interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-shadowroot
//! WHATWG DOM Standard §4.8.1
//!
//! Shadow roots are DocumentFragments that serve as the root of a shadow tree.
//! A shadow root is always attached to another node tree through its host element.
//!
//! Migrated from: webidl/src/dom/ShadowRoot.zig

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const ShadowRoot = interfaces.ShadowRoot;

pub const State = ShadowRoot.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Internal state for ShadowRoot
/// Spec: https://dom.spec.whatwg.org/#shadowroot
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The mode of this shadow root ("open" or "closed")
    shadow_mode: enums.ShadowRootMode,

    /// Whether focus is delegated to the first focusable element
    delegates_focus_flag: bool,

    /// How slottables are assigned to slots ("manual" or "named")
    slot_assignment_mode: enums.SlotAssignmentMode,

    /// Whether this shadow root can be cloned
    clonable_flag: bool,

    /// Whether this shadow root can be serialized
    serializable_flag: bool,

    /// Whether this shadow root is available to element internals
    available_to_element_internals: bool,

    /// Whether this shadow root is declarative
    declarative_flag: bool,

    /// Keep custom element registry null (for declarative shadow roots)
    keep_custom_element_registry_null: bool,

    /// The host element for this shadow root
    host: ?*runtime.Instance,

    /// Custom element registry (from DocumentOrShadowRoot mixin), read
    /// through `get()`: a registry whose keeper went reads null (CE2-M2).
    registry_edge: @import("dom").custom_elements.RegistryAssociation = .{},

    /// Fullscreen element (from DocumentOrShadowRoot mixin)
    fullscreen_element: ?*runtime.Instance,

    /// Active element (from DocumentOrShadowRoot mixin)
    active_element: ?*runtime.Instance,

    /// Picture-in-picture element (from DocumentOrShadowRoot mixin)
    picture_in_picture_element: ?*runtime.Instance,

    /// Pointer lock element (from DocumentOrShadowRoot mixin)
    pointer_lock_element: ?*runtime.Instance,

    /// StyleSheetList (from DocumentOrShadowRoot mixin), and its keeping:
    /// see same_object.KeptChild.
    style_sheets: ?*runtime.Instance,
    style_sheets_kept: @import("same_object.zig").KeptChild = .{},

    /// Adopted style sheets (CSSOM 6.2.3): the view of the
    /// ObservableArray<CSSStyleSheet>'s backing list the style engine reads
    /// (dom.style.adopted); the array itself the shadow root keeps as a
    /// traced value of its wrapper.
    adopted_style_sheets: @import("dom").style.adopted.AdoptedSheets,

    /// domindex1: this tree scope's map from IDs to its elements
    /// (dom.tree_ordered_map): what getElementById answers from.
    tree_index: @import("dom").tree_ordered_map.Maps,

    /// CSS Shadow1 §4.2: assigned by its node document after construction.
    tree_scope_serial: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .shadow_mode = ._open_,
            .delegates_focus_flag = false,
            .slot_assignment_mode = ._named_,
            .clonable_flag = false,
            .serializable_flag = false,
            .available_to_element_internals = false,
            .declarative_flag = false,
            .keep_custom_element_registry_null = false,
            .host = null,
            .fullscreen_element = null,
            .active_element = null,
            .picture_in_picture_element = null,
            .pointer_lock_element = null,
            .style_sheets = null,
            .adopted_style_sheets = @import("dom").style.adopted.AdoptedSheets.init(allocator),
            .tree_index = @import("dom").tree_ordered_map.Maps.init(allocator, .shadow_root),
        };
    }

    /// What the state owns, without its shadow root (dom.orphan_states):
    /// its holds of its adopted style sheets' records - plain memory, let go
    /// at a sweep too. The registry association is the root's to end
    /// (`deinitOwn`).
    pub fn deinit(self: *InternalState) void {
        self.adopted_style_sheets.deinit();
        // Plain memory too, and it keeps nothing after (domindex1).
        self.tree_index.deinit();
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = runtime.InstanceRegistry(.shadow_root, InternalState);

/// This shadow root's state, or null once it has been torn down. Every member
/// then answers InvalidStateError rather than read freed state.
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// dom.tree_ordered_map (domindex1): `instance`'s maps, or null for a
/// DocumentFragment that is no ShadowRoot.
fn treeIndexOf(instance: *runtime.Instance) ?*@import("dom").tree_ordered_map.Maps {
    if (instance.stateAs(ShadowRoot.State) == null) return null;
    const internal = getInternal(instance) orelse return null;
    return &internal.tree_index;
}

/// dom.shadow_hosts: `instance`'s host is being torn down (Element.deinit).
/// The shadow root forgets it and stays a working DocumentFragment; see
/// `get_host` for when that can happen.
fn hostDestroyed(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.host = null;
}

/// Public function to get internal state (for other impls that need it)
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    @import("dom").custom_elements.installShadow(.{
        .set_registry = &setCustomElementRegistry,
        .create = &createForHost,
        .clone_flags = &cloneFlags,
        .available_to_internals = &isAvailableToElementInternals,
        .keeps_registry_null = &keepsRegistryNull,
    });
    // A host's teardown reaches its shadow root through this hook.
    @import("dom").shadow_hosts.install(.{ .host_destroyed = &hostDestroyed, .scope_serial = &treeScopeSerial });
    @import("dom").adopting_steps.install(&adoptingSteps);
    // domindex1: its tree scope's ID map.
    @import("dom").tree_ordered_map.installShadowRoot(&treeIndexOf);
    // A host removed from its tree while script held no wrapper of it is an
    // orphan nothing deinits, and so is its shadow root: the states no
    // deinit reached, at their Browser's end (dom.orphan_states).
    @import("dom").orphan_states.installRegistrySweep(Registry);
    // The style engine reads the shadow root's adopted style sheets.
    @import("dom").style.hooks.install(.{ .shadow_root_adopted_sheets = &adoptedSheetsOf });
    // The HTML parser's declarative shadow roots, and DOM attach-a-shadow-root
    // step 4's reuse of one, read and set flags no IDL member reaches.
    @import("dom").declarative_shadow.install(.{
        .mark_declarative = &markDeclarative,
        .is_declarative = &isDeclarative,
        .set_declarative = &setDeclarative,
    });
}

/// HTML "in head", template start tag, steps 7.11.4-7.11.7: the parser's
/// root is available to element internals and declarative; a
/// shadowrootcustomelementregistry attribute keeps its registry null.
fn markDeclarative(instance: *runtime.Instance, keep_registry_null: bool) void {
    const internal = getInternal(instance) orelse return;
    internal.available_to_element_internals = true;
    internal.declarative_flag = true;
    if (keep_registry_null) internal.keep_custom_element_registry_null = true;
}

/// ShadowRoot's own construction steps: the generated chain runs
/// DocumentFragment's first (and so Node's, whose node type for a shadow root
/// is DOCUMENT_FRAGMENT_NODE: it is a DocumentFragment).
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    // Its state: a block of the Browser's arena the registry owns, so the
    // registry's `remove` returns it and an orphaned root's goes with the
    // arena. A block of its own (`set`) had no exit for an orphaned host's
    // root (lane orphanleak).
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = InternalState.init(allocator);
}

/// ShadowRoot's own teardown: the generated chain runs DocumentFragment's
/// after it - what it is as a DocumentFragment: its Node state, its whole
/// subtree (its children have a parent, so the wrapper cache never frees
/// them - only that walk does) and its EventTarget state.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Get internal state from registry (where it was stored in init)
    if (Registry.get(instance)) |internal| {
        if (internal.style_sheets) |ss| internal.style_sheets_kept.releaseOwned(ss);
        internal.style_sheets = null;
        internal.registry_edge.release(instance);
        internal.deinit();
    }
    // Returns the block to the arena.
    Registry.remove(instance);
}

fn setCustomElementRegistry(instance: *runtime.Instance, registry: ?*runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const document = try interfaces.Node.get_ownerDocument(instance);
    if (registry) |value| if (document) |owner| {
        try @import("dom").custom_elements.associateDocument(value, owner);
    };
    // CE2-S2: the document keeps its own global registry; only another one is
    // traced from the shadow root.
    const document_registry = if (document) |owner| try interfaces.Document.get_customElementRegistry(owner) else null;
    internal.registry_edge.setForNode(instance, registry, document_registry);
}

fn createForHost(host: *runtime.Instance, options: dictionaries.ShadowRootInit, registry: ?*runtime.Instance) !*runtime.Instance {
    const shadow = try create(host.ctx.allocator, host.ctx, host, options.mode, options.delegatesFocus orelse false, options.slotAssignment orelse ._named_, options.clonable orelse false, options.serializable orelse false);
    errdefer @import("dom").node_creation.destroyUninserted(shadow);
    // Attach-a-shadow-root steps 9 and 14.
    const state = @import("dom").custom_elements.get(host);
    setAvailableToElementInternals(shadow, if (state) |value| value.state == .precustomized or value.state == .custom else false);
    try setCustomElementRegistry(shadow, registry);
    return shadow;
}

fn cloneFlags(source: *runtime.Instance, copy: *runtime.Instance) void {
    const from = getInternal(source) orelse return;
    const to = getInternal(copy) orelse return;
    to.declarative_flag = from.declarative_flag;
    to.keep_custom_element_registry_null = from.keep_custom_element_registry_null;
    // DOM clone step 6 omits this flag. Blink Element::Clone and WebKit
    // ShadowRoot::cloneNodeInternal preserve it; both pass the scoped-registry
    // upgrade WPT 5/5 (Firefox does not ship scoped registries). Follow that
    // browser behavior: there is no newer spec step to implement instead.
    to.available_to_element_internals = from.available_to_element_internals;
}

fn keepsRegistryNull(instance: *runtime.Instance) bool {
    return (getInternal(instance) orelse return false).keep_custom_element_registry_null;
}

// ============================================================================
// Factory function for creating ShadowRoots
// ============================================================================

/// Create a new ShadowRoot attached to a host element
/// Called by Element.attachShadow()
pub fn create(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    host: *runtime.Instance,
    mode: enums.ShadowRootMode,
    delegates_focus: bool,
    slot_assignment: enums.SlotAssignmentMode,
    clonable: bool,
    serializable: bool,
) !*runtime.Instance {
    const instance = try ShadowRoot.init(allocator, ctx);
    errdefer ShadowRoot.deinit(instance);

    // DOM attach-a-shadow-root step 5: create with the host's node document.
    // For an element, ownerDocument is its node document.
    const document = try interfaces.Node.get_ownerDocument(host);
    try @import("dom").node_document.set(instance, document);

    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (document) |owner| internal.tree_scope_serial = @import("dom").tree_scope.nextForDocument(owner);
    internal.host = host;
    internal.shadow_mode = mode;
    internal.delegates_focus_flag = delegates_focus;
    internal.slot_assignment_mode = slot_assignment;
    internal.clonable_flag = clonable;
    internal.serializable_flag = serializable;

    return instance;
}

// ============================================================================
// ShadowRoot own attributes
// ============================================================================

/// DOM §4.8.1 - ShadowRoot.mode
/// Returns the mode of this shadow root ("open" or "closed").
pub fn get_mode(instance: *runtime.Instance) anyerror!enums.ShadowRootMode {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.shadow_mode;
}

/// DOM §4.8.1 - ShadowRoot.delegatesFocus
/// Returns whether focus is delegated to the first focusable element.
pub fn get_delegatesFocus(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.delegates_focus_flag;
}

/// DOM §4.8.1 - ShadowRoot.slotAssignment
/// Returns how slottables are assigned to slots ("manual" or "named").
pub fn get_slotAssignment(instance: *runtime.Instance) anyerror!enums.SlotAssignmentMode {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.slot_assignment_mode;
}

/// DOM §4.8.1 - ShadowRoot.clonable
/// Returns whether this shadow root can be cloned.
pub fn get_clonable(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.clonable_flag;
}

/// DOM §4.8.1 - ShadowRoot.serializable
/// Returns whether this shadow root can be serialized.
pub fn get_serializable(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.serializable_flag;
}

/// DOM §4.8.1 - ShadowRoot.host
/// "The host getter steps are to return this's host."
///
/// The shadow root keeps its host: an edge from its wrapper to the host's
/// (Element.attachShadow), so script that holds only the shadow root still
/// reaches its host after a collection. Stated deviation, narrower than it
/// was: a host freed by something other than the collector - its tree's
/// teardown, when a detached ancestor of it is collected (a node does not
/// keep its tree root), or its realm's end - is forgotten (dom.shadow_hosts),
/// and this answers InvalidStateError, never a pointer to freed memory.
pub fn get_host(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.host orelse return error.InvalidStateError;
}

// ============================================================================
// InnerHTML mixin
// ============================================================================

/// InnerHTML.innerHTML getter
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-shadowroot-innerhtml
/// "Return the result of running fragment serializing algorithm steps with
/// this and true."
pub fn get_innerHTML(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    return @import("html").serialization.fragment(instance, true);
}

/// InnerHTML.innerHTML setter
pub fn set_innerHTML(instance: *runtime.Instance, value: typedefs.TrustedHTMLOrDOMString) anyerror!void {
    // Step 1: "Let compliantString be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, this's relevant
    // global object, the given value, "ShadowRoot innerHTML", and "script"."
    const allocator = instance.ctx.allocator;
    const compliant = try @import("dom").trusted_types.compliantStringFor(allocator, .html, instance, value, "ShadowRoot innerHTML");
    defer allocator.free(compliant);
    // Steps 2–3: parse with this registry and the host's tokenizer context,
    // then replace all as a single DOM mutation.
    const dom = @import("dom");
    const fragment = try @import("html").custom_elements.parseFragment(instance, compliant);
    defer dom.node_creation.destroyUninserted(fragment);
    const fragment_base = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
    const shadow_base = dom.instance_bridge.getNodeBase(instance) orelse return error.InvalidStateError;
    try dom.mutation.replaceAll(@as(?*dom.NodeBase, fragment_base), shadow_base);
}

// ============================================================================
// DocumentOrShadowRoot mixin attributes
// ============================================================================

/// DocumentOrShadowRoot.customElementRegistry getter
/// Returns null if no custom element registry is associated
pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.registry_edge.get();
}

/// DocumentOrShadowRoot.fullscreenElement getter
/// Returns the element in this shadow tree that is currently in fullscreen mode, or null.
pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.fullscreen_element;
}

/// DocumentOrShadowRoot.pictureInPictureElement getter
/// Returns the element in this shadow tree that is currently in picture-in-picture mode, or null.
pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.picture_in_picture_element;
}

/// DocumentOrShadowRoot.pointerLockElement getter
/// Returns the element in this shadow tree that has pointer lock, or null.
pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.pointer_lock_element;
}

/// DocumentOrShadowRoot.styleSheets getter: "a StyleSheetList collection
/// representing the document or shadow root CSS style sheets" (CSSOM
/// 6.2.3) - the list reads the style engine live; made on first access and
/// kept as long as the shadow root (same_object.KeptChild).
pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const sheets = internal.style_sheets orelse blk: {
        const made = interfaces.StyleSheetList.initWith(internal.allocator, instance.ctx, .{ .sheets_of = instance }) catch return error.OutOfMemory;
        internal.style_sheets = made;
        internal.style_sheets_kept.made(made);
        break :blk made;
    };
    internal.style_sheets_kept.handOut(instance, sheets, .{ .name = "styleSheets" });
    return sheets;
}

/// DocumentOrShadowRoot.adoptedStyleSheets getter: the shadow root's
/// ObservableArray<CSSStyleSheet>, made on first read (dom.style.adopted).
pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    return @import("dom").style.adopted.get(instance);
}

/// DocumentOrShadowRoot.adoptedStyleSheets setter: the value converted to
/// sequence<CSSStyleSheet>, then the backing list replaced
/// (dom.style.adopted).
pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    try @import("dom").style.adopted.set(instance, value);
}

/// dom.style's `shadow_root_adopted_sheets`.
fn adoptedSheetsOf(instance: *runtime.Instance) ?*@import("dom").style.adopted.AdoptedSheets {
    const internal = getInternal(instance) orelse return null;
    return &internal.adopted_style_sheets;
}

/// HTML DocumentOrShadowRoot.activeElement steps 1–7: the document's
/// focused area, retargeted into this tree (also used by Document).
pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    return @import("html").focus.activeElement(instance);
}

// ============================================================================
// Operations
// ============================================================================

/// getHTML(options) - Serialize shadow tree to HTML
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-shadowroot-gethtml
/// "Return the result of HTML fragment serialization algorithm with this,
/// options["serializableShadowRoots"], and options["shadowRoots"]."
pub fn call_getHTML(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetHTMLOptions)) anyerror!runtime.DOMString {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    const given = options.getOrDefault(.{});
    return @import("html").serialization.fragmentWithShadowRoots(instance, given.serializableShadowRoots orelse false, given.shadowRoots orelse &.{});
}

/// HTML 8.5.2 setHTML: safe filtering with this root's host as context.
pub fn call_setHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!void {
    var converted = try @import("html").sanitizer.convertOptions(instance.ctx, options.getOrDefault(.{}).sanitizer, true);
    defer converted.deinit();
    try @import("html").sanitizer.setHTML(instance, instance, html.asSlice(), &converted, true, true);
}

/// HTML 8.5.2 setHTMLUnsafe, steps 1–2.
pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString, options: webidl.Opt(dictionaries.SetHTMLUnsafeOptions)) anyerror!void {
    var converted = try @import("html").sanitizer.convertOptions(instance.ctx, options.getOrDefault(.{}).sanitizer, false);
    defer converted.deinit();
    // Step 1: "Let compliantHTML be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, this's relevant
    // global object, html, "ShadowRoot setHTMLUnsafe", and "script"."
    const allocator = instance.ctx.allocator;
    const compliant = try @import("dom").trusted_types.compliantStringFor(allocator, .html, instance, html, "ShadowRoot setHTMLUnsafe");
    defer allocator.free(compliant);
    // Step 2: configure, parse, sanitize, and replace the shadow children.
    try @import("html").sanitizer.setHTML(instance, instance, compliant, &converted, false, options.getOrDefault(.{}).sanitizer != null);
}

/// getAnimations() - Get all animations in shadow tree
pub fn call_getAnimations(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // TODO: Implement animation collection - return proper V8 Array
    _ = instance;
    return runtime.JSValue.jsUndefined;
}

// ============================================================================
// Internal methods
// ============================================================================

/// Get the mode as an enum value
pub fn getMode(instance: *runtime.Instance) enums.ShadowRootMode {
    const internal = getInternal(instance) orelse return ._closed_;
    return internal.shadow_mode;
}

/// Get the slot assignment mode as an enum value
pub fn getSlotAssignmentMode(instance: *runtime.Instance) enums.SlotAssignmentMode {
    const internal = getInternal(instance) orelse return ._named_;
    return internal.slot_assignment_mode;
}

/// Check if this shadow root is available to element internals
pub fn isAvailableToElementInternals(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.available_to_element_internals;
}

/// Check if this shadow root is declarative
pub fn isDeclarative(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.declarative_flag;
}

/// Set available to element internals
pub fn setAvailableToElementInternals(instance: *runtime.Instance, value: bool) void {
    const internal = getInternal(instance) orelse return;
    internal.available_to_element_internals = value;
}

/// Set declarative flag
pub fn setDeclarative(instance: *runtime.Instance, value: bool) void {
    const internal = getInternal(instance) orelse return;
    internal.declarative_flag = value;
}

fn treeScopeSerial(root: *runtime.Instance) u64 {
    if (root.stateAs(ShadowRoot.State) == null) return 0;
    return (getInternal(root) orelse return 0).tree_scope_serial;
}

/// DOM adopt §4.5 runs the adopting steps on every shadow-including element
/// after changing node documents. Each host assigns its own root's new ID;
/// nested hosts receive this callback too. Same-document adoption skips it.
fn adoptingSteps(host: *runtime.Instance, old_document: ?*runtime.Instance) void {
    const shadow = @import("dom").shadow_hosts.rootForHost(host) orelse return;
    const internal = getInternal(shadow) orelse return;
    const document = (interfaces.Node.get_ownerDocument(shadow) catch return) orelse return;
    if (old_document == document) return;
    internal.tree_scope_serial = @import("dom").tree_scope.nextForDocument(document);
}

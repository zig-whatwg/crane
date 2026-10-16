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

    /// StyleSheetList (from DocumentOrShadowRoot mixin)
    style_sheets: ?*runtime.Instance,

    /// Adopted style sheets (from DocumentOrShadowRoot mixin): the value it
    /// was last set to, HELD by the shadow root (engine.retainValue) and
    /// released when it is set again and at deinit. The setter's argument is
    /// the binding's - its handle, or its string bytes, freed when the setter
    /// returns - so it is never stored as it came.
    /// TODO: Proper ObservableArray<CSSStyleSheet> support
    adopted_style_sheets: ?engine.Owned = null,

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
            .adopted_style_sheets = null,
        };
    }

    /// What the state owns, without its shadow root (dom.orphan_states):
    /// its hold of the adopted style sheets' value - released while the
    /// agent lives, at a sweep too (EventTarget's sweep releases listeners
    /// the same way). The registry association is the root's to end
    /// (`deinitOwn`).
    pub fn deinit(self: *InternalState) void {
        if (self.adopted_style_sheets) |sheets| sheets.release();
        self.adopted_style_sheets = null;
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
    @import("dom").shadow_hosts.install(.{ .host_destroyed = &hostDestroyed });
    // A host removed from its tree while script held no wrapper of it is an
    // orphan nothing deinits, and so is its shadow root: the states no
    // deinit reached, at their Browser's end (dom.orphan_states).
    @import("dom").orphan_states.installRegistrySweep(Registry);
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
    try @import("dom").node_document.set(instance, try interfaces.Node.get_ownerDocument(host));

    const internal = getInternal(instance) orelse return error.InvalidStateError;
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

/// DocumentOrShadowRoot.styleSheets getter
/// Returns the StyleSheetList of stylesheets associated with this shadow root.
/// Lazily creates an empty StyleSheetList on first access.
pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.style_sheets) |sheets| {
        return sheets;
    }
    // Lazily create an empty StyleSheetList
    const StyleSheetList = interfaces.StyleSheetList;
    const sheets = StyleSheetList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    internal.style_sheets = sheets;
    return sheets;
}

/// DocumentOrShadowRoot.adoptedStyleSheets getter
pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.adopted_style_sheets) |sheets| {
        // The shadow root keeps its hold; the result is a hold of the
        // binding's own.
        return (try engine.retainValue(instance.ctx, sheets.value)).take();
    }
    // Return undefined if not set
    // TODO: Return empty V8 Array - need V8 array creation utility
    return runtime.JSValue.jsUndefined;
}

/// DocumentOrShadowRoot.adoptedStyleSheets setter
pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // The argument is the binding's, borrowed for this call: the shadow root
    // keeps a hold of its own, and lets go of the value it held before.
    const held = try engine.retainValue(instance.ctx, value);
    if (internal.adopted_style_sheets) |old| old.release();
    internal.adopted_style_sheets = held;
}

/// DocumentOrShadowRoot.activeElement getter
/// Returns the deepest element in this shadow tree that has focus, or null.
pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.active_element;
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

/// setHTMLUnsafe(html) - Parse and replace shadow tree contents
pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString) anyerror!void {
    // Step 1: "Let compliantHTML be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, this's relevant
    // global object, html, "ShadowRoot setHTMLUnsafe", and "script"."
    const allocator = instance.ctx.allocator;
    const compliant = try @import("dom").trusted_types.compliantStringFor(allocator, .html, instance, html, "ShadowRoot setHTMLUnsafe");
    defer allocator.free(compliant);
    // Step 2: "set and filter HTML" given this, compliantHTML and false: the
    // context is this's host; no sanitizer (the IDL has no options); the
    // HTML fragment parsing algorithm with allowDeclarativeShadowRoots true;
    // then "replace all with fragment within this".
    const dom = @import("dom");
    const fragment = try @import("html").custom_elements.parseFragmentUnsafe(instance, compliant);
    defer dom.node_creation.destroyUninserted(fragment);
    const fragment_base = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
    const shadow_base = dom.instance_bridge.getNodeBase(instance) orelse return error.InvalidStateError;
    try dom.mutation.replaceAll(@as(?*dom.NodeBase, fragment_base), shadow_base);
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

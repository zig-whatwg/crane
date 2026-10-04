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

    /// Event handler for slotchange event
    /// Stored as runtime.JSValue with global handle scope for persistence
    onslotchange: ?runtime.JSValue = null,

    /// Custom element registry (from DocumentOrShadowRoot mixin)
    custom_element_registry: ?*runtime.Instance,

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
            .onslotchange = null,
            .custom_element_registry = null,
            .fullscreen_element = null,
            .active_element = null,
            .picture_in_picture_element = null,
            .pointer_lock_element = null,
            .style_sheets = null,
            .adopted_style_sheets = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Dispose JSValue handles that may contain global handles
        if (self.onslotchange) |*handler| {
            handler.deinit(self.allocator);
        }
        self.onslotchange = null;

        if (self.adopted_style_sheets) |sheets| sheets.release();
        self.adopted_style_sheets = null;
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

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
    // A host's teardown reaches its shadow root through this hook.
    @import("dom").shadow_hosts.install(.{ .host_destroyed = &hostDestroyed });
}

/// Initialize instance (creates the instance)
/// Chains to DocumentFragmentImpl.init() to properly initialize the inheritance chain.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const DocumentFragmentImpl = @import("DocumentFragment.zig");
    const NodeImpl = @import("Node.zig");

    // Chain to DocumentFragment's init which chains to Node which chains to EventTarget
    // This properly initializes the entire inheritance chain using registries
    const instance = try DocumentFragmentImpl.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Set the node type for ShadowRoot (same as DocumentFragment per spec)
    if (NodeImpl.getInternalState(instance)) |node_internal| {
        node_internal.node_type = NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE;
    }

    // Initialize ShadowRoot's own internal state and register it
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator);
    try Registry.set(instance, internal);

    return instance;
}

/// Get the Node internal state from a ShadowRoot instance
pub fn getNodeInternal(instance: *runtime.Instance) ?*@import("Node.zig").InternalState {
    const NodeImpl = @import("Node.zig");
    return NodeImpl.getInternalState(instance);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Get internal state from registry (where it was stored in init)
    if (Registry.get(instance)) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    Registry.remove(instance);
    // Then what it is as a DocumentFragment: its Node state, its whole
    // subtree (its children have a parent, so the wrapper cache never frees
    // them - only this walk does) and its EventTarget state. This deinit
    // stopped at its own state before, and every shadow root left all of
    // that behind. Node.deinit's lifecycle guard makes a second call a no-op.
    interfaces.DocumentFragment.deinit(instance);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
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
    const instance = try init(allocator, State, &ShadowRoot.vtable, ctx);
    errdefer deinit(instance);

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
// Event Handlers
// ============================================================================

/// DOM §4.8.1 - ShadowRoot.onslotchange getter
/// Event handler for the slotchange event.
pub fn get_onslotchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.onslotchange) |handler| {
        _ = handler;
        // TODO: Convert to proper EventHandler typedef
    }
    return null;
}

/// DOM §4.8.1 - ShadowRoot.onslotchange setter
pub fn set_onslotchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // TODO: Proper event handler storage
    _ = value;
    internal.onslotchange = null;
}

// ============================================================================
// InnerHTML mixin
// ============================================================================

/// InnerHTML.innerHTML getter
pub fn get_innerHTML(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // TODO: Implement HTML serialization
    _ = instance;
    // Return empty string
    return runtime.DOMString.initEmpty();
}

/// InnerHTML.innerHTML setter
pub fn set_innerHTML(instance: *runtime.Instance, value: typedefs.TrustedHTMLOrDOMString) anyerror!void {
    // Step 1: "Let compliantString be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, this's relevant
    // global object, the given value, "ShadowRoot innerHTML", and "script"."
    const allocator = instance.ctx.allocator;
    const compliant = try @import("dom").trusted_types.compliantStringFor(allocator, .html, instance, value, "ShadowRoot innerHTML");
    defer allocator.free(compliant);
    // TODO: steps 2-3 - the fragment parsing algorithm with this's host as
    // the context, then replace all within this.
    return error.NotImplemented;
}

// ============================================================================
// DocumentOrShadowRoot mixin attributes
// ============================================================================

/// DocumentOrShadowRoot.customElementRegistry getter
/// Returns null if no custom element registry is associated
pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.custom_element_registry;
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
pub fn call_getHTML(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetHTMLOptions)) anyerror!runtime.DOMString {
    // TODO: Implement HTML serialization with options
    _ = instance;
    _ = options;
    return runtime.DOMString.initEmpty();
}

/// setHTMLUnsafe(html) - Parse and replace shadow tree contents
pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString) anyerror!void {
    // Step 1: "Let compliantHTML be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, this's relevant
    // global object, html, "ShadowRoot setHTMLUnsafe", and "script"."
    const allocator = instance.ctx.allocator;
    const compliant = try @import("dom").trusted_types.compliantStringFor(allocator, .html, instance, html, "ShadowRoot setHTMLUnsafe");
    defer allocator.free(compliant);
    // TODO: step 2 - set and filter HTML with declarative shadow roots.
    return error.NotImplemented;
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

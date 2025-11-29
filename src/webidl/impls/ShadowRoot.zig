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
    onslotchange: ?*anyopaque,

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

    /// Adopted style sheets (from DocumentOrShadowRoot mixin)
    /// TODO: Proper FrozenArray<CSSStyleSheet> support
    adopted_style_sheets: ?*anyopaque,

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
        // No cleanup needed - we don't own the referenced elements
        _ = self;
    }
};

/// Helper to access internal state from instance
fn getInternal(instance: *runtime.Instance) *InternalState {
    const state = instance.getState(State);
    return @ptrCast(@alignCast(state.own._internal));
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

    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const NodeImpl = @import("Node.zig");
    const DocumentFragmentImpl = @import("DocumentFragment.zig");

    // Initialize Node's internal state (ShadowRoot → DocumentFragment → Node)
    // With embedded inheritance: state.base = DocumentFragment.State, state.base.base = Node.State
    const node_internal = try ArenaAllocator.get().create(NodeImpl.InternalState);
    node_internal.* = NodeImpl.InternalState.init(allocator);
    node_internal.node_type = NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE;
    state.base.base.own._internal = node_internal;

    // Initialize DocumentFragment's internal state
    const df_internal = try ArenaAllocator.get().create(DocumentFragmentImpl.InternalState);
    df_internal.* = DocumentFragmentImpl.InternalState.init(allocator);
    state.base.own._internal = df_internal;

    // Initialize ShadowRoot's own internal state
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    return instance;
}

/// Get the Node internal state from a ShadowRoot instance
/// With embedded inheritance: state.base.base = Node.State
pub fn getNodeInternal(instance: *runtime.Instance) ?*@import("Node.zig").InternalState {
    const state = instance.getState(State);
    return state.base.base.own._internal;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal_ptr| {
        const internal: *InternalState = @ptrCast(@alignCast(internal_ptr));
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    runtime.Instance.deinit(instance);
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

    const internal = getInternal(instance);
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
    const internal = getInternal(instance);
    return internal.shadow_mode;
}

/// DOM §4.8.1 - ShadowRoot.delegatesFocus
/// Returns whether focus is delegated to the first focusable element.
pub fn get_delegatesFocus(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance);
    return internal.delegates_focus_flag;
}

/// DOM §4.8.1 - ShadowRoot.slotAssignment
/// Returns how slottables are assigned to slots ("manual" or "named").
pub fn get_slotAssignment(instance: *runtime.Instance) anyerror!enums.SlotAssignmentMode {
    const internal = getInternal(instance);
    return internal.slot_assignment_mode;
}

/// DOM §4.8.1 - ShadowRoot.clonable
/// Returns whether this shadow root can be cloned.
pub fn get_clonable(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance);
    return internal.clonable_flag;
}

/// DOM §4.8.1 - ShadowRoot.serializable
/// Returns whether this shadow root can be serialized.
pub fn get_serializable(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance);
    return internal.serializable_flag;
}

/// DOM §4.8.1 - ShadowRoot.host
/// Returns the element that hosts this shadow root.
pub fn get_host(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
    return internal.host orelse return error.NotImplemented;
}

// ============================================================================
// Event Handlers
// ============================================================================

/// DOM §4.8.1 - ShadowRoot.onslotchange getter
/// Event handler for the slotchange event.
pub fn get_onslotchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance);
    if (internal.onslotchange) |handler| {
        _ = handler;
        // TODO: Convert to proper EventHandler typedef
    }
    return null;
}

/// DOM §4.8.1 - ShadowRoot.onslotchange setter
pub fn set_onslotchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance);
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
pub fn set_innerHTML(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    // TODO: Implement HTML parsing and fragment replacement
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

// ============================================================================
// DocumentOrShadowRoot mixin attributes
// ============================================================================

/// DocumentOrShadowRoot.customElementRegistry getter
/// Returns null if no custom element registry is associated
pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance);
    return internal.custom_element_registry;
}

/// DocumentOrShadowRoot.fullscreenElement getter
/// Returns the element in this shadow tree that is currently in fullscreen mode, or null.
pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance);
    return internal.fullscreen_element;
}

/// DocumentOrShadowRoot.pictureInPictureElement getter
/// Returns the element in this shadow tree that is currently in picture-in-picture mode, or null.
pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance);
    return internal.picture_in_picture_element;
}

/// DocumentOrShadowRoot.pointerLockElement getter
/// Returns the element in this shadow tree that has pointer lock, or null.
pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance);
    return internal.pointer_lock_element;
}

/// DocumentOrShadowRoot.styleSheets getter
/// Returns the StyleSheetList of stylesheets associated with this shadow root.
/// Lazily creates an empty StyleSheetList on first access.
pub fn get_styleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance);
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
pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!*const anyopaque {
    const internal = getInternal(instance);
    if (internal.adopted_style_sheets) |sheets| {
        return sheets;
    }
    // Return empty pointer for null
    const empty: []const *runtime.Instance = &[_]*runtime.Instance{};
    return @ptrCast(empty.ptr);
}

/// DocumentOrShadowRoot.adoptedStyleSheets setter
pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
    const internal = getInternal(instance);
    // TODO: Proper FrozenArray<CSSStyleSheet> handling
    internal.adopted_style_sheets = @constCast(value);
}

/// DocumentOrShadowRoot.activeElement getter
/// Returns the deepest element in this shadow tree that has focus, or null.
pub fn get_activeElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance);
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
pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: runtime.DOMString) anyerror!void {
    // TODO: Implement unsafe HTML parsing
    _ = instance;
    _ = html;
    return error.NotImplemented;
}

/// getAnimations() - Get all animations in shadow tree
pub fn call_getAnimations(instance: *runtime.Instance) anyerror!*const anyopaque {
    // TODO: Implement animation collection
    _ = instance;
    // Return empty array as opaque pointer
    const empty: []const *runtime.Instance = &[_]*runtime.Instance{};
    return @ptrCast(empty.ptr);
}

// ============================================================================
// Internal methods
// ============================================================================

/// Get the mode as an enum value
pub fn getMode(instance: *runtime.Instance) enums.ShadowRootMode {
    const internal = getInternal(instance);
    return internal.shadow_mode;
}

/// Get the slot assignment mode as an enum value
pub fn getSlotAssignmentMode(instance: *runtime.Instance) enums.SlotAssignmentMode {
    const internal = getInternal(instance);
    return internal.slot_assignment_mode;
}

/// Check if this shadow root is available to element internals
pub fn isAvailableToElementInternals(instance: *runtime.Instance) bool {
    const internal = getInternal(instance);
    return internal.available_to_element_internals;
}

/// Check if this shadow root is declarative
pub fn isDeclarative(instance: *runtime.Instance) bool {
    const internal = getInternal(instance);
    return internal.declarative_flag;
}

/// Set available to element internals
pub fn setAvailableToElementInternals(instance: *runtime.Instance, value: bool) void {
    const internal = getInternal(instance);
    internal.available_to_element_internals = value;
}

/// Set declarative flag
pub fn setDeclarative(instance: *runtime.Instance, value: bool) void {
    const internal = getInternal(instance);
    internal.declarative_flag = value;
}

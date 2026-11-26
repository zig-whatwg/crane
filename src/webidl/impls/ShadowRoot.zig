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
    /// Kept by value in this interface's own State (runtime.OwnState, the
    /// State's `_embedded`; lane perf2 batch 5, Z7): a node is one block.
    pub const embedded_in_state = true;

    // No allocator copy (lane perf2 batch 7): its one reader makes the
    // StyleSheetList with the root's Browser's allocator
    // (runtime.allocatorOf), the allocator the root was made with (asserted
    // in Node's initOwn) - 16 bytes on every shadow root.

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

    // No fullscreen, active, Picture-in-Picture or pointer lock element of
    // its own (lane perf2 batch 8: 32 B a shadow root, never set): each getter
    // retargets its node document's element against this
    // (dom.designated_elements; activeElement, the focused area's anchor,
    // html.focus).

    /// StyleSheetList (from DocumentOrShadowRoot mixin), and its keeping:
    /// see same_object.KeptChild.
    style_sheets_kept: @import("dom").same_object.KeptChild = .{},

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
            .shadow_mode = ._open_,
            .delegates_focus_flag = false,
            .slot_assignment_mode = ._named_,
            .clonable_flag = false,
            .serializable_flag = false,
            .available_to_element_internals = false,
            .declarative_flag = false,
            .keep_custom_element_registry_null = false,
            .host = null,
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

// Its internal state, in its own generated State (`own._internal`): runtime.OwnState.
const utils = @import("webidl").utils;
const Registry = runtime.OwnState(State, InternalState);

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
fn shadowHasInternal(instance: *runtime.Instance) bool {
    return getInternal(instance) != null;
}

fn shadowStyleSheets(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const sheets = internal.style_sheets_kept.get() orelse blk: {
        const made = interfaces.StyleSheetList.initWith(runtime.allocatorOf(instance), instance.ctx, .{ .sheets_of = instance }) catch return error.OutOfMemory;
        internal.style_sheets_kept.made(made);
        break :blk made;
    };
    internal.style_sheets_kept.handOut(instance, sheets, .{ .name = "styleSheets" });
    return sheets;
}

fn shadowCustomElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.registry_edge.get();
}

pub fn installHooks() void {
    @import("dom").custom_elements.installShadow(.{
        .set_registry = &setCustomElementRegistry,
        .create = &createForHost,
        .clone_flags = &cloneFlags,
        .available_to_internals = &isAvailableToElementInternals,
        .keeps_registry_null = &keepsRegistryNull,
    });
    // A host's teardown and DocumentOrShadowRoot mixin reach ShadowRoot through this hook.
    @import("dom").shadow_hosts.install(.{
        .host_destroyed = &hostDestroyed,
        .scope_serial = &treeScopeSerial,
        .style_sheets = &shadowStyleSheets,
        .custom_element_registry = &shadowCustomElementRegistry,
        .has_internal = &shadowHasInternal,
    });
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
    const internal = try Registry.create(instance);
    internal.* = InternalState.init(allocator);
}

/// ShadowRoot's own teardown: the generated chain runs DocumentFragment's
/// after it - what it is as a DocumentFragment: its Node state, its whole
/// subtree (its children have a parent, so the wrapper cache never frees
/// them - only that walk does) and its EventTarget state.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Get internal state from registry (where it was stored in init)
    if (Registry.get(instance)) |internal| {
        if (internal.style_sheets_kept.get()) |ss| internal.style_sheets_kept.releaseOwned(ss);
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
    // Step 1: "Let (compliantString, compliantOptions) be the result of
    // invoking the get trusted type compliant input algorithm with this's
    // relevant global object, the given value, a new SetHTMLUnsafeOptions
    // dictionary, "ShadowRoot innerHTML", this's node document's type, and
    // false."
    const allocator = instance.ctx.allocator;
    var compliant = try @import("html").parser_options.legacyCompliantInput(allocator, instance, @import("dom").trusted_types.inputFrom(value), "ShadowRoot innerHTML");
    defer compliant.deinit(allocator);
    // Step 2: filter and set HTML given this, compliantString,
    // compliantOptions and Legacy - parse with this registry and the host's
    // tokenizer context, then replace all as a single DOM mutation.
    const dom = @import("dom");
    const fragment = try @import("html").html_insertion.legacyParse(instance, compliant.html, if (compliant.options) |*options| options else null);
    defer dom.node_creation.destroyUninserted(fragment);
    const fragment_base = dom.instance_bridge.getNodeBase(fragment) orelse return error.InvalidStateError;
    const shadow_base = dom.instance_bridge.getNodeBase(instance) orelse return error.InvalidStateError;
    try dom.mutation.replaceAll(@as(?*dom.NodeBase, fragment_base), shadow_base);
}

// ============================================================================
// DocumentOrShadowRoot mixin attributes
// ============================================================================

/// dom.style's `shadow_root_adopted_sheets`.
fn adoptedSheetsOf(instance: *runtime.Instance) ?*@import("dom").style.adopted.AdoptedSheets {
    const internal = getInternal(instance) orelse return null;
    return &internal.adopted_style_sheets;
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

/// HTML 8.5.2 ShadowRoot's setHTML(html, options): filter and set HTML
/// given this, in Safe mode (this's host is the parser's context).
pub fn call_setHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!void {
    const insertion = @import("html").html_insertion;
    var parsed = try insertion.ParserOptions.fromDictionary(instance.ctx, options.getOrDefault(.{}).sanitizer, null);
    defer parsed.deinit();
    try insertion.containerSafe(instance, .set, html.asSlice(), &parsed);
}

/// HTML 8.5.2 ShadowRoot's appendHTML(html, options).
pub fn call_appendHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!void {
    const insertion = @import("html").html_insertion;
    var parsed = try insertion.ParserOptions.fromDictionary(instance.ctx, options.getOrDefault(.{}).sanitizer, null);
    defer parsed.deinit();
    try insertion.containerSafe(instance, .append, html.asSlice(), &parsed);
}

/// HTML 8.5.2 ShadowRoot's prependHTML(html, options).
pub fn call_prependHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!void {
    const insertion = @import("html").html_insertion;
    var parsed = try insertion.ParserOptions.fromDictionary(instance.ctx, options.getOrDefault(.{}).sanitizer, null);
    defer parsed.deinit();
    try insertion.containerSafe(instance, .prepend, html.asSlice(), &parsed);
}

/// HTML 8.5.2 ShadowRoot's setHTMLUnsafe(html, options): get trusted type
/// compliant input ("ShadowRoot setHTMLUnsafe"), then filter and set HTML
/// given this in Unsafe mode.
pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
    const insertion = @import("html").html_insertion;
    const parsed = try insertion.ParserOptions.fromUnion(instance.ctx, if (options.wasPassed()) options.getValue() else null);
    try insertion.containerUnsafe(instance, .set, @import("dom").trusted_types.inputFrom(html), parsed, "ShadowRoot setHTMLUnsafe");
}

/// HTML 8.5.2 ShadowRoot's appendHTMLUnsafe(html, options).
pub fn call_appendHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
    const insertion = @import("html").html_insertion;
    const parsed = try insertion.ParserOptions.fromUnion(instance.ctx, if (options.wasPassed()) options.getValue() else null);
    try insertion.containerUnsafe(instance, .append, @import("dom").trusted_types.inputFrom(html), parsed, "ShadowRoot appendHTMLUnsafe");
}

/// HTML 8.5.2 ShadowRoot's prependHTMLUnsafe(html, options).
pub fn call_prependHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
    const insertion = @import("html").html_insertion;
    const parsed = try insertion.ParserOptions.fromUnion(instance.ctx, if (options.wasPassed()) options.getValue() else null);
    try insertion.containerUnsafe(instance, .prepend, @import("dom").trusted_types.inputFrom(html), parsed, "ShadowRoot prependHTMLUnsafe");
}

/// HTML 8.5.3 ShadowRoot's streamHTML(options).
pub fn call_streamHTML(instance: *runtime.Instance, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!*runtime.Instance {
    return @import("html").stream_html.containerSafe(instance, .set, options.getOrDefault(.{}).sanitizer);
}

/// HTML 8.5.3 ShadowRoot's streamAppendHTML(options).
pub fn call_streamAppendHTML(instance: *runtime.Instance, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!*runtime.Instance {
    return @import("html").stream_html.containerSafe(instance, .append, options.getOrDefault(.{}).sanitizer);
}

/// HTML 8.5.3 ShadowRoot's streamPrependHTML(options).
pub fn call_streamPrependHTML(instance: *runtime.Instance, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!*runtime.Instance {
    return @import("html").stream_html.containerSafe(instance, .prepend, options.getOrDefault(.{}).sanitizer);
}

/// HTML 8.5.3 ShadowRoot's streamHTMLUnsafe(options).
pub fn call_streamHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
    const parsed = try @import("html").html_insertion.ParserOptions.fromUnion(instance.ctx, if (options.wasPassed()) options.getValue() else null);
    return @import("html").stream_html.containerUnsafe(instance, .set, parsed, "ShadowRoot streamHTMLUnsafe");
}

/// HTML 8.5.3 ShadowRoot's streamAppendHTMLUnsafe(options).
pub fn call_streamAppendHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
    const parsed = try @import("html").html_insertion.ParserOptions.fromUnion(instance.ctx, if (options.wasPassed()) options.getValue() else null);
    return @import("html").stream_html.containerUnsafe(instance, .append, parsed, "ShadowRoot streamAppendHTMLUnsafe");
}

/// HTML 8.5.3 ShadowRoot's streamPrependHTMLUnsafe(options).
pub fn call_streamPrependHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(typedefs.SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
    const parsed = try @import("html").html_insertion.ParserOptions.fromUnion(instance.ctx, if (options.wasPassed()) options.getValue() else null);
    return @import("html").stream_html.containerUnsafe(instance, .prepend, parsed, "ShadowRoot streamPrependHTMLUnsafe");
}

/// elementFromPoint(x, y) on a ShadowRoot, as Chrome, Firefox and Safari
/// expose it (specs/supplementary/ShadowRootHitTesting.idl; CSSOM View has it
/// on Document only): the node document's elementFromPoint(x, y), retargeted
/// against this shadow root (Blink TreeScope::ElementFromPoint, Gecko
/// DocumentOrShadowRoot::ElementFromPoint, WebKit TreeScope::elementFromPoint
/// retarget the hit-tested element). Hit testing is the document's, so the
/// same no-renderer answer: CSSOM View step 1's negative coordinates are
/// null, as is every point while no renderer gives a box.
pub fn call_elementFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyerror!?*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    const document = (try interfaces.Node.get_ownerDocument(instance)) orelse return null;
    const hit = try interfaces.Document.call_elementFromPoint(document, x, y);
    return @import("dom").retarget.retargetAgainst(hit, instance);
}

/// elementsFromPoint(x, y) on a ShadowRoot (see `call_elementFromPoint`):
/// the hit-tested elements of the node document, each retargeted against
/// this shadow root - none while no renderer gives a box (CSSOM View: an
/// empty sequence for a point no box covers).
pub fn call_elementsFromPoint(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    _ = x;
    _ = y;
    // OWNED, handed to the binding.
    const array = try engine.createSequenceOfValues(engine.currentRealm() orelse instance.ctx, &.{});
    return array.take();
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

// CSSOM6.2.3 / HTML4.12.3, as Blink TreeScopeAdopter::
// MoveShadowTreeToNewDocument (Chromium cc7021d31c75:154-165): preserve
// only the associated template-owner round trips, never unrelated documents.
fn preserveTemplateSheetRelation(old_document: ?*runtime.Instance, document: *runtime.Instance) bool {
    const old = old_document orelse return false;
    const templates = @import("dom").template_contents;
    return templates.existingOwnerDocument(old) == document or templates.existingOwnerDocument(document) == old;
}

/// DOM adopt §4.5 runs the adopting steps on every shadow-including element
/// after changing node documents. Each host assigns its own root's new ID;
/// nested hosts receive this callback too. Same-document adoption skips it.
fn adoptingSteps(host: *runtime.Instance, old_document: ?*runtime.Instance) void {
    const shadow = @import("dom").shadow_hosts.rootForHost(host) orelse return;
    const internal = getInternal(shadow) orelse return;
    const document = (interfaces.Node.get_ownerDocument(shadow) catch return) orelse return;
    if (old_document == document) return;
    if (!preserveTemplateSheetRelation(old_document, document)) @import("dom").style.adopted.clearExisting(shadow);
    internal.tree_scope_serial = @import("dom").tree_scope.nextForDocument(document);
}

//! Implementation for Element interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-element
//! WHATWG DOM Standard §4.8
//!
//! Element is the most general base class from which all element objects
//! (i.e. objects that represent elements) in a Document inherit. It only
//! has methods and properties common to all kinds of elements.
//!
//! Migrated from: webidl/src/dom/element.zig

const std = @import("std");
const engine = @import("engine");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const dom = @import("dom");
const same_object = @import("same_object.zig");
const Element = interfaces.Element;

// Import related impls
const DOMTokenListImpl = @import("DOMTokenList.zig");
const NamedNodeMapImpl = @import("NamedNodeMap.zig");

// Import mixins for shared interface methods
const mixins = @import("mixins");

pub const State = Element.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    NotFoundError,
    SyntaxError,
    InvalidCharacterError,
    OutOfMemory,
};

/// Static sentinel for representing "undefined" return values.
/// Used instead of @ptrFromInt(1) to provide a valid pointer that represents
/// undefined/empty results from operations that return *const anyopaque.
var undefined_sentinel: u8 = 0;

/// Custom element state per HTML spec
/// Spec: https://html.spec.whatwg.org/#custom-element-state
pub const CustomElementState = dom.custom_elements.State;

/// An attribute of the list: the type is `dom.element_data`'s, which the
/// tree reads in place (ElementData, below).
const AttributeEntry = dom.element_data.AttributeEntry;
const ElementData = dom.element_data.ElementData;

/// The slot an Attr node is kept in: one per node, named by its address - an
/// element keeps a node for each attribute script asked one for.
fn attrSlot(buffer: []u8, attr: *runtime.Instance) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "attr:{x}", .{@intFromPtr(attr)}) catch "attr" };
}

/// `element` keeps `attr`, its node for one of its attributes.
fn traceAttrNode(element: *runtime.Instance, attr: *runtime.Instance) void {
    var buffer: [48]u8 = undefined;
    engine.traceChild(element, attr, attrSlot(&buffer, attr));
}

/// `element` no longer keeps `attr`. Not from teardown: there the edge goes
/// with the element's wrapper.
fn forgetAttrNode(element: *runtime.Instance, attr: *runtime.Instance) void {
    var buffer: [48]u8 = undefined;
    engine.forgetTracedChild(element, attrSlot(&buffer, attr));
}

/// Internal state for Element implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The attribute list, the ID and classes, and the qualified name: the
    /// part the rest of the tree reads, through `dom.element_data.of`
    /// (installed below). By value: one block, one lifetime. Written only
    /// here, by "handle attribute changes" and "create an element".
    data: ElementData,

    /// The element's slot attribute value
    slot: runtime.DOMString,

    /// Shadow root attached to this element (null if not a shadow host)
    shadow_root: ?*runtime.Instance = null,
    /// `shadow_root`, kept for as long as this element's wrapper lives - "an
    /// element has an associated shadow root", and a shadow root has no
    /// parent, so nothing else keeps it - by an edge from this element's
    /// wrapper (see `same_object.KeptChild`). Severed from it in `deinit`.
    shadow_root_kept: same_object.KeptChild = .{},

    /// Custom element state per HTML spec
    custom_element_state: CustomElementState = .undefined,
    custom_element_definition: ?*dom.custom_elements.Definition = null,
    custom_element_ever_enqueued: bool = false,
    custom_element_registry: dom.custom_elements.RegistryAssociation = .{},

    /// "is" value for customized built-in elements
    is_value: ?runtime.DOMString = null,

    /// DOM 4.2.2.2: the element as a slottable - its assigned slot and its
    /// manual slot assignment, weak references the slot algorithms keep
    /// (dom.slot_helpers, dom.shadow_dom_algorithms). Its name is `slot`.
    slottable: dom.slot_helpers.SlottableState = .{},

    /// Cached NamedNodeMap for the attributes getter
    /// Per WebIDL, the same object must be returned on subsequent accesses
    /// so that own properties added to the object persist.
    named_node_map: ?*runtime.Instance = null,
    /// Slab generation of `named_node_map` when it was taken. The wrapper
    /// cache's teardown sweep can free the map before it reaches the element;
    /// the flags below do not see that, the generation does.
    named_node_map_generation: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .data = ElementData.init(allocator),
            .slot = runtime.DOMString.initEmpty(),
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.custom_element_definition) |definition| definition.deinit();
        self.slot.deinit(self.allocator);
        if (self.is_value) |*v| {
            v.deinit(self.allocator);
        }

        // Clean up cached NamedNodeMap
        // CRITICAL: Mark the NamedNodeMap via lifecycle tracking BEFORE calling deinit.
        // We use lifecycle tracking (not wrapper_cache.markInstanceCleanedUp) because
        // during wrapper_cache.deinit, the HashMap is being iterated/destroyed and
        // cannot be safely accessed. The lifecycle tracking uses a SEPARATE data
        // structure that's safe to modify during teardown.
        //
        // wrapper_cache.deinit checks isCleanupStarted() before calling gc.onObjectFreed,
        // so marking here prevents double-free of the NamedNodeMap.
        if (self.named_node_map) |nnm| {
            // The protocol above covers Element freeing the map FIRST. The other
            // order happens too: if script ever touched `el.attributes`, the map
            // was wrapped, and the wrapper cache's weak callback frees it at
            // whatever GC finds it dead - long before this exit-time sweep. It
            // marks the Instance cleaned-up and the slab reclaims the memory,
            // so `NamedNodeMap.deinit` here reads `getState` off an unmapped
            // page: SEGV in `Instance.stateAs` under
            // `InstanceRegistry(Element.InternalState).deinitAllAndClear`, which
            // is how custom-elements/connected-callbacks.html died at exit.
            //
            // The lifecycle flags are keyed on the address and never dereference
            // it, so they are safe to consult on freed memory. If the slab has
            // since reissued the address to a live object, the stale flag makes
            // this skip a deinit it should have done - a leak, and the
            // conservative side of the same trade the rest of this tree makes.
            //
            // The flags miss one order: the wrapper cache's teardown sweep freed
            // the map through onObjectFreed - state block and slab slot, no
            // flag set - before it reached this element. `getState` on that
            // poisoned block sails past every null check (0xAA is not null) and
            // the attribute list is freed a second time. The generation recorded
            // when the map was taken is what tells a freed or reissued slot from
            // the map this element still owns.
            const already_gone = runtime.instance_lifecycle.isCleanedUp(nnm) or
                runtime.instance_lifecycle.isCleanupStarted(nnm) or
                runtime.SlabAllocator.generationOf(nnm) != self.named_node_map_generation;
            if (!already_gone) {
                _ = runtime.instance_lifecycle.markCleanupStarted(nnm);
                interfaces.NamedNodeMap.deinit(nnm);
            }
            self.named_node_map = null;
        }

        // The attributes' Attr nodes go first, then the list with the names.
        var index: usize = 0;
        while (self.data.attributeAtMut(index)) |entry| : (index += 1) detachAttrNode(null, entry);
        self.data.deinit();
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = runtime.InstanceRegistry(.element, InternalState);

/// Get the internal state from an instance
/// Made public for use by Document's getElementById, getElementsByTagName, etc.
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Its states left at its Browser's end (Browser.deinit).
    @import("dom").teardown_sweeps.install(.elements, &sweepRemaining);
    // The attribute list's hook, for its ancestors' use (cloning). Installed
    // before any element can be cloned: this runs for every element.
    dom.element_attributes.install(.{
        .at = &attributeAtHook,
        .count = &attributeCountHook,
        .append = &appendAttributeHook,
        .change = &changeAttributeHook,
        .set = &setAttributeHook,
        .remove = &removeAttributeHook,
        .node_at = &attrNodeAtHook,
        .existing_node_at = &existingAttrNodeAtHook,
    });
    // The list, the ID and classes and the qualified name, read in place by
    // the tree's own algorithms (the selector matcher, getElementById, the
    // HTML elements' reflection, the CSSOM).
    dom.element_data.install(.{ .of = &dataOf });
    // The parsers' "create an element" sets names through `dom.node_creation`.
    dom.node_creation.installElement(.{ .set_names = &setNamesHook, .is_value = &isValueHook, .names = &namesHook });
    dom.shadow_hosts.install(.{ .root_for_host = &shadowRootOf });
    // An event handler content attribute's raw uncompiled handler, compiled
    // when its value is first needed (HTML 8.1.8.1).
    dom.event_handlers.installRawCompiler(&compileRawEventHandler);
    // The slot algorithms read an element's slottable state through
    // `dom.slot_helpers`.
    dom.slot_helpers.install(.{ .element_slottable = &slottableOf });
    dom.custom_elements.installElement(.{
        .get = &customElementData,
        .initialize = &initializeCustomElement,
        .set_state = &setCustomElementState,
        .set_definition = &setCustomElementDefinition,
        .shadow_root_of = &shadowRootOf,
        .mark_enqueued = &markCustomElementEnqueued,
        .set_registry = &setCustomElementRegistry,
        .attach_shadow = &attachShadow,
    });
}

fn isValueHook(instance: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;
    return if (internal.is_value) |value| value.asSlice() else null;
}

/// dom.node_creation's names: this element's namespace, prefix and local
/// name, borrowed - fixed for its life once "create an element" set them.
fn namesHook(instance: *runtime.Instance) ?dom.node_creation.ElementNames {
    const internal = getInternal(instance) orelse return null;
    return .{
        .namespace = if (internal.data.namespace_uri) |ns| ns.asSlice() else null,
        .prefix = if (internal.data.prefix) |p| p.asSlice() else null,
        .local_name = internal.data.local_name.asSlice(),
    };
}

fn shadowRootOf(instance: *runtime.Instance) ?*runtime.Instance {
    return (getInternal(instance) orelse return null).shadow_root;
}

/// `dom.slot_helpers`: the element as a slottable - its state and its name,
/// which is its slot attribute's value (DOM 4.2.2.2).
fn slottableOf(instance: *runtime.Instance) ?dom.slot_helpers.Slottable {
    const internal = getInternal(instance) orelse return null;
    return .{ .state = &internal.slottable, .name = internal.slot.asSlice() };
}

fn markCustomElementEnqueued(instance: *runtime.Instance) void {
    (getInternal(instance) orelse return).custom_element_ever_enqueued = true;
}

fn setCustomElementRegistry(instance: *runtime.Instance, registry: ?*runtime.Instance) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const document = try interfaces.Node.get_ownerDocument(instance);
    if (registry) |value| if (document) |owner| {
        try dom.custom_elements.associateDocument(value, owner);
    };
    // CE2-S2: the document keeps its own global registry; only another one is
    // traced from the element.
    const document_registry = if (document) |owner| try interfaces.Document.get_customElementRegistry(owner) else null;
    internal.custom_element_registry.setForNode(instance, registry, document_registry);
}

fn customElementData(instance: *runtime.Instance) ?dom.custom_elements.ElementData {
    const internal = getInternal(instance) orelse return null;
    return .{
        .state = internal.custom_element_state,
        .definition = internal.custom_element_definition,
        .is_value = if (internal.is_value) |value| value.asSlice() else null,
    };
}

fn initializeCustomElement(instance: *runtime.Instance, prefix: ?[]const u8, is_value: ?[]const u8, state: CustomElementState) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    var owned_is = if (is_value) |value| try runtime.DOMString.initDupe(internal.allocator, value) else null;
    errdefer if (owned_is) |*value| value.deinit(internal.allocator);
    const owned_prefix = if (prefix) |value| try runtime.DOMString.initDupe(internal.allocator, value) else null;
    if (internal.data.prefix) |*value| value.deinit(internal.allocator);
    internal.data.prefix = owned_prefix;
    if (internal.is_value) |*value| value.deinit(internal.allocator);
    internal.is_value = owned_is;
    internal.custom_element_state = state;
}

fn setCustomElementState(instance: *runtime.Instance, state: CustomElementState) void {
    const internal = getInternal(instance) orelse return;
    internal.custom_element_state = state;
}

fn setCustomElementDefinition(instance: *runtime.Instance, definition: ?*dom.custom_elements.Definition) void {
    const internal = getInternal(instance) orelse return;
    const old = internal.custom_element_definition;
    internal.custom_element_definition = if (definition) |value| value.retain() else null;
    if (old) |value| value.deinit();
}

/// Element's own construction steps: the generated chain runs Node's first.
///
/// IMPORTANT: Due to state hierarchy complexity, internal state is stored
/// in a global registry rather than in the State struct.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;

    // Initialize Element's own internal state in registry
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = InternalState.init(allocator);
}

/// Get Element's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Element's own teardown: the generated chain runs Node's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        if (internal.custom_element_ever_enqueued) dom.custom_elements.cancelElement(instance);
        internal.custom_element_registry.release(instance);
        // The host lets its shadow root go: the shadow root forgets its host
        // (dom.shadow_hosts); the host's edge to it goes with the host's
        // wrapper, so the wrapper cache frees it - and its subtree - once
        // script drops it too. Here and not in InternalState.deinit, which
        // cleanupAllRemainingInternal's exit sweep also runs, after the
        // engine is gone.
        //
        // Not torn down: a shadow root keeps its host while script holds it
        // (its edge, drawn in attachShadow), but a host can still go first -
        // a node its tree's teardown frees, or at the realm's end - and the
        // shadow root must go on working as a DocumentFragment. Its `host`
        // then answers InvalidStateError (ShadowRoot.get_host).
        if (internal.shadow_root) |shadow| {
            internal.shadow_root_kept.release(shadow, forgetHost);
            internal.shadow_root = null;
        }
        internal.deinit();
    }
    Registry.remove(instance);
}

/// `shadow`, still the shadow root this element made, loses its host.
fn forgetHost(shadow: *runtime.Instance) void {
    dom.shadow_hosts.hostDestroyed(shadow);
}

/// dom.teardown_sweeps: at its Browser's end, every Element state still in
/// `scope`'s table - an orphan's no teardown reached - frees what it owns.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    Registry.deinitAllAndClear(scope);
}

// =============================================================================
// Setters for internal state (used by Document factory methods)
// =============================================================================

/// Set the namespace URI of this element
/// Used by Document.createElementNS
pub fn setNamespaceURI(instance: *runtime.Instance, namespace: ?[]const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free existing namespace if any
    if (internal.data.namespace_uri) |*ns| {
        ns.deinit(internal.allocator);
        internal.data.namespace_uri = null;
    }

    // Set new namespace if provided
    if (namespace) |ns| {
        internal.data.namespace_uri = try runtime.DOMString.initDupe(internal.allocator, ns);
    }
}

/// Set the namespace prefix of this element
/// Used by Document.createElementNS
pub fn setPrefix(instance: *runtime.Instance, prefix: ?[]const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free existing prefix if any
    if (internal.data.prefix) |*p| {
        p.deinit(internal.allocator);
        internal.data.prefix = null;
    }

    // Set new prefix if provided
    if (prefix) |p| {
        internal.data.prefix = try runtime.DOMString.initDupe(internal.allocator, p);
    }
}

/// Set the local name of this element
/// Used by Document.createElement and Document.createElementNS
/// Uses tag name interning for common HTML elements to avoid allocation.
pub fn setLocalName(instance: *runtime.Instance, local_name: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Free existing local name
    internal.data.local_name.deinit(internal.allocator);

    // Try to use interned tag name for common HTML elements - on an exact
    // match only: a local name is case-sensitive.
    const html_core = @import("html_core");
    if (html_core.internTagNameExact(local_name)) |interned| {
        // Use interned static string - no allocation needed
        internal.data.local_name = runtime.DOMString.initInterned(interned);
    } else {
        // Fall back to allocation for custom/unknown elements
        internal.data.local_name = try runtime.DOMString.initDupe(internal.allocator, local_name);
    }
}

/// Getter for namespaceURI
/// DOM §4.8 - Returns the namespace URI of this element
pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.data.namespace_uri) |ns| {
        // Clone to transfer ownership to caller (interface layer will free)
        return try ns.clone(instance.ctx.allocator);
    }
    // DOMString?: an element in no namespace answers null, not "".
    return null;
}

/// Getter for prefix
/// DOM §4.8 - Returns the namespace prefix of this element
pub fn get_prefix(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.data.prefix) |p| {
        // Clone to transfer ownership to caller (interface layer will free)
        return try p.clone(instance.ctx.allocator);
    }
    return null;
}

/// Getter for localName
/// DOM §4.8 - Returns the local name of this element
pub fn get_localName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.data.local_name.clone(instance.ctx.allocator);
}

/// Getter for tagName
/// DOM §4.8 - Returns the qualified name of this element
/// For HTML elements in HTML documents, this is uppercase
/// Spec: https://dom.spec.whatwg.org/#dom-element-tagname
pub fn get_tagName(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // DOM 4.9 "HTML-uppercased qualified name": "If this is in the HTML
    // namespace and its node document is an HTML document, then set
    // qualifiedName to qualifiedName in ASCII uppercase." An element in no
    // namespace, or one in an XML document, keeps its name as written
    // (dom/nodes/Element-tagName.html, Document-createElement.html's XML
    // and XHTML documents).
    const HTML_NAMESPACE = "http://www.w3.org/1999/xhtml";
    const is_html_element = internal.data.namespace_uri != null and
        std.mem.eql(u8, internal.data.namespace_uri.?.asSlice(), HTML_NAMESPACE) and
        nodeDocumentIsHtml(instance);

    // If there's a prefix, return "prefix:localName"
    if (internal.data.prefix) |p| {
        const prefix_slice = p.asSlice();
        const local_slice = internal.data.local_name.asSlice();

        // Allocate buffer for "prefix:localName"
        const total_len = prefix_slice.len + 1 + local_slice.len;
        var buffer = try instance.ctx.allocator.alloc(u8, total_len);
        @memcpy(buffer[0..prefix_slice.len], prefix_slice);
        buffer[prefix_slice.len] = ':';
        @memcpy(buffer[prefix_slice.len + 1 ..], local_slice);

        // Uppercase for HTML elements in HTML documents
        if (is_html_element) {
            for (buffer) |*c| {
                c.* = std.ascii.toUpper(c.*);
            }
        }

        return runtime.DOMString.initOwned(buffer);
    }

    // No prefix, return just local name
    // Uppercase for HTML elements in HTML documents
    if (is_html_element) {
        const local_slice = internal.data.local_name.asSlice();
        var buffer = try instance.ctx.allocator.alloc(u8, local_slice.len);
        for (local_slice, 0..) |c, i| {
            buffer[i] = std.ascii.toUpper(c);
        }
        return runtime.DOMString.initOwned(buffer);
    }

    // Non-HTML element: return as-is
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.data.local_name.clone(instance.ctx.allocator);
}

/// Whether `element`'s node document is an HTML document (DOM 4.5: its type
/// is "html").
fn nodeDocumentIsHtml(element: *runtime.Instance) bool {
    const document = (interfaces.Node.get_ownerDocument(element) catch return true) orelse return true;
    return dom.document_internals.getDocumentType(document) != .xml;
}

/// Getter for id
/// DOM §4.8 - Returns the value of the id attribute
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.data.id.clone(instance.ctx.allocator);
}

/// Getter for className
/// DOM §4.8 - Returns the value of the class attribute
pub fn get_className(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.data.class_name.clone(instance.ctx.allocator);
}

/// Getter for classList
/// DOM §4.8 - Returns a DOMTokenList for the class attribute
/// Spec: https://dom.spec.whatwg.org/#dom-element-classlist
///
/// The classList getter steps are to return a DOMTokenList object whose
/// associated element is this and whose associated attribute's local name is class.
pub fn get_classList(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create a new DOMTokenList
    // Use interface instead of impl (per Golden Rule #13)
    const token_list = interfaces.DOMTokenList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.DOMTokenList.deinit(token_list);

    // Initialize with current class attribute value
    interfaces.DOMTokenList.set_value(token_list, internal.data.class_name) catch return error.OutOfMemory;

    // Associate with this element and the "class" attribute
    DOMTokenListImpl.setElement(token_list, instance, runtime.DOMString.initInterned("class"));

    return token_list;
}

/// Getter for slot
/// DOM §4.8 - Returns the value of the slot attribute
pub fn get_slot(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Clone to transfer ownership to caller (interface layer will free)
    return try internal.slot.clone(instance.ctx.allocator);
}

/// Getter for attributes
/// DOM §4.8 - Returns a NamedNodeMap of the element's attributes
/// Spec: https://dom.spec.whatwg.org/#dom-element-attributes
///
/// The attributes getter steps are to return the associated NamedNodeMap.
/// Per WebIDL semantics, returns the same cached object on each access so that
/// own properties added to the attributes object persist across accesses.
pub fn get_attributes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse {
        return error.InvalidStateError;
    };

    // Return cached NamedNodeMap if it exists
    if (internal.named_node_map) |cached| {
        return cached;
    }

    // Create a NamedNodeMap containing all attributes
    // Use interface instead of impl (per Golden Rule #13)
    const named_node_map = interfaces.NamedNodeMap.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.NamedNodeMap.deinit(named_node_map);

    // Set the owner element
    NamedNodeMapImpl.setOwnerElement(named_node_map, instance);

    // The map reads this element's list whenever it is asked - it is live -
    // so there is nothing to copy into it.

    // Cache the NamedNodeMap for future accesses, with the generation that
    // proves it is still this map at deinit.
    internal.named_node_map = named_node_map;
    internal.named_node_map_generation = runtime.SlabAllocator.generationOf(named_node_map);

    return named_node_map;
}

/// Getter for shadowRoot
/// DOM §4.8 - Returns the element's shadow root if attached and mode is "open"
/// Spec: https://dom.spec.whatwg.org/#dom-element-shadowroot
///
/// The shadowRoot getter steps are:
/// 1. Let shadow be this's shadow root.
/// 2. If shadow is null or its mode is "closed", then return null.
/// 3. Return shadow.
pub fn get_shadowRoot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: Let shadow be this's shadow root
    const shadow = internal.shadow_root orelse return null;

    // Step 2: If shadow's mode is "closed", return null
    // Use interface instead of impl (per Golden Rule #13)
    const mode = interfaces.ShadowRoot.get_mode(shadow) catch return null;

    // Check if mode is closed
    if (mode == ._closed_) {
        return null;
    }

    // Step 3: Return shadow
    return shadow;
}

/// Getter for customElementRegistry
/// HTML §4.13.3 - Returns the element's associated custom element registry
/// Spec: https://html.spec.whatwg.org/#dom-element-customelementregistry
///
pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return (getInternal(instance) orelse return error.InvalidStateError).custom_element_registry.get();
}

/// Getter for part
/// CSS Shadow Parts - Returns the DOMTokenList for the part attribute
/// Spec: https://drafts.csswg.org/css-shadow-parts/#dom-element-part
///
/// The part getter returns a DOMTokenList reflecting the part attribute.
pub fn get_part(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Create a DOMTokenList for the part attribute
    // Use interface instead of impl (per Golden Rule #13)
    const token_list = interfaces.DOMTokenList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.DOMTokenList.deinit(token_list);

    // Find current part attribute value
    if (internal.data.findAttribute(null, "part")) |entry| {
        interfaces.DOMTokenList.set_value(token_list, runtime.DOMString.initInterned(entry.value)) catch return error.OutOfMemory;
    }

    // Associate with this element and the "part" attribute (internal method)
    DOMTokenListImpl.setElement(token_list, instance, runtime.DOMString.initInterned("part"));

    return token_list;
}

/// Getter for activeViewTransition
/// View Transitions API - Returns the active ViewTransition for this element
/// Spec: https://drafts.csswg.org/css-view-transitions-2/#dom-element-activeviewtransition
///
/// Note: Returns null - View Transitions API requires rendering engine.
pub fn get_activeViewTransition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // View Transitions require rendering engine - return null
    return null;
}

/// Getter for innerHTML
/// DOM Parsing §3 - Returns the HTML serialization of the element's descendants
/// Spec: https://w3c.github.io/DOM-Parsing/#dom-element-innerhtml
///
pub fn get_innerHTML(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    return @import("html").serialization.fragment(instance, false);
}

/// Getter for outerHTML
/// DOM Parsing §3 - Returns the HTML serialization of the element including itself
/// Spec: https://w3c.github.io/DOM-Parsing/#dom-element-outerhtml
///
pub fn get_outerHTML(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    return @import("html").serialization.outer(instance);
}

/// Getter for scrollTop
/// CSSOM View §3.1 - Returns scroll position from top
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollTop(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return 0.0;
}

/// Getter for scrollLeft
/// CSSOM View §3.1 - Returns scroll position from left
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollLeft(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return 0.0;
}

/// Getter for scrollWidth
/// CSSOM View §3.1 - Returns scroll width of element
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollWidth(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for scrollHeight
/// CSSOM View §3.1 - Returns scroll height of element
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_scrollHeight(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for clientTop
/// CSSOM View §3.1 - Returns top border width
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_clientTop(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for clientLeft
/// CSSOM View §3.1 - Returns left border width
/// Returns 0 for non-rendered elements (no layout engine)
pub fn get_clientLeft(instance: *runtime.Instance) anyerror!i32 {
    _ = instance;
    return 0;
}

/// Getter for clientWidth
/// CSSOM View §3.1 - Returns inner width of element
/// "1. If the element has no associated CSS layout box ..., return zero." -
/// with no layout capability, nothing has one. With one, the platform's
/// box: a replaced element's from its facts (decision 19b's STOPGAP,
/// dom.image_sources.replacedFacts), any other element's from layoutBox.
/// Not modelled, stated: step 2's root and body elements (the viewport).
pub fn get_clientWidth(instance: *runtime.Instance) anyerror!i32 {
    const box = clientBox(instance) orelse return 0;
    return roundedLength(box.client.width);
}

/// Getter for clientHeight
/// CSSOM View §3.1 - Returns inner height of element; as clientWidth.
pub fn get_clientHeight(instance: *runtime.Instance) anyerror!i32 {
    const box = clientBox(instance) orelse return 0;
    return roundedLength(box.client.height);
}

/// The element's layout box, if the platform lays out and gives it one.
fn clientBox(instance: *runtime.Instance) ?@import("platform").BoxMetrics {
    const platform = @import("platform");
    if (platform.capabilities.layout == .unsupported) {
        return null;
    } else {
        const browser = @import("html").platform_state.of(instance.ctx) orelse return null;
        const document = interfaces.Node.get_ownerDocument(instance) catch null;
        const document_node = dom.image_sources.layoutNode(document);
        const node = dom.image_sources.layoutNode(instance);
        // STOPGAP (decision 19b): a replaced element's box is sized from the
        // facts given with the query, until OQ4's DOM-to-renderer design.
        if (dom.image_sources.replacedFacts(instance)) |facts| return platform.replacedElementBox(browser, document_node, node, &facts);
        return platform.layoutBox(browser, document_node, node);
    }
}

fn roundedLength(value: f64) i32 {
    if (!std.math.isFinite(value)) return 0;
    return @intFromFloat(std.math.clamp(@round(value), @as(f64, std.math.minInt(i32)), @as(f64, std.math.maxInt(i32))));
}

/// Getter for currentCSSZoom
/// CSSOM View - Returns current CSS zoom level
/// Returns 1.0 (no zoom) for non-rendered elements
pub fn get_currentCSSZoom(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return 1.0;
}

/// Getter for ariaActiveDescendantElement
/// ARIAMixin - Element reference attribute
/// Spec: https://w3c.github.io/aria/#aria-activedescendant
///
/// Returns the element referenced by aria-activedescendant, or null if not set
pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return getAriaElementRef(instance, "aria-activedescendant");
}

/// Getter for ariaControlsElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariacontrolselements
///
/// Returns a frozen array of elements referenced by space-separated IDs in aria-controls.
/// Note: Returns null - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaControlsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaDescribedByElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-describedby
///
/// Returns an array of elements referenced by space-separated IDs in aria-describedby
/// Note: Returns null - full implementation requires FrozenArray support
pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaDetailsElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-details
///
/// Returns an array of elements referenced by space-separated IDs in aria-details
/// Note: Returns null - full implementation requires FrozenArray support
pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaErrorMessageElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-errormessage
///
/// Returns an array of elements referenced by space-separated IDs in aria-errormessage
/// Note: Returns null - full implementation requires FrozenArray support
pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaFlowToElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-flowto
///
/// Returns an array of elements referenced by space-separated IDs in aria-flowto.
/// Note: Returns null - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaLabelledByElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-labelledby
///
/// Returns an array of elements referenced by space-separated IDs in aria-labelledby.
/// Note: Returns null - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for ariaOwnsElements
/// ARIAMixin - Element array reference
/// Spec: https://w3c.github.io/aria/#aria-owns
///
/// Returns an array of elements referenced by space-separated IDs in aria-owns.
/// Note: Returns null - full implementation requires FrozenArray support and ID resolution.
pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // Return null - full implementation requires resolving space-separated IDs
    return null;
}

/// Getter for regionOverset
/// CSS Regions §10.2 - Returns the region's overset state
/// Spec: https://drafts.csswg.org/css-regions-1/#dom-region-regionoverset
///
/// Note: CSS Regions is deprecated/removed from most browsers.
/// Returns empty string as no region flow is active.
pub fn get_regionOverset(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    _ = instance;
    // CSS Regions not supported - return empty string
    return .{ .empty = {} };
}

/// Slottable's assignedSlot getter: "return the result of find a slot given
/// this and true" - null for a slot in a closed shadow root.
/// Spec: https://dom.spec.whatwg.org/#dom-slotable-assignedslot
pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return dom.shadow_dom_algorithms.assignedSlotForScript(instance);
}

/// Setter for id: `id` reflects "id".
/// Spec: https://dom.spec.whatwg.org/#dom-element-id
pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setAttributeValue(instance, "id", value.asSlice(), null, null);
}

/// Setter for className: `className` reflects "class".
/// Spec: https://dom.spec.whatwg.org/#dom-element-classname
pub fn set_className(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setAttributeValue(instance, "class", value.asSlice(), null, null);
}

/// Setter for slot: `slot` reflects "slot".
/// Spec: https://dom.spec.whatwg.org/#dom-element-slot
pub fn set_slot(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setAttributeValue(instance, "slot", value.asSlice(), null, null);
}

// =============================================================================
// The attribute list - DOM §4.9
//
// Every change to an element's attributes goes through the four algorithms
// "change", "append", "remove" and "replace" below, and each of them ends in
// "handle attribute changes": the mutation record, the custom element
// reaction and the attribute change steps. The id, class and slot caches are
// kept in step by those change steps, and by nothing else.
//
// Subclasses (HTMLElement's reflection, the script element's attributes) use
// the public "get / set an attribute value" and "remove an attribute"
// entry points; nothing outside this file touches the list directly.
// =============================================================================

/// "element is in the HTML namespace and its node document is an HTML
/// document": when getAttribute, setAttribute, hasAttribute, removeAttribute
/// and toggleAttribute lowercase the name they are given.
fn isHtmlElementInHtmlDocument(instance: *runtime.Instance, internal: *const InternalState) bool {
    const ns = internal.data.namespace_uri orelse return false;
    if (!std.mem.eql(u8, ns.asSlice(), infra.namespaces.HTML_NAMESPACE)) return false;
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return false;
    return dom.document_internals.getDocumentType(document) == .html;
}

/// A name as an attribute lookup should see it: `qualifiedName in ASCII
/// lowercase` when the element is an HTML element in an HTML document.
/// Short names are lowercased into the caller's buffer.
const LookupName = struct {
    slice: []const u8,
    owned: ?[]u8 = null,

    fn deinit(self: LookupName, allocator: std.mem.Allocator) void {
        if (self.owned) |owned| allocator.free(owned);
    }
};

fn lookupName(instance: *runtime.Instance, internal: *const InternalState, name: []const u8, buffer: []u8) !LookupName {
    // A name with no ASCII upper alpha is its own lowercase - the case for
    // every name the HTML parser produces - so skip the document check.
    const has_upper = for (name) |c| {
        if (std.ascii.isUpper(c)) break true;
    } else false;
    if (!has_upper or !isHtmlElementInHtmlDocument(instance, internal)) return .{ .slice = name };

    if (name.len <= buffer.len) return .{ .slice = std.ascii.lowerString(buffer[0..name.len], name) };
    const owned = try std.ascii.allocLowerString(internal.allocator, name);
    return .{ .slice = owned, .owned = owned };
}

/// DOM "handle attribute changes" for an attribute - identified by its
/// namespace and local name - with this element, oldValue and newValue.
///
/// Spec: https://dom.spec.whatwg.org/#handle-attribute-changes
fn handleAttributeChanges(
    instance: *runtime.Instance,
    namespace: ?[]const u8,
    local_name: []const u8,
    old_value: ?[]const u8,
    new_value: ?[]const u8,
) void {
    // Collections filter on any attribute: the node document's DOM tree
    // version moves (Blink's InvalidateNodeListCaches on attribute change).
    dom.refcount.attributeChanged(instance);

    // Step 1: "Queue a mutation record of "attributes" for element with
    // attribute's local name, attribute's namespace, oldValue, « », « »,
    // null, and null." The record copies what it keeps. A failure to queue
    // one must not skip the change steps below - the attribute has already
    // changed, and its caches must follow.
    dom.mutation_observer_algorithms.queueAttributeMutationRecord(instance, local_name, namespace, old_value) catch |err| {
        std.log.scoped(.element).warn("attributes mutation record not queued: {}", .{err});
    };

    // Step 2: "If element is custom, then enqueue a custom element callback
    // reaction with element, callback name "attributeChangedCallback", and
    // « attribute's local name, oldValue, newValue, attribute's namespace »."
    if (getInternal(instance)) |internal| {
        if (internal.custom_element_state == .custom) dom.custom_elements.enqueueCallback(instance, .attribute_changed, .{
            .attribute_changed = .{ .local_name = local_name, .old_value = old_value, .new_value = new_value, .namespace = namespace },
        });
    }

    // Step 3: "Run the attribute change steps with element, attribute's local
    // name, oldValue, newValue, and attribute's namespace."
    attributeChangeSteps(instance, local_name, old_value, new_value, namespace);
    // HTML 4.10.18.3 / 4.10.19.5: form, id and disabled can change a
    // form-associated custom element's owner or disabled state.
    if (namespace == null and (std.mem.eql(u8, local_name, "form") or std.mem.eql(u8, local_name, "id") or std.mem.eql(u8, local_name, "disabled"))) {
        dom.custom_elements.formAttributeChanged(instance, local_name, old_value, new_value);
    }
}

/// The attribute change steps this engine defines, in one place.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-change-ext
///
/// The image step can run script - it fetches and fires load or error
/// synchronously - so it goes last, after every step that reads the name and
/// value it was handed.
fn attributeChangeSteps(
    instance: *runtime.Instance,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void {
    // Every step below concerns attributes in no namespace.
    if (namespace != null) return;
    const internal = getInternal(instance) orelse return;

    // DOM §4.9: "If localName is id, namespace is null, and value is null or
    // the empty string, then unset element's ID. Otherwise, if localName is
    // id, namespace is null, then set element's ID to value." The class and
    // slot caches follow their attributes the same way.
    if (std.mem.eql(u8, local_name, "id")) {
        replaceCachedValue(internal, &internal.data.id, value);
    } else if (std.mem.eql(u8, local_name, "class")) {
        replaceCachedValue(internal, &internal.data.class_name, value);
    } else if (std.mem.eql(u8, local_name, "slot")) {
        // DOM 4.2.2.2: the slottable's name follows its slot attribute, and
        // a changed name re-assigns it.
        replaceCachedValue(internal, &internal.slot, value);
        dom.shadow_dom_algorithms.slottableNameChanged(instance, old_value, value);
    }

    // HTML §8.1.8.1: event handler content attributes.
    eventHandlerAttributeChangeSteps(instance, local_name, value);

    // HTML 3.2.6.5: the style attribute.
    if (std.mem.eql(u8, local_name, "style")) styleAttributeChangeSteps(instance, internal, value);

    // The steps the element's own type defines (an iframe's src and srcdoc),
    // which its impl installs (dom.attribute_change_steps) - for an HTML
    // element only, as the hook's contract says: its steps are keyed by HTML
    // local name, and a foreign element named "iframe" or "script" is no
    // HTMLIFrameElement or HTMLScriptElement (createElementNS(other, "iframe")
    // ran the iframe's steps on a plain Element, whose state they read as an
    // iframe's - a wild pointer).
    const element_namespace = if (internal.data.namespace_uri) |ns| ns.asSlice() else return;
    dom.attribute_change_steps.runForAttribute(instance, element_namespace, local_name, old_value, value, namespace);
    if (!std.mem.eql(u8, element_namespace, "http://www.w3.org/1999/xhtml")) return;
    dom.attribute_change_steps.run(instance, internal.data.local_name.asSlice(), local_name, old_value, value, namespace);
}

fn replaceCachedValue(internal: *InternalState, cache: *runtime.DOMString, value: ?[]const u8) void {
    cache.deinit(internal.allocator);
    cache.* = runtime.DOMString.initEmpty();
    if (value) |v| {
        // A failed copy leaves the cache empty; the attribute itself is set.
        cache.* = runtime.DOMString.initDupe(internal.allocator, v) catch runtime.DOMString.initEmpty();
    }
}

/// DOM "change an attribute" - the one at `index` - to `value`.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-change
fn changeAttribute(instance: *runtime.Instance, internal: *InternalState, index: usize, value: []const u8) !void {
    const entry = internal.data.attributeAtMut(index) orelse return error.InvalidStateError;
    const new_value = try internal.allocator.dupe(u8, value);

    // Step 1: "Let oldValue be attribute's value."
    const old_value = entry.value;
    defer internal.allocator.free(old_value);

    // Step 2: "Set attribute's value to value."
    entry.value = new_value;

    // Step 3: "Handle attribute changes for attribute with attribute's
    // element, oldValue, and value."
    handleAttributeChanges(instance, entry.namespace_uri, entry.local_name, old_value, new_value);
}

/// DOM "append an attribute" to this element.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-append
fn appendAttribute(
    instance: *runtime.Instance,
    internal: *InternalState,
    namespace: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,
    value: []const u8,
) !void {
    const allocator = internal.allocator;
    const namespace_copy: ?[]const u8 = if (namespace) |ns| try allocator.dupe(u8, ns) else null;
    errdefer if (namespace_copy) |ns| allocator.free(ns);
    const prefix_copy: ?[]const u8 = if (prefix) |p| try allocator.dupe(u8, p) else null;
    errdefer if (prefix_copy) |p| allocator.free(p);
    const local_name_copy = try allocator.dupe(u8, local_name);
    errdefer allocator.free(local_name_copy);
    const value_copy = try allocator.dupe(u8, value);
    errdefer allocator.free(value_copy);

    const entry = AttributeEntry{
        .namespace_uri = namespace_copy,
        .prefix = prefix_copy,
        .local_name = local_name_copy,
        .value = value_copy,
    };

    // Step 1: "Append attribute to element's attribute list."
    try internal.data.addAttribute(entry);

    // Steps 2 and 3 set the attribute's element and node document: this list
    // stores the attribute's data, and an Attr node made for it takes both
    // from the element when it is created.

    // Step 4: "Handle attribute changes for attribute with element, null, and
    // attribute's value."
    handleAttributeChanges(instance, entry.namespace_uri, entry.local_name, null, entry.value);
}

/// DOM "remove an attribute" - the one at `index`.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-remove
fn removeAttributeAt(instance: *runtime.Instance, internal: *InternalState, index: usize) void {
    // Steps 1 and 2: "Let element be attribute's element. Remove attribute
    // from element's attribute list." The entry is ours until the changes
    // below have read its name and value.
    var entry = internal.data.takeAttributeAt(index);
    defer ElementData.freeAttributeEntry(internal.allocator, entry);

    // Step 3: "Set attribute's element to null." - its Attr node, if script
    // has one, keeps the value it had here.
    detachAttrNode(instance, &entry);

    // Step 4: "Handle attribute changes for attribute with element,
    // attribute's value, and null."
    handleAttributeChanges(instance, entry.namespace_uri, entry.local_name, entry.value, null);
}

/// DOM "set an attribute value": the setter steps of every reflected string
/// attribute, and of the internal callers that set a content attribute -
/// those outside this file through `dom.element_attributes.set`.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-set-value
fn setAttributeValue(
    instance: *runtime.Instance,
    local_name: []const u8,
    value: []const u8,
    prefix: ?[]const u8,
    namespace: ?[]const u8,
) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: "Let attribute be the result of getting an attribute given
    // namespace, localName, and element."
    const index = internal.data.indexOfAttribute(namespace, local_name) orelse {
        // Step 2: "If attribute is null, create an attribute whose namespace
        // is namespace, namespace prefix is prefix, local name is localName,
        // value is value, and node document is element's node document, then
        // append this attribute to element, and then return."
        return appendAttribute(instance, internal, namespace, prefix, local_name, value);
    };

    // Step 3: "Change attribute to value."
    return changeAttribute(instance, internal, index, value);
}

/// DOM "remove an attribute by namespace and local name" - from outside this
/// file, `dom.element_attributes.remove`.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-remove-by-namespace
fn removeAttributeByNamespaceAndLocalName(instance: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) void {
    const internal = getInternal(instance) orelse return;
    // Step 1: "Let attr be the result of getting an attribute given
    // namespace, localName, and element." (Getting one maps "" to null.)
    const ns: ?[]const u8 = if (namespace) |n| (if (n.len == 0) null else n) else null;
    // Step 2: "If attr is non-null, then remove attr."
    const index = internal.data.indexOfAttribute(ns, local_name) orelse return;
    removeAttributeAt(instance, internal, index);
}

/// DOM "remove an attribute by name": the first attribute whose qualified
/// name is `qualified_name`, after lowercasing for an HTML element in an HTML
/// document.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-remove-by-name
fn removeAttributeByName(instance: *runtime.Instance, qualified_name: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualified_name, &buffer);
    defer name.deinit(internal.allocator);
    // Step 1: "Let attr be the result of getting an attribute given
    // qualifiedName and element."
    // Step 2: "If attr is non-null, then remove attr."
    const index = internal.data.indexOfQualifiedName(name.slice) orelse return;
    removeAttributeAt(instance, internal, index);
}

/// `dom.node_creation.setElementNames`: DOM "create an element" setting the
/// element's local name and namespace, unvalidated. Both are set even when
/// one fails; the first failure is reported.
fn setNamesHook(element: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) dom.node_creation.Error!void {
    const named = setLocalName(element, local_name);
    const namespaced = setNamespaceURI(element, namespace);
    try named;
    try namespaced;
}

/// `dom.element_attributes.at`: the list read in place.
fn attributeAtHook(element: *runtime.Instance, index: usize) ?dom.element_attributes.Attribute {
    const internal = getInternal(element) orelse return null;
    const entry = internal.data.attributeAt(index) orelse return null;
    return .{
        .namespace = entry.namespace_uri,
        .prefix = entry.prefix,
        .local_name = entry.local_name,
        .value = entry.value,
    };
}

/// `dom.element_attributes.count`.
fn attributeCountHook(element: *runtime.Instance) usize {
    const internal = getInternal(element) orelse return 0;
    return internal.data.getAttributeCount();
}

/// `dom.element_attributes.append`: "append an attribute" with exactly the
/// fields given.
fn appendAttributeHook(element: *runtime.Instance, attribute: dom.element_attributes.Attribute) dom.element_attributes.Error!void {
    const internal = getInternal(element) orelse return error.InvalidStateError;
    return appendAttribute(element, internal, attribute.namespace, attribute.prefix, attribute.local_name, attribute.value);
}

/// `dom.element_attributes.change`: an Attr node's "set an existing attribute
/// value" for an attribute that has an element.
fn changeAttributeHook(element: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8, value: []const u8) dom.element_attributes.Error!void {
    const internal = getInternal(element) orelse return error.InvalidStateError;
    const index = internal.data.indexOfAttribute(namespace, local_name) orelse return error.InvalidStateError;
    changeAttribute(element, internal, index, value) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidStateError,
    };
}

/// `dom.element_attributes.set`: "set an attribute value".
fn setAttributeHook(element: *runtime.Instance, local_name: []const u8, value: []const u8, prefix: ?[]const u8, namespace: ?[]const u8) dom.element_attributes.Error!void {
    setAttributeValue(element, local_name, value, prefix, namespace) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidStateError,
    };
}

/// `dom.element_attributes.remove`: "remove an attribute by namespace and
/// local name".
fn removeAttributeHook(element: *runtime.Instance, namespace: ?[]const u8, local_name: []const u8) void {
    removeAttributeByNamespaceAndLocalName(element, namespace, local_name);
}

/// `dom.element_data.of`: this element's attribute list, ID, classes and
/// qualified name, in its own state.
fn dataOf(element: *runtime.Instance) ?*ElementData {
    const internal = getInternal(element) orelse return null;
    return &internal.data;
}

/// `dom.element_attributes.nodeAt`: NamedNodeMap's item(index).
fn attrNodeAtHook(element: *runtime.Instance, index: usize) dom.element_attributes.Error!?*runtime.Instance {
    const internal = getInternal(element) orelse return null;
    if (index >= internal.data.getAttributeCount()) return null;
    return ensureAttrNode(element, internal, index) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidStateError,
    };
}

/// `dom.element_attributes.existingNodeAt`: the Attr node made for the
/// attribute at `index`, if one was and it is still alive; never makes one.
fn existingAttrNodeAtHook(element: *runtime.Instance, index: usize) ?*runtime.Instance {
    const internal = getInternal(element) orelse return null;
    const entry = internal.data.attributeAt(index) orelse return null;
    const link = entry.attr_node orelse return null;
    return if (link.isLive()) link.instance else null;
}

// Note: matches(), closest(), and webkitMatchesSelector() match through
// dom.selector_matching, which querySelector() shares.

// =============================================================================
// Insert Adjacent Algorithm (DOM §4.10.7)
// =============================================================================

/// DOM insert adjacent, shared by insertAdjacentElement and insertAdjacentText.
/// https://dom.spec.whatwg.org/#insert-adjacent
fn insertAdjacent(element: *runtime.Instance, where: []const u8, node: *runtime.Instance) anyerror!?*runtime.Instance {
    // Each case returns pre-insert's result, including its hierarchy errors.
    if (std.ascii.eqlIgnoreCase(where, "beforebegin")) {
        // Step 1: before element in its parent, or null without a parent.
        const parent = (try interfaces.Node.get_parentNode(element)) orelse return null;
        return try interfaces.Node.call_insertBefore(parent, node, element);
    } else if (std.ascii.eqlIgnoreCase(where, "afterbegin")) {
        // Step 2: before element's first child.
        return try interfaces.Node.call_insertBefore(element, node, try interfaces.Node.get_firstChild(element));
    } else if (std.ascii.eqlIgnoreCase(where, "beforeend")) {
        // Step 3: before null in element.
        return try interfaces.Node.call_insertBefore(element, node, null);
    } else if (std.ascii.eqlIgnoreCase(where, "afterend")) {
        // Step 4: before the next sibling, or null without a parent.
        const parent = (try interfaces.Node.get_parentNode(element)) orelse return null;
        return try interfaces.Node.call_insertBefore(parent, node, try interfaces.Node.get_nextSibling(element));
    }
    // Step 5: any other position is invalid.
    return error.SyntaxError;
}

// =============================================================================
// ARIA Attribute Helpers
// =============================================================================

/// Get an ARIA attribute value. The ARIA attributes reflect as nullable
/// DOMStrings: "If attr is null, then return null."
/// Spec: https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#reflecting-content-attributes-in-idl-attributes
fn getAriaAttribute(instance: *runtime.Instance, aria_name: []const u8) ?runtime.DOMString {
    const internal = getInternal(instance) orelse return null;
    const entry = internal.data.findAttribute(null, aria_name) orelse return null;
    return runtime.DOMString.initInterned(entry.value);
}

/// Set an ARIA attribute value: a null value removes the attribute, anything
/// else sets it - the setter steps of a reflected nullable DOMString.
fn setAriaAttribute(instance: *runtime.Instance, aria_name: []const u8, value: ?runtime.DOMString) ImplError!void {
    if (value) |v| {
        setAttributeValue(instance, aria_name, v.asSlice(), null, null) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidStateError,
        };
    } else {
        removeAttributeByNamespaceAndLocalName(instance, null, aria_name);
    }
}

/// Get an element by ID from the owner document (for ARIA element reference attributes)
/// Returns null if the element is not connected to a document or the ID is not found
fn getElementByIdFromDocument(instance: *runtime.Instance, id: []const u8) ?*runtime.Instance {
    if (id.len == 0) return null;

    // Get the owner document (nullable return type now)
    const owner_doc_opt = interfaces.Node.get_ownerDocument(instance) catch return null;
    const owner_doc = owner_doc_opt orelse return null;

    // Use document's getElementById
    // Use interface instead of impl (per Golden Rule #13)
    const result = interfaces.Document.call_getElementById(owner_doc, runtime.DOMString.initInterned(id)) catch return null;
    return result;
}

/// Get an ARIA element reference attribute (single element)
/// These attributes contain an ID reference that needs to be resolved to an element
fn getAriaElementRef(instance: *runtime.Instance, aria_attr: []const u8) ?*runtime.Instance {
    // Get the attribute value (contains an ID)
    const attr_value = getAriaAttribute(instance, aria_attr) orelse return null;
    const id = attr_value.asSlice();
    if (id.len == 0) return null;

    return getElementByIdFromDocument(instance, id);
}

/// Set an ARIA element reference attribute
/// Takes an element and stores its ID as the attribute value
fn setAriaElementRef(instance: *runtime.Instance, aria_attr: []const u8, element: ?*runtime.Instance) ImplError!void {
    if (element) |elem| {
        // Get the element's ID
        if (getInternal(elem)) |elem_internal| {
            const elem_id = elem_internal.data.id.asSlice();
            if (elem_id.len > 0) {
                // Set the ARIA attribute to the element's ID
                return setAriaAttribute(instance, aria_attr, runtime.DOMString.initInterned(elem_id));
            }
        }
    }
    // Element is null or has no ID - remove the attribute
    removeAttributeByNamespaceAndLocalName(instance, null, aria_attr);
}

/// Setter for innerHTML
/// DOM Parsing §3.2 - Sets the element's inner HTML
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-innerhtml-property
///
/// Steps:
/// 1. Parse the string using the HTML fragment parsing algorithm
/// 2. Remove all children from this element
/// 3. Append parsed nodes to this element
///
/// HTML Standard - Sets the innerHTML of this element
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-innerhtml-property
///
/// Steps:
/// 1. Let context element be this (the element)
/// 2. Parse the string using the HTML fragment parsing algorithm with context
/// 3. Replace all children of context with the parsed nodes
pub fn set_innerHTML(instance: *runtime.Instance, value: typedefs.TrustedHTMLOrDOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let compliantString be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, this's relevant
    // global object, the given value, "Element innerHTML", and "script"."
    const compliant = try dom.trusted_types.compliantStringFor(internal.allocator, .html, instance, value, "Element innerHTML");
    defer internal.allocator.free(compliant);
    const html_string: []const u8 = compliant;

    const target = try dom.template_contents.insertionTarget(instance);
    const element_base = dom.instance_bridge.getNodeBase(target) orelse return error.InvalidStateError;

    // The empty string parses to an empty fragment: replace all with nothing.
    if (html_string.len == 0) {
        try dom.mutation.replaceAll(@as(?*dom.NodeBase, null), element_base);
        return;
    }

    // Step 1: "Let fragment be the result of invoking the fragment parsing
    // algorithm steps with context and compliantString."
    const fragment = @import("html").custom_elements.parseFragment(instance, html_string) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        // The XML fragment parsing algorithm's step 7.
        error.SyntaxError => return error.SyntaxError,
        else => return error.NotSupportedError,
    };

    // The fragment is empty once its children have moved.
    defer dom.node_creation.destroyUninserted(fragment);
    const fragment_base = dom.instance_bridge.getNodeBase(@ptrCast(fragment)) orelse return error.InvalidStateError;

    // Step 2: "If context is a template element, then set context to the
    // template element's template contents."
    // The target above also handles replacement by an empty fragment.

    // Step 3: "Replace all with fragment within context." One tree mutation
    // record for the whole change; removing each child and moving each
    // parsed node one at a time queued a record apiece.
    try dom.mutation.replaceAll(@as(?*dom.NodeBase, fragment_base), element_base);
}

/// Setter for outerHTML
/// HTML §8.5.5 - Replaces the element with a parsed fragment.
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#the-outerhtml-property
pub fn set_outerHTML(instance: *runtime.Instance, value: typedefs.TrustedHTMLOrDOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // HTML outerHTML setter step 1: "Let compliantString be the result of
    // invoking the get trusted type compliant string algorithm with
    // TrustedHTML, this's relevant global object, the given value, "Element
    // outerHTML", and "script"."
    const compliant = try dom.trusted_types.compliantStringFor(internal.allocator, .html, instance, value, "Element outerHTML");
    defer internal.allocator.free(compliant);

    // Steps 2–4: only a detached element is a no-op; a Document parent is
    // specifically NoModificationAllowedError, not HierarchyRequestError.
    const parent = (try interfaces.Node.get_parentNode(instance)) orelse return;
    const parent_type = try interfaces.Node.get_nodeType(parent);
    if (parent_type == interfaces.Node.get_DOCUMENT_NODE()) {
        return error.NoModificationAllowedError;
    }

    // Step 5: a fragment is not a parsing context element. Create the
    // specified HTML body in this's node document, then reclaim it when the
    // parse finishes (Gecko Element::SetOuterHTML uses the same context).
    var temporary_body: ?*runtime.Instance = null;
    defer if (temporary_body) |body| dom.node_creation.destroyUninserted(body);
    const context = if (parent_type == interfaces.Node.get_DOCUMENT_FRAGMENT_NODE()) blk: {
        const document = (try interfaces.Node.get_ownerDocument(instance)) orelse return error.InvalidStateError;
        const body = try interfaces.Document.call_createElementNS(
            document,
            runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"),
            runtime.DOMString.initInterned("body"),
            webidl.Opt(runtime.JSValue).notPassed(),
        );
        temporary_body = body;
        break :blk body;
    } else parent;

    // Step 6: parse with the adjusted parent as context.
    const fragment = @import("html").dom_parser.parseFragment(
        internal.allocator,
        instance.ctx,
        compliant,
        context,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        // The XML fragment parsing algorithm's step 7.
        error.SyntaxError => return error.SyntaxError,
        else => return error.NotSupportedError,
    };
    defer dom.node_creation.destroyUninserted(fragment);

    // Step 7: one replacement, including its single child-list mutation
    // record. Use this's actual parent after parsing, not the fictional body.
    const actual_parent = (try interfaces.Node.get_parentNode(instance)) orelse return error.NotFoundError;
    _ = try interfaces.Node.call_replaceChild(actual_parent, fragment, instance);
}

/// Setter for scrollTop
/// CSSOM View §3.1 - Sets scroll position from top
/// No-op for non-rendered elements (no layout engine)
pub fn set_scrollTop(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would require layout engine to scroll
}

/// Setter for scrollLeft
/// CSSOM View §3.1 - Sets scroll position from left
/// No-op for non-rendered elements (no layout engine)
pub fn set_scrollLeft(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would require layout engine to scroll
}

/// Setter for ariaActiveDescendantElement
/// ARIAMixin - Element reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaactivedescendantelement
///
/// Sets the element that is the active descendant. This should set
/// aria-activedescendant to the target element's ID.
/// Note: No-op - full implementation requires getting target element's ID
/// and setting aria-activedescendant attribute.
pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to get value's ID and set aria-activedescendant
    // Full implementation requires: get ID from value element, set attribute
}

/// Setter for ariaControlsElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariacontrolselements
///
/// Sets the elements that this element controls. This should set
/// aria-controls to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaControlsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-controls
}

/// Setter for ariaDescribedByElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariadescribedbyelements
///
/// Sets the elements that describe this element. This should set
/// aria-describedby to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-describedby
}

/// Setter for ariaDetailsElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariadetailselements
///
/// Sets the elements that provide details for this element. This should set
/// aria-details to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-details
}

/// Setter for ariaErrorMessageElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaerrormessageelements
///
/// Sets the elements that contain error messages for this element. This should set
/// aria-errormessage to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-errormessage
}

/// Setter for ariaFlowToElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaflowtoelements
///
/// Sets the elements that are the next in reading order. This should set
/// aria-flowto to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-flowto
}

/// Setter for ariaLabelledByElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-arialabelledbyelements
///
/// Sets the elements that label this element. This should set
/// aria-labelledby to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-labelledby
}

/// Setter for ariaOwnsElements
/// ARIAMixin - Element array reference setter
/// Spec: https://w3c.github.io/aria/#dom-ariamixin-ariaownselements
///
/// Sets the elements that are owned by this element. This should set
/// aria-owns to space-separated IDs of the target elements.
/// Note: No-op - full implementation requires FrozenArray handling and ID extraction.
pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    // No-op - would need to extract IDs from elements and set aria-owns
}

/// Operation: getAttributeNS
/// DOM §4.8 - Returns the value of the attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributens
pub fn call_getAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let attr be the result of getting an attribute given
    // namespace, localName, and this." Getting one maps "" to null.
    const ns: ?[]const u8 = if (namespace) |n| (if (n.len() == 0) null else n.asSlice()) else null;
    // Step 2: "If attr is null, return null."
    const entry = internal.data.findAttribute(ns, localName.asSlice()) orelse return null;
    // Step 3: "Return attr's value."
    return runtime.DOMString.initInterned(entry.value);
}

/// Operation: getAttribute
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattribute
pub fn call_getAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let attr be the result of getting an attribute given
    // qualifiedName and this": the first attribute whose qualified name is
    // qualifiedName, lowercased for an HTML element in an HTML document.
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualifiedName.asSlice(), &buffer);
    defer name.deinit(internal.allocator);
    // Step 2: "If attr is null, return null."
    const index = internal.data.indexOfQualifiedName(name.slice) orelse return null;
    // Step 3: "Return attr's value."
    return runtime.DOMString.initInterned(internal.data.attributeAt(index).?.value);
}

/// Operation: hasAttribute
/// Spec: https://dom.spec.whatwg.org/#dom-element-hasattribute
pub fn call_hasAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: lowercase for an HTML element in an HTML document.
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualifiedName.asSlice(), &buffer);
    defer name.deinit(internal.allocator);
    // Step 2: "Return true if this has an attribute whose qualified name is
    // qualifiedName; otherwise false."
    return internal.data.indexOfQualifiedName(name.slice) != null;
}

/// Operation: matches
/// DOM §4.10.4 - Returns true if element matches the given selector
/// Spec: https://dom.spec.whatwg.org/#dom-element-matches
pub fn call_matches(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!bool {
    // The matching is dom.selector_matching's, shared with ParentNode's
    // querySelector() and querySelectorAll().
    return dom.selector_matching.matches(instance, selectors.asSlice());
}

/// Operation: releasePointerCapture
/// Pointer Events §5.4.3 - Releases pointer capture
/// Spec: https://w3c.github.io/pointerevents/#dom-element-releasepointercapture
///
/// Without pointer event support, this is a no-op
pub fn call_releasePointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
    _ = instance;
    _ = pointerId;
    // No-op without pointer event support
}

/// Operation: computedStyleMap
/// CSS Typed OM §5.3 - Returns the element's computed style as a StylePropertyMapReadOnly
/// Spec: https://drafts.css-houdini.org/css-typed-om-1/#dom-element-computedstylemap
///
/// Note: Returns null - requires CSSOM and layout engine
pub fn call_computedStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // Requires CSSOM and layout engine - return null
    return error.NotImplemented;
}

/// Operation: scroll
/// CSSOM View §5.1 - Scrolls the element to the given coordinates
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scroll
///
/// Without a layout engine, this is a no-op (returns sentinel for undefined)
pub fn call_scroll(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // No-op without layout engine - returns undefined
    // TODO: Should return a resolved Promise<undefined>
    return runtime.JSValue.jsUndefined;
}

/// Operation: getClientRects
/// CSSOM View §5.1 - Returns a DOMRectList of client rects for this element
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-getclientrects
///
/// Without a layout engine, returns an empty DOMRectList
pub fn call_getClientRects(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return empty DOMRectList (no layout = no client rects)
    return interfaces.DOMRectList.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
}

/// Operation: scrollBy
/// CSSOM View §5.1 - Scrolls the element by the given amounts
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollby
///
/// Without a layout engine, this is a no-op (returns sentinel for undefined)
pub fn call_scrollBy(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // No-op without layout engine - returns undefined
    // TODO: Should return a resolved Promise<undefined>
    return runtime.JSValue.jsUndefined;
}

/// Operation: convertQuadFromNode
/// CSSOM View §6 - Converts a quad from another element's coordinate space
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-convertquadfromnode
///
/// Note: Returns null - requires layout engine for coordinate transformations
pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: dictionaries.DOMQuadInit, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = quad;
    _ = from;
    _ = options;
    // Requires layout engine for coordinate transformations - return null
    return error.NotImplemented;
}

/// Operation: setAttributeNodeNS
/// DOM §4.8 - Adds or replaces the Attr node with the given namespace
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattributenodens
///
/// The setAttributeNodeNS(attr) method steps are to return the result of
/// setting an attribute given attr and this.
///
/// Returns the old Attr node if replaced, or null if newly added.
pub fn call_setAttributeNodeNS(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
    // setAttributeNodeNS and setAttributeNode have identical behavior per spec
    // They both call the "set an attribute" algorithm
    return call_setAttributeNode(instance, attr);
}

/// Operation: getAttributeNodeNS
/// DOM §4.8 - Returns the Attr node with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributenodens
pub fn call_getAttributeNodeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "Getting an attribute given namespace, localName, and this": "" is null.
    const ns: ?[]const u8 = if (namespace) |n| (if (n.len() == 0) null else n.asSlice()) else null;
    const index = internal.data.indexOfAttribute(ns, localName.asSlice()) orelse return null;
    return try ensureAttrNode(instance, internal, index);
}

/// The Attr node for the attribute at `index`: the one made before, or a new
/// one made now. This list stores attribute data; a node is made only when
/// script asks for one, and the same node is handed out after that - the
/// design of Blink's Element::EnsureAttr and WebKit's Element::ensureAttr.
fn ensureAttrNode(instance: *runtime.Instance, internal: *InternalState, index: usize) !*runtime.Instance {
    const entry = internal.data.attributeAtMut(index) orelse return error.InvalidStateError;
    if (entry.attr_node) |link| {
        if (link.isLive()) return link.instance;
    }

    const attr = try interfaces.Attr.init(internal.allocator, instance.ctx);
    errdefer interfaces.Attr.deinit(attr);
    try dom.attr_nodes.name(attr, entry.namespace_uri, entry.prefix, entry.local_name);
    try dom.attr_nodes.attach(attr, instance);
    // `attach` can run nothing, so `entry` is still this attribute's.
    if (entry.attr_node) |old| forgetAttrNode(instance, old.instance);
    entry.attr_node = dom.element_data.AttrNodeLink.to(attr);
    traceAttrNode(instance, attr);
    return attr;
}

/// The attribute `entry` stands for is leaving this element: its Attr node, if
/// one was made, keeps the value and loses its element, and this element stops
/// keeping it - `element` null when the element is being torn down, where the
/// edge goes with its wrapper.
fn detachAttrNode(element: ?*runtime.Instance, entry: *AttributeEntry) void {
    const link = entry.attr_node orelse return;
    entry.attr_node = null;
    if (element) |e| forgetAttrNode(e, link.instance);
    // A teardown sweep - or the collector, with the element - may have freed
    // the node first.
    if (!link.isLive()) return;
    dom.attr_nodes.detach(link.instance, entry.value) catch {};
}

/// `attr` is now the Attr node for the attribute at `index`.
fn adoptAttrNode(instance: *runtime.Instance, internal: *InternalState, index: usize, attr: *runtime.Instance) !void {
    const entry = internal.data.attributeAtMut(index) orelse return error.InvalidStateError;
    try dom.attr_nodes.attach(attr, instance);
    if (entry.attr_node) |old| forgetAttrNode(instance, old.instance);
    entry.attr_node = dom.element_data.AttrNodeLink.to(attr);
    traceAttrNode(instance, attr);
}

/// Operation: setAttributeNS
/// DOM §4.8 - Sets the attribute with the given namespace and qualified name
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattributens
pub fn call_setAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, qualifiedName: runtime.DOMString, value: typedefs.TrustedTypeOrDOMString) anyerror!void {
    // Step 1: "Let (namespace, prefix, localName) be the result of validating
    // and extracting namespace and qualifiedName given "attribute"."
    const extracted = try dom.names.validateAndExtract(
        if (namespace) |ns| ns.asSlice() else null,
        qualifiedName.asSlice(),
        .attribute,
    );

    // Step 2: "Let verifiedValue be the result of calling get trusted type
    // compliant attribute value with localName, namespace, this, and value."
    const allocator = instance.ctx.allocator;
    const verified = try dom.trusted_types.getCompliantAttributeValue(allocator, extracted.local_name, extracted.namespace, instance, dom.trusted_types.inputFrom(value));
    defer allocator.free(verified);

    // Step 3: "Set an attribute value for this using localName,
    // verifiedValue, prefix, and namespace."
    try setAttributeValue(instance, extracted.local_name, verified, extracted.prefix, extracted.namespace);
}

/// Operation: setAttributeNode
/// DOM §4.8 - Adds or replaces the Attr node
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattributenode
///
/// The setAttributeNode(attr) method steps are to return the result of
/// setting an attribute given attr and this.
pub fn call_setAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // The getters clone into the Attr's context allocator; this frame owns
    // the copies. An Attr with no namespace or prefix reports "".
    const attr_allocator = attr.ctx.allocator;
    var namespace_string = (interfaces.Attr.get_namespaceURI(attr) catch return error.InvalidStateError) orelse runtime.DOMString.initEmpty();
    defer namespace_string.deinit(attr_allocator);
    var prefix_string = (interfaces.Attr.get_prefix(attr) catch return error.InvalidStateError) orelse runtime.DOMString.initEmpty();
    defer prefix_string.deinit(attr_allocator);
    var local_name = interfaces.Attr.get_localName(attr) catch return error.InvalidStateError;
    defer local_name.deinit(attr_allocator);
    var value = interfaces.Attr.get_value(attr) catch return error.InvalidStateError;
    defer value.deinit(attr_allocator);
    const namespace: ?[]const u8 = if (namespace_string.len() == 0) null else namespace_string.asSlice();
    const prefix: ?[]const u8 = if (prefix_string.len() == 0) null else prefix_string.asSlice();

    // Step 1: "Let verifiedValue be the result of calling get trusted type
    // compliant attribute value with attr's local name, attr's namespace,
    // element, and attr's value." A default policy runs script: everything
    // below reads the attribute and the element again, after it.
    const verified = try dom.trusted_types.getCompliantAttributeValue(internal.allocator, local_name.asSlice(), namespace, instance, .{ .string = value.asSlice() });
    defer internal.allocator.free(verified);

    // Step 2: "If attr's element is neither null nor element, throw an
    // "InUseAttributeError" DOMException."
    const attr_element = interfaces.Attr.get_ownerElement(attr) catch null;
    if (attr_element) |element| {
        if (element != instance) return error.InUseAttributeError;
    }

    // Step 3: "Let oldAttr be the result of getting an attribute given attr's
    // namespace, attr's local name, and element."
    const old_index = internal.data.indexOfAttribute(namespace, local_name.asSlice()) orelse {
        // Step 5: "Set attr's value to verifiedValue." Step 7: "Otherwise,
        // append attr to element." attr becomes the node for the new
        // attribute before the attribute change steps run.
        try appendAttribute(instance, internal, namespace, prefix, local_name.asSlice(), verified);
        // Found again by name: the change steps can run script.
        const new_index = internal.data.indexOfAttribute(namespace, local_name.asSlice()) orelse return null;
        try adoptAttrNode(instance, internal, new_index, attr);
        // Step 8: "Return oldAttr." - null.
        return null;
    };

    // Step 4: "If oldAttr is attr, return attr."
    if (internal.data.attributeAt(old_index).?.attr_node) |link| {
        if (link.isLive() and link.instance == attr) return attr;
    }

    // Step 5: "Set attr's value to verifiedValue" - the value the replacing
    // attribute takes below.

    // Step 6: "If oldAttr is non-null, then replace oldAttr with attr."
    // "Set oldAttribute's element to null": oldAttr - the node script may
    // already hold, or one made now to hand back - keeps its last value.
    const old_attr = try ensureAttrNode(instance, internal, old_index);
    detachAttrNode(instance, internal.data.attributeAtMut(old_index).?);
    try replaceAttributeAt(instance, internal, old_index, prefix, verified);
    // Found again by name: the change steps can run script.
    if (internal.data.indexOfAttribute(namespace, local_name.asSlice())) |index| {
        try adoptAttrNode(instance, internal, index, attr);
    }

    // Step 8: "Return oldAttr."
    return old_attr;
}

/// DOM "replace an attribute": the one at `index` by an attribute with the
/// same namespace and local name, and the given prefix and value.
///
/// Spec: https://dom.spec.whatwg.org/#concept-element-attributes-replace
fn replaceAttributeAt(instance: *runtime.Instance, internal: *InternalState, index: usize, prefix: ?[]const u8, value: []const u8) !void {
    const allocator = internal.allocator;
    const entry = internal.data.attributeAtMut(index) orelse return error.InvalidStateError;
    const new_prefix: ?[]const u8 = if (prefix) |p| try allocator.dupe(u8, p) else null;
    errdefer if (new_prefix) |p| allocator.free(p);
    const new_value = try allocator.dupe(u8, value);

    // Step 2: "Replace oldAttribute by newAttribute in element's attribute
    // list." Steps 3 to 5 move the element from one Attr node to the other.
    const old_prefix = entry.prefix;
    const old_value = entry.value;
    defer {
        if (old_prefix) |p| allocator.free(p);
        allocator.free(old_value);
    }
    entry.prefix = new_prefix;
    entry.value = new_value;

    // Step 6: "Handle attribute changes for oldAttribute with element,
    // oldAttribute's value, and newAttribute's value."
    handleAttributeChanges(instance, entry.namespace_uri, entry.local_name, old_value, new_value);
}

/// Operation: scrollTo
/// CSSOM View §5.1 - Scrolls the element to the given coordinates (alias for scroll)
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollto
///
/// Without a layout engine, this is a no-op (returns sentinel for undefined)
pub fn call_scrollTo(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ScrollToOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // No-op without layout engine - returns undefined
    // TODO: Should return a resolved Promise<undefined>
    return runtime.JSValue.jsUndefined;
}

/// Operation: getElementsByTagNameNS
/// DOM §4.10.5 - Returns HTMLCollection of descendants with matching namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getelementsbytagnamens
pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // DOM: "return the list of elements with namespace namespace and local
    // name localName for this" - a LIVE collection (dom.live_collections).
    const collection = interfaces.HTMLCollection.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.HTMLCollection.deinit(collection);
    try dom.live_collections.elementsWithNamespaceAndLocalName(collection, instance, if (namespace) |ns| ns.asSlice() else null, localName.asSlice());
    return collection;
}

/// Operation: getRegionFlowRanges
/// CSS Regions §10.3 - Returns ranges for content in this region
/// Spec: https://drafts.csswg.org/css-regions-1/#dom-region-getregionflowranges
///
/// Note: CSS Regions is deprecated - returns null
pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    // CSS Regions is deprecated - return null
    return null;
}

/// Operation: getBoxQuads
/// CSSOM View §6 - Returns the element's CSS boxes as DOMQuads
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-getboxquads
///
/// Note: Returns sentinel for empty array - requires layout engine
pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(dictionaries.BoxQuadOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // Requires layout engine - return undefined (empty array)
    return runtime.JSValue.jsUndefined;
}

/// Operation: focusableAreas
/// CSS Spatial Navigation §5 - Returns focusable areas in specified direction
/// Spec: https://drafts.csswg.org/css-nav-1/#dom-element-focusableareas
///
/// Note: Returns undefined (empty array) - spatial navigation not implemented
pub fn call_focusableAreas(instance: *runtime.Instance, option: webidl.Opt(dictionaries.FocusableAreasOption)) anyerror!runtime.JSValue {
    _ = instance;
    _ = option;
    // Spatial navigation not implemented - return undefined (empty array)
    return runtime.JSValue.jsUndefined;
}

/// Operation: convertPointFromNode
/// CSSOM View §6 - Converts a point from another element's coordinate space
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-convertpointfromnode
///
/// Note: Returns null - requires layout engine for coordinate transformations
pub fn call_convertPointFromNode(instance: *runtime.Instance, point: dictionaries.DOMPointInit, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = point;
    _ = from;
    _ = options;
    // Requires layout engine - return null
    return error.NotImplemented;
}

/// Operation: getAnimations
/// Web Animations §4.4.4 - Returns animations targeting this element
/// Spec: https://drafts.csswg.org/web-animations-1/#dom-animatable-getanimations
///
/// Returns sentinel for empty array (no animations without rendering engine)
pub fn call_getAnimations(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetAnimationsOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // Returns undefined (empty array) - no animations without rendering engine
    return runtime.JSValue.jsUndefined;
}

/// Operation: getElementsByClassName
/// DOM §4.10.5 - Returns HTMLCollection of descendants with all given class names
/// Spec: https://dom.spec.whatwg.org/#dom-element-getelementsbyclassname
pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const names_slice = classNames.asSlice();

    // Create HTMLCollection
    const collection = interfaces.HTMLCollection.init(
        internal.allocator,
        instance.ctx,
    ) catch return error.OutOfMemory;
    errdefer interfaces.HTMLCollection.deinit(collection);

    // DOM "list of elements with class names", steps 1–3: an empty
    // ordered set gives an empty list; otherwise filter live descendants.
    var classes = std.mem.tokenizeAny(u8, names_slice, "\t\n\x0c\r ");
    if (classes.next() != null)
        try @import("dom").live_collections.elementsWithClassNames(collection, instance, names_slice);

    return collection;
}

/// Operation: insertAdjacentElement
/// DOM §4.10.7 - Insert element at specified position relative to this element
/// Spec: https://dom.spec.whatwg.org/#dom-element-insertadjacentelement
///
/// The insertAdjacentElement(where, element) method steps are to return the result of
/// running insert adjacent, given this, where, and element.
///
/// Position values (case-insensitive):
/// - "beforebegin": Before this element (as a sibling)
/// - "afterbegin": Inside this element, before first child
/// - "beforeend": Inside this element, after last child
/// - "afterend": After this element (as a sibling)
pub fn call_insertAdjacentElement(instance: *runtime.Instance, where: runtime.DOMString, element: *runtime.Instance) anyerror!?*runtime.Instance {
    // insertAdjacent returns null if parent is null for beforebegin/afterend positions
    return insertAdjacent(instance, where.asSlice(), element);
}

/// Operation: webkitMatchesSelector
/// Legacy alias for matches() - Returns true if element matches the given selector
/// Spec: https://dom.spec.whatwg.org/#dom-element-webkitmatchesselector
pub fn call_webkitMatchesSelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!bool {
    // webkitMatchesSelector is an alias for matches()
    return call_matches(instance, selectors);
}

/// Operation: spatialNavigationSearch
/// CSS Spatial Navigation §5 - Searches for next focusable element in direction
/// Spec: https://drafts.csswg.org/css-nav-1/#dom-element-spatialnavigationsearch
///
/// Note: Returns null - spatial navigation not implemented without layout engine
pub fn call_spatialNavigationSearch(instance: *runtime.Instance, dir: enums.SpatialNavigationDirection, options: webidl.Opt(dictionaries.SpatialNavigationSearchOptions)) anyerror!?*runtime.Instance {
    _ = instance;
    _ = dir;
    _ = options;
    // Spatial navigation not implemented without layout engine - return null
    return null;
}

/// Operation: getElementsByTagName
/// Spec: https://dom.spec.whatwg.org/#dom-element-getelementsbytagname
///
/// "The getElementsByTagName(qualifiedName) method steps are to return the
/// list of elements with qualified name qualifiedName for this" - a LIVE
/// collection (dom.live_collections), which holds this element (refcount
/// design 5h). It was a snapshot, which neither saw later mutations nor
/// kept its root (crane/hd-retention-tagname.html).
pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const collection = interfaces.HTMLCollection.init(internal.allocator, instance.ctx) catch return error.OutOfMemory;
    errdefer interfaces.HTMLCollection.deinit(collection);
    try dom.live_collections.elementsWithQualifiedName(collection, instance, qualifiedName.asSlice());
    return collection;
}

/// Operation: closest
/// DOM §4.10.4 - Returns closest ancestor (or self) matching selector
/// Spec: https://dom.spec.whatwg.org/#dom-element-closest
pub fn call_closest(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!?*runtime.Instance {
    return dom.selector_matching.closest(instance, selectors.asSlice());
}

/// Operation: getSpatialNavigationContainer
/// CSS Spatial Navigation §5 - Returns spatial navigation container
/// Spec: https://drafts.csswg.org/css-nav-1/#dom-element-getspatialnavigationcontainer
///
/// Note: Returns null - spatial navigation not implemented
pub fn call_getSpatialNavigationContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    // Spatial navigation not implemented - return null
    return error.NotImplemented;
}

/// Operation: removeAttribute
/// DOM §4.8 - Removes the named attribute
pub fn call_removeAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!void {
    // "Remove an attribute given qualifiedName and this, and then return
    // undefined."
    try removeAttributeByName(instance, qualifiedName.asSlice());
}

/// Operation: convertRectFromNode
/// CSSOM View §6 - Converts a rect from another element's coordinate space
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-convertrectfromnode
///
/// Note: Returns null - requires layout engine for coordinate transformations
pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: typedefs.GeometryNode, options: webidl.Opt(dictionaries.ConvertCoordinateOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = rect;
    _ = from;
    _ = options;
    // Requires layout engine - return null
    return error.NotImplemented;
}

/// Operation: removeAttributeNode
/// DOM §4.8 - Removes the given Attr node from this element
/// Spec: https://dom.spec.whatwg.org/#dom-element-removeattributenode
///
/// The removeAttributeNode(attr) method steps are:
/// 1. If this's attribute list does not contain attr, then throw a "NotFoundError" DOMException.
/// 2. Remove attr.
/// 3. Return attr.
pub fn call_removeAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: "If this's attribute list does not contain attr, then throw a
    // "NotFoundError" DOMException." The list contains attr when attr is the
    // node made for one of its attributes.
    var iter = internal.data.attributeIterator();
    var index: usize = 0;
    const found = while (iter.next()) |entry| : (index += 1) {
        const link = entry.attr_node orelse continue;
        if (link.isLive() and link.instance == attr) break true;
    } else false;
    if (!found) return error.NotFoundError;

    // Step 2: "Remove attr." - which sets attr's element to null.
    removeAttributeAt(instance, internal, index);

    // Step 3: "Return attr."
    return attr;
}

/// Operation: removeAttributeNS
/// DOM §4.8 - Removes the attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-removeattributens
pub fn call_removeAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!void {
    // "Remove an attribute given namespace, localName, and this, and then
    // return undefined."
    removeAttributeByNamespaceAndLocalName(instance, if (namespace) |ns| ns.asSlice() else null, localName.asSlice());
}

/// Operation: insertAdjacentText
/// DOM §4.10.7 - Creates a Text node and inserts it at specified position
/// Spec: https://dom.spec.whatwg.org/#dom-element-insertadjacenttext
///
/// The insertAdjacentText(where, data) method steps are:
/// 1. Let text be a new Text node whose data is data and node document is this's node document.
/// 2. Run the insert adjacent algorithm given this, where, and text.
pub fn call_insertAdjacentText(instance: *runtime.Instance, where: runtime.DOMString, data: runtime.DOMString) anyerror!void {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: create Text with the given data and this's node document.
    const text_node = interfaces.Text.initWith(instance.ctx.allocator, instance.ctx, .{ .data = data.asSlice() }) catch return error.OutOfMemory;
    errdefer interfaces.Text.deinit(text_node);
    const owner = (try interfaces.Node.get_ownerDocument(instance)) orelse return error.InvalidStateError;
    try dom.node_document.set(text_node, owner);

    // Step 2: Run insert adjacent algorithm
    _ = try insertAdjacent(instance, where.asSlice(), text_node);
}

/// Operation: requestFullscreen
/// Fullscreen API §4.1 - Requests fullscreen mode for this element
/// Spec: https://fullscreen.spec.whatwg.org/#dom-element-requestfullscreen
///
/// Note: Returns sentinel - fullscreen requires browser integration
pub fn call_requestFullscreen(instance: *runtime.Instance, options: webidl.Opt(dictionaries.FullscreenOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // Fullscreen requires browser integration - return undefined
    // TODO: Should return a rejected Promise with TypeError
    return runtime.JSValue.jsUndefined;
}

/// Operation: animate
/// Web Animations §4.4.3 - Creates and runs a new Animation
/// Spec: https://drafts.csswg.org/web-animations-1/#dom-animatable-animate
///
/// Note: Returns null - requires Web Animations API and rendering engine
pub fn call_animate(instance: *runtime.Instance, keyframes: ?runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    _ = instance;
    _ = keyframes;
    _ = options;
    // Animation requires rendering engine - return null
    return error.NotImplemented;
}

/// Operation: getHTML
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-gethtml
///
/// "Return the result of HTML fragment serialization algorithm with this,
/// options["serializableShadowRoots"], and options["shadowRoots"]."
pub fn call_getHTML(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetHTMLOptions)) anyerror!runtime.DOMString {
    _ = getInternal(instance) orelse return error.InvalidStateError;
    const given = options.getOrDefault(.{});
    return @import("html").serialization.fragmentWithShadowRoots(instance, given.serializableShadowRoots orelse false, given.shadowRoots orelse &.{});
}

/// Operation: getAttributeNode
/// DOM §4.8 - Returns the Attr node with the given qualified name
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributenode
///
/// The getAttributeNode(qualifiedName) method steps are to return the result of
/// getting an attribute given qualifiedName and this.
pub fn call_getAttributeNode(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // "Return the result of getting an attribute given qualifiedName and
    // this."
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualifiedName.asSlice(), &buffer);
    defer name.deinit(internal.allocator);
    const index = internal.data.indexOfQualifiedName(name.slice) orelse return null;
    return try ensureAttrNode(instance, internal, index);
}

/// Operation: startViewTransition
/// View Transitions API - Starts a view transition
/// Spec: https://drafts.csswg.org/css-view-transitions-1/#dom-document-startviewtransition
///
/// Note: Returns null - View Transitions require rendering engine
pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    _ = instance;
    _ = callbackOptions;
    // View Transitions require rendering engine - return null
    return error.NotImplemented;
}

/// HTML 8.5.2 setHTML, steps 1–2: template contents, then safe filtering.
pub fn call_setHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(dictionaries.SetHTMLOptions)) anyerror!void {
    var converted = try @import("html").sanitizer.convertOptions(instance.ctx, options.getOrDefault(.{}).sanitizer, true);
    defer converted.deinit();
    const target = try dom.template_contents.insertionTarget(instance);
    try @import("html").sanitizer.setHTML(instance, target, html.asSlice(), &converted, true, true);
}

/// HTML 8.5.2 setHTMLUnsafe, steps 1–3.
pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: typedefs.TrustedHTMLOrDOMString, options: webidl.Opt(dictionaries.SetHTMLUnsafeOptions)) anyerror!void {
    var converted = try @import("html").sanitizer.convertOptions(instance.ctx, options.getOrDefault(.{}).sanitizer, false);
    defer converted.deinit();
    // Step 1: "Let compliantHTML be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, this's relevant
    // global object, html, "Element setHTMLUnsafe", and "script"."
    const allocator = instance.ctx.allocator;
    const compliant = try dom.trusted_types.compliantStringFor(allocator, .html, instance, html, "Element setHTMLUnsafe");
    defer allocator.free(compliant);
    // Step 2: "Let target be this's template contents if this is a template
    // element; otherwise this."
    const target = try dom.template_contents.insertionTarget(instance);
    // Step 3: configure, parse, sanitize, and replace children.
    try @import("html").sanitizer.setHTML(instance, target, compliant, &converted, false, options.getOrDefault(.{}).sanitizer != null);
}

/// Operation: scrollIntoView
/// CSSOM View §5.1 - Scrolls this element into view
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-scrollintoview
///
/// Without a layout engine, this is a no-op (returns sentinel for undefined)
pub fn call_scrollIntoView(instance: *runtime.Instance, arg: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = instance;
    _ = arg;
    // No-op without layout engine - returns undefined
    // TODO: Should return a resolved Promise<undefined>
    return runtime.JSValue.jsUndefined;
}

/// Operation: hasAttributes
/// DOM §4.8 - Returns true if the element has any attributes
/// Spec: https://dom.spec.whatwg.org/#dom-element-hasattributes
pub fn call_hasAttributes(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.data.getAttributeCount() > 0;
}

/// Operation: hasPointerCapture
/// Pointer Events §5.4.4 - Checks if element has pointer capture
/// Spec: https://w3c.github.io/pointerevents/#dom-element-haspointercapture
///
/// Without pointer event support, always returns false
pub fn call_hasPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!bool {
    _ = instance;
    _ = pointerId;
    // No pointer capture without pointer event support
    return false;
}

/// Operation: toggleAttribute
/// DOM §4.8 - Toggles the named attribute: removes it if present, adds it if not
/// Spec: https://dom.spec.whatwg.org/#dom-element-toggleattribute
///
/// Steps:
/// 1. If qualifiedName is invalid, throw InvalidCharacterError
/// 2. If HTML element in HTML document, lowercase qualifiedName
/// 3. If attribute exists and force is not true, remove it and return false
/// 4. If attribute doesn't exist and force is not false, add it with empty value and return true
/// 5. Return whether attribute now exists
pub fn call_toggleAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, force: webidl.Opt(bool)) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: "If qualifiedName is not a valid attribute local name, then
    // throw an "InvalidCharacterError" DOMException."
    if (!dom.names.isValidAttributeLocalName(qualifiedName.asSlice())) return error.InvalidCharacterError;

    // Step 2: lowercase for an HTML element in an HTML document.
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualifiedName.asSlice(), &buffer);
    defer name.deinit(internal.allocator);

    // Step 3: "Let attribute be the first attribute in this's attribute list
    // whose qualified name is qualifiedName, and null otherwise."
    const index = internal.data.indexOfQualifiedName(name.slice) orelse {
        // Step 4.1: "If force is not given or is true, create an attribute
        // whose local name is qualifiedName, value is the empty string, and
        // node document is this's node document, then append this attribute
        // to this, and then return true."
        if (!force.was_passed or force.value) {
            try appendAttribute(instance, internal, null, null, name.slice, "");
            return true;
        }
        // Step 4.2: "Return false."
        return false;
    };

    // Step 5: "Otherwise, if force is not given or is false, remove an
    // attribute given qualifiedName and this, and then return false." The
    // attribute that removes is the one step 3 found.
    if (!force.was_passed or !force.value) {
        removeAttributeAt(instance, internal, index);
        return false;
    }

    // Step 6: "Return true."
    return true;
}

/// Operation: pseudo
/// CSSOM §6.1 - Returns a CSSPseudoElement for the given pseudo-element type
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-pseudo
///
/// Note: Returns null - requires CSSOM and pseudo-element support
pub fn call_pseudo(instance: *runtime.Instance, @"type": typedefs.CSSOMString) anyerror!?*runtime.Instance {
    _ = instance;
    _ = @"type";
    // Requires CSSOM and pseudo-element support - return null
    return error.NotImplemented;
}

/// Operation: setAttribute
/// Spec: https://dom.spec.whatwg.org/#dom-element-setattribute
pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, value: typedefs.TrustedTypeOrDOMString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: "If qualifiedName is not a valid attribute local name, then
    // throw an "InvalidCharacterError" DOMException." It is only used as a
    // qualified name to find an attribute that already has it; a new one
    // takes it as its local name.
    if (!dom.names.isValidAttributeLocalName(qualifiedName.asSlice())) return error.InvalidCharacterError;

    // Step 2: lowercase for an HTML element in an HTML document.
    var buffer: [64]u8 = undefined;
    const name = try lookupName(instance, internal, qualifiedName.asSlice(), &buffer);
    defer name.deinit(internal.allocator);

    // Step 3: "Let verifiedValue be the result of calling get trusted type
    // compliant attribute value with qualifiedName, null, this, and value."
    // A default policy runs script: step 4 looks the attribute up after it.
    const verified = try dom.trusted_types.getCompliantAttributeValue(internal.allocator, name.slice, null, instance, dom.trusted_types.inputFrom(value));
    defer internal.allocator.free(verified);

    // Step 4: "Let attribute be the first attribute in this's attribute list
    // whose qualified name is qualifiedName, and null otherwise."
    // Step 5: "If attribute is non-null, then change attribute to
    // verifiedValue and return."
    if (internal.data.indexOfQualifiedName(name.slice)) |index| {
        return changeAttribute(instance, internal, index, verified);
    }

    // Steps 6 and 7: "Set attribute to a new attribute whose local name is
    // qualifiedName, value is verifiedValue, and node document is this's node
    // document. Append attribute to this."
    try appendAttribute(instance, internal, null, null, name.slice, verified);
}

// =============================================================================
// Event handler content attributes (HTML §8.1.8.1)
// =============================================================================

/// The attribute change steps that synchronize event handler content
/// attributes with event handlers.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-attributes
/// "1. If namespace is not null, or localName is not the name of an event
///  handler content attribute on element, then return.
///  2. Let eventTarget be the result of determining the target of an event
///  handler given element and localName.
///  3. If value is null, then deactivate an event handler given eventTarget and
///  localName.
///  4. Otherwise: ... set eventHandler's value to the internal raw uncompiled
///  handler value/location."
///
/// Nothing did this before, so `<body onload="...">` - and every `onload=`,
/// `onerror=`, `onclick=` attribute on any element - never ran. Pages that
/// start their tests from `<body onload>` (all of encoding/legacy-mb-*) waited
/// out the harness timeout on every variant.
///
/// Deviation, stated: the spec keeps the value as an internal raw uncompiled
/// handler and compiles it the first time the handler's current value is
/// needed. For an element whose document has a browsing context this compiles
/// it here, at attribute-change time: Crane's handler maps hold a compiled
/// function under a pointer tag, and all four tag values are taken. What that
/// changes: a syntax error surfaces when the attribute is set rather than when
/// the event first fires, and the scope chain captures the element's document
/// at set time. The function is otherwise the spec's: same name, same
/// parameters, same object environments, and it is assigned through the event
/// handler IDL attribute, so getters, dispatch and removal all see one handler.
///
/// An element whose document has NO browsing context - a template's
/// contents, the inert document of a sanitizing fragment parse, DOMParser's -
/// gets the spec's raw uncompiled handler (`rawEventHandlerSteps`): scripting
/// is disabled there, so its current value is null, and once the element is
/// adopted into a document with a browsing context the first read or dispatch
/// compiles it there (`compileRawEventHandler`). Compiling at adoption would
/// run script (error reports, the IDL setter) in the middle of insertion.
fn eventHandlerAttributeChangeSteps(instance: *runtime.Instance, local_name: []const u8, value: ?[]const u8) void {
    // Step 1: only unnamespaced "on..." attributes of HTML elements. Whether
    // the name really is an event handler of the target is checked below,
    // against the target's own IDL attributes.
    if (!std.mem.startsWith(u8, local_name, "on") or local_name.len <= 2) return;
    const internal = getInternal(instance) orelse return;
    const ns = if (internal.data.namespace_uri) |n| n.asSlice() else return;
    if (!std.mem.eql(u8, ns, "http://www.w3.org/1999/xhtml")) return;

    // Step 2: determining the target of an event handler.
    const document = (interfaces.Node.get_ownerDocument(instance) catch null) orelse return;
    const element_name = internal.data.local_name.asSlice();
    const forwards_to_window = (std.mem.eql(u8, element_name, "body") or std.mem.eql(u8, element_name, "frameset")) and
        dom.event_handlers.isWindowReflecting(local_name);

    // A document with no browsing context: a window-reflecting handler has
    // no target (determining the target, step 3: its document is not an
    // active document), and the element's own is a raw uncompiled handler.
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse {
        if (!forwards_to_window) rawEventHandlerSteps(instance, local_name, value);
        return;
    };
    // A document sandboxed without allow-scripts: "getting the current value
    // of the event handler" step 1.2 returns null while "document's active
    // sandboxing flag set has its sandboxed scripts browsing context flag
    // set", so nothing is compiled. The element's own handler is the spec's
    // internal raw uncompiled handler (it compiles only once the element is
    // in a document that runs script); a window-reflecting one is never set.
    if (dom.document_scripts.scriptsSandboxed(document)) {
        if (!forwards_to_window) rawEventHandlerSteps(instance, local_name, value);
        return;
    }
    const target: *runtime.Instance = if (forwards_to_window) window else instance;
    _ = compileEventHandlerAttribute(instance, document, target, forwards_to_window, local_name, value);
}

/// Steps 1-5 of the attribute change steps with the handler compiled now
/// (see the deviation above), for `instance`'s attribute `local_name` whose
/// handler's target is `target` - the element, or its document's window for
/// a body's window-reflecting handler. False when the name is not an event
/// handler of the target's, or no engine stands behind the realm.
fn compileEventHandlerAttribute(
    instance: *runtime.Instance,
    document: *runtime.Instance,
    target: *runtime.Instance,
    forwards_to_window: bool,
    local_name: []const u8,
    value: ?[]const u8,
) bool {
    // The settings object is the document's (step 3.5), and the handler is
    // compiled and set in its realm. A realm with no engine behind it (a DOM
    // unit test) runs no script, so there is no handler to compile: every
    // engine error below leaves the content attribute a plain attribute.
    const realm = document.ctx;
    const target_value: runtime.JSValue = .{ .instance = target };

    // "localName is the name of an event handler content attribute on
    // element": the target exposes an event handler IDL attribute of that name.
    if (!(engine.hasProperty(realm, target_value, local_name) catch return false)) return false;

    // Step 3: deactivate. The IDL attribute set to null clears the handler.
    const body = value orelse {
        engine.setProperty(realm, target_value, local_name, runtime.JSValue.jsNull) catch {};
        return true;
    };

    // Step 5.1: "If the Should element's inline behavior be blocked by
    // Content Security Policy? algorithm returns "Blocked" when executed upon
    // element, "script attribute", and value, then return." The handler is
    // not compiled, and its value stays what it was.
    if (dom.csp_violations.shouldBlockInline(instance, .script_attribute, body, .{})) return true;

    // Getting the current value of the event handler, step 3: the function,
    // compiled in the settings object's realm. Its scope (3.9) is the global
    // environment, then - for an element's handler - the document and the
    // element itself; a Window's handler (a body's onload) gets neither.
    // TODO: the form owner's object environment between the two.
    // The script's URL is the document's (OWNED: the getter's copy).
    const url = interfaces.Document.get_URL(document) catch return true;
    defer document.ctx.allocator.free(url);
    const source: engine.EventHandlerSource = .{
        .body = body,
        .name = local_name,
        .url = url,
        // Where the attribute is, for errors: not recorded.
        .lineno = 0,
        .parameters = if (forwards_to_window and std.mem.eql(u8, local_name, "onerror")) .onerror else .event,
        .document = if (forwards_to_window) null else document,
        .form_owner = null,
        .element = if (forwards_to_window) null else instance,
    };
    // Step 3.7: a body that does not parse is reported for the settings
    // object's global (the reporter), and leaves the handler null.
    const compiled = engine.compileEventHandler(realm, &source, .{ .report = reportException, .host = realm }) catch return true;
    const function = compiled orelse {
        engine.setProperty(realm, target_value, local_name, runtime.JSValue.jsNull) catch {};
        return true;
    };
    defer function.release();

    // Step 3.12: the handler's value is the function - through the IDL
    // attribute, which stores it exactly as `element.onload = fn` would.
    engine.setProperty(realm, target_value, local_name, function.value) catch {};
    return true;
}

/// The names of the event handler content attributes every HTML element
/// has: GlobalEventHandlers' attribute members, which HTMLElement includes
/// (HTML 8.1.8.2). A body's or frameset's WindowEventHandlers are its
/// window's, and with no browsing context they have no target.
const global_event_handler_names = blk: {
    @setEvalBranchQuota(20_000);
    const decls = @typeInfo(mixins.GlobalEventHandlers).@"struct".decls;
    var names: [decls.len]struct { []const u8 } = undefined;
    var count: usize = 0;
    for (decls) |decl| {
        if (!std.mem.startsWith(u8, decl.name, "get_on")) continue;
        names[count] = .{decl.name["get_".len..]};
        count += 1;
    }
    break :blk std.StaticStringMap(void).initComptime(names[0..count]);
};

/// Steps 1-5 of the attribute change steps for an element whose document
/// has no browsing context: step 3's deactivation for a removed attribute,
/// else step 5 - the CSP check against that document, then the handler's
/// value is "the internal raw uncompiled handler", activated
/// (dom.event_handlers.setRaw). Nothing is compiled, and no script can run:
/// the name is checked against the attribute list natively, not through the
/// element's IDL attributes, which would wrap the element.
fn rawEventHandlerSteps(instance: *runtime.Instance, local_name: []const u8, value: ?[]const u8) void {
    if (!global_event_handler_names.has(local_name)) return;
    const event_type = dom.event_handlers.eventTypeOf(local_name);
    const body = value orelse {
        // Step 3: deactivate - the map's value and the listener go.
        dom.event_handlers.set(typedefs.EventHandler, instance, event_type, null) catch {};
        return;
    };
    // Step 5.1, against the element's document's policies.
    if (dom.csp_violations.shouldBlockInline(instance, .script_attribute, body, .{})) return;
    dom.event_handlers.setRaw(instance, event_type) catch {};
}

/// "Getting the current value of the event handler" step 1 for a raw
/// uncompiled handler of `target`'s (dom.event_handlers.compileRaw): step 1.2,
/// "if scripting is disabled for document, then return null" - with no
/// browsing context it stays raw - then the body, which is the content
/// attribute (any change to it reruns the attribute change steps), compiled
/// in the element's current document and set as the value.
///
/// Deviation, stated: the CSP check (attribute change step 5.1) runs again
/// here, against the document the element is in now. The spec runs it only
/// when the attribute is set - against a document with no browsing context,
/// whose policies are empty - so an element parsed into a template or an
/// inert fragment and adopted into a page whose policy forbids inline
/// handlers would run its handler. Blink checks the window's policy for a
/// template document's element (its execution context is the window's,
/// Document::AllowInlineEventHandler), which this matches.
fn compileRawEventHandler(target: *runtime.Instance, event_type: []const u8) dom.event_handlers.RawCompile {
    // The content attribute: "on" and the event type, lowercased (the four
    // legacy WebKit types are mixed-case; every handler name is lowercase).
    var name_buffer: [64]u8 = undefined;
    if (event_type.len + 2 > name_buffer.len) return .settled;
    @memcpy(name_buffer[0..2], "on");
    const local_name = name_buffer[0 .. event_type.len + 2];
    _ = std.ascii.lowerString(local_name[2..], event_type);

    const document = (interfaces.Node.get_ownerDocument(target) catch null) orelse return .scripting_disabled;
    if ((interfaces.Document.get_defaultView(document) catch null) == null) return .scripting_disabled;
    // Step 1.2's other half: "or document's active sandboxing flag set has
    // its sandboxed scripts browsing context flag set, then return null."
    if (dom.document_scripts.scriptsSandboxed(document)) return .scripting_disabled;
    const internal = getInternal(target) orelse return .settled;
    // The body, copied: compiling reports errors, and the script that runs
    // can change the attribute under a borrowed slice.
    const attribute = dom.element_data.getAttributeByNamespaceAndLocalName(&internal.data, null, local_name) orelse return .settled;
    const body = target.ctx.allocator.dupe(u8, attribute.value) catch return .settled;
    defer target.ctx.allocator.free(body);
    _ = compileEventHandlerAttribute(target, document, target, false, local_name, body);
    return .settled;
}

/// HTML 3.2.6.5, the style attribute, when it "is added or has its value
/// changed" - by the parser, setAttribute, an Attr node, cloning: every
/// write reaches here, as the attribute change steps of an attribute in no
/// namespace named "style" on an element with ElementCSSInlineStyle (HTML,
/// SVG and MathML elements). "However, if the Should element's inline
/// behavior be blocked by Content Security Policy? algorithm returns
/// "Blocked" when executed upon the attribute's element, "style attribute",
/// and the attribute's value, then the style rules defined in the
/// attribute's value must not be applied to the element." Removing the
/// attribute is not checked: there is nothing to apply.
///
/// CSSOM's own writes (element.style) would set the attribute with the
/// declaration block's updating flag set, and its attribute change steps
/// then do nothing; Crane's CSSOM does not write the attribute back at all,
/// so they never reach here.
///
/// Not modelled, stated: an allowed value is not parsed into the element's
/// inline declaration block (CSSOM's attribute change steps for it) - nothing
/// reflects the style attribute into element.style yet; that step goes after
/// this check. Blink, Gecko and WebKit skip the check for an attribute
/// copied by cloning (WPT style-src/inline-style-allowed-while-cloning-
/// objects reads the clone's style); HTML has no such exception, and with no
/// declaration block to fill, this checks every write.
fn styleAttributeChangeSteps(instance: *runtime.Instance, internal: *InternalState, value: ?[]const u8) void {
    const v = value orelse return;
    const ns = if (internal.data.namespace_uri) |n| n.asSlice() else return;
    if (!std.mem.eql(u8, ns, "http://www.w3.org/1999/xhtml") and
        !std.mem.eql(u8, ns, "http://www.w3.org/2000/svg") and
        !std.mem.eql(u8, ns, "http://www.w3.org/1998/Math/MathML")) return;
    if (dom.csp_violations.shouldBlockInline(instance, .style_attribute, v, .{})) return;
    // TODO(cssom): parse `v` into the element's inline declaration block.
}

/// HTML "report an exception" for the global of the realm the engine names -
/// an event handler's settings object's - or else `host`'s.
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const fallback: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse fallback;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}

/// Operation: insertAdjacentHTML
/// DOM Parsing §3.4 - Parses HTML and inserts it at the specified position
/// Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-element-insertadjacenthtml
///
/// Position values:
/// - "beforebegin": Before the element itself
/// - "afterbegin": Just inside the element, before its first child
/// - "beforeend": Just inside the element, after its last child
/// - "afterend": After the element itself
///
pub fn call_insertAdjacentHTML(instance: *runtime.Instance, position: runtime.DOMString, string: typedefs.TrustedHTMLOrDOMString) anyerror!void {
    // Step 1: "Let compliantString be the result of invoking the get trusted
    // type compliant string algorithm with TrustedHTML, this's relevant
    // global object, string, "Element insertAdjacentHTML", and "script"."
    const allocator = instance.ctx.allocator;
    const compliant = try dom.trusted_types.compliantStringFor(allocator, .html, instance, string, "Element insertAdjacentHTML");
    defer allocator.free(compliant);
    // HTML 8.5.6 steps 2–3: choose a context or throw before parsing.
    const Position = enum { beforebegin, afterbegin, beforeend, afterend };
    const where: Position = blk: {
        inline for (std.meta.fields(Position)) |field| {
            if (std.ascii.eqlIgnoreCase(position.asSlice(), field.name)) break :blk @enumFromInt(field.value);
        }
        return error.SyntaxError;
    };
    var context = switch (where) {
        .beforebegin, .afterend => (try interfaces.Node.get_parentNode(instance)) orelse return error.NoModificationAllowedError,
        .afterbegin, .beforeend => instance,
    };
    const context_type = try interfaces.Node.get_nodeType(context);
    if (context_type == interfaces.Node.get_DOCUMENT_NODE()) return error.NoModificationAllowedError;

    // Step 4: a fragment/shadow parent, or an HTML document's html element,
    // uses a fresh HTML body only as the parsing context, never as the target.
    var temporary_body: ?*runtime.Instance = null;
    defer if (temporary_body) |body| dom.node_creation.destroyUninserted(body);
    const use_body = if (context_type != interfaces.Node.get_ELEMENT_NODE()) true else blk: {
        const state = getInternal(context) orelse return error.InvalidStateError;
        if (!std.mem.eql(u8, state.data.local_name.asSlice(), "html")) break :blk false;
        const namespace = state.data.namespace_uri orelse break :blk false;
        if (!std.mem.eql(u8, namespace.asSlice(), infra.namespaces.HTML_NAMESPACE)) break :blk false;
        const document = (try interfaces.Node.get_ownerDocument(context)) orelse return error.InvalidStateError;
        break :blk dom.document_internals.getDocumentType(document) == .html;
    };
    if (use_body) {
        const document = (try interfaces.Node.get_ownerDocument(instance)) orelse return error.InvalidStateError;
        context = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(infra.namespaces.HTML_NAMESPACE), runtime.DOMString.initInterned("body"), .notPassed());
        temporary_body = context;
    }

    // Step 5: the existing fragment parser owns parsing and upgrades.
    const fragment = try @import("html").dom_parser.parseFragment(allocator, instance.ctx, compliant, context);
    defer dom.node_creation.destroyUninserted(fragment);
    const fragment_base = dom.instance_bridge.getNodeBase(@ptrCast(fragment)) orelse return error.InvalidStateError;

    // Step 6: insert the whole fragment within the calling IDL member's
    // reaction scope. Unlike innerHTML, template gets ordinary child nodes.
    const parent = switch (where) {
        .beforebegin, .afterend => (try interfaces.Node.get_parentNode(instance)) orelse return error.NotFoundError,
        .afterbegin, .beforeend => instance,
    };
    const parent_base = dom.instance_bridge.getNodeBase(@ptrCast(parent)) orelse return error.InvalidStateError;
    const reference = switch (where) {
        .beforebegin => instance,
        .afterbegin => try interfaces.Node.get_firstChild(instance),
        .afterend => try interfaces.Node.get_nextSibling(instance),
        .beforeend => null,
    };
    const reference_base: ?*dom.NodeBase = if (reference) |node| dom.instance_bridge.getNodeBase(@ptrCast(node)) orelse return error.InvalidStateError else null;
    if (where == .beforeend) {
        _ = try dom.mutation.append(fragment_base, parent_base);
    } else {
        try dom.mutation.insert(fragment_base, parent_base, reference_base, false);
    }
}

/// Operation: checkVisibility
/// CSSOM View §3.1 - Checks if the element would be visible
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-checkvisibility
///
/// Returns true if the element is potentially visible (connected, rendered, not hidden).
/// Without a layout engine, we assume elements are visible if they exist.
pub fn call_checkVisibility(instance: *runtime.Instance, options: webidl.Opt(dictionaries.CheckVisibilityOptions)) anyerror!bool {
    _ = instance;
    _ = options; // Layout-related options can't be checked without a layout engine

    // Without a layout engine, we assume all elements are visible
    // A proper implementation would check:
    // - computed display != none
    // - computed visibility != hidden (if checkVisibilityCSS)
    // - opacity > 0 (if checkOpacity)
    // - not a content-visibility: hidden element (if contentVisibilityAuto)
    return true;
}

/// Operation: getAttributeNames
/// DOM §4.8 - Returns the qualified names of all attributes in order
/// Spec: https://dom.spec.whatwg.org/#dom-element-getattributenames
///
/// Returns a sequence of DOMStrings (the qualified names of attributes).
/// Note: These are not guaranteed to be unique.
pub fn call_getAttributeNames(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // "Return the qualified names of the attributes in this's attribute list,
    // in order; otherwise a new list." A sequence<DOMString> is a new Array
    // of the current realm: an impl's return value is the JavaScript value,
    // as in URLSearchParams.getAll.
    const allocator = internal.allocator;
    const values = try allocator.alloc(runtime.JSValue, internal.data.getAttributeCount());
    defer allocator.free(values);
    // The qualified names made here ("prefix:localName"); a local name alone
    // is BORROWED from the attribute list for the call.
    var made: std.ArrayListUnmanaged([]u8) = .empty;
    defer {
        for (made.items) |name| allocator.free(name);
        made.deinit(allocator);
    }

    var iter = internal.data.attributeIterator();
    var index: usize = 0;
    while (iter.next()) |entry| : (index += 1) {
        const qualified_name: []const u8 = if (entry.prefix) |prefix| name: {
            try made.ensureUnusedCapacity(allocator, 1);
            const joined = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ prefix, entry.local_name });
            made.appendAssumeCapacity(joined);
            break :name joined;
        } else entry.local_name;
        values[index] = runtime.JSValue.fromStringRef(qualified_name);
    }

    // OWNED, handed to the binding.
    const array = try engine.createSequenceOfValues(engine.currentRealm() orelse instance.ctx, values[0..index]);
    return array.take();
}

/// Operation: attachShadow
/// DOM §4.9 - Attaches a shadow root to this element
/// Spec: https://dom.spec.whatwg.org/#dom-element-attachshadow
///
/// DOM attachShadow steps 1–5.
pub fn call_attachShadow(instance: *runtime.Instance, init_data: dictionaries.ShadowRootInit) anyerror!*runtime.Instance {
    const document = (try interfaces.Node.get_ownerDocument(instance)) orelse return error.InvalidStateError;
    const document_registry = try interfaces.Document.get_customElementRegistry(document);
    // Steps 1–2: an omitted member uses the document's registry; null stays null.
    const registry = init_data.customElementRegistry.getOrDefault(document_registry);
    if (registry) |value| {
        // The member is a `CustomElementRegistry?`: WebIDL converts a value
        // to an interface type only if it implements that interface (3.2.21),
        // else TypeError. The binding hands interface-typed dictionary
        // members over as any platform object, so the check is here; read
        // as a registry, another object's state was a garbage cast (CE2-M1).
        if (value.stateAs(interfaces.CustomElementRegistry.State) == null) return error.TypeError;
        if (!dom.custom_elements.isScoped(value) and value != document_registry) return error.NotSupportedError;
    }
    return attachShadow(instance, init_data, registry);
}

/// DOM attach-a-shadow-root, also used by cloning with an explicit registry.
fn attachShadow(instance: *runtime.Instance, init_data: dictionaries.ShadowRootInit, registry: ?*runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // "attach a shadow root", given element, mode, clonable, serializable,
    // delegatesFocus and slotAssignment:

    // Step 1: "If element's namespace is not the HTML namespace, then throw a
    // NotSupportedError DOMException."
    const namespace = if (internal.data.namespace_uri) |ns| ns.asSlice() else "";
    if (!std.mem.eql(u8, namespace, "http://www.w3.org/1999/xhtml")) return error.NotSupportedError;

    // Step 2: "If element's local name is not a valid shadow host name, then
    // throw a NotSupportedError DOMException." Only these hosts are ever
    // given a shadow root - and every one of them tears down through
    // Element.deinit, which is what releases it.
    const local_name = internal.data.local_name.asSlice();
    if (!isValidShadowHostName(local_name)) return error.NotSupportedError;

    // Step 3: "If element's local name is a valid custom element name, or
    // element's is value is non-null": if its definition's disable shadow is
    // true, throw a NotSupportedError DOMException.
    if (dom.custom_elements.lookup(internal.custom_element_registry.get(), namespace, local_name, if (internal.is_value) |value| value.asSlice() else null)) |definition| {
        if (definition.disable_shadow) return error.NotSupportedError;
    }

    // Step 4: "If element is a shadow host":
    if (internal.shadow_root) |current| {
        // 4.1-4.2: "If currentShadowRoot's declarative is false, or its mode
        // is not mode, then throw a NotSupportedError DOMException."
        if (!dom.declarative_shadow.isDeclarative(current)) return error.NotSupportedError;
        if (try interfaces.ShadowRoot.get_mode(current) != init_data.mode) return error.NotSupportedError;
        // 4.3: "Remove all of currentShadowRoot's children, in tree order."
        while (try interfaces.Node.get_firstChild(current)) |child| _ = try interfaces.Node.call_removeChild(current, child);
        // 4.4: "Set currentShadowRoot's declarative to false."
        dom.declarative_shadow.setDeclarative(current, false);
        // 4.5: "Return." attachShadow then returns this's shadow root.
        return current;
    }

    // Steps 5–14: create and initialize through the shadow root's owner.
    const shadow_root = try dom.custom_elements.createShadow(instance, init_data, registry);

    // Step 13: "Set element's shadow root to shadow." The element keeps it
    // for its whole life - nothing else does - by an edge from its wrapper,
    // which script holds: it is calling this.
    internal.shadow_root = shadow_root;
    // The node's shadow host bit, the slot steps' fast-path guard
    // (NodeBase.is_shadow_host).
    if (dom.instance_bridge.getNodeBase(instance)) |base| base.is_shadow_host = true;
    // The shadow root's holds count in its host's chain (refcount, step 3).
    // Here, in the step itself, so every attach - scripted and declarative -
    // runs it.
    dom.shadow_hosts.attached(instance, shadow_root);
    internal.shadow_root_kept.made(shadow_root);
    internal.shadow_root_kept.handOut(instance, shadow_root, .{ .name = "shadowRoot" });
    // And the shadow root keeps its host, whose `host` it answers for its
    // whole life: script routinely holds only the shadow root
    // (`document.createElement("div").attachShadow(...)`). Blink traces it
    // (Node::Trace visits parent_or_shadow_host_node_), WebKit's shadow root
    // keeps its host. An edge each way, so the pair keep each other while
    // script holds either and go together once it holds neither. Drawn
    // second: until the host's edge above, nothing kept the shadow root's
    // new wrapper.
    engine.traceChild(shadow_root, instance, .{ .name = "host" });

    return shadow_root;
}

/// DOM: "A valid shadow host name is: a valid custom element name; "article",
/// "aside", "blockquote", "body", "div", "footer", "h1", "h2", "h3", "h4",
/// "h5", "h6", "header", "main", "nav", "p", "section", or "span"."
fn isValidShadowHostName(local_name: []const u8) bool {
    if (dom.names.isValidCustomElementName(local_name)) return true;
    const names = [_][]const u8{
        "article", "aside", "blockquote", "body",   "div",  "footer", "h1", "h2",      "h3",
        "h4",      "h5",    "h6",         "header", "main", "nav",    "p",  "section", "span",
    };
    for (names) |name| {
        if (std.mem.eql(u8, local_name, name)) return true;
    }
    return false;
}

/// Operation: requestPointerLock
/// Pointer Lock API §4.1 - Requests pointer lock on this element
/// Spec: https://w3c.github.io/pointerlock/#dom-element-requestpointerlock
///
/// Note: Returns sentinel - pointer lock requires browser integration
pub fn call_requestPointerLock(instance: *runtime.Instance, options: webidl.Opt(dictionaries.PointerLockOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    // Pointer lock requires browser integration - return undefined
    // TODO: Should return a rejected Promise with SecurityError
    return runtime.JSValue.jsUndefined;
}

/// Operation: hasAttributeNS
/// DOM §4.8 - Returns true if the element has an attribute with the given namespace and local name
/// Spec: https://dom.spec.whatwg.org/#dom-element-hasattributens
pub fn call_hasAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "If namespace is the empty string, then set it to null."
    const ns: ?[]const u8 = if (namespace) |n| (if (n.len() == 0) null else n.asSlice()) else null;
    // Step 2: "Return true if this has an attribute whose namespace is
    // namespace and local name is localName; otherwise false."
    return internal.data.findAttribute(ns, localName.asSlice()) != null;
}

/// Parse a CSS length value string and return pixels.
/// Supports: px, cm, mm, in, pt, pc (absolute units).
/// Returns null for unsupported units or invalid values.
/// Spec: https://drafts.csswg.org/css-values-4/#lengths
fn parseCssLengthToPixels(value: []const u8) ?f64 {
    const trimmed = std.mem.trim(u8, value, " \t\n\r");
    if (trimmed.len == 0) return null;

    // Find where the numeric part ends
    var numeric_end: usize = 0;
    var has_dot = false;

    for (trimmed, 0..) |c, i| {
        if (c == '-' and i == 0) {
            numeric_end = 1;
        } else if (c == '.' and !has_dot) {
            has_dot = true;
            numeric_end = i + 1;
        } else if (c >= '0' and c <= '9') {
            numeric_end = i + 1;
        } else {
            break;
        }
    }

    if (numeric_end == 0) return null;

    const numeric_str = trimmed[0..numeric_end];
    const unit_str = std.mem.trim(u8, trimmed[numeric_end..], " \t");

    const numeric_value = std.fmt.parseFloat(f64, numeric_str) catch return null;

    // Handle different units - convert to pixels
    // Spec: https://drafts.csswg.org/css-values-4/#absolute-lengths
    if (unit_str.len == 0) {
        // Unitless - in quirks mode this might be treated as px, but strictly it's invalid
        // For pragmatic compatibility, treat as px
        return numeric_value;
    } else if (std.ascii.eqlIgnoreCase(unit_str, "px")) {
        return numeric_value;
    } else if (std.ascii.eqlIgnoreCase(unit_str, "cm")) {
        return numeric_value * 37.7953; // 1cm = 37.7953px
    } else if (std.ascii.eqlIgnoreCase(unit_str, "mm")) {
        return numeric_value * 3.77953; // 1mm = 3.77953px
    } else if (std.ascii.eqlIgnoreCase(unit_str, "in")) {
        return numeric_value * 96.0; // 1in = 96px
    } else if (std.ascii.eqlIgnoreCase(unit_str, "pt")) {
        return numeric_value * (96.0 / 72.0); // 1pt = 96/72px
    } else if (std.ascii.eqlIgnoreCase(unit_str, "pc")) {
        return numeric_value * 16.0; // 1pc = 16px
    } else if (std.ascii.eqlIgnoreCase(unit_str, "q")) {
        return numeric_value * 0.944882; // 1Q = 0.944882px
    }

    // Relative units (em, rem, %, vw, vh, etc.) require layout context
    // Return null to indicate we can't compute the value
    return null;
}

/// Operation: getBoundingClientRect
/// CSSOM View §3.1 - Returns a DOMRect with the element's bounding box
/// Spec: https://drafts.csswg.org/cssom-view/#dom-element-getboundingclientrect
///
/// Returns a DOMRect representing the smallest rectangle containing the entire element.
/// For elements with inline CSS dimensions (width/height in pixels), returns those dimensions.
/// For elements without explicit dimensions or with relative units, returns zero dimensions.
pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidStateError;

    var width: f64 = 0;
    var height: f64 = 0;

    // Try to get CSS dimensions from the element's inline style: the
    // declarations the element keeps (dom.cssom.InlineStyle), not its
    // CSSStyleDeclaration's, so they survive V8 GC of the style wrapper
    if (dom.cssom.inlineStyleOf(instance)) |inline_style| {
        if (inline_style.getProperty("width")) |width_value| {
            if (parseCssLengthToPixels(width_value)) |w| {
                width = w;
            }
        }
        if (inline_style.getProperty("height")) |height_value| {
            if (parseCssLengthToPixels(height_value)) |h| {
                height = h;
            }
        }
    }

    // Return DOMRect with computed dimensions
    // x and y are 0 since we don't have layout position information
    return interfaces.DOMRect.call_constructor(
        instance.ctx,
        webidl.Opt(f64).passed(0), // x
        webidl.Opt(f64).passed(0), // y
        webidl.Opt(f64).passed(width), // width
        webidl.Opt(f64).passed(height), // height
    ) catch return error.OutOfMemory;
}

/// Operation: setPointerCapture
/// Pointer Events §5.4.2 - Sets pointer capture
/// Spec: https://w3c.github.io/pointerevents/#dom-element-setpointercapture
///
/// Without pointer event support, this is a no-op
pub fn call_setPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
    _ = instance;
    _ = pointerId;
    // No-op without pointer event support
}

/// Operation: ariaNotify
pub fn call_ariaNotify(instance: *runtime.Instance, announcement: runtime.DOMString, options: webidl.Opt(dictionaries.AriaNotificationOptions)) anyerror!void {
    _ = instance;
    _ = announcement;
    _ = options;
    return error.NotImplemented;
}

//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ShadowRootImpl = @import("impls").ShadowRoot;
const DocumentFragment = @import("interfaces").DocumentFragment;
const DocumentOrShadowRoot = @import("interfaces").DocumentOrShadowRoot;
const Element = @import("interfaces").Element;
const (TrustedHTML or DOMString) = @import("interfaces").(TrustedHTML or DOMString);
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const ShadowRootMode = @import("enums").ShadowRootMode;
const ObservableArray<CSSStyleSheet> = @import("interfaces").ObservableArray<CSSStyleSheet>;
const StyleSheetList = @import("interfaces").StyleSheetList;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const SlotAssignmentMode = @import("enums").SlotAssignmentMode;
const EventHandler = @import("typedefs").EventHandler;

pub const ShadowRoot = struct {
    pub const Meta = struct {
        pub const name = "ShadowRoot";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DocumentFragment;
        pub const MixinTypes = .{
            DocumentOrShadowRoot,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            mode: ShadowRootMode = undefined,
            delegatesFocus: bool = undefined,
            slotAssignment: SlotAssignmentMode = undefined,
            clonable: bool = undefined,
            serializable: bool = undefined,
            host: Element = undefined,
            onslotchange: EventHandler = undefined,
            innerHTML: (TrustedHTML or DOMString) = undefined,
            customElementRegistry: ?CustomElementRegistry = null,
            fullscreenElement: ?Element = null,
            pictureInPictureElement: ?Element = null,
            pointerLockElement: ?Element = null,
            styleSheets: StyleSheetList = undefined,
            adoptedStyleSheets: ObservableArray<CSSStyleSheet> = undefined,
            activeElement: ?Element = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ShadowRoot, .{
        .deinit_fn = &deinit_wrapper,

        .get_ATTRIBUTE_NODE = &DocumentFragment.get_ATTRIBUTE_NODE,
        .get_CDATA_SECTION_NODE = &DocumentFragment.get_CDATA_SECTION_NODE,
        .get_COMMENT_NODE = &DocumentFragment.get_COMMENT_NODE,
        .get_DOCUMENT_FRAGMENT_NODE = &DocumentFragment.get_DOCUMENT_FRAGMENT_NODE,
        .get_DOCUMENT_NODE = &DocumentFragment.get_DOCUMENT_NODE,
        .get_DOCUMENT_POSITION_CONTAINED_BY = &DocumentFragment.get_DOCUMENT_POSITION_CONTAINED_BY,
        .get_DOCUMENT_POSITION_CONTAINS = &DocumentFragment.get_DOCUMENT_POSITION_CONTAINS,
        .get_DOCUMENT_POSITION_DISCONNECTED = &DocumentFragment.get_DOCUMENT_POSITION_DISCONNECTED,
        .get_DOCUMENT_POSITION_FOLLOWING = &DocumentFragment.get_DOCUMENT_POSITION_FOLLOWING,
        .get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = &DocumentFragment.get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC,
        .get_DOCUMENT_POSITION_PRECEDING = &DocumentFragment.get_DOCUMENT_POSITION_PRECEDING,
        .get_DOCUMENT_TYPE_NODE = &DocumentFragment.get_DOCUMENT_TYPE_NODE,
        .get_ELEMENT_NODE = &DocumentFragment.get_ELEMENT_NODE,
        .get_ENTITY_NODE = &DocumentFragment.get_ENTITY_NODE,
        .get_ENTITY_REFERENCE_NODE = &DocumentFragment.get_ENTITY_REFERENCE_NODE,
        .get_NOTATION_NODE = &DocumentFragment.get_NOTATION_NODE,
        .get_PROCESSING_INSTRUCTION_NODE = &DocumentFragment.get_PROCESSING_INSTRUCTION_NODE,
        .get_TEXT_NODE = &DocumentFragment.get_TEXT_NODE,
        .get_activeElement = &get_activeElement,
        .get_adoptedStyleSheets = &get_adoptedStyleSheets,
        .get_baseURI = &get_baseURI,
        .get_childElementCount = &get_childElementCount,
        .get_childNodes = &get_childNodes,
        .get_children = &get_children,
        .get_clonable = &get_clonable,
        .get_customElementRegistry = &get_customElementRegistry,
        .get_delegatesFocus = &get_delegatesFocus,
        .get_firstChild = &get_firstChild,
        .get_firstElementChild = &get_firstElementChild,
        .get_fullscreenElement = &get_fullscreenElement,
        .get_host = &get_host,
        .get_innerHTML = &get_innerHTML,
        .get_isConnected = &get_isConnected,
        .get_lastChild = &get_lastChild,
        .get_lastElementChild = &get_lastElementChild,
        .get_mode = &get_mode,
        .get_nextSibling = &get_nextSibling,
        .get_nodeName = &get_nodeName,
        .get_nodeType = &get_nodeType,
        .get_nodeValue = &get_nodeValue,
        .get_onslotchange = &get_onslotchange,
        .get_ownerDocument = &get_ownerDocument,
        .get_parentElement = &get_parentElement,
        .get_parentNode = &get_parentNode,
        .get_pictureInPictureElement = &get_pictureInPictureElement,
        .get_pointerLockElement = &get_pointerLockElement,
        .get_previousSibling = &get_previousSibling,
        .get_serializable = &get_serializable,
        .get_slotAssignment = &get_slotAssignment,
        .get_styleSheets = &get_styleSheets,
        .get_textContent = &get_textContent,

        .set_adoptedStyleSheets = &set_adoptedStyleSheets,
        .set_innerHTML = &set_innerHTML,
        .set_nodeValue = &set_nodeValue,
        .set_onslotchange = &set_onslotchange,
        .set_textContent = &set_textContent,

        .call_addEventListener = &call_addEventListener,
        .call_append = &call_append,
        .call_appendChild = &call_appendChild,
        .call_cloneNode = &call_cloneNode,
        .call_compareDocumentPosition = &call_compareDocumentPosition,
        .call_contains = &call_contains,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getAnimations = &call_getAnimations,
        .call_getElementById = &call_getElementById,
        .call_getHTML = &call_getHTML,
        .call_getRootNode = &call_getRootNode,
        .call_hasChildNodes = &call_hasChildNodes,
        .call_insertBefore = &call_insertBefore,
        .call_isDefaultNamespace = &call_isDefaultNamespace,
        .call_isEqualNode = &call_isEqualNode,
        .call_isSameNode = &call_isSameNode,
        .call_lookupNamespaceURI = &call_lookupNamespaceURI,
        .call_lookupPrefix = &call_lookupPrefix,
        .call_moveBefore = &call_moveBefore,
        .call_normalize = &call_normalize,
        .call_prepend = &call_prepend,
        .call_querySelector = &call_querySelector,
        .call_querySelectorAll = &call_querySelectorAll,
        .call_removeChild = &call_removeChild,
        .call_removeEventListener = &call_removeEventListener,
        .call_replaceChild = &call_replaceChild,
        .call_replaceChildren = &call_replaceChildren,
        .call_setHTMLUnsafe = &call_setHTMLUnsafe,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ShadowRootImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ShadowRootImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_nodeType(instance: *runtime.Instance) anyerror!u16 {
        return try ShadowRootImpl.get_nodeType(instance);
    }

    pub fn get_nodeName(instance: *runtime.Instance) anyerror!DOMString {
        return try ShadowRootImpl.get_nodeName(instance);
    }

    pub fn get_baseURI(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ShadowRootImpl.get_baseURI(instance);
    }

    pub fn get_isConnected(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRootImpl.get_isConnected(instance);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_ownerDocument(instance);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_parentNode(instance);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_parentElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyerror!NodeList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_childNodes) |cached| {
            return cached;
        }
        const value = try ShadowRootImpl.get_childNodes(instance);
        state.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_firstChild(instance);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_lastChild(instance);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_nextSibling(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_nodeValue(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ShadowRootImpl.set_nodeValue(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_textContent(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ShadowRootImpl.set_textContent(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_children) |cached| {
            return cached;
        }
        const value = try ShadowRootImpl.get_children(instance);
        state.cached_children = value;
        return value;
    }

    pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_firstElementChild(instance);
    }

    pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_lastElementChild(instance);
    }

    pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
        return try ShadowRootImpl.get_childElementCount(instance);
    }

    pub fn get_mode(instance: *runtime.Instance) anyerror!ShadowRootMode {
        return try ShadowRootImpl.get_mode(instance);
    }

    pub fn get_delegatesFocus(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRootImpl.get_delegatesFocus(instance);
    }

    pub fn get_slotAssignment(instance: *runtime.Instance) anyerror!SlotAssignmentMode {
        return try ShadowRootImpl.get_slotAssignment(instance);
    }

    pub fn get_clonable(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRootImpl.get_clonable(instance);
    }

    pub fn get_serializable(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRootImpl.get_serializable(instance);
    }

    pub fn get_host(instance: *runtime.Instance) anyerror!Element {
        return try ShadowRootImpl.get_host(instance);
    }

    pub fn get_onslotchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ShadowRootImpl.get_onslotchange(instance);
    }

    pub fn set_onslotchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ShadowRootImpl.set_onslotchange(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_innerHTML(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_innerHTML(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_innerHTML(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ShadowRootImpl.set_innerHTML(instance, value);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_customElementRegistry(instance);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_fullscreenElement(instance);
    }

    pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_pictureInPictureElement(instance);
    }

    pub fn get_pointerLockElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_pointerLockElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheets(instance: *runtime.Instance) anyerror!StyleSheetList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_styleSheets) |cached| {
            return cached;
        }
        const value = try ShadowRootImpl.get_styleSheets(instance);
        state.cached_styleSheets = value;
        return value;
    }

    pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_adoptedStyleSheets(instance);
    }

    pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try ShadowRootImpl.set_adoptedStyleSheets(instance, value);
    }

    pub fn get_activeElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.get_activeElement(instance);
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) anyerror!bool {
        
        return try ShadowRootImpl.call_isDefaultNamespace(instance, namespace);
    }

    pub fn call_querySelector(instance: *runtime.Instance, selectors: DOMString) anyerror!anyopaque {
        
        return try ShadowRootImpl.call_querySelector(instance, selectors);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: Node) anyerror!u16 {
        
        return try ShadowRootImpl.call_compareDocumentPosition(instance, other);
    }

    pub fn call_contains(instance: *runtime.Instance, other: anyopaque) anyerror!bool {
        
        return try ShadowRootImpl.call_contains(instance, other);
    }

    pub fn call_getElementById(instance: *runtime.Instance, elementId: DOMString) anyerror!anyopaque {
        
        return try ShadowRootImpl.call_getElementById(instance, elementId);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ShadowRootImpl.call_removeEventListener(instance, type_, callback, options);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return try ShadowRootImpl.call_cloneNode(instance, subtree);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_append(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ShadowRootImpl.call_append(instance, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_moveBefore(instance: *runtime.Instance, node: Node, child: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ShadowRootImpl.call_moveBefore(instance, node, child);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: GetRootNodeOptions) anyerror!Node {
        
        return try ShadowRootImpl.call_getRootNode(instance, options);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_prepend(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ShadowRootImpl.call_prepend(instance, nodes);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ShadowRootImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getHTML(instance: *runtime.Instance, options: GetHTMLOptions) anyerror!DOMString {
        
        return try ShadowRootImpl.call_getHTML(instance, options);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) anyerror!bool {
        
        return try ShadowRootImpl.call_isSameNode(instance, otherNode);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ShadowRootImpl.call_setHTMLUnsafe(instance, html);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) anyerror!anyopaque {
        
        return try ShadowRootImpl.call_lookupPrefix(instance, namespace);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ShadowRootImpl.call_when(instance, type_, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: Node, child: anyopaque) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ShadowRootImpl.call_insertBefore(instance, node, child);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) anyerror!anyopaque {
        
        return try ShadowRootImpl.call_lookupNamespaceURI(instance, prefix);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ShadowRootImpl.call_addEventListener(instance, type_, callback, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ShadowRootImpl.call_appendChild(instance, node);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) anyerror!bool {
        return try ShadowRootImpl.call_hasChildNodes(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceChildren(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ShadowRootImpl.call_replaceChildren(instance, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ShadowRootImpl.call_removeChild(instance, child);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try ShadowRootImpl.call_normalize(instance);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) anyerror!bool {
        
        return try ShadowRootImpl.call_isEqualNode(instance, otherNode);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: Node, child: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ShadowRootImpl.call_replaceChild(instance, node, child);
    }

    /// Extended attributes: [NewObject]
    pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: DOMString) anyerror!NodeList {
        // [NewObject] - Caller owns the returned object
        
        return try ShadowRootImpl.call_querySelectorAll(instance, selectors);
    }

    pub fn call_getAnimations(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowRootImpl.call_getAnimations(instance);
    }

};

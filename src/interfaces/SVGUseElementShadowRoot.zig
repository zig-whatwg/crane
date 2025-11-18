//! Generated from: SVG.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGUseElementShadowRootImpl = @import("../impls/SVGUseElementShadowRoot.zig");
const ShadowRoot = @import("ShadowRoot.zig");

pub const SVGUseElementShadowRoot = struct {
    pub const Meta = struct {
        pub const name = "SVGUseElementShadowRoot";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ShadowRoot;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGUseElementShadowRoot, .{
        .deinit_fn = &deinit_wrapper,

        .get_ATTRIBUTE_NODE = &ShadowRoot.get_ATTRIBUTE_NODE,
        .get_CDATA_SECTION_NODE = &ShadowRoot.get_CDATA_SECTION_NODE,
        .get_COMMENT_NODE = &ShadowRoot.get_COMMENT_NODE,
        .get_DOCUMENT_FRAGMENT_NODE = &ShadowRoot.get_DOCUMENT_FRAGMENT_NODE,
        .get_DOCUMENT_NODE = &ShadowRoot.get_DOCUMENT_NODE,
        .get_DOCUMENT_POSITION_CONTAINED_BY = &ShadowRoot.get_DOCUMENT_POSITION_CONTAINED_BY,
        .get_DOCUMENT_POSITION_CONTAINS = &ShadowRoot.get_DOCUMENT_POSITION_CONTAINS,
        .get_DOCUMENT_POSITION_DISCONNECTED = &ShadowRoot.get_DOCUMENT_POSITION_DISCONNECTED,
        .get_DOCUMENT_POSITION_FOLLOWING = &ShadowRoot.get_DOCUMENT_POSITION_FOLLOWING,
        .get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = &ShadowRoot.get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC,
        .get_DOCUMENT_POSITION_PRECEDING = &ShadowRoot.get_DOCUMENT_POSITION_PRECEDING,
        .get_DOCUMENT_TYPE_NODE = &ShadowRoot.get_DOCUMENT_TYPE_NODE,
        .get_ELEMENT_NODE = &ShadowRoot.get_ELEMENT_NODE,
        .get_ENTITY_NODE = &ShadowRoot.get_ENTITY_NODE,
        .get_ENTITY_REFERENCE_NODE = &ShadowRoot.get_ENTITY_REFERENCE_NODE,
        .get_NOTATION_NODE = &ShadowRoot.get_NOTATION_NODE,
        .get_PROCESSING_INSTRUCTION_NODE = &ShadowRoot.get_PROCESSING_INSTRUCTION_NODE,
        .get_TEXT_NODE = &ShadowRoot.get_TEXT_NODE,
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
        
        // Initialize the state (Impl receives full hierarchy)
        SVGUseElementShadowRootImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SVGUseElementShadowRootImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_nodeType(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_nodeType(state);
    }

    pub fn get_nodeName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_nodeName(state);
    }

    pub fn get_baseURI(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_baseURI(state);
    }

    pub fn get_isConnected(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_isConnected(state);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_ownerDocument(state);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_parentNode(state);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_parentElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_childNodes) |cached| {
            return cached;
        }
        const value = SVGUseElementShadowRootImpl.get_childNodes(state);
        state.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_firstChild(state);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_lastChild(state);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_previousSibling(state);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_nextSibling(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_nodeValue(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        SVGUseElementShadowRootImpl.set_nodeValue(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_textContent(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        SVGUseElementShadowRootImpl.set_textContent(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_children) |cached| {
            return cached;
        }
        const value = SVGUseElementShadowRootImpl.get_children(state);
        state.cached_children = value;
        return value;
    }

    pub fn get_firstElementChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_firstElementChild(state);
    }

    pub fn get_lastElementChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_lastElementChild(state);
    }

    pub fn get_childElementCount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_childElementCount(state);
    }

    pub fn get_mode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_mode(state);
    }

    pub fn get_delegatesFocus(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_delegatesFocus(state);
    }

    pub fn get_slotAssignment(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_slotAssignment(state);
    }

    pub fn get_clonable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_clonable(state);
    }

    pub fn get_serializable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_serializable(state);
    }

    pub fn get_host(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_host(state);
    }

    pub fn get_onslotchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_onslotchange(state);
    }

    pub fn set_onslotchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SVGUseElementShadowRootImpl.set_onslotchange(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_innerHTML(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_innerHTML(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_innerHTML(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        SVGUseElementShadowRootImpl.set_innerHTML(state, value);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_customElementRegistry(state);
    }

    /// Extended attributes: [LegacyLenientSetter]
    pub fn get_fullscreenElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_fullscreenElement(state);
    }

    pub fn get_pictureInPictureElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_pictureInPictureElement(state);
    }

    pub fn get_pointerLockElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_pointerLockElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_styleSheets(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_styleSheets) |cached| {
            return cached;
        }
        const value = SVGUseElementShadowRootImpl.get_styleSheets(state);
        state.cached_styleSheets = value;
        return value;
    }

    pub fn get_adoptedStyleSheets(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_adoptedStyleSheets(state);
    }

    pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SVGUseElementShadowRootImpl.set_adoptedStyleSheets(state, value);
    }

    pub fn get_activeElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.get_activeElement(state);
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) bool {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_isDefaultNamespace(state, namespace);
    }

    pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_querySelector(state, selectors);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: anyopaque) u16 {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_compareDocumentPosition(state, other);
    }

    pub fn call_contains(instance: *runtime.Instance, other: anyopaque) bool {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_contains(state, other);
    }

    pub fn call_getElementById(instance: *runtime.Instance, elementId: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_getElementById(state, elementId);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_removeEventListener(state, type_, callback, options);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return SVGUseElementShadowRootImpl.call_cloneNode(state, subtree);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_append(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return SVGUseElementShadowRootImpl.call_append(state, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_moveBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return SVGUseElementShadowRootImpl.call_moveBefore(state, node, child);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_getRootNode(state, options);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_prepend(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return SVGUseElementShadowRootImpl.call_prepend(state, nodes);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getHTML(instance: *runtime.Instance, options: anyopaque) runtime.DOMString {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_getHTML(state, options);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_isSameNode(state, otherNode);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return SVGUseElementShadowRootImpl.call_setHTMLUnsafe(state, html);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_lookupPrefix(state, namespace);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_when(state, type_, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return SVGUseElementShadowRootImpl.call_insertBefore(state, node, child);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_lookupNamespaceURI(state, prefix);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_addEventListener(state, type_, callback, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return SVGUseElementShadowRootImpl.call_appendChild(state, node);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.call_hasChildNodes(state);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceChildren(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return SVGUseElementShadowRootImpl.call_replaceChildren(state, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return SVGUseElementShadowRootImpl.call_removeChild(state, child);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return SVGUseElementShadowRootImpl.call_normalize(state);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return SVGUseElementShadowRootImpl.call_isEqualNode(state, otherNode);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return SVGUseElementShadowRootImpl.call_replaceChild(state, node, child);
    }

    /// Extended attributes: [NewObject]
    pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return SVGUseElementShadowRootImpl.call_querySelectorAll(state, selectors);
    }

    pub fn call_getAnimations(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SVGUseElementShadowRootImpl.call_getAnimations(state);
    }

};

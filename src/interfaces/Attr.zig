//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AttrImpl = @import("../impls/Attr.zig");
const Node = @import("Node.zig");

pub const Attr = struct {
    pub const Meta = struct {
        pub const name = "Attr";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Node;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            namespaceURI: ?runtime.DOMString = null,
            prefix: ?runtime.DOMString = null,
            localName: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            value: runtime.DOMString = undefined,
            ownerElement: ?Element = null,
            specified: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Attr, .{
        .deinit_fn = &deinit_wrapper,

        .get_ATTRIBUTE_NODE = &Node.get_ATTRIBUTE_NODE,
        .get_CDATA_SECTION_NODE = &Node.get_CDATA_SECTION_NODE,
        .get_COMMENT_NODE = &Node.get_COMMENT_NODE,
        .get_DOCUMENT_FRAGMENT_NODE = &Node.get_DOCUMENT_FRAGMENT_NODE,
        .get_DOCUMENT_NODE = &Node.get_DOCUMENT_NODE,
        .get_DOCUMENT_POSITION_CONTAINED_BY = &Node.get_DOCUMENT_POSITION_CONTAINED_BY,
        .get_DOCUMENT_POSITION_CONTAINS = &Node.get_DOCUMENT_POSITION_CONTAINS,
        .get_DOCUMENT_POSITION_DISCONNECTED = &Node.get_DOCUMENT_POSITION_DISCONNECTED,
        .get_DOCUMENT_POSITION_FOLLOWING = &Node.get_DOCUMENT_POSITION_FOLLOWING,
        .get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = &Node.get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC,
        .get_DOCUMENT_POSITION_PRECEDING = &Node.get_DOCUMENT_POSITION_PRECEDING,
        .get_DOCUMENT_TYPE_NODE = &Node.get_DOCUMENT_TYPE_NODE,
        .get_ELEMENT_NODE = &Node.get_ELEMENT_NODE,
        .get_ENTITY_NODE = &Node.get_ENTITY_NODE,
        .get_ENTITY_REFERENCE_NODE = &Node.get_ENTITY_REFERENCE_NODE,
        .get_NOTATION_NODE = &Node.get_NOTATION_NODE,
        .get_PROCESSING_INSTRUCTION_NODE = &Node.get_PROCESSING_INSTRUCTION_NODE,
        .get_TEXT_NODE = &Node.get_TEXT_NODE,
        .get_baseURI = &get_baseURI,
        .get_childNodes = &get_childNodes,
        .get_firstChild = &get_firstChild,
        .get_isConnected = &get_isConnected,
        .get_lastChild = &get_lastChild,
        .get_localName = &get_localName,
        .get_name = &get_name,
        .get_namespaceURI = &get_namespaceURI,
        .get_nextSibling = &get_nextSibling,
        .get_nodeName = &get_nodeName,
        .get_nodeType = &get_nodeType,
        .get_nodeValue = &get_nodeValue,
        .get_ownerDocument = &get_ownerDocument,
        .get_ownerElement = &get_ownerElement,
        .get_parentElement = &get_parentElement,
        .get_parentNode = &get_parentNode,
        .get_prefix = &get_prefix,
        .get_previousSibling = &get_previousSibling,
        .get_specified = &get_specified,
        .get_textContent = &get_textContent,
        .get_value = &get_value,

        .set_nodeValue = &set_nodeValue,
        .set_textContent = &set_textContent,
        .set_value = &set_value,

        .call_addEventListener = &call_addEventListener,
        .call_appendChild = &call_appendChild,
        .call_cloneNode = &call_cloneNode,
        .call_compareDocumentPosition = &call_compareDocumentPosition,
        .call_contains = &call_contains,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getRootNode = &call_getRootNode,
        .call_hasChildNodes = &call_hasChildNodes,
        .call_insertBefore = &call_insertBefore,
        .call_isDefaultNamespace = &call_isDefaultNamespace,
        .call_isEqualNode = &call_isEqualNode,
        .call_isSameNode = &call_isSameNode,
        .call_lookupNamespaceURI = &call_lookupNamespaceURI,
        .call_lookupPrefix = &call_lookupPrefix,
        .call_normalize = &call_normalize,
        .call_removeChild = &call_removeChild,
        .call_removeEventListener = &call_removeEventListener,
        .call_replaceChild = &call_replaceChild,
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
        AttrImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AttrImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_nodeType(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return AttrImpl.get_nodeType(state);
    }

    pub fn get_nodeName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return AttrImpl.get_nodeName(state);
    }

    pub fn get_baseURI(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return AttrImpl.get_baseURI(state);
    }

    pub fn get_isConnected(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return AttrImpl.get_isConnected(state);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_ownerDocument(state);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_parentNode(state);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_parentElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_childNodes) |cached| {
            return cached;
        }
        const value = AttrImpl.get_childNodes(state);
        state.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_firstChild(state);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_lastChild(state);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_previousSibling(state);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_nextSibling(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_nodeValue(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        AttrImpl.set_nodeValue(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_textContent(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        AttrImpl.set_textContent(state, value);
    }

    pub fn get_namespaceURI(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_namespaceURI(state);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_prefix(state);
    }

    pub fn get_localName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return AttrImpl.get_localName(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return AttrImpl.get_name(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_value(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return AttrImpl.get_value(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        AttrImpl.set_value(state, value);
    }

    pub fn get_ownerElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AttrImpl.get_ownerElement(state);
    }

    pub fn get_specified(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return AttrImpl.get_specified(state);
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) bool {
        const state = instance.getState(State);
        
        return AttrImpl.call_isDefaultNamespace(state, namespace);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AttrImpl.call_when(state, type_, options);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: anyopaque) u16 {
        const state = instance.getState(State);
        
        return AttrImpl.call_compareDocumentPosition(state, other);
    }

    pub fn call_contains(instance: *runtime.Instance, other: anyopaque) bool {
        const state = instance.getState(State);
        
        return AttrImpl.call_contains(state, other);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return AttrImpl.call_insertBefore(state, node, child);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AttrImpl.call_lookupNamespaceURI(state, prefix);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AttrImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AttrImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return AttrImpl.call_hasChildNodes(state);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return AttrImpl.call_cloneNode(state, subtree);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return AttrImpl.call_appendChild(state, node);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AttrImpl.call_getRootNode(state, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return AttrImpl.call_removeChild(state, child);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return AttrImpl.call_dispatchEvent(state, event);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return AttrImpl.call_normalize(state);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return AttrImpl.call_isEqualNode(state, otherNode);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return AttrImpl.call_isSameNode(state, otherNode);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return AttrImpl.call_replaceChild(state, node, child);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return AttrImpl.call_lookupPrefix(state, namespace);
    }

};

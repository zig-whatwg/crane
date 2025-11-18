//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NodeImpl = @import("../impls/Node.zig");
const EventTarget = @import("EventTarget.zig");

pub const Node = struct {
    pub const Meta = struct {
        pub const name = "Node";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            nodeType: u16 = undefined,
            nodeName: runtime.DOMString = undefined,
            baseURI: runtime.USVString = undefined,
            isConnected: bool = undefined,
            ownerDocument: ?Document = null,
            parentNode: ?Node = null,
            parentElement: ?Element = null,
            childNodes: NodeList = undefined,
            firstChild: ?Node = null,
            lastChild: ?Node = null,
            previousSibling: ?Node = null,
            nextSibling: ?Node = null,
            nodeValue: ?runtime.DOMString = null,
            textContent: ?runtime.DOMString = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short ELEMENT_NODE = 1;
    pub fn get_ELEMENT_NODE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short ATTRIBUTE_NODE = 2;
    pub fn get_ATTRIBUTE_NODE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short TEXT_NODE = 3;
    pub fn get_TEXT_NODE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short CDATA_SECTION_NODE = 4;
    pub fn get_CDATA_SECTION_NODE() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short ENTITY_REFERENCE_NODE = 5;
    pub fn get_ENTITY_REFERENCE_NODE() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short ENTITY_NODE = 6;
    pub fn get_ENTITY_NODE() u16 {
        return 6;
    }

    /// WebIDL constant: const unsigned short PROCESSING_INSTRUCTION_NODE = 7;
    pub fn get_PROCESSING_INSTRUCTION_NODE() u16 {
        return 7;
    }

    /// WebIDL constant: const unsigned short COMMENT_NODE = 8;
    pub fn get_COMMENT_NODE() u16 {
        return 8;
    }

    /// WebIDL constant: const unsigned short DOCUMENT_NODE = 9;
    pub fn get_DOCUMENT_NODE() u16 {
        return 9;
    }

    /// WebIDL constant: const unsigned short DOCUMENT_TYPE_NODE = 10;
    pub fn get_DOCUMENT_TYPE_NODE() u16 {
        return 10;
    }

    /// WebIDL constant: const unsigned short DOCUMENT_FRAGMENT_NODE = 11;
    pub fn get_DOCUMENT_FRAGMENT_NODE() u16 {
        return 11;
    }

    /// WebIDL constant: const unsigned short NOTATION_NODE = 12;
    pub fn get_NOTATION_NODE() u16 {
        return 12;
    }

    /// WebIDL constant: const unsigned short DOCUMENT_POSITION_DISCONNECTED = 1;
    pub fn get_DOCUMENT_POSITION_DISCONNECTED() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short DOCUMENT_POSITION_PRECEDING = 2;
    pub fn get_DOCUMENT_POSITION_PRECEDING() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short DOCUMENT_POSITION_FOLLOWING = 4;
    pub fn get_DOCUMENT_POSITION_FOLLOWING() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short DOCUMENT_POSITION_CONTAINS = 8;
    pub fn get_DOCUMENT_POSITION_CONTAINS() u16 {
        return 8;
    }

    /// WebIDL constant: const unsigned short DOCUMENT_POSITION_CONTAINED_BY = 16;
    pub fn get_DOCUMENT_POSITION_CONTAINED_BY() u16 {
        return 16;
    }

    /// WebIDL constant: const unsigned short DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 32;
    pub fn get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC() u16 {
        return 32;
    }

    pub const vtable = runtime.buildVTable(Node, .{
        .deinit_fn = &deinit_wrapper,

        .get_ATTRIBUTE_NODE = &get_ATTRIBUTE_NODE,
        .get_CDATA_SECTION_NODE = &get_CDATA_SECTION_NODE,
        .get_COMMENT_NODE = &get_COMMENT_NODE,
        .get_DOCUMENT_FRAGMENT_NODE = &get_DOCUMENT_FRAGMENT_NODE,
        .get_DOCUMENT_NODE = &get_DOCUMENT_NODE,
        .get_DOCUMENT_POSITION_CONTAINED_BY = &get_DOCUMENT_POSITION_CONTAINED_BY,
        .get_DOCUMENT_POSITION_CONTAINS = &get_DOCUMENT_POSITION_CONTAINS,
        .get_DOCUMENT_POSITION_DISCONNECTED = &get_DOCUMENT_POSITION_DISCONNECTED,
        .get_DOCUMENT_POSITION_FOLLOWING = &get_DOCUMENT_POSITION_FOLLOWING,
        .get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = &get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC,
        .get_DOCUMENT_POSITION_PRECEDING = &get_DOCUMENT_POSITION_PRECEDING,
        .get_DOCUMENT_TYPE_NODE = &get_DOCUMENT_TYPE_NODE,
        .get_ELEMENT_NODE = &get_ELEMENT_NODE,
        .get_ENTITY_NODE = &get_ENTITY_NODE,
        .get_ENTITY_REFERENCE_NODE = &get_ENTITY_REFERENCE_NODE,
        .get_NOTATION_NODE = &get_NOTATION_NODE,
        .get_PROCESSING_INSTRUCTION_NODE = &get_PROCESSING_INSTRUCTION_NODE,
        .get_TEXT_NODE = &get_TEXT_NODE,
        .get_baseURI = &get_baseURI,
        .get_childNodes = &get_childNodes,
        .get_firstChild = &get_firstChild,
        .get_isConnected = &get_isConnected,
        .get_lastChild = &get_lastChild,
        .get_nextSibling = &get_nextSibling,
        .get_nodeName = &get_nodeName,
        .get_nodeType = &get_nodeType,
        .get_nodeValue = &get_nodeValue,
        .get_ownerDocument = &get_ownerDocument,
        .get_parentElement = &get_parentElement,
        .get_parentNode = &get_parentNode,
        .get_previousSibling = &get_previousSibling,
        .get_textContent = &get_textContent,

        .set_nodeValue = &set_nodeValue,
        .set_textContent = &set_textContent,

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
        NodeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NodeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_nodeType(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return NodeImpl.get_nodeType(state);
    }

    pub fn get_nodeName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NodeImpl.get_nodeName(state);
    }

    pub fn get_baseURI(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return NodeImpl.get_baseURI(state);
    }

    pub fn get_isConnected(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NodeImpl.get_isConnected(state);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeImpl.get_ownerDocument(state);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeImpl.get_parentNode(state);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeImpl.get_parentElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_childNodes) |cached| {
            return cached;
        }
        const value = NodeImpl.get_childNodes(state);
        state.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeImpl.get_firstChild(state);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeImpl.get_lastChild(state);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeImpl.get_previousSibling(state);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeImpl.get_nextSibling(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeImpl.get_nodeValue(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        NodeImpl.set_nodeValue(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeImpl.get_textContent(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        NodeImpl.set_textContent(state, value);
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) bool {
        const state = instance.getState(State);
        
        return NodeImpl.call_isDefaultNamespace(state, namespace);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NodeImpl.call_when(state, type_, options);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: anyopaque) u16 {
        const state = instance.getState(State);
        
        return NodeImpl.call_compareDocumentPosition(state, other);
    }

    pub fn call_contains(instance: *runtime.Instance, other: anyopaque) bool {
        const state = instance.getState(State);
        
        return NodeImpl.call_contains(state, other);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return NodeImpl.call_insertBefore(state, node, child);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NodeImpl.call_lookupNamespaceURI(state, prefix);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NodeImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NodeImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NodeImpl.call_hasChildNodes(state);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return NodeImpl.call_cloneNode(state, subtree);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return NodeImpl.call_appendChild(state, node);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NodeImpl.call_getRootNode(state, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return NodeImpl.call_removeChild(state, child);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return NodeImpl.call_dispatchEvent(state, event);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return NodeImpl.call_normalize(state);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return NodeImpl.call_isEqualNode(state, otherNode);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return NodeImpl.call_isSameNode(state, otherNode);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return NodeImpl.call_replaceChild(state, node, child);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NodeImpl.call_lookupPrefix(state, namespace);
    }

};

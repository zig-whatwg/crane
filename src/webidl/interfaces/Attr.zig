//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AttrImpl = @import("impls").Attr;
const Node = @import("interfaces").Node;
const Element = @import("interfaces").Element;
const DOMString = @import("typedefs").DOMString;

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
        
        // Initialize the instance (Impl receives full instance)
        AttrImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AttrImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_nodeType(instance: *runtime.Instance) anyerror!u16 {
        return try AttrImpl.get_nodeType(instance);
    }

    pub fn get_nodeName(instance: *runtime.Instance) anyerror!DOMString {
        return try AttrImpl.get_nodeName(instance);
    }

    pub fn get_baseURI(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try AttrImpl.get_baseURI(instance);
    }

    pub fn get_isConnected(instance: *runtime.Instance) anyerror!bool {
        return try AttrImpl.get_isConnected(instance);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_ownerDocument(instance);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_parentNode(instance);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_parentElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyerror!NodeList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_childNodes) |cached| {
            return cached;
        }
        const value = try AttrImpl.get_childNodes(instance);
        state.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_firstChild(instance);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_lastChild(instance);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_nextSibling(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_nodeValue(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try AttrImpl.set_nodeValue(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_textContent(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try AttrImpl.set_textContent(instance, value);
    }

    pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_namespaceURI(instance);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_prefix(instance);
    }

    pub fn get_localName(instance: *runtime.Instance) anyerror!DOMString {
        return try AttrImpl.get_localName(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try AttrImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try AttrImpl.get_value(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try AttrImpl.set_value(instance, value);
    }

    pub fn get_ownerElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try AttrImpl.get_ownerElement(instance);
    }

    pub fn get_specified(instance: *runtime.Instance) anyerror!bool {
        return try AttrImpl.get_specified(instance);
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) anyerror!bool {
        
        return try AttrImpl.call_isDefaultNamespace(instance, namespace);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try AttrImpl.call_when(instance, type_, options);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: Node) anyerror!u16 {
        
        return try AttrImpl.call_compareDocumentPosition(instance, other);
    }

    pub fn call_contains(instance: *runtime.Instance, other: anyopaque) anyerror!bool {
        
        return try AttrImpl.call_contains(instance, other);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: Node, child: anyopaque) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try AttrImpl.call_insertBefore(instance, node, child);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) anyerror!anyopaque {
        
        return try AttrImpl.call_lookupNamespaceURI(instance, prefix);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AttrImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AttrImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) anyerror!bool {
        return try AttrImpl.call_hasChildNodes(instance);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return try AttrImpl.call_cloneNode(instance, subtree);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try AttrImpl.call_appendChild(instance, node);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: GetRootNodeOptions) anyerror!Node {
        
        return try AttrImpl.call_getRootNode(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try AttrImpl.call_removeChild(instance, child);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try AttrImpl.call_dispatchEvent(instance, event);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try AttrImpl.call_normalize(instance);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) anyerror!bool {
        
        return try AttrImpl.call_isEqualNode(instance, otherNode);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) anyerror!bool {
        
        return try AttrImpl.call_isSameNode(instance, otherNode);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: Node, child: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try AttrImpl.call_replaceChild(instance, node, child);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) anyerror!anyopaque {
        
        return try AttrImpl.call_lookupPrefix(instance, namespace);
    }

};

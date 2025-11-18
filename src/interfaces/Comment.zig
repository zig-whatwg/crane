//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CommentImpl = @import("../impls/Comment.zig");
const CharacterData = @import("CharacterData.zig");

pub const Comment = struct {
    pub const Meta = struct {
        pub const name = "Comment";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CharacterData;
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

    pub const vtable = runtime.buildVTable(Comment, .{
        .deinit_fn = &deinit_wrapper,

        .get_ATTRIBUTE_NODE = &CharacterData.get_ATTRIBUTE_NODE,
        .get_CDATA_SECTION_NODE = &CharacterData.get_CDATA_SECTION_NODE,
        .get_COMMENT_NODE = &CharacterData.get_COMMENT_NODE,
        .get_DOCUMENT_FRAGMENT_NODE = &CharacterData.get_DOCUMENT_FRAGMENT_NODE,
        .get_DOCUMENT_NODE = &CharacterData.get_DOCUMENT_NODE,
        .get_DOCUMENT_POSITION_CONTAINED_BY = &CharacterData.get_DOCUMENT_POSITION_CONTAINED_BY,
        .get_DOCUMENT_POSITION_CONTAINS = &CharacterData.get_DOCUMENT_POSITION_CONTAINS,
        .get_DOCUMENT_POSITION_DISCONNECTED = &CharacterData.get_DOCUMENT_POSITION_DISCONNECTED,
        .get_DOCUMENT_POSITION_FOLLOWING = &CharacterData.get_DOCUMENT_POSITION_FOLLOWING,
        .get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = &CharacterData.get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC,
        .get_DOCUMENT_POSITION_PRECEDING = &CharacterData.get_DOCUMENT_POSITION_PRECEDING,
        .get_DOCUMENT_TYPE_NODE = &CharacterData.get_DOCUMENT_TYPE_NODE,
        .get_ELEMENT_NODE = &CharacterData.get_ELEMENT_NODE,
        .get_ENTITY_NODE = &CharacterData.get_ENTITY_NODE,
        .get_ENTITY_REFERENCE_NODE = &CharacterData.get_ENTITY_REFERENCE_NODE,
        .get_NOTATION_NODE = &CharacterData.get_NOTATION_NODE,
        .get_PROCESSING_INSTRUCTION_NODE = &CharacterData.get_PROCESSING_INSTRUCTION_NODE,
        .get_TEXT_NODE = &CharacterData.get_TEXT_NODE,
        .get_baseURI = &get_baseURI,
        .get_childNodes = &get_childNodes,
        .get_data = &get_data,
        .get_firstChild = &get_firstChild,
        .get_isConnected = &get_isConnected,
        .get_lastChild = &get_lastChild,
        .get_length = &get_length,
        .get_nextElementSibling = &get_nextElementSibling,
        .get_nextSibling = &get_nextSibling,
        .get_nodeName = &get_nodeName,
        .get_nodeType = &get_nodeType,
        .get_nodeValue = &get_nodeValue,
        .get_ownerDocument = &get_ownerDocument,
        .get_parentElement = &get_parentElement,
        .get_parentNode = &get_parentNode,
        .get_previousElementSibling = &get_previousElementSibling,
        .get_previousSibling = &get_previousSibling,
        .get_textContent = &get_textContent,

        .set_data = &set_data,
        .set_nodeValue = &set_nodeValue,
        .set_textContent = &set_textContent,

        .call_addEventListener = &call_addEventListener,
        .call_after = &call_after,
        .call_appendChild = &call_appendChild,
        .call_appendData = &call_appendData,
        .call_before = &call_before,
        .call_cloneNode = &call_cloneNode,
        .call_compareDocumentPosition = &call_compareDocumentPosition,
        .call_contains = &call_contains,
        .call_deleteData = &call_deleteData,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getRootNode = &call_getRootNode,
        .call_hasChildNodes = &call_hasChildNodes,
        .call_insertBefore = &call_insertBefore,
        .call_insertData = &call_insertData,
        .call_isDefaultNamespace = &call_isDefaultNamespace,
        .call_isEqualNode = &call_isEqualNode,
        .call_isSameNode = &call_isSameNode,
        .call_lookupNamespaceURI = &call_lookupNamespaceURI,
        .call_lookupPrefix = &call_lookupPrefix,
        .call_normalize = &call_normalize,
        .call_remove = &call_remove,
        .call_removeChild = &call_removeChild,
        .call_removeEventListener = &call_removeEventListener,
        .call_replaceChild = &call_replaceChild,
        .call_replaceData = &call_replaceData,
        .call_replaceWith = &call_replaceWith,
        .call_substringData = &call_substringData,
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
        CommentImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CommentImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, data: runtime.DOMString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CommentImpl.constructor(state, data);
        
        return instance;
    }

    pub fn get_nodeType(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return CommentImpl.get_nodeType(state);
    }

    pub fn get_nodeName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CommentImpl.get_nodeName(state);
    }

    pub fn get_baseURI(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return CommentImpl.get_baseURI(state);
    }

    pub fn get_isConnected(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CommentImpl.get_isConnected(state);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CommentImpl.get_ownerDocument(state);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CommentImpl.get_parentNode(state);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CommentImpl.get_parentElement(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_childNodes) |cached| {
            return cached;
        }
        const value = CommentImpl.get_childNodes(state);
        state.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CommentImpl.get_firstChild(state);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CommentImpl.get_lastChild(state);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CommentImpl.get_previousSibling(state);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CommentImpl.get_nextSibling(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CommentImpl.get_nodeValue(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        CommentImpl.set_nodeValue(state, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CommentImpl.get_textContent(state);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        CommentImpl.set_textContent(state, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_data(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CommentImpl.get_data(state);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_data(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CommentImpl.set_data(state, value);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return CommentImpl.get_length(state);
    }

    pub fn get_previousElementSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CommentImpl.get_previousElementSibling(state);
    }

    pub fn get_nextElementSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CommentImpl.get_nextElementSibling(state);
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) bool {
        const state = instance.getState(State);
        
        return CommentImpl.call_isDefaultNamespace(state, namespace);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: anyopaque) u16 {
        const state = instance.getState(State);
        
        return CommentImpl.call_compareDocumentPosition(state, other);
    }

    pub fn call_contains(instance: *runtime.Instance, other: anyopaque) bool {
        const state = instance.getState(State);
        
        return CommentImpl.call_contains(state, other);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_remove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return CommentImpl.call_remove(state);
    }

    pub fn call_replaceData(instance: *runtime.Instance, offset: u32, count: u32, data: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CommentImpl.call_replaceData(state, offset, count, data);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CommentImpl.call_removeEventListener(state, type_, callback, options);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return CommentImpl.call_cloneNode(state, subtree);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CommentImpl.call_getRootNode(state, options);
    }

    pub fn call_substringData(instance: *runtime.Instance, offset: u32, count: u32) runtime.DOMString {
        const state = instance.getState(State);
        
        return CommentImpl.call_substringData(state, offset, count);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return CommentImpl.call_dispatchEvent(state, event);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceWith(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return CommentImpl.call_replaceWith(state, nodes);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return CommentImpl.call_isSameNode(state, otherNode);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CommentImpl.call_lookupPrefix(state, namespace);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CommentImpl.call_when(state, type_, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return CommentImpl.call_insertBefore(state, node, child);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_before(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return CommentImpl.call_before(state, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_after(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return CommentImpl.call_after(state, nodes);
    }

    pub fn call_appendData(instance: *runtime.Instance, data: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CommentImpl.call_appendData(state, data);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CommentImpl.call_lookupNamespaceURI(state, prefix);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CommentImpl.call_addEventListener(state, type_, callback, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return CommentImpl.call_appendChild(state, node);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CommentImpl.call_hasChildNodes(state);
    }

    pub fn call_insertData(instance: *runtime.Instance, offset: u32, data: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CommentImpl.call_insertData(state, offset, data);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return CommentImpl.call_removeChild(state, child);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return CommentImpl.call_normalize(state);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) bool {
        const state = instance.getState(State);
        
        return CommentImpl.call_isEqualNode(state, otherNode);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return CommentImpl.call_replaceChild(state, node, child);
    }

    pub fn call_deleteData(instance: *runtime.Instance, offset: u32, count: u32) anyopaque {
        const state = instance.getState(State);
        
        return CommentImpl.call_deleteData(state, offset, count);
    }

};

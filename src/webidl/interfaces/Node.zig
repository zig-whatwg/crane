//! Generated from: dom.idl
//! Generated at: 2025-11-29T11:15:57Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NodeImpl = @import("impls").Node;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const Document = @import("interfaces").Document;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const NodeList = @import("interfaces").NodeList;
const USVString = @import("interfaces").USVString;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const Element = @import("interfaces").Element;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;

pub const Node = struct {
    pub const Meta = struct {
        pub const name = "Node";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "nodeType", "get_nodeType", null },
            .{ "nodeName", "get_nodeName", null },
            .{ "baseURI", "get_baseURI", null },
            .{ "isConnected", "get_isConnected", null },
            .{ "ownerDocument", "get_ownerDocument", null },
            .{ "parentNode", "get_parentNode", null },
            .{ "parentElement", "get_parentElement", null },
            .{ "childNodes", "get_childNodes", null },
            .{ "firstChild", "get_firstChild", null },
            .{ "lastChild", "get_lastChild", null },
            .{ "previousSibling", "get_previousSibling", null },
            .{ "nextSibling", "get_nextSibling", null },
            .{ "nodeValue", "get_nodeValue", "set_nodeValue" },
            .{ "textContent", "get_textContent", "set_textContent" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getRootNode", "call_getRootNode", 0 },
            .{ "hasChildNodes", "call_hasChildNodes", 0 },
            .{ "normalize", "call_normalize", 0 },
            .{ "cloneNode", "call_cloneNode", 0 },
            .{ "isEqualNode", "call_isEqualNode", 1 },
            .{ "isSameNode", "call_isSameNode", 1 },
            .{ "compareDocumentPosition", "call_compareDocumentPosition", 1 },
            .{ "contains", "call_contains", 1 },
            .{ "lookupPrefix", "call_lookupPrefix", 1 },
            .{ "lookupNamespaceURI", "call_lookupNamespaceURI", 1 },
            .{ "isDefaultNamespace", "call_isDefaultNamespace", 1 },
            .{ "insertBefore", "call_insertBefore", 2 },
            .{ "appendChild", "call_appendChild", 1 },
            .{ "replaceChild", "call_replaceChild", 2 },
            .{ "removeChild", "call_removeChild", 1 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "ELEMENT_NODE", "get_ELEMENT_NODE" },
            .{ "ATTRIBUTE_NODE", "get_ATTRIBUTE_NODE" },
            .{ "TEXT_NODE", "get_TEXT_NODE" },
            .{ "CDATA_SECTION_NODE", "get_CDATA_SECTION_NODE" },
            .{ "ENTITY_REFERENCE_NODE", "get_ENTITY_REFERENCE_NODE" },
            .{ "ENTITY_NODE", "get_ENTITY_NODE" },
            .{ "PROCESSING_INSTRUCTION_NODE", "get_PROCESSING_INSTRUCTION_NODE" },
            .{ "COMMENT_NODE", "get_COMMENT_NODE" },
            .{ "DOCUMENT_NODE", "get_DOCUMENT_NODE" },
            .{ "DOCUMENT_TYPE_NODE", "get_DOCUMENT_TYPE_NODE" },
            .{ "DOCUMENT_FRAGMENT_NODE", "get_DOCUMENT_FRAGMENT_NODE" },
            .{ "NOTATION_NODE", "get_NOTATION_NODE" },
            .{ "DOCUMENT_POSITION_DISCONNECTED", "get_DOCUMENT_POSITION_DISCONNECTED" },
            .{ "DOCUMENT_POSITION_PRECEDING", "get_DOCUMENT_POSITION_PRECEDING" },
            .{ "DOCUMENT_POSITION_FOLLOWING", "get_DOCUMENT_POSITION_FOLLOWING" },
            .{ "DOCUMENT_POSITION_CONTAINS", "get_DOCUMENT_POSITION_CONTAINS" },
            .{ "DOCUMENT_POSITION_CONTAINED_BY", "get_DOCUMENT_POSITION_CONTAINED_BY" },
            .{ "DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC", "get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getRootNode",
            "hasChildNodes",
            "normalize",
            "cloneNode",
            "isEqualNode",
            "isSameNode",
            "compareDocumentPosition",
            "contains",
            "lookupPrefix",
            "lookupNamespaceURI",
            "isDefaultNamespace",
            "insertBefore",
            "appendChild",
            "replaceChild",
            "removeChild",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "nodeType", "get_nodeType", null },
            .{ "nodeName", "get_nodeName", null },
            .{ "parentNode", "get_parentNode", null },
            .{ "parentElement", "get_parentElement", null },
            .{ "childNodes", "get_childNodes", null },
            .{ "firstChild", "get_firstChild", null },
            .{ "lastChild", "get_lastChild", null },
            .{ "previousSibling", "get_previousSibling", null },
            .{ "nextSibling", "get_nextSibling", null },
            .{ "nodeValue", "get_nodeValue", "set_nodeValue" },
            .{ "textContent", "get_textContent", "set_textContent" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "baseURI", "get_baseURI", null },
            .{ "isConnected", "get_isConnected", null },
            .{ "ownerDocument", "get_ownerDocument", null },
        };

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            nodeType: u16 = undefined,
            nodeName: runtime.DOMString = undefined,
            baseURI: runtime.USVString = undefined,
            isConnected: bool = undefined,
            ownerDocument: ?*runtime.Instance = null,
            parentNode: ?*runtime.Instance = null,
            parentElement: ?*runtime.Instance = null,
            childNodes: *runtime.Instance = undefined,
            firstChild: ?*runtime.Instance = null,
            lastChild: ?*runtime.Instance = null,
            previousSibling: ?*runtime.Instance = null,
            nextSibling: ?*runtime.Instance = null,
            nodeValue: ?runtime.DOMString = null,
            textContent: ?runtime.DOMString = null,
            cached_childNodes: ?*runtime.Instance = null,
            _internal: ?*NodeImpl.InternalState = null,
        },
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

    const delegates = .{
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

        .call_appendChild = &call_appendChild,
        .call_cloneNode = &call_cloneNode,
        .call_compareDocumentPosition = &call_compareDocumentPosition,
        .call_contains = &call_contains,
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
        .call_replaceChild = &call_replaceChild,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NodeImpl.deinit(instance);
    }

    pub fn get_nodeType(instance: *runtime.Instance) anyerror!u16 {
        return try NodeImpl.get_nodeType(instance);
    }

    pub fn get_nodeName(instance: *runtime.Instance) anyerror!DOMString {
        return try NodeImpl.get_nodeName(instance);
    }

    pub fn get_baseURI(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NodeImpl.get_baseURI(instance);
    }

    pub fn get_isConnected(instance: *runtime.Instance) anyerror!bool {
        return try NodeImpl.get_isConnected(instance);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NodeImpl.get_ownerDocument(instance);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NodeImpl.get_parentNode(instance);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NodeImpl.get_parentElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_childNodes) |cached| {
            return cached;
        }
        const value = try NodeImpl.get_childNodes(instance);
        state.own.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NodeImpl.get_firstChild(instance);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NodeImpl.get_lastChild(instance);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NodeImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NodeImpl.get_nextSibling(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyerror!?DOMString {
        return try NodeImpl.get_nodeValue(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        try NodeImpl.set_nodeValue(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyerror!?DOMString {
        return try NodeImpl.get_textContent(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        try NodeImpl.set_textContent(instance, value);
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: ?DOMString) anyerror!bool {
        return try NodeImpl.call_isDefaultNamespace(instance, namespace);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: *runtime.Instance) anyerror!u16 {
        return try NodeImpl.call_compareDocumentPosition(instance, other);
    }

    pub fn call_contains(instance: *runtime.Instance, other: ?*runtime.Instance) anyerror!bool {
        return try NodeImpl.call_contains(instance, other);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        return try NodeImpl.call_insertBefore(instance, node, child);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: ?DOMString) anyerror!?DOMString {
        return try NodeImpl.call_lookupNamespaceURI(instance, prefix);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: *runtime.Instance) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        return try NodeImpl.call_appendChild(instance, node);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) anyerror!bool {
        return try NodeImpl.call_hasChildNodes(instance);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: webidl.Opt(bool)) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        // [NewObject] - Caller owns the returned object

        return try NodeImpl.call_cloneNode(instance, subtree);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: webidl.Opt(GetRootNodeOptions)) anyerror!*runtime.Instance {
        return try NodeImpl.call_getRootNode(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: *runtime.Instance) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        return try NodeImpl.call_removeChild(instance, child);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: ?*runtime.Instance) anyerror!bool {
        return try NodeImpl.call_isEqualNode(instance, otherNode);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        return try NodeImpl.call_normalize(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: *runtime.Instance, child: *runtime.Instance) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        return try NodeImpl.call_replaceChild(instance, node, child);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: ?*runtime.Instance) anyerror!bool {
        return try NodeImpl.call_isSameNode(instance, otherNode);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: ?DOMString) anyerror!?DOMString {
        return try NodeImpl.call_lookupPrefix(instance, namespace);
    }

    // =============================================================================
    // Internal State Access (for script execution algorithms)
    // =============================================================================

    /// Get the node type (returns u16 constant like NodeType.TEXT_NODE)
    pub fn getNodeType(instance: *runtime.Instance) ?u16 {
        return NodeImpl.getNodeType(instance);
    }

    /// Get the first child node
    pub fn getFirstChild(instance: *runtime.Instance) ?*runtime.Instance {
        return NodeImpl.getFirstChild(instance);
    }

    /// Get the next sibling node
    pub fn getNextSibling(instance: *runtime.Instance) ?*runtime.Instance {
        return NodeImpl.getNextSibling(instance);
    }

    /// Get internal state
    pub fn getInternalState(instance: *runtime.Instance) ?*NodeImpl.InternalState {
        return NodeImpl.getInternalState(instance);
    }

    // Re-export types for external use
    pub const NodeType = NodeImpl.NodeType;
};

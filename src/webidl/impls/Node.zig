//! Implementation for Node interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const Node = interfaces.Node;

pub const State = Node.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for nodeType
pub fn get_nodeType(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for nodeName
pub fn get_nodeName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for baseURI
pub fn get_baseURI(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isConnected
pub fn get_isConnected(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ownerDocument
pub fn get_ownerDocument(instance: *runtime.Instance) ImplError!interfaces.Document {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for parentNode
pub fn get_parentNode(instance: *runtime.Instance) ImplError!interfaces.Node {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for parentElement
pub fn get_parentElement(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for childNodes
pub fn get_childNodes(instance: *runtime.Instance) ImplError!interfaces.NodeList {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for firstChild
pub fn get_firstChild(instance: *runtime.Instance) ImplError!interfaces.Node {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lastChild
pub fn get_lastChild(instance: *runtime.Instance) ImplError!interfaces.Node {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for previousSibling
pub fn get_previousSibling(instance: *runtime.Instance) ImplError!interfaces.Node {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for nextSibling
pub fn get_nextSibling(instance: *runtime.Instance) ImplError!interfaces.Node {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for nodeValue
pub fn get_nodeValue(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for textContent
pub fn get_textContent(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for nodeValue
pub fn set_nodeValue(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for textContent
pub fn set_textContent(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: isDefaultNamespace
pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = namespace;
    return error.NotImplemented;
}

/// Operation: compareDocumentPosition
pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: interfaces.Node) ImplError!u16 {
    _ = instance;
    _ = other;
    return error.NotImplemented;
}

/// Operation: contains
pub fn call_contains(instance: *runtime.Instance, other: interfaces.Node) ImplError!bool {
    _ = instance;
    _ = other;
    return error.NotImplemented;
}

/// Operation: insertBefore
pub fn call_insertBefore(instance: *runtime.Instance, node: interfaces.Node, child: interfaces.Node) ImplError!interfaces.Node {
    _ = instance;
    _ = node;
    _ = child;
    return error.NotImplemented;
}

/// Operation: lookupNamespaceURI
pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = prefix;
    return error.NotImplemented;
}

/// Operation: appendChild
pub fn call_appendChild(instance: *runtime.Instance, node: interfaces.Node) ImplError!interfaces.Node {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: hasChildNodes
pub fn call_hasChildNodes(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: cloneNode
pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) ImplError!interfaces.Node {
    _ = instance;
    _ = subtree;
    return error.NotImplemented;
}

/// Operation: getRootNode
pub fn call_getRootNode(instance: *runtime.Instance, options: dictionaries.GetRootNodeOptions) ImplError!interfaces.Node {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: removeChild
pub fn call_removeChild(instance: *runtime.Instance, child: interfaces.Node) ImplError!interfaces.Node {
    _ = instance;
    _ = child;
    return error.NotImplemented;
}

/// Operation: isEqualNode
pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: interfaces.Node) ImplError!bool {
    _ = instance;
    _ = otherNode;
    return error.NotImplemented;
}

/// Operation: normalize
pub fn call_normalize(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: replaceChild
pub fn call_replaceChild(instance: *runtime.Instance, node: interfaces.Node, child: interfaces.Node) ImplError!interfaces.Node {
    _ = instance;
    _ = node;
    _ = child;
    return error.NotImplemented;
}

/// Operation: isSameNode
pub fn call_isSameNode(instance: *runtime.Instance, otherNode: interfaces.Node) ImplError!bool {
    _ = instance;
    _ = otherNode;
    return error.NotImplemented;
}

/// Operation: lookupPrefix
pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = namespace;
    return error.NotImplemented;
}


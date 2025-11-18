//! Implementation for DocumentFragment interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const DocumentFragment = @import("interfaces").DocumentFragment;

pub const State = DocumentFragment.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Constructor implementation
pub fn constructor(instance: *runtime.Instance) !void {
    _ = instance;
    // TODO: Implement constructor logic
}

/// Getter for nodeType
pub fn get_nodeType(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for nodeName
pub fn get_nodeName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for baseURI
pub fn get_baseURI(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for isConnected
pub fn get_isConnected(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for ownerDocument
pub fn get_ownerDocument(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for parentNode
pub fn get_parentNode(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for parentElement
pub fn get_parentElement(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for childNodes
pub fn get_childNodes(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for firstChild
pub fn get_firstChild(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lastChild
pub fn get_lastChild(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for previousSibling
pub fn get_previousSibling(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for nextSibling
pub fn get_nextSibling(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for nodeValue
pub fn get_nodeValue(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for textContent
pub fn get_textContent(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for children
pub fn get_children(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for firstElementChild
pub fn get_firstElementChild(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lastElementChild
pub fn get_lastElementChild(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for childElementCount
pub fn get_childElementCount(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for nodeValue
pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for textContent
pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: addEventListener
pub fn call_addEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeEventListener
pub fn call_removeEventListener(instance: *runtime.Instance, type: runtime.DOMString, callback: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = type;
    _ = callback;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dispatchEvent
pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) ImplError!bool {
    _ = instance;
    _ = event;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: when
pub fn call_when(instance: *runtime.Instance, type: runtime.DOMString, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = type;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getRootNode
pub fn call_getRootNode(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: hasChildNodes
pub fn call_hasChildNodes(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: normalize
pub fn call_normalize(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cloneNode
pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) ImplError!anyopaque {
    _ = instance;
    _ = subtree;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isEqualNode
pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) ImplError!bool {
    _ = instance;
    _ = otherNode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isSameNode
pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) ImplError!bool {
    _ = instance;
    _ = otherNode;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compareDocumentPosition
pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: anyopaque) ImplError!u16 {
    _ = instance;
    _ = other;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: contains
pub fn call_contains(instance: *runtime.Instance, other: anyopaque) ImplError!bool {
    _ = instance;
    _ = other;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lookupPrefix
pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = namespace;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lookupNamespaceURI
pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = prefix;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isDefaultNamespace
pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) ImplError!bool {
    _ = instance;
    _ = namespace;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: insertBefore
pub fn call_insertBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = node;
    _ = child;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: appendChild
pub fn call_appendChild(instance: *runtime.Instance, node: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: replaceChild
pub fn call_replaceChild(instance: *runtime.Instance, node: anyopaque, child: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = node;
    _ = child;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeChild
pub fn call_removeChild(instance: *runtime.Instance, child: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = child;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getElementById
pub fn call_getElementById(instance: *runtime.Instance, elementId: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = elementId;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: prepend
pub fn call_prepend(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: append
pub fn call_append(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: replaceChildren
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: anyopaque) ImplError!void {
    _ = instance;
    _ = nodes;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: moveBefore
pub fn call_moveBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) ImplError!void {
    _ = instance;
    _ = node;
    _ = child;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: querySelector
pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = selectors;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: querySelectorAll
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = selectors;
    // TODO: Implement operation
    return error.NotImplemented;
}


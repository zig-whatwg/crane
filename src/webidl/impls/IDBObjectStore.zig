//! Implementation for IDBObjectStore interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const IDBObjectStore = @import("interfaces").IDBObjectStore;

pub const State = IDBObjectStore.State;

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

/// Getter for name
pub fn get_name(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for keyPath
pub fn get_keyPath(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for indexNames
pub fn get_indexNames(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for transaction
pub fn get_transaction(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for autoIncrement
pub fn get_autoIncrement(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for name
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: put
pub fn call_put(instance: *runtime.Instance, value: anyopaque, key: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = value;
    _ = key;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, value: anyopaque, key: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = value;
    _ = key;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance, query: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = query;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: get
pub fn call_get(instance: *runtime.Instance, query: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = query;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getKey
pub fn call_getKey(instance: *runtime.Instance, query: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = query;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAll
pub fn call_getAll(instance: *runtime.Instance, queryOrOptions: anyopaque, count: u32) ImplError!anyopaque {
    _ = instance;
    _ = queryOrOptions;
    _ = count;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAllKeys
pub fn call_getAllKeys(instance: *runtime.Instance, queryOrOptions: anyopaque, count: u32) ImplError!anyopaque {
    _ = instance;
    _ = queryOrOptions;
    _ = count;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAllRecords
pub fn call_getAllRecords(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: count
pub fn call_count(instance: *runtime.Instance, query: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = query;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: openCursor
pub fn call_openCursor(instance: *runtime.Instance, query: anyopaque, direction: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = query;
    _ = direction;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: openKeyCursor
pub fn call_openKeyCursor(instance: *runtime.Instance, query: anyopaque, direction: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = query;
    _ = direction;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: index
pub fn call_index(instance: *runtime.Instance, name: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createIndex
pub fn call_createIndex(instance: *runtime.Instance, name: runtime.DOMString, keyPath: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = name;
    _ = keyPath;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteIndex
pub fn call_deleteIndex(instance: *runtime.Instance, name: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}


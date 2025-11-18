//! Implementation for console interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const console = @import("interfaces").console;

pub const State = console.State;

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

/// Operation: assert
pub fn call_assert(instance: *runtime.Instance, condition: bool, data: anyopaque) ImplError!void {
    _ = instance;
    _ = condition;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: debug
pub fn call_debug(instance: *runtime.Instance, data: anyopaque) ImplError!void {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: error
pub fn call_error(instance: *runtime.Instance, data: anyopaque) ImplError!void {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: info
pub fn call_info(instance: *runtime.Instance, data: anyopaque) ImplError!void {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: log
pub fn call_log(instance: *runtime.Instance, data: anyopaque) ImplError!void {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: table
pub fn call_table(instance: *runtime.Instance, tabularData: anyopaque, properties: anyopaque) ImplError!void {
    _ = instance;
    _ = tabularData;
    _ = properties;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: trace
pub fn call_trace(instance: *runtime.Instance, data: anyopaque) ImplError!void {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: warn
pub fn call_warn(instance: *runtime.Instance, data: anyopaque) ImplError!void {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dir
pub fn call_dir(instance: *runtime.Instance, item: anyopaque, options: anyopaque) ImplError!void {
    _ = instance;
    _ = item;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: dirxml
pub fn call_dirxml(instance: *runtime.Instance, data: anyopaque) ImplError!void {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: count
pub fn call_count(instance: *runtime.Instance, label: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = label;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: countReset
pub fn call_countReset(instance: *runtime.Instance, label: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = label;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: group
pub fn call_group(instance: *runtime.Instance, data: anyopaque) ImplError!void {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: groupCollapsed
pub fn call_groupCollapsed(instance: *runtime.Instance, data: anyopaque) ImplError!void {
    _ = instance;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: groupEnd
pub fn call_groupEnd(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: time
pub fn call_time(instance: *runtime.Instance, label: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = label;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: timeLog
pub fn call_timeLog(instance: *runtime.Instance, label: runtime.DOMString, data: anyopaque) ImplError!void {
    _ = instance;
    _ = label;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: timeEnd
pub fn call_timeEnd(instance: *runtime.Instance, label: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = label;
    // TODO: Implement operation
    return error.NotImplemented;
}


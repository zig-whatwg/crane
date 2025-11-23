//! Implementation for TextTrack interface
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
const TextTrack = interfaces.TextTrack;

pub const State = TextTrack.State;

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

/// Getter for kind
pub fn get_kind(instance: *runtime.Instance) ImplError!enums.TextTrackKind {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for label
pub fn get_label(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for language
pub fn get_language(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for id
pub fn get_id(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for inBandMetadataTrackDispatchType
pub fn get_inBandMetadataTrackDispatchType(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for mode
pub fn get_mode(instance: *runtime.Instance) ImplError!enums.TextTrackMode {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for cues
pub fn get_cues(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for activeCues
pub fn get_activeCues(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncuechange
pub fn get_oncuechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sourceBuffer
pub fn get_sourceBuffer(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for mode
pub fn set_mode(instance: *runtime.Instance, value: enums.TextTrackMode) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncuechange
pub fn set_oncuechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: addCue
pub fn call_addCue(instance: *runtime.Instance, cue: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = cue;
    return error.NotImplemented;
}

/// Operation: removeCue
pub fn call_removeCue(instance: *runtime.Instance, cue: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = cue;
    return error.NotImplemented;
}


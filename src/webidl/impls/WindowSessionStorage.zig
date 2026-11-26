//! Implementation for the WindowSessionStorage mixin (HTML §12.2.2):
//! readonly attribute Storage sessionStorage, included by Window.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const WindowSessionStorage = interfaces.WindowSessionStorage;

pub const State = WindowSessionStorage.State;

pub const ImplError = error{
    InvalidStateError,
    SecurityError,
    OutOfMemory,
};

pub const InternalState = struct {};

/// Getter for sessionStorage (HTML §12.2.2).
pub fn get_sessionStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return dom.window_globals.sessionStorageOf(instance);
}

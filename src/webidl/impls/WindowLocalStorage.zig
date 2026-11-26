//! Implementation for the WindowLocalStorage mixin (HTML §12.2.3):
//! readonly attribute Storage localStorage, included by Window.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const WindowLocalStorage = interfaces.WindowLocalStorage;

pub const State = WindowLocalStorage.State;

pub const ImplError = error{
    InvalidStateError,
    SecurityError,
    OutOfMemory,
};

pub const InternalState = struct {};

/// Getter for localStorage (HTML §12.2.3).
pub fn get_localStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return dom.window_globals.localStorageOf(instance);
}

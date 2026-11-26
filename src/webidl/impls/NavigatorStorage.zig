//! Implementation for the NavigatorStorage mixin (WHATWG Storage Standard):
//! [SecureContext, SameObject] readonly attribute StorageManager storage,
//! shared by Navigator and WorkerNavigator.
//!
//! Each includer's generated [SameObject] getter caches the returned
//! StorageManager in its own State (`cached_storage`) and ties its wrapper
//! lifetime to the navigator's.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const NavigatorStorage = interfaces.NavigatorStorage;

pub const State = NavigatorStorage.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Getter for storage (Storage Standard): returns the StorageManager for
/// this navigator, made in its relevant realm on first use.
pub fn get_storage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.StorageManager.init(instance.ctx.allocator, instance.ctx);
}

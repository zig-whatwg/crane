//! Implementation for WorkerNavigator interface
//!
//! Spec: HTML Standard § 10.1.3 The WorkerNavigator interface
//! https://html.spec.whatwg.org/#workernavigator
//!
//! The WorkerNavigator interface provides navigator-like information
//! within worker contexts, with a subset of the Window's Navigator API.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WorkerNavigator = interfaces.WorkerNavigator;

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const InternalWorkerNavigator = workers.WorkerNavigator;

pub const State = WorkerNavigator.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for WorkerNavigator implementation
///
/// Contains a reference to the backing WorkerNavigator from src/html/workers/.
pub const InternalState = struct {
    /// Backing implementation from workers module
    internal_navigator: *InternalWorkerNavigator,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    /// Whether this object owns `internal_navigator`. A WorkerGlobalScope lends its own:
    /// the global scope owns it and outlives every object in its realm.
    owned: bool = true,

    pub fn deinit(self: *InternalState) void {
        if (self.owned) self.internal_navigator.deinit();
    }
};

/// A WorkerGlobalScope lends its own worker navigator record at construction
/// (its navigator getter). The global scope owns the record and outlives
/// every object in its realm.
pub const construction_args = .{"navigator"};

/// WorkerNavigator's own construction steps: its state over the lent record.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    if (!@hasField(@TypeOf(args), "navigator")) return;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .internal_navigator = args.navigator, .allocator = allocator, .owned = false };
    instance.getState(State).own._internal = internal;
}

/// WorkerNavigator's own teardown.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for mediaCapabilities
pub fn get_mediaCapabilities(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for serial
pub fn get_serial(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for permissions
pub fn get_permissions(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.Permissions.init(instance.ctx.allocator, instance.ctx);
}

/// Getter for usb
pub fn get_usb(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for hid
pub fn get_hid(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for serviceWorker (Service Workers 3.3): "the
/// ServiceWorkerContainer object that is associated with this" - made in its
/// relevant realm on first use and kept by the generated getter
/// ([SameObject]), which the binding ties to this object's wrapper.
pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.ServiceWorkerContainer.init(instance.ctx.allocator, instance.ctx);
}

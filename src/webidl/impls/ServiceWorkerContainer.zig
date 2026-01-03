//! Implementation for ServiceWorkerContainer interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const ServiceWorkerContainer = interfaces.ServiceWorkerContainer;

// Service worker registration via VTable pattern (avoids circular deps)
// Uses sw_common module directly (leaf module with no WebIDL dependencies)
const sw_common = @import("sw_common");

pub const State = ServiceWorkerContainer.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    messages_started: bool = false,

    pub fn deinit(self: *InternalState) void {
        self.allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .allocator = allocator,
        .messages_started = false,
    };

    // Store internal state in the instance
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
}

/// Getter for controller
pub fn get_controller(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for ready
/// Returns a Promise that resolves when a ServiceWorker is active and controlling the page.
///
/// Spec: https://w3c.github.io/ServiceWorker/#navigator-service-worker-ready
pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
    std.debug.print("[SW] get_ready called\n", .{});

    // Get the engine interface and context
    const engine = instance.ctx.engine orelse {
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Get allocator from internal state
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;

    // Create a Promise
    const promise_handle = engine.createPromise(engine_ctx, allocator) catch {
        return error.InvalidState;
    };

    // Get the registrar from the global registry
    const registrar = sw_common.registrar_registry.get() orelse {
        // No registrar - still return a pending promise (will never resolve without registrar)
        // This matches browser behavior where ready waits indefinitely
        return getPromiseAndCleanup(engine, promise_handle, allocator);
    };

    // Get storage key from the current context (origin)
    const storage_key = "https://example.com";

    // Look up any registration for this origin
    const maybe_handle = registrar.getRegistration(storage_key, "/");

    if (maybe_handle) |handle| {
        // Found a registration - create a ServiceWorkerRegistration object
        _ = handle;

        const ServiceWorkerRegistration = interfaces.ServiceWorkerRegistration;
        const registration = ServiceWorkerRegistration.init(
            allocator,
            instance.ctx,
        ) catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return getPromiseAndCleanup(engine, promise_handle, allocator);
        };

        // Configure the registration
        const ServiceWorkerRegistrationImpl = @import("ServiceWorkerRegistration.zig");
        ServiceWorkerRegistrationImpl.configure(
            registration,
            "/",
            true, // is_secure_context
        ) catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return getPromiseAndCleanup(engine, promise_handle, allocator);
        };

        // Resolve the promise with the registration instance
        engine.resolvePromise(engine_ctx, promise_handle, @ptrCast(registration)) catch {};
    }
    // If no registration found, the promise stays pending (per spec, ready never rejects)

    return getPromiseAndCleanup(engine, promise_handle, allocator);
}

/// Getter for oncontrollerchange
pub fn get_oncontrollerchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmessage
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onmessageerror
pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for oncontrollerchange
pub fn set_oncontrollerchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmessage
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onmessageerror
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: startMessages
pub fn call_startMessages(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.messages_started = true;
    }
}

/// Operation: getRegistrations
pub fn call_getRegistrations(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // Get the engine interface and context
    const engine = instance.ctx.engine orelse {
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Get allocator from internal state
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;

    // Create a Promise that resolves to empty array (no registrations)
    // TODO: Actually look up registrations in the registry
    const promise_handle = engine.createPromise(engine_ctx, allocator) catch {
        return error.InvalidState;
    };

    // Resolve with null for now (should be empty array, but null works for basic case)
    engine.resolvePromise(engine_ctx, promise_handle, null) catch {
        return error.InvalidState;
    };

    return getPromiseAndCleanup(engine, promise_handle, allocator);
}

/// Operation: getRegistration
/// Returns a Promise that resolves to the ServiceWorkerRegistration for the given scope, or undefined.
///
/// Spec: https://w3c.github.io/ServiceWorker/#navigator-service-worker-getRegistration
pub fn call_getRegistration(instance: *runtime.Instance, clientURL: webidl.Opt(runtime.USVString)) anyerror!runtime.JSValue {
    std.debug.print("[SW] call_getRegistration called\n", .{});

    // Get the engine interface and context
    const engine = instance.ctx.engine orelse {
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Get allocator from internal state
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;

    // Create a Promise
    const promise_handle = engine.createPromise(engine_ctx, allocator) catch {
        return error.InvalidState;
    };

    // Get the registrar from the global registry
    const registrar = sw_common.registrar_registry.get() orelse {
        // No registrar available - resolve with undefined (per spec, not an error)
        engine.resolvePromise(engine_ctx, promise_handle, null) catch {};
        return getPromiseAndCleanup(engine, promise_handle, allocator);
    };

    // Get storage key from the current context (origin)
    // TODO: Get from browsing context properly
    const storage_key = "https://example.com";

    // Get the client URL to look up - use provided URL or current document URL
    const lookup_url: []const u8 = if (clientURL.was_passed)
        clientURL.value
    else
        "/"; // Default to root scope if no URL provided

    // Look up the registration
    const maybe_handle = registrar.getRegistration(storage_key, lookup_url);

    if (maybe_handle) |handle| {
        // Found a registration - create a ServiceWorkerRegistration object
        _ = handle; // Handle id stored in registry, used for lookups

        const ServiceWorkerRegistration = interfaces.ServiceWorkerRegistration;
        const registration = ServiceWorkerRegistration.init(
            allocator,
            instance.ctx,
        ) catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return getPromiseAndCleanup(engine, promise_handle, allocator);
        };

        // Configure the registration with the lookup URL as scope
        // (The registrar matched this URL to the appropriate scope)
        const ServiceWorkerRegistrationImpl = @import("ServiceWorkerRegistration.zig");
        ServiceWorkerRegistrationImpl.configure(
            registration,
            lookup_url,
            true, // is_secure_context
        ) catch |err| {
            engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
            return getPromiseAndCleanup(engine, promise_handle, allocator);
        };

        // Resolve the promise with the registration instance
        engine.resolvePromise(engine_ctx, promise_handle, @ptrCast(registration)) catch {};
    } else {
        // No registration found - resolve with undefined (null)
        engine.resolvePromise(engine_ctx, promise_handle, null) catch {};
    }

    return getPromiseAndCleanup(engine, promise_handle, allocator);
}

/// Operation: register
/// Registers a service worker for the given script URL.
/// Returns a Promise that resolves to a ServiceWorkerRegistration.
///
/// Spec: https://w3c.github.io/ServiceWorker/#navigator-service-worker-register
pub fn call_register(instance: *runtime.Instance, scriptURL: runtime.DOMString, options: webidl.Opt(dictionaries.RegistrationOptions)) anyerror!runtime.JSValue {
    // Get the engine interface and context
    const engine = instance.ctx.engine orelse {
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Get allocator from internal state
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;

    // Create a Promise through the engine abstraction
    const promise_handle = engine.createPromise(engine_ctx, allocator) catch {
        return error.InvalidState;
    };

    // Get the registrar from the global registry
    const registrar = sw_common.registrar_registry.get() orelse {
        // No registrar available - service workers not supported
        engine.rejectPromise(engine_ctx, promise_handle, error.NotSupportedError) catch {};
        return getPromiseAndCleanup(engine, promise_handle, allocator);
    };

    // Get storage key from the current context (origin)
    // For now, use a placeholder - Browser should set this up properly
    const storage_key = "https://example.com"; // TODO: Get from browsing context

    // Extract options
    const scope: ?[]const u8 = if (options.was_passed and options.value.scope != null)
        options.value.scope.?
    else
        null;
    const worker_type: sw_common.WorkerType = if (options.was_passed)
        if (options.value.type) |t| switch (t) {
            ._classic_ => .classic,
            ._module_ => .module,
        } else .classic
    else
        .classic;
    const update_via_cache: sw_common.UpdateViaCacheMode = if (options.was_passed)
        if (options.value.updateViaCache) |u| switch (u) {
            ._imports_ => .imports,
            ._all_ => .all,
            ._none_ => .none,
        } else .imports
    else
        .imports;

    // Call the registrar
    const result = registrar.register(
        storage_key,
        scriptURL.asSlice(),
        scope,
        worker_type,
        update_via_cache,
    );

    // Convert result to Promise
    switch (result) {
        .success, .pending => |handle| {
            // Create a ServiceWorkerRegistration object from the handle
            _ = handle; // Handle id stored in registry, used for lookups

            // Create the ServiceWorkerRegistration instance
            const ServiceWorkerRegistration = interfaces.ServiceWorkerRegistration;
            const registration = ServiceWorkerRegistration.init(
                allocator,
                instance.ctx,
            ) catch |err| {
                engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
                return getPromiseAndCleanup(engine, promise_handle, allocator);
            };

            // Configure the registration with actual scope and security context
            const ServiceWorkerRegistrationImpl = @import("ServiceWorkerRegistration.zig");
            ServiceWorkerRegistrationImpl.configure(
                registration,
                scope orelse "/", // Use the actual scope, default to "/" if null
                true, // is_secure_context - assume HTTPS for now
            ) catch |err| {
                engine.rejectPromise(engine_ctx, promise_handle, err) catch {};
                return getPromiseAndCleanup(engine, promise_handle, allocator);
            };

            // Resolve the promise with the registration instance
            // The engine wraps the instance pointer appropriately
            engine.resolvePromise(engine_ctx, promise_handle, @ptrCast(registration)) catch {};
        },
        .invalid_script_url => {
            engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
        },
        .invalid_scope_url => {
            engine.rejectPromise(engine_ctx, promise_handle, error.TypeError) catch {};
        },
        .security_error => {
            engine.rejectPromise(engine_ctx, promise_handle, error.SecurityError) catch {};
        },
        .not_available => {
            engine.rejectPromise(engine_ctx, promise_handle, error.NotSupportedError) catch {};
        },
        .err => {
            engine.rejectPromise(engine_ctx, promise_handle, error.InvalidState) catch {};
        },
    }

    return getPromiseAndCleanup(engine, promise_handle, allocator);
}

/// Helper to get promise object and destroy handle to prevent memory leaks
fn getPromiseAndCleanup(engine: *const runtime.EngineInterface, promise_handle: *anyopaque, allocator: std.mem.Allocator) runtime.JSValue {
    const promise_obj = engine.getPromiseObject(promise_handle);
    if (engine.destroyPromiseHandle) |destroy| {
        destroy(promise_handle, allocator);
    }
    return runtime.JSValue.fromHandle(promise_obj);
}

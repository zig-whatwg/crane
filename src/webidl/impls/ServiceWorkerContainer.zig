//! Implementation for ServiceWorkerContainer interface
//!
//! Spec: Service Workers 3.4 ServiceWorkerContainer
//! https://w3c.github.io/ServiceWorker/#serviceworkercontainer-interface
//!
//! The object a Navigator's or WorkerNavigator's `serviceWorker` returns.
//! Its service worker client is its realm's environment, and what its
//! members do there - the jobs, the matching, the ready promise, the
//! controller - is the service_worker module's (src/service_worker/realm.zig),
//! which keeps the realm's environment and the promises it waits on, and its
//! client message queue - what its service workers' Client.postMessage()
//! sends waits there until startMessages(), the first set of onmessage, or
//! DOMContentLoaded enables it. Its event handlers (oncontrollerchange,
//! onmessage, onmessageerror) are the generated ones (dom.event_handlers);
//! onmessage's setter adds the queue's step.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const service_worker = @import("service_worker");
const ServiceWorkerContainer = interfaces.ServiceWorkerContainer;

pub const State = ServiceWorkerContainer.State;

pub const ImplError = error{
    NotImplemented,
};

/// No state of its own: its realm's environment is the module's.
pub const InternalState = struct {};

/// Installed once, at process start: Handle Service Worker Client Unload
/// runs as an unloading document cleanup step - for every realm that ends,
/// on its thread - and the realm's environment ends with it.
pub fn installHooks() void {
    @import("dom").unloading_cleanup.install(&service_worker.realm.environmentEnded);
    // HTML "the end" step 6.4: the client message queue is enabled after
    // DOMContentLoaded.
    @import("dom").client_message_queues.install(&service_worker.realm.enableClientMessageQueueOf);
}

/// ServiceWorkerContainer's own construction steps: the generated chain runs
/// EventTarget's first. "The user agent must create a ServiceWorkerContainer
/// object when a Navigator object or a WorkerNavigator object is created and
/// associate it with that object": its realm becomes a service worker client
/// now, and this is the object its controllerchange is fired at.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    _ = args;
    service_worker.realm.containerMade(instance);
}

/// Getter for controller (3.4.1).
pub fn get_controller(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return service_worker.realm.controller(instance);
}

/// Getter for ready (3.4.2).
pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return service_worker.realm.ready(instance);
}

/// Operation: startMessages (3.4.6) - "enable this's client message queue if
/// it is not enabled".
pub fn call_startMessages(instance: *runtime.Instance) anyerror!void {
    service_worker.realm.startMessages(instance);
}

/// Setter for onmessage (3.4.7): the generated event handler's steps, and
/// "the first time the onmessage setter steps are performed, enable this's
/// client message queue".
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try @import("dom").event_handlers.setValue(typedefs.EventHandler, instance, "onmessage", value);
    service_worker.realm.startMessages(instance);
}

/// Operation: getRegistrations (3.4.5).
pub fn call_getRegistrations(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return service_worker.realm.getRegistrations(instance);
}

/// Operation: getRegistration (3.4.4); clientURL defaults to "".
pub fn call_getRegistration(instance: *runtime.Instance, clientURL: webidl.Opt(runtime.USVString)) anyerror!runtime.JSValue {
    const client_url: []const u8 = if (clientURL.was_passed) clientURL.value else "";
    return service_worker.realm.getRegistration(instance, client_url);
}

/// Operation: register (3.4.3).
pub fn call_register(instance: *runtime.Instance, scriptURL: typedefs.TrustedScriptURLOrUSVString, options: webidl.Opt(dictionaries.RegistrationOptions)) anyerror!runtime.JSValue {
    // Service Workers register() step 2: "Let compliantScriptURL be the result
    // of invoking the get trusted type compliant string algorithm with
    // TrustedScriptURL, this's relevant global object, scriptURL,
    // "ServiceWorkerContainer register", and "script"."
    const allocator = instance.ctx.allocator;
    const compliant = try @import("dom").trusted_types.compliantStringFor(allocator, .script_url, instance, scriptURL, "ServiceWorkerContainer register");
    defer allocator.free(compliant);
    var converted: service_worker.realm.RegisterOptions = .{};
    if (options.was_passed) {
        const given = options.value;
        converted.scope = given.scope;
        if (given.type) |worker_type| converted.worker_type = switch (worker_type) {
            ._classic_ => .classic,
            ._module_ => .module,
        };
        if (given.updateViaCache) |mode| converted.update_via_cache = switch (mode) {
            ._imports_ => .imports,
            ._all_ => .all,
            ._none_ => .none,
        };
    }
    // Steps 3-8.
    return service_worker.realm.register(instance, compliant, converted);
}

//! Implementation for ServiceWorkerGlobalScope interface
//!
//! WHATWG Service Worker + Cookie Store Standard Integration
//!
//! The ServiceWorkerGlobalScope includes the cookieStore attribute and
//! oncookiechange event handler from the CookieStore API.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CookieStoreImpl = @import("CookieStore.zig");
const ServiceWorkerGlobalScope = interfaces.ServiceWorkerGlobalScope;

pub const State = ServiceWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    OutOfMemory,
};

/// Internal state for ServiceWorkerGlobalScope implementation
pub const InternalState = struct {
    /// The origin host for this service worker
    origin_host: []const u8,
    /// Whether this is a secure context
    is_secure_context: bool,
    /// Lazily initialized CookieStore instance (SameObject)
    cookie_store: ?*runtime.Instance,
    /// The oncookiechange event handler
    oncookiechange_handler: ?*const anyopaque,
    /// The oninstall event handler
    oninstall_handler: ?typedefs.EventHandler,
    /// The onactivate event handler
    onactivate_handler: ?typedefs.EventHandler,
    /// The onfetch event handler
    onfetch_handler: ?typedefs.EventHandler,
    /// The onmessage event handler
    onmessage_handler: ?typedefs.EventHandler,
    /// The onmessageerror event handler
    onmessageerror_handler: ?typedefs.EventHandler,
    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, origin_host: []const u8, is_secure_context: bool) !*InternalState {
        const internal = try allocator.create(InternalState);
        errdefer allocator.destroy(internal);

        const host_copy = try allocator.dupe(u8, origin_host);
        errdefer allocator.free(host_copy);

        internal.* = InternalState{
            .origin_host = host_copy,
            .is_secure_context = is_secure_context,
            .cookie_store = null,
            .oncookiechange_handler = null,
            .oninstall_handler = null,
            .onactivate_handler = null,
            .onfetch_handler = null,
            .onmessage_handler = null,
            .onmessageerror_handler = null,
            .allocator = allocator,
        };

        return internal;
    }

    pub fn deinit(self: *InternalState) void {
        // Note: cookie_store is owned by the runtime GC, we don't deinit it here
        self.allocator.free(self.origin_host);
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

    // Initialize internal state with default values
    const internal = try InternalState.init(allocator, "localhost", true);

    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
}

/// Helper to get internal state from instance
fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Getter for clients
pub fn get_clients(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for registration
pub fn get_registration(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for serviceWorker
pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oninstall
/// Returns the event handler for the install event
pub fn get_oninstall(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternalState(instance) orelse return null;
    return if (internal.oninstall_handler) |handler| handler else null;
}

/// Getter for onactivate
/// Returns the event handler for the activate event
pub fn get_onactivate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternalState(instance) orelse return null;
    return if (internal.onactivate_handler) |handler| handler else null;
}

/// Getter for onfetch
/// Returns the event handler for the fetch event
pub fn get_onfetch(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternalState(instance) orelse return null;
    return if (internal.onfetch_handler) |handler| handler else null;
}

/// Getter for onmessage
/// Returns the event handler for the message event
pub fn get_onmessage(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternalState(instance) orelse return null;
    return if (internal.onmessage_handler) |handler| handler else null;
}

/// Getter for onmessageerror
/// Returns the event handler for the messageerror event
pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternalState(instance) orelse return null;
    return if (internal.onmessageerror_handler) |handler| handler else null;
}

/// Getter for onperiodicsync
pub fn get_onperiodicsync(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for cookieStore
/// https://cookiestore.spec.whatwg.org/#dom-serviceworkerglobalscope-cookiestore
///
/// Returns the CookieStore for this service worker's origin.
/// CookieStore is a SecureContext-only feature.
pub fn get_cookieStore(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // SecureContext check
    if (!internal.is_secure_context) {
        return error.SecurityError;
    }

    // Lazy initialization (SameObject behavior)
    if (internal.cookie_store) |store| {
        return store;
    }

    // Create new CookieStore for this origin
    const CookieStore = interfaces.CookieStore;

    const cookie_store = CookieStoreImpl.createForOrigin(
        internal.allocator,
        CookieStore.State,
        &CookieStore.vtable,
        instance.ctx,
        internal.origin_host,
        internal.is_secure_context,
    ) catch {
        return error.OutOfMemory;
    };

    internal.cookie_store = cookie_store;
    return cookie_store;
}

/// Getter for oncookiechange
/// https://cookiestore.spec.whatwg.org/#dom-serviceworkerglobalscope-oncookiechange
pub fn get_oncookiechange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternalState(instance) orelse return null;
    // Cast the stored opaque pointer back to EventHandler type
    if (internal.oncookiechange_handler) |handler| {
        return @ptrCast(@alignCast(handler));
    }
    return null;
}

/// Getter for onsync
pub fn get_onsync(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncontentdelete
pub fn get_oncontentdelete(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbackgroundfetchsuccess
pub fn get_onbackgroundfetchsuccess(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbackgroundfetchfail
pub fn get_onbackgroundfetchfail(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbackgroundfetchabort
pub fn get_onbackgroundfetchabort(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onbackgroundfetchclick
pub fn get_onbackgroundfetchclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpush
pub fn get_onpush(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpushsubscriptionchange
pub fn get_onpushsubscriptionchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncanmakepayment
pub fn get_oncanmakepayment(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onpaymentrequest
pub fn get_onpaymentrequest(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onnotificationclick
pub fn get_onnotificationclick(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onnotificationclose
pub fn get_onnotificationclose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for oninstall
/// Sets the event handler for the install event
pub fn set_oninstall(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    internal.oninstall_handler = value;
}

/// Setter for onactivate
/// Sets the event handler for the activate event
pub fn set_onactivate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    internal.onactivate_handler = value;
}

/// Setter for onfetch
/// Sets the event handler for the fetch event
pub fn set_onfetch(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    internal.onfetch_handler = value;
}

/// Setter for onmessage
/// Sets the event handler for the message event
pub fn set_onmessage(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    internal.onmessage_handler = value;
}

/// Setter for onmessageerror
/// Sets the event handler for the messageerror event
pub fn set_onmessageerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    internal.onmessageerror_handler = value;
}

/// Setter for onperiodicsync
pub fn set_onperiodicsync(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncookiechange
/// https://cookiestore.spec.whatwg.org/#dom-serviceworkerglobalscope-oncookiechange
pub fn set_oncookiechange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    internal.oncookiechange_handler = value;
}

/// Setter for onsync
pub fn set_onsync(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncontentdelete
pub fn set_oncontentdelete(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbackgroundfetchsuccess
pub fn set_onbackgroundfetchsuccess(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbackgroundfetchfail
pub fn set_onbackgroundfetchfail(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbackgroundfetchabort
pub fn set_onbackgroundfetchabort(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onbackgroundfetchclick
pub fn set_onbackgroundfetchclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpush
pub fn set_onpush(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpushsubscriptionchange
pub fn set_onpushsubscriptionchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncanmakepayment
pub fn set_oncanmakepayment(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onpaymentrequest
pub fn set_onpaymentrequest(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onnotificationclick
pub fn set_onnotificationclick(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onnotificationclose
pub fn set_onnotificationclose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: skipWaiting
pub fn call_skipWaiting(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

// ============================================================================
// Public API for integration
// ============================================================================

/// Create a new ServiceWorkerGlobalScope for a given origin
/// This is used when creating a new service worker context.
pub fn createForOrigin(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    origin_host: []const u8,
    is_secure_context: bool,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    const internal = try InternalState.init(allocator, origin_host, is_secure_context);

    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Get the CookieStore for this service worker (if available)
pub fn getCookieStore(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternalState(instance) orelse return null;
    return internal.cookie_store;
}

/// Get the oncookiechange handler
pub fn getOncookiechangeHandler(instance: *runtime.Instance) ?*const anyopaque {
    const internal = getInternalState(instance) orelse return null;
    return internal.oncookiechange_handler;
}

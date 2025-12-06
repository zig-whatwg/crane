//! Implementation for ServiceWorkerRegistration interface
//!
//! WHATWG Service Worker + Cookie Store Standard Integration
//!
//! The ServiceWorkerRegistration includes the cookies attribute
//! which returns a CookieStoreManager for managing cookie subscriptions.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CookieStoreManagerImpl = @import("CookieStoreManager.zig");
const ServiceWorkerRegistration = interfaces.ServiceWorkerRegistration;

pub const State = ServiceWorkerRegistration.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    OutOfMemory,
};

/// Internal state for ServiceWorkerRegistration implementation
pub const InternalState = struct {
    /// The scope URL for this registration
    scope_url: []const u8,
    /// Whether this is a secure context
    is_secure_context: bool,
    /// Lazily initialized CookieStoreManager instance (SameObject)
    cookie_store_manager: ?*runtime.Instance,
    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, scope_url: []const u8, is_secure_context: bool) !*InternalState {
        const internal = try allocator.create(InternalState);
        errdefer allocator.destroy(internal);

        const scope_copy = try allocator.dupe(u8, scope_url);
        errdefer allocator.free(scope_copy);

        internal.* = InternalState{
            .scope_url = scope_copy,
            .is_secure_context = is_secure_context,
            .cookie_store_manager = null,
            .allocator = allocator,
        };

        return internal;
    }

    pub fn deinit(self: *InternalState) void {
        // Note: cookie_store_manager is owned by the runtime GC, we don't deinit it here
        self.allocator.free(self.scope_url);
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

    // Initialize internal state with default scope
    const internal = try InternalState.init(allocator, "/", true);

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

/// Getter for installing
pub fn get_installing(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for waiting
pub fn get_waiting(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for active
pub fn get_active(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for navigationPreload
pub fn get_navigationPreload(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scope
pub fn get_scope(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    return internal.scope_url;
}

/// Getter for updateViaCache
pub fn get_updateViaCache(instance: *runtime.Instance) anyerror!enums.ServiceWorkerUpdateViaCache {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onupdatefound
pub fn get_onupdatefound(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for periodicSync
pub fn get_periodicSync(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for cookies
/// https://cookiestore.spec.whatwg.org/#dom-serviceworkerregistration-cookies
///
/// Returns the CookieStoreManager for this registration.
/// CookieStoreManager is a SecureContext-only feature.
pub fn get_cookies(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // SecureContext check
    if (!internal.is_secure_context) {
        return error.SecurityError;
    }

    // Lazy initialization (SameObject behavior)
    if (internal.cookie_store_manager) |manager| {
        return manager;
    }

    // Create new CookieStoreManager for this registration
    const CookieStoreManager = interfaces.CookieStoreManager;

    const cookie_store_manager = CookieStoreManagerImpl.createForRegistration(
        internal.allocator,
        CookieStoreManager.State,
        &CookieStoreManager.vtable,
        instance.ctx,
        internal.scope_url,
        internal.is_secure_context,
    ) catch {
        return error.OutOfMemory;
    };

    internal.cookie_store_manager = cookie_store_manager;
    return cookie_store_manager;
}

/// Getter for sync
pub fn get_sync(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for index
pub fn get_index(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for backgroundFetch
pub fn get_backgroundFetch(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for paymentManager
pub fn get_paymentManager(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pushManager
pub fn get_pushManager(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onupdatefound
pub fn set_onupdatefound(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: unregister
pub fn call_unregister(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: update
pub fn call_update(instance: *runtime.Instance) anyerror!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: showNotification
pub fn call_showNotification(instance: *runtime.Instance, title: runtime.DOMString, options: webidl.Opt(dictionaries.NotificationOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = title;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getNotifications
pub fn call_getNotifications(instance: *runtime.Instance, filter: webidl.Opt(dictionaries.GetNotificationOptions)) anyerror!*const anyopaque {
    _ = instance;
    _ = filter;
    return error.NotImplemented;
}

// ============================================================================
// Public API for integration
// ============================================================================

/// Create a new ServiceWorkerRegistration for a given scope
/// This is used when registering a new service worker.
pub fn createForScope(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    scope_url: []const u8,
    is_secure_context: bool,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    const internal = try InternalState.init(allocator, scope_url, is_secure_context);

    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Get the CookieStoreManager for this registration (if available)
pub fn getCookieStoreManager(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternalState(instance) orelse return null;
    return internal.cookie_store_manager;
}

/// Get the scope URL for this registration
pub fn getScopeUrl(instance: *runtime.Instance) ?[]const u8 {
    const internal = getInternalState(instance) orelse return null;
    return internal.scope_url;
}

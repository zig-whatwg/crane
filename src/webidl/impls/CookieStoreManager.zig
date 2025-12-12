//! Implementation for CookieStoreManager interface
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//!
//! The CookieStoreManager interface manages cookie change subscriptions for
//! Service Workers. It is accessed via ServiceWorkerRegistration.cookies.
//!
//! Methods:
//! - subscribe(subscriptions): Add cookie change subscriptions
//! - getSubscriptions(): Get current subscriptions
//! - unsubscribe(subscriptions): Remove cookie change subscriptions

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CookieStoreManager = interfaces.CookieStoreManager;

pub const State = CookieStoreManager.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    SecurityError,
    OutOfMemory,
};

/// A cookie subscription (matches CookieStoreGetOptions)
pub const CookieSubscription = struct {
    /// Cookie name to subscribe to (null = all cookies)
    name: ?[]const u8,
    /// URL to scope subscription to (null = registration scope)
    url: ?[]const u8,

    /// Allocator for owned strings
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: ?[]const u8, url: ?[]const u8) !Self {
        return Self{
            .name = if (name) |n| try allocator.dupe(u8, n) else null,
            .url = if (url) |u| try allocator.dupe(u8, u) else null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.name) |n| self.allocator.free(n);
        if (self.url) |u| self.allocator.free(u);
        self.* = undefined;
    }

    pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
        return Self.init(allocator, self.name, self.url);
    }

    /// Check if two subscriptions are equal (for deduplication)
    pub fn eql(self: Self, other: Self) bool {
        const name_eq = if (self.name) |n1| blk: {
            if (other.name) |n2| {
                break :blk std.mem.eql(u8, n1, n2);
            }
            break :blk false;
        } else other.name == null;

        const url_eq = if (self.url) |url1| blk: {
            if (other.url) |url2| {
                break :blk std.mem.eql(u8, url1, url2);
            }
            break :blk false;
        } else other.url == null;

        return name_eq and url_eq;
    }
};

/// Internal state for CookieStoreManager implementation
pub const InternalState = struct {
    /// List of active subscriptions
    subscriptions: std.ArrayListUnmanaged(CookieSubscription),

    /// The scope URL for this manager (from ServiceWorkerRegistration)
    scope_url: ?[]const u8,

    /// Whether this is in a secure context
    is_secure_context: bool,

    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, scope_url: ?[]const u8, is_secure_context: bool) !*InternalState {
        const internal = try allocator.create(InternalState);
        errdefer allocator.destroy(internal);

        const scope_copy = if (scope_url) |s| try allocator.dupe(u8, s) else null;
        errdefer if (scope_copy) |s| allocator.free(s);

        internal.* = InternalState{
            .subscriptions = .{},
            .scope_url = scope_copy,
            .is_secure_context = is_secure_context,
            .allocator = allocator,
        };

        return internal;
    }

    pub fn deinit(self: *InternalState) void {
        for (self.subscriptions.items) |*sub| {
            sub.deinit();
        }
        self.subscriptions.deinit(self.allocator);

        if (self.scope_url) |s| {
            self.allocator.free(s);
        }

        self.allocator.destroy(self);
    }

    /// Add a subscription (with deduplication)
    pub fn addSubscription(self: *InternalState, name: ?[]const u8, url: ?[]const u8) !void {
        // Check for duplicate
        for (self.subscriptions.items) |existing| {
            const new_sub = CookieSubscription{
                .name = name,
                .url = url,
                .allocator = self.allocator,
            };
            if (existing.eql(new_sub)) {
                return; // Already exists
            }
        }

        const sub = try CookieSubscription.init(self.allocator, name, url);
        try self.subscriptions.append(self.allocator, sub);
    }

    /// Remove a subscription
    pub fn removeSubscription(self: *InternalState, name: ?[]const u8, url: ?[]const u8) void {
        const to_remove = CookieSubscription{
            .name = name,
            .url = url,
            .allocator = self.allocator,
        };

        var i: usize = 0;
        while (i < self.subscriptions.items.len) {
            if (self.subscriptions.items[i].eql(to_remove)) {
                var removed = self.subscriptions.orderedRemove(i);
                removed.deinit();
            } else {
                i += 1;
            }
        }
    }

    /// Check if a URL is within the scope
    pub fn isWithinScope(self: *InternalState, url: []const u8) bool {
        const scope = self.scope_url orelse return true; // No scope = allow all
        return std.mem.startsWith(u8, url, scope);
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
    const internal = try InternalState.init(allocator, null, true);

    // Store internal state pointer in state
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

/// Helper to get internal state from instance
fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Sentinel value representing "undefined" for Promise resolution
const undefined_sentinel: u8 = 0;

/// Operation: subscribe(subscriptions)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestoremanager-subscribe
///
/// Add cookie change subscriptions. Each subscription specifies a name and/or
/// URL to watch for cookie changes.
pub fn call_subscribe(instance: *runtime.Instance, subscriptions: runtime.JSValue) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // Check secure context
    if (!internal.is_secure_context) {
        return error.SecurityError;
    }

    // The subscriptions parameter is a sequence<CookieStoreGetOptions>
    // Use typed extraction for type-safe access to dictionary array
    const subs_slice = try webidl.extractDictionarySlice(
        dictionaries.CookieStoreGetOptions,
        subscriptions.toAnyopaque(),
    );

    for (subs_slice) |sub| {
        // Validate URL is within scope if provided
        if (sub.url) |url| {
            if (!internal.isWithinScope(url)) {
                return error.TypeError; // URL must be within registration scope
            }
        }

        // Add subscription
        try internal.addSubscription(sub.name, sub.url);
    }

    // Return undefined for void Promise
    return runtime.JSValue.jsUndefined;
}

/// Operation: getSubscriptions()
/// https://cookiestore.spec.whatwg.org/#dom-cookiestoremanager-getsubscriptions
///
/// Returns a Promise that resolves with the current list of subscriptions.
pub fn call_getSubscriptions(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    // TODO: Return proper V8 Array of CookieStoreGetOptions dictionaries
    // internal.subscriptions contains the subscription data
    _ = internal;
    return runtime.JSValue.jsUndefined;
}

/// Operation: unsubscribe(subscriptions)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestoremanager-unsubscribe
///
/// Remove cookie change subscriptions.
pub fn call_unsubscribe(instance: *runtime.Instance, subscriptions: runtime.JSValue) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // Check secure context
    if (!internal.is_secure_context) {
        return error.SecurityError;
    }

    // The subscriptions parameter is a sequence<CookieStoreGetOptions>
    // Use typed extraction for type-safe access to dictionary array
    const subs_slice = try webidl.extractDictionarySlice(
        dictionaries.CookieStoreGetOptions,
        subscriptions.toAnyopaque(),
    );

    for (subs_slice) |sub| {
        // Validate URL is within scope if provided
        if (sub.url) |url| {
            if (!internal.isWithinScope(url)) {
                return error.TypeError; // URL must be within registration scope
            }
        }

        // Remove subscription
        internal.removeSubscription(sub.name, sub.url);
    }

    // Return undefined for void Promise
    return runtime.JSValue.jsUndefined;
}

// ============================================================================
// Public API for integration
// ============================================================================

/// Create a new CookieStoreManager for a ServiceWorkerRegistration
/// This is used by ServiceWorkerRegistration to create its cookies attribute.
pub fn createForRegistration(
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

/// Get the subscriptions list for external access
pub fn getSubscriptions(instance: *runtime.Instance) ?[]const CookieSubscription {
    if (getInternalState(instance)) |internal| {
        return internal.subscriptions.items;
    }
    return null;
}

/// Check if a cookie change matches any subscription
pub fn matchesSubscription(instance: *runtime.Instance, cookie_name: []const u8, cookie_url: []const u8) bool {
    const internal = getInternalState(instance) orelse return false;

    // No subscriptions = match nothing
    if (internal.subscriptions.items.len == 0) {
        return false;
    }

    for (internal.subscriptions.items) |sub| {
        // Check name match (null = match all)
        const name_matches = if (sub.name) |n| std.mem.eql(u8, n, cookie_name) else true;

        // Check URL match (null = match scope)
        const url_matches = if (sub.url) |u| std.mem.startsWith(u8, cookie_url, u) else true;

        if (name_matches and url_matches) {
            return true;
        }
    }

    return false;
}

//! Service Worker Types
//!
//! Core type definitions for Service Workers implementation.
//! Based on W3C Service Workers specification Section 2.
//!
//! Spec: https://w3c.github.io/ServiceWorker/

const std = @import("std");

// =============================================================================
// Service Worker State (Section 2.1)
// =============================================================================

/// Service worker state.
///
/// A service worker has an associated state, which is one of:
/// - "parsed": Initial state after script is parsed
/// - "installing": During install event
/// - "installed": Install succeeded, waiting to activate
/// - "activating": During activate event
/// - "activated": Active and handling events
/// - "redundant": Replaced or install/activate failed
///
/// Spec: https://w3c.github.io/ServiceWorker/#service-worker-state
pub const ServiceWorkerState = enum {
    /// Initial state after script is parsed.
    parsed,

    /// During install event.
    installing,

    /// Install succeeded, waiting to activate.
    installed,

    /// During activate event.
    activating,

    /// Active and handling events.
    activated,

    /// Replaced or install/activate failed.
    redundant,

    /// Check if state transition is valid.
    ///
    /// Valid transitions per spec:
    /// - parsed -> installing
    /// - installing -> installed | redundant
    /// - installed -> activating | redundant
    /// - activating -> activated | redundant
    /// - activated -> redundant
    /// - redundant -> (terminal, no transitions)
    pub fn canTransitionTo(self: ServiceWorkerState, target: ServiceWorkerState) bool {
        return switch (self) {
            .parsed => target == .installing,
            .installing => target == .installed or target == .redundant,
            .installed => target == .activating or target == .redundant,
            .activating => target == .activated or target == .redundant,
            .activated => target == .redundant,
            .redundant => false, // Terminal state
        };
    }

    /// Get human-readable name.
    pub fn name(self: ServiceWorkerState) []const u8 {
        return switch (self) {
            .parsed => "parsed",
            .installing => "installing",
            .installed => "installed",
            .activating => "activating",
            .activated => "activated",
            .redundant => "redundant",
        };
    }
};

// =============================================================================
// Worker Type (Section 2.1)
// =============================================================================

/// Worker type - classic or module.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dfn-type
pub const WorkerType = enum {
    /// Classic script worker.
    classic,

    /// ES module worker.
    module,

    pub fn name(self: WorkerType) []const u8 {
        return switch (self) {
            .classic => "classic",
            .module => "module",
        };
    }
};

// =============================================================================
// Update Via Cache Mode (Section 2.3)
// =============================================================================

/// Update via cache mode.
///
/// Controls how the browser cache is used when checking for SW updates.
///
/// Spec: https://w3c.github.io/ServiceWorker/#enumdef-serviceworkerupdateviacache
pub const UpdateViaCacheMode = enum {
    /// Only imported scripts bypass cache.
    imports,

    /// All requests use cache.
    all,

    /// No requests use cache.
    none,

    pub fn name(self: UpdateViaCacheMode) []const u8 {
        return switch (self) {
            .imports => "imports",
            .all => "all",
            .none => "none",
        };
    }
};

// =============================================================================
// Client Types (Section 2.4, 4.6)
// =============================================================================

/// Frame type for window clients.
///
/// Spec: https://w3c.github.io/ServiceWorker/#enumdef-frametype
pub const FrameType = enum {
    /// Auxiliary browsing context.
    auxiliary,

    /// Top-level browsing context.
    top_level,

    /// Nested browsing context (iframe).
    nested,

    /// Not a window (workers).
    none,

    pub fn name(self: FrameType) []const u8 {
        return switch (self) {
            .auxiliary => "auxiliary",
            .top_level => "top-level",
            .nested => "nested",
            .none => "none",
        };
    }
};

/// Client type.
///
/// Spec: https://w3c.github.io/ServiceWorker/#enumdef-clienttype
pub const ClientType = enum {
    /// Window client.
    window,

    /// Dedicated worker client.
    worker,

    /// Shared worker client.
    sharedworker,

    /// All client types.
    all,

    pub fn name(self: ClientType) []const u8 {
        return switch (self) {
            .window => "window",
            .worker => "worker",
            .sharedworker => "sharedworker",
            .all => "all",
        };
    }
};

/// Visibility state for window clients.
///
/// Spec: https://www.w3.org/TR/page-visibility/#dom-visibilitystate
pub const VisibilityState = enum {
    /// Document is hidden.
    hidden,

    /// Document is visible.
    visible,

    pub fn name(self: VisibilityState) []const u8 {
        return switch (self) {
            .hidden => "hidden",
            .visible => "visible",
        };
    }
};

// =============================================================================
// Job Types (Appendix A)
// =============================================================================

/// Job type for the job queue.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dfn-job-type
pub const JobType = enum {
    /// Register a new service worker.
    register,

    /// Update an existing service worker.
    update,

    /// Unregister a service worker.
    unregister,

    pub fn name(self: JobType) []const u8 {
        return switch (self) {
            .register => "register",
            .update => "update",
            .unregister => "unregister",
        };
    }
};

// =============================================================================
// Router Types (Section 4.9, 4.10)
// =============================================================================

/// Running status for router conditions.
///
/// Spec: https://w3c.github.io/ServiceWorker/#enumdef-runningstatus
pub const RunningStatus = enum {
    /// Service worker is running.
    running,

    /// Service worker is not running.
    not_running,

    pub fn name(self: RunningStatus) []const u8 {
        return switch (self) {
            .running => "running",
            .not_running => "not-running",
        };
    }
};

/// Router source enum values.
///
/// Spec: https://w3c.github.io/ServiceWorker/#enumdef-routersourceenum
pub const RouterSourceEnum = enum {
    /// Use cache.
    cache,

    /// Dispatch fetch event to service worker.
    fetch_event,

    /// Go directly to network.
    network,

    /// Race network and fetch handler.
    race_network_and_fetch_handler,

    pub fn name(self: RouterSourceEnum) []const u8 {
        return switch (self) {
            .cache => "cache",
            .fetch_event => "fetch-event",
            .network => "network",
            .race_network_and_fetch_handler => "race-network-and-fetch-handler",
        };
    }
};

// =============================================================================
// Service Worker Timing Info (Section 2.2)
// =============================================================================

/// Service worker timing info.
///
/// Marks certain points in time for navigation/resource timing APIs.
///
/// Spec: https://w3c.github.io/ServiceWorker/#service-worker-timing-info
pub const ServiceWorkerTimingInfo = struct {
    /// When the service worker started.
    start_time: f64 = 0,

    /// When the fetch event was dispatched.
    fetch_event_dispatch_time: f64 = 0,

    /// When router rule evaluation started.
    worker_router_evaluation_start: f64 = 0,

    /// When cache lookup started (if routed to cache).
    worker_cache_lookup_start: f64 = 0,

    /// The matched router source (e.g., "cache", "network").
    worker_matched_router_source: []const u8 = "",

    /// The final router source used.
    worker_final_router_source: []const u8 = "",
};

// =============================================================================
// Registration Options
// =============================================================================

/// Options for registering a service worker.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dictdef-registrationoptions
pub const RegistrationOptions = struct {
    /// Scope URL for the registration.
    scope: ?[]const u8 = null,

    /// Worker type (classic or module).
    worker_type: WorkerType = .classic,

    /// Update via cache mode.
    update_via_cache: UpdateViaCacheMode = .imports,
};

// =============================================================================
// Client Query Options
// =============================================================================

/// Options for querying clients.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dictdef-clientqueryoptions
pub const ClientQueryOptions = struct {
    /// Include uncontrolled clients.
    include_uncontrolled: bool = false,

    /// Type of clients to match.
    client_type: ClientType = .window,
};

// =============================================================================
// Navigation Preload State
// =============================================================================

/// State of navigation preload.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dictdef-navigationpreloadstate
pub const NavigationPreloadState = struct {
    /// Whether navigation preload is enabled.
    enabled: bool = false,

    /// Custom header value for Service-Worker-Navigation-Preload header.
    header_value: []const u8 = "true",
};

// =============================================================================
// Cache Query Options
// =============================================================================

/// Options for cache queries.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dictdef-cachequeryoptions
pub const CacheQueryOptions = struct {
    /// Ignore query string in URL matching.
    ignore_search: bool = false,

    /// Ignore HTTP method in matching.
    ignore_method: bool = false,

    /// Ignore Vary header in matching.
    ignore_vary: bool = false,
};

/// Options for multi-cache queries.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dictdef-multicachequeryoptions
pub const MultiCacheQueryOptions = struct {
    /// Ignore query string in URL matching.
    ignore_search: bool = false,

    /// Ignore HTTP method in matching.
    ignore_method: bool = false,

    /// Ignore Vary header in matching.
    ignore_vary: bool = false,

    /// Specific cache name to search.
    cache_name: ?[]const u8 = null,

    /// Convert to CacheQueryOptions.
    pub fn toCacheQueryOptions(self: *const MultiCacheQueryOptions) CacheQueryOptions {
        return .{
            .ignore_search = self.ignore_search,
            .ignore_method = self.ignore_method,
            .ignore_vary = self.ignore_vary,
        };
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ServiceWorkerState transitions" {
    // Valid transitions
    try std.testing.expect(ServiceWorkerState.parsed.canTransitionTo(.installing));
    try std.testing.expect(ServiceWorkerState.installing.canTransitionTo(.installed));
    try std.testing.expect(ServiceWorkerState.installing.canTransitionTo(.redundant));
    try std.testing.expect(ServiceWorkerState.installed.canTransitionTo(.activating));
    try std.testing.expect(ServiceWorkerState.activating.canTransitionTo(.activated));
    try std.testing.expect(ServiceWorkerState.activated.canTransitionTo(.redundant));

    // Invalid transitions
    try std.testing.expect(!ServiceWorkerState.parsed.canTransitionTo(.activated));
    try std.testing.expect(!ServiceWorkerState.redundant.canTransitionTo(.parsed));
    try std.testing.expect(!ServiceWorkerState.activated.canTransitionTo(.installing));
}

test "ServiceWorkerState names" {
    try std.testing.expectEqualStrings("parsed", ServiceWorkerState.parsed.name());
    try std.testing.expectEqualStrings("installing", ServiceWorkerState.installing.name());
    try std.testing.expectEqualStrings("activated", ServiceWorkerState.activated.name());
}

test "WorkerType names" {
    try std.testing.expectEqualStrings("classic", WorkerType.classic.name());
    try std.testing.expectEqualStrings("module", WorkerType.module.name());
}

test "UpdateViaCacheMode names" {
    try std.testing.expectEqualStrings("imports", UpdateViaCacheMode.imports.name());
    try std.testing.expectEqualStrings("all", UpdateViaCacheMode.all.name());
    try std.testing.expectEqualStrings("none", UpdateViaCacheMode.none.name());
}

test "FrameType names" {
    try std.testing.expectEqualStrings("top-level", FrameType.top_level.name());
    try std.testing.expectEqualStrings("nested", FrameType.nested.name());
}

test "ClientType names" {
    try std.testing.expectEqualStrings("window", ClientType.window.name());
    try std.testing.expectEqualStrings("sharedworker", ClientType.sharedworker.name());
}

test "JobType names" {
    try std.testing.expectEqualStrings("register", JobType.register.name());
    try std.testing.expectEqualStrings("update", JobType.update.name());
    try std.testing.expectEqualStrings("unregister", JobType.unregister.name());
}

test "RouterSourceEnum names" {
    try std.testing.expectEqualStrings("cache", RouterSourceEnum.cache.name());
    try std.testing.expectEqualStrings("fetch-event", RouterSourceEnum.fetch_event.name());
    try std.testing.expectEqualStrings("network", RouterSourceEnum.network.name());
}

test "ServiceWorkerTimingInfo defaults" {
    const timing = ServiceWorkerTimingInfo{};
    try std.testing.expectEqual(@as(f64, 0), timing.start_time);
    try std.testing.expectEqual(@as(f64, 0), timing.fetch_event_dispatch_time);
}

test "RegistrationOptions defaults" {
    const opts = RegistrationOptions{};
    try std.testing.expect(opts.scope == null);
    try std.testing.expectEqual(WorkerType.classic, opts.worker_type);
    try std.testing.expectEqual(UpdateViaCacheMode.imports, opts.update_via_cache);
}

test "ClientQueryOptions defaults" {
    const opts = ClientQueryOptions{};
    try std.testing.expect(!opts.include_uncontrolled);
    try std.testing.expectEqual(ClientType.window, opts.client_type);
}

test "CacheQueryOptions defaults" {
    const opts = CacheQueryOptions{};
    try std.testing.expect(!opts.ignore_search);
    try std.testing.expect(!opts.ignore_method);
    try std.testing.expect(!opts.ignore_vary);
}

//! Standalone service worker fetch integration module.
//! This module can be imported by browser without circular dependencies.
//! It provides fetch interception infrastructure for service workers.
//!
//! NOTE: The registrar (for navigator.serviceWorker.register()) is NOT
//! included here due to circular dependency issues. It must be initialized
//! separately through a different path.

pub const RegistrationMap = @import("registration_map.zig").RegistrationMap;
pub const ScopeToJobQueueMap = @import("job.zig").ScopeToJobQueueMap;
pub const fetch_interceptor = @import("integration/fetch_interceptor_impl.zig");

/// Initialize and register the service worker fetch interceptor.
/// Call this during browser initialization.
pub fn ensureRegistered(allocator: @import("std").mem.Allocator, registration_map: *RegistrationMap) bool {
    return fetch_interceptor.ensureRegistered(allocator, registration_map);
}

/// Unregister the service worker fetch interceptor.
/// Call this during browser cleanup.
pub fn unregister(allocator: @import("std").mem.Allocator) void {
    fetch_interceptor.unregister(allocator);
}

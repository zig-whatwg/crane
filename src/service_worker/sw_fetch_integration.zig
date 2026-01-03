//! Standalone service worker fetch integration module.
//! This module can be imported by browser without circular dependencies.
//! It only includes the minimal code needed for fetch interception.

pub const RegistrationMap = @import("registration_map.zig").RegistrationMap;
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

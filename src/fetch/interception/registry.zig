//! WHATWG Fetch Standard - Fetch Interceptor Registry
//!
//! Thread-safe global registry for the active FetchInterceptor.
//! Uses atomic operations for lock-free read/write access.
//!
//! Architecture:
//! - Single active interceptor (can be replaced with chain later)
//! - Browser.init() registers the service worker interceptor
//! - http_fetch.zig reads via get() on each request
//! - Browser.deinit() unregisters before cleanup
//!
//! Thread Safety:
//! - Uses atomic load/store with acquire/release semantics
//! - Safe for concurrent read access from multiple fetch operations
//! - Write operations (register/unregister) should be serialized by caller

const std = @import("std");
const FetchInterceptor = @import("fetch_interceptor.zig").FetchInterceptor;

// =============================================================================
// Global Registry State
// =============================================================================

/// Global interceptor pointer, atomically accessed.
/// null means no interceptor is registered.
var g_interceptor: std.atomic.Value(?*const FetchInterceptor) = std.atomic.Value(?*const FetchInterceptor).init(null);

// =============================================================================
// Registry API
// =============================================================================

/// Register a fetch interceptor.
///
/// The interceptor must remain valid until unregister() is called.
/// Typically called once during Browser.init().
///
/// If an interceptor is already registered, it will be replaced.
/// The caller is responsible for cleaning up the old interceptor if needed.
///
/// Thread Safety: Uses release semantics to ensure all writes to the
/// interceptor object are visible to readers.
pub fn register(interceptor: *const FetchInterceptor) void {
    g_interceptor.store(interceptor, .release);
}

/// Unregister the current fetch interceptor.
///
/// Should be called before freeing the interceptor object.
/// Typically called during Browser.deinit().
///
/// Thread Safety: Uses release semantics. After this returns,
/// new get() calls will return null. However, in-flight fetch
/// operations may still hold a reference to the old interceptor.
/// Caller should ensure no fetches are in progress before freeing.
pub fn unregister() void {
    g_interceptor.store(null, .release);
}

/// Get the currently registered fetch interceptor, if any.
///
/// Returns null if no interceptor is registered.
/// Called by http_fetch.zig on each fetch request.
///
/// Thread Safety: Uses acquire semantics to ensure all writes
/// to the interceptor object are visible after loading the pointer.
pub fn get() ?*const FetchInterceptor {
    return g_interceptor.load(.acquire);
}

/// Check if an interceptor is currently registered.
///
/// Convenience function for conditional logic.
pub fn isRegistered() bool {
    return get() != null;
}

// =============================================================================
// Testing Support
// =============================================================================

/// Reset the registry to its initial state.
/// Only for use in tests to ensure isolation between test cases.
pub fn resetForTesting() void {
    g_interceptor.store(null, .seq_cst);
}

// =============================================================================
// Tests
// =============================================================================

test "registry - register and get" {
    // Ensure clean state
    resetForTesting();

    try std.testing.expect(get() == null);
    try std.testing.expect(!isRegistered());

    // Create a mock interceptor
    const mock_vtable = FetchInterceptor.VTable{
        .intercept = undefined, // Not called in this test
    };
    const mock_interceptor = FetchInterceptor{
        .ptr = undefined,
        .vtable = &mock_vtable,
    };

    // Register
    register(&mock_interceptor);
    try std.testing.expect(get() != null);
    try std.testing.expect(isRegistered());

    // Unregister
    unregister();
    try std.testing.expect(get() == null);
    try std.testing.expect(!isRegistered());
}

test "registry - replace interceptor" {
    resetForTesting();

    const vtable1 = FetchInterceptor.VTable{ .intercept = undefined };
    const vtable2 = FetchInterceptor.VTable{ .intercept = undefined };

    const interceptor1 = FetchInterceptor{ .ptr = undefined, .vtable = &vtable1 };
    const interceptor2 = FetchInterceptor{ .ptr = undefined, .vtable = &vtable2 };

    register(&interceptor1);
    try std.testing.expect(get().?.vtable == &vtable1);

    register(&interceptor2);
    try std.testing.expect(get().?.vtable == &vtable2);

    unregister();
}

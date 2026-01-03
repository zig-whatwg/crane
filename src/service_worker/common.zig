//! Service Worker Common Types
//!
//! Leaf types that have NO WebIDL dependencies.
//! Safe to import from Browser and other modules that cannot import WebIDL.
//!
//! This module breaks the circular dependency:
//! Browser -> service_worker -> webidl/interfaces -> browser
//!
//! By providing types that Browser can import without pulling in WebIDL.

const std = @import("std");

// Re-export all leaf types from types.zig
pub const types = @import("types.zig");

// Core enums (no dependencies)
pub const ServiceWorkerState = types.ServiceWorkerState;
pub const WorkerType = types.WorkerType;
pub const UpdateViaCacheMode = types.UpdateViaCacheMode;
pub const FrameType = types.FrameType;
pub const ClientType = types.ClientType;
pub const VisibilityState = types.VisibilityState;
pub const JobType = types.JobType;
pub const RunningStatus = types.RunningStatus;
pub const RouterSourceEnum = types.RouterSourceEnum;

// Timing info (no dependencies)
pub const ServiceWorkerTimingInfo = types.ServiceWorkerTimingInfo;

// Options structs (no dependencies)
pub const RegistrationOptions = types.RegistrationOptions;
pub const ClientQueryOptions = types.ClientQueryOptions;
pub const NavigationPreloadState = types.NavigationPreloadState;
pub const CacheQueryOptions = types.CacheQueryOptions;
pub const MultiCacheQueryOptions = types.MultiCacheQueryOptions;

// =============================================================================
// Opaque Handles for Cross-Layer Communication
// =============================================================================

/// Opaque handle for a service worker registration.
/// Used by Browser to reference registrations without importing WebIDL types.
pub const RegistrationHandle = struct {
    id: u64,

    pub const invalid: RegistrationHandle = .{ .id = 0 };

    pub fn isValid(self: RegistrationHandle) bool {
        return self.id != 0;
    }
};

/// Opaque handle for a service worker instance.
/// Used by Browser to reference workers without importing WebIDL types.
pub const ServiceWorkerHandle = struct {
    id: u64,

    pub const invalid: ServiceWorkerHandle = .{ .id = 0 };

    pub fn isValid(self: ServiceWorkerHandle) bool {
        return self.id != 0;
    }
};

/// Registration key for looking up registrations by scope.
/// This is a value type that can be used as a hash map key.
pub const RegistrationKey = struct {
    /// The serialized storage key (origin).
    storage_key: []const u8,
    /// The scope URL.
    scope: []const u8,

    pub fn hash(self: RegistrationKey) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(self.storage_key);
        hasher.update(self.scope);
        return hasher.final();
    }

    pub fn eql(a: RegistrationKey, b: RegistrationKey) bool {
        return std.mem.eql(u8, a.storage_key, b.storage_key) and
            std.mem.eql(u8, a.scope, b.scope);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "RegistrationHandle validity" {
    const invalid = RegistrationHandle.invalid;
    try std.testing.expect(!invalid.isValid());

    const valid = RegistrationHandle{ .id = 42 };
    try std.testing.expect(valid.isValid());
}

test "ServiceWorkerHandle validity" {
    const invalid = ServiceWorkerHandle.invalid;
    try std.testing.expect(!invalid.isValid());

    const valid = ServiceWorkerHandle{ .id = 42 };
    try std.testing.expect(valid.isValid());
}

test "RegistrationKey hashing" {
    const key1 = RegistrationKey{
        .storage_key = "https://example.com",
        .scope = "/app/",
    };
    const key2 = RegistrationKey{
        .storage_key = "https://example.com",
        .scope = "/app/",
    };
    const key3 = RegistrationKey{
        .storage_key = "https://other.com",
        .scope = "/app/",
    };

    try std.testing.expectEqual(key1.hash(), key2.hash());
    try std.testing.expect(key1.hash() != key3.hash());
    try std.testing.expect(key1.eql(key2));
    try std.testing.expect(!key1.eql(key3));
}

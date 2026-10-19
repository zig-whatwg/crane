//! W3C Permissions API
//!
//! Spec: https://www.w3.org/TR/permissions/
//!
//! Native permission types and pure query rules. The live Permissions API
//! is implemented by the WebIDL Permissions and PermissionStatus interfaces;
//! it uses `query` and these value types, not the legacy storage or registry.
//!
//! ## Overview
//!
//! The standard API queries powerful-feature permissions. The legacy native
//! `Permissions`, `PermissionStorage` and `PermissionStatusRegistry` below
//! are standalone helpers, not a per-Browser store or change notification
//! implementation. Their request/revoke methods are not standard API methods.
//!
//! ## Permission States
//!
//! Permissions can be in one of three states:
//! - `granted`: User has explicitly granted permission
//! - `denied`: User has explicitly denied permission
//! - `prompt`: User has not yet made a decision (default)
//!
//! ## Legacy native helper usage
//!
//! ```zig
//! const allocator = std.heap.page_allocator;
//!
//! // Create storage and permissions
//! var storage = PermissionStorage.init(allocator);
//! defer storage.deinit();
//!
//! const origin = Origin.createBorrowed("https", "example.com", 443);
//! var permissions = Permissions.init(allocator, &storage, origin);
//! defer permissions.deinit();
//!
//! // Query permission state
//! const status = try permissions.query(PermissionDescriptor.simple(.geolocation));
//! defer permissions.releaseStatus(status);
//!
//! if (status.state == .granted) {
//!     // Permission already granted
//! } else if (status.state == .prompt) {
//!     // Need to request permission
//! }
//! ```

const std = @import("std");

// Core types
pub const types = @import("types.zig");
pub const PermissionName = types.PermissionName;
pub const PermissionState = types.PermissionState;
pub const PermissionDescriptor = types.PermissionDescriptor;
pub const PermissionExtra = types.PermissionExtra;
pub const Origin = types.Origin;

// Rules used by the live WebIDL query implementation (no native registry).
pub const query = @import("query.zig");
pub const OverrideStore = @import("override_store.zig").OverrideStore;
pub const ChangeBatch = @import("change_batch.zig").ChangeBatch;
pub const BrowserStore = @import("browser_store.zig").BrowserStore;

// Storage
pub const storage = @import("storage.zig");
pub const PermissionStorage = storage.PermissionStorage;
pub const PermissionKey = storage.PermissionKey;
pub const StorageBackend = storage.StorageBackend;

// Status
pub const status = @import("status.zig");
pub const PermissionStatus = status.PermissionStatus;
pub const PermissionStatusRegistry = status.PermissionStatusRegistry;

// Main interface
pub const permissions = @import("permissions.zig");
pub const Permissions = permissions.Permissions;
pub const isGranted = permissions.isGranted;
pub const isDenied = permissions.isDenied;
pub const needsRequest = permissions.needsRequest;

test {
    // Import all submodule tests
    _ = types;
    _ = storage;
    _ = status;
    _ = permissions;
    _ = query;
    _ = @import("change_batch.zig");
}

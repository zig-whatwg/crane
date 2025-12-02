//! W3C Permissions API
//!
//! Spec: https://www.w3.org/TR/permissions/
//!
//! This module provides Zig implementation of the W3C Permissions API,
//! which allows web applications to query and request permission states
//! for powerful features like geolocation, camera, microphone, etc.
//!
//! ## Overview
//!
//! The Permissions API provides a consistent way to:
//! - Query the current state of a permission (`query`)
//! - Request permission from the user (`request`)
//! - Revoke a previously granted permission (`revoke`)
//!
//! ## Permission States
//!
//! Permissions can be in one of three states:
//! - `granted`: User has explicitly granted permission
//! - `denied`: User has explicitly denied permission
//! - `prompt`: User has not yet made a decision (default)
//!
//! ## Usage
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
}

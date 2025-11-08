//! Blob URL Support
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#concept-url-blob-entry
//! File API: https://w3c.github.io/FileAPI/#blob-url-entry
//! Spec Reference: Lines 819-821, 1025, 1602
//!
//! Blob URLs are special URLs that refer to Blob objects. The actual blob URL
//! store and resolution logic is defined in the File API specification, not
//! the URL Standard. This module provides the hooks for integrating with an
//! external blob URL store.

const std = @import("std");
const Origin = @import("origin").Origin;

/// Blob URL Entry (opaque type)
///
/// This represents a blob URL entry from the File API specification.
/// The actual structure is defined externally (in a File API implementation).
///
/// Spec: https://w3c.github.io/FileAPI/#blob-url-entry
///
/// A blob URL entry contains:
/// - object: a Blob object
/// - environment: a settings object (contains origin)
pub const BlobURLEntry = opaque {
    /// Get the origin from a blob URL entry's environment
    ///
    /// This is a hook that must be implemented by the File API.
    /// The default implementation returns an opaque origin.
    pub fn getOrigin(self: *const BlobURLEntry, allocator: std.mem.Allocator) !Origin {
        _ = self;
        _ = allocator;
        // Default: return opaque origin
        // A real File API implementation would:
        // 1. Get the entry's environment
        // 2. Get the environment's origin
        // 3. Return that origin
        return Origin{ .opaque_origin = {} };
    }
};

/// Blob URL Store (abstract interface)
///
/// This is the interface for resolving blob URLs. A File API implementation
/// must provide this functionality.
pub const BlobURLStore = struct {
    /// Resolve a blob URL to a blob URL entry
    ///
    /// Spec: https://w3c.github.io/FileAPI/#blob-url-resolve
    ///
    /// This function is called during URL parsing (spec line 1025).
    /// It should:
    /// 1. Look up the URL string in the blob URL store
    /// 2. Return the corresponding blob URL entry, or null if not found
    ///
    /// Note: This is a hook for external implementation. The default
    /// implementation always returns null.
    resolveFn: *const fn (url_string: []const u8) ?*BlobURLEntry,

    /// Create a default blob URL store (no-op implementation)
    pub fn default() BlobURLStore {
        return .{
            .resolveFn = &defaultResolve,
        };
    }

    /// Resolve a blob URL using this store
    pub fn resolve(self: BlobURLStore, url_string: []const u8) ?*BlobURLEntry {
        return self.resolveFn(url_string);
    }

    /// Default resolve implementation (always returns null)
    fn defaultResolve(url_string: []const u8) ?*BlobURLEntry {
        _ = url_string;
        return null;
    }
};

/// Global blob URL store instance
///
/// This can be set by a File API implementation to provide blob URL resolution.
/// By default, it's a no-op store that always returns null.
pub var global_blob_store: BlobURLStore = BlobURLStore.default();

/// Set the global blob URL store
///
/// This should be called by a File API implementation during initialization.
pub fn setGlobalBlobStore(store: BlobURLStore) void {
    global_blob_store = store;
}

/// Resolve a blob URL using the global store
///
/// This is called during URL parsing (spec line 1025).
pub fn resolveBlobURL(url_string: []const u8) ?*BlobURLEntry {
    return global_blob_store.resolve(url_string);
}

// Tests

test "blob URL store - default returns null" {
    const entry = resolveBlobURL("blob:https://example.com/550e8400");
    try std.testing.expect(entry == null);
}

test "blob URL entry - default origin is opaque" {
    // We can't test this without a real blob URL entry, but we document
    // the expected behavior:
    //
    // const entry: *BlobURLEntry = ...;
    // const origin = try entry.getOrigin(allocator);
    // defer origin.deinit(allocator);
    // try std.testing.expect(origin == .opaque_origin);
}

test "blob URL store - custom implementation" {
    const TestStore = struct {
        fn customResolve(url_string: []const u8) ?*BlobURLEntry {
            // In a real implementation, this would:
            // 1. Parse the URL
            // 2. Look it up in a hash map
            // 3. Return the entry if found
            _ = url_string;
            return null;
        }
    };

    const store = BlobURLStore{ .resolveFn = &TestStore.customResolve };
    const entry = store.resolve("blob:https://example.com/550e8400");
    try std.testing.expect(entry == null);
}

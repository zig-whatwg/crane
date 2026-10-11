//! Blob URL Support
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#concept-url-blob-entry
//! File API: https://w3c.github.io/FileAPI/#blob-url-entry
//! Spec Reference: Lines 819-821, 1025, 1602
//!
//! Blob URLs are special URLs that refer to Blob objects. The actual blob URL
//! store and resolution logic is defined in the File API specification, not
//! the URL Standard: the store is the file module's (file.BlobURLStore, one
//! per Browser). This module gives the URL record its blob URL entry type.
//! (Its second, process-wide store - a resolver hook nothing installed or
//! called - was deleted with instances B3.)

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

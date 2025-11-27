//! W3C File API Implementation in Zig
//!
//! This library implements the W3C File API specification, providing
//! web-compatible file handling APIs for Blob, File, FileList, and FileReader.
//!
//! Spec: https://www.w3.org/TR/FileAPI/
//!
//! ## Current Status
//!
//! - BlobData internal structure: ✅ Complete
//! - FileData internal structure: ✅ Complete
//! - FileListData internal structure: ✅ Complete
//! - FileReaderData internal structure: ✅ Complete
//! - BlobURLStore: ✅ Complete
//! - Algorithms:
//!   - slice-blob: ✅ Complete
//!   - process-blob-parts: ✅ Complete
//!   - convert-line-endings-to-native: ✅ Complete
//!   - package-data: ✅ Complete
//!   - read-operation: ✅ Complete (sync placeholder)
//!
//! ## Usage
//!
//! ```zig
//! const file = @import("file");
//!
//! // Create a blob
//! const blob = try file.BlobData.init(allocator, "Hello, World!", "text/plain");
//! defer blob.deinit();
//!
//! // Slice a blob
//! const sliced = try file.algorithms.sliceBlob(allocator, blob, 0, 5, null);
//! defer sliced.deinit();
//!
//! // Create a file
//! const file_data = try file.FileData.init(allocator, blob, "hello.txt", null);
//! defer file_data.deinit();
//! ```
//!
//! ## Integration with WebIDL
//!
//! The internal data structures in this module are used by the WebIDL
//! interface implementations in `src/webidl/impls/`:
//! - Blob.zig
//! - File.zig
//! - FileList.zig
//! - FileReader.zig
//! - FileReaderSync.zig
//!
//! ## Thread Safety
//!
//! All structures in this module are designed for single-threaded access
//! within a JavaScript realm. Cross-realm transfer requires structured cloning.

const std = @import("std");

// ============================================================================
// Internal Data Structures
// ============================================================================

/// Internal data storage for Blob objects.
/// Represents an immutable sequence of bytes with an optional MIME type.
pub const BlobData = @import("blob_internals.zig").BlobData;

/// Internal data storage for File objects.
/// Extends BlobData with name and lastModified attributes.
pub const FileData = @import("file_internals.zig").FileData;

/// Internal data storage for FileList objects.
/// A read-only list of File objects.
pub const FileListData = @import("file_list_internals.zig").FileListData;

/// Internal data storage for FileReader objects.
/// Manages the state machine for async file reading.
pub const FileReaderData = @import("file_reader_internals.zig").FileReaderData;

/// FileReader state constants.
pub const FileReaderState = @import("file_reader_internals.zig").FileReaderState;

/// The type of read operation for FileReader.
pub const ReadType = @import("file_reader_internals.zig").ReadType;

/// Result of a FileReader read operation.
pub const ReadResult = @import("file_reader_internals.zig").ReadResult;

/// Global blob URL store for createObjectURL/revokeObjectURL.
pub const BlobURLStore = @import("blob_url_store.zig").BlobURLStore;

/// Entry in the blob URL store.
pub const BlobURLEntry = @import("blob_url_store.zig").BlobURLEntry;

// ============================================================================
// Algorithms
// ============================================================================

/// W3C File API algorithms.
pub const algorithms = struct {
    /// Slice blob algorithm per W3C File API spec §2.
    /// Creates a new Blob from a byte range of an existing Blob.
    pub const sliceBlob = @import("algorithms/slice_blob.zig").sliceBlob;

    /// Process blob parts algorithm per W3C File API spec §3.1.
    /// Converts BlobPart sequence to a single byte sequence.
    pub const processBlobParts = @import("algorithms/process_blob_parts.zig").processBlobParts;

    /// BlobPart union type for process blob parts.
    pub const BlobPart = @import("algorithms/process_blob_parts.zig").BlobPart;

    /// Options for processing blob parts.
    pub const ProcessOptions = @import("algorithms/process_blob_parts.zig").ProcessOptions;

    /// Line ending conversion mode.
    pub const Endings = @import("algorithms/process_blob_parts.zig").Endings;

    /// Convert line endings to native format per W3C File API spec.
    pub const convertLineEndingsToNative = @import("algorithms/line_endings.zig").convertLineEndingsToNative;

    /// Convert line endings with allocation.
    pub const convertLineEndingsToNativeAlloc = @import("algorithms/line_endings.zig").convertLineEndingsToNativeAlloc;

    /// Native line ending for current platform.
    pub const NATIVE_LINE_ENDING = @import("algorithms/line_endings.zig").NATIVE_LINE_ENDING;

    /// Package data algorithm per W3C File API spec §6.1.
    /// Converts raw bytes to the format requested by FileReader.
    pub const packageData = @import("algorithms/package_data.zig").packageData;

    /// Package data read type.
    pub const PackageReadType = @import("algorithms/package_data.zig").ReadType;

    /// Package data result.
    pub const PackageResult = @import("algorithms/package_data.zig").PackageResult;

    /// Start a read operation on a FileReader.
    pub const startReadOperation = @import("algorithms/read_operation.zig").startReadOperation;

    /// Abort an in-progress read operation.
    pub const abortReadOperation = @import("algorithms/read_operation.zig").abortReadOperation;

    /// Read operation error types.
    pub const ReadError = @import("algorithms/read_operation.zig").ReadError;
};

// ============================================================================
// Tests
// ============================================================================

test {
    // Run all tests from imported modules
    std.testing.refAllDecls(@This());

    // Internal data structures
    _ = @import("blob_internals.zig");
    _ = @import("file_internals.zig");
    _ = @import("file_list_internals.zig");
    _ = @import("file_reader_internals.zig");
    _ = @import("blob_url_store.zig");

    // Algorithms
    _ = @import("algorithms/slice_blob.zig");
    _ = @import("algorithms/process_blob_parts.zig");
    _ = @import("algorithms/line_endings.zig");
    _ = @import("algorithms/package_data.zig");
    _ = @import("algorithms/read_operation.zig");
}

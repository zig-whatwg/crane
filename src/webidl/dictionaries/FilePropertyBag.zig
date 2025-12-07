//! WebIDL dictionary: FilePropertyBag
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const BlobPropertyBag = @import("BlobPropertyBag.zig").BlobPropertyBag;

pub const FilePropertyBag = struct {
    // Inherited from BlobPropertyBag
    base: BlobPropertyBag,

    lastModified: ?i64 = null,
};

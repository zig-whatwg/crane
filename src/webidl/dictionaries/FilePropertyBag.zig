//! WebIDL dictionary: FilePropertyBag
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const BlobPropertyBag = @import("BlobPropertyBag.zig").BlobPropertyBag;

pub const FilePropertyBag = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from BlobPropertyBag
    base: BlobPropertyBag,

    lastModified: ?i64 = null,
};

//! WebIDL dictionary: SharedStorageSetMethodOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const SharedStorageModifierMethodOptions = @import("SharedStorageModifierMethodOptions.zig").SharedStorageModifierMethodOptions;

pub const SharedStorageSetMethodOptions = struct {
    // Inherited from SharedStorageModifierMethodOptions
    base: SharedStorageModifierMethodOptions,

    ignoreIfPresent: ?bool = null,
};

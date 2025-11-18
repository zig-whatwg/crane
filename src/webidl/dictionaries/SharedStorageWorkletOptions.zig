//! WebIDL dictionary: SharedStorageWorkletOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const WorkletOptions = @import("WorkletOptions.zig").WorkletOptions;

pub const SharedStorageWorkletOptions = struct {
    // Inherited from WorkletOptions
    base: WorkletOptions,

    dataOrigin: ?runtime.DOMString = null,
};

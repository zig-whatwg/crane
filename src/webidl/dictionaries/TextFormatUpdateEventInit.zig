//! WebIDL dictionary: TextFormatUpdateEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const EventInit = @import("EventInit.zig").EventInit;

pub const TextFormatUpdateEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    textFormats: ?[]const *runtime.Instance = null,
};

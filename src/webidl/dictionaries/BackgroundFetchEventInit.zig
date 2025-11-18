//! WebIDL dictionary: BackgroundFetchEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const BackgroundFetchEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    registration: anyopaque,
};

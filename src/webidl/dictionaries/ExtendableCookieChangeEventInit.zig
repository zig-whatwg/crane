//! WebIDL dictionary: ExtendableCookieChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const ExtendableEventInit = @import("ExtendableEventInit.zig").ExtendableEventInit;

pub const ExtendableCookieChangeEventInit = struct {
    // Inherited from ExtendableEventInit
    base: ExtendableEventInit,

    changed: ?typedefs.CookieList = null,
    deleted: ?typedefs.CookieList = null,
};

//! WebIDL typedef: PushMessageDataInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PushMessageDataInit = union(enum) {
    variant_0: *const anyopaque,
    variant_1: runtime.USVString,
};

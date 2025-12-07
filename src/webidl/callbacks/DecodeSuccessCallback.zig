//! WebIDL callback: DecodeSuccessCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const DecodeSuccessCallback = *const fn (decodedData: *const anyopaque) void;

//! WebIDL callback: BlobCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const BlobCallback = *const fn (blob: ?*const anyopaque) void;

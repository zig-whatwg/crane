//! WebIDL callback: BlobCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const BlobCallback = *const fn (blob: ?*const anyopaque) void;

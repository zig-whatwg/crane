//! WebIDL callback: FileCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const FileCallback = *const fn (file: *const anyopaque) void;

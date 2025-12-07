//! WebIDL callback: RunFunctionForSharedStorageSelectURLOperation
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const RunFunctionForSharedStorageSelectURLOperation = *const fn (urls: *const anyopaque, data: webidl.Opt(v8.JSValue)) *const anyopaque;

//! WebIDL callback: LockGrantedCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const LockGrantedCallback = *const fn (lock: ?runtime.JSValue) runtime.JSValue;

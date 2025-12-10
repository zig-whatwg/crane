//! WebIDL callback: UnderlyingSinkWriteCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const UnderlyingSinkWriteCallback = *const fn (chunk: runtime.JSValue, controller: *runtime.Instance) runtime.JSValue;

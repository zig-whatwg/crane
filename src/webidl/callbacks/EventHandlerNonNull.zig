//! WebIDL callback: EventHandlerNonNull
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const EventHandlerNonNull = *const fn (event: *const anyopaque) runtime.JSValue;

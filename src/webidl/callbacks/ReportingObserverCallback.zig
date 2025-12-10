//! WebIDL callback: ReportingObserverCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const ReportingObserverCallback = *const fn (reports: runtime.JSValue, observer: runtime.JSValue) void;

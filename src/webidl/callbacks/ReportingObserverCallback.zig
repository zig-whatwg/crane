//! WebIDL callback: ReportingObserverCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const ReportingObserverCallback = *const fn (reports: *const anyopaque, observer: *const anyopaque) void;

//! WebIDL callback: NotificationPermissionCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");

pub const NotificationPermissionCallback = *const fn (permission: *const anyopaque) void;

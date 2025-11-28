//! WebIDL callback: NotificationPermissionCallback
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const NotificationPermissionCallback = *const fn (permission: *const anyopaque) void;

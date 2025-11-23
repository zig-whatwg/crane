//! WebIDL dictionary: RouterCondition
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RouterCondition = struct {
    urlPattern: ?*const anyopaque = null,
    requestMethod: ?runtime.ByteString = null,
    requestMode: ?*const anyopaque = null,
    requestDestination: ?*const anyopaque = null,
    runningStatus: ?*const anyopaque = null,
    _or: ?*const anyopaque = null,
    not: ?*const anyopaque = null,
};

//! WebIDL dictionary: RouterCondition
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const RouterCondition = struct {
    urlPattern: ?anyopaque = null,
    requestMethod: ?runtime.DOMString = null,
    requestMode: ?anyopaque = null,
    requestDestination: ?anyopaque = null,
    runningStatus: ?anyopaque = null,
    _or: ?anyopaque = null,
    not: ?anyopaque = null,
};

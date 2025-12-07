//! WebIDL dictionary: RouterCondition
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const RouterCondition = struct {
    urlPattern: ?typedefs.URLPatternCompatible = null,
    requestMethod: ?runtime.ByteString = null,
    requestMode: ?enums.RequestMode = null,
    requestDestination: ?enums.RequestDestination = null,
    runningStatus: ?enums.RunningStatus = null,
    _or: ?[]const RouterCondition = null,
    not: ?RouterCondition = null,
};

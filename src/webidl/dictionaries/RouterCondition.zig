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
    @"or": ?[]const RouterCondition = null,
    not: ?RouterCondition = null,

    /// WebIDL ByteString members: a code unit above 0xFF throws a TypeError
    /// when the dictionary is converted.
    pub const byte_string_members = .{"requestMethod"};
};

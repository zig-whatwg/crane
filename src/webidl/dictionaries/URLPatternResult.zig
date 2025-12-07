//! WebIDL dictionary: URLPatternResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const URLPatternComponentResult = @import("URLPatternComponentResult.zig").URLPatternComponentResult;

pub const URLPatternResult = struct {
    inputs: ?[]const typedefs.URLPatternInput = null,
    protocol: ?URLPatternComponentResult = null,
    username: ?URLPatternComponentResult = null,
    password: ?URLPatternComponentResult = null,
    hostname: ?URLPatternComponentResult = null,
    port: ?URLPatternComponentResult = null,
    pathname: ?URLPatternComponentResult = null,
    search: ?URLPatternComponentResult = null,
    hash: ?URLPatternComponentResult = null,
};

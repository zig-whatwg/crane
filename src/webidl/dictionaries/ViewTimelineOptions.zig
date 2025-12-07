//! WebIDL dictionary: ViewTimelineOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const ViewTimelineOptions = struct {
    subject: ?*runtime.Instance = null,
    axis: ?enums.ScrollAxis = null,
    inset: ?*const anyopaque = null,
};

//! WebIDL dictionary: HandwritingPrediction
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const HandwritingSegment = @import("HandwritingSegment.zig").HandwritingSegment;

pub const HandwritingPrediction = struct {
    text: runtime.DOMString,
    segmentationResult: ?[]const HandwritingSegment = null,
};

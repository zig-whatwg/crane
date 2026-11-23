//! WebIDL dictionary: HandwritingPrediction
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const HandwritingSegment = @import("HandwritingSegment.zig").HandwritingSegment;

pub const HandwritingPrediction = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    text: runtime.DOMString,
    segmentationResult: ?[]const HandwritingSegment = null,
};

//! WebIDL dictionary: HandwritingSegment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const HandwritingDrawingSegment = @import("HandwritingDrawingSegment.zig").HandwritingDrawingSegment;

pub const HandwritingSegment = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    grapheme: runtime.DOMString,
    beginIndex: u32,
    endIndex: u32,
    drawingSegments: []const HandwritingDrawingSegment,
};

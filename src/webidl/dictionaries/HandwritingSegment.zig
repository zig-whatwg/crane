//! WebIDL dictionary: HandwritingSegment
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const HandwritingSegment = struct {
    grapheme: runtime.DOMString,
    beginIndex: u32,
    endIndex: u32,
    drawingSegments: anyopaque,
};

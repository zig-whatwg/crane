//! WebIDL dictionary: HandwritingRecognizerQueryResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const HandwritingHintsQueryResult = @import("HandwritingHintsQueryResult.zig").HandwritingHintsQueryResult;

pub const HandwritingRecognizerQueryResult = struct {
    textAlternatives: ?bool = null,
    textSegmentation: ?bool = null,
    hints: ?HandwritingHintsQueryResult = null,
};

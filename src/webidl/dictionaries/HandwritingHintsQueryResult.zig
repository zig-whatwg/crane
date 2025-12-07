//! WebIDL dictionary: HandwritingHintsQueryResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const HandwritingHintsQueryResult = struct {
    recognitionType: ?[]const enums.HandwritingRecognitionType = null,
    inputType: ?[]const enums.HandwritingInputType = null,
    textContext: ?bool = null,
    alternatives: ?bool = null,
};

//! WebIDL dictionary: HandwritingRecognizerQueryResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const HandwritingHintsQueryResult = @import("HandwritingHintsQueryResult.zig").HandwritingHintsQueryResult;

pub const HandwritingRecognizerQueryResult = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    textAlternatives: ?bool = null,
    textSegmentation: ?bool = null,
    hints: ?HandwritingHintsQueryResult = null,
};

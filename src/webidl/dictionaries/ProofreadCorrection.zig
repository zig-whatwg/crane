//! WebIDL dictionary: ProofreadCorrection
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const ProofreadCorrection = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    startIndex: ?u64 = null,
    endIndex: ?u64 = null,
    correction: ?runtime.DOMString = null,
    types: ?[]const enums.CorrectionType = null,
    explanation: ?runtime.DOMString = null,
};

//! WebIDL dictionary: ProofreadResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ProofreadCorrection = @import("ProofreadCorrection.zig").ProofreadCorrection;

pub const ProofreadResult = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    correctedInput: ?runtime.DOMString = null,
    corrections: ?[]const ProofreadCorrection = null,
};

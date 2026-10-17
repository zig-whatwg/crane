//! WebIDL dictionary: ProofreadResult
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const ProofreadCorrection = @import("ProofreadCorrection.zig").ProofreadCorrection;

pub const ProofreadResult = struct {
    correctedInput: ?runtime.DOMString = null,
    corrections: ?[]const ProofreadCorrection = null,
};

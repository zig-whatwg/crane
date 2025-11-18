//! WebIDL dictionary: MLLstmOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLLstmOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    bias: ?anyopaque = null,
    recurrentBias: ?anyopaque = null,
    peepholeWeight: ?anyopaque = null,
    initialHiddenState: ?anyopaque = null,
    initialCellState: ?anyopaque = null,
    returnSequence: ?bool = null,
    direction: ?anyopaque = null,
    layout: ?anyopaque = null,
    activations: ?anyopaque = null,
};

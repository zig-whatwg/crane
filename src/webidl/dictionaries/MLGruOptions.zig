//! WebIDL dictionary: MLGruOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLGruOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    bias: ?*const anyopaque = null,
    recurrentBias: ?*const anyopaque = null,
    initialHiddenState: ?*const anyopaque = null,
    resetAfter: ?bool = null,
    returnSequence: ?bool = null,
    direction: ?*const anyopaque = null,
    layout: ?*const anyopaque = null,
    activations: ?*const anyopaque = null,
};

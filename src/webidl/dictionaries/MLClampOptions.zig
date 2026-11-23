//! WebIDL dictionary: MLClampOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLClampOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    minValue: ?typedefs.MLNumber = null,
    maxValue: ?typedefs.MLNumber = null,
};

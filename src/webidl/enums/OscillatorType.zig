//! WebIDL enum: OscillatorType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const OscillatorType = enum {
    _sine_,
    _square_,
    _sawtooth_,
    _triangle_,
    _custom_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "sine", "square", "sawtooth", "triangle", "custom" };
};

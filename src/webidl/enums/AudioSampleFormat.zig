//! WebIDL enum: AudioSampleFormat
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const AudioSampleFormat = enum {
    _u8_,
    _s16_,
    _s32_,
    _f32_,
    _u8_planar_,
    _s16_planar_,
    _s32_planar_,
    _f32_planar_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "u8", "s16", "s32", "f32", "u8-planar", "s16-planar", "s32-planar", "f32-planar" };
};

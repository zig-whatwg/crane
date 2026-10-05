//! WebIDL enum: BiquadFilterType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const BiquadFilterType = enum {
    _lowpass_,
    _highpass_,
    _bandpass_,
    _lowshelf_,
    _highshelf_,
    _peaking_,
    _notch_,
    _allpass_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "lowpass", "highpass", "bandpass", "lowshelf", "highshelf", "peaking", "notch", "allpass" };
};

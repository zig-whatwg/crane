//! WebIDL enum: TextTrackKind
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const TextTrackKind = enum {
    _subtitles_,
    _captions_,
    _descriptions_,
    _chapters_,
    _metadata_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "subtitles", "captions", "descriptions", "chapters", "metadata" };
};

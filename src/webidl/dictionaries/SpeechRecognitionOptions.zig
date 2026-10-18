//! WebIDL dictionary: SpeechRecognitionOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const SpeechRecognitionOptions = struct {
    langs: []const runtime.DOMString,
    processLocally: ?bool = null,
    quality: ?enums.SpeechRecognitionQuality = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "processLocally", .{ .boolean = false } },
        .{ "quality", .{ .string = "command" } },
    };
};

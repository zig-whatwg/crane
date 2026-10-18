//! WebIDL dictionary: SpeechRecognitionErrorEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const SpeechRecognitionErrorEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    @"error": enums.SpeechRecognitionErrorCode,
    message: ?runtime.DOMString = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "message", .{ .string = "" } },
    };
};

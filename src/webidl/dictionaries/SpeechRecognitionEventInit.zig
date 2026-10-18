//! WebIDL dictionary: SpeechRecognitionEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const SpeechRecognitionEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    resultIndex: ?u32 = null,
    results: *runtime.Instance,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "resultIndex", .{ .number = 0 } },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "results", "SpeechRecognitionResultList" },
    };
};

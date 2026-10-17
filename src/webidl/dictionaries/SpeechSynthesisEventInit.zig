//! WebIDL dictionary: SpeechSynthesisEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const EventInit = @import("EventInit.zig").EventInit;

pub const SpeechSynthesisEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    utterance: *runtime.Instance,
    charIndex: ?u32 = null,
    charLength: ?u32 = null,
    elapsedTime: ?f32 = null,
    name: ?runtime.DOMString = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"elapsedTime"};

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "utterance", "SpeechSynthesisUtterance" },
    };
};

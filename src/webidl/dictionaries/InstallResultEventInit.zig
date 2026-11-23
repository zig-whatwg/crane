//! WebIDL dictionary: InstallResultEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const EventInit = @import("EventInit.zig").EventInit;

pub const InstallResultEventInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from EventInit
    base: EventInit,

    result: ?enums.InstallResult = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "result", .{ .string = "aborted" } },
    };
};

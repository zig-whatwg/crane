//! WebIDL dictionary: WorkerOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const WorkerOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    name: ?runtime.DOMString = null,
    type: ?enums.WorkerType = null,
    credentials: ?enums.RequestCredentials = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "name", .{ .string = "" } },
        .{ "type", .{ .string = "classic" } },
        .{ "credentials", .{ .string = "same-origin" } },
    };
};

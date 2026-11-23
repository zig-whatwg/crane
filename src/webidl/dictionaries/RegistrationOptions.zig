//! WebIDL dictionary: RegistrationOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const RegistrationOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    scope: ?runtime.USVString = null,
    type: ?enums.WorkerType = null,
    updateViaCache: ?enums.ServiceWorkerUpdateViaCache = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "type", .{ .string = "classic" } },
        .{ "updateViaCache", .{ .string = "imports" } },
    };
};

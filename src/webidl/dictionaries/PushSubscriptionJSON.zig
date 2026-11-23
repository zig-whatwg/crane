//! WebIDL dictionary: PushSubscriptionJSON
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PushSubscriptionJSON = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    endpoint: ?runtime.USVString = null,
    expirationTime: ?typedefs.EpochTimeStamp = null,
    keys: ?[]const struct {
        pub const webidl_record_entry = true;
        key: runtime.DOMString,
        value: runtime.USVString,
    } = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "expirationTime", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"expirationTime"};
};

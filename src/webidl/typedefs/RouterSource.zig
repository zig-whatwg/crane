//! WebIDL typedef: RouterSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");
const enums = @import("enums");

pub const RouterSource = union(enum) {
    router_source_dict: dictionaries.RouterSourceDict,
    router_source_enum: enums.RouterSourceEnum,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "router_source_dict", .kind = .dictionary },
        .{ .field = "router_source_enum", .kind = .enumeration },
    };
};

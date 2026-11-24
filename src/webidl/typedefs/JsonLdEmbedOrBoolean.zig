//! WebIDL typedef: JsonLdEmbedOrBoolean
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const enums = @import("enums");

pub const JsonLdEmbedOrBoolean = union(enum) {
    json_ld_embed: enums.JsonLdEmbed,
    boolean: bool,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "json_ld_embed", .kind = .enumeration },
        .{ .field = "boolean", .kind = .boolean },
    };
};

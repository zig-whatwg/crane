//! WebIDL typedef: BooleanOrImportNodeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const BooleanOrImportNodeOptions = union(enum) {
    boolean: bool,
    import_node_options: dictionaries.ImportNodeOptions,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "boolean", .kind = .boolean },
        .{ .field = "import_node_options", .kind = .dictionary },
    };
};

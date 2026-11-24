//! WebIDL typedef: BooleanOrScrollIntoViewOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const BooleanOrScrollIntoViewOptions = union(enum) {
    boolean: bool,
    scroll_into_view_options: dictionaries.ScrollIntoViewOptions,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "boolean", .kind = .boolean },
        .{ .field = "scroll_into_view_options", .kind = .dictionary },
    };
};

//! WebIDL dictionary: FragmentResultOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const BreakTokenOptions = @import("BreakTokenOptions.zig").BreakTokenOptions;

pub const FragmentResultOptions = struct {
    inlineSize: ?f64 = null,
    blockSize: ?f64 = null,
    autoBlockSize: ?f64 = null,
    childFragments: ?[]const *runtime.Instance = null,
    data: ?runtime.JSValue = null,
    breakToken: ?BreakTokenOptions = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "inlineSize", "blockSize", "autoBlockSize" };

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"data"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "inlineSize", .{ .number = 0 } },
        .{ "blockSize", .{ .number = 0 } },
        .{ "autoBlockSize", .{ .number = 0 } },
        .{ "childFragments", .empty_sequence },
        .{ "data", .null },
        .{ "breakToken", .null },
    };

    /// WebIDL interface types: the interface each interface-typed member
    /// converts to - a TypeError unless the value implements it.
    pub const interface_members = .{
        .{ "childFragments", "LayoutFragment" },
    };
};

//! WebIDL typedef: CompositeOperationOrAutoOrSequenceOfCompositeOperationOrAuto
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const enums = @import("enums");

pub const CompositeOperationOrAutoOrSequenceOfCompositeOperationOrAuto = union(enum) {
    composite_operation_or_auto: enums.CompositeOperationOrAuto,
    composite_operation_or_auto_sequence: []const enums.CompositeOperationOrAuto,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "composite_operation_or_auto", .kind = .enumeration },
        .{ .field = "composite_operation_or_auto_sequence", .kind = .{ .sequence = null } },
    };
};

//! WebIDL dictionary: PaymentMethodChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PaymentRequestUpdateEventInit = @import("PaymentRequestUpdateEventInit.zig").PaymentRequestUpdateEventInit;

pub const PaymentMethodChangeEventInit = struct {
    // Inherited from PaymentRequestUpdateEventInit
    base: PaymentRequestUpdateEventInit,

    methodName: ?runtime.DOMString = null,
    methodDetails: ?runtime.JSValue = null,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"methodDetails"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "methodName", .{ .string = "" } },
        .{ "methodDetails", .null },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"methodDetails"};
};

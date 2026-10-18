//! WebIDL dictionary: PaymentItem
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PaymentCurrencyAmount = @import("PaymentCurrencyAmount.zig").PaymentCurrencyAmount;

pub const PaymentItem = struct {
    label: runtime.DOMString,
    amount: PaymentCurrencyAmount,
    pending: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "pending", .{ .boolean = false } },
    };
};

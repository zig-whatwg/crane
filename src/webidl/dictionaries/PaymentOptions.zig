//! WebIDL dictionary: PaymentOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const PaymentOptions = struct {
    requestPayerName: ?bool = null,
    requestBillingAddress: ?bool = null,
    requestPayerEmail: ?bool = null,
    requestPayerPhone: ?bool = null,
    requestShipping: ?bool = null,
    shippingType: ?enums.PaymentShippingType = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "requestPayerName", .{ .boolean = false } },
        .{ "requestBillingAddress", .{ .boolean = false } },
        .{ "requestPayerEmail", .{ .boolean = false } },
        .{ "requestPayerPhone", .{ .boolean = false } },
        .{ "requestShipping", .{ .boolean = false } },
        .{ "shippingType", .{ .string = "shipping" } },
    };
};

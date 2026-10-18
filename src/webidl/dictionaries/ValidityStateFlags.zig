//! WebIDL dictionary: ValidityStateFlags
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ValidityStateFlags = struct {
    valueMissing: ?bool = null,
    typeMismatch: ?bool = null,
    patternMismatch: ?bool = null,
    tooLong: ?bool = null,
    tooShort: ?bool = null,
    rangeUnderflow: ?bool = null,
    rangeOverflow: ?bool = null,
    stepMismatch: ?bool = null,
    badInput: ?bool = null,
    customError: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "valueMissing", .{ .boolean = false } },
        .{ "typeMismatch", .{ .boolean = false } },
        .{ "patternMismatch", .{ .boolean = false } },
        .{ "tooLong", .{ .boolean = false } },
        .{ "tooShort", .{ .boolean = false } },
        .{ "rangeUnderflow", .{ .boolean = false } },
        .{ "rangeOverflow", .{ .boolean = false } },
        .{ "stepMismatch", .{ .boolean = false } },
        .{ "badInput", .{ .boolean = false } },
        .{ "customError", .{ .boolean = false } },
    };
};

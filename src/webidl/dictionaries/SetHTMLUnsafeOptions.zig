//! WebIDL dictionary: SetHTMLUnsafeOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const SetHTMLUnsafeOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    runScripts: ?bool = null,
    sanitizer: ?typedefs.SanitizerOrSanitizerConfigOrSanitizerPresets = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "runScripts", .{ .boolean = false } },
    };
};

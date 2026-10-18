//! WebIDL dictionary: SanitizerElementNamespace
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");

pub const SanitizerElementNamespace = struct {
    name: runtime.DOMString,
    namespace: webidl.Opt(?runtime.DOMString) = .notPassed(),

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "namespace", .{ .string = "http://www.w3.org/1999/xhtml" } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"namespace"};
};

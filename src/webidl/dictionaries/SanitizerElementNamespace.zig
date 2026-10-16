//! WebIDL dictionary: SanitizerElementNamespace
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("typedefs");

pub const SanitizerElementNamespace = struct {
    name: runtime.DOMString,
    namespace: webidl.Opt(?runtime.DOMString) = .notPassed(),

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"namespace"};
};

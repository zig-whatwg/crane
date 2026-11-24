//! WebIDL typedef: SanitizerPI
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");

pub const SanitizerPI = union(enum) {
    domstring: runtime.DOMString,
    sanitizer_processing_instruction: dictionaries.SanitizerProcessingInstruction,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "domstring", .kind = .string },
        .{ .field = "sanitizer_processing_instruction", .kind = .dictionary },
    };
};

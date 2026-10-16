//! WebIDL dictionary: SanitizerElementNamespace
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("typedefs");

pub const SanitizerElementNamespace = struct {
    name: runtime.DOMString,
    namespace: webidl.Opt(?runtime.DOMString) = .notPassed(),
};

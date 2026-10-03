//! W3C Trusted Types: the parts that need neither an engine nor a global.
//!
//! The API objects are impls (TrustedTypePolicyFactory, TrustedTypePolicy,
//! TrustedHTML, TrustedScript, TrustedScriptURL); the enforcement algorithms
//! that read a global's CSP list and run its default policy are in
//! src/dom/trusted_types.zig; the two CSP directives are in
//! src/csp/directives. What is here is plain data: the three kinds of
//! Trusted Type, and the tables of 2.3.1 (getPropertyType) and 3.8 ("get
//! Trusted Type data for attribute").
//!
//! Spec: https://w3c.github.io/trusted-types/dist/spec/

const std = @import("std");

/// A Trusted Type (2.2): the interface a value is an instance of, or the one a
/// sink expects.
pub const Kind = enum {
    html,
    script,
    script_url,

    /// The interface's name: "TrustedHTML", "TrustedScript",
    /// "TrustedScriptURL" - the trustedTypeName the algorithms pass around,
    /// and what getAttributeType/getPropertyType return.
    pub fn interfaceName(self: Kind) []const u8 {
        return switch (self) {
            .html => "TrustedHTML",
            .script => "TrustedScript",
            .script_url => "TrustedScriptURL",
        };
    }

    /// 3.3 step 1: the policy option ("function name") that makes it.
    pub fn functionName(self: Kind) []const u8 {
        return switch (self) {
            .html => "createHTML",
            .script => "createScript",
            .script_url => "createScriptURL",
        };
    }
};

pub const attributes = @import("attributes.zig");

test {
    std.testing.refAllDecls(@This());
}

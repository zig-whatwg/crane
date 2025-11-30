//! W3C Trusted Types Module
//!
//! Spec: https://w3c.github.io/trusted-types/dist/spec/
//!
//! This module provides Zig implementations of the W3C Trusted Types specification,
//! which provides a mechanism to lock down DOM XSS injection sinks.
//!
//! ## Core Types
//!
//! - `TrustedHTML` - Represents trusted HTML content safe for innerHTML, etc.
//! - `TrustedScript` - Represents trusted script content safe for eval, etc.
//! - `TrustedScriptURL` - Represents trusted URLs safe for script src, etc.
//! - `TrustedType` - Union of all trusted types
//!
//! ## Policies (TODO)
//!
//! - `TrustedTypePolicy` - Creates trusted type values via callback functions
//! - `TrustedTypePolicyFactory` - Factory for creating and managing policies
//!
//! ## Usage
//!
//! ```zig
//! const trusted_types = @import("trusted_types");
//!
//! // Create a trusted HTML value (normally done through a policy)
//! var html = try trusted_types.TrustedHTML.create(allocator, "<div>Safe content</div>");
//! defer html.deinit();
//!
//! // Get the string value
//! const value = html.toString();
//! ```
//!
//! ## Integration with CSP
//!
//! Trusted Types work with Content Security Policy (CSP) via the directives:
//! - `trusted-types` - Controls which policies can be created
//! - `require-trusted-types-for` - Requires trusted types for certain sinks
//!
//! See the CSP module for CSP directive handling.

const std = @import("std");

// Re-export core types
pub const types = @import("types.zig");

pub const TrustedHTML = types.TrustedHTML;
pub const TrustedScript = types.TrustedScript;
pub const TrustedScriptURL = types.TrustedScriptURL;
pub const TrustedType = types.TrustedType;

// Policy module - creates Trusted Types with callbacks
pub const policy = @import("policy.zig");

pub const TrustedTypePolicy = policy.TrustedTypePolicy;
pub const TrustedTypePolicyOptions = policy.TrustedTypePolicyOptions;
pub const PolicyError = policy.PolicyError;

// Callback types
pub const CreateHTMLCallback = policy.CreateHTMLCallback;
pub const CreateScriptCallback = policy.CreateScriptCallback;
pub const CreateScriptURLCallback = policy.CreateScriptURLCallback;

// TODO: Add these in subsequent tasks
// pub const factory = @import("factory.zig");
// pub const TrustedTypePolicyFactory = factory.TrustedTypePolicyFactory;
//
// pub const sink_types = @import("sink_types.zig");
// pub const getAttributeType = sink_types.getAttributeType;
// pub const getPropertyType = sink_types.getPropertyType;

test {
    std.testing.refAllDecls(@This());
}

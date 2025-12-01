//! Content Security Policy (CSP) Module
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/
//!
//! This module provides a complete implementation of CSP including:
//! - Policy and directive data structures
//! - Header parsing algorithms
//! - Source expression matching
//! - Directive fallback chains
//! - Trusted Types integration
//!
//! ## Overview
//!
//! CSP is a security mechanism that allows web developers to control which
//! resources can be loaded and executed by a document. It's implemented via
//! HTTP headers (Content-Security-Policy, Content-Security-Policy-Report-Only)
//! or <meta> tags.
//!
//! ## Key Components
//!
//! - **Policy**: A single CSP policy with directives and disposition
//! - **Directive**: Name/value pair controlling specific behavior (e.g., script-src)
//! - **SourceList**: List of source expressions in a directive value
//! - **CSPList**: Multiple policies applied to a document/worker
//!
//! ## Usage
//!
//! ```zig
//! const csp = @import("csp");
//!
//! // Parse a CSP header
//! var policy = try csp.parsing.parseSerializedCSP(
//!     allocator,
//!     "default-src 'self'; script-src 'self' https://cdn.example.com",
//!     .header,
//!     .enforce,
//! );
//! defer policy.deinit();
//!
//! // Check if a URL is allowed
//! const script_src = policy.getDirective("script-src").?;
//! const allowed = csp.matching.doesUrlMatchSourceList(
//!     "https", "cdn.example.com", 443, "/script.js",
//!     &script_src.value,
//!     null, // self_origin
//!     0,    // redirect_count
//! );
//! ```
//!
//! ## Trusted Types Integration
//!
//! CSP includes directives for controlling Trusted Types:
//! - `trusted-types`: Controls which policy names can be created
//! - `require-trusted-types-for`: Enables enforcement for DOM XSS sinks
//!
//! ```zig
//! // Check if Trusted Types are required
//! if (csp.directives.isScriptSinkEnforcementRequired(&csp_list)) {
//!     // DOM XSS sinks require Trusted Types
//! }
//!
//! // Check if a policy name is allowed
//! const result = csp.directives.shouldTrustedTypePolicyCreationBeBlocked(
//!     &csp_list, "my-policy", .enforce,
//! );
//! ```

const std = @import("std");

// Core types
pub const types = @import("types.zig");

pub const Policy = types.Policy;
pub const PolicyDisposition = types.PolicyDisposition;
pub const PolicySource = types.PolicySource;
pub const Directive = types.Directive;
pub const DirectiveSet = types.DirectiveSet;
pub const SourceExpression = types.SourceExpression;
pub const SourceExpressionType = types.SourceExpressionType;
pub const SourceList = types.SourceList;
pub const CSPList = types.CSPList;
pub const Origin = types.Origin;
pub const Violation = types.Violation;
pub const ViolationResource = types.ViolationResource;

// Parsing
pub const parsing = @import("parsing.zig");

pub const parseSerializedCSP = parsing.parseSerializedCSP;
pub const parseSourceExpression = parsing.parseSourceExpression;

// Matching
pub const matching = @import("matching.zig");

pub const doesUrlMatchSourceList = matching.doesUrlMatchSourceList;
pub const doesUrlMatchExpression = matching.doesUrlMatchExpression;
pub const doesNonceMatch = matching.doesNonceMatch;
pub const doesHashMatch = matching.doesHashMatch;
pub const allowsUnsafeInline = matching.allowsUnsafeInline;
pub const allowsUnsafeEval = matching.allowsUnsafeEval;
pub const hasStrictDynamic = matching.hasStrictDynamic;
pub const getDefaultPort = matching.getDefaultPort;

// Fallback
pub const fallback = @import("fallback.zig");

pub const getEffectiveDirective = fallback.getEffectiveDirective;
pub const getFallbackChain = fallback.getFallbackChain;
pub const getMatchingDirectiveName = fallback.getMatchingDirectiveName;
pub const getEffectiveScriptSrc = fallback.getEffectiveScriptSrc;
pub const getEffectiveScriptSrcElem = fallback.getEffectiveScriptSrcElem;
pub const getEffectiveStyleSrc = fallback.getEffectiveStyleSrc;
pub const getEffectiveConnectSrc = fallback.getEffectiveConnectSrc;

// Violations
pub const violations = @import("violations.zig");

pub const createViolation = violations.createViolation;
pub const createTrustedTypesPolicyViolation = violations.createTrustedTypesPolicyViolation;
pub const createTrustedTypesSinkViolation = violations.createTrustedTypesSinkViolation;
pub const createViolationReport = violations.createViolationReport;
pub const reportViolation = violations.reportViolation;
pub const ViolationOptions = violations.ViolationOptions;

// Trusted Types directives
pub const directives = @import("directives/root.zig");

// Run all tests
test {
    std.testing.refAllDecls(@This());
}

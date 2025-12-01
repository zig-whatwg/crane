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

// Policy factory module - manages policies and provides type checking
pub const policy_factory = @import("policy_factory.zig");

pub const TrustedTypePolicyFactory = policy_factory.TrustedTypePolicyFactory;
pub const FactoryError = policy_factory.FactoryError;

// Enforcement module - core enforcement algorithms per spec §3.4-3.5, §4.3.4
pub const enforcement = @import("enforcement.zig");

// DOM integration module - integrates Trusted Types with DOM injection sinks
pub const dom_integration = @import("dom_integration.zig");

// Eval integration module - integrates Trusted Types with eval/Function
pub const eval_integration = @import("eval_integration.zig");

pub const EnforcementError = enforcement.EnforcementError;
pub const ExpectedType = enforcement.ExpectedType;
pub const InputValue = enforcement.InputValue;
pub const SinkMismatchResult = enforcement.SinkMismatchResult;
pub const CspDisposition = enforcement.CspDisposition;
pub const CspPolicyInfo = enforcement.CspPolicyInfo;
pub const GlobalObject = enforcement.GlobalObject;

// Core enforcement functions
pub const getTrustedTypeCompliantString = enforcement.getTrustedTypeCompliantString;
pub const processValueWithDefaultPolicy = enforcement.processValueWithDefaultPolicy;
pub const shouldSinkTypeMismatchViolationBeBlockedByCSP = enforcement.shouldSinkTypeMismatchViolationBeBlockedByCSP;

// Convenience helpers
pub const isValidTrustedHTML = enforcement.isValidTrustedHTML;
pub const isValidTrustedScript = enforcement.isValidTrustedScript;
pub const isValidTrustedScriptURL = enforcement.isValidTrustedScriptURL;
pub const getRequiredTypeForProperty = enforcement.getRequiredTypeForProperty;
pub const getRequiredTypeForAttribute = enforcement.getRequiredTypeForAttribute;
pub const createCspPolicyInfo = enforcement.createCspPolicyInfo;

// Eval integration exports
pub const EvalInput = eval_integration.EvalInput;
pub const EvalCspPolicyInfo = eval_integration.EvalCspPolicyInfo;
pub const CompilationCheckResult = eval_integration.CompilationCheckResult;
pub const ensureCSPDoesNotBlockStringCompilation = eval_integration.ensureCSPDoesNotBlockStringCompilation;
pub const validateEval = eval_integration.validateEval;
pub const validateFunctionConstructor = eval_integration.validateFunctionConstructor;
pub const validateTimerStringCallback = eval_integration.validateTimerStringCallback;

// Eval sink name constants
pub const SINK_EVAL = eval_integration.SINK_EVAL;
pub const SINK_FUNCTION = eval_integration.SINK_FUNCTION;
pub const SINK_SET_TIMEOUT = eval_integration.SINK_SET_TIMEOUT;
pub const SINK_SET_INTERVAL = eval_integration.SINK_SET_INTERVAL;

// TODO: Add these in subsequent tasks
// pub const sink_types = @import("sink_types.zig");
// Full sink type mapping table per spec

test {
    std.testing.refAllDecls(@This());
}

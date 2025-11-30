//! CSP Directives Module
//!
//! This module provides directive-specific functionality for CSP.
//! Each directive may have special parsing or matching rules.

pub const trusted_types = @import("trusted_types.zig");
pub const require_trusted_types = @import("require_trusted_types.zig");

// Re-export commonly used functions
pub const shouldTrustedTypePolicyCreationBeBlocked = trusted_types.shouldTrustedTypePolicyCreationBeBlocked;
pub const doesTrustedTypesDirectiveAllowName = trusted_types.doesTrustedTypesDirectiveAllowName;
pub const areDuplicatePolicyNamesAllowed = trusted_types.areDuplicatePolicyNamesAllowed;

pub const doesSinkTypeRequireTrustedTypes = require_trusted_types.doesSinkTypeRequireTrustedTypes;
pub const isScriptSinkEnforcementRequired = require_trusted_types.isScriptSinkEnforcementRequired;
pub const isTrustedTypesEnforcementActive = require_trusted_types.isTrustedTypesEnforcementActive;

// Constants
pub const TT_KEYWORD_NONE = trusted_types.TT_KEYWORD_NONE;
pub const TT_KEYWORD_ALLOW_DUPLICATES = trusted_types.TT_KEYWORD_ALLOW_DUPLICATES;
pub const TT_WILDCARD = trusted_types.TT_WILDCARD;
pub const SINK_GROUP_SCRIPT = require_trusted_types.SINK_GROUP_SCRIPT;

test {
    @import("std").testing.refAllDecls(@This());
}

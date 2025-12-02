//! CSP Directives Module
//!
//! This module provides directive-specific functionality for CSP.
//! Each directive may have special parsing or matching rules.
//!
//! ## Directive Categories
//!
//! ### Trusted Types
//! - `trusted-types`: Control policy creation
//! - `require-trusted-types-for`: Enable enforcement
//!
//! ### Navigation Directives
//! - `frame-ancestors`: Control embedding
//! - `form-action`: Control form submissions
//! - `base-uri`: Control <base> element
//!
//! ### Security Directives
//! - `sandbox`: Apply sandbox restrictions
//! - `upgrade-insecure-requests`: Upgrade HTTP to HTTPS
//!
//! ### Reporting Directives
//! - `report-to`: Reporting API integration
//! - `report-uri`: Legacy reporting (deprecated)

// Trusted Types
pub const trusted_types = @import("trusted_types.zig");
pub const require_trusted_types = @import("require_trusted_types.zig");

// Navigation Directives
pub const frame_ancestors = @import("frame_ancestors.zig");
pub const form_action = @import("form_action.zig");
pub const base_uri = @import("base_uri.zig");

// Security Directives
pub const sandbox = @import("sandbox.zig");
pub const upgrade_insecure = @import("upgrade_insecure.zig");

// Reporting Directives
pub const report_to = @import("report_to.zig");

// Re-export Trusted Types functions
pub const shouldTrustedTypePolicyCreationBeBlocked = trusted_types.shouldTrustedTypePolicyCreationBeBlocked;
pub const doesTrustedTypesDirectiveAllowName = trusted_types.doesTrustedTypesDirectiveAllowName;
pub const areDuplicatePolicyNamesAllowed = trusted_types.areDuplicatePolicyNamesAllowed;

pub const doesSinkTypeRequireTrustedTypes = require_trusted_types.doesSinkTypeRequireTrustedTypes;
pub const isScriptSinkEnforcementRequired = require_trusted_types.isScriptSinkEnforcementRequired;
pub const isTrustedTypesEnforcementActive = require_trusted_types.isTrustedTypesEnforcementActive;

// Re-export frame-ancestors functions
pub const isAncestorAllowed = frame_ancestors.isAncestorAllowed;
pub const areAllAncestorsAllowed = frame_ancestors.areAllAncestorsAllowed;
pub const blocksAllFraming = frame_ancestors.blocksAllFraming;

// Re-export form-action functions
pub const isFormActionAllowed = form_action.isFormActionAllowed;
pub const blocksAllFormActions = form_action.blocksAllFormActions;
pub const isFormActionAllowedByList = form_action.isFormActionAllowedByList;

// Re-export base-uri functions
pub const isBaseUriAllowed = base_uri.isBaseUriAllowed;
pub const blocksAllBaseUris = base_uri.blocksAllBaseUris;
pub const isBaseUriAllowedByList = base_uri.isBaseUriAllowedByList;

// Re-export sandbox functions
pub const SandboxFlags = sandbox.SandboxFlags;
pub const parseSandboxDirective = sandbox.parseSandboxDirective;
pub const getSandboxFlags = sandbox.getSandboxFlags;
pub const getCombinedSandboxFlags = sandbox.getCombinedSandboxFlags;
pub const areScriptsAllowed = sandbox.areScriptsAllowed;
pub const areFormsAllowed = sandbox.areFormsAllowed;
pub const arePopupsAllowed = sandbox.arePopupsAllowed;
pub const isTopNavigationAllowed = sandbox.isTopNavigationAllowed;

// Re-export upgrade-insecure-requests functions
pub const shouldUpgradeInsecureRequests = upgrade_insecure.shouldUpgradeInsecureRequests;
pub const hasUpgradeInsecureRequests = upgrade_insecure.hasUpgradeInsecureRequests;
pub const canUpgradeScheme = upgrade_insecure.canUpgradeScheme;
pub const getUpgradedScheme = upgrade_insecure.getUpgradedScheme;
pub const upgradeUrlComponents = upgrade_insecure.upgradeUrlComponents;
pub const UpgradeResult = upgrade_insecure.UpgradeResult;

// Re-export report-to functions
pub const getReportingGroup = report_to.getReportingGroup;
pub const getReportUris = report_to.getReportUris;
pub const hasReporting = report_to.hasReporting;
pub const getReportingMechanism = report_to.getReportingMechanism;
pub const ReportingMechanism = report_to.ReportingMechanism;
pub const ReportConfig = report_to.ReportConfig;
pub const getReportConfig = report_to.getReportConfig;

// Constants
pub const TT_KEYWORD_NONE = trusted_types.TT_KEYWORD_NONE;
pub const TT_KEYWORD_ALLOW_DUPLICATES = trusted_types.TT_KEYWORD_ALLOW_DUPLICATES;
pub const TT_WILDCARD = trusted_types.TT_WILDCARD;
pub const SINK_GROUP_SCRIPT = require_trusted_types.SINK_GROUP_SCRIPT;

test {
    @import("std").testing.refAllDecls(@This());
}

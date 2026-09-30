//! Navigation Module - HTML Standard §7
//!
//! The engine-free parts of navigating and of session history, which the
//! navigable containers (impls/HTMLIFrameElement), History, Location and the
//! navigation API build on.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html
//!
//! ## Components
//!
//! - **joint_history**: a traversable's session history - its entries,
//!   steps, and what the navigation API reads of them
//! - **navigate_steps**: the pure steps of "navigate" (history handling,
//!   fragment navigations, about:blank and javascript: URLs)
//! - **declarative_refresh**: parsing a meta refresh or Refresh header value
//! - **fetch_integration**: the navigation fetch
//! - **document_type**: which document a response makes
//! - **termination_nesting**: the event loop's termination nesting level
//! - **security_policies**: COOP, COEP, CORP, sandboxing, framing

pub const fetch_integration = @import("fetch_integration.zig");
pub const navigate_steps = @import("navigate_steps.zig");
pub const declarative_refresh = @import("declarative_refresh.zig");
pub const termination_nesting = @import("termination_nesting.zig");
pub const joint_history = @import("joint_history.zig");
pub const document_type = @import("document_type.zig");
pub const security_policies = @import("security_policies.zig");

pub const fetchNavigationResource = fetch_integration.fetchNavigationResource;
pub const NavigationFetchResult = fetch_integration.NavigationFetchResult;
pub const NavigationFetchOptions = fetch_integration.NavigationFetchOptions;
pub const NavigationFetchError = fetch_integration.NavigationFetchError;
pub const isHtmlResponse = fetch_integration.isHtmlResponse;
pub const isXmlResponse = fetch_integration.isXmlResponse;
pub const shouldNavigationProceed = fetch_integration.shouldNavigationProceed;
pub const isCrossOrigin = fetch_integration.isCrossOrigin;

pub const CoopValue = security_policies.CoopValue;
pub const CoepValue = security_policies.CoepValue;
pub const CorpValue = security_policies.CorpValue;
pub const CrossOriginOpenerPolicy = security_policies.CrossOriginOpenerPolicy;
pub const CrossOriginEmbedderPolicy = security_policies.CrossOriginEmbedderPolicy;
pub const SecurityPolicies = security_policies.SecurityPolicies;
pub const SecurityPolicyHeaderMap = security_policies.HeaderMap;
pub const checkCoopEnforcement = security_policies.checkCoopEnforcement;
pub const checkCoepEnforcement = security_policies.checkCoepEnforcement;
pub const isCrossOriginIsolated = security_policies.isCrossOriginIsolated;
pub const isNavigationAllowedBySandbox = security_policies.isNavigationAllowedBySandbox;
pub const checkNavigationSecurity = security_policies.checkNavigationSecurity;
pub const XFrameOptions = security_policies.XFrameOptions;
pub const isFramingAllowed = security_policies.isFramingAllowed;

test {
    @import("std").testing.refAllDecls(@This());
}

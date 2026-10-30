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
//! - **object_resource_type**: what an object's or embed's resource is
//! - **termination_nesting**: the event loop's termination nesting level
//! - **security_policies**: X-Frame-Options framing
//! - **opener_policy**: COOP matching and browsing context group switches
//! - **sandbox_navigation**: "allowed by sandboxing to navigate"

pub const fetch_integration = @import("fetch_integration.zig");
pub const navigate_steps = @import("navigate_steps.zig");
pub const declarative_refresh = @import("declarative_refresh.zig");
pub const termination_nesting = @import("termination_nesting.zig");
pub const joint_history = @import("joint_history.zig");
pub const traversal_queue = @import("traversal_queue.zig");
/// HTML "apply the history step", run as items of that queue.
pub const apply_history_step = @import("apply_history_step.zig");
pub const document_type = @import("document_type.zig");
pub const object_resource_type = @import("object_resource_type.zig");
pub const security_policies = @import("security_policies.zig");
pub const opener_policy = @import("opener_policy.zig");
/// HTML "allowed by sandboxing to navigate".
pub const sandbox_navigation = @import("sandbox_navigation.zig");
/// HTML "not restored reasons" and a Document's bfcache blocking details.
pub const not_restored_reasons = @import("not_restored_reasons.zig");

pub const fetchNavigationResource = fetch_integration.fetchNavigationResource;
pub const NavigationFetchResult = fetch_integration.NavigationFetchResult;
pub const NavigationFetchOptions = fetch_integration.NavigationFetchOptions;
pub const NavigationFetchError = fetch_integration.NavigationFetchError;
pub const isHtmlResponse = fetch_integration.isHtmlResponse;
pub const isXmlResponse = fetch_integration.isXmlResponse;
pub const shouldNavigationProceed = fetch_integration.shouldNavigationProceed;
pub const isCrossOrigin = fetch_integration.isCrossOrigin;

pub const XFrameOptions = security_policies.XFrameOptions;
pub const isFramingAllowed = security_policies.isFramingAllowed;

test {
    @import("std").testing.refAllDecls(@This());
}

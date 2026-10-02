//! HTML "create a new child navigable" for a browsing context that exists
//! before its window does. The WindowProxy's indexed access (`frames[i]`,
//! HTML 7.2.3.1) can find a child browsing context whose container has not
//! made its navigable's realm yet; the realm, its Window and its initial
//! about:blank document are the container's to make (engine.createWindowRealm
//! with the parent's realm), so HTMLIFrameElement installs this hook and the
//! engine adapter's indexed getter asks it.
//!
//! lint-impls: hook for HTMLIFrameElement
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// What HTMLIFrameElement supplies.
pub const Implementation = struct {
    /// The Window of `browsing_context`'s navigable (an html_core
    /// BrowsingContext, opaque here), made by its container now if it has
    /// none; null when it cannot be made.
    window: *const fn (browsing_context: *anyopaque) ?*runtime.Instance,
};

var implementation: ?Implementation = null;

/// Called by HTMLIFrameElement's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// The Window of `browsing_context`'s navigable, made by its container if
/// need be; null without one, or without an installed implementation.
pub fn window(browsing_context: *anyopaque) ?*runtime.Instance {
    const impl = implementation orelse return null;
    return impl.window(browsing_context);
}

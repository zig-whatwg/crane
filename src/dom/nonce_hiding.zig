//! HTML 2.5.6's nonce hiding, for the one path that gives a connected
//! element a nonce without connecting it: HTML's parser adding a repeated
//! html or body tag's attributes to the element it already made ("in body",
//! a start tag whose tag name is "html" or "body": "add the attribute and its
//! corresponding value to that element"). Installed by the
//! HTMLOrSVGOrMathMLElement mixin, which owns [[CryptographicNonce]] and the
//! hiding steps.
//!
//! lint-impls: hook for HTMLOrSVGOrMathMLElement
const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;

pub const Steps = struct {
    /// The hiding steps (HTML 2.5.6 "becomes browsing-context connected"
    /// steps 1-2.3) for `element`, connected, whose nonce attribute was just
    /// added.
    hide: *const fn (element: *runtime.Instance) void,
    /// Whether `element`'s [[CryptographicNonce]] is nonempty.
    has_nonce: *const fn (element: *runtime.Instance) bool,
};

// process-wide: immutable nonce steps installed at process start, identical for every Browser and thread
var steps: Hook(?Steps) = .init(null);

/// Called by the HTMLOrSVGOrMathMLElement mixin's installHooks.
pub fn install(installed: Steps) void {
    steps.install(installed);
}

/// Hide the nonce attribute the parser just added to connected `element`.
pub fn hide(element: *runtime.Instance) void {
    if (steps.get()) |s| s.hide(element);
}

/// Whether `element` already has a nonempty [[CryptographicNonce]].
pub fn hasNonce(element: *runtime.Instance) bool {
    const s = steps.get() orelse return false;
    return s.has_nonce(element);
}

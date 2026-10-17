//! A URLPattern object's associated URL pattern, for algorithms of other
//! specifications that take a URLPatternCompatible: URLPattern's "build a URL
//! pattern from a Web IDL value" step 1 - "If input is a URLPattern, return
//! input's associated URL pattern" - which Service Workers' Parse URL Pattern
//! runs for a router condition's urlPattern. The pattern is URLPattern's
//! state, so URLPattern installs the step once, at process start (its
//! installHooks), and callers ask here.
//!
//! The pattern is opaque here (dom does not import urlpattern): it is a
//! `*const urlpattern.URLPattern`, BORROWED for as long as the object lives.
//!
//! Spec: https://urlpattern.spec.whatwg.org/#build-a-url-pattern-from-a-web-idl-value
//!
//! lint-impls: hook for URLPattern
const runtime = @import("runtime");
const process_start = @import("process_start.zig");

/// `instance`'s associated URL pattern, or null when it is no URLPattern.
pub const PatternOf = *const fn (instance: *runtime.Instance) ?*const anyopaque;

// process-wide: a function pointer URLPattern's installHooks writes once at process start, the same for every Browser
var implementation: ?PatternOf = null;

/// Install the owner's step before any Browser exists.
pub fn install(step: PatternOf) void {
    process_start.assertInstalling();
    implementation = step;
}

/// `instance`'s associated URL pattern (a `*const urlpattern.URLPattern`),
/// or null when it is not a URLPattern object.
pub fn patternOf(instance: *runtime.Instance) ?*const anyopaque {
    const step = implementation orelse return null;
    return step(instance);
}

//! A node going away, told to the intersection observers that observe it.
//! What an observer observes is IntersectionObserver's state, and a node's
//! end is Node's to know: so IntersectionObserver installs this hook and Node
//! calls it as a node is torn down, and an observer whose last target went
//! stops holding itself alive (its pending activity: "an
//! IntersectionObserver will remain alive until ... the observer is not
//! observing any targets").
//!
//! Spec: https://w3c.github.io/IntersectionObserver/#lifetime
//!
//! lint-impls: hook for IntersectionObserver
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

pub const Implementation = struct {
    target_destroyed: *const fn (node: *runtime.Instance) void,
};

var implementation: ?Implementation = null;

/// Called by IntersectionObserver's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// `node` is being torn down. Nothing happens before any observer exists.
pub fn targetDestroyed(node: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.target_destroyed(node);
}

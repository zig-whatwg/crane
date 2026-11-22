//! Resize Observer's share of HTML "update the rendering" (step 16.2.5 to
//! 16.3): gather the active resize observations at depth, broadcast them
//! while there are any, then report the loop error for what was skipped.
//! What an observer observes is ResizeObserver's state, and the step is
//! update_the_rendering's to run: so ResizeObserver installs this hook at
//! process start and step 16 calls it for each document.
//!
//! Spec: https://drafts.csswg.org/resize-observer-1/#algorithms
//!       https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering
//!
//! lint-impls: hook for ResizeObserver
const Hook = @import("hook.zig").Hook;

const runtime = @import("runtime");

/// A box size: Resize Observer "calculate box size"'s inline and block
/// lengths - what an observer calculates and its entries report (shared by
/// ResizeObserver and ResizeObserverEntry, which reach each other only
/// through their interfaces).
pub const Size = struct {
    inline_size: f64 = 0,
    block_size: f64 = 0,
};

pub const Implementation = struct {
    /// HTML "update the rendering" 16.2.5-16.3 for `document`: may run
    /// script (the observers' callbacks).
    run: *const fn (document: *runtime.Instance) void,
};

var implementation: Hook(?Implementation) = .init(null);

/// Called by ResizeObserver's installHooks, once, at process start.
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// Step 16.2.5-16.3 for `document`. Nothing happens before any observer
/// exists.
pub fn run(document: *runtime.Instance) void {
    const impl = implementation.get() orelse return;
    impl.run(document);
}

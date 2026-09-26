//! The event loop's "termination nesting level" (HTML §7.5.9 "unload" steps
//! 7 and 14, and the steps to fire beforeunload, steps 3 and 5): raised while
//! beforeunload, pagehide, visibilitychange or unload handlers run. The window
//! open steps refuse to open anything while it is nonzero (step 1).
//!
//! Per thread: an event loop is. Document raises it around the handlers
//! unloading runs; Window reads it.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#termination-nesting-level

threadlocal var level: u32 = 0;

/// "Increase the event loop's termination nesting level by 1."
pub fn enter() void {
    level += 1;
}

/// "Decrease the event loop's termination nesting level by 1."
pub fn leave() void {
    if (level > 0) level -= 1;
}

/// Whether the level is nonzero: unload-time handlers are running.
pub fn active() bool {
    return level > 0;
}

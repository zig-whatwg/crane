//! HTML's steps that enable a ServiceWorkerContainer's client message queue
//! (Service Workers 3.4) from outside the container: "the end" step 6.4,
//! after DOMContentLoaded fires at a document. (A worker's queue - "run a
//! worker" step 14 - is enabled before its loop runs any task, which the
//! container's owner knows by itself.)
//!
//! The queue is the service worker module's state for the realm, and the
//! document lifecycle is Document's, so the container's owner installs its
//! step here and Document runs it - the shape of `unloading_cleanup.zig`.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-end
//! Spec: https://w3c.github.io/ServiceWorker/#dfn-client-message-queue
//!
//! lint-impls: hook for ServiceWorkerContainer

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");

/// Enable the client message queue of the container whose service worker
/// client is `realm`'s settings object, if there is one.
pub const Step = *const fn (realm: runtime.Context) void;

// process-wide: one function pointer the ServiceWorkerContainer impl installs once at process start (crane.Process), the same for every Browser and thread
var enable_step: ?Step = null;

/// Called by ServiceWorkerContainer's installHooks, once, at process start.
pub fn install(step: Step) void {
    process_start.assertInstalling();
    enable_step = step;
}

/// "The end" step 6.4, for the document whose realm is `realm`: DOMContentLoaded
/// has been fired at it.
pub fn domContentLoaded(realm: runtime.Context) void {
    const step = enable_step orelse return;
    step(realm);
}

test "with nothing installed, DOMContentLoaded enables nothing" {
    const saved = enable_step;
    defer enable_step = saved;
    enable_step = null;
    var realm: runtime.ContextData = undefined;
    domContentLoaded(&realm);
}

//! HTML's "unloading document cleanup steps" that other specifications
//! define, run for an environment that ends.
//!
//! HTML runs them in "unload a document" (step 18) and "destroy a document"
//! (step 6) for the document's relevant settings object, "in an unspecified
//! order"; the File API, Service Workers, Web Locks, WebRTC and others add
//! steps. A worker's global scope ending has no such hook in the spec yet -
//! the File API notes "This needs a similar hook when a worker is unloaded" -
//! and Blink runs both from one place (ExecutionContext's ContextDestroyed,
//! which PublicURLManager observes), so the steps here run for a worker's
//! realm when it ends too.
//!
//! The steps are their owners'. Each owner installs its step here; the code
//! that ends a document or a worker - the browser layer, the worker host -
//! runs every installed step for the ending realm and never imports an owner.
//! An environment is its realm (`runtime.Context`): a step compares it and
//! must not assume the realm can still run script.
//!
//! lint-impls: hook for URL, EventTarget, CustomElementRegistry

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");

/// One specification's unloading document cleanup step, for `environment`.
pub const Step = *const fn (environment: runtime.Context) void;

const max_steps = 16;
var steps: [max_steps]Step = undefined;
var count: usize = 0;

/// Install `step`. Idempotent: the same function installs once.
pub fn install(step: Step) void {
    process_start.assertInstalling();
    for (steps[0..count]) |existing| {
        if (existing == step) return;
    }
    // A step dropped here is cleanup that never runs; there are far fewer
    // owners than slots.
    std.debug.assert(count < max_steps);
    if (count == max_steps) return;
    steps[count] = step;
    count += 1;
}

/// Run every installed step for `environment`, in installation order: its
/// document is being unloaded or destroyed, or its worker has ended. Running
/// them again for the same environment finds nothing left to do.
pub fn run(environment: runtime.Context) void {
    for (steps[0..count]) |step| step(environment);
}

var test_runs: usize = 0;
var test_last: ?runtime.Context = null;
fn testStep(environment: runtime.Context) void {
    test_runs += 1;
    test_last = environment;
}

test "an installed step runs once per run, for the environment it is given, however often it was installed" {
    const saved = count;
    defer count = saved;
    count = 0;
    test_runs = 0;

    var realm: runtime.ContextData = undefined;
    run(&realm);
    try std.testing.expectEqual(@as(usize, 0), test_runs);

    install(&testStep);
    install(&testStep);
    run(&realm);
    try std.testing.expectEqual(@as(usize, 1), test_runs);
    try std.testing.expectEqual(@as(?runtime.Context, &realm), test_last);
}

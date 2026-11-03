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
const hook = @import("hook.zig");
const runtime = @import("runtime");

/// One specification's unloading document cleanup step, for `environment`.
pub const Step = *const fn (environment: runtime.Context) void;

const max_steps = 24;
/// Process-wide, written once at start-up (hook.zig).
var steps: hook.Hook(hook.List(Step, max_steps)) = .init(.empty);

/// Install `step`. Idempotent: the same function installs once.
pub fn install(step: Step) void {
    const list = steps.installing();
    if (list.contains(step)) return;
    // A step dropped here would be cleanup that never runs: past the
    // capacity the append panics (there are far fewer owners than slots).
    list.append(step);
}

/// Run every installed step for `environment`, in installation order: its
/// document is being unloaded or destroyed, or its worker has ended. Running
/// them again for the same environment finds nothing left to do.
pub fn run(environment: runtime.Context) void {
    for (steps.read().slice()) |step| step(environment);
}

test "an installed step runs once per run, for the environment it is given, however often it was installed" {
    // The test's step: what it saw lives in the test, not in the product.
    const Test = struct {
        var runs: usize = 0;
        var last: ?runtime.Context = null;
        fn step(environment: runtime.Context) void {
            runs += 1;
            last = environment;
        }
    };
    // The test's own empty table, given back whole at its end: this test's
    // step must not stay in the process's own table.
    const override = steps.overrideForTest(.empty);
    defer override.restore();

    var realm: runtime.ContextData = undefined;
    run(&realm);
    try std.testing.expectEqual(@as(usize, 0), Test.runs);

    install(&Test.step);
    install(&Test.step);
    run(&realm);
    try std.testing.expectEqual(@as(usize, 1), Test.runs);
    try std.testing.expectEqual(@as(?runtime.Context, &realm), Test.last);
}

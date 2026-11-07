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
//! Two kinds of step (lane coi2 batch 3):
//! - (i) a document step (`install`): HTML's unloading document cleanup
//!   steps proper, which run whenever a document is unloaded or destroyed -
//!   a WebSocket made to disappear, a Web Lock released, a blob URL entry
//!   removed;
//! - (ii) a global teardown step (`installGlobalTeardown`): the end of what
//!   the global itself holds - its reporting observers' registrations, its
//!   channels' keeps - which run only when the global is discarded.
//! The two differ only when HTML "create and initialize a Document object"
//! step 6 reuses the Window: the initial about:blank document and the
//! same-origin one that replaces it "share the same Window object", so the
//! about:blank's unload runs the (i) steps alone (`runDocumentSteps`), and the
//! (ii) steps run once that Window's realm ends or a later document of it is
//! destroyed with no successor in it (`run`) - as Blink, whose reused
//! LocalDOMWindow (DocumentLoader ShouldReuseDOMWindow) never gets the
//! ContextDestroyed that ends a ReportingObserver or a BroadcastChannel.
//!
//! lint-impls: hook for URL, EventTarget, CustomElementRegistry

const std = @import("std");
const hook = @import("hook.zig");
const runtime = @import("runtime");

/// One specification's unloading document cleanup step, for `environment`.
pub const Step = *const fn (environment: runtime.Context) void;

/// Which of the two kinds a step is (the module comment says why).
pub const Kind = enum { document, global_teardown };

const Entry = struct { step: Step, kind: Kind };

const max_steps = 24;
/// Process-wide, written once at start-up (hook.zig).
var steps: hook.Hook(hook.List(Entry, max_steps)) = .init(.empty);

/// Install `step` as a document step: HTML's unloading document cleanup
/// steps, run at every unload of a document. Idempotent: the same function
/// installs once.
pub fn install(step: Step) void {
    installKind(step, .document);
}

/// Install `step` as a global teardown step: it ends what the global holds,
/// and runs only when the global is discarded - never for a document whose
/// Window the next document reuses. Idempotent.
pub fn installGlobalTeardown(step: Step) void {
    installKind(step, .global_teardown);
}

fn installKind(step: Step, kind: Kind) void {
    const list = steps.installing();
    for (list.slice()) |entry| if (entry.step == step) return;
    // A step dropped here would be cleanup that never runs: past the
    // capacity the append panics (there are far fewer owners than slots).
    list.append(.{ .step = step, .kind = kind });
}

/// Run every installed step for `environment`, in installation order: its
/// document is being unloaded or destroyed and its global with it, or its
/// worker has ended. Running them again for the same environment finds
/// nothing left to do.
pub fn run(environment: runtime.Context) void {
    for (steps.read().slice()) |entry| entry.step(environment);
}

/// Run the document steps alone for `environment`: its document is unloaded
/// or destroyed, but its global lives on with the next document (HTML
/// "create and initialize a Document object" step 6). The global teardown
/// steps run when the global is discarded (`run`).
pub fn runDocumentSteps(environment: runtime.Context) void {
    for (steps.read().slice()) |entry| if (entry.kind == .document) entry.step(environment);
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

test "a reused Window's unload runs the document steps alone; the global's end runs both kinds" {
    const Test = struct {
        var document_runs: usize = 0;
        var teardown_runs: usize = 0;
        fn documentStep(_: runtime.Context) void {
            document_runs += 1;
        }
        fn teardownStep(_: runtime.Context) void {
            teardown_runs += 1;
        }
    };
    const override = steps.overrideForTest(.empty);
    defer override.restore();

    install(&Test.documentStep);
    installGlobalTeardown(&Test.teardownStep);
    // A step installs once, whichever kind asks again.
    installGlobalTeardown(&Test.documentStep);
    var realm: runtime.ContextData = undefined;

    // The initial about:blank's unload, its Window kept for the next document.
    runDocumentSteps(&realm);
    try std.testing.expectEqual(@as(usize, 1), Test.document_runs);
    try std.testing.expectEqual(@as(usize, 0), Test.teardown_runs);

    // The global's end.
    run(&realm);
    try std.testing.expectEqual(@as(usize, 2), Test.document_runs);
    try std.testing.expectEqual(@as(usize, 1), Test.teardown_runs);
}

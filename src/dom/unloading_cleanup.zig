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
//! And two kinds of environment (lane crash1): a step is for documents and
//! workers (`install`, `installGlobalTeardown`), or for documents alone
//! (`installDocumentOnly`) - a step about something only a document has,
//! which a worker's end (`runWorkerEnd`) never runs. Fullscreen's "fully exit
//! fullscreen" is one: a worker has no fullscreen element, and the step finds
//! the document through the Browser's browsing contexts, which only the
//! window agent's thread may read - a worker's end runs on the worker's
//! thread. Run there, it raced the window agent's frame changes and crashed
//! (resource-timing/TAO-match.html, SIGABRT "incorrect alignment"; a
//! service worker's end, "General protection exception": lane ifr1's FULL
//! A/B, 2026-11-14). Blink draws the same line: its fullscreen state is a
//! window's (Fullscreen is a Supplement<LocalDOMWindow>), and a
//! WorkerGlobalScope has none to end.
//!
//! lint-impls: hook for URL, EventTarget, CustomElementRegistry

const std = @import("std");
const hook = @import("hook.zig");
const runtime = @import("runtime");

/// One specification's unloading document cleanup step, for `environment`.
pub const Step = *const fn (environment: runtime.Context) void;

/// Which of the two kinds a step is (the module comment says why).
pub const Kind = enum { document, global_teardown };

/// Which environments' ends a step is for (the module comment says why).
pub const Environments = enum { documents_and_workers, documents };

const Entry = struct { step: Step, kind: Kind, environments: Environments };

const max_steps = 24;
/// Process-wide, written once at start-up (hook.zig).
var steps: hook.Hook(hook.List(Entry, max_steps)) = .init(.empty);

/// Install `step` as a document step: HTML's unloading document cleanup
/// steps, run at every unload of a document. Idempotent: the same function
/// installs once.
pub fn install(step: Step) void {
    installKind(step, .document, .documents_and_workers);
}

/// Install `step` as a document step that only a document's end runs: a
/// worker's end (`runWorkerEnd`) skips it. For a step about something a
/// worker never has - its fullscreen element - and above all one that reads
/// the window agent's own state, which a worker's end, on the worker's
/// thread, must not touch. Idempotent.
pub fn installDocumentOnly(step: Step) void {
    installKind(step, .document, .documents);
}

/// Install `step` as a global teardown step: it ends what the global holds,
/// and runs only when the global is discarded - never for a document whose
/// Window the next document reuses. Idempotent.
pub fn installGlobalTeardown(step: Step) void {
    installKind(step, .global_teardown, .documents_and_workers);
}

fn installKind(step: Step, kind: Kind, environments: Environments) void {
    const list = steps.installing();
    for (list.slice()) |entry| if (entry.step == step) return;
    // A step dropped here would be cleanup that never runs: past the
    // capacity the append panics (there are far fewer owners than slots).
    list.append(.{ .step = step, .kind = kind, .environments = environments });
}

/// Run every installed step for `environment`, in installation order: its
/// document is being unloaded or destroyed and its global with it. Running
/// them again for the same environment finds nothing left to do. A worker's
/// end runs `runWorkerEnd`, never this.
pub fn run(environment: runtime.Context) void {
    for (steps.read().slice()) |entry| entry.step(environment);
}

/// Run the steps for workers for `environment`, a worker's realm that has
/// ended ("run a worker", once its event loop exits), in installation order,
/// on the worker's thread: both kinds - its global goes with it - but no
/// document-only step (`installDocumentOnly`).
pub fn runWorkerEnd(environment: runtime.Context) void {
    for (steps.read().slice()) |entry| if (entry.environments == .documents_and_workers) entry.step(environment);
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

test "a worker's end runs the steps for workers of both kinds, and no document-only step" {
    const Test = struct {
        var shared_runs: usize = 0;
        var teardown_runs: usize = 0;
        var document_only_runs: usize = 0;
        fn sharedStep(_: runtime.Context) void {
            shared_runs += 1;
        }
        fn teardownStep(_: runtime.Context) void {
            teardown_runs += 1;
        }
        fn documentOnlyStep(_: runtime.Context) void {
            document_only_runs += 1;
        }
    };
    const override = steps.overrideForTest(.empty);
    defer override.restore();

    install(&Test.sharedStep);
    installDocumentOnly(&Test.documentOnlyStep);
    installGlobalTeardown(&Test.teardownStep);
    // A step installs once, whichever installer asks again: the first kind
    // and environments stand.
    install(&Test.documentOnlyStep);
    var realm: runtime.ContextData = undefined;

    // A worker's end.
    runWorkerEnd(&realm);
    try std.testing.expectEqual(@as(usize, 1), Test.shared_runs);
    try std.testing.expectEqual(@as(usize, 1), Test.teardown_runs);
    try std.testing.expectEqual(@as(usize, 0), Test.document_only_runs);

    // A document's unload with its Window kept, then its global's end: the
    // document-only step runs at both.
    runDocumentSteps(&realm);
    try std.testing.expectEqual(@as(usize, 2), Test.shared_runs);
    try std.testing.expectEqual(@as(usize, 1), Test.teardown_runs);
    try std.testing.expectEqual(@as(usize, 1), Test.document_only_runs);
    run(&realm);
    try std.testing.expectEqual(@as(usize, 3), Test.shared_runs);
    try std.testing.expectEqual(@as(usize, 2), Test.teardown_runs);
    try std.testing.expectEqual(@as(usize, 2), Test.document_only_runs);
}

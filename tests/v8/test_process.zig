//! The process a tests/v8 test runs in.
//!
//! tools/test_launcher runs this directory's tests in any order: a process
//! per test, a few to a process, or the whole suite in one shuffled process.
//! So a test may assume only what `start` makes, and must leave the process
//! as it found it (the approved test plan, tmp/plans/test-architecture-
//! recommendation.md section 3: Blink gives each test a fresh isolate,
//! SpiderMonkey's jsapi-tests assert no runtime is alive at exit). Lane
//! v8order1 found four ways tests/v8 broke that, each a test changing state
//! that later tests of the same process read (docs/testing/
//! tests-v8-order-findings-2026-11-01.tsv):
//!
//! - the standalone runtime: a test that ended it (runtime.deinitializeRuntime)
//!   took it from every later test whose helper had cached "started" in a
//!   once-flag - "a platform object made in a realm no Browser owns, with no
//!   standalone runtime" (`start`, `OwnRuntime`);
//! - V8's flags: a test whose first act was a bare `v8_Isolate_New` started
//!   V8 without the runtime's flags (ShadowRealm, JSPI, Float16Array), which
//!   V8 freezes when it starts (`start`);
//! - an isolate left entered: a file's helper that entered its isolate for
//!   the process made it the current isolate of every later test
//!   (`FileIsolate`);
//! - process hooks installed lazily: a test that swapped a hook before its
//!   helper's first call had the helper's start-up overwrite the swap, and
//!   then restored "no hooks" over the real ones (`start` first).
//!
//! Not a test file: the tests of this directory import it.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const ffi = @import("v8").ffi;

/// Start what every test may assume, as crane.Process starts a host
/// (src/browser/process.zig): the engine - V8's platform with the runtime's
/// flags, and the process's dispatchers - then every src/dom hook, once, by
/// whichever test asks first, recorded in the process's own start-up state
/// (dom.process_start); and the standalone runtime (runtime.initializeRuntime),
/// the scope every realm no Browser owns allocates from, when none is
/// running. Call it before anything that starts V8 - a bare
/// `ffi.v8_Isolate_New` included - and before swapping a hook. Nothing a test
/// does may end what this starts; a test that needs a standalone runtime of
/// its own takes one with `OwnRuntime`.
pub fn start() void {
    if (dom.process_start.begin()) {
        engine.initializeEngine(.{}) catch @panic("tests/v8: the engine did not start");
        interfaces.process_hooks.startHooksForTest();
        dom.process_start.finish(false);
    } else switch (dom.process_start.waitUntilStarted()) {
        .running => {},
        else => @panic("tests/v8: the process did not start"),
    }
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
}

/// A standalone runtime of the test's own, so that what it leaves in its
/// slab and arena is freed - through the test's allocator, which then reports
/// a leak - when the test ends: `begin` starts the process (`start`) and puts
/// a new standalone scope in the process's place; `end` ends it and puts the
/// process's back. Every later test then finds the runtime the earlier ones
/// made, which a bare `runtime.deinitializeRuntime` took from them.
pub const OwnRuntime = struct {
    previous: ?*runtime.BrowserScope,

    pub fn begin(allocator: std.mem.Allocator) OwnRuntime {
        start();
        const previous = runtime.BrowserScope.standalone();
        runtime.initializeRuntime(allocator);
        return .{ .previous = previous };
    }

    pub fn end(self: OwnRuntime) void {
        runtime.deinitializeRuntime();
        runtime.BrowserScope.setStandalone(self.previous);
    }
};

/// An isolate a test file keeps for the whole process, the current isolate
/// only while one of its tests runs: left entered, it would be the current
/// isolate of every later test of the process (engine_agent_test's "the
/// page's" isolate was, and every test after it that compared the current
/// isolate with its own failed). Its entered context and handle scope are its
/// own (V8 keeps both per isolate), so they stay between tests.
///
/// The file's helper sets `isolate` once, then calls `enter` wherever a test
/// needs it current; every test of the file starts with
/// `defer file.leave();`, which undoes every entry `enter` made.
pub const FileIsolate = struct {
    isolate: ?*ffi.Isolate = null,
    /// The entries `enter` made since the last `leave`.
    entries: u32 = 0,

    /// Make the file's isolate the current one, unless it is.
    pub fn enter(self: *FileIsolate) void {
        const isolate = self.isolate.?;
        if (ffi.v8_Isolate_GetCurrent() == isolate) return;
        ffi.v8_Isolate_Enter(isolate);
        self.entries += 1;
    }

    /// Undo every entry `enter` made: the current isolate is the one before.
    pub fn leave(self: *FileIsolate) void {
        while (self.entries > 0) : (self.entries -= 1) ffi.v8_Isolate_Exit(self.isolate.?);
    }
};

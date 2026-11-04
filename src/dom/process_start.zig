//! The process's start-up phase: the `process` module's `start`
//! (src/process/start.zig), re-exported so that src/dom and the layers that
//! reach it through dom (`dom.process_start`: crane.Process, the Crane test
//! runner, the generated `process_hooks.startHooksForTest()`) keep their
//! name for it. It lives in that leaf module because hook slots below dom
//! (the runtime tier, the V8 adapter, fetch, hr_time) ask it too.

const start = @import("process").start;

pub const Phase = start.Phase;
pub const State = start.State;
pub const get = start.get;
pub const begin = start.begin;
pub const finish = start.finish;
pub const end = start.end;
pub const waitUntilStarted = start.waitUntilStarted;
pub const Writer = start.Writer;
pub const writerOf = start.writerOf;
pub const writer = start.writer;
pub const refuseWrite = start.refuseWrite;
pub const installForTest = start.installForTest;
pub const outstandingOverrides = start.outstandingOverrides;
pub const OverrideObserver = start.OverrideObserver;
pub const observeOverridesForTest = start.observeOverridesForTest;
pub const overrideMade = start.overrideMade;
pub const overrideRestored = start.overrideRestored;

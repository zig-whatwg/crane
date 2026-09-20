//! HTML Event Loop Module
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-loops
//! HTML Standard §8.1.7 "Event loops"
//!
//! # ⚠️ NOTHING RUNS THIS LOOP
//!
//! This module is allocated but never driven. Verified 2026-09-20:
//!
//!   * `WorkerContext.spin` (workers/worker_context.zig:285), `WorkerAgent.spin`
//!     (:204), `DedicatedWorker.spin` (:749) and `SharedWorker.spin` (:345) form a
//!     chain whose OUTERMOST link has no caller anywhere outside this package's own
//!     tests. A `DedicatedWorker` IS constructed (impls/Worker.zig:571), so a
//!     `WorkerContext` and its `EventLoop` are created - and then never spun.
//!   * `WorkerGlobalScope.setEventLoop` (impls/WorkerGlobalScope.zig:205) is never
//!     called, so `internal.event_loop` is always null and `call_setTimeout` returns
//!     `error.NotImplemented`.
//!   * `EventLoop.init(.window, ...)` appears only in this file's own tests.
//!
//! The live path for BOTH window and worker is the V8 loop:
//! `runtime/engines/v8/event_loop.zig` (`V8EventLoop`), which implements the
//! `event_loop` interface that `runtime.ContextData.event_loop` is typed against.
//! Timers go through `NativeTimerManager`, microtasks through V8's own queue.
//!
//! ## What that cost, concretely
//!
//! This module implements HTML §8.6's timer clamp (`timers.zig`:
//! `MIN_NESTED_DELAY_MS`, `NESTING_LEVEL_THRESHOLD`). Because it never ran, the
//! clamp had to be re-implemented in the window's binding layer - and the WORKER
//! binding got no clamp at all until 2026-09-20. Two implementations, one applied,
//! one path unprotected. The rule now lives in `v8.native_timer`, where both
//! bindings reach it.
//!
//! ## Before using anything here
//!
//! Check whether the live loop already does it. Adding a caller to this module
//! does not make it run - `V8EventLoop.runOnceBlocking` is what the browser
//! actually pumps (`browser/Browser.zig:483`). What this module still has that the
//! live loop does not is the 16 spec task sources and a Zig-side microtask queue
//! with checkpoint callbacks; porting those INTO `V8EventLoop` is the useful
//! direction, not reviving this one.
//!
//! Note the flat `std.ArrayList(Task)` in `V8EventLoop` is NOT a spec violation:
//! §8.1.7 lets the implementation choose which task queue to service, and a single
//! FIFO preserves same-source order, which is the guarantee the spec actually
//! makes. Task sources buy prioritisation and the ability to pause a source, not
//! ordering correctness.
//!
//! This module provides the core event loop implementation for HTML processing.
//! The event loop coordinates events, user interaction, scripts, rendering,
//! networking, and more.
//!
//! ## Key Components
//!
//! - `EventLoop` - The main event loop struct
//! - `Task` - A task to be executed by the event loop
//! - `TaskSource` - Categorizes tasks by their origin
//! - `TaskQueue` - A queue of tasks from related sources
//! - `Microtask` - A microtask for Promise reactions and similar
//! - `MicrotaskQueue` - The queue of pending microtasks
//! - `TimerManager` - Manages setTimeout/setInterval
//!
//! ## Example Usage
//!
//! ```zig
//! const std = @import("std");
//! const event_loop = @import("event_loop/root.zig");
//! const timer_backend = @import("../platform/timer_backend.zig");
//!
//! pub fn main() !void {
//!     const allocator = std.heap.page_allocator;
//!
//!     // Create a timer backend
//!     const platform = try timer_backend.RealTimerBackend.init(allocator);
//!     defer platform.deinit();
//!
//!     // Create the event loop
//!     var loop = try event_loop.EventLoop.init(allocator, .window, platform.backend());
//!     defer loop.deinit();
//!
//!     // Queue a task
//!     _ = try loop.queueTask(.dom_manipulation, myCallback, myContext, null);
//!
//!     // Set a timer
//!     _ = try loop.setTimeout(timerCallback, 1000, null);
//!
//!     // Run the event loop
//!     try loop.run();
//! }
//! ```

const std = @import("std");

// Core modules
pub const task = @import("task.zig");
pub const task_queue = @import("task_queue.zig");
pub const microtask = @import("microtask.zig");
pub const timers = @import("timers.zig");
pub const rendering = @import("rendering.zig");
pub const event_loop = @import("event_loop.zig");

// Main types
pub const Task = task.Task;
pub const TaskSource = task.TaskSource;
pub const Microtask = task.Microtask;

pub const TaskQueue = task_queue.TaskQueue;
pub const TaskQueueSet = task_queue.TaskQueueSet;

pub const MicrotaskQueue = microtask.MicrotaskQueue;
pub const MicrotaskCheckpointState = microtask.MicrotaskCheckpointState;
pub const MicrotaskCheckpointCallbacks = microtask.MicrotaskCheckpointCallbacks;
pub const performMicrotaskCheckpoint = microtask.performMicrotaskCheckpoint;

pub const Timer = timers.Timer;
pub const TimerManager = timers.TimerManager;
pub const VisibilityState = timers.VisibilityState;

pub const FrameRequestCallback = rendering.FrameRequestCallback;
pub const AnimationFrameProvider = rendering.AnimationFrameProvider;
pub const RenderingState = rendering.RenderingState;
pub const IdleCallback = rendering.IdleCallback;
pub const IdleDeadline = rendering.IdleDeadline;
pub const IdleCallbackManager = rendering.IdleCallbackManager;

pub const EventLoop = event_loop.EventLoop;
pub const EventLoopType = event_loop.EventLoopType;
pub const RenderingCallbacks = event_loop.RenderingCallbacks;

test {
    std.testing.refAllDecls(@This());
}

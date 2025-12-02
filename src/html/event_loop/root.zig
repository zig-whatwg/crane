//! HTML Event Loop Module
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#event-loops
//! HTML Standard §8.1.7 "Event loops"
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

pub const EventLoop = event_loop.EventLoop;
pub const EventLoopType = event_loop.EventLoopType;
pub const RenderingCallbacks = event_loop.RenderingCallbacks;

test {
    std.testing.refAllDecls(@This());
}

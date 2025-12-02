//! HTML Specification Implementation
//!
//! Spec: https://html.spec.whatwg.org/
//! HTML Living Standard
//!
//! This module provides implementations of various parts of the HTML specification:
//!
//! - **Event Loop** (§8.1.7) - Core event loop for coordinating events, scripts,
//!   rendering, and more
//! - **Timers** (§8.6) - setTimeout() and setInterval()
//! - **Custom Elements** - Custom element registry and lifecycle
//!
//! ## Architecture
//!
//! The HTML module is organized around the key concepts from the spec:
//!
//! ```
//! src/html/
//! ├── event_loop/          # Event loop, task queues, microtasks, timers
//! │   ├── event_loop.zig   # Main EventLoop struct
//! │   ├── task.zig         # Task and TaskSource definitions
//! │   ├── task_queue.zig   # TaskQueue and TaskQueueSet
//! │   ├── microtask.zig    # Microtask queue and checkpoint
//! │   ├── timers.zig       # setTimeout/setInterval
//! │   └── root.zig         # Module exports
//! ├── custom_elements.zig  # Custom element definitions
//! └── root.zig             # This file
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const html = @import("html/root.zig");
//! const timer_backend = @import("platform/timer_backend.zig");
//!
//! // Create event loop
//! const platform = try timer_backend.RealTimerBackend.init(allocator);
//! var event_loop = try html.EventLoop.init(allocator, .window, platform.backend());
//! defer event_loop.deinit();
//!
//! // Queue tasks
//! _ = try event_loop.queueTask(.dom_manipulation, callback, context, null);
//!
//! // Set timers
//! _ = try event_loop.setTimeout(timerCallback, 1000, null);
//!
//! // Run
//! try event_loop.run();
//! ```

const std = @import("std");

// Event Loop (§8.1.7)
pub const event_loop = @import("event_loop/root.zig");

// Re-export commonly used types
pub const EventLoop = event_loop.EventLoop;
pub const EventLoopType = event_loop.EventLoopType;
pub const Task = event_loop.Task;
pub const TaskSource = event_loop.TaskSource;
pub const Microtask = event_loop.Microtask;
pub const Timer = event_loop.Timer;
pub const TimerManager = event_loop.TimerManager;
pub const VisibilityState = event_loop.VisibilityState;
pub const RenderingCallbacks = event_loop.RenderingCallbacks;

// Custom Elements
pub const custom_elements = @import("custom_elements.zig");

test {
    std.testing.refAllDecls(@This());
}

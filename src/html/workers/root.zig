//! Web Workers Module
//!
//! Spec: HTML Standard § 10 Web workers
//! https://html.spec.whatwg.org/#workers
//!
//! This module implements the Web Workers specification, providing:
//!
//! - **Dedicated Workers** (§10.2.3) - Workers owned by a single Document or worker
//! - **Shared Workers** (§10.2.4) - Workers that can be shared between multiple contexts
//! - **Worker Agent** - Event loop and lifecycle management for workers
//!
//! ## Architecture
//!
//! ```
//! src/html/workers/
//! ├── types.zig              # Core type definitions
//! ├── worker_agent.zig       # Worker agent (event loop + state)
//! ├── dedicated_worker.zig   # DedicatedWorker implementation
//! ├── shared_worker.zig      # SharedWorker implementation
//! ├── shared_worker_manager.zig  # Registry for shared workers
//! ├── worker_location.zig    # WorkerLocation implementation
//! ├── worker_navigator.zig   # WorkerNavigator implementation
//! └── root.zig               # This file
//! ```
//!
//! ## Usage
//!
//! ### Dedicated Worker
//!
//! ```zig
//! const workers = @import("html/workers/root.zig");
//! const timer_backend = @import("platform").timer_backend;
//!
//! // Create platform backend
//! const mock = try timer_backend.MockTimerBackend.init(allocator);
//! defer mock.allocator.destroy(mock);
//!
//! // Create dedicated worker
//! const worker = try workers.DedicatedWorker.init(
//!     allocator,
//!     mock.backend(),
//!     "https://example.com/worker.js",
//!     .{ .name = "my-worker" },
//! );
//! defer worker.deinit();
//!
//! // Start the worker
//! try worker.start();
//!
//! // Worker runs its event loop
//! // ...
//!
//! // Terminate when done
//! worker.terminate();
//! ```
//!
//! ### Shared Worker
//!
//! ```zig
//! const workers = @import("html/workers/root.zig");
//!
//! // Create shared worker manager
//! var manager = workers.SharedWorkerManager.init(allocator, platform);
//! defer manager.deinit();
//!
//! // Get or create shared worker
//! const result = try manager.getOrCreate(
//!     "https://example.com/shared.js",
//!     "my-shared-worker",
//!     .{},
//!     "https://example.com",
//! );
//!
//! if (result.is_new) {
//!     // New worker, start it
//!     try result.worker.start();
//! }
//!
//! // Connect to the worker
//! const conn = try result.worker.connect();
//! // conn.outside_port is the MessagePort for communication
//! ```

const std = @import("std");

// Core types
pub const types = @import("types.zig");
pub const WorkerType = types.WorkerType;
pub const RequestCredentials = types.RequestCredentials;
pub const WorkerOptions = types.WorkerOptions;
pub const WorkerState = types.WorkerState;
pub const WorkerOwner = types.WorkerOwner;
pub const WorkerData = types.WorkerData;
pub const HttpsState = types.HttpsState;
pub const WorkerError = types.WorkerError;

// Worker Agent
pub const worker_agent = @import("worker_agent.zig");
pub const WorkerAgent = worker_agent.WorkerAgent;

// Dedicated Worker
pub const dedicated_worker = @import("dedicated_worker.zig");
pub const DedicatedWorker = dedicated_worker.DedicatedWorker;

// Shared Worker
pub const shared_worker = @import("shared_worker.zig");
pub const SharedWorker = shared_worker.SharedWorker;
pub const SharedWorkerConnection = shared_worker.SharedWorkerConnection;

// Shared Worker Manager
pub const shared_worker_manager = @import("shared_worker_manager.zig");
pub const SharedWorkerManager = shared_worker_manager.SharedWorkerManager;

// Worker Location
pub const worker_location = @import("worker_location.zig");
pub const WorkerLocation = worker_location.WorkerLocation;

// Worker Navigator
pub const worker_navigator = @import("worker_navigator.zig");
pub const WorkerNavigator = worker_navigator.WorkerNavigator;

test {
    std.testing.refAllDecls(@This());
}

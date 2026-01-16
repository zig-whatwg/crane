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
pub const ConnectEventCallback = shared_worker.ConnectEventCallback;

// Shared Worker Manager
pub const shared_worker_manager = @import("shared_worker_manager.zig");
pub const SharedWorkerManager = shared_worker_manager.SharedWorkerManager;

// Worker Location
pub const worker_location = @import("worker_location.zig");
pub const WorkerLocation = worker_location.WorkerLocation;

// Worker Navigator
pub const worker_navigator = @import("worker_navigator.zig");
pub const WorkerNavigator = worker_navigator.WorkerNavigator;

// Script Fetching
pub const script_fetch = @import("script_fetch.zig");
pub const fetchWorkerScript = script_fetch.fetchWorkerScript;
pub const fetchImportScripts = script_fetch.fetchImportScripts;
pub const FetchedScript = script_fetch.FetchedScript;
pub const WorkerScriptError = script_fetch.WorkerScriptError;
pub const WorkerScriptFetchOptions = script_fetch.WorkerScriptFetchOptions;
pub const isValidWorkerScriptType = script_fetch.isValidWorkerScriptType;

// Document Origin (for resolving relative Worker script URLs)
pub const setDocumentOrigin = script_fetch.setDocumentOrigin;
pub const getDocumentOrigin = script_fetch.getDocumentOrigin;
pub const clearDocumentOrigin = script_fetch.clearDocumentOrigin;

// Blob URL Resolution (callback-based to avoid circular dependencies)
pub const BlobResolveResult = script_fetch.BlobResolveResult;
pub const BlobResolverFn = script_fetch.BlobResolverFn;
pub const setBlobResolver = script_fetch.setBlobResolver;
pub const getBlobResolver = script_fetch.getBlobResolver;
pub const clearBlobResolver = script_fetch.clearBlobResolver;

// Message Channel (postMessage/MessageEvent)
pub const message_channel = @import("message_channel.zig");
pub const WorkerPortPair = message_channel.WorkerPortPair;
pub const WorkerPort = message_channel.WorkerPort;
pub const QueuedMessage = message_channel.QueuedMessage;
pub const WorkerMessageError = message_channel.WorkerMessageError;
pub const createWorkerPorts = message_channel.createWorkerPorts;
pub const serializeForPostMessage = message_channel.serializeForPostMessage;
pub const deserializeFromPostMessage = message_channel.deserializeFromPostMessage;

// Worker Context (V8 isolation)
pub const worker_context = @import("worker_context.zig");
pub const WorkerContext = worker_context.WorkerContext;
pub const WorkerContextError = worker_context.WorkerContextError;

// Module Worker Support
pub const module_worker = @import("module_worker.zig");
pub const ModuleWorkerConfig = module_worker.ModuleWorkerConfig;
pub const ModuleWorkerExecutor = module_worker.ModuleWorkerExecutor;
pub const validateImportScripts = module_worker.validateImportScripts;
pub const resolveWorkerModuleSpecifier = module_worker.resolveWorkerModuleSpecifier;
pub const isBareSpecifier = module_worker.isBareSpecifier;
pub const getImportScriptsTypeErrorMessage = module_worker.getImportScriptsTypeErrorMessage;

// Worker Error Handling
pub const worker_error = @import("worker_error.zig");
pub const WorkerErrorEvent = worker_error.WorkerErrorEvent;
pub const WorkerPromiseRejection = worker_error.WorkerPromiseRejection;
pub const WorkerErrorHandler = worker_error.WorkerErrorHandler;
pub const TerminationCleanup = worker_error.TerminationCleanup;
pub const TerminationState = worker_error.TerminationState;
pub const reportErrorToConsole = worker_error.reportErrorToConsole;
pub const createErrorEventFromException = worker_error.createErrorEventFromException;
pub const canAcceptTasks = worker_error.canAcceptTasks;
pub const canContinueExecution = worker_error.canContinueExecution;

// Worker Threading (true multi-threaded execution)
pub const worker_threading = @import("worker_threading.zig");
pub const ThreadSafeMessageQueue = worker_threading.ThreadSafeMessageQueue;
pub const WorkerThreadState = worker_threading.WorkerThreadState;
pub const WorkerThreadRunner = worker_threading.WorkerThreadRunner;
pub const ThreadedWorkerManager = worker_threading.ThreadedWorkerManager;

// Worker V8 Integration (V8 isolate per worker thread)
pub const worker_v8_integration = @import("worker_v8_integration.zig");
pub const WorkerIsolateData = worker_v8_integration.WorkerIsolateData;
pub const WorkerV8Integration = worker_v8_integration.WorkerV8Integration;
pub const V8WorkerError = worker_v8_integration.V8WorkerError;

test {
    std.testing.refAllDecls(@This());
}

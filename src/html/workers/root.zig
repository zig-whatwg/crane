//! Web Workers Module
//!
//! Spec: HTML Standard § 10 Web workers
//! https://html.spec.whatwg.org/#workers
//!
//! What the worker host (src/html/worker_host.zig) and the Worker,
//! SharedWorker and WorkerGlobalScope impls share that needs no interface:
//!
//! ```
//! src/html/workers/
//! ├── types.zig              # Core type definitions (WorkerType, credentials, options)
//! ├── worker_location.zig    # WorkerLocation's URL record
//! ├── worker_navigator.zig   # WorkerNavigator's values
//! ├── script_fetch.zig       # fetch a classic/module worker script
//! └── root.zig               # This file
//! ```
//!
//! A worker runs on a thread of its own (src/html/worker_thread.zig and its
//! companions); the modules that once modelled a worker here - an agent, a
//! context, a port pair, threading - are gone with that move.

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

test {
    std.testing.refAllDecls(@This());
}

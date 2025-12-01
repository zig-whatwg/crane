//! Mocks Module
//!
//! This module provides temporary mock implementations for WHATWG/W3C specs
//! that are not yet implemented. These mocks allow dependent specs (like
//! Storage, IndexedDB, and Service Workers) to be developed without waiting
//! for full implementations.
//!
//! ## Mocked Specs
//!
//! - **Cache API** (Service Workers): For Storage spec storage endpoints
//! - **File System API**: For Storage spec storage endpoints
//! - **Structured Clone**: For IndexedDB value serialization
//! - **Worker Infrastructure** (HTML): For Service Worker implementation
//!   - WorkerGlobalScope: Base interface for worker global scopes
//!   - WorkerLocation: URL information for workers
//!   - WorkerNavigator: Navigator interface for workers
//!   - Worker Event Loop: Task queuing and microtasks
//!   - Script Evaluation: Worker script execution
//!   - MessagePort: Inter-context messaging
//!
//! ## Usage
//!
//! ```zig
//! const mocks = @import("mocks");
//!
//! // Use structured clone mock for testing
//! const cloned = try mocks.structured_clone.clone(allocator, value);
//!
//! // Create a worker global scope for service worker testing
//! const scope = try mocks.WorkerGlobalScope.init(allocator, "https://example.com/sw.js", .module);
//! defer scope.deinit();
//! ```
//!
//! ## TODO
//!
//! All mocks in this module should eventually be replaced with full
//! implementations of their respective specifications:
//!
//! - Cache API: https://w3c.github.io/ServiceWorker/#cache-interface
//! - File System: https://fs.spec.whatwg.org/
//! - Structured Clone: https://html.spec.whatwg.org/multipage/structured-data.html
//! - Workers: https://html.spec.whatwg.org/multipage/workers.html
//!

const std = @import("std");

// === Existing Mocks ===
pub const cache_api = @import("cache_api.zig");
pub const file_system = @import("file_system.zig");
pub const structured_clone = @import("structured_clone.zig");
pub const environment = @import("environment.zig");
pub const origin_utils = @import("origin_utils.zig");
pub const service_worker = @import("service_worker.zig");
pub const form_data = @import("form_data.zig");

// === Worker Infrastructure Mocks (for Service Workers) ===
pub const worker_global_scope = @import("worker_global_scope.zig");
pub const worker_location = @import("worker_location.zig");
pub const worker_navigator = @import("worker_navigator.zig");
pub const worker_event_loop = @import("worker_event_loop.zig");
pub const script_evaluation = @import("script_evaluation.zig");
pub const message_port = @import("message_port.zig");

// Environment exports for convenience.
pub const EnvironmentSettingsObject = environment.EnvironmentSettingsObject;
pub const PolicyContainer = environment.PolicyContainer;
pub const ReferrerPolicy = environment.ReferrerPolicy;
pub const EmbedderPolicy = environment.EmbedderPolicy;
pub const createMockGlobal = environment.createMockGlobal;
pub const destroyMockGlobal = environment.destroyMockGlobal;
pub const sameOrigin = environment.sameOrigin;

// Origin utilities exports
pub const isSameOriginDomain = origin_utils.isSameOriginDomain;
pub const isSameSite = origin_utils.isSameSite;
pub const isSchemelesslySameSite = origin_utils.isSchemelesslySameSite;
pub const getRegistrableDomain = origin_utils.getRegistrableDomain;

// Service worker exports
pub const ServiceWorkerController = service_worker.ServiceWorkerController;
pub const ServiceWorkersMode = service_worker.ServiceWorkersMode;

// FormData exports
pub const FormData = form_data.FormData;
pub const encodeMultipart = form_data.encodeMultipart;
pub const parseUrlEncoded = form_data.parseUrlEncoded;

// Worker infrastructure exports (for Service Workers)
pub const WorkerGlobalScope = worker_global_scope.WorkerGlobalScope;
pub const WorkerLocation = worker_location.WorkerLocation;
pub const WorkerNavigator = worker_navigator.WorkerNavigator;
pub const WorkerEventLoop = worker_event_loop.WorkerEventLoop;
pub const TaskSource = worker_event_loop.TaskSource;
pub const ScriptEvaluator = script_evaluation.ScriptEvaluator;
pub const ScriptType = script_evaluation.ScriptType;
pub const EvaluationResult = script_evaluation.EvaluationResult;
pub const MessagePort = message_port.MessagePort;
pub const MessageChannel = message_port.MessageChannel;

/// Common error type for mock implementations
pub const MockError = error{
    /// Operation not yet implemented - this is expected for mocks
    NotImplemented,
    /// Operation would require full spec implementation
    RequiresFullImplementation,
    /// Type not supported by mock
    UnsupportedType,
    /// Out of memory
    OutOfMemory,
};

test {
    std.testing.refAllDecls(@This());
}

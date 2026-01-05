//! Service Worker Algorithms Module (Layer 2 - Scheduling)
//!
//! Implementation of the Service Worker specification algorithms from Appendix A.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#algorithms
//!
//! ## Architecture: Layer 2 (Scheduling) vs Layer 3 (Execution)
//!
//! This algorithms/ directory is **Layer 2 (Scheduling)** - it handles:
//! - Registration state machine and job queue management
//! - Lifecycle transitions (install, activate, terminate)
//! - Fetch event routing
//!
//! **CRITICAL**: This layer MUST NOT import from:
//! - `global/` (ServiceWorkerGlobalScope) - execution layer
//! - `browser/` - browser integration layer
//! - `runtime/` - V8/JS engine bindings
//!
//! The execution layer (Layer 3) is in `src/browser/service_worker/ServiceWorkerManager.zig`
//! which implements the `RunContext` callbacks defined in `registrar_contract.zig`.
//!
//! This separation prevents circular dependencies. See tests/service_worker/import_cycle_test.zig.
//!
//! ## Overview
//!
//! This module contains the core algorithms that define the service worker lifecycle
//! and behavior:
//!
//! - **Job Processing**: Create, schedule, and run jobs
//! - **Register**: Register a new service worker
//! - **Update**: Check for script updates
//! - **Install**: Handle the install event
//! - **Activate**: Handle the activate event
//! - **Handle Fetch**: Intercept fetch requests
//! - **Terminate**: Stop a service worker
//! - **Soft Update**: Schedule background updates
//! - **Try Activate**: Check activation conditions
//! - **Try Clear**: Remove unused registrations
//! - **Get Newest Worker**: Find the most recent worker
//!
//! ## Usage
//!
//! ```zig
//! const algorithms = @import("service_worker").algorithms;
//!
//! // Register a new service worker
//! const result = try algorithms.register(
//!     storage_key,
//!     script_url,
//!     .{ .worker_type = .module },
//!     context,
//! );
//!
//! // Handle a fetch request
//! const fetch_result = algorithms.handleFetch(registration, request, context, allocator);
//! switch (fetch_result) {
//!     .response => |resp| // Use the response from SW
//!     .network => // Fall back to network
//!     .err => |e| // Handle error
//! }
//! ```

const std = @import("std");

// Get Newest Worker
pub const get_newest = @import("get_newest.zig");
pub const getNewestWorker = get_newest.getNewestWorker;

// Try Clear Registration
pub const try_clear = @import("try_clear.zig");
pub const tryClearRegistration = try_clear.tryClearRegistration;
pub const canClearRegistration = try_clear.canClearRegistration;
pub const TryClearResult = try_clear.TryClearResult;

// Try Activate
pub const try_activate = @import("try_activate.zig");
pub const tryActivate = try_activate.tryActivate;
pub const canActivate = try_activate.canActivate;
pub const TryActivateResult = try_activate.TryActivateResult;
pub const ActivationContext = try_activate.ActivationContext;

// Soft Update
pub const soft_update = @import("soft_update.zig");
pub const softUpdate = soft_update.softUpdate;
pub const shouldSoftUpdate = soft_update.shouldSoftUpdate;
pub const SoftUpdateResult = soft_update.SoftUpdateResult;

// Job Processing
pub const jobs = @import("jobs.zig");
pub const scheduleJob = jobs.scheduleJob;
pub const runNextJob = jobs.runNextJob;
pub const finishJob = jobs.finishJob;
pub const RunContext = jobs.RunContext;
pub const JobResult = jobs.JobResult;

// Install
pub const install_algorithm = @import("install.zig");
pub const install = install_algorithm.install;
pub const installSync = install_algorithm.installSync;
pub const InstallResult = install_algorithm.InstallResult;
pub const InstallContext = install_algorithm.InstallContext;

// Activate
pub const activate_algorithm = @import("activate.zig");
pub const activate = activate_algorithm.activate;
pub const activateSync = activate_algorithm.activateSync;
pub const ActivateResult = activate_algorithm.ActivateResult;
pub const ActivateContext = activate_algorithm.ActivateContext;

// Handle Fetch
pub const handle_fetch = @import("handle_fetch.zig");
pub const handleFetch = handle_fetch.handleFetch;
pub const shouldHandleFetch = handle_fetch.shouldHandleFetch;
pub const HandleFetchResult = handle_fetch.HandleFetchResult;
pub const HandleFetchContext = handle_fetch.HandleFetchContext;
pub const HandleFetchError = handle_fetch.HandleFetchError;
pub const RequestInfo = handle_fetch.RequestInfo;
pub const ResponseInfo = handle_fetch.ResponseInfo;
pub const Header = handle_fetch.Header;

// Register
pub const register_algorithm = @import("register.zig");
pub const register = register_algorithm.register;
pub const RegisterResult = register_algorithm.RegisterResult;
pub const RegisterOptions = register_algorithm.RegisterOptions;
pub const RegisterContext = register_algorithm.RegisterContext;

// Update
pub const update_algorithm = @import("update.zig");
pub const update = update_algorithm.update;
pub const updateSync = update_algorithm.updateSync;
pub const UpdateResult = update_algorithm.UpdateResult;
pub const UpdateContext = update_algorithm.UpdateContext;
pub const ScriptContent = update_algorithm.ScriptContent;

// Terminate
pub const terminate_algorithm = @import("terminate.zig");
pub const terminate = terminate_algorithm.terminate;
pub const forceTerminate = terminate_algorithm.forceTerminate;
pub const canTerminate = terminate_algorithm.canTerminate;
pub const TerminateResult = terminate_algorithm.TerminateResult;
pub const TerminateContext = terminate_algorithm.TerminateContext;

// =============================================================================
// Tests
// =============================================================================

test {
    std.testing.refAllDecls(@This());
}

//! Service Workers Module
//!
//! Implementation of W3C Service Workers specification.
//!
//! Spec: https://w3c.github.io/ServiceWorker/
//!
//! ## Overview
//!
//! Service Workers provide a programmable network proxy that runs independently
//! of web pages, enabling offline support, push notifications, and background sync.
//!
//! ## Module Structure
//!
//! - **types.zig**: Enums and basic types (ServiceWorkerState, WorkerType, etc.)
//! - **timing.zig**: Service worker timing info for performance APIs
//! - **service_worker.zig**: Internal ServiceWorker struct
//! - **registration.zig**: Internal ServiceWorkerRegistration struct
//! - **client.zig**: Internal Client/WindowClient structs
//! - **registration_map.zig**: Global registration map
//! - **job.zig**: Job queue system for serializing operations
//!
//! ## Usage
//!
//! ```zig
//! const sw = @import("service_worker");
//!
//! // Create a registration
//! const reg = try sw.Registration.init(allocator, "https://example.com", "https://example.com/");
//! defer reg.deinit();
//!
//! // Create a service worker
//! const worker = try sw.ServiceWorker.init(allocator, "https://example.com/sw.js", .module);
//! defer worker.deinit();
//!
//! // Set as installing worker
//! reg.setInstallingWorker(worker);
//! ```
//!
//! ## Status
//!
//! This implementation is in progress. Currently implemented:
//! - [x] Core data structures (Phase 2)
//! - [x] Client-side interfaces (Phase 3)
//! - [x] ServiceWorkerGlobalScope (Phase 4)
//! - [ ] Events (Phase 5)
//! - [ ] Cache API (Phase 6)
//! - [ ] Core algorithms (Phase 7)
//! - [ ] Fetch integration (Phase 8)

const std = @import("std");

// Core types
pub const types = @import("types.zig");
pub const ServiceWorkerState = types.ServiceWorkerState;
pub const WorkerType = types.WorkerType;
pub const UpdateViaCacheMode = types.UpdateViaCacheMode;
pub const FrameType = types.FrameType;
pub const ClientType = types.ClientType;
pub const VisibilityState = types.VisibilityState;
pub const JobType = types.JobType;
pub const RunningStatus = types.RunningStatus;
pub const RouterSourceEnum = types.RouterSourceEnum;
pub const ServiceWorkerTimingInfo = types.ServiceWorkerTimingInfo;
pub const RegistrationOptions = types.RegistrationOptions;
pub const ClientQueryOptions = types.ClientQueryOptions;
pub const NavigationPreloadState = types.NavigationPreloadState;
pub const CacheQueryOptions = types.CacheQueryOptions;
pub const MultiCacheQueryOptions = types.MultiCacheQueryOptions;

// Timing
pub const timing = @import("timing.zig");
pub const TimingInfo = timing.TimingInfo;

// Core structures
pub const service_worker = @import("service_worker.zig");
pub const ServiceWorker = service_worker.ServiceWorker;

pub const registration = @import("registration.zig");
pub const Registration = registration.Registration;

pub const client = @import("client.zig");
pub const Client = client.Client;
pub const WindowClient = client.WindowClient;

// Global state
pub const registration_map = @import("registration_map.zig");
pub const RegistrationMap = registration_map.RegistrationMap;
pub const RegistrationKey = registration_map.RegistrationKey;

// Job queue
pub const job = @import("job.zig");
pub const Job = job.Job;
pub const JobQueue = job.JobQueue;
pub const ScopeToJobQueueMap = job.ScopeToJobQueueMap;

// Client-side WebIDL interfaces (Phase 3)
pub const interfaces = @import("interfaces/root.zig");

// Re-export commonly used interface types
pub const ServiceWorkerInterface = interfaces.ServiceWorkerInterface;
pub const ServiceWorkerRegistrationInterface = interfaces.ServiceWorkerRegistrationInterface;
pub const ServiceWorkerContainer = interfaces.ServiceWorkerContainer;
pub const NavigationPreloadManager = interfaces.NavigationPreloadManager;
pub const ClientInterface = interfaces.ClientInterface;
pub const WindowClientInterface = interfaces.WindowClientInterface;

// ServiceWorkerGlobalScope and context APIs (Phase 4)
pub const global = @import("global/root.zig");

// Re-export commonly used global types
pub const ServiceWorkerGlobalScope = global.ServiceWorkerGlobalScope;
pub const Clients = global.Clients;

// =============================================================================
// Tests
// =============================================================================

test {
    std.testing.refAllDecls(@This());
}

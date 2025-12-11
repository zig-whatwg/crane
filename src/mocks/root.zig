//! ⚠️ MOCKS MODULE - DEPRECATED
//!
//! This module contains temporary mocks for specs not yet fully implemented.
//! Most mocks now have real implementations - prefer using:
//!
//! - src/webidl/interfaces/ - WebIDL interface implementations
//! - src/webidl/impls/ - WebIDL implementation files
//! - src/html/ - HTML spec implementations
//! - src/fs/ - File System API
//! - src/html/structured_clone/ - Structured Clone algorithm
//!
//! ## Remaining Items
//!
//! - **environment.zig** - EnvironmentSettingsObject (no full impl yet)
//! - **script_evaluation.zig** - Test utility for simulating script failures
//! - **origin_utils.zig** - Some origin functions not yet in src/url/origin.zig
//!
//! ## Migration Guide
//!
//! | Old Mock | New Implementation |
//! |----------|-------------------|
//! | WorkerGlobalScope | src/webidl/interfaces/WorkerGlobalScope.zig |
//! | WorkerLocation | src/webidl/interfaces/WorkerLocation.zig |
//! | WorkerNavigator | src/webidl/interfaces/WorkerNavigator.zig |
//! | MessagePort | src/webidl/interfaces/MessagePort.zig |
//! | FormData | src/webidl/impls/FormData.zig |
//! | CacheStorage | src/webidl/impls/CacheStorage.zig |
//! | structured_clone | src/html/structured_clone/ |
//! | file_system | src/fs/ |
//!

const std = @import("std");

// === Remaining Mocks ===

/// Environment settings object mock
/// TODO: Implement real EnvironmentSettingsObject per HTML spec
/// Spec: https://html.spec.whatwg.org/#environment-settings-object
pub const environment = @import("environment.zig");

/// Origin utility functions not yet in src/url/origin.zig
/// TODO: Move remaining functions to src/url/origin.zig
pub const origin_utils = @import("origin_utils.zig");

/// Test utility for simulating script evaluation failures
/// Note: This is intentionally a mock for test configurability
pub const script_evaluation = @import("script_evaluation.zig");

// Environment exports for convenience
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

// Script evaluation exports (test utility)
pub const ScriptEvaluator = script_evaluation.ScriptEvaluator;
pub const ScriptType = script_evaluation.ScriptType;
pub const EvaluationResult = script_evaluation.EvaluationResult;

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

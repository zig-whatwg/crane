//! Worker Types
//!
//! Spec: HTML Standard § 10 Web workers
//! https://html.spec.whatwg.org/#workers
//!
//! Core type definitions for Web Workers implementation.

const std = @import("std");
const runtime = @import("runtime");

/// Worker type - classic or module script.
///
/// Spec: HTML Standard § 10.1.3
/// https://html.spec.whatwg.org/#workertype
pub const WorkerType = enum {
    /// Classic script worker (default)
    classic,
    /// Module script worker
    module,

    pub fn fromString(s: []const u8) ?WorkerType {
        if (std.mem.eql(u8, s, "classic")) return .classic;
        if (std.mem.eql(u8, s, "module")) return .module;
        return null;
    }

    pub fn toString(self: WorkerType) []const u8 {
        return switch (self) {
            .classic => "classic",
            .module => "module",
        };
    }
};

/// Request credentials mode for module workers.
///
/// Spec: Fetch Standard § 5.4
/// https://fetch.spec.whatwg.org/#request-credentials-mode
pub const RequestCredentials = enum {
    /// Credentials are never sent (default for cross-origin)
    omit,
    /// Credentials only sent for same-origin requests (default)
    same_origin,
    /// Credentials always sent
    include,

    pub fn fromString(s: []const u8) ?RequestCredentials {
        if (std.mem.eql(u8, s, "omit")) return .omit;
        if (std.mem.eql(u8, s, "same-origin")) return .same_origin;
        if (std.mem.eql(u8, s, "include")) return .include;
        return null;
    }

    pub fn toString(self: RequestCredentials) []const u8 {
        return switch (self) {
            .omit => "omit",
            .same_origin => "same-origin",
            .include => "include",
        };
    }
};

/// Worker options dictionary.
///
/// Spec: HTML Standard § 10.2.3.1
/// https://html.spec.whatwg.org/#workeroptions
pub const WorkerOptions = struct {
    /// Worker script type
    worker_type: WorkerType = .classic,
    /// Credentials mode (only for module workers)
    credentials: RequestCredentials = .same_origin,
    /// Worker name (for debugging)
    name: []const u8 = "",
};

/// Worker state in its lifecycle.
///
/// Based on spec processing model:
/// https://html.spec.whatwg.org/#worker-processing-model
pub const WorkerState = enum {
    /// Worker is being created
    pending,
    /// Worker script is being fetched
    fetching,
    /// Worker script is running
    running,
    /// Worker closing flag is set
    closing,
    /// Worker has terminated
    terminated,
};

/// Worker owner - Document or WorkerGlobalScope.
///
/// Spec: HTML Standard § 10.1.4.1
/// "An event loop has one or more task queues."
pub const WorkerOwner = union(enum) {
    /// Owned by a Document
    document: *anyopaque,
    /// Owned by another WorkerGlobalScope
    worker: *anyopaque,

    pub fn isFullyActive(self: WorkerOwner) bool {
        // TODO: Implement actual check against Document/WorkerGlobalScope
        _ = self;
        return true;
    }
};

/// Worker data for internal tracking.
///
/// Stores all spec-required worker fields.
pub const WorkerData = struct {
    /// Worker URL
    url: ?[]const u8 = null,

    /// Worker type (classic/module)
    worker_type: WorkerType = .classic,

    /// Worker name
    name: []const u8 = "",

    /// Worker credentials (for module workers)
    credentials: RequestCredentials = .same_origin,

    /// Worker state
    state: WorkerState = .pending,

    /// Closing flag
    ///
    /// Spec: HTML Standard § 10.1.4.3
    /// "Each WorkerGlobalScope also has a closing flag"
    closing: bool = false,

    /// Owner set - Documents and WorkerGlobalScopes that own this worker
    ///
    /// Spec: HTML Standard § 10.1.4.1
    /// "A WorkerGlobalScope object has an associated owner set"
    owner_set_count: usize = 0,

    /// Cross-origin isolated capability
    cross_origin_isolated: bool = false,

    /// HTTPS state ("none", "deprecated", "modern")
    https_state: HttpsState = .none,

    /// Module map (for module workers)
    /// TODO: Implement proper module map
    has_module_map: bool = false,

    /// Allocator used
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) WorkerData {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WorkerData) void {
        if (self.url) |url| {
            self.allocator.free(url);
        }
        if (self.name.len > 0) {
            // Name might be borrowed or owned - only free if we allocated
        }
    }

    pub fn setUrl(self: *WorkerData, url: []const u8) !void {
        if (self.url) |old_url| {
            self.allocator.free(old_url);
        }
        self.url = try self.allocator.dupe(u8, url);
    }
};

/// HTTPS state enum.
pub const HttpsState = enum {
    none,
    deprecated,
    modern,
};

/// Error types for worker operations.
pub const WorkerError = error{
    /// Worker script fetch failed
    ScriptFetchFailed,
    /// Worker script parse failed
    ScriptParseFailed,
    /// Worker is not running
    WorkerNotRunning,
    /// Worker is closing
    WorkerClosing,
    /// Worker is terminated
    WorkerTerminated,
    /// Security error (CORS, etc.)
    SecurityError,
    /// Data clone error during message passing
    DataCloneError,
    /// Port is not entangled
    PortNotEntangled,
    /// Invalid URL
    InvalidURL,
    /// Network error
    NetworkError,
    /// Out of memory
    OutOfMemory,
    /// Type error (e.g., importScripts in module worker)
    TypeError,
};

test "WorkerType - fromString" {
    try std.testing.expectEqual(WorkerType.classic, WorkerType.fromString("classic").?);
    try std.testing.expectEqual(WorkerType.module, WorkerType.fromString("module").?);
    try std.testing.expect(WorkerType.fromString("invalid") == null);
}

test "RequestCredentials - fromString" {
    try std.testing.expectEqual(RequestCredentials.omit, RequestCredentials.fromString("omit").?);
    try std.testing.expectEqual(RequestCredentials.same_origin, RequestCredentials.fromString("same-origin").?);
    try std.testing.expectEqual(RequestCredentials.include, RequestCredentials.fromString("include").?);
    try std.testing.expect(RequestCredentials.fromString("invalid") == null);
}

test "WorkerData - init and deinit" {
    const allocator = std.testing.allocator;
    var data = WorkerData.init(allocator);
    defer data.deinit();

    try std.testing.expectEqual(WorkerState.pending, data.state);
    try std.testing.expectEqual(WorkerType.classic, data.worker_type);
    try std.testing.expect(!data.closing);
}

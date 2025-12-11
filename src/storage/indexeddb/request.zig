//! IndexedDB Request Implementation
//!
//! Implements IDBRequest and IDBOpenDBRequest per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#request-api
//!
//! ## Spec Reference
//!
//! Algorithms:
//! - IDBRequest/result: specs/algorithms/IndexedDB-3.json lines 331-343
//! - IDBRequest/error: specs/algorithms/IndexedDB-3.json lines 344-357
//!
//! ## Request Lifecycle
//!
//! 1. Request is created with readyState = "pending"
//! 2. Operation executes asynchronously
//! 3. On completion, readyState = "done", result/error is set
//! 4. "success" or "error" event is fired
//!
//! ## Usage
//!
//! ```zig
//! const request = try store.get(key);
//!
//! // Check if done
//! if (request.ready_state == .done) {
//!     if (request.err) |e| {
//!         // Handle error
//!     } else if (request.result) |result| {
//!         // Use result
//!     }
//! }
//! ```

const std = @import("std");
const IDBError = @import("errors.zig").IDBError;
const IDBKey = @import("key.zig").IDBKey;
const IDBTransaction = @import("transaction.zig").IDBTransaction;

// Forward declarations for types from other modules
pub const IDBDatabase = @import("database.zig").IDBDatabase;
pub const IDBCursor = @import("cursor.zig").IDBCursor;

/// Request ready state
/// https://w3c.github.io/IndexedDB/#idbrequestreadystate
pub const IDBRequestReadyState = enum {
    /// The request is pending
    pending,
    /// The request is complete
    done,
};

/// Request source type
pub const RequestSourceType = enum {
    /// Request from IDBFactory
    factory,
    /// Request from IDBObjectStore
    object_store,
    /// Request from IDBIndex
    index,
    /// Request from IDBCursor
    cursor,
};

/// Request result union
pub const RequestResult = union(enum) {
    /// Undefined result
    undefined: void,
    /// Database connection
    database: *IDBDatabase,
    /// IDB Key
    key: IDBKey,
    /// Record value (serialized)
    value: []const u8,
    /// Cursor
    cursor: *IDBCursor,
    /// Count result
    count: u64,
    /// Array of keys
    keys: []IDBKey,
    /// Array of values
    values: [][]const u8,
};

/// IDBRequest represents an asynchronous operation
/// https://w3c.github.io/IndexedDB/#idbrequest
pub const IDBRequest = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// The ready state of the request
    /// https://w3c.github.io/IndexedDB/#dom-idbrequest-readystate
    ready_state: IDBRequestReadyState,

    /// The result of the request (only valid when done and no error)
    /// https://w3c.github.io/IndexedDB/#dom-idbrequest-result
    result: ?RequestResult,

    /// The error if the request failed
    /// https://w3c.github.io/IndexedDB/#dom-idbrequest-error
    err: ?IDBError,

    /// The source type of the request
    source_type: ?RequestSourceType,

    /// The transaction this request belongs to (null for open requests)
    /// REFACTORED: Was `?*anyopaque` - now properly typed for IDBTransaction
    transaction: ?*IDBTransaction,

    /// Done flag (internal)
    done_flag: bool,

    /// Processed flag (internal)
    processed_flag: bool,

    /// Event handlers
    onsuccess: ?*const fn (*Self) void,
    onerror: ?*const fn (*Self) void,

    /// Initialize a new request
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .ready_state = .pending,
            .result = null,
            .err = null,
            .source_type = null,
            .transaction = null,
            .done_flag = false,
            .processed_flag = false,
            .onsuccess = null,
            .onerror = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        // Result cleanup is handled by specific result types
        _ = self;
    }

    /// Get the result
    /// https://w3c.github.io/IndexedDB/#dom-idbrequest-result
    ///
    /// Algorithm (specs/algorithms/IndexedDB-3.json lines 331-343):
    /// 1. If this's done flag is false, throw InvalidStateError
    /// 2. Return this's result, or undefined if error occurred
    pub fn getResult(self: *Self) IDBError!?RequestResult {
        if (!self.done_flag) {
            return IDBError.InvalidStateError;
        }
        return self.result;
    }

    /// Get the error
    /// https://w3c.github.io/IndexedDB/#dom-idbrequest-error
    ///
    /// Algorithm (specs/algorithms/IndexedDB-3.json lines 344-357):
    /// 1. If this's done flag is false, throw InvalidStateError
    /// 2. Return this's error, or null if no error occurred
    pub fn getError(self: *Self) IDBError!?IDBError {
        if (!self.done_flag) {
            return IDBError.InvalidStateError;
        }
        return self.err;
    }

    /// Mark the request as successful with a result
    pub fn setResult(self: *Self, res: RequestResult) void {
        self.result = res;
        self.err = null;
        self.done_flag = true;
        self.ready_state = .done;

        // Fire success event
        if (self.onsuccess) |handler| {
            handler(self);
        }
    }

    /// Mark the request as failed with an error
    pub fn setError(self: *Self, e: IDBError) void {
        self.result = null;
        self.err = e;
        self.done_flag = true;
        self.ready_state = .done;

        // Fire error event
        if (self.onerror) |handler| {
            handler(self);
        }
    }
};

/// IDBOpenDBRequest is used for open and delete operations
/// https://w3c.github.io/IndexedDB/#idbopendbrequest
pub const IDBOpenDBRequest = struct {
    const Self = @This();

    /// Base request
    base: IDBRequest,

    /// Previous database version
    old_version: u64,

    /// New database version (null for deletion)
    new_version: ?u64,

    /// Event handlers specific to open requests
    onupgradeneeded: ?*const fn (*Self) void,
    onblocked: ?*const fn (*Self) void,

    /// Initialize an open request
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .base = IDBRequest.init(allocator),
            .old_version = 0,
            .new_version = null,
            .onupgradeneeded = null,
            .onblocked = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.base.deinit();
    }

    /// Get the ready state
    pub fn getReadyState(self: *Self) IDBRequestReadyState {
        return self.base.ready_state;
    }

    /// Get the result (IDBDatabase or undefined)
    pub fn getResult(self: *Self) IDBError!?RequestResult {
        return self.base.getResult();
    }

    /// Get the error
    pub fn getError(self: *Self) IDBError!?IDBError {
        return self.base.getError();
    }

    /// Fire upgradeneeded event
    pub fn fireUpgradeneeded(self: *Self) void {
        if (self.onupgradeneeded) |handler| {
            handler(self);
        }
    }

    /// Fire blocked event
    pub fn fireBlocked(self: *Self) void {
        if (self.onblocked) |handler| {
            handler(self);
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBRequest - init" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    try std.testing.expectEqual(IDBRequestReadyState.pending, request.ready_state);
    try std.testing.expect(request.result == null);
    try std.testing.expect(request.err == null);
}

test "IDBRequest - getResult throws when pending" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    const result = request.getResult();
    try std.testing.expectError(IDBError.InvalidStateError, result);
}

test "IDBRequest - getError throws when pending" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    const result = request.getError();
    try std.testing.expectError(IDBError.InvalidStateError, result);
}

test "IDBRequest - setResult" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    request.setResult(.{ .count = 42 });

    try std.testing.expectEqual(IDBRequestReadyState.done, request.ready_state);
    try std.testing.expect(request.err == null);

    const result = try request.getResult();
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(u64, 42), result.?.count);
}

test "IDBRequest - setError" {
    const allocator = std.testing.allocator;

    var request = IDBRequest.init(allocator);
    defer request.deinit();

    request.setError(IDBError.NotFoundError);

    try std.testing.expectEqual(IDBRequestReadyState.done, request.ready_state);
    try std.testing.expect(request.result == null);

    const err = try request.getError();
    try std.testing.expectEqual(IDBError.NotFoundError, err.?);
}

test "IDBOpenDBRequest - init and deinit" {
    const allocator = std.testing.allocator;

    var request = IDBOpenDBRequest.init(allocator);
    defer request.deinit();

    try std.testing.expectEqual(@as(u64, 0), request.old_version);
    try std.testing.expect(request.new_version == null);
}

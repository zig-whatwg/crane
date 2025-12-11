//! IndexedDB WebIDL Type Definitions
//!
//! Provides WebIDL-compatible type definitions for IndexedDB interfaces.
//! These types enable integration with the WebIDL code generation system.
//!
//! ## W3C IDL Source
//!
//! Types are based on specs/idl/IndexedDB.idl from W3C WebIDL definitions.
//!
//! ## Architecture
//!
//! This module bridges the gap between:
//! - Zig implementation types (database.zig, transaction.zig, etc.)
//! - WebIDL interface definitions for JavaScript binding generation
//!
//! ## Interfaces Defined
//!
//! - IDBRequest
//! - IDBOpenDBRequest
//! - IDBVersionChangeEvent
//! - IDBFactory
//! - IDBDatabase
//! - IDBTransaction
//! - IDBObjectStore
//! - IDBIndex
//! - IDBKeyRange
//! - IDBCursor
//! - IDBCursorWithValue
//!
//! ## Usage with Codegen
//!
//! The WebIDL codegen system can use these definitions to generate:
//! - JavaScript bindings
//! - Type converters
//! - Interface wrappers

const std = @import("std");

// Import Zig implementations
const impl = struct {
    pub const IDBRequest = @import("request.zig").IDBRequest;
    pub const IDBOpenDBRequest = @import("request.zig").IDBOpenDBRequest;
    pub const IDBRequestReadyState = @import("request.zig").IDBRequestReadyState;
    pub const IDBDatabase = @import("database.zig").IDBDatabase;
    pub const IDBTransaction = @import("transaction.zig").IDBTransaction;
    pub const IDBTransactionMode = @import("transaction.zig").IDBTransactionMode;
    pub const IDBTransactionState = @import("transaction.zig").IDBTransactionState;
    pub const IDBTransactionDurability = @import("transaction.zig").IDBTransactionDurability;
    pub const IDBObjectStore = @import("object_store.zig").IDBObjectStore;
    pub const IDBIndex = @import("index.zig").IDBIndex;
    pub const IDBCursor = @import("cursor.zig").IDBCursor;
    pub const IDBCursorDirection = @import("cursor.zig").IDBCursorDirection;
    pub const IDBKeyRange = @import("key_range.zig").IDBKeyRange;
    pub const IDBKey = @import("key.zig").IDBKey;
    pub const IDBFactory = @import("factory.zig").IDBFactory;
    pub const IDBVersionChangeEvent = @import("version_change_event.zig").IDBVersionChangeEvent;
    pub const IDBError = @import("errors.zig").IDBError;
};

// ============================================================================
// WebIDL Enum Types
// ============================================================================

/// IDBRequestReadyState enum
/// https://w3c.github.io/IndexedDB/#enumdef-idbrequestreadystate
pub const IDBRequestReadyState = enum {
    pending,
    done,

    pub fn toString(self: IDBRequestReadyState) []const u8 {
        return switch (self) {
            .pending => "pending",
            .done => "done",
        };
    }

    pub fn fromString(str: []const u8) ?IDBRequestReadyState {
        if (std.mem.eql(u8, str, "pending")) return .pending;
        if (std.mem.eql(u8, str, "done")) return .done;
        return null;
    }
};

/// IDBTransactionMode enum
/// https://w3c.github.io/IndexedDB/#enumdef-idbtransactionmode
pub const IDBTransactionMode = enum {
    readonly,
    readwrite,
    versionchange,

    pub fn toString(self: IDBTransactionMode) []const u8 {
        return switch (self) {
            .readonly => "readonly",
            .readwrite => "readwrite",
            .versionchange => "versionchange",
        };
    }

    pub fn fromString(str: []const u8) ?IDBTransactionMode {
        if (std.mem.eql(u8, str, "readonly")) return .readonly;
        if (std.mem.eql(u8, str, "readwrite")) return .readwrite;
        if (std.mem.eql(u8, str, "versionchange")) return .versionchange;
        return null;
    }
};

/// IDBTransactionDurability enum
/// https://w3c.github.io/IndexedDB/#enumdef-idbtransactiondurability
pub const IDBTransactionDurability = enum {
    default,
    strict,
    relaxed,

    pub fn toString(self: IDBTransactionDurability) []const u8 {
        return switch (self) {
            .default => "default",
            .strict => "strict",
            .relaxed => "relaxed",
        };
    }

    pub fn fromString(str: []const u8) ?IDBTransactionDurability {
        if (std.mem.eql(u8, str, "default")) return .default;
        if (std.mem.eql(u8, str, "strict")) return .strict;
        if (std.mem.eql(u8, str, "relaxed")) return .relaxed;
        return null;
    }
};

/// IDBCursorDirection enum
/// https://w3c.github.io/IndexedDB/#enumdef-idbcursordirection
pub const IDBCursorDirection = enum {
    next,
    nextunique,
    prev,
    prevunique,

    pub fn toString(self: IDBCursorDirection) []const u8 {
        return switch (self) {
            .next => "next",
            .nextunique => "nextunique",
            .prev => "prev",
            .prevunique => "prevunique",
        };
    }

    pub fn fromString(str: []const u8) ?IDBCursorDirection {
        if (std.mem.eql(u8, str, "next")) return .next;
        if (std.mem.eql(u8, str, "nextunique")) return .nextunique;
        if (std.mem.eql(u8, str, "prev")) return .prev;
        if (std.mem.eql(u8, str, "prevunique")) return .prevunique;
        return null;
    }
};

// ============================================================================
// WebIDL Dictionary Types
// ============================================================================

/// IDBVersionChangeEventInit dictionary
/// https://w3c.github.io/IndexedDB/#dictdef-idbversionchangeeventinit
pub const IDBVersionChangeEventInit = struct {
    /// Default: 0
    oldVersion: u64 = 0,
    /// Default: null
    newVersion: ?u64 = null,
    /// From EventInit - Default: false
    bubbles: bool = false,
    /// From EventInit - Default: false
    cancelable: bool = false,
};

/// IDBTransactionOptions dictionary
/// https://w3c.github.io/IndexedDB/#dictdef-idbtransactionoptions
pub const IDBTransactionOptions = struct {
    durability: IDBTransactionDurability = .default,
};

/// IDBObjectStoreParameters dictionary
/// https://w3c.github.io/IndexedDB/#dictdef-idbobjectstoreparameters
pub const IDBObjectStoreParameters = struct {
    keyPath: ?KeyPathType = null,
    autoIncrement: bool = false,

    pub const KeyPathType = union(enum) {
        single: []const u8,
        sequence: []const []const u8,
    };
};

/// IDBIndexParameters dictionary
/// https://w3c.github.io/IndexedDB/#dictdef-idbindexparameters
pub const IDBIndexParameters = struct {
    unique: bool = false,
    multiEntry: bool = false,
};

/// IDBGetAllOptions dictionary
/// https://w3c.github.io/IndexedDB/#dictdef-idbgetalloptions
pub const IDBGetAllOptions = struct {
    /// KEEP: anyopaque represents WebIDL 'any' type per spec - can be
    /// IDBKeyRange or any key value. Type erasure is spec-compliant here.
    query: ?*anyopaque = null,
    count: ?u32 = null,
    direction: IDBCursorDirection = .next,
};

/// IDBDatabaseInfo dictionary
/// https://w3c.github.io/IndexedDB/#dictdef-idbdatabaseinfo
pub const IDBDatabaseInfo = struct {
    name: []const u8,
    version: u64,
};

// ============================================================================
// WebIDL Interface Wrappers
// ============================================================================

/// WebIDL wrapper for IDBRequest interface
/// https://w3c.github.io/IndexedDB/#idbrequest
pub const WebIDLIDBRequest = struct {
    const Self = @This();

    /// Underlying Zig implementation
    impl_ptr: *impl.IDBRequest,

    /// Wrap a Zig IDBRequest
    pub fn wrap(request: *impl.IDBRequest) Self {
        return Self{ .impl_ptr = request };
    }

    // -- Attributes --

    /// KEEP: Returns anyopaque because WebIDL 'any' type per spec - result
    /// can be database, cursor, key, value, etc. Type erasure is spec-compliant.
    pub fn result(self: Self) !?*anyopaque {
        const res = try self.impl_ptr.getResult();
        // Convert to any - in real impl would convert to V8 value
        _ = res;
        return null;
    }

    pub fn @"error"(self: Self) !?impl.IDBError {
        return try self.impl_ptr.getError();
    }

    /// KEEP: Returns anyopaque because source can be IDBObjectStore, IDBIndex,
    /// or IDBCursor per WebIDL spec. Type erasure is spec-compliant.
    pub fn source(self: Self) ?*anyopaque {
        // Return source object (store, index, or cursor)
        _ = self;
        return null;
    }

    pub fn transaction(self: Self) ?*impl.IDBTransaction {
        if (self.impl_ptr.transaction) |txn_ptr| {
            return @ptrCast(@alignCast(txn_ptr));
        }
        return null;
    }

    pub fn readyState(self: Self) IDBRequestReadyState {
        return switch (self.impl_ptr.ready_state) {
            .pending => .pending,
            .done => .done,
        };
    }
};

/// WebIDL wrapper for IDBDatabase interface
/// https://w3c.github.io/IndexedDB/#idbdatabase
pub const WebIDLIDBDatabase = struct {
    const Self = @This();

    impl_ptr: *impl.IDBDatabase,

    pub fn wrap(db: *impl.IDBDatabase) Self {
        return Self{ .impl_ptr = db };
    }

    // -- Attributes --

    pub fn name(self: Self) []const u8 {
        return self.impl_ptr.name;
    }

    pub fn version(self: Self) u64 {
        return self.impl_ptr.version;
    }

    pub fn objectStoreNames(self: Self) []const []const u8 {
        // In real impl, would return DOMStringList
        _ = self;
        return &.{};
    }

    // -- Methods --

    pub fn transaction(
        self: Self,
        storeNames: []const []const u8,
        mode: IDBTransactionMode,
        options: IDBTransactionOptions,
    ) !*impl.IDBTransaction {
        _ = options;
        const impl_mode = switch (mode) {
            .readonly => impl.IDBTransactionMode.readonly,
            .readwrite => impl.IDBTransactionMode.readwrite,
            .versionchange => impl.IDBTransactionMode.versionchange,
        };
        return try self.impl_ptr.transaction(storeNames, impl_mode);
    }

    pub fn close(self: Self) void {
        self.impl_ptr.close();
    }

    pub fn createObjectStore(
        self: Self,
        store_name: []const u8,
        options: IDBObjectStoreParameters,
    ) !*impl.IDBObjectStore {
        _ = options;
        return try self.impl_ptr.createObjectStore(store_name, .{});
    }

    pub fn deleteObjectStore(self: Self, store_name: []const u8) !void {
        try self.impl_ptr.deleteObjectStore(store_name);
    }
};

/// WebIDL wrapper for IDBKeyRange interface
/// https://w3c.github.io/IndexedDB/#idbkeyrange
pub const WebIDLIDBKeyRange = struct {
    const Self = @This();

    impl_ptr: *impl.IDBKeyRange,

    pub fn wrap(range: *impl.IDBKeyRange) Self {
        return Self{ .impl_ptr = range };
    }

    // -- Attributes --

    pub fn lower(self: Self) ?impl.IDBKey {
        return self.impl_ptr.lower;
    }

    pub fn upper(self: Self) ?impl.IDBKey {
        return self.impl_ptr.upper;
    }

    pub fn lowerOpen(self: Self) bool {
        return self.impl_ptr.lower_open;
    }

    pub fn upperOpen(self: Self) bool {
        return self.impl_ptr.upper_open;
    }

    // -- Static Methods --

    pub fn only(value: impl.IDBKey) !impl.IDBKeyRange {
        return impl.IDBKeyRange.only(value);
    }

    pub fn lowerBound(lower_val: impl.IDBKey, open: bool) !impl.IDBKeyRange {
        return impl.IDBKeyRange.lowerBound(lower_val, open);
    }

    pub fn upperBound(upper_val: impl.IDBKey, open: bool) !impl.IDBKeyRange {
        return impl.IDBKeyRange.upperBound(upper_val, open);
    }

    pub fn bound(lower_val: impl.IDBKey, upper_val: impl.IDBKey, lowerOpen_: bool, upperOpen_: bool) !impl.IDBKeyRange {
        return impl.IDBKeyRange.bound(lower_val, upper_val, lowerOpen_, upperOpen_);
    }

    // -- Methods --

    pub fn includes(self: Self, key: impl.IDBKey) bool {
        return self.impl_ptr.includes(key);
    }
};

// ============================================================================
// Interface Registry
// ============================================================================

/// Registry of all IndexedDB WebIDL interfaces
pub const InterfaceRegistry = struct {
    /// Interface names in specification order
    pub const interfaces = [_][]const u8{
        "IDBRequest",
        "IDBOpenDBRequest",
        "IDBVersionChangeEvent",
        "IDBFactory",
        "IDBDatabase",
        "IDBObjectStore",
        "IDBIndex",
        "IDBKeyRange",
        "IDBRecord",
        "IDBCursor",
        "IDBCursorWithValue",
        "IDBTransaction",
    };

    /// Enum types
    pub const enums = [_][]const u8{
        "IDBRequestReadyState",
        "IDBTransactionMode",
        "IDBTransactionDurability",
        "IDBCursorDirection",
    };

    /// Dictionary types
    pub const dictionaries = [_][]const u8{
        "IDBVersionChangeEventInit",
        "IDBTransactionOptions",
        "IDBObjectStoreParameters",
        "IDBIndexParameters",
        "IDBGetAllOptions",
        "IDBDatabaseInfo",
    };

    /// Check if a name is a known interface
    pub fn isInterface(name: []const u8) bool {
        for (interfaces) |iface| {
            if (std.mem.eql(u8, iface, name)) return true;
        }
        return false;
    }

    /// Check if a name is a known enum
    pub fn isEnum(name: []const u8) bool {
        for (enums) |e| {
            if (std.mem.eql(u8, e, name)) return true;
        }
        return false;
    }

    /// Check if a name is a known dictionary
    pub fn isDictionary(name: []const u8) bool {
        for (dictionaries) |d| {
            if (std.mem.eql(u8, d, name)) return true;
        }
        return false;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBRequestReadyState - toString" {
    try std.testing.expectEqualStrings("pending", IDBRequestReadyState.pending.toString());
    try std.testing.expectEqualStrings("done", IDBRequestReadyState.done.toString());
}

test "IDBRequestReadyState - fromString" {
    try std.testing.expectEqual(IDBRequestReadyState.pending, IDBRequestReadyState.fromString("pending").?);
    try std.testing.expectEqual(IDBRequestReadyState.done, IDBRequestReadyState.fromString("done").?);
    try std.testing.expect(IDBRequestReadyState.fromString("invalid") == null);
}

test "IDBTransactionMode - toString" {
    try std.testing.expectEqualStrings("readonly", IDBTransactionMode.readonly.toString());
    try std.testing.expectEqualStrings("readwrite", IDBTransactionMode.readwrite.toString());
    try std.testing.expectEqualStrings("versionchange", IDBTransactionMode.versionchange.toString());
}

test "IDBTransactionMode - fromString" {
    try std.testing.expectEqual(IDBTransactionMode.readonly, IDBTransactionMode.fromString("readonly").?);
    try std.testing.expectEqual(IDBTransactionMode.readwrite, IDBTransactionMode.fromString("readwrite").?);
    try std.testing.expectEqual(IDBTransactionMode.versionchange, IDBTransactionMode.fromString("versionchange").?);
    try std.testing.expect(IDBTransactionMode.fromString("invalid") == null);
}

test "IDBCursorDirection - toString" {
    try std.testing.expectEqualStrings("next", IDBCursorDirection.next.toString());
    try std.testing.expectEqualStrings("nextunique", IDBCursorDirection.nextunique.toString());
    try std.testing.expectEqualStrings("prev", IDBCursorDirection.prev.toString());
    try std.testing.expectEqualStrings("prevunique", IDBCursorDirection.prevunique.toString());
}

test "IDBVersionChangeEventInit - defaults" {
    const init = IDBVersionChangeEventInit{};
    try std.testing.expectEqual(@as(u64, 0), init.oldVersion);
    try std.testing.expect(init.newVersion == null);
    try std.testing.expect(!init.bubbles);
    try std.testing.expect(!init.cancelable);
}

test "IDBTransactionOptions - defaults" {
    const options = IDBTransactionOptions{};
    try std.testing.expectEqual(IDBTransactionDurability.default, options.durability);
}

test "IDBObjectStoreParameters - defaults" {
    const params = IDBObjectStoreParameters{};
    try std.testing.expect(params.keyPath == null);
    try std.testing.expect(!params.autoIncrement);
}

test "IDBIndexParameters - defaults" {
    const params = IDBIndexParameters{};
    try std.testing.expect(!params.unique);
    try std.testing.expect(!params.multiEntry);
}

test "InterfaceRegistry - isInterface" {
    try std.testing.expect(InterfaceRegistry.isInterface("IDBRequest"));
    try std.testing.expect(InterfaceRegistry.isInterface("IDBDatabase"));
    try std.testing.expect(InterfaceRegistry.isInterface("IDBTransaction"));
    try std.testing.expect(!InterfaceRegistry.isInterface("NotAnInterface"));
}

test "InterfaceRegistry - isEnum" {
    try std.testing.expect(InterfaceRegistry.isEnum("IDBRequestReadyState"));
    try std.testing.expect(InterfaceRegistry.isEnum("IDBTransactionMode"));
    try std.testing.expect(!InterfaceRegistry.isEnum("NotAnEnum"));
}

test "InterfaceRegistry - isDictionary" {
    try std.testing.expect(InterfaceRegistry.isDictionary("IDBVersionChangeEventInit"));
    try std.testing.expect(InterfaceRegistry.isDictionary("IDBTransactionOptions"));
    try std.testing.expect(!InterfaceRegistry.isDictionary("NotADictionary"));
}

test "WebIDLIDBRequest - wrap and readyState" {
    const allocator = std.testing.allocator;

    var request = impl.IDBRequest.init(allocator);
    defer request.deinit();

    const webidl_req = WebIDLIDBRequest.wrap(&request);
    try std.testing.expectEqual(IDBRequestReadyState.pending, webidl_req.readyState());

    request.setResult(.{ .count = 42 });
    try std.testing.expectEqual(IDBRequestReadyState.done, webidl_req.readyState());
}

test "WebIDLIDBKeyRange - static methods" {
    const key = impl.IDBKey.number(5);

    const range = try WebIDLIDBKeyRange.only(key);
    try std.testing.expect(!range.lower_open);
    try std.testing.expect(!range.upper_open);
}

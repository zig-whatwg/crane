//! IndexedDB Implementation
//!
//! Implements the W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/
//!
//! ## Spec Reference
//!
//! The algorithms are defined in `specs/algorithms/IndexedDB-3.json`.
//!
//! ## Architecture
//!
//! ```
//! IDBFactory
//!     └── IDBOpenDBRequest
//!         └── IDBDatabase
//!             └── IDBTransaction
//!                 ├── IDBObjectStore
//!                 │   ├── IDBIndex
//!                 │   └── IDBCursor
//!                 └── IDBRequest
//! ```
//!
//! ## Key Components
//!
//! - **IDBFactory**: Entry point for opening/deleting databases
//! - **IDBDatabase**: Represents a database connection
//! - **IDBTransaction**: Groups operations atomically
//! - **IDBObjectStore**: Key-value storage container
//! - **IDBIndex**: Secondary index for efficient queries
//! - **IDBCursor**: Iterator for traversing data
//! - **IDBKeyRange**: Represents a range of keys
//! - **IDBRequest**: Async operation handle
//!
//! ## Usage
//!
//! ```zig
//! const idb = @import("indexeddb");
//!
//! // Open a database
//! var factory = idb.IDBFactory.init(allocator);
//! const request = try factory.open("mydb", 1);
//!
//! // Work with the database
//! const db = request.result.database;
//! const txn = try db.transaction(&.{"store"}, .readwrite);
//! const store = txn.objectStore("store");
//! try store.put(value, key);
//! try txn.commit();
//! ```

const std = @import("std");

// Core types
pub const key = @import("key.zig");
pub const IDBKey = key.IDBKey;
pub const IDBKeyType = key.IDBKeyType;
pub const compareKeys = key.compare;

pub const key_range = @import("key_range.zig");
pub const IDBKeyRange = key_range.IDBKeyRange;

pub const request = @import("request.zig");
pub const IDBRequest = request.IDBRequest;
pub const IDBRequestReadyState = request.IDBRequestReadyState;
pub const IDBOpenDBRequest = request.IDBOpenDBRequest;

pub const factory = @import("factory.zig");
pub const IDBFactory = factory.IDBFactory;
pub const IDBDatabaseInfo = factory.IDBDatabaseInfo;

pub const database = @import("database.zig");
pub const IDBDatabase = database.IDBDatabase;

pub const transaction = @import("transaction.zig");
pub const IDBTransaction = transaction.IDBTransaction;
pub const IDBTransactionMode = transaction.IDBTransactionMode;
pub const IDBTransactionState = transaction.IDBTransactionState;
pub const IDBTransactionDurability = transaction.IDBTransactionDurability;

pub const object_store = @import("object_store.zig");
pub const IDBObjectStore = object_store.IDBObjectStore;

pub const index = @import("index.zig");
pub const IDBIndex = index.IDBIndex;

pub const cursor = @import("cursor.zig");
pub const IDBCursor = cursor.IDBCursor;
pub const IDBCursorWithValue = cursor.IDBCursorWithValue;
pub const IDBCursorDirection = cursor.IDBCursorDirection;

pub const version_change_event = @import("version_change_event.zig");
pub const IDBVersionChangeEvent = version_change_event.IDBVersionChangeEvent;

// Error types
pub const IDBError = @import("errors.zig").IDBError;

test {
    _ = key;
    _ = key_range;
    _ = request;
    _ = factory;
    _ = database;
    _ = transaction;
    _ = object_store;
    _ = index;
    _ = cursor;
    _ = version_change_event;
}

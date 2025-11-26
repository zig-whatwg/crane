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

pub const key_path = @import("key_path.zig");
pub const KeyPath = key_path.KeyPath;
pub const ExtractedValue = key_path.ExtractedValue;
pub const ExtractionResult = key_path.ExtractionResult;
pub const EvaluationResult = key_path.EvaluationResult;
pub const isValidKeyPath = key_path.isValidKeyPath;
pub const isValidIdentifier = key_path.isValidIdentifier;
pub const validateKeyPath = key_path.validateKeyPath;
pub const evaluateKeyPath = key_path.evaluateKeyPath;
pub const extractKey = key_path.extractKey;
pub const checkKeyInjectable = key_path.checkKeyInjectable;

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

pub const index_keygen = @import("index_keygen.zig");
pub const IndexKeyResult = index_keygen.IndexKeyResult;
pub const IndexKeyGenOptions = index_keygen.IndexKeyGenOptions;
pub const generateIndexKey = index_keygen.generateIndexKey;
pub const wouldViolateUnique = index_keygen.wouldViolateUnique;
pub const addIndexEntries = index_keygen.addIndexEntries;
pub const updateIndexesForRecord = index_keygen.updateIndexesForRecord;
pub const removeIndexEntriesForPrimaryKey = index_keygen.removeIndexEntriesForPrimaryKey;

pub const cursor = @import("cursor.zig");
pub const IDBCursor = cursor.IDBCursor;
pub const IDBCursorWithValue = cursor.IDBCursorWithValue;
pub const IDBCursorDirection = cursor.IDBCursorDirection;

pub const version_change_event = @import("version_change_event.zig");
pub const IDBVersionChangeEvent = version_change_event.IDBVersionChangeEvent;

pub const events = @import("events.zig");
pub const IDBEvent = events.IDBEvent;
pub const EventDispatchResult = events.EventDispatchResult;
pub const fireSuccessEvent = events.fireSuccessEvent;
pub const fireErrorEvent = events.fireErrorEvent;
pub const fireVersionChangeEvent = events.fireVersionChangeEvent;
pub const fireBlockedEvent = events.fireBlockedEvent;
pub const fireUpgradeneededEvent = events.fireUpgradeneededEvent;
pub const fireCompleteEvent = events.fireCompleteEvent;
pub const fireAbortEvent = events.fireAbortEvent;

pub const async_operations = @import("async_operations.zig");
pub const OperationType = async_operations.OperationType;
pub const AsyncOperation = async_operations.AsyncOperation;
pub const AsyncOperationQueue = async_operations.AsyncOperationQueue;
pub const IDBPromise = async_operations.IDBPromise;
pub const DatabaseTask = async_operations.DatabaseTask;
pub const DatabaseTaskQueue = async_operations.DatabaseTaskQueue;
pub const resolveRequest = async_operations.resolveRequest;
pub const rejectRequest = async_operations.rejectRequest;

// Error types
pub const IDBError = @import("errors.zig").IDBError;

test {
    _ = key;
    _ = key_range;
    _ = key_path;
    _ = request;
    _ = factory;
    _ = database;
    _ = transaction;
    _ = object_store;
    _ = index;
    _ = index_keygen;
    _ = cursor;
    _ = version_change_event;
    _ = events;
    _ = async_operations;
}

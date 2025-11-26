//! IndexedDB Error Types
//!
//! Defines error types per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#exceptions
//!
//! ## Error Mapping
//!
//! | Error Name | Description |
//! |------------|-------------|
//! | UnknownError | Operation failed for reasons unrelated to the database |
//! | ConstraintError | Mutation operation violated a constraint |
//! | DataError | Data provided does not meet requirements |
//! | TransactionInactiveError | Request placed against inactive transaction |
//! | ReadOnlyError | Mutation attempted in read-only transaction |
//! | VersionError | Attempt to open database with lower version |
//! | NotFoundError | Requested object not found |
//! | InvalidStateError | Object is in invalid state for operation |
//! | InvalidAccessError | Invalid operation for this object |
//! | AbortError | Transaction was aborted |
//! | QuotaExceededError | Storage quota exceeded |
//! | DataCloneError | Data could not be cloned |

const std = @import("std");

/// IndexedDB error types
/// https://w3c.github.io/IndexedDB/#exceptions
pub const IDBError = error{
    /// The operation failed for reasons unrelated to the database itself
    /// and not covered by any other error code.
    UnknownError,

    /// A mutation operation in the transaction failed because a constraint
    /// was not satisfied. For example, an object such as an object store
    /// or index already exists and a request attempted to create a new one.
    ConstraintError,

    /// Data provided to an operation does not meet requirements.
    DataError,

    /// A request was placed against a transaction which is currently not
    /// active, or which is finished.
    TransactionInactiveError,

    /// The mutating operation was attempted in a read-only transaction.
    ReadOnlyError,

    /// An attempt was made to open a database using a lower version than
    /// the existing version.
    VersionError,

    /// The operation failed because the requested database object could
    /// not be found. For example, an object store did not exist but was
    /// being opened.
    NotFoundError,

    /// The object is in an invalid state for the attempted operation.
    InvalidStateError,

    /// The operation is not allowed in this context.
    InvalidAccessError,

    /// A request was aborted, for example through a call to
    /// IDBTransaction.abort().
    AbortError,

    /// The operation failed because there was not enough remaining storage
    /// space, or the storage quota was reached and the user declined to
    /// give more space to the database.
    QuotaExceededError,

    /// The internal structure of an object could not be cloned. This could
    /// happen when attempting to clone a function or a DOM node.
    DataCloneError,

    /// The key or key range provided is invalid.
    InvalidKeyError,

    /// The key path provided is invalid.
    InvalidKeyPathError,

    /// Out of memory
    OutOfMemory,

    /// Type error (e.g., version = 0)
    TypeError,

    /// Security error (e.g., opaque origin)
    SecurityError,
};

/// Convert IDBError to DOMException name
pub fn toDOMExceptionName(err: IDBError) []const u8 {
    return switch (err) {
        error.UnknownError => "UnknownError",
        error.ConstraintError => "ConstraintError",
        error.DataError => "DataError",
        error.TransactionInactiveError => "TransactionInactiveError",
        error.ReadOnlyError => "ReadOnlyError",
        error.VersionError => "VersionError",
        error.NotFoundError => "NotFoundError",
        error.InvalidStateError => "InvalidStateError",
        error.InvalidAccessError => "InvalidAccessError",
        error.AbortError => "AbortError",
        error.QuotaExceededError => "QuotaExceededError",
        error.DataCloneError => "DataCloneError",
        error.InvalidKeyError => "DataError", // Maps to DataError per spec
        error.InvalidKeyPathError => "SyntaxError",
        error.OutOfMemory => "UnknownError",
        error.TypeError => "TypeError",
        error.SecurityError => "SecurityError",
    };
}

/// Convert IDBError to human-readable message
pub fn toMessage(err: IDBError) []const u8 {
    return switch (err) {
        error.UnknownError => "The operation failed for an unknown reason.",
        error.ConstraintError => "A constraint was violated.",
        error.DataError => "The data provided does not meet requirements.",
        error.TransactionInactiveError => "The transaction is not active.",
        error.ReadOnlyError => "A mutation operation was attempted in a read-only transaction.",
        error.VersionError => "The version provided is lower than the existing version.",
        error.NotFoundError => "The requested object was not found.",
        error.InvalidStateError => "The object is in an invalid state.",
        error.InvalidAccessError => "The operation is not allowed in this context.",
        error.AbortError => "The transaction was aborted.",
        error.QuotaExceededError => "The storage quota has been exceeded.",
        error.DataCloneError => "The data could not be cloned.",
        error.InvalidKeyError => "The key provided is invalid.",
        error.InvalidKeyPathError => "The key path provided is invalid.",
        error.OutOfMemory => "Out of memory.",
        error.TypeError => "A type error occurred.",
        error.SecurityError => "A security error occurred.",
    };
}

// ============================================================================
// Tests
// ============================================================================

test "toDOMExceptionName" {
    try std.testing.expectEqualStrings("ConstraintError", toDOMExceptionName(error.ConstraintError));
    try std.testing.expectEqualStrings("DataError", toDOMExceptionName(error.DataError));
    try std.testing.expectEqualStrings("VersionError", toDOMExceptionName(error.VersionError));
}

test "toMessage" {
    const msg = toMessage(error.ConstraintError);
    try std.testing.expect(msg.len > 0);
}

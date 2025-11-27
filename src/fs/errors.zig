//! File System Error Types
//!
//! Spec: https://fs.spec.whatwg.org/#concepts
//!
//! Defines error types for File System API operations as specified
//! in the WHATWG File System Standard.

const std = @import("std");

/// File system access result returned by query/request access algorithms.
/// https://fs.spec.whatwg.org/#file-system-access-result
pub const FileSystemAccessResult = struct {
    /// The permission state from the access check
    permission_state: PermissionState,
    /// Error name if permission was not granted (empty string if granted)
    error_name: ErrorName,

    /// Create a granted access result
    pub fn granted() FileSystemAccessResult {
        return .{
            .permission_state = .granted,
            .error_name = .none,
        };
    }

    /// Create a denied access result with the specified error
    pub fn denied(error_name: ErrorName) FileSystemAccessResult {
        return .{
            .permission_state = .denied,
            .error_name = error_name,
        };
    }

    /// Create a prompt access result (user needs to be asked)
    pub fn prompt() FileSystemAccessResult {
        return .{
            .permission_state = .prompt,
            .error_name = .none,
        };
    }

    /// Check if access was granted
    pub fn isGranted(self: FileSystemAccessResult) bool {
        return self.permission_state == .granted;
    }
};

/// Permission state as defined in the Permissions API.
/// https://w3c.github.io/permissions/#enumdef-permissionstate
pub const PermissionState = enum {
    /// Permission has been granted
    granted,
    /// Permission has been denied
    denied,
    /// User should be prompted for permission
    prompt,

    pub fn toString(self: PermissionState) []const u8 {
        return switch (self) {
            .granted => "granted",
            .denied => "denied",
            .prompt => "prompt",
        };
    }
};

/// Error names for file system operations.
/// These correspond to DOMException names per the spec.
pub const ErrorName = enum {
    /// No error
    none,
    /// The requested file could not be found
    NotFoundError,
    /// The entry type does not match expected type (file vs directory)
    TypeMismatchError,
    /// Invalid modification (e.g., deleting non-empty directory without recursive)
    InvalidModificationError,
    /// Cannot modify due to lock being held
    NoModificationAllowedError,
    /// Operation is not valid in current state
    InvalidStateError,
    /// Operation was aborted
    AbortError,
    /// Storage quota exceeded
    QuotaExceededError,
    /// Security violation (e.g., cross-origin access)
    SecurityError,
    /// Permission denied
    NotAllowedError,
    /// Invalid argument
    TypeError,
    /// Data could not be cloned (serialization error)
    DataCloneError,
    /// Encoding error
    EncodingError,

    pub fn toString(self: ErrorName) []const u8 {
        return switch (self) {
            .none => "",
            .NotFoundError => "NotFoundError",
            .TypeMismatchError => "TypeMismatchError",
            .InvalidModificationError => "InvalidModificationError",
            .NoModificationAllowedError => "NoModificationAllowedError",
            .InvalidStateError => "InvalidStateError",
            .AbortError => "AbortError",
            .QuotaExceededError => "QuotaExceededError",
            .SecurityError => "SecurityError",
            .NotAllowedError => "NotAllowedError",
            .TypeError => "TypeError",
            .DataCloneError => "DataCloneError",
            .EncodingError => "EncodingError",
        };
    }
};

/// File system operation errors.
/// These are Zig errors that map to DOMException error names.
pub const FileSystemError = error{
    /// The requested file or directory could not be found
    NotFound,
    /// The entry type does not match (expected file but got directory or vice versa)
    TypeMismatch,
    /// Invalid modification attempt (e.g., removing non-empty dir without recursive flag)
    InvalidModification,
    /// Cannot modify because a lock is held on the resource
    NoModificationAllowed,
    /// Operation is not valid in the current state
    InvalidState,
    /// Operation was aborted (e.g., by user or security check)
    Aborted,
    /// Storage quota has been exceeded
    QuotaExceeded,
    /// Security restriction prevents the operation
    SecurityViolation,
    /// Permission was denied
    NotAllowed,
    /// Invalid name (empty, contains invalid characters, etc.)
    InvalidName,
    /// Serialization/deserialization error
    DataClone,
    /// Out of memory
    OutOfMemory,
};

/// Convert a FileSystemError to its corresponding ErrorName
pub fn errorToErrorName(err: FileSystemError) ErrorName {
    return switch (err) {
        error.NotFound => .NotFoundError,
        error.TypeMismatch => .TypeMismatchError,
        error.InvalidModification => .InvalidModificationError,
        error.NoModificationAllowed => .NoModificationAllowedError,
        error.InvalidState => .InvalidStateError,
        error.Aborted => .AbortError,
        error.QuotaExceeded => .QuotaExceededError,
        error.SecurityViolation => .SecurityError,
        error.NotAllowed => .NotAllowedError,
        error.InvalidName => .TypeError,
        error.DataClone => .DataCloneError,
        error.OutOfMemory => .NotAllowedError,
    };
}

/// Convert an ErrorName to its corresponding FileSystemError
pub fn errorNameToError(name: ErrorName) ?FileSystemError {
    return switch (name) {
        .none => null,
        .NotFoundError => error.NotFound,
        .TypeMismatchError => error.TypeMismatch,
        .InvalidModificationError => error.InvalidModification,
        .NoModificationAllowedError => error.NoModificationAllowed,
        .InvalidStateError => error.InvalidState,
        .AbortError => error.Aborted,
        .QuotaExceededError => error.QuotaExceeded,
        .SecurityError => error.SecurityViolation,
        .NotAllowedError => error.NotAllowed,
        .TypeError => error.InvalidName,
        .DataCloneError => error.DataClone,
        .EncodingError => error.InvalidState,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "FileSystemAccessResult - granted" {
    const result = FileSystemAccessResult.granted();
    try std.testing.expect(result.isGranted());
    try std.testing.expectEqual(PermissionState.granted, result.permission_state);
    try std.testing.expectEqual(ErrorName.none, result.error_name);
}

test "FileSystemAccessResult - denied" {
    const result = FileSystemAccessResult.denied(.NotAllowedError);
    try std.testing.expect(!result.isGranted());
    try std.testing.expectEqual(PermissionState.denied, result.permission_state);
    try std.testing.expectEqual(ErrorName.NotAllowedError, result.error_name);
}

test "FileSystemAccessResult - prompt" {
    const result = FileSystemAccessResult.prompt();
    try std.testing.expect(!result.isGranted());
    try std.testing.expectEqual(PermissionState.prompt, result.permission_state);
}

test "PermissionState - toString" {
    try std.testing.expectEqualStrings("granted", PermissionState.granted.toString());
    try std.testing.expectEqualStrings("denied", PermissionState.denied.toString());
    try std.testing.expectEqualStrings("prompt", PermissionState.prompt.toString());
}

test "ErrorName - toString" {
    try std.testing.expectEqualStrings("", ErrorName.none.toString());
    try std.testing.expectEqualStrings("NotFoundError", ErrorName.NotFoundError.toString());
    try std.testing.expectEqualStrings("TypeMismatchError", ErrorName.TypeMismatchError.toString());
    try std.testing.expectEqualStrings("NotAllowedError", ErrorName.NotAllowedError.toString());
}

test "errorToErrorName - mapping" {
    try std.testing.expectEqual(ErrorName.NotFoundError, errorToErrorName(error.NotFound));
    try std.testing.expectEqual(ErrorName.TypeMismatchError, errorToErrorName(error.TypeMismatch));
    try std.testing.expectEqual(ErrorName.QuotaExceededError, errorToErrorName(error.QuotaExceeded));
    try std.testing.expectEqual(ErrorName.NotAllowedError, errorToErrorName(error.NotAllowed));
}

test "errorNameToError - mapping" {
    try std.testing.expectEqual(@as(?FileSystemError, null), errorNameToError(.none));
    try std.testing.expectEqual(@as(?FileSystemError, error.NotFound), errorNameToError(.NotFoundError));
    try std.testing.expectEqual(@as(?FileSystemError, error.TypeMismatch), errorNameToError(.TypeMismatchError));
}

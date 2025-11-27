//! WHATWG File System Standard Implementation
//!
//! Spec: https://fs.spec.whatwg.org/
//!
//! This library implements the WHATWG File System Standard, providing
//! file system access APIs for web applications.
//!
//! ## Architecture
//!
//! The implementation is split into several components:
//!
//! - **Locator** (`locator.zig`): File system path and location representation
//! - **Entry** (`entry.zig`): File and directory entry types
//! - **Lock** (`lock.zig`): File locking utilities
//! - **Errors** (`errors.zig`): Error types and access results
//! - **Context** (`context.zig`): File system queue and task scheduling
//! - **Backend** (`backend.zig`): Backend trait for platform abstraction
//!
//! ## Usage
//!
//! This library provides trait interfaces that must be implemented by
//! embedders for their specific platform. No pre-built backends are shipped.
//!
//! ```zig
//! const fs = @import("fs");
//!
//! // Create a file system context
//! var ctx = fs.FileSystemContext.init(allocator);
//! defer ctx.deinit();
//!
//! // Create a locator for a bucket file system root
//! var locator = try fs.FileSystemLocator.bucketRoot(allocator, "bucket:origin");
//! defer locator.deinit();
//!
//! // Check if valid file name
//! const is_valid = fs.isValidFileName("document.txt");
//! ```
//!
//! ## Specification References
//!
//! - WHATWG File System Standard: https://fs.spec.whatwg.org/
//! - File System Access API: https://wicg.github.io/file-system-access/

const std = @import("std");

// Error types
pub const errors = @import("errors.zig");
pub const FileSystemError = errors.FileSystemError;
pub const FileSystemAccessResult = errors.FileSystemAccessResult;
pub const PermissionState = errors.PermissionState;
pub const ErrorName = errors.ErrorName;
pub const errorToErrorName = errors.errorToErrorName;
pub const errorNameToError = errors.errorNameToError;

// Locator types
pub const locator = @import("locator.zig");
pub const FileSystemLocator = locator.FileSystemLocator;
pub const FileSystemPath = locator.FileSystemPath;
pub const FileSystemRoot = locator.FileSystemRoot;
pub const FileSystemHandleKind = locator.FileSystemHandleKind;

// Entry types
pub const entry = @import("entry.zig");
pub const FileEntry = entry.FileEntry;
pub const DirectoryEntry = entry.DirectoryEntry;
pub const Entry = entry.Entry;
pub const LockState = entry.LockState;
pub const LockResult = entry.LockResult;
pub const AccessMode = entry.AccessMode;
pub const AccessAlgorithm = entry.AccessAlgorithm;

// Lock utilities
pub const lock = @import("lock.zig");
pub const FileLockGuard = lock.FileLockGuard;
pub const LockType = lock.LockType;
pub const LockOperationResult = lock.LockOperationResult;
pub const canAcquireLock = lock.canAcquireLock;
pub const describeLockState = lock.describeLockState;

// Context and queue
pub const context = @import("context.zig");
pub const FileSystemContext = context.FileSystemContext;
pub const FileSystemQueue = context.FileSystemQueue;
pub const FileSystemTask = context.FileSystemTask;
pub const TaskPriority = context.TaskPriority;
pub const isValidFileName = context.isValidFileName;
pub const path_separator = context.path_separator;

test {
    std.testing.refAllDecls(@This());
    _ = errors;
    _ = locator;
    _ = entry;
    _ = lock;
    _ = context;
}

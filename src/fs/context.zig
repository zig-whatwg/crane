//! File System Context
//!
//! Spec: https://fs.spec.whatwg.org/#file-system-queue
//!
//! Provides the file system queue and task scheduling infrastructure
//! required by the File System API specification.

const std = @import("std");
const builtin = @import("builtin");

/// Task priority levels for the file system queue.
pub const TaskPriority = enum {
    /// High priority - user-initiated operations
    high,
    /// Normal priority - regular operations
    normal,
    /// Low priority - background operations
    low,
};

/// A task to be executed on the file system queue.
pub const FileSystemTask = struct {
    /// The task function to execute
    execute: *const fn (context: *anyopaque) void,
    /// Context data for the task
    context: *anyopaque,
    /// Priority of this task
    priority: TaskPriority,
};

/// The file system queue for coordinating file system operations.
/// https://fs.spec.whatwg.org/#file-system-queue
///
/// A user agent has an associated file system queue which is the result of
/// starting a new parallel queue. This queue is to be used for all file
/// system operations.
///
/// Note: In a full implementation, this would integrate with the browser's
/// event loop and parallel queue infrastructure. This is a simplified
/// implementation for the library.
pub const FileSystemQueue = struct {
    /// Pending tasks
    tasks: std.ArrayListUnmanaged(FileSystemTask),
    /// Mutex for thread safety
    mutex: std.Thread.Mutex,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new file system queue
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .tasks = .{},
            .mutex = .{},
            .allocator = allocator,
        };
    }

    /// Enqueue a task to the file system queue.
    /// https://fs.spec.whatwg.org/#file-system-queue
    pub fn enqueue(self: *Self, task: FileSystemTask) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.tasks.append(self.allocator, task);
    }

    /// Enqueue steps to be executed on the file system queue.
    /// This is a convenience wrapper for the common pattern in the spec.
    pub fn enqueueSteps(
        self: *Self,
        comptime T: type,
        context: *T,
        comptime execute_fn: fn (*T) void,
    ) !void {
        const wrapper = struct {
            fn execute(ctx: *anyopaque) void {
                const typed_ctx: *T = @ptrCast(@alignCast(ctx));
                execute_fn(typed_ctx);
            }
        };

        try self.enqueue(.{
            .execute = wrapper.execute,
            .context = context,
            .priority = .normal,
        });
    }

    /// Process all pending tasks synchronously.
    /// In a real implementation, this would be handled by the event loop.
    pub fn processAll(self: *Self) void {
        self.mutex.lock();
        const tasks = self.tasks.toOwnedSlice(self.allocator) catch return;
        self.mutex.unlock();
        defer self.allocator.free(tasks);

        for (tasks) |task| {
            task.execute(task.context);
        }
    }

    /// Process one task if available.
    /// Returns true if a task was processed.
    pub fn processOne(self: *Self) bool {
        self.mutex.lock();
        if (self.tasks.items.len == 0) {
            self.mutex.unlock();
            return false;
        }
        const task = self.tasks.orderedRemove(0);
        self.mutex.unlock();

        task.execute(task.context);
        return true;
    }

    /// Get the number of pending tasks
    pub fn pendingCount(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.tasks.items.len;
    }

    /// Check if the queue is empty
    pub fn isEmpty(self: *Self) bool {
        return self.pendingCount() == 0;
    }

    /// Free resources
    pub fn deinit(self: *Self) void {
        self.tasks.deinit(self.allocator);
    }
};

/// File system context holding global state for file system operations.
pub const FileSystemContext = struct {
    /// The file system queue
    queue: FileSystemQueue,
    /// Allocator for this context
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new file system context
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .queue = FileSystemQueue.init(allocator),
            .allocator = allocator,
        };
    }

    /// Enqueue steps to the file system queue.
    /// https://fs.spec.whatwg.org/ - "Enqueue the following steps to the file system queue"
    pub fn enqueueSteps(
        self: *Self,
        comptime T: type,
        context: *T,
        comptime execute_fn: fn (*T) void,
    ) !void {
        try self.queue.enqueueSteps(T, context, execute_fn);
    }

    /// Queue a storage task with the global object.
    /// https://fs.spec.whatwg.org/ - "Queue a storage task with global"
    ///
    /// In a full implementation, this would integrate with the HTML event loop.
    /// For now, it executes the task directly.
    pub fn queueStorageTask(
        self: *Self,
        comptime T: type,
        context: *T,
        comptime execute_fn: fn (*T) void,
    ) !void {
        // In a real implementation, this would queue to the storage task source
        // For now, just enqueue to our queue
        try self.enqueueSteps(T, context, execute_fn);
    }

    /// Process all pending tasks
    pub fn processTasks(self: *Self) void {
        self.queue.processAll();
    }

    /// Free resources
    pub fn deinit(self: *Self) void {
        self.queue.deinit();
    }
};

/// Valid file name check.
/// https://fs.spec.whatwg.org/#valid-file-name
///
/// A valid file name is a string that:
/// - is not an empty string
/// - is not equal to "." or ".."
/// - does not contain '/' or any other character used as path separator
pub fn isValidFileName(file_name: []const u8) bool {
    // Not empty
    if (file_name.len == 0) return false;

    // Not "." or ".."
    if (std.mem.eql(u8, file_name, ".") or std.mem.eql(u8, file_name, "..")) {
        return false;
    }

    // Does not contain path separators
    for (file_name) |c| {
        if (c == '/') return false;
        // Windows path separator (if on Windows platform)
        if (builtin.os.tag == .windows) {
            if (c == '\\') return false;
        }
    }

    return true;
}

/// Platform-specific path separator
pub const path_separator: u8 = if (builtin.os.tag == .windows) '\\' else '/';

// ============================================================================
// Tests
// ============================================================================

test "FileSystemQueue - basic operations" {
    const allocator = std.testing.allocator;
    var queue = FileSystemQueue.init(allocator);
    defer queue.deinit();

    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), queue.pendingCount());
}

test "FileSystemQueue - enqueue and process" {
    const allocator = std.testing.allocator;
    var queue = FileSystemQueue.init(allocator);
    defer queue.deinit();

    var counter: usize = 0;

    const Context = struct {
        counter_ptr: *usize,
    };

    var ctx = Context{ .counter_ptr = &counter };

    try queue.enqueueSteps(Context, &ctx, struct {
        fn execute(c: *Context) void {
            c.counter_ptr.* += 1;
        }
    }.execute);

    try std.testing.expectEqual(@as(usize, 1), queue.pendingCount());

    queue.processAll();

    try std.testing.expectEqual(@as(usize, 0), queue.pendingCount());
    try std.testing.expectEqual(@as(usize, 1), counter);
}

test "FileSystemContext - basic operations" {
    const allocator = std.testing.allocator;
    var ctx = FileSystemContext.init(allocator);
    defer ctx.deinit();

    try std.testing.expect(ctx.queue.isEmpty());
}

test "isValidFileName - valid names" {
    try std.testing.expect(isValidFileName("file.txt"));
    try std.testing.expect(isValidFileName("document"));
    try std.testing.expect(isValidFileName("my file.txt"));
    try std.testing.expect(isValidFileName("..."));
    try std.testing.expect(isValidFileName(".hidden"));
    try std.testing.expect(isValidFileName("file.tar.gz"));
}

test "isValidFileName - invalid names" {
    // Empty string
    try std.testing.expect(!isValidFileName(""));

    // "." and ".."
    try std.testing.expect(!isValidFileName("."));
    try std.testing.expect(!isValidFileName(".."));

    // Contains path separator
    try std.testing.expect(!isValidFileName("path/to/file"));
    try std.testing.expect(!isValidFileName("/file"));
    try std.testing.expect(!isValidFileName("file/"));
}

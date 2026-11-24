//! # Typed callback wrappers
//!
//! SelfContainedWorkCallback keeps a callback and its typed data in one heap
//! block, so a C-style queue that carries only a `?*anyopaque` (a timer's or a
//! thread pool's) gets both back through the trampoline. browser/Context.zig's
//! window timers use it.

const std = @import("std");

// ============================================================================
// Self-Contained Work Callback
// ============================================================================

/// A work callback that stores the callback function and context together.
///
/// This is the recommended pattern for thread pool work items because it
/// ensures the callback and context are always available together.
///
/// ## Example
///
/// ```zig
/// const ComputeContext = struct {
///     input: []const f64,
///     result: f64 = 0,
/// };
///
/// fn computeSum(ctx: *ComputeContext) void {
///     var sum: f64 = 0;
///     for (ctx.input) |v| sum += v;
///     ctx.result = sum;
/// }
///
/// var cb = try SelfContainedWorkCallback(ComputeContext).create(
///     allocator,
///     &computeSum,
///     .{ .input = data },
/// );
///
/// // Submit to thread pool
/// thread_pool.submit(cb.getTrampolineCallback(), cb.eraseForFFI());
///
/// // On completion (from completion callback):
/// const result = cb.getData().result;
/// cb.destroy();
/// ```
pub fn SelfContainedWorkCallback(comptime UserData: type) type {
    return struct {
        const Self = @This();

        /// Embedded user data
        data: UserData,

        /// Callback function pointer
        callback: *const fn (data: *UserData) void,

        /// Allocator for self-destruction
        allocator: std.mem.Allocator,

        /// Create a new self-contained work callback on the heap
        pub fn create(
            allocator: std.mem.Allocator,
            callback: *const fn (data: *UserData) void,
            data: UserData,
        ) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .data = data,
                .callback = callback,
                .allocator = allocator,
            };
            return self;
        }

        /// Destroy the callback wrapper
        pub fn destroy(self: *Self) void {
            self.allocator.destroy(self);
        }

        /// Invoke the callback (does NOT destroy self)
        pub fn invoke(self: *Self) void {
            self.callback(&self.data);
        }

        /// Invoke and destroy (one-shot pattern)
        pub fn invokeAndDestroy(self: *Self) void {
            self.callback(&self.data);
            self.destroy();
        }

        /// Get pointer to embedded data
        pub fn getData(self: *Self) *UserData {
            return &self.data;
        }

        /// Erase type for FFI boundaries (thread pool APIs require *anyopaque).
        ///
        /// KEEP: anyopaque required - thread pool API interop at FFI boundary.
        /// Use with getTrampolineCallback() to pass to C-style work queue APIs.
        /// The trampoline will cast back to *Self and invoke the callback.
        pub fn eraseForFFI(self: *Self) *anyopaque {
            return @ptrCast(self);
        }

        /// Get a static trampoline function for legacy APIs
        pub fn getTrampolineCallback() *const fn (data: ?*anyopaque) void {
            return &trampoline;
        }

        fn trampoline(data: ?*anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(data orelse return));
            self.invoke();
        }
    };
}

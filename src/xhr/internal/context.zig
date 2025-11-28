//! Global Context Abstraction
//!
//! Minimal abstraction for Window/Worker context until HTML Standard is implemented.
//!
//! TODO: Replace with actual HTML Standard Window and Worker implementations
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#realms-settings-objects-global-objects

const std = @import("std");
const runtime = @import("runtime");
const EventLoop = runtime.event_loop;

/// Global context stub
///
/// This is a minimal abstraction that will be replaced when the HTML Standard's
/// Window and Worker objects are implemented.
pub const GlobalContext = struct {
    /// Event loop reference
    event_loop: *EventLoop.Scheduler,

    /// Context type (for sync XHR validation)
    context_type: ContextType,

    pub const ContextType = enum {
        unknown, // Default stub
        window, // TODO: HTML Standard Window
        worker, // TODO: HTML Standard Worker
    };

    /// Create a stub global context
    pub fn init(event_loop: *EventLoop.Scheduler) GlobalContext {
        return .{
            .event_loop = event_loop,
            .context_type = .unknown,
        };
    }

    /// Check if this is a Window context
    ///
    /// TODO: Replace with actual Window type check when HTML Standard implemented
    pub fn isWindow(self: *const GlobalContext) bool {
        // For now, stub returns false
        // When HTML Standard is implemented, this will check:
        // return @TypeOf(self.global_object) == Window;
        return self.context_type == .window;
    }

    /// Check if this is a Worker context
    ///
    /// TODO: Replace with actual Worker type check when HTML Standard implemented
    pub fn isWorker(self: *const GlobalContext) bool {
        // For now, stub returns false
        // When HTML Standard is implemented, this will check:
        // return @TypeOf(self.global_object) == DedicatedWorker or
        //        @TypeOf(self.global_object) == SharedWorker;
        return self.context_type == .worker;
    }

    /// Get the event loop
    pub fn getEventLoop(self: *const GlobalContext) *EventLoop.Scheduler {
        return self.event_loop;
    }
};

test "GlobalContext - stub creation" {
    var event_loop = EventLoop.Scheduler.init();
    const context = GlobalContext.init(&event_loop);

    // Stub should return false for both
    try std.testing.expect(!context.isWindow());
    try std.testing.expect(!context.isWorker());

    // Event loop should be accessible
    try std.testing.expectEqual(&event_loop, context.getEventLoop());
}

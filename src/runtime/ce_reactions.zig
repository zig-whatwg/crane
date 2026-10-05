//! [CEReactions] reaches the HTML owner without importing its implementation.
const Instance = @import("instance.zig").Instance;
const Agent = @import("engine_types.zig").Agent;

/// Borrowed agent-owned state captured before the member can run script.
/// A null agent_state needs no pop. An empty definition set still tracks
/// depth. This never keeps the member's receiver or its realm.
pub const Scope = struct {
    agent: ?*Agent = null,
    agent_state: ?*anyopaque = null,
};

pub const Hooks = struct {
    begin: *const fn (?*Instance) Scope,
    end: *const fn (Scope) void,
};
// process-wide: immutable function pointers installed once before Browsers start; each call resolves its own relevant agent, so threads and Browsers share no reaction state
var hooks: ?Hooks = null;

/// CustomElementRegistry installs this while process_start is .starting.
/// The owner checks that phase before crossing the runtime tier's boundary.
pub fn install(implementation: Hooks) void {
    hooks = implementation;
}

pub fn begin(instance: ?*Instance) Scope {
    return (hooks orelse return .{}).begin(instance);
}

pub fn end(scope: Scope) void {
    if (scope.agent_state == null) return;
    (hooks orelse return).end(scope);
}

test "a reaction scope survives destruction of the original receiver" {
    const testing = @import("std").testing;
    const saved = hooks;
    defer hooks = saved;
    const TestHooks = struct {
        fn enter(instance: ?*Instance) Scope {
            return .{ .agent_state = if (instance) |object| object.state else null };
        }
        fn leave(scope: Scope) void {
            const calls: *usize = @ptrCast(@alignCast(scope.agent_state.?));
            calls.* += 1;
        }
    };
    install(.{ .begin = TestHooks.enter, .end = TestHooks.leave });
    var calls: usize = 0;
    const receiver = try testing.allocator.create(Instance);
    receiver.* = .{ .vtable = undefined, .ctx = undefined, .state = &calls };
    const scope = begin(receiver);
    testing.allocator.destroy(receiver);
    end(scope);
    end(begin(null));
    try testing.expectEqual(@as(usize, 1), calls);
}

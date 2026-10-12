//! Implementation for Comment interface
//! DOM §4.11 - Comment nodes contain arbitrary character data (comments)
//!
//! Inheritance: Comment → CharacterData → Node → EventTarget

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const Comment = interfaces.Comment;

// Parent class implementation
const CharacterDataImpl = @import("CharacterData.zig");
const NodeImpl = @import("Node.zig");

pub const State = Comment.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for Comment
/// Comment doesn't need additional state beyond CharacterData
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = runtime.InstanceRegistry(.comment, InternalState);

/// Comment's own construction steps: the generated chain runs CharacterData's first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;

    // Initialize Comment internal state in global registry
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = InternalState.init(allocator);
}

/// Get Comment's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Comment's own teardown: the generated chain runs CharacterData's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);
}

/// Constructor implementation
/// DOM §4.11 - Comment(data)
/// Creates a new Comment node with the given data
pub fn call_constructor(ctx: runtime.Context, data: webidl.Opt(runtime.DOMString)) !*runtime.Instance {
    const instance = try Comment.init(ctx.allocator, ctx);
    errdefer Comment.deinit(instance);

    // Set the comment data via CharacterData
    const data_slice = if (data.was_passed) data.value.asSlice() else "";
    try CharacterDataImpl.setData(instance, data_slice);

    return instance;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Its states left at its Browser's end (Browser.deinit).
    @import("dom").teardown_sweeps.install(.node_types, &sweepRemaining);
}

/// dom.teardown_sweeps: at its Browser's end, every Comment state still in
/// `scope`'s table - an orphan's no teardown reached - frees what it owns.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    Registry.deinitAllAndClear(scope);
}

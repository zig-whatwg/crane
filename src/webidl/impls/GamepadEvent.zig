//! GamepadEvent's inherited Event construction.
//! Spec: https://w3c.github.io/gamepad/#gamepadevent-interface

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const event_construction = @import("dom").event_construction;
const GamepadEvent = interfaces.GamepadEvent;

pub const State = GamepadEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// No Gamepad-specific owned state until the GAMEPAD holder is implemented.
pub const InternalState = struct {};

/// Borrowed constructor inputs carried through the generated chain.
pub const construction_args = .{ "gamepad_event_type", "gamepad_event_init" };

/// DOM constructor steps 1-2: initialize Event through its owner's hook.
/// The generated parent chain creates Event's part and owns its teardown.
pub fn initOwn(
    instance: *runtime.Instance,
    allocator: std.mem.Allocator,
    comptime StateType: type,
    args: anytype,
) !void {
    _ = allocator;
    _ = StateType;
    if (@hasField(@TypeOf(args), "gamepad_event_type")) {
        const dictionary: dictionaries.GamepadEventInit = if (@hasField(@TypeOf(args), "gamepad_event_init")) args.gamepad_event_init else .{ .base = .{} };
        // Inner event creation steps 2-4: initialized flag, relative high
        // resolution timestamp, and EventInit members. Constructor step 2
        // copies the type. WebKit's GamepadEvent constructors likewise
        // delegate inherited state to Event.
        try event_construction.innerEventCreationSteps(instance, args.gamepad_event_type, event_construction.eventInitFrom(dictionary.base));
        // Step 4 TODO(gamepad holder): retain dictionary.gamepad when the
        // GAMEPAD API and its approved holder are implemented. Never keep
        // the dictionary's borrowed instance pointer without that holder.
    }
}

/// DOM Event constructor steps 1-3, using GamepadEvent as the interface.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.GamepadEventInit)) !*runtime.Instance {
    return GamepadEvent.initWith(ctx.allocator, ctx, .{
        .gamepad_event_type = @"type",
        .gamepad_event_init = eventInitDict.getOrDefault(.{ .base = .{} }),
    });
}

/// Getter for gamepad
pub fn get_gamepad(instance: *runtime.Instance) anyerror!*runtime.Instance {
    // Step 4 TODO(gamepad holder): expose the initialized Gamepad after
    // the GAMEPAD API supplies its lifetime-safe holder.
    _ = instance;
    return error.NotImplemented;
}

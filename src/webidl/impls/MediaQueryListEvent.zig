//! Implementation for MediaQueryListEvent interface (CSSOM View 4.2.1)
//!
//! The event a MediaQueryList fires when its matches state changes, and one
//! script constructs: its media and matches are the event init's.
//!
//! Spec: https://drafts.csswg.org/cssom-view/#the-mediaquerylistevent-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const performance_timeline = @import("dom").performance_timeline;
const MediaQueryListEvent = interfaces.MediaQueryListEvent;

pub const State = MediaQueryListEvent.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Initialize instance: the Event part is set up by the constructor.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    const state = instance.getState(StateType);
    state.own.media = runtime.DOMString.initEmpty();
    state.own.matches = false;
    return instance;
}

/// Deinitialize instance: the media, then the Event part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    state.own.media.deinit(instance.ctx.allocator);
    state.own.media = runtime.DOMString.initEmpty();
    interfaces.Event.deinit(instance);
}

/// new MediaQueryListEvent(type, eventInitDict): DOM's inner event creation
/// steps, each MediaQueryListEventInit member initializing the attribute of
/// its name ("media" defaults to "", "matches" to false).
pub fn call_constructor(ctx: runtime.Context, @"type": typedefs.CSSOMString, eventInitDict: webidl.Opt(dictionaries.MediaQueryListEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &MediaQueryListEvent.vtable, ctx);
    errdefer deinit(instance);
    const state = instance.getState(State);
    const init_dict = if (eventInitDict.was_passed) eventInitDict.value else dictionaries.MediaQueryListEventInit{ .base = .{} };
    // What deinit reads, should anything below fail.
    state.base.own.type = runtime.DOMString.initEmpty();
    state.base.own.type = try @"type".clone(ctx.allocator);
    // DOM inner event creation step 3: relative to the relevant global.
    state.base.own.timeStamp = performance_timeline.now(instance.ctx) orelse 0;
    state.base.own.bubbles = init_dict.base.bubbles orelse false;
    state.base.own.cancelable = init_dict.base.cancelable orelse false;
    state.base.own.composed = init_dict.base.composed orelse false;
    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;
    // Copied: the binding frees the dictionary's strings when the
    // constructor returns.
    if (init_dict.media) |media| state.own.media = try media.clone(ctx.allocator);
    state.own.matches = init_dict.matches orelse false;
    // The inherited Event internal state and its initialized flag: without
    // them dispatchEvent throws InvalidStateError.
    try webidl.utils.initEventBase(&state.base.own, runtime.arenaOf(instance), ctx.allocator);
    return instance;
}

/// Getter for media.
pub fn get_media(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    // The event outlives the call.
    return runtime.DOMString.initInterned(instance.getState(State).own.media.asSlice());
}

/// Getter for matches.
pub fn get_matches(instance: *runtime.Instance) anyerror!bool {
    return instance.getState(State).own.matches;
}

//! Implementation for MediaQueryList interface (CSSOM View 4.2)
//!
//! A MediaQueryList is matchMedia()'s answer: a parsed media query list, the
//! document it is evaluated against, and its matches state. `matches` is
//! evaluated when read, against the document's media environment (the same
//! one style resolution uses: dom.style's `media_values`). The list registers
//! with its document's style engine, which runs CSSOM View's "evaluate media
//! queries and report changes" for the document in each rendering update and
//! asks each list, oldest first, to report its own change
//! (`reportChange`): `change` fires when the matches state differs from the
//! one the last report saw.
//!
//! Stated: Blink keeps a list with `change` listeners alive while its
//! document lives (MediaQueryList::HasPendingActivity); here a list script
//! no longer references can be collected with its listeners, and reports
//! nothing after that. A rendering update runs only while animation frame
//! callbacks are pending (src/browser/Context.zig), so a change is reported
//! at the next such frame.
//!
//! Spec: https://drafts.csswg.org/cssom-view/#the-mediaquerylist-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const css = @import("css");
const dom = @import("dom");
const MediaQueryList = interfaces.MediaQueryList;

const log = std.log.scoped(.css);

pub const State = MediaQueryList.State;

pub const ImplError = error{
    NotImplemented,
};

/// Facts given at construction (matchMedia): the document, and the query's
/// text, parsed here.
pub const construction_args = .{ "media_document", "media_query" };

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The associated document: a raw back link (the document's engine
    /// lists this object, not the other way), with its generation.
    document: *runtime.Instance,
    document_generation: u64,
    /// The associated media query list.
    list: css.media_queries.MediaQueryList,
    /// The associated media: the list, serialized. Owned.
    media: []u8,
    /// The matches state the last report saw (initially the state at
    /// creation).
    reported_matches: bool,

    fn liveDocument(self: *const InternalState) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return null;
        return self.document;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns, installed once, at process start.
pub fn installHooks() void {
    dom.style.hooks.install(.{ .report_media_query_list = &reportChange });
}

/// The construction chain's own step: matchMedia's steps 1-2 - "Let parsed
/// media query list be the result of parsing query", and the list's
/// document.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const document: *runtime.Instance = args.media_document;
    const query: []const u8 = args.media_query;
    var list = try css.media_queries.MediaQueryList.parse(allocator, query);
    errdefer list.deinit();
    var text: std.Io.Writer.Allocating = .init(allocator);
    defer text.deinit();
    list.serialize(&text.writer) catch return error.OutOfMemory;
    const media = try text.toOwnedSlice();
    errdefer allocator.free(media);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{
        .allocator = allocator,
        .document = document,
        .document_generation = runtime.SlabAllocator.generationOf(document),
        .list = list,
        .media = media,
        .reported_matches = false,
    };
    internal.reported_matches = evaluate(internal);
    instance.getState(State).own._internal = internal;
    if (dom.style.engine.engineOf(document)) |engine| engine.addMediaQueryList(instance) catch |err| {
        // The list still answers `matches`; it reports no change.
        log.warn("MediaQueryList not registered for change events: {}", .{err});
    };
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.liveDocument()) |document| {
        if (dom.style.engine.engineOf(document)) |engine| engine.removeMediaQueryList(instance);
    }
    internal.list.deinit();
    internal.allocator.free(internal.media);
    runtime.arenaOf(instance).destroy(InternalState, internal);
    state.own._internal = null;
}

/// The matches state: whether the list matches the state of its document.
/// A document that has gone matches nothing.
fn evaluate(internal: *const InternalState) bool {
    const document = internal.liveDocument() orelse return false;
    const values = dom.style.hooks.mediaValues(document);
    return internal.list.matches(&values);
}

/// CSSOM View 4.2 "evaluate media queries and report changes", step 1.1,
/// for one list: "If target's matches state has changed since the last time
/// these steps were run, fire an event named change at target using
/// MediaQueryListEvent, with its isTrusted attribute initialized to true,
/// its media attribute initialized to target's media, and its matches
/// attribute initialized to target's matches state."
fn reportChange(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    const now = evaluate(internal);
    if (now == internal.reported_matches) return;
    internal.reported_matches = now;
    const event = interfaces.MediaQueryListEvent.call_constructor(
        instance.ctx,
        runtime.DOMString.initInterned("change"),
        webidl.Opt(dictionaries.MediaQueryListEventInit).passed(.{ .base = .{}, .media = runtime.DOMString.initInterned(internal.media), .matches = now }),
    ) catch |err| {
        log.warn("MediaQueryList change event not made: {}", .{err});
        return;
    };
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = dom.fire_event.dispatchTrusted(instance, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// Getter for media: the associated media.
pub fn get_media(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    // The list outlives the call.
    return runtime.DOMString.initInterned(internal.media);
}

/// Getter for matches: the associated matches state.
pub fn get_matches(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return evaluate(internal);
}

/// addListener(callback): "Add an event listener with this and an event
/// listener whose type is change, and callback is callback."
pub fn call_addListener(instance: *runtime.Instance, callback: ??*runtime.CallbackWrapper) anyerror!void {
    try interfaces.EventTarget.call_addEventListener(instance, runtime.DOMString.initInterned("change"), callback, webidl.Opt(runtime.JSValue).notPassed());
}

/// removeListener(callback): "If this's event listener list contains an
/// event listener whose type is change, callback is callback, and capture is
/// false, then remove an event listener with this and that event listener" -
/// removeEventListener with no options, whose capture is false.
pub fn call_removeListener(instance: *runtime.Instance, callback: ??*runtime.CallbackWrapper) anyerror!void {
    try interfaces.EventTarget.call_removeEventListener(instance, runtime.DOMString.initInterned("change"), callback, webidl.Opt(runtime.JSValue).notPassed());
}

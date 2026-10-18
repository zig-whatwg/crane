//! Implementation for MediaList interface (CSSOM 4.4)
//!
//! A MediaList is a view of a collection of media queries: a style sheet's
//! media, or an @media or @import rule's (dom.style.MediaOf, held from
//! construction). Every change goes to the model, which moves its sheet's
//! version: a sheet whose media no longer matches stops applying.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-medialist-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const css = @import("css");
const dom = @import("dom");
const MediaList = interfaces.MediaList;

const MediaQueryList = css.media_queries.MediaQueryList;

pub const State = MediaList.State;

pub const ImplError = error{
    NotImplemented,
};

/// What the list is a view of (its construction argument).
pub const construction_args = .{"media_of"};

pub const InternalState = struct {
    /// Held.
    of: dom.style.MediaOf,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = allocator;
    const of: dom.style.MediaOf = args.media_of;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .of = of };
    switch (of) {
        .sheet => |r| r.ref(),
        .rule => |r| r.ref(),
    }
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    switch (internal.of) {
        .sheet => |r| r.unref(),
        .rule => |r| r.unref(),
    }
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// The collection of media queries now; null for an empty one.
fn listOf(internal: *InternalState) ?*const MediaQueryList {
    return switch (internal.of) {
        .sheet => |record| record.mediaList(),
        .rule => |rule| switch (rule.data) {
            .media => |*m| &m.list,
            .import => |*i| &i.media,
            else => null,
        },
    };
}

/// Replace the collection with the parse of `text`.
fn setList(internal: *InternalState, text: []const u8) !void {
    switch (internal.of) {
        .sheet => |record| try record.setMedia(text),
        .rule => |rule| {
            const target: *MediaQueryList = switch (rule.data) {
                .media => |*m| &m.list,
                .import => |*i| &i.media,
                else => return,
            };
            const parsed = try MediaQueryList.parse(rule.allocator, text);
            target.deinit();
            target.* = parsed;
            if (rule.sheet()) |record| record.changed();
        },
    }
}

fn allocatorOf(internal: *const InternalState) std.mem.Allocator {
    return switch (internal.of) {
        .sheet => |r| r.allocator,
        .rule => |r| r.allocator,
    };
}

/// The serialization of the collection, or of its query at `index`.
fn serialized(allocator: std.mem.Allocator, list: *const MediaQueryList, index: ?usize) ![]u8 {
    var text: std.Io.Writer.Allocating = .init(allocator);
    defer text.deinit();
    if (index) |i| list.serializeAt(i, &text.writer) catch return error.OutOfMemory else list.serialize(&text.writer) catch return error.OutOfMemory;
    return text.toOwnedSlice();
}

/// mediaText getter: "return a serialization of the collection of media
/// queries".
pub fn get_mediaText(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    const list = listOf(internal) orelse return runtime.DOMString.initEmpty();
    const text = try serialized(instance.ctx.allocator, list, null);
    if (text.len == 0) {
        instance.ctx.allocator.free(text);
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initOwned(text);
}

/// mediaText setter: "1. Empty the collection of media queries. 2. If the
/// given value is the empty string, then return. 3. Append all the media
/// queries as a result of parsing the given value to the collection of
/// media queries."
pub fn set_mediaText(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    try setList(internal, value.asSlice());
}

/// length: "the number of media queries in the collection".
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    const list = listOf(internal) orelse return 0;
    return @intCast(list.queries.len);
}

/// item(index): "a serialization of the media query in the collection of
/// media queries given by index, or null, if index is greater than or equal
/// to the number of media queries".
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?typedefs.CSSOMString {
    const internal = getInternal(instance) orelse return null;
    const list = listOf(internal) orelse return null;
    if (index >= list.queries.len) return null;
    return runtime.DOMString.initOwned(try serialized(instance.ctx.allocator, list, index));
}

/// The serializations of the collection's queries, owned.
fn queryTexts(allocator: std.mem.Allocator, internal: *InternalState) !std.ArrayList([]u8) {
    var texts: std.ArrayList([]u8) = .empty;
    errdefer freeTexts(allocator, &texts);
    const list = listOf(internal) orelse return texts;
    for (0..list.queries.len) |i| try texts.append(allocator, try serialized(allocator, list, i));
    return texts;
}

fn freeTexts(allocator: std.mem.Allocator, texts: *std.ArrayList([]u8)) void {
    for (texts.items) |t| allocator.free(t);
    texts.deinit(allocator);
}

/// The one media query `medium` parses as, serialized; null when it is not
/// exactly one ("parse a media query").
fn parseOne(allocator: std.mem.Allocator, medium: []const u8) !?[]u8 {
    var parsed = try MediaQueryList.parse(allocator, medium);
    defer parsed.deinit();
    if (parsed.queries.len != 1) return null;
    return try serialized(allocator, &parsed, 0);
}

fn setTexts(internal: *InternalState, allocator: std.mem.Allocator, texts: []const []u8) !void {
    const joined = try std.mem.join(allocator, ", ", texts);
    defer allocator.free(joined);
    try setList(internal, joined);
}

/// appendMedium(medium): "1. Let m be the result of parsing the given value.
/// 2. If m is null, then return. 3. If comparing m with any of the media
/// queries in the collection of media queries returns true, then return.
/// 4. Append m to the collection of media queries."
pub fn call_appendMedium(instance: *runtime.Instance, medium: typedefs.CSSOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    const allocator = allocatorOf(internal);
    const m = (try parseOne(allocator, medium.asSlice())) orelse return;
    defer allocator.free(m);
    var texts = try queryTexts(allocator, internal);
    defer freeTexts(allocator, &texts);
    // "Compare media queries": their serializations.
    for (texts.items) |t| if (std.mem.eql(u8, t, m)) return;
    try texts.append(allocator, try allocator.dupe(u8, m));
    try setTexts(internal, allocator, texts.items);
}

/// deleteMedium(medium): "1. Let m be the result of parsing the given value.
/// 2. If m is null, then return. 3. Remove any media query from the
/// collection of media queries for which comparing the media query with m
/// returns true. If nothing was removed, then throw a NotFoundError
/// exception."
pub fn call_deleteMedium(instance: *runtime.Instance, medium: typedefs.CSSOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    const allocator = allocatorOf(internal);
    const m = (try parseOne(allocator, medium.asSlice())) orelse return;
    defer allocator.free(m);
    var texts = try queryTexts(allocator, internal);
    defer freeTexts(allocator, &texts);
    var removed = false;
    var i: usize = 0;
    while (i < texts.items.len) {
        if (std.mem.eql(u8, texts.items[i], m)) {
            allocator.free(texts.orderedRemove(i));
            removed = true;
            continue;
        }
        i += 1;
    }
    if (!removed) return error.NotFoundError;
    try setTexts(internal, allocator, texts.items);
}

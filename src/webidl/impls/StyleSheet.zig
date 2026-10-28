//! Implementation for StyleSheet interface (CSSOM 6.1.1)
//!
//! A StyleSheet object - always a CSSStyleSheet - is a view of a CSS style
//! sheet, the style engine's `dom.style.SheetRecord`, which it holds
//! (counted) from construction: a sheet whose owner let it go ("remove a
//! CSS style sheet") stays readable through its object, with no owner node.
//! The record links back to this object for identity; the descendants read
//! the record through dom.style's `sheet_record_of`, which this installs.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-stylesheet-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dom = @import("dom");
const StyleSheet = interfaces.StyleSheet;

pub const State = StyleSheet.State;

pub const ImplError = error{
    NotImplemented,
};

/// The CSS style sheet this object is a view of (its construction argument).
pub const construction_args = .{"sheet_record"};

pub const InternalState = struct {
    /// Held.
    record: *dom.style.SheetRecord,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

fn recordOf(instance: *runtime.Instance) ?*dom.style.SheetRecord {
    const internal = getInternal(instance) orelse return null;
    return internal.record;
}

/// The hooks this type owns, installed once, at process start.
pub fn installHooks() void {
    dom.style.hooks.install(.{ .sheet_record_of = &recordOf });
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = allocator;
    const record: *dom.style.SheetRecord = args.sheet_record;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .record = record };
    record.ref();
    instance.getState(State).own._internal = internal;
}

/// The object goes: it lets its sheet go.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    internal.record.object.clearIf(instance);
    internal.record.unref();
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// "The type attribute must return the type": "text/css".
pub fn get_type(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    _ = instance;
    return runtime.DOMString.initInterned("text/css");
}

/// "The href attribute must return the location."
pub fn get_href(instance: *runtime.Instance) anyerror!?runtime.USVString {
    const record = recordOf(instance) orelse return null;
    const location = record.location orelse return null;
    // The binding frees a returned USVString.
    return try instance.ctx.allocator.dupe(u8, location);
}

/// "The ownerNode attribute must return the owner node."
pub fn get_ownerNode(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    const record = recordOf(instance) orelse return null;
    const owner = record.owner_node orelse return null;
    return runtime.JSValue{ .instance = owner };
}

/// "The parentStyleSheet attribute must return the parent CSS style sheet."
pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const record = recordOf(instance) orelse return null;
    const parent = record.parentSheet() orelse return null;
    return try dom.style.objects.sheetObject(parent, instance.ctx);
}

/// "The title attribute must return the title or null if title is the
/// empty string."
pub fn get_title(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const record = recordOf(instance) orelse return null;
    if (record.title.len == 0) return null;
    return runtime.DOMString.initInterned(record.title);
}

/// "The media attribute must return the media" ([SameObject]): a MediaList
/// over the sheet's media.
pub fn get_media(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const record = recordOf(instance) orelse return error.InvalidStateError;
    // CSSOM 6.4.4: the import rule and its associated sheet expose one media
    // object. User ruling, 2026-10-27 (liaison Q79, tmp/probe-q79/): follow
    // Firefox 158's shared identity and writes; Chrome 156 and Safari 27
    // returned separate objects with an empty sheet view in both getter orders.
    // Blink fixed this in 2870b09ab93d. The generated [SameObject] accessors
    // retain the shared view through the rule's accessor.
    if (record.owner_rule) |rule| {
        const owner = try dom.style.objects.ruleObject(rule, instance.ctx);
        return interfaces.CSSImportRule.get_media(owner);
    }
    return interfaces.MediaList.initWith(instance.ctx.allocator, instance.ctx, .{ .media_of = dom.style.MediaOf{ .sheet = record } });
}

/// "The disabled attribute, on getting, must return true if the disabled
/// flag is set, or false otherwise."
pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
    const record = recordOf(instance) orelse return false;
    return record.disabled;
}

/// "On setting, the disabled attribute must set the disabled flag if the
/// new value is true, or unset the disabled flag otherwise."
pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
    const record = recordOf(instance) orelse return;
    if (record.disabled == value) return;
    record.disabled = value;
    record.changed();
}

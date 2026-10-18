//! Implementation for StyleSheetList interface (CSSOM 6.2.2)
//!
//! document.styleSheets and shadowRoot.styleSheets: a live collection of
//! the "document or shadow root CSS style sheets" of its scope - a Document
//! or a ShadowRoot, given at construction and linked back to (the scope
//! keeps this list, [SameObject]) - read from the style engine on each
//! access (dom.style.scopeSheets). Each sheet is handed out as its
//! CSSStyleSheet object, which its owner element keeps.
//!
//! Spec: https://drafts.csswg.org/cssom-1/#the-stylesheetlist-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const StyleSheetList = interfaces.StyleSheetList;

pub const State = StyleSheetList.State;

pub const ImplError = error{
    NotImplemented,
};

/// The Document or ShadowRoot whose sheets are listed (its construction
/// argument).
pub const construction_args = .{"sheets_of"};

pub const InternalState = struct {
    /// A raw back link (the scope keeps this list) with its generation.
    scope: *runtime.Instance,
    scope_generation: u64,

    fn liveScope(self: *const InternalState) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.scope) != self.scope_generation) return null;
        return self.scope;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = allocator;
    const scope: *runtime.Instance = args.sheets_of;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .scope = scope, .scope_generation = runtime.SlabAllocator.generationOf(scope) };
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// Getter for length: "the number of CSS style sheets represented by the
/// collection".
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    const scope = internal.liveScope() orelse return 0;
    const allocator = instance.ctx.allocator;
    var sheets: std.ArrayList(*dom.style.SheetRecord) = .empty;
    defer sheets.deinit(allocator);
    try dom.style.scopeSheets(scope, &sheets, allocator);
    return @intCast(sheets.items.len);
}

/// item(index), and the indexed getter: "the indexth CSS style sheet in the
/// collection. If there is no indexth object in the collection, then the
/// method must return null."
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const scope = internal.liveScope() orelse return null;
    const allocator = instance.ctx.allocator;
    var sheets: std.ArrayList(*dom.style.SheetRecord) = .empty;
    defer sheets.deinit(allocator);
    try dom.style.scopeSheets(scope, &sheets, allocator);
    if (index >= sheets.items.len) return null;
    const record = sheets.items[index];
    const realm = if (record.owner_node) |owner| owner.ctx else instance.ctx;
    return try dom.style.objects.sheetObject(record, realm);
}

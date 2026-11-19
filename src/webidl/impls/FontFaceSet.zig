//! CSS Font Loading 3 §3: ordered membership and loading state.
//! The generated EventTarget chain owns event handlers and dispatch state.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const webidl = @import("webidl");
const dom = @import("dom");
const fonts = dom.style.engine.resource_loading.font_loading;

pub const State = interfaces.FontFaceSet.State;
pub const ImplError = error{ NotImplemented, InvalidStateError, InvalidModificationError, SyntaxError };
pub const InternalState = fonts.Set;
pub const construction_args = .{"font_document"};
const Registry = runtime.InstanceRegistry(.font_face_set, InternalState);

pub fn installHooks() void {
    dom.style.hooks.install(.{ .font_set_of = fontSetOf });
    dom.orphan_states.installRegistrySweep(Registry);
    dom.document_fetches.install(.{ .discard = discardRealm });
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    instance.getState(StateType).own._internal = null;
    // Q16: the BrowserScope registry is window-thread-only. A worker's set
    // (Font Loading 3 §4.1, "Worker FontFaceSources": no document, its set
    // entries what script adds) is the object's own, made and freed on the
    // worker's thread.
    if (!instance.ctx.isWindow()) {
        // A realm with no engine (a test's bare context) has no promise to
        // make: no state, as before.
        if (!instance.ctx.hasEngine()) return;
        const internal = try allocator.create(InternalState);
        internal.* = fonts.Set.init(instance, null);
        instance.getState(StateType).own._internal = internal;
        errdefer {
            internal.deinit();
            allocator.destroy(internal);
            instance.getState(StateType).own._internal = null;
        }
        try internal.ready.ensure(instance);
        return;
    }
    const document: ?*runtime.Instance = if (@hasField(@TypeOf(args), "font_document")) args.font_document else null;
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = fonts.Set.init(instance, document);
    instance.getState(StateType).own._internal = internal;
    errdefer {
        internal.deinit();
        Registry.remove(instance);
        instance.getState(StateType).own._internal = null;
    }
    try internal.ready.ensure(instance);
    internal.environmentChanged();
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    if (!instance.ctx.isWindow()) {
        const state = instance.stateAs(State) orelse return;
        const internal = state.own._internal orelse return;
        state.own._internal = null;
        const allocator = internal.allocator;
        internal.deinit();
        allocator.destroy(internal);
        return;
    }
    if (Registry.get(instance)) |internal| internal.deinit();
    if (instance.stateAs(State)) |state| state.own._internal = null;
    Registry.remove(instance);
}

fn fontSetOf(instance: *runtime.Instance) ?*fonts.Set {
    if (!instance.ctx.isWindow()) {
        const state = instance.stateAs(State) orelse return null;
        return state.own._internal;
    }
    return Registry.get(instance);
}

fn setOf(instance: *runtime.Instance) !*fonts.Set {
    const set = fontSetOf(instance) orelse return error.InvalidStateError;
    try set.reconcile();
    return set;
}

pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const set = try setOf(instance);
    try fonts.flushSettledReady(set);
    return (try set.ready.get(instance)).take();
}

pub fn get_status(instance: *runtime.Instance) anyerror!enums.FontFaceSetLoadStatus {
    return switch ((try setOf(instance)).status) {
        .loading => ._loading_,
        .loaded => ._loaded_,
    };
}

/// WebIDL 2.5.12: the set entries the binding's setlike members (size, has,
/// forEach, keys, values, entries, the iterator) read; null once the set is
/// gone.
pub fn setlikeEntries(instance: *runtime.Instance) ?*webidl.setlike.PlatformObjects {
    const set = fontSetOf(instance) orelse return null;
    return set.setlikeView();
}

pub fn call_add(instance: *runtime.Instance, font: *runtime.Instance) anyerror!*runtime.Instance {
    try (try setOf(instance)).add(font);
    return instance;
}

pub fn call_delete(instance: *runtime.Instance, font: *runtime.Instance) anyerror!bool {
    return (try setOf(instance)).remove(font);
}

pub fn call_clear(instance: *runtime.Instance) anyerror!void {
    (try setOf(instance)).clear();
}

/// Font Loading3 §3.2: parse, match and wait for every selected face.
pub fn call_load(instance: *runtime.Instance, font: typedefs.CSSOMString, text: webidl.Opt(typedefs.CSSOMString)) anyerror!runtime.JSValue {
    const set = try setOf(instance);
    return (try set.load(font.asSlice(), if (text.was_passed) text.value.asSlice() else " ")).take();
}

/// Font Loading 3 §3.3: whether the font list renders `text` without any
/// unloaded or loading face; starts no load. A syntax error throws.
pub fn call_check(instance: *runtime.Instance, font: typedefs.CSSOMString, text: webidl.Opt(typedefs.CSSOMString)) anyerror!bool {
    const set = try setOf(instance);
    return set.check(font.asSlice(), if (text.was_passed) text.value.asSlice() else " ");
}

fn discardRealm(realm: runtime.Context) void {
    if (!realm.isWindow()) return;
    var iterator = Registry.iterator(realm.browserScope() orelse return) orelse return;
    while (iterator.next()) |entry| if (entry.internal.realm == realm) {
        entry.internal.discard();
    };
}

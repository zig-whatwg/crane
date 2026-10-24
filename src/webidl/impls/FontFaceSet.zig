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
pub const ImplError = error{ NotImplemented, InvalidStateError, InvalidModificationError };
pub const InternalState = fonts.Set;
pub const construction_args = .{"font_document"};
const Registry = runtime.InstanceRegistry(.font_face_set, InternalState);

pub fn installHooks() void {
    dom.style.hooks.install(.{ .font_set_of = fontSetOf });
    dom.orphan_states.installRegistrySweep(Registry);
    dom.document_fetches.install(.{ .discard = discardRealm });
}

pub fn initOwn(instance: *runtime.Instance, _: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    instance.getState(StateType).own._internal = null;
    // Q16: the BrowserScope registry is window-thread-only. Worker font
    // sources are a separately assigned capability and do not enter it.
    if (!instance.ctx.isWindow()) return;
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
    if (!instance.ctx.isWindow()) return;
    if (Registry.get(instance)) |internal| internal.deinit();
    if (instance.stateAs(State)) |state| state.own._internal = null;
    Registry.remove(instance);
}

fn fontSetOf(instance: *runtime.Instance) ?*fonts.Set {
    if (!instance.ctx.isWindow()) return null;
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

pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
    return @intCast((try setOf(instance)).members.items.len);
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

// Font shorthand matching awaits row119's typed request helper (Q39).
pub fn call_load(_: *runtime.Instance, _: typedefs.CSSOMString, _: webidl.Opt(typedefs.CSSOMString)) anyerror!runtime.JSValue {
    return error.NotImplemented;
}

pub fn call_check(_: *runtime.Instance, _: typedefs.CSSOMString, _: webidl.Opt(typedefs.CSSOMString)) anyerror!bool {
    return error.NotImplemented;
}

fn discardRealm(realm: runtime.Context) void {
    if (!realm.isWindow()) return;
    var iterator = Registry.iterator(realm.browserScope() orelse return) orelse return;
    while (iterator.next()) |entry| if (entry.internal.realm == realm) {
        entry.internal.discard();
    };
}

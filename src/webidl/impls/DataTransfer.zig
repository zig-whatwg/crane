//! Implementation for DataTransfer interface
//!
//! Spec: HTML 6.11.3 The DataTransfer interface
//! https://html.spec.whatwg.org/multipage/dnd.html#the-datatransfer-interface
//!
//! ```idl
//! [Exposed=Window]
//! interface DataTransfer {
//!   constructor();
//!   attribute DOMString dropEffect;
//!   attribute DOMString effectAllowed;
//!   [SameObject] readonly attribute DataTransferItemList items;
//!   undefined setDragImage(Element image, long x, long y);
//!   /* old interface */
//!   readonly attribute FrozenArray<DOMString> types;
//!   DOMString getData(DOMString format);
//!   undefined setData(DOMString format, DOMString data);
//!   undefined clearData(optional DOMString format);
//!   [SameObject] readonly attribute FileList files;
//! };
//! ```
//!
//! What script needs to build file lists - `new DataTransfer()`,
//! `items.add(file)`, `files` - and the attributes the constructor sets.
//! Crane has no drag-and-drop operation (rendering and input are the host's),
//! so a DataTransfer is only ever made by its constructor: always associated
//! with its drag data store, in read/write mode.
//!
//! The drag data store (dom.drag_data_store) is this object's own: made in
//! the constructor, freed in deinit. Its item list and its files list are
//! made with it and kept by edges from this object (slots "items" and
//! "files"); each file item's File by an edge too (the store's "item.<id>").
//! The generated getters cache `items` and `files` as [SameObject], and the
//! binding draws the edge back from each to this object, so a list script
//! keeps its DataTransfer - and the store - alive.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const drag_data_store = dom.drag_data_store;
const DataTransfer = interfaces.DataTransfer;

pub const State = DataTransfer.State;

pub const ImplError = error{
    NotImplemented,
};

/// dropEffect's values (6.11.3: "none", "copy", "link", "move").
const drop_effects = [_][]const u8{ "none", "copy", "link", "move" };
/// effectAllowed's values.
const allowed_effects = [_][]const u8{ "none", "copy", "copyLink", "copyMove", "link", "linkMove", "move", "all", "uninitialized" };

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    store: *drag_data_store.Store,
    /// The DataTransferItemList and FileList made with the store. With an
    /// engine, the edges from this object own them (their wrappers do);
    /// without one (engine-free tests), this object frees them.
    items: *runtime.Instance,
    files: *runtime.Instance,
    traced: bool,
    /// Static strings: an entry of drop_effects / allowed_effects.
    drop_effect: []const u8 = "none",
    effect_allowed: []const u8 = "none",
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: the store, and - engine-free - the children this
/// object made. With an engine the children are their wrappers', and the
/// edges to them went with this object's wrapper (or, for one freed
/// unwrapped, are let go here).
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    internal.store.destroy();
    if (internal.traced) {
        engine.forgetTracedChild(instance, .{ .name = "items" });
        engine.forgetTracedChild(instance, .{ .name = "files" });
    } else {
        runtime.Instance.deinit(internal.items);
        runtime.Instance.deinit(internal.files);
    }
    internal.allocator.destroy(internal);
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// The DataTransfer() constructor: "a newly created DataTransfer object
/// initialized as follows":
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const allocator = ctx.allocator;
    const instance = try init(allocator, State, &DataTransfer.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    // 1. Set the drag data store's item list to be an empty list.
    // 2. Set the drag data store's mode to read/write mode.
    const store = try drag_data_store.Store.create(allocator, instance, .read_write);
    errdefer store.destroy();
    const items = try drag_data_store.makeItemList(instance, store);
    errdefer runtime.Instance.deinit(items);
    const files = try interfaces.FileList.init(allocator, ctx);
    errdefer runtime.Instance.deinit(files);
    const internal = try allocator.create(InternalState);
    // 3. Set the dropEffect and effectAllowed to "none".
    internal.* = .{ .allocator = allocator, .store = store, .items = items, .files = files, .traced = ctx.hasEngine() };
    instance.getState(State).own._internal = internal;
    if (internal.traced) {
        // Held until this object's wrapper exists (the binding caches `this`
        // when the constructor returns), then edges from it.
        engine.traceChild(instance, items, .{ .name = "items" });
        engine.traceChild(instance, files, .{ .name = "files" });
    }
    store.setFiles(files);
    return instance;
}

/// Getter for dropEffect: "On getting, it must return its current value."
pub fn get_dropEffect(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("none");
    return runtime.DOMString.initInterned(internal.drop_effect);
}

/// Setter for dropEffect: "if the new value is one of "none", "copy",
/// "link", or "move", then the attribute's current value must be set to the
/// new value. Other values must be ignored."
pub fn set_dropEffect(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    for (drop_effects) |effect| {
        if (std.mem.eql(u8, effect, value.asSlice())) internal.drop_effect = effect;
    }
}

/// Getter for effectAllowed: "On getting, it must return its current value."
pub fn get_effectAllowed(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initInterned("none");
    return runtime.DOMString.initInterned(internal.effect_allowed);
}

/// Setter for effectAllowed: "if the drag data store's mode is the
/// read/write mode and the new value is one of [...], then the attribute's
/// current value must be set to the new value. Otherwise, it must be left
/// unchanged."
pub fn set_effectAllowed(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const internal = getInternal(instance) orelse return;
    if (internal.store.mode != .read_write) return;
    for (allowed_effects) |effect| {
        if (std.mem.eql(u8, effect, value.asSlice())) internal.effect_allowed = effect;
    }
}

/// Getter for items: "must return a DataTransferItemList object associated
/// with the DataTransfer object" - the one made with it ([SameObject]).
pub fn get_items(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.items;
}

/// Getter for files: "a live FileList sequence consisting of File objects
/// representing the files found by the following steps" - one object, the
/// one made with the store, which rebuilds it in place on every change to
/// the item list ([SameObject]; Blink's DataTransfer::files_, WebKit's
/// m_fileList, Gecko's DataTransferItemList::mFiles: the same live object
/// in all three).
pub fn get_files(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.files;
}

/// Getter for types
pub fn get_types(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getData
pub fn call_getData(instance: *runtime.Instance, format: runtime.DOMString) anyerror!runtime.DOMString {
    _ = instance;
    _ = format;
    return error.NotImplemented;
}

/// Operation: clearData
pub fn call_clearData(instance: *runtime.Instance, format: webidl.Opt(runtime.DOMString)) anyerror!void {
    _ = instance;
    _ = format;
    return error.NotImplemented;
}

/// Operation: setDragImage
pub fn call_setDragImage(instance: *runtime.Instance, image: *runtime.Instance, x: i32, y: i32) anyerror!void {
    _ = instance;
    _ = image;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: setData
pub fn call_setData(instance: *runtime.Instance, format: runtime.DOMString, data: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = format;
    _ = data;
    return error.NotImplemented;
}

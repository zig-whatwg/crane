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
//! `items.add(file)`, `files` - the attributes the constructor sets, and the
//! old interface's types/getData/setData/clearData. Crane has no
//! drag-and-drop operation (rendering and input are the host's); a
//! DataTransfer is made by its constructor, or by the clipboard event steps
//! (Clipboard API "fire a clipboard event", src/html/execcommand/
//! clipboard.zig), which change its store's mode through
//! dom.drag_data_store.storeOf: always associated with its drag data store.
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

/// The drag data store hook (dom.drag_data_store.storeOf): the clipboard
/// event steps (src/html/execcommand/clipboard.zig) set the mode of, fill
/// and read the store of a DataTransfer they made, without this impl.
pub fn installHooks() void {
    drag_data_store.installDataTransfer(.{ .store_of = &storeOfDataTransfer });
}

fn storeOfDataTransfer(instance: *runtime.Instance) ?*drag_data_store.Store {
    const internal = getInternal(instance) orelse return null;
    return internal.store;
}

/// getData, setData and clearData steps 3-4/4-5: the format converted to
/// ASCII lowercase, "text" changed to "text/plain" and "url" to
/// "text/uri-list" (whether it was "url": getData's convert-to-URL).
/// OWNED by `allocator`.
fn normalizedFormat(allocator: std.mem.Allocator, format: []const u8) !struct { format: []u8, url: bool } {
    const lowered = try std.ascii.allocLowerString(allocator, format);
    if (std.mem.eql(u8, lowered, "text")) {
        allocator.free(lowered);
        return .{ .format = try allocator.dupe(u8, "text/plain"), .url = false };
    }
    if (std.mem.eql(u8, lowered, "url")) {
        allocator.free(lowered);
        return .{ .format = try allocator.dupe(u8, "text/uri-list"), .url = true };
    }
    return .{ .format = lowered, .url = false };
}

/// Remove the text item of type `format`, if any, through the item list
/// (its remove(index) also lets go of the item's DataTransferItem, which
/// then reads as disabled). The store is in read/write mode.
fn removeText(internal: *InternalState, format: []const u8) !void {
    const index = internal.store.textIndex(format) orelse return;
    try interfaces.DataTransferItemList.call_remove(internal.items, @intCast(index));
}

/// Getter for types: the types array (HTML 6.11.3): each text item's type
/// string, then "Files" when any item is a file; empty when no longer
/// associated with a drag data store. A new frozen array per read.
/// TODO(datatransfer-types-identity): HTML sets one array when the item
/// list changes, so `types === types` holds between changes; keep it.
pub fn get_types(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const realm = engine.currentRealm() orelse instance.ctx;
    const internal = getInternal(instance) orelse return (try engine.createFrozenArray(realm, &.{})).take();
    const store = internal.store;
    const allocator = instance.ctx.allocator;
    var values: std.ArrayList(runtime.JSValue) = .empty;
    defer values.deinit(allocator);
    // 2.1. Each text item's type string, in order.
    for (store.items.items) |item| {
        if (item.kind == .text) try values.append(allocator, runtime.JSValue.fromStringRef(item.type_string));
    }
    // 2.2. "Files" when any item is a file.
    if (store.hasFiles()) try values.append(allocator, runtime.JSValue.fromStringRef("Files"));
    // 3. A frozen array of L.
    return (try engine.createFrozenArray(realm, values.items)).take();
}

/// Operation: getData(format), HTML 6.11.3.
pub fn call_getData(instance: *runtime.Instance, format: runtime.DOMString) anyerror!runtime.DOMString {
    // 1. Not associated with a drag data store: the empty string.
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    // 2. Protected mode: the empty string.
    if (internal.store.mode == .protected) return runtime.DOMString.initEmpty();
    // 3-6. The format, lowercased; "text" and "url" (convert-to-URL).
    const allocator = instance.ctx.allocator;
    const normalized = try normalizedFormat(allocator, format.asSlice());
    defer allocator.free(normalized.format);
    // 7-8. The data of the text item of that type, or the empty string.
    const data = internal.store.textData(normalized.format) orelse return runtime.DOMString.initEmpty();
    // 9. convert-to-URL: the first URL of the text/uri-list (RFC 2483: one
    //    URI per CRLF-separated line, "#" lines are comments).
    if (normalized.url) {
        var lines = std.mem.tokenizeAny(u8, data, "\r\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;
            return runtime.DOMString.initDupe(allocator, trimmed);
        }
        return runtime.DOMString.initEmpty();
    }
    // 10.
    return runtime.DOMString.initDupe(allocator, data);
}

/// Operation: clearData(format), HTML 6.11.3.
pub fn call_clearData(instance: *runtime.Instance, format: webidl.Opt(runtime.DOMString)) anyerror!void {
    // 1. Not associated with a drag data store: nothing happens.
    const internal = getInternal(instance) orelse return;
    // 2. Not in read/write mode: nothing happens.
    if (internal.store.mode != .read_write) return;
    // 3. No argument: remove every text item.
    if (!format.was_passed) {
        // Clipboard API "fire a clipboard event" step 11.1.
        try internal.store.noteClear(null);
        var index = internal.store.length();
        while (index > 0) {
            index -= 1;
            if (internal.store.items.items[index].kind != .text) continue;
            try interfaces.DataTransferItemList.call_remove(internal.items, @intCast(index));
        }
        return;
    }
    // 4-5. The format, lowercased; "text" and "url".
    const allocator = instance.ctx.allocator;
    const normalized = try normalizedFormat(allocator, format.value.asSlice());
    defer allocator.free(normalized.format);
    try internal.store.noteClear(normalized.format);
    // 6. Remove the text item of that type, if there is one.
    try removeText(internal, normalized.format);
}

/// Operation: setDragImage
pub fn call_setDragImage(instance: *runtime.Instance, image: *runtime.Instance, x: i32, y: i32) anyerror!void {
    _ = instance;
    _ = image;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: setData(format, data), HTML 6.11.3.
pub fn call_setData(instance: *runtime.Instance, format: runtime.DOMString, data: runtime.DOMString) anyerror!void {
    // 1. Not associated with a drag data store: nothing happens.
    const internal = getInternal(instance) orelse return;
    // 2. Not in read/write mode: nothing happens.
    if (internal.store.mode != .read_write) return;
    // 3-4. The format, lowercased; "text" and "url".
    const allocator = instance.ctx.allocator;
    const normalized = try normalizedFormat(allocator, format.asSlice());
    defer allocator.free(normalized.format);
    // 5. Remove the text item of that type, if there is one.
    try removeText(internal, normalized.format);
    // 6. Add a text item of that type with the data.
    _ = try internal.store.addText(data.asSlice(), normalized.format);
    // Clipboard API "fire a clipboard event" step 11.2.
    internal.store.noteSet(normalized.format);
}

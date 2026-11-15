//! HTML 8.9.1.6 "PDF viewing support": MimeTypeArray, navigator.mimeTypes -
//! its relevant global object's "PDF viewer mime type objects".
//!
//! As PluginArray keeps the Window's PDF viewer plugin objects, the Window's
//! one MimeTypeArray ([SameObject] on its one Navigator) makes and keeps its
//! PDF viewer mime type objects - two MimeType objects when the user agent's
//! PDF viewer supported is true, none otherwise - as traced children. A
//! Plugin's item() and namedItem() reach them through the Window's
//! navigator.mimeTypes.
//!
//! Spec: https://html.spec.whatwg.org/multipage/system-state.html#pdf-viewing-support

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const pdf_viewer = @import("html_core").navigator.pdf_viewer;

pub const State = interfaces.MimeTypeArray.State;

pub const ImplError = error{
    NotImplemented,
};

const count = pdf_viewer.mime_types.len;

/// The Window's PDF viewer mime type objects, made on first use.
pub const InternalState = struct {
    mime_types: [count]?*runtime.Instance = @splat(null),
    generations: [count]u64 = @splat(0),
    made: usize = 0,
};

const slot_names = blk: {
    var names: [count][]const u8 = undefined;
    for (0..count) |i| names[i] = std.fmt.comptimePrint("MimeTypeArray:pdf viewer mime type {d}", .{i});
    break :blk names;
};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    _ = args;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    inline for (0..count) |i| {
        if (i < internal.made) engine.forgetTracedChild(instance, .{ .name = slot_names[i] });
    }
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// The Window's PDF viewer mime type objects: two MimeType objects typed by
/// `pdf_viewer.mime_types`, or the empty list when the PDF viewer is not
/// supported. BORROWED.
fn mimeTypeObjects(instance: *runtime.Instance) ![]const ?*runtime.Instance {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    const internal = state.own._internal orelse return error.InvalidStateError;
    const wanted = pdf_viewer.mimeTypesWhen(pdf_viewer.supported()).len;
    while (internal.made < wanted) {
        const index = internal.made;
        const mime_type = try interfaces.MimeType.initWith(instance.ctx.allocator, instance.ctx, .{ .pdf_mime_type_index = @as(u8, @intCast(index)) });
        internal.mime_types[index] = mime_type;
        internal.generations[index] = runtime.SlabAllocator.generationOf(mime_type);
        internal.made += 1;
        // This array keeps it: the same object comes back from item(),
        // namedItem() and a Plugin's item() and namedItem().
        engine.traceChild(instance, mime_type, .{ .name = slot_names[index] });
    }
    return internal.mime_types[0..wanted];
}

fn mimeTypeAt(instance: *runtime.Instance, index: usize) !?*runtime.Instance {
    const mime_types = try mimeTypeObjects(instance);
    if (index >= mime_types.len) return null;
    const mime_type = mime_types[index] orelse return null;
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    if (runtime.SlabAllocator.generationOf(mime_type) != internal.generations[index]) return null;
    return mime_type;
}

/// "The MimeTypeArray interface's length getter steps are to return this's
/// relevant global object's PDF viewer mime type objects's size."
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return @intCast(pdf_viewer.mimeTypesWhen(pdf_viewer.supported()).len);
}

/// item(index): "1. Let mimeTypes be this's relevant global object's PDF
/// viewer mime type objects. 2. If index < mimeTypes's size, then return
/// mimeTypes[index]. 3. Return null." Also the indexed getter.
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    return mimeTypeAt(instance, index);
}

/// namedItem(name): "1. For each MimeType mimeType of this's relevant global
/// object's PDF viewer mime type objects: if mimeType's type is name, then
/// return mimeType. 2. Return null." Also the named getter.
pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?*runtime.Instance {
    const index = pdf_viewer.mimeTypeIndex(pdf_viewer.supported(), name.asSlice()) orelse return null;
    return mimeTypeAt(instance, index);
}

/// "MimeTypeArray interface supports named properties. If the user agent's
/// PDF viewer supported is true, then they are the PDF viewer mime types.
/// Otherwise, they are the empty list."
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    _ = instance;
    const names = pdf_viewer.mimeTypesWhen(pdf_viewer.supported());
    const out = try allocator.alloc(runtime.DOMString, names.len);
    for (out, names) |*slot, name| slot.* = runtime.DOMString.initInterned(name);
    return out;
}

pub fn isSupportedPropertyName(instance: *runtime.Instance, name: runtime.DOMString) anyerror!bool {
    _ = instance;
    return pdf_viewer.mimeTypeIndex(pdf_viewer.supported(), name.asSlice()) != null;
}

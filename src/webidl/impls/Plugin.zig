//! HTML 8.9.1.6 "PDF viewing support": Plugin - one of a Window's five PDF
//! viewer plugin objects (made and kept by its navigator.plugins,
//! PluginArray.zig). "Each Plugin object has a name, which is set when the
//! object is created": the index of its name in the PDF viewer plugin names.
//!
//! Spec: https://html.spec.whatwg.org/multipage/system-state.html#pdf-viewing-support

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const pdf_viewer = @import("html_core").navigator.pdf_viewer;

pub const State = interfaces.Plugin.State;

pub const ImplError = error{
    NotImplemented,
};

/// Its name, as an index into `pdf_viewer.plugin_names`.
pub const InternalState = struct {
    name_index: u8,
};

/// PluginArray makes each with its name's index.
pub const construction_args = .{"pdf_plugin_index"};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    const index: u8 = if (@hasField(@TypeOf(args), "pdf_plugin_index")) args.pdf_plugin_index else 0;
    std.debug.assert(index < pdf_viewer.plugin_names.len);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .name_index = index };
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// "The Plugin interface's name getter steps are to return this's name."
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.stateAs(State) orelse return runtime.DOMString.initEmpty();
    const internal = state.own._internal orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initInterned(pdf_viewer.plugin_names[internal.name_index]);
}

/// "... description getter steps are to return "Portable Document Format"."
pub fn get_description(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned(pdf_viewer.description);
}

/// "... filename getter steps are to return "internal-pdf-viewer"."
pub fn get_filename(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned(pdf_viewer.filename);
}

/// "The Plugin interface's length getter steps are to return this's relevant
/// global object's PDF viewer mime type objects's size."
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return @intCast(pdf_viewer.mimeTypesWhen(pdf_viewer.supported()).len);
}

/// item(index): "1. Let mimeTypes be this's relevant global object's PDF
/// viewer mime type objects. 2. If index < mimeTypes's size, then return
/// mimeTypes[index]. 3. Return null." - the objects navigator.mimeTypes
/// holds. Also the indexed getter.
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    if (index >= pdf_viewer.mimeTypesWhen(pdf_viewer.supported()).len) return null;
    const mime_types = try relevantMimeTypeArray(instance);
    return interfaces.MimeTypeArray.call_item(mime_types, index);
}

/// namedItem(name): "1. For each MimeType mimeType of this's relevant global
/// object's PDF viewer mime type objects: if mimeType's type is name, then
/// return mimeType. 2. Return null." Also the named getter.
pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?*runtime.Instance {
    if (pdf_viewer.mimeTypeIndex(pdf_viewer.supported(), name.asSlice()) == null) return null;
    const mime_types = try relevantMimeTypeArray(instance);
    return interfaces.MimeTypeArray.call_namedItem(mime_types, name);
}

/// "The Plugin interface supports named properties. If the user agent's PDF
/// viewer supported is true, then they are the PDF viewer mime types.
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

/// The MimeTypeArray that holds this's relevant global object's PDF viewer
/// mime type objects: its Window's navigator.mimeTypes ([SameObject]).
fn relevantMimeTypeArray(instance: *runtime.Instance) !*runtime.Instance {
    const record = instance.ctx.getRealm() orelse return error.InvalidStateError;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.InvalidStateError));
    if (window.stateAs(interfaces.Window.State) == null) return error.InvalidStateError;
    const navigator = try interfaces.Window.get_navigator(window);
    return interfaces.Navigator.get_mimeTypes(navigator);
}

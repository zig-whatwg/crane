//! HTML 8.9.1.6 "PDF viewing support": MimeType - one of a Window's two PDF
//! viewer mime type objects (made and kept by its navigator.mimeTypes,
//! MimeTypeArray.zig). "Each MimeType object has a type, which is set when
//! the object is created": the index of its type in the PDF viewer mime types.
//!
//! Spec: https://html.spec.whatwg.org/multipage/system-state.html#pdf-viewing-support

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const pdf_viewer = @import("html_core").navigator.pdf_viewer;

pub const State = interfaces.MimeType.State;

pub const ImplError = error{
    NotImplemented,
};

/// Its type, as an index into `pdf_viewer.mime_types`.
pub const InternalState = struct {
    type_index: u8,
};

/// MimeTypeArray makes each with its type's index.
pub const construction_args = .{"pdf_mime_type_index"};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    const index: u8 = if (@hasField(@TypeOf(args), "pdf_mime_type_index")) args.pdf_mime_type_index else 0;
    std.debug.assert(index < pdf_viewer.mime_types.len);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .type_index = index };
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// "The MimeType interface's type getter steps are to return this's type."
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.stateAs(State) orelse return runtime.DOMString.initEmpty();
    const internal = state.own._internal orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initInterned(pdf_viewer.mime_types[internal.type_index]);
}

/// "... description getter steps are to return "Portable Document Format"."
pub fn get_description(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned(pdf_viewer.description);
}

/// "... suffixes getter steps are to return "pdf"."
pub fn get_suffixes(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned(pdf_viewer.suffixes);
}

/// "The MimeType interface's enabledPlugin getter steps are to return this's
/// relevant global object's PDF viewer plugin objects[0] (i.e., the generic
/// "PDF Viewer" one)" - the object navigator.plugins[0] is. A MimeType exists
/// only while the PDF viewer is supported, so that list is never empty here.
pub fn get_enabledPlugin(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const record = instance.ctx.getRealm() orelse return error.InvalidStateError;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.InvalidStateError));
    if (window.stateAs(interfaces.Window.State) == null) return error.InvalidStateError;
    const navigator = try interfaces.Window.get_navigator(window);
    const plugins = try interfaces.Navigator.get_plugins(navigator);
    return (try interfaces.PluginArray.call_item(plugins, 0)) orelse error.InvalidStateError;
}

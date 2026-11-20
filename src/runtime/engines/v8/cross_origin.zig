//! HTML 7.2.1 cross-origin objects on V8 [cross_origin_objects]: the
//! adapter's Zig half of the access checks and interceptors in
//! v8_wrapper.cpp ("lane: xorigin2").
//!
//! - CrossOriginProperties (7.2.1.3.1), the one table: which members a
//!   cross-origin Window or Location exposes, and - from it - which of the
//!   binding's functions skip WebIDL's "perform a security check"
//!   (`acceptsAnyReceiver`).
//! - The dispatch the C++ half calls: IsPlatformObjectSameOrigin through the
//!   object's realm's WindowRealmOptions.is_platform_object_same_origin
//!   (asked every time, never kept), the SecurityError, the child navigables.
//! - Installing it: on the Window global template and Location's instance
//!   template (both also in the snapshot generator), the process's dispatch,
//!   each isolate's failed-access-check callback, and the external
//!   references of the template callbacks.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const v8 = @import("ffi.zig");
const conv = @import("conversions.zig");
const context_manager = @import("context_manager.zig");
const protocol_realms = @import("protocol_realms.zig");
const V8Interface = @import("interface.zig").V8Interface;

/// Which platform object a template's checks serve (v8_wrapper.cpp's
/// kCrossOriginWindow / kCrossOriginLocation).
pub const Kind = enum(c_int) { window = 0, location = 1 };

/// An entry of CrossOriginProperties (7.2.1.3.1): an attribute with
/// [[NeedsGetter]] / [[NeedsSetter]], or an operation (neither).
pub const Property = struct {
    name: []const u8,
    needs_getter: bool = false,
    needs_setter: bool = false,

    fn isOperation(self: Property) bool {
        return !self.needs_getter and !self.needs_setter;
    }
};

/// CrossOriginProperties(Window), step 3, in its order (CrossOriginOwnPropertyKeys
/// lists them so).
pub const window_properties = [_]Property{
    .{ .name = "window", .needs_getter = true },
    .{ .name = "self", .needs_getter = true },
    .{ .name = "location", .needs_getter = true, .needs_setter = true },
    .{ .name = "close" },
    .{ .name = "closed", .needs_getter = true },
    .{ .name = "focus" },
    .{ .name = "blur" },
    .{ .name = "frames", .needs_getter = true },
    .{ .name = "length", .needs_getter = true },
    .{ .name = "top", .needs_getter = true },
    .{ .name = "opener", .needs_getter = true },
    .{ .name = "parent", .needs_getter = true },
    .{ .name = "postMessage" },
};

/// CrossOriginProperties(Location), step 2.
pub const location_properties = [_]Property{
    .{ .name = "href", .needs_setter = true },
    .{ .name = "replace" },
};

/// The function of a member a binding makes.
pub const Use = enum { operation, getter, setter };

/// Whether interface `iface`'s function for `use` of `js_name` accepts any
/// receiver - skips WebIDL's "perform a security check" (HTML 7.2.1.1).
/// Interfaces a Window or a Location implements (Window, its ancestor
/// EventTarget, Location) check every member's `this` unless HTML's table
/// lists the member for that kind of access (step 2.1). That is the default,
/// which is the safe answer: a member nobody listed is checked. Every other
/// interface's members accept any receiver - a WindowProxy or Location is
/// never one of their platform objects, and their own brand check refuses it
/// with a TypeError, as Blink's bindings do (they check only
/// [CheckSecurity] interfaces).
pub fn acceptsAnyReceiver(comptime iface: []const u8, comptime js_name: []const u8, comptime use: Use) bool {
    @setEvalBranchQuota(100_000);
    const table: []const Property = if (comptime std.mem.eql(u8, iface, "Window"))
        &window_properties
    else if (comptime std.mem.eql(u8, iface, "Location"))
        &location_properties
    else if (comptime std.mem.eql(u8, iface, "EventTarget"))
        &.{}
    else
        return true;
    inline for (table) |property| {
        if (comptime std.mem.eql(u8, property.name, js_name)) {
            return switch (use) {
                .operation => property.isOperation(),
                .getter => property.needs_getter,
                .setter => property.needs_setter,
            };
        }
    }
    return false;
}

/// The property name HTML 7.1.3.3's access report check is told for `use`
/// of member `js_name` of interface `iface` (WindowRealmOptions.
/// report_window_access), or null: Window's CrossOriginProperties members
/// for the uses the table lists - Chromium's make_report_coop_access
/// (bind_gen/interface.py) reports exactly the [CrossOrigin] members, a
/// getter unless it says Setter only - and the opener setter, which
/// Chromium's DOMWindow::setOpenerForBindings reports as "opener".
/// Deviation: a same-origin Window's `self` and `frames` - and `window` too,
/// in a realm restored from the snapshot (context_manager's hydration step
/// 16) - are own data properties whose value is its global
/// (protocol_realms bindWindowToGlobal), not accessors, so no binding runs
/// for their same-origin [[Get]] and only the cross-origin one (this
/// table's members) reports.
pub fn windowAccessProperty(comptime iface: []const u8, comptime js_name: []const u8, comptime use: Use) ?[]const u8 {
    @setEvalBranchQuota(100_000);
    if (comptime !std.mem.eql(u8, iface, "Window")) return null;
    if (comptime use == .setter and std.mem.eql(u8, js_name, "opener")) return "opener";
    inline for (window_properties) |property| {
        if (comptime std.mem.eql(u8, property.name, js_name)) {
            const listed = switch (use) {
                .operation => property.isOperation(),
                .getter => property.needs_getter,
                .setter => property.needs_setter,
            };
            return if (listed) property.name else null;
        }
    }
    return null;
}

/// Whether interface `iface`'s members run WebIDL's security check at all:
/// the interfaces a Window or a Location implements (acceptsAnyReceiver).
pub fn isSecurityChecked(comptime iface: []const u8) bool {
    return std.mem.eql(u8, iface, "Window") or std.mem.eql(u8, iface, "Location") or
        std.mem.eql(u8, iface, "EventTarget");
}

/// WebIDL's "perform a security check" (HTML 7.2.1.1 step 3) for a binding
/// that runs it itself: a Location member (its Proxy hides V8's access check),
/// or an operation whose return type is a promise, whose exception - this
/// SecurityError included - becomes a rejected promise, so
/// V8 must not throw it before the callback (WebIDL 3.7.6; fetch and
/// createImageBitmap with a cross-origin `this`, html/browsers/origin/
/// cross-origin-objects/cross-origin-objects.html). False when `this` is a
/// WindowProxy or Location the current realm - the function's - is not same
/// origin-domain with; true for any other `this`, which the brand check
/// judges.
pub fn receiverIsAccessible(info: *const v8.FunctionCallbackInfo) bool {
    const object = instanceOf(v8.FunctionCallbackInfo.v8_FunctionCallbackInfo_ThisInstance(info)) orelse return true;
    const kind = object.vtable.name;
    if (!std.mem.eql(u8, kind, "Window") and !std.mem.eql(u8, kind, "Location")) return true;
    // The C++ half unwraps the same Proxy layer, with Local handles only.
    // V8 has entered the member function's realm, including borrowed members.
    return v8.v8_FunctionCallbackInfo_ReceiverIsAccessible(info);
}

/// `binding`'s own steps for each entry of `table`, as the C++ half takes
/// them.
fn membersOf(comptime Binding: type, comptime table: []const Property) [table.len]v8.CrossOriginMember {
    @setEvalBranchQuota(20_000);
    var members: [table.len]v8.CrossOriginMember = undefined;
    for (table, 0..) |property, i| {
        members[i] = .{
            .name = property.name.ptr,
            .name_len = property.name.len,
            .method = if (property.isOperation()) Binding.operationCallback(property.name) else null,
            .getter = if (property.needs_getter) Binding.attributeGetterCallback(property.name) else null,
            .setter = if (property.needs_setter) Binding.attributeSetterCallback(property.name) else null,
            .length = if (property.isOperation()) Binding.operationLength(property.name) else 0,
        };
    }
    return members;
}

const window_members = membersOf(V8Interface(interfaces.Window), &window_properties);
const location_members = membersOf(V8Interface(interfaces.Location), &location_properties);

const dispatch: v8.CrossOriginDispatch = .{
    .same_origin = sameOrigin,
    .throw_security_error = throwSecurityError,
    .child_at = context_manager.windowIndexedPropertyGetter,
    .child_count = childCount,
    .child_named = childNamed,
    .window_members = &window_members,
    .window_member_count = window_members.len,
    .location_members = &location_members,
    .location_member_count = location_members.len,
};

/// The process's dispatch, once, at process start (engine.initializeEngine).
pub fn installDispatch() void {
    v8.v8_SetCrossOriginDispatch(&dispatch);
}

/// `isolate`'s failed-access-check callback: a SecurityError in the current
/// realm. Every agent's isolate, when it is made.
pub fn installOnIsolate(isolate: *v8.Isolate) void {
    v8.v8_Isolate_SetCrossOriginFailedAccessCheck(isolate);
}

/// The cross-origin access check and interceptors on a Window global
/// template (its WindowProxy) or Location's instance template - before the
/// template makes an instance, and in the snapshot generator as well.
pub fn installOnTemplate(template: *v8.ObjectTemplate, kind: Kind) void {
    v8.v8_ObjectTemplate_SetCrossOriginAccessCheck(template, @backingInt(kind));
}

/// The template callbacks, as the snapshot's external references.
pub fn registerExternalReferences() void {
    const ext_refs = @import("external_references.zig");
    var refs: [32]usize = undefined;
    const count = v8.v8_CrossOrigin_ExternalReferences(&refs, refs.len);
    std.debug.assert(count <= refs.len);
    for (refs[0..@min(count, refs.len)]) |ref| ext_refs.registerPointer(ref);
}

// ============================================================================
// The dispatch
// ============================================================================

/// The platform object behind a wrapper's internal field, or null for one
/// whose instance went (cleared, or a poisoned slot).
fn instanceOf(ptr: ?*anyopaque) ?*runtime.Instance {
    const p = ptr orelse return null;
    const as_int = @intFromPtr(p);
    if (as_int == 0xaaaaaaaaaaaaaaaa or as_int == 0xdeaddeaddeaddead or
        (as_int & 0xFFFF000000000000) == 0xaaaa000000000000) return null;
    return @ptrCast(@alignCast(p));
}

/// IsPlatformObjectSameOrigin(object) for a current realm that is not the
/// object's (the C++ half answers that one): the object's realm's host,
/// asked now. A realm made without a host check reaches and is reached as a
/// same-origin one; a current realm the context manager does not know is
/// refused.
fn sameOrigin(isolate: *v8.Isolate, current_realm: ?*anyopaque, object_ptr: ?*anyopaque) callconv(.c) bool {
    _ = isolate;
    const object = instanceOf(object_ptr) orelse return true;
    const check = protocol_realms.sameOriginCheckOf(object.ctx) orelse return true;
    const key = current_realm orelse return false;
    const current = context_manager.getByKey(@intFromPtr(key)) orelse return false;
    return check.is_platform_object_same_origin(check.host, current, object);
}

/// Which access a SecurityError refused (v8_wrapper.cpp's
/// kCrossOriginAccess*): the groups of v8::ExceptionContext a message names
/// - a named property's [[Get]], [[GetOwnProperty]] or query; its [[Set]] or
/// [[DefineOwnProperty]]; its [[Delete]]; the same three for an array
/// index; and an access V8's failed-access-check callback reports with no
/// property (unknown).
pub const Access = enum(i32) {
    unknown = 0,
    named_get = 1,
    named_set = 2,
    named_delete = 3,
    indexed_get = 4,
    indexed_set = 5,
    indexed_delete = 6,
    _,
};

/// A SecurityError DOMException, made in the current realm: the realm of
/// the [[Get]], [[Set]] or call that tried the cross-origin access, with
/// the message Chrome gives it (`securityErrorMessage`).
fn throwSecurityError(isolate: *v8.Isolate, kind: i32, access: i32, name: [*]const u8, name_len: usize) callconv(.c) void {
    // Owned: a fresh Global<Context>.
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwError(isolate, "SecurityError");
        return;
    };
    defer v8.v8_Context_Dispose(context);
    var buffer: [1024]u8 = undefined;
    const object: Kind = if (kind == @backingInt(Kind.location)) .location else .window;
    const origin = accessingOrigin(context);
    defer if (origin) |o| o.global.ctx.allocator.free(o.serialized);
    const message = securityErrorMessage(&buffer, object, @fromBackingInt(@intCast(access)), name[0..name_len], if (origin) |o| o.serialized else null);
    conv.throwDOMExceptionFromContext(isolate, context, "SecurityError", message);
}

/// The current realm's origin, serialized (OWNED by its global's realm
/// allocator), or null when the realm has none to tell.
fn accessingOrigin(context: *v8.Context) ?struct { global: *runtime.Instance, serialized: []const u8 } {
    const global = context_manager.globalObjectForContext(context) orelse return null;
    const settings = dom.global_settings.of(global) orelse return null;
    const serialized = settings.origin(global) catch return null;
    return .{ .global = global, .serialized = serialized };
}

/// A cross-origin SecurityError's message, in Chrome's words (the user's
/// Chrome-compatible choice for UA-defined text, as navigator.vendor; main,
/// 2026-11-20 1:10 PM ET): the context Blink's bindings add for the access -
/// "Failed to read a named property 'href' from 'Location': " - before the
/// detail its DOMWindow gives a script - "Blocked a frame with origin
/// "<origin>" from accessing a cross-origin frame." HTML leaves the text to
/// the user agent; html/browsers/browsing-the-web/navigating-across-documents/
/// grandparent_location_aboutsrcdoc.sub.window.js compares it whole
/// (wpt#65241). With no origin to name (a realm with no settings) the detail
/// is the exception's name, as before.
///
/// The strings are reproduced from Chromium (BSD-3-Clause; credited in
/// THIRD_PARTY_NOTICES.md), revision 671d6af90da4ab79e89cabbd7220cae70025cc11:
/// third_party/blink/renderer/platform/bindings/exception_messages.cc
/// (ExceptionMessages::AddContextToMessage, FailedToGetNamed, FailedToSetNamed,
/// FailedToDeleteNamed, FailedToGetIndexed, FailedToSetIndexed,
/// FailedToDeleteIndexed, OptionalNameProperty, OptionalIndexProperty;
/// Copyright (C) 2013 Google Inc. All rights reserved.) and
/// third_party/blink/renderer/core/frame/dom_window.cc
/// (DOMWindow::SanitizedCrossDomainAccessErrorMessage; Copyright 2014 The
/// Chromium Authors).
pub fn securityErrorMessage(buffer: []u8, object: Kind, access: Access, name: []const u8, origin: ?[]const u8) []const u8 {
    const interface = switch (object) {
        .window => "Window",
        .location => "Location",
    };
    var detail_buffer: [512]u8 = undefined;
    const detail = if (origin) |o|
        std.fmt.bufPrint(&detail_buffer, "Blocked a frame with origin \"{s}\" from accessing a cross-origin frame.", .{o}) catch "SecurityError"
    else
        "SecurityError";
    const result = switch (access) {
        .named_get => if (name.len > 0)
            std.fmt.bufPrint(buffer, "Failed to read a named property '{s}' from '{s}': {s}", .{ name, interface, detail })
        else
            std.fmt.bufPrint(buffer, "Failed to read a named property from '{s}': {s}", .{ interface, detail }),
        .named_set => if (name.len > 0)
            std.fmt.bufPrint(buffer, "Failed to set a named property '{s}' on '{s}': {s}", .{ name, interface, detail })
        else
            std.fmt.bufPrint(buffer, "Failed to set a named property on '{s}': {s}", .{ interface, detail }),
        .named_delete => if (name.len > 0)
            std.fmt.bufPrint(buffer, "Failed to delete a named property '{s}' from '{s}': {s}", .{ name, interface, detail })
        else
            std.fmt.bufPrint(buffer, "Failed to delete a named property from '{s}': {s}", .{ interface, detail }),
        .indexed_get => std.fmt.bufPrint(buffer, "Failed to read an indexed property [{s}] from '{s}': {s}", .{ name, interface, detail }),
        .indexed_set => std.fmt.bufPrint(buffer, "Failed to set an indexed property [{s}] on '{s}': {s}", .{ name, interface, detail }),
        .indexed_delete => std.fmt.bufPrint(buffer, "Failed to delete an indexed property [{s}] from '{s}': {s}", .{ name, interface, detail }),
        else => std.fmt.bufPrint(buffer, "{s}", .{detail}),
    };
    // A name too long for the buffer: the detail alone.
    return result catch std.fmt.bufPrint(buffer, "{s}", .{detail}) catch "SecurityError";
}

test "a cross-origin SecurityError's message is Chrome's" {
    var buffer: [1024]u8 = undefined;
    const origin = "http://www.web-platform.test:8001";
    try std.testing.expectEqualStrings(
        "Failed to read a named property 'href' from 'Location': Blocked a frame with origin \"http://www.web-platform.test:8001\" from accessing a cross-origin frame.",
        securityErrorMessage(&buffer, .location, .named_get, "href", origin),
    );
    try std.testing.expectEqualStrings(
        "Failed to set a named property 'foo' on 'Window': Blocked a frame with origin \"http://www.web-platform.test:8001\" from accessing a cross-origin frame.",
        securityErrorMessage(&buffer, .window, .named_set, "foo", origin),
    );
    try std.testing.expectEqualStrings(
        "Failed to delete a named property 'document' from 'Window': Blocked a frame with origin \"http://www.web-platform.test:8001\" from accessing a cross-origin frame.",
        securityErrorMessage(&buffer, .window, .named_delete, "document", origin),
    );
    try std.testing.expectEqualStrings(
        "Failed to read an indexed property [3] from 'Window': Blocked a frame with origin \"http://www.web-platform.test:8001\" from accessing a cross-origin frame.",
        securityErrorMessage(&buffer, .window, .indexed_get, "3", origin),
    );
    try std.testing.expectEqualStrings(
        "Failed to set an indexed property [0] on 'Window': Blocked a frame with origin \"http://www.web-platform.test:8001\" from accessing a cross-origin frame.",
        securityErrorMessage(&buffer, .window, .indexed_set, "0", origin),
    );
    // A symbol has no name to show; an access with no property is the detail alone.
    try std.testing.expectEqualStrings(
        "Failed to read a named property from 'Window': Blocked a frame with origin \"http://www.web-platform.test:8001\" from accessing a cross-origin frame.",
        securityErrorMessage(&buffer, .window, .named_get, "", origin),
    );
    try std.testing.expectEqualStrings(
        "Blocked a frame with origin \"http://www.web-platform.test:8001\" from accessing a cross-origin frame.",
        securityErrorMessage(&buffer, .window, .unknown, "", origin),
    );
    // No origin to name: the exception's name, as before.
    try std.testing.expectEqualStrings("Failed to read a named property 'href' from 'Location': SecurityError", securityErrorMessage(&buffer, .location, .named_get, "href", null));
}

/// The number of W's document-tree child navigables (7.2.3.10 step 2).
fn childCount(window_ptr: ?*anyopaque) callconv(.c) u32 {
    const window = instanceOf(window_ptr) orelse return 0;
    return interfaces.Window.get_length(window) catch 0;
}

/// The WindowProxy of W's named child navigable `name` (7.2.3.5 step 6), as
/// an owned Global the C++ half releases; null when the name reaches none.
fn childNamed(isolate: *v8.Isolate, window_ptr: ?*anyopaque, name: [*]const u8, name_len: usize) callconv(.c) ?*v8.Value {
    _ = isolate;
    const window = instanceOf(window_ptr) orelse return null;
    const child = dom.cross_origin.childNavigableNamed(window, name[0..name_len]) orelse return null;
    // HTML 7.1.3.3's access report check (Chromium reports "named").
    protocol_realms.reportWindowAccess(window, "named");
    const proxy = protocol_realms.windowProxyOf(child) orelse return null;
    defer v8.v8_Object_Dispose(proxy);
    return v8.v8_Global_Clone(@ptrCast(proxy));
}

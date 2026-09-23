//! Lazy interface objects on a child realm's global.
//!
//! A realm's global has one property per exposed interface. Building all of
//! them when the realm is created - ~1,260 functions, their prototypes and
//! every member on both - cost an iframe ~25 ms and ~2.8 MB, whether or not
//! its script touched any of them. V8's `Object::SetLazyDataProperty`
//! (v8-object.h: "the provided getter is invoked ... the first time it is
//! read. After the property is accessed once, it is replaced with an ordinary
//! data property") defers that to the first read, per interface.
//!
//! interface_bindings.registerAllTemplatesOnly(.lazy_follows) installs these;
//! the getter builds the whole interface object through
//! V8Interface.materializeInterfaceObject, so a lazily built one is the same
//! as an eagerly built one.

const std = @import("std");
const v8 = @import("ffi.zig");
const interface_bindings = @import("interface_bindings.zig");

/// Built eagerly in every realm, never lazily.
const core_interfaces = std.StaticStringMap(void).initComptime(.{
    .{ "EventTarget", {} },
    .{ "Node", {} },
    .{ "Element", {} },
    .{ "Document", {} },
    .{ "HTMLDocument", {} },
    .{ "Window", {} },
    // Worker must NOT use lazy getter - it needs fresh constructor callbacks
    // to work properly after snapshot restore.
    .{ "Worker", {} },
    .{ "MessageEvent", {} },
    // URL must be eager so webkitURL === URL works (legacy window alias)
    // Per WebIDL spec: [LegacyWindowAlias=webkitURL] requires object identity
    .{ "URL", {} },
});

pub fn isLazyInstallableInterface(name: []const u8) bool {
    return !core_interfaces.has(name);
}

fn nameToNative(name: *v8.Name, buf: []u8) ?[]const u8 {
    if (!v8.v8_Name_IsString(name)) return null;
    const string: *v8.String = @ptrCast(name);
    const len = v8.v8_String_WriteUtf8_Raw(string, buf.ptr, @intCast(buf.len));
    if (len <= 0) return null;
    // V8's WriteUtf8 includes null terminator in the length, exclude it
    const actual_len: usize = @intCast(len);
    if (actual_len > 0 and buf[actual_len - 1] == 0) {
        return buf[0 .. actual_len - 1];
    }
    return buf[0..actual_len];
}

/// The lazy data property's getter: build the interface object named by the
/// property. V8 then replaces the property with a data property holding it.
pub fn lazyConstructorGetter(
    property: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    const isolate = info.getIsolate();
    // The realm that owns the global, not the current one: a parent reading
    // `iframe.contentWindow.DOMParser` first would otherwise build ITS OWN
    // DOMParser, and V8 would store that on the iframe's global for good.
    const holder = info.getHolder() orelse return;
    defer v8.v8_Object_Dispose(holder);
    const context = v8.v8_Object_GetCreationContext(holder) orelse return;
    defer v8.v8_Context_Dispose(context);

    var name_buf: [256]u8 = undefined;
    const name = nameToNative(property, &name_buf) orelse return;

    const constructor = interface_bindings.materializeInterfaceObjectByName(name, isolate, context) orelse return;
    defer v8.v8_Function_Dispose(constructor);

    info.setReturnValue(@ptrCast(constructor));
}

/// `global[name]` as a lazy data property (DontEnum, like an eager interface
/// object: writable, not enumerable, configurable).
pub fn installLazy(isolate: *v8.Isolate, context: *v8.Context, global: *v8.Object, name: []const u8) void {
    const key = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return;
    defer v8.v8_String_Dispose(key);
    v8.v8_Object_SetLazyDataProperty(global, context, @ptrCast(key), lazyConstructorGetter, null);
}

pub fn registerExternalReferences() void {
    const ext_refs = @import("external_references.zig");
    ext_refs.registerPointer(@intFromPtr(&lazyConstructorGetter));
}

const testing = std.testing;

test "the core interfaces are never lazy; every other one is" {
    for ([_][]const u8{ "EventTarget", "Node", "Element", "Document", "HTMLDocument", "Window", "Worker", "MessageEvent", "URL" }) |name| {
        try testing.expect(!isLazyInstallableInterface(name));
    }
    try testing.expect(isLazyInstallableInterface("DOMParser"));
    try testing.expect(isLazyInstallableInterface("PaymentRequest"));
}

test "global_constructor_handler module compiles" {
    testing.refAllDecls(@This());
}

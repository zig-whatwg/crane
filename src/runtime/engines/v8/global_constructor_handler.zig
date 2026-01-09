const std = @import("std");
const v8 = @import("ffi.zig");
const interface_catalog = @import("interface_catalog.zig");
const interface_bindings = @import("interface_bindings.zig");

const core_interfaces = std.StaticStringMap(void).initComptime(.{
    .{ "EventTarget", {} },
    .{ "Node", {} },
    .{ "Element", {} },
    .{ "Document", {} },
    .{ "HTMLDocument", {} },
    .{ "Window", {} },
    // Worker must NOT use lazy getter - it needs fresh constructor callbacks
    // to work properly after snapshot restore. The lazy getter would return
    // a cached template with stale callback pointers.
    .{ "Worker", {} },
    .{ "MessageEvent", {} },
});

fn isLazyInstallableInterface(name: []const u8) bool {
    if (core_interfaces.has(name)) {
        return false;
    }
    const index = interface_catalog.indexOfByNameRuntime(name);
    return index != interface_catalog.INVALID_INDEX;
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

pub fn lazyConstructorGetter(
    property: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    var name_buf: [256]u8 = undefined;
    const name = nameToNative(property, &name_buf) orelse return;

    const template = interface_bindings.createTemplateOnDemandByName(name, isolate) orelse return;
    const constructor = v8.v8_FunctionTemplate_GetFunction(template, context) orelse return;

    info.setReturnValue(@ptrCast(constructor));
}

pub fn installLazyConstructorsOnGlobal(context: *v8.Context) void {
    const isolate = v8.v8_Isolate_GetCurrent() orelse return;
    const global = v8.v8_Context_Global(context) orelse return;

    const valid_interfaces = comptime interface_catalog.getValidInterfaces();

    inline for (valid_interfaces) |iface| {
        const iface_name = iface.name;

        if (comptime !core_interfaces.has(iface_name)) {
            if (v8.v8_String_NewFromUtf8(isolate, iface_name.ptr, @intCast(iface_name.len))) |key| {
                v8.v8_Object_SetLazyDataProperty(
                    global,
                    context,
                    @ptrCast(key),
                    lazyConstructorGetter,
                    null,
                );
            }
        } else {
            // Debug: Verify core interfaces are being skipped
            if (std.mem.eql(u8, iface_name, "Worker")) {
                std.debug.print("[LAZY] Skipping Worker - it's in core_interfaces\n", .{});
            }
        }
    }
}

pub fn installOnGlobalTemplate(global_template: *v8.ObjectTemplate) void {
    _ = global_template;
}

pub fn registerExternalReferences() void {
    const ext_refs = @import("external_references.zig");
    ext_refs.registerPointer(@intFromPtr(&lazyConstructorGetter));
}

const testing = std.testing;

test "isLazyInstallableInterface - core interfaces return false" {
    try testing.expect(!isLazyInstallableInterface("EventTarget"));
    try testing.expect(!isLazyInstallableInterface("Node"));
    try testing.expect(!isLazyInstallableInterface("Element"));
    try testing.expect(!isLazyInstallableInterface("Document"));
    try testing.expect(!isLazyInstallableInterface("Window"));
}

test "isLazyInstallableInterface - unknown names return false" {
    try testing.expect(!isLazyInstallableInterface("NotAnInterface"));
    try testing.expect(!isLazyInstallableInterface("randomProperty"));
    try testing.expect(!isLazyInstallableInterface("console"));
}

test "isLazyInstallableInterface - MessageEvent should return true" {
    try testing.expect(isLazyInstallableInterface("MessageEvent"));
}

test "global_constructor_handler module compiles" {
    testing.refAllDecls(@This());
}

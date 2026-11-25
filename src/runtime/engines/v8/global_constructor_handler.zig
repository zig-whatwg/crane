//! A global's exposed constructs, built when script first reads them.
//!
//! Every exposed construct of a global - an interface object, a legacy
//! factory function, an alias - is a lazy data property (V8's
//! `SetLazyDataProperty`, v8-object.h: "the provided getter is invoked ...
//! the first time it is read. After the property is accessed once, it is
//! replaced with an ordinary data property"), put on the global's template
//! once per isolate (interface_bindings.installExposedConstructs) or, for one
//! only some realms expose, on the realm's global
//! (interface_bindings.installConditionalConstructs) - Blink's
//! IDLMemberInstaller::InstallExposedConstructs. A realm builds only the
//! interface objects its script reads: building all ~1,080 of a Window costs
//! a realm ~1.1 MB (lane tmpl1's measurement, tmp/plans/tmpl1-measure.md).
//!
//! The getter builds the construct through interface_bindings.makeConstruct
//! - for an interface, V8Interface.materializeInterfaceObject, the one
//! function every realm builds an interface object with, so a lazily built
//! one is the same as one built for a wrapper first.

const std = @import("std");
const v8 = @import("ffi.zig");
const interface_bindings = @import("interface_bindings.zig");

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

/// The lazy data property's getter: build the construct its data names (its
/// index in interface_bindings.constructs) - or, with no index, the one its
/// property's name names. V8 then replaces the property with a data property
/// holding it.
pub fn lazyConstructGetter(
    property: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    const isolate = info.getIsolate();
    // The realm that owns the global, not the current one: a parent reading
    // `iframe.contentWindow.DOMParser` first would otherwise build ITS OWN
    // DOMParser, and V8 would store that on the iframe's global for good.
    // Found by THE Window-receiver rule (realm_global.receiverRealm): for a
    // contextual read in a realm whose WindowProxy went on, V8 15.7 hands a
    // native data property V8's detached copy of the proxy as Holder()
    // (GetHolderForApi, V8 32fd863235d) - contextless, so its creation
    // context answered nothing and the first read of a lazy interface object
    // there was undefined; the rule answers that realm, whose global the
    // property is on (design 2.3 gap a; RED 966f3a99eb5).
    const holder = info.getHolder() orelse return;
    defer v8.v8_Object_Dispose(holder);
    const context = @import("realm_global.zig").receiverRealm(isolate, holder, .native) orelse return;
    defer v8.v8_Context_Dispose(context);

    const index = v8.v8_PropertyCallbackInfo_DataInt32(info, -1);
    const made = if (index >= 0)
        interface_bindings.makeConstruct(index, isolate, context)
    else by_name: {
        var name_buf: [256]u8 = undefined;
        const name = nameToNative(property, &name_buf) orelse return;
        break :by_name interface_bindings.materializeInterfaceObjectByName(name, isolate, context);
    };
    const constructor = made orelse return;
    defer v8.v8_Function_Dispose(constructor);
    info.setReturnValue(@ptrCast(constructor));
}

pub fn registerExternalReferences() void {
    const ext_refs = @import("external_references.zig");
    ext_refs.registerPointer(@intFromPtr(&lazyConstructGetter));
}

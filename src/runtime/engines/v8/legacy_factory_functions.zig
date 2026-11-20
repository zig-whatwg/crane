//! WebIDL [LegacyFactoryFunction]: `Image()`, `Audio()` and `Option()`.
//!
//! Each is its own function object (WebIDL 3.7.2 "legacy factory
//! functions"), not an alias of the interface object. The interface objects
//! are [HTMLConstructor]s, so `new HTMLImageElement()` throws - and while
//! `Image` was registered as that same function, so did `new Image()`, which
//! turned every page that builds one at top level into a harness ERROR
//! ("Illegal invocation").
//!
//! The function object F: its steps throw a TypeError when NewTarget is
//! undefined, convert the arguments, and run the factory's steps in F's realm
//! (a built-in function runs in its own realm, so "the current global object"
//! is F's global); `length` is the number of required arguments (0 for all
//! three), `name` is the identifier, and `prototype` is the interface
//! prototype object, {writable: false, enumerable: false, configurable:
//! false}. F is a property of the global, {writable: true, enumerable:
//! false, configurable: true}.
//!
//! The factories' steps are HTML's (4.8.4.1 Image, 4.8.11.1 Audio, 4.10.10
//! Option) and reach the DOM only through interfaces.
//!
//! WebIDL's steps make the object by "internally create a new object
//! implementing the interface" with NewTarget: its prototype is
//! NewTarget.prototype - or, when that is not an object, the interface
//! prototype object of GetFunctionRealm(NewTarget) - so `class CustomImage
//! extends Image {}` constructs a CustomImage (`applyNewTargetPrototype`;
//! webidl/ecmascript-binding/legacy-factor-function-subclass.window.js,
//! Chrome 157, Firefox 160 and Safari 27.2 pass 1/1). HTML's steps create the
//! element with "create an element", which gives it the interface prototype;
//! the binding then gives its wrapper NewTarget's.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const v8 = @import("ffi.zig");
const conv = @import("conversions.zig");
const interface = @import("interface.zig");

const Kind = enum { image, audio, option };

const Factory = struct {
    name: []const u8,
    interface: []const u8,
    kind: Kind,
};

const factories = [_]Factory{
    .{ .name = "Image", .interface = "HTMLImageElement", .kind = .image },
    .{ .name = "Audio", .interface = "HTMLAudioElement", .kind = .audio },
    .{ .name = "Option", .interface = "HTMLOptionElement", .kind = .option },
};

/// Every callback a snapshot may hold must be an external reference.
pub fn registerExternalReferences() void {
    const ext_refs = @import("external_references.zig");
    inline for (factories) |factory| {
        ext_refs.registerPointer(@intFromPtr(&Callback(factory).callback));
    }
}

/// Define each factory on `context`'s global, eagerly - in a realm that
/// exposes its interface (a worker's global has no HTMLImageElement, so no
/// Image). A Window realm has them as lazy constructs instead
/// (interface_bindings.constructs, `make`).
pub fn install(isolate: *v8.Isolate, context: *v8.Context) void {
    const global = v8.v8_Context_Global(context) orelse return;
    defer v8.v8_Object_Dispose(global);

    inline for (factories) |factory| installOne(isolate, context, global, factory);
}

fn installOne(isolate: *v8.Isolate, context: *v8.Context, global: *v8.Object, comptime factory: Factory) void {
    const iface_key = v8.v8_String_NewFromUtf8(isolate, factory.interface.ptr, @intCast(factory.interface.len)) orelse return;
    defer v8.v8_String_Dispose(iface_key);
    const iface_value = v8.v8_Object_Get(global, context, @ptrCast(iface_key)) orelse return;
    defer v8.v8_Value_Dispose(iface_value);
    if (!v8.v8_Value_IsObject(iface_value)) return;
    const function = make(factory.name, isolate, context, @ptrCast(iface_value)) orelse return;
    defer v8.v8_Function_Dispose(function);
    const name = v8.v8_String_NewFromUtf8(isolate, factory.name.ptr, @intCast(factory.name.len)) orelse return;
    defer v8.v8_String_Dispose(name);
    _ = v8.v8_Object_DefineProperty(global, context, @ptrCast(name), @ptrCast(function), true, false, true);
}

/// The [LegacyFactoryFunction] `name` (Image, Audio or Option) made in
/// `context`, whose `prototype` is `interface_object`'s - its interface's
/// interface prototype object (WebIDL 3.7.2: the legacy factory function's
/// "prototype" property, { [[Writable]]: false, [[Enumerable]]: false,
/// [[Configurable]]: false }). OWNED, or null for another name or when it
/// could not be made. The interface object is BORROWED.
pub fn make(comptime name: []const u8, isolate: *v8.Isolate, context: *v8.Context, interface_object: *v8.Function) ?*v8.Function {
    const factory = comptime for (factories) |f| {
        if (std.mem.eql(u8, f.name, name)) break f;
    } else @compileError("no legacy factory function " ++ name);
    const proto_key = v8.v8_String_NewFromUtf8(isolate, "prototype", 9) orelse return null;
    defer v8.v8_String_Dispose(proto_key);
    const proto = v8.v8_Object_Get(@ptrCast(interface_object), context, @ptrCast(proto_key)) orelse return null;
    defer v8.v8_Value_Dispose(proto);

    const template = v8.v8_FunctionTemplate_New(isolate, Callback(factory).callback, null) orelse return null;
    defer v8.v8_FunctionTemplate_Dispose(template);
    const name_v8 = v8.v8_String_NewFromUtf8(isolate, factory.name.ptr, @intCast(factory.name.len)) orelse return null;
    defer v8.v8_String_Dispose(name_v8);
    v8.v8_FunctionTemplate_SetClassName(template, name_v8);
    v8.v8_FunctionTemplate_SetLength(template, 0);

    const function = v8.v8_FunctionTemplate_GetFunction(template, context) orelse return null;
    _ = v8.v8_Object_DefineProperty(@ptrCast(function), context, @ptrCast(proto_key), proto, false, false, false);
    return function;
}

fn Callback(comptime factory: Factory) type {
    const kind = factory.kind;
    return struct {
        fn callback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
            const isolate = info.getIsolate();
            const context = info.getFunctionCreationContext() orelse return;
            defer v8.v8_Context_Dispose(context);

            // WebIDL: "If NewTarget is undefined, then throw a TypeError."
            if (!info.isConstructCall()) {
                conv.throwTypeErrorFromContext(isolate, context, "Please use the 'new' operator, this DOM object constructor cannot be called as a function.");
                return;
            }

            // "Let document be the current global object's associated Document."
            const document = documentOf(context) orelse {
                conv.throwTypeErrorFromContext(isolate, context, "Illegal constructor");
                return;
            };

            const element = construct(kind, isolate, context, info, document) catch |err| {
                if (err != error.ExceptionPending) conv.throwWebIDLErrorFromContext(isolate, context, @errorName(err));
                return;
            };
            const wrapper = conv.instanceToV8(isolate, element);
            // A getter on NewTarget's "prototype" threw: that exception.
            if (!applyNewTargetPrototype(info, wrapper, isolate, context, factory.interface)) return;
            info.setReturnValue(wrapper);
        }
    };
}

/// WebIDL "internally create a new object implementing the interface" with
/// NewTarget, steps 2-3, for the object a factory made: its prototype is
/// ? Get(NewTarget, "prototype"), or - that not being an Object - the
/// interface prototype object of `interface_name` in GetFunctionRealm(
/// NewTarget). `new Image()` (NewTarget the factory, whose prototype IS the
/// interface prototype object) changes nothing. False when the Get threw:
/// its exception is pending.
fn applyNewTargetPrototype(
    info: *const v8.FunctionCallbackInfo,
    wrapper: *v8.Value,
    isolate: *v8.Isolate,
    context: *v8.Context,
    comptime interface_name: []const u8,
) bool {
    if (!v8.v8_Value_IsObject(wrapper)) return true;
    const new_target = info.getNewTarget() orelse return true;
    defer v8.v8_Value_Dispose(new_target);
    if (!v8.v8_Value_IsObject(new_target)) return true;
    const prototype_key = v8.v8_String_NewFromUtf8(isolate, "prototype", 9) orelse return true;
    defer v8.v8_String_Dispose(prototype_key);
    const from_target = v8.v8_Object_Get(@ptrCast(new_target), context, @ptrCast(prototype_key)) orelse return false;
    defer v8.v8_Value_Dispose(from_target);
    const prototype: *v8.Value = if (v8.v8_Value_IsObject(from_target)) from_target else fallback: {
        // Step 3: the interface prototype object of GetFunctionRealm(NewTarget).
        const realm_owned = interface.getFunctionRealm(new_target, isolate);
        defer if (realm_owned) |r| v8.v8_Context_Dispose(r);
        const realm = realm_owned orelse context;
        const global = v8.v8_Context_Global(realm) orelse return true;
        defer v8.v8_Object_Dispose(global);
        const name = v8.v8_String_NewFromUtf8(isolate, interface_name.ptr, @intCast(interface_name.len)) orelse return true;
        defer v8.v8_String_Dispose(name);
        const interface_object = v8.v8_Object_Get(global, realm, @ptrCast(name)) orelse return false;
        defer v8.v8_Value_Dispose(interface_object);
        if (!v8.v8_Value_IsObject(interface_object)) return true;
        const interface_prototype = v8.v8_Object_Get(@ptrCast(interface_object), realm, @ptrCast(prototype_key)) orelse return false;
        if (!v8.v8_Value_IsObject(interface_prototype)) {
            v8.v8_Value_Dispose(interface_prototype);
            return true;
        }
        break :fallback interface_prototype;
    };
    defer if (prototype != from_target) v8.v8_Value_Dispose(prototype);
    if (v8.v8_Object_GetPrototypeV2(@ptrCast(wrapper))) |current| {
        defer v8.v8_Value_Dispose(current);
        if (v8.v8_Value_StrictEquals(current, prototype)) return true;
    }
    _ = v8.v8_Object_SetPrototypeV2(@ptrCast(wrapper), context, prototype);
    return true;
}

/// The Document of the Window whose global `context` is.
fn documentOf(context: *v8.Context) ?*runtime.Instance {
    const global = v8.v8_Context_Global(context) orelse return null;
    defer v8.v8_Object_Dispose(global);
    const ptr = v8.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return null;
    const window: *runtime.Instance = @ptrCast(@alignCast(ptr));
    if (window.stateAs(interfaces.Window.State) == null) return null;
    return interfaces.Window.get_document(window) catch null;
}

/// Argument `index`, or null when it was not passed or is undefined - both
/// mean "not given" for an optional argument (WebIDL 3.7.x overload
/// resolution treats a trailing undefined as missing).
fn argument(info: *const v8.FunctionCallbackInfo, index: c_int) ?*v8.Value {
    if (index >= info.length()) return null;
    const value = info.get(index);
    if (v8.v8_Value_IsUndefined(value)) {
        v8.v8_Value_Dispose(value);
        return null;
    }
    return value;
}

fn construct(comptime kind: Kind, isolate: *v8.Isolate, context: *v8.Context, info: *const v8.FunctionCallbackInfo, document: *runtime.Instance) !*runtime.Instance {
    const allocator = document.ctx.allocator;
    return switch (kind) {
        .image => {
            // Image(optional unsigned long width, optional unsigned long height):
            // the arguments are converted before the steps run.
            const width = try optionalUnsignedLong(context, argument(info, 0));
            const height = try optionalUnsignedLong(context, argument(info, 1));

            // Step 2: create an element given document, "img", and the HTML namespace.
            const img = try createElement(document, "img");
            errdefer img.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(img));
            // Steps 3-4: set an attribute value for width and for height.
            if (width) |w| try setNumberAttribute(allocator, img, "width", w);
            if (height) |h| try setNumberAttribute(allocator, img, "height", h);
            return img;
        },
        .audio => {
            // Audio(optional DOMString src)
            var src = try optionalString(allocator, isolate, context, argument(info, 0));
            defer if (src) |*s| s.deinit(allocator);

            const audio = try createElement(document, "audio");
            errdefer audio.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(audio));
            // Step 3: set an attribute value using "preload" and "auto".
            try interfaces.Element.call_setAttribute(audio, runtime.DOMString.initInterned("preload"), .{ .domstring = runtime.DOMString.initInterned("auto") });
            // Step 4: if src is given, set an attribute value using "src".
            if (src) |s| try interfaces.Element.call_setAttribute(audio, runtime.DOMString.initInterned("src"), .{ .domstring = s });
            return audio;
        },
        .option => {
            // Option(optional DOMString text = "", optional DOMString value,
            //        optional boolean defaultSelected = false,
            //        optional boolean selected = false)
            var text = try optionalString(allocator, isolate, context, argument(info, 0));
            defer if (text) |*s| s.deinit(allocator);
            var value = try optionalString(allocator, isolate, context, argument(info, 1));
            defer if (value) |*s| s.deinit(allocator);
            const default_selected = optionalBoolean(isolate, argument(info, 2));
            const selected = optionalBoolean(isolate, argument(info, 3));

            const option = try createElement(document, "option");
            errdefer option.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(option));
            // Step 3: if text is not the empty string, append a new Text node
            // whose data is text.
            if (text) |t| {
                if (t.asSlice().len > 0) {
                    const node = try interfaces.Document.call_createTextNode(document, t);
                    _ = try interfaces.Node.call_appendChild(option, node);
                }
            }
            // Step 4: if value is given, set an attribute value using "value".
            if (value) |v| try interfaces.Element.call_setAttribute(option, runtime.DOMString.initInterned("value"), .{ .domstring = v });
            // Step 5: if defaultSelected is true, set an attribute value using
            // "selected" and the empty string.
            if (default_selected) try interfaces.Element.call_setAttribute(option, runtime.DOMString.initInterned("selected"), .{ .domstring = runtime.DOMString.initEmpty() });
            // Step 6: set selectedness to `selected` - "even if defaultSelected
            // is true". A clean option's selectedness follows the `selected`
            // attribute, which step 5 has just made equal to defaultSelected,
            // so it is already right when the two agree. When they differ the
            // `selected` setter records it. Deviation: that setter also sets
            // the option's dirtiness, which step 6 does not, and no interface
            // sets one without the other - the difference shows only if the
            // `selected` content attribute changes afterwards.
            if (selected != default_selected) try interfaces.HTMLOptionElement.set_selected(option, selected);
            return option;
        },
    };
}

fn createElement(document: *runtime.Instance, comptime local_name: []const u8) !*runtime.Instance {
    const Options = @typeInfo(@TypeOf(interfaces.Document.call_createElement)).@"fn".param_types[2].?;
    return interfaces.Document.call_createElement(document, runtime.DOMString.initInterned(local_name), Options.notPassed());
}

/// "Set an attribute value" with a number: its decimal representation.
fn setNumberAttribute(allocator: std.mem.Allocator, element: *runtime.Instance, comptime name: []const u8, number: u32) !void {
    var buffer: [10]u8 = undefined;
    const digits = std.fmt.bufPrint(&buffer, "{d}", .{number}) catch unreachable;
    var value = try runtime.DOMString.initDupe(allocator, digits);
    defer value.deinit(allocator);
    try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned(name), .{ .domstring = value });
}

fn optionalUnsignedLong(context: *v8.Context, value: ?*v8.Value) !?u32 {
    const v = value orelse return null;
    defer v8.v8_Value_Dispose(v);
    return try conv.fromV8UnsignedLong(context, v);
}

fn optionalString(allocator: std.mem.Allocator, isolate: *v8.Isolate, context: *v8.Context, value: ?*v8.Value) !?runtime.DOMString {
    const v = value orelse return null;
    defer v8.v8_Value_Dispose(v);
    return try conv.fromV8Value(runtime.DOMString, allocator, isolate, context, v);
}

fn optionalBoolean(isolate: *v8.Isolate, value: ?*v8.Value) bool {
    const v = value orelse return false;
    defer v8.v8_Value_Dispose(v);
    return conv.fromV8Boolean(isolate, v);
}

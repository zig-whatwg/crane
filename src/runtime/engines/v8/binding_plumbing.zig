//! The V8 binding's interface-independent plumbing: ordinary functions that
//! every interface's generated callbacks call with a small descriptor - the
//! interface's name as a slice, flags, and pointers to the few functions that
//! are the interface's own (lane compiletime1, 2026-11-04).
//!
//! `V8Interface(Interface)` (interface.zig) is instantiated for every one of
//! the ~1,260 interfaces, and each of its callbacks for every member, so
//! anything written inside it is analysed, compiled and emitted once per
//! interface or per member: constructorCallback alone was 15.5 s of Sema and
//! 15.3 s of codegen over its instances in one test binary (lane onebin2's
//! time report), and LLVM Emit Object - 58% of a test binary's compile -
//! scales with what is emitted. What a callback does that does not depend on
//! its interface's types now lives here, once; each generic instance is a
//! thin shim that keeps only its own argument conversion, the impl call and
//! the return conversion.
//!
//! The split is the one Blink's and Servo's generated bindings make:
//! - Blink's bind_gen (third_party/blink/renderer/bindings/scripts/bind_gen/
//!   interface.py: make_constructor_callback_def, make_check_receiver,
//!   make_check_argument_length, make_attribute_get_callback_def) emits per
//!   member only the receiver's unwrapping, the arguments' conversion
//!   (NativeValueTraits), the call and the return (bindings::V8SetReturnValue);
//!   everything shared is a runtime helper the generated code calls with the
//!   interface's and member's names (ExceptionState, V8ThrowException,
//!   ExceptionToRejectPromiseScope, CEReactionsScope).
//! - Servo (components/script_bindings/utils.rs, generic_call /
//!   generic_method / generic_getter / generic_setter) runs ONE function for
//!   every member: it unwraps `this` from the member's JSJitInfo (protoID,
//!   depth) and a CallPolicyInfo (lenient_this, the cross-origin check), then
//!   calls the member's own op, which CodegenRust.py generates to convert the
//!   arguments, call the impl and convert the result.
//!
//! Behaviour is the generic code's, step for step: the same exceptions with
//! the same messages, the same order of side effects, the same handle
//! ownership - every `defer` that releases a handle moved here with its
//! handle. Where the generic code chose at compile time (`comptime` on an
//! interface name or a type), the descriptor carries the answer, computed at
//! compile time by the shim.

const std = @import("std");
const log = std.log.scoped(.v8_interface);
const debug = @import("debug.zig");
const v8 = @import("ffi.zig");
const conv = @import("conversions.zig");
const runtime = @import("runtime");
const webidl = @import("webidl");
const dom_algorithm = @import("dom_algorithm.zig");
const interface = @import("interface.zig");
const realm_global = @import("realm_global.zig");
const template_registry = @import("template_registry.zig");
const protocol_agents = @import("protocol_agents.zig");
const WrapperCache = @import("wrapper_cache.zig").WrapperCache;
const value_operations = @import("value_operations.zig");
const CallFrame = @import("call_frame.zig").CallFrame;

// ============================================================================
// Constructors (WebIDL 3.7.1 "interface object" [[Call]]/[[Construct]])
// ============================================================================

/// What an interface's constructor callback needs that is its own.
pub const Constructor = struct {
    interface_name: []const u8,
    /// "<interface> constructor: 'new' is required".
    new_required_message: []const u8,
    /// Whether converting a constructor argument may make the engine keep
    /// the current context (`interface.typeRetainsContext` over the
    /// constructor's parameters - an allowlist whose default is "retains"):
    /// then the binding does not release it.
    params_retain_context: bool,
    /// [HTMLConstructor]: with the agent's host hook, the construction is
    /// HTML's (`constructHTMLElement`).
    html_constructor: bool,
    /// The Worker and MutationObserver constructors log their steps at debug.
    traces_construction: bool,
    /// DOMException: its instance gets a `stack` (`captureDOMExceptionStack`).
    dom_exception: bool,
    /// The interface's own steps: convert the arguments and call its
    /// constructor (`V8Interface.callConstructorWithArgs`).
    construct: *const fn (
        info: *const v8.FunctionCallbackInfo,
        allocator: std.mem.Allocator,
        ctx: runtime.Context,
        current_context: *v8.Context,
        isolate: *v8.Isolate,
    ) anyerror!*runtime.Instance,
    /// Its conditional [LegacyUnforgeable] members, installed on a new
    /// instance (`V8Interface.installConditionalUnforgeables`), or null.
    install_conditional_unforgeables: ?*const fn (isolate: *v8.Isolate, context: *v8.Context, object: *v8.Object) void,
};

/// An interface object's [[Construct]] (and [[Call]], which throws): the
/// generic constructorCallback's steps, for the interface `self` describes.
pub fn construct(info: *const v8.FunctionCallbackInfo, self: *const Constructor) void {
    debug.print("[V8_CONSTRUCTOR] constructorCallback called for: {s}\n", .{self.interface_name});
    // A DOM algorithm on the agent's stack until it returns into script
    // (dom_algorithm.zig; refcount design 9, risk 4).
    const algorithm = dom_algorithm.enter(info.getIsolate());
    defer dom_algorithm.leaveToScript(algorithm);

    // Always-on stderr debug for Worker and MutationObserver constructor to trace issues
    if (self.traces_construction) {
        log.debug("[CTOR_CALLBACK] {s} constructorCallback ENTRY\n", .{self.interface_name});
    }

    const isolate = info.getIsolate();

    // CRITICAL: Check if this is a constructor call (called with 'new')
    // If called as a function (without 'new'), 'this' may be the global object
    // which has 0 internal fields, causing "Internal field out of bounds" crash.
    if (!info.isConstructCall()) {
        // Owned handle; the null branch has none to release.
        const function_ctx = info.getFunctionCreationContext() orelse {
            conv.throwTypeError(isolate, self.new_required_message);
            return;
        };
        defer v8.v8_Context_Dispose(function_ctx);
        conv.throwTypeErrorFromContext(isolate, function_ctx, self.new_required_message);
        return;
    }

    // Get V8 contexts:
    // - current_context: The caller's context (for argument parsing)
    // - constructor_context: The constructor's creation context (for object realm)
    //
    // Per WebIDL §3.7.2 [[Construct]]: "Let realm be F's relevant realm"
    // Objects created by constructors belong to the constructor's realm, not the caller's realm.
    const current_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwError(isolate, "No current V8 context");
        return;
    };
    // Released unless converting a constructor argument makes the engine
    // keep the context (`new MutationObserver(callback)`) - the same
    // allowlist gate as MethodCallback's.
    defer if (!self.params_retain_context) v8.v8_Context_Dispose(current_context);

    // Implementation of GetFunctionRealm algorithm for constructor realm
    // This ensures we correctly handle cross-realm construction, bound functions, and proxies.
    // Using the constructor function's realm (F.[[Realm]]) per WebIDL spec.
    // The constructor is the callee: its realm is the current context V8
    // entered for the call (v8_FunctionCallbackInfo_GetFunctionCreationContext).
    // A construct call's target is the FunctionTemplateInfo, so the callee
    // function itself was never read here (V8 >= 14 keeps it private).
    // Owned in both branches, and released: `ctx_mgr.getOrCreateWithIsolate`
    // keeps its own copy of the handle when it creates an entry, so the
    // caller's is always the caller's. (Before it did, this leaked one
    // Global<Context> per constructor call - each one keeping its page's
    // whole native context alive.)
    const constructor_v8_context = info.getFunctionCreationContext();
    defer if (constructor_v8_context) |c| v8.v8_Context_Dispose(c);
    const constructor_context = constructor_v8_context orelse current_context;

    // Get or create isolate allocator (uses page_allocator as fallback)
    const isolate_alloc = @import("isolate_allocator.zig");
    const allocator = isolate_alloc.getOrInitAllocator(isolate, std.heap.c_allocator) catch {
        conv.throwError(isolate, "Failed to get isolate allocator");
        return;
    };

    // Get or create runtime context from the CONSTRUCTOR'S context (not caller's)
    // This ensures the realm in ctx matches the constructor's realm
    const ctx_mgr = @import("context_manager.zig");
    const ctx = ctx_mgr.getOrCreateWithIsolate(constructor_context, isolate, allocator) catch {
        conv.throwError(isolate, "Failed to get runtime context");
        return;
    };

    // Get 'this' object (the newly created instance). Owned, like
    // every getThis(), until the wrapper cache takes it: `cache.set`
    // below stores this exact pointer as `entry.wrapper` and arms
    // `v8_Global_SetWeak` on it, so from a successful set the cache
    // owns it and frees it via `disposeEntryWrapper` - disposing it
    // then is a double free plus a weak callback pointing at freed
    // memory. Every other exit releases it here: a conversion that
    // threw, an impl that failed, an instance that already had a
    // wrapper, no cache, a failed set. Those exits used to keep it,
    // one Global<Object> per failed `new X()` of any interface (Codex
    // row 14 Q16; tests/v8/constructor_error_receiver_test.zig).
    const this_obj = info.getThis();
    var receiver_taken = false;
    defer if (!receiver_taken) v8.v8_Object_Dispose(this_obj);

    // HTML 3.2.3 "HTML element constructors" [html_constructor]: with
    // the agent's host hook, the construction is HTML's - the element
    // a custom element class's super() gets, new or upgrading.
    if (self.html_constructor) {
        if (protocol_agents.htmlConstructorHookOf(isolate)) |hook| {
            // It binds or releases the receiver itself.
            receiver_taken = true;
            constructHTMLElement(self, info, hook, this_obj, isolate, current_context, constructor_context, ctx);
            return;
        }
    }

    // ========================================
    // CROSS-REALM CONSTRUCTOR SUPPORT (WebIDL §3.7.2)
    // ========================================
    // When NewTarget.prototype is not an object (e.g., primitive like 7),
    // we must fall back to the interface prototype object from the
    // appropriate realm (GetFunctionRealm(NewTarget)).
    //
    // V8 already creates 'this' with the correct prototype when NewTarget.prototype
    // is valid, but falls back to Object.prototype when it's invalid.
    // We need to detect this and fix it.
    // Note: Use current_context here since NewTarget comes from the caller's realm
    interface.handleNewTargetPrototypeFallback(info, this_obj, isolate, current_context, self.interface_name);

    // Call the interface's constructor with arguments parsed at comptime
    // Note: Arguments are parsed from current_context (caller's values), but
    // the runtime ctx uses constructor_context (constructor's realm)
    if (self.traces_construction) {
        log.debug("[CTOR_CALLBACK] {s} calling callConstructorWithArgs\n", .{self.interface_name});
    }
    const instance = self.construct(info, allocator, ctx, current_context, isolate) catch |err| {
        // ExceptionPending means an exception was already rethrown during conversion
        // (e.g., from toString() throwing) - don't throw a second error
        if (self.traces_construction) {
            log.debug("[CTOR_CALLBACK] {s} callConstructorWithArgs FAILED: {s}\n", .{ self.interface_name, @errorName(err) });
        }
        if (err == conv.ConversionError.ExceptionPending) {
            return;
        }
        // Throw appropriate error type based on error name
        // Use throwWebIDLError which properly creates DOMException for WebIDL errors
        // Owned: this returns a fresh Global<Context> per call, which nothing was
        // disposing - 2 leaked handles per DOM object created. Dispose the OWNED
        // one only; the `orelse` fallback is borrowed and freeing it would be a
        // double free.
        const function_ctx_owned = info.getFunctionCreationContext();
        defer if (function_ctx_owned) |c| v8.v8_Context_Dispose(c);
        const function_ctx = function_ctx_owned orelse current_context;
        conv.throwWebIDLErrorFromContext(isolate, function_ctx, @errorName(err));
        return;
    };

    // An instance its own construction already wrapped (a traced edge
    // made its wrapper): that wrapper, given NewTarget's prototype, is
    // the result - binding `this_obj` instead would replace it, and
    // every edge drawn on it with it (WrapperCache.set refuses). The
    // receiver is then bound to nothing, and released.
    if (interface.adoptExistingWrapper(info, this_obj, instance, constructor_context)) return;

    // Store the Zig instance in the V8 object's internal field (slot 0)
    interface.setInstance(runtime.Instance, this_obj, instance);

    // ========================================
    // CACHE THE WRAPPER: Store constructor-created wrapper for identity
    // ========================================
    if (self.install_conditional_unforgeables) |install| install(isolate, constructor_context, this_obj);
    if (ctx.getV8WrapperCacheStorage()) |cache_storage| {
        const cache: *WrapperCache = @ptrCast(@alignCast(cache_storage));

        // The cache owns the instance through `this` from here. When
        // it cannot take it (OutOfMemory), the construction fails:
        // returning `this` anyway left an instance nothing owned
        // (Codex row 15 Q22). The receiver is unbound - nothing reaches
        // the instance through it - and released by the deferred
        // dispose above (a set that fails stored nothing); the
        // instance, which nothing else ever wrapped, is freed, and the
        // error is thrown.
        // A node's receiver moves into its slot (its box goes): nothing
        // below reads `this_obj` but a DOMException's, which is no node.
        // The instance was created by this call (WebIDL 3.7.2: the
        // constructor steps make a new object) and is first wrapped here -
        // one a traced edge wrapped while it was made returned above: inside
        // a callback it is stamped with the agent's callback clock, so that
        // its finalizer may run at a binding's return into that callback's
        // script (finalizer_safe_point.zig, "Inside a callback"). Script
        // the constructor itself ran - a dictionary getter, a callback - has
        // returned; a callback it invoked has ended.
        const stamp: u32 = if (algorithm) |queue| queue.freshStamp() else 0;
        _ = cache.setConstructed(instance, this_obj, isolate, stamp) catch |err| {
            unbindReceiver(this_obj);
            instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
            const function_ctx_owned = info.getFunctionCreationContext();
            defer if (function_ctx_owned) |c| v8.v8_Context_Dispose(c);
            conv.throwWebIDLErrorFromContext(isolate, function_ctx_owned orelse current_context, @errorName(err));
            return;
        };
        receiver_taken = true;
    }

    // ========================================
    // POST-CONSTRUCTOR HOOKS: Interface-specific initialization
    // ========================================
    // For DOMException: add stack property per WebIDL spec
    // If the implementation has a stack property on normal errors, DOMException must too
    if (self.dom_exception) {
        interface.captureDOMExceptionStack(this_obj, isolate, constructor_context);
    }

    // Return 'this' (V8 does this automatically for constructors)
}

/// HTML 3.2.3 "HTML element constructors", the overridden constructor
/// steps of an [HTMLConstructor] interface, across the seam
/// (engine.HostHooks.htmlConstructor): step 1 here, then steps 10-11
/// (the receiver's prototype), the host's 2-9, 12, 13 and 15, and 14
/// and 16 here. Takes `this_obj`, V8's receiver for NewTarget: it is
/// bound to the element, or released - never left registered for an
/// element whose existing wrapper is the result.
///
/// Order: V8 performed Get(NewTarget, "prototype") when it made the
/// receiver, before step 1, so a throwing or side-effecting getter is
/// seen before the TypeErrors of steps 1-9, 12 and 13 (the spec has it
/// after them). Blink's V8HTMLConstructor::HtmlConstructor
/// (third_party/blink/renderer/bindings/core/v8/v8_html_constructor.cc)
/// runs under the same V8 construct path and has the same order.
fn constructHTMLElement(
    self: *const Constructor,
    info: *const v8.FunctionCallbackInfo,
    hook: protocol_agents.HTMLConstructorHook,
    this_obj: *v8.Object,
    isolate: *v8.Isolate,
    current_context: *v8.Context,
    function_context: *v8.Context,
    realm: runtime.Context,
) void {
    var receiver_taken = false;
    defer if (!receiver_taken) v8.v8_Object_Dispose(this_obj);

    // The active function object: this interface's interface object.
    // A construct call's FunctionCallbackInfo names its target as the
    // FunctionTemplateInfo rather than the function (V8's
    // GetTargetFunctionTemplateInfo reads either), and V8 >= 14 gives no
    // read of it; the interface object is the template's instantiation in
    // the current context - the callee's, which V8 entered for the call.
    const active: ?*v8.Function = activeInterfaceObject(self, current_context);
    defer if (active) |f| v8.v8_Function_Dispose(f);

    // A construct call always has NewTarget.
    const new_target = info.getNewTarget() orelse {
        conv.throwTypeErrorFromContext(isolate, function_context, "Illegal constructor");
        return;
    };
    defer v8.v8_Value_Dispose(new_target);

    // 1. If NewTarget is equal to the active function object, then
    //    throw a TypeError.
    if (active) |function| {
        if (v8.v8_Value_StrictEquals(new_target, @ptrCast(function))) {
            conv.throwTypeErrorFromContext(isolate, function_context, "Illegal constructor");
            return;
        }
    }

    // 10-11. Let prototype be ? Get(NewTarget, "prototype"); if it is
    //        not an Object, the interface prototype object of
    //        GetFunctionRealm(NewTarget) whose interface is the active
    //        function's. V8 made the receiver with NewTarget's
    //        prototype, or - for a non-object - the active function's
    //        own realm's. Only then can the realm be wrong, so only then
    //        is NewTarget read again (its getter runs twice there, as on
    //        every constructor's path); a prototype of NewTarget's own
    //        is never re-read, so its getter's script ran once, before
    //        the host's steps (the hook's single-call contract).
    //    V8's fallback for a non-object is %Object.prototype% of
    //    GetFunctionRealm(NewTarget) for an API constructor
    //    (JSFunction::GetDerivedMap: OBJECT_FUNCTION_INDEX when the
    //    constructor names no intrinsic), never an interface
    //    prototype - so a receiver given that object needs the
    //    fallback too (CE-S1: newtarget.html, newtarget-customized-
    //    builtins.html). The fallback re-reads NewTarget.prototype
    //    and changes nothing for a real object, so a NewTarget whose
    //    prototype IS that %Object.prototype% stays as it is.
    if (receiverHasActivePrototype(this_obj, active, current_context) or
        receiverHasRealmObjectPrototype(this_obj, new_target, isolate))
    {
        interface.handleNewTargetPrototypeFallback(info, this_obj, isolate, current_context, self.interface_name);
    }

    // 2-9, 12, 13 and 15: the host's. NewTarget BORROWED for the call.
    const constructed = hook.call(hook.host, realm, .{ .handle = .{ .ptr = @ptrCast(new_target) } }, self.interface_name) catch |err| {
        if (err == error.ExceptionPending) return;
        // TypeError (steps 5, 7.1, 8.2 and 13): of the active
        // function's realm.
        conv.throwWebIDLErrorFromContext(isolate, function_context, @errorName(err));
        return;
    };
    switch (constructed) {
        // 9. A new element: wrapped in the receiver, whose prototype is
        //    NewTarget's (9.1). The construction's result is the
        //    receiver, as for any constructor - unless the element's
        //    creation already wrapped it (an edge traced to it made
        //    its wrapper): that wrapper is then the element's, and
        //    takes the receiver's prototype as an upgrade's does
        //    (steps 14 and 16 below). Binding the receiver would
        //    replace it, and every edge drawn on it with it (a
        //    template's content, PR-M1); WrapperCache.set refuses.
        .created => |element| {
            if (interface.adoptExistingWrapper(info, this_obj, element, function_context)) return;
            receiver_taken = bindConstructedElement(self, this_obj, element, isolate) catch |err| {
                // Not cached: the new element is this construction's
                // to free (nothing else ever wrapped it), and the
                // construction throws (Codex row 15 Q22).
                element.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(element));
                conv.throwWebIDLErrorFromContext(isolate, function_context, @errorName(err));
                return;
            };
        },
        .upgrading => |element| {
            // 14. Perform ? element.[[SetPrototypeOf]](prototype). An
            //     ordinary object's answers false rather than throwing
            //     (non-extensible): a normal completion, so nothing is
            //     thrown.
            // 16. Return element: its wrapper is the construction's
            //     result (V8 takes an API constructor's object return
            //     value). The receiver is discarded, bound to nothing.
            if (interface.adoptExistingWrapper(info, this_obj, element, function_context)) return;
            // Never wrapped: the receiver becomes its wrapper, with
            // the prototype already set (step 14) - and is the result
            // (step 16).
            receiver_taken = bindConstructedElement(self, this_obj, element, isolate) catch |err| {
                // Not cached: the upgrading element stays the
                // construction stack's; the construction throws.
                conv.throwWebIDLErrorFromContext(isolate, function_context, @errorName(err));
                return;
            };
        },
    }
}

/// This interface's interface object in `context`: its FunctionTemplate's
/// instantiation there (one per context, so identity holds). OWNED.
fn activeInterfaceObject(self: *const Constructor, context: *v8.Context) ?*v8.Function {
    const template = template_registry.getTemplate(self.interface_name) orelse return null;
    return v8.v8_FunctionTemplate_GetFunction(template, context);
}

/// Whether V8 gave `receiver` the active function's own `prototype` -
/// what it does when NewTarget's is not an object (and when it is that
/// very object). The active function is an interface object, whose
/// `prototype` is a non-writable, non-configurable data property: the
/// read runs no script.
fn receiverHasActivePrototype(receiver: *v8.Object, active_function: ?*v8.Function, context: *v8.Context) bool {
    const function = active_function orelse return true;
    const isolate = v8.v8_Isolate_GetCurrent() orelse return true;
    const key = v8.v8_String_NewFromUtf8(isolate, "prototype", 9) orelse return true;
    defer v8.v8_String_Dispose(key);
    const active_prototype = v8.v8_Object_Get(@ptrCast(function), context, @ptrCast(key)) orelse return true;
    defer v8.v8_Value_Dispose(active_prototype);
    const prototype = v8.v8_Object_GetPrototypeV2(receiver) orelse return true;
    defer v8.v8_Value_Dispose(prototype);
    return v8.v8_Value_StrictEquals(prototype, active_prototype);
}

/// Whether V8 gave `receiver` %Object.prototype% of
/// GetFunctionRealm(`new_target`) - what it does for an API
/// constructor when NewTarget's `prototype` is not an object. A
/// prototype whose own [[Prototype]] is not null cannot be it, and is
/// answered without finding the realm.
fn receiverHasRealmObjectPrototype(receiver: *v8.Object, new_target: *v8.Value, isolate: *v8.Isolate) bool {
    const prototype = v8.v8_Object_GetPrototypeV2(receiver) orelse return false;
    defer v8.v8_Value_Dispose(prototype);
    if (!v8.v8_Value_IsObject(prototype)) return false;
    const above = v8.v8_Object_GetPrototypeV2(@ptrCast(prototype)) orelse return false;
    defer v8.v8_Value_Dispose(above);
    if (!v8.v8_Value_IsNull(above)) return false;
    const realm = interface.getFunctionRealm(new_target, isolate) orelse return false;
    defer v8.v8_Context_Dispose(realm);
    // An ordinary object made in that realm has its %Object.prototype%.
    const probe = v8.v8_Object_NewInContext(realm) orelse return false;
    defer v8.v8_Object_Dispose(probe);
    const object_prototype = v8.v8_Object_GetPrototypeV2(probe) orelse return false;
    defer v8.v8_Value_Dispose(object_prototype);
    return v8.v8_Value_StrictEquals(prototype, object_prototype);
}

/// The wrapper cache of `element`'s relevant realm.
fn elementWrapperCache(element: *runtime.Instance) ?*WrapperCache {
    const storage = element.ctx.getV8WrapperCacheStorage() orelse return null;
    return @ptrCast(@alignCast(storage));
}

/// Bind `element` to `receiver` - the object V8 made for NewTarget - as
/// the constructor path binds its instance: its Instance in the
/// internal fields, and the wrapper cache's entry. Whether the cache
/// took the receiver's handle.
fn bindConstructedElement(self: *const Constructor, receiver: *v8.Object, element: *runtime.Instance, isolate: *v8.Isolate) anyerror!bool {
    interface.setInstance(runtime.Instance, receiver, element);
    if (self.install_conditional_unforgeables) |install| {
        const context: *v8.Context = @ptrCast(@alignCast(element.ctx.engine_ctx orelse return false));
        install(isolate, context, receiver);
    }
    const cache = elementWrapperCache(element) orelse return false;
    // The element's receiver moves into its slot (its box goes): the
    // caller reads `receiver` no more.
    _ = cache.set(element, receiver, isolate) catch |err| {
        // Not cached (OutOfMemory): the receiver must not reach the
        // element, which nothing owns through it (Codex row 15 Q22).
        log.warn("a constructed {s}'s wrapper was not cached: {s}", .{ self.interface_name, @errorName(err) });
        unbindReceiver(receiver);
        return err;
    };
    return true;
}

/// Clear the internal field `setInstance` wrote on `receiver`, so a
/// receiver the wrapper cache did not take reaches no instance.
fn unbindReceiver(receiver: *v8.Object) void {
    if (v8.v8_Object_InternalFieldCount(receiver) >= 1) v8.v8_Object_SetAlignedPointerInInternalField(receiver, 0, null);
}

// ============================================================================
// Operations (WebIDL 3.7.6 "create an operation function")
// ============================================================================

/// What an operation's callback needs that is its own.
pub const Operation = struct {
    interface_name: []const u8,
    /// The operation's name as WebIDL spells it (the Zig name without its
    /// `call_` prefix), for the argument-count TypeError.
    operation_name: []const u8,
    /// Its return type is a promise: an exception rejects it (WebIDL 3.7.6;
    /// `rejectOnThrow`).
    returns_promise: bool,
    /// [CEReactions] on any function its dispatch can run
    /// (`interface.dispatchRunsCEReactions`): dispatched in a binding catch
    /// scope (`inBindingCatchScope`).
    ce_reactions: bool,
    /// The binding runs WebIDL's security check on `this` (Location's
    /// members, and the promise-returning members whose SecurityError
    /// rejects; `V8Interface.bindingChecksReceiver`).
    checks_receiver: bool,
    /// An overloaded operation's dispatch (`V8Interface.forwardToOverload`
    /// over its set): true when it handled the call. Null for one overload.
    forward_overload: ?*const fn (info: *const v8.FunctionCallbackInfo) bool,
    /// Whether converting an argument may make the engine keep the current
    /// context (`interface.typeRetainsContext`, an allowlist whose default
    /// is "retains"): then the binding does not release it.
    params_retain_context: bool,
    /// The interface is a [Global] one (Window): `this` resolves to a realm's
    /// Window.
    global_interface: bool,
    /// The operation's fewest required arguments (its `length`; 0: no check).
    required_arguments: usize,
    /// Whether `instance` implements the interface (`conv.implements`).
    implements: *const fn (instance: *const runtime.Instance) bool,
    /// The operation's own steps: its arguments converted, the impl called
    /// and its result converted (`V8Interface.callMethodWithArgs`). The
    /// result's handle, or null for undefined; `result_owned` says whether it
    /// is the binding's to release once set.
    invoke: *const fn (
        instance: *runtime.Instance,
        info: *const v8.FunctionCallbackInfo,
        allocator: std.mem.Allocator,
        isolate: *v8.Isolate,
        frame: *CallFrame,
        result_owned: *bool,
    ) anyerror!?*v8.Value,
    /// HTML's access report check for a CrossOriginProperties(Window)
    /// member (Chromium's make_report_coop_access): the property name the
    /// realm's report_window_access is told before the member's steps
    /// (protocol_realms.reportWindowAccess), or null for every other member.
    window_access: ?[]const u8 = null,
};

/// An operation function's steps (the generic MethodCallback's callback,
/// scoped and body), for the operation `self` describes.
pub fn operation(info: *const v8.FunctionCallbackInfo, self: *const Operation) void {
    // A DOM algorithm on the agent's stack until it returns
    // into script (dom_algorithm.zig; refcount design 9, risk 4).
    const algorithm = dom_algorithm.enter(info.getIsolate());
    defer dom_algorithm.leaveToScript(algorithm);
    var call: OperationCall = .{ .info = info, .operation = self };
    if (self.returns_promise) return rejectOnThrow(info, &call, OperationCall.scoped);
    call.scoped();
}

/// One call of an operation, as the data a catching run hands back to it.
const OperationCall = struct {
    info: *const v8.FunctionCallbackInfo,
    operation: *const Operation,

    /// A [CEReactions] operation is dispatched in a binding catch
    /// scope (engine.withPendingExceptionSetAside).
    fn scoped(call: *OperationCall) void {
        if (call.operation.ce_reactions) return inBindingCatchScope(call.info, call, OperationCall.body);
        call.body();
    }

    fn body(call: *OperationCall) void {
        operationBody(call.info, call.operation);
    }
};

/// WebIDL 3.7.6, for an operation whose return type is a promise: its steps -
/// the brand check, argument conversion and the operation itself - run with
/// an exception handler, and an exception becomes a promise rejected with it
/// (interface.zig's `rejectOnThrow`, for a call whose steps take data).
fn rejectOnThrow(info: *const v8.FunctionCallbackInfo, data: anytype, comptime steps: fn (@TypeOf(data)) void) void {
    const Thunk = struct {
        fn run(raw: ?*anyopaque) callconv(.c) void {
            steps(@ptrCast(@alignCast(raw.?)));
        }
    };
    const isolate = info.getIsolate();
    var thrown: ?*v8.Value = null;
    if (!v8.v8_RunCatching(isolate, Thunk.run, @ptrCast(data), &thrown)) return;
    const reason = thrown orelse return;
    defer v8.v8_Value_Dispose(reason);
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);
    const resolver = v8.v8_PromiseResolver_New(context) orelse return;
    defer v8.v8_PromiseResolver_Dispose(resolver);
    _ = v8.v8_PromiseResolver_Reject(resolver, context, reason);
    const promise = v8.v8_PromiseResolver_GetPromise(resolver) orelse return;
    defer v8.v8_Promise_Dispose(promise);
    info.setReturnValue(@ptrCast(promise));
}

/// Run `steps(data)` in a binding catch scope (v8_wrapper.cpp, "Binding
/// catch scopes"; interface.zig's `inBindingCatchScope`, for a call whose
/// steps take data).
fn inBindingCatchScope(info: *const v8.FunctionCallbackInfo, data: anytype, comptime steps: fn (@TypeOf(data)) void) void {
    const Thunk = struct {
        fn run(raw: ?*anyopaque) callconv(.c) void {
            steps(@ptrCast(@alignCast(raw.?)));
        }
    };
    v8.v8_RunInBindingCatchScope(info.getIsolate(), Thunk.run, @ptrCast(data));
}

fn operationBody(info: *const v8.FunctionCallbackInfo, self: *const Operation) void {
    // WebIDL operation 2.1.2.2 / HTML 7.2.1.1. Location's
    // Proxy needs an explicit check; promise-returning members
    // keep this inside rejectOnThrow. Cross-origin replace is
    // allowed by the same table that configures V8's checks.
    if (self.checks_receiver) {
        if (!@import("cross_origin.zig").receiverIsAccessible(info)) {
            const isolate = info.getIsolate();
            if (v8.v8_Isolate_GetCurrentContext(isolate)) |current| {
                // Owned: a fresh Global<Context>, used only to pick the realm.
                defer v8.v8_Context_Dispose(current);
                conv.throwWebIDLErrorFromContext(isolate, current, "SecurityError");
            }
            return;
        }
    }
    // An overloaded operation is installed as its FIRST
    // overload; pick the one the arguments mean.
    if (self.forward_overload) |forward| {
        if (forward(info)) return;
    }

    const isolate = info.getIsolate();

    // The call's contexts, made when a step asks for one (perf3 phase 1b):
    // the CURRENT context, where arguments convert (input comes from the
    // caller's realm), for a conversion that needs it; the function's
    // creation context - the METHOD's realm, where an error is thrown and an
    // object result is made (other.SomeInterface.prototype.method.call(obj)
    // must answer with `other`'s prototypes: WPT default-toJSON-cross-realm)
    // - for an error or such a result. An operation whose arguments are
    // Strings, Numbers, booleans or platform objects and whose result is a
    // string, a number, a boolean or null makes neither: two Globals per
    // call before.
    //
    // The current context is the conversion's to keep when converting one of
    // the arguments may make the engine keep it (`conv.fromV8Value` stores it
    // into a persistent `runtime.CallbackWrapper` for callback-typed
    // parameters, so `createElement(DOMString)` is transient while
    // `setTimeout(TimerHandler, ...)` is not). `typeRetainsContext` is an
    // ALLOWLIST of provably inert types and answers "retains" for anything it
    // does not recognise. That direction matters: written as a blocklist,
    // this exact check released a context `setTimeout` still needed and
    // produced 10 crashes out of 12 files. See
    // tests/v8/retention_predicate_test.zig.
    var frame = CallFrame.init(info, self.params_retain_context);
    defer frame.release();

    // Get allocator
    const isolate_alloc = @import("isolate_allocator.zig");
    const allocator = isolate_alloc.getOrInitAllocator(isolate, std.heap.c_allocator) catch {
        conv.throwError(isolate, "Failed to get isolate allocator");
        return;
    };

    const instance = operationReceiver(self, info, isolate) orelse {
        // Throw TypeError from method's realm (function's creation context)
        // Per WebIDL spec: "Throw a TypeError using the function's realm."
        throwInFunctionRealm(&frame, .type_error, "Illegal invocation");
        return;
    };

    // WebIDL "create an operation function" step 2.4: "If O does
    // not implement the interface target, throw a TypeError."
    // Nothing above asks that of every receiver: the implicit-this
    // path hands back the realm's GLOBAL for a null `this` whatever
    // the interface (idlharness calls every operation as
    // `op.apply(null, args)`), and a wrapper's one internal field is
    // its instance, with no type beside it (lane v8up A0: field 1's
    // WrapperTypeInfo, kept for 24 interfaces, is gone). The impl
    // would then read another interface's
    // state as its own: `XMLHttpRequest.open` on the Window died on
    // `_internal.?`. The state ancestry is the brand check; an
    // instance whose vtable carries none implements nothing
    // (`conv.implements`: only a test's hand-made vtable lacks
    // one).
    if (!self.implements(instance)) {
        throwInFunctionRealm(&frame, .type_error, "Illegal invocation");
        return;
    }

    // Step 3: too few arguments is a TypeError, in the
    // operation's realm, before any is converted.
    if (throwIfTooFewArguments(self, info, &frame)) return;

    // HTML 7.1.3.3: the access is checked for a report before the steps.
    if (self.window_access) |property| @import("protocol_realms.zig").reportWindowAccess(instance, property);

    // Call the method with appropriate arguments
    // CROSS-REALM SUPPORT: the frame gives the method's realm for a result
    // object made there
    var result_owned = false;
    const result = self.invoke(instance, info, allocator, isolate, &frame, &result_owned) catch |err| {
        // ExceptionPending means an exception was already rethrown during conversion
        if (err == conv.ConversionError.ExceptionPending) {
            return;
        }
        // Throw proper DOMException for WebIDL errors
        if (frame.functionContext()) |realm| {
            interface.throwMemberError(isolate, realm, err);
        } else {
            conv.throwError(isolate, @errorName(err));
        }
        return;
    };

    // Convert and set return value. setReturnValue copies, so a
    // handle the conversion made or the impl handed over is
    // released here - kept, a promise or an object pinned its
    // whole page. A result set straight into the return slot
    // (`setDirectResult`) comes back as null.
    if (result) |v8_result| {
        info.setReturnValue(v8_result);
        if (result_owned) v8.v8_Global_Dispose(v8_result);
    }
    // If result is null, V8 will return undefined (correct for void methods)
}

/// The instance an operation's `this` is, or null when it is none - the
/// caller throws "Illegal invocation".
fn operationReceiver(self: *const Operation, info: *const v8.FunctionCallbackInfo, isolate: *v8.Isolate) ?*runtime.Instance {
    // A non-[Global] interface's receiver, read from `info` with no handle
    // (`thisInstance`, as the attribute getter reads it): a Global<Object>
    // per call before (perf3 phase 1b). A freed instance's poisoned pointer
    // is none, as `interface.getInstance` answered. Whether it implements
    // this interface is the caller's check (operationBody step 2.4).
    // A Window found there - `this` is a WindowProxy, whose field 0 names
    // the Window it reaches NOW - and any [Global] interface's receiver go
    // through THE Window-receiver rule (realm_global.receiverRealm): an
    // EventTarget member used contextually in a realm whose WindowProxy went
    // on acts on that realm's own Window (design 2.3, the ruling).
    if (!self.global_interface) {
        if (thisInstance(info)) |found| {
            if (!isPoisoned(@intFromPtr(found))) {
                const instance: *runtime.Instance = @ptrCast(@alignCast(found));
                if (!isWindowInstance(instance)) return instance;
            }
        }
    }
    const this_obj = info.getThis();
    defer v8.v8_Object_Dispose(this_obj);
    if (!self.global_interface) {
        // Non-[Global] interface: `this`'s instance, whose interface the
        // caller checks (operationBody step 2.4, the state ancestry).
        if (interface.getInstance(runtime.Instance, this_obj)) |inst| {
            if (!isWindowInstance(inst)) return inst;
        }
    }
    // A [Global] interface's receiver, a Window `this`, or a `this` with no
    // instance - the global V8 made a missing receiver in sloppy mode
    // (WebIDL 3.8: the operation's own global) - by the rule.
    return @ptrCast(@alignCast(windowOf(isolate, this_obj)));
}

/// WebIDL "create an operation function" step 3, the overload
/// resolution algorithm, for the argument count alone: an operation's
/// effective overload set has an entry for each number of arguments
/// it can be called with, and none below the fewest it requires, so
/// the algorithm throws a TypeError there - before any argument is
/// converted. (A missing required DOMString used to convert as "", so
/// `localStorage.getItem()` returned null instead of throwing.)
/// True when it threw.
fn throwIfTooFewArguments(self: *const Operation, info: *const v8.FunctionCallbackInfo, frame: *CallFrame) bool {
    const required = self.required_arguments;
    if (required == 0) return false;
    const given: usize = @intCast(@max(info.length(), 0));
    if (given >= required) return false;
    var buffer: [256]u8 = undefined;
    const message = std.fmt.bufPrint(&buffer, "Failed to execute '{s}' on '{s}': {d} argument{s} required, but only {d} present.", .{ self.operation_name, self.interface_name, required, if (required == 1) "" else "s", given }) catch "Not enough arguments";
    throwInFunctionRealm(frame, .type_error, message);
    return true;
}

// ============================================================================
// [Global] receivers
// ============================================================================

/// THE Window-receiver rule every Window member callback goes through -
/// accessors, operations, the indexed interceptor
/// (context_manager.windowIndexedPropertyGetter) and the lazy interface
/// objects (global_constructor_handler): realm_global.receiverRealm, whose
/// comment carries the rule, the probe and the KNOWN DEVIATION. `receiver`
/// is This() (BORROWED). The answer is the receiver realm's global object: a
/// Window, or a worker's or worklet's global scope for their own [Global]
/// members. Null: none - "Illegal invocation".
pub fn windowOf(isolate: *v8.Isolate, receiver: *v8.Object) ?*anyopaque {
    return @ptrCast(realm_global.globalOfReceiver(isolate, receiver, .member));
}

/// Whether `instance` is a Window - a realm's global platform object, which
/// script only ever reaches through a WindowProxy.
fn isWindowInstance(instance: *const runtime.Instance) bool {
    return std.mem.eql(u8, instance.vtable.name, "Window");
}

// ============================================================================
// Attribute getters (WebIDL 3.7.6 "the attribute getter")
// ============================================================================

/// The realm a getter's thrown error is made in. WebIDL: "throw a TypeError
/// using the function's realm" - the getter's creation context, or the
/// current one when V8 knows none. Only the throwing paths use it, and each
/// is a fresh Global<Context> the caller owns, so it is taken on the first
/// throw, not on every call: taken eagerly, the two were made and disposed per
/// `list.length` - a third of the binding's cost in a profile of
/// NodeList-static-length-getter-tampered-1.html (2026-10-01). Released on
/// every exit (the per-element context leak this once was: 1.00 per
/// createElement, one per `document` / `el.id` read).
pub const ErrorRealm = struct {
    info: *const v8.FunctionCallbackInfo,
    isolate: *v8.Isolate,
    owned: ?*v8.Context = null,

    pub fn get(self: *ErrorRealm) ?*v8.Context {
        if (self.owned == null) {
            self.owned = self.info.getFunctionCreationContext() orelse
                v8.v8_Isolate_GetCurrentContext(self.isolate);
        }
        return self.owned;
    }

    pub fn throwTypeError(self: *ErrorRealm, message: []const u8) void {
        if (self.get()) |realm| {
            conv.throwTypeErrorFromContext(self.isolate, realm, message);
        } else {
            conv.throwError(self.isolate, message);
        }
    }

    pub fn release(self: *ErrorRealm) void {
        if (self.owned) |c| v8.v8_Context_Dispose(c);
        self.owned = null;
    }
};

/// What an attribute's getter callback needs that is its own.
pub const Getter = struct {
    interface_name: []const u8,
    /// The impl function's name (`get_<attribute>`), for the debug trace.
    getter_name: []const u8,
    kind: Kind,
    /// WebIDL attribute getter 1.1.2.2 / HTML 7.2.1.1: Location's Proxy
    /// checks its platform target (`V8Interface.acceptsAnyReceiver`).
    checks_receiver: bool,
    /// Window's `window`: answered without its Window (`answerWindowGetter`).
    answers_window: bool,
    /// A handle for `this` is used: a [Global] interface compares it with
    /// globals, and a [SameObject] attribute draws an edge from it.
    needs_this_handle: bool,
    /// [LegacyLenientThis]: a `this` that is no instance reads undefined.
    lenient_this: bool,
    /// The interface is a [Global] one (Window).
    global_interface: bool,
    /// Window's self, window and frames return `this`, the global proxy.
    returns_global_this: bool,
    /// Whether `instance` implements the interface (`conv.implements`).
    implements: *const fn (instance: *const runtime.Instance) bool,
    /// The attribute's own steps for an instance: call the impl's getter,
    /// convert its result and set it (`finishGetter`), or throw what it
    /// failed with (`getterFailed`).
    read: ?*const fn (info: *const v8.FunctionCallbackInfo, instance: *runtime.Instance, this_handle: ?*v8.Object, error_realm: *ErrorRealm) void,
    /// A constant's getter (no instance): sets its value.
    read_constant: ?*const fn (info: *const v8.FunctionCallbackInfo) void,
    /// HTML's access report check for a CrossOriginProperties(Window)
    /// member (Chromium's make_report_coop_access): the property name the
    /// realm's report_window_access is told before the member's steps
    /// (protocol_realms.reportWindowAccess), or null for every other member.
    window_access: ?[]const u8 = null,

    pub const Kind = enum {
        /// The impl's getter returns void: a skipped property.
        not_implemented,
        /// A constant: the getter takes no instance.
        constant,
        instance,
    };
};

/// An attribute getter function's steps (the generic
/// PropertyGetterCallback's callback), for the attribute `self` describes.
pub fn attributeGetter(info: *const v8.FunctionCallbackInfo, self: *const Getter) void {
    // Use compile-time debug logging to avoid runtime overhead
    // This is called on every property access, so must be zero-cost when disabled
    debug.print("[PropertyGetterCallback] Called for {s}.{s}\n", .{ self.interface_name, self.getter_name });
    // A DOM algorithm on the agent's stack until it returns
    // into script (dom_algorithm.zig; refcount design 9, risk 4).
    const algorithm = dom_algorithm.enter(info.getIsolate());
    defer dom_algorithm.leaveToScript(algorithm);

    const isolate_inner = info.getIsolate();

    var error_realm: ErrorRealm = .{ .info = info, .isolate = isolate_inner };
    defer error_realm.release();

    // WebIDL attribute getter 1.1.2.2 / HTML 7.2.1.1: a
    // Proxy's borrowed getter must check its platform target.
    if (self.checks_receiver) {
        if (!@import("cross_origin.zig").receiverIsAccessible(info)) {
            if (error_realm.get()) |realm| conv.throwWebIDLErrorFromContext(isolate_inner, realm, "SecurityError");
            return;
        }
    }

    switch (self.kind) {
        // Skip void return types (skipped properties)
        .not_implemented => {
            conv.throwError(isolate_inner, "Property not implemented");
            return;
        },
        // Static getter (constants)
        .constant => {
            self.read_constant.?(info);
            return;
        },
        .instance => {},
    }

    // `window` needs no Window (see answerWindowGetter).
    if (self.answers_window) {
        if (answerWindowGetter(info, self.window_access)) return;
    }

    // Instance getter - extract instance from 'this' and call.
    //
    // A handle for `this` only where one is used: a [Global]
    // interface compares it with globals and asks its
    // creation context, and a [SameObject] attribute draws an
    // edge from it. Every other getter reads the receiver's
    // internal field from `info` (thisInstance), which
    // makes no handle: the Global, made and disposed per read,
    // was most of `list.length` in NodeList-static-length-
    // getter-tampered-[123].html (~6e7 reads each).
    const this_handle: ?*v8.Object = if (self.needs_this_handle) info.getThis() else null;
    defer if (this_handle) |held| v8.v8_Object_Dispose(held);

    // Check if this is a [LegacyLenientThis] attribute
    // Per WebIDL §4.3.10: these attributes do NOT throw TypeError on invalid this
    // Instead, getters return undefined
    const is_lenient_this = self.lenient_this;

    // For [Global] interfaces (like Window): THE Window-receiver rule
    // (windowOf, realm_global.receiverRealm). A null or undefined `this` is
    // the method's own global by then (V8 makes a missing receiver the
    // function's global proxy), another realm's WindowProxy acts on its
    // Window, and anything else throws a TypeError from the method's realm.
    const resolved_instance: ?*anyopaque = blk: {
        if (self.global_interface) {
            // THE Window-receiver rule (windowOf): the method's own global
            // (a missing receiver V8 made it), a realm's WindowProxy, or V8's
            // detached copy of one; anything else - Object.create(Window.
            // prototype), a plain object - is no Window, and throws below.
            if (windowOf(isolate_inner, this_handle.?)) |window| break :blk window;
            // Fall through to throw TypeError
        } else {
            // Non-[Global] interface: use normal this handling
            //
            // We MUST verify that `this` is actually an instance of this interface
            // BEFORE using the internal field pointer. This is critical because in
            // sloppy mode, `getter.call(null)` coerces null to the global object (Window),
            // which HAS internal fields but is NOT an instance of this interface.
            // Without this check, we'd pass the Window's internal pointer to the getter,
            // causing InvalidStateError instead of the correct TypeError.
            //
            // Per WebIDL spec:
            // - For regular attributes: throw TypeError if `this` is not a valid instance
            // - For [LegacyLenientThis]: return undefined if `this` is not a valid instance

            // The brand check is the instance's state ancestry (`self.implements`
            // below): per instance, so it holds across realms, where each realm
            // has its own prototype objects, and whatever an object's prototype
            // says. Per WebIDL 3.7.6: "If O is not a platform object that
            // implements the interface, throw a TypeError". `this`'s instance is
            // read from `info` with no handle (`thisInstance`); a wrapper keeps
            // no WrapperTypeInfo beside it (lane v8up A0).
            if (thisInstance(info)) |instance_ptr| break :blk instance_ptr;
            // [LegacyLenientThis] - return undefined instead of throwing
            if (is_lenient_this) {
                conv.setReturnUndefined(info);
                return;
            }
        }

        // [LegacyLenientThis] on a [Global] interface (Window's
        // onmouseenter, onmouseleave): `this` is no Window -
        // return undefined (WebIDL 3.7.6 step 1.2.1).
        if (is_lenient_this) {
            conv.setReturnUndefined(info);
            return;
        }

        // Throw TypeError from getter's realm (function's creation context)
        // Per WebIDL spec: "Throw a TypeError using the function's realm."
        error_realm.throwTypeError("Illegal invocation");

        return;
    };

    // Shouldn't happen - we either have a valid instance or returned above
    if (resolved_instance == null) {
        error_realm.throwTypeError("Illegal invocation");
        return;
    }

    // Safety check: detect use-after-free by checking for poison patterns
    // Common allocator poison values: 0xaaaa... (freed), 0xdead... (deleted)
    const ptr_as_int = @intFromPtr(resolved_instance.?);
    if (isPoisoned(ptr_as_int)) {
        // Instance was freed - return undefined to prevent crash
        conv.setReturnUndefined(info);
        return;
    }

    const instance: *runtime.Instance = @ptrCast(@alignCast(resolved_instance.?));

    if (!self.implements(instance)) {
        if (self.lenient_this) {
            conv.setReturnUndefined(info);
        } else {
            error_realm.throwTypeError("Illegal invocation");
        }
        return;
    }

    // Additional safety check: validate instance.ctx is not corrupted
    // This catches cases where the Instance struct was freed but V8 still holds a reference
    const ctx_as_int = @intFromPtr(instance.ctx);
    if (isPoisoned(ctx_as_int) or ctx_as_int == 0) {
        // Instance was freed - return undefined to prevent crash
        conv.setReturnUndefined(info);
        return;
    }

    // Deep validation: check if the allocator inside ContextData is valid
    // The ctx pointer may be valid, but the ContextData contents may be freed
    const allocator_vtable_int = @intFromPtr(instance.ctx.allocator.vtable);
    if (isPoisoned(allocator_vtable_int) or allocator_vtable_int == 0) {
        // ContextData was freed - return undefined to prevent crash
        conv.setReturnUndefined(info);
        return;
    }

    // SPECIAL HANDLING: Window.self and Window.window must return the V8 global object
    // Per HTML spec, these properties return the WindowProxy which IS the global object.
    // testharness.js relies on this: (function(global_scope){...})(self)
    // If we return a wrapped Window instance instead of the actual global, the
    // exposed functions won't be accessible as global variables.
    // HTML 7.1.3.3: the access is checked for a report before the steps
    // (DOMWindow::ReportCoopAccess in Chromium's generated getter).
    if (self.window_access) |property| @import("protocol_realms.zig").reportWindowAccess(instance, property);

    if (self.returns_global_this) {
        // Return info.This() - the actual receiver object
        // For a property access on the global, this is the global proxy
        // that JS uses for variable resolution
        // Owned, like every getThis(): the return value
        // is a copy, so the handle goes when this returns.
        // Kept, it leaked one handle to the global per
        // `window`/`self` read - and a handle to the
        // global pins its whole page.
        const global_this = info.getThis();
        defer v8.v8_Object_Dispose(global_this);
        info.setReturnValue(@ptrCast(global_this));
        return;
    }

    self.read.?(info, instance, this_handle, &error_realm);
}

const poison_pattern_aa: usize = 0xaaaaaaaaaaaaaaaa;
const poison_pattern_dead: usize = 0xdeaddeaddeaddead;

/// An address an allocator's poison fills in: freed (0xaaaa...) or deleted
/// (0xdead...) memory.
fn isPoisoned(address: usize) bool {
    return address == poison_pattern_aa or address == poison_pattern_dead or
        (address & 0xFFFF000000000000) == 0xaaaa000000000000;
}

/// A getter's failure: thrown in the getter's realm (`error_realm`), but
/// NotImplemented reads undefined.
pub fn getterFailed(info: *const v8.FunctionCallbackInfo, err: anyerror, error_realm: *ErrorRealm) void {
    const isolate_inner = info.getIsolate();
    if (err == error.NotImplemented) {
        // For WPT constructor tests, don't throw for unimplemented properties
        // when they are accessed during global object enumeration
        conv.setReturnUndefined(info);
        return;
    }
    // The error is the getter's realm's - a SecurityError
    // too (throwMemberError says why): the cross-origin
    // checks are V8's [cross_origin_objects]. Without them,
    // a SecurityError is made in the CALLER's (entered)
    // realm, as the impls' own checks needed. Each context
    // is a fresh Global, owned, used only to pick the realm.
    const entered_ctx = if (comptime engine_capabilities.cross_origin_objects == .unsupported)
        v8.v8_Isolate_GetEnteredOrMicrotaskContext(isolate_inner)
    else
        null;
    defer if (entered_ctx) |ctx| v8.v8_Context_Dispose(ctx);
    const getter_context = error_realm.get();
    const error_context = if (err == error.SecurityError)
        entered_ctx orelse getter_context
    else
        getter_context;
    if (error_context) |ctx| {
        conv.throwWebIDLErrorFromContext(isolate_inner, ctx, @errorName(err));
    } else {
        conv.throwError(isolate_inner, @errorName(err));
    }
}

const engine_capabilities = @import("protocol.zig").capabilities;

/// A [SameObject] attribute's edge from its owner's wrapper to the child's
/// (`recordSameObjectEdge`), drawn once the child's value is made.
pub const SameObjectEdge = struct {
    owner: *v8.Object,
    prop_name: []const u8,
};

/// A getter's result: converted and set as the callback's return value, and
/// what the binding owns of it released - the steps every attribute whose
/// result is a `PayloadType` shares (`byte_string`: a [ByteString]
/// attribute). Instantiated per result type, not per attribute. `result`'s
/// string, when it is one the impl allocated, is freed with
/// `cleanup_allocator` - captured before the getter ran, as a collection the
/// conversion triggers may free the instance's context.
pub fn finishGetter(
    comptime PayloadType: type,
    comptime byte_string: bool,
    info: *const v8.FunctionCallbackInfo,
    result: PayloadType,
    cleanup_allocator: std.mem.Allocator,
    same_object: ?SameObjectEdge,
) void {
    const isolate_inner = info.getIsolate();
    // For string types that allocate memory, free after V8 conversion.
    // IMPORTANT: Impls MUST use instance.ctx.allocator for returned strings,
    // not internal.allocator, so this cleanup uses the correct allocator.
    // Static strings (empty string "") have len=0 and won't be freed.
    // NOTE: We use cleanup_allocator captured before the getter call to avoid
    // use-after-free if V8 operations during conversion trigger GC.
    //
    // IMPORTANT: Getters that return internal references (not newly allocated)
    // MUST be updated to dupe the string first, or the cleanup will double-free.
    // NOTE: JSValue is NOT cleaned up here because getters typically return
    // internal state references (e.g., MessageEvent.data). Operations that
    // allocate new JSValue data (like structuredClone) are cleaned up in
    // callMethodWithArgs instead.
    // Check for both direct string types and optional string types (?DOMString, etc.)
    const is_optional_type = comptime @typeInfo(PayloadType) == .optional;
    const inner_type = comptime if (is_optional_type) @typeInfo(PayloadType).optional.child else PayloadType;
    const needs_cleanup = comptime (inner_type == runtime.USVString or inner_type == []const u8 or inner_type == runtime.DOMString);

    defer if (needs_cleanup) {
        // Re-validate allocator before cleanup - it could have been invalidated
        const cleanup_vtable_int = @intFromPtr(cleanup_allocator.vtable);
        const is_poisoned = (isPoisoned(cleanup_vtable_int) or cleanup_vtable_int == 0);
        if (!is_poisoned) {
            // Handle optional types - unwrap first using comptime branching
            if (comptime is_optional_type) {
                if (result) |val| {
                    if (inner_type == runtime.DOMString) {
                        var mutable = val;
                        mutable.deinit(cleanup_allocator);
                    } else if (inner_type == runtime.USVString or inner_type == []const u8) {
                        if (val.len > 0) {
                            cleanup_allocator.free(val);
                        }
                    }
                }
            } else {
                if (inner_type == runtime.DOMString) {
                    var mutable = result;
                    mutable.deinit(cleanup_allocator);
                } else if (inner_type == runtime.USVString or inner_type == []const u8) {
                    if (result.len > 0) {
                        cleanup_allocator.free(result);
                    }
                }
            }
        }
        // else: Allocator was freed during V8 operations - skip cleanup
        // This leaks memory but prevents crash. The memory will be
        // reclaimed when the context/isolate is disposed.
    };

    // A number or boolean goes straight into the return
    // slot: no Global to make and release per read (200,000
    // v8_Number_New for 200,000 `list.length` reads). The
    // value is the one the conversions below give: a WebIDL
    // integer type up to 32 bits as that integer, a 64-bit
    // one or a float as the double it converts to, a
    // boolean as itself (WebIDL 3.2.x, "converted to an
    // ECMAScript value").
    if (comptime interface.primitiveGetterResult(PayloadType)) {
        interface.setPrimitiveReturn(info, PayloadType, result);
        return;
    }

    // A string, an enumeration value or a null result goes straight into the
    // return slot as well: made in V8's callback scope, no Global to make and
    // release per read (perf3 phase 1b: `el.id` made one Global per read,
    // and its release took two process-wide locks). The values are the ones
    // the conversions below give (WebIDL 3.2.10/3.2.12 "converted to an
    // ECMAScript value": the String of the same code units; 3.2.24 an
    // enumeration value's String; null). A [SameObject] getter keeps the
    // path below: its edge needs the value.
    if (comptime !byte_string and directGetterResult(PayloadType)) {
        if (same_object == null) {
            setDirectResult(info, PayloadType, result);
            return;
        }
    }

    // Convert to V8 using comptime type dispatch
    const v8_value: *v8.Value = comptime_convert: {
        if (comptime byte_string) {
            break :comptime_convert conv.byteStringToV8(PayloadType, isolate_inner, result) catch
                (v8.v8_Undefined(isolate_inner) orelse unreachable);
        }
        // WebIDL primitive types
        // Handle all unsigned integer types (u8, u16, u32)
        if (PayloadType == u32 or PayloadType == runtime.UnsignedLong) {
            break :comptime_convert @ptrCast(conv.toV8UnsignedLong(isolate_inner, result));
        } else if (PayloadType == u16) {
            // WebIDL unsigned short (u16) - convert to u32 for V8
            break :comptime_convert @ptrCast(conv.toV8UnsignedLong(isolate_inner, @as(u32, result)));
        } else if (PayloadType == u8) {
            // WebIDL octet (u8) - convert to u32 for V8
            break :comptime_convert @ptrCast(conv.toV8UnsignedLong(isolate_inner, @as(u32, result)));
        } else if (PayloadType == i32 or PayloadType == runtime.Long) {
            break :comptime_convert @ptrCast(conv.toV8Long(isolate_inner, result));
        } else if (PayloadType == i16) {
            // WebIDL short (i16) - convert to i32 for V8
            break :comptime_convert @ptrCast(conv.toV8Long(isolate_inner, @as(i32, result)));
        } else if (PayloadType == i8) {
            // WebIDL byte (i8) - convert to i32 for V8
            break :comptime_convert @ptrCast(conv.toV8Long(isolate_inner, @as(i32, result)));
        } else if (PayloadType == u64 or PayloadType == runtime.UnsignedLongLong) {
            const val: f64 = @floatFromInt(result);
            break :comptime_convert @ptrCast(v8.v8_Number_New(isolate_inner, val));
        } else if (PayloadType == ?u64) {
            // Optional u64 - null or number
            if (result) |num| {
                const val: f64 = @floatFromInt(num);
                break :comptime_convert @ptrCast(v8.v8_Number_New(isolate_inner, val));
            } else {
                break :comptime_convert v8.v8_Null(isolate_inner) orelse unreachable;
            }
        } else if (PayloadType == i64 or PayloadType == runtime.LongLong) {
            const val: f64 = @floatFromInt(result);
            break :comptime_convert @ptrCast(v8.v8_Number_New(isolate_inner, val));
        } else if (PayloadType == ?i64) {
            // Optional i64 - null or number
            if (result) |num| {
                const val: f64 = @floatFromInt(num);
                break :comptime_convert @ptrCast(v8.v8_Number_New(isolate_inner, val));
            } else {
                break :comptime_convert v8.v8_Null(isolate_inner) orelse unreachable;
            }
        } else if (PayloadType == f64 or PayloadType == runtime.Double) {
            break :comptime_convert @ptrCast(v8.v8_Number_New(isolate_inner, result));
        } else if (PayloadType == f32 or PayloadType == runtime.Float) {
            break :comptime_convert @ptrCast(v8.v8_Number_New(isolate_inner, @floatCast(result)));
        } else if (PayloadType == bool or PayloadType == runtime.Boolean) {
            break :comptime_convert v8.v8_Boolean_New(isolate_inner, result) orelse unreachable;
        } else if (PayloadType == runtime.DOMString) {
            break :comptime_convert @ptrCast(conv.toV8String(isolate_inner, result));
        } else if (PayloadType == ?runtime.DOMString) {
            // Optional DOMString - null or convert to string
            if (result) |str| {
                break :comptime_convert @ptrCast(conv.toV8String(isolate_inner, str));
            } else {
                break :comptime_convert v8.v8_Null(isolate_inner) orelse unreachable;
            }
        } else if (PayloadType == runtime.USVString or PayloadType == []const u8) {
            // USVString is []const u8 - convert to V8 string
            if (conv.newStringFromWtf8(isolate_inner, result)) |str| {
                break :comptime_convert str;
            } else {
                break :comptime_convert v8.v8_Undefined(isolate_inner) orelse unreachable;
            }
        } else if (@typeInfo(PayloadType) == .@"enum") {
            // WebIDL enum - convert to string using @tagName
            // This is a runtime conversion so we use a helper function
            break :comptime_convert @ptrCast(conv.enumToV8String(PayloadType, isolate_inner, result));
        } else if (PayloadType == *runtime.Instance or comptime isRuntimeInstancePtr(PayloadType)) {
            // Instance pointer - wrap with correct V8 prototype
            // This handles both *runtime.Instance directly and typedefs like WindowProxy
            break :comptime_convert @ptrCast(conv.instanceToV8(isolate_inner, result));
        } else if (PayloadType == ?*runtime.Instance or comptime isOptionalRuntimeInstancePtr(PayloadType)) {
            // Optional Instance pointer - null or wrap
            if (result) |inst| {
                break :comptime_convert @ptrCast(conv.instanceToV8(isolate_inner, inst));
            } else {
                break :comptime_convert v8.v8_Null(isolate_inner) orelse unreachable;
            }
        } else if (PayloadType == *const anyopaque) {
            // SAFETY: Cannot blindly cast *const anyopaque to V8 Value.
            // These are often Zig-side objects (like *runtime.Instance for
            // Promise returns) that need proper wrapping, not raw casting.
            // For now, return undefined to prevent crashes.
            // TODO: Implement proper Promise creation for [NewObject] methods
            break :comptime_convert v8.v8_Undefined(isolate_inner) orelse unreachable;
        } else if (PayloadType == runtime.JSValue) {
            // JSValue - use conv.toV8Value to convert to V8 Value
            // This handles all JSValue variants: undefined, null, boolean, number, string, handle, instance
            const current_context = v8.v8_Isolate_GetCurrentContext(isolate_inner) orelse {
                break :comptime_convert v8.v8_Undefined(isolate_inner) orelse unreachable;
            };
            // Owned: v8_Isolate_GetCurrentContext allocates a Global per call.
            defer v8.v8_Context_Dispose(current_context);
            const v8_converted = conv.toV8Value(runtime.JSValue, isolate_inner, current_context, result) catch {
                break :comptime_convert v8.v8_Undefined(isolate_inner) orelse unreachable;
            };
            break :comptime_convert v8_converted;
        } else if (comptime isOptionalCallbackType(PayloadType)) {
            // An optional callback function type (EventHandler is
            // ?EventHandlerNonNull, a function pointer): the value
            // is the function's Global<Value>* (conversions.zig,
            // UNTAGGED - a tag in a function pointer's low bits is
            // illegal behaviour an optimized build acts on), which
            // is what setReturnValue reads. Null is JavaScript null.
            if (result) |function_value| {
                const address: usize = @intFromPtr(function_value);
                break :comptime_convert @ptrFromInt(address);
            } else {
                break :comptime_convert v8.v8_Null(isolate_inner) orelse unreachable;
            }
        } else {
            // For complex types (unions, optionals, etc.), use conv.toV8Value
            // which handles all types including optional unions like MessageEventSource
            const current_context = v8.v8_Isolate_GetCurrentContext(isolate_inner) orelse {
                break :comptime_convert v8.v8_Undefined(isolate_inner) orelse unreachable;
            };
            // Owned: v8_Isolate_GetCurrentContext allocates a Global per call.
            defer v8.v8_Context_Dispose(current_context);
            const v8_converted = conv.toV8Value(PayloadType, isolate_inner, current_context, result) catch {
                break :comptime_convert v8.v8_Undefined(isolate_inner) orelse unreachable;
            };
            break :comptime_convert v8_converted;
        }
    };

    // [SameObject]: the owner hands out one child for its
    // whole life, and caches it as a bare pointer (the
    // generated `cached_<name>`). Nothing in script need
    // hold the child, so tie its wrapper to the owner's -
    // Blink traces the same edge - or a collection frees it
    // under the cache.
    if (same_object) |edge| {
        recordSameObjectEdge(isolate_inner, edge.owner, edge.prop_name, v8_value);
    }

    info.setReturnValue(v8_value);
    // setReturnValue reads the handle into a Local. A value the
    // conversion above made is ours: every number, boolean,
    // string and enum read leaked a Global - 200,000
    // `v8_Number_New`s for 200,000 `list.length` reads. So is
    // every JSValue result but an instance's wrapper: a handle
    // the impl returns is the binding's (engine.Owned.take),
    // and the other arms are made here.
    if (comptime interface.getterValueIsOwned(PayloadType)) {
        v8.v8_Global_Dispose(v8_value);
    } else if (comptime PayloadType == runtime.JSValue) {
        if (result != .instance) v8.v8_Global_Dispose(v8_value);
        // A string the impl made for the result is the
        // binding's too, as an operation's is
        // (callMethodWithArgs): xhr.response's text
        // leaked on every read. A string the impl keeps
        // goes out as a reference (`owned` false), which
        // this leaves alone.
        interface.freeOwnedString(cleanup_allocator, result);
    } else if (comptime PayloadType == ?runtime.JSValue) {
        if (result == null or result.? != .instance) v8.v8_Global_Dispose(v8_value);
        if (result) |value| interface.freeOwnedString(cleanup_allocator, value);
    } else if (comptime isUnionResult(PayloadType)) {
        // A union (CSSNumberish, LineAndPositionSetting):
        // its active member's conversion, and so that
        // member's ownership - a number or string made
        // here is released, a wrapper or an `any`
        // member's handle (ImageData.data's, the
        // ImageData's own) is kept (conv.unionValueIsOwned).
        if (conv.unionValueIsOwned(PayloadType, result)) v8.v8_Global_Dispose(v8_value);
    } else if (comptime @typeInfo(PayloadType) == .optional and isUnionResult(@typeInfo(PayloadType).optional.child)) {
        // A nullable union: null as below, a member as above.
        if (result) |member| {
            if (conv.unionValueIsOwned(@typeInfo(PayloadType).optional.child, member)) v8.v8_Global_Dispose(v8_value);
        } else v8.v8_Global_Dispose(v8_value);
    } else if (comptime @typeInfo(PayloadType) == .optional) {
        // Any other optional: a null result's value is made
        // here, fresh - `v8.v8_Null(isolate_inner)` in the
        // instance and callback branches, `toV8Null` in
        // conv.toV8Value's optional branch, and the
        // wrapper's v8_Null news a Global per call - so it
        // is ours. A non-null one stays: it may be a
        // wrapper the cache owns or a stored callback. Kept,
        // every `event.target` read before dispatch, every
        // `messageEvent.source` of a WebSocket message,
        // leaked a Null Global.
        if (result == null) v8.v8_Global_Dispose(v8_value);
    }
}

/// Whether a getter result of type `T` is set straight into the return slot
/// by `setDirectResult` (perf3 phase 1b): a string, a nullable string, an
/// enumeration value. An allowlist; everything else converts as before.
pub fn directGetterResult(comptime T: type) bool {
    if (T == runtime.DOMString or T == ?runtime.DOMString) return true;
    if (T == []const u8 or T == ?[]const u8) return true;
    return @typeInfo(T) == .@"enum";
}

/// Whether an operation's result of type `T` (its error union unwrapped) is
/// set straight into the return slot (perf3 phase 1b): the getter's
/// allowlist, plus the numbers and booleans `convertReturnValue` makes a
/// Number or Boolean of - the same values (WebIDL 3.2.x: an integer type
/// converts to the Number of its value, a float to its double, a boolean to
/// itself), with no Global.
pub fn directOperationResult(comptime T: type) bool {
    if (directGetterResult(T)) return true;
    const numbers = [_]type{ bool, i16, i32, i64, u16, u32, u64, f32, f64 };
    inline for (numbers) |N| {
        if (T == N) return true;
    }
    return false;
}

/// Set `value` (a `directOperationResult` type) as the call's return value,
/// with no handle: a number or a boolean as setPrimitiveReturn writes it, null
/// as the root, a string by `setReturnWtf8`, an enumeration value as the
/// String of its IDL value.
pub fn setDirectResult(info: *const v8.FunctionCallbackInfo, comptime T: type, value: T) void {
    if (comptime @typeInfo(T) == .optional) {
        if (value) |present| {
            setDirectResult(info, @typeInfo(T).optional.child, present);
        } else {
            v8.FunctionCallbackInfo.v8_FunctionCallbackInfo_SetReturnNull(info);
        }
    } else if (comptime T == runtime.DOMString) {
        setReturnWtf8(info, value.asSlice());
    } else if (comptime T == []const u8) {
        setReturnWtf8(info, value);
    } else if (comptime @typeInfo(T) == .@"enum") {
        setReturnWtf8(info, conv.idlEnumValue(T, value));
    } else if (comptime interface.primitiveGetterResult(T) or T == i16 or T == u16) {
        interface.setPrimitiveReturn(info, T, value);
    } else {
        @compileError("setDirectResult: not a direct result type: " ++ @typeName(T));
    }
}

/// Set the String of the code units the WTF-8 `bytes` encode as the call's
/// return value (WebIDL 3.2.10: "the String value that represents the same
/// sequence of code units"). ASCII is made with NewFromOneByte (a copy, no
/// decode), well-formed UTF-8 with NewFromUtf8, both in V8's callback scope;
/// bytes with a surrogate code point keep `conv.newStringFromWtf8`'s two-byte
/// path and its Global, the one the result had before (rare: a lone
/// surrogate in a DOM string).
pub fn setReturnWtf8(info: *const v8.FunctionCallbackInfo, bytes: []const u8) void {
    if (bytes.len > std.math.maxInt(c_int)) {
        conv.setReturnUndefined(info);
        return;
    }
    if (allAscii(bytes)) {
        v8.FunctionCallbackInfo.v8_FunctionCallbackInfo_SetReturnString(info, bytes.ptr, @intCast(bytes.len), true);
        return;
    }
    if (value_operations.hasSurrogateCodePoint(bytes)) {
        const isolate = info.getIsolate();
        const made = conv.newStringFromWtf8(isolate, bytes) orelse {
            conv.setReturnUndefined(info);
            return;
        };
        info.setReturnValue(made);
        v8.v8_Global_Dispose(made);
        return;
    }
    v8.FunctionCallbackInfo.v8_FunctionCallbackInfo_SetReturnString(info, bytes.ptr, @intCast(bytes.len), false);
}

/// Whether every byte of `bytes` is ASCII (below 0x80): sixteen at a time.
fn allAscii(bytes: []const u8) bool {
    const Lanes = @Vector(16, u8);
    var i: usize = 0;
    while (i + 16 <= bytes.len) : (i += 16) {
        const lanes: Lanes = bytes[i..][0..16].*;
        if (@reduce(.Or, lanes) & 0x80 != 0) return false;
    }
    while (i < bytes.len) : (i += 1) {
        if (bytes[i] & 0x80 != 0) return false;
    }
    return true;
}

/// Tie the wrapper of a [SameObject] child to its owner's wrapper - the
/// edge Blink traces - with one edge per realm. An element has one
/// wrapper whatever realm reads it, but its child gets a wrapper in
/// each realm that reads it, and one shared key let each realm's read
/// cut the edge to the other realm's wrapper.
pub fn recordSameObjectEdge(isolate: *v8.Isolate, owner: *v8.Object, prop_name: []const u8, child: *v8.Value) void {
    const realm = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(realm);
    const addr = @intFromPtr(v8.v8_Context_GetRawAddress(realm));
    var buf: [160]u8 = undefined;
    const key = std.fmt.bufPrint(&buf, "crane:SameObject:{s}@{x}", .{ prop_name, addr }) catch return;
    v8.v8_Object_SetPrivateRef(owner, key.ptr, @intCast(key.len), child);

    // And the edge back. A [SameObject] child - classList, dataset,
    // attributes, style - reads and writes through its owner, and
    // script can keep the child and drop the owner; the owner must then
    // live as long as the child (Blink traces the child to its element;
    // WebKit forwards the child's refcount to it). A JS-heap edge, not
    // a Global, so the pair still collects as a unit. Without it,
    // `el.attributes` kept past `el` read a freed element.
    if (!v8.v8_Value_IsObject(child)) return;
    var back_buf: [168]u8 = undefined;
    const back = std.fmt.bufPrint(&back_buf, "crane:SameObjectOwner:{s}@{x}", .{ prop_name, addr }) catch return;
    v8.v8_Object_SetPrivateRef(@ptrCast(child), back.ptr, @intCast(back.len), @ptrCast(owner));
}

/// HTML: "The window, frames, and self getter steps are to return this's
/// relevant realm.[[GlobalEnv]].[[GlobalThisValue]]" - the WindowProxy,
/// which the getter's own realm answers without its Window: when `this` is
/// that realm's global, its global this value is the context's global
/// proxy. `self` and `frames` are own data properties holding it already;
/// `window` is an accessor, and a removed frame's realm ends
/// (engine.WindowRealmEnd.navigable_destroyed) with its global still
/// attached but its Window freed, so looking the Window up made `w.window`
/// throw where `w.self` answered (self-et-al.window.js). Answers false for
/// any other `this`, which the generic path brand-checks.
pub fn answerWindowGetter(info: *const v8.FunctionCallbackInfo, window_access: ?[]const u8) bool {
    const isolate = info.getIsolate();
    // V8 enters the getter's creation context: the method's realm.
    const method_ctx = v8.v8_Isolate_GetCurrentContext(isolate) orelse return false;
    defer v8.v8_Context_Dispose(method_ctx);
    const method_global = v8.v8_Context_Global(method_ctx) orelse return false;
    defer v8.v8_Object_Dispose(method_global);
    const this_obj = info.getThis();
    defer v8.v8_Object_Dispose(this_obj);
    if (!v8.v8_Value_StrictEquals(@ptrCast(this_obj), @ptrCast(method_global))) return false;
    // HTML 7.1.3.3's access report check, for the method's realm's Window:
    // `this` is the method's own global, so THE Window-receiver rule's
    // contextual case - the Window the method's realm was attached with
    // (never field 0 of its global, which a reused WindowProxy points at the
    // next realm's Window). reportWindowAccess asks first whether the
    // Browser monitors access at all.
    if (window_access) |property| {
        if (@import("context_manager.zig").getWindowForContext(method_ctx)) |window| @import("protocol_realms.zig").reportWindowAccess(window, property);
    }
    // Copied into the return value; ours is released above.
    info.setReturnValue(@ptrCast(method_global));
    return true;
}

// ============================================================================
// Type predicates the shared steps branch on (none depends on an interface)
// ============================================================================

pub fn isRuntimeInstancePtr(comptime T: type) bool {
    const type_info = @typeInfo(T);
    if (type_info != .pointer) return false;
    // Check if it's a pointer to runtime.Instance by comparing child type
    return type_info.pointer.child == runtime.Instance;
}

pub fn isOptionalRuntimeInstancePtr(comptime T: type) bool {
    const type_info = @typeInfo(T);
    if (type_info != .optional) return false;
    const child_info = @typeInfo(type_info.optional.child);
    if (child_info != .pointer) return false;
    return child_info.pointer.child == runtime.Instance;
}

/// A tagged union result other than DOMString and JSValue (whose own arms
/// the binding knows).
pub fn isUnionResult(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .@"union" or info.@"union".tag_type == null) return false;
    return T != runtime.DOMString and T != runtime.JSValue;
}

pub fn isOptionalCallbackType(comptime T: type) bool {
    const type_info = @typeInfo(T);
    if (type_info != .optional) return false;

    const child_info = @typeInfo(type_info.optional.child);
    if (child_info != .pointer) return false;

    const ptr_child_info = @typeInfo(child_info.pointer.child);
    return ptr_child_info == .@"fn";
}

// ============================================================================
// Attribute setters (WebIDL 3.7.6 "the attribute setter")
// ============================================================================

/// What an attribute's setter callback needs that is its own.
pub const Setter = struct {
    interface_name: []const u8,
    /// [CEReactions]: dispatched in a binding catch scope.
    ce_reactions: bool,
    /// Whether converting the value may make the engine keep the current
    /// context (`interface.typeRetainsContext`): then it is not released.
    value_retains_context: bool,
    /// WebIDL attribute setter 4.5.2: Location's setters (but href's) check
    /// their platform target before the value converts.
    checks_receiver: bool,
    /// [LegacyNullToEmptyString]: a null value converts as "".
    null_to_empty: bool,
    /// The conversion copies out of the value's handle
    /// (`interface.argHandleIsCopied`): released whatever happens.
    value_is_copied: bool,
    /// An `any` value, BORROWED by the setter (`interface.setterValueIsBorrowed`):
    /// never handed over to its conversion.
    value_is_borrowed: bool,
    /// A callback value, whose Global is the value itself
    /// (`v8_Global_DisposeCallbackValue`).
    value_is_callback: bool,
    /// [LegacyLenientThis]: a `this` that is no instance does nothing.
    lenient_this: bool,
    /// The interface is a [Global] one (Window).
    global_interface: bool,
    /// Whether `instance` implements the interface (`conv.implements`).
    implements: *const fn (instance: *const runtime.Instance) bool,
    /// The attribute's own steps for an instance: convert the value, call the
    /// impl's setter, throw what either failed with. The value is read from
    /// `info` when its type converts without a handle, else taken from
    /// `value` (its Global, made then); the contexts come from `frame`. It
    /// sets `value_handed_over` when the conversion took the value's handle.
    write: *const fn (
        info: *const v8.FunctionCallbackInfo,
        instance: *runtime.Instance,
        frame: *CallFrame,
        value: *SetterValue,
        value_handed_over: *bool,
    ) void,
    /// HTML's access report check for a CrossOriginProperties(Window)
    /// member (Chromium's make_report_coop_access): the property name the
    /// realm's report_window_access is told before the member's steps
    /// (protocol_realms.reportWindowAccess), or null for every other member.
    window_access: ?[]const u8 = null,
};

/// A setter's value, info[0], as a Global made only when its conversion
/// needs one (perf3 phase 1b): undefined when the argument is missing (WebIDL:
/// a missing argument is undefined), the empty string for a null under
/// [LegacyNullToEmptyString] (`interface.nullToEmptyString`). The setter
/// releases what was made (setterBody's defer).
pub const SetterValue = struct {
    info: *const v8.FunctionCallbackInfo,
    isolate: *v8.Isolate,
    null_to_empty: bool,
    handle: ?*v8.Value = null,

    pub fn get(self: *SetterValue) *v8.Value {
        if (self.handle) |made| return made;
        const raw = if (self.info.length() > 0) self.info.get(0) else v8.v8_Undefined(self.isolate) orelse unreachable;
        const made = if (self.null_to_empty) interface.nullToEmptyString(self.isolate, raw) else raw;
        self.handle = made;
        return made;
    }
};

/// What `throwInFunctionRealm` throws.
pub const ThrownError = enum { type_error, webidl };

/// Throw a TypeError (`type_error`) or the WebIDL error named `message`
/// (`webidl`) in the function's realm - "throw a TypeError using the
/// function's realm" - from the call's frame; with no context at all, a plain
/// error, as the binding threw when V8 had none.
pub fn throwInFunctionRealm(frame: *CallFrame, kind: ThrownError, message: []const u8) void {
    const realm = frame.functionContext() orelse {
        conv.throwError(frame.isolate, message);
        return;
    };
    switch (kind) {
        .type_error => conv.throwTypeErrorFromContext(frame.isolate, realm, message),
        .webidl => conv.throwWebIDLErrorFromContext(frame.isolate, realm, message),
    }
}

/// `this`'s instance - internal field 0, through a legacy platform object's
/// proxy - read from `info` with no handle (v8_FunctionCallbackInfo_ThisInstance;
/// perf3 phase 1b), or null when `this` has none. Whether it implements the
/// member's interface is the caller's brand check, the instance's state
/// ancestry (`conv.implements`): per WebIDL a `this` that is not a platform
/// object implementing the interface is a TypeError, and an ancestry check per
/// instance holds across realms. A wrapper keeps no WrapperTypeInfo beside its
/// instance (lane v8up A0).
pub fn thisInstance(info: *const v8.FunctionCallbackInfo) ?*anyopaque {
    return v8.FunctionCallbackInfo.v8_FunctionCallbackInfo_ThisInstance(info);
}

/// An attribute setter function's steps (the generic makeSetterCallback's
/// callback and body), for the attribute `self` describes.
pub fn attributeSetter(info: *const v8.FunctionCallbackInfo, self: *const Setter) void {
    // A DOM algorithm on the agent's stack until it returns
    // into script (dom_algorithm.zig; refcount design 9, risk 4).
    const algorithm = dom_algorithm.enter(info.getIsolate());
    defer dom_algorithm.leaveToScript(algorithm);
    var call: SetterCall = .{ .info = info, .setter = self };
    if (self.ce_reactions) return inBindingCatchScope(info, &call, SetterCall.body);
    call.body();
}

/// One call of a setter, as the data a catching run hands back to it.
const SetterCall = struct {
    info: *const v8.FunctionCallbackInfo,
    setter: *const Setter,

    fn body(call: *SetterCall) void {
        setterBody(call.info, call.setter);
    }
};

fn setterBody(info: *const v8.FunctionCallbackInfo, self: *const Setter) void {
    const isolate_inner = info.getIsolate();
    // The call's contexts, made when a step asks for one (perf3 phase 1b):
    // the current context for a conversion that needs it, the setter's own
    // realm ("Throw a TypeError using the function's realm") for an error.
    // A setter that converts its value without either - a String into a
    // DOMString, a Number, a boolean - makes neither: two Globals per
    // assignment before. Each is released when the setter returns, but the
    // current context once the value's conversion may keep it
    // (`value_retains_context`, the allowlist every other binding path
    // consults; before, a setter never released it, so each
    // `el.onclick = f` pinned its page).
    var frame = CallFrame.init(info, self.value_retains_context);
    defer frame.release();

    // WebIDL attribute setter 4.5.2 precedes conversion.
    // CrossOriginProperties exempts href's setter.
    if (self.checks_receiver) {
        if (!@import("cross_origin.zig").receiverIsAccessible(info)) {
            throwInFunctionRealm(&frame, .webidl, "SecurityError");
            return;
        }
    }

    // The value, info[0] - undefined when missing (WebIDL: a missing
    // argument is undefined) - as a Global made only when its conversion
    // needs one (`SetterValue`). That handle is owned (`info.get`
    // allocates a Global, as does `v8_Undefined`), and released here
    // unless it was handed to a conversion that may keep it - the rule
    // `convertArgReleasing` applies to an operation's arguments,
    // `argHandleIsCopied`. A setter released nothing, so every
    // assignment leaked one handle, and one that held an object
    // of another realm kept that realm alive.
    //
    // An `any` value is BORROWED by the setter
    // (`setterValueIsBorrowed`): never handed over, so the defer
    // releases it once the setter has returned or failed - and
    // when its conversion fails, which made nothing that refers
    // to it. Every other kept type is handed over to its
    // conversion (the attribute's `write`).
    //
    // A callback value's Global is the value itself, borrowed
    // for the setter: a take moved its function out, and the
    // emptied box goes without the general dispose's lookups
    // (v8_Global_DisposeCallbackValue), as an argument's does.
    var value: SetterValue = .{ .info = info, .isolate = isolate_inner, .null_to_empty = self.null_to_empty };
    var value_handed_over = false;
    defer if (value.handle) |made| {
        if (self.value_is_copied or !value_handed_over) {
            if (self.value_is_callback) v8.v8_Global_DisposeCallbackValue(made) else v8.v8_Value_Dispose(made);
        }
    };

    // Check if this is a [LegacyLenientThis] attribute
    const is_lenient_this = self.lenient_this;

    // For [Global] interfaces (like Window), we need special handling:
    // Per WebIDL §3.8, if this is null/undefined, use the method's global object.
    // See PropertyGetterCallback for detailed explanation.
    const resolved_instance: ?*anyopaque = blk: {
        if (self.global_interface) {
            // A handle for `this`, for THE Window-receiver rule (windowOf):
            // the only setters that still make one; `thisInstance` serves
            // every other.
            const this_obj = info.getThis();
            defer v8.v8_Object_Dispose(this_obj);
            if (windowOf(isolate_inner, this_obj)) |window| break :blk window;
            // No Window: throw below.
        } else {
            // Non-[Global] interface: use normal this handling
            //
            // We MUST verify that `this` is actually an instance of this interface
            // BEFORE using the internal field pointer. This is critical because in
            // sloppy mode, `setter.call(null)` coerces null to the global object (Window),
            // which HAS internal fields but is NOT an instance of this interface.
            // Without this check, we'd pass the Window's internal pointer to the setter,
            // causing InvalidStateError instead of the correct TypeError.
            //
            // Per WebIDL spec:
            // - For regular attributes: throw TypeError if `this` is not a valid instance
            // - For [LegacyLenientThis]: silently return if `this` is not a valid instance

            // The brand check is the instance's state ancestry (`self.implements`
            // below), per instance, so it holds across realms. `this`'s instance
            // is read from `info` with no handle (`thisInstance`): a
            // Global<Object> per assignment before (perf3 phase 1b).
            if (thisInstance(info)) |instance_ptr| break :blk instance_ptr;
            // [LegacyLenientThis] - silently return instead of throwing
            if (is_lenient_this) {
                conv.setReturnUndefined(info);
                return;
            }
        }

        // [LegacyLenientThis] on a [Global] interface: `this` is
        // no Window - return (WebIDL 3.7.6 setter step 1.3.1).
        if (is_lenient_this) {
            conv.setReturnUndefined(info);
            return;
        }

        // Throw TypeError from setter's realm (function's creation context)
        // Per WebIDL spec: "Throw a TypeError using the function's realm."
        throwInFunctionRealm(&frame, .type_error, "Illegal invocation");
        return;
    };

    if (resolved_instance == null) {
        throwInFunctionRealm(&frame, .type_error, "Illegal invocation");
        return;
    }

    // Safety check: detect use-after-free by checking for poison patterns
    const ptr_as_int = @intFromPtr(resolved_instance.?);
    if (isPoisoned(ptr_as_int)) {
        conv.throwError(isolate_inner, "Cannot set property on freed object");
        return;
    }

    const instance: *runtime.Instance = @ptrCast(@alignCast(resolved_instance.?));

    if (!self.implements(instance)) {
        if (!is_lenient_this) {
            throwInFunctionRealm(&frame, .type_error, "Illegal invocation");
        }
        return;
    }

    // HTML 7.1.3.3: the access is checked for a report before the steps.
    if (self.window_access) |property| @import("protocol_realms.zig").reportWindowAccess(instance, property);

    self.write(info, instance, &frame, &value, &value_handed_over);
}

// ============================================================================
// Operation results
// ============================================================================

/// What an operation returning `ReturnType` gives back once its error union
/// is unwrapped.
pub fn OperationPayload(comptime ReturnType: type) type {
    const type_info = @typeInfo(ReturnType);
    return if (type_info == .error_union) type_info.error_union.payload else ReturnType;
}

/// An operation's result (`zig_result`, what its impl returned): converted
/// to the value the call returns, in `return_context` (the method's realm),
/// and what the binding owns of the impl's result freed - the steps every
/// operation whose result is a `ReturnType` shares (`byte_string`: a
/// [ByteString] result). Instantiated per result type, not per operation
/// (V8Interface.callMethodWithArgs, whose argument conversions and impl call
/// are the operation's own).
pub fn finishOperation(
    comptime ReturnType: type,
    comptime byte_string: bool,
    info: *const v8.FunctionCallbackInfo,
    instance: *runtime.Instance,
    zig_result: OperationPayload(ReturnType),
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    frame: *CallFrame,
    result_owned: *bool,
) !?*v8.Value {
    // Determine the payload type (unwrap error union if needed) for cleanup
    // Determine the payload type (unwrap error union and optional if needed) for cleanup
    const PayloadType = comptime blk: {
        var T = ReturnType;
        const type_info = @typeInfo(T);
        if (type_info == .error_union) {
            T = type_info.error_union.payload;
        }
        break :blk T;
    };

    // Get the innermost type for cleanup (unwrap optional)
    const InnerType = comptime blk: {
        const type_info = @typeInfo(PayloadType);
        if (type_info == .optional) {
            break :blk type_info.optional.child;
        } else {
            break :blk PayloadType;
        }
    };

    // Check if InnerType is an array/slice type (for sequence cleanup)
    const is_sequence = comptime blk: {
        const type_info = @typeInfo(InnerType);
        break :blk type_info == .pointer and type_info.pointer.size == .slice;
    };

    // Get the element type if it's a sequence
    const ElementType = comptime blk: {
        if (is_sequence) {
            const ptr_info = @typeInfo(InnerType).pointer;
            break :blk ptr_info.child;
        } else {
            break :blk void;
        }
    };

    // For string types that allocate memory, free after V8 conversion.
    // IMPORTANT: Impls MUST use instance.ctx.allocator for returned strings,
    // not internal.allocator, so this cleanup uses the correct allocator.
    // Static strings (empty string "") have len=0 and won't be freed.
    // Handles both optional and non-optional string types.
    // Also handles sequences (arrays) of strings.
    // Also handles JSValue with owned strings.
    const needs_string_cleanup = comptime (InnerType == runtime.USVString or
        InnerType == []const u8 or
        InnerType == runtime.DOMString or
        InnerType == runtime.JSValue);
    const needs_sequence_cleanup = comptime (is_sequence and
        (ElementType == []const u8 or ElementType == runtime.USVString));
    const is_optional = comptime (@typeInfo(PayloadType) == .optional);

    defer if (needs_string_cleanup) {
        if (InnerType == runtime.DOMString) {
            if (is_optional) {
                if (zig_result) |value| {
                    var mutable = value;
                    mutable.deinit(instance.ctx.allocator);
                }
            } else {
                var mutable = zig_result;
                mutable.deinit(instance.ctx.allocator);
            }
        } else if (InnerType == runtime.USVString or InnerType == []const u8) {
            if (is_optional) {
                if (zig_result) |value| {
                    if (value.len > 0) {
                        instance.ctx.allocator.free(value);
                    }
                }
            } else {
                if (zig_result.len > 0) {
                    instance.ctx.allocator.free(zig_result);
                }
            }
        } else if (InnerType == runtime.JSValue) {
            // Free owned string data in JSValue after V8 conversion
            if (is_optional) {
                if (zig_result) |value| {
                    switch (value) {
                        .string => |s| {
                            if (s.owned and s.data.len > 0) {
                                instance.ctx.allocator.free(s.data);
                            }
                        },
                        else => {},
                    }
                }
            } else {
                switch (zig_result) {
                    .string => |s| {
                        if (s.owned and s.data.len > 0) {
                            instance.ctx.allocator.free(s.data);
                        }
                    },
                    else => {},
                }
            }
        }
    };

    // Cleanup for sequences (arrays) - free the array itself
    // Note: Individual strings in the array are NOT freed here because
    // they should reference internal data, not be separately allocated
    defer if (needs_sequence_cleanup) {
        if (zig_result.len > 0) {
            instance.ctx.allocator.free(zig_result);
        }
    };

    // A string, a number, a boolean, an enumeration value or null goes
    // straight into the return slot, made in V8's callback scope with no
    // Global (perf3 phase 1b; `directOperationResult`): the values
    // convertReturnValue makes of them, and they need no realm.
    if (comptime !byte_string and directOperationResult(PayloadType)) {
        result_owned.* = false;
        setDirectResult(info, PayloadType, zig_result);
        return null;
    }

    // Convert return value to V8
    // CROSS-REALM SUPPORT: the method's realm (the frame's function context)
    // for object creation - asked of the frame only by the results made in
    // it (a union's or a dictionary's object): a void, a wrapper or a handle
    // makes no context (perf3 phase 1b: every void operation made one).
    return try convertReturnValue(ReturnType, byte_string, zig_result, allocator, isolate, frame, result_owned);
}

/// Convert Zig return value to V8 Value
pub fn convertReturnValue(
    comptime ReturnType: type,
    comptime byte_string: bool,
    result: anytype,
    allocator: std.mem.Allocator,
    isolate: *v8.Isolate,
    frame: *CallFrame,
    owned: *bool,
) !?*v8.Value {
    // Suppress unused parameter warning - allocator used only in recursive calls
    _ = allocator;

    // `owned` answers whether the handle returned is the binding's to
    // release once the caller has set it as the call's result
    // (setReturnValue copies). True where this conversion made the
    // handle, and for every handle a JSValue result carries - what an
    // impl returns is the binding's. A wrapper is the cache's, and a
    // union's or dictionary's parts are not told apart here, so they
    // stay false - a leak at worst, never a handle freed under its
    // holder.
    owned.* = false;

    const type_info = @typeInfo(ReturnType);

    // Handle error union - unwrap it
    if (type_info == .error_union) {
        const PayloadType = type_info.error_union.payload;
        return convertReturnValue(PayloadType, byte_string, result, std.heap.page_allocator, isolate, frame, owned);
    }

    // Handle void return
    if (ReturnType == void) {
        return null;
    }

    if (comptime byte_string) {
        owned.* = true;
        return try conv.byteStringToV8(ReturnType, isolate, result);
    }

    // Handle optional types
    if (type_info == .optional) {
        if (result) |value| {
            const ChildType = type_info.optional.child;
            return convertReturnValue(ChildType, false, value, std.heap.page_allocator, isolate, frame, owned);
        } else {
            owned.* = true;
            return @ptrCast(v8.v8_Null(isolate));
        }
    }

    // A platform object is its wrapper in its relevant realm
    // (`conv.instanceToV8`), whichever realm the operation's function
    // belongs to: wrapped in `v8_context` - the CALLEE's realm - an
    // object a method borrowed from another realm returned got a
    // second wrapper there, with that realm's prototype
    // (tests/v8/cross_realm_wrapper_test.zig). The wrapper is the
    // wrapper cache's; only the undefined of an object that cannot be
    // wrapped is this call's.
    if (ReturnType == *runtime.Instance) {
        const wrapper = conv.instanceToV8(isolate, result);
        owned.* = v8.v8_Value_IsUndefined(wrapper);
        return wrapper;
    }

    // Handle primitive types
    if (ReturnType == bool) {
        owned.* = true;
        return @ptrCast(v8.v8_Boolean_New(isolate, result));
    }

    if (ReturnType == i16 or ReturnType == i32 or ReturnType == i64 or ReturnType == u16 or ReturnType == u32 or ReturnType == u64) {
        owned.* = true;
        return @ptrCast(v8.v8_Number_New(isolate, @floatFromInt(result)));
    }

    if (ReturnType == f64 or ReturnType == f32) {
        owned.* = true;
        return @ptrCast(v8.v8_Number_New(isolate, result));
    }

    // Handle DOMString
    if (ReturnType == runtime.DOMString) {
        const slice = result.asSlice();
        // WTF-8: its lone surrogates kept (conv.newStringFromWtf8).
        const v8_str = conv.newStringFromWtf8(isolate, slice) orelse {
            return v8.v8_Undefined(isolate);
        };
        owned.* = true;
        return @ptrCast(v8_str);
    }

    // Handle []const u8 (string slices)
    if (ReturnType == []const u8) {
        const v8_str = conv.newStringFromWtf8(isolate, result) orelse {
            return v8.v8_Undefined(isolate);
        };
        owned.* = true;
        return @ptrCast(v8_str);
    }

    // Handle runtime.JSValue - engine-agnostic value wrapper
    if (ReturnType == runtime.JSValue) {
        // What an impl returns is the binding's (engine.Owned.take): a
        // handle - the impl's to hand over, a value it keeps going back
        // as a hold of its own (retainValue) - and every value made
        // here are released once set. Only an instance's wrapper is
        // not: it is the wrapper cache's.
        owned.* = result != .instance;
        return switch (result) {
            .undefined => v8.v8_Undefined(isolate),
            .null => @ptrCast(v8.v8_Null(isolate)),
            .boolean => |b| @ptrCast(v8.v8_Boolean_New(isolate, b)),
            .number => |n| @ptrCast(v8.v8_Number_New(isolate, n)),
            .string => |s| blk: {
                if (s.data.len == 0) {
                    break :blk @ptrCast(v8.v8_String_Empty(isolate) orelse return v8.v8_Undefined(isolate));
                }
                break :blk @ptrCast(conv.newStringFromWtf8(isolate, s.data) orelse return v8.v8_Undefined(isolate));
            },
            // A Global<Value>*, set as the result as it is.
            .handle => |h| @ptrCast(h.ptr),
            // Its wrapper in its relevant realm, as above.
            .instance => |i| blk: {
                const wrapper = conv.instanceToV8(isolate, @ptrCast(@alignCast(i)));
                owned.* = v8.v8_Value_IsUndefined(wrapper);
                break :blk wrapper;
            },
        };
    }

    // An ArrayBufferView result is the binding's, as a JSValue
    // result's handle is (ArrayBufferView.jsHandle): an impl that
    // returns a view it was given or keeps returns it over a hold of
    // its own (`withJsHandle`), since the arguments are released
    // before this runs. Released once set.
    if (ReturnType == webidl.ArrayBufferView) {
        owned.* = true;
        const js = result.jsHandle() orelse return v8.v8_Undefined(isolate);
        return @ptrCast(@alignCast(js));
    }

    // A WebIDL enumeration value is the String of its value (WebIDL
    // 3.2.24) - "" included: canPlayType's "" answer. The conversion
    // and ownership the attribute getter path uses (enumToV8String
    // makes the string; released once set). Without this case an
    // enum fell to the fallback below and reached script as undefined.
    if (type_info == .@"enum") {
        owned.* = true;
        return conv.enumToV8String(ReturnType, isolate, result);
    }

    // A union (FormData.get's (File or USVString), getReader's
    // reader): its active member's conversion, and so that member's
    // ownership (`conv.unionValueIsOwned`) - a String made for a
    // string member is released once set, a wrapper is the cache's.
    // `owned` was left false for every union, so FormData.get kept
    // the String of every string entry it returned.
    if (type_info == .@"union") {
        const v8_context = frame.functionContext() orelse {
            owned.* = true;
            return v8.v8_Undefined(isolate);
        };
        const converted = conv.toV8Value(ReturnType, isolate, v8_context, result) catch {
            owned.* = true;
            return v8.v8_Undefined(isolate);
        };
        owned.* = conv.unionValueIsOwned(ReturnType, result);
        return converted;
    }

    // Handle Promise(T) types - extract the handle and return the V8 Promise
    if (@typeInfo(ReturnType) == .@"struct") {
        if (@hasDecl(ReturnType, "ResultType") and @hasField(ReturnType, "handle")) {
            // This is a Promise(T) type - extract the V8 Promise handle
            return @ptrCast(result.handle);
        }
        // A dictionary (URLPatternResult, NavigationResult): its object
        // is made for this call (WebIDL 3.2.18), and released once
        // set - kept, it leaked a Global per call. A JavaScript value
        // the impl handed over in it is the binding's too, as a
        // JSValue result is: released once the object holds it
        // (conv.releaseReturnedDictionaryHandles).
        owned.* = comptime conv.dictionaryValueIsOwned(ReturnType);
        defer conv.releaseReturnedDictionaryHandles(ReturnType, result);
        const v8_context = frame.functionContext() orelse {
            owned.* = true;
            return v8.v8_Undefined(isolate);
        };
        return conv.toV8Value(ReturnType, isolate, v8_context, result) catch {
            owned.* = true;
            return v8.v8_Undefined(isolate);
        };
    }

    // Handle *const anyopaque - SAFETY: Cannot blindly cast to V8 Value
    // These are often Zig-side objects (like *runtime.Instance for
    // Promise returns) that need proper wrapping, not raw casting.
    if (ReturnType == *const anyopaque) {
        // Return undefined to prevent crashes from misaligned pointers
        // TODO: Implement proper Promise creation for [NewObject] methods
        return v8.v8_Undefined(isolate);
    }

    // For other types, return undefined as fallback
    // TODO: Expand type conversion coverage
    return v8.v8_Undefined(isolate);
}

// ============================================================================
// Installation
// ============================================================================

/// Register operation `method_name` on `proto_tmpl` with `callback` (its
/// operation callback): a FunctionTemplate of length `arity`, no prototype,
/// `attributes`, and V8's security check for a cross-origin `this` when
/// `engine_checks_receiver` (V8Interface.engineChecksReceiver).
///
/// CROSS-REALM SUPPORT: no V8 signature. V8's signature checking is too
/// strict for WebIDL cross-realm semantics: when obj is created via
/// `new child.DOMParser()` (child realm's FunctionTemplate) and we call
/// `DOMParser.prototype.method.call(obj, ...)` (parent realm's method), V8's
/// signature check rejects it because obj's FunctionTemplate differs from the
/// parent realm's receiver template. Per WebIDL, cross-realm `this` values
/// work - an object created as a DOMParser in ANY realm is usable with
/// DOMParser methods from ANY realm (within the same agent/isolate). The
/// operation callback validates `this` by its internal fields
/// (`operationReceiver`), which holds across realms.
pub fn registerMethod(
    isolate: *v8.Isolate,
    proto_tmpl: *v8.ObjectTemplate,
    callback: v8.FunctionCallback,
    method_name: []const u8,
    arity: c_int,
    attributes: c_int,
    engine_checks_receiver: bool,
) void {
    const method_tmpl = v8.v8_FunctionTemplate_New(
        isolate,
        callback,
        null,
    ) orelse {
        std.debug.panic("Failed to create function template for method", .{});
    };
    // ObjectTemplate::Set below keeps the method template itself.
    defer v8.v8_FunctionTemplate_Dispose(method_tmpl);

    // Set method length (arity) - number of required parameters
    v8.v8_FunctionTemplate_SetLength(method_tmpl, arity);

    // Remove prototype property from method functions.
    // Per WebIDL spec, methods are not constructible and should not have
    // the legacy "arguments"/"caller" properties.
    // This ensures Reflect.ownKeys(method) returns ["length", "name"].
    v8.v8_FunctionTemplate_RemovePrototype(method_tmpl);

    // WebIDL's security check for a cross-origin `this`, unless HTML
    // lists the operation (cross_origin.zig).
    if (engine_checks_receiver) v8.v8_FunctionTemplate_SetAcceptAnyReceiver(method_tmpl, false);

    // Add FunctionTemplate to prototype (not the function itself)
    // ObjectTemplate::Set accepts Templates or primitives
    // Set with DontEnum attribute to make methods non-enumerable (spec-compliant)
    const name_str = v8.v8_String_NewFromUtf8(
        isolate,
        method_name.ptr,
        @intCast(method_name.len),
    ) orelse {
        std.debug.panic("Failed to create string for method name", .{});
    };
    defer v8.v8_String_Dispose(name_str);
    // Per WebIDL spec §3.7.6, method properties should be:
    // { writable: true, enumerable: true, configurable: true } -
    // an unforgeable one's neither writable nor configurable.
    v8.v8_ObjectTemplate_SetWithAttributes(
        proto_tmpl,
        name_str,
        @ptrCast(method_tmpl),
        attributes,
    );
}

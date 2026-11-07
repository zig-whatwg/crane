//! A binding call's own values: its contexts, made when a step first asks for
//! one, and its arguments, read straight from the call (perf3 phase 1b,
//! tmp/plans/perf3-design.md section 5).
//!
//! V8 opens a HandleScope around every API callback (its CallApiCallback
//! builtins: "Allocates HandleScope, extracts returned value from handle and
//! propagates exceptions", src/codegen/<arch>/macro-assembler-<arch>.cc), and
//! Blink's generated bindings make their Locals in it rather than a persistent
//! handle per value. The binding's own values - its results, `this`, the
//! current and the function's contexts, an argument that converts without
//! running script - never outlive the call, so they need no Global: the FFI
//! functions this file calls take the callback's `info`, open no scope of
//! their own, and hand Zig plain data (bytes, a number, an instance pointer),
//! never a Local. What a step must keep still goes through the owning path:
//! a context a parameter's conversion retains (`retain_current`), every value
//! of a type that keeps its handle (`any`, `object`, callbacks, buffer
//! sources), every slow path - each takes the Global it took before.

const std = @import("std");
const v8 = @import("ffi.zig");

/// The contexts of one binding call, each made on first use and released when
/// the call ends (`release`), as the binding released them before - only no
/// longer made by a call that never asks.
pub const CallFrame = struct {
    info: *const v8.FunctionCallbackInfo,
    isolate: *v8.Isolate,
    /// The current context - the caller's realm, where arguments convert -
    /// once made (`currentContext`).
    current: ?*v8.Context = null,
    /// The function's creation context - its realm, where errors are thrown
    /// and objects made - once made (`functionContext`).
    function: ?*v8.Context = null,
    /// `current` was made here (released by `release`), not handed in.
    owns_current: bool = true,
    /// `function` was made here, not the current context standing in for a
    /// function with no creation context, nor handed in.
    owns_function: bool = true,
    /// A parameter's conversion may keep the current context
    /// (`interface.typeRetainsContext`, an allowlist whose default is
    /// "retains"): once made, it is the conversion's, never released here -
    /// the hand-over the binding made before, now only when a conversion asks.
    retain_current: bool = false,

    pub fn init(info: *const v8.FunctionCallbackInfo, retain_current: bool) CallFrame {
        return .{ .info = info, .isolate = info.getIsolate(), .retain_current = retain_current };
    }

    /// A frame over contexts its caller already holds and releases (a static
    /// operation's): nothing is made or released here.
    pub fn borrowing(info: *const v8.FunctionCallbackInfo, current: *v8.Context, function: *v8.Context) CallFrame {
        return .{
            .info = info,
            .isolate = info.getIsolate(),
            .current = current,
            .function = function,
            .owns_current = false,
            .owns_function = false,
        };
    }

    /// The current context (a Global the frame holds), or null when V8 has
    /// none.
    pub fn currentContext(self: *CallFrame) ?*v8.Context {
        if (self.current == null) self.current = v8.v8_Isolate_GetCurrentContext(self.isolate);
        return self.current;
    }

    /// The function's creation context - "the function's realm" WebIDL
    /// throws in - or, for a function with none, the current context.
    pub fn functionContext(self: *CallFrame) ?*v8.Context {
        if (self.function == null) {
            if (self.info.getFunctionCreationContext()) |made| {
                self.function = made;
                self.owns_function = true;
            } else {
                self.function = self.currentContext();
                self.owns_function = false;
            }
        }
        return self.function;
    }

    /// End the frame: release what it made and keeps.
    pub fn release(self: *CallFrame) void {
        if (self.owns_function) {
            if (self.function) |c| v8.v8_Context_Dispose(c);
        }
        if (self.owns_current and !self.retain_current) {
            if (self.current) |c| v8.v8_Context_Dispose(c);
        }
        self.function = null;
        self.current = null;
    }
};

/// What `v8_FunctionCallbackInfo_ReadArgument` read of an argument, with no
/// handle (the FFI struct, ffi.zig).
pub const ArgumentRead = v8.ArgumentRead;

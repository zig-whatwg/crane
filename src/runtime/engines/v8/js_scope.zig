//! JsScope - RAII Scope Guard for V8 Operations
//!
//! This module provides a scope guard similar to Chromium's `ScriptState::Scope`
//! that bundles HandleScope creation and context entry into a single abstraction.
//!
//! ## Problem
//!
//! V8 requires a `HandleScope` to exist when creating Local handles. When JavaScript
//! calls into Zig, V8 automatically provides a HandleScope. However, when Zig code
//! initiates V8 operations from outside V8 (timers, event dispatch, async callbacks),
//! there is NO automatic HandleScope - causing the fatal error:
//!
//! ```
//! Fatal error in v8::HandleScope::CreateHandle()
//! Cannot create a handle without a HandleScope
//! ```
//!
//! ## Solution
//!
//! Use `JsScope` at entry points where Zig code initiates V8 operations:
//! - Timer callbacks (setTimeout, setInterval)
//! - Event dispatch
//! - Promise continuations
//! - Any async operation entering V8
//!
//! ## Usage
//!
//! ```zig
//! fn timerCallback(data: ?*anyopaque) void {
//!     const instance = getInstanceFromData(data);
//!
//!     // Create scope - handles HandleScope + context entry
//!     var scope = JsScope.init(instance) orelse return;
//!     defer scope.deinit();
//!
//!     // Now safe to do V8 operations
//!     dispatchEvent(instance, event);
//! }
//! ```
//!
//! ## Design (following Chromium's ScriptState::Scope pattern)
//!
//! The scope:
//! 1. Gets the current isolate
//! 2. Creates a HandleScope (required for Local handle creation)
//! 3. Enters the V8 context (required for JavaScript execution)
//! 4. On deinit: exits context and disposes HandleScope
//!
//! Nested scopes are safe - V8 handles them correctly.

const ffi = @import("ffi.zig");

/// RAII scope guard for V8 operations.
///
/// Creates a HandleScope and enters the V8 context on init.
/// Exits context and disposes HandleScope on deinit.
///
/// Use this at entry points where Zig initiates V8 operations
/// (timers, events, async callbacks).
pub const JsScope = struct {
    handle_scope: *ffi.HandleScope,
    context: *ffi.Context,
    isolate: *ffi.Isolate,

    /// Initialize a JsScope from a runtime Context.
    ///
    /// The context must have a valid engine_ctx (V8 context pointer).
    /// Returns null if:
    /// - No current isolate
    /// - engine_ctx is null
    /// - HandleScope creation fails
    ///
    /// Usage:
    /// ```zig
    /// var scope = JsScope.init(instance.ctx) orelse return;
    /// defer scope.deinit();
    /// // V8 operations now safe
    /// ```
    pub fn init(ctx: anytype) ?JsScope {
        // Get the V8 context from the runtime context's engine_ctx field
        const engine_ctx = ctx.engine_ctx orelse return null;
        const v8_context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
        return initFromV8Context(v8_context);
    }

    /// Initialize a JsScope from a raw V8 Context pointer.
    ///
    /// This is the lowest-level init function. Use when you have
    /// direct access to the V8 context pointer.
    pub fn initFromV8Context(v8_context: *ffi.Context) ?JsScope {
        // Get the current isolate
        const isolate = ffi.v8_Isolate_GetCurrent() orelse return null;

        // Create HandleScope - this is CRITICAL for Local handle creation
        const handle_scope = ffi.v8_HandleScope_New(isolate) orelse return null;

        // Enter the context - required for JavaScript execution
        ffi.v8_Context_Enter(v8_context);

        return JsScope{
            .handle_scope = handle_scope,
            .context = v8_context,
            .isolate = isolate,
        };
    }

    /// Initialize a JsScope with just an isolate (uses current context).
    ///
    /// Use this when you have an isolate but need to get the current context.
    pub fn initFromIsolate(isolate: *ffi.Isolate) ?JsScope {
        // Get current context from isolate
        const v8_context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return null;

        // Create HandleScope
        const handle_scope = ffi.v8_HandleScope_New(isolate) orelse return null;

        // Enter the context
        ffi.v8_Context_Enter(v8_context);

        return JsScope{
            .handle_scope = handle_scope,
            .context = v8_context,
            .isolate = isolate,
        };
    }

    /// Clean up the scope.
    ///
    /// Exits the V8 context and disposes the HandleScope.
    /// Always use with `defer`:
    ///
    /// ```zig
    /// var scope = JsScope.init(instance) orelse return;
    /// defer scope.deinit();
    /// ```
    pub fn deinit(self: JsScope) void {
        // Exit context first (reverse order of init)
        ffi.v8_Context_Exit(self.context);

        // Then dispose HandleScope
        ffi.v8_HandleScope_Dispose(self.handle_scope);
    }

    /// Get the V8 isolate for this scope.
    pub fn getIsolate(self: JsScope) *ffi.Isolate {
        return self.isolate;
    }

    /// Get the V8 context for this scope.
    pub fn getContext(self: JsScope) *ffi.Context {
        return self.context;
    }
};

/// Convenience function to check if we're currently in a valid V8 context.
///
/// Use this to guard early returns before creating a JsScope:
/// ```zig
/// if (!isV8ContextValid(instance.ctx)) return;
/// var scope = JsScope.init(instance.ctx) orelse return;
/// defer scope.deinit();
/// ```
pub fn isV8ContextValid(ctx: anytype) bool {
    if (ctx.engine_ctx == null) return false;
    if (ffi.v8_Isolate_GetCurrent() == null) return false;
    return true;
}

test "JsScope basic structure" {
    // This is a compile-time test to ensure the struct is well-formed
    const scope_size = @sizeOf(JsScope);
    const expected_size = @sizeOf(*ffi.HandleScope) + @sizeOf(*ffi.Context) + @sizeOf(*ffi.Isolate);
    try @import("std").testing.expectEqual(expected_size, scope_size);
}

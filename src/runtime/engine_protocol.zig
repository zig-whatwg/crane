//! Crane's JavaScript engine protocol: module `engine`.
//!
//! The operations every engine adapter provides, declared once here with the
//! signatures that ARE the contract (AGENTS.md, "The engine boundary").
//! Consumers `@import("engine")` and call `engine.op(...)`:
//!
//!     const engine = @import("engine");
//!     const promise = try engine.createResolvedPromise(realm, value);
//!     return promise.take(); // OWNED: the binding takes it
//!
//! Dispatch is static. `engine_impl` is the adapter build.zig binds from
//! `-Dengine=` - src/runtime/engines/<engine>/protocol.zig - and each
//! operation below is an inline function whose body calls that adapter's
//! function of the same name, so a call site compiles to a direct call into
//! the adapter: no table, no optional unwrap, no `ctx.getEngine()`.
//!
//! The contract is checked at compile time, whenever this module is used
//! (the `comptime` block at the end of the file). Every public inline
//! function here is an operation, and the adapter must declare a function of
//! the same name with exactly the same parameter and return types; a missing
//! or mis-typed one is a compile error in this file that names the operation
//! - whether or not anything calls it.
//!
//! An operation an engine can only offer with a capability (`requires`) is
//! checked, and may be called, only where `capabilities` says the engine has
//! it. `capabilities` is comptime-known, so a caller writes
//! `if (engine.capabilities.X) engine.op(...)` and, on an engine without X,
//! the branch is compiled out - calling the operation outside such a branch
//! there is a compile error, and the adapter need not declare it at all.
//!
//! Ownership is in the types. A JSValue PARAMETER is BORROWED for the call;
//! a result the caller must release is `Owned`; `realm: Context` is BORROWED.
//!
//! Status: the first operations of the protocol, alongside the runtime Engine
//! table (src/runtime/engine_interface.zig) - the table serves everything
//! not yet declared here, and both reach the same adapter functions.

const std = @import("std");
const runtime = @import("runtime");
const impl = @import("engine_impl");

// ============================================================================
// Types
// ============================================================================

/// A realm's identity - HTML's realm, ECMAScript's Realm Record - as the
/// runtime records it. Stable until the realm is torn down. BORROWED
/// wherever an operation takes one.
pub const Context = runtime.Context;

/// An ECMAScript agent: a V8 isolate, a JavaScriptCore context group. Opaque
/// to consumers; a realm records its own (`Context.agent`).
pub const Agent = runtime.Agent;

/// The IDL-level value. As a parameter, always BORROWED for the call.
pub const JSValue = runtime.JSValue;

/// Steps an operation runs inside a realm; `data` is the pointer the caller
/// passed alongside them.
pub const RealmSteps = runtime.RealmSteps;

/// What an operation fails with. `NotSupported` is an engine without the
/// operation; `ExceptionPending` is script having thrown, the exception
/// still pending in the engine (return it without throwing another);
/// `OperationFailed` is the engine failing.
pub const Error = runtime.EngineError;

/// A value the caller owns: every operation whose result must be released
/// returns one. Exactly one of `release` and `take` ends it.
pub const Owned = struct {
    value: JSValue,

    /// Give the value back to the engine.
    pub fn release(self: Owned) void {
        releaseValue(self);
    }

    /// Hand the value, and the duty to release it, to something documented
    /// to take ownership - the binding, for an operation's result.
    pub fn take(self: Owned) JSValue {
        return self.value;
    }
};

/// ECMAScript's Completion Record, from an operation that runs script: the
/// value it returned, or the value it threw. OWNED either way.
pub const Completion = union(enum) {
    normal: Owned,
    throw: Owned,
};

/// What an engine can do that another cannot - each a declared deviation,
/// never a silent one. Comptime-known: a host path that needs a capability is
/// compiled out where the engine lacks it.
pub const Capabilities = struct {
    /// ECMAScript modules: HostLoadImportedModule and module records.
    /// Without it, `<script type=module>` fires `error` and `import()`
    /// rejects with a TypeError.
    module_scripts: bool,
    /// HostPromiseRejectionTracker and [[PromiseIsHandled]]. Without it,
    /// no `unhandledrejection` / `rejectionhandled` events.
    promise_rejection_tracking: bool,
    /// A WindowProxy distinct from the global, kept across navigations.
    /// Without it, a navigation that makes a new Window gives
    /// `contentWindow` a new identity.
    reuse_window_proxy: bool,
    /// Microtask checkpoints at HTML's points. Without it, they happen when
    /// the engine's outermost call returns.
    microtask_checkpoint_control: bool,
    /// ECMAScript GetFunctionRealm. Without it, a callback's realm is the one
    /// recorded when it was converted.
    exact_function_realm: bool,
    /// Realms restored from a heap snapshot. Without it, every realm is
    /// created afresh.
    restores_snapshots: bool,
    /// An agent's [[CanBlock]] set by the host. Without it, the engine's
    /// default.
    can_block_control: bool,
    /// Diagnostics for tools, never for spec code: heap statistics, heap
    /// snapshots and the engine's own counters.
    heap_statistics: bool,
    heap_snapshots: bool,
    diagnostic_counters: bool,
};

/// The capabilities of the engine this build selected.
pub const capabilities: Capabilities = impl.capabilities;

/// The engine this build selected, for messages ("V8", "JavaScriptCore").
pub const name: []const u8 = impl.name;

/// The operations that need a capability, and which: each is checked, and
/// callable, only where `capabilities` has it.
const requires = struct {
    pub const promiseIsHandled: Capability = .promise_rejection_tracking;
};

const Capability = std.meta.FieldEnum(Capabilities);

// ============================================================================
// Operations
// ============================================================================

/// ECMAScript's current realm: the realm of the running execution context.
/// While a binding runs - an operation, attribute or constructor - it is the
/// realm of the running function object, which is where WebIDL converts the
/// result. Null when no script is running, or the running context is not a
/// realm the engine hosts.
pub inline fn currentRealm() ?Context {
    return impl.currentRealm();
}

/// ECMAScript IsCallable(`value`). `value` is BORROWED.
pub inline fn isCallable(value: JSValue) bool {
    return impl.isCallable(value);
}

/// Give an owned value back to the engine. A value that holds no engine
/// resource is left alone, so any Owned may be released.
pub inline fn releaseValue(value: Owned) void {
    impl.releaseValue(value);
}

/// WebIDL "a promise resolved with" `value` (§ 3.2.24), made in `realm`.
/// `value` is BORROWED. OWNED: release it, or `take()` it to hand it to the
/// binding.
pub inline fn createResolvedPromise(realm: Context, value: JSValue) Error!Owned {
    return impl.createResolvedPromise(realm, value);
}

/// HTML "queue a global task" (8.1.7.1), the task's run side: run `steps` as
/// a task of `realm` - entering the realm (for a worker realm, its agent
/// too), and afterwards doing what ends a task there. For a caller on the
/// host's event loop - a network completion, a timer - that is not already
/// running script in that realm.
pub inline fn runTaskInRealm(realm: Context, steps: RealmSteps, data: ?*anyopaque) Error!void {
    return impl.runTaskInRealm(realm, steps, data);
}

/// Collect `agent`'s garbage now, as completely as the engine can - for
/// TestUtils.gc() only (the TestUtils Standard: never in a shipping
/// configuration).
pub inline fn requestGarbageCollection(agent: *Agent) void {
    impl.requestGarbageCollection(agent);
}

/// [[PromiseIsHandled]] of `promise` - what HTML's "notify about rejected
/// promises" reads. False for a value that is not a promise. BORROWED.
/// Needs `capabilities.promise_rejection_tracking`.
pub inline fn promiseIsHandled(promise: JSValue) bool {
    comptime gate("promiseIsHandled");
    return impl.promiseIsHandled(promise);
}

// ============================================================================
// The contract, checked
// ============================================================================

/// A gated operation reached where the engine lacks its capability: say so,
/// and how to write the call.
fn gate(comptime operation: []const u8) void {
    const capability = @tagName(@field(requires, operation));
    if (!@field(capabilities, capability)) @compileError("engine." ++ operation ++ " needs engine.capabilities." ++
        capability ++ ", which " ++ name ++ " does not have: call it inside `if (engine.capabilities." ++
        capability ++ ")`, which compiles the call out on this engine");
}

comptime {
    const protocol = @This();
    for (@typeInfo(protocol).@"struct".decls) |decl| {
        const expected = switch (@typeInfo(@TypeOf(@field(protocol, decl.name)))) {
            .@"fn" => |f| f,
            else => continue,
        };
        // Every public inline function is an operation.
        if (expected.calling_convention != .@"inline") continue;
        if (@hasDecl(requires, decl.name) and !@field(capabilities, @tagName(@field(requires, decl.name)))) continue;
        conforms(decl.name, expected);
    }
}

/// The adapter declares `operation` with exactly the protocol's parameter and
/// return types.
fn conforms(comptime operation: []const u8, comptime expected: std.builtin.Type.Fn) void {
    const adapter = name ++ " engine adapter (engine_impl)";
    if (!@hasDecl(impl, operation)) @compileError(adapter ++ " lacks protocol operation `" ++ operation ++ "`");
    const Actual = @TypeOf(@field(impl, operation));
    const actual = switch (@typeInfo(Actual)) {
        .@"fn" => |f| f,
        else => @compileError(adapter ++ ": `" ++ operation ++ "` is not a function"),
    };
    var same = actual.return_type == expected.return_type and actual.params.len == expected.params.len and !actual.is_generic;
    if (same) {
        for (actual.params, expected.params) |a, e| {
            if (a.type != e.type) same = false;
        }
    }
    if (!same) @compileError(adapter ++ ": `" ++ operation ++ "` is " ++ @typeName(Actual) ++
        "; the protocol's signature is " ++ signature(expected));
}

fn signature(comptime f: std.builtin.Type.Fn) []const u8 {
    var text: []const u8 = "fn (";
    for (f.params, 0..) |p, i| text = text ++ (if (i == 0) "" else ", ") ++ @typeName(p.type.?);
    return text ++ ") " ++ @typeName(f.return_type.?);
}

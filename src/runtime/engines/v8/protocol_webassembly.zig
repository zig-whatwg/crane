//! WebAssembly Web API 2, "compile a potential WebAssembly response"
//! [webassembly_streaming], for V8.
//!
//! V8 owns WebAssembly: it defines `compileStreaming` and
//! `instantiateStreaming` on every context of an isolate that has a
//! WasmStreamingCallback (wasm-js.cc WasmJs::Install, per context, never into
//! a snapshot), does Promise.resolve(source).then itself, and calls that
//! callback with what the source fulfilled with and a WasmStreaming - the
//! split Blink's v8_wasm_response_extensions.cc is written against. createAgent
//! sets the callback on the isolate of an agent whose host supplies
//! HostHooks.compilePotentialWebAssemblyResponse, before any realm of it
//! exists; v8_wrapper.cpp's callback reaches `onWasmStreaming` here through
//! the process's one dispatcher, which hands the host a `Compilation`.
//!
//! Every compilation has exactly one end of each kind:
//! - V8's side (the C++ record holding the WasmStreaming) is ended once, by
//!   whichever comes first: the host's finish or abort, the end of the realm
//!   it was handed in (an abort with no reason: the call's promise is never
//!   settled, as Blink aborts when its context is gone), or the agent's end.
//! - The Zig record is freed once: by the host's finish or abort, or - for one
//!   the host never ended - by the agent's end, after which the host must not
//!   touch it (engine.HostHooks.compilePotentialWebAssemblyResponse).
//! The C++ record holds a shared_ptr<WasmStreaming>, which must not outlive
//! its isolate: the agent's end (`Compilations.endAll`) runs before the
//! isolate is disposed.
//!
//! Single-threaded: a compilation is made, fed and ended on its agent's thread.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const context_manager = @import("context_manager.zig");
const protocol_agents = @import("protocol_agents.zig");
const realm_finalizers = @import("realm_finalizers.zig");
const support = @import("protocol_support.zig");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Error = engine.Error;

/// engine.WebAssemblyResponseCompilation, as V8's adapter keeps it.
pub const Compilation = struct {
    /// V8's side; null once ended - by the host, or by the engine at its
    /// realm's end or its agent's.
    native: ?*ffi.WasmResponseCompilation,
    isolate: *ffi.Isolate,
    /// The realm the host was handed it in: the compileStreaming call's.
    realm: Context,
    /// The agent's list (`Compilations`), until the Zig record is freed.
    agent: *Compilations,
    prev: ?*Compilation = null,
    next: ?*Compilation = null,
    /// On `realm`'s finalizer list while V8's side is live: the realm's end
    /// ends it (`droppedWithRealm`).
    realm_node: realm_finalizers.Node = .{ .drop = droppedWithRealm },

    fn of(compilation: *engine.WebAssemblyResponseCompilation) *Compilation {
        return @ptrCast(@alignCast(compilation));
    }

    fn handle(self: *Compilation) *engine.WebAssemblyResponseCompilation {
        return @ptrCast(self);
    }

    /// End V8's side without settling the call's promise, if it is live.
    fn abortNative(self: *Compilation) void {
        self.realm_node.unlink();
        const native = self.native orelse return;
        self.native = null;
        const entered = IsolateEntered.of(self.isolate);
        defer entered.leave();
        ffi.v8_WasmResponseCompilation_Abort(native, null);
    }

    /// Off every list, and freed.
    fn destroy(self: *Compilation) void {
        std.debug.assert(self.native == null);
        self.realm_node.unlink();
        const list = self.agent;
        list.remove(self);
        list.allocator.destroy(self);
    }
};

/// The realm the host was handed a compilation in has ended: V8's side ends
/// with no settlement - nothing can see the call's promise any more. The Zig
/// record stays the host's until it ends it, or until the agent ends.
fn droppedWithRealm(node: *realm_finalizers.Node) void {
    const self: *Compilation = @fieldParentPtr("realm_node", node);
    self.abortNative();
}

/// An agent's compilations the host has not ended (AgentRecord
/// `webassembly_compilations`). Reached on the agent's own thread only.
pub const Compilations = struct {
    /// AgentOptions.allocator: the Zig records' allocator.
    allocator: std.mem.Allocator,
    head: ?*Compilation = null,
    count: usize = 0,

    fn add(self: *Compilations, compilation: *Compilation) void {
        compilation.prev = null;
        compilation.next = self.head;
        if (self.head) |head| head.prev = compilation;
        self.head = compilation;
        self.count += 1;
    }

    fn remove(self: *Compilations, compilation: *Compilation) void {
        if (compilation.prev) |prev| prev.next = compilation.next else self.head = compilation.next;
        if (compilation.next) |next| next.prev = compilation.prev;
        compilation.prev = null;
        compilation.next = null;
        self.count -= 1;
    }

    /// The agent ends, before its isolate is disposed: every compilation the
    /// host has not ended ends here - V8's side without settling, if its
    /// realm's end had not already ended it - and its record is freed. The
    /// host must not touch one after.
    pub fn endAll(self: *Compilations) void {
        while (self.head) |compilation| {
            compilation.abortNative();
            compilation.destroy();
        }
    }

    /// How many of the agent's compilations still hold V8's side - for tests.
    pub fn liveNative(self: *const Compilations) usize {
        var live: usize = 0;
        var at = self.head;
        while (at) |compilation| : (at = compilation.next) {
            if (compilation.native != null) live += 1;
        }
        return live;
    }
};

/// `isolate` entered for the scope of a call, if it is not the current one:
/// V8's WasmStreaming works in its isolate.
const IsolateEntered = struct {
    isolate: *ffi.Isolate,
    entered: bool,

    fn of(isolate: *ffi.Isolate) IsolateEntered {
        const entered = ffi.v8_Isolate_GetCurrent() != isolate;
        if (entered) ffi.v8_Isolate_Enter(isolate);
        return .{ .isolate = isolate, .entered = entered };
    }

    fn leave(self: IsolateEntered) void {
        if (self.entered) ffi.v8_Isolate_Exit(self.isolate);
    }
};

/// v8_wrapper.cpp's WasmStreamingCallback, through the process's dispatcher
/// (initializeEngine): `context` is the compileStreaming call's, `source` -
/// BORROWED for the call - what its source fulfilled with. Hands the host a
/// new Compilation over `native`; false when the agent has no such host or
/// the realm has ended, and the caller then rejects `native` with a TypeError
/// and deletes it.
pub fn onWasmStreaming(isolate: *ffi.Isolate, context: *ffi.Context, source: *ffi.Value, native: *ffi.WasmResponseCompilation) callconv(.c) bool {
    const record = protocol_agents.recordOf(isolate) orelse return false;
    const hook = record.hooks.compilePotentialWebAssemblyResponse orelse return false;
    const realm = context_manager.get(context) orelse return false;
    const list = &record.webassembly_compilations;
    const compilation = list.allocator.create(Compilation) catch return false;
    compilation.* = .{ .native = native, .isolate = isolate, .realm = realm, .agent = list };
    // A realm with a wrapper cache ends its compilations (`droppedWithRealm`);
    // one with none (a host's own context) leaves them to the host and the
    // agent's end.
    if (realm_finalizers.listOf(realm)) |finalizers| {
        finalizers.add(&compilation.realm_node) catch {
            list.allocator.destroy(compilation);
            return false;
        };
    }
    list.add(compilation);
    hook(record.host, realm, support.borrowed(source), compilation.handle());
    return true;
}

/// engine.appendWebAssemblyResponseBytes: WasmStreaming::OnBytesReceived,
/// in the compilation's realm. Without effect once V8's side has ended.
pub fn appendWebAssemblyResponseBytes(compilation: *engine.WebAssemblyResponseCompilation, bytes: []const u8) Error!void {
    const self = Compilation.of(compilation);
    const native = self.native orelse return;
    if (bytes.len == 0) return;
    const entered = support.enter(self.realm) catch {
        // The realm has gone: nothing can see the promise any more.
        self.abortNative();
        return;
    };
    defer entered.leave();
    ffi.v8_WasmResponseCompilation_Append(native, bytes.ptr, bytes.len);
}

/// engine.finishWebAssemblyResponse: WasmStreaming::SetUrl and Finish, in
/// the compilation's realm; then the record is freed.
pub fn finishWebAssemblyResponse(compilation: *engine.WebAssemblyResponseCompilation, url: []const u8) void {
    const self = Compilation.of(compilation);
    if (self.native) |native| {
        self.realm_node.unlink();
        self.native = null;
        if (support.enter(self.realm)) |entered| {
            defer entered.leave();
            ffi.v8_WasmResponseCompilation_Finish(native, url.ptr, url.len);
        } else |_| {
            const isolate_entered = IsolateEntered.of(self.isolate);
            defer isolate_entered.leave();
            ffi.v8_WasmResponseCompilation_Abort(native, null);
        }
    }
    self.destroy();
}

/// engine.abortWebAssemblyResponse: WasmStreaming::Abort with `reason` - as
/// a value of the compilation's realm - or with none; then the record is
/// freed.
pub fn abortWebAssemblyResponse(compilation: *engine.WebAssemblyResponseCompilation, reason: ?JSValue) void {
    const self = Compilation.of(compilation);
    if (self.native) |native| {
        const given = reason orelse {
            self.abortNative();
            return self.destroy();
        };
        self.realm_node.unlink();
        self.native = null;
        const entered = support.enter(self.realm) catch {
            const isolate_entered = IsolateEntered.of(self.isolate);
            defer isolate_entered.leave();
            ffi.v8_WasmResponseCompilation_Abort(native, null);
            return self.destroy();
        };
        defer entered.leave();
        // A handle is a Global already; anything else - a platform object, an
        // inline primitive - is made one in the realm.
        const held: ?*ffi.Value = if (support.handleOf(given) == null) support.ownGlobal(entered, given) catch null else null;
        defer if (held) |h| ffi.v8_Global_Dispose(h);
        const value = support.handleOf(given) orelse held;
        if (value == null) {
            // The reason could not be made a value: still reject, with a
            // TypeError, rather than leave the promise pending.
            const type_error = support.newTypeError(entered.isolate, entered.context(), "WebAssembly compilation aborted") catch null;
            defer if (type_error) |e| ffi.v8_Global_Dispose(e);
            ffi.v8_WasmResponseCompilation_Abort(native, type_error);
        } else {
            ffi.v8_WasmResponseCompilation_Abort(native, value);
        }
    }
    self.destroy();
}

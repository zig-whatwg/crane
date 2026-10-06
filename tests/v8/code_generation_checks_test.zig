//! The engine protocol's code generation checks [code_generation_checks],
//! as the V8 adapter wires them (protocol_agents.zig, v8_wrapper.cpp):
//! HostEnsureCanCompileStrings for eval and the Function constructors,
//! HostGetCodeForEval for an eval of an object, HostEnsureCanCompileWasmBytes
//! for WebAssembly - in every realm path of a hooked agent (a Window realm, a
//! frame's, a worker's), and in none of an agent without the hooks.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent), makes its own agents, and leaves no
//! isolate entered that it entered.

const std = @import("std");
/// Every worker realm has an event loop; this test drives none.
const inline_task_loop = @import("inline_task_loop.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// The test's host: what each hook was asked, and what it answers.
const Host = struct {
    verdict: protocol.StringCompilationVerdict = .allowed,
    wasm_allowed: bool = true,
    strings_calls: usize = 0,
    code_calls: usize = 0,
    wasm_calls: usize = 0,
    compilation_type: ?protocol.StringCompilationType = null,
    code_like: bool = false,
    realm: ?runtime.Context = null,
    argument_was_handle: bool = false,
    code_buffer: [256]u8 = undefined,
    code_len: usize = 0,

    const hooks: protocol.HostHooks = .{
        .ensureCanCompileStrings = ensure,
        .getCodeForEval = getCode,
        .ensureCanCompileWasmBytes = wasm,
    };

    fn ensure(host: ?*anyopaque, realm: runtime.Context, compilation: *const protocol.StringCompilation) protocol.StringCompilationVerdict {
        const self: *Host = @ptrCast(@alignCast(host.?));
        self.strings_calls += 1;
        self.compilation_type = compilation.compilation_type;
        self.code_like = compilation.arguments_are_code_like;
        self.realm = realm;
        self.code_len = @min(compilation.code_string.len, self.code_buffer.len);
        @memcpy(self.code_buffer[0..self.code_len], compilation.code_string[0..self.code_len]);
        return self.verdict;
    }

    /// HostGetCodeForEval for this host: an object with a string `code`
    /// property has that code; anything else none. The argument comes as the
    /// binding hands an `any` object to the host - a handle - and is read
    /// through the protocol.
    fn getCode(host: ?*anyopaque, realm: runtime.Context, argument: runtime.JSValue, allocator: std.mem.Allocator) ?[]u8 {
        const self: *Host = @ptrCast(@alignCast(host.?));
        self.code_calls += 1;
        self.argument_was_handle = argument == .handle;
        const code = protocol.getProperty(realm, argument, "code") catch return null;
        defer code.release();
        if (protocol.typeOf(realm, code.value) != .string) return null;
        return protocol.convertToDOMString(realm, code.value, allocator) catch null;
    }

    fn wasm(host: ?*anyopaque, realm: runtime.Context) bool {
        const self: *Host = @ptrCast(@alignCast(host.?));
        self.wasm_calls += 1;
        self.realm = realm;
        return self.wasm_allowed;
    }

    fn seenCode(self: *const Host) []const u8 {
        return self.code_buffer[0..self.code_len];
    }
};

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

fn windowRealm(agent: *protocol.Agent) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
}

/// `source`'s completion value in `realm`, as a string; nothing reported.
fn evalString(realm: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    const result = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter());
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    return result;
}

fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try evalString(realm, source);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

/// Whether `realm`'s context lets V8 compile strings without asking.
fn compilesWithoutAsking(realm: runtime.Context) !bool {
    const Probe = struct {
        realm: runtime.Context,
        allowed: bool = false,
        fn steps(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const context: *ffi.Context = @ptrCast(@alignCast(self.realm.engine_ctx.?));
            self.allowed = ffi.v8_Context_IsCodeGenerationFromStringsAllowed(context);
        }
    };
    var probe: Probe = .{ .realm = realm };
    try protocol.runInRealm(realm, Probe.steps, &probe);
    return probe.allowed;
}

test "code generation checks: a hooked agent's Window realm asks the host before eval and the Function constructors compile" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    try std.testing.expect(!try compilesWithoutAsking(realm));

    // Direct eval: PerformEval's codeString is the argument.
    try expectEval(realm, "eval('1 + 1')", "2");
    try std.testing.expectEqual(protocol.StringCompilationType.eval, host.compilation_type.?);
    try std.testing.expectEqualStrings("1 + 1", host.seenCode());
    try std.testing.expect(!host.code_like);
    try std.testing.expectEqual(realm, host.realm.?);
    // Indirect eval is eval too.
    try expectEval(realm, "(0, eval)('2 + 2')", "4");
    try std.testing.expectEqual(protocol.StringCompilationType.eval, host.compilation_type.?);
    try std.testing.expectEqualStrings("2 + 2", host.seenCode());

    // CreateDynamicFunction's sourceString, as ECMA-262 builds it.
    try expectEval(realm, "new Function('a', 'b', 'return a + b')(1, 2)", "3");
    try std.testing.expectEqual(protocol.StringCompilationType.function, host.compilation_type.?);
    try std.testing.expectEqualStrings("function anonymous(a,b\n) {\nreturn a + b\n}", host.seenCode());
    try expectEval(realm, "typeof new (async function () {}.constructor)('return 1')", "function");
    try std.testing.expectEqualStrings("async function anonymous(\n) {\nreturn 1\n}", host.seenCode());
    try expectEval(realm, "typeof new (function* () {}.constructor)('yield 1')", "function");
    try std.testing.expectEqualStrings("function* anonymous(\n) {\nyield 1\n}", host.seenCode());
    try expectEval(realm, "typeof new (async function* () {}.constructor)('yield 1')", "function");
    try std.testing.expectEqualStrings("async function* anonymous(\n) {\nyield 1\n}", host.seenCode());

    // Blocked: EvalError, and nothing ran.
    host.verdict = .blocked;
    try expectEval(realm, "try { eval('globalThis.ran = 1'); 'compiled' } catch (e) { e instanceof EvalError }", "true");
    try expectEval(realm, "try { (0, eval)('globalThis.ran = 1'); 'compiled' } catch (e) { e instanceof EvalError }", "true");
    try expectEval(realm, "try { new Function('globalThis.ran = 1'); 'compiled' } catch (e) { e instanceof EvalError }", "true");
    try expectEval(realm, "typeof globalThis.ran", "undefined");
    host.verdict = .allowed;
}

test "code generation checks: an eval of an object compiles HostGetCodeForEval's code, or returns the object unchecked" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);

    // Code: compiled in the object's place, checked with its arguments
    // code-like.
    try expectEval(realm, "eval({ code: '40 + 2' })", "42");
    try std.testing.expect(host.argument_was_handle);
    try std.testing.expectEqualStrings("40 + 2", host.seenCode());
    try std.testing.expect(host.code_like);
    host.verdict = .blocked;
    try expectEval(realm, "try { eval({ code: '1' }); 'compiled' } catch (e) { e instanceof EvalError }", "true");
    host.verdict = .allowed;

    // No code: the object itself, and the strings check never ran.
    const before = host.strings_calls;
    try expectEval(realm, "const o = { other: 1 }; eval(o) === o", "true");
    try expectEval(realm, "eval(5) === 5 && eval(null) === null", "true");
    try std.testing.expectEqual(before, host.strings_calls);
}

test "code generation checks: WebAssembly compilation asks the host; false is a CompileError" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);

    const empty_module = "const bytes = new Uint8Array([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);";
    try expectEval(realm, empty_module ++ " new WebAssembly.Module(bytes) instanceof WebAssembly.Module", "true");
    try std.testing.expect(host.wasm_calls >= 1);
    try std.testing.expectEqual(realm, host.realm.?);
    host.wasm_allowed = false;
    try expectEval(realm, "try { new WebAssembly.Module(new Uint8Array([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0])); 'compiled' } catch (e) { e instanceof WebAssembly.CompileError }", "true");
}

/// A frame's Window realm, made as a frame's is: inside its parent's script.
const FrameRealm = struct {
    agent: *protocol.Agent,
    parent: runtime.Context,
    made: ?runtime.Context = null,
    failed: ?anyerror = null,

    fn steps(data: ?*anyopaque) void {
        const self: *FrameRealm = @ptrCast(@alignCast(data.?));
        self.made = protocol.createWindowRealm(&.{
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .parent = self.parent,
            .create_global_object = WindowHost.createGlobalObject,
        }) catch |err| {
            self.failed = err;
            return;
        };
    }
};

test "code generation checks: a frame's realm and a worker's realm of a hooked agent ask too" {
    try setup();
    var host: Host = .{ .verdict = .blocked };
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const parent = try windowRealm(agent);
    defer protocol.destroyWindowRealm(parent, .global_detached);
    var frame_realm: FrameRealm = .{ .agent = agent, .parent = parent };
    try protocol.runInRealm(parent, FrameRealm.steps, &frame_realm);
    if (frame_realm.failed) |err| return err;
    const frame = frame_realm.made.?;
    defer protocol.destroyWindowRealm(frame, .global_detached);
    try std.testing.expect(!try compilesWithoutAsking(frame));
    try expectEval(frame, "try { eval('1'); 'compiled' } catch (e) { e instanceof EvalError }", "true");
    try std.testing.expectEqual(frame, host.realm.?);

    // A worker's agent, hooked the same way, and its realm.
    var worker_host: Host = .{ .verdict = .blocked };
    const worker_agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &Host.hooks, .host = &worker_host });
    defer protocol.destroyAgent(worker_agent);
    const worker = try protocol.createWorkerRealm(worker_agent, &.{
        .url = "https://example.test/worker.js",
        .timer = null,
        .event_loop = inline_task_loop.eventLoop(),
        .allocator = std.heap.page_allocator,
    });
    defer protocol.destroyWorkerRealm(worker.realm, null, null);
    try std.testing.expect(!try compilesWithoutAsking(worker.realm));
    try expectEval(worker.realm, "try { new Function('return 1'); 'compiled' } catch (e) { e instanceof EvalError }", "true");
    try std.testing.expectEqual(@as(usize, 1), worker_host.strings_calls);
    try std.testing.expectEqual(protocol.StringCompilationType.function, worker_host.compilation_type.?);
}

test "code generation checks: an agent without the hooks compiles everything, and its realms never ask" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    try std.testing.expect(try compilesWithoutAsking(realm));
    try expectEval(realm, "eval('6 * 7') + new Function('return 1')()", "43");
    try expectEval(realm, "new WebAssembly.Module(new Uint8Array([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0])) instanceof WebAssembly.Module", "true");
}

test "code generation checks: the compilation type is read from CreateDynamicFunction's source shape" {
    const of = v8.protocol_agents.stringCompilationOf;
    const function = of("(function anonymous(a\n) {\nreturn a\n})", false);
    try std.testing.expectEqual(protocol.StringCompilationType.function, function.compilation_type);
    try std.testing.expectEqualStrings("function anonymous(a\n) {\nreturn a\n}", function.code_string);
    const eval = of("(function anonymous() {})", true);
    try std.testing.expectEqual(protocol.StringCompilationType.eval, eval.compilation_type);
    try std.testing.expectEqualStrings("(function anonymous() {})", eval.code_string);
    try std.testing.expect(eval.arguments_are_code_like);
    try std.testing.expectEqual(protocol.StringCompilationType.eval, of("1 + 1", false).compilation_type);
}

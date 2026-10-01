//! The live Context Global counter counts every Context Global the wrapper
//! makes.
//!
//! v8_Context_Dispose subtracts one from `live_context_globals` for whatever
//! it is handed, so every function that returns a new Global<Context> must
//! add one. Several did not - v8_FunctionCallbackInfo_GetFunctionCreationContext,
//! which every binding getter and method call takes, among them - so the
//! counter fell by one per call: gc_bench read -1.00 per cycle for a plain
//! `probe.nodeType`, and engine-boundary read -1 per worker realm
//! (v8_Context_NewWithGlobalConstructor). A real leak then read as nothing,
//! or as the drift's opposite. These pin the balance: a creation site added
//! without its count turns them red.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;

/// One isolate and realm for the file, registered with the context manager
/// as a page's is; V8 is never torn down here.
fn realm() !void {
    if (isolate_once != null) return;
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    _ = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    isolate_once = i;
    context_once = context;
}

/// Script's value of `expression`, as an integer.
fn scriptInt(expression: []const u8) !i32 {
    const i = isolate_once.?;
    const context = context_once.?;
    const code = ffi.v8_String_NewFromUtf8(i, expression.ptr, @intCast(expression.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context);
}

test "binding getter and method calls leave live_context_globals unchanged" {
    try realm();
    const context = context_once.?;
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    v8.interface_bindings.Event.registerGlobalFast(isolate_once.?, context, global, "Event");
    // The first calls make what later ones reuse.
    try std.testing.expectEqual(@as(i32, 4), try scriptInt("globalThis.e = new Event('ping'); e.stopPropagation(); e.type.length"));

    const before = ffi.v8_Debug_LiveContextGlobals();
    // 64 getter calls and 64 method calls through the binding.
    try std.testing.expectEqual(@as(i32, 256), try scriptInt("let n = 0; for (let i = 0; i < 64; i++) { n += e.type.length; e.stopPropagation(); } n"));
    const after = ffi.v8_Debug_LiveContextGlobals();
    if (after != before) {
        std.debug.print("live_context_globals {d} -> {d} over 128 binding calls\n", .{ before, after });
        return error.CounterDrift;
    }
}

test "a context made with a global constructor and disposed leaves live_context_globals unchanged" {
    try realm();
    const isolate = isolate_once.?;
    const template = ffi.v8_FunctionTemplate_New(isolate, null, null) orelse return error.TemplateFailed;
    defer ffi.v8_FunctionTemplate_Dispose(template);

    const before = ffi.v8_Debug_LiveContextGlobals();
    for (0..4) |_| {
        const made = ffi.v8_Context_NewWithGlobalConstructor(isolate, template) orelse return error.ContextCreationFailed;
        ffi.v8_Context_Dispose(made);
        const plain = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
        ffi.v8_Context_Dispose(plain);
    }
    const after = ffi.v8_Debug_LiveContextGlobals();
    if (after != before) {
        std.debug.print("live_context_globals {d} -> {d} over 8 contexts made and disposed\n", .{ before, after });
        return error.CounterDrift;
    }
}

// ---------------------------------------------------------------------------
// The binding's API callbacks release the current context they take.
//
// Inside an API callback `v8_Isolate_GetCurrentContext` is the callee's realm,
// and the wrapper hands it out as a Global the caller owns. A callback that
// keeps it pins that realm - every object in it - for the isolate's life, one
// Global per call (docs/lessons/architecture-an-api-callback-s-current-context-
// is-the-callee-s-realm.md). Each test below runs one callback 64 times and
// reads the live Context Global count before and after; V8's own global handle
// bytes cross-check it.

var all_interfaces_installed = false;

/// Every interface, installed once in the file's realm.
fn allInterfaces() !void {
    try realm();
    if (all_interfaces_installed) return;
    v8.interface_bindings.registerAllInterfaces(isolate_once.?, context_once.?);
    all_interfaces_installed = true;
}

const Left = struct {
    context_globals: i64,
    handle_bytes: i64,
};

/// What 64 runs of `body` leave behind: live Context Globals, and V8's global
/// handle bytes after a collection. Two runs first, so that what the first
/// call makes and later ones reuse is not counted.
fn leftBy(comptime body: []const u8) !Left {
    const isolate = isolate_once.?;
    const loop = "(() => { for (let i = 0; i < {N}; i++) { " ++ body ++ " } return 0 })()";
    _ = try scriptInt(comptime replaceN(loop, "2"));
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    const contexts_before = ffi.v8_Debug_LiveContextGlobals();
    const bytes_before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    _ = try scriptInt(comptime replaceN(loop, "64"));
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    return .{
        .context_globals = ffi.v8_Debug_LiveContextGlobals() - contexts_before,
        .handle_bytes = @as(i64, @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate))) - bytes_before,
    };
}

fn replaceN(comptime loop: []const u8, comptime n: []const u8) []const u8 {
    const at = std.mem.indexOf(u8, loop, "{N}").?;
    return loop[0..at] ++ n ++ loop[at + 3 ..];
}

fn expectNothingLeft(comptime what: []const u8, left: Left) !void {
    if (left.context_globals != 0 or left.handle_bytes > 0) {
        std.debug.print("64 runs of {s} left {d} Context Globals and {d} bytes of global handles\n", .{ what, left.context_globals, left.handle_bytes });
        return error.HandlesLeaked;
    }
}

fn expectNoContextLeft(comptime what: []const u8, left: Left) !void {
    if (left.context_globals != 0) {
        std.debug.print("64 runs of {s} left {d} Context Globals\n", .{ what, left.context_globals });
        return error.HandlesLeaked;
    }
}

test "a getter that throws releases the contexts it took" {
    try allInterfaces();
    // WritableStreamDefaultWriter.desiredSize step 1: a released writer's
    // stream is undefined - a TypeError, thrown from the getter's error path.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.releasedWriter = new WritableStream().getWriter();
        \\releasedWriter.releaseLock();
        \\(() => { try { releasedWriter.desiredSize; return 0 } catch (e) { return e instanceof TypeError ? 1 : 2 } })()
    ));
    try expectNothingLeft("a throwing getter", try leftBy("try { releasedWriter.desiredSize } catch (e) {}"));
}

test "the indexed property setter releases the current context" {
    try allInterfaces();
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.setterDoc = new Document().implementation.createHTMLDocument('');
        \\globalThis.select = setterDoc.createElement('select');
        \\globalThis.option = setterDoc.createElement('option');
        \\select[0] = option;
        \\select.length
    ));
    try expectNothingLeft("select[0] = option", try leftBy("select[0] = option;"));
}

test "the indexed property definer releases the current context" {
    try allInterfaces();
    // Object.defineProperty on an indexed collection runs the definer: on a
    // select (an indexed setter) it converts the value and sets the option;
    // on a NodeList (none) it converts nothing.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.definerDoc = new Document().implementation.createHTMLDocument('');
        \\globalThis.definedSelect = definerDoc.createElement('select');
        \\globalThis.definedOption = definerDoc.createElement('option');
        \\globalThis.children = definerDoc.body.childNodes;
        \\Object.defineProperty(definedSelect, '0', { value: definedOption, configurable: true, enumerable: true, writable: true });
        \\definedSelect.length
    ));
    // Context Globals only: the definer's other handles (the descriptor's
    // value, v8_PropertyDescriptor_GetValue, among them) are outside this
    // case, and still leak.
    try expectNoContextLeft("Object.defineProperty(select, '0', ...)", try leftBy("Object.defineProperty(definedSelect, '0', { value: definedOption, configurable: true, enumerable: true, writable: true });"));
    try expectNoContextLeft("Object.defineProperty(nodeList, '0', ...)", try leftBy("try { Object.defineProperty(children, '0', { value: 1 }) } catch (e) {}"));
}

test "the named property setter releases the current context" {
    try allInterfaces();
    try std.testing.expectEqual(@as(i32, 3), try scriptInt(
        \\globalThis.datasetOwner = new Document().implementation.createHTMLDocument('').createElement('div');
        \\datasetOwner.setAttribute('data-foo', 'x');
        \\globalThis.dataset = datasetOwner.dataset;
        \\dataset.foo = 'bar';
        \\datasetOwner.getAttribute('data-foo').length
    ));
    try expectNothingLeft("dataset.foo = 'bar'", try leftBy("dataset.foo = 'bar';"));
}

test "values(options) on a ReadableStream releases the context and the handles it read the options with" {
    try allInterfaces();
    // The first call locks the stream; every later one throws a TypeError
    // after reading its options - the same path, run 64 times.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.lockedStream = new ReadableStream();
        \\lockedStream.values({ preventCancel: true });
        \\(() => { try { lockedStream.values({ preventCancel: true }); return 0 } catch (e) { return e instanceof TypeError ? 1 : 2 } })()
    ));
    try expectNothingLeft("stream.values({ preventCancel: true })", try leftBy("try { lockedStream.values({ preventCancel: true }) } catch (e) {}"));
}

// ---------------------------------------------------------------------------
// A getter's null result is the binding's; a wrapper it returns is not.

test "a getter that answers null releases the null it made" {
    try allInterfaces();
    // Event.target before dispatch (?*runtime.Instance) and
    // MessageEvent.source (?MessageEventSource, a union of wrappers): each
    // null is a fresh v8_Null the binding hands to setReturnValue.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.undispatched = new Event('x');
        \\globalThis.sourceless = new MessageEvent('m');
        \\undispatched.target === null && sourceless.source === null ? 1 : 0
    ));
    try expectNothingLeft("new Event('x').target", try leftBy("undispatched.target;"));
    try expectNothingLeft("new MessageEvent('m').source", try leftBy("sourceless.source;"));
}

test "a getter's wrapper result stays the wrapper cache's" {
    try allInterfaces();
    // A dispatched event keeps its target: the getter returns the target's
    // cached wrapper, which the binding must never release - the next read
    // would then wrap the target anew, without the property set on it.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.kept = new EventTarget();
        \\kept.marker = 42;
        \\globalThis.dispatched = new Event('ping');
        \\kept.dispatchEvent(dispatched);
        \\dispatched.target === kept ? 1 : 0
    ));
    try expectNothingLeft("dispatched.target", try leftBy("if (dispatched.target !== kept) throw new Error('not the same wrapper');"));
    ffi.v8_Isolate_RequestGarbageCollection(isolate_once.?);
    try std.testing.expectEqual(@as(i32, 42), try scriptInt("dispatched.target === kept ? dispatched.target.marker : -1"));
}

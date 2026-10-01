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

/// The page allocator, counting the bytes live through it: the realm's
/// allocator, so that what an impl allocates for a result - a string a
/// getter returns - and the binding never frees shows up as bytes left.
/// `std.testing.allocator` does not see it: the realm outlives every test.
const CountingAllocator = struct {
    live: i64 = 0,

    fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const memory = std.heap.page_allocator.rawAlloc(len, alignment, ret_addr) orelse return null;
        self.live += @intCast(len);
        return memory;
    }
    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        if (!std.heap.page_allocator.rawResize(memory, alignment, new_len, ret_addr)) return false;
        self.live += @as(i64, @intCast(new_len)) - @as(i64, @intCast(memory.len));
        return true;
    }
    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const moved = std.heap.page_allocator.rawRemap(memory, alignment, new_len, ret_addr) orelse return null;
        self.live += @as(i64, @intCast(new_len)) - @as(i64, @intCast(memory.len));
        return moved;
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.live -= @intCast(memory.len);
        std.heap.page_allocator.rawFree(memory, alignment, ret_addr);
    }
};

var realm_allocator: CountingAllocator = .{};

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
    _ = try v8.context_manager.getOrCreate(context, realm_allocator.allocator());
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
    /// Bytes still live through the realm's allocator.
    realm_bytes: i64 = 0,
};

/// What 64 runs of `body` leave behind: live Context Globals, V8's global
/// handle bytes after a collection, and bytes of the realm's allocator. Two
/// runs first, so that what the first call makes and later ones reuse is not
/// counted.
fn leftBy(comptime body: []const u8) !Left {
    const isolate = isolate_once.?;
    const loop = "(() => { for (let i = 0; i < {N}; i++) { " ++ body ++ " } return 0 })()";
    _ = try scriptInt(comptime replaceN(loop, "2"));
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    const contexts_before = ffi.v8_Debug_LiveContextGlobals();
    const bytes_before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    const realm_before = realm_allocator.live;
    _ = try scriptInt(comptime replaceN(loop, "64"));
    ffi.v8_Isolate_RequestGarbageCollection(isolate);
    return .{
        .context_globals = ffi.v8_Debug_LiveContextGlobals() - contexts_before,
        .handle_bytes = @as(i64, @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate))) - bytes_before,
        .realm_bytes = realm_allocator.live - realm_before,
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

/// Nothing left at all: no Context Global, no global handle bytes, and no
/// bytes of the realm's allocator - what an impl allocated for a result is
/// the binding's to free.
fn expectNothingLeftAnywhere(comptime what: []const u8, left: Left) !void {
    if (left.context_globals != 0 or left.handle_bytes > 0 or left.realm_bytes > 0) {
        std.debug.print("64 runs of {s} left {d} Context Globals, {d} bytes of global handles and {d} bytes of the realm's allocator\n", .{ what, left.context_globals, left.handle_bytes, left.realm_bytes });
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
    try expectNoContextLeft("Object.defineProperty(select, '0', ...)", try leftBy("Object.defineProperty(definedSelect, '0', { value: definedOption, configurable: true, enumerable: true, writable: true });"));
    try expectNoContextLeft("Object.defineProperty(nodeList, '0', ...)", try leftBy("try { Object.defineProperty(children, '0', { value: 1 }) } catch (e) {}"));
}

test "the indexed property definer releases every handle it takes" {
    try allInterfaces();
    // Besides the current context: the descriptor's value
    // (v8_PropertyDescriptor_GetValue hands out a Global the caller owns) and
    // whatever else one Object.defineProperty on a select takes - nine
    // handles a call, 288 bytes, before this.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.allDefinedDoc = new Document().implementation.createHTMLDocument('');
        \\globalThis.allDefinedSelect = allDefinedDoc.createElement('select');
        \\globalThis.allDefinedOption = allDefinedDoc.createElement('option');
        \\Object.defineProperty(allDefinedSelect, '0', { value: allDefinedOption, configurable: true, enumerable: true, writable: true });
        \\globalThis.readOnlyCollection = allDefinedDoc.getElementsByTagName('select');
        \\allDefinedDoc.body.appendChild(allDefinedSelect);
        \\(() => { 'use strict'; try { readOnlyCollection[0] = 1; return 0 } catch (e) { return e instanceof TypeError ? allDefinedSelect.length : 2 } })()
    ));
    try expectNothingLeft("Object.defineProperty(select, '0', ...)", try leftBy("Object.defineProperty(allDefinedSelect, '0', { value: allDefinedOption, configurable: true, enumerable: true, writable: true });"));
    try expectNothingLeft("Object.defineProperty(nodeList, '0', ...)", try leftBy("try { Object.defineProperty(children, '0', { value: 1 }) } catch (e) {}"));
    // An HTMLCollection has no indexed setter: a strict-mode assignment to
    // an index reaches the definer, which throws a TypeError whose message
    // and error it made. (Object.defineProperty on it does not throw today,
    // where WebIDL's [[DefineOwnProperty]] returns false - a conformance
    // gap, queued.)
    try expectNothingLeft("'use strict'; htmlCollection[0] = 1", try leftBy("(() => { 'use strict'; try { readOnlyCollection[0] = 1 } catch (e) {} })();"));
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

// ---------------------------------------------------------------------------
// A getter's result is the binding's: a value the conversion makes, and memory
// the impl allocated for it.

test "a getter's non-null optional number is released" {
    try allInterfaces();
    // WritableStreamDefaultWriter.desiredSize is `unrestricted double?`
    // (?f64): non-null on a writable stream, a fresh Number each read.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.sizedWriter = new WritableStream().getWriter();
        \\sizedWriter.desiredSize
    ));
    try expectNothingLeft("writer.desiredSize", try leftBy("sizedWriter.desiredSize;"));
}

test "getterValueIsOwned: the non-null value of an optional primitive is made fresh" {
    // conv.toV8Value converts `?T` by converting its payload, so a non-null
    // `?f64`, `?bool` or `?u32` is a fresh Number or Boolean exactly as an
    // `f64`, `bool` or `u32` is. No impl returns a non-null `?bool` or `?u32`
    // today (RTCPeerConnection.canTrickleIceCandidates, RTCError's alerts are
    // stubs), so the predicate is pinned here.
    const owned = v8.interface_mod.getterValueIsOwned;
    try std.testing.expect(owned(?f64));
    try std.testing.expect(owned(?f32));
    try std.testing.expect(owned(?bool));
    try std.testing.expect(owned(?u32));
    try std.testing.expect(owned(?u16));
    try std.testing.expect(owned(?u8));
    try std.testing.expect(owned(?i32));
    try std.testing.expect(owned(?i16));
    try std.testing.expect(owned(?i8));
    try std.testing.expect(owned(?runtime.USVString));
    const Direction = enum { forward, backward };
    try std.testing.expect(owned(?Direction));
    // The default is unchanged: an optional of a kept value stays kept.
    try std.testing.expect(!owned(?*runtime.Instance));
    try std.testing.expect(!owned(?runtime.JSValue));
}

test "xhr.response frees the text it made" {
    try allInterfaces();
    // XMLHttpRequest response, step 1: for responseType "" the text
    // response - a string the getter makes on each read and hands over
    // owned, as an operation's result is.
    try std.testing.expectEqual(@as(i32, 5), try scriptInt(
        \\globalThis.doneXhr = new XMLHttpRequest();
        \\doneXhr.open('GET', 'data:text/plain,hello', false);
        \\doneXhr.send();
        \\doneXhr.response.length
    ));
    try expectNothingLeftAnywhere("xhr.response", try leftBy("doneXhr.response;"));
}

test "a getter's kept string stays the object's: read twice, and 64 times, it is the same" {
    try allInterfaces();
    // MessageEvent.data and PopStateEvent.state keep a string they were
    // initialized with. The getter path frees a string result handed over
    // owned, so a kept one goes out as a reference - handed over owned,
    // the first read freed the event's own copy and the second read it
    // after the free.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.textEvent = new MessageEvent('message', { data: 'kept text' });
        \\globalThis.stateEvent = new PopStateEvent('popstate', { state: 'kept state' });
        \\textEvent.data === 'kept text' && textEvent.data === 'kept text' &&
        \\    stateEvent.state === 'kept state' && stateEvent.state === 'kept state' ? 1 : 0
    ));
    try expectNothingLeftAnywhere("messageEvent.data", try leftBy("if (textEvent.data !== 'kept text') throw new Error(textEvent.data);"));
    try expectNothingLeftAnywhere("popStateEvent.state", try leftBy("if (stateEvent.state !== 'kept state') throw new Error(stateEvent.state);"));
    try std.testing.expectEqual(@as(i32, 1), try scriptInt("textEvent.data === 'kept text' && stateEvent.state === 'kept state' ? 1 : 0"));
}

test "the indexed descriptor and query release what they make" {
    try allInterfaces();
    // V8 asks a legacy platform object for an index's descriptor
    // (Object.getOwnPropertyDescriptor) and attributes (`in`); each answer
    // is made for the call.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.describedDoc = new Document().implementation.createHTMLDocument('');
        \\globalThis.describedSelect = describedDoc.createElement('select');
        \\describedSelect.appendChild(describedDoc.createElement('option'));
        \\globalThis.describedTokens = describedDoc.createElement('div').classList;
        \\describedTokens.add('tok');
        \\Object.getOwnPropertyDescriptor(describedSelect, 0).value === describedSelect[0] && (0 in describedTokens) ? 1 : 0
    ));
    try expectNothingLeft("Object.getOwnPropertyDescriptor(select, 0)", try leftBy("Object.getOwnPropertyDescriptor(describedSelect, 0);"));
    try expectNothingLeftAnywhere("Object.getOwnPropertyDescriptor(classList, 0)", try leftBy("Object.getOwnPropertyDescriptor(describedTokens, 0);"));
    try expectNothingLeft("0 in select", try leftBy("0 in describedSelect;"));
}

test "an indexed getter frees the string it returns" {
    try allInterfaces();
    // DOMTokenList's indexed getter is item(): a copy of the token, owned by
    // the caller. classList.item(0), an operation, frees it; classList[0]
    // did not.
    try std.testing.expectEqual(@as(i32, 3), try scriptInt(
        \\globalThis.tokenOwner = new Document().implementation.createHTMLDocument('').createElement('div');
        \\tokenOwner.className = 'abc def';
        \\globalThis.tokens = tokenOwner.classList;
        \\tokens[0].length
    ));
    try expectNothingLeftAnywhere("classList[0]", try leftBy("tokens[0];"));
}

test "a named getter frees the string it returns" {
    try allInterfaces();
    // DOMStringMap's named getter answers the data-* attribute's value.
    try std.testing.expectEqual(@as(i32, 6), try scriptInt(
        \\globalThis.namedOwner = new Document().implementation.createHTMLDocument('').createElement('div');
        \\namedOwner.setAttribute('data-named', 'xyzzy!');
        \\globalThis.namedMap = namedOwner.dataset;
        \\namedMap.named.length
    ));
    try expectNothingLeftAnywhere("dataset.named", try leftBy("namedMap.named;"));
    try expectNothingLeftAnywhere("Object.getOwnPropertyDescriptor(dataset, 'named')", try leftBy("Object.getOwnPropertyDescriptor(namedMap, 'named');"));
}

// ---------------------------------------------------------------------------
// document.all's legacy caller.

test "document.all's legacy caller releases what it takes" {
    try allInterfaces();
    // Called as a function, document.all runs the binding's call handler:
    // the current context, the argument and the result were Globals the
    // handler made and kept, three a call.
    // item() is not implemented past its step 1 yet (the collection has no
    // root), so a call with an argument throws item()'s error - and must
    // release what it made on that path too.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.allDoc = new Document().implementation.createHTMLDocument('');
        \\globalThis.allOfDoc = allDoc.all;
        \\(() => { try { allOfDoc('nothing-has-this-name'); return 1 } catch (e) { return 1 } })()
    ));
    try expectNothingLeft("document.all('x')", try leftBy("try { allOfDoc('x') } catch (e) {}"));
    try expectNothingLeft("document.all(0)", try leftBy("try { allOfDoc(0) } catch (e) {}"));
    try expectNothingLeft("document.all()", try leftBy("allOfDoc();"));
}

test "document.all() with no argument is null" {
    try allInterfaces();
    // WebIDL: the legacy caller is the operation `item(optional DOMString
    // nameOrIndex)`; HTML's item() step 1: "If nameOrIndex was not provided,
    // return null."
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\globalThis.noArgDoc = new Document().implementation.createHTMLDocument('');
        \\noArgDoc.all() === null ? 1 : 0
    ));
}

// ---- lane: speed ----
// Attribute and indexed getters take their contexts only where they use them.
//
// A getter's success path - nearly every call - needs no Global<Context>: the
// creation context (WebIDL "throw a TypeError using the function's realm")
// serves only the throwing paths, and the current one only conversions that
// take one. Taken eagerly they were two Global<Context> made and disposed per
// `list.length`, a third of the binding's cost in a profile of
// dom/nodes/NodeList-static-length-getter-tampered-1.html. These pin what may
// not move when they are taken lazily: the realm an error is made in, and no
// handle left behind.

var second_context: ?*ffi.Context = null;

/// A second realm of the agent with every interface, reachable from the
/// file's realm as `otherRealm` (one security token for both).
fn secondRealm() !void {
    try allInterfaces();
    if (second_context != null) return;
    const isolate = isolate_once.?;
    const first = context_once.?;
    const other = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    _ = try v8.context_manager.getOrCreate(other, realm_allocator.allocator());
    ffi.v8_Context_Enter(other);
    v8.interface_bindings.registerAllInterfaces(isolate, other);
    ffi.v8_Context_Exit(other);

    const token_text = "speed-lane-same-origin";
    const token = ffi.v8_String_NewFromUtf8(isolate, token_text.ptr, token_text.len) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(token);
    ffi.v8_Context_SetSecurityToken(first, @ptrCast(token));
    ffi.v8_Context_SetSecurityToken(other, @ptrCast(token));

    const first_global = ffi.v8_Context_Global(first) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(first_global);
    const other_global = ffi.v8_Context_Global(other) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(other_global);
    const key_text = "otherRealm";
    const key = ffi.v8_String_NewFromUtf8(isolate, key_text.ptr, key_text.len) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(first_global, first, @ptrCast(key), @ptrCast(other_global))) return error.SetFailed;
    second_context = other;
}

test "an attribute getter called on an illegal receiver throws the getter's realm's TypeError" {
    try secondRealm();
    // WebIDL 3.7.6 (attribute getter) step 1.2: the receiver is not a platform
    // object implementing the interface - "throw a TypeError". The getter is
    // a built-in function object of otherRealm, so the TypeError is
    // otherRealm's, whichever realm calls it.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\(() => {
        \\  const get = Object.getOwnPropertyDescriptor(otherRealm.Node.prototype, 'nodeType').get;
        \\  try { get.call({}); return 0 } catch (e) { return e instanceof otherRealm.TypeError ? 1 : (e instanceof TypeError ? 2 : 3) }
        \\})()
    ));
    // The same getter, on a node, answers.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\(() => {
        \\  const get = Object.getOwnPropertyDescriptor(otherRealm.Node.prototype, 'nodeType').get;
        \\  return get.call(new Document().implementation.createHTMLDocument('').body);
        \\})()
    ));
}

test "an attribute getter whose impl throws throws in the getter's realm" {
    try secondRealm();
    // WritableStreamDefaultWriter.desiredSize step 1: a released writer has no
    // stream - the impl's TypeError, converted by the binding.
    try std.testing.expectEqual(@as(i32, 1), try scriptInt(
        \\(() => {
        \\  const writer = new otherRealm.WritableStream().getWriter();
        \\  writer.releaseLock();
        \\  try { writer.desiredSize; return 0 } catch (e) { return e instanceof otherRealm.TypeError ? 1 : (e instanceof TypeError ? 2 : 3) }
        \\})()
    ));
}

test "an indexed getter's and a length getter's success paths leave no handle" {
    try allInterfaces();
    try std.testing.expectEqual(@as(i32, 3), try scriptInt(
        \\globalThis.lengthDoc = new Document().implementation.createHTMLDocument('');
        \\for (let i = 0; i < 3; i++) lengthDoc.body.append(lengthDoc.createElement('span'));
        \\globalThis.staticList = lengthDoc.querySelectorAll('span');
        \\globalThis.tokens = lengthDoc.body.classList;
        \\tokens.add('a', 'b');
        \\staticList.length
    ));
    try expectNothingLeftAnywhere("list.length", try leftBy("staticList.length;"));
    try expectNothingLeftAnywhere("list[1]", try leftBy("staticList[1];"));
    try expectNothingLeftAnywhere("classList[0]", try leftBy("tokens[0];"));
    try expectNothingLeftAnywhere("el.id", try leftBy("lengthDoc.body.id;"));
}
// ---- end lane: speed ----

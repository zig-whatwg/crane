//! WebIDL 3.2.15 through the real binding: a value of an interface type
//! converts only from a platform object that implements the interface -
//! "1. If V implements I, then return the IDL interface type value that
//! represents a reference to that platform object. 2. Throw a TypeError."
//!
//! Every interface type is the one Zig type `*runtime.Instance`, and the
//! conversion accepted ANY platform object: the receiver was brand-checked,
//! a union's arms were (by their names), but an operation's argument, a
//! constructor's, an attribute's value, a dictionary member and a sequence's
//! elements took a Blob as a Node, a URLSearchParams as a Blob. The impl then
//! read one interface's state as another's - `fd.append(name, new
//! URLSearchParams(), filename)` made FormData read URLSearchParams' state as
//! a Blob's, and long single-process runs of xhr/formdata/ segfaulted in
//! normalizeMimeType. Codegen now names the interface of each such position
//! (`interface_arguments`, `constructor_interface_arguments`,
//! `interface_members`) and the binding asks the state ancestry, as it asks
//! of a receiver.
//!
//! The values are made the way the binding makes them: by script, through
//! the generated templates. Several members used here are stubs that answer
//! NotImplemented (a NotSupportedError): reaching one is what "the value
//! converted" looks like, and a TypeError is the conversion's.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const ffi = v8.ffi;

var isolate_once: ?*ffi.Isolate = null;
var context_once: ?*ffi.Context = null;
var realm_once: ?runtime.Context = null;

/// One isolate and realm for the file, registered with the context manager
/// as a page's is, every interface installed; V8 is never torn down here.
fn realm() !runtime.Context {
    if (realm_once) |r| return r;
    try engine.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    const i = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(i);
    _ = ffi.v8_HandleScope_New(i);
    const context = ffi.v8_Context_New(i) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    v8.context_manager.init(std.heap.page_allocator) catch {};
    const r = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
    runtime.initializeRuntime(std.heap.page_allocator);
    v8.interface_bindings.registerAllInterfaces(i, context);
    isolate_once = i;
    context_once = context;
    realm_once = r;
    return r;
}

/// What each thunk in `cases` (an array literal of functions) does when
/// called: "ok", "TypeError", or "<name>: <message>" of what else it threw.
const prelude =
    \\(() => {
    \\  const kind = (f) => {
    \\    try { f(); return 'ok'; }
    \\    catch (e) { return e instanceof TypeError ? 'TypeError' : String(e && e.name) + ': ' + String(e && e.message); }
    \\  };
    \\  return (
;
const epilogue =
    \\  ).map(kind).join('|');
    \\})()
;

/// The kinds `cases` (an array literal of thunks) come to, '|'-separated,
/// OWNED by the testing allocator.
fn kinds(comptime cases: []const u8) ![]u8 {
    _ = try realm();
    const isolate = isolate_once.?;
    const context = context_once.?;
    const code = prelude ++ cases ++ epilogue;
    const text = ffi.v8_String_NewFromUtf8(isolate, code.ptr, @intCast(code.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.Threw;
    defer ffi.v8_Value_Dispose(value);
    const string = ffi.v8_Value_ToString(value, context) orelse return error.Threw;
    defer ffi.v8_String_Dispose(string);
    const length = ffi.v8_String_Utf8Length(string);
    if (length < 0) return error.StringFailed;
    const out = try std.testing.allocator.alloc(u8, @intCast(length));
    errdefer std.testing.allocator.free(out);
    if (ffi.v8_String_WriteUtf8(string, out.ptr, @intCast(length)) != length) return error.StringFailed;
    return out;
}

/// `cases` come to `expected` (space-separated kinds); "!TypeError" in
/// `expected` matches any kind but TypeError (the value converted, and the
/// member's own steps ran).
fn expectKinds(comptime cases: []const u8, expected: []const u8) !void {
    const got = try kinds(cases);
    defer std.testing.allocator.free(got);
    var got_it = std.mem.tokenizeScalar(u8, got, '|');
    var want_it = std.mem.tokenizeScalar(u8, expected, ' ');
    while (want_it.next()) |want| {
        const kind = got_it.next() orelse break;
        const matches = if (std.mem.eql(u8, want, "!TypeError")) !std.mem.eql(u8, kind, "TypeError") else std.mem.eql(u8, kind, want);
        if (!matches) {
            std.debug.print("expected \"{s}\", got \"{s}\"\n", .{ expected, got });
            return error.TestExpectedEqual;
        }
    } else if (got_it.next() == null) return;
    std.debug.print("expected \"{s}\", got \"{s}\"\n", .{ expected, got });
    return error.TestExpectedEqual;
}

test "an operation's argument of another interface is a TypeError" {
    // Path2D.addPath(Path2D path, ...): a Blob, a plain object and null are
    // no Path2D; a Path2D reaches the operation.
    try expectKinds(
        \\[
        \\  () => new Path2D().addPath(new Blob()),
        \\  () => new Path2D().addPath({}),
        \\  () => new Path2D().addPath(null),
        \\  () => new Path2D().addPath(new Path2D()),
        \\]
    , "TypeError TypeError TypeError !TypeError");
}

test "a constructor's argument takes the interface and what inherits from it" {
    // CSSMatrixComponent(DOMMatrixReadOnly matrix, ...): DOMMatrix inherits
    // DOMMatrixReadOnly, so it implements it.
    try expectKinds(
        \\[
        \\  () => new CSSMatrixComponent(new Blob()),
        \\  () => new CSSMatrixComponent(new DOMMatrixReadOnly()),
        \\  () => new CSSMatrixComponent(new DOMMatrix()),
        \\]
    , "TypeError ok ok");
}

test "an overloaded constructor chosen by its argument count checks the argument's interface" {
    // CSSRotate(CSSNumericValue angle) is the only one-argument constructor,
    // so overload resolution picks it without looking at the value's type
    // (WebIDL 3.6 step 12 runs only for two or more candidates): the
    // conversion is the check. CSSUnitValue inherits CSSNumericValue.
    try expectKinds(
        \\[
        \\  () => new CSSRotate(new Blob()),
        \\  () => new CSSRotate(new CSSUnitValue(1, 'deg')),
        \\]
    , "TypeError ok");
}

test "an attribute's value of another interface is a TypeError; null is a nullable's value" {
    // SpeechSynthesisUtterance.voice: SpeechSynthesisVoice?.
    try expectKinds(
        \\[
        \\  () => { new SpeechSynthesisUtterance().voice = new Blob(); },
        \\  () => { new SpeechSynthesisUtterance().voice = {}; },
        \\  () => { new SpeechSynthesisUtterance().voice = null; },
        \\]
    , "TypeError TypeError !TypeError");
}

test "a dictionary member of another interface is a TypeError" {
    // MouseEventInit.relatedTarget: EventTarget?. An AbortSignal is an
    // EventTarget; a Blob is not.
    try expectKinds(
        \\[
        \\  () => new MouseEvent('x', { relatedTarget: new Blob() }),
        \\  () => { if (new MouseEvent('x', { relatedTarget: null }).relatedTarget !== null) throw new Error('not null'); },
        \\  () => {
        \\    const target = new EventTarget();
        \\    if (new MouseEvent('x', { relatedTarget: target }).relatedTarget !== target) throw new Error('not the target');
        \\  },
        \\  () => new MouseEvent('x', { relatedTarget: new AbortController().signal }),
        \\]
    , "TypeError ok ok ok");
}

test "a sequence's element of another interface is a TypeError" {
    // MessageEventInit.ports: sequence<MessagePort>.
    try expectKinds(
        \\[
        \\  () => new MessageEvent('m', { ports: [new Blob()] }),
        \\  () => new MessageEvent('m', { ports: [null] }),
        \\  () => new MessageEvent('m', { ports: [] }),
        \\]
    , "TypeError TypeError ok");
}

test "the overload FormData.append(name, blobValue, filename) takes only a Blob" {
    // The three-argument append is the only overload of three arguments, so
    // the conversion is the check (xhr/formdata/append-formelement.html,
    // testFormDataAppendToFormWrongPlatformObject). A File is a Blob.
    //
    // The first case shows what got through before: FormData made a File
    // from the URLSearchParams, reading its state as a Blob's - the File's
    // size and type are whatever URLSearchParams' bytes say (the read
    // segfaulted in normalizeMimeType in long single-process runs).
    try expectKinds(
        \\[
        \\  () => {
        \\    const fd = new FormData();
        \\    fd.append('name', new URLSearchParams('a=b&c=d'), 'filename');
        \\    const made = fd.get('name');
        \\    throw new Error('a File was made from a URLSearchParams: size ' + made.size + ', type ' + JSON.stringify(made.type));
        \\  },
        \\  () => new FormData().set('name', new URLSearchParams(), 'filename'),
        \\  () => new FormData().append('name', 'string', 'filename'),
        \\  () => {
        \\    const fd = new FormData();
        \\    fd.append('name', new File(['x'], 'a.txt'), 'b.txt');
        \\    if (fd.get('name').name !== 'b.txt') throw new Error('wrong name');
        \\  },
        \\  () => new FormData().append('name', new Blob(['x']), 'c.txt'),
        \\]
    , "TypeError TypeError TypeError ok ok");
}

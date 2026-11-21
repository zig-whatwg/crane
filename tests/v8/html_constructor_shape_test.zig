//! The [HTMLConstructor] interface objects' shape (HTML 3.2.3; WebIDL 3.7.1
//! "create an interface object", 3.7.3 "create an interface prototype
//! object"), PINNED on main 5a621f2cb - what any change to how they are made
//! must keep (lane blk7 made them derived classes, whose [[Construct]] makes
//! no receiver, and held them to these pins; the user then ruled the V8
//! adapter keeps Chrome's FunctionTemplates, 2026-11-21). For every one of the
//! 77 [HTMLConstructor] interfaces a Window exposes, in a page's realm and a
//! frame's - restored from the build's snapshot and made without it - and in
//! a realm whose element wrappers are made before script reads any interface
//! object:
//!
//! - typeof, name and length; Function.prototype.toString's NativeFunction
//!   text, with the interface's name;
//! - the `prototype` property (not writable, enumerable or configurable),
//!   `prototype.constructor` (the interface object; writable, configurable,
//!   not enumerable) and Symbol.toStringTag;
//! - both [[Prototype]] chains: the interface object's is its parent's, the
//!   prototype's is its parent's prototype;
//! - the interface object's own properties, and the prototype's own
//!   properties in order with their kinds and attributes (a fingerprint per
//!   interface, `prototype_shapes`);
//! - an element of each tag: its [[Prototype]] is its interface's prototype,
//!   and it is an instance of its interface and of HTMLElement - the
//!   non-[HTMLConstructor] children of HTMLElement (HTMLUnknownElement,
//!   HTMLMediaElement's constants through HTMLVideoElement) included;
//! - the [LegacyFactoryFunction]s' prototypes (Image, Audio, Option);
//! - calling one without new is a TypeError.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const v8 = @import("v8");
const ffi = v8.ffi;
const helpers = @import("webidl").helpers;
/// The snapshot this build generated (build.zig passes its path).
const snapshot_path = @import("test_snapshot").path;

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

const no_hooks: protocol.HostHooks = .{};

fn evaluate(r: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    errdefer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    return got;
}

fn expectEval(r: runtime.Context, source: []const u8, want: []const u8) !void {
    const got = try evaluate(r, source);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, want)) std.debug.print("{s}\n  -> {s}\n", .{ source[source.len -| 200..], got });
    try testing.expectEqualStrings(want, got);
}

/// Every [HTMLConstructor] interface a Window exposes, as the JS array
/// literal `[[name, parent name], ...]`.
const html_constructors = blk: {
    @setEvalBranchQuota(50_000_000);
    var out: []const u8 = "[";
    var n: usize = 0;
    for (@typeInfo(interfaces).@"struct".decl_names) |name| {
        const T = @field(interfaces, name);
        if (@TypeOf(T) != type or @typeInfo(T) != .@"struct" or !@hasDecl(T, "Meta")) continue;
        if (!@hasDecl(T, "html_constructor") or !T.html_constructor) continue;
        if (v8.interface_bindings.shouldSkipInterface(name)) continue;
        if (!helpers.isExposedIn(T, .Window)) continue;
        out = out ++ "['" ++ name ++ "','" ++ T.Meta.ParentInterface.Meta.name ++ "'],";
        n += 1;
    }
    break :blk .{ .table = out ++ "]", .count = n };
};

test "the [HTMLConstructor] table is the 77 interfaces HTML and its applicable specifications give the attribute" {
    try testing.expectEqual(@as(usize, 77), html_constructors.count);
}

/// The fingerprint of each [HTMLConstructor] interface prototype object's
/// own properties, in order - every key with its kind and attributes - in
/// a secure Window realm, as main 5a621f2cb made them: `name:fnv1a32/count`.
/// Recorded from this test's own output on that tree (an empty entry prints
/// what it reads).
const prototype_shapes = "{" ++
    "'HTMLAnchorElement':'a0797347/29'," ++
    "'HTMLAreaElement':'3727badd/26'," ++
    "'HTMLAudioElement':'79735475/2'," ++
    "'HTMLBRElement':'2ccffcf1/3'," ++
    "'HTMLBaseElement':'096988c1/4'," ++
    "'HTMLBodyElement':'2e86dadf/30'," ++
    "'HTMLButtonElement':'1946241d/23'," ++
    "'HTMLCameraElement':'c5c0dbfa/8'," ++
    "'HTMLCanvasElement':'20368582/9'," ++
    "'HTMLDListElement':'1f1b9d0d/3'," ++
    "'HTMLDataElement':'187007e9/3'," ++
    "'HTMLDataListElement':'924d8fd1/3'," ++
    "'HTMLDetailsElement':'7a6fa4ec/4'," ++
    "'HTMLDialogElement':'85c45e20/9'," ++
    "'HTMLDirectoryElement':'1f1b9d0d/3'," ++
    "'HTMLDivElement':'8c4c7915/3'," ++
    "'HTMLElement':'d020e339/152'," ++
    "'HTMLEmbedElement':'770c2ddc/9'," ++
    "'HTMLFencedFrameElement':'88e1bb07/7'," ++
    "'HTMLFieldSetElement':'8e103add/13'," ++
    "'HTMLFontElement':'96aad77f/5'," ++
    "'HTMLFormElement':'1851c40a/21'," ++
    "'HTMLFrameElement':'c04f88c4/12'," ++
    "'HTMLFrameSetElement':'b5c477f9/25'," ++
    "'HTMLGeolocationElement':'d5f58ced/14'," ++
    "'HTMLHRElement':'6802175b/7'," ++
    "'HTMLHeadElement':'79735475/2'," ++
    "'HTMLHeadingElement':'8c4c7915/3'," ++
    "'HTMLHtmlElement':'a4a8752e/3'," ++
    "'HTMLIFrameElement':'1c33c66b/26'," ++
    "'HTMLImageElement':'0bc3edcf/30'," ++
    "'HTMLInputElement':'0ce32926/63'," ++
    "'HTMLInstallElement':'46cf9b9c/8'," ++
    "'HTMLLIElement':'9d39cf04/4'," ++
    "'HTMLLabelElement':'acfbbe3d/5'," ++
    "'HTMLLegendElement':'0ae285cb/4'," ++
    "'HTMLLinkElement':'c712f6c4/22'," ++
    "'HTMLMapElement':'eea01ff9/4'," ++
    "'HTMLMarqueeElement':'23b0a376/15'," ++
    "'HTMLMenuElement':'1f1b9d0d/3'," ++
    "'HTMLMetaElement':'41c6aefb/7'," ++
    "'HTMLMeterElement':'b72c1f80/9'," ++
    "'HTMLMicrophoneElement':'c5c0dbfa/8'," ++
    "'HTMLModElement':'1a213433/4'," ++
    "'HTMLOListElement':'5376bf30/6'," ++
    "'HTMLObjectElement':'2fe75145/28'," ++
    "'HTMLOptGroupElement':'313e5571/4'," ++
    "'HTMLOptionElement':'18741ae6/10'," ++
    "'HTMLOutputElement':'f8f737c2/15'," ++
    "'HTMLParagraphElement':'8c4c7915/3'," ++
    "'HTMLParamElement':'661bde24/6'," ++
    "'HTMLPictureElement':'79735475/2'," ++
    "'HTMLPortalElement':'413578b8/8'," ++
    "'HTMLPreElement':'4a794be6/3'," ++
    "'HTMLProgressElement':'13ca2f02/6'," ++
    "'HTMLQuoteElement':'be0a6495/3'," ++
    "'HTMLScriptElement':'6dfa1a9b/18'," ++
    "'HTMLSelectElement':'705f67ac/28'," ++
    "'HTMLSelectedContentElement':'79735475/2'," ++
    "'HTMLSlotElement':'b9ba0c41/6'," ++
    "'HTMLSourceElement':'e9df9cd1/9'," ++
    "'HTMLSpanElement':'79735475/2'," ++
    "'HTMLStyleElement':'76d9f685/7'," ++
    "'HTMLTableCaptionElement':'8c4c7915/3'," ++
    "'HTMLTableCellElement':'df0f7302/17'," ++
    "'HTMLTableColElement':'92c996fe/8'," ++
    "'HTMLTableElement':'e32c4483/25'," ++
    "'HTMLTableRowElement':'b8dcec7d/12'," ++
    "'HTMLTableSectionElement':'c6b86619/9'," ++
    "'HTMLTemplateElement':'2a59e838/10'," ++
    "'HTMLTextAreaElement':'8b834354/32'," ++
    "'HTMLTimeElement':'b5517f53/3'," ++
    "'HTMLTitleElement':'c0629175/3'," ++
    "'HTMLTrackElement':'484ba327/13'," ++
    "'HTMLUListElement':'328916e8/4'," ++
    "'HTMLUserMediaElement':'3bee1e00/8'," ++
    "'HTMLVideoElement':'b3ed224b/15'," ++
    "}";

/// The interface objects' own properties (keys, kinds and attributes) on
/// main 5a621f2cb: length, name and prototype for every one with no static
/// member of its own - no `arguments` or `caller` (WebIDL 3.7.1; V8 gives a
/// FunctionTemplate's function none since it is made read-only-prototype) -
/// and HTMLScriptElement's static supports() and HTMLTrackElement's
/// constants after them.
const interface_object_shapes = "{" ++
    "'*':'length:v001,name:v001,prototype:v000'," ++
    "'HTMLScriptElement':'length:v001,name:v001,prototype:v000,supports:v111'," ++
    "'HTMLTrackElement':'length:v001,name:v001,prototype:v000,NONE:v010,LOADING:v010,LOADED:v010,ERROR:v010'," ++
    "}";

/// The JS that checks it all in a realm: "ok", or the first failures (and,
/// for an unrecorded fingerprint, what it read).
fn shapeCheck(comptime secure: bool) []const u8 {
    return "const table = " ++ html_constructors.table ++ ";\nconst SHAPES = " ++ prototype_shapes ++
        ";\nconst OBJECT_SHAPES = " ++ interface_object_shapes ++ ";\nconst SECURE = " ++ (if (secure) "true" else "false") ++ ";\n" ++
        \\(() => {
        \\  const bad = [], record = [];
        \\  const fnv = s => { let h = 0x811c9dc5; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; } return h.toString(16).padStart(8, '0'); };
        \\  const shape = o => Reflect.ownKeys(o).map(k => { const d = Object.getOwnPropertyDescriptor(o, k);
        \\    return String(k) + ':' + ('value' in d ? 'v' + (+d.writable) : 'a' + (d.get ? 1 : 0) + (d.set ? 1 : 0)) + (+d.enumerable) + (+d.configurable); }).join(',');
        \\  for (const [n, p] of table) {
        \\    const X = globalThis[n], P = globalThis[p];
        \\    if (typeof X !== 'function') { bad.push('no interface object ' + n); continue; }
        \\    if (X.name !== n) bad.push('name ' + n);
        \\    if (X.length !== 0) bad.push('length ' + n);
        \\    const text = Function.prototype.toString.call(X);
        \\    if (text !== 'function ' + n + '() { [native code] }') bad.push('toString ' + n + ': ' + text);
        \\    const pd = Object.getOwnPropertyDescriptor(X, 'prototype');
        \\    if (!pd || pd.writable || pd.enumerable || pd.configurable) bad.push('prototype descriptor ' + n);
        \\    const proto = X.prototype;
        \\    const cd = Object.getOwnPropertyDescriptor(proto, 'constructor');
        \\    if (!cd || cd.value !== X || !cd.writable || cd.enumerable || !cd.configurable) bad.push('constructor ' + n);
        \\    if (proto[Symbol.toStringTag] !== n || Object.prototype.toString.call(proto) !== '[object ' + n + ']') bad.push('toStringTag ' + n);
        \\    if (Object.getPrototypeOf(X) !== P) bad.push('interface object [[Prototype]] ' + n);
        \\    if (Object.getPrototypeOf(proto) !== P.prototype) bad.push('prototype [[Prototype]] ' + n);
        \\    if (!(Object.create(proto) instanceof X) || !(Object.create(proto) instanceof HTMLElement)) bad.push('instanceof ' + n);
        \\    let threw = null;
        \\    try { X(); } catch (e) { threw = e; }
        \\    if (!(threw instanceof TypeError)) bad.push('called without new ' + n);
        \\    const os = shape(X), pinned = OBJECT_SHAPES[n in OBJECT_SHAPES ? n : '*'];
        \\    if (os !== pinned) bad.push('interface object shape ' + n + ': ' + os);
        \\    if (SECURE) {
        \\      const got = fnv(shape(proto)) + '/' + Reflect.ownKeys(proto).length;
        \\      if (!(n in SHAPES)) record.push(n + ':' + got);
        \\      else if (SHAPES[n] !== got) bad.push('prototype shape ' + n + ' ' + got + ' (pinned ' + SHAPES[n] + ')');
        \\    }
        \\  }
        \\  if (SECURE !== ('onpointerrawupdate' in HTMLElement.prototype)) bad.push('[SecureContext] member onpointerrawupdate');
        \\  // [LegacyFactoryFunction]s: their prototype is the interface's (WebIDL 3.7.2).
        \\  if (Image.prototype !== HTMLImageElement.prototype || Audio.prototype !== HTMLAudioElement.prototype || Option.prototype !== HTMLOptionElement.prototype) bad.push('factory prototypes');
        \\  // Constants: an interface object's own (HTMLTrackElement) and an
        \\  // inherited one's (HTMLMediaElement's, through HTMLVideoElement).
        \\  if (HTMLTrackElement.LOADED !== 2 || HTMLTrackElement.prototype.LOADED !== 2) bad.push('HTMLTrackElement constants');
        \\  if (HTMLVideoElement.NETWORK_LOADING !== 2 || Object.getPrototypeOf(HTMLVideoElement) !== HTMLMediaElement) bad.push('HTMLMediaElement constants');
        \\  return (bad.slice(0, 12).join('; ') || 'ok') + (record.length ? ' RECORD ' + record.join(' ') : '');
        \\})()
    ;
}

/// An element of each tag, made by a new document: its [[Prototype]] is its
/// interface's prototype. Run before any other script of a fresh realm, its
/// wrappers are made before script reads any interface object.
const element_check =
    \\(() => {
    \\  const bad = [];
    \\  const doc = new Document().implementation.createHTMLDocument('t');
    \\  const tags = [['a','HTMLAnchorElement'],['area','HTMLAreaElement'],['audio','HTMLAudioElement'],['base','HTMLBaseElement'],
    \\    ['br','HTMLBRElement'],['body','HTMLBodyElement'],['button','HTMLButtonElement'],['canvas','HTMLCanvasElement'],
    \\    ['data','HTMLDataElement'],['datalist','HTMLDataListElement'],['details','HTMLDetailsElement'],['dialog','HTMLDialogElement'],
    \\    ['div','HTMLDivElement'],['dl','HTMLDListElement'],['dir','HTMLDirectoryElement'],['embed','HTMLEmbedElement'],
    \\    ['fieldset','HTMLFieldSetElement'],['font','HTMLFontElement'],['form','HTMLFormElement'],['frame','HTMLFrameElement'],
    \\    ['frameset','HTMLFrameSetElement'],['h1','HTMLHeadingElement'],['head','HTMLHeadElement'],['hr','HTMLHRElement'],
    \\    ['html','HTMLHtmlElement'],['iframe','HTMLIFrameElement'],['img','HTMLImageElement'],['input','HTMLInputElement'],
    \\    ['label','HTMLLabelElement'],['legend','HTMLLegendElement'],['li','HTMLLIElement'],['link','HTMLLinkElement'],
    \\    ['map','HTMLMapElement'],['marquee','HTMLMarqueeElement'],['menu','HTMLMenuElement'],['meta','HTMLMetaElement'],
    \\    ['meter','HTMLMeterElement'],['del','HTMLModElement'],['ins','HTMLModElement'],['object','HTMLObjectElement'],
    \\    ['ol','HTMLOListElement'],['optgroup','HTMLOptGroupElement'],['option','HTMLOptionElement'],['output','HTMLOutputElement'],
    \\    ['p','HTMLParagraphElement'],['param','HTMLParamElement'],['picture','HTMLPictureElement'],['pre','HTMLPreElement'],
    \\    ['progress','HTMLProgressElement'],['q','HTMLQuoteElement'],['blockquote','HTMLQuoteElement'],['script','HTMLScriptElement'],
    \\    ['select','HTMLSelectElement'],['slot','HTMLSlotElement'],['source','HTMLSourceElement'],['span','HTMLSpanElement'],
    \\    ['style','HTMLStyleElement'],['caption','HTMLTableCaptionElement'],['td','HTMLTableCellElement'],['th','HTMLTableCellElement'],
    \\    ['col','HTMLTableColElement'],['colgroup','HTMLTableColElement'],['table','HTMLTableElement'],['tr','HTMLTableRowElement'],
    \\    ['tbody','HTMLTableSectionElement'],['thead','HTMLTableSectionElement'],['template','HTMLTemplateElement'],
    \\    ['textarea','HTMLTextAreaElement'],['time','HTMLTimeElement'],['title','HTMLTitleElement'],['track','HTMLTrackElement'],
    \\    ['ul','HTMLUListElement'],['video','HTMLVideoElement'],['section','HTMLElement'],['custom-tag','HTMLElement'],
    \\    ['blk7unknown','HTMLUnknownElement']];
    \\  // Every element made first: its wrapper before its interface object is read.
    \\  const made = tags.map(([tag]) => doc.createElement(tag));
    \\  tags.forEach(([tag, n], i) => {
    \\    const el = made[i], X = globalThis[n];
    \\    if (Object.getPrototypeOf(el) !== X.prototype) bad.push('[[Prototype]] of <' + tag + '>');
    \\    if (!(el instanceof X) || !(el instanceof HTMLElement) || !(el instanceof Element)) bad.push('instanceof <' + tag + '>');
    \\    if (el.constructor !== X) bad.push('constructor of <' + tag + '>');
    \\  });
    \\  if (Object.getPrototypeOf(HTMLUnknownElement.prototype) !== HTMLElement.prototype || Object.getPrototypeOf(HTMLUnknownElement) !== HTMLElement) bad.push('HTMLUnknownElement chains');
    \\  if (Object.getPrototypeOf(HTMLMediaElement.prototype) !== HTMLElement.prototype || Object.getPrototypeOf(HTMLMediaElement) !== HTMLElement) bad.push('HTMLMediaElement chains');
    \\  return bad.slice(0, 12).join('; ') || 'ok';
    \\})()
;

fn windowRealm(agent: *protocol.Agent, from_snapshot: bool, origin: []const u8) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent_cluster_cross_origin_isolated = true,
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = from_snapshot,
        .timer = null,
        .origin = origin,
        .secure_context = std.mem.startsWith(u8, origin, "https:"),
        .create_global_object = WindowHost.createGlobalObject,
    });
}

/// A frame's Window realm, made inside its parent's script as HTML makes a
/// navigable's.
const Frame = struct {
    agent: *protocol.Agent,
    parent: runtime.Context,
    from_snapshot: bool,
    origin: []const u8 = "https://blk7.test",
    made: ?runtime.Context = null,
    failed: ?anyerror = null,

    fn make(self: *Frame) !runtime.Context {
        try protocol.runInRealm(self.parent, steps, self);
        if (self.failed) |err| return err;
        return self.made.?;
    }

    fn steps(data: ?*anyopaque) void {
        const self: *Frame = @ptrCast(@alignCast(data.?));
        self.made = protocol.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = self.from_snapshot,
            .timer = null,
            .origin = self.origin,
            .secure_context = std.mem.startsWith(u8, self.origin, "https:"),
            .parent = self.parent,
            .create_global_object = WindowHost.createGlobalObject,
        }) catch |err| {
            self.failed = err;
            return;
        };
    }
};

/// The checks in a page's realm of `agent`, in a frame of it, in a realm
/// whose wrappers come first, and in a frame that is not a secure context.
fn checkRealms(agent: *protocol.Agent, from_snapshot: bool) !void {
    // Wrappers first: no interface object read before the elements are made.
    {
        const first = try windowRealm(agent, from_snapshot, "https://blk7.test");
        defer protocol.destroyWindowRealm(first, .global_detached);
        try expectEval(first, element_check, "ok");
        try expectEval(first, shapeCheck(true), "ok");
    }
    const page = try windowRealm(agent, from_snapshot, "https://blk7.test");
    defer protocol.destroyWindowRealm(page, .global_detached);
    try expectEval(page, shapeCheck(true), "ok");
    try expectEval(page, element_check, "ok");

    var frame_maker: Frame = .{ .agent = agent, .parent = page, .from_snapshot = from_snapshot };
    const frame = try frame_maker.make();
    defer protocol.destroyWindowRealm(frame, .global_detached);
    try expectEval(frame, element_check, "ok");
    try expectEval(frame, shapeCheck(true), "ok");

    var insecure_maker: Frame = .{ .agent = agent, .parent = page, .from_snapshot = from_snapshot, .origin = "http://blk7.test" };
    const insecure = try insecure_maker.make();
    defer protocol.destroyWindowRealm(insecure, .global_detached);
    try expectEval(insecure, shapeCheck(false), "ok");
    try expectEval(insecure, element_check, "ok");
}

/// A window agent restored from the build's snapshot, in a process whose V8
/// started with it - or null (skipped, saying so) when V8 started before.
const SnapshotAgent = struct {
    bytes: []u8,
    agent: *protocol.Agent,

    fn open() !?SnapshotAgent {
        if (ffi.v8_Platform_IsInitialized()) {
            std.log.warn("skipping: V8 was started in this process before this test; run it in a process of its own (tests-v8 runs at batch 1; -Dlaunch-batch=1 or -Dtest-file=)", .{});
            return null;
        }
        const io = std.testing.io;
        const file = try std.Io.Dir.cwd().openFile(io, snapshot_path, .{});
        defer file.close(io);
        const size = (try file.stat(io)).size;
        const bytes = try std.heap.c_allocator.alloc(u8, size);
        errdefer std.heap.c_allocator.free(bytes);
        _ = try file.readPositionalAll(io, bytes, 0);
        try test_process.startSnapshot(bytes);
        errdefer test_process.endSnapshot();
        dom.style.ua_sheet.build();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = true, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        if (!ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent)))) return error.AgentNotRestoredFromSnapshot;
        return .{ .bytes = bytes, .agent = agent };
    }

    fn close(self: SnapshotAgent) void {
        protocol.destroyAgent(self.agent);
        test_process.endSnapshot();
        std.heap.c_allocator.free(self.bytes);
    }
};

test "the [HTMLConstructor] interface objects of Window realms restored from the snapshot keep their pinned shape" {
    const restored = (try SnapshotAgent.open()) orelse return error.SkipZigTest;
    defer restored.close();
    try checkRealms(restored.agent, true);
}

test "the [HTMLConstructor] interface objects of Window realms made without the snapshot keep their pinned shape" {
    test_process.start();
    dom.style.ua_sheet.build();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    try checkRealms(agent, false);
}

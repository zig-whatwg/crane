//! B7: WebIDL 2.5.11/2.5.12 & 3.7.11/3.7.12 setlike & maplike bindings across
//! every setlike (10) and maplike (12) interface in specs/idl, including
//! non-interface value types, non-string keys, sequence values, live iteration
//! across mutations, and zero V8 global handle leaks.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const v8 = @import("v8");
const ffi = v8.ffi;
const a = std.testing.allocator;

fn onThread(comptime body: fn () anyerror!void) !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void) void {
            out.* = body();
        }
    }.run, .{&result});
    thread.join();
    try result;
}

const Host = struct {
    fn window(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(a, realm) catch null;
    }
    fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        std.debug.print("b7 setlike/maplike script error: {s}\n", .{info.message});
    }
};

const no_hooks: engine.HostHooks = .{};

const TestRealm = struct {
    own_runtime: test_process.OwnRuntime = undefined,
    scope: runtime.BrowserScope = undefined,
    agent: *engine.Agent = undefined,
    realm: runtime.Context = undefined,

    fn open(self: *TestRealm) !void {
        test_process.start();
        interfaces.process_hooks.startHooksForTest();
        self.own_runtime = test_process.OwnRuntime.begin(a);
        errdefer self.own_runtime.end();
        self.scope = runtime.BrowserScope.init(a);
        errdefer self.scope.deinit();
        self.agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &no_hooks,
            .allocator = a,
        });
        errdefer engine.destroyAgent(self.agent);
        self.realm = try engine.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = self.agent,
            .allocator = a,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://b7.test",
            .browser_scope = &self.scope,
            .create_global_object = Host.window,
        });
    }

    fn close(self: *TestRealm) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
        self.scope.deinit();
        self.own_runtime.end();
    }

    fn evalOk(self: *const TestRealm, source: []const u8) !void {
        const result = try engine.evaluateClassicScriptToString(
            self.realm,
            .{ .utf8 = source },
            "bind1_setlike_maplike_test.js",
            null,
            a,
            .{ .report = Host.report, .host = null },
        );
        defer a.free(result);
        try testing.expectEqualStrings("ok", result);
    }

    fn exposeInstance(self: *const TestRealm, name: []const u8, instance: *runtime.Instance) !void {
        const ctx: *ffi.Context = @ptrCast(@alignCast(self.realm.getEngineContext() orelse return error.InvalidStateError));
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(self.agent));
        const global = ffi.v8_Context_Global(ctx) orelse return error.InvalidStateError;
        defer ffi.v8_Object_Dispose(global);
        const wrapper = try v8.conversions.instanceToV8Checked(isolate, instance);
        const key = ffi.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return error.OutOfMemory;
        defer ffi.v8_String_Dispose(key);
        _ = ffi.v8_Object_Set(global, ctx, @ptrCast(key), wrapper);
    }
};

fn testAllIdlharnessDescriptors() !void {
    var tr: TestRealm = .{};
    try tr.open();
    defer tr.close();

    try tr.evalOk(
        \\(() => {
        \\  function checkSetlike(name, readonly) {
        \\    const iface = globalThis[name];
        \\    if (!iface) return name + ':missing';
        \\    const proto = iface.prototype;
        \\    const methods = [['entries', 0], ['keys', 0], ['values', 0], ['forEach', 1], ['has', 1]];
        \\    if (!readonly) methods.push(['add', 1], ['delete', 1], ['clear', 0]);
        \\    for (const [m, len] of methods) {
        \\      const d = Object.getOwnPropertyDescriptor(proto, m);
        \\      if (!d || typeof d.value !== 'function') return name + '.' + m + ':not-fn';
        \\      if (!d.enumerable || !d.configurable || !d.writable) return name + '.' + m + ':attrs';
        \\      if (d.value.length !== len) return name + '.' + m + ':len=' + d.value.length;
        \\      if (d.value.name !== m) return name + '.' + m + ':name=' + d.value.name;
        \\    }
        \\    if (readonly) {
        \\      for (const m of ['add', 'delete', 'clear']) {
        \\        if (Object.getOwnPropertyDescriptor(proto, m) !== undefined) return name + ':readonly-has-' + m;
        \\      }
        \\    }
        \\    const it = Object.getOwnPropertyDescriptor(proto, Symbol.iterator);
        \\    if (!it || it.value !== proto.values || it.enumerable !== false || !it.configurable || !it.writable) return name + ':iterator';
        \\    const sz = Object.getOwnPropertyDescriptor(proto, 'size');
        \\    if (!sz || typeof sz.get !== 'function' || sz.set !== undefined || !sz.enumerable || !sz.configurable || sz.get.length !== 0 || sz.get.name !== 'get size') return name + ':size';
        \\    return null;
        \\  }
        \\
        \\  function checkMaplike(name, readonly) {
        \\    const iface = globalThis[name];
        \\    if (!iface) return name + ':missing';
        \\    const proto = iface.prototype;
        \\    const methods = [['entries', 0], ['keys', 0], ['values', 0], ['forEach', 1], ['get', 1], ['has', 1]];
        \\    if (!readonly) methods.push(['set', 2], ['delete', 1], ['clear', 0]);
        \\    for (const [m, len] of methods) {
        \\      const d = Object.getOwnPropertyDescriptor(proto, m);
        \\      if (!d || typeof d.value !== 'function') return name + '.' + m + ':not-fn';
        \\      if (!d.enumerable || !d.configurable || !d.writable) return name + '.' + m + ':attrs';
        \\      if (d.value.length !== len) return name + '.' + m + ':len=' + d.value.length;
        \\      if (d.value.name !== m) return name + '.' + m + ':name=' + d.value.name;
        \\    }
        \\    if (readonly) {
        \\      for (const m of ['set', 'delete', 'clear']) {
        \\        if (Object.getOwnPropertyDescriptor(proto, m) !== undefined) return name + ':readonly-has-' + m;
        \\      }
        \\    }
        \\    const it = Object.getOwnPropertyDescriptor(proto, Symbol.iterator);
        \\    if (!it || it.value !== proto.entries || it.enumerable !== false || !it.configurable || !it.writable) return name + ':iterator';
        \\    const sz = Object.getOwnPropertyDescriptor(proto, 'size');
        \\    if (!sz || typeof sz.get !== 'function' || sz.set !== undefined || !sz.enumerable || !sz.configurable || sz.get.length !== 0 || sz.get.name !== 'get size') return name + ':size';
        \\    return null;
        \\  }
        \\
        \\  const setlikes = [
        \\    ['CustomStateSet', false],
        \\    ['FontFaceSet', false],
        \\    ['FontFaceVariations', true],
        \\    ['GPUSupportedFeatures', true],
        \\    ['Highlight', false],
        \\    ['ViewTransitionTypeSet', false],
        \\    ['WGSLLanguageFeatures', true],
        \\    ['XRAnchorSet', true],
        \\    ['XRMeshSet', true],
        \\    ['XRPlaneSet', true],
        \\  ];
        \\  for (const [name, ro] of setlikes) {
        \\    const err = checkSetlike(name, ro);
        \\    if (err) return err;
        \\  }
        \\
        \\  const maplikes = [
        \\    ['AttributionAggregationServices', true],
        \\    ['AudioParamMap', true],
        \\    ['BluetoothManufacturerDataFilter', true],
        \\    ['BluetoothManufacturerDataMap', true],
        \\    ['BluetoothServiceDataFilter', true],
        \\    ['BluetoothServiceDataMap', true],
        \\    ['CSSFontFeatureValuesMap', false],
        \\    ['EventCounts', true],
        \\    ['HighlightRegistry', false],
        \\    ['KeyboardLayoutMap', true],
        \\    ['MIDIInputMap', true],
        \\    ['MIDIOutputMap', true],
        \\    ['NamedFlowMap', false],
        \\    ['RTCStatsReport', true],
        \\  ];
        \\  for (const [name, ro] of maplikes) {
        \\    const err = checkMaplike(name, ro);
        \\    if (err) return err;
        \\  }
        \\  return 'ok';
        \\})()
    );
}

test "all 10 setlike and 14 maplike interfaces expose WebIDL 3.7.11/3.7.12 prototype descriptors" {
    try onThread(testAllIdlharnessDescriptors);
}

fn testCssFontFeatureValuesMapLive() !void {
    var tr: TestRealm = .{};
    try tr.open();
    defer tr.close();

    try tr.evalOk(
        \\(() => {
        \\  const d = new Document().implementation.createHTMLDocument('b7');
        \\  const style = d.createElement('style');
        \\  style.textContent = '@font-feature-values Example { @styleset { z: 1; a: 2; m: 3; z: 4; } }';
        \\  d.head.appendChild(style);
        \\  const rule = style.sheet.cssRules[0];
        \\  const map = rule.styleset;
        \\
        \\  // Basic queries & order
        \\  if (map.size !== 3) return 'size=' + map.size;
        \\  if (!map.has('z') || map.has('missing')) return 'has';
        \\  const z1 = map.get('z');
        \\  if (!Array.isArray(z1) || z1.length !== 1 || z1[0] !== 4) return 'get z=' + JSON.stringify(z1);
        \\  if (map.get('missing') !== undefined) return 'get missing';
        \\  // WebIDL 3.2.21: sequence return creates a fresh JS Array each call
        \\  z1.push(999);
        \\  const z2 = map.get('z');
        \\  if (z2 === z1 || z2.length !== 1 || z2[0] !== 4) return 'fresh array violated';
        \\
        \\  // keys / values / entries / @@iterator / forEach
        \\  if (JSON.stringify([...map.keys()]) !== '["z","a","m"]') return 'keys=' + JSON.stringify([...map.keys()]);
        \\  if (JSON.stringify([...map.values()]) !== '[[4],[2],[3]]') return 'values=' + JSON.stringify([...map.values()]);
        \\  if (JSON.stringify([...map.entries()]) !== '[["z",[4]],["a",[2]],["m",[3]]]') return 'entries';
        \\  if (JSON.stringify([...map]) !== '[["z",[4]],["a",[2]],["m",[3]]]') return '@@iterator';
        \\  const seen = [];
        \\  const receiver = { tag: 'this' };
        \\  map.forEach(function(v, k, m) {
        \\    if (this !== receiver || m !== map) throw new Error('forEach receiver/map');
        \\    seen.push([k, v]);
        \\  }, receiver);
        \\  if (JSON.stringify(seen) !== '[["z",[4]],["a",[2]],["m",[3]]]') return 'forEach=' + JSON.stringify(seen);
        \\
        \\  // Live iteration across update, delete, re-insert, and clear (WebIDL 3.7.11.2)
        \\  const it = map.entries();
        \\  const s1 = it.next();
        \\  if (s1.done || s1.value[0] !== 'z' || s1.value[1][0] !== 4) return 's1';
        \\  // Update visited 'z' -> preserves position, NOT re-yielded
        \\  if (map.set('z', [40, 41]) !== undefined) return 'set return';
        \\  // Delete unvisited 'a' -> skipped
        \\  if (map.delete('a') !== true || map.delete('a') !== false) return 'delete a';
        \\  if (rule.cssText.includes('a:')) return 'cssText after delete=' + rule.cssText;
        \\  const s2 = it.next();
        \\  if (s2.done || s2.value[0] !== 'm' || s2.value[1][0] !== 3) return 's2';
        \\  // Delete visited 'z' and re-add -> goes to end and IS yielded
        \\  map.delete('z');
        \\  map.set('z', 77);
        \\  const s3 = it.next();
        \\  if (s3.done || s3.value[0] !== 'z' || s3.value[1][0] !== 77) return 's3';
        \\  // Clear and insert while iterator is still open -> yielded!
        \\  map.clear();
        \\  if (map.size !== 0) return 'size after clear';
        \\  map.set('after', [5, 6]);
        \\  const s4 = it.next();
        \\  if (s4.done || s4.value[0] !== 'after' || s4.value[1].length !== 2) return 's4';
        \\  const s5 = it.next();
        \\  if (!s5.done || s5.value !== undefined) return 's5';
        \\  return 'ok';
        \\})()
    );
}

test "CSSFontFeatureValuesMap maplike members iterate live and reflect CSSOM mutations" {
    try onThread(testCssFontFeatureValuesMapLive);
}

fn testNonInterfaceAndNonStringMaplikesAndSetlikes() !void {
    var tr: TestRealm = .{};
    try tr.open();
    defer tr.close();

    // 1. EventCounts: readonly maplike<DOMString, unsigned long long>
    const ec = try interfaces.EventCounts.init(a, tr.realm);
    if (comptime @hasDecl(interfaces.EventCounts, "maplikeEntries")) {
        const entries = interfaces.EventCounts.maplikeEntries(ec).?;
        try entries.set("click", 42);
        try entries.set("keydown", 9007199254740991); // MAX_SAFE_INTEGER
    }
    try tr.exposeInstance("__ec", ec);

    // 2. KeyboardLayoutMap: readonly maplike<DOMString, DOMString>
    const kl = try interfaces.KeyboardLayoutMap.init(a, tr.realm);
    if (comptime @hasDecl(interfaces.KeyboardLayoutMap, "maplikeEntries")) {
        const entries = interfaces.KeyboardLayoutMap.maplikeEntries(kl).?;
        try entries.set("KeyQ", "q");
        try entries.set("KeyW", "w");
    }
    try tr.exposeInstance("__kl", kl);

    // 3. GPUSupportedFeatures: readonly setlike<DOMString>
    const gpu = try interfaces.GPUSupportedFeatures.init(a, tr.realm);
    if (comptime @hasDecl(interfaces.GPUSupportedFeatures, "setlikeEntries")) {
        const entries = interfaces.GPUSupportedFeatures.setlikeEntries(gpu).?;
        try entries.append("texture-compression-bc");
        try entries.append("timestamp-query");
    }
    try tr.exposeInstance("__gpu", gpu);

    // 4. FontFaceVariations: readonly setlike<FontFaceVariationAxis> (empty)
    const ffv = try interfaces.FontFaceVariations.init(a, tr.realm);
    try tr.exposeInstance("__ffv", ffv);

    // 5. BluetoothManufacturerDataFilter: readonly maplike<unsigned short, BluetoothDataFilter>
    const bmdf = try interfaces.BluetoothManufacturerDataFilter.init(a, tr.realm);
    try tr.exposeInstance("__bmdf", bmdf);

    // 6. BluetoothServiceDataFilter: readonly maplike<UUID [=DOMString], BluetoothDataFilter>
    const bsdf = try interfaces.BluetoothServiceDataFilter.init(a, tr.realm);
    try tr.exposeInstance("__bsdf", bsdf);

    // 7. RTCStatsReport: readonly maplike<DOMString, object>
    const rtc = try interfaces.RTCStatsReport.init(a, tr.realm);
    try tr.exposeInstance("__rtc", rtc);

    // 8. BluetoothManufacturerDataMap: readonly maplike<unsigned short, DataView>
    const bmdm = try interfaces.BluetoothManufacturerDataMap.init(a, tr.realm);
    try tr.exposeInstance("__bmdm", bmdm);

    // 9. NamedFlowMap: read-write maplike<CSSOMString, NamedFlow>
    const nfm = try interfaces.NamedFlowMap.init(a, tr.realm);
    const nf = try interfaces.NamedFlow.init(a, tr.realm);
    try tr.exposeInstance("__nfm", nfm);
    try tr.exposeInstance("__nf", nf);

    try tr.evalOk(
        \\(() => {
        \\  // EventCounts (DOMString -> unsigned long long)
        \\  if (__ec.size !== 2) return 'ec.size=' + __ec.size;
        \\  if (__ec.get('click') !== 42) return 'ec.get(click)=' + __ec.get('click');
        \\  if (__ec.get('keydown') !== 9007199254740991) return 'ec.get(keydown)';
        \\  if (!__ec.has('click') || __ec.has('nope') || __ec.get('nope') !== undefined) return 'ec.has';
        \\  if (JSON.stringify([...__ec]) !== '[["click",42],["keydown",9007199254740991]]') return 'ec.iter';
        \\  if (__ec.set !== undefined || __ec.delete !== undefined || __ec.clear !== undefined) return 'ec.ro';
        \\
        \\  // KeyboardLayoutMap (DOMString -> DOMString)
        \\  if (__kl.size !== 2 || __kl.get('KeyQ') !== 'q' || __kl.get('KeyW') !== 'w') return 'kl.get';
        \\  if (JSON.stringify([...__kl.entries()]) !== '[["KeyQ","q"],["KeyW","w"]]') return 'kl.entries';
        \\
        \\  // GPUSupportedFeatures (readonly setlike<DOMString>)
        \\  if (__gpu.size !== 2 || !__gpu.has('timestamp-query') || __gpu.has('none')) return 'gpu.has';
        \\  if (JSON.stringify([...__gpu]) !== '["texture-compression-bc","timestamp-query"]') return 'gpu.iter';
        \\  if (JSON.stringify([...__gpu.entries()]) !== '[["texture-compression-bc","texture-compression-bc"],["timestamp-query","timestamp-query"]]') return 'gpu.entries';
        \\  if (__gpu.add !== undefined || __gpu.delete !== undefined || __gpu.clear !== undefined) return 'gpu.ro';
        \\
        \\  // Empty readonly setlike/maplike stubs
        \\  if (__ffv.size !== 0 || [...__ffv].length !== 0) return 'ffv';
        \\  if (__bmdf.size !== 0 || __bmdf.has(-0) !== false || __bmdf.get(0x10042) !== undefined || [...__bmdf].length !== 0) return 'bmdf';
        \\  // Non-string key conversion error propagates (Symbol -> ToNumber throws TypeError)
        \\  let symThrew = false;
        \\  try { __bmdf.has(Symbol('x')); } catch (e) { symThrew = e instanceof TypeError; }
        \\  if (!symThrew) return 'bmdf.symbol-key';
        \\  if (__bsdf.size !== 0 || __bsdf.has('0000180d-0000-1000-8000-00805f9b34fb') !== false) return 'bsdf';
        \\  if (__rtc.size !== 0 || __rtc.get('id') !== undefined || [...__rtc].length !== 0) return 'rtc';
        \\  if (__bmdm.size !== 0 || __bmdm.get(76) !== undefined || [...__bmdm].length !== 0) return 'bmdm';
        \\
        \\  // NamedFlowMap (read-write maplike<CSSOMString, NamedFlow>)
        \\  if (__nfm.set('main', __nf) !== __nfm) return 'nfm.set-ret';
        \\  if (__nfm.size !== 1 || !__nfm.has('main') || __nfm.get('main') !== __nf) return 'nfm.get';
        \\  let badValThrew = false;
        \\  try { __nfm.set('bad', {}); } catch (e) { badValThrew = e instanceof TypeError; }
        \\  if (!badValThrew) return 'nfm.bad-val';
        \\  if (__nfm.delete('main') !== true || __nfm.delete('main') !== false || __nfm.size !== 0) return 'nfm.delete';
        \\  __nfm.set('a', __nf);
        \\  __nfm.clear();
        \\  if (__nfm.size !== 0) return 'nfm.clear';
        \\  return 'ok';
        \\})()
    );
}

test "non-interface value types and non-string keys work across maplike and setlike" {
    try onThread(testNonInterfaceAndNonStringMaplikesAndSetlikes);
}

fn testZeroHandleLeaks() !void {
    var tr: TestRealm = .{};
    try tr.open();
    defer tr.close();

    const ec = try interfaces.EventCounts.init(a, tr.realm);
    if (comptime @hasDecl(interfaces.EventCounts, "maplikeEntries")) {
        const entries = interfaces.EventCounts.maplikeEntries(ec).?;
        try entries.set("click", 7);
    }
    try tr.exposeInstance("__ec", ec);

    const gpu = try interfaces.GPUSupportedFeatures.init(a, tr.realm);
    if (comptime @hasDecl(interfaces.GPUSupportedFeatures, "setlikeEntries")) {
        const entries = interfaces.GPUSupportedFeatures.setlikeEntries(gpu).?;
        try entries.append("bgra8unorm-storage");
    }
    try tr.exposeInstance("__gpu", gpu);

    const nfm = try interfaces.NamedFlowMap.init(a, tr.realm);
    const nf = try interfaces.NamedFlow.init(a, tr.realm);
    try tr.exposeInstance("__nfm", nfm);
    try tr.exposeInstance("__nf", nf);

    // Compile the workload once as a JS callback so before/after measures only
    // the setlike/maplike operations (not script compilation handles).
    const setup = try engine.evaluateClassicScript(
        tr.realm,
        .{
            .utf8 =
            \\(() => {
            \\  const d = new Document().implementation.createHTMLDocument('b7');
            \\  const style = d.createElement('style');
            \\  style.textContent = '@font-feature-values F { @styleset { k: 1 2; } }';
            \\  d.head.appendChild(style);
            \\  const ffm = style.sheet.cssRules[0].styleset;
            \\  return (i) => {
            \\    ffm.set('k', [i, i + 1]);
            \\    const v = ffm.get('k');
            \\    if (v[0] !== i) return false;
            \\    ffm.forEach((val, key) => { if (!key || !val.length) throw new Error(); });
            \\    for (const [k, val] of ffm.entries()) { if (!k || !val.length) throw new Error(); }
            \\    if (__ec.get('click') !== 7 || !__ec.has('click')) return false;
            \\    for (const [k, val] of __ec) { if (k !== 'click' || val !== 7) throw new Error(); }
            \\    if (!__gpu.has('bgra8unorm-storage')) return false;
            \\    for (const feat of __gpu) { if (feat !== 'bgra8unorm-storage') throw new Error(); }
            \\    __nfm.set('f', __nf);
            \\    if (__nfm.get('f') !== __nf || !__nfm.has('f')) return false;
            \\    for (const [k, val] of __nfm) { if (k !== 'f' || val !== __nf) throw new Error(); }
            \\    if (!__nfm.delete('f')) return false;
            \\    return true;
            \\  };
            \\})()
            ,
        },
        "bind1_setlike_maplike_test.js",
        null,
        .{ .report = Host.report, .host = null },
    );
    const cb: engine.CallbackFunction = .{ .function = setup, .context = tr.realm };
    defer cb.release();

    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const runN = struct {
        fn go(r: runtime.Context, f: *const engine.CallbackFunction, n: u32) !void {
            for (0..n) |i| {
                switch (try engine.invokeCallbackFunctionAs(bool, .{}, r, f, .undefined, .{@as(u32, @intCast(i))}, .rethrow, a)) {
                    .normal => |h| {
                        defer h.release(a);
                        try testing.expect(h.value);
                    },
                    .throw => |t| {
                        t.release();
                        return error.UnexpectedThrow;
                    },
                }
            }
        }
    }.go;

    try runN(tr.realm, &cb, 64);
    try engine.runInRealm(tr.realm, Collect.steps, tr.agent);
    try engine.runInRealm(tr.realm, Collect.steps, tr.agent);

    const isolate: *ffi.Isolate = @ptrCast(@alignCast(tr.agent));
    const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    try runN(tr.realm, &cb, 64);
    try engine.runInRealm(tr.realm, Collect.steps, tr.agent);
    try engine.runInRealm(tr.realm, Collect.steps, tr.agent);
    const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
    try testing.expectEqual(@as(i64, 0), after - before);
}

test "setlike and maplike operations leak zero V8 global handles over 64 iterations" {
    try onThread(testZeroHandleLeaks);
}

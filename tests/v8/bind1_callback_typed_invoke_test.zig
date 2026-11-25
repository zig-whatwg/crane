//! B6: typed callback invocations (`invokeCallbackFunctionAs`,
//! `invokeCallbackFunctionToPromise`, `constructCallbackFunctionAs`,
//! `callUserObjectOperationAs`) and prose conversion (`convertFromJS`).
//!
//! Covers:
//! - WebIDL 3.12 step 10 typed arguments (primitives, strings, instances,
//!   dictionaries, `webidl.Opt` missing middle + trailing truncation, variadic
//!   `[]const JSValue` tail).
//! - WebIDL 3.12 step 13 / 3.11 step 14 / construct step 12 typed return
//!   conversion inside the callback's prepared realm and incumbent scope:
//!   `void`, `bool`, `u16`, `f64` (unrestricted + restricted), `DOMString`,
//!   `?DOMString`, `USVString`, `ByteString`, dictionary, `*runtime.Instance`
//!   (with `Held.js` keeping the wrapper alive across GC), `JSValue`, union,
//!   `BorrowedCallbackFunction`.
//! - Conversion throws under `.rethrow` and `.report` (preserving throw site).
//! - WebIDL 3.2.24 promise return: always a new Promise on normal return,
//!   rejected Promise on sync throw, never throws into caller.
//! - Zero leaked V8 global handles over 64 calls per operation.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

const SampleDict = struct {
    pub const webidl_dictionary = true;
    offset: ?f64 = null,
    easing: ?runtime.DOMString = null,
    pub const restricted_members = .{"offset"};
    pub const nullable_members = .{"offset"};
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
    last_message: [256]u8 = undefined,
    last_message_len: usize = 0,
    last_lineno: u32 = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        const n = @min(info.message.len, self.last_message.len);
        @memcpy(self.last_message[0..n], info.message[0..n]);
        self.last_message_len = n;
        self.last_lineno = info.lineno;
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }

    fn message(self: *const Reports) []const u8 {
        return self.last_message[0..self.last_message_len];
    }
};

const no_hooks: protocol.HostHooks = .{};

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        test_process.start();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn openSecondRealm(self: Page) !runtime.Context {
        return protocol.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://other.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    fn evalIn(realm: runtime.Context, source: []const u8) !protocol.Owned {
        var reports: Reports = .{};
        const owned = try protocol.evaluateClassicScript(realm, .{ .utf8 = source }, "test.js", null, reports.reporter());
        try testing.expectEqual(@as(usize, 0), reports.count);
        return owned;
    }

    fn eval(self: Page, source: []const u8) !protocol.Owned {
        return evalIn(self.realm, source);
    }

    fn makeCallback(realm: runtime.Context, source: []const u8, callback_context: ?runtime.Context) !protocol.CallbackFunction {
        const owned = try evalIn(realm, source);
        return .{ .function = owned, .context = callback_context };
    }

    fn makeInterface(realm: runtime.Context, source: []const u8, callback_context: ?runtime.Context) !protocol.CallbackInterface {
        const owned = try evalIn(realm, source);
        return .{ .object = owned, .context = callback_context };
    }
};

test "invokeCallbackFunctionAs: primitives, strings, nullable, restricted double, ByteString" {
    const page = try Page.open();
    defer page.close();
    const a = testing.allocator;

    // void
    {
        const cb = try Page.makeCallback(page.realm, "(x) => x + 1", page.realm);
        defer cb.release();
        const out = try protocol.invokeCallbackFunctionAs(void, .{}, page.realm, &cb, .undefined, .{@as(i32, 5)}, .rethrow, a);
        switch (out) {
            .normal => |held| held.release(a),
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }
    }

    // bool
    {
        const cb = try Page.makeCallback(page.realm, "(s) => s.length > 2", page.realm);
        defer cb.release();
        const out = try protocol.invokeCallbackFunctionAs(bool, .{}, page.realm, &cb, .undefined, .{runtime.DOMString.initInterned("abc")}, .rethrow, a);
        switch (out) {
            .normal => |held| {
                defer held.release(a);
                try testing.expect(held.value);
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }
    }

    // unrestricted double (allows NaN and Infinity)
    {
        const cb = try Page.makeCallback(page.realm, "() => Infinity", page.realm);
        defer cb.release();
        const out = try protocol.invokeCallbackFunctionAs(f64, .{}, page.realm, &cb, .undefined, .{}, .rethrow, a);
        switch (out) {
            .normal => |held| {
                defer held.release(a);
                try testing.expect(std.math.isPositiveInf(held.value));
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }
    }

    // restricted double rejects NaN / Infinity with TypeError
    {
        const cb = try Page.makeCallback(page.realm, "() => NaN", page.realm);
        defer cb.release();
        const out = try protocol.invokeCallbackFunctionAs(f64, .{ .restricted_float = true }, page.realm, &cb, .undefined, .{}, .rethrow, a);
        switch (out) {
            .normal => |held| {
                held.release(a);
                return error.ExpectedThrow;
            },
            .throw => |t| t.release(),
        }
    }

    // ?DOMString: null/undefined -> null, value -> ToString
    {
        const cb_null = try Page.makeCallback(page.realm, "() => undefined", page.realm);
        defer cb_null.release();
        const out1 = try protocol.invokeCallbackFunctionAs(?runtime.DOMString, .{}, page.realm, &cb_null, .undefined, .{}, .rethrow, a);
        switch (out1) {
            .normal => |held| {
                defer held.release(a);
                try testing.expect(held.value == null);
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }

        const cb_str = try Page.makeCallback(page.realm, "() => 42", page.realm);
        defer cb_str.release();
        const out2 = try protocol.invokeCallbackFunctionAs(?runtime.DOMString, .{}, page.realm, &cb_str, .undefined, .{}, .rethrow, a);
        switch (out2) {
            .normal => |held| {
                defer held.release(a);
                try testing.expectEqualStrings("42", held.value.?.asSlice());
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }
    }

    // ByteString rejects code points > 0xFF
    {
        const cb = try Page.makeCallback(page.realm, "() => '\\u0100'", page.realm);
        defer cb.release();
        const out = try protocol.invokeCallbackFunctionAs(runtime.ByteString, .{ .byte_string = true }, page.realm, &cb, .undefined, .{}, .rethrow, a);
        switch (out) {
            .normal => |held| {
                held.release(a);
                return error.ExpectedThrow;
            },
            .throw => |t| t.release(),
        }
    }
}

test "invokeCallbackFunctionAs: dictionary and union returns, and typed arguments with Opt truncation" {
    const page = try Page.open();
    defer page.close();
    const a = testing.allocator;

    // Dictionary return
    {
        const cb = try Page.makeCallback(page.realm, "() => ({ offset: 0.5, easing: 'ease-in' })", page.realm);
        defer cb.release();
        const out = try protocol.invokeCallbackFunctionAs(SampleDict, .{}, page.realm, &cb, .undefined, .{}, .rethrow, a);
        switch (out) {
            .normal => |held| {
                defer held.release(a);
                try testing.expectEqual(@as(?f64, 0.5), held.value.offset);
                try testing.expectEqualStrings("ease-in", held.value.easing.?.asSlice());
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }
    }

    // Typed arguments: trailing missing webidl.Opt truncates arguments.length, middle missing passes undefined,
    // trailing []const JSValue appends variadic arguments.
    {
        const cb = try Page.makeCallback(page.realm, "(function(a, b, c) { return arguments.length + ':' + a + ':' + typeof b + ':' + c; })", page.realm);
        defer cb.release();
        const OptInt = webidl.Opt(i32);
        const out1 = try protocol.invokeCallbackFunctionAs(
            runtime.DOMString,
            .{},
            page.realm,
            &cb,
            .undefined,
            .{ runtime.DOMString.initInterned("hi"), OptInt.notPassed(), OptInt.notPassed() },
            .rethrow,
            a,
        );
        switch (out1) {
            .normal => |held| {
                defer held.release(a);
                try testing.expectEqualStrings("1:hi:undefined:undefined", held.value.asSlice());
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }

        const out2 = try protocol.invokeCallbackFunctionAs(
            runtime.DOMString,
            .{},
            page.realm,
            &cb,
            .undefined,
            .{ runtime.DOMString.initInterned("hi"), OptInt.notPassed(), OptInt.passed(7) },
            .rethrow,
            a,
        );
        switch (out2) {
            .normal => |held| {
                defer held.release(a);
                try testing.expectEqualStrings("3:hi:undefined:7", held.value.asSlice());
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }

        const extra = [_]runtime.JSValue{ .{ .number = 9 }, .{ .boolean = true } };
        const out3 = try protocol.invokeCallbackFunctionAs(
            runtime.DOMString,
            .{},
            page.realm,
            &cb,
            .undefined,
            .{ runtime.DOMString.initInterned("v"), @as([]const runtime.JSValue, &extra) },
            .rethrow,
            a,
        );
        switch (out3) {
            .normal => |held| {
                defer held.release(a);
                try testing.expectEqualStrings("3:v:number:true", held.value.asSlice());
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }
    }
}

test "invokeCallbackFunctionAs: return conversion throws inside callback context under rethrow and report" {
    const page = try Page.open();
    defer page.close();
    const a = testing.allocator;

    // valueOf throwing on unrestricted double (rethrow)
    {
        const cb = try Page.makeCallback(page.realm, "() => ({ valueOf() { throw new RangeError('bad-size'); } })", page.realm);
        defer cb.release();
        const out = try protocol.invokeCallbackFunctionAs(f64, .{}, page.realm, &cb, .undefined, .{}, .rethrow, a);
        switch (out) {
            .normal => |held| {
                held.release(a);
                return error.ExpectedThrow;
            },
            .throw => |t| {
                defer t.release();
                const text = try protocol.convertToDOMString(page.realm, t.borrow(), a);
                defer a.free(text);
                try testing.expect(std.mem.indexOf(u8, text, "bad-size") != null);
            },
        }
    }

    // toString throwing on ?DOMString under .report preserves throw site and returns null
    {
        const cb = try Page.makeCallback(page.realm, "\n\n() => ({ toString() { throw new Error('site-boom'); } })", page.realm);
        defer cb.release();
        var reports: Reports = .{};
        const out = try protocol.invokeCallbackFunctionAs(?runtime.DOMString, .{}, page.realm, &cb, .undefined, .{}, .{ .report = reports.reporter() }, a);
        switch (out) {
            .normal => |held| {
                defer held.release(a);
                try testing.expect(held.value == null);
                try testing.expectEqual(@as(usize, 1), reports.count);
                try testing.expect(std.mem.indexOf(u8, reports.message(), "site-boom") != null);
                try testing.expectEqual(@as(u32, 3), reports.last_lineno);
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }
    }

    // Cross-realm: return conversion runs inside F's associated realm (step 13
    // before step 14.2 cleanup), so a synthesized TypeError (restricted double
    // rejecting NaN) is an instance of F's realm's TypeError, not the caller's.
    {
        const other = try page.openSecondRealm();
        defer protocol.destroyWindowRealm(other, .global_detached);

        const cb = try Page.makeCallback(other, "() => NaN", other);
        defer cb.release();
        const out = try protocol.invokeCallbackFunctionAs(f64, .{ .restricted_float = true }, page.realm, &cb, .undefined, .{}, .rethrow, a);
        switch (out) {
            .normal => |held| {
                held.release(a);
                return error.ExpectedThrow;
            },
            .throw => |t| {
                defer t.release();
                const check_other = try Page.makeCallback(other, "(e) => e instanceof TypeError", other);
                defer check_other.release();
                const res = try protocol.invokeCallbackFunctionAs(bool, .{}, other, &check_other, .undefined, .{t.borrow()}, .rethrow, a);
                switch (res) {
                    .normal => |h| {
                        defer h.release(a);
                        try testing.expect(h.value);
                    },
                    .throw => |e| {
                        e.release();
                        return error.UnexpectedThrow;
                    },
                }
            },
        }
    }
}

test "invokeCallbackFunctionToPromise: PromiseResolve passes through same-realm Promise, wraps non-promise/cross-realm, sync throw rejects" {
    const page = try Page.open();
    defer page.close();

    // Non-promise return is wrapped in a fulfilled Promise
    {
        const cb = try Page.makeCallback(page.realm, "() => 123", page.realm);
        defer cb.release();
        const p = try protocol.invokeCallbackFunctionToPromise(page.realm, &cb, .undefined, .{});
        defer p.release();
        // V8 PromiseState: 0 = pending, 1 = fulfilled, 2 = rejected.
        try testing.expectEqual(@as(c_int, 1), ffi.v8_Promise_State(@ptrCast(@alignCast(p.value.handle.ptr))));
    }

    // Same-realm %Promise% passes through unchanged (PromiseResolve: 0 extra
    // microtask ticks, Chrome 157 + Firefox 159/161 2-of-3 browser majority).
    {
        const setup_res = try page.eval("globalThis.origPromise = Promise.resolve(123); globalThis.fnRetP = () => globalThis.origPromise; globalThis.fnRetP");
        const cb: protocol.CallbackFunction = .{ .function = setup_res, .context = page.realm };
        defer cb.release();

        const p = try protocol.invokeCallbackFunctionToPromise(page.realm, &cb, .undefined, .{});
        defer p.release();

        const check_cb = try Page.makeCallback(page.realm, "(p) => (p instanceof Promise) && (p === globalThis.origPromise)", page.realm);
        defer check_cb.release();
        const check = try protocol.invokeCallbackFunctionAs(bool, .{}, page.realm, &check_cb, .undefined, .{p.borrow()}, .rethrow, testing.allocator);
        switch (check) {
            .normal => |held| {
                defer held.release(testing.allocator);
                try testing.expect(held.value);
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }
    }

    // Cross-realm %Promise% is wrapped in a NEW %Promise% of F's associated realm.
    {
        const other = try page.openSecondRealm();
        defer protocol.destroyWindowRealm(other, .global_detached);
        const other_p = try Page.evalIn(other, "Promise.resolve(7)");
        defer other_p.release();
        const cb = try Page.makeCallback(page.realm, "(p) => p", page.realm);
        defer cb.release();
        const returned = try protocol.invokeCallbackFunctionToPromise(page.realm, &cb, .undefined, .{other_p.borrow()});
        defer returned.release();
        try testing.expect(!protocol.sameValue(page.realm, other_p.borrow(), returned.borrow()));
    }

    // Promise whose .constructor getter throws becomes a rejected Promise (never throws).
    {
        const cb = try Page.makeCallback(
            page.realm,
            "() => { const p = Promise.resolve(1); Object.defineProperty(p, 'constructor', { get() { throw new Error('ctor-boom'); } }); return p; }",
            page.realm,
        );
        defer cb.release();
        const p = try protocol.invokeCallbackFunctionToPromise(page.realm, &cb, .undefined, .{});
        defer p.release();
        try testing.expectEqual(@as(c_int, 2), ffi.v8_Promise_State(@ptrCast(@alignCast(p.value.handle.ptr))));
    }

    // Sync throw returns a rejected Promise (never throws)
    {
        const cb = try Page.makeCallback(page.realm, "() => { throw new TypeError('boom'); }", page.realm);
        defer cb.release();
        const p = try protocol.invokeCallbackFunctionToPromise(page.realm, &cb, .undefined, .{});
        defer p.release();
        // V8 PromiseState: 0 = pending, 1 = fulfilled, 2 = rejected.
        try testing.expectEqual(@as(c_int, 2), ffi.v8_Promise_State(@ptrCast(@alignCast(p.value.handle.ptr))));
    }
}

test "constructCallbackFunctionAs: interface return checks type and Held.js keeps wrapper alive across GC" {
    const page = try Page.open();
    defer page.close();
    const a = testing.allocator;

    // Returning a valid HTMLElement succeeds and survives GC while Held is live
    {
        const cb = try Page.makeCallback(page.realm, "(function MakeDiv() { return new Document().implementation.createHTMLDocument('').createElement('div'); })", page.realm);
        defer cb.release();
        const out = try protocol.constructCallbackFunctionAs(*runtime.Instance, .{ .interface = interfaces.HTMLElement }, page.realm, &cb, .{}, a);
        switch (out) {
            .normal => |held| {
                defer held.release(a);
                try page.collect();
                try testing.expect(held.value.stateAs(interfaces.HTMLElement.State) != null);
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }
    }

    // Returning a non-HTMLElement object throws TypeError
    {
        const cb = try Page.makeCallback(page.realm, "(function MakePlain() { return {}; })", page.realm);
        defer cb.release();
        const out = try protocol.constructCallbackFunctionAs(*runtime.Instance, .{ .interface = interfaces.HTMLElement }, page.realm, &cb, .{}, a);
        switch (out) {
            .normal => |held| {
                held.release(a);
                return error.ExpectedThrow;
            },
            .throw => |t| t.release(),
        }
    }

    // Non-constructor throws TypeError (step 3)
    {
        const cb = try Page.makeCallback(page.realm, "() => {}", page.realm);
        defer cb.release();
        const out = try protocol.constructCallbackFunctionAs(*runtime.Instance, .{ .interface = interfaces.HTMLElement }, page.realm, &cb, .{}, a);
        switch (out) {
            .normal => |held| {
                held.release(a);
                return error.ExpectedThrow;
            },
            .throw => |t| t.release(),
        }
    }
}

test "callUserObjectOperationAs: callable and object with operation, typed return (u16 and ?DOMString)" {
    const page = try Page.open();
    defer page.close();
    const a = testing.allocator;

    // Object with acceptNode -> u16 (NodeFilter shape)
    {
        const iface = try Page.makeInterface(page.realm, "({ acceptNode(x) { return x + 2; } })", page.realm);
        defer iface.release();
        const out = try protocol.callUserObjectOperationAs(u16, .{}, page.realm, &iface, "acceptNode", .undefined, .{@as(u16, 1)}, .rethrow, a);
        switch (out) {
            .normal => |held| {
                defer held.release(a);
                try testing.expectEqual(@as(u16, 3), held.value);
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }
    }

    // Callable object -> ?DOMString (XPathNSResolver shape)
    {
        const iface = try Page.makeInterface(page.realm, "(p) => p === 'svg' ? 'http://www.w3.org/2000/svg' : null", page.realm);
        defer iface.release();
        const out = try protocol.callUserObjectOperationAs(?runtime.DOMString, .{}, page.realm, &iface, "lookupNamespaceURI", .undefined, .{@as(?runtime.DOMString, runtime.DOMString.initInterned("svg"))}, .rethrow, a);
        switch (out) {
            .normal => |held| {
                defer held.release(a);
                try testing.expectEqualStrings("http://www.w3.org/2000/svg", held.value.?.asSlice());
            },
            .throw => |t| {
                t.release();
                return error.UnexpectedThrow;
            },
        }
    }
}

test "convertFromJS: prose dictionary conversion (BaseKeyframe) and getter throw" {
    const page = try Page.open();
    defer page.close();
    const a = testing.allocator;

    const good = try page.eval("({ offset: 0.25, easing: 'ease-out', composite: 'add' })");
    defer good.release();
    const out = try protocol.convertFromJS(SampleDict, .{}, page.realm, good.borrow(), a);
    switch (out) {
        .normal => |held| {
            defer held.release(a);
            try testing.expectEqual(@as(?f64, 0.25), held.value.offset);
            try testing.expectEqualStrings("ease-out", held.value.easing.?.asSlice());
        },
        .throw => |t| {
            t.release();
            return error.UnexpectedThrow;
        },
    }

    const bad = try page.eval("({ get offset() { throw new RangeError('getter-boom'); } })");
    defer bad.release();
    const out_bad = try protocol.convertFromJS(SampleDict, .{}, page.realm, bad.borrow(), a);
    switch (out_bad) {
        .normal => |held| {
            held.release(a);
            return error.ExpectedThrow;
        },
        .throw => |t| t.release(),
    }
}

test "handle counts over 64 calls: zero global handle bytes leaked across all B6 operations" {
    const page = try Page.open();
    defer page.close();
    const a = testing.allocator;

    const cb_str = try Page.makeCallback(page.realm, "(s) => s + '!'", page.realm);
    defer cb_str.release();
    const cb_throw = try Page.makeCallback(page.realm, "() => { throw new Error('x'); }", page.realm);
    defer cb_throw.release();
    const cb_ctor = try Page.makeCallback(page.realm, "function C() { return new Document().implementation.createHTMLDocument('').createElement('span'); }", page.realm);
    defer cb_ctor.release();
    const iface_op = try Page.makeInterface(page.realm, "({ acceptNode() { return 1; } })", page.realm);
    defer iface_op.release();
    const obj = try page.eval("({ offset: 0.5, easing: 'linear' })");
    defer obj.release();

    const runBatch = struct {
        fn go(
            r: runtime.Context,
            alloc: std.mem.Allocator,
            c_str: *const protocol.CallbackFunction,
            c_throw: *const protocol.CallbackFunction,
            c_ctor: *const protocol.CallbackFunction,
            i_op: *const protocol.CallbackInterface,
            o: runtime.JSValue,
        ) !void {
            for (0..64) |_| {
                switch (try protocol.invokeCallbackFunctionAs(?runtime.DOMString, .{}, r, c_str, .undefined, .{runtime.DOMString.initInterned("a")}, .rethrow, alloc)) {
                    .normal => |h| h.release(alloc),
                    .throw => |t| t.release(),
                }
                switch (try protocol.invokeCallbackFunctionAs(f64, .{}, r, c_throw, .undefined, .{}, .rethrow, alloc)) {
                    .normal => |h| h.release(alloc),
                    .throw => |t| t.release(),
                }
                const p1 = try protocol.invokeCallbackFunctionToPromise(r, c_str, .undefined, .{runtime.DOMString.initInterned("a")});
                p1.release();
                const p2 = try protocol.invokeCallbackFunctionToPromise(r, c_throw, .undefined, .{});
                p2.release();
                switch (try protocol.constructCallbackFunctionAs(*runtime.Instance, .{ .interface = interfaces.HTMLElement }, r, c_ctor, .{}, alloc)) {
                    .normal => |h| h.release(alloc),
                    .throw => |t| t.release(),
                }
                switch (try protocol.callUserObjectOperationAs(u16, .{}, r, i_op, "acceptNode", .undefined, .{}, .rethrow, alloc)) {
                    .normal => |h| h.release(alloc),
                    .throw => |t| t.release(),
                }
                switch (try protocol.convertFromJS(SampleDict, .{}, r, o, alloc)) {
                    .normal => |h| h.release(alloc),
                    .throw => |t| t.release(),
                }
            }
        }
    }.go;

    try runBatch(page.realm, a, &cb_str, &cb_throw, &cb_ctor, &iface_op, obj.borrow());
    try page.collect();
    const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate()));
    try runBatch(page.realm, a, &cb_str, &cb_throw, &cb_ctor, &iface_op, obj.borrow());
    try page.collect();
    const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate()));
    try testing.expectEqual(@as(i64, 0), after - before);
}

test "streams QueuingStrategySize converts return inside callback associated realm (WebIDL 3.12 step 13)" {
    const page = try Page.open();
    defer page.close();
    const other = try page.openSecondRealm();
    defer protocol.destroyWindowRealm(other, .global_detached);

    const other_size = try Page.evalIn(other, "() => Symbol('bad-size')");
    defer other_size.release();
    const other_type_error = try Page.evalIn(other, "TypeError");
    defer other_type_error.release();

    // Hand `other_size` and `other.TypeError` into `page.realm`.
    const install = try Page.makeCallback(page.realm, "(s, TE) => { globalThis.__otherSize = s; globalThis.__otherTE = TE; }", page.realm);
    defer install.release();
    switch (try protocol.invokeCallbackFunctionAs(void, .{}, page.realm, &install, .undefined, .{ other_size.borrow(), other_type_error.borrow() }, .rethrow, testing.allocator)) {
        .normal => |h| h.release(testing.allocator),
        .throw => |t| {
            t.release();
            return error.UnexpectedThrow;
        },
    }

    // ReadableStreamDefaultController.enqueue: size() returning Symbol() throws
    // other.TypeError (from size's associated realm, not the stream's realm).
    const rs_check = try Page.makeCallback(
        page.realm,
        \\() => {
        \\  let ctrl;
        \\  new ReadableStream({ start(c) { ctrl = c; } }, { size: globalThis.__otherSize, highWaterMark: 1 });
        \\  try { ctrl.enqueue('x'); return false; } catch (e) { return e instanceof globalThis.__otherTE; }
        \\}
    ,
        page.realm,
    );
    defer rs_check.release();
    switch (try protocol.invokeCallbackFunctionAs(bool, .{}, page.realm, &rs_check, .undefined, .{}, .rethrow, testing.allocator)) {
        .normal => |h| {
            defer h.release(testing.allocator);
            try testing.expect(h.value);
        },
        .throw => |t| {
            t.release();
            return error.UnexpectedThrow;
        },
    }

    // WritableStream: size() returning Symbol() rejects write() with other.TypeError.
    const ws_check = try Page.makeCallback(
        page.realm,
        \\() => {
        \\  globalThis.__wsOk = false;
        \\  const ws = new WritableStream({}, { size: globalThis.__otherSize, highWaterMark: 1 });
        \\  ws.getWriter().write('x').catch(e => { globalThis.__wsOk = (e instanceof globalThis.__otherTE); });
        \\}
    ,
        page.realm,
    );
    defer ws_check.release();
    switch (try protocol.invokeCallbackFunctionAs(void, .{}, page.realm, &ws_check, .undefined, .{}, .rethrow, testing.allocator)) {
        .normal => |h| h.release(testing.allocator),
        .throw => |t| {
            t.release();
            return error.UnexpectedThrow;
        },
    }
    const read_ok = try Page.makeCallback(page.realm, "() => globalThis.__wsOk", page.realm);
    defer read_ok.release();
    switch (try protocol.invokeCallbackFunctionAs(bool, .{}, page.realm, &read_ok, .undefined, .{}, .rethrow, testing.allocator)) {
        .normal => |h| {
            defer h.release(testing.allocator);
            try testing.expect(h.value);
        },
        .throw => |t| {
            t.release();
            return error.UnexpectedThrow;
        },
    }
}

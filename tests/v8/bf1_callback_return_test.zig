//! WebIDL invoke step 13 converts the result before either callback scope ends.
const std = @import("std");
const engine = @import("engine");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;

fn eval(isolate: *ffi.Isolate, context: *ffi.Context, source: []const u8) !*ffi.Value {
    const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return error.NoString;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.NoScript;
    defer ffi.v8_Script_Dispose(script);
    return ffi.v8_Script_Run(context, script) orelse error.NoValue;
}

fn setGlobal(isolate: *ffi.Isolate, context: *ffi.Context, name: []const u8, value: *ffi.Value) !void {
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return error.NoString;
    defer ffi.v8_String_Dispose(key);
    try std.testing.expect(ffi.v8_Object_Set(global, context, @ptrCast(key), value));
}

/// A native toString has no script frame that can replace the stored incumbent.
fn incumbentMarker(info: *const ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = ffi.v8_Isolate_GetIncumbentContext(isolate) orelse return;
    defer ffi.v8_Context_Dispose(context);
    const global = ffi.v8_Context_Global(context) orelse return;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(isolate, "marker", 6) orelse return;
    defer ffi.v8_String_Dispose(key);
    const marker = ffi.v8_Object_Get(global, context, @ptrCast(key)) orelse return;
    defer ffi.v8_Value_Dispose(marker);
    info.setReturnValue(marker);
}

fn invoke(realm: runtime.Context, callback: *const engine.CallbackFunction) !engine.Completion {
    return invokeWithBehavior(realm, callback, .rethrow);
}

fn invokeWithBehavior(realm: runtime.Context, callback: *const engine.CallbackFunction, behavior: engine.ExceptionBehavior) !engine.Completion {
    if (comptime @hasDecl(engine, "invokeCallbackFunctionWithReturnType")) {
        return engine.invokeCallbackFunctionWithReturnType(realm, callback, .undefined, &.{}, behavior, .nullable_dom_string);
    }
    return engine.invokeCallbackFunction(realm, callback, .undefined, &.{}, behavior);
}

fn release(completion: engine.Completion) void {
    switch (completion) {
        .normal => |value| value.release(),
        .throw => |value| value.release(),
    }
}

fn check(comptime site_only: bool) !void {
    try engine.initializeEngine(.{});
    const isolate = ffi.v8_Isolate_New() orelse return error.NoIsolate;
    defer ffi.v8_Isolate_Dispose(isolate);
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const scope = ffi.v8_HandleScope_New(isolate) orelse return error.NoScope;
    defer ffi.v8_HandleScope_Dispose(scope);
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    try v8.context_manager.init(std.testing.allocator);
    defer v8.context_manager.deinit();

    const caller = ffi.v8_Context_New(isolate) orelse return error.NoContext;
    defer ffi.v8_Context_Dispose(caller);
    const relevant = ffi.v8_Context_New(isolate) orelse return error.NoContext;
    defer ffi.v8_Context_Dispose(relevant);
    const stored = ffi.v8_Context_New(isolate) orelse return error.NoContext;
    defer ffi.v8_Context_Dispose(stored);
    const caller_realm = try v8.context_manager.getOrCreate(caller, std.testing.allocator);
    _ = try v8.context_manager.getOrCreate(relevant, std.testing.allocator);
    const stored_realm = try v8.context_manager.getOrCreate(stored, std.testing.allocator);
    ffi.v8_Context_Enter(caller);
    defer ffi.v8_Context_Exit(caller);
    const marker = try eval(isolate, stored, "globalThis.marker = 'stored'");
    ffi.v8_Value_Dispose(marker);
    const probe = ffi.v8_Function_NewWithData(caller, incumbentMarker, null, 0) orelse return error.NoFunction;
    defer ffi.v8_Value_Dispose(probe);
    try setGlobal(isolate, relevant, "probe", probe);
    const callback: engine.CallbackFunction = .{
        .function = .{ .value = runtime.JSValue.fromHandle(try eval(isolate, relevant, "(() => ({toString: probe}))")) },
        .context = stored_realm,
    };
    defer callback.release();
    if (!site_only) {
        const first = try invoke(caller_realm, &callback);
        defer release(first);
        try std.testing.expect(first == .normal);
        try std.testing.expect(engine.typeOf(caller_realm, first.normal.value) == .string);
        const text = try engine.convertToDOMString(caller_realm, first.normal.value, std.testing.allocator);
        defer std.testing.allocator.free(text);
        try std.testing.expectEqualStrings("stored", text);

        // V8 13.1's first Sparkplug tier-up allocates its own persistent
        // compilation queue (baseline-batch-compiler.cc:EnsureQueueCapacity).
        // Initialize that engine-wide queue with unrelated direct V8 calls,
        // before measuring the callback adapter's ownership.
        const plain = try eval(isolate, caller, "(() => 1)");
        defer ffi.v8_Value_Dispose(plain);
        const control_before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        for (0..32) |_| {
            var threw = false;
            var site: ?*ffi.V8ErrorInfo = null;
            const value = ffi.v8_Function_CallCatchingWithSite(caller, plain, null, 0, null, &threw, &site) orelse return error.NoControlValue;
            defer ffi.v8_Value_Dispose(value);
            defer ffi.v8_FreeErrorInfo(site);
            try std.testing.expect(!threw);
        }
        const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        std.debug.print("plain V8 tiering control: {d} -> {d} bytes\n", .{ control_before, before });
        for (0..64) |_| release(try invoke(caller_realm, &callback));
        const after_first = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        for (0..64) |_| release(try invoke(caller_realm, &callback));
        const after_second = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        std.debug.print("callback conversion handle probe: {d} -> {d} -> {d} bytes\n", .{ before, after_first, after_second });
        try std.testing.expectEqual(before, after_first);
        try std.testing.expectEqual(after_first, after_second);
    }

    // A primitive thrown during conversion has no stack property. The
    // reporter must receive the original TryCatch message before it is gone.
    const Reports = struct {
        count: usize = 0,
        line: u32 = 0,
        filename_matches: bool = false,
        fn report(data: ?*anyopaque, info: *const engine.ErrorInfo) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.count += 1;
            self.line = info.lineno;
            self.filename_matches = std.mem.eql(u8, info.filename, "bf1-return-conversion.js");
        }
    };
    var reports: Reports = .{};
    const primitive_throw: engine.CallbackFunction = .{
        .function = .{ .value = runtime.JSValue.fromHandle(try eval(isolate, relevant,
            \\(() => ({toString() {
            \\  throw 7;
            \\}}))
            \\//# sourceURL=bf1-return-conversion.js
        )) },
        .context = stored_realm,
    };
    defer primitive_throw.release();
    release(try invokeWithBehavior(caller_realm, &primitive_throw, .{ .report = .{ .report = Reports.report, .host = &reports } }));
    try std.testing.expectEqual(@as(usize, 1), reports.count);
    try std.testing.expectEqual(@as(u32, 2), reports.line);
    try std.testing.expect(reports.filename_matches);

    if (site_only) return;

    // ToString(Symbol) throws a TypeError in the callback's relevant realm.
    const throwing: engine.CallbackFunction = .{
        .function = .{ .value = runtime.JSValue.fromHandle(try eval(isolate, relevant, "(() => Symbol())")) },
        .context = stored_realm,
    };
    defer throwing.release();
    const failed = try invoke(caller_realm, &throwing);
    defer release(failed);
    try std.testing.expect(failed == .throw);
    try setGlobal(isolate, relevant, "caught", @ptrCast(@alignCast(failed.throw.value.handle.ptr)));
    const is_relevant_error = try eval(isolate, relevant, "caught instanceof TypeError");
    defer ffi.v8_Value_Dispose(is_relevant_error);
    try std.testing.expect(try v8.conversions.fromV8Value(bool, std.testing.allocator, isolate, relevant, is_relevant_error));
}

fn onThread(comptime site_only: bool) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = check(site_only);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}

test "callback return conversion keeps its incumbent, realm and no extra handles" {
    try onThread(false);
}

test "callback return conversion reports a primitive at its original throw site" {
    try onThread(true);
}

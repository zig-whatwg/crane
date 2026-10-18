//! WebAssembly Web API 2, "compile a potential WebAssembly response": the
//! host's steps (engine.HostHooks.compilePotentialWebAssemblyResponse,
//! [webassembly_streaming]).
//!
//! The engine owns WebAssembly.compileStreaming and instantiateStreaming, as
//! it owns the rest of WebAssembly: it does step 1, step 2's reaction to
//! `source` (a rejection rejects returnValue without reaching here), steps
//! 2.9.1-2.9.2 (asynchronously compile the bytes, resolve returnValue) and the
//! instantiation. This is steps 2.1-2.8 - the browsers split it the same way:
//! Blink's v8_wasm_response_extensions.cc StreamFromResponseCallback, Gecko's
//! FetchUtil::StreamResponseToJS, WebKit's
//! JSDOMGlobalObject::compileStreaming / handleResponseOnStreamingAction.
//!
//! The checks run in the spec's order - Content-Type, CORS-same-origin, ok
//! status - each a TypeError; Blink checks the status first, which changes
//! only the message. Step 2.8 consumes the body through the Response's own
//! arrayBuffer() steps (Fetch "consume body": unusable is a TypeError, a null
//! body is no bytes, a chunk that is not a Uint8Array is a TypeError, an
//! aborted fetch rejects with its reason), and step 2.9 hands the engine the
//! whole body in one part once it is read. That is the spec's own model -
//! its note says the difference from feeding the engine chunk by chunk, as
//! Blink's FetchDataLoaderForWasmStreaming does, is unobservable; per-chunk
//! feeding through a reader loop is a follow-up on the same operations.
//!
//! Spec: https://webassembly.github.io/spec/web-api/#compile-a-potential-webassembly-response

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const fetch = @import("fetch");
const dom = @import("dom");

const InternalResponse = fetch.internal.InternalResponse;

/// Whether this engine hands the host WebAssembly responses at all.
pub const supported = engine.capabilities.webassembly_streaming != .unsupported;

/// HostHooks.compilePotentialWebAssemblyResponse: steps 2.1-2.8 for the
/// `source` a compileStreaming or instantiateStreaming call in `realm`
/// fulfilled with. `compilation` is ended - finished or aborted - exactly
/// once, here or by the body's reaction.
pub fn compilePotentialWebAssemblyResponse(host: ?*anyopaque, realm: runtime.Context, source: engine.JSValue, compilation: *engine.WebAssemblyResponseCompilation) void {
    _ = host;
    if (comptime !supported) return;
    start(realm, source, compilation) catch |err| {
        const message = switch (err) {
            error.NotAResponse => "WebAssembly.compileStreaming(): an argument must be provided, which must be a Response or Promise<Response> object",
            error.NoContentType, error.WrongContentType => "WebAssembly.compileStreaming(): the response's MIME type is not 'application/wasm'",
            error.NotCorsSameOrigin => "WebAssembly.compileStreaming(): the response is not CORS-same-origin",
            error.NotOk => "WebAssembly.compileStreaming(): the response's status is not an ok status",
            else => "WebAssembly.compileStreaming(): the response's body could not be read",
        };
        rejectWithTypeError(realm, compilation, message);
    };
}

const StartError = error{ NotAResponse, NoContentType, WrongContentType, NotCorsSameOrigin, NotOk, OutOfMemory, BodyFailed };

/// Steps 2.1-2.8; on an error nothing has ended `compilation`.
fn start(realm: runtime.Context, source: engine.JSValue, compilation: *engine.WebAssemblyResponseCompilation) StartError!void {
    // 2.1. "Let response be unwrappedSource's response." unwrappedSource is a
    // Response object: the Promise<Response> argument's conversion, which
    // the engine's own Promise.resolve does not make.
    const object = engine.convertToPlatformObject(realm, source) orelse return error.NotAResponse;
    if (object.stateAs(interfaces.Response.State) == null) return error.NotAResponse;
    const response: *InternalResponse = @ptrCast(@alignCast(dom.fetch_objects.responseOf(object) orelse return error.NotAResponse));

    // 2.2-2.5. The Content-Type of response's header list, with HTTP tab or
    // space bytes trimmed, is exactly `application/wasm`, ignoring ASCII
    // case: no parameters, not even an empty `application/wasm;`.
    try checkContentType(realm.allocator, response);

    // 2.6. CORS-same-origin: a response whose type is "basic", "cors" or
    // "default" (HTML 2.5.4).
    if (!isCorsSameOrigin(response)) return error.NotCorsSameOrigin;

    // 2.7. An ok status: 200 to 299.
    if (!fetch.internal.isOkStatus(response.status)) return error.NotOk;

    // The module's URL (WebAssembly Web API section 4), read now - the
    // response does not change while its body is read - and serialized as
    // Response's `url` getter does, with exclude fragment (Blink hands V8
    // response->url()).
    const raw_url = response.url() orelse "";
    const url = raw_url[0 .. std.mem.indexOfScalar(u8, raw_url, '#') orelse raw_url.len];
    const read = Read.create(realm, compilation, url) catch return error.OutOfMemory;
    errdefer read.destroy();

    // 2.8. "Consume response's body as an ArrayBuffer, and let bodyPromise be
    // the result" - the Body mixin's arrayBuffer() steps, on the Response
    // object.
    // A [NewObject] result: the caller's to release.
    const body_promise: engine.Owned = .{ .value = interfaces.Response.call_arrayBuffer(object) catch return error.BodyFailed };
    defer body_promise.release();

    // 2.9. "React to bodyPromise" - in `realm`, so the reaction ends with it
    // (its dropped end) at the latest.
    engine.reactToPromise(realm, body_promise.value, &Read.steps, read) catch return error.BodyFailed;
}

/// Steps 2.2-2.5: getting `Content-Type` from `response`'s header list.
fn checkContentType(allocator: std.mem.Allocator, response: *const InternalResponse) StartError!void {
    // 2.2. "Let mimeType be the result of getting `Content-Type` from
    // response's header list."
    const mime_type = (response.header_list.get(allocator, "Content-Type") catch return error.OutOfMemory) orelse {
        // 2.3. Null.
        return error.NoContentType;
    };
    defer allocator.free(mime_type);
    // 2.4. "Remove all HTTP tab or space byte from the start and end of
    // mimeType."
    const trimmed = std.mem.trim(u8, mime_type, "\t ");
    // 2.5. A byte-case-insensitive match for `application/wasm`.
    if (!std.ascii.eqlIgnoreCase(trimmed, "application/wasm")) return error.WrongContentType;
}

/// HTML 2.5.4 "CORS-same-origin": a response whose type is "basic", "cors"
/// or "default".
fn isCorsSameOrigin(response: *const InternalResponse) bool {
    return switch (response.response_type) {
        .basic, .cors, .default => true,
        .@"error", .@"opaque", .opaqueredirect => false,
    };
}

/// Reject returnValue with a new TypeError of `realm` - ending `compilation`.
fn rejectWithTypeError(realm: runtime.Context, compilation: *engine.WebAssemblyResponseCompilation, message: []const u8) void {
    if (comptime !supported) return;
    const type_error = engine.createSimpleException(realm, .TypeError, message) catch {
        // No error could be made: still end the compilation. The promise is
        // left pending only when the engine cannot make a value at all.
        return engine.abortWebAssemblyResponse(compilation, null);
    };
    defer type_error.release();
    engine.abortWebAssemblyResponse(compilation, type_error.value);
}

/// Step 2.9's reaction to bodyPromise: its one end of `compilation`.
const Read = struct {
    realm: runtime.Context,
    compilation: *engine.WebAssemblyResponseCompilation,
    /// The response's URL, owned.
    url: []u8,

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled, .rejected = rejected, .dropped = dropped };

    fn create(realm: runtime.Context, compilation: *engine.WebAssemblyResponseCompilation, url: []const u8) !*Read {
        const self = try realm.allocator.create(Read);
        errdefer realm.allocator.destroy(self);
        self.* = .{ .realm = realm, .compilation = compilation, .url = try realm.allocator.dupe(u8, url) };
        return self;
    }

    fn destroy(self: *Read) void {
        const allocator = self.realm.allocator;
        allocator.free(self.url);
        allocator.destroy(self);
    }

    /// "If bodyPromise was fulfilled with value bodyArrayBuffer": 1. "Let
    /// stableBytes be a copy of the bytes held by the buffer
    /// bodyArrayBuffer" - the engine copies what it is handed - 2.
    /// "Asynchronously compile the WebAssembly module stableBytes ... and
    /// resolve returnValue with the result."
    fn fulfilled(data: ?*anyopaque, value: engine.JSValue) void {
        const self: *Read = @ptrCast(@alignCast(data.?));
        defer self.destroy();
        if (comptime !supported) return;
        if (engine.borrowArrayBufferBytes(self.realm, value)) |bytes| {
            engine.appendWebAssemblyResponseBytes(self.compilation, bytes) catch {};
        }
        engine.finishWebAssemblyResponse(self.compilation, self.url);
    }

    /// "If bodyPromise was rejected with reason reason: Reject returnValue
    /// with reason."
    fn rejected(data: ?*anyopaque, reason: engine.JSValue) void {
        const self: *Read = @ptrCast(@alignCast(data.?));
        defer self.destroy();
        if (comptime !supported) return;
        engine.abortWebAssemblyResponse(self.compilation, reason);
    }

    /// The reaction ended unsettled - its realm ended, or the promise was
    /// collected: nothing can see returnValue, which is left unsettled.
    fn dropped(data: ?*anyopaque) void {
        const self: *Read = @ptrCast(@alignCast(data.?));
        defer self.destroy();
        if (comptime !supported) return;
        engine.abortWebAssemblyResponse(self.compilation, null);
    }
};

//! WebIDL Dictionary Parsing for WHATWG Streams
//!
//! This module provides functions to parse WebIDL dictionaries from JavaScript
//! objects. These parsers are used by stream constructors and methods to extract
//! configuration options from user-provided objects.
//!
//! Spec: https://streams.spec.whatwg.org/
//! WebIDL: https://webidl.spec.whatwg.org/#idl-dictionaries
//!
//! Uses webidl's dictionary extraction utilities for proper parsing.

const std = @import("std");
const webidl = @import("webidl");
const dict = @import("dict_types");
const common = @import("common");
const dom = @import("dom");

// ============================================================================
// UnderlyingSource Dictionary Parsing
// ============================================================================

/// Parse UnderlyingSource dictionary from JavaScript object
///
/// Spec: § 4.1.3 "new ReadableStream(underlyingSource, strategy)" - Step 2
///
/// IDL:
/// ```webidl
/// dictionary UnderlyingSource {
///   UnderlyingSourceStartCallback start;
///   UnderlyingSourcePullCallback pull;
///   UnderlyingSourceCancelCallback cancel;
///   ReadableStreamType type;
///   [EnforceRange] unsigned long long autoAllocateChunkSize;
/// };
/// ```
///
/// Algorithm:
/// 1. Let dict be underlyingSource, converted to an IDL value of type UnderlyingSource
/// 2. Extract start, pull, cancel callbacks if present
/// 3. Extract type field ("bytes" or undefined)
/// 4. Extract autoAllocateChunkSize if type is "bytes"
/// 5. Validate autoAllocateChunkSize is positive if present
pub fn parseUnderlyingSource(
    allocator: std.mem.Allocator,
    value: ?webidl.JSValue,
) !dict.UnderlyingSource {
    _ = allocator;

    // If value is null or undefined, return defaults
    if (value == null) {
        return .{};
    }

    const js_value = value.?;

    // If value is undefined or null, return defaults
    if (js_value == .undefined or js_value == .null) {
        return .{};
    }

    // Step 1: Extract callbacks using webidl.extractCallback
    const start = try webidl.extractCallback(js_value, "start", false);
    const pull = try webidl.extractCallback(js_value, "pull", false);
    const cancel = try webidl.extractCallback(js_value, "cancel", false);

    // Step 2: Extract type property (optional, "bytes" or undefined)
    var stream_type: ?dict.ReadableStreamType = null;
    if (js_value == .object) {
        if (js_value.object.get("type")) |type_value| {
            if (type_value == .string) {
                const type_str = type_value.string;
                if (std.mem.eql(u8, type_str, "bytes")) {
                    stream_type = dict.ReadableStreamType.bytes;
                } else {
                    // Invalid type value - spec says to throw TypeError
                    return error.TypeError;
                }
            } else if (type_value != .undefined and type_value != .null) {
                return error.TypeError;
            }
        }
    }

    // Step 3: Extract autoAllocateChunkSize with [EnforceRange]
    const auto_allocate = try webidl.extractDictionaryMemberWithAttrs(
        ?u64,
        js_value,
        "autoAllocateChunkSize",
        false, // optional
        null, // no default
        .{ .enforce_range = true },
    );

    // Step 4: Validate autoAllocateChunkSize > 0 if present
    if (auto_allocate) |chunk_size| {
        if (chunk_size == 0) {
            return error.TypeError;
        }
    }

    return .{
        .start = start,
        .pull = pull,
        .cancel = cancel,
        .type = stream_type,
        .auto_allocate_chunk_size = auto_allocate,
    };
}

// ============================================================================
// UnderlyingSink Dictionary Parsing
// ============================================================================

/// Parse UnderlyingSink dictionary from JavaScript object
///
/// Spec: § 4.2.4 "new WritableStream(underlyingSink, strategy)" - Step 2
///
/// IDL:
/// ```webidl
/// dictionary UnderlyingSink {
///   UnderlyingSinkStartCallback start;
///   UnderlyingSinkWriteCallback write;
///   UnderlyingSinkCloseCallback close;
///   UnderlyingSinkAbortCallback abort;
///   any type;
/// };
/// ```
///
/// Algorithm:
/// 1. Let dict be underlyingSink, converted to an IDL value of type UnderlyingSink
/// 2. Extract start, write, close, abort callbacks if present
/// 3. Extract type field (must be undefined, reserved for future use)
/// 4. Throw TypeError if type is not undefined
pub fn parseUnderlyingSink(
    allocator: std.mem.Allocator,
    value: ?webidl.JSValue,
) !dict.UnderlyingSink {
    _ = allocator;

    // If value is null or undefined, return defaults
    if (value == null) {
        return .{};
    }

    const js_value = value.?;

    // If value is undefined or null, return defaults
    if (js_value == .undefined or js_value == .null) {
        return .{};
    }

    // Step 1: Extract callbacks using webidl.extractCallback
    const start = try webidl.extractCallback(js_value, "start", false);
    const write = try webidl.extractCallback(js_value, "write", false);
    const close = try webidl.extractCallback(js_value, "close", false);
    const abort = try webidl.extractCallback(js_value, "abort", false);

    // Step 2: Extract type property (reserved for future use, must be undefined)
    if (js_value == .object) {
        if (js_value.object.get("type")) |type_value| {
            // Type property must be undefined or null
            if (type_value != .undefined and type_value != .null) {
                return error.TypeError;
            }
        }
    }

    return .{
        .start = start,
        .write = write,
        .close = close,
        .abort = abort,
        .type = null, // Reserved for future use
    };
}

// ============================================================================
// Transformer Dictionary Parsing
// ============================================================================

/// Parse Transformer dictionary from JavaScript object
///
/// Spec: § 4.3.3 "new TransformStream(transformer, writableStrategy, readableStrategy)" - Step 2
///
/// IDL:
/// ```webidl
/// dictionary Transformer {
///   TransformerStartCallback start;
///   TransformerTransformCallback transform;
///   TransformerFlushCallback flush;
///   TransformerCancelCallback cancel;
///   any readableType;
///   any writableType;
/// };
/// ```
///
/// Algorithm:
/// 1. Let dict be transformer, converted to an IDL value of type Transformer
/// 2. Extract start, transform, flush, cancel callbacks if present
/// 3. Extract readableType and writableType fields (must be undefined)
/// 4. Throw TypeError if readableType or writableType is not undefined
pub fn parseTransformer(
    allocator: std.mem.Allocator,
    value: ?webidl.JSValue,
) !dict.Transformer {
    _ = allocator;

    // If value is null or undefined, return defaults
    if (value == null) {
        return .{};
    }

    const js_value = value.?;

    // If value is undefined or null, return defaults
    if (js_value == .undefined or js_value == .null) {
        return .{};
    }

    // Step 1: Extract callbacks using webidl.extractCallback
    const start = try webidl.extractCallback(js_value, "start", false);
    const transform = try webidl.extractCallback(js_value, "transform", false);
    const flush = try webidl.extractCallback(js_value, "flush", false);
    const cancel = try webidl.extractCallback(js_value, "cancel", false);

    // Step 2: Extract readableType and writableType (reserved for future use, must be undefined)
    if (js_value == .object) {
        if (js_value.object.get("readableType")) |readable_type| {
            if (readable_type != .undefined and readable_type != .null) {
                return error.TypeError;
            }
        }
        if (js_value.object.get("writableType")) |writable_type| {
            if (writable_type != .undefined and writable_type != .null) {
                return error.TypeError;
            }
        }
    }

    return .{
        .start = start,
        .transform = transform,
        .flush = flush,
        .cancel = cancel,
        .readable_type = null, // Reserved for future use
        .writable_type = null, // Reserved for future use
    };
}

// ============================================================================
// QueuingStrategy Dictionary Parsing
// ============================================================================

/// Parse QueuingStrategy dictionary from JavaScript object
///
/// Used by stream constructors to extract queuing configuration.
///
/// IDL:
/// ```webidl
/// dictionary QueuingStrategy {
///   unrestricted double highWaterMark;
///   QueuingStrategySize size;
/// };
/// ```
///
/// Algorithm:
/// 1. Let dict be strategy, converted to an IDL value of type QueuingStrategy
/// 2. Extract highWaterMark if present (unrestricted double, allows Infinity/NaN)
/// 3. Extract size callback if present
pub fn parseQueuingStrategy(
    allocator: std.mem.Allocator,
    value: ?webidl.JSValue,
) !dict.QueuingStrategy {
    _ = allocator;

    // If value is null or undefined, return defaults
    if (value == null) {
        return .{};
    }

    const js_value = value.?;

    // If value is undefined or null, return defaults
    if (js_value == .undefined or js_value == .null) {
        return .{};
    }

    // Step 1: Extract highWaterMark (unrestricted double - allows Infinity/NaN)
    const high_water_mark = try webidl.extractDictionaryMember(
        ?f64,
        js_value,
        "highWaterMark",
        false, // optional
        null, // no default
    );

    // Step 2: Extract size callback
    const size = try webidl.extractCallback(js_value, "size", false);

    return .{
        .high_water_mark = high_water_mark,
        .size = size,
    };
}

/// Extract high water mark from QueuingStrategy, with default
///
/// Spec: Multiple places use "Extract high water mark from strategy"
///
/// Algorithm:
/// 1. Let highWaterMark be ? Get(strategy, "highWaterMark")
/// 2. If highWaterMark is undefined, return defaultHWM
/// 3. Return ? ToNumber(highWaterMark)
pub fn extractHighWaterMark(
    value: ?webidl.JSValue,
    default_hwm: f64,
) !f64 {
    if (value == null) {
        return default_hwm;
    }

    const js_value = value.?;

    // If value is undefined or null, return default
    if (js_value == .undefined or js_value == .null) {
        return default_hwm;
    }

    // Extract highWaterMark property from object (as optional)
    const hwm_optional = try webidl.extractDictionaryMember(
        ?f64,
        js_value,
        "highWaterMark",
        false, // optional
        null,
    );

    // Return extracted value or default
    return hwm_optional orelse default_hwm;
}

/// Extract size algorithm from QueuingStrategy, with default
///
/// Spec: Multiple places use "Extract size algorithm from strategy"
///
/// Algorithm:
/// 1. Let size be ? Get(strategy, "size")
/// 2. If size is undefined, return default algorithm (returns 1 for every chunk)
/// 3. Return size (as a callable)
pub fn extractSizeAlgorithm(
    value: ?webidl.JSValue,
) common.SizeAlgorithm {
    if (value == null) {
        return common.defaultSizeAlgorithm();
    }

    const js_value = value.?;

    // If value is undefined or null, return default
    if (js_value == .undefined or js_value == .null) {
        return common.defaultSizeAlgorithm();
    }

    // Extract size callback from object
    const size = webidl.extractCallback(js_value, "size", false) catch {
        return common.defaultSizeAlgorithm();
    };

    // If no size callback provided, return default
    if (size == null) {
        return common.defaultSizeAlgorithm();
    }

    // Wrap callback in SizeAlgorithm
    return common.wrapGenericSizeCallback(size.?);
}

// ============================================================================
// StreamPipeOptions Dictionary Parsing
// ============================================================================

/// Parse StreamPipeOptions dictionary from JavaScript object
///
/// Used by pipeTo and pipeThrough to control pipe behavior.
///
/// IDL:
/// ```webidl
/// dictionary StreamPipeOptions {
///   boolean preventClose = false;
///   boolean preventAbort = false;
///   boolean preventCancel = false;
///   AbortSignal signal;
/// };
/// ```
///
/// Algorithm:
/// 1. Let dict be options, converted to an IDL value of type StreamPipeOptions
/// 2. Extract preventClose (default false)
/// 3. Extract preventAbort (default false)
/// 4. Extract preventCancel (default false)
/// 5. Extract signal if present
pub fn parseStreamPipeOptions(
    allocator: std.mem.Allocator,
    value: ?webidl.JSValue,
) !dict.StreamPipeOptions {
    _ = allocator;

    // If value is null or undefined, return defaults
    if (value == null) {
        return .{};
    }

    const js_value = value.?;

    // If value is undefined or null, return defaults
    if (js_value == .undefined or js_value == .null) {
        return .{};
    }

    // Step 1: Check if value is an object
    if (js_value != .object) {
        return error.TypeError;
    }

    const obj = js_value.object;

    var options = dict.StreamPipeOptions{};

    // Step 2: Get "preventClose" property (default false)
    if (obj.get("preventClose")) |prevent_close| {
        options.prevent_close = prevent_close.toBoolean();
    }

    // Step 3: Get "preventAbort" property (default false)
    if (obj.get("preventAbort")) |prevent_abort| {
        options.prevent_abort = prevent_abort.toBoolean();
    }

    // Step 4: Get "preventCancel" property (default false)
    if (obj.get("preventCancel")) |prevent_cancel| {
        options.prevent_cancel = prevent_cancel.toBoolean();
    }

    // Step 5: Get "signal" property if present (AbortSignal)
    if (obj.get("signal")) |signal_value| {
        // Extract AbortSignal interface instance using webidl unwrapping
        // This validates the type and extracts the native Zig pointer
        if (webidl.isInterface(signal_value)) {
            options.signal = webidl.unwrapInterface(dom.AbortSignal, signal_value) catch null;
        }
    }

    return options;
}

// ============================================================================
// ReadableWritablePair Dictionary Parsing
// ============================================================================

/// Parse ReadableWritablePair dictionary from JavaScript object
///
/// Used by pipeThrough to extract transform stream sides.
///
/// IDL:
/// ```webidl
/// dictionary ReadableWritablePair {
///   required ReadableStream readable;
///   required WritableStream writable;
/// };
/// ```
///
/// Algorithm:
/// 1. Let dict be transform, converted to an IDL value of type ReadableWritablePair
/// 2. Extract readable (required field)
/// 3. Extract writable (required field)
/// 4. Throw TypeError if either field is missing
pub fn parseReadableWritablePair(
    allocator: std.mem.Allocator,
    value: webidl.JSValue,
) !dict.ReadableWritablePair {
    _ = allocator;

    // Step 1: Check if value is an object
    if (value != .object) {
        return error.TypeError;
    }

    const obj = value.object;

    // Step 2: Get "readable" property (required)
    const readable_value = obj.get("readable") orelse return error.TypeError;

    // Step 3: Validate readable is a ReadableStream instance
    if (readable_value != .interface_ptr) {
        return error.TypeError;
    }

    const ReadableStream = @import("readable_stream").ReadableStream;
    const readable_stream = webidl.unwrapInterface(ReadableStream, readable_value) catch return error.TypeError;

    // Step 4: Get "writable" property (required)
    const writable_value = obj.get("writable") orelse return error.TypeError;

    // Step 5: Validate writable is a WritableStream instance
    if (writable_value != .interface_ptr) {
        return error.TypeError;
    }

    const WritableStream = @import("writable_stream").WritableStream;
    const writable_stream = webidl.unwrapInterface(WritableStream, writable_value) catch return error.TypeError;

    return dict.ReadableWritablePair{
        .readable = @ptrCast(readable_stream),
        .writable = @ptrCast(writable_stream),
    };
}

// ============================================================================
// ReadableStreamGetReaderOptions Dictionary Parsing
// ============================================================================

/// Parse ReadableStreamGetReaderOptions dictionary from JavaScript object
///
/// Used by getReader to determine reader type.
///
/// IDL:
/// ```webidl
/// dictionary ReadableStreamGetReaderOptions {
///   ReadableStreamReaderMode mode;
/// };
/// ```
///
/// Algorithm:
/// 1. Let dict be options, converted to an IDL value of type ReadableStreamGetReaderOptions
/// 2. Extract mode if present ("byob" or undefined)
pub fn parseReadableStreamGetReaderOptions(
    allocator: std.mem.Allocator,
    value: ?webidl.JSValue,
) !dict.ReadableStreamGetReaderOptions {
    _ = allocator;

    // If value is null or undefined, return defaults
    if (value == null) {
        return .{};
    }

    const js_value = value.?;

    // If value is undefined or null, return defaults
    if (js_value == .undefined or js_value == .null) {
        return .{};
    }

    // Step 1: Check if value is an object
    if (js_value != .object) {
        return error.TypeError;
    }

    const obj = js_value.object;

    // Step 2: Get "mode" property (optional)
    if (obj.get("mode")) |mode_value| {
        // Step 3: Convert to enum
        if (mode_value == .string) {
            const mode_str = mode_value.string;

            // Step 4: "byob" is the only valid value
            if (std.mem.eql(u8, mode_str, "byob")) {
                return .{ .mode = .byob };
            } else {
                // Invalid mode value
                return error.TypeError;
            }
        } else if (mode_value == .undefined or mode_value == .null) {
            // Undefined/null mode means default
            return .{ .mode = null };
        } else {
            // Mode must be a string
            return error.TypeError;
        }
    }

    // No mode specified - return defaults
    return .{};
}

// ============================================================================
// ReadableStreamIteratorOptions Dictionary Parsing
// ============================================================================

/// Parse ReadableStreamIteratorOptions dictionary from JavaScript object
///
/// Used by async iteration (values method).
///
/// IDL:
/// ```webidl
/// dictionary ReadableStreamIteratorOptions {
///   boolean preventCancel = false;
/// };
/// ```
pub fn parseReadableStreamIteratorOptions(
    allocator: std.mem.Allocator,
    value: ?webidl.JSValue,
) !dict.ReadableStreamIteratorOptions {
    _ = allocator;

    // If value is null or undefined, return defaults
    if (value == null) {
        return .{};
    }

    const js_value = value.?;

    // If value is undefined or null, return defaults
    if (js_value == .undefined or js_value == .null) {
        return .{};
    }

    // Step 1: Check if value is an object
    if (js_value != .object) {
        return error.TypeError;
    }

    const obj = js_value.object;

    var options = dict.ReadableStreamIteratorOptions{};

    // Step 2: Get "preventCancel" property (default false)
    if (obj.get("preventCancel")) |prevent_cancel| {
        options.prevent_cancel = prevent_cancel.toBoolean();
    }

    return options;
}

// ============================================================================
// ReadableStreamBYOBReaderReadOptions Dictionary Parsing
// ============================================================================

/// Parse ReadableStreamBYOBReaderReadOptions dictionary from JavaScript object
///
/// Used by BYOB reader read method.
///
/// IDL:
/// ```webidl
/// dictionary ReadableStreamBYOBReaderReadOptions {
///   [EnforceRange] unsigned long long min = 1;
/// };
/// ```
pub fn parseReadableStreamBYOBReaderReadOptions(
    allocator: std.mem.Allocator,
    value: ?webidl.JSValue,
) !dict.ReadableStreamBYOBReaderReadOptions {
    _ = allocator;

    // If value is null or undefined, return defaults
    if (value == null) {
        return .{};
    }

    const js_value = value.?;

    // If value is undefined or null, return defaults
    if (js_value == .undefined or js_value == .null) {
        return .{};
    }

    // Extract min property with [EnforceRange] attribute (default 1)
    const min = try webidl.extractDictionaryMemberWithAttrs(
        u64,
        js_value,
        "min",
        false, // optional
        1, // default value
        .{ .enforce_range = true },
    );

    return .{ .min = min };
}

// ============================================================================
// QueuingStrategyInit Dictionary Parsing
// ============================================================================

/// Parse QueuingStrategyInit dictionary from JavaScript object
///
/// Used by ByteLengthQueuingStrategy and CountQueuingStrategy constructors.
///
/// IDL:
/// ```webidl
/// dictionary QueuingStrategyInit {
///   required unrestricted double highWaterMark;
/// };
/// ```
pub fn parseQueuingStrategyInit(
    allocator: std.mem.Allocator,
    value: webidl.JSValue,
) !dict.QueuingStrategyInit {
    _ = allocator;

    // Extract required highWaterMark property (unrestricted double)
    const high_water_mark = try webidl.extractDictionaryMember(
        f64,
        value,
        "highWaterMark",
        true, // required
        null,
    );

    return .{ .high_water_mark = high_water_mark };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "parseUnderlyingSource - null returns defaults" {
    const result = try parseUnderlyingSource(testing.allocator, null);
    try testing.expect(result.start == null);
    try testing.expect(result.pull == null);
    try testing.expect(result.cancel == null);
    try testing.expect(result.type == null);
    try testing.expect(result.auto_allocate_chunk_size == null);
}

test "parseUnderlyingSink - null returns defaults" {
    const result = try parseUnderlyingSink(testing.allocator, null);
    try testing.expect(result.start == null);
    try testing.expect(result.write == null);
    try testing.expect(result.close == null);
    try testing.expect(result.abort == null);
    try testing.expect(result.type == null);
}

test "parseTransformer - null returns defaults" {
    const result = try parseTransformer(testing.allocator, null);
    try testing.expect(result.start == null);
    try testing.expect(result.transform == null);
    try testing.expect(result.flush == null);
    try testing.expect(result.cancel == null);
    try testing.expect(result.readable_type == null);
    try testing.expect(result.writable_type == null);
}

test "parseQueuingStrategy - null returns defaults" {
    const result = try parseQueuingStrategy(testing.allocator, null);
    try testing.expect(result.high_water_mark == null);
    try testing.expect(result.size == null);
}

test "extractHighWaterMark - null returns default" {
    const result = try extractHighWaterMark(null, 1.0);
    try testing.expectEqual(@as(f64, 1.0), result);
}

test "extractHighWaterMark - number returns value" {
    const value = webidl.JSValue{ .number = 16.0 };
    const result = try extractHighWaterMark(value, 1.0);
    try testing.expectEqual(@as(f64, 16.0), result);
}

test "parseStreamPipeOptions - null returns defaults" {
    const result = try parseStreamPipeOptions(testing.allocator, null);
    try testing.expect(!result.prevent_close);
    try testing.expect(!result.prevent_abort);
    try testing.expect(!result.prevent_cancel);
    try testing.expect(result.signal == null);
}

test "parseQueuingStrategyInit - number extracts high water mark" {
    const value = webidl.JSValue{ .number = 5.0 };
    const result = try parseQueuingStrategyInit(testing.allocator, value);
    try testing.expectEqual(@as(f64, 5.0), result.high_water_mark);
}

test "parseReadableStreamGetReaderOptions - undefined returns defaults" {
    const result = try parseReadableStreamGetReaderOptions(testing.allocator, null);
    try testing.expect(result.mode == null);
}

test "parseReadableStreamGetReaderOptions - byob mode" {
    var obj = webidl.JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("mode", .{ .string = "byob" });
    const value = webidl.JSValue{ .object = obj };

    const result = try parseReadableStreamGetReaderOptions(testing.allocator, value);
    try testing.expect(result.mode != null);
    try testing.expectEqual(dict.ReaderMode.byob, result.mode.?);
}

test "parseReadableStreamGetReaderOptions - invalid mode fails" {
    var obj = webidl.JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("mode", .{ .string = "invalid" });
    const value = webidl.JSValue{ .object = obj };

    const result = parseReadableStreamGetReaderOptions(testing.allocator, value);
    try testing.expectError(error.TypeError, result);
}

test "parseStreamPipeOptions - all options" {
    var obj = webidl.JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("preventClose", .{ .boolean = true });
    try obj.set("preventAbort", .{ .boolean = true });
    try obj.set("preventCancel", .{ .boolean = false });
    const value = webidl.JSValue{ .object = obj };

    const result = try parseStreamPipeOptions(testing.allocator, value);
    try testing.expect(result.prevent_close);
    try testing.expect(result.prevent_abort);
    try testing.expect(!result.prevent_cancel);
}

test "parseReadableStreamIteratorOptions - preventCancel" {
    var obj = webidl.JSObject.init(testing.allocator);
    defer obj.deinit();

    try obj.set("preventCancel", .{ .boolean = true });
    const value = webidl.JSValue{ .object = obj };

    const result = try parseReadableStreamIteratorOptions(testing.allocator, value);
    try testing.expect(result.prevent_cancel);
}

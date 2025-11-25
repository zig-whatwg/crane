//! Implementation for TextEncoder interface
//!
//! WHATWG Encoding Standard § 5.2
//! https://encoding.spec.whatwg.org/#interface-textencoder
//!
//! TextEncoder encodes strings into UTF-8 byte sequences.
//!
//! ## Features
//!
//! - **UTF-8 Only**: Always encodes to UTF-8 (no label parameter)
//! - **No Streaming**: Stateless operation (no buffering needed)
//! - **Two Methods**: `encode()` allocates new buffer, `encodeInto()` uses existing buffer
//! - **Performance**: ASCII fast path for common cases

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const infra = @import("infra");

const TextEncoder = interfaces.TextEncoder;

pub const State = TextEncoder.State;

pub const ImplError = error{
    /// Out of memory
    OutOfMemory,
    /// Invalid state
    InvalidState,
};

/// Internal state for TextEncoder implementation
/// TextEncoder is stateless, so this just stores the allocator for encode()
pub const InternalState = struct {
    /// Memory allocator for encode() output
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        self.allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// WHATWG Encoding Standard § 5.2.1
/// https://encoding.spec.whatwg.org/#dom-textencoder
///
/// Creates a new UTF-8 encoder (stateless).
///
/// The new TextEncoder() constructor steps are to do nothing.
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &TextEncoder.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = InternalState{
        .allocator = allocator,
    };

    state.own._internal = internal;

    // Set encoding to "utf-8" (always UTF-8 per spec)
    state.own.encoding = runtime.DOMString.initInterned("utf-8");

    return instance;
}

/// Getter for encoding
/// Returns the encoding name (always "utf-8" for TextEncoder)
/// Spec: https://encoding.spec.whatwg.org/#dom-textencodercommon-encoding
pub fn get_encoding(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const state = instance.getState(State);
    return state.own.encoding;
}

/// encode() operation
/// WHATWG Encoding Standard § 5.2.2
/// https://encoding.spec.whatwg.org/#dom-textencoder-encode
///
/// Encodes the input string to UTF-8 and returns a newly allocated Uint8Array.
///
/// The encode(input) method steps are:
/// 1. Convert input to an I/O queue of scalar values
/// 2. Let output be the I/O queue of bytes
/// 3. Process with UTF-8 encoder
/// 4. Return Uint8Array
pub fn call_encode(instance: *runtime.Instance, input: runtime.USVString) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return ImplError.InvalidState;
    const allocator = internal.allocator;

    // Handle empty input (common case)
    if (input.len == 0) {
        // Return pointer to empty Uint8Array descriptor
        // The V8 bindings layer will create the actual Uint8Array object
        return createUint8ArrayDescriptor(allocator, "") catch return ImplError.OutOfMemory;
    }

    // ASCII FAST PATH: For ASCII-only input, copy directly
    if (isAscii(input)) {
        const output = allocator.dupe(u8, input) catch return ImplError.OutOfMemory;
        return createUint8ArrayDescriptor(allocator, output) catch return ImplError.OutOfMemory;
    }

    // GENERAL PATH: Validate and encode UTF-8
    // Since input is already USVString (valid UTF-8), we can copy directly
    // USVString contains only Unicode scalar values (no surrogates)
    if (!std.unicode.utf8ValidateSlice(input)) {
        // Invalid UTF-8 - replace invalid sequences with U+FFFD
        // This shouldn't happen with proper USVString input, but handle gracefully
        const output = replaceInvalidUtf8(allocator, input) catch return ImplError.OutOfMemory;
        return createUint8ArrayDescriptor(allocator, output) catch return ImplError.OutOfMemory;
    }

    // Valid UTF-8 - duplicate
    const output = allocator.dupe(u8, input) catch return ImplError.OutOfMemory;
    return createUint8ArrayDescriptor(allocator, output) catch return ImplError.OutOfMemory;
}

/// encodeInto() operation
/// WHATWG Encoding Standard § 5.2.3
/// https://encoding.spec.whatwg.org/#dom-textencoder-encodeinto
///
/// Encodes the source string into the destination buffer (zero-copy, no allocation).
///
/// The encodeInto(source, destination) method steps are:
/// 1. Convert source to scalar values
/// 2. Encode with UTF-8 encoder into destination
/// 3. Return read/written counts
pub fn call_encodeInto(
    instance: *runtime.Instance,
    source: runtime.USVString,
    destination: *const anyopaque,
) ImplError!dictionaries.TextEncoderEncodeIntoResult {
    _ = instance;

    // Extract destination buffer from opaque pointer
    // The V8 bindings layer should have passed a Uint8Array that we can write to
    const dest_buf = extractUint8ArrayBuffer(destination);

    var read: u64 = 0;
    var written: u64 = 0;

    // Process UTF-8 input
    var i: usize = 0;
    while (i < source.len and written < dest_buf.len) {
        // Get UTF-8 code point length
        const cp_len = std.unicode.utf8ByteSequenceLength(source[i]) catch {
            // Invalid UTF-8 start byte - skip
            i += 1;
            read += 1;
            continue;
        };

        // Check if we have enough space in destination
        if (written + cp_len > dest_buf.len) {
            // Not enough space for this code point - stop here
            // (don't partially write multibyte characters)
            break;
        }

        // Check if we have enough input bytes
        if (i + cp_len > source.len) {
            // Incomplete code point at end of input
            break;
        }

        // Copy code point bytes to destination
        @memcpy(dest_buf[written .. written + cp_len], source[i .. i + cp_len]);

        written += cp_len;
        read += cp_len;
        i += cp_len;
    }

    return .{
        .read = read,
        .written = written,
    };
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Check if byte slice is ASCII-only (fast path optimization)
fn isAscii(bytes: []const u8) bool {
    return infra.string.isAscii(bytes);
}

/// Replace invalid UTF-8 sequences with U+FFFD REPLACEMENT CHARACTER
fn replaceInvalidUtf8(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    const replacement = "\u{FFFD}"; // U+FFFD in UTF-8 (3 bytes: EF BF BD)

    var i: usize = 0;
    while (i < input.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(input[i]) catch {
            // Invalid start byte - replace with U+FFFD
            try output.appendSlice(replacement);
            i += 1;
            continue;
        };

        if (i + cp_len > input.len) {
            // Incomplete code point at end - replace with U+FFFD
            try output.appendSlice(replacement);
            break;
        }

        // Validate code point
        const cp = std.unicode.utf8Decode(input[i .. i + cp_len]) catch {
            // Invalid code point - replace with U+FFFD
            try output.appendSlice(replacement);
            i += cp_len;
            continue;
        };

        // Valid code point - encode back to UTF-8
        var buf: [4]u8 = undefined;
        const out_len = std.unicode.utf8Encode(cp, &buf) catch unreachable;
        try output.appendSlice(buf[0..out_len]);
        i += cp_len;
    }

    return output.toOwnedSlice();
}

/// Descriptor for passing Uint8Array data to V8 bindings
/// This is a simple struct that V8 bindings can read to create the actual Uint8Array
const Uint8ArrayDescriptor = extern struct {
    data: [*]const u8,
    len: usize,
};

/// Create a Uint8Array descriptor for V8 bindings
/// The descriptor is allocated and the pointer is returned as *const anyopaque
fn createUint8ArrayDescriptor(allocator: std.mem.Allocator, data: []const u8) !*const anyopaque {
    const desc = try allocator.create(Uint8ArrayDescriptor);
    desc.* = .{
        .data = data.ptr,
        .len = data.len,
    };
    return @ptrCast(desc);
}

/// Extract the byte buffer from a Uint8Array opaque pointer
/// The V8 bindings should have passed a pointer to a buffer descriptor
fn extractUint8ArrayBuffer(source: *const anyopaque) []u8 {
    // Check for null-like pointer
    const source_addr = @intFromPtr(source);
    if (source_addr == 0) {
        return &[_]u8{};
    }

    // Interpret as a Uint8Array descriptor
    // This assumes V8 bindings pass a compatible struct
    const Uint8ArrayWriteDescriptor = extern struct {
        data: [*]u8,
        len: usize,
    };

    const desc: *const Uint8ArrayWriteDescriptor = @ptrCast(@alignCast(source));
    if (desc.len == 0) {
        return &[_]u8{};
    }

    return desc.data[0..desc.len];
}

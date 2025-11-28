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
const webidl = @import("webidl");
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
pub fn call_encode(instance: *runtime.Instance, input: webidl.Opt(runtime.USVString)) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return ImplError.InvalidState;
    const allocator = internal.allocator;

    // Unwrap Opt for input (default to empty string)
    const input_str = if (input.wasPassed()) input.value else "";

    // Handle empty input (common case)
    if (input_str.len == 0) {
        // Return pointer to empty Uint8Array descriptor
        // The V8 bindings layer will create the actual Uint8Array object
        return createUint8ArrayDescriptor(allocator, "") catch return ImplError.OutOfMemory;
    }

    // ASCII FAST PATH: For ASCII-only input, copy directly
    if (isAscii(input_str)) {
        const output = allocator.dupe(u8, input_str) catch return ImplError.OutOfMemory;
        return createUint8ArrayDescriptor(allocator, output) catch return ImplError.OutOfMemory;
    }

    // GENERAL PATH: Validate and encode UTF-8
    // Since input is already USVString (valid UTF-8), we can copy directly
    // USVString contains only Unicode scalar values (no surrogates)
    if (!std.unicode.utf8ValidateSlice(input_str)) {
        // Invalid UTF-8 - replace invalid sequences with U+FFFD
        // This shouldn't happen with proper USVString input, but handle gracefully
        const output = replaceInvalidUtf8(allocator, input_str) catch return ImplError.OutOfMemory;
        return createUint8ArrayDescriptor(allocator, output) catch return ImplError.OutOfMemory;
    }

    // Valid UTF-8 - duplicate
    const output = allocator.dupe(u8, input_str) catch return ImplError.OutOfMemory;
    return createUint8ArrayDescriptor(allocator, output) catch return ImplError.OutOfMemory;
}

/// encodeInto() operation
/// WHATWG Encoding Standard § 5.2.3
/// https://encoding.spec.whatwg.org/#dom-textencoder-encodeinto
///
/// Encodes the source string into the destination buffer (zero-copy, no allocation).
///
/// IMPORTANT: The `read` return value counts UTF-16 code units, NOT UTF-8 bytes.
/// This is because JavaScript strings are UTF-16 encoded internally.
/// For code points > U+FFFF (supplementary plane), read increments by 2 (surrogate pair).
///
/// The encodeInto(source, destination) method steps are:
/// 1. Let read be 0.
/// 2. Let written be 0.
/// 3. Let encoder be an instance of the UTF-8 encoder.
/// 4. Let unused be the I/O queue of scalar values « end-of-queue ».
/// 5. Convert source to an I/O queue of scalar values.
/// 6. While true:
///    a. Let item be the result of reading from source.
///    b. Let result be the result of running encoder's handler on unused and item.
///    c. If result is finished, then break.
///    d. Otherwise:
///       i.   If destination's byte length − written >= number of bytes in result:
///            1. If item is greater than U+FFFF, then increment read by 2.
///            2. Otherwise, increment read by 1.
///            3. Write the bytes in result into destination, with startingOffset set to written.
///            4. Increment written by the number of bytes in result.
///       ii.  Otherwise, break.
/// 7. Return «[ "read" → read, "written" → written ]».
pub fn call_encodeInto(instance: *runtime.Instance, source: runtime.USVString, destination: *const anyopaque) ImplError!dictionaries.TextEncoderEncodeIntoResult {
    _ = instance;

    // Extract destination buffer from opaque pointer
    // The V8 bindings layer should have passed a Uint8Array that we can write to
    const dest_buf = extractUint8ArrayBuffer(destination);

    // Step 1-2: Initialize counters
    var read: u64 = 0;
    var written: u64 = 0;

    // Step 5-6: Process each scalar value (code point) from source
    // Source is USVString (UTF-8 encoded), we decode to code points then encode back
    var i: usize = 0;
    while (i < source.len) {
        // Step 6a: Read next scalar value (code point) from source
        const cp_len = std.unicode.utf8ByteSequenceLength(source[i]) catch {
            // Invalid UTF-8 start byte - this shouldn't happen with valid USVString
            // Skip this byte (it won't be encoded)
            i += 1;
            continue;
        };

        // Check if we have complete UTF-8 sequence
        if (i + cp_len > source.len) {
            // Incomplete UTF-8 sequence at end - stop processing
            break;
        }

        // Decode the code point
        const code_point = std.unicode.utf8Decode(source[i .. i + cp_len]) catch {
            // Invalid UTF-8 sequence - skip
            i += cp_len;
            continue;
        };

        // Step 6b: Run UTF-8 encoder's handler
        // UTF-8 encoding of a code point produces 1-4 bytes
        var encoded_bytes: [4]u8 = undefined;
        const bytes_needed = std.unicode.utf8Encode(code_point, &encoded_bytes) catch {
            // This shouldn't happen for valid scalar values
            i += cp_len;
            continue;
        };

        // Step 6c: If result is finished (end-of-queue), break
        // (We check this implicitly by the while loop condition)

        // Step 6d: Check if we have enough space in destination
        if (written + bytes_needed > dest_buf.len) {
            // Step 6d.ii: Not enough space - break without writing
            break;
        }

        // Step 6d.i: We have enough space - write and update counters

        // Step 6d.i.1-2: Update read counter based on UTF-16 representation
        // Code points > U+FFFF require a surrogate pair (2 code units) in UTF-16
        // Code points <= U+FFFF require 1 code unit in UTF-16
        if (code_point > 0xFFFF) {
            read += 2; // Surrogate pair in UTF-16
        } else {
            read += 1; // Single code unit in UTF-16
        }

        // Step 6d.i.3: Write the encoded bytes to destination
        @memcpy(dest_buf[written .. written + bytes_needed], encoded_bytes[0..bytes_needed]);

        // Step 6d.i.4: Increment written by number of bytes
        written += bytes_needed;

        // Move to next code point in source
        i += cp_len;
    }

    // Step 7: Return result
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

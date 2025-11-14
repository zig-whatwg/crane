//! IPv4 Parser
//!
//! WHATWG URL Standard: https://url.spec.whatwg.org/#ipv4-parser
//! Spec Reference: Lines 461-537
//!
//! Parses IPv4 addresses from ASCII strings. Supports:
//! - Decimal notation: 192.168.1.1
//! - Hexadecimal notation: 0xC0.0xA8.0x1.0x1
//! - Octal notation: 0300.0250.01.01
//! - Mixed formats: 192.0xA8.0001.1
//! - Abbreviated forms: 127.1, 192.168.257
//!
//! ## Usage
//!
//! ```zig
//! const ipv4 = @import("ipv4_parser");
//!
//! // Parse standard notation
//! const addr = try ipv4.parseIPv4(allocator, "192.168.1.1", &errors);
//! // Result: 0xC0A80101
//!
//! // Parse abbreviated
//! const addr2 = try ipv4.parseIPv4(allocator, "127.1", &errors);
//! // Result: 0x7F000001
//! ```

const std = @import("std");
const infra = @import("infra");
const validation = @import("validation");

pub const IPv4Error = error{
    EmptyPart,
    TooManyParts,
    NonNumericPart,
    OutOfRange,
    OutOfMemory,
};

/// IPv4 number parser result (spec line 507)
const NumberResult = struct {
    value: u64,
    validation_error: bool, // true if non-decimal (hex or octal)
};

/// Parse an IPv4 number (spec lines 507-537)
///
/// Supports decimal, hexadecimal (0x prefix), and octal (leading 0).
/// Returns (value, validation_error) where validation_error is true for non-decimal.
fn parseIPv4Number(input: []const u8) !NumberResult {
    // Step 1: Empty string is failure
    if (input.len == 0) {
        return IPv4Error.NonNumericPart;
    }

    var validation_error = false;
    var R: u8 = 10; // Radix
    var start: usize = 0;

    // Step 4: Check for hexadecimal (0x or 0X)
    if (input.len >= 2 and input[0] == '0' and (input[1] == 'x' or input[1] == 'X')) {
        validation_error = true;
        start = 2;
        R = 16;
    }
    // Step 5: Check for octal (leading 0)
    else if (input.len >= 2 and input[0] == '0') {
        validation_error = true;
        start = 1;
        R = 8;
    }

    const number_part = input[start..];

    // Step 6: Empty after prefix means 0
    if (number_part.len == 0) {
        return NumberResult{ .value = 0, .validation_error = true };
    }

    // Step 7: Check all characters are valid for the radix
    // Step 8: Parse the number
    const value = std.fmt.parseInt(u64, number_part, R) catch {
        return IPv4Error.NonNumericPart;
    };

    // Step 9: Return (value, validation_error)
    return NumberResult{ .value = value, .validation_error = validation_error };
}

/// Parse IPv4 address (spec lines 461-505)
///
/// Takes ASCII string and returns 32-bit IPv4 address.
/// Supports various notations and validates according to spec.
///
/// Note: errors List must be initialized with the same allocator
pub fn parseIPv4(
    allocator: std.mem.Allocator,
    input: []const u8,
    errors: ?*infra.List(validation.ValidationError),
) !u32 {
    // Step 1: Split on '.'
    var parts = infra.List([]const u8).init(allocator);
    defer parts.deinit();

    var it = std.mem.splitScalar(u8, input, '.');
    while (it.next()) |part| {
        try parts.append(part);
    }

    // Step 2: Handle trailing empty part
    if (parts.len > 0 and parts.get(parts.len - 1).?.len == 0) {
        if (errors) |errs| {
            try errs.append(.{ .type = .ipv4_empty_part });
        }

        // Remove last item if there's more than one part
        if (parts.len > 1) {
            _ = parts.remove(parts.len - 1) catch unreachable;
        }
    }

    // Step 3: Check for too many parts
    if (parts.len > 4) {
        if (errors) |errs| {
            try errs.append(.{ .type = .ipv4_too_many_parts });
        }
        return IPv4Error.TooManyParts;
    }

    // Step 4: Parse each part
    var numbers = infra.List(u64).init(allocator);
    defer numbers.deinit();

    // Step 5: Parse each part
    for (parts.toSlice()) |part| {
        const result = parseIPv4Number(part) catch {
            if (errors) |errs| {
                try errs.append(.{ .type = .ipv4_non_numeric_part });
            }
            return IPv4Error.NonNumericPart;
        };

        // Step 5.3: Non-decimal validation error
        if (result.validation_error) {
            if (errors) |errs| {
                try errs.append(.{ .type = .ipv4_non_decimal_part });
            }
        }

        // Step 5.4: Append to numbers
        try numbers.append(result.value);
    }

    // Step 6: Check if any item > 255 (validation error)
    for (numbers.toSlice()) |n| {
        if (n > 255) {
            if (errors) |errs| {
                try errs.append(.{ .type = .ipv4_out_of_range_part });
            }
            break; // Only report once
        }
    }

    // Step 7: If any but last > 255, failure
    const nums_slice = numbers.toSlice();
    for (nums_slice[0 .. nums_slice.len - 1]) |n| {
        if (n > 255) {
            return IPv4Error.OutOfRange;
        }
    }

    // Step 8: Check last item range
    const max_last = std.math.pow(u64, 256, 5 - numbers.len);
    if (nums_slice[nums_slice.len - 1] >= max_last) {
        return IPv4Error.OutOfRange;
    }

    // Step 9: Get last item
    var ipv4 = nums_slice[nums_slice.len - 1];

    // Step 11-12: Accumulate other parts
    var counter: usize = 0;
    for (nums_slice[0 .. nums_slice.len - 1]) |n| {
        const shift = std.math.pow(u64, 256, 3 - counter);
        ipv4 += n * shift;
        counter += 1;
    }

    // Step 13: Return as u32
    return @intCast(ipv4);
}

test "ipv4 parser - standard notation" {
    const allocator = std.testing.allocator;

    // 192.168.1.1 = 0xC0A80101
    const addr = try parseIPv4(allocator, "192.168.1.1", null);
    try std.testing.expectEqual(@as(u32, 0xC0A80101), addr);
}

test "ipv4 parser - localhost" {
    const allocator = std.testing.allocator;

    // 127.0.0.1 = 0x7F000001
    const addr = try parseIPv4(allocator, "127.0.0.1", null);
    try std.testing.expectEqual(@as(u32, 0x7F000001), addr);
}

test "ipv4 parser - abbreviated two parts" {
    const allocator = std.testing.allocator;

    // 127.1 = 127.0.0.1 = 0x7F000001
    const addr = try parseIPv4(allocator, "127.1", null);
    try std.testing.expectEqual(@as(u32, 0x7F000001), addr);
}

test "ipv4 parser - abbreviated one part" {
    const allocator = std.testing.allocator;

    // 2130706433 = 127.0.0.1 = 0x7F000001
    const addr = try parseIPv4(allocator, "2130706433", null);
    try std.testing.expectEqual(@as(u32, 0x7F000001), addr);
}

test "ipv4 parser - hexadecimal" {
    const allocator = std.testing.allocator;

    // 0xC0.0xA8.0x1.0x1 = 192.168.1.1
    const addr = try parseIPv4(allocator, "0xC0.0xA8.0x1.0x1", null);
    try std.testing.expectEqual(@as(u32, 0xC0A80101), addr);
}

test "ipv4 parser - octal" {
    const allocator = std.testing.allocator;

    // 0300.0250.01.01 = 192.168.1.1
    const addr = try parseIPv4(allocator, "0300.0250.01.01", null);
    try std.testing.expectEqual(@as(u32, 0xC0A80101), addr);
}

test "ipv4 parser - trailing dot" {
    const allocator = std.testing.allocator;

    var errors_list = infra.List(validation.ValidationError).init(allocator);
    defer errors_list.deinit();

    // 127.0.0.1. should parse and generate validation error
    const addr = try parseIPv4(allocator, "127.0.0.1.", &errors_list);
    try std.testing.expectEqual(@as(u32, 0x7F000001), addr);
    try std.testing.expectEqual(@as(usize, 1), errors_list.len);
    try std.testing.expectEqual(validation.ErrorType.ipv4_empty_part, errors_list.get(0).?.type);
}

test "ipv4 parser - too many parts" {
    const allocator = std.testing.allocator;

    // 1.2.3.4.5 should fail
    try std.testing.expectError(IPv4Error.TooManyParts, parseIPv4(allocator, "1.2.3.4.5", null));
}

test "ipv4 parser - non-numeric" {
    const allocator = std.testing.allocator;

    // test.42 should fail
    try std.testing.expectError(IPv4Error.NonNumericPart, parseIPv4(allocator, "test.42", null));
}

test "ipv4 parser - out of range" {
    const allocator = std.testing.allocator;

    // 255.255.4000.1 should fail (4000 > 255 in non-last position)
    try std.testing.expectError(IPv4Error.OutOfRange, parseIPv4(allocator, "255.255.4000.1", null));
}

//! WebIDL Enumeration Type Support
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-enums
//!
//! WebIDL enumerations are sets of string values. Conversion validates that
//! the provided JavaScript string matches one of the enumeration's values.

const std = @import("std");
const primitives = @import("primitives.zig");

pub fn Enumeration(comptime values: []const []const u8) type {
    return struct {
        value: []const u8,

        const Self = @This();

        pub fn fromJSValue(js_value: primitives.JSValue) !Self {
            const str = switch (js_value) {
                .string => |s| s,
                else => return error.TypeError,
            };

            for (values) |valid| {
                if (std.mem.eql(u8, str, valid)) {
                    return Self{ .value = str };
                }
            }

            return error.TypeError;
        }

        pub fn eql(self: Self, other: []const u8) bool {
            return std.mem.eql(u8, self.value, other);
        }

        pub fn is(self: Self, comptime expected: []const u8) bool {
            comptime {
                var found = false;
                for (values) |v| {
                    if (std.mem.eql(u8, v, expected)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    @compileError("Value '" ++ expected ++ "' is not a valid enumeration value");
                }
            }
            return std.mem.eql(u8, self.value, expected);
        }
    };
}

const testing = std.testing;




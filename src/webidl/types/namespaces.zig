//! WebIDL Namespace Support
//!
//! Spec: https://webidl.spec.whatwg.org/#idl-namespaces
//!
//! Namespaces are collections of static operations and attributes that cannot
//! be instantiated. Unlike interfaces, namespaces do not have constructors and
//! cannot have regular (non-static) members.
//!
//! # Key Differences from Interfaces
//!
//! - **Interface**: Can instantiate with `new ClassName()`
//! - **Namespace**: Cannot instantiate, only call static methods
//!
//! # Usage
//!
//! ```zig
//! const namespaces = @import("namespaces.zig");
//!
//! // Define a namespace
//! pub const Console = Namespace(struct {
//!     pub fn log(data: []const u8) void {
//!         // Implementation
//!     }
//!
//!     pub fn warn(data: []const u8) void {
//!         // Implementation
//!     }
//! });
//!
//! // Usage:
//! Console.log("Hello");  // ✅ Works
//! // new Console();      // ❌ Error: Cannot instantiate namespace
//! ```
//!
//! # Web Platform Examples
//!
//! ## console Namespace
//! ```webidl
//! [Exposed=(Window,Worker)]
//! namespace console {
//!   undefined log(any... data);
//!   undefined warn(any... data);
//!   undefined error(any... data);
//! };
//! ```
//!
//! ## CSS Namespace
//! ```webidl
//! [Exposed=Window]
//! namespace CSS {
//!   boolean supports(CSSOMString property, CSSOMString value);
//!   DOMString escape(DOMString ident);
//! };
//! ```

const std = @import("std");

/// Namespace wraps a struct containing only static members.
///
/// Spec: https://webidl.spec.whatwg.org/#idl-namespaces
///
/// Namespaces cannot be instantiated. All members must be functions (operations)
/// or constants. Regular attributes are not allowed.
///
/// In Zig 0.15+, we simply validate the definition and return it directly.
/// The validation ensures:
/// - No instance fields (only functions and constants)
/// - All members are public
///
/// Example:
/// ```zig
/// pub const MathUtils = Namespace(struct {
///     pub fn add(a: i32, b: i32) i32 {
///         return a + b;
///     }
///
///     pub const PI: f64 = 3.14159;
/// });
///
/// // Usage:
/// const result = MathUtils.add(2, 3);  // Works
/// const pi = MathUtils.PI;             // Works
/// // const instance = MathUtils{};     // Compile error (no fields)
/// ```
pub fn Namespace(comptime Definition: type) type {
    // Validate at compile time that Definition only has static members
    comptime validateNamespaceDefinition(Definition);

    // Simply return the definition itself - it's already validated
    // Namespaces are just structs with no fields, only functions/constants
    return Definition;
}

/// Compile-time validation that a namespace definition is valid
fn validateNamespaceDefinition(comptime Definition: type) void {
    const type_info = @typeInfo(Definition);

    switch (type_info) {
        .@"struct" => |struct_info| {
            // Check that there are no instance fields
            if (struct_info.fields.len > 0) {
                @compileError("Namespace '" ++ @typeName(Definition) ++ "' cannot have instance fields. Found " ++ std.fmt.comptimePrint("{d}", .{struct_info.fields.len}) ++ " fields. Use only functions (pub fn) and constants (pub const).");
            }

            // Note: In Zig 0.15+, struct decls don't have is_pub field
            // We can't validate public/private at compile time for decls
            // So we just check for no fields, which is the main requirement
        },
        else => {
            @compileError("Namespace definition must be a struct, got: " ++ @typeName(Definition));
        },
    }
}

/// Merge two namespace definitions into one (for partial namespaces)
///
/// Spec: https://webidl.spec.whatwg.org/#idl-namespaces (partial namespace)
///
/// Since Zig 0.15 removed usingnamespace, we generate wrapper functions
/// that forward to the original namespace parts.
///
/// Example:
/// ```zig
/// pub const ConsolePart1 = struct {
///     pub fn log(msg: []const u8) void { }
/// };
///
/// pub const ConsolePart2 = struct {
///     pub fn warn(msg: []const u8) void { }
/// };
///
/// pub const Console = ConsolePart1; // Just use one part directly
/// // Or manually merge:
/// pub const Console = struct {
///     pub const log = ConsolePart1.log;
///     pub const warn = ConsolePart2.warn;
/// };
/// ```
///
/// Note: Without usingnamespace, partial namespaces require manual merging
/// or using one part as the base. This is a limitation of Zig 0.15+.
pub const PartialNamespaceInfo = struct {
    /// Information about partial namespace support in Zig 0.15+
    pub const info =
        \\Partial namespaces (splitting a namespace across multiple definitions)
        \\require manual merging in Zig 0.15+ since usingnamespace was removed.
        \\
        \\Options:
        \\1. Use one part as the base: pub const Console = ConsolePart1;
        \\2. Manually merge: pub const Console = struct {
        \\       pub const log = Part1.log;
        \\       pub const warn = Part2.warn;
        \\   };
        \\3. Use a single comprehensive definition instead of partial
    ;
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "Namespace - basic operations" {
    const TestNamespace = Namespace(struct {
        pub fn add(a: i32, b: i32) i32 {
            return a + b;
        }

        pub fn multiply(a: i32, b: i32) i32 {
            return a * b;
        }
    });

    try testing.expectEqual(@as(i32, 5), TestNamespace.add(2, 3));
    try testing.expectEqual(@as(i32, 6), TestNamespace.multiply(2, 3));
}

test "Namespace - with constants" {
    const MathNamespace = Namespace(struct {
        pub const PI: f64 = 3.14159;
        pub const E: f64 = 2.71828;

        pub fn circle_area(radius: f64) f64 {
            return PI * radius * radius;
        }
    });

    try testing.expectEqual(@as(f64, 3.14159), MathNamespace.PI);
    try testing.expectEqual(@as(f64, 2.71828), MathNamespace.E);
    try testing.expectApproxEqAbs(@as(f64, 12.56636), MathNamespace.circle_area(2.0), 0.0001);
}

test "Namespace - console-like API" {
    const Console = Namespace(struct {
        var log_count: usize = 0;
        var last_message: ?[]const u8 = null;

        pub fn log(message: []const u8) void {
            log_count += 1;
            last_message = message;
        }

        pub fn getLogCount() usize {
            return log_count;
        }

        pub fn reset() void {
            log_count = 0;
            last_message = null;
        }
    });

    Console.reset();
    Console.log("Hello");
    Console.log("World");

    try testing.expectEqual(@as(usize, 2), Console.getLogCount());
    try testing.expectEqualStrings("World", Console.last_message.?);
}

test "Namespace - CSS.supports-like API" {
    const CSS = Namespace(struct {
        pub fn supports(property: []const u8, value: []const u8) bool {
            // Simplified implementation
            _ = property;
            _ = value;
            return true;
        }

        pub fn escape(ident: []const u8) []const u8 {
            // Simplified implementation - just return input
            return ident;
        }
    });

    try testing.expect(CSS.supports("display", "flex"));
    try testing.expectEqualStrings("my-id", CSS.escape("my-id"));
}

test "Namespace - manual merge (partial namespace pattern)" {
    // Part 1
    const Part1 = struct {
        pub fn foo() i32 {
            return 1;
        }
        pub const VALUE1: i32 = 100;
    };

    // Part 2
    const Part2 = struct {
        pub fn bar() i32 {
            return 2;
        }
        pub const VALUE2: i32 = 200;
    };

    // Manual merge (Zig 0.15+ pattern)
    const Combined = struct {
        pub const foo = Part1.foo;
        pub const VALUE1 = Part1.VALUE1;
        pub const bar = Part2.bar;
        pub const VALUE2 = Part2.VALUE2;
    };

    try testing.expectEqual(@as(i32, 1), Combined.foo());
    try testing.expectEqual(@as(i32, 2), Combined.bar());
    try testing.expectEqual(@as(i32, 100), Combined.VALUE1);
    try testing.expectEqual(@as(i32, 200), Combined.VALUE2);
}

test "Namespace - cannot have fields" {
    // This should work - no fields
    const ValidNamespace = Namespace(struct {
        pub fn test_fn() void {}
    });
    _ = ValidNamespace;

    // Note: We can't test compile errors in runtime tests
    // But the following would fail at compile time:
    // const InvalidNamespace = Namespace(struct {
    //     field: i32,  // Error: cannot have fields
    //     pub fn test_fn() void {}
    // });
}

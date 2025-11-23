//! TypedArray types - JavaScript built-in typed array views
//!
//! Wrappers for V8's TypedArray types. These are views into ArrayBuffer data.

/// Generic TypedArray wrapper
fn TypedArray(comptime T: type) type {
    return struct {
        handle: ?*anyopaque = null,
        length: usize = 0,
        byte_offset: usize = 0,

        const Self = @This();
        pub const ElementType = T;

        pub fn isNull(self: Self) bool {
            return self.handle == null;
        }
    };
}

// Signed integer arrays
pub const Int8Array = TypedArray(i8);
pub const Int16Array = TypedArray(i16);
pub const Int32Array = TypedArray(i32);

// Unsigned integer arrays
pub const Uint8Array = TypedArray(u8);
pub const Uint8ClampedArray = TypedArray(u8); // Clamped to 0-255
pub const Uint16Array = TypedArray(u16);
pub const Uint32Array = TypedArray(u32);

// Floating point arrays
pub const Float32Array = TypedArray(f32);
pub const Float64Array = TypedArray(f64);

// BigInt arrays
pub const BigInt64Array = TypedArray(i64);
pub const BigUint64Array = TypedArray(u64);

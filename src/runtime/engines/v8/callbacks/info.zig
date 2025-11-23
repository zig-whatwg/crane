//! V8 Callback Info Types
//!
//! Information structures passed to V8 callbacks.

const std = @import("std");
const Instance = @import("../../../instance.zig").Instance;
const V8Context = @import("../context.zig").V8Context;

/// Callback information passed from V8
///
/// Mimics v8::FunctionCallbackInfo
/// In real V8 integration, this would be a wrapper around V8's callback info.
pub const CallbackInfo = struct {
    /// V8 context handle (in real V8, this is v8::Local<v8::Context>)
    v8_ctx: *V8Context,

    /// 'this' object handle (in real V8, this is v8::Local<v8::Object>)
    this_handle: ?usize,

    /// Arguments (in real V8, these are v8::Local<v8::Value>)
    args: []const usize,

    /// Return value slot (in real V8, this is v8::ReturnValue<v8::Value>)
    return_value: ?usize,

    /// Get 'this' object
    pub fn getThis(self: CallbackInfo) !*Instance {
        const handle = self.this_handle orelse return error.NoThisObject;
        return try self.v8_ctx.getInstance(handle);
    }

    /// Get argument at index
    pub fn getArg(self: CallbackInfo, index: usize) ?usize {
        if (index >= self.args.len) return null;
        return self.args[index];
    }

    /// Get argument count
    pub fn argCount(self: CallbackInfo) usize {
        return self.args.len;
    }

    /// Set return value
    pub fn setReturnValue(self: *CallbackInfo, value: usize) void {
        self.return_value = value;
    }
};

/// Property callback information
///
/// Mimics v8::PropertyCallbackInfo
pub const PropertyCallbackInfo = struct {
    /// V8 context handle
    v8_ctx: *V8Context,

    /// 'this' object handle
    this_handle: ?usize,

    /// Property name being accessed
    property_name: []const u8,

    /// Return value slot
    return_value: ?usize,

    /// Get 'this' object
    pub fn getThis(self: PropertyCallbackInfo) !*Instance {
        const handle = self.this_handle orelse return error.NoThisObject;
        return try self.v8_ctx.getInstance(handle);
    }

    /// Set return value
    pub fn setReturnValue(self: *PropertyCallbackInfo, value: usize) void {
        self.return_value = value;
    }
};

//! Engine Binding Unit Tests
//!
//! Comprehensive tests for the EngineBinding system including:
//! - EngineBinding VTable operations
//! - Interface registration
//! - Error handling
//! - Memory management
//!
//! NOTE ON anyopaque USAGE:
//! The `*anyopaque` pointers in these tests are LEGITIMATE - they're testing the
//! C ABI boundary of the EngineBinding VTable. The stub binding functions require
//! generic void* (anyopaque) contexts because they're part of the C FFI interface.
//! See docs/legitimate-anyopaque.md for details on FFI boundary patterns.

const std = @import("std");
const testing = std.testing;

const engine_binding = @import("runtime").engine_binding;
const EngineBinding = engine_binding.EngineBinding;
const BindingError = engine_binding.BindingError;
const EngineError = engine_binding.EngineError;
const InterfaceDescriptor = engine_binding.InterfaceDescriptor;
const InterfaceBindingConfig = engine_binding.InterfaceBindingConfig;
const TemplateHandle = engine_binding.TemplateHandle;

// =============================================================================
// Stub Binding Tests
// =============================================================================

test "stub_binding - has correct metadata" {
    const stub = engine_binding.stub_binding;

    try testing.expectEqualStrings("stub", std.mem.span(stub.name));
    try testing.expectEqualStrings("0.0.0", std.mem.span(stub.version));
}

test "stub_binding - registerInterface returns NoEngine" {
    const stub = engine_binding.stub_binding;

    const desc = InterfaceDescriptor{
        .name = "TestInterface",
    };
    const config = InterfaceBindingConfig{};

    // Use @as to avoid type mismatch in undefined pointer
    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);

    try testing.expectError(
        EngineError.NoEngine,
        stub.registerInterface.?(dummy_ctx, &desc, &config),
    );
}

test "stub_binding - registerDictionary returns NoEngine" {
    const stub = engine_binding.stub_binding;
    const binding_types = @import("runtime").binding_types;

    const desc = binding_types.DictionaryDescriptor{
        .name = "TestDict",
    };

    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);

    try testing.expectError(
        EngineError.NoEngine,
        stub.registerDictionary.?(dummy_ctx, &desc),
    );
}

test "stub_binding - registerEnum returns NoEngine" {
    const stub = engine_binding.stub_binding;
    const binding_types = @import("runtime").binding_types;

    const values = [_][*:0]const u8{ "value1", "value2" };
    const desc = binding_types.EnumDescriptor{
        .name = "TestEnum",
        .values = &values,
        .values_len = 2,
    };

    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);

    try testing.expectError(
        EngineError.NoEngine,
        stub.registerEnum.?(dummy_ctx, &desc),
    );
}

test "stub_binding - getInterfaceTemplate returns null" {
    const stub = engine_binding.stub_binding;

    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);

    const result = stub.getInterfaceTemplate.?(dummy_ctx, "NonExistent");
    try testing.expectEqual(@as(?TemplateHandle, null), result);
}

test "stub_binding - createInstance returns NoEngine" {
    const stub = engine_binding.stub_binding;

    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);
    const dummy_template: TemplateHandle = @ptrCast(&dummy);
    var zig_instance: u8 = 0;

    try testing.expectError(
        EngineError.NoEngine,
        stub.createInstance.?(dummy_ctx, dummy_template, @ptrCast(&zig_instance)),
    );
}

test "stub_binding - setPrototype returns PrototypeSetupFailed" {
    const stub = engine_binding.stub_binding;

    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);
    const child_template: TemplateHandle = @ptrCast(&dummy);
    const parent_template: TemplateHandle = @ptrCast(&dummy);

    try testing.expectError(
        BindingError.PrototypeSetupFailed,
        stub.setPrototype.?(dummy_ctx, child_template, parent_template),
    );
}

test "stub_binding - includeMixin returns MixinNotFound" {
    const stub = engine_binding.stub_binding;

    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);
    const interface_template: TemplateHandle = @ptrCast(&dummy);
    const mixin_template: TemplateHandle = @ptrCast(&dummy);

    try testing.expectError(
        BindingError.MixinNotFound,
        stub.includeMixin.?(dummy_ctx, interface_template, mixin_template),
    );
}

test "stub_binding - exposeOnGlobal returns NoEngine" {
    const stub = engine_binding.stub_binding;

    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);
    const template: TemplateHandle = @ptrCast(&dummy);

    try testing.expectError(
        EngineError.NoEngine,
        stub.exposeOnGlobal.?(dummy_ctx, template, "GlobalName"),
    );
}

test "stub_binding - isInstanceOf returns false" {
    const stub = engine_binding.stub_binding;

    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);

    const result = stub.isInstanceOf.?(dummy_ctx, @ptrCast(&dummy), "SomeInterface");
    try testing.expect(!result);
}

test "stub_binding - unwrapInstance returns null" {
    const stub = engine_binding.stub_binding;

    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);

    const result = stub.unwrapInstance.?(dummy_ctx, @ptrCast(&dummy));
    try testing.expectEqual(@as(?*anyopaque, null), result);
}

test "stub_binding - isSerializable returns false" {
    const stub = engine_binding.stub_binding;

    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);

    try testing.expect(!stub.isSerializable.?(dummy_ctx, @ptrCast(&dummy)));
}

test "stub_binding - isTransferable returns false" {
    const stub = engine_binding.stub_binding;

    var dummy: u8 = 0;
    const dummy_ctx: *anyopaque = @ptrCast(&dummy);

    try testing.expect(!stub.isTransferable.?(dummy_ctx, @ptrCast(&dummy)));
}

test "stub_binding - base engine interface is accessible" {
    const stub = engine_binding.stub_binding;

    // Verify base EngineInterface is linked
    try testing.expectEqualStrings("stub", stub.base.name);
    try testing.expectEqualStrings("0.0.0", stub.base.version);
}

// =============================================================================
// InterfaceBindingConfig Tests
// =============================================================================

test "InterfaceBindingConfig - default values" {
    const config = InterfaceBindingConfig{};

    try testing.expectEqual(@as(?engine_binding.NativeConstructorFn, null), config.constructor);
    try testing.expectEqual(@as(u32, 0), config.methods_len);
    try testing.expectEqual(@as(u32, 0), config.getters_len);
    try testing.expectEqual(@as(u32, 0), config.setters_len);
    try testing.expectEqual(@as(?engine_binding.NativeIndexedGetterFn, null), config.indexed_getter);
    try testing.expectEqual(@as(?engine_binding.NativeIndexedSetterFn, null), config.indexed_setter);
    try testing.expectEqual(@as(?engine_binding.NativeNamedGetterFn, null), config.named_getter);
    try testing.expectEqual(@as(?engine_binding.NativeNamedSetterFn, null), config.named_setter);
    try testing.expectEqual(@as(?engine_binding.DestructorFn, null), config.destructor);
    try testing.expectEqual(@as(?*anyopaque, null), config.user_data);
}

test "InterfaceBindingConfig - is extern struct" {
    const info = @typeInfo(InterfaceBindingConfig);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

// =============================================================================
// Struct Layout Tests (for C ABI compatibility)
// =============================================================================

test "EngineBinding - is extern struct" {
    const info = @typeInfo(EngineBinding);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

test "InterfaceDescriptor - is extern struct" {
    const info = @typeInfo(InterfaceDescriptor);
    try testing.expect(info == .@"struct");
    try testing.expect(info.@"struct".layout == .@"extern");
}

// =============================================================================
// Error Type Tests
// =============================================================================

test "BindingError - all error variants exist" {
    // Just verify the error set compiles and has expected variants
    const errors: []const BindingError = &.{
        BindingError.AlreadyRegistered,
        BindingError.ParentNotFound,
        BindingError.MixinNotFound,
        BindingError.InvalidDescriptor,
        BindingError.ConstructorFailed,
        BindingError.MethodBindingFailed,
        BindingError.PropertyBindingFailed,
        BindingError.PrototypeSetupFailed,
        BindingError.TemplateCreationFailed,
        BindingError.OutOfMemory,
    };

    try testing.expectEqual(@as(usize, 10), errors.len);
}

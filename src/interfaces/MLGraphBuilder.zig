//! Generated from: webnn.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MLGraphBuilderImpl = @import("../impls/MLGraphBuilder.zig");

pub const MLGraphBuilder = struct {
    pub const Meta = struct {
        pub const name = "MLGraphBuilder";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MLGraphBuilder, .{
        .deinit_fn = &deinit_wrapper,

        .call_abs = &call_abs,
        .call_add = &call_add,
        .call_argMax = &call_argMax,
        .call_argMin = &call_argMin,
        .call_averagePool2d = &call_averagePool2d,
        .call_batchNormalization = &call_batchNormalization,
        .call_build = &call_build,
        .call_cast = &call_cast,
        .call_ceil = &call_ceil,
        .call_clamp = &call_clamp,
        .call_concat = &call_concat,
        .call_constant = &call_constant,
        .call_constant = &call_constant,
        .call_constant = &call_constant,
        .call_conv2d = &call_conv2d,
        .call_convTranspose2d = &call_convTranspose2d,
        .call_cos = &call_cos,
        .call_cumulativeSum = &call_cumulativeSum,
        .call_dequantizeLinear = &call_dequantizeLinear,
        .call_div = &call_div,
        .call_elu = &call_elu,
        .call_equal = &call_equal,
        .call_erf = &call_erf,
        .call_exp = &call_exp,
        .call_expand = &call_expand,
        .call_floor = &call_floor,
        .call_gather = &call_gather,
        .call_gatherElements = &call_gatherElements,
        .call_gatherND = &call_gatherND,
        .call_gelu = &call_gelu,
        .call_gemm = &call_gemm,
        .call_greater = &call_greater,
        .call_greaterOrEqual = &call_greaterOrEqual,
        .call_gru = &call_gru,
        .call_gruCell = &call_gruCell,
        .call_hardSigmoid = &call_hardSigmoid,
        .call_hardSwish = &call_hardSwish,
        .call_identity = &call_identity,
        .call_input = &call_input,
        .call_instanceNormalization = &call_instanceNormalization,
        .call_isInfinite = &call_isInfinite,
        .call_isNaN = &call_isNaN,
        .call_l2Pool2d = &call_l2Pool2d,
        .call_layerNormalization = &call_layerNormalization,
        .call_leakyRelu = &call_leakyRelu,
        .call_lesser = &call_lesser,
        .call_lesserOrEqual = &call_lesserOrEqual,
        .call_linear = &call_linear,
        .call_log = &call_log,
        .call_logicalAnd = &call_logicalAnd,
        .call_logicalNot = &call_logicalNot,
        .call_logicalOr = &call_logicalOr,
        .call_logicalXor = &call_logicalXor,
        .call_lstm = &call_lstm,
        .call_lstmCell = &call_lstmCell,
        .call_matmul = &call_matmul,
        .call_max = &call_max,
        .call_maxPool2d = &call_maxPool2d,
        .call_min = &call_min,
        .call_mul = &call_mul,
        .call_neg = &call_neg,
        .call_notEqual = &call_notEqual,
        .call_pad = &call_pad,
        .call_pow = &call_pow,
        .call_prelu = &call_prelu,
        .call_quantizeLinear = &call_quantizeLinear,
        .call_reciprocal = &call_reciprocal,
        .call_reduceL1 = &call_reduceL1,
        .call_reduceL2 = &call_reduceL2,
        .call_reduceLogSum = &call_reduceLogSum,
        .call_reduceLogSumExp = &call_reduceLogSumExp,
        .call_reduceMax = &call_reduceMax,
        .call_reduceMean = &call_reduceMean,
        .call_reduceMin = &call_reduceMin,
        .call_reduceProduct = &call_reduceProduct,
        .call_reduceSum = &call_reduceSum,
        .call_reduceSumSquare = &call_reduceSumSquare,
        .call_relu = &call_relu,
        .call_resample2d = &call_resample2d,
        .call_reshape = &call_reshape,
        .call_reverse = &call_reverse,
        .call_roundEven = &call_roundEven,
        .call_scatterElements = &call_scatterElements,
        .call_scatterND = &call_scatterND,
        .call_sigmoid = &call_sigmoid,
        .call_sign = &call_sign,
        .call_sin = &call_sin,
        .call_slice = &call_slice,
        .call_softmax = &call_softmax,
        .call_softplus = &call_softplus,
        .call_softsign = &call_softsign,
        .call_split = &call_split,
        .call_sqrt = &call_sqrt,
        .call_sub = &call_sub,
        .call_tan = &call_tan,
        .call_tanh = &call_tanh,
        .call_tile = &call_tile,
        .call_transpose = &call_transpose,
        .call_triangular = &call_triangular,
        .call_where = &call_where,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MLGraphBuilderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MLGraphBuilderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, context: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try MLGraphBuilderImpl.constructor(state, context);
        
        return instance;
    }

    pub fn call_reduceL2(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reduceL2(state, input, options);
    }

    pub fn call_reverse(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reverse(state, input, options);
    }

    pub fn call_lesserOrEqual(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_lesserOrEqual(state, a, b, options);
    }

    pub fn call_reduceSumSquare(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reduceSumSquare(state, input, options);
    }

    pub fn call_instanceNormalization(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_instanceNormalization(state, input, options);
    }

    pub fn call_ceil(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_ceil(state, input, options);
    }

    pub fn call_greater(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_greater(state, a, b, options);
    }

    pub fn call_exp(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_exp(state, input, options);
    }

    pub fn call_reduceLogSum(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reduceLogSum(state, input, options);
    }

    pub fn call_gatherElements(instance: *runtime.Instance, input: anyopaque, indices: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_gatherElements(state, input, indices, options);
    }

    pub fn call_convTranspose2d(instance: *runtime.Instance, input: anyopaque, filter: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_convTranspose2d(state, input, filter, options);
    }

    pub fn call_relu(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_relu(state, input, options);
    }

    pub fn call_where(instance: *runtime.Instance, condition: anyopaque, trueValue: anyopaque, falseValue: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_where(state, condition, trueValue, falseValue, options);
    }

    pub fn call_build(instance: *runtime.Instance, outputs: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_build(state, outputs);
    }

    pub fn call_sub(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_sub(state, a, b, options);
    }

    pub fn call_isInfinite(instance: *runtime.Instance, a: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_isInfinite(state, a, options);
    }

    pub fn call_reduceLogSumExp(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reduceLogSumExp(state, input, options);
    }

    pub fn call_transpose(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_transpose(state, input, options);
    }

    pub fn call_gru(instance: *runtime.Instance, input: anyopaque, weight: anyopaque, recurrentWeight: anyopaque, steps: u32, hiddenSize: u32, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on steps
        if (steps > std.math.maxInt(u53)) return error.TypeError;
        // [EnforceRange] on hiddenSize
        if (hiddenSize > std.math.maxInt(u53)) return error.TypeError;
        
        return MLGraphBuilderImpl.call_gru(state, input, weight, recurrentWeight, steps, hiddenSize, options);
    }

    pub fn call_conv2d(instance: *runtime.Instance, input: anyopaque, filter: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_conv2d(state, input, filter, options);
    }

    pub fn call_cos(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_cos(state, input, options);
    }

    pub fn call_quantizeLinear(instance: *runtime.Instance, input: anyopaque, scale: anyopaque, zeroPoint: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_quantizeLinear(state, input, scale, zeroPoint, options);
    }

    pub fn call_elu(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_elu(state, input, options);
    }

    pub fn call_gather(instance: *runtime.Instance, input: anyopaque, indices: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_gather(state, input, indices, options);
    }

    pub fn call_greaterOrEqual(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_greaterOrEqual(state, a, b, options);
    }

    pub fn call_gatherND(instance: *runtime.Instance, input: anyopaque, indices: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_gatherND(state, input, indices, options);
    }

    pub fn call_l2Pool2d(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_l2Pool2d(state, input, options);
    }

    pub fn call_erf(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_erf(state, input, options);
    }

    pub fn call_add(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_add(state, a, b, options);
    }

    pub fn call_layerNormalization(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_layerNormalization(state, input, options);
    }

    pub fn call_pad(instance: *runtime.Instance, input: anyopaque, beginningPadding: anyopaque, endingPadding: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_pad(state, input, beginningPadding, endingPadding, options);
    }

    pub fn call_notEqual(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_notEqual(state, a, b, options);
    }

    pub fn call_log(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_log(state, input, options);
    }

    pub fn call_dequantizeLinear(instance: *runtime.Instance, input: anyopaque, scale: anyopaque, zeroPoint: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_dequantizeLinear(state, input, scale, zeroPoint, options);
    }

    pub fn call_maxPool2d(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_maxPool2d(state, input, options);
    }

    pub fn call_reduceL1(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reduceL1(state, input, options);
    }

    pub fn call_floor(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_floor(state, input, options);
    }

    pub fn call_linear(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_linear(state, input, options);
    }

    pub fn call_reduceMax(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reduceMax(state, input, options);
    }

    pub fn call_resample2d(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_resample2d(state, input, options);
    }

    pub fn call_softmax(instance: *runtime.Instance, input: anyopaque, axis: u32, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on axis
        if (axis > std.math.maxInt(u53)) return error.TypeError;
        
        return MLGraphBuilderImpl.call_softmax(state, input, axis, options);
    }

    pub fn call_min(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_min(state, a, b, options);
    }

    pub fn call_lesser(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_lesser(state, a, b, options);
    }

    pub fn call_isNaN(instance: *runtime.Instance, a: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_isNaN(state, a, options);
    }

    pub fn call_gemm(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_gemm(state, a, b, options);
    }

    pub fn call_cast(instance: *runtime.Instance, input: anyopaque, dataType: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_cast(state, input, dataType, options);
    }

    pub fn call_hardSwish(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_hardSwish(state, input, options);
    }

    pub fn call_reduceSum(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reduceSum(state, input, options);
    }

    pub fn call_roundEven(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_roundEven(state, input, options);
    }

    pub fn call_sqrt(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_sqrt(state, input, options);
    }

    pub fn call_averagePool2d(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_averagePool2d(state, input, options);
    }

    pub fn call_equal(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_equal(state, a, b, options);
    }

    pub fn call_slice(instance: *runtime.Instance, input: anyopaque, starts: anyopaque, sizes: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_slice(state, input, starts, sizes, options);
    }

    pub fn call_logicalNot(instance: *runtime.Instance, a: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_logicalNot(state, a, options);
    }

    pub fn call_mul(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_mul(state, a, b, options);
    }

    pub fn call_sin(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_sin(state, input, options);
    }

    /// Arguments for constant (WebIDL overloading)
    pub const ConstantArgs = union(enum) {
        /// constant(descriptor, buffer)
        MLOperandDescriptor_AllowSharedBufferSource: struct {
            descriptor: anyopaque,
            buffer: anyopaque,
        },
        /// constant(dataType, value)
        MLOperandDataType_MLNumber: struct {
            dataType: anyopaque,
            value: anyopaque,
        },
        /// constant(tensor)
        MLTensor: anyopaque,
    };

    pub fn call_constant(instance: *runtime.Instance, args: ConstantArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .MLOperandDescriptor_AllowSharedBufferSource => |a| return MLGraphBuilderImpl.MLOperandDescriptor_AllowSharedBufferSource(state, a.descriptor, a.buffer),
            .MLOperandDataType_MLNumber => |a| return MLGraphBuilderImpl.MLOperandDataType_MLNumber(state, a.dataType, a.value),
            .MLTensor => |arg| return MLGraphBuilderImpl.MLTensor(state, arg),
        }
    }

    pub fn call_gruCell(instance: *runtime.Instance, input: anyopaque, weight: anyopaque, recurrentWeight: anyopaque, hiddenState: anyopaque, hiddenSize: u32, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on hiddenSize
        if (hiddenSize > std.math.maxInt(u53)) return error.TypeError;
        
        return MLGraphBuilderImpl.call_gruCell(state, input, weight, recurrentWeight, hiddenState, hiddenSize, options);
    }

    pub fn call_split(instance: *runtime.Instance, input: anyopaque, splits: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_split(state, input, splits, options);
    }

    pub fn call_tanh(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_tanh(state, input, options);
    }

    pub fn call_reshape(instance: *runtime.Instance, input: anyopaque, newShape: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reshape(state, input, newShape, options);
    }

    pub fn call_hardSigmoid(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_hardSigmoid(state, input, options);
    }

    pub fn call_reciprocal(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reciprocal(state, input, options);
    }

    pub fn call_expand(instance: *runtime.Instance, input: anyopaque, newShape: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_expand(state, input, newShape, options);
    }

    pub fn call_identity(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_identity(state, input, options);
    }

    pub fn call_leakyRelu(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_leakyRelu(state, input, options);
    }

    pub fn call_clamp(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_clamp(state, input, options);
    }

    pub fn call_lstmCell(instance: *runtime.Instance, input: anyopaque, weight: anyopaque, recurrentWeight: anyopaque, hiddenState: anyopaque, cellState: anyopaque, hiddenSize: u32, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on hiddenSize
        if (hiddenSize > std.math.maxInt(u53)) return error.TypeError;
        
        return MLGraphBuilderImpl.call_lstmCell(state, input, weight, recurrentWeight, hiddenState, cellState, hiddenSize, options);
    }

    pub fn call_prelu(instance: *runtime.Instance, input: anyopaque, slope: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_prelu(state, input, slope, options);
    }

    pub fn call_logicalXor(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_logicalXor(state, a, b, options);
    }

    pub fn call_scatterElements(instance: *runtime.Instance, input: anyopaque, indices: anyopaque, updates: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_scatterElements(state, input, indices, updates, options);
    }

    pub fn call_abs(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_abs(state, input, options);
    }

    pub fn call_input(instance: *runtime.Instance, name: runtime.USVString, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_input(state, name, descriptor);
    }

    pub fn call_tan(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_tan(state, input, options);
    }

    pub fn call_logicalAnd(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_logicalAnd(state, a, b, options);
    }

    pub fn call_softsign(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_softsign(state, input, options);
    }

    pub fn call_triangular(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_triangular(state, input, options);
    }

    pub fn call_max(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_max(state, a, b, options);
    }

    pub fn call_sign(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_sign(state, input, options);
    }

    pub fn call_logicalOr(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_logicalOr(state, a, b, options);
    }

    pub fn call_neg(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_neg(state, input, options);
    }

    pub fn call_lstm(instance: *runtime.Instance, input: anyopaque, weight: anyopaque, recurrentWeight: anyopaque, steps: u32, hiddenSize: u32, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on steps
        if (steps > std.math.maxInt(u53)) return error.TypeError;
        // [EnforceRange] on hiddenSize
        if (hiddenSize > std.math.maxInt(u53)) return error.TypeError;
        
        return MLGraphBuilderImpl.call_lstm(state, input, weight, recurrentWeight, steps, hiddenSize, options);
    }

    pub fn call_concat(instance: *runtime.Instance, inputs: anyopaque, axis: u32, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on axis
        if (axis > std.math.maxInt(u53)) return error.TypeError;
        
        return MLGraphBuilderImpl.call_concat(state, inputs, axis, options);
    }

    pub fn call_pow(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_pow(state, a, b, options);
    }

    pub fn call_argMax(instance: *runtime.Instance, input: anyopaque, axis: u32, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on axis
        if (axis > std.math.maxInt(u53)) return error.TypeError;
        
        return MLGraphBuilderImpl.call_argMax(state, input, axis, options);
    }

    pub fn call_reduceMean(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reduceMean(state, input, options);
    }

    pub fn call_softplus(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_softplus(state, input, options);
    }

    pub fn call_gelu(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_gelu(state, input, options);
    }

    pub fn call_reduceMin(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reduceMin(state, input, options);
    }

    pub fn call_argMin(instance: *runtime.Instance, input: anyopaque, axis: u32, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on axis
        if (axis > std.math.maxInt(u53)) return error.TypeError;
        
        return MLGraphBuilderImpl.call_argMin(state, input, axis, options);
    }

    pub fn call_batchNormalization(instance: *runtime.Instance, input: anyopaque, mean: anyopaque, variance: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_batchNormalization(state, input, mean, variance, options);
    }

    pub fn call_cumulativeSum(instance: *runtime.Instance, input: anyopaque, axis: u32, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_cumulativeSum(state, input, axis, options);
    }

    pub fn call_matmul(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_matmul(state, a, b, options);
    }

    pub fn call_scatterND(instance: *runtime.Instance, input: anyopaque, indices: anyopaque, updates: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_scatterND(state, input, indices, updates, options);
    }

    pub fn call_reduceProduct(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_reduceProduct(state, input, options);
    }

    pub fn call_sigmoid(instance: *runtime.Instance, input: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_sigmoid(state, input, options);
    }

    pub fn call_tile(instance: *runtime.Instance, input: anyopaque, repetitions: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_tile(state, input, repetitions, options);
    }

    pub fn call_div(instance: *runtime.Instance, a: anyopaque, b: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLGraphBuilderImpl.call_div(state, a, b, options);
    }

};

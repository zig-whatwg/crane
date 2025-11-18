//! Generated from: webnn.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MLGraphBuilderImpl = @import("impls").MLGraphBuilder;
const MLTensor = @import("interfaces").MLTensor;
const MLLinearOptions = @import("dictionaries").MLLinearOptions;
const MLCumulativeSumOptions = @import("dictionaries").MLCumulativeSumOptions;
const MLLeakyReluOptions = @import("dictionaries").MLLeakyReluOptions;
const MLNamedOperands = @import("typedefs").MLNamedOperands;
const MLBatchNormalizationOptions = @import("dictionaries").MLBatchNormalizationOptions;
const MLResample2dOptions = @import("dictionaries").MLResample2dOptions;
const MLOperatorOptions = @import("dictionaries").MLOperatorOptions;
const MLGruOptions = @import("dictionaries").MLGruOptions;
const (unsigned long or sequence) = @import("interfaces").(unsigned long or sequence);
const MLTriangularOptions = @import("dictionaries").MLTriangularOptions;
const MLOperandDescriptor = @import("dictionaries").MLOperandDescriptor;
const MLSliceOptions = @import("dictionaries").MLSliceOptions;
const MLNumber = @import("typedefs").MLNumber;
const MLPadOptions = @import("dictionaries").MLPadOptions;
const MLInstanceNormalizationOptions = @import("dictionaries").MLInstanceNormalizationOptions;
const MLOperand = @import("interfaces").MLOperand;
const MLContext = @import("interfaces").MLContext;
const MLOperandDataType = @import("enums").MLOperandDataType;
const MLScatterOptions = @import("dictionaries").MLScatterOptions;
const MLClampOptions = @import("dictionaries").MLClampOptions;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const MLEluOptions = @import("dictionaries").MLEluOptions;
const MLConv2dOptions = @import("dictionaries").MLConv2dOptions;
const MLHardSigmoidOptions = @import("dictionaries").MLHardSigmoidOptions;
const MLGatherOptions = @import("dictionaries").MLGatherOptions;
const MLArgMinMaxOptions = @import("dictionaries").MLArgMinMaxOptions;
const MLReverseOptions = @import("dictionaries").MLReverseOptions;
const Promise<MLGraph> = @import("interfaces").Promise<MLGraph>;
const MLSplitOptions = @import("dictionaries").MLSplitOptions;
const MLLstmCellOptions = @import("dictionaries").MLLstmCellOptions;
const MLGemmOptions = @import("dictionaries").MLGemmOptions;
const MLConvTranspose2dOptions = @import("dictionaries").MLConvTranspose2dOptions;
const MLLayerNormalizationOptions = @import("dictionaries").MLLayerNormalizationOptions;
const MLLstmOptions = @import("dictionaries").MLLstmOptions;
const MLPool2dOptions = @import("dictionaries").MLPool2dOptions;
const MLGruCellOptions = @import("dictionaries").MLGruCellOptions;
const MLReduceOptions = @import("dictionaries").MLReduceOptions;
const MLTransposeOptions = @import("dictionaries").MLTransposeOptions;

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
        
        // Initialize the instance (Impl receives full instance)
        MLGraphBuilderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MLGraphBuilderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, context: MLContext) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try MLGraphBuilderImpl.constructor(instance, context);
        
        return instance;
    }

    pub fn call_reduceL2(instance: *runtime.Instance, input: MLOperand, options: MLReduceOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reduceL2(instance, input, options);
    }

    pub fn call_reverse(instance: *runtime.Instance, input: MLOperand, options: MLReverseOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reverse(instance, input, options);
    }

    pub fn call_lesserOrEqual(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_lesserOrEqual(instance, a, b, options);
    }

    pub fn call_reduceSumSquare(instance: *runtime.Instance, input: MLOperand, options: MLReduceOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reduceSumSquare(instance, input, options);
    }

    pub fn call_instanceNormalization(instance: *runtime.Instance, input: MLOperand, options: MLInstanceNormalizationOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_instanceNormalization(instance, input, options);
    }

    pub fn call_ceil(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_ceil(instance, input, options);
    }

    pub fn call_greater(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_greater(instance, a, b, options);
    }

    pub fn call_exp(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_exp(instance, input, options);
    }

    pub fn call_reduceLogSum(instance: *runtime.Instance, input: MLOperand, options: MLReduceOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reduceLogSum(instance, input, options);
    }

    pub fn call_gatherElements(instance: *runtime.Instance, input: MLOperand, indices: MLOperand, options: MLGatherOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_gatherElements(instance, input, indices, options);
    }

    pub fn call_convTranspose2d(instance: *runtime.Instance, input: MLOperand, filter: MLOperand, options: MLConvTranspose2dOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_convTranspose2d(instance, input, filter, options);
    }

    pub fn call_relu(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_relu(instance, input, options);
    }

    pub fn call_where(instance: *runtime.Instance, condition: MLOperand, trueValue: MLOperand, falseValue: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_where(instance, condition, trueValue, falseValue, options);
    }

    pub fn call_build(instance: *runtime.Instance, outputs: MLNamedOperands) anyerror!anyopaque {
        
        return try MLGraphBuilderImpl.call_build(instance, outputs);
    }

    pub fn call_sub(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_sub(instance, a, b, options);
    }

    pub fn call_isInfinite(instance: *runtime.Instance, a: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_isInfinite(instance, a, options);
    }

    pub fn call_reduceLogSumExp(instance: *runtime.Instance, input: MLOperand, options: MLReduceOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reduceLogSumExp(instance, input, options);
    }

    pub fn call_transpose(instance: *runtime.Instance, input: MLOperand, options: MLTransposeOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_transpose(instance, input, options);
    }

    pub fn call_gru(instance: *runtime.Instance, input: MLOperand, weight: MLOperand, recurrentWeight: MLOperand, steps: u32, hiddenSize: u32, options: MLGruOptions) anyerror!anyopaque {
        // [EnforceRange] on steps
        if (!runtime.isInRange(steps)) return error.TypeError;
        // [EnforceRange] on hiddenSize
        if (!runtime.isInRange(hiddenSize)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_gru(instance, input, weight, recurrentWeight, steps, hiddenSize, options);
    }

    pub fn call_conv2d(instance: *runtime.Instance, input: MLOperand, filter: MLOperand, options: MLConv2dOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_conv2d(instance, input, filter, options);
    }

    pub fn call_cos(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_cos(instance, input, options);
    }

    pub fn call_quantizeLinear(instance: *runtime.Instance, input: MLOperand, scale: MLOperand, zeroPoint: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_quantizeLinear(instance, input, scale, zeroPoint, options);
    }

    pub fn call_elu(instance: *runtime.Instance, input: MLOperand, options: MLEluOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_elu(instance, input, options);
    }

    pub fn call_gather(instance: *runtime.Instance, input: MLOperand, indices: MLOperand, options: MLGatherOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_gather(instance, input, indices, options);
    }

    pub fn call_greaterOrEqual(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_greaterOrEqual(instance, a, b, options);
    }

    pub fn call_gatherND(instance: *runtime.Instance, input: MLOperand, indices: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_gatherND(instance, input, indices, options);
    }

    pub fn call_l2Pool2d(instance: *runtime.Instance, input: MLOperand, options: MLPool2dOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_l2Pool2d(instance, input, options);
    }

    pub fn call_erf(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_erf(instance, input, options);
    }

    pub fn call_add(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_add(instance, a, b, options);
    }

    pub fn call_layerNormalization(instance: *runtime.Instance, input: MLOperand, options: MLLayerNormalizationOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_layerNormalization(instance, input, options);
    }

    pub fn call_pad(instance: *runtime.Instance, input: MLOperand, beginningPadding: anyopaque, endingPadding: anyopaque, options: MLPadOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_pad(instance, input, beginningPadding, endingPadding, options);
    }

    pub fn call_notEqual(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_notEqual(instance, a, b, options);
    }

    pub fn call_log(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_log(instance, input, options);
    }

    pub fn call_dequantizeLinear(instance: *runtime.Instance, input: MLOperand, scale: MLOperand, zeroPoint: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_dequantizeLinear(instance, input, scale, zeroPoint, options);
    }

    pub fn call_maxPool2d(instance: *runtime.Instance, input: MLOperand, options: MLPool2dOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_maxPool2d(instance, input, options);
    }

    pub fn call_reduceL1(instance: *runtime.Instance, input: MLOperand, options: MLReduceOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reduceL1(instance, input, options);
    }

    pub fn call_floor(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_floor(instance, input, options);
    }

    pub fn call_linear(instance: *runtime.Instance, input: MLOperand, options: MLLinearOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_linear(instance, input, options);
    }

    pub fn call_reduceMax(instance: *runtime.Instance, input: MLOperand, options: MLReduceOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reduceMax(instance, input, options);
    }

    pub fn call_resample2d(instance: *runtime.Instance, input: MLOperand, options: MLResample2dOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_resample2d(instance, input, options);
    }

    pub fn call_softmax(instance: *runtime.Instance, input: MLOperand, axis: u32, options: MLOperatorOptions) anyerror!MLOperand {
        // [EnforceRange] on axis
        if (!runtime.isInRange(axis)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_softmax(instance, input, axis, options);
    }

    pub fn call_min(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_min(instance, a, b, options);
    }

    pub fn call_lesser(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_lesser(instance, a, b, options);
    }

    pub fn call_isNaN(instance: *runtime.Instance, a: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_isNaN(instance, a, options);
    }

    pub fn call_gemm(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLGemmOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_gemm(instance, a, b, options);
    }

    pub fn call_cast(instance: *runtime.Instance, input: MLOperand, dataType: MLOperandDataType, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_cast(instance, input, dataType, options);
    }

    pub fn call_hardSwish(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_hardSwish(instance, input, options);
    }

    pub fn call_reduceSum(instance: *runtime.Instance, input: MLOperand, options: MLReduceOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reduceSum(instance, input, options);
    }

    pub fn call_roundEven(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_roundEven(instance, input, options);
    }

    pub fn call_sqrt(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_sqrt(instance, input, options);
    }

    pub fn call_averagePool2d(instance: *runtime.Instance, input: MLOperand, options: MLPool2dOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_averagePool2d(instance, input, options);
    }

    pub fn call_equal(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_equal(instance, a, b, options);
    }

    pub fn call_slice(instance: *runtime.Instance, input: MLOperand, starts: anyopaque, sizes: anyopaque, options: MLSliceOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_slice(instance, input, starts, sizes, options);
    }

    pub fn call_logicalNot(instance: *runtime.Instance, a: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_logicalNot(instance, a, options);
    }

    pub fn call_mul(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_mul(instance, a, b, options);
    }

    pub fn call_sin(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_sin(instance, input, options);
    }

    /// Arguments for constant (WebIDL overloading)
    pub const ConstantArgs = union(enum) {
        /// constant(descriptor, buffer)
        MLOperandDescriptor_AllowSharedBufferSource: struct {
            descriptor: MLOperandDescriptor,
            buffer: AllowSharedBufferSource,
        },
        /// constant(dataType, value)
        MLOperandDataType_MLNumber: struct {
            dataType: MLOperandDataType,
            value: MLNumber,
        },
        /// constant(tensor)
        MLTensor: MLTensor,
    };

    pub fn call_constant(instance: *runtime.Instance, args: ConstantArgs) anyerror!MLOperand {
        switch (args) {
            .MLOperandDescriptor_AllowSharedBufferSource => |a| return try MLGraphBuilderImpl.MLOperandDescriptor_AllowSharedBufferSource(instance, a.descriptor, a.buffer),
            .MLOperandDataType_MLNumber => |a| return try MLGraphBuilderImpl.MLOperandDataType_MLNumber(instance, a.dataType, a.value),
            .MLTensor => |arg| return try MLGraphBuilderImpl.MLTensor(instance, arg),
        }
    }

    pub fn call_gruCell(instance: *runtime.Instance, input: MLOperand, weight: MLOperand, recurrentWeight: MLOperand, hiddenState: MLOperand, hiddenSize: u32, options: MLGruCellOptions) anyerror!MLOperand {
        // [EnforceRange] on hiddenSize
        if (!runtime.isInRange(hiddenSize)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_gruCell(instance, input, weight, recurrentWeight, hiddenState, hiddenSize, options);
    }

    pub fn call_split(instance: *runtime.Instance, input: MLOperand, splits: anyopaque, options: MLSplitOptions) anyerror!anyopaque {
        
        return try MLGraphBuilderImpl.call_split(instance, input, splits, options);
    }

    pub fn call_tanh(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_tanh(instance, input, options);
    }

    pub fn call_reshape(instance: *runtime.Instance, input: MLOperand, newShape: anyopaque, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reshape(instance, input, newShape, options);
    }

    pub fn call_hardSigmoid(instance: *runtime.Instance, input: MLOperand, options: MLHardSigmoidOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_hardSigmoid(instance, input, options);
    }

    pub fn call_reciprocal(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reciprocal(instance, input, options);
    }

    pub fn call_expand(instance: *runtime.Instance, input: MLOperand, newShape: anyopaque, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_expand(instance, input, newShape, options);
    }

    pub fn call_identity(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_identity(instance, input, options);
    }

    pub fn call_leakyRelu(instance: *runtime.Instance, input: MLOperand, options: MLLeakyReluOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_leakyRelu(instance, input, options);
    }

    pub fn call_clamp(instance: *runtime.Instance, input: MLOperand, options: MLClampOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_clamp(instance, input, options);
    }

    pub fn call_lstmCell(instance: *runtime.Instance, input: MLOperand, weight: MLOperand, recurrentWeight: MLOperand, hiddenState: MLOperand, cellState: MLOperand, hiddenSize: u32, options: MLLstmCellOptions) anyerror!anyopaque {
        // [EnforceRange] on hiddenSize
        if (!runtime.isInRange(hiddenSize)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_lstmCell(instance, input, weight, recurrentWeight, hiddenState, cellState, hiddenSize, options);
    }

    pub fn call_prelu(instance: *runtime.Instance, input: MLOperand, slope: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_prelu(instance, input, slope, options);
    }

    pub fn call_logicalXor(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_logicalXor(instance, a, b, options);
    }

    pub fn call_scatterElements(instance: *runtime.Instance, input: MLOperand, indices: MLOperand, updates: MLOperand, options: MLScatterOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_scatterElements(instance, input, indices, updates, options);
    }

    pub fn call_abs(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_abs(instance, input, options);
    }

    pub fn call_input(instance: *runtime.Instance, name: runtime.USVString, descriptor: MLOperandDescriptor) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_input(instance, name, descriptor);
    }

    pub fn call_tan(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_tan(instance, input, options);
    }

    pub fn call_logicalAnd(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_logicalAnd(instance, a, b, options);
    }

    pub fn call_softsign(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_softsign(instance, input, options);
    }

    pub fn call_triangular(instance: *runtime.Instance, input: MLOperand, options: MLTriangularOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_triangular(instance, input, options);
    }

    pub fn call_max(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_max(instance, a, b, options);
    }

    pub fn call_sign(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_sign(instance, input, options);
    }

    pub fn call_logicalOr(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_logicalOr(instance, a, b, options);
    }

    pub fn call_neg(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_neg(instance, input, options);
    }

    pub fn call_lstm(instance: *runtime.Instance, input: MLOperand, weight: MLOperand, recurrentWeight: MLOperand, steps: u32, hiddenSize: u32, options: MLLstmOptions) anyerror!anyopaque {
        // [EnforceRange] on steps
        if (!runtime.isInRange(steps)) return error.TypeError;
        // [EnforceRange] on hiddenSize
        if (!runtime.isInRange(hiddenSize)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_lstm(instance, input, weight, recurrentWeight, steps, hiddenSize, options);
    }

    pub fn call_concat(instance: *runtime.Instance, inputs: anyopaque, axis: u32, options: MLOperatorOptions) anyerror!MLOperand {
        // [EnforceRange] on axis
        if (!runtime.isInRange(axis)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_concat(instance, inputs, axis, options);
    }

    pub fn call_pow(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_pow(instance, a, b, options);
    }

    pub fn call_argMax(instance: *runtime.Instance, input: MLOperand, axis: u32, options: MLArgMinMaxOptions) anyerror!MLOperand {
        // [EnforceRange] on axis
        if (!runtime.isInRange(axis)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_argMax(instance, input, axis, options);
    }

    pub fn call_reduceMean(instance: *runtime.Instance, input: MLOperand, options: MLReduceOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reduceMean(instance, input, options);
    }

    pub fn call_softplus(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_softplus(instance, input, options);
    }

    pub fn call_gelu(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_gelu(instance, input, options);
    }

    pub fn call_reduceMin(instance: *runtime.Instance, input: MLOperand, options: MLReduceOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reduceMin(instance, input, options);
    }

    pub fn call_argMin(instance: *runtime.Instance, input: MLOperand, axis: u32, options: MLArgMinMaxOptions) anyerror!MLOperand {
        // [EnforceRange] on axis
        if (!runtime.isInRange(axis)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_argMin(instance, input, axis, options);
    }

    pub fn call_batchNormalization(instance: *runtime.Instance, input: MLOperand, mean: MLOperand, variance: MLOperand, options: MLBatchNormalizationOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_batchNormalization(instance, input, mean, variance, options);
    }

    pub fn call_cumulativeSum(instance: *runtime.Instance, input: MLOperand, axis: u32, options: MLCumulativeSumOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_cumulativeSum(instance, input, axis, options);
    }

    pub fn call_matmul(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_matmul(instance, a, b, options);
    }

    pub fn call_scatterND(instance: *runtime.Instance, input: MLOperand, indices: MLOperand, updates: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_scatterND(instance, input, indices, updates, options);
    }

    pub fn call_reduceProduct(instance: *runtime.Instance, input: MLOperand, options: MLReduceOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_reduceProduct(instance, input, options);
    }

    pub fn call_sigmoid(instance: *runtime.Instance, input: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_sigmoid(instance, input, options);
    }

    pub fn call_tile(instance: *runtime.Instance, input: MLOperand, repetitions: anyopaque, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_tile(instance, input, repetitions, options);
    }

    pub fn call_div(instance: *runtime.Instance, a: MLOperand, b: MLOperand, options: MLOperatorOptions) anyerror!MLOperand {
        
        return try MLGraphBuilderImpl.call_div(instance, a, b, options);
    }

};

//! Generated from: webnn.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MLGraphBuilderImpl = @import("impls").MLGraphBuilder;
const mixins = @import("mixins");
const MLTensor = @import("interfaces").MLTensor;
const MLLinearOptions = @import("dictionaries").MLLinearOptions;
const MLCumulativeSumOptions = @import("dictionaries").MLCumulativeSumOptions;
const MLLeakyReluOptions = @import("dictionaries").MLLeakyReluOptions;
const MLNamedOperands = @import("typedefs").MLNamedOperands;
const MLBatchNormalizationOptions = @import("dictionaries").MLBatchNormalizationOptions;
const MLResample2dOptions = @import("dictionaries").MLResample2dOptions;
const MLOperatorOptions = @import("dictionaries").MLOperatorOptions;
const MLGruOptions = @import("dictionaries").MLGruOptions;
const MLTriangularOptions = @import("dictionaries").MLTriangularOptions;
const USVString = @import("interfaces").USVString;
const MLOperandDescriptor = @import("dictionaries").MLOperandDescriptor;
const MLNumber = @import("typedefs").MLNumber;
const MLPadOptions = @import("dictionaries").MLPadOptions;
const MLInstanceNormalizationOptions = @import("dictionaries").MLInstanceNormalizationOptions;
const MLSliceOptions = @import("dictionaries").MLSliceOptions;
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
const MLSplitOptions = @import("dictionaries").MLSplitOptions;
const MLLstmCellOptions = @import("dictionaries").MLLstmCellOptions;
const MLGemmOptions = @import("dictionaries").MLGemmOptions;
const MLConvTranspose2dOptions = @import("dictionaries").MLConvTranspose2dOptions;
const MLLayerNormalizationOptions = @import("dictionaries").MLLayerNormalizationOptions;
const MLLstmOptions = @import("dictionaries").MLLstmOptions;
const MLPool2dOptions = @import("dictionaries").MLPool2dOptions;
const MLGruCellOptions = @import("dictionaries").MLGruCellOptions;
const MLReduceOptions = @import("dictionaries").MLReduceOptions;
const sequence = @import("interfaces").sequence;
const MLTransposeOptions = @import("dictionaries").MLTransposeOptions;
const MLGraph = @import("interfaces").MLGraph;

pub const MLGraphBuilder = struct {
    pub const Meta = struct {
        pub const name = "MLGraphBuilder";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "input", "call_input", 2 },
            .{ "constant", "call_constant", 2 },
            .{ "constant", "call_constant", 2 },
            .{ "constant", "call_constant", 1 },
            .{ "build", "call_build", 1 },
            .{ "argMin", "call_argMin", 2 },
            .{ "argMax", "call_argMax", 2 },
            .{ "batchNormalization", "call_batchNormalization", 3 },
            .{ "cast", "call_cast", 2 },
            .{ "clamp", "call_clamp", 1 },
            .{ "concat", "call_concat", 2 },
            .{ "conv2d", "call_conv2d", 2 },
            .{ "convTranspose2d", "call_convTranspose2d", 2 },
            .{ "cumulativeSum", "call_cumulativeSum", 2 },
            .{ "add", "call_add", 2 },
            .{ "sub", "call_sub", 2 },
            .{ "mul", "call_mul", 2 },
            .{ "div", "call_div", 2 },
            .{ "max", "call_max", 2 },
            .{ "min", "call_min", 2 },
            .{ "pow", "call_pow", 2 },
            .{ "equal", "call_equal", 2 },
            .{ "notEqual", "call_notEqual", 2 },
            .{ "greater", "call_greater", 2 },
            .{ "greaterOrEqual", "call_greaterOrEqual", 2 },
            .{ "lesser", "call_lesser", 2 },
            .{ "lesserOrEqual", "call_lesserOrEqual", 2 },
            .{ "logicalNot", "call_logicalNot", 1 },
            .{ "logicalAnd", "call_logicalAnd", 2 },
            .{ "logicalOr", "call_logicalOr", 2 },
            .{ "logicalXor", "call_logicalXor", 2 },
            .{ "isNaN", "call_isNaN", 1 },
            .{ "isInfinite", "call_isInfinite", 1 },
            .{ "abs", "call_abs", 1 },
            .{ "ceil", "call_ceil", 1 },
            .{ "cos", "call_cos", 1 },
            .{ "erf", "call_erf", 1 },
            .{ "exp", "call_exp", 1 },
            .{ "floor", "call_floor", 1 },
            .{ "identity", "call_identity", 1 },
            .{ "log", "call_log", 1 },
            .{ "neg", "call_neg", 1 },
            .{ "reciprocal", "call_reciprocal", 1 },
            .{ "roundEven", "call_roundEven", 1 },
            .{ "sin", "call_sin", 1 },
            .{ "sign", "call_sign", 1 },
            .{ "sqrt", "call_sqrt", 1 },
            .{ "tan", "call_tan", 1 },
            .{ "dequantizeLinear", "call_dequantizeLinear", 3 },
            .{ "quantizeLinear", "call_quantizeLinear", 3 },
            .{ "elu", "call_elu", 1 },
            .{ "expand", "call_expand", 2 },
            .{ "gather", "call_gather", 2 },
            .{ "gatherElements", "call_gatherElements", 2 },
            .{ "gatherND", "call_gatherND", 2 },
            .{ "gelu", "call_gelu", 1 },
            .{ "gemm", "call_gemm", 2 },
            .{ "gru", "call_gru", 5 },
            .{ "gruCell", "call_gruCell", 5 },
            .{ "hardSigmoid", "call_hardSigmoid", 1 },
            .{ "hardSwish", "call_hardSwish", 1 },
            .{ "instanceNormalization", "call_instanceNormalization", 1 },
            .{ "layerNormalization", "call_layerNormalization", 1 },
            .{ "leakyRelu", "call_leakyRelu", 1 },
            .{ "linear", "call_linear", 1 },
            .{ "lstm", "call_lstm", 5 },
            .{ "lstmCell", "call_lstmCell", 6 },
            .{ "matmul", "call_matmul", 2 },
            .{ "pad", "call_pad", 3 },
            .{ "averagePool2d", "call_averagePool2d", 1 },
            .{ "l2Pool2d", "call_l2Pool2d", 1 },
            .{ "maxPool2d", "call_maxPool2d", 1 },
            .{ "prelu", "call_prelu", 2 },
            .{ "reduceL1", "call_reduceL1", 1 },
            .{ "reduceL2", "call_reduceL2", 1 },
            .{ "reduceLogSum", "call_reduceLogSum", 1 },
            .{ "reduceLogSumExp", "call_reduceLogSumExp", 1 },
            .{ "reduceMax", "call_reduceMax", 1 },
            .{ "reduceMean", "call_reduceMean", 1 },
            .{ "reduceMin", "call_reduceMin", 1 },
            .{ "reduceProduct", "call_reduceProduct", 1 },
            .{ "reduceSum", "call_reduceSum", 1 },
            .{ "reduceSumSquare", "call_reduceSumSquare", 1 },
            .{ "relu", "call_relu", 1 },
            .{ "resample2d", "call_resample2d", 1 },
            .{ "reshape", "call_reshape", 2 },
            .{ "reverse", "call_reverse", 1 },
            .{ "scatterElements", "call_scatterElements", 3 },
            .{ "scatterND", "call_scatterND", 3 },
            .{ "sigmoid", "call_sigmoid", 1 },
            .{ "slice", "call_slice", 3 },
            .{ "softmax", "call_softmax", 2 },
            .{ "softplus", "call_softplus", 1 },
            .{ "softsign", "call_softsign", 1 },
            .{ "split", "call_split", 2 },
            .{ "tanh", "call_tanh", 1 },
            .{ "tile", "call_tile", 2 },
            .{ "transpose", "call_transpose", 1 },
            .{ "triangular", "call_triangular", 1 },
            .{ "where", "call_where", 3 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "input",
            "constant",
            "constant",
            "constant",
            "build",
            "argMin",
            "argMax",
            "batchNormalization",
            "cast",
            "clamp",
            "concat",
            "conv2d",
            "convTranspose2d",
            "cumulativeSum",
            "add",
            "sub",
            "mul",
            "div",
            "max",
            "min",
            "pow",
            "equal",
            "notEqual",
            "greater",
            "greaterOrEqual",
            "lesser",
            "lesserOrEqual",
            "logicalNot",
            "logicalAnd",
            "logicalOr",
            "logicalXor",
            "isNaN",
            "isInfinite",
            "abs",
            "ceil",
            "cos",
            "erf",
            "exp",
            "floor",
            "identity",
            "log",
            "neg",
            "reciprocal",
            "roundEven",
            "sin",
            "sign",
            "sqrt",
            "tan",
            "dequantizeLinear",
            "quantizeLinear",
            "elu",
            "expand",
            "gather",
            "gatherElements",
            "gatherND",
            "gelu",
            "gemm",
            "gru",
            "gruCell",
            "hardSigmoid",
            "hardSwish",
            "instanceNormalization",
            "layerNormalization",
            "leakyRelu",
            "linear",
            "lstm",
            "lstmCell",
            "matmul",
            "pad",
            "averagePool2d",
            "l2Pool2d",
            "maxPool2d",
            "prelu",
            "reduceL1",
            "reduceL2",
            "reduceLogSum",
            "reduceLogSumExp",
            "reduceMax",
            "reduceMean",
            "reduceMin",
            "reduceProduct",
            "reduceSum",
            "reduceSumSquare",
            "relu",
            "resample2d",
            "reshape",
            "reverse",
            "scatterElements",
            "scatterND",
            "sigmoid",
            "slice",
            "softmax",
            "softplus",
            "softsign",
            "split",
            "tanh",
            "tile",
            "transpose",
            "triangular",
            "where",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*MLGraphBuilderImpl.InternalState = null,
        },
    );

    const delegates = .{

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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MLGraphBuilderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MLGraphBuilderImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, context: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MLGraphBuilderImpl.call_constructor(allocator, ctx, context);
    }

    pub fn call_reduceL2(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLReduceOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reduceL2(instance, input, options);
    }

    pub fn call_reverse(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLReverseOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reverse(instance, input, options);
    }

    pub fn call_lesserOrEqual(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_lesserOrEqual(instance, a, b, options);
    }

    pub fn call_reduceSumSquare(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLReduceOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reduceSumSquare(instance, input, options);
    }

    pub fn call_instanceNormalization(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLInstanceNormalizationOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_instanceNormalization(instance, input, options);
    }

    pub fn call_ceil(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_ceil(instance, input, options);
    }

    pub fn call_greater(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_greater(instance, a, b, options);
    }

    pub fn call_exp(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_exp(instance, input, options);
    }

    pub fn call_reduceLogSum(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLReduceOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reduceLogSum(instance, input, options);
    }

    pub fn call_gatherElements(instance: *runtime.Instance, input: *runtime.Instance, indices: *runtime.Instance, options: webidl.Opt(MLGatherOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_gatherElements(instance, input, indices, options);
    }

    pub fn call_convTranspose2d(instance: *runtime.Instance, input: *runtime.Instance, filter: *runtime.Instance, options: webidl.Opt(MLConvTranspose2dOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_convTranspose2d(instance, input, filter, options);
    }

    pub fn call_relu(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_relu(instance, input, options);
    }

    pub fn call_where(instance: *runtime.Instance, condition: *runtime.Instance, trueValue: *runtime.Instance, falseValue: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_where(instance, condition, trueValue, falseValue, options);
    }

    pub fn call_build(instance: *runtime.Instance, outputs: MLNamedOperands) anyerror!*const anyopaque {
        
        return try MLGraphBuilderImpl.call_build(instance, outputs);
    }

    pub fn call_sub(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_sub(instance, a, b, options);
    }

    pub fn call_isInfinite(instance: *runtime.Instance, a: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_isInfinite(instance, a, options);
    }

    pub fn call_reduceLogSumExp(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLReduceOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reduceLogSumExp(instance, input, options);
    }

    pub fn call_transpose(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLTransposeOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_transpose(instance, input, options);
    }

    pub fn call_gru(instance: *runtime.Instance, input: *runtime.Instance, weight: *runtime.Instance, recurrentWeight: *runtime.Instance, steps: u32, hiddenSize: u32, options: webidl.Opt(MLGruOptions)) anyerror!*const anyopaque {
        // [EnforceRange] on steps
        if (!runtime.isInRange(u32, steps)) return error.TypeError;
        // [EnforceRange] on hiddenSize
        if (!runtime.isInRange(u32, hiddenSize)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_gru(instance, input, weight, recurrentWeight, steps, hiddenSize, options);
    }

    pub fn call_conv2d(instance: *runtime.Instance, input: *runtime.Instance, filter: *runtime.Instance, options: webidl.Opt(MLConv2dOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_conv2d(instance, input, filter, options);
    }

    pub fn call_cos(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_cos(instance, input, options);
    }

    pub fn call_quantizeLinear(instance: *runtime.Instance, input: *runtime.Instance, scale: *runtime.Instance, zeroPoint: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_quantizeLinear(instance, input, scale, zeroPoint, options);
    }

    pub fn call_elu(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLEluOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_elu(instance, input, options);
    }

    pub fn call_gather(instance: *runtime.Instance, input: *runtime.Instance, indices: *runtime.Instance, options: webidl.Opt(MLGatherOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_gather(instance, input, indices, options);
    }

    pub fn call_greaterOrEqual(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_greaterOrEqual(instance, a, b, options);
    }

    pub fn call_gatherND(instance: *runtime.Instance, input: *runtime.Instance, indices: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_gatherND(instance, input, indices, options);
    }

    pub fn call_l2Pool2d(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLPool2dOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_l2Pool2d(instance, input, options);
    }

    pub fn call_erf(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_erf(instance, input, options);
    }

    pub fn call_add(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_add(instance, a, b, options);
    }

    pub fn call_layerNormalization(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLLayerNormalizationOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_layerNormalization(instance, input, options);
    }

    pub fn call_pad(instance: *runtime.Instance, input: *runtime.Instance, beginningPadding: *const anyopaque, endingPadding: *const anyopaque, options: webidl.Opt(MLPadOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_pad(instance, input, beginningPadding, endingPadding, options);
    }

    pub fn call_notEqual(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_notEqual(instance, a, b, options);
    }

    pub fn call_log(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_log(instance, input, options);
    }

    pub fn call_dequantizeLinear(instance: *runtime.Instance, input: *runtime.Instance, scale: *runtime.Instance, zeroPoint: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_dequantizeLinear(instance, input, scale, zeroPoint, options);
    }

    pub fn call_maxPool2d(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLPool2dOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_maxPool2d(instance, input, options);
    }

    pub fn call_reduceL1(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLReduceOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reduceL1(instance, input, options);
    }

    pub fn call_floor(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_floor(instance, input, options);
    }

    pub fn call_linear(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLLinearOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_linear(instance, input, options);
    }

    pub fn call_reduceMax(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLReduceOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reduceMax(instance, input, options);
    }

    pub fn call_resample2d(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLResample2dOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_resample2d(instance, input, options);
    }

    pub fn call_softmax(instance: *runtime.Instance, input: *runtime.Instance, axis: u32, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        // [EnforceRange] on axis
        if (!runtime.isInRange(u32, axis)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_softmax(instance, input, axis, options);
    }

    pub fn call_min(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_min(instance, a, b, options);
    }

    pub fn call_lesser(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_lesser(instance, a, b, options);
    }

    pub fn call_isNaN(instance: *runtime.Instance, a: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_isNaN(instance, a, options);
    }

    pub fn call_gemm(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLGemmOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_gemm(instance, a, b, options);
    }

    pub fn call_cast(instance: *runtime.Instance, input: *runtime.Instance, dataType: MLOperandDataType, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_cast(instance, input, dataType, options);
    }

    pub fn call_hardSwish(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_hardSwish(instance, input, options);
    }

    pub fn call_reduceSum(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLReduceOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reduceSum(instance, input, options);
    }

    pub fn call_roundEven(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_roundEven(instance, input, options);
    }

    pub fn call_sqrt(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_sqrt(instance, input, options);
    }

    pub fn call_averagePool2d(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLPool2dOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_averagePool2d(instance, input, options);
    }

    pub fn call_equal(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_equal(instance, a, b, options);
    }

    pub fn call_slice(instance: *runtime.Instance, input: *runtime.Instance, starts: *const anyopaque, sizes: *const anyopaque, options: webidl.Opt(MLSliceOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_slice(instance, input, starts, sizes, options);
    }

    pub fn call_logicalNot(instance: *runtime.Instance, a: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_logicalNot(instance, a, options);
    }

    pub fn call_mul(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_mul(instance, a, b, options);
    }

    pub fn call_sin(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_sin(instance, input, options);
    }

    pub fn call_constant(instance: *runtime.Instance, descriptor: MLOperandDescriptor, buffer: AllowSharedBufferSource) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_constant(instance, descriptor, buffer);
    }

    pub fn call_gruCell(instance: *runtime.Instance, input: *runtime.Instance, weight: *runtime.Instance, recurrentWeight: *runtime.Instance, hiddenState: *runtime.Instance, hiddenSize: u32, options: webidl.Opt(MLGruCellOptions)) anyerror!*runtime.Instance {
        // [EnforceRange] on hiddenSize
        if (!runtime.isInRange(u32, hiddenSize)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_gruCell(instance, input, weight, recurrentWeight, hiddenState, hiddenSize, options);
    }

    pub fn call_split(instance: *runtime.Instance, input: *runtime.Instance, splits: *const anyopaque, options: webidl.Opt(MLSplitOptions)) anyerror!*const anyopaque {
        
        return try MLGraphBuilderImpl.call_split(instance, input, splits, options);
    }

    pub fn call_tanh(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_tanh(instance, input, options);
    }

    pub fn call_reshape(instance: *runtime.Instance, input: *runtime.Instance, newShape: *const anyopaque, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reshape(instance, input, newShape, options);
    }

    pub fn call_hardSigmoid(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLHardSigmoidOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_hardSigmoid(instance, input, options);
    }

    pub fn call_reciprocal(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reciprocal(instance, input, options);
    }

    pub fn call_expand(instance: *runtime.Instance, input: *runtime.Instance, newShape: *const anyopaque, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_expand(instance, input, newShape, options);
    }

    pub fn call_identity(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_identity(instance, input, options);
    }

    pub fn call_leakyRelu(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLLeakyReluOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_leakyRelu(instance, input, options);
    }

    pub fn call_clamp(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLClampOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_clamp(instance, input, options);
    }

    pub fn call_lstmCell(instance: *runtime.Instance, input: *runtime.Instance, weight: *runtime.Instance, recurrentWeight: *runtime.Instance, hiddenState: *runtime.Instance, cellState: *runtime.Instance, hiddenSize: u32, options: webidl.Opt(MLLstmCellOptions)) anyerror!*const anyopaque {
        // [EnforceRange] on hiddenSize
        if (!runtime.isInRange(u32, hiddenSize)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_lstmCell(instance, input, weight, recurrentWeight, hiddenState, cellState, hiddenSize, options);
    }

    pub fn call_prelu(instance: *runtime.Instance, input: *runtime.Instance, slope: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_prelu(instance, input, slope, options);
    }

    pub fn call_logicalXor(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_logicalXor(instance, a, b, options);
    }

    pub fn call_scatterElements(instance: *runtime.Instance, input: *runtime.Instance, indices: *runtime.Instance, updates: *runtime.Instance, options: webidl.Opt(MLScatterOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_scatterElements(instance, input, indices, updates, options);
    }

    pub fn call_abs(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_abs(instance, input, options);
    }

    pub fn call_input(instance: *runtime.Instance, name: runtime.USVString, descriptor: MLOperandDescriptor) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_input(instance, name, descriptor);
    }

    pub fn call_tan(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_tan(instance, input, options);
    }

    pub fn call_logicalAnd(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_logicalAnd(instance, a, b, options);
    }

    pub fn call_softsign(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_softsign(instance, input, options);
    }

    pub fn call_triangular(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLTriangularOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_triangular(instance, input, options);
    }

    pub fn call_max(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_max(instance, a, b, options);
    }

    pub fn call_sign(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_sign(instance, input, options);
    }

    pub fn call_logicalOr(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_logicalOr(instance, a, b, options);
    }

    pub fn call_neg(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_neg(instance, input, options);
    }

    pub fn call_lstm(instance: *runtime.Instance, input: *runtime.Instance, weight: *runtime.Instance, recurrentWeight: *runtime.Instance, steps: u32, hiddenSize: u32, options: webidl.Opt(MLLstmOptions)) anyerror!*const anyopaque {
        // [EnforceRange] on steps
        if (!runtime.isInRange(u32, steps)) return error.TypeError;
        // [EnforceRange] on hiddenSize
        if (!runtime.isInRange(u32, hiddenSize)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_lstm(instance, input, weight, recurrentWeight, steps, hiddenSize, options);
    }

    pub fn call_concat(instance: *runtime.Instance, inputs: *const anyopaque, axis: u32, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        // [EnforceRange] on axis
        if (!runtime.isInRange(u32, axis)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_concat(instance, inputs, axis, options);
    }

    pub fn call_pow(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_pow(instance, a, b, options);
    }

    pub fn call_argMax(instance: *runtime.Instance, input: *runtime.Instance, axis: u32, options: webidl.Opt(MLArgMinMaxOptions)) anyerror!*runtime.Instance {
        // [EnforceRange] on axis
        if (!runtime.isInRange(u32, axis)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_argMax(instance, input, axis, options);
    }

    pub fn call_reduceMean(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLReduceOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reduceMean(instance, input, options);
    }

    pub fn call_softplus(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_softplus(instance, input, options);
    }

    pub fn call_gelu(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_gelu(instance, input, options);
    }

    pub fn call_reduceMin(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLReduceOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reduceMin(instance, input, options);
    }

    pub fn call_argMin(instance: *runtime.Instance, input: *runtime.Instance, axis: u32, options: webidl.Opt(MLArgMinMaxOptions)) anyerror!*runtime.Instance {
        // [EnforceRange] on axis
        if (!runtime.isInRange(u32, axis)) return error.TypeError;
        
        return try MLGraphBuilderImpl.call_argMin(instance, input, axis, options);
    }

    pub fn call_batchNormalization(instance: *runtime.Instance, input: *runtime.Instance, mean: *runtime.Instance, variance: *runtime.Instance, options: webidl.Opt(MLBatchNormalizationOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_batchNormalization(instance, input, mean, variance, options);
    }

    pub fn call_cumulativeSum(instance: *runtime.Instance, input: *runtime.Instance, axis: u32, options: webidl.Opt(MLCumulativeSumOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_cumulativeSum(instance, input, axis, options);
    }

    pub fn call_matmul(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_matmul(instance, a, b, options);
    }

    pub fn call_scatterND(instance: *runtime.Instance, input: *runtime.Instance, indices: *runtime.Instance, updates: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_scatterND(instance, input, indices, updates, options);
    }

    pub fn call_reduceProduct(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLReduceOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_reduceProduct(instance, input, options);
    }

    pub fn call_sigmoid(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_sigmoid(instance, input, options);
    }

    pub fn call_tile(instance: *runtime.Instance, input: *runtime.Instance, repetitions: *const anyopaque, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_tile(instance, input, repetitions, options);
    }

    pub fn call_div(instance: *runtime.Instance, a: *runtime.Instance, b: *runtime.Instance, options: webidl.Opt(MLOperatorOptions)) anyerror!*runtime.Instance {
        
        return try MLGraphBuilderImpl.call_div(instance, a, b, options);
    }

};

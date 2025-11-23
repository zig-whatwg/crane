//! Implementation for MLGraphBuilder interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const MLGraphBuilder = interfaces.MLGraphBuilder;

pub const State = MLGraphBuilder.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, context: interfaces.MLContext) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &MLGraphBuilder.vtable, ctx);
    errdefer deinit(instance);

    _ = context;
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Operation: reduceL2
pub fn call_reduceL2(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLReduceOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reverse
pub fn call_reverse(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLReverseOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: lesserOrEqual
pub fn call_lesserOrEqual(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reduceSumSquare
pub fn call_reduceSumSquare(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLReduceOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: instanceNormalization
pub fn call_instanceNormalization(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLInstanceNormalizationOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: ceil
pub fn call_ceil(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: greater
pub fn call_greater(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: exp
pub fn call_exp(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reduceLogSum
pub fn call_reduceLogSum(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLReduceOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: gatherElements
pub fn call_gatherElements(instance: *runtime.Instance, input: interfaces.MLOperand, indices: interfaces.MLOperand, options: dictionaries.MLGatherOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = indices;
    _ = options;
    return error.NotImplemented;
}

/// Operation: convTranspose2d
pub fn call_convTranspose2d(instance: *runtime.Instance, input: interfaces.MLOperand, filter: interfaces.MLOperand, options: dictionaries.MLConvTranspose2dOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = filter;
    _ = options;
    return error.NotImplemented;
}

/// Operation: relu
pub fn call_relu(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: where
pub fn call_where(instance: *runtime.Instance, condition: interfaces.MLOperand, trueValue: interfaces.MLOperand, falseValue: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = condition;
    _ = trueValue;
    _ = falseValue;
    _ = options;
    return error.NotImplemented;
}

/// Operation: build
pub fn call_build(instance: *runtime.Instance, outputs: typedefs.MLNamedOperands) ImplError!*const anyopaque {
    _ = instance;
    _ = outputs;
    return error.NotImplemented;
}

/// Operation: sub
pub fn call_sub(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: isInfinite
pub fn call_isInfinite(instance: *runtime.Instance, a: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reduceLogSumExp
pub fn call_reduceLogSumExp(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLReduceOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: transpose
pub fn call_transpose(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLTransposeOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: gru
pub fn call_gru(instance: *runtime.Instance, input: interfaces.MLOperand, weight: interfaces.MLOperand, recurrentWeight: interfaces.MLOperand, steps: u32, hiddenSize: u32, options: dictionaries.MLGruOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = input;
    _ = weight;
    _ = recurrentWeight;
    _ = steps;
    _ = hiddenSize;
    _ = options;
    return error.NotImplemented;
}

/// Operation: conv2d
pub fn call_conv2d(instance: *runtime.Instance, input: interfaces.MLOperand, filter: interfaces.MLOperand, options: dictionaries.MLConv2dOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = filter;
    _ = options;
    return error.NotImplemented;
}

/// Operation: cos
pub fn call_cos(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: quantizeLinear
pub fn call_quantizeLinear(instance: *runtime.Instance, input: interfaces.MLOperand, scale: interfaces.MLOperand, zeroPoint: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = scale;
    _ = zeroPoint;
    _ = options;
    return error.NotImplemented;
}

/// Operation: elu
pub fn call_elu(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLEluOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: gather
pub fn call_gather(instance: *runtime.Instance, input: interfaces.MLOperand, indices: interfaces.MLOperand, options: dictionaries.MLGatherOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = indices;
    _ = options;
    return error.NotImplemented;
}

/// Operation: greaterOrEqual
pub fn call_greaterOrEqual(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: gatherND
pub fn call_gatherND(instance: *runtime.Instance, input: interfaces.MLOperand, indices: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = indices;
    _ = options;
    return error.NotImplemented;
}

/// Operation: l2Pool2d
pub fn call_l2Pool2d(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLPool2dOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: erf
pub fn call_erf(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: layerNormalization
pub fn call_layerNormalization(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLLayerNormalizationOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: pad
pub fn call_pad(instance: *runtime.Instance, input: interfaces.MLOperand, beginningPadding: *const anyopaque, endingPadding: *const anyopaque, options: dictionaries.MLPadOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = beginningPadding;
    _ = endingPadding;
    _ = options;
    return error.NotImplemented;
}

/// Operation: notEqual
pub fn call_notEqual(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: log
pub fn call_log(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: dequantizeLinear
pub fn call_dequantizeLinear(instance: *runtime.Instance, input: interfaces.MLOperand, scale: interfaces.MLOperand, zeroPoint: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = scale;
    _ = zeroPoint;
    _ = options;
    return error.NotImplemented;
}

/// Operation: maxPool2d
pub fn call_maxPool2d(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLPool2dOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reduceL1
pub fn call_reduceL1(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLReduceOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: floor
pub fn call_floor(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: linear
pub fn call_linear(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLLinearOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reduceMax
pub fn call_reduceMax(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLReduceOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: resample2d
pub fn call_resample2d(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLResample2dOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: softmax
pub fn call_softmax(instance: *runtime.Instance, input: interfaces.MLOperand, axis: u32, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = axis;
    _ = options;
    return error.NotImplemented;
}

/// Operation: min
pub fn call_min(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: lesser
pub fn call_lesser(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: isNaN
pub fn call_isNaN(instance: *runtime.Instance, a: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = options;
    return error.NotImplemented;
}

/// Operation: gemm
pub fn call_gemm(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLGemmOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: cast
pub fn call_cast(instance: *runtime.Instance, input: interfaces.MLOperand, dataType: enums.MLOperandDataType, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = dataType;
    _ = options;
    return error.NotImplemented;
}

/// Operation: hardSwish
pub fn call_hardSwish(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reduceSum
pub fn call_reduceSum(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLReduceOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: roundEven
pub fn call_roundEven(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: sqrt
pub fn call_sqrt(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: averagePool2d
pub fn call_averagePool2d(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLPool2dOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: equal
pub fn call_equal(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: slice
pub fn call_slice(instance: *runtime.Instance, input: interfaces.MLOperand, starts: *const anyopaque, sizes: *const anyopaque, options: dictionaries.MLSliceOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = starts;
    _ = sizes;
    _ = options;
    return error.NotImplemented;
}

/// Operation: logicalNot
pub fn call_logicalNot(instance: *runtime.Instance, a: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = options;
    return error.NotImplemented;
}

/// Operation: mul
pub fn call_mul(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: sin
pub fn call_sin(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: constant
pub fn call_constant(instance: *runtime.Instance, descriptor: dictionaries.MLOperandDescriptor, buffer: typedefs.AllowSharedBufferSource) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = descriptor;
    _ = buffer;
    return error.NotImplemented;
}

/// Operation: gruCell
pub fn call_gruCell(instance: *runtime.Instance, input: interfaces.MLOperand, weight: interfaces.MLOperand, recurrentWeight: interfaces.MLOperand, hiddenState: interfaces.MLOperand, hiddenSize: u32, options: dictionaries.MLGruCellOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = weight;
    _ = recurrentWeight;
    _ = hiddenState;
    _ = hiddenSize;
    _ = options;
    return error.NotImplemented;
}

/// Operation: split
pub fn call_split(instance: *runtime.Instance, input: interfaces.MLOperand, splits: *const anyopaque, options: dictionaries.MLSplitOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = input;
    _ = splits;
    _ = options;
    return error.NotImplemented;
}

/// Operation: tanh
pub fn call_tanh(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reshape
pub fn call_reshape(instance: *runtime.Instance, input: interfaces.MLOperand, newShape: *const anyopaque, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = newShape;
    _ = options;
    return error.NotImplemented;
}

/// Operation: hardSigmoid
pub fn call_hardSigmoid(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLHardSigmoidOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reciprocal
pub fn call_reciprocal(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: expand
pub fn call_expand(instance: *runtime.Instance, input: interfaces.MLOperand, newShape: *const anyopaque, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = newShape;
    _ = options;
    return error.NotImplemented;
}

/// Operation: identity
pub fn call_identity(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: leakyRelu
pub fn call_leakyRelu(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLLeakyReluOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clamp
pub fn call_clamp(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLClampOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: lstmCell
pub fn call_lstmCell(instance: *runtime.Instance, input: interfaces.MLOperand, weight: interfaces.MLOperand, recurrentWeight: interfaces.MLOperand, hiddenState: interfaces.MLOperand, cellState: interfaces.MLOperand, hiddenSize: u32, options: dictionaries.MLLstmCellOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = input;
    _ = weight;
    _ = recurrentWeight;
    _ = hiddenState;
    _ = cellState;
    _ = hiddenSize;
    _ = options;
    return error.NotImplemented;
}

/// Operation: prelu
pub fn call_prelu(instance: *runtime.Instance, input: interfaces.MLOperand, slope: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = slope;
    _ = options;
    return error.NotImplemented;
}

/// Operation: logicalXor
pub fn call_logicalXor(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: scatterElements
pub fn call_scatterElements(instance: *runtime.Instance, input: interfaces.MLOperand, indices: interfaces.MLOperand, updates: interfaces.MLOperand, options: dictionaries.MLScatterOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = indices;
    _ = updates;
    _ = options;
    return error.NotImplemented;
}

/// Operation: abs
pub fn call_abs(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: input
pub fn call_input(instance: *runtime.Instance, name: runtime.USVString, descriptor: dictionaries.MLOperandDescriptor) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = name;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: tan
pub fn call_tan(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: logicalAnd
pub fn call_logicalAnd(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: softsign
pub fn call_softsign(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: triangular
pub fn call_triangular(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLTriangularOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: max
pub fn call_max(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: sign
pub fn call_sign(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: logicalOr
pub fn call_logicalOr(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: neg
pub fn call_neg(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: lstm
pub fn call_lstm(instance: *runtime.Instance, input: interfaces.MLOperand, weight: interfaces.MLOperand, recurrentWeight: interfaces.MLOperand, steps: u32, hiddenSize: u32, options: dictionaries.MLLstmOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = input;
    _ = weight;
    _ = recurrentWeight;
    _ = steps;
    _ = hiddenSize;
    _ = options;
    return error.NotImplemented;
}

/// Operation: concat
pub fn call_concat(instance: *runtime.Instance, inputs: *const anyopaque, axis: u32, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = inputs;
    _ = axis;
    _ = options;
    return error.NotImplemented;
}

/// Operation: pow
pub fn call_pow(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: argMax
pub fn call_argMax(instance: *runtime.Instance, input: interfaces.MLOperand, axis: u32, options: dictionaries.MLArgMinMaxOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = axis;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reduceMean
pub fn call_reduceMean(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLReduceOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: softplus
pub fn call_softplus(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: gelu
pub fn call_gelu(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reduceMin
pub fn call_reduceMin(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLReduceOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: argMin
pub fn call_argMin(instance: *runtime.Instance, input: interfaces.MLOperand, axis: u32, options: dictionaries.MLArgMinMaxOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = axis;
    _ = options;
    return error.NotImplemented;
}

/// Operation: batchNormalization
pub fn call_batchNormalization(instance: *runtime.Instance, input: interfaces.MLOperand, mean: interfaces.MLOperand, variance: interfaces.MLOperand, options: dictionaries.MLBatchNormalizationOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = mean;
    _ = variance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: cumulativeSum
pub fn call_cumulativeSum(instance: *runtime.Instance, input: interfaces.MLOperand, axis: u32, options: dictionaries.MLCumulativeSumOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = axis;
    _ = options;
    return error.NotImplemented;
}

/// Operation: matmul
pub fn call_matmul(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}

/// Operation: scatterND
pub fn call_scatterND(instance: *runtime.Instance, input: interfaces.MLOperand, indices: interfaces.MLOperand, updates: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = indices;
    _ = updates;
    _ = options;
    return error.NotImplemented;
}

/// Operation: reduceProduct
pub fn call_reduceProduct(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLReduceOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: sigmoid
pub fn call_sigmoid(instance: *runtime.Instance, input: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = options;
    return error.NotImplemented;
}

/// Operation: tile
pub fn call_tile(instance: *runtime.Instance, input: interfaces.MLOperand, repetitions: *const anyopaque, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = input;
    _ = repetitions;
    _ = options;
    return error.NotImplemented;
}

/// Operation: div
pub fn call_div(instance: *runtime.Instance, a: interfaces.MLOperand, b: interfaces.MLOperand, options: dictionaries.MLOperatorOptions) ImplError!interfaces.MLOperand {
    _ = instance;
    _ = a;
    _ = b;
    _ = options;
    return error.NotImplemented;
}


// Unified V8 C API Wrapper for Zig
//
// This provides a single, consistent C-compatible API for V8.
// All functions use MixedCase naming (v8_TypeName_MethodName).
// All handles use Global<T>* for cross-scope persistence.
//
// Used by:
// - REPL (persistent handles for context, isolate, etc.)
// - Namespace bindings (callbacks convert Local→Global→Local)

#include <v8.h>
#include <libplatform/libplatform.h>
#include <cstring>

using namespace v8;

// Platform singleton
static std::unique_ptr<Platform> g_platform = nullptr;
static bool v8_initialized = false;

extern "C" {

// ============================================================================
// Platform Management
// ============================================================================

void v8_Platform_Initialize() {
    if (!v8_initialized) {
        V8::InitializeICUDefaultLocation("");
        V8::InitializeExternalStartupData("");
        g_platform = platform::NewDefaultPlatform();
        V8::InitializePlatform(g_platform.get());
        V8::Initialize();
        v8_initialized = true;
    }
}

void v8_Platform_Dispose() {
    if (v8_initialized) {
        V8::Dispose();
        V8::DisposePlatform();
        v8_initialized = false;
    }
}

// ============================================================================
// Isolate Management
// ============================================================================

Isolate* v8_Isolate_New() {
    if (!v8_initialized) {
        v8_Platform_Initialize();
    }
    
    Isolate::CreateParams create_params;
    create_params.array_buffer_allocator = ArrayBuffer::Allocator::NewDefaultAllocator();
    return Isolate::New(create_params);
}

void v8_Isolate_Dispose(Isolate* isolate) {
    if (isolate) {
        isolate->Dispose();
    }
}

void v8_Isolate_Enter(Isolate* isolate) {
    isolate->Enter();
}

void v8_Isolate_Exit(Isolate* isolate) {
    isolate->Exit();
}

Global<Context>* v8_Isolate_GetCurrentContext(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Context> ctx = isolate->GetCurrentContext();
    return new Global<Context>(isolate, ctx);
}

void v8_Isolate_ThrowException(Isolate* isolate, Global<Value>* exception) {
    HandleScope handle_scope(isolate);
    Local<Value> exc = exception->Get(isolate);
    isolate->ThrowException(exc);
}

void v8_Isolate_SetData(Isolate* isolate, int slot, void* data) {
    isolate->SetData(slot, data);
}

void* v8_Isolate_GetData(Isolate* isolate, int slot) {
    return isolate->GetData(slot);
}

// ============================================================================
// Context Management
// ============================================================================

Global<Context>* v8_Context_New(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Context> context = Context::New(isolate);
    return new Global<Context>(isolate, context);
}

void v8_Context_Dispose(Global<Context>* context) {
    if (context) {
        context->Reset();
        delete context;
    }
}

void v8_Context_Enter(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    local_context->Enter();
}

void v8_Context_Exit(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    local_context->Exit();
}

Global<Object>* v8_Context_Global(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    Local<Object> global = local_context->Global();
    return new Global<Object>(isolate, global);
}

// ============================================================================
// String Functions
// ============================================================================

Global<String>* v8_String_NewFromUtf8(Isolate* isolate, const uint8_t* data, int length) {
    HandleScope handle_scope(isolate);
    MaybeLocal<String> maybe_str = String::NewFromUtf8(
        isolate,
        reinterpret_cast<const char*>(data),
        NewStringType::kNormal,
        length
    );
    if (maybe_str.IsEmpty()) {
        return nullptr;
    }
    Local<String> str = maybe_str.ToLocalChecked();
    return new Global<String>(isolate, str);
}

void v8_String_Dispose(Global<String>* str) {
    if (str) {
        str->Reset();
        delete str;
    }
}

int v8_String_Utf8Length(Global<String>* str) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> local_str = str->Get(isolate);
    return local_str->Utf8Length(isolate);
}

int v8_String_WriteUtf8(Global<String>* str, char* buffer, int length) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> local_str = str->Get(isolate);
    return local_str->WriteUtf8(isolate, buffer, length);
}

Global<String>* v8_String_Empty(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<String> empty = String::Empty(isolate);
    return new Global<String>(isolate, empty);
}

// ============================================================================
// Value Functions
// ============================================================================

bool v8_Value_IsUndefined(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsUndefined();
}

bool v8_Value_IsString(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsString();
}

bool v8_Value_IsNull(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsNull();
}

bool v8_Value_IsBoolean(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsBoolean();
}

bool v8_Value_IsNumber(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsNumber();
}

bool v8_Value_IsSymbol(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsSymbol();
}

bool v8_Value_IsBigInt(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsBigInt();
}

bool v8_Value_IsObject(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsObject();
}

bool v8_Value_IsArray(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsArray();
}

bool v8_Value_IsNullOrUndefined(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsNullOrUndefined();
}

bool v8_Value_BooleanValue(Global<Value>* value, Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->BooleanValue(isolate);
}

double v8_Value_NumberValue(Global<Value>* value, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    Maybe<double> maybe_num = val->NumberValue(ctx);
    return maybe_num.FromMaybe(0.0);
}

int32_t v8_Value_Int32Value(Global<Value>* value, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    Maybe<int32_t> maybe_int = val->Int32Value(ctx);
    return maybe_int.FromMaybe(0);
}

uint32_t v8_Value_Uint32Value(Global<Value>* value, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    Maybe<uint32_t> maybe_uint = val->Uint32Value(ctx);
    return maybe_uint.FromMaybe(0);
}

int64_t v8_Value_IntegerValue(Global<Value>* value, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    Maybe<int64_t> maybe_int = val->IntegerValue(ctx);
    return maybe_int.FromMaybe(0);
}

Global<String>* v8_Value_ToString(Global<Value>* value, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    MaybeLocal<String> maybe_str = val->ToString(ctx);
    if (maybe_str.IsEmpty()) {
        return nullptr;
    }
    
    Local<String> str = maybe_str.ToLocalChecked();
    return new Global<String>(isolate, str);
}

void v8_Value_Dispose(Global<Value>* value) {
    if (value) {
        value->Reset();
        delete value;
    }
}

// ============================================================================
// Number Functions
// ============================================================================

Global<Number>* v8_Number_New(Isolate* isolate, double value) {
    HandleScope handle_scope(isolate);
    Local<Number> num = Number::New(isolate, value);
    return new Global<Number>(isolate, num);
}

Global<Number>* v8_Integer_New(Isolate* isolate, int32_t value) {
    HandleScope handle_scope(isolate);
    Local<Integer> num = Integer::New(isolate, value);
    return new Global<Number>(isolate, num.As<Number>());
}

// ============================================================================
// Object Functions
// ============================================================================

Global<Object>* v8_Object_New(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Object> obj = Object::New(isolate);
    return new Global<Object>(isolate, obj);
}

bool v8_Object_Set(Global<Object>* object, Global<Context>* context, Global<Value>* key, Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);
    Local<Value> v = value->Get(isolate);
    
    Maybe<bool> result = obj->Set(ctx, k, v);
    return result.FromMaybe(false);
}

Global<Value>* v8_Object_Get(Global<Object>* object, Global<Context>* context, Global<Value>* key) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);
    
    MaybeLocal<Value> maybe_val = obj->Get(ctx, k);
    if (maybe_val.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> val = maybe_val.ToLocalChecked();
    return new Global<Value>(isolate, val);
}

Global<Array>* v8_Object_GetOwnPropertyNames(Global<Context>* context, Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    MaybeLocal<Array> maybe_names = local_obj->GetOwnPropertyNames(local_context);
    if (maybe_names.IsEmpty()) {
        return nullptr;
    }
    
    Local<Array> names = maybe_names.ToLocalChecked();
    return new Global<Array>(isolate, names);
}

// Get all property names including prototype chain and non-enumerable
Global<Array>* v8_Object_GetPropertyNames(Global<Context>* context, Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    // Include all properties from prototype chain, including non-enumerable ones
    MaybeLocal<Array> maybe_names = local_obj->GetPropertyNames(
        local_context,
        KeyCollectionMode::kIncludePrototypes,
        static_cast<PropertyFilter>(PropertyFilter::ALL_PROPERTIES | PropertyFilter::SKIP_SYMBOLS),
        IndexFilter::kIncludeIndices,
        KeyConversionMode::kConvertToString
    );
    if (maybe_names.IsEmpty()) {
        return nullptr;
    }
    
    Local<Array> names = maybe_names.ToLocalChecked();
    return new Global<Array>(isolate, names);
}

void v8_Object_SetAlignedPointerInInternalField(Global<Object>* obj, int index, void* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    local_obj->SetAlignedPointerInInternalField(index, value);
}

void* v8_Object_GetAlignedPointerFromInternalField(Global<Object>* obj, int index) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    return local_obj->GetAlignedPointerFromInternalField(index);
}

void v8_Object_Dispose(Global<Object>* obj) {
    if (obj) {
        obj->Reset();
        delete obj;
    }
}

// ============================================================================
// Array Functions
// ============================================================================

Global<Array>* v8_Array_New(Isolate* isolate, int length) {
    HandleScope handle_scope(isolate);
    Local<Array> arr = Array::New(isolate, length);
    return new Global<Array>(isolate, arr);
}

uint32_t v8_Array_Length(Global<Array>* arr) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Array> local_arr = arr->Get(isolate);
    return local_arr->Length();
}

Global<Value>* v8_Array_Get(Global<Context>* context, Global<Array>* arr, uint32_t index) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Array> local_arr = arr->Get(isolate);
    
    MaybeLocal<Value> maybe_value = local_arr->Get(local_context, index);
    if (maybe_value.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> value = maybe_value.ToLocalChecked();
    return new Global<Value>(isolate, value);
}

bool v8_Array_Set(Global<Array>* arr, Global<Context>* context, uint32_t index, Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Array> local_arr = arr->Get(isolate);
    Local<Value> local_value = value->Get(isolate);
    
    Maybe<bool> result = local_arr->Set(local_context, index, local_value);
    return result.FromMaybe(false);
}

void v8_Array_Dispose(Global<Array>* arr) {
    if (arr) {
        arr->Reset();
        delete arr;
    }
}

// ============================================================================
// Script Functions
// ============================================================================

Global<Script>* v8_Script_Compile(Global<Context>* context, Global<String>* source) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<String> local_source = source->Get(isolate);
    
    MaybeLocal<Script> maybe_script = Script::Compile(local_context, local_source);
    if (maybe_script.IsEmpty()) {
        return nullptr;
    }
    
    Local<Script> script = maybe_script.ToLocalChecked();
    return new Global<Script>(isolate, script);
}

Global<Value>* v8_Script_Run(Global<Context>* context, Global<Script>* script) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Script> local_script = script->Get(isolate);
    
    MaybeLocal<Value> maybe_result = local_script->Run(local_context);
    if (maybe_result.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> result = maybe_result.ToLocalChecked();
    return new Global<Value>(isolate, result);
}

void v8_Script_Dispose(Global<Script>* script) {
    if (script) {
        script->Reset();
        delete script;
    }
}

// ============================================================================
// Exception Functions
// ============================================================================

Global<Value>* v8_Exception_TypeError(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::TypeError(msg);
    return new Global<Value>(isolate, exception);
}

Global<Value>* v8_Exception_RangeError(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::RangeError(msg);
    return new Global<Value>(isolate, exception);
}

Global<Value>* v8_Exception_Error(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::Error(msg);
    return new Global<Value>(isolate, exception);
}

Global<Value>* v8_TryCatch_Exception(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    TryCatch try_catch(isolate);
    
    if (try_catch.HasCaught()) {
        Local<Value> exception = try_catch.Exception();
        return new Global<Value>(isolate, exception);
    }
    
    return nullptr;
}

// ============================================================================
// Special Values
// ============================================================================

Global<Value>* v8_Undefined(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Value> undef = Undefined(isolate);
    return new Global<Value>(isolate, undef);
}

Global<Value>* v8_Null(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Value> null_val = Null(isolate);
    return new Global<Value>(isolate, null_val);
}

// ============================================================================
// FunctionTemplate & FunctionCallbackInfo (for namespace bindings)
// ============================================================================

// Callback wrapper: converts V8 callback to our Global-based API
typedef void (*ZigCallback)(const FunctionCallbackInfo<Value>*);

Global<FunctionTemplate>* v8_FunctionTemplate_New(
    Isolate* isolate,
    ZigCallback callback,
    Global<Value>* data
) {
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> tpl = FunctionTemplate::New(
        isolate,
        reinterpret_cast<FunctionCallback>(callback),
        data ? data->Get(isolate) : Local<Value>()
    );
    return new Global<FunctionTemplate>(isolate, tpl);
}

Global<Function>* v8_FunctionTemplate_GetFunction(Global<FunctionTemplate>* function_template, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<FunctionTemplate> tpl = function_template->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    MaybeLocal<Function> maybe_fn = tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        return nullptr;
    }
    
    Local<Function> fn = maybe_fn.ToLocalChecked();
    return new Global<Function>(isolate, fn);
}

void v8_FunctionTemplate_Dispose(Global<FunctionTemplate>* tpl) {
    if (tpl) {
        tpl->Reset();
        delete tpl;
    }
}

void v8_FunctionTemplate_SetClassName(Global<FunctionTemplate>* tpl, Global<String>* name) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<String> local_name = name->Get(isolate);
    local_tpl->SetClassName(local_name);
}

Global<ObjectTemplate>* v8_FunctionTemplate_InstanceTemplate(Global<FunctionTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<ObjectTemplate> instance_tpl = local_tpl->InstanceTemplate();
    return new Global<ObjectTemplate>(isolate, instance_tpl);
}

Global<ObjectTemplate>* v8_FunctionTemplate_PrototypeTemplate(Global<FunctionTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<ObjectTemplate> proto_tpl = local_tpl->PrototypeTemplate();
    return new Global<ObjectTemplate>(isolate, proto_tpl);
}

void v8_FunctionTemplate_Inherit(Global<FunctionTemplate>* tpl, Global<FunctionTemplate>* parent) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<FunctionTemplate> local_parent = parent->Get(isolate);
    local_tpl->Inherit(local_parent);
}

void v8_FunctionTemplate_SetLength(Global<FunctionTemplate>* tpl, int length) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->SetLength(length);
}

// FunctionCallbackInfo accessors
Isolate* v8_FunctionCallbackInfo_GetIsolate(const FunctionCallbackInfo<Value>* info) {
    return info->GetIsolate();
}

int v8_FunctionCallbackInfo_Length(const FunctionCallbackInfo<Value>* info) {
    return info->Length();
}

Global<Value>* v8_FunctionCallbackInfo_GetArgument(const FunctionCallbackInfo<Value>* info, int index) {
    Isolate* isolate = info->GetIsolate();
    Local<Value> arg = (*info)[index];
    return new Global<Value>(isolate, arg);
}

void v8_FunctionCallbackInfo_SetReturnValue(const FunctionCallbackInfo<Value>* info, Global<Value>* value) {
    Isolate* isolate = info->GetIsolate();
    Local<Value> val = value->Get(isolate);
    info->GetReturnValue().Set(val);
}

void v8_Function_Dispose(Global<Function>* fn) {
    if (fn) {
        fn->Reset();
        delete fn;
    }
}

// FunctionCallbackInfo - get 'this' object
Global<Object>* v8_FunctionCallbackInfo_This(const FunctionCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Object> self = info->This();
    return new Global<Object>(isolate, self);
}

// ObjectTemplate - set property (uses current isolate from the template's context)
void v8_ObjectTemplate_Set(Global<ObjectTemplate>* tpl, Global<String>* name, Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<String> key = name->Get(isolate);
    Local<Value> val = value->Get(isolate);
    local_tpl->Set(key, val);
}

// ObjectTemplate - set property with attributes
void v8_ObjectTemplate_SetWithAttributes(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    Global<Value>* value,
    int attributes
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<String> key = name->Get(isolate);
    Local<Value> val = value->Get(isolate);
    local_tpl->Set(key, val, static_cast<PropertyAttribute>(attributes));
}

// ObjectTemplate - set internal field count
void v8_ObjectTemplate_SetInternalFieldCount(Global<ObjectTemplate>* tpl, int count) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->SetInternalFieldCount(count);
}

// Callback types for accessors (using Name instead of String for modern V8 API)
typedef void (*AccessorNameGetterCallback)(Local<Name> property, const PropertyCallbackInfo<Value>& info);
typedef void (*AccessorNameSetterCallback)(Local<Name> property, Local<Value> value, const PropertyCallbackInfo<void>& info);

// ObjectTemplate - set accessor (getter/setter) using SetNativeDataProperty
void v8_ObjectTemplate_SetAccessor(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    AccessorNameGetterCallback getter,
    AccessorNameSetterCallback setter,
    Global<Value>* data
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<String> key = name->Get(isolate);
    Local<Value> local_data = data ? data->Get(isolate) : Local<Value>();
    
    local_tpl->SetNativeDataProperty(key, getter, setter, local_data);
}

// ObjectTemplate - set accessor property (creates visible accessor descriptor)
// This version creates a FunctionTemplate for the getter/setter, making them
// visible in Object.getOwnPropertyDescriptor as { get: [Function], set: [Function] }
void v8_ObjectTemplate_SetAccessorProperty(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    AccessorNameGetterCallback getter,
    AccessorNameSetterCallback setter
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<Name> key = name->Get(isolate).As<Name>();
    
    // Create a wrapper FunctionTemplate for the getter
    // The wrapper converts FunctionCallbackInfo to PropertyCallbackInfo
    auto getter_wrapper = [](const FunctionCallbackInfo<Value>& info) {
        // Extract the actual getter callback from data
        auto actual_getter = reinterpret_cast<AccessorNameGetterCallback>(
            info.Data().As<v8::External>()->Value()
        );
        
        // Create a PropertyCallbackInfo-like context
        // V8 internally uses the same info structure for both
        const PropertyCallbackInfo<Value>& prop_info =
            *reinterpret_cast<const PropertyCallbackInfo<Value>*>(&info);
        
        // Call the actual getter with an empty property name
        // (property name isn't used in our generated getters)
        Local<String> empty_name = String::Empty(info.GetIsolate());
        actual_getter(empty_name.As<Name>(), prop_info);
    };
    
    // Wrap the getter callback pointer in External so we can pass it as data
    Local<External> getter_data = External::New(isolate, reinterpret_cast<void*>(getter));
    
    Local<FunctionTemplate> getter_tpl = FunctionTemplate::New(
        isolate,
        getter_wrapper,
        getter_data
    );
    
    // Create FunctionTemplate for setter (if provided)
    Local<FunctionTemplate> setter_tpl;
    if (setter != nullptr) {
        auto setter_wrapper = [](const FunctionCallbackInfo<Value>& info) {
            auto actual_setter = reinterpret_cast<AccessorNameSetterCallback>(
                info.Data().As<v8::External>()->Value()
            );
            
            const PropertyCallbackInfo<void>& prop_info =
                *reinterpret_cast<const PropertyCallbackInfo<void>*>(&info);
            
            Local<String> empty_name = String::Empty(info.GetIsolate());
            Local<Value> value = info[0];  // First argument is the new value
            actual_setter(empty_name.As<Name>(), value, prop_info);
        };
        
        Local<External> setter_data = External::New(isolate, reinterpret_cast<void*>(setter));
        setter_tpl = FunctionTemplate::New(
            isolate,
            setter_wrapper,
            setter_data
        );
    }
    
    // Set as accessor property with proper attributes
    // PropertyAttribute::None means enumerable=true, configurable=true (WebIDL default)
    local_tpl->SetAccessorProperty(
        key,
        getter_tpl,
        setter ? setter_tpl : Local<FunctionTemplate>(),
        PropertyAttribute::None
    );
}

// ObjectTemplate - set named property handler (intercepts all property access)
// Using V8's callback types - these use the modern Intercepted return type
void v8_ObjectTemplate_SetNamedPropertyHandler(
    Global<ObjectTemplate>* tpl,
    NamedPropertyGetterCallback getter,
    NamedPropertySetterCallback setter,
    NamedPropertyQueryCallback query,
    NamedPropertyDeleterCallback deleter,
    NamedPropertyEnumeratorCallback enumerator,
    Global<Value>* data
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<Value> local_data = data ? data->Get(isolate) : Local<Value>();
    
    // V8 NamedPropertyHandlerConfiguration constructor takes 9 parameters:
    // 7 callbacks (getter, setter, query, deleter, enumerator, definer, descriptor)
    // + data + flags
    local_tpl->SetHandler(NamedPropertyHandlerConfiguration(
        getter,
        setter,
        query,
        deleter,
        enumerator,
        nullptr,  // definer callback (not needed for lazy properties)
        nullptr,  // descriptor callback (not needed for lazy properties)
        local_data,
        PropertyHandlerFlags::kNone
    ));
}

// PropertyCallbackInfo - get isolate
Isolate* v8_PropertyCallbackInfo_GetIsolate(const PropertyCallbackInfo<Value>* info) {
    return info->GetIsolate();
}

// PropertyCallbackInfo (void) - get isolate (for setters)
Isolate* v8_PropertyCallbackInfo_Void_GetIsolate(const PropertyCallbackInfo<void>* info) {
    return info->GetIsolate();
}

// PropertyCallbackInfo - get this
Global<Object>* v8_PropertyCallbackInfo_This(const PropertyCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    return new Global<Object>(isolate, info->This());
}

// PropertyCallbackInfo - get holder object
// Returns nullptr if not available (e.g., accessing property on prototype)
//
// IMPORTANT: This function can return nullptr when accessing properties
// on prototypes without instances. The caller MUST check for nullptr.
Global<Object>* v8_PropertyCallbackInfo_Holder(const PropertyCallbackInfo<Value>* info) {
    // For now, return nullptr to indicate no holder available
    // This forces callers to handle the prototype-access case
    // TODO: Investigate why Global<Object> creation crashes for prototypes
    return nullptr;
}

// PropertyCallbackInfo - set return value
void v8_PropertyCallbackInfo_SetReturnValue(const PropertyCallbackInfo<Value>* info, Global<Value>* value) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    info->GetReturnValue().Set(val);
}

// PropertyCallbackInfo - set return value to undefined
void v8_PropertyCallbackInfo_SetUndefined(const PropertyCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    info->GetReturnValue().SetUndefined();
}

// ============================================================================
// Name Functions  
// ============================================================================

bool v8_Name_IsString(const void* name) {
    // CRITICAL INSIGHT: V8 callback passes Local<Name> BY VALUE, which at the C ABI level
    // means the pointer inside Local<Name> is what gets passed.
    // This pointer points to a V8 internal object.
    // We can safely cast this to Value* and call IsString() through operator->
    
    // The `name` parameter is the internal pointer from Local<Name>.
    // In V8's implementation, calling operator-> on a Local<> returns the internal pointer.
    // So we can treat `name` as if it were the result of local_name.operator->()
    
    const Value* value = reinterpret_cast<const Value*>(name);
    return value->IsString();
}

// String functions for raw pointers (from callbacks)
int v8_String_Utf8Length_Raw(const void* str) {
    Isolate* isolate = Isolate::GetCurrent();
    // str is the internal V8 String pointer
    const String* string_ptr = reinterpret_cast<const String*>(str);
    return string_ptr->Utf8Length(isolate);
}

int v8_String_WriteUtf8_Raw(const void* str, char* buffer, int length) {
    Isolate* isolate = Isolate::GetCurrent();
    const String* string_ptr = reinterpret_cast<const String*>(str);
    return string_ptr->WriteUtf8(isolate, buffer, length);
}

// ============================================================================
// Object Property Descriptor Functions
// ============================================================================

bool v8_Object_DefineProperty(Global<Object>* object, Global<Context>* context, Global<Value>* key,
                               Global<Value>* value, bool writable, bool enumerable, bool configurable) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Name> name = key->Get(isolate).As<Name>();
    Local<Value> val = value->Get(isolate);
    
    // Create property descriptor
    v8::PropertyAttribute attributes = v8::None;
    if (!writable) attributes = static_cast<v8::PropertyAttribute>(attributes | v8::ReadOnly);
    if (!enumerable) attributes = static_cast<v8::PropertyAttribute>(attributes | v8::DontEnum);
    if (!configurable) attributes = static_cast<v8::PropertyAttribute>(attributes | v8::DontDelete);
    
    return obj->DefineOwnProperty(ctx, name, val, attributes).FromMaybe(false);
}

// ============================================================================
// Object Extensibility Functions
// ============================================================================

bool v8_Object_PreventExtensions(Global<Object>* object, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    return obj->SetIntegrityLevel(ctx, v8::IntegrityLevel::kSealed).FromMaybe(false);
}

// ============================================================================
// Symbol Functions
// ============================================================================

Global<Symbol>* v8_Symbol_GetToStringTag(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Symbol> symbol = Symbol::GetToStringTag(isolate);
    return new Global<Symbol>(isolate, symbol);
}

Global<Symbol>* v8_Symbol_GetIterator(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Symbol> symbol = Symbol::GetIterator(isolate);
    return new Global<Symbol>(isolate, symbol);
}

} // extern "C"

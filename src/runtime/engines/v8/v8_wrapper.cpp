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

// ============================================================================
// Weak Callback Support (must be outside extern "C")
// ============================================================================

/// Weak callback function type (matches Zig WeakCallbackFn)
typedef void (*ZigWeakCallbackFn)(void* data, size_t length_in_bytes);

/// Weak callback data structure
struct WeakCallbackData {
    ZigWeakCallbackFn callback;
    void* user_data;
};

/// Internal weak callback wrapper - V8 calls this, which then calls the Zig callback
template<typename T>
static void WeakCallbackWrapper(const WeakCallbackInfo<WeakCallbackData>& info) {
    WeakCallbackData* data = info.GetParameter();
    
    if (data && data->callback) {
        // Call the Zig finalizer with user data
        data->callback(data->user_data, 0);
        
        // Clean up the wrapper data
        delete data;
    }
}

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

Isolate* v8_Isolate_GetCurrent() {
    return Isolate::GetCurrent();
}

// Get the raw internal address of a context (for stable identity)
// Returns a unique identifier for the context that stays constant across Global/Local conversions
void* v8_Context_GetRawAddress(Global<Context>* context_handle) {
    // Get the internal V8 context pointer from the Global handle
    // This address is stable and can be used as a HashMap key
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context_handle->Get(isolate);
    // Return the raw internal pointer - this is stable across handle conversions
    return *reinterpret_cast<void**>(*ctx);
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

bool v8_Value_IsFunction(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsFunction();
}

bool v8_Value_IsArray(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsArray();
}

bool v8_Value_IsPromise(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsPromise();
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

int v8_Object_InternalFieldCount(Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    return local_obj->InternalFieldCount();
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

Global<Value>* v8_Exception_SyntaxError(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::SyntaxError(msg);
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

Global<Value>* v8_Boolean_New(Isolate* isolate, bool value) {
    HandleScope handle_scope(isolate);
    Local<Boolean> bool_val = Boolean::New(isolate, value);
    return new Global<Value>(isolate, bool_val);
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

// Create FunctionTemplate with Signature (receiver type checking)
// The signature ensures the callback is only called when 'this' is an instance
// of the receiver template (or a subclass via inheritance).
Global<FunctionTemplate>* v8_FunctionTemplate_NewWithSignature(
    Isolate* isolate,
    ZigCallback callback,
    Global<Value>* data,
    Global<FunctionTemplate>* receiver
) {
    HandleScope handle_scope(isolate);
    
    // Create signature from receiver template
    Local<FunctionTemplate> receiver_local = receiver->Get(isolate);
    Local<Signature> signature = Signature::New(isolate, receiver_local);
    
    // Create function template with signature
    Local<FunctionTemplate> tpl = FunctionTemplate::New(
        isolate,
        reinterpret_cast<FunctionCallback>(callback),
        data ? data->Get(isolate) : Local<Value>(),
        signature  // V8 will enforce receiver type
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

// FunctionCallbackInfo - get callback data
Global<Value>* v8_FunctionCallbackInfo_Data(const FunctionCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Value> data = info->Data();
    return new Global<Value>(isolate, data);
}

// ============================================================================
// External - Wrap C pointers for storage in V8
// ============================================================================

// Create External value wrapping a C pointer
Global<External>* v8_External_New(Isolate* isolate, void* value) {
    HandleScope handle_scope(isolate);
    Local<External> external = External::New(isolate, value);
    return new Global<External>(isolate, external);
}

// Extract wrapped pointer from External
void* v8_External_Value(Global<External>* external) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<External> local_ext = external->Get(isolate);
    return local_ext->Value();
}

// Dispose External
void v8_External_Dispose(Global<External>* external) {
    if (external) {
        external->Reset();
        delete external;
    }
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
//
// Uses FunctionCallback directly (same as methods) to avoid PropertyCallbackInfo issues.
// Getter: receives no arguments, returns value via info.GetReturnValue()
// Setter: receives new value as info[0], sets it on the object
void v8_ObjectTemplate_SetAccessorProperty(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    FunctionCallback getter,
    FunctionCallback setter
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<Name> key = name->Get(isolate).As<Name>();
    
    // Create FunctionTemplate for getter using the callback directly
    // No wrapping or casting needed - FunctionCallback is the native type
    Local<FunctionTemplate> getter_tpl = FunctionTemplate::New(
        isolate,
        getter,
        Local<Value>()  // No data needed
    );
    
    // Create FunctionTemplate for setter (if provided)
    Local<FunctionTemplate> setter_tpl;
    if (setter != nullptr) {
        setter_tpl = FunctionTemplate::New(
            isolate,
            setter,
            Local<Value>()  // No data needed
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

// ObjectTemplate - set indexed property handler (for array-like access: obj[0], obj[1], etc.)
void v8_ObjectTemplate_SetIndexedPropertyHandler(
    Global<ObjectTemplate>* tpl,
    IndexedPropertyGetterCallbackV2 getter
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    local_tpl->SetHandler(IndexedPropertyHandlerConfiguration(
        getter,
        nullptr,  // setter callback (read-only for now)
        nullptr,  // query callback (not needed)
        nullptr,  // deleter callback (not needed)
        nullptr,  // enumerator callback (not needed)
        nullptr,  // definer callback (not needed)
        nullptr,  // descriptor callback (not needed)
        Local<Value>(),  // data (not needed)
        PropertyHandlerFlags::kNone
    ));
}

// ObjectTemplate - create instance from template
Global<Object>* v8_ObjectTemplate_NewInstance(Global<ObjectTemplate>* tpl, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<Context> local_ctx = context->Get(isolate);
    Context::Scope context_scope(local_ctx);
    
    MaybeLocal<Object> maybe_obj = local_tpl->NewInstance(local_ctx);
    if (maybe_obj.IsEmpty()) {
        return nullptr;
    }
    return new Global<Object>(isolate, maybe_obj.ToLocalChecked());
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

// Object internal field functions for raw/local pointers (from callbacks)
// Used in property interceptors where we have Local<Object> not Global<Object>
int v8_Object_InternalFieldCount_Raw(const void* obj) {
    // Cast to non-const since V8 API requires it
    Object* object_ptr = const_cast<Object*>(reinterpret_cast<const Object*>(obj));
    return object_ptr->InternalFieldCount();
}

void* v8_Object_GetAlignedPointerFromInternalField_Raw(const void* obj, int index) {
    // Cast to non-const since V8 API requires it
    Object* object_ptr = const_cast<Object*>(reinterpret_cast<const Object*>(obj));
    return object_ptr->GetAlignedPointerFromInternalField(index);
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

// Number value extraction for raw pointers (from callbacks/anyopaque)
// This works with Global<Value>* handles that are passed through as void*
double v8_Value_NumberValue_Raw(const void* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    // The value is a Global<Value>* passed as void*
    const Global<Value>* global_value = reinterpret_cast<const Global<Value>*>(value);
    Local<Value> val = global_value->Get(isolate);
    
    // Get the current context
    Local<Context> ctx = isolate->GetCurrentContext();
    
    Maybe<double> maybe_num = val->NumberValue(ctx);
    return maybe_num.FromMaybe(std::nan(""));
}

// String length extraction for raw pointers (from callbacks/anyopaque)
// Returns -1 if not a string, otherwise returns UTF-8 byte length
int v8_Value_StringLength_Raw(const void* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    const Global<Value>* global_value = reinterpret_cast<const Global<Value>*>(value);
    Local<Value> val = global_value->Get(isolate);
    
    if (!val->IsString()) {
        return -1;
    }
    
    Local<String> str = val.As<String>();
    return str->Utf8Length(isolate);
}

// String value extraction for raw pointers (from callbacks/anyopaque)
// Writes UTF-8 to buffer, returns bytes written. buffer_len should include space for null terminator.
int v8_Value_StringWriteUtf8_Raw(const void* value, char* buffer, int buffer_len) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    const Global<Value>* global_value = reinterpret_cast<const Global<Value>*>(value);
    Local<Value> val = global_value->Get(isolate);
    
    if (!val->IsString()) {
        if (buffer_len > 0) buffer[0] = '\0';
        return 0;
    }
    
    Local<String> str = val.As<String>();
    int flags = String::NO_NULL_TERMINATION;
    return str->WriteUtf8(isolate, buffer, buffer_len, nullptr, flags);
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
// Object Prototype Functions
// ============================================================================

bool v8_Object_SetPrototype(Global<Object>* object, Global<Context>* context, Global<Value>* prototype) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> proto = prototype->Get(isolate);
    
    return obj->SetPrototype(ctx, proto).FromMaybe(false);
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

Global<Symbol>* v8_Symbol_GetAsyncIterator(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Symbol> symbol = Symbol::GetAsyncIterator(isolate);
    return new Global<Symbol>(isolate, symbol);
}

void v8_Symbol_Dispose(Global<Symbol>* symbol) {
    delete symbol;
}

Global<Value>* v8_Object_GetPropertyWithSymbol(
    Global<Context>* context,
    Global<Object>* obj,
    Global<Symbol>* symbol
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> object = obj->Get(isolate);
    Local<Symbol> sym = symbol->Get(isolate);
    
    MaybeLocal<Value> result = object->Get(ctx, sym);
    if (result.IsEmpty()) {
        return nullptr;
    }
    
    return new Global<Value>(isolate, result.ToLocalChecked());
}

bool v8_Object_Has(
    Global<Context>* context,
    Global<Object>* obj,
    const char* key
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> object = obj->Get(isolate);
    Local<String> key_str = String::NewFromUtf8(isolate, key).ToLocalChecked();
    
    Maybe<bool> result = object->Has(ctx, key_str);
    return result.FromMaybe(false);
}

Global<Value>* v8_Function_CallWithReceiver(
    Global<Context>* context,
    Global<Function>* function,
    Global<Value>* receiver,
    int argc,
    Global<Value>** argv
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Function> fn = function->Get(isolate);
    Local<Value> recv = receiver ? receiver->Get(isolate) : Undefined(isolate).As<Value>();
    
    std::vector<Local<Value>> args;
    args.reserve(argc);
    for (int i = 0; i < argc; i++) {
        args.push_back(argv[i]->Get(isolate));
    }
    
    MaybeLocal<Value> result = fn->Call(ctx, recv, argc, args.data());
    if (result.IsEmpty()) {
        return nullptr;
    }
    
    return new Global<Value>(isolate, result.ToLocalChecked());
}

// ============================================================================
// Microtask Functions (Event Loop Integration)
// ============================================================================

/// Enqueue a microtask callback
///
/// Microtasks are high-priority tasks that run before the next JavaScript task.
/// This is used for promise reactions, mutation observers, etc.
///
/// The callback will be invoked with the provided data pointer.
/// The caller is responsible for managing the lifetime of data.
void v8_Isolate_EnqueueMicrotask(
    Isolate* isolate,
    void (*callback)(void*),
    void* data
) {
    // V8 expects a C function pointer, not a C++ lambda
    isolate->EnqueueMicrotask(callback, data);
}

/// Perform a microtask checkpoint
///
/// This runs all pending microtasks to completion. If microtasks enqueue
/// additional microtasks, those are also executed before returning.
///
/// This implements "perform a microtask checkpoint" from HTML spec:
/// https://html.spec.whatwg.org/#perform-a-microtask-checkpoint
void v8_Isolate_PerformMicrotaskCheckpoint(Isolate* isolate) {
    isolate->PerformMicrotaskCheckpoint();
}

/// Set the microtasks policy for the isolate
///
/// - kExplicit: Microtasks must be explicitly run via PerformMicrotaskCheckpoint
/// - kScoped: Microtasks run automatically at the end of each MicrotasksScope
/// - kAuto: Microtasks run automatically (deprecated, use kScoped)
///
/// Default is kAuto for backward compatibility.
/// For embedder control, use kExplicit.
void v8_Isolate_SetMicrotasksPolicy(Isolate* isolate, int policy) {
    MicrotasksPolicy v8_policy;
    switch (policy) {
        case 0: v8_policy = MicrotasksPolicy::kExplicit; break;
        case 1: v8_policy = MicrotasksPolicy::kScoped; break;
        case 2: v8_policy = MicrotasksPolicy::kAuto; break;
        default: return;  // Invalid policy
    }
    isolate->SetMicrotasksPolicy(v8_policy);
}

// ============================================================================
// Function Call Support (Phase 1: Runtime Callback Infrastructure)
// ============================================================================

/// Call a JavaScript function from native code
///
/// This enables Zig to invoke JavaScript callbacks, which is essential for
/// Streams API callbacks (write_algorithm, pull_algorithm, etc.).
///
/// @param function - The JavaScript function to call
/// @param context - The V8 context in which to execute the call
/// @param recv - The 'this' value for the function call (use v8_Undefined for no 'this')
/// @param argc - Number of arguments to pass
/// @param argv - Array of argument values
/// @return The return value from the function call, or nullptr if an exception occurred
Global<Value>* v8_Function_Call(
    Global<Function>* function,
    Global<Context>* context,
    Global<Value>* recv,
    int argc,
    Global<Value>** argv
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    // Convert Global handles to Local handles
    Local<Function> fn = function->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> this_val = recv->Get(isolate);
    
    // Convert argument array from Global to Local
    Local<Value>* local_argv = new Local<Value>[argc];
    for (int i = 0; i < argc; i++) {
        local_argv[i] = argv[i]->Get(isolate);
    }
    
    // Call the function
    MaybeLocal<Value> maybe_result = fn->Call(ctx, this_val, argc, local_argv);
    
    // Clean up local argument array
    delete[] local_argv;
    
    // Check for exception
    if (maybe_result.IsEmpty()) {
        return nullptr;  // Exception occurred
    }
    
    // Return the result as a Global handle
    Local<Value> result = maybe_result.ToLocalChecked();
    return new Global<Value>(isolate, result);
}

// ============================================================================
// Promise API (Phase 2: Runtime Callback Infrastructure  
// ============================================================================

/// Create a new Promise resolver
Global<Promise::Resolver>* v8_PromiseResolver_New(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    MaybeLocal<Promise::Resolver> maybe_resolver = Promise::Resolver::New(ctx);
    if (maybe_resolver.IsEmpty()) {
        return nullptr;
    }
    
    Local<Promise::Resolver> resolver = maybe_resolver.ToLocalChecked();
    return new Global<Promise::Resolver>(isolate, resolver);
}

/// Get Promise from resolver
Global<Promise>* v8_PromiseResolver_GetPromise(Global<Promise::Resolver>* resolver) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Promise::Resolver> res = resolver->Get(isolate);
    Local<Promise> promise = res->GetPromise();
    return new Global<Promise>(isolate, promise);
}

/// Resolve a Promise with a value
bool v8_PromiseResolver_Resolve(
    Global<Promise::Resolver>* resolver,
    Global<Context>* context,
    Global<Value>* value
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Promise::Resolver> res = resolver->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = value->Get(isolate);
    
    Maybe<bool> result = res->Resolve(ctx, val);
    return result.FromMaybe(false);
}

/// Reject a Promise with a reason
bool v8_PromiseResolver_Reject(
    Global<Promise::Resolver>* resolver,
    Global<Context>* context,
    Global<Value>* reason
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Promise::Resolver> res = resolver->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> val = reason->Get(isolate);
    
    Maybe<bool> result = res->Reject(ctx, val);
    return result.FromMaybe(false);
}

/// Chain a .then() handler to a Promise
Global<Promise>* v8_Promise_Then(
    Global<Promise>* promise,
    Global<Context>* context,
    Global<Function>* on_fulfilled,
    Global<Function>* on_rejected
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Promise> prom = promise->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Function> fulfilled = on_fulfilled ? on_fulfilled->Get(isolate) : Local<Function>();
    Local<Function> rejected = on_rejected ? on_rejected->Get(isolate) : Local<Function>();
    
    MaybeLocal<Promise> maybe_result = prom->Then(ctx, fulfilled, rejected);
    if (maybe_result.IsEmpty()) {
        return nullptr;
    }
    
    Local<Promise> result = maybe_result.ToLocalChecked();
    return new Global<Promise>(isolate, result);
}

/// Chain a .catch() handler to a Promise
Global<Promise>* v8_Promise_Catch(
    Global<Promise>* promise,
    Global<Context>* context,
    Global<Function>* on_rejected
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Promise> prom = promise->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Function> rejected = on_rejected->Get(isolate);
    
    MaybeLocal<Promise> maybe_result = prom->Catch(ctx, rejected);
    if (maybe_result.IsEmpty()) {
        return nullptr;
    }
    
    Local<Promise> result = maybe_result.ToLocalChecked();
    return new Global<Promise>(isolate, result);
}

/// Dispose a Promise
void v8_Promise_Dispose(Global<Promise>* promise) {
    if (promise) {
        promise->Reset();
        delete promise;
    }
}

/// Dispose a PromiseResolver
void v8_PromiseResolver_Dispose(Global<Promise::Resolver>* resolver) {
    if (resolver) {
        resolver->Reset();
        delete resolver;
    }
}

// ============================================================================
// Promise Handler Creation (Phase 3: Callback Utilities)
// ============================================================================

/// Create a function that resolves a PromiseResolver
///
/// Returns a JavaScript function that, when called, resolves the given
/// PromiseResolver with its first argument.
///
/// Used for chaining Promises: source.then(createResolveHandler(target))
Global<Function>* v8_PromiseResolver_CreateResolveHandler(
    Global<Context>* context,
    Global<Promise::Resolver>* resolver
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Create External to hold resolver pointer
    // NOTE: We're storing a raw pointer - caller must ensure resolver outlives handler
    Local<External> data = External::New(isolate, resolver);
    
    // Create callback that resolves the PromiseResolver
    auto callback = [](const FunctionCallbackInfo<Value>& info) {
        Isolate* isolate = info.GetIsolate();
        HandleScope scope(isolate);
        
        // Extract resolver from data
        Local<External> external = Local<External>::Cast(info.Data());
        auto* resolver = static_cast<Global<Promise::Resolver>*>(external->Value());
        
        // Get value argument (or undefined if no args)
        Local<Value> value = info.Length() > 0 ? info[0] : Undefined(isolate).As<Value>();
        
        // Resolve the Promise
        Local<Promise::Resolver> res = resolver->Get(isolate);
        Local<Context> ctx = isolate->GetCurrentContext();
        Maybe<bool> result = res->Resolve(ctx, value);
        
        // Return undefined
        info.GetReturnValue().SetUndefined();
    };
    
    // Create FunctionTemplate
    Local<FunctionTemplate> tpl = FunctionTemplate::New(isolate, callback, data);
    MaybeLocal<Function> maybe_fn = tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        return nullptr;
    }
    
    Local<Function> fn = maybe_fn.ToLocalChecked();
    return new Global<Function>(isolate, fn);
}

/// Create a function that rejects a PromiseResolver
///
/// Returns a JavaScript function that, when called, rejects the given
/// PromiseResolver with its first argument.
///
/// Used for chaining Promises: source.catch(createRejectHandler(target))
Global<Function>* v8_PromiseResolver_CreateRejectHandler(
    Global<Context>* context,
    Global<Promise::Resolver>* resolver
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Create External to hold resolver pointer
    Local<External> data = External::New(isolate, resolver);
    
    // Create callback that rejects the PromiseResolver
    auto callback = [](const FunctionCallbackInfo<Value>& info) {
        Isolate* isolate = info.GetIsolate();
        HandleScope scope(isolate);
        
        // Extract resolver from data
        Local<External> external = Local<External>::Cast(info.Data());
        auto* resolver = static_cast<Global<Promise::Resolver>*>(external->Value());
        
        // Get reason argument (or undefined if no args)
        Local<Value> reason = info.Length() > 0 ? info[0] : Undefined(isolate).As<Value>();
        
        // Reject the Promise
        Local<Promise::Resolver> res = resolver->Get(isolate);
        Local<Context> ctx = isolate->GetCurrentContext();
        Maybe<bool> result = res->Reject(ctx, reason);
        
        // Return undefined
        info.GetReturnValue().SetUndefined();
    };
    
    // Create FunctionTemplate
    Local<FunctionTemplate> tpl = FunctionTemplate::New(isolate, callback, data);
    MaybeLocal<Function> maybe_fn = tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        return nullptr;
    }
    
    Local<Function> fn = maybe_fn.ToLocalChecked();
    return new Global<Function>(isolate, fn);
}

// ============================================================================
// ArrayBuffer API (Phase 4: Runtime Infrastructure)
// ============================================================================

/// Create a new ArrayBuffer
///
/// Allocates a V8 ArrayBuffer with the specified byte length.
/// Caller must call v8_ArrayBuffer_Dispose when done.
Global<ArrayBuffer>* v8_ArrayBuffer_New(Isolate* isolate, size_t byte_length) {
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> buffer = ArrayBuffer::New(isolate, byte_length);
    return new Global<ArrayBuffer>(isolate, buffer);
}

/// Get ArrayBuffer backing store pointer
///
/// Returns a pointer to the raw memory backing the ArrayBuffer.
/// Valid only while the ArrayBuffer is not detached.
void* v8_ArrayBuffer_Data(Global<ArrayBuffer>* buffer) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> buf = buffer->Get(isolate);
    
    // Get backing store
    std::shared_ptr<BackingStore> backing_store = buf->GetBackingStore();
    if (!backing_store) {
        return nullptr;
    }
    return backing_store->Data();
}

/// Get ArrayBuffer byte length
size_t v8_ArrayBuffer_ByteLength(Global<ArrayBuffer>* buffer) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> buf = buffer->Get(isolate);
    return buf->ByteLength();
}

/// Check if ArrayBuffer is detached
bool v8_ArrayBuffer_IsDetached(Global<ArrayBuffer>* buffer) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> buf = buffer->Get(isolate);
    return buf->WasDetached();
}

/// Detach an ArrayBuffer
///
/// Transfers ownership of the backing store, making the ArrayBuffer unusable.
/// Used for transferable ArrayBuffers in postMessage and structured clone.
void v8_ArrayBuffer_Detach(Global<ArrayBuffer>* buffer) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> buf = buffer->Get(isolate);
    
    // Detach with no key (nullptr indicates default detach)
    Maybe<bool> result = buf->Detach(Local<Value>());
    (void)result; // Ignore result for now
}

/// Dispose ArrayBuffer
void v8_ArrayBuffer_Dispose(Global<ArrayBuffer>* buffer) {
    if (buffer) {
        buffer->Reset();
        delete buffer;
    }
}

// ============================================================================
// TypedArray API (Phase 4: ArrayBufferView Introspection)
// ============================================================================

/// Check if Value is a Uint8Array
bool v8_Value_IsUint8Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsUint8Array();
}

/// Check if Value is an Int8Array
bool v8_Value_IsInt8Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsInt8Array();
}

/// Check if Value is a Uint16Array
bool v8_Value_IsUint16Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsUint16Array();
}

/// Check if Value is an Int16Array
bool v8_Value_IsInt16Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsInt16Array();
}

/// Check if Value is a Uint32Array
bool v8_Value_IsUint32Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsUint32Array();
}

/// Check if Value is an Int32Array
bool v8_Value_IsInt32Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsInt32Array();
}

/// Check if Value is a Float32Array
bool v8_Value_IsFloat32Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsFloat32Array();
}

/// Check if Value is a Float64Array
bool v8_Value_IsFloat64Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsFloat64Array();
}

/// Check if Value is a Uint8ClampedArray
bool v8_Value_IsUint8ClampedArray(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsUint8ClampedArray();
}

/// Check if Value is a BigInt64Array
bool v8_Value_IsBigInt64Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsBigInt64Array();
}

/// Check if Value is a BigUint64Array
bool v8_Value_IsBigUint64Array(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsBigUint64Array();
}

/// Check if Value is any TypedArray
bool v8_Value_IsTypedArray(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsTypedArray();
}

/// Check if Value is a DataView
bool v8_Value_IsDataView(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsDataView();
}

/// Get the ArrayBuffer from a TypedArray
///
/// Returns the underlying ArrayBuffer that the TypedArray is viewing.
/// Caller must call v8_ArrayBuffer_Dispose when done.
Global<ArrayBuffer>* v8_TypedArray_Buffer(Global<Value>* typed_array) {
    if (!typed_array) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = typed_array->Get(isolate);
    
    if (!val->IsTypedArray()) {
        return nullptr;
    }
    
    Local<TypedArray> ta = val.As<TypedArray>();
    Local<ArrayBuffer> buffer = ta->Buffer();
    return new Global<ArrayBuffer>(isolate, buffer);
}

/// Get TypedArray byte length
///
/// Returns the number of bytes in the TypedArray view.
/// Returns 0 if the view is detached or invalid.
size_t v8_TypedArray_ByteLength(Global<Value>* typed_array) {
    if (!typed_array) return 0;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = typed_array->Get(isolate);
    
    if (!val->IsTypedArray()) {
        return 0;
    }
    
    Local<TypedArray> ta = val.As<TypedArray>();
    return ta->ByteLength();
}

/// Get TypedArray byte offset
///
/// Returns the offset in bytes from the start of the ArrayBuffer.
size_t v8_TypedArray_ByteOffset(Global<Value>* typed_array) {
    if (!typed_array) return 0;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = typed_array->Get(isolate);
    
    if (!val->IsTypedArray()) {
        return 0;
    }
    
    Local<TypedArray> ta = val.As<TypedArray>();
    return ta->ByteOffset();
}

/// Get TypedArray length (element count)
///
/// Returns the number of elements in the TypedArray.
/// Not the same as ByteLength (ByteLength = Length * ElementSize).
size_t v8_TypedArray_Length(Global<Value>* typed_array) {
    if (!typed_array) return 0;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = typed_array->Get(isolate);
    
    if (!val->IsTypedArray()) {
        return 0;
    }
    
    Local<TypedArray> ta = val.As<TypedArray>();
    return ta->Length();
}

// ============================================================================
// TypedArray Construction
// ============================================================================

/// Create a Uint8Array view over an ArrayBuffer
///
/// @param isolate - V8 isolate
/// @param buffer - The ArrayBuffer to view
/// @param byte_offset - Offset into the buffer
/// @param length - Number of elements (bytes for Uint8Array)
/// @return Global handle to new Uint8Array, or null on error
Global<Value>* v8_Uint8Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Uint8Array> arr = Uint8Array::New(local_buffer, byte_offset, length);
    return new Global<Value>(isolate, arr);
}

/// Create an Int8Array view over an ArrayBuffer
Global<Value>* v8_Int8Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Int8Array> arr = Int8Array::New(local_buffer, byte_offset, length);
    return new Global<Value>(isolate, arr);
}

/// Create a Uint8ClampedArray view over an ArrayBuffer
Global<Value>* v8_Uint8ClampedArray_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Uint8ClampedArray> arr = Uint8ClampedArray::New(local_buffer, byte_offset, length);
    return new Global<Value>(isolate, arr);
}

/// Create a Uint16Array view over an ArrayBuffer
Global<Value>* v8_Uint16Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Uint16Array> arr = Uint16Array::New(local_buffer, byte_offset, length);
    return new Global<Value>(isolate, arr);
}

/// Create an Int16Array view over an ArrayBuffer
Global<Value>* v8_Int16Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Int16Array> arr = Int16Array::New(local_buffer, byte_offset, length);
    return new Global<Value>(isolate, arr);
}

/// Create a Uint32Array view over an ArrayBuffer
Global<Value>* v8_Uint32Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Uint32Array> arr = Uint32Array::New(local_buffer, byte_offset, length);
    return new Global<Value>(isolate, arr);
}

/// Create an Int32Array view over an ArrayBuffer
Global<Value>* v8_Int32Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Int32Array> arr = Int32Array::New(local_buffer, byte_offset, length);
    return new Global<Value>(isolate, arr);
}

/// Create a Float32Array view over an ArrayBuffer
Global<Value>* v8_Float32Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Float32Array> arr = Float32Array::New(local_buffer, byte_offset, length);
    return new Global<Value>(isolate, arr);
}

/// Create a Float64Array view over an ArrayBuffer
Global<Value>* v8_Float64Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Float64Array> arr = Float64Array::New(local_buffer, byte_offset, length);
    return new Global<Value>(isolate, arr);
}

/// Create a BigInt64Array view over an ArrayBuffer
Global<Value>* v8_BigInt64Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<BigInt64Array> arr = BigInt64Array::New(local_buffer, byte_offset, length);
    return new Global<Value>(isolate, arr);
}

/// Create a BigUint64Array view over an ArrayBuffer
Global<Value>* v8_BigUint64Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<BigUint64Array> arr = BigUint64Array::New(local_buffer, byte_offset, length);
    return new Global<Value>(isolate, arr);
}

/// Create a DataView over an ArrayBuffer
Global<Value>* v8_DataView_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t byte_length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<DataView> view = DataView::New(local_buffer, byte_offset, byte_length);
    return new Global<Value>(isolate, view);
}

// ============================================================================
// Weak Callbacks / Finalizers
// ============================================================================

/// Make a Global handle weak with a finalizer callback
void v8_Global_SetWeak(void* handle, void* user_data, ZigWeakCallbackFn callback) {
    if (!handle || !callback) return;
    
    // Cast to Global<Value>* (all Global types are compatible for SetWeak)
    Global<Value>* global = reinterpret_cast<Global<Value>*>(handle);
    
    // Create wrapper data that holds both the callback and user data
    WeakCallbackData* wrapper = new WeakCallbackData{callback, user_data};
    
    // Make the Global handle weak with our wrapper callback
    global->SetWeak(wrapper, WeakCallbackWrapper<Value>, WeakCallbackType::kParameter);
}

/// Clear weak reference and restore strong reference
void v8_Global_ClearWeak(void* handle) {
    if (!handle) return;
    
    Global<Value>* global = reinterpret_cast<Global<Value>*>(handle);
    global->ClearWeak();
}

// ============================================================================
// Async Iterator Support
// ============================================================================

/// Zig async iterator next callback type
/// Returns a V8 Promise that resolves to { value, done }
typedef Global<Promise>* (*ZigAsyncIteratorNextFn)(
    Isolate* isolate,
    Global<Context>* context,
    void* iterator_ptr
);

/// Zig async iterator return callback type
/// Returns a V8 Promise that resolves to { value: undefined, done: true }
typedef Global<Promise>* (*ZigAsyncIteratorReturnFn)(
    Isolate* isolate,
    Global<Context>* context,
    void* iterator_ptr
);

/// Internal storage for async iterator callbacks
struct AsyncIteratorData {
    void* iterator_ptr;              // Zig iterator pointer
    ZigAsyncIteratorNextFn next_fn;  // Callback for next()
    ZigAsyncIteratorReturnFn return_fn; // Callback for return()
};

/// Callback wrapper for async iterator next() method
static void AsyncIteratorNextCallback(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    
    // Extract iterator data from function's data (passed via External)
    Local<Value> data_value = info.Data();
    if (!data_value->IsExternal()) {
        isolate->ThrowException(Exception::TypeError(
            String::NewFromUtf8Literal(isolate, "Invalid async iterator callback data")
        ));
        return;
    }
    
    Local<External> external = Local<External>::Cast(data_value);
    AsyncIteratorData* data = static_cast<AsyncIteratorData*>(external->Value());
    

    
    if (!data || !data->next_fn) {
        isolate->ThrowException(Exception::TypeError(
            String::NewFromUtf8Literal(isolate, "Async iterator not properly initialized")
        ));
        return;
    }
    
    // Get current context as Global handle
    // NOTE: Do NOT delete this context handle immediately after calling the Zig function.
    // The Zig code stores this context pointer in a PromiseBridge and uses it later
    // when resolving the promise (in a microtask). Deleting it here causes use-after-free.
    // The context handle will be managed by V8's GC - we intentionally don't delete it.
    Local<Context> local_context = isolate->GetCurrentContext();
    Global<Context>* context = new Global<Context>(isolate, local_context);
    
    // Call Zig next function - it returns a V8 Promise
    Global<Promise>* promise_global = data->next_fn(isolate, context, data->iterator_ptr);
    
    if (!promise_global) {
        isolate->ThrowException(Exception::Error(
            String::NewFromUtf8Literal(isolate, "Iterator next() failed")
        ));
        return;
    }
    
    // Convert Global promise to Local
    Local<Promise> promise = promise_global->Get(isolate);
    
    // Return the promise directly (it already resolves to { value, done })
    info.GetReturnValue().Set(promise);
}

/// Callback wrapper for async iterator return() method
static void AsyncIteratorReturnCallback(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    
    // Extract iterator data from function's data (passed via External)
    Local<Value> data_value = info.Data();
    if (!data_value->IsExternal()) {
        isolate->ThrowException(Exception::TypeError(
            String::NewFromUtf8Literal(isolate, "Invalid async iterator callback data")
        ));
        return;
    }
    
    Local<External> external = Local<External>::Cast(data_value);
    AsyncIteratorData* data = static_cast<AsyncIteratorData*>(external->Value());
    
    if (!data || !data->return_fn) {
        isolate->ThrowException(Exception::TypeError(
            String::NewFromUtf8Literal(isolate, "Async iterator not properly initialized")
        ));
        return;
    }
    
    // Get current context as Global handle
    // NOTE: Do NOT delete this context handle immediately after calling the Zig function.
    // Same reason as in AsyncIteratorNextCallback - the context is stored in PromiseBridge.
    Local<Context> local_context = isolate->GetCurrentContext();
    Global<Context>* context = new Global<Context>(isolate, local_context);
    
    // Call Zig return function - it returns a V8 Promise
    Global<Promise>* promise_global = data->return_fn(isolate, context, data->iterator_ptr);
    
    if (!promise_global) {
        isolate->ThrowException(Exception::Error(
            String::NewFromUtf8Literal(isolate, "Iterator return() failed")
        ));
        return;
    }
    
    // Convert Global promise to Local
    Local<Promise> promise = promise_global->Get(isolate);
    
    // Return the promise directly (it already resolves to { value: undefined, done: true })
    info.GetReturnValue().Set(promise);
}

/// Create a V8 async iterator object wrapping a Zig async iterator
///
/// Creates a JavaScript object with next() and return() methods that conform
/// to the ES async iterator protocol.
///
/// The object has an internal field storing AsyncIteratorData with:
/// - iterator_ptr: Opaque Zig iterator pointer
/// - next_fn: Zig callback for next() -> { value, done }
/// - return_fn: Zig callback for cleanup
///
/// JavaScript Usage:
///   const result = await iterator.next(); // { value: ..., done: false }
///   await iterator.return(); // Cleanup

// Cached async iterator template - ensures all iterators share the same constructor
static Global<FunctionTemplate>* g_async_iterator_template = nullptr;

/// Get or create the cached async iterator template
static Local<FunctionTemplate> getAsyncIteratorTemplate(Isolate* isolate) {
    if (g_async_iterator_template == nullptr) {
        // Create the template once and cache it
        Local<FunctionTemplate> tpl = FunctionTemplate::New(isolate);
        tpl->SetClassName(String::NewFromUtf8Literal(isolate, "ReadableStreamAsyncIterator"));
        tpl->InstanceTemplate()->SetInternalFieldCount(1);
        g_async_iterator_template = new Global<FunctionTemplate>(isolate, tpl);
    }
    return g_async_iterator_template->Get(isolate);
}

Global<Object>* v8_AsyncIterator_New(
    Isolate* isolate,
    Global<Context>* context,
    void* iterator_ptr,
    ZigAsyncIteratorNextFn next_fn,
    ZigAsyncIteratorReturnFn return_fn
) {
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Get the cached template - all iterators share this template
    Local<FunctionTemplate> tpl = getAsyncIteratorTemplate(isolate);
    
    // Create object instance from template's instance template
    Local<Object> obj = tpl->InstanceTemplate()->NewInstance(ctx).ToLocalChecked();
    
    // Allocate and store iterator data in internal field
    AsyncIteratorData* data = new AsyncIteratorData{
        iterator_ptr,
        next_fn,
        return_fn
    };
    obj->SetAlignedPointerInInternalField(0, data);
    

    
    // Wrap data pointer in External for passing to function callbacks
    Local<External> data_external = External::New(isolate, data);
    
    // Create 'next' method with data passed via External
    Local<String> next_name = String::NewFromUtf8Literal(isolate, "next");
    Local<FunctionTemplate> next_tpl = FunctionTemplate::New(isolate, AsyncIteratorNextCallback, data_external);
    Local<Function> next_fn_obj = next_tpl->GetFunction(ctx).ToLocalChecked();
    obj->Set(ctx, next_name, next_fn_obj).Check();
    
    // Create 'return' method with data passed via External
    Local<String> return_name = String::NewFromUtf8Literal(isolate, "return");
    Local<FunctionTemplate> return_tpl = FunctionTemplate::New(isolate, AsyncIteratorReturnCallback, data_external);
    Local<Function> return_fn_obj = return_tpl->GetFunction(ctx).ToLocalChecked();
    obj->Set(ctx, return_name, return_fn_obj).Check();
    
    // Add Symbol.asyncIterator that returns this object
    // This makes the object both an async iterator AND async iterable
    // so that `for await...of` works directly on the iterator object
    Local<Symbol> async_iterator_symbol = Symbol::GetAsyncIterator(isolate);
    Local<FunctionTemplate> self_tpl = FunctionTemplate::New(isolate, 
        [](const FunctionCallbackInfo<Value>& info) {
            // Return the iterator object itself (this)
            info.GetReturnValue().Set(info.This());
        });
    Local<Function> self_fn = self_tpl->GetFunction(ctx).ToLocalChecked();
    obj->Set(ctx, async_iterator_symbol, self_fn).Check();
    
    // Return as Global handle
    return new Global<Object>(isolate, obj);
}

/// Dispose an async iterator object and free its internal data
void v8_AsyncIterator_Dispose(Global<Object>* iterator) {
    if (!iterator) return;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> obj = iterator->Get(isolate);
    
    // Free internal AsyncIteratorData
    if (obj->InternalFieldCount() >= 1) {
        AsyncIteratorData* data = static_cast<AsyncIteratorData*>(
            obj->GetAlignedPointerFromInternalField(0)
        );
        if (data) {
            delete data;
            obj->SetAlignedPointerInInternalField(0, nullptr);
        }
    }
    
    // Dispose Global handle
    iterator->Reset();
    delete iterator;
}


// ============================================================================
// TestUtils API - GC for testing (WHATWG TestUtils Standard)
// ============================================================================

/// Request a full garbage collection on the isolate
///
/// This is for testing purposes only and should NOT be exposed to web content.
/// Per WHATWG TestUtils spec: https://testutils.spec.whatwg.org/
///
/// Note: V8's public API does not expose RequestGarbageCollectionForTesting
/// in production builds. We use LowMemoryNotification() which hints to V8
/// that it should perform GC as soon as possible.
///
/// This function is synchronous - LowMemoryNotification triggers immediate GC.
void v8_Isolate_RequestGarbageCollection(Isolate* isolate) {
    if (!isolate) return;
    
    // LowMemoryNotification triggers V8 to perform garbage collection
    // as aggressively as possible. Per V8 docs, this is a synchronous
    // call that attempts to reclaim as much memory as possible.
    isolate->LowMemoryNotification();
}

} // extern "C"

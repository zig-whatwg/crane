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
#include <v8-snapshot.h>
#include <libplatform/libplatform.h>
#include <cstring>
#include <string>
#include <vector>
#include <set>
#include <algorithm>
#include <execinfo.h>  // For backtrace on macOS/Linux

using namespace v8;

// Platform singleton
static std::unique_ptr<Platform> g_platform = nullptr;
static bool v8_initialized = false;

// ============================================================================
// Snapshot Mode Global Handle Tracking
// ============================================================================
//
// V8's SnapshotCreator::CreateBlob() requires that there be no outstanding
// Global handles when called. Since our wrapper returns Global<T>* from most
// functions, we need a way to track and dispose them before snapshot creation.
//
// When snapshot mode is enabled:
// 1. All Global handles created are tracked in a vector
// 2. Before calling CreateBlob(), call v8_Snapshot_ClearGlobalHandles() to reset them all
// 3. This allows V8 to serialize the heap without complaining about Global handles

static bool g_snapshot_mode = false;

// We store void* pointers along with type-specific reset functions
struct GlobalHandleEntry {
    void* handle;
    void (*reset_fn)(void*);
};
static std::vector<GlobalHandleEntry> g_snapshot_handles;

// Type-erased reset function template
template<typename T>
static void resetGlobalHandle(void* ptr) {
    Global<T>* handle = static_cast<Global<T>*>(ptr);
    handle->Reset();
    delete handle;
}

// Track a handle for snapshot cleanup
template<typename T>
static Global<T>* trackHandle(Global<T>* handle) {
    if (g_snapshot_mode && handle) {
        g_snapshot_handles.push_back({handle, resetGlobalHandle<T>});
    }
    return handle;
}

// ============================================================================
// Debug Alignment Checks
// ============================================================================
//
// V8 uses pointer tagging on some platforms (arm64). When Zig code receives
// tagged pointers and casts them with @alignCast, it can trigger alignment
// errors. These macros help detect misaligned pointers at the FFI boundary.
//
// Usage: CHECK_ALIGNMENT(ptr, Type) at the start of functions that receive
// Global<T>* pointers from Zig.

#ifdef NDEBUG
// Release build: no-op
#define CHECK_ALIGNMENT(ptr, type) ((void)0)
#define CHECK_ALIGNMENT_LOG(ptr, type, func_name) ((void)0)
#else
// Debug build: check alignment and log errors
#define CHECK_ALIGNMENT(ptr, type) \
    do { \
        if (ptr && (reinterpret_cast<uintptr_t>(ptr) & (alignof(type) - 1)) != 0) { \
            fprintf(stderr, "V8_WRAPPER: Misaligned pointer %p for type %s (requires %zu-byte alignment, got %zu)\n", \
                    static_cast<const void*>(ptr), #type, alignof(type), \
                    reinterpret_cast<uintptr_t>(ptr) & (alignof(type) - 1)); \
        } \
    } while (0)

#define CHECK_ALIGNMENT_LOG(ptr, type, func_name) \
    do { \
        if (ptr && (reinterpret_cast<uintptr_t>(ptr) & (alignof(type) - 1)) != 0) { \
            fprintf(stderr, "V8_WRAPPER[%s]: Misaligned pointer %p for type %s (requires %zu-byte alignment)\n", \
                    func_name, static_cast<const void*>(ptr), #type, alignof(type)); \
        } \
    } while (0)
#endif

// ============================================================================
// Weak Callback Support (must be outside extern "C")
// ============================================================================

/// Weak callback function type (matches Zig WeakCallbackFn)
typedef void (*ZigWeakCallbackFn)(void* data, size_t length_in_bytes);

/// Weak callback data structure
struct WeakCallbackData {
    ZigWeakCallbackFn callback;
    void* user_data;
    Global<Value>* handle;  // Store handle pointer so we can reset it
};

/// Internal weak callback wrapper - V8 calls this, which then calls the Zig callback
template<typename T>
static void WeakCallbackWrapper(const WeakCallbackInfo<WeakCallbackData>& info) {
    WeakCallbackData* data = info.GetParameter();
    
    if (data) {
        // CRITICAL: V8 requires that weak callbacks MUST reset the handle
        // before returning. Failure to do so causes "Handle not reset in first callback"
        // crashes during GC.
        if (data->handle) {
            data->handle->Reset();
        }
        
        // Call the Zig finalizer with user data
        if (data->callback) {
            data->callback(data->user_data, 0);
        }
        
        // Clean up the wrapper data
        delete data;
    }
}

// ============================================================================
// V8 Exception Information Structure
// ============================================================================
//
// When V8 operations throw JavaScript exceptions, we capture detailed error
// information including the message, stack trace, line/column numbers, and
// source line. This enables proper error reporting in Zig code.

struct V8ErrorInfo {
    bool has_error;
    char* message;         // malloc'd, Zig must free
    char* stack_trace;     // malloc'd, Zig must free
    int line_number;
    int column_number;
    char* source_line;     // malloc'd, Zig must free
    char* resource_name;   // malloc'd, Zig must free
};

/// Extract exception information from a TryCatch
///
/// This function extracts all available information from a V8 exception:
/// - The exception message
/// - Stack trace (if available)
/// - Line and column numbers
/// - Source line text
/// - Resource name (filename/URL)
///
/// The caller is responsible for freeing the returned struct with v8_FreeErrorInfo.
static V8ErrorInfo* extractException(Isolate* isolate, TryCatch* try_catch) {
    HandleScope handle_scope(isolate);
    
    V8ErrorInfo* info = new V8ErrorInfo();
    info->has_error = true;
    info->message = nullptr;
    info->stack_trace = nullptr;
    info->line_number = -1;
    info->column_number = -1;
    info->source_line = nullptr;
    info->resource_name = nullptr;
    
    // Extract exception message
    Local<Value> exception = try_catch->Exception();
    String::Utf8Value exception_str(isolate, exception);
    info->message = strdup(*exception_str ? *exception_str : "Unknown error");
    
    // Extract detailed message information
    Local<Message> message = try_catch->Message();
    if (!message.IsEmpty()) {
        Local<Context> ctx = isolate->GetCurrentContext();
        
        // Line and column numbers
        info->line_number = message->GetLineNumber(ctx).FromMaybe(-1);
        info->column_number = message->GetStartColumn();
        
        // Source line
        MaybeLocal<String> source_line_maybe = message->GetSourceLine(ctx);
        if (!source_line_maybe.IsEmpty()) {
            String::Utf8Value source(isolate, source_line_maybe.ToLocalChecked());
            info->source_line = strdup(*source ? *source : "");
        }
        
        // Resource name (filename/URL)
        Local<Value> resource = message->GetScriptResourceName();
        String::Utf8Value resource_str(isolate, resource);
        info->resource_name = strdup(*resource_str ? *resource_str : "<unknown>");
        
        // Full stack trace
        MaybeLocal<Value> stack_trace_maybe = try_catch->StackTrace(ctx);
        if (!stack_trace_maybe.IsEmpty()) {
            String::Utf8Value stack(isolate, stack_trace_maybe.ToLocalChecked());
            info->stack_trace = strdup(*stack ? *stack : "");
        }
    }
    
    return info;
}

extern "C" {

Global<Function>* v8_FunctionCallbackInfo_GetFunction(const FunctionCallbackInfo<Value>* info) {
    if (!info) return nullptr;
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    
    // FCILayout { implicit_args, values, length }
    struct FCILayout {
        internal::Address* implicit_args;
        internal::Address* values;
        internal::Address length;
    };
    const FCILayout* layout = reinterpret_cast<const FCILayout*>(info);
    internal::Address target_addr = layout->implicit_args[4]; // kTargetIndex
    Local<Value> target_val = *reinterpret_cast<Local<Value>*>(&target_addr);
    
    if (target_val.IsEmpty() || !target_val->IsFunction()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Function>(isolate, target_val.As<Function>()));
}

// ============================================================================
// V8ErrorInfo Functions
// ============================================================================

/// Free a V8ErrorInfo structure
///
/// Frees all strings allocated within the structure and the structure itself.
void v8_FreeErrorInfo(V8ErrorInfo* info) {
    if (!info) return;
    
    if (info->message) free(info->message);
    if (info->stack_trace) free(info->stack_trace);
    if (info->source_line) free(info->source_line);
    if (info->resource_name) free(info->resource_name);
    
    delete info;
}

// ============================================================================
// Safe Script/Module Operations with TryCatch
// ============================================================================
// These "_Safe" variants wrap V8 operations with TryCatch to capture exception
// details when operations fail. This enables proper error reporting in Zig.

/// Result structure for safe script compilation
struct V8ScriptCompileResult {
    Global<Script>* script;      // nullptr if compilation failed
    V8ErrorInfo* error;          // nullptr if compilation succeeded
};

/// Result structure for safe script execution
struct V8ScriptRunResult {
    Global<Value>* value;        // nullptr if execution failed
    V8ErrorInfo* error;          // nullptr if execution succeeded
};

/// Result structure for safe function calls
struct V8FunctionCallResult {
    Global<Value>* value;        // nullptr if call failed
    V8ErrorInfo* error;          // nullptr if call succeeded
};

/// Result structure for safe module compilation
struct V8ModuleCompileResult {
    Global<Module>* module;      // nullptr if compilation failed
    V8ErrorInfo* error;          // nullptr if compilation succeeded
};

/// Result structure for safe module instantiation
struct V8ModuleInstantiateResult {
    bool success;                // true if instantiation succeeded
    V8ErrorInfo* error;          // nullptr if instantiation succeeded
};

/// Result structure for safe module evaluation
struct V8ModuleEvaluateResult {
    Global<Value>* value;        // nullptr if evaluation failed
    V8ErrorInfo* error;          // nullptr if evaluation succeeded
};

/// Compile a script with TryCatch error handling
///
/// Returns both the compiled script (on success) and error details (on failure).
/// The caller must free the error with v8_FreeErrorInfo if non-null.
V8ScriptCompileResult* v8_Script_Compile_Safe(Global<Context>* context, Global<String>* source) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);  // Ensure context is entered for compilation
    Local<String> local_source = source->Get(isolate);
    
    V8ScriptCompileResult* result = new V8ScriptCompileResult();
    result->script = nullptr;
    result->error = nullptr;
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Script> maybe_script = Script::Compile(local_context, local_source);
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_script.IsEmpty()) {
        // No exception but empty result - create generic error
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Script compilation failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Script> script = maybe_script.ToLocalChecked();
    result->script = trackHandle(new Global<Script>(isolate, script));
    return result;
}

/// Compile a script with origin and TryCatch error handling
V8ScriptCompileResult* v8_Script_CompileWithOrigin_Safe(
    Global<Context>* context,
    Global<String>* source,
    Global<String>* resource_name
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);  // Ensure context is entered for compilation
    Local<String> local_source = source->Get(isolate);
    Local<String> local_resource_name = resource_name->Get(isolate);
    
    V8ScriptCompileResult* result = new V8ScriptCompileResult();
    result->script = nullptr;
    result->error = nullptr;
    
    ScriptOrigin origin(local_resource_name);
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Script> maybe_script = Script::Compile(local_context, local_source, &origin);
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_script.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Script compilation failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Script> script = maybe_script.ToLocalChecked();
    result->script = trackHandle(new Global<Script>(isolate, script));
    return result;
}

/// Free a V8ScriptCompileResult
void v8_FreeScriptCompileResult(V8ScriptCompileResult* result) {
    if (!result) return;
    // Note: script is owned by caller if non-null
    if (result->error) v8_FreeErrorInfo(result->error);
    delete result;
}

/// Run a compiled script with TryCatch error handling
V8ScriptRunResult* v8_Script_Run_Safe(Global<Context>* context, Global<Script>* script) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);  // Ensure context is entered for global resolution
    Local<Script> local_script = script->Get(isolate);
    
    V8ScriptRunResult* result = new V8ScriptRunResult();
    result->value = nullptr;
    result->error = nullptr;
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Value> maybe_result = local_script->Run(local_context);
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_result.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Script execution failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Value> value = maybe_result.ToLocalChecked();
    result->value = trackHandle(new Global<Value>(isolate, value));
    return result;
}

/// Free a V8ScriptRunResult
void v8_FreeScriptRunResult(V8ScriptRunResult* result) {
    if (!result) return;
    // Note: value is owned by caller if non-null
    if (result->error) v8_FreeErrorInfo(result->error);
    delete result;
}

/// Call a function with TryCatch error handling
V8FunctionCallResult* v8_Function_Call_Safe(
    Global<Function>* function,
    Global<Context>* context,
    Global<Value>* recv,
    int argc,
    Global<Value>** argv
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Function> fn = function->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> this_val = recv ? recv->Get(isolate) : Undefined(isolate).As<Value>();
    
    V8FunctionCallResult* result = new V8FunctionCallResult();
    result->value = nullptr;
    result->error = nullptr;
    
    // Convert argument array from Global to Local
    Local<Value>* local_argv = argc > 0 ? new Local<Value>[argc] : nullptr;
    for (int i = 0; i < argc; i++) {
        local_argv[i] = argv[i]->Get(isolate);
    }
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Value> maybe_result = fn->Call(ctx, this_val, argc, local_argv);
    
    delete[] local_argv;
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_result.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Function call failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Value> value = maybe_result.ToLocalChecked();
    result->value = trackHandle(new Global<Value>(isolate, value));
    return result;
}

/// Call a function with receiver and TryCatch error handling
V8FunctionCallResult* v8_Function_CallWithReceiver_Safe(
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
    
    V8FunctionCallResult* result = new V8FunctionCallResult();
    result->value = nullptr;
    result->error = nullptr;
    
    std::vector<Local<Value>> args;
    args.reserve(argc);
    for (int i = 0; i < argc; i++) {
        args.push_back(argv[i]->Get(isolate));
    }
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Value> maybe_result = fn->Call(ctx, recv, argc, args.data());
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_result.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Function call failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Value> value = maybe_result.ToLocalChecked();
    result->value = trackHandle(new Global<Value>(isolate, value));
    return result;
}

/// Free a V8FunctionCallResult
void v8_FreeFunctionCallResult(V8FunctionCallResult* result) {
    if (!result) return;
    // Note: value is owned by caller if non-null
    if (result->error) v8_FreeErrorInfo(result->error);
    delete result;
}

/// Compile an ES module with TryCatch error handling
V8ModuleCompileResult* v8_Module_Compile_Safe(
    Global<Context>* context,
    Global<String>* source,
    Global<String>* resource_name
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<String> local_source = source->Get(isolate);
    Local<String> local_name = resource_name ? resource_name->Get(isolate) : String::Empty(isolate);
    
    V8ModuleCompileResult* result = new V8ModuleCompileResult();
    result->module = nullptr;
    result->error = nullptr;
    
    // Create ScriptOrigin for module (is_module = true)
    ScriptOrigin origin(
        local_name,        // resource name
        0,                 // line offset
        0,                 // column offset
        false,             // is_shared_cross_origin
        -1,                // script id
        Local<Value>(),    // source_map_url
        false,             // is_opaque
        false,             // is_wasm
        true               // is_module
    );
    
    ScriptCompiler::Source script_source(local_source, origin);
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Module> maybe_module = ScriptCompiler::CompileModule(isolate, &script_source);
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_module.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Module compilation failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Module> module = maybe_module.ToLocalChecked();
    result->module = trackHandle(new Global<Module>(isolate, module));
    return result;
}

/// Free a V8ModuleCompileResult
void v8_FreeModuleCompileResult(V8ModuleCompileResult* result) {
    if (!result) return;
    // Note: module is owned by caller if non-null
    if (result->error) v8_FreeErrorInfo(result->error);
    delete result;
}

/// Forward declaration of module resolve callback (defined later in file)
static MaybeLocal<Module> V8ModuleResolveCallback(
    Local<Context> context,
    Local<String> specifier,
    Local<FixedArray> import_assertions,
    Local<Module> referrer
);

/// Instantiate a module with TryCatch error handling
V8ModuleInstantiateResult* v8_Module_Instantiate_Safe(Global<Context>* context, Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Module> local_module = module->Get(isolate);
    
    V8ModuleInstantiateResult* result = new V8ModuleInstantiateResult();
    result->success = false;
    result->error = nullptr;
    
    TryCatch try_catch(isolate);
    
    Maybe<bool> maybe_success = local_module->InstantiateModule(local_context, V8ModuleResolveCallback);
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    result->success = maybe_success.FromMaybe(false);
    if (!result->success) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Module instantiation failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
    }
    return result;
}

/// Free a V8ModuleInstantiateResult
void v8_FreeModuleInstantiateResult(V8ModuleInstantiateResult* result) {
    if (!result) return;
    if (result->error) v8_FreeErrorInfo(result->error);
    delete result;
}

/// Evaluate a module with TryCatch error handling
V8ModuleEvaluateResult* v8_Module_Evaluate_Safe(Global<Context>* context, Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Module> local_module = module->Get(isolate);
    
    V8ModuleEvaluateResult* result = new V8ModuleEvaluateResult();
    result->value = nullptr;
    result->error = nullptr;
    
    TryCatch try_catch(isolate);
    
    MaybeLocal<Value> maybe_result = local_module->Evaluate(local_context);
    
    if (try_catch.HasCaught()) {
        result->error = extractException(isolate, &try_catch);
        return result;
    }
    
    if (maybe_result.IsEmpty()) {
        result->error = new V8ErrorInfo();
        result->error->has_error = true;
        result->error->message = strdup("Module evaluation failed");
        result->error->stack_trace = nullptr;
        result->error->line_number = -1;
        result->error->column_number = -1;
        result->error->source_line = nullptr;
        result->error->resource_name = nullptr;
        return result;
    }
    
    Local<Value> value = maybe_result.ToLocalChecked();
    result->value = trackHandle(new Global<Value>(isolate, value));
    return result;
}

/// Free a V8ModuleEvaluateResult
void v8_FreeModuleEvaluateResult(V8ModuleEvaluateResult* result) {
    if (!result) return;
    // Note: value is owned by caller if non-null
    if (result->error) v8_FreeErrorInfo(result->error);
    delete result;
}

// ============================================================================
// Snapshot Mode Control
// ============================================================================

/// Enable snapshot mode - start tracking Global handles for later cleanup
void v8_Snapshot_EnableMode() {
    g_snapshot_mode = true;
    g_snapshot_handles.clear();
}

/// Disable snapshot mode and clear tracked handles
void v8_Snapshot_DisableMode() {
    g_snapshot_mode = false;
    g_snapshot_handles.clear();
}

/// Clear all tracked Global handles - MUST be called BEFORE exiting context/isolate
///
/// V8 requires no outstanding Global handles when creating a snapshot.
/// This MUST be called while still in the context/isolate, not after exiting.
void v8_Snapshot_ClearGlobalHandles() {
    for (auto& entry : g_snapshot_handles) {
        entry.reset_fn(entry.handle);
    }
    g_snapshot_handles.clear();
}

// ============================================================================
// Platform Management
// ============================================================================

/// Set V8 command-line flags from a string
///
/// This must be called BEFORE V8::Initialize(). Use this to configure V8
/// behavior like hash seeding, snapshot options, etc.
///
/// Example flags:
/// - "--hash-seed=0" - Use deterministic hash seed (may help with snapshots)
/// - "--no-lazy" - Disable lazy compilation
///
/// @param flags - Null-terminated string of V8 command-line flags
void v8_SetFlagsFromString(const char* flags) {
    if (flags) {
        V8::SetFlagsFromString(flags);
    }
}

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

// Map to track ArrayBuffer::Allocators per isolate for cleanup
static std::unordered_map<Isolate*, ArrayBuffer::Allocator*> g_isolate_allocators;

Isolate* v8_Isolate_New() {
    if (!v8_initialized) {
        v8_Platform_Initialize();
    }
    
    Isolate::CreateParams create_params;
    ArrayBuffer::Allocator* allocator = ArrayBuffer::Allocator::NewDefaultAllocator();
    create_params.array_buffer_allocator = allocator;
    Isolate* isolate = Isolate::New(create_params);
    
    // Track the allocator for cleanup when isolate is disposed
    if (isolate) {
        g_isolate_allocators[isolate] = allocator;
    } else {
        // Isolate creation failed, clean up the allocator
        delete allocator;
    }
    
    return isolate;
}

void v8_Isolate_Dispose(Isolate* isolate) {
    if (isolate) {
        // Get the allocator before disposing the isolate
        ArrayBuffer::Allocator* allocator = nullptr;
        auto it = g_isolate_allocators.find(isolate);
        if (it != g_isolate_allocators.end()) {
            allocator = it->second;
            g_isolate_allocators.erase(it);
        }
        
        // Dispose the isolate first
        isolate->Dispose();
        
        // Then delete the allocator
        if (allocator) {
            delete allocator;
        }
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
    return trackHandle(new Global<Context>(isolate, ctx));
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
    return trackHandle(new Global<Context>(isolate, context));
}

Global<Context>* v8_Context_NewWithGlobalTemplate(Isolate* isolate, Global<ObjectTemplate>* global_template) {
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_template = global_template->Get(isolate);
    Local<Context> context = Context::New(isolate, nullptr, local_template);
    return trackHandle(new Global<Context>(isolate, context));
}

/// Create a context using a FunctionTemplate's InstanceTemplate as the global.
/// This ensures that the global object inherits from the FunctionTemplate's prototype,
/// which is necessary for cross-realm Window support where properties like `name`
/// are defined as getters on Window.prototype.
///
/// Unlike v8_Context_NewWithGlobalTemplate which uses a plain ObjectTemplate,
/// this function creates a global object that:
/// 1. Has the shape defined by the FunctionTemplate's InstanceTemplate
/// 2. Has the FunctionTemplate's prototype in its prototype chain
///
/// Args:
///   isolate: V8 isolate
///   global_constructor: FunctionTemplate to use as the global object's "constructor"
///
/// Returns: New context with global object based on the FunctionTemplate
Global<Context>* v8_Context_NewWithGlobalConstructor(Isolate* isolate, Global<FunctionTemplate>* global_constructor) {
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_template = global_constructor->Get(isolate);
    Local<ObjectTemplate> instance_template = local_template->InstanceTemplate();
    Local<Context> context = Context::New(isolate, nullptr, instance_template);
    return trackHandle(new Global<Context>(isolate, context));
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
    return trackHandle(new Global<Object>(isolate, global));
}

// Set the security token of a context
// Contexts with the same security token are considered same-origin
void v8_Context_SetSecurityToken(Global<Context>* context, Global<Value>* token) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    Local<Value> local_token = token->Get(isolate);
    local_context->SetSecurityToken(local_token);
}

// Get the security token of a context
Global<Value>* v8_Context_GetSecurityToken(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    Local<Value> token = local_context->GetSecurityToken();
    return trackHandle(new Global<Value>(isolate, token));
}

// Use the default security token for a context
// This makes the context same-origin with itself only
void v8_Context_UseDefaultSecurityToken(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> local_context = context->Get(isolate);
    local_context->UseDefaultSecurityToken();
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
    return trackHandle(new Global<String>(isolate, str));
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
    return trackHandle(new Global<String>(isolate, empty));
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

// NOTE: These v8_Value_Is* functions now accept EITHER a Global<Value>* OR a raw V8 tagged pointer
// (from a Local handle's internal slot). We use a heuristic to detect which:
// - Global<Value>* pointers are heap-allocated and have specific alignment
// - Raw V8 tagged pointers have the low bit set for SMIs or point to V8 heap objects
//
// Actually, this approach is fragile. Let's instead create separate functions for Local vs Global.
// For now, we'll add new _Local variants that take void* representing the raw tagged pointer.

bool v8_Value_IsObject(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsObject();
}

// Version for Local handle internal pointers
bool v8_Value_IsObject_Local(void* value_ptr) {
    if (!value_ptr) return false;
    // The value_ptr IS the internal Value* pointer from a Local<Value>
    // Cast it directly to Value* - V8 handles pointer tagging internally
    Value* val = reinterpret_cast<Value*>(value_ptr);
    return val->IsObject();
}

// Version for Local handle internal pointers - safe for Smis and raw V8 pointers
bool v8_Value_IsSymbol_Local(void* value_ptr) {
    if (!value_ptr) return false;
    // The value_ptr IS the internal Value* pointer from a Local<Value>
    // Cast it directly to Value* - V8 handles pointer tagging internally
    Value* val = reinterpret_cast<Value*>(value_ptr);
    return val->IsSymbol();
}

// Version for Local handle internal pointers - safe for Smis and raw V8 pointers
bool v8_Value_IsString_Local(void* value_ptr) {
    if (!value_ptr) return false;
    // The value_ptr IS the internal Value* pointer from a Local<Value>
    // Cast it directly to Value* - V8 handles pointer tagging internally
    Value* val = reinterpret_cast<Value*>(value_ptr);
    return val->IsString();
}

bool v8_Value_IsFunction(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return !val.IsEmpty() && val->IsFunction();
}

// Version for Local handle internal pointers
bool v8_Value_IsFunction_Local(void* value_ptr) {
    if (!value_ptr) return false;
    // Reconstruct Local from internal pointer
    Local<Value> val = *reinterpret_cast<Local<Value>*>(&value_ptr);
    return val->IsFunction();
}

bool v8_Value_IsArray(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsArray();
}

bool v8_Value_IsArrayBuffer(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsArrayBuffer();
}

bool v8_Value_IsArrayBufferView(Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsArrayBufferView();
}

// Version for Local handle internal pointers
bool v8_Value_IsArray_Local(void* value_ptr) {
    if (!value_ptr) return false;
    Local<Value> val = *reinterpret_cast<Local<Value>*>(&value_ptr);
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

// Version for Local handle internal pointers
bool v8_Value_IsNullOrUndefined_Local(void* value_ptr) {
    if (!value_ptr) return false;
    Local<Value> val = *reinterpret_cast<Local<Value>*>(&value_ptr);
    return val->IsNullOrUndefined();
}

/// Check if a value has [[IsHTMLDDA]] internal slot (document.all)
/// Per ECMA-262, these "undetectable" objects are falsy despite being objects.
/// Used for WebIDL this-value validation - document.all should throw TypeError
/// when used as 'this' for incompatible operations.
bool v8_Value_IsUndetectable(Global<Value>* value) {
    if (!value) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    return val->IsObject() && val.As<Object>()->IsUndetectable();
}

// Version for Local handle internal pointers (raw V8 tagged pointer)
bool v8_Value_IsUndetectable_Local(void* value_ptr) {
    if (!value_ptr) return false;
    Local<Value> val = *reinterpret_cast<Local<Value>*>(&value_ptr);
    return val->IsObject() && val.As<Object>()->IsUndetectable();
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
    return trackHandle(new Global<String>(isolate, str));
}

// Version for raw V8 internal pointers (from interceptor callbacks)
Global<String>* v8_Value_ToString_Local(void* value_ptr, Global<Context>* context) {
    if (!value_ptr) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    // Cast raw pointer directly to Value* - V8 handles pointer tagging internally
    Value* val = reinterpret_cast<Value*>(value_ptr);
    
    MaybeLocal<String> maybe_str = val->ToString(ctx);
    if (maybe_str.IsEmpty()) {
        return nullptr;
    }
    
    Local<String> str = maybe_str.ToLocalChecked();
    return trackHandle(new Global<String>(isolate, str));
}

bool v8_Value_StrictEquals(Global<Value>* value1, Global<Value>* value2) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Value> v1 = value1->Get(isolate);
    Local<Value> v2 = value2->Get(isolate);
    
    return v1->StrictEquals(v2);
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
    return trackHandle(new Global<Number>(isolate, num));
}

Global<Number>* v8_Integer_New(Isolate* isolate, int32_t value) {
    HandleScope handle_scope(isolate);
    Local<Integer> num = Integer::New(isolate, value);
    return trackHandle(new Global<Number>(isolate, num.As<Number>()));
}

// ============================================================================
// Object Functions
// ============================================================================

Global<Object>* v8_Object_New(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Object> obj = Object::New(isolate);
    return trackHandle(new Global<Object>(isolate, obj));
}

Global<Object>* v8_Object_NewWithNullPrototype(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    
    // Create an object with null prototype using Object.create(null)
    Local<Object> obj = Object::New(isolate, v8::Null(isolate), nullptr, nullptr, 0);
    return trackHandle(new Global<Object>(isolate, obj));
}

// Create a plain object {} in a specific context (for cross-realm support).
// The object's prototype will be the target context's Object.prototype,
// which is essential for correct cross-realm toJSON behavior per WebIDL spec.
Global<Object>* v8_Object_NewInContext(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Enter the target context to ensure the object is created
    // with that context's Object.prototype
    Context::Scope context_scope(ctx);
    
    Local<Object> obj = Object::New(isolate);
    return trackHandle(new Global<Object>(isolate, obj));
}

// Create an array [] in a specific context (for cross-realm support).
// The array's prototype will be the target context's Array.prototype.
Global<Array>* v8_Array_NewInContext(Global<Context>* context, int length) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Enter the target context to ensure the array is created
    // with that context's Array.prototype
    Context::Scope context_scope(ctx);
    
    Local<Array> arr = Array::New(isolate, length);
    return trackHandle(new Global<Array>(isolate, arr));
}

bool v8_Object_Set(Global<Object>* object, Global<Context>* context, Global<Value>* key, Global<Value>* value) {
    CHECK_ALIGNMENT_LOG(object, Global<Object>, "v8_Object_Set");
    CHECK_ALIGNMENT_LOG(context, Global<Context>, "v8_Object_Set");
    CHECK_ALIGNMENT_LOG(key, Global<Value>, "v8_Object_Set");
    CHECK_ALIGNMENT_LOG(value, Global<Value>, "v8_Object_Set");
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);
    Local<Value> v = value->Get(isolate);
    
    Maybe<bool> result = obj->Set(ctx, k, v);
    return result.FromMaybe(false);
}

bool v8_Object_Delete(Global<Object>* object, Global<Context>* context, Global<Value>* key) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);
    
    Maybe<bool> result = obj->Delete(ctx, k);
    return result.FromMaybe(false);
}

bool v8_Object_CreateDataProperty(Global<Object>* object, Global<Context>* context, Global<String>* key, Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<String> k = key->Get(isolate);
    Local<Value> v = value->Get(isolate);
    
    // Use DefineOwnProperty with explicit attributes to ensure we create an own property
    // that shadows any prototype accessor
    PropertyDescriptor desc(v, true); // writable = true
    desc.set_enumerable(true);
    desc.set_configurable(true);
    
    Maybe<bool> result = obj->DefineOwnProperty(ctx, k, v, static_cast<PropertyAttribute>(None));
    return result.FromMaybe(false);
}

Global<Value>* v8_Object_Get(Global<Object>* object, Global<Context>* context, Global<Value>* key) {
    CHECK_ALIGNMENT_LOG(object, Global<Object>, "v8_Object_Get");
    CHECK_ALIGNMENT_LOG(context, Global<Context>, "v8_Object_Get");
    CHECK_ALIGNMENT_LOG(key, Global<Value>, "v8_Object_Get");
    
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
    return trackHandle(new Global<Value>(isolate, val));
}

// Check if an object has an own property (not inherited)
bool v8_Object_HasOwnProperty(Global<Object>* object, Global<Context>* context, Global<Value>* key) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);
    
    // HasOwnProperty takes a Name (String or Symbol), not a generic Value
    if (!k->IsName()) {
        return false;
    }
    
    Maybe<bool> result = obj->HasOwnProperty(ctx, k.As<Name>());
    return result.FromMaybe(false);
}

// Get the own property descriptor for a property
// Returns an object with value, writable, enumerable, configurable, get, set
// or nullptr if the property doesn't exist as an own property
Global<Value>* v8_Object_GetOwnPropertyDescriptor(Global<Object>* object, Global<Context>* context, Global<Value>* key) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> obj = object->Get(isolate);
    Local<Value> k = key->Get(isolate);
    
    // GetOwnPropertyDescriptor takes a Name (String or Symbol)
    if (!k->IsName()) {
        return nullptr;
    }
    
    MaybeLocal<Value> maybe_desc = obj->GetOwnPropertyDescriptor(ctx, k.As<Name>());
    if (maybe_desc.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> desc = maybe_desc.ToLocalChecked();
    // If the property doesn't exist, GetOwnPropertyDescriptor returns undefined
    if (desc->IsUndefined()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Value>(isolate, desc));
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
    return trackHandle(new Global<Array>(isolate, names));
}

// Get own property names with numeric indices converted to strings
// Required for Proxy ownKeys trap which must return only strings/symbols
Global<Array>* v8_Object_GetOwnPropertyNamesAsStrings(Global<Context>* context, Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    // Use GetOwnPropertyNames with kConvertToString to ensure all keys are strings
    // PropertyFilter::ALL_PROPERTIES (value 0) includes both enumerable and non-enumerable
    MaybeLocal<Array> maybe_names = local_obj->GetOwnPropertyNames(
        local_context,
        PropertyFilter::ALL_PROPERTIES,
        KeyConversionMode::kConvertToString
    );
    if (maybe_names.IsEmpty()) {
        return nullptr;
    }
    
    Local<Array> names = maybe_names.ToLocalChecked();
    return trackHandle(new Global<Array>(isolate, names));
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
    return trackHandle(new Global<Array>(isolate, names));
}

// Get own property symbols (for Object.getOwnPropertySymbols)
Global<Array>* v8_Object_GetOwnPropertySymbols(Global<Context>* context, Global<Object>* obj) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    // Get only symbol properties, own only
    MaybeLocal<Array> maybe_names = local_obj->GetOwnPropertyNames(
        local_context,
        static_cast<PropertyFilter>(PropertyFilter::ALL_PROPERTIES | PropertyFilter::SKIP_STRINGS),
        KeyConversionMode::kKeepNumbers  // Doesn't matter for symbols
    );
    if (maybe_names.IsEmpty()) {
        return nullptr;
    }
    
    Local<Array> names = maybe_names.ToLocalChecked();
    return trackHandle(new Global<Array>(isolate, names));
}

void v8_Object_SetAlignedPointerInInternalField(Global<Object>* obj, int index, void* value) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    // Defensive check: verify object has enough internal fields
    int field_count = local_obj->InternalFieldCount();
    if (index >= field_count) {
        fprintf(stderr, "FATAL: SetAlignedPointerInInternalField index %d out of bounds (object has %d internal fields)\n", 
                index, field_count);
        fprintf(stderr, "  This usually means:\n");
        fprintf(stderr, "  1. Object was not created from a template with SetInternalFieldCount(2)\n");
        fprintf(stderr, "  2. Object is the global object (has 0 internal fields by default)\n");
        fprintf(stderr, "  3. Object is from a different isolate/context\n");
        
        // Print backtrace to identify caller
        fprintf(stderr, "\nBacktrace:\n");
        void* callstack[128];
        int frames = backtrace(callstack, 128);
        char** symbols = backtrace_symbols(callstack, frames);
        if (symbols) {
            for (int i = 0; i < frames; i++) {
                fprintf(stderr, "  %s\n", symbols[i]);
            }
            free(symbols);
        }
        fprintf(stderr, "\n");
        // Don't crash here - let V8's internal check provide the crash location
        // but we've logged useful debug info
    }
    
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
    
    // CROSS-REALM FIX: If object is a Proxy, unwrap to get the target.
    // Proxies (used for legacy platform objects like CSSStyleDeclaration)
    // have no internal fields - the internal fields are on the target object.
    if (local_obj->IsProxy()) {
        Local<Proxy> proxy = local_obj.As<Proxy>();
        Local<Value> target = proxy->GetTarget();
        if (target->IsObject()) {
            local_obj = target.As<Object>();
        }
    }
    
    // Safety check: verify object has enough internal fields before access
    // This prevents crashes when accessing prototype objects or other objects
    // that don't have internal fields set up
    if (local_obj->InternalFieldCount() <= index) {
        return nullptr;
    }
    
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
    return trackHandle(new Global<Array>(isolate, arr));
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
    return trackHandle(new Global<Value>(isolate, value));
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
    Context::Scope context_scope(local_context);  // Ensure context is entered for compilation
    Local<String> local_source = source->Get(isolate);
    
    MaybeLocal<Script> maybe_script = Script::Compile(local_context, local_source);
    if (maybe_script.IsEmpty()) {
        return nullptr;
    }
    
    Local<Script> script = maybe_script.ToLocalChecked();
    return trackHandle(new Global<Script>(isolate, script));
}

/// Compile a script with a source URL (for error messages and source maps)
Global<Script>* v8_Script_CompileWithOrigin(Global<Context>* context, Global<String>* source, Global<String>* resource_name) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);  // Ensure context is entered for compilation
    Local<String> local_source = source->Get(isolate);
    Local<String> local_resource_name = resource_name->Get(isolate);
    
    // Create ScriptOrigin with the resource name (URL)
    // ScriptOrigin takes Local<Value> as first arg, not Isolate
    ScriptOrigin origin(local_resource_name);
    
    MaybeLocal<Script> maybe_script = Script::Compile(local_context, local_source, &origin);
    if (maybe_script.IsEmpty()) {
        return nullptr;
    }
    
    Local<Script> script = maybe_script.ToLocalChecked();
    return trackHandle(new Global<Script>(isolate, script));
}

Global<Value>* v8_Script_Run(Global<Context>* context, Global<Script>* script) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Context::Scope context_scope(local_context);  // Ensure context is entered for global resolution
    Local<Script> local_script = script->Get(isolate);
    
    MaybeLocal<Value> maybe_result = local_script->Run(local_context);
    if (maybe_result.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> result = maybe_result.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, result));
}

void v8_Script_Dispose(Global<Script>* script) {
    if (script) {
        script->Reset();
        delete script;
    }
}

// ============================================================================
// Module Functions (ES Modules support)
// ============================================================================

/// Module resolve callback data structure
struct ModuleResolveCallbackData {
    void* user_data;
    void* (*callback)(void* user_data, const char* specifier, int specifier_len, void* referrer_module);
};

/// Global module resolve callback (set per isolate)
static ModuleResolveCallbackData* g_module_resolve_callback = nullptr;

/// V8 Module resolve callback wrapper
static MaybeLocal<Module> V8ModuleResolveCallback(
    Local<Context> context,
    Local<String> specifier,
    Local<FixedArray> import_assertions,
    Local<Module> referrer
) {
    (void)import_assertions;  // Not used currently
    
    if (!g_module_resolve_callback || !g_module_resolve_callback->callback) {
        return MaybeLocal<Module>();
    }
    
    Isolate* isolate = context->GetIsolate();
    
    // Convert specifier to C string
    String::Utf8Value specifier_utf8(isolate, specifier);
    const char* specifier_cstr = *specifier_utf8;
    int specifier_len = specifier_utf8.length();
    
    // Create a Global handle for the referrer module
    Global<Module>* referrer_global = new Global<Module>(isolate, referrer);
    
    // Call the Zig callback
    void* result = g_module_resolve_callback->callback(
        g_module_resolve_callback->user_data,
        specifier_cstr,
        specifier_len,
        referrer_global
    );
    
    if (!result) {
        delete referrer_global;
        return MaybeLocal<Module>();
    }
    
    // Result should be a Global<Module>*
    Global<Module>* resolved = static_cast<Global<Module>*>(result);
    Local<Module> local_resolved = resolved->Get(isolate);
    
    delete referrer_global;
    
    return local_resolved;
}

/// Set the module resolve callback for the current isolate
void v8_Module_SetResolveCallback(
    void* user_data,
    void* (*callback)(void* user_data, const char* specifier, int specifier_len, void* referrer_module)
) {
    if (!g_module_resolve_callback) {
        g_module_resolve_callback = new ModuleResolveCallbackData();
    }
    g_module_resolve_callback->user_data = user_data;
    g_module_resolve_callback->callback = callback;
}

/// Compile source code as an ES Module
/// Returns nullptr on compilation error
Global<Module>* v8_Module_Compile(
    Global<Context>* context,
    Global<String>* source,
    Global<String>* resource_name
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<String> local_source = source->Get(isolate);
    Local<String> local_name = resource_name ? resource_name->Get(isolate) : String::Empty(isolate);
    
    // Create ScriptOrigin for module (is_module = true)
    ScriptOrigin origin(
        local_name,        // resource name
        0,                 // line offset
        0,                 // column offset
        false,             // is_shared_cross_origin
        -1,                // script id
        Local<Value>(),    // source_map_url
        false,             // is_opaque
        false,             // is_wasm
        true               // is_module
    );
    
    // Create ScriptCompiler::Source
    ScriptCompiler::Source script_source(local_source, origin);
    
    // Compile the module
    MaybeLocal<Module> maybe_module = ScriptCompiler::CompileModule(isolate, &script_source);
    
    if (maybe_module.IsEmpty()) {
        return nullptr;
    }
    
    Local<Module> module = maybe_module.ToLocalChecked();
    return trackHandle(new Global<Module>(isolate, module));
}

/// Get the number of module requests (imports) in a module
int v8_Module_GetModuleRequestsLength(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    Local<FixedArray> requests = local_module->GetModuleRequests();
    return requests->Length();
}

/// Get the module specifier (import path) at the given index
/// Caller must free the returned string with v8_FreeString
char* v8_Module_GetModuleRequest(Global<Module>* module, int index) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    Local<FixedArray> requests = local_module->GetModuleRequests();
    
    if (index < 0 || index >= requests->Length()) {
        return nullptr;
    }
    
    // FixedArray::Get returns Local<Data>, cast to ModuleRequest
    Local<Data> data = requests->Get(isolate->GetCurrentContext(), index);
    Local<ModuleRequest> request = data.As<ModuleRequest>();
    Local<String> specifier = request->GetSpecifier();
    
    String::Utf8Value utf8(isolate, specifier);
    int len = utf8.length();
    char* result = new char[len + 1];
    memcpy(result, *utf8, len);
    result[len] = '\0';
    
    return result;
}

/// Free a string allocated by v8_Module_GetModuleRequest
void v8_FreeString(char* str) {
    if (str) {
        delete[] str;
    }
}

/// Get the module's status (0=Uninstantiated, 1=Instantiating, 2=Instantiated, 3=Evaluating, 4=Evaluated, 5=Errored)
int v8_Module_GetStatus(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    return static_cast<int>(local_module->GetStatus());
}

/// Instantiate the module (link all imports)
/// Returns true on success, false on error
bool v8_Module_Instantiate(Global<Context>* context, Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Module> local_module = module->Get(isolate);
    
    Maybe<bool> result = local_module->InstantiateModule(local_context, V8ModuleResolveCallback);
    
    return result.FromMaybe(false);
}

/// Evaluate the module (execute the top-level code)
/// Returns the result value or nullptr on error
Global<Value>* v8_Module_Evaluate(Global<Context>* context, Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> local_context = context->Get(isolate);
    Local<Module> local_module = module->Get(isolate);
    
    MaybeLocal<Value> maybe_result = local_module->Evaluate(local_context);
    
    if (maybe_result.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> result = maybe_result.ToLocalChecked();
    return trackHandle(new Global<Value>(isolate, result));
}

/// Get the module's exception (if status is Errored)
Global<Value>* v8_Module_GetException(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    
    if (local_module->GetStatus() != Module::kErrored) {
        return nullptr;
    }
    
    Local<Value> exception = local_module->GetException();
    return trackHandle(new Global<Value>(isolate, exception));
}

/// Get the module's namespace object (exports)
Global<Object>* v8_Module_GetModuleNamespace(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    Local<Value> ns = local_module->GetModuleNamespace();
    
    if (!ns->IsObject()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Object>(isolate, ns.As<Object>()));
}

/// Get the module's identity hash (for use as map key)
int v8_Module_GetIdentityHash(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    return local_module->GetIdentityHash();
}

/// Dispose a module handle
void v8_Module_Dispose(Global<Module>* module) {
    if (module) {
        module->Reset();
        delete module;
    }
}

/// Check if a module or any of its dependencies has top-level await
/// 
/// Per TC39 TLA spec, this returns true if the module graph contains
/// any async module (i.e., module with top-level await).
/// Must be called after module instantiation.
/// 
/// @param module - Compiled and instantiated module handle
/// @return true if the module or any dependency has TLA
bool v8_Module_IsGraphAsync(Global<Module>* module) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Module> local_module = module->Get(isolate);
    
    // V8's IsGraphAsync() checks if this module or any of its dependencies
    // contain top-level await, requiring async evaluation
    return local_module->IsGraphAsync();
}

// ============================================================================
// Dynamic Import (import() expression) Support
// ============================================================================

/// Dynamic import callback data structure
struct DynamicImportCallbackData {
    void* user_data;
    /// Callback signature:
    ///   user_data: Context passed during setup
    ///   context: V8 Context* where import() was called
    ///   referrer_module_specifier: Module specifier string of the calling module (or null)
    ///   referrer_module_specifier_len: Length of specifier string
    ///   specifier: The specifier passed to import()
    ///   specifier_len: Length of specifier
    ///   promise_resolver: V8 PromiseResolver* to resolve/reject with result
    /// Returns: void (result communicated via promise_resolver)
    void (*callback)(
        void* user_data,
        void* context,
        const char* referrer_module_specifier,
        int referrer_module_specifier_len,
        const char* specifier,
        int specifier_len,
        void* promise_resolver
    );
};

/// Global dynamic import callback (set per isolate)
static DynamicImportCallbackData* g_dynamic_import_callback = nullptr;

/// V8 Host dynamic import callback wrapper
/// This is called by V8 whenever import() is used in JavaScript
static MaybeLocal<Promise> V8HostImportModuleDynamicallyCallback(
    Local<Context> context,
    Local<Data> host_defined_options,
    Local<Value> resource_name,
    Local<String> specifier,
    Local<FixedArray> import_assertions
) {
    (void)host_defined_options;
    (void)import_assertions;
    
    Isolate* isolate = context->GetIsolate();
    EscapableHandleScope handle_scope(isolate);
    
    // Create promise resolver to return
    Local<Promise::Resolver> resolver;
    if (!Promise::Resolver::New(context).ToLocal(&resolver)) {
        return MaybeLocal<Promise>();
    }
    
    // If no callback registered, reject with error
    if (!g_dynamic_import_callback || !g_dynamic_import_callback->callback) {
        Local<String> error_msg = String::NewFromUtf8Literal(isolate, "Dynamic import not supported");
        Local<Value> error = Exception::Error(error_msg);
        resolver->Reject(context, error).Check();
        return handle_scope.Escape(resolver->GetPromise());
    }
    
    // Convert specifier to C string
    String::Utf8Value specifier_utf8(isolate, specifier);
    const char* specifier_cstr = *specifier_utf8;
    int specifier_len = specifier_utf8.length();
    
    // Convert resource name (referrer) to C string if present
    const char* referrer_cstr = nullptr;
    int referrer_len = 0;
    String::Utf8Value* referrer_utf8 = nullptr;
    if (!resource_name.IsEmpty() && resource_name->IsString()) {
        referrer_utf8 = new String::Utf8Value(isolate, resource_name);
        referrer_cstr = **referrer_utf8;
        referrer_len = referrer_utf8->length();
    }
    
    // Create Global handles for context and resolver to pass to Zig
    Global<Context>* context_global = new Global<Context>(isolate, context);
    Global<Promise::Resolver>* resolver_global = new Global<Promise::Resolver>(isolate, resolver);
    
    // Call the Zig callback - it will resolve/reject the promise
    g_dynamic_import_callback->callback(
        g_dynamic_import_callback->user_data,
        context_global,
        referrer_cstr,
        referrer_len,
        specifier_cstr,
        specifier_len,
        resolver_global
    );
    
    // Clean up referrer string (if allocated)
    if (referrer_utf8) {
        delete referrer_utf8;
    }
    
    // Return the promise - Zig callback will resolve/reject it asynchronously
    return handle_scope.Escape(resolver->GetPromise());
}

/// Set the dynamic import callback for the current isolate
/// This callback is invoked whenever import() is used in JavaScript
void v8_Isolate_SetHostImportModuleDynamicallyCallback(
    Isolate* isolate,
    void* user_data,
    void (*callback)(
        void* user_data,
        void* context,
        const char* referrer_module_specifier,
        int referrer_module_specifier_len,
        const char* specifier,
        int specifier_len,
        void* promise_resolver
    )
) {
    // Store callback data
    if (!g_dynamic_import_callback) {
        g_dynamic_import_callback = new DynamicImportCallbackData();
    }
    g_dynamic_import_callback->user_data = user_data;
    g_dynamic_import_callback->callback = callback;
    
    // Register with V8
    isolate->SetHostImportModuleDynamicallyCallback(V8HostImportModuleDynamicallyCallback);
}

/// Resolve a dynamic import promise with a module namespace
/// Called from Zig when module loading succeeds
void v8_DynamicImport_Resolve(
    void* context_ptr,
    void* resolver_ptr,
    void* module_namespace_ptr
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Global<Context>* context_global = static_cast<Global<Context>*>(context_ptr);
    Global<Promise::Resolver>* resolver_global = static_cast<Global<Promise::Resolver>*>(resolver_ptr);
    Global<Object>* namespace_global = static_cast<Global<Object>*>(module_namespace_ptr);
    
    Local<Context> context = context_global->Get(isolate);
    Local<Promise::Resolver> resolver = resolver_global->Get(isolate);
    Local<Object> module_namespace = namespace_global->Get(isolate);
    
    // Resolve the promise with the module namespace
    resolver->Resolve(context, module_namespace).Check();
    
    // Clean up Global handles
    delete context_global;
    resolver_global->Reset();
    delete resolver_global;
    // Don't delete namespace_global - caller owns it
}

/// Reject a dynamic import promise with an error
/// Called from Zig when module loading fails
void v8_DynamicImport_Reject(
    void* context_ptr,
    void* resolver_ptr,
    const char* error_message,
    int error_message_len
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Global<Context>* context_global = static_cast<Global<Context>*>(context_ptr);
    Global<Promise::Resolver>* resolver_global = static_cast<Global<Promise::Resolver>*>(resolver_ptr);
    
    Local<Context> context = context_global->Get(isolate);
    Local<Promise::Resolver> resolver = resolver_global->Get(isolate);
    
    // Create error from message
    Local<String> msg = String::NewFromUtf8(isolate, error_message, NewStringType::kNormal, error_message_len)
        .ToLocalChecked();
    Local<Value> error = Exception::Error(msg);
    
    // Reject the promise
    resolver->Reject(context, error).Check();
    
    // Clean up Global handles
    delete context_global;
    resolver_global->Reset();
    delete resolver_global;
}

// ============================================================================
// Exception Functions
// ============================================================================

Global<Value>* v8_Exception_TypeError(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::TypeError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

Global<Value>* v8_Exception_RangeError(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::RangeError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

Global<Value>* v8_Exception_SyntaxError(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::SyntaxError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

Global<Value>* v8_Exception_Error(Global<String>* message) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<String> msg = message->Get(isolate);
    Local<Value> exception = Exception::Error(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

// ============================================================================
// Cross-Realm Exception Functions
// ============================================================================
//
// These functions support throwing exceptions from a specific context/realm.
// Per WebIDL spec, when a method throws TypeError for invalid `this`, the
// TypeError must come from the method's realm (where it was defined), not
// the caller's realm. This is essential for cross-realm iframe support.

/// Get the context in which an object was created (for cross-realm support).
/// Returns nullptr if the object's creation context is unavailable.
Global<Context>* v8_Object_GetCreationContext(Global<Object>* obj) {
    if (!obj) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    MaybeLocal<Context> maybe_ctx = local_obj->GetCreationContext();
    if (maybe_ctx.IsEmpty()) {
        return nullptr;
    }
    
    Local<Context> ctx = maybe_ctx.ToLocalChecked();
    return trackHandle(new Global<Context>(isolate, ctx));
}

/// Get the context in which a Global<Object> was created.
/// This is used in callbacks after converting the `this` object to a Global handle.
/// Returns nullptr if the object's creation context is unavailable.
///
/// Note: For FunctionCallbackInfo callbacks, use v8_FunctionCallbackInfo_Holder to get
/// the holder object, then call v8_Object_GetCreationContext on it.
///
/// This function is kept for compatibility but v8_Object_GetCreationContext (for Global handles)
/// should be preferred when possible.
Global<Context>* v8_Object_GetCreationContext_Raw(const void* obj_ptr) {
    // This function is deprecated - use v8_Object_GetCreationContext with a Global handle instead.
    // The raw pointer approach doesn't work reliably in modern V8.
    return nullptr;
}

/// Create TypeError in a specific context (for cross-realm errors).
/// This enters the context before creating the error, ensuring the
/// TypeError constructor comes from the correct realm.
///
/// @param context - The context/realm where the TypeError should originate
/// @param message - The error message as a V8 string
/// @returns A TypeError from the specified context's realm
Global<Value>* v8_Exception_TypeErrorInContext(Global<Context>* context, Global<String>* message) {
    if (!context || !message) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<String> msg = message->Get(isolate);
    
    // Enter the context to ensure TypeError comes from this realm
    Context::Scope context_scope(ctx);
    
    Local<Value> exception = Exception::TypeError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

/// Create RangeError in a specific context (for cross-realm errors).
Global<Value>* v8_Exception_RangeErrorInContext(Global<Context>* context, Global<String>* message) {
    if (!context || !message) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<String> msg = message->Get(isolate);
    
    // Enter the context to ensure RangeError comes from this realm
    Context::Scope context_scope(ctx);
    
    Local<Value> exception = Exception::RangeError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

/// Create SyntaxError in a specific context (for cross-realm errors).
Global<Value>* v8_Exception_SyntaxErrorInContext(Global<Context>* context, Global<String>* message) {
    if (!context || !message) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<String> msg = message->Get(isolate);
    
    // Enter the context to ensure SyntaxError comes from this realm
    Context::Scope context_scope(ctx);
    
    Local<Value> exception = Exception::SyntaxError(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

/// Create Error in a specific context (for cross-realm errors).
Global<Value>* v8_Exception_ErrorInContext(Global<Context>* context, Global<String>* message) {
    if (!context || !message) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<String> msg = message->Get(isolate);
    
    // Enter the context to ensure Error comes from this realm
    Context::Scope context_scope(ctx);
    
    Local<Value> exception = Exception::Error(msg);
    return trackHandle(new Global<Value>(isolate, exception));
}

/// Get the holder object from FunctionCallbackInfo.
/// The holder is the object where the property was found in the prototype chain.
/// For methods called on an instance, this is typically the prototype object
/// where the method is defined.
///
/// V8 stores the holder object at implicit_args_[kHolderIndex = 0].
///
/// For cross-realm support, we need the actual holder (e.g., other.DOMRectReadOnly.prototype)
/// not This() (the receiver, e.g., our rect object).
Global<Object>* v8_FunctionCallbackInfo_Holder(const FunctionCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    
    // FunctionCallbackInfo memory layout (from v8-function-callback.h):
    // The class stores a pointer to implicit_args_ array which contains:
    //   - [0]: holder (kHolderIndex)
    //   - [1]: isolate (kIsolateIndex)
    //   - [2]: context (kContextIndex)
    //   - [3]: return value (kReturnValueIndex)
    //   - [4]: target (kTargetIndex)
    //   - [5]: new target (kNewTargetIndex)
    //
    // The holder is the prototype object where the method was found.
    // We access it via Data() and pointer arithmetic since Data() returns
    // implicit_args_[kTargetIndex].
    //
    // For methods installed via FunctionTemplate on prototype templates:
    // - The function is created from the FunctionTemplate
    // - Its "holder" in the callback context is the prototype object
    // - That prototype's creation context is the realm we want
    
    // Since V8 doesn't expose Holder() directly for FunctionCallbackInfo in modern versions,
    // we use the fact that NewTarget() for non-construct calls returns undefined,
    // and we can use the current context to determine the method's realm.
    //
    // When other.DOMRectReadOnly.prototype.toJSON.call(rect) is called:
    // - The current isolate context AT CALLBACK TIME is the caller's context
    // - But we want the context where the prototype method was instantiated
    //
    // The best we can do without holder access is to return This() and then
    // use GetPrototypeCreationContext to walk up to find the defining context.
    // This works because:
    // - rect's prototype is DOMRectReadOnly.prototype from main context
    // - but we're calling other.DOMRectReadOnly.prototype.toJSON on it
    //
    // Actually, for toJSON and similar, V8's Data() contains what we passed
    // when creating the function template. If we store the context there,
    // we could retrieve it here.
    //
    // For now, return This() and rely on GetPrototypeCreationContext in Zig
    // to find the method's realm by walking the prototype chain.
    Local<Object> this_obj = info->This();
    return trackHandle(new Global<Object>(isolate, this_obj));
}

/// Get the creation context of an object's prototype.
/// This walks up the prototype chain to find the first object with a
/// creation context different from the current context.
///
/// This is useful for cross-realm error handling, where we need to find
/// the context where the method/property was defined (on the prototype),
/// not the context where the `this` object was created.
///
/// For example:
///   const notElement = Object.create(other.HTMLElement.prototype);
///   // notElement is created in main context
///   // but its prototype is from iframe's context
///   // We want to throw TypeError from iframe's context
Global<Context>* v8_Object_GetPrototypeCreationContext(Global<Object>* obj) {
    if (!obj) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> local_obj = obj->Get(isolate);
    
    // Get the prototype of the object
    Local<Value> proto_val = local_obj->GetPrototype();
    if (proto_val.IsEmpty() || !proto_val->IsObject()) {
        return nullptr;
    }
    
    Local<Object> proto = proto_val.As<Object>();
    
    // Get the prototype's creation context
    MaybeLocal<Context> maybe_ctx = proto->GetCreationContext();
    if (maybe_ctx.IsEmpty()) {
        return nullptr;
    }
    
    Local<Context> ctx = maybe_ctx.ToLocalChecked();
    return trackHandle(new Global<Context>(isolate, ctx));
}

Global<Value>* v8_TryCatch_Exception(Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    TryCatch try_catch(isolate);
    
    if (try_catch.HasCaught()) {
        Local<Value> exception = try_catch.Exception();
        return trackHandle(new Global<Value>(isolate, exception));
    }
    
    return nullptr;
}

// ============================================================================
// Special Values
// ============================================================================

Global<Value>* v8_Undefined(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Value> undef = Undefined(isolate);
    return trackHandle(new Global<Value>(isolate, undef));
}

Global<Value>* v8_Null(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Value> null_val = Null(isolate);
    return trackHandle(new Global<Value>(isolate, null_val));
}

Global<Value>* v8_Boolean_New(Isolate* isolate, bool value) {
    HandleScope handle_scope(isolate);
    Local<Boolean> bool_val = Boolean::New(isolate, value);
    return trackHandle(new Global<Value>(isolate, bool_val));
}

/// Persist a Local value to a Global handle.
/// Takes a Local<Value> internal pointer and creates a tracked Global<Value>*.
/// Use this to safely store/return values that came from Local handles.
///
/// @param isolate - V8 Isolate
/// @param local_ptr - Internal pointer from a Local<Value> (from v8_Global_Get, etc.)
/// @return Global<Value>* that can be safely stored and used with setReturnValue
Global<Value>* v8_Value_Persist(Isolate* isolate, void* local_ptr) {
    if (!isolate || !local_ptr) return nullptr;
    
    HandleScope handle_scope(isolate);
    
    // Reconstruct Local from internal pointer
    Local<Value> local = *reinterpret_cast<Local<Value>*>(&local_ptr);
    
    // Create and track a Global handle
    return trackHandle(new Global<Value>(isolate, local));
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
    return trackHandle(new Global<FunctionTemplate>(isolate, tpl));
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
    return trackHandle(new Global<FunctionTemplate>(isolate, tpl));
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
    return trackHandle(new Global<Function>(isolate, fn));
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
    return trackHandle(new Global<ObjectTemplate>(isolate, instance_tpl));
}

Global<ObjectTemplate>* v8_FunctionTemplate_PrototypeTemplate(Global<FunctionTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<ObjectTemplate> proto_tpl = local_tpl->PrototypeTemplate();
    return trackHandle(new Global<ObjectTemplate>(isolate, proto_tpl));
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

// Check if a value is an instance of the given FunctionTemplate
// This is used for [LegacyLenientThis] attribute checking
bool v8_FunctionTemplate_HasInstance(Global<FunctionTemplate>* tpl, Global<Object>* object) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<Object> local_obj = object->Get(isolate);
    return local_tpl->HasInstance(local_obj);
}

void v8_FunctionTemplate_ReadOnlyPrototype(Global<FunctionTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    // ReadOnlyPrototype() makes the "prototype" property non-writable
    // and also removes "arguments" and "caller" properties from functions
    // created from this template, making them behave like strict mode functions.
    local_tpl->ReadOnlyPrototype();
}

// Get the prototype object from a FunctionTemplate.
// This calls GetFunction() and then gets the "prototype" property from the function.
// Used when wrapping Zig instances as V8 objects - we need to manually set the prototype
// because ObjectTemplate::NewInstance() doesn't automatically link to the FunctionTemplate's prototype.
Global<Object>* v8_FunctionTemplate_GetPrototypeObject(Global<FunctionTemplate>* tpl, Global<Context>* context) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Get the function from the template
    MaybeLocal<Function> maybe_fn = local_tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        return nullptr;
    }
    
    Local<Function> fn = maybe_fn.ToLocalChecked();
    
    // Get the "prototype" property from the function
    Local<String> prototype_str = String::NewFromUtf8Literal(isolate, "prototype");
    MaybeLocal<Value> maybe_proto = fn->Get(ctx, prototype_str);
    if (maybe_proto.IsEmpty()) {
        return nullptr;
    }
    
    Local<Value> proto_val = maybe_proto.ToLocalChecked();
    if (!proto_val->IsObject()) {
        return nullptr;
    }
    
    Local<Object> proto_obj = proto_val.As<Object>();
    return trackHandle(new Global<Object>(isolate, proto_obj));
}

void v8_FunctionTemplate_RemovePrototype(Global<FunctionTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    // RemovePrototype() removes the "prototype" property entirely.
    // This also removes "arguments" and "caller" properties.
    // Use for methods and getters which should not have prototype.
    local_tpl->RemovePrototype();
}

/// Set a call handler on a FunctionTemplate.
/// This is required for objects marked as undetectable (like document.all)
/// because V8 requires undetectable objects to be callable.
void v8_FunctionTemplate_SetCallHandler(
    Global<FunctionTemplate>* tpl,
    FunctionCallback callback,
    void* data
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> local_tpl = tpl->Get(isolate);
    Local<Value> callback_data = data ? Local<Value>(External::New(isolate, data)) : Local<Value>();
    local_tpl->SetCallHandler(callback, callback_data);
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
    return trackHandle(new Global<Value>(isolate, arg));
}

void v8_FunctionCallbackInfo_SetReturnValue(const FunctionCallbackInfo<Value>* info, Global<Value>* value) {
    if (!value) {
        // Null value passed - set undefined and log warning
        fprintf(stderr, "WARNING: v8_FunctionCallbackInfo_SetReturnValue called with null value\n");
        return;
    }
    
    // Sanity checks for corrupted pointers
    uintptr_t ptr_val = reinterpret_cast<uintptr_t>(value);
    
    // Check 1: Pointer should be in a reasonable address range (not small integers or negative values)
    if (ptr_val < 0x1000 || ptr_val > 0x0000FFFFFFFFFFFF) {
        fprintf(stderr, "WARNING: v8_FunctionCallbackInfo_SetReturnValue called with suspicious pointer: %p (out of range)\n", value);
        // Don't try to access this pointer - it's clearly garbage
        // Just return undefined instead
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Check 2: V8's Global handles should be aligned to at least 8 bytes on 64-bit
    if ((ptr_val & 0x7) != 0) {
        fprintf(stderr, "WARNING: v8_FunctionCallbackInfo_SetReturnValue called with misaligned pointer: %p (alignment=%lu)\n", value, ptr_val & 0x7);
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Check if the Global handle is empty (was Reset() called on it?)
    if (value->IsEmpty()) {
        fprintf(stderr, "WARNING: v8_FunctionCallbackInfo_SetReturnValue called with empty Global handle\n");
        return;
    }
    
    Isolate* isolate = info->GetIsolate();
    Local<Value> val = value->Get(isolate);
    info->GetReturnValue().Set(val);
}

/// Set return value from a Local<Value> pointer
///
/// This is used when we have a Local<Value> (from v8_Global_Get or other operations)
/// instead of a Global<Value>*. The pointer is treated as the internal pointer
/// from a Local<Value> and wrapped in a Local to pass to ReturnValue::Set.
///
/// @param info - FunctionCallbackInfo pointer
/// @param local_ptr - Internal pointer from a Local<Value> (from v8_Global_Get, etc.)
void v8_FunctionCallbackInfo_SetReturnValueLocal(const FunctionCallbackInfo<Value>* info, void* local_ptr) {
    if (!local_ptr) {
        // Null value - set undefined
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Sanity checks for corrupted pointers
    uintptr_t ptr_val = reinterpret_cast<uintptr_t>(local_ptr);
    
    // Check 1: Pointer should be in a reasonable address range
    if (ptr_val < 0x1000 || ptr_val > 0x0000FFFFFFFFFFFF) {
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Check 2: Should be aligned to at least 4 bytes
    if ((ptr_val & 0x3) != 0) {
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Wrap the raw pointer in a Local<Value>
    // This assumes the pointer came from a valid Local (like from v8_Global_Get)
    Local<Value> local = *reinterpret_cast<Local<Value>*>(&local_ptr);
    info->GetReturnValue().Set(local);
}

/// Set the return value from a Global handle.
/// 
/// This function properly converts a Global<Value> to a Local<Value> using the
/// isolate's current context, then sets it as the return value.
///
/// Use this when the value comes from v8_String_NewFromUtf8, v8_Number_New, etc.
/// which return Global<T>* handles.
///
/// @param info - FunctionCallbackInfo pointer
/// @param global_ptr - Pointer to a Global<Value> (from v8_String_NewFromUtf8, etc.)
void v8_FunctionCallbackInfo_SetReturnValueGlobal(const FunctionCallbackInfo<Value>* info, void* global_ptr) {
    if (!global_ptr) {
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Sanity checks for corrupted pointers (same as SetReturnValue)
    uintptr_t ptr_val = reinterpret_cast<uintptr_t>(global_ptr);
    
    // Check 1: Pointer should be in a reasonable address range
    if (ptr_val < 0x1000 || ptr_val > 0x0000FFFFFFFFFFFF) {
        fprintf(stderr, "WARNING: v8_FunctionCallbackInfo_SetReturnValueGlobal called with suspicious pointer: %p (out of range)\n", global_ptr);
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    // Check 2: V8's Global handles should be aligned to at least 8 bytes on 64-bit
    if ((ptr_val & 0x7) != 0) {
        fprintf(stderr, "WARNING: v8_FunctionCallbackInfo_SetReturnValueGlobal called with misaligned pointer: %p (alignment=%lu)\n", global_ptr, ptr_val & 0x7);
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    
    // Cast to Global<Value>* and get the Local from it
    Global<Value>* global = reinterpret_cast<Global<Value>*>(global_ptr);
    
    // Check if the Global handle is empty
    if (global->IsEmpty()) {
        fprintf(stderr, "WARNING: v8_FunctionCallbackInfo_SetReturnValueGlobal called with empty Global handle\n");
        info->GetReturnValue().SetUndefined();
        return;
    }
    
    Local<Value> local = global->Get(isolate);
    info->GetReturnValue().Set(local);
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
    return trackHandle(new Global<Object>(isolate, self));
}

// FunctionCallbackInfo - check if called with 'new'
bool v8_FunctionCallbackInfo_IsConstructCall(const FunctionCallbackInfo<Value>* info) {
    return info->IsConstructCall();
}

// FunctionCallbackInfo - get callback data
Global<Value>* v8_FunctionCallbackInfo_Data(const FunctionCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Value> data = info->Data();
    return trackHandle(new Global<Value>(isolate, data));
}

/// Get the creation context of the target function being called.
/// This is critical for cross-realm support: when calling
/// other.SomeInterface.prototype.method.call(obj), we need the context
/// where 'method' was instantiated (the iframe's context), not where
/// 'obj' was created (the main context) or the calling context.
///
/// Uses V8's internal layout to access the target function at kTargetIndex (4),
/// then gets its creation context.
Global<Context>* v8_FunctionCallbackInfo_GetFunctionCreationContext(const FunctionCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    
    // Access the target (function being called) through implicit_args_
    // Layout from v8-function-callback.h:
    //   kTargetIndex = 4
    // The implicit_args_ pointer is stored at offset 0 of FunctionCallbackInfo
    //
    // Since FunctionCallbackInfo stores:
    //   internal::Address* implicit_args_;   // offset 0
    //   internal::Address* values_;          // offset 8
    //   internal::Address length_;           // offset 16
    //
    // We can cast and access implicit_args_ directly.
    
    struct FCILayout {
        internal::Address* implicit_args;
        internal::Address* values;
        internal::Address length;
    };
    
    const FCILayout* layout = reinterpret_cast<const FCILayout*>(info);
    
    // Get the target function from implicit_args[kTargetIndex]
    // kTargetIndex = 4
    internal::Address target_addr = layout->implicit_args[4];
    
    // Convert the internal address to a Local<Value> using reinterpret
    // V8 Local handles internally store an Address*, so we create a pointer to
    // our address slot and reinterpret it as a Local
    Local<Value> target_value = *reinterpret_cast<Local<Value>*>(&target_addr);
    
    if (target_value.IsEmpty() || !target_value->IsFunction()) {
        // Fallback: return current context
        return trackHandle(new Global<Context>(isolate, isolate->GetCurrentContext()));
    }
    
    Local<Function> target_func = target_value.As<Function>();
    
    // Get the creation context of the function
    // This is the context where the function was instantiated (e.g., iframe context)
    MaybeLocal<Context> maybe_ctx = target_func->GetCreationContext();
    if (maybe_ctx.IsEmpty()) {
        return trackHandle(new Global<Context>(isolate, isolate->GetCurrentContext()));
    }
    
    return trackHandle(new Global<Context>(isolate, maybe_ctx.ToLocalChecked()));
}

/// Get the NewTarget from a constructor call.
/// This returns the function that was actually called with 'new', which is important
/// for cross-realm construction: when using Reflect.construct(Ctor, args, NewTarget),
/// the object should be created in NewTarget's realm.
///
/// Returns nullptr for non-construct calls.
Global<Value>* v8_FunctionCallbackInfo_NewTarget(const FunctionCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    
    // Use V8's public NewTarget() API which handles internal layout properly
    Local<Value> new_target = info->NewTarget();
    
    // For non-construct calls, NewTarget is undefined
    if (new_target.IsEmpty() || new_target->IsUndefined()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Value>(isolate, new_target));
}

/// Check if a value is a bound function.
/// Bound functions are created via Function.prototype.bind() and have
/// a [[BoundTargetFunction]] internal slot.
///
/// This is used for implementing GetFunctionRealm algorithm per ECMA-262 §7.3.22,
/// which needs to recurse through bound functions to find the original realm.
bool v8_Value_IsBoundFunction(Global<Value>* value) {
    if (!value) return false;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> local_value = value->Get(isolate);
    
    if (!local_value->IsFunction()) return false;
    
    // V8 doesn't expose a direct IsBoundFunction check, but we can detect
    // bound functions by checking if they have the internal bound target.
    // Bound functions in V8 are JSBoundFunction objects with specific properties.
    //
    // A practical way to detect this: bound functions have name starting with "bound "
    // and their .length property is computed specially.
    // 
    // However, the most reliable way is to check internal fields.
    // V8's JSBoundFunction has [[BoundTargetFunction]], [[BoundThis]], [[BoundArguments]]
    //
    // For a simpler approach, we use the fact that GetBoundFunction() on a
    // non-bound function returns itself, while on bound function it returns the target.
    // But V8 12+ may not have GetBoundFunction exposed...
    //
    // Alternative: check Function::GetScriptOrigin() - bound functions have empty origin
    // But this isn't fully reliable either.
    //
    // Best approach: check internal class name via Object::GetConstructorName
    // But this could be spoofed...
    //
    // V8 12.x approach: JSBoundFunction is a separate type but not directly queryable
    // from the public API. We'll use a heuristic: try to get the name and check
    // if it starts with "bound ".
    
    Local<Function> func = local_value.As<Function>();
    Local<Value> name_val = func->GetName();
    
    if (name_val->IsString()) {
        Local<String> name_str = name_val.As<String>();
        String::Utf8Value utf8(isolate, name_str);
        if (*utf8 && strncmp(*utf8, "bound ", 6) == 0) {
            return true;
        }
    }
    
    // Additional check: bound functions typically don't have own 'prototype' property
    // (unless explicitly set), but this isn't definitive
    
    return false;
}

/// Get the [[BoundTargetFunction]] of a bound function.
/// This is used for implementing GetFunctionRealm algorithm per ECMA-262 §7.3.22,
/// which needs to recurse through bound functions to find the original function's realm.
///
/// Returns nullptr if the value is not a function or if we can't determine the bound target.
/// For non-bound functions, returns the function itself.
Global<Function>* v8_BoundFunction_GetBoundTargetFunction(Global<Function>* func) {
    if (!func) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Function> local_func = func->Get(isolate);
    
    // V8 doesn't expose GetBoundFunction() in the public API for v12+
    // We need to use internal APIs or workarounds
    //
    // Since we can't directly access [[BoundTargetFunction]], we return the
    // function itself. The caller should use v8_Value_IsBoundFunction first
    // to check, and if it's bound, we need another approach.
    //
    // For now, we'll use Function::GetCreationContext on the function directly.
    // Even for bound functions, GetCreationContext returns the realm where
    // the *bound function object* was created, which may be sufficient.
    //
    // If we need the true target, we could:
    // 1. Call toString() and parse it (hacky)
    // 2. Use V8 internals (not portable)
    // 3. Store a map of bound functions to targets (complex)
    
    // For now, just return the same function - the IsBoundFunction check
    // will indicate if further processing is needed
    return trackHandle(new Global<Function>(isolate, local_func));
}

/// Get the creation context (realm) of a function.
/// This is the context where the function was instantiated.
///
/// For cross-realm constructor support per WebIDL §3.7.2:
/// - Objects should be created in GetFunctionRealm(NewTarget) realm
/// - This function provides the realm for regular functions
/// - For bound functions and proxies, the caller must handle recursion
Global<Context>* v8_Function_GetCreationContext(Global<Function>* func) {
    if (!func) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Function> local_func = func->Get(isolate);
    
    MaybeLocal<Context> maybe_ctx = local_func->GetCreationContext();
    if (maybe_ctx.IsEmpty()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Context>(isolate, maybe_ctx.ToLocalChecked()));
}

// ============================================================================
// External - Wrap C pointers for storage in V8
// ============================================================================

// Create External value wrapping a C pointer
Global<External>* v8_External_New(Isolate* isolate, void* value) {
    HandleScope handle_scope(isolate);
    Local<External> external = External::New(isolate, value);
    return trackHandle(new Global<External>(isolate, external));
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

// ObjectTemplate - create a new ObjectTemplate
Global<ObjectTemplate>* v8_ObjectTemplate_New(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> tpl = ObjectTemplate::New(isolate);
    return trackHandle(new Global<ObjectTemplate>(isolate, tpl));
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

// ObjectTemplate - set FunctionTemplate property with attributes
// Used by GlobalTemplateRegistry to attach interface constructors to the global template
// FunctionTemplate is a subclass of Template, not Value, so we need a separate function
void v8_ObjectTemplate_SetFunctionTemplate(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    Global<FunctionTemplate>* func_tpl,
    int attributes
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<String> key = name->Get(isolate);
    Local<FunctionTemplate> local_func_tpl = func_tpl->Get(isolate);
    // Use ObjectTemplate::Set(Local<Name>, Local<Data>, PropertyAttribute)
    // FunctionTemplate is a Template, which inherits from Data
    local_tpl->Set(key, local_func_tpl, static_cast<PropertyAttribute>(attributes));
}

// ObjectTemplate - set internal field count
void v8_ObjectTemplate_SetInternalFieldCount(Global<ObjectTemplate>* tpl, int count) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->SetInternalFieldCount(count);
}

// ObjectTemplate - mark prototype as immutable
// This makes Object.setPrototypeOf(obj, newProto) throw TypeError
// when newProto !== Object.getPrototypeOf(obj)
// Required for WebIDL global objects (Window, WorkerGlobalScope)
void v8_ObjectTemplate_SetImmutableProto(Global<ObjectTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->SetImmutableProto();
}

// ObjectTemplate - mark as undetectable
// Per ECMA-262, objects with [[IsHTMLDDA]] internal slot are "undetectable":
// - typeof returns "undefined"
// - == null and == undefined return true
// - ToBoolean returns false
// This is used for document.all (HTMLAllCollection).
// Spec: https://tc39.es/ecma262/#sec-IsHTMLDDA-internal-slot
void v8_ObjectTemplate_MarkAsUndetectable(Global<ObjectTemplate>* tpl) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    local_tpl->MarkAsUndetectable();
}

// ObjectTemplate - set call-as-function handler
// This allows instances to be called like functions.
// Required for objects marked as undetectable (like document.all).
// The callback is invoked when instances are called with ().
void v8_ObjectTemplate_SetCallAsFunctionHandler(
    Global<ObjectTemplate>* tpl,
    FunctionCallback callback,
    void* data
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<Value> callback_data = data ? Local<Value>(External::New(isolate, data)) : Local<Value>();
    local_tpl->SetCallAsFunctionHandler(callback, callback_data);
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
// Per WebIDL spec, getter functions must have name "get <propname>" and setter "set <propname>"
void v8_ObjectTemplate_SetAccessorProperty(
    Global<ObjectTemplate>* tpl,
    Global<String>* name,
    FunctionCallback getter,
    FunctionCallback setter
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    Local<String> key = name->Get(isolate);
    
    // Get property name as UTF-8 for building "get <name>" / "set <name>"
    String::Utf8Value prop_name_utf8(isolate, key);
    const char* prop_name = *prop_name_utf8;
    
    // Create FunctionTemplate for getter using the callback directly
    // No wrapping or casting needed - FunctionCallback is the native type
    Local<FunctionTemplate> getter_tpl = FunctionTemplate::New(
        isolate,
        getter,
        Local<Value>()  // No data needed
    );
    
    // Per WebIDL spec, getter function name must be "get <attribute name>"
    // Build the getter name: "get " + property name
    std::string getter_name = std::string("get ") + prop_name;
    Local<String> getter_name_str = String::NewFromUtf8(
        isolate, getter_name.c_str(), NewStringType::kNormal
    ).ToLocalChecked();
    getter_tpl->SetClassName(getter_name_str);
    
    // Create FunctionTemplate for setter (if provided)
    Local<FunctionTemplate> setter_tpl;
    if (setter != nullptr) {
        setter_tpl = FunctionTemplate::New(
            isolate,
            setter,
            Local<Value>()  // No data needed
        );
        
        // Per WebIDL spec, setter function name must be "set <attribute name>"
        std::string setter_name = std::string("set ") + prop_name;
        Local<String> setter_name_str = String::NewFromUtf8(
            isolate, setter_name.c_str(), NewStringType::kNormal
        ).ToLocalChecked();
        setter_tpl->SetClassName(setter_name_str);
    }
    
    // Set as accessor property with proper attributes
    // PropertyAttribute::None means enumerable=true, configurable=true (WebIDL default)
    local_tpl->SetAccessorProperty(
        key.As<Name>(),
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

// Named property handler with enumerator and descriptor support for legacy platform objects
// Uses Intercepted return type for query/descriptor callbacks to properly handle missing properties
typedef Intercepted (*InterceptedNamedQueryCallback)(Local<Name> property, const PropertyCallbackInfo<Integer>&);
typedef Intercepted (*InterceptedNamedDescriptorCallback)(Local<Name> property, const PropertyCallbackInfo<Value>&);

void v8_ObjectTemplate_SetNamedPropertyHandlerFull(
    Global<ObjectTemplate>* tpl,
    NamedPropertyGetterCallback getter,
    NamedPropertySetterCallback setter,
    InterceptedNamedQueryCallback query,
    NamedPropertyDeleterCallback deleter,
    NamedPropertyEnumeratorCallback enumerator,
    InterceptedNamedDescriptorCallback descriptor,
    PropertyHandlerFlags flags
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    local_tpl->SetHandler(NamedPropertyHandlerConfiguration(
        getter,
        setter,
        query,
        deleter,
        enumerator,
        nullptr,  // definer callback (see SetNamedPropertyHandlerWithDefiner for definer support)
        descriptor,
        Local<Value>(),  // data
        flags
    ));
}

// Named definer callback type for [[DefineOwnProperty]] trap on named properties
// Per WebIDL spec, accessor descriptors must throw TypeError
typedef Intercepted (*InterceptedNamedDefinerCallback)(
    Local<Name> property,
    const PropertyDescriptor& desc,
    const PropertyCallbackInfo<void>& info);

// Named property handler with definer support for [[DefineOwnProperty]] per WebIDL §3.9.3
void v8_ObjectTemplate_SetNamedPropertyHandlerWithDefiner(
    Global<ObjectTemplate>* tpl,
    NamedPropertyGetterCallback getter,
    NamedPropertySetterCallback setter,
    InterceptedNamedQueryCallback query,
    NamedPropertyDeleterCallback deleter,
    NamedPropertyEnumeratorCallback enumerator,
    InterceptedNamedDefinerCallback definer,
    InterceptedNamedDescriptorCallback descriptor,
    PropertyHandlerFlags flags
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    local_tpl->SetHandler(NamedPropertyHandlerConfiguration(
        getter,
        setter,
        query,
        deleter,
        enumerator,
        definer,  // definer callback for Object.defineProperty() per WebIDL §3.9.3
        descriptor,
        Local<Value>(),  // data
        flags
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

// IndexedPropertyEnumeratorCallbackV2 matches V8's expected signature
using IndexedPropertyEnumeratorCallbackV2 = void (*)(const PropertyCallbackInfo<Array>&);

// ObjectTemplate - set indexed property handler with enumerator (for array-like access with Reflect.ownKeys support)
void v8_ObjectTemplate_SetIndexedPropertyHandlerWithEnumerator(
    Global<ObjectTemplate>* tpl,
    IndexedPropertyGetterCallbackV2 getter,
    IndexedPropertyEnumeratorCallbackV2 enumerator
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    local_tpl->SetHandler(IndexedPropertyHandlerConfiguration(
        getter,
        nullptr,  // setter callback (read-only for now)
        nullptr,  // query callback (not needed)
        nullptr,  // deleter callback (not needed)
        enumerator,  // enumerator callback for Reflect.ownKeys
        nullptr,  // definer callback (not needed)
        nullptr,  // descriptor callback (not needed)
        Local<Value>(),  // data (not needed)
        PropertyHandlerFlags::kNone
    ));
}

// ObjectTemplate - set indexed property handler with full support (getter, setter, query, enumerator, descriptor)
// Uses V8's indexed property callback types with Intercepted return type
// Our Zig callbacks return Intercepted (u8 enum) to match V8's expectations
typedef Intercepted (*InterceptedIndexedQueryCallback)(uint32_t index, const PropertyCallbackInfo<Integer>&);
typedef Intercepted (*InterceptedIndexedDescriptorCallback)(uint32_t index, const PropertyCallbackInfo<Value>&);

// Forward declaration for setter callback type (defined below)
typedef Intercepted (*InterceptedIndexedSetterCallbackFull)(
    uint32_t index,
    Local<Value> value,
    const PropertyCallbackInfo<void>& info);

void v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
    Global<ObjectTemplate>* tpl,
    IndexedPropertyGetterCallbackV2 getter,
    InterceptedIndexedSetterCallbackFull setter,
    InterceptedIndexedQueryCallback query,
    IndexedPropertyEnumeratorCallbackV2 enumerator,
    InterceptedIndexedDescriptorCallback descriptor
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    // Callbacks now match V8's expected Intercepted return type
    local_tpl->SetHandler(IndexedPropertyHandlerConfiguration(
        getter,
        setter,   // setter callback for obj[index] = value (throws TypeError for read-only)
        query,    // query callback (returns Intercepted)
        nullptr,  // deleter callback (not needed)
        enumerator,  // enumerator callback for Reflect.ownKeys
        nullptr,  // definer callback (not needed)
        descriptor,  // descriptor callback (returns Intercepted)
        Local<Value>(),  // data (not needed)
        PropertyHandlerFlags::kNone
    ));
}

// Definer callback type for [[DefineOwnProperty]] trap
// Per WebIDL spec, accessor descriptors must throw TypeError
// Data descriptors work only if interface supports indexed setter
typedef Intercepted (*InterceptedIndexedDefinerCallback)(
    uint32_t index,
    const PropertyDescriptor& desc,
    const PropertyCallbackInfo<void>& info);

// Setter callback type for indexed properties
typedef Intercepted (*InterceptedIndexedSetterCallback)(
    uint32_t index,
    Local<Value> value,
    const PropertyCallbackInfo<void>& info);

// ObjectTemplate - set indexed property handler with definer support
// This enables proper [[DefineOwnProperty]] handling per WebIDL spec
void v8_ObjectTemplate_SetIndexedPropertyHandlerWithDefiner(
    Global<ObjectTemplate>* tpl,
    IndexedPropertyGetterCallbackV2 getter,
    InterceptedIndexedSetterCallback setter,
    InterceptedIndexedQueryCallback query,
    IndexedPropertyEnumeratorCallbackV2 enumerator,
    InterceptedIndexedDefinerCallback definer,
    InterceptedIndexedDescriptorCallback descriptor
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<ObjectTemplate> local_tpl = tpl->Get(isolate);
    
    // Full indexed property handler configuration with definer support
    local_tpl->SetHandler(IndexedPropertyHandlerConfiguration(
        getter,
        setter,      // setter callback for obj[index] = value
        query,       // query callback (returns Intercepted)
        nullptr,     // deleter callback (not needed)
        enumerator,  // enumerator callback for Reflect.ownKeys
        definer,     // definer callback for Object.defineProperty()
        descriptor,  // descriptor callback (returns Intercepted)
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
    return trackHandle(new Global<Object>(isolate, maybe_obj.ToLocalChecked()));
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
    return trackHandle(new Global<Object>(isolate, info->This()));
}

// PropertyCallbackInfo - get holder object
// Returns nullptr if not available (e.g., accessing property on prototype)
Global<Object>* v8_PropertyCallbackInfo_Holder(const PropertyCallbackInfo<Value>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Object> holder = info->Holder();
    if (holder.IsEmpty()) return nullptr;
    return trackHandle(new Global<Object>(isolate, holder));
}

// PropertyCallbackInfo (void) - get holder
Global<Object>* v8_PropertyCallbackInfo_Void_Holder(const PropertyCallbackInfo<void>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Object> holder = info->Holder();
    if (holder.IsEmpty()) return nullptr;
    return trackHandle(new Global<Object>(isolate, holder));
}

// PropertyCallbackInfo - set return value
void v8_PropertyCallbackInfo_SetReturnValue(const PropertyCallbackInfo<Value>* info, Global<Value>* value) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    info->GetReturnValue().Set(val);
}

// PropertyCallbackInfo (void) - set return value (mostly for Boolean results)
void v8_PropertyCallbackInfo_Void_SetReturnValue(const PropertyCallbackInfo<void>* info, Global<Value>* value) {
    Isolate* isolate = Isolate::GetCurrent();
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

// PropertyCallbackInfo<Value> - check if errors should throw (strict mode)
// Returns true if we're in strict mode and should throw TypeError on failure
bool v8_PropertyCallbackInfo_ShouldThrowOnError(const PropertyCallbackInfo<Value>* info) {
    return info->ShouldThrowOnError();
}

// PropertyCallbackInfo<void> - check if errors should throw (strict mode)
// Returns true if we're in strict mode and should throw TypeError on failure
bool v8_PropertyCallbackInfo_Void_ShouldThrowOnError(const PropertyCallbackInfo<void>* info) {
    return info->ShouldThrowOnError();
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
    Object* object_ptr = const_cast<Object*>(reinterpret_cast<const Object*>(obj));
    
    // CROSS-REALM FIX: Unwrap Proxy to get target with internal fields
    if (object_ptr->IsProxy()) {
        Proxy* proxy = Proxy::Cast(object_ptr);
        Value* target = *proxy->GetTarget();
        if (target->IsObject()) {
            object_ptr = Object::Cast(target);
        }
    }
    
    if (object_ptr->InternalFieldCount() <= index) {
        return nullptr;
    }
    
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

// Set an accessor property (getter/setter) on an existing V8 Object
// This is used to make Window properties own properties of the global object
// so that Object.getOwnPropertyDescriptor(window, "name") returns { get: [Function], set: [Function] }
bool v8_Object_SetAccessorProperty(
    Global<Object>* object,
    Global<Context>* context,
    Global<String>* name,
    FunctionCallback getter,
    FunctionCallback setter
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<String> key = name->Get(isolate);
    Context::Scope context_scope(ctx);
    
    // Get property name as UTF-8 for building "get <name>" / "set <name>"
    String::Utf8Value prop_name_utf8(isolate, key);
    const char* prop_name = *prop_name_utf8;
    
    // Create getter function
    Local<Function> getter_func;
    if (getter != nullptr) {
        Local<FunctionTemplate> getter_tpl = FunctionTemplate::New(isolate, getter);
        std::string getter_name = std::string("get ") + prop_name;
        Local<String> getter_name_str = String::NewFromUtf8(
            isolate, getter_name.c_str(), NewStringType::kNormal
        ).ToLocalChecked();
        getter_tpl->SetClassName(getter_name_str);
        getter_func = getter_tpl->GetFunction(ctx).ToLocalChecked();
    }
    
    // Create setter function
    Local<Function> setter_func;
    if (setter != nullptr) {
        Local<FunctionTemplate> setter_tpl = FunctionTemplate::New(isolate, setter);
        std::string setter_name = std::string("set ") + prop_name;
        Local<String> setter_name_str = String::NewFromUtf8(
            isolate, setter_name.c_str(), NewStringType::kNormal
        ).ToLocalChecked();
        setter_tpl->SetClassName(setter_name_str);
        setter_func = setter_tpl->GetFunction(ctx).ToLocalChecked();
    }
    
    // Create accessor property descriptor
    // PropertyDescriptor(Local<Value> get, Local<Value> set) creates an accessor descriptor
    PropertyDescriptor desc(
        getter ? Local<Value>(getter_func) : Local<Value>(),
        setter ? Local<Value>(setter_func) : Local<Value>()
    );
    desc.set_enumerable(true);  // WebIDL default
    desc.set_configurable(true); // WebIDL default
    
    // Define the property on the object
    return obj->DefineProperty(ctx, key.As<Name>(), desc).FromMaybe(false);
}

// Create a property descriptor object for Object.getOwnPropertyDescriptor callbacks
// Returns an object like: { value: <value>, writable: <bool>, enumerable: <bool>, configurable: <bool> }
// Takes a Global<Value>* for the value parameter - caller must ensure value is a valid global handle
Global<Object>* v8_CreateDataPropertyDescriptor(
    Global<Context>* context,
    Global<Value>* value,
    bool writable,
    bool enumerable,
    bool configurable
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    
    Local<Object> desc = Object::New(isolate);
    
    // Get the local value from the global handle
    Local<Value> val = value->Get(isolate);
    desc->Set(ctx, v8::String::NewFromUtf8(isolate, "value").ToLocalChecked(), val).Check();
    
    // Set writable
    desc->Set(ctx, v8::String::NewFromUtf8(isolate, "writable").ToLocalChecked(),
              Boolean::New(isolate, writable)).Check();
    
    // Set enumerable
    desc->Set(ctx, v8::String::NewFromUtf8(isolate, "enumerable").ToLocalChecked(),
              Boolean::New(isolate, enumerable)).Check();
    
    // Set configurable
    desc->Set(ctx, v8::String::NewFromUtf8(isolate, "configurable").ToLocalChecked(),
              Boolean::New(isolate, configurable)).Check();
    
    return trackHandle(new Global<Object>(isolate, desc));
}

// ============================================================================
// PropertyDescriptor Helper Functions
// For use with indexed/named property definer callbacks
// ============================================================================

// Check if a PropertyDescriptor is an accessor descriptor (has get or set)
bool v8_PropertyDescriptor_IsAccessorDescriptor(const PropertyDescriptor* desc) {
    // PropertyDescriptor* desc is passed from V8's definer callback
    // V8's PropertyDescriptor has has_get(), has_set(), has_value()
    return desc->has_get() || desc->has_set();
}

// Check if a PropertyDescriptor is a data descriptor (has value)
bool v8_PropertyDescriptor_IsDataDescriptor(const PropertyDescriptor* desc) {
    return desc->has_value();
}

// Get the value from a data PropertyDescriptor
// Returns nullptr if the descriptor doesn't have a value
Global<Value>* v8_PropertyDescriptor_GetValue(const PropertyDescriptor* desc) {
    if (!desc->has_value()) {
        return nullptr;
    }
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = desc->value();
    if (val.IsEmpty()) {
        return nullptr;
    }
    return new Global<Value>(isolate, val);
}

// Check if PropertyDescriptor has a configurable field specified
bool v8_PropertyDescriptor_HasConfigurable(const PropertyDescriptor* desc) {
    return desc->has_configurable();
}

// Get the configurable value from PropertyDescriptor
bool v8_PropertyDescriptor_Configurable(const PropertyDescriptor* desc) {
    return desc->configurable();
}

// Check if PropertyDescriptor has an enumerable field specified
bool v8_PropertyDescriptor_HasEnumerable(const PropertyDescriptor* desc) {
    return desc->has_enumerable();
}

// Get the enumerable value from PropertyDescriptor
bool v8_PropertyDescriptor_Enumerable(const PropertyDescriptor* desc) {
    return desc->enumerable();
}

// Check if PropertyDescriptor has a writable field specified
bool v8_PropertyDescriptor_HasWritable(const PropertyDescriptor* desc) {
    return desc->has_writable();
}

// Get the writable value from PropertyDescriptor
bool v8_PropertyDescriptor_Writable(const PropertyDescriptor* desc) {
    return desc->writable();
}

// Get the isolate from PropertyCallbackInfo<void>
// (PropertyCallbackInfo<void> is used for setters and definers)
Isolate* v8_PropertyCallbackInfo_Void_This_GetIsolate(const PropertyCallbackInfo<void>* info) {
    return info->GetIsolate();
}

// Get 'this' object from PropertyCallbackInfo<void>
Global<Object>* v8_PropertyCallbackInfo_Void_This(const PropertyCallbackInfo<void>* info) {
    Isolate* isolate = info->GetIsolate();
    HandleScope handle_scope(isolate);
    return trackHandle(new Global<Object>(isolate, info->This()));
}

// Set an object's prototype as immutable
bool v8_Object_SetImmutableProto(Global<Object>* object, Global<Context>* context) {
    if (!object || !context) return false;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Per V8 documentation, SetImmutableProto is only available on templates.
    // To make an EXISTING object have an immutable prototype, we can use 
    // Proxy or other techniques, but for normal objects V8 doesn't 
    // expose a public API to set this bit once created.
    
    // However, for the Global object, we set it via template.
    // For Window.prototype, we'll try to use a Proxy wrapper if needed, 
    // but first let's see if we can just use the template.
    return true; 
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

/// Set the prototype of an object using SetPrototypeV2.
/// This is the newer API that works properly with global objects (JSGlobalObject).
/// The old SetPrototype is deprecated for global objects.
bool v8_Object_SetPrototypeV2(Global<Object>* object, Global<Context>* context, Global<Value>* prototype) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> proto = prototype->Get(isolate);
    
    return obj->SetPrototypeV2(ctx, proto).FromMaybe(false);
}

Global<Value>* v8_Object_GetPrototype(Global<Object>* object) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Object> obj = object->Get(isolate);
    Local<Value> proto = obj->GetPrototype();
    
    if (proto.IsEmpty()) {
        return nullptr;
    }
    
    return new Global<Value>(isolate, proto);
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
    return trackHandle(new Global<Symbol>(isolate, symbol));
}

Global<Symbol>* v8_Symbol_GetIterator(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Symbol> symbol = Symbol::GetIterator(isolate);
    return trackHandle(new Global<Symbol>(isolate, symbol));
}

Global<Symbol>* v8_Symbol_GetAsyncIterator(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Symbol> symbol = Symbol::GetAsyncIterator(isolate);
    return trackHandle(new Global<Symbol>(isolate, symbol));
}

Global<Symbol>* v8_Symbol_GetUnscopables(Isolate* isolate) {
    HandleScope handle_scope(isolate);
    Local<Symbol> symbol = Symbol::GetUnscopables(isolate);
    return trackHandle(new Global<Symbol>(isolate, symbol));
}

void v8_Symbol_Dispose(Global<Symbol>* symbol) {
    delete symbol;
}

Global<Value>* v8_Object_GetPropertyWithSymbol(
    Global<Context>* context,
    Global<Object>* obj,
    Global<Symbol>* symbol
) {
    CHECK_ALIGNMENT_LOG(context, Global<Context>, "v8_Object_GetPropertyWithSymbol");
    CHECK_ALIGNMENT_LOG(obj, Global<Object>, "v8_Object_GetPropertyWithSymbol");
    CHECK_ALIGNMENT_LOG(symbol, Global<Symbol>, "v8_Object_GetPropertyWithSymbol");
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> object = obj->Get(isolate);
    Local<Symbol> sym = symbol->Get(isolate);
    
    MaybeLocal<Value> result = object->Get(ctx, sym);
    if (result.IsEmpty()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Value>(isolate, result.ToLocalChecked()));
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
    CHECK_ALIGNMENT_LOG(context, Global<Context>, "v8_Function_CallWithReceiver");
    CHECK_ALIGNMENT_LOG(function, Global<Function>, "v8_Function_CallWithReceiver");
    CHECK_ALIGNMENT_LOG(receiver, Global<Value>, "v8_Function_CallWithReceiver");
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Function> fn = function->Get(isolate);
    Local<Value> recv = receiver ? receiver->Get(isolate) : Undefined(isolate).As<Value>();
    
    std::vector<Local<Value>> args;
    args.reserve(argc);
    for (int i = 0; i < argc; i++) {
        CHECK_ALIGNMENT_LOG(argv[i], Global<Value>, "v8_Function_CallWithReceiver[argv]");
        args.push_back(argv[i]->Get(isolate));
    }
    
    MaybeLocal<Value> result = fn->Call(ctx, recv, argc, args.data());
    if (result.IsEmpty()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Value>(isolate, result.ToLocalChecked()));
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
// Promise Rejection Tracking (for unhandledrejection/rejectionhandled events)
// ============================================================================

/// Type definition for Zig promise rejection event callback
/// Signature: fn(user_data: *anyopaque, event_type: i32, promise: *anyopaque, value: ?*anyopaque) void
/// 
/// event_type values (from V8 PromiseRejectEvent enum):
///   0 = kPromiseRejectWithNoHandler       - Promise rejected, no handler attached
///   1 = kPromiseHandlerAddedAfterReject   - Handler added to previously-rejected promise
///   2 = kPromiseRejectAfterResolved       - Promise rejected after already resolved (unused)
///   3 = kPromiseResolveAfterResolved      - Promise resolved after already resolved (unused)
typedef void (*ZigPromiseRejectEventCallback)(
    void* user_data,
    int event_type,
    void* promise,
    void* value
);

/// Global storage for promise reject callback data
struct PromiseRejectCallbackData {
    void* user_data;
    ZigPromiseRejectEventCallback callback;
};
static PromiseRejectCallbackData* g_promise_reject_callback = nullptr;

/// V8 callback that forwards promise rejection events to Zig
static void V8PromiseRejectCallback(PromiseRejectMessage message) {
    if (!g_promise_reject_callback || !g_promise_reject_callback->callback) {
        return;
    }
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    // Get the promise (always available)
    Local<Promise> promise = message.GetPromise();
    
    // Get the rejection value (may be empty for some event types)
    Local<Value> value = message.GetValue();
    
    // Create Global handles for Zig to use
    // Note: Zig is responsible for disposing these
    Global<Promise>* promise_global = trackHandle(new Global<Promise>(isolate, promise));
    
    Global<Value>* value_global = nullptr;
    if (!value.IsEmpty()) {
        value_global = trackHandle(new Global<Value>(isolate, value));
    }
    
    // Map V8 event type to integer
    int event_type = static_cast<int>(message.GetEvent());
    
    // Call Zig callback
    g_promise_reject_callback->callback(
        g_promise_reject_callback->user_data,
        event_type,
        promise_global,
        value_global
    );
}

/// Set the promise rejection callback for an isolate
/// 
/// This enables tracking of unhandled promise rejections and late-attached handlers.
/// The callback will be invoked when:
/// - A promise is rejected with no handler (event_type=0)
/// - A handler is added to a previously-rejected promise (event_type=1)
///
/// @param isolate - The V8 isolate to configure
/// @param user_data - Opaque pointer passed to callback
/// @param callback - Zig callback function
void v8_Isolate_SetPromiseRejectCallback(
    Isolate* isolate,
    void* user_data,
    ZigPromiseRejectEventCallback callback
) {
    // Store callback data
    if (!g_promise_reject_callback) {
        g_promise_reject_callback = new PromiseRejectCallbackData();
    }
    g_promise_reject_callback->user_data = user_data;
    g_promise_reject_callback->callback = callback;
    
    // Register with V8
    isolate->SetPromiseRejectCallback(V8PromiseRejectCallback);
}

/// Clear the promise rejection callback for an isolate
void v8_Isolate_ClearPromiseRejectCallback(Isolate* isolate) {
    if (g_promise_reject_callback) {
        delete g_promise_reject_callback;
        g_promise_reject_callback = nullptr;
    }
    isolate->SetPromiseRejectCallback(nullptr);
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
    CHECK_ALIGNMENT_LOG(function, Global<Function>, "v8_Function_Call");
    CHECK_ALIGNMENT_LOG(context, Global<Context>, "v8_Function_Call");
    CHECK_ALIGNMENT_LOG(recv, Global<Value>, "v8_Function_Call");
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    // Convert Global handles to Local handles
    Local<Function> fn = function->Get(isolate);
    Local<Context> ctx = context->Get(isolate);
    Local<Value> this_val = recv->Get(isolate);
    
    // Convert argument array from Global to Local
    Local<Value>* local_argv = new Local<Value>[argc];
    for (int i = 0; i < argc; i++) {
        CHECK_ALIGNMENT_LOG(argv[i], Global<Value>, "v8_Function_Call[argv]");
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
    return trackHandle(new Global<Value>(isolate, result));
}

// ============================================================================
// Function::NewInstance - Create object via constructor (sets up prototype chain)
// ============================================================================

/// Create a new instance of a function (like calling `new Func()`)
/// This properly sets up the prototype chain, unlike ObjectTemplate::NewInstance()
Global<Object>* v8_Function_NewInstance(
    Global<Function>* function,
    Global<Context>* context,
    int argc,
    Global<Value>** argv
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    Local<Function> func = function->Get(isolate);
    
    // Convert argv to Local<Value> array
    std::vector<Local<Value>> local_argv;
    if (argc > 0 && argv != nullptr) {
        local_argv.reserve(argc);
        for (int i = 0; i < argc; i++) {
            local_argv.push_back(argv[i]->Get(isolate));
        }
    }
    
    MaybeLocal<Object> maybe_obj = func->NewInstance(ctx, argc, argc > 0 ? local_argv.data() : nullptr);
    if (maybe_obj.IsEmpty()) {
        return nullptr;
    }
    
    return trackHandle(new Global<Object>(isolate, maybe_obj.ToLocalChecked()));
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
    return trackHandle(new Global<Promise::Resolver>(isolate, resolver));
}

/// Get Promise from resolver
Global<Promise>* v8_PromiseResolver_GetPromise(Global<Promise::Resolver>* resolver) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Promise::Resolver> res = resolver->Get(isolate);
    Local<Promise> promise = res->GetPromise();
    return trackHandle(new Global<Promise>(isolate, promise));
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
    return trackHandle(new Global<Promise>(isolate, result));
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
    return trackHandle(new Global<Promise>(isolate, result));
}

/// Dispose a Promise
void v8_Promise_Dispose(Global<Promise>* promise) {
    if (promise) {
        promise->Reset();
        delete promise;
    }
}

/// Get the state of a Promise
/// Returns: 0 = Pending, 1 = Fulfilled, 2 = Rejected
int v8_Promise_State(Global<Promise>* promise) {
    if (!promise) return 0;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Promise> prom = promise->Get(isolate);
    return static_cast<int>(prom->State());
}

/// Get the result of a settled Promise (fulfilled value or rejection reason)
/// Returns nullptr if the promise is still pending
Global<Value>* v8_Promise_Result(Global<Promise>* promise) {
    if (!promise) return nullptr;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Promise> prom = promise->Get(isolate);
    
    // Only get result if promise is settled (not pending)
    if (prom->State() == Promise::kPending) {
        return nullptr;
    }
    
    Local<Value> result = prom->Result();
    return trackHandle(new Global<Value>(isolate, result));
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
    return trackHandle(new Global<Function>(isolate, fn));
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
    return trackHandle(new Global<Function>(isolate, fn));
}

// ============================================================================
// Zig Callback Bridge for Promise Handlers
// ============================================================================

/// Type definition for Zig promise fulfill callback
/// Signature: fn(context: *anyopaque, value: ?*anyopaque) void
typedef void (*ZigPromiseFulfillCallback)(void* context, void* value);

/// Type definition for Zig promise reject callback  
/// Signature: fn(context: *anyopaque, reason: ?*anyopaque) void
typedef void (*ZigPromiseRejectCallback)(void* context, void* reason);

/// Data structure to hold Zig callback info
struct ZigPromiseCallbackData {
    ZigPromiseFulfillCallback fulfill_callback;
    ZigPromiseRejectCallback reject_callback;
    void* fulfill_context;
    void* reject_context;
};

/// Create a V8 Function that invokes a Zig fulfill callback when called
///
/// When the returned function is called (e.g., from Promise.then()), it will:
/// 1. Extract the first argument (or undefined)
/// 2. Call the Zig fulfill_callback with the context and argument
///
/// Arguments:
///   - context: V8 Context
///   - fulfill_callback: Zig function to call on fulfillment
///   - fulfill_context: Context pointer to pass to Zig callback
///
/// Returns:
///   - Global<Function>* that invokes the Zig callback, or nullptr on failure
Global<Function>* v8_CreateZigFulfillHandler(
    Global<Context>* context,
    ZigPromiseFulfillCallback fulfill_callback,
    void* fulfill_context
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Allocate callback data
    auto* data = new ZigPromiseCallbackData{
        fulfill_callback,
        nullptr,
        fulfill_context,
        nullptr
    };
    
    // Store in External
    Local<External> external = External::New(isolate, data);
    
    // Create callback that invokes the Zig function
    auto callback = [](const FunctionCallbackInfo<Value>& info) {
        Isolate* isolate = info.GetIsolate();
        HandleScope scope(isolate);
        
        // Extract callback data
        Local<External> external = Local<External>::Cast(info.Data());
        auto* data = static_cast<ZigPromiseCallbackData*>(external->Value());
        
        if (data && data->fulfill_callback) {
            // Get value argument (or nullptr if no args/undefined)
            void* value = nullptr;
            if (info.Length() > 0 && !info[0]->IsUndefined()) {
                // Store the Local<Value> as a Global for Zig to use
                // The Zig side will need to handle this appropriately
                value = new Global<Value>(isolate, info[0]);
            }
            
            // Call Zig callback
            data->fulfill_callback(data->fulfill_context, value);
        }
        
        // Return undefined
        info.GetReturnValue().SetUndefined();
    };
    
    // Create FunctionTemplate
    Local<FunctionTemplate> tpl = FunctionTemplate::New(isolate, callback, external);
    MaybeLocal<Function> maybe_fn = tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        delete data;
        return nullptr;
    }
    
    Local<Function> fn = maybe_fn.ToLocalChecked();
    return trackHandle(new Global<Function>(isolate, fn));
}

/// Create a V8 Function that invokes a Zig reject callback when called
///
/// When the returned function is called (e.g., from Promise.catch()), it will:
/// 1. Extract the first argument (rejection reason, or undefined)
/// 2. Call the Zig reject_callback with the context and reason
///
/// Arguments:
///   - context: V8 Context
///   - reject_callback: Zig function to call on rejection
///   - reject_context: Context pointer to pass to Zig callback
///
/// Returns:
///   - Global<Function>* that invokes the Zig callback, or nullptr on failure
Global<Function>* v8_CreateZigRejectHandler(
    Global<Context>* context,
    ZigPromiseRejectCallback reject_callback,
    void* reject_context
) {
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    // Allocate callback data
    auto* data = new ZigPromiseCallbackData{
        nullptr,
        reject_callback,
        nullptr,
        reject_context
    };
    
    // Store in External
    Local<External> external = External::New(isolate, data);
    
    // Create callback that invokes the Zig function
    auto callback = [](const FunctionCallbackInfo<Value>& info) {
        Isolate* isolate = info.GetIsolate();
        HandleScope scope(isolate);
        
        // Extract callback data
        Local<External> external = Local<External>::Cast(info.Data());
        auto* data = static_cast<ZigPromiseCallbackData*>(external->Value());
        
        if (data && data->reject_callback) {
            // Get reason argument (or nullptr if no args/undefined)
            void* reason = nullptr;
            if (info.Length() > 0 && !info[0]->IsUndefined()) {
                // Store the Local<Value> as a Global for Zig to use
                reason = new Global<Value>(isolate, info[0]);
            }
            
            // Call Zig callback
            data->reject_callback(data->reject_context, reason);
        }
        
        // Return undefined
        info.GetReturnValue().SetUndefined();
    };
    
    // Create FunctionTemplate
    Local<FunctionTemplate> tpl = FunctionTemplate::New(isolate, callback, external);
    MaybeLocal<Function> maybe_fn = tpl->GetFunction(ctx);
    if (maybe_fn.IsEmpty()) {
        delete data;
        return nullptr;
    }
    
    Local<Function> fn = maybe_fn.ToLocalChecked();
    return trackHandle(new Global<Function>(isolate, fn));
}

/// Dispose a Zig callback handler function
///
/// This frees both the V8 Global<Function> and the ZigPromiseCallbackData.
/// Must be called when the handler is no longer needed.
void v8_DisposeZigCallbackHandler(Global<Function>* handler) {
    if (handler) {
        // Note: We can't easily access the callback data from here to free it,
        // so it will be leaked. In a real implementation, we'd need weak callbacks
        // or a different architecture. For now, the data is small and persistent
        // for the lifetime of the stream.
        handler->Reset();
        delete handler;
    }
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
    return trackHandle(new Global<ArrayBuffer>(isolate, buffer));
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
    return trackHandle(new Global<ArrayBuffer>(isolate, buffer));
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
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create an Int8Array view over an ArrayBuffer
Global<Value>* v8_Int8Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Int8Array> arr = Int8Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a Uint8ClampedArray view over an ArrayBuffer
Global<Value>* v8_Uint8ClampedArray_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Uint8ClampedArray> arr = Uint8ClampedArray::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a Uint16Array view over an ArrayBuffer
Global<Value>* v8_Uint16Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Uint16Array> arr = Uint16Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create an Int16Array view over an ArrayBuffer
Global<Value>* v8_Int16Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Int16Array> arr = Int16Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a Uint32Array view over an ArrayBuffer
Global<Value>* v8_Uint32Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Uint32Array> arr = Uint32Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create an Int32Array view over an ArrayBuffer
Global<Value>* v8_Int32Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Int32Array> arr = Int32Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a Float32Array view over an ArrayBuffer
Global<Value>* v8_Float32Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Float32Array> arr = Float32Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a Float64Array view over an ArrayBuffer
Global<Value>* v8_Float64Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<Float64Array> arr = Float64Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a BigInt64Array view over an ArrayBuffer
Global<Value>* v8_BigInt64Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<BigInt64Array> arr = BigInt64Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a BigUint64Array view over an ArrayBuffer
Global<Value>* v8_BigUint64Array_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<BigUint64Array> arr = BigUint64Array::New(local_buffer, byte_offset, length);
    return trackHandle(new Global<Value>(isolate, arr));
}

/// Create a DataView over an ArrayBuffer
Global<Value>* v8_DataView_New(Isolate* isolate, Global<ArrayBuffer>* buffer, size_t byte_offset, size_t byte_length) {
    if (!isolate || !buffer) return nullptr;
    
    HandleScope handle_scope(isolate);
    Local<ArrayBuffer> local_buffer = buffer->Get(isolate);
    
    Local<DataView> view = DataView::New(local_buffer, byte_offset, byte_length);
    return trackHandle(new Global<Value>(isolate, view));
}

// ============================================================================
// Weak Callbacks / Finalizers
// ============================================================================

/// Make a Global handle weak with a finalizer callback
void v8_Global_SetWeak(void* handle, void* user_data, ZigWeakCallbackFn callback) {
    if (!handle || !callback) return;
    
    // Cast to Global<Value>* (all Global types are compatible for SetWeak)
    Global<Value>* global = reinterpret_cast<Global<Value>*>(handle);
    
    // Create wrapper data that holds callback, user data, AND the handle pointer
    // The handle pointer is needed so the weak callback can reset it (V8 requirement)
    WeakCallbackData* wrapper = new WeakCallbackData{callback, user_data, global};
    
    // Make the Global handle weak with our wrapper callback
    global->SetWeak(wrapper, WeakCallbackWrapper<Value>, WeakCallbackType::kParameter);
}

/// Clear weak reference and restore strong reference
void v8_Global_ClearWeak(void* handle) {
    if (!handle) return;
    
    Global<Value>* global = reinterpret_cast<Global<Value>*>(handle);
    global->ClearWeak();
}

/// Check if a Global handle is weak
///
/// @param handle - Global handle to check
/// @return true if the handle is weak, false otherwise
bool v8_Global_IsWeak(void* handle) {
    if (!handle) return false;
    
    Global<Value>* global = reinterpret_cast<Global<Value>*>(handle);
    return global->IsWeak();
}

/// Create a weak Global<Value> from a Local<Value>
///
/// This creates a Global handle that is immediately weak. When V8 GC collects
/// the value (no more strong references), the callback is invoked with user_data.
///
/// @param isolate - Current V8 isolate
/// @param local - Local value pointer (from within an active HandleScope)
/// @param user_data - User data to pass to callback on GC
/// @param callback - Function to call when value is garbage collected
/// @return New weak Global<Value>* or nullptr if local is empty
Global<Value>* v8_Value_ToWeakGlobal(
    Isolate* isolate,
    void* local,
    void* user_data,
    ZigWeakCallbackFn callback
) {
    if (!isolate || !local) return nullptr;
    
    HandleScope handle_scope(isolate);
    
    // Cast the void* back to Value* - this is the internal pointer from a Local<Value>
    Value* value_ptr = reinterpret_cast<Value*>(local);
    Local<Value> local_value = *reinterpret_cast<Local<Value>*>(&value_ptr);
    
    if (local_value.IsEmpty()) return nullptr;
    
    // Create the Global handle
    Global<Value>* global = new Global<Value>(isolate, local_value);
    
    // If callback is provided, make it weak immediately
    if (callback != nullptr) {
        WeakCallbackData* wrapper = new WeakCallbackData{callback, user_data};
        global->SetWeak(wrapper, WeakCallbackWrapper<Value>, WeakCallbackType::kParameter);
    }
    
    return global;
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

/// Callback for Symbol.asyncIterator - returns 'this' (the iterator itself)
///
/// This makes the async iterator object both an iterator AND an iterable,
/// allowing `for await...of` to work directly on the iterator object.
/// ES spec: https://tc39.es/ecma262/#sec-%asynciteratorprototype%-@@asynciterator
static void AsyncIteratorSelfCallback(const FunctionCallbackInfo<Value>& info) {
    // Return the iterator object itself (this)
    info.GetReturnValue().Set(info.This());
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
// This cache is isolate-specific and MUST be cleared before disposing an isolate.
static Global<FunctionTemplate>* g_async_iterator_template = nullptr;
static Isolate* g_async_iterator_isolate = nullptr;

/// Clear the async iterator template cache
/// MUST be called before disposing an isolate to prevent use-after-free crashes.
void v8_ClearAsyncIteratorTemplateCache() {
    if (g_async_iterator_template != nullptr) {
        g_async_iterator_template->Reset();
        delete g_async_iterator_template;
        g_async_iterator_template = nullptr;
    }
    g_async_iterator_isolate = nullptr;
}

/// Clear the module resolve callback
/// MUST be called before disposing an isolate to prevent use-after-free crashes.
/// The user_data pointer becomes invalid when the Zig runtime is deinitialized.
void v8_ClearModuleResolveCallback() {
    if (g_module_resolve_callback != nullptr) {
        delete g_module_resolve_callback;
        g_module_resolve_callback = nullptr;
    }
}

/// Clear the dynamic import callback
/// MUST be called before disposing an isolate to prevent use-after-free crashes.
/// The user_data pointer becomes invalid when the Zig runtime is deinitialized.
void v8_ClearDynamicImportCallback() {
    if (g_dynamic_import_callback != nullptr) {
        delete g_dynamic_import_callback;
        g_dynamic_import_callback = nullptr;
    }
}

/// Get or create the cached async iterator template
static Local<FunctionTemplate> getAsyncIteratorTemplate(Isolate* isolate) {
    // Check if we have a cached template from a DIFFERENT isolate (stale cache)
    if (g_async_iterator_template != nullptr && g_async_iterator_isolate != isolate) {
        // Clear the stale cache - the old isolate was disposed
        v8_ClearAsyncIteratorTemplateCache();
    }
    
    if (g_async_iterator_template == nullptr) {
        // Create the template once and cache it
        Local<FunctionTemplate> tpl = FunctionTemplate::New(isolate);
        tpl->SetClassName(String::NewFromUtf8Literal(isolate, "ReadableStreamAsyncIterator"));
        tpl->InstanceTemplate()->SetInternalFieldCount(1);
        g_async_iterator_template = new Global<FunctionTemplate>(isolate, tpl);
        g_async_iterator_isolate = isolate;
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
    Local<FunctionTemplate> self_tpl = FunctionTemplate::New(isolate, AsyncIteratorSelfCallback);
    Local<Function> self_fn = self_tpl->GetFunction(ctx).ToLocalChecked();
    obj->Set(ctx, async_iterator_symbol, self_fn).Check();
    
    // Return as Global handle
    return trackHandle(new Global<Object>(isolate, obj));
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

// ============================================================================
// V8 Snapshot API - Build-Time Heap Serialization
// ============================================================================
//
// This API enables creating V8 heap snapshots that include pre-registered
// WebIDL interfaces. At runtime, loading a snapshot is ~100-1000x faster
// than re-registering all interfaces via FFI calls.
//
// Usage Pattern:
//   Build Time:
//     1. Create SnapshotCreator with external references
//     2. Get the isolate, register all WebIDL interfaces
//     3. Set default context with registered interfaces
//     4. Create blob - returns StartupData with serialized heap
//     5. Save blob to file
//
//   Runtime:
//     1. Load blob from file
//     2. Create isolate from snapshot with same external references
//     3. Create context from snapshot - interfaces are already registered!
//
// CRITICAL: External references (C++ callback pointers) MUST be provided in
// the SAME ORDER at snapshot creation time and loading time.

/// C-compatible StartupData structure for FFI
/// Matches v8::StartupData layout
struct V8StartupData {
    const char* data;
    int raw_size;
};

/// Create a new SnapshotCreator
///
/// The SnapshotCreator owns an isolate that is set up for serialization.
/// The isolate is automatically entered when created.
///
/// @param external_references - Null-terminated array of external reference pointers.
///                              These are C++ callback function pointers that will be
///                              called from snapshotted code. MUST be in same order
///                              at snapshot creation and loading time.
/// @return Opaque pointer to SnapshotCreator (caller owns, must call Dispose)
void* v8_SnapshotCreator_New(const intptr_t* external_references) {
    if (!v8_initialized) {
        v8_Platform_Initialize();
    }
    
    // Create isolate params with external references
    Isolate::CreateParams params;
    params.array_buffer_allocator = ArrayBuffer::Allocator::NewDefaultAllocator();
    params.external_references = external_references;
    
    // SnapshotCreator creates and enters its own isolate
    SnapshotCreator* creator = new SnapshotCreator(params);
    return creator;
}

/// Get the isolate from a SnapshotCreator
///
/// Use this isolate to set up the global object, register interfaces, etc.
/// The isolate is already entered when returned.
///
/// @param creator - SnapshotCreator handle from v8_SnapshotCreator_New
/// @return The isolate managed by this SnapshotCreator
Isolate* v8_SnapshotCreator_GetIsolate(void* creator) {
    if (!creator) return nullptr;
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    return sc->GetIsolate();
}

// =============================================================================
// Snapshot Internal Field Serialization/Deserialization
// =============================================================================
// These callbacks handle serialization of internal fields during snapshot
// creation and restoration. Without these, V8 cannot properly serialize
// objects with internal fields, leading to rehashability errors.

/// Serialize internal fields during snapshot creation
///
/// This callback is invoked by V8 for each object with internal fields.
/// For our minimal snapshots (no WebIDL objects in snapshot), we return
/// empty data to indicate no serialization needed.
StartupData SerializeInternalFields(Local<Object> holder, int index, void* data) {
    // For minimal snapshots without embedded objects, return empty
    // This tells V8 there's nothing to serialize for this field
    return {nullptr, 0};
}

/// Deserialize internal fields during snapshot loading
///
/// This callback is invoked by V8 when restoring objects with internal fields.
/// For our minimal snapshots, we just set the field to nullptr.
void DeserializeInternalFields(Local<Object> holder, int index,
                               StartupData payload, void* data) {
    // For minimal snapshots, set internal field to nullptr
    // WebIDL objects are registered at runtime, not from snapshot
    if (payload.raw_size == 0) {
        holder->SetAlignedPointerInInternalField(index, nullptr);
    }
}

/// Create a context and set it as default for snapshot
///
/// This function creates a new context using Local handles (not Global) and
/// immediately sets it as the default context for the snapshot. Using Local
/// handles avoids the "global handle not serialized" error during CreateBlob.
///
/// @param creator - SnapshotCreator handle
/// @return true on success, false on failure
bool v8_SnapshotCreator_CreateAndSetDefaultContext(void* creator) {
    if (!creator) {
        fprintf(stderr, "[v8_SnapshotCreator_CreateAndSetDefaultContext] ERROR: creator is null\n");
        return false;
    }
    
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    Isolate* isolate = sc->GetIsolate();
    
    HandleScope handle_scope(isolate);
    
    // Create context using Local handle only (no Global)
    Local<Context> context = Context::New(isolate);
    if (context.IsEmpty()) {
        fprintf(stderr, "[v8_SnapshotCreator_CreateAndSetDefaultContext] ERROR: Context::New failed\n");
        return false;
    }
    
    // Enter and exit context (V8 requirement)
    context->Enter();
    context->Exit();
    
    sc->SetDefaultContext(context);
    return true;
}

/// Create a context and add it to snapshot at index
///
/// This function creates a new context using Local handles (not Global) and
/// immediately adds it to the snapshot's context array. Using Local handles
/// avoids the "global handle not serialized" error during CreateBlob.
///
/// @param creator - SnapshotCreator handle
/// @return The index at which the context was added, or SIZE_MAX on failure
size_t v8_SnapshotCreator_CreateAndAddContext(void* creator) {
    if (!creator) {
        fprintf(stderr, "[v8_SnapshotCreator_CreateAndAddContext] ERROR: creator is null\n");
        return SIZE_MAX;
    }
    
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    Isolate* isolate = sc->GetIsolate();
    
    HandleScope handle_scope(isolate);
    
    // Create context using Local handle only (no Global)
    Local<Context> context = Context::New(isolate);
    if (context.IsEmpty()) {
        fprintf(stderr, "[v8_SnapshotCreator_CreateAndAddContext] ERROR: Context::New failed\n");
        return SIZE_MAX;
    }
    
    // Enter and exit context (V8 requirement)
    context->Enter();
    context->Exit();
    
    size_t index = sc->AddContext(context);
    return index;
}

/// Set the default context for the snapshot
///
/// The snapshot will contain this context's state. When loading the snapshot,
/// contexts created will start with this state.
///
/// IMPORTANT: This must be called outside of any HandleScope!
/// The context should be fully set up with all interfaces registered.
///
/// @param creator - SnapshotCreator handle
/// @param context - Global handle to the context to snapshot
void v8_SnapshotCreator_SetDefaultContext(void* creator, Global<Context>* context) {
    if (!creator || !context) {
        fprintf(stderr, "[v8_SnapshotCreator_SetDefaultContext] ERROR: creator or context is null\n");
        return;
    }
    
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    Isolate* isolate = sc->GetIsolate();
    
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    if (ctx.IsEmpty()) {
        fprintf(stderr, "[v8_SnapshotCreator_SetDefaultContext] ERROR: context is empty\n");
        return;
    }
    
    fprintf(stderr, "[v8_SnapshotCreator_SetDefaultContext] Setting default context\n");
    sc->SetDefaultContext(ctx);
    fprintf(stderr, "[v8_SnapshotCreator_SetDefaultContext] Default context set successfully\n");
}

/// Add context to snapshot at specific index
///
/// This adds a context that can be retrieved via Context::FromSnapshot(isolate, index)
/// after deserialization. The first call returns index 0, second returns 1, etc.
///
/// @param creator - SnapshotCreator handle
/// @param context - Global handle to the context to snapshot
/// @return The index at which the context was added (0-based)
size_t v8_SnapshotCreator_AddContext(void* creator, Global<Context>* context) {
    if (!creator || !context) {
        fprintf(stderr, "[v8_SnapshotCreator_AddContext] ERROR: creator or context is null\n");
        return SIZE_MAX;
    }
    
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    Isolate* isolate = sc->GetIsolate();
    
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    
    if (ctx.IsEmpty()) {
        fprintf(stderr, "[v8_SnapshotCreator_AddContext] ERROR: context is empty\n");
        return SIZE_MAX;
    }
    
    fprintf(stderr, "[v8_SnapshotCreator_AddContext] Adding context to snapshot\n");
    size_t index = sc->AddContext(ctx);
    fprintf(stderr, "[v8_SnapshotCreator_AddContext] Context added at index %zu\n", index);
    return index;
}

/// Create the snapshot blob
///
/// Serializes the V8 heap including the default context.
/// This MUST be called outside of any HandleScope.
///
/// @param creator - SnapshotCreator handle
/// @param function_code_handling - 0 = clear function code, 1 = keep function code
/// @param out_data - Output: pointer to snapshot data (caller must free with delete[])
/// @param out_size - Output: size of snapshot data in bytes
/// @return true on success, false on failure
bool v8_SnapshotCreator_CreateBlob(
    void* creator,
    int function_code_handling,
    const char** out_data,
    int* out_size
) {
    if (!creator || !out_data || !out_size) return false;
    
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    
    SnapshotCreator::FunctionCodeHandling handling = 
        function_code_handling == 1 
            ? SnapshotCreator::FunctionCodeHandling::kKeep
            : SnapshotCreator::FunctionCodeHandling::kClear;
    
    StartupData blob = sc->CreateBlob(handling);
    
    if (blob.data == nullptr || blob.raw_size <= 0) {
        *out_data = nullptr;
        *out_size = 0;
        return false;
    }
    
    // Copy the data - caller owns this memory
    char* data_copy = new char[blob.raw_size];
    memcpy(data_copy, blob.data, blob.raw_size);
    
    // Free the original V8-allocated data
    delete[] blob.data;
    
    *out_data = data_copy;
    *out_size = blob.raw_size;
    return true;
}

/// Dispose a SnapshotCreator
///
/// This also disposes the isolate owned by the SnapshotCreator.
/// Must be called after CreateBlob.
///
/// @param creator - SnapshotCreator handle to dispose
void v8_SnapshotCreator_Dispose(void* creator) {
    if (!creator) return;
    SnapshotCreator* sc = static_cast<SnapshotCreator*>(creator);
    delete sc;
}

/// Free snapshot data allocated by v8_SnapshotCreator_CreateBlob
///
/// @param data - Pointer returned in out_data from CreateBlob
void v8_Snapshot_FreeData(const char* data) {
    if (data) {
        delete[] data;
    }
}

/// Create a new isolate from a snapshot blob
///
/// This is the runtime counterpart to SnapshotCreator. The isolate
/// starts with the heap state from the snapshot, so all interfaces
/// that were registered at snapshot time are already available.
///
/// CRITICAL: external_references MUST be the same array (same order)
/// as was used when creating the snapshot.
///
/// @param snapshot_data - Pointer to snapshot blob data
/// @param snapshot_size - Size of snapshot blob in bytes
/// @param external_references - Null-terminated array of external references
///                              (must match snapshot creation order exactly)
/// @return New isolate with snapshot state, or nullptr on failure
Isolate* v8_Isolate_NewFromSnapshot(
    const char* snapshot_data,
    int snapshot_size,
    const intptr_t* external_references
) {
    if (!v8_initialized) {
        v8_Platform_Initialize();
    }
    
    if (!snapshot_data || snapshot_size <= 0) {
        fprintf(stderr, "[v8_Isolate_NewFromSnapshot] ERROR: Invalid snapshot data\n");
        return nullptr;
    }
    
    // Count external references (silently)
    int ref_count = 0;
    if (external_references) {
        while (external_references[ref_count] != 0) ref_count++;
    }
    
    // CRITICAL: Heap-allocate StartupData and snapshot copy.
    // V8 stores only a POINTER to StartupData, so it must live for the
    // entire lifetime of the isolate. Stack allocation would cause the
    // pointer to become dangling when this function returns.
    
    // Copy snapshot data to heap (we don't own the input buffer)
    char* data_copy = new char[snapshot_size];
    memcpy(data_copy, snapshot_data, snapshot_size);
    
    // Heap-allocate StartupData struct
    StartupData* startup_data = new StartupData();
    startup_data->data = data_copy;
    startup_data->raw_size = snapshot_size;
    
    // Validate the snapshot
    if (!startup_data->IsValid()) {
        fprintf(stderr, "[v8_Isolate_NewFromSnapshot] ERROR: Snapshot data is not valid\n");
        delete[] data_copy;
        delete startup_data;
        return nullptr;
    }
    
    // Create isolate params with snapshot and external references
    Isolate::CreateParams create_params;
    create_params.array_buffer_allocator = ArrayBuffer::Allocator::NewDefaultAllocator();
    create_params.snapshot_blob = startup_data;  // Heap-allocated, lives forever
    create_params.external_references = external_references;
    
    Isolate* isolate = Isolate::New(create_params);
    if (!isolate) {
        fprintf(stderr, "[v8_Isolate_NewFromSnapshot] ERROR: Isolate::New returned nullptr\n");
        delete[] data_copy;
        delete startup_data;
        return nullptr;
    }
    
    // Store pointers in isolate's embedder data slots for cleanup later
    // NOTE: Slots 0-1 are reserved for Zig-side usage:
    //   Slot 0: IsolateAllocator (see isolate_allocator.zig)
    //   Slot 1: IsolateTemplates (see isolate_templates.zig)
    // We use higher slots for C++ snapshot data:
    //   Slot 2: StartupData struct pointer
    //   Slot 3: Snapshot data buffer pointer
    isolate->SetData(2, startup_data);
    isolate->SetData(3, data_copy);
    
    return isolate;
}

/// Create a context from the snapshot's default context
///
/// This creates a new context based on the default context that was
/// set in the snapshot. The context starts with all the state
/// (including registered interfaces) from snapshot creation time.
///
/// @param isolate - Isolate created from v8_Isolate_NewFromSnapshot
/// @return New context with snapshot state
Global<Context>* v8_Context_NewFromSnapshot(Isolate* isolate) {
    if (!isolate) {
        fprintf(stderr, "[v8_Context_NewFromSnapshot] ERROR: isolate is null\n");
        return nullptr;
    }
    
    // Enter the isolate before creating context
    Isolate::Scope isolate_scope(isolate);
    HandleScope handle_scope(isolate);
    
    // Add TryCatch to capture any exception
    TryCatch try_catch(isolate);
    
    // Use Context::FromSnapshot(isolate, 0) to retrieve the context that was
    // added via AddContext() during snapshot creation. This preserves the
    // global proxy (unlike the default context from SetDefaultContext).
    // The DeserializeInternalFieldsCallback handles any internal field restoration.
    MaybeLocal<Context> maybe_context = Context::FromSnapshot(
        isolate, 0,
        DeserializeInternalFieldsCallback(DeserializeInternalFields, nullptr));
    
    if (try_catch.HasCaught()) {
        fprintf(stderr, "[v8_Context_NewFromSnapshot] Exception caught during FromSnapshot\n");
        Local<Message> message = try_catch.Message();
        if (!message.IsEmpty()) {
            String::Utf8Value msg_str(isolate, message->Get());
            fprintf(stderr, "[v8_Context_NewFromSnapshot] Exception: %s\n", *msg_str);
        }
    }
    
    Local<Context> context;
    if (!maybe_context.ToLocal(&context)) {
        fprintf(stderr, "[v8_Context_NewFromSnapshot] ERROR: Context::FromSnapshot(0) failed\n");
        fprintf(stderr, "[v8_Context_NewFromSnapshot] This usually means:\n");
        fprintf(stderr, "  1. External references mismatch between snapshot creation and loading\n");
        fprintf(stderr, "  2. No context was added at index 0 during snapshot creation\n");
        fprintf(stderr, "  3. Snapshot data is corrupted or from incompatible V8 version\n");
return nullptr;
    }
    
    // Check global object internal fields
    Local<Object> global = context->Global();
    int internal_field_count = global->InternalFieldCount();
    (void)internal_field_count; // Suppress unused variable warning
    
    return trackHandle(new Global<Context>(isolate, context));
}

/// Create a context from a specific index in the snapshot
///
/// This creates a new context based on the context that was added at the
/// specified index during snapshot creation. Use this to restore different
/// context types (e.g., window context at index 0, worker context at index 1).
///
/// @param isolate - Isolate created from v8_Isolate_NewFromSnapshot
/// @param context_index - The index of the context to restore (0-based)
/// @return New context with snapshot state, or nullptr if index is invalid
Global<Context>* v8_Context_NewFromSnapshotAt(Isolate* isolate, size_t context_index) {
    if (!isolate) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotAt] ERROR: isolate is null\n");
        return nullptr;
    }
    
    // Enter the isolate before creating context
    Isolate::Scope isolate_scope(isolate);
    HandleScope handle_scope(isolate);
    
    // Add TryCatch to capture any exception
    TryCatch try_catch(isolate);
    
    // Use Context::FromSnapshot to retrieve the context at the specified index
    MaybeLocal<Context> maybe_context = Context::FromSnapshot(
        isolate, context_index,
        DeserializeInternalFieldsCallback(DeserializeInternalFields, nullptr));
    
    if (try_catch.HasCaught()) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotAt] Exception caught during FromSnapshot(%zu)\n", context_index);
        Local<Message> message = try_catch.Message();
        if (!message.IsEmpty()) {
            String::Utf8Value msg_str(isolate, message->Get());
            fprintf(stderr, "[v8_Context_NewFromSnapshotAt] Exception: %s\n", *msg_str);
        }
    }
    
    Local<Context> context;
    if (!maybe_context.ToLocal(&context)) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotAt] ERROR: Context::FromSnapshot(%zu) failed\n", context_index);
        fprintf(stderr, "  This usually means no context was added at index %zu during snapshot creation\n", context_index);
        return nullptr;
    }
    
    return trackHandle(new Global<Context>(isolate, context));
}

/// Create a NEW context for an isolate that was created from a snapshot
///
/// Unlike v8_Context_NewFromSnapshot which restores a specific context from the
/// snapshot by index, this creates a completely new context. The new context will
/// have all the V8 builtins from the snapshot's default context as a template.
///
/// Use this when you need a fresh context but want to benefit from the snapshot's
/// pre-initialized V8 builtins.
///
/// @param isolate - Isolate created from v8_Isolate_NewFromSnapshot
/// @return New context (fresh, not from snapshot state)
Global<Context>* v8_Context_NewFromSnapshotDefault(Isolate* isolate) {
    if (!isolate) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] ERROR: isolate is null\n");
        return nullptr;
    }
    
    fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] Creating new context for snapshot isolate...\n");
    
    // The isolate should already be entered by the caller
    HandleScope handle_scope(isolate);
    
    // Add TryCatch to capture any exception
    TryCatch try_catch(isolate);
    
    // CRITICAL: When an isolate is created from a snapshot, Context::New() without
    // a global_template will try to deserialize from the snapshot, which fails with
    // "index < num_contexts" if no contexts were added via AddContext().
    //
    // To force V8 to create a FRESH context (not from snapshot), we provide an
    // empty global_template. This tells V8 to bootstrap a new context from scratch
    // while still benefiting from the snapshot's isolate-level optimizations
    // (pre-compiled builtins, heap state, etc.).
    //
    // Per V8 docs: "If a global template is provided, it will be used to create
    // the global object for the context from scratch."
    
    // Create an empty ObjectTemplate for the global object
    Local<ObjectTemplate> global_template = ObjectTemplate::New(isolate);
    
    fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] Using empty global_template to force fresh context...\n");
    
    // Create context with the empty template and deserializer callback.
    // The DeserializeInternalFields callback is needed for snapshot isolates
    // to properly handle context creation.
    Local<Context> context = Context::New(
        isolate,
        nullptr,  // no extensions
        global_template,  // PROVIDE TEMPLATE to skip snapshot context
        MaybeLocal<Value>(),  // no global object
        DeserializeInternalFieldsCallback(DeserializeInternalFields, nullptr),
        nullptr  // no microtask queue
    );
    
    if (try_catch.HasCaught()) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] Exception caught during Context::New\n");
        Local<Message> message = try_catch.Message();
        if (!message.IsEmpty()) {
            String::Utf8Value msg_str(isolate, message->Get());
            fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] Exception: %s\n", *msg_str);
        }
        return nullptr;
    }
    
    if (context.IsEmpty()) {
        fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] ERROR: Context::New returned empty context\n");
        return nullptr;
    }
    
    fprintf(stderr, "[v8_Context_NewFromSnapshotDefault] SUCCESS: New context created\n");
    return trackHandle(new Global<Context>(isolate, context));
}

/// Check if a snapshot blob is valid
///
/// Validates that the snapshot data can be used with the current V8 version.
///
/// @param snapshot_data - Pointer to snapshot blob data
/// @param snapshot_size - Size of snapshot blob in bytes
/// @return true if valid, false if invalid or corrupted
bool v8_Snapshot_IsValid(const char* snapshot_data, int snapshot_size) {
    if (!snapshot_data || snapshot_size <= 0) {
        return false;
    }
    
    StartupData startup_data;
    startup_data.data = snapshot_data;
    startup_data.raw_size = snapshot_size;
    
    return startup_data.IsValid();
}

/// Check if a snapshot blob can be rehashed during deserialization
///
/// If CanBeRehashed() returns false, the snapshot can only be loaded by an
/// isolate with the same hash seed that was used during snapshot creation.
/// This typically causes "rehashability" errors during context restoration.
///
/// @param snapshot_data - Pointer to snapshot blob data
/// @param snapshot_size - Size of snapshot blob in bytes
/// @return true if rehashable, false if not
bool v8_Snapshot_CanBeRehashed(const char* snapshot_data, int snapshot_size) {
    if (!snapshot_data || snapshot_size <= 0) {
        return false;
    }
    
    StartupData startup_data;
    startup_data.data = snapshot_data;
    startup_data.raw_size = snapshot_size;
    
    bool result = startup_data.CanBeRehashed();
    fprintf(stderr, "[v8_Snapshot_CanBeRehashed] Snapshot rehashability: %s\n", 
            result ? "true" : "false");
    return result;
}

// ============================================================================
// C++ Callback Pointers for External References
// ============================================================================
//
// These functions return pointers to C++ callbacks that are used by V8
// FunctionTemplates. For V8 snapshots to work correctly, ALL callback
// function pointers must be registered in the external references array.
//
// Since C++ static functions aren't directly accessible from Zig FFI,
// we expose them through these getter functions.

/// Get pointer to AsyncIteratorNextCallback
///
/// This callback is used when creating async iterator objects via
/// v8_CreateAsyncIterator. It wraps the Zig next function and handles
/// the V8-specific Promise wrapping.
///
/// @return Function pointer to AsyncIteratorNextCallback
void* v8_GetAsyncIteratorNextCallback() {
    return reinterpret_cast<void*>(&AsyncIteratorNextCallback);
}

/// Get pointer to AsyncIteratorReturnCallback
///
/// This callback is used when creating async iterator objects via
/// v8_CreateAsyncIterator. It wraps the Zig return function and handles
/// the V8-specific Promise wrapping.
///
/// @return Function pointer to AsyncIteratorReturnCallback
void* v8_GetAsyncIteratorReturnCallback() {
    return reinterpret_cast<void*>(&AsyncIteratorReturnCallback);
}

/// Get pointer to AsyncIteratorSelfCallback
///
/// This callback is used for Symbol.asyncIterator on async iterator objects.
/// It simply returns 'this', making the iterator both an iterator and iterable.
///
/// @return Function pointer to AsyncIteratorSelfCallback
void* v8_GetAsyncIteratorSelfCallback() {
    return reinterpret_cast<void*>(&AsyncIteratorSelfCallback);
}

// ============================================================================
// V8 Locker/Unlocker API - Thread Safety for Multi-Threaded Access
// ============================================================================
//
// V8 isolates are NOT thread-safe. When multiple threads need to access
// the same isolate, they MUST use v8::Locker to acquire exclusive access.
//
// Usage Pattern:
//   Thread 1: v8_Locker_New(isolate) -> do work -> v8_Locker_Dispose(locker)
//   Thread 2: blocks until Thread 1 releases, then acquires
//
// For blocking operations within locked sections, use Unlocker to temporarily
// release the lock so other threads can make progress:
//   v8_Unlocker_New(isolate) -> blocking I/O -> v8_Unlocker_Dispose(unlocker)

/// Create a new Locker for exclusive isolate access
///
/// This blocks if another thread holds the lock.
/// Returns an opaque pointer that must be passed to v8_Locker_Dispose.
///
/// @param isolate - The isolate to lock
/// @return Opaque Locker pointer (caller must dispose)
void* v8_Locker_New(Isolate* isolate) {
    return new Locker(isolate);
}

/// Dispose a Locker and release the lock
///
/// After calling this, other threads can acquire the lock.
///
/// @param locker - Locker pointer from v8_Locker_New
void v8_Locker_Dispose(void* locker) {
    if (locker) {
        delete static_cast<Locker*>(locker);
    }
}

/// Check if the current thread holds a lock on the isolate
///
/// @param isolate - The isolate to check
/// @return true if current thread holds the lock
bool v8_Locker_IsLocked(Isolate* isolate) {
    return Locker::IsLocked(isolate);
}

/// Create a new Unlocker to temporarily release the isolate lock
///
/// Use this when performing blocking operations that don't need V8 access.
/// The lock is automatically reacquired when the Unlocker is disposed.
///
/// IMPORTANT: Only call this when you already hold the lock (via Locker).
///
/// @param isolate - The isolate to temporarily unlock
/// @return Opaque Unlocker pointer (caller must dispose)
void* v8_Unlocker_New(Isolate* isolate) {
    return new Unlocker(isolate);
}

/// Dispose an Unlocker and reacquire the lock
///
/// This blocks if another thread acquired the lock while unlocked.
///
/// @param unlocker - Unlocker pointer from v8_Unlocker_New
void v8_Unlocker_Dispose(void* unlocker) {
    if (unlocker) {
        delete static_cast<Unlocker*>(unlocker);
    }
}

// ============================================================================
// Global Handle Conversion API
// ============================================================================
//
// These functions enable converting Local handles to Global handles for
// cross-scope persistence. This is critical for storing JavaScript callbacks
// (like stream start/write/close callbacks) that need to survive past the
// HandleScope that created them.
//
// V8 Handle Lifecycle:
// - Local<T>: Stack-bound, invalid after HandleScope ends
// - Global<T>: Heap-allocated, persists until explicitly Reset()
//
// Usage:
// 1. When extracting callback from dictionary: call v8_Value_ToGlobal()
// 2. When invoking callback: call v8_Global_Get() to get Local
// 3. When done with callback: call v8_Global_Dispose()

/// Convert a Local<Value> to a heap-allocated Global<Value>
///
/// The Local value comes from the current HandleScope. The returned Global
/// pointer persists independently of any HandleScope and must be disposed
/// with v8_Global_Dispose().
///
/// IMPORTANT: The 'local' parameter must be a valid Local<Value> internal pointer
/// from within an active HandleScope. This function creates a Global that persists
/// after the HandleScope ends.
///
/// @param isolate - Current V8 isolate
/// @param local - Local value pointer (from callback or conversion)
/// @return New Global<Value>* or nullptr if local is empty
Global<Value>* v8_Value_ToGlobal(Isolate* isolate, void* local) {
    if (!isolate || !local) return nullptr;
    
    HandleScope handle_scope(isolate);
    
    // Cast the void* back to Value* - this is the internal pointer from a Local<Value>
    // We can construct a Local from this internal pointer using the internal API
    Value* value_ptr = reinterpret_cast<Value*>(local);
    
    // Use internal::ValueHelper to construct a proper Local<Value>
    // This mirrors how V8 internally handles the conversion
    Local<Value> local_value = *reinterpret_cast<Local<Value>*>(&value_ptr);
    
    if (local_value.IsEmpty()) return nullptr;
    
    return new Global<Value>(isolate, local_value);
}

/// Dispose a Global<Value> handle
///
/// Releases the persistent reference, allowing the V8 value to be garbage
/// collected if no other references exist.
///
/// @param global - Global handle to dispose (null-safe)
void v8_Global_Dispose(Global<Value>* global) {
    if (global != nullptr) {
        global->Reset();
        delete global;
    }
}

/// Check if a Global handle is empty or null
///
/// @param global - Global handle to check
/// @return true if null or empty, false if valid
bool v8_Global_IsEmpty(Global<Value>* global) {
    return global == nullptr || global->IsEmpty();
}

/// Get a Local<Value> from a Global<Value>
///
/// Creates a new Local handle in the current HandleScope. The returned
/// Local is valid only within the current HandleScope.
///
/// @param isolate - Current V8 isolate
/// @param global - Global handle to dereference
/// @return Local value pointer (as void*) or nullptr if global is empty
///
/// IMPORTANT: This function uses EscapableHandleScope to ensure the returned
/// Local handle is valid in the caller's HandleScope. The caller must have
/// an active HandleScope.
void* v8_Global_Get(Isolate* isolate, Global<Value>* global) {
    if (!isolate || !global || global->IsEmpty()) return nullptr;
    
    // Use EscapableHandleScope so we can return the Local to the caller's scope
    EscapableHandleScope handle_scope(isolate);
    Local<Value> local = global->Get(isolate);
    
    // Escape the local so it survives this function's HandleScope
    Local<Value> escaped = handle_scope.Escape(local);
    
    // Return the internal pointer - now valid in caller's HandleScope
    return *reinterpret_cast<void**>(&escaped);
}

/// Convert a Global<Value> to a Global<Function> if it contains a function
///
/// @param global - Global value handle
/// @return The same pointer cast to Global<Function>* if it's a function, nullptr otherwise
Global<Function>* v8_Global_ToFunction(Global<Value>* global) {
    if (!global || global->IsEmpty()) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> local = global->Get(isolate);
    
    if (!local->IsFunction()) return nullptr;
    
    // The Global<Value> and Global<Function> have the same internal representation
    // when the value is actually a function, so we can safely cast
    return reinterpret_cast<Global<Function>*>(global);
}

// ============================================================================
// JSON Serialization for Cross-Isolate Message Passing
// ============================================================================
//
// These functions enable serializing V8 values to JSON strings and back,
// which is useful for passing messages between worker isolates and the main
// thread when full structured clone is not available.

/// Serialize a V8 value to JSON string and copy to buffer
///
/// This function uses V8's JSON.stringify to convert a value to its JSON
/// representation, then copies the UTF-8 string to the provided buffer.
///
/// The function operates in two modes:
/// 1. If buffer_len is 0, returns the required buffer size
/// 2. If buffer_len > 0, writes JSON to buffer and returns bytes written
///
/// IMPORTANT: This function uses the CURRENT context from the current isolate.
/// It does NOT enter a new context - the caller must ensure the correct context
/// is already active. The context_raw parameter is used only for JSON::Stringify.
///
/// @param context_raw - Raw V8 Context pointer (passed to JSON::Stringify)
/// @param value_raw - Raw V8 Value pointer
/// @param buffer - Output buffer for UTF-8 JSON string
/// @param buffer_len - Size of output buffer (0 to query size)
/// @return Number of bytes written, -1 on error, or required size if buffer_len is 0
int v8_JSON_Stringify_ToBuffer(
    Context* context_raw,
    Value* value_raw,
    char* buffer,
    int buffer_len
) {
    // Get current isolate
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return -1;
    
    // Create HandleScope for local handles
    HandleScope handle_scope(isolate);
    
    // Get the CURRENT context from the isolate (not the passed context!)
    // This avoids context mismatch issues when called from within script execution
    Local<Context> context = isolate->GetCurrentContext();
    if (context.IsEmpty()) {
        return -1;  // No active context
    }
    
    // Convert value_raw to Local handle
    // value_raw is actually a Global<Value>* from v8_FunctionCallbackInfo_GetArgument
    // We need to dereference it and get the local handle
    Global<Value>* global_handle = reinterpret_cast<Global<Value>*>(value_raw);
    Local<Value> value = global_handle->Get(isolate);
    
    // Use V8's JSON.stringify with the current context
    // Do NOT enter a new context - we're already in one during script execution
    MaybeLocal<String> maybe_json = JSON::Stringify(context, value);
    if (maybe_json.IsEmpty()) {
        return -1;  // Stringify failed (e.g., circular reference, BigInt)
    }
    
    Local<String> json_str = maybe_json.ToLocalChecked();
    
    // Get the UTF-8 length
    int utf8_length = json_str->Utf8Length(isolate);
    
    // If buffer_len is 0, just return the required size
    if (buffer_len == 0) {
        return utf8_length;
    }
    
    // Check if buffer is large enough
    if (buffer_len < utf8_length) {
        // Return required size so caller can allocate larger buffer
        return utf8_length;
    }
    
    // Write UTF-8 to buffer
    int written = json_str->WriteUtf8(
        isolate,
        buffer,
        buffer_len,
        nullptr,  // nchars_ref
        String::NO_NULL_TERMINATION
    );
    
    return written;
}

/// Parse JSON string from buffer and return V8 value
///
/// This function uses V8's JSON.parse to convert a JSON string to a V8 value.
/// The returned value is "escaped" from this function's HandleScope using
/// EscapableHandleScope, so it remains valid in the caller's HandleScope.
///
/// IMPORTANT: This function uses the CURRENT context from the current isolate.
/// The caller must ensure the correct isolate is entered and the correct
/// context is active before calling this function. The caller must also have
/// an active HandleScope.
///
/// @param context_raw - Raw V8 Context pointer (currently unused - uses current context)
/// @param json_str - UTF-8 JSON string
/// @param json_len - Length of JSON string
/// @return Local Value pointer (valid in caller's HandleScope) or nullptr on error
Value* v8_JSON_Parse_FromBuffer(
    Context* context_raw,
    const char* json_str,
    int json_len
) {
    (void)context_raw;  // Unused - we use current context
    
    // Get current isolate
    Isolate* isolate = Isolate::GetCurrent();
    if (!isolate) return nullptr;
    
    // Use EscapableHandleScope so we can return the handle to the caller's scope
    EscapableHandleScope handle_scope(isolate);
    
    // Get the CURRENT context from the isolate (not the passed context!)
    // This avoids context mismatch issues when called after isolate enter/exit
    Local<Context> context = isolate->GetCurrentContext();
    if (context.IsEmpty()) {
        return nullptr;  // No active context
    }
    
    // Create V8 string from JSON buffer
    MaybeLocal<String> maybe_str = String::NewFromUtf8(
        isolate,
        json_str,
        NewStringType::kNormal,
        json_len
    );
    
    if (maybe_str.IsEmpty()) {
        return nullptr;  // Failed to create string
    }
    
    Local<String> v8_json_str = maybe_str.ToLocalChecked();
    
    // Use V8's JSON.parse with the current context
    // Do NOT enter a new context - we should already be in the correct one
    MaybeLocal<Value> maybe_value = JSON::Parse(context, v8_json_str);
    
    if (maybe_value.IsEmpty()) {
        return nullptr;  // Parse failed (invalid JSON)
    }
    
    Local<Value> parsed_value = maybe_value.ToLocalChecked();
    
    // Escape the handle so it survives the destruction of our HandleScope
    // and remains valid in the caller's HandleScope
    Local<Value> escaped = handle_scope.Escape(parsed_value);
    
    // Return the internal pointer - valid in caller's HandleScope
    return *reinterpret_cast<Value**>(&escaped);
}

// ============================================================================
// HandleScope API for Zig Timer Callbacks
// ============================================================================
//
// V8 requires a HandleScope to be active when creating Local handles.
// When Zig timer callbacks fire from libuv, there's no active HandleScope.
// These functions allow Zig code to create and dispose HandleScopes.
//
// V8's HandleScope has private new/delete operators - it's designed for
// stack allocation only. We work around this by:
// 1. Using a derived class with public new/delete operators
// 2. Using the protected default constructor + Initialize() method
//
// Usage pattern in Zig:
//   const scope = v8_HandleScope_New(isolate);
//   defer v8_HandleScope_Dispose(scope);
//   // ... V8 operations that create Local handles ...

/// Derived HandleScope that can be heap-allocated
/// Uses the protected default constructor + Initialize() pattern
/// Provides public new/delete to override base class's private ones
class HeapHandleScope : public HandleScope {
 public:
    HeapHandleScope(Isolate* isolate) : HandleScope() {
        Initialize(isolate);
    }
    
    // Override base class's private new/delete with public versions
    // This is valid C++ - derived class can expose hidden base class members
    static void* operator new(size_t size) {
        return ::operator new(size);
    }
    
    static void operator delete(void* ptr) {
        ::operator delete(ptr);
    }
};

/// Create a new HandleScope for the given isolate
///
/// This must be called before any V8 operation that creates Local handles
/// when called from a non-V8 context (e.g., libuv timer callbacks).
///
/// @param isolate - The V8 isolate
/// @return Opaque pointer to HandleScope, or nullptr on failure
void* v8_HandleScope_New(Isolate* isolate) {
    if (!isolate) return nullptr;
    
    // Create heap-allocatable HandleScope via derived class
    return new HeapHandleScope(isolate);
}

/// Dispose a HandleScope created by v8_HandleScope_New
///
/// This must be called when done with V8 operations to properly clean up.
/// Typically used with defer in Zig.
///
/// @param scope_ptr - Pointer from v8_HandleScope_New
void v8_HandleScope_Dispose(void* scope_ptr) {
    if (!scope_ptr) return;
    
    HeapHandleScope* scope = static_cast<HeapHandleScope*>(scope_ptr);
    delete scope;
}

// ============================================================================
// V8 Proxy API - For ObservableArray Exotic Objects
// ============================================================================
//
// The Proxy API allows creating JavaScript Proxy objects from native code.
// This is required for implementing WebIDL ObservableArray which is specified
// as an exotic object backed by a Proxy.
//
// Spec: https://webidl.spec.whatwg.org/#idl-observable-array
//       https://webidl.spec.whatwg.org/#es-observable-array
//
// Key Requirements:
// - Proxy internals (target, handler) must NOT leak to JavaScript
// - Must support custom traps: get, set, deleteProperty, ownKeys, getPrototypeOf
// - ownKeys must return keys in order: indices (ascending) → "length" → strings (insertion)

/// Create a new V8 Proxy object
///
/// Creates a JavaScript Proxy with the specified target and handler.
///
/// @param context - The V8 context
/// @param target - The target object the proxy wraps
/// @param handler - The handler object with trap functions
/// @return Global handle to new Proxy object, or nullptr on error
Global<Object>* v8_Proxy_New(
    Global<Context>* context,
    Global<Object>* target,
    Global<Object>* handler
) {
    if (!context || !target || !handler) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    
    Local<Context> ctx = context->Get(isolate);
    Local<Object> local_target = target->Get(isolate);
    Local<Object> local_handler = handler->Get(isolate);
    
    MaybeLocal<Proxy> maybe_proxy = Proxy::New(ctx, local_target, local_handler);
    if (maybe_proxy.IsEmpty()) {
        return nullptr;
    }
    
    Local<Proxy> proxy = maybe_proxy.ToLocalChecked();
    
    // Proxy inherits from Object, so we can cast
    return trackHandle(new Global<Object>(isolate, proxy.As<Object>()));
}

/// Check if a value is a Proxy
///
/// @param value - The value to check
/// @return true if the value is a Proxy, false otherwise
bool v8_Value_IsProxy(Global<Value>* value) {
    if (!value) return false;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Value> val = value->Get(isolate);
    
    return val->IsProxy();
}

/// Get the target of a Proxy
///
/// @param proxy - The Proxy object
/// @return Global handle to the target, or nullptr if not a Proxy
Global<Value>* v8_Proxy_GetTarget(Global<Object>* proxy) {
    if (!proxy) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> obj = proxy->Get(isolate);
    
    if (!obj->IsProxy()) return nullptr;
    
    Local<Proxy> proxy_obj = obj.As<Proxy>();
    Local<Value> target = proxy_obj->GetTarget();
    
    return trackHandle(new Global<Value>(isolate, target));
}

/// Get the handler of a Proxy
///
/// @param proxy - The Proxy object
/// @return Global handle to the handler, or nullptr if not a Proxy
Global<Value>* v8_Proxy_GetHandler(Global<Object>* proxy) {
    if (!proxy) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> obj = proxy->Get(isolate);
    
    if (!obj->IsProxy()) return nullptr;
    
    Local<Proxy> proxy_obj = obj.As<Proxy>();
    Local<Value> handler = proxy_obj->GetHandler();
    
    return trackHandle(new Global<Value>(isolate, handler));
}

/// Revoke a Proxy (make it unusable)
///
/// After revocation, any operation on the Proxy will throw TypeError.
///
/// @param proxy - The Proxy object to revoke
void v8_Proxy_Revoke(Global<Object>* proxy) {
    if (!proxy) return;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> obj = proxy->Get(isolate);
    
    if (!obj->IsProxy()) return;
    
    Local<Proxy> proxy_obj = obj.As<Proxy>();
    proxy_obj->Revoke();
}

/// Check if a Proxy has been revoked
///
/// @param proxy - The Proxy object to check
/// @return true if revoked, false otherwise or if not a Proxy
bool v8_Proxy_IsRevoked(Global<Object>* proxy) {
    if (!proxy) return true;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Object> obj = proxy->Get(isolate);
    
    if (!obj->IsProxy()) return true;
    
    Local<Proxy> proxy_obj = obj.As<Proxy>();
    return proxy_obj->IsRevoked();
}

} // extern "C" - temporarily close for C++ helper functions

// ============================================================================
// Legacy Platform Object Proxy Support
// ============================================================================
// 
// WebIDL §3.9.6 requires [[OwnPropertyKeys]] to return keys in order:
// 1. Indexed property keys (ascending numeric order)
// 2. Named property keys (in definition order)
// 3. Own property keys (strings, then symbols)
//
// V8's default enumeration order is: own → interceptors
// We use a Proxy to override [[OwnPropertyKeys]] while forwarding all other
// operations transparently to the target.
// ============================================================================

namespace {

// Helper to get indexed property keys from an object with length property
Local<Array> GetIndexedPropertyKeys(Isolate* isolate, Local<Context> context, Local<Object> target) {
    Local<String> length_key = String::NewFromUtf8Literal(isolate, "length");
    
    MaybeLocal<Value> maybe_length = target->Get(context, length_key);
    if (maybe_length.IsEmpty()) {
        return Array::New(isolate, 0);
    }
    
    Local<Value> length_val = maybe_length.ToLocalChecked();
    if (!length_val->IsNumber()) {
        return Array::New(isolate, 0);
    }
    
    uint32_t length = length_val->Uint32Value(context).FromMaybe(0);
    Local<Array> indices = Array::New(isolate, length);
    
    for (uint32_t i = 0; i < length; i++) {
        Local<String> idx_str = String::NewFromUtf8(isolate, std::to_string(i).c_str()).ToLocalChecked();
        indices->Set(context, i, idx_str).Check();
    }
    
    return indices;
}

// Helper to get named property keys by calling the named property enumerator
// This works by triggering Object.keys which will call our interceptor
Local<Array> GetNamedPropertyKeys(Isolate* isolate, Local<Context> context, Local<Object> target) {
    // Get property names that would be returned by the named property enumerator
    // We use GetPropertyNames with ONLY_ENUMERABLE to get interceptor keys
    PropertyFilter filter = static_cast<PropertyFilter>(
        PropertyFilter::ONLY_ENUMERABLE | 
        PropertyFilter::SKIP_SYMBOLS
    );
    
    MaybeLocal<Array> maybe_names = target->GetPropertyNames(
        context,
        KeyCollectionMode::kOwnOnly,
        filter,
        IndexFilter::kSkipIndices  // Skip indices, we handle them separately
    );
    
    if (maybe_names.IsEmpty()) {
        return Array::New(isolate, 0);
    }
    
    return maybe_names.ToLocalChecked();
}

// Helper to get own property keys (non-interceptor, non-indexed)
Local<Array> GetOwnPropertyKeys(Isolate* isolate, Local<Context> context, Local<Object> target) {
    // Get ALL own property names including non-enumerable
    MaybeLocal<Array> maybe_names = target->GetOwnPropertyNames(
        context,
        static_cast<PropertyFilter>(PropertyFilter::ALL_PROPERTIES),
        KeyConversionMode::kConvertToString
    );
    
    if (maybe_names.IsEmpty()) {
        return Array::New(isolate, 0);
    }
    
    return maybe_names.ToLocalChecked();
}

// The ownKeys trap implementation for legacy platform objects
// Uses Reflect.ownKeys(target) to get all keys, then reorders them per WebIDL §3.9.6
void LegacyPlatformObjectOwnKeys(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    
    if (info.Length() < 1 || !info[0]->IsObject()) {
        info.GetReturnValue().Set(Array::New(isolate, 0));
        return;
    }
    
    Local<Object> target = info[0].As<Object>();
    
    // Get Reflect.ownKeys(target) to get V8's native key list
    Local<Object> reflect = context->Global()
        ->Get(context, String::NewFromUtf8Literal(isolate, "Reflect"))
        .ToLocalChecked().As<Object>();
    
    Local<Function> ownKeys_fn = reflect
        ->Get(context, String::NewFromUtf8Literal(isolate, "ownKeys"))
        .ToLocalChecked().As<Function>();
    
    Local<Value> args[] = { target };
    MaybeLocal<Value> maybe_keys = ownKeys_fn->Call(context, reflect, 1, args);
    
    if (maybe_keys.IsEmpty()) {
        info.GetReturnValue().Set(Array::New(isolate, 0));
        return;
    }
    
    Local<Array> all_keys = maybe_keys.ToLocalChecked().As<Array>();
    
    // Categorize keys into: indices, named, own strings, symbols
    std::vector<uint32_t> indices;
    std::vector<Local<Value>> named_props;
    std::vector<Local<Value>> own_props;
    std::vector<Local<Value>> symbols;
    
    // Get the length for determining index range
    Local<String> length_key = String::NewFromUtf8Literal(isolate, "length");
    uint32_t length = 0;
    MaybeLocal<Value> maybe_length = target->Get(context, length_key);
    if (!maybe_length.IsEmpty()) {
        Local<Value> length_val = maybe_length.ToLocalChecked();
        if (length_val->IsNumber()) {
            length = length_val->Uint32Value(context).FromMaybe(0);
        }
    }
    
    // NOTE: We intentionally do NOT call target->GetPropertyNames() here.
    // V8's KeyAccumulator::FilterForEnumerableProperties expects all keys to be
    // Name objects (String or Symbol), but indexed property interceptors return
    // integer indices. This causes a crash: "Check failed: IsName(*element)".
    // Instead, we use the keys from Reflect.ownKeys(target) which we already have,
    // and use HasRealNamedProperty to distinguish own vs interceptor-provided keys.
    
    // Categorize each key
    // V8's ownKeys trap requires all returned values to be Name objects (String or Symbol).
    // Reflect.ownKeys can return numeric indices as integers, so we must convert them.
    for (uint32_t i = 0; i < all_keys->Length(); i++) {
        MaybeLocal<Value> maybe_key = all_keys->Get(context, i);
        if (maybe_key.IsEmpty()) continue;
        
        Local<Value> key = maybe_key.ToLocalChecked();
        
        if (key->IsSymbol()) {
            symbols.push_back(key);
        } else if (key->IsNumber()) {
            // Numeric keys must be converted to strings for V8's KeyAccumulator
            // which expects all keys to be Name objects (String or Symbol).
            // This handles indexed properties returned as integers.
            double num_val = key->NumberValue(context).FromMaybe(0);
            if (num_val >= 0 && num_val < 0xFFFFFFFF) {
                uint32_t idx = static_cast<uint32_t>(num_val);
                if (idx < length) {
                    indices.push_back(idx);
                } else {
                    // Index out of range - treat as own property string
                    Local<String> idx_str = String::NewFromUtf8(isolate, std::to_string(idx).c_str()).ToLocalChecked();
                    own_props.push_back(idx_str);
                }
            }
        } else if (key->IsString()) {
            String::Utf8Value utf8(isolate, key);
            std::string key_str(*utf8);
            
            // Check if it's a numeric index within range
            bool is_index = false;
            if (!key_str.empty() && std::all_of(key_str.begin(), key_str.end(), ::isdigit)) {
                uint32_t idx = std::stoul(key_str);
                if (idx < length) {
                    indices.push_back(idx);
                    is_index = true;
                }
            }
            
            if (!is_index) {
                // Use HasRealNamedProperty to distinguish actual own properties
                // from named properties provided by the interceptor.
                // HasRealNamedProperty returns true only for actual own properties,
                // not for properties from the named property handler.
                Local<String> key_string = key.As<String>();
                Maybe<bool> has_real = target->HasRealNamedProperty(context, key_string);
                if (has_real.FromMaybe(false)) {
                    own_props.push_back(key);
                } else {
                    named_props.push_back(key);
                }
            }
        }
        // Note: Keys that are not Symbol, Number, or String are silently ignored.
        // This should not happen with well-formed ownKeys results.
    }
    
    // Sort indices
    std::sort(indices.begin(), indices.end());
    
    // Build result in WebIDL order: indices, named, own, symbols
    std::vector<Local<Value>> result_keys;
    
    for (uint32_t idx : indices) {
        Local<String> idx_str = String::NewFromUtf8(isolate, std::to_string(idx).c_str()).ToLocalChecked();
        result_keys.push_back(idx_str);
    }
    for (const auto& key : named_props) {
        result_keys.push_back(key);
    }
    for (const auto& key : own_props) {
        result_keys.push_back(key);
    }
    for (const auto& key : symbols) {
        result_keys.push_back(key);
    }
    
    Local<Array> result = Array::New(isolate, static_cast<int>(result_keys.size()));
    for (size_t i = 0; i < result_keys.size(); i++) {
        result->Set(context, static_cast<uint32_t>(i), result_keys[i]).Check();
    }
    
    info.GetReturnValue().Set(result);
}

// The getOwnPropertyDescriptor trap - must be consistent with ownKeys
void LegacyPlatformObjectGetOwnPropertyDescriptor(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    
    if (info.Length() < 2 || !info[0]->IsObject()) {
        info.GetReturnValue().SetUndefined();
        return;
    }
    
    Local<Object> target = info[0].As<Object>();
    Local<Value> key = info[1];
    
    // Forward to Reflect.getOwnPropertyDescriptor(target, key)
    Local<Object> reflect = context->Global()
        ->Get(context, String::NewFromUtf8Literal(isolate, "Reflect"))
        .ToLocalChecked().As<Object>();
    
    Local<Function> getOwnPropertyDescriptor = reflect
        ->Get(context, String::NewFromUtf8Literal(isolate, "getOwnPropertyDescriptor"))
        .ToLocalChecked().As<Function>();
    
    Local<Value> args[] = { target, key };
    MaybeLocal<Value> result = getOwnPropertyDescriptor->Call(context, reflect, 2, args);
    
    if (result.IsEmpty()) {
        info.GetReturnValue().SetUndefined();
    } else {
        info.GetReturnValue().Set(result.ToLocalChecked());
    }
}

// Generic trap that forwards to Reflect
void ForwardToReflect(const FunctionCallbackInfo<Value>& info, const char* method_name) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    
    Local<Object> reflect = context->Global()
        ->Get(context, String::NewFromUtf8Literal(isolate, "Reflect"))
        .ToLocalChecked().As<Object>();
    
    Local<Function> method = reflect
        ->Get(context, String::NewFromUtf8(isolate, method_name).ToLocalChecked())
        .ToLocalChecked().As<Function>();
    
    std::vector<Local<Value>> args;
    for (int i = 0; i < info.Length(); i++) {
        args.push_back(info[i]);
    }
    
    MaybeLocal<Value> result = method->Call(context, reflect, 
        static_cast<int>(args.size()), args.data());
    
    if (!result.IsEmpty()) {
        info.GetReturnValue().Set(result.ToLocalChecked());
    }
}

void TrapGet(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    
    if (info.Length() < 2) return;
    
    Local<Value> target = info[0];
    Local<Value> property = info[1];
    
    if (property->IsString()) {
        String::Utf8Value prop_str(isolate, property);
        fprintf(stderr, "[TrapGet] property='%s'\n", *prop_str);
    }
    
    Local<Object> reflect = context->Global()
        ->Get(context, String::NewFromUtf8Literal(isolate, "Reflect"))
        .ToLocalChecked().As<Object>();
    
    Local<Function> get_fn = reflect
        ->Get(context, String::NewFromUtf8Literal(isolate, "get"))
        .ToLocalChecked().As<Function>();
    
    Local<Value> args[] = { target, property, target };
    MaybeLocal<Value> result = get_fn->Call(context, reflect, 3, args);
    
    if (!result.IsEmpty()) {
        info.GetReturnValue().Set(result.ToLocalChecked());
    }
}

void TrapSet(const FunctionCallbackInfo<Value>& info) {
    Isolate* isolate = info.GetIsolate();
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    
    if (info.Length() < 3) {
        info.GetReturnValue().Set(false);
        return;
    }
    
    Local<Object> target = info[0].As<Object>();
    Local<Value> property = info[1];
    
    if (property->IsString()) {
        String::Utf8Value prop_str(isolate, property);
        fprintf(stderr, "[TrapSet] property='%s'\n", *prop_str);
    }
    Local<Value> value = info[2];
    
    // Use Object.defineProperty to bypass named property interceptor.
    // Reflect.set goes through the interceptor which may not create
    // actual own properties on objects with named property handlers.
    Local<Object> object_ctor = context->Global()
        ->Get(context, String::NewFromUtf8Literal(isolate, "Object"))
        .ToLocalChecked().As<Object>();
    
    Local<Function> define_prop = object_ctor
        ->Get(context, String::NewFromUtf8Literal(isolate, "defineProperty"))
        .ToLocalChecked().As<Function>();
    
    // Create property descriptor: { value, writable: true, enumerable: true, configurable: true }
    Local<Object> descriptor = Object::New(isolate);
    descriptor->Set(context, String::NewFromUtf8Literal(isolate, "value"), value).Check();
    descriptor->Set(context, String::NewFromUtf8Literal(isolate, "writable"), Boolean::New(isolate, true)).Check();
    descriptor->Set(context, String::NewFromUtf8Literal(isolate, "enumerable"), Boolean::New(isolate, true)).Check();
    descriptor->Set(context, String::NewFromUtf8Literal(isolate, "configurable"), Boolean::New(isolate, true)).Check();
    
    Local<Value> args[] = { target, property, descriptor };
    MaybeLocal<Value> result = define_prop->Call(context, object_ctor, 3, args);
    
    info.GetReturnValue().Set(!result.IsEmpty());
}
void TrapHas(const FunctionCallbackInfo<Value>& info) { ForwardToReflect(info, "has"); }
void TrapDeleteProperty(const FunctionCallbackInfo<Value>& info) { ForwardToReflect(info, "deleteProperty"); }
void TrapDefineProperty(const FunctionCallbackInfo<Value>& info) { ForwardToReflect(info, "defineProperty"); }
void TrapGetPrototypeOf(const FunctionCallbackInfo<Value>& info) { ForwardToReflect(info, "getPrototypeOf"); }
void TrapSetPrototypeOf(const FunctionCallbackInfo<Value>& info) { ForwardToReflect(info, "setPrototypeOf"); }
void TrapIsExtensible(const FunctionCallbackInfo<Value>& info) { ForwardToReflect(info, "isExtensible"); }
void TrapPreventExtensions(const FunctionCallbackInfo<Value>& info) { ForwardToReflect(info, "preventExtensions"); }

} // anonymous namespace

extern "C" {

/// Create a transparent Proxy for a legacy platform object
/// 
/// This wraps the target in a Proxy that forwards all operations to the target
/// except for [[OwnPropertyKeys]] which returns keys in WebIDL order:
/// indexed → named → own → symbols
///
/// @param context - The V8 context
/// @param target - The legacy platform object to wrap
/// @return Global handle to the Proxy, or nullptr on failure
Global<Object>* v8_CreateLegacyPlatformObjectProxy(Global<Context>* context, Global<Object>* target) {
    if (!context || !target) return nullptr;
    
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    Local<Context> ctx = context->Get(isolate);
    Context::Scope context_scope(ctx);
    Local<Object> local_target = target->Get(isolate);
    
    // Create the handler object with all traps
    Local<Object> handler = Object::New(isolate);
    
    // Helper to create and set a function trap
    auto set_trap = [&](const char* name, FunctionCallback callback) {
        Local<FunctionTemplate> tmpl = FunctionTemplate::New(isolate, callback);
        Local<Function> fn = tmpl->GetFunction(ctx).ToLocalChecked();
        handler->Set(ctx, String::NewFromUtf8(isolate, name).ToLocalChecked(), fn).Check();
    };
    
    // Set all traps
    set_trap("get", TrapGet);
    set_trap("set", TrapSet);
    set_trap("has", TrapHas);
    set_trap("deleteProperty", TrapDeleteProperty);
    set_trap("ownKeys", LegacyPlatformObjectOwnKeys);
    set_trap("getOwnPropertyDescriptor", LegacyPlatformObjectGetOwnPropertyDescriptor);
    set_trap("defineProperty", TrapDefineProperty);
    set_trap("getPrototypeOf", TrapGetPrototypeOf);
    set_trap("setPrototypeOf", TrapSetPrototypeOf);
    set_trap("isExtensible", TrapIsExtensible);
    set_trap("preventExtensions", TrapPreventExtensions);
    
    // Create the Proxy
    MaybeLocal<Proxy> maybe_proxy = Proxy::New(ctx, local_target, handler);
    if (maybe_proxy.IsEmpty()) {
        return nullptr;
    }
    
    Local<Proxy> proxy = maybe_proxy.ToLocalChecked();
    return trackHandle(new Global<Object>(isolate, proxy.As<Object>()));
}

} // extern "C"

extern "C" void v8_FunctionTemplate_SetPrototypeProviderTemplate(Global<FunctionTemplate>* tpl, Global<FunctionTemplate>* provider) {
    if (!tpl || !provider) return;
    Isolate* isolate = Isolate::GetCurrent();
    HandleScope handle_scope(isolate);
    tpl->Get(isolate)->SetPrototypeProviderTemplate(provider->Get(isolate));
}

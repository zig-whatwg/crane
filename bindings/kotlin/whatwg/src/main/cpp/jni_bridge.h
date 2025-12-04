/**
 * @file jni_bridge.h
 * @brief JNI bridge header for WHATWG Kotlin bindings
 * 
 * This header declares the JNI native methods that bridge Kotlin to the
 * WHATWG C library. It also provides callback context management for
 * passing Kotlin callbacks to native code.
 */

#ifndef WHATWG_JNI_BRIDGE_H
#define WHATWG_JNI_BRIDGE_H

#include <jni.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// Callback Context
// ============================================================================

/**
 * @brief Context for storing JNI callback references.
 * 
 * This structure holds the JVM and global references needed to call
 * back into Kotlin from native code.
 */
typedef struct {
    JavaVM* jvm;
    jobject callback_object;
    jmethodID method_id;
} jni_callback_context_t;

/**
 * @brief Creates a new callback context.
 * 
 * @param env JNI environment
 * @param callback Kotlin callback object
 * @param method_name Name of the method to call
 * @param method_sig JNI method signature
 * @return Callback context, or NULL on failure
 */
jni_callback_context_t* jni_callback_context_create(
    JNIEnv* env,
    jobject callback,
    const char* method_name,
    const char* method_sig
);

/**
 * @brief Destroys a callback context and releases references.
 * 
 * @param ctx Callback context to destroy
 */
void jni_callback_context_destroy(jni_callback_context_t* ctx);

/**
 * @brief Gets JNIEnv for the current thread.
 * 
 * Attaches the current thread to the JVM if necessary.
 * 
 * @param ctx Callback context with JVM reference
 * @return JNIEnv for current thread, or NULL on failure
 */
JNIEnv* jni_callback_get_env(jni_callback_context_t* ctx);

// ============================================================================
// Provider Context
// ============================================================================

/**
 * @brief Context for a complete set of provider callbacks.
 * 
 * This structure holds all the callback contexts for each capability
 * provider, allowing the native VTables to call back into Kotlin.
 */
typedef struct {
    JavaVM* jvm;
    
    // Clipboard provider
    jobject clipboard_provider;
    jmethodID clipboard_read_text;
    jmethodID clipboard_write_text;
    
    // Timer provider
    jobject timer_provider;
    jmethodID timer_set_timeout;
    jmethodID timer_set_interval;
    jmethodID timer_clear_timeout;
    jmethodID timer_clear_interval;
    
    // Network provider
    jobject network_provider;
    jmethodID network_fetch;
    jmethodID network_is_online;
    
    // Storage provider
    jobject storage_provider;
    jmethodID storage_get_item;
    jmethodID storage_set_item;
    jmethodID storage_remove_item;
    jmethodID storage_clear;
    jmethodID storage_length;
    jmethodID storage_key;
    
    // Geolocation provider
    jobject geolocation_provider;
    jmethodID geo_get_current_position;
    jmethodID geo_watch_position;
    jmethodID geo_clear_watch;
    
    // Notification provider
    jobject notification_provider;
    jmethodID notification_request_permission;
    jmethodID notification_show;
    
    // UI provider
    jobject ui_provider;
    jmethodID ui_alert;
    jmethodID ui_confirm;
    jmethodID ui_prompt;
    
} jni_provider_context_t;

/**
 * @brief Creates a new provider context.
 * 
 * @param env JNI environment
 * @return Provider context, or NULL on failure
 */
jni_provider_context_t* jni_provider_context_create(JNIEnv* env);

/**
 * @brief Destroys a provider context and releases all references.
 * 
 * @param ctx Provider context to destroy
 */
void jni_provider_context_destroy(jni_provider_context_t* ctx);

/**
 * @brief Sets a provider in the context.
 * 
 * @param ctx Provider context
 * @param env JNI environment
 * @param provider_type Type of provider (e.g., "clipboard", "timer")
 * @param provider Provider object
 * @return 0 on success, -1 on failure
 */
int jni_provider_context_set_provider(
    jni_provider_context_t* ctx,
    JNIEnv* env,
    const char* provider_type,
    jobject provider
);

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * @brief Converts a Java string to a C string.
 * 
 * The returned string must be freed with free().
 * 
 * @param env JNI environment
 * @param jstr Java string
 * @return C string, or NULL on failure
 */
char* jni_string_to_c(JNIEnv* env, jstring jstr);

/**
 * @brief Converts a C string to a Java string.
 * 
 * @param env JNI environment
 * @param cstr C string
 * @return Java string, or NULL on failure
 */
jstring jni_string_from_c(JNIEnv* env, const char* cstr);

/**
 * @brief Throws a Java exception from native code.
 * 
 * @param env JNI environment
 * @param exception_class Full class name of exception
 * @param message Exception message
 */
void jni_throw_exception(JNIEnv* env, const char* exception_class, const char* message);

#ifdef __cplusplus
}
#endif

#endif /* WHATWG_JNI_BRIDGE_H */

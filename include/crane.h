/*
 * Crane's host API: isolated Browsers on threads of their own, and their
 * tabs (the instances design, section 5.2; src/browser/capi.zig).
 *
 * Every call is thread-safe and blocks its caller until the Browser's thread
 * has answered. Called from the Browser's own thread - inside an event
 * callback - a tab call returns CRANE_ERR_WRONG_THREAD: no re-entrant
 * commands. Strings out are UTF-8, owned by the result and freed by its
 * _free function. Every options struct starts with struct_size, so the ABI
 * can grow: set it to sizeof the struct.
 *
 * A tab id is the tab's top-level traversable's navigable id (WebDriver
 * BiDi's browsing context id): process-unique, kept for the tab's life.
 *
 * Copyright (c) Crane contributors. MIT License.
 */
#ifndef CRANE_H
#define CRANE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct crane_browser crane_browser_t;
typedef uint64_t crane_tab_id;

typedef enum {
    CRANE_OK = 0,
    CRANE_ERR_INVALID_ARGUMENT = 1,
    CRANE_ERR_NO_SUCH_TAB = 2,
    CRANE_ERR_UNSUPPORTED = 3,
    CRANE_ERR_PROFILE_IN_USE = 4,
    CRANE_ERR_OUT_OF_MEMORY = 5,
    CRANE_ERR_NAVIGATION_FAILED = 6,
    CRANE_ERR_WRONG_THREAD = 7,
    CRANE_ERR_PROCESS_NOT_STARTED = 8,
    CRANE_ERR_TIMEOUT = 9,
    CRANE_ERR_INTERNAL = 10,
    CRANE_ERR_NO_SUCH_DIALOG = 11,  /* no dialog open in the tab */
    CRANE_ERR_USER_PROMPT_OPEN = 12 /* a dialog opened while the call
                                       waited: answer it, call again */
} crane_status;

/* When a navigation call returns (BiDi browsingContext.ReadinessState). */
typedef enum {
    CRANE_READY_NONE = 0,        /* once the navigation has started */
    CRANE_READY_INTERACTIVE = 1, /* the new document's DOMContentLoaded */
    CRANE_READY_COMPLETE = 2     /* the new document's load */
} crane_readiness;

/* ---- The process ------------------------------------------------------ */

typedef struct {
    uint32_t struct_size;
    const char *snapshot_path; /* NULL: the default; "": none */
} crane_process_options_t;

/* Once, first in main, before the embedder makes any thread that will run
 * Crane. */
crane_status crane_process_init(const crane_process_options_t *options);
/* After the last Browser. The engine keeps its platform until exit. */
void crane_process_shutdown(void);

/* ---- Events ----------------------------------------------------------- */

/* What a Zig host hears, for a C host: tabs and frames, each navigation
 * milestone, a new document's start, the simple dialogs, and a page asking
 * for a window. Field use per kind is listed beside each kind. */
typedef enum {
    CRANE_EVENT_TAB_CREATED = 1,
    CRANE_EVENT_TAB_DESTROYED = 2,
    CRANE_EVENT_FRAME_CREATED = 3,
    CRANE_EVENT_FRAME_DESTROYED = 4,
    CRANE_EVENT_NAVIGATION_STARTED = 5,       /* url; detail: crane_navigation_initiator */
    CRANE_EVENT_NAVIGATION_READY = 6,         /* response decided, nothing unloaded yet:
                                                 url; detail: crane_ready_outcome;
                                                 http_status; extra: MIME type;
                                                 message: a network error's text */
    CRANE_EVENT_NAVIGATION_COMMITTED = 7,     /* url; extra: MIME type;
                                                 detail: CRANE_COMMITTED_* bits */
    CRANE_EVENT_NAVIGATION_SAME_DOCUMENT = 8, /* url; detail: crane_same_document_kind */
    CRANE_EVENT_NAVIGATION_ABORTED = 9,       /* detail: crane_abort_reason */
    CRANE_EVENT_DOM_CONTENT_LOADED = 10,
    CRANE_EVENT_LOAD = 11,
    CRANE_EVENT_STOPPED_LOADING = 12,
    CRANE_EVENT_DOCUMENT_START = 13,          /* realm set up, no page script run */
    CRANE_EVENT_DIALOG_OPENING = 14,          /* tab; related: its navigable;
                                                 detail: crane_dialog_kind; message;
                                                 extra: prompt()'s default; url */
    CRANE_EVENT_DIALOG_CLOSED = 15,           /* flag: accepted; message: the
                                                 prompt's answer */
    CRANE_EVENT_WINDOW_OPEN = 16              /* before the window exists: related:
                                                 the navigable asking; url; message:
                                                 the window name; extra: features,
                                                 comma-separated; flag: user gesture */
} crane_event_kind;

typedef enum { CRANE_INITIATOR_BROWSER_UI = 0, CRANE_INITIATOR_DOCUMENT = 1 } crane_navigation_initiator;
typedef enum {
    CRANE_READY_DOCUMENT = 0,
    CRANE_READY_NETWORK_ERROR = 1,
    CRANE_READY_NO_DOCUMENT = 2,   /* 204 or 205 */
    CRANE_READY_DOWNLOAD = 3
} crane_ready_outcome;
typedef enum {
    CRANE_SAME_DOCUMENT_FRAGMENT = 0,
    CRANE_SAME_DOCUMENT_PUSH = 1,
    CRANE_SAME_DOCUMENT_REPLACE = 2,
    CRANE_SAME_DOCUMENT_TRAVERSE = 3,
    CRANE_SAME_DOCUMENT_INTERCEPT = 4
} crane_same_document_kind;
typedef enum {
    CRANE_ABORT_SUPERSEDED = 0,
    CRANE_ABORT_STOPPED = 1,
    CRANE_ABORT_CANCELED_BY_BEFOREUNLOAD = 2,
    CRANE_ABORT_NAVIGABLE_GONE = 3,
    CRANE_ABORT_BLOCKED = 4
} crane_abort_reason;
typedef enum {
    CRANE_DIALOG_ALERT = 0,
    CRANE_DIALOG_CONFIRM = 1,
    CRANE_DIALOG_PROMPT = 2,
    CRANE_DIALOG_BEFOREUNLOAD = 3
} crane_dialog_kind;
#define CRANE_COMMITTED_ERROR_PAGE 1u
#define CRANE_COMMITTED_RESTORED 2u   /* shown again from the back/forward cache */

typedef struct {
    uint32_t struct_size;
    uint32_t kind;              /* crane_event_kind */
    uint64_t tab;               /* the tab, or the navigable the event is
                                   about (a frame's, a navigation's) */
    uint64_t related;           /* tab_created: its opener (0: none);
                                   frame_created: the parent navigable;
                                   dialog_*, window_open: the navigable */
    bool created_by_web_content;/* tab_created: a page's popup */
    const char *url;            /* see the kinds; borrowed for the call */
    /* Read the fields below only when struct_size covers them. */
    uint64_t navigation_id;     /* navigation events: CDP's loaderId; 0 none */
    uint32_t detail;            /* see the kinds */
    uint32_t http_status;       /* navigation_ready */
    const char *message;        /* see the kinds; borrowed for the call */
    const char *extra;          /* see the kinds; borrowed for the call */
    bool flag;                  /* dialog_closed: accepted;
                                   window_open: a user gesture */
} crane_event_t;

/* Called on the Browser's thread, in order. Must not block or call back. */
typedef void (*crane_event_fn)(void *context, const crane_event_t *event);

/* ---- Browsers --------------------------------------------------------- */

typedef enum {
    CRANE_PROXY_SYSTEM = 0,     /* http_proxy/https_proxy/no_proxy */
    CRANE_PROXY_DIRECT = 1,
    CRANE_PROXY_MANUAL = 2,
    CRANE_PROXY_PAC = 3,        /* CRANE_ERR_UNSUPPORTED */
    CRANE_PROXY_AUTODETECT = 4  /* CRANE_ERR_UNSUPPORTED */
} crane_proxy_kind;

typedef struct {
    uint32_t kind;              /* crane_proxy_kind */
    const char *http;           /* manual: for http: and ws: URLs */
    const char *ssl;            /* manual: for https: and wss: URLs */
    const char *no_proxy;       /* manual: comma-separated hosts */
    const char *pac_url;
} crane_proxy_t;

typedef struct {
    uint32_t struct_size;
    const char *profile_dir;    /* NULL: in memory (a directory:
                                   CRANE_ERR_UNSUPPORTED for now) */
    const char *user_agent;     /* NULL: Crane's */
    const crane_proxy_t *proxy; /* NULL: system */
    bool accept_insecure_certs;
    crane_event_fn on_event;    /* NULL: no events */
    void *event_context;
    bool answers_dialogs;       /* the embedder answers every dialog
                                   (crane_tab_answer_dialog); false: the
                                   platform's dialog does */
} crane_browser_options_t;

/* A Browser on a thread of its own, sharing nothing with any other. */
crane_status crane_browser_create(const crane_browser_options_t *options, crane_browser_t **out);
/* Every tab closed without prompting; the thread joined. */
void crane_browser_destroy(crane_browser_t *browser);

/* ---- Tabs ------------------------------------------------------------- */

typedef struct {
    crane_tab_id id;
    crane_tab_id opener;        /* 0: none */
    bool created_by_web_content;
    char *url;
    char *title;
} crane_tab_info_t;

typedef struct {
    char *url;                  /* the active document's URL then */
} crane_navigate_result_t;

#define CRANE_EVAL_AWAIT_PROMISE 1u
#define CRANE_EVAL_USER_ACTIVATION 2u

typedef struct {
    bool exception;             /* json is the exception's details */
    char *json;                 /* else a BiDi script.RemoteValue */
} crane_evaluate_result_t;

crane_status crane_tab_create(crane_browser_t *browser, const char *url /* NULL: about:blank */,
                              bool background, crane_tab_id *out);
crane_status crane_tab_list(crane_browser_t *browser, crane_tab_info_t **out, size_t *count);
void         crane_tab_info_free(crane_tab_info_t *infos, size_t count);
crane_status crane_tab_activate(crane_browser_t *browser, crane_tab_id tab);
crane_status crane_tab_navigate(crane_browser_t *browser, crane_tab_id tab, const char *url,
                                crane_readiness wait, crane_navigate_result_t *out /* may be NULL */);
crane_status crane_tab_reload(crane_browser_t *browser, crane_tab_id tab, crane_readiness wait,
                              crane_navigate_result_t *out /* may be NULL */);
void         crane_navigate_result_free(crane_navigate_result_t *result);
crane_status crane_tab_traverse_history(crane_browser_t *browser, crane_tab_id tab, int32_t delta);
crane_status crane_tab_evaluate(crane_browser_t *browser, crane_tab_id tab, const char *source, size_t len,
                                uint32_t flags, crane_evaluate_result_t *out);
void         crane_evaluate_result_free(crane_evaluate_result_t *result);
crane_status crane_tab_close(crane_browser_t *browser, crane_tab_id tab, bool prompt_unload);
/* Answer the dialog open in a tab: any thread, the event callback included.
 * text (NULL: none) is what an accepted prompt() returns. */
crane_status crane_tab_answer_dialog(crane_browser_t *browser, crane_tab_id tab, bool accept, const char *text);

#ifdef __cplusplus
}
#endif

#endif /* CRANE_H */

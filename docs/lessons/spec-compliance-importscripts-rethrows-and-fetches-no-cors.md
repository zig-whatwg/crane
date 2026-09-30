# Spec Compliance: importScripts() fetches no-cors and runs with rethrow errors

**Date**: 2026-09-30
**Lesson**: An importScripts()ed script is fetched with a new request's default mode, "no-cors", and run with "rethrow errors" true: what it throws goes to the caller's catch - or, muted, becomes a NetworkError - and is never reported to the worker's onerror.

**Why**: "Import scripts into worker global scope" runs "fetch a classic worker-imported script" (no-cors, destination script, the unsafe response's status and JavaScript MIME type checked) and then "run a classic script" with rethrow errors, "letting the exception ... continue to be processed by the calling script".

**What Happened**: Crane ran the imported script through the worker's normal "run a classic script", which reports: a `try { importScripts(x) } catch` never caught, the worker's `error` fired, and testharness counted a harness error (checkpoint-importScripts.any.js). The legacy html_core fetch it used was same-origin only, so a script reached through a cross-origin redirect was a NetworkError (base-url-worker-importScripts.html).

**Fix**: worker_host.fetchClassicWorkerImportedScript and runImportedScript (lane/scripts 93268d8f3): the engine's reporter keeps the thrown value, and the caller throws it again with `engine.throwValue` (ExceptionPending); a CORS-cross-origin script's throw is a NetworkError and its base URL about:blank. Crane test: crane/script-import-scripts.html.

**Takeaway**: **"Rethrow errors" means the report never happens: keep the thrown value from the engine's reporter and throw it into the caller once the script has been cleaned up after.**

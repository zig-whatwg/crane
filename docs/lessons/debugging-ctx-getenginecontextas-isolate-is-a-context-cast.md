# Debugging: `ctx.getEngineContextAs(Isolate)` is a context cast to an isolate

**Date**: 2026-09-22
**Lesson**: Three more impls survived the WebSocket and XHR fixes still casting
a context pointer to an isolate (046399d52). Grep for it; use
`v8_Isolate_GetCurrent()`.

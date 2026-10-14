# Architecture: Window callback errors use the HTML reporter

**Date**: 2026-10-14
**Lesson**: A null ContextData.report_exception on a Window realm means use the shared HTML error reporter, not discard the exception.

**Why**: ContextData.report_exception is a host override for workers. Windows report exceptions by firing ErrorEvent at their global through html.report_exception.reportErrorInfo. The engine protocol's reporter gives the associated realm and borrowed error information; the feature supplies the route to that global.

**What Happened**: An XPath namespace resolver correctly threw NamespaceError after a callback failed, but the original exception never reached the window's error listener. Calling only the optional context override silently did nothing for Window realms. Six upstream resolver tests detected the missing reports; `crane/xp2-resolver-report.html` isolated the original thrown-object identity.

**Fix**: Follow Window.reportIdleCallbackException: select engine.ErrorInfo.realm, fall back to the calling realm, obtain its global, and pass the extracted information to the shared HTML reporter. Keep the completion's owned exception alive until reporting ends, then release it. The reporter handles the worker override, error-event construction and recursion guard.

**Takeaway**: **Use the shared HTML reporting algorithm; the context override alone is not a general exception-reporting API.**

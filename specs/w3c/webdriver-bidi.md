## 1. Introduction

*This section is non-normative.*

[WebDriver](#biblio-webdriver "WebDriver") defines a
protocol for introspection and remote control of user agents. This
specification extends WebDriver by introducing bidirectional
communication. In place of the strict command/response format of
WebDriver, this permits events to stream from the user agent to the
controlling software, better matching the evented nature of the browser
DOM.

## 2. Infrastructure

This specification depends on the Infra Standard.
[\[INFRA\]](#biblio-infra "Infra Standard")

Network protocol messages are defined using CDDL.
[\[RFC8610\]](#biblio-rfc8610 "Concise Data Definition Language (CDDL): A Notational Convention to Express Concise Binary Object Representation (CBOR) and JSON Data Structures")

This specification defines a [wait queue] which is a
[map](https://infra.spec.whatwg.org/#ordered-map).

Surely there's a better mechanism for
doing this \"wait for an event\" thing.

When an algorithm `algorithm` running [in
parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel) [awaits] a set of events `events`, and
`resume id`:

1. Pause the execution of `algorithm`.

2. Assert: [wait queue](#wait-queue) does not contain `resume id`.

3. Set [wait queue](#wait-queue)\[`resume id`\] to (`events`,
 `algorithm`).

To [resume] given
`name`, `id` and `parameters`:

1. If [wait queue](#wait-queue)
 does not contain `id`, return.

2. Let (`events`, `algorithm`) be [wait
 queue](#wait-queue)\[`id`\]

3. For each `event` in `events`:

 1. If `event` equals `name`:

 1. Remove `id` from [wait
 queue](#wait-queue).

 2. Resume running the steps in `algorithm` from the
 point at which they were paused, passing `name`
 and `parameters` as the result of the
 [await](#awaits).

 (#issue-540e1580) Should we have something
 like microtasks to ensure this runs before any other tasks
 on the event loop?

## 3. Protocol

This section defines the basic concepts of the WebDriver BiDi protocol.
These terms are distinct from their representation at the
[transport](#transport) layer.

The protocol is defined using a
[CDDL](#biblio-rfc8610 "Concise Data Definition Language (CDDL): A Notational Convention to Express Concise Binary Object Representation (CBOR) and JSON Data Structures")
definition. For the convenience of implementers two separate CDDL
definitions are defined; the [remote end
definition] which
defines the format of messages produced on the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends) and consumed on the [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends), and the [local end
definition] which defines
the format of messages produced on the [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) and consumed on the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends)

### 3.1. Definition

Should this be an appendix?

This section gives the initial contents of the
[`remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition). These are augmented by the definition fragments
defined in the remainder of the specification.

[`Remote end definition`](#cddl-module-remote-end-definition)

```
Command = {
 id: js-uint,
 CommandData,
 Extensible,
}

CommandData = (
 BrowserCommand //
 BrowsingContextCommand //
 EmulationCommand //
 InputCommand //
 NetworkCommand //
 ScriptCommand //
 SessionCommand //
 StorageCommand //
 WebExtensionCommand
)

EmptyParams = {
 Extensible
}
```

[`Local end definition`](#cddl-module-local-end-definition)

```
Message = (
 CommandResponse /
 ErrorResponse /
 Event
)

CommandResponse = {
 type: "success",
 id: js-uint,
 result: ResultData,
 Extensible
}

ErrorResponse = {
 type: "error",
 id: js-uint / null,
 error: ErrorCode,
 message: text,
 ? stacktrace: text,
 Extensible
}

ResultData = (
 BrowserResult /
 BrowsingContextResult /
 EmulationResult /
 InputResult /
 NetworkResult /
 ScriptResult /
 SessionResult /
 StorageResult /
 WebExtensionResult
)

EmptyResult = {
 Extensible
}

Event = {
 type: "event",
 EventData,
 Extensible
}

EventData = (
 BrowsingContextEvent //
 InputEvent //
 LogEvent //
 NetworkEvent //
 ScriptEvent
)
```

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`Local end definition`](#cddl-module-local-end-definition)

```
Extensible = (*text => any)

js-int = -9007199254740991..9007199254740991
js-uint = 0..9007199254740991
```

### 3.2. Session

WebDriver BiDi extends the
[session](https://w3c.github.io/webdriver/#dfn-sessions) concept from
[WebDriver](#biblio-webdriver "WebDriver").

A
[session](https://w3c.github.io/webdriver/#dfn-sessions) has a [BiDi flag], which is false unless otherwise stated.

A [BiDi session] is a
[session](https://w3c.github.io/webdriver/#dfn-sessions) which has the [BiDi
flag](#bidi-flag) set to true.

The list of [active BiDi sessions] is given by:

1. Let `BiDi sessions` be a new
 [list](https://infra.spec.whatwg.org/#list).

2. For each `session` in [active
 sessions](https://w3c.github.io/webdriver/#dfn-active-sessions):

 1. If `session` is a [BiDi
 session](#bidi-session)
 append `session` to `BiDi sessions`.

3. Return `BiDi sessions`.

### 3.3. Modules

The WebDriver BiDi protocol is organized into modules.

Each [module]
represents a collection of related [commands](#command) and [events](#event)
pertaining to a certain aspect of the user agent. For example, a module
might contain functionality for inspecting and manipulating the DOM, or
for script execution.

Each module has a [module name] which is a string. The
[command name](#command-command-name) and [event
name](#event-event-name) for
commands and events defined in the module start with the [module
name](#module-module-name)
followed by a period \"`.`\".

Modules which contain [commands](#command) define
[`remote end definition`](#cddl-module-remote-end-definition) fragments. These provide choices in the `CommandData`
group for the module's [commands](#command), and can also define additional definition properties.
They can also define
[`local end definition`](#cddl-module-local-end-definition) fragments that provide additional choices in the
`ResultData` group for the results of commands in the module.

Modules which contain events define
[`local end definition`](#cddl-module-local-end-definition) fragments that are choices in the `Event` group for
the module's [events](#event).

An implementation may define [extension modules]. These must have a [module
name](#module-module-name)
that contains a single colon \"`:`\" character. The part before the
colon is the prefix; this is typically the same for all [extension
modules](#extension-modules)
specific to a given implementation and should be unique for a given
implementation.

Other specifications may define their own WebDriver-BiDi modules that
extend the protocol. Such modules must not have a name which contains a
colon (`:`) character, nor must they define [command
names](#command-command-name), [event
names](#subscription-event-names), or property names that contain that character.

Authors of external specifications are encouraged to to add new modules
rather than extending existing ones. Where it is desired to extend an
existing module, it is preferred to integrate the extension directly
into the specification containing the original module definition.

### 3.4. Commands

A [command] is an
asynchronous operation, requested by the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends) and run on the [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends), resulting in either a result or an error being
returned to the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends). Multiple commands can run at the same time, and
commands can potentially be long-running. As a consequence, commands can
finish out-of-order.

Each [command](#command) is defined
by:

- A [command type] which is defined by a
 [`remote end definition`](#cddl-module-remote-end-definition) fragment containing a group. Each such group has two
 fields:

 - `method` which is a string literal of the form
 `[module name].[method name]`. This is the [command
 name].

 - `params` which defines a mapping containing data that to be passed
 into the command. The populated value of this map is the [command
 parameters].

- A [result type], which is defined by a
 [`local end definition`](#cddl-module-local-end-definition) fragment.

- A set of [remote end
 steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) which define the actions to take for a command given
 a [BiDi session](#bidi-session) and [command
 parameters](#command-command-parameters) and return an instance of the command [result
 type](#command-result-type).

A command that can run without an active session is a [static
command]. Commands are not static commands unless stated in
their definition.

When commands are sent from the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends) they have a command id. This is an identifier used by
the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends) to identify the response from a particular command.
From the point of view of the [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) this identifier is opaque and cannot be used internally
to identify the command.

 This is because the command id is entirely controlled
by the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends) and isn't necessarily unique over the course of a
session. For example a [local
end](https://w3c.github.io/webdriver/#dfn-local-ends) which ignores all responses could use the same command
id for each command.

The [set of all command names] is a
[set](https://infra.spec.whatwg.org/#ordered-set) containing all the defined [command
names](#command-command-name), including any belonging to [extension
modules](#extension-modules).

### 3.5. Errors

WebDriver BiDi extends the set of [error
codes](https://w3c.github.io/webdriver/#dfn-error-code) from
[WebDriver](#biblio-webdriver "WebDriver") with the
following additional codes:

[invalid web extension]
: Tried to install an invalid web extension.

[no such client window]
: Tried to interact with an unknown [client
 window](#client-window).

[no such handle]
: Tried to deserialize an unknown `RemoteObjectReference`.

[no such history entry]
: Tried to havigate to an unknown [session history
 entry](https://html.spec.whatwg.org/multipage/browsing-the-web.html#session-history-entry).

[no such network collector]
: Tried to remove an unknown
 [collector](#network-collector).

[no such intercept]
: Tried to remove an unknown [network
 intercept](#network-intercept).

[no such network data]
: Tried to reference an unknown [network
 data](#network-data).

[no such node]
: Tried to deserialize an unknown `SharedReference`.

[no such request]
: Tried to continue an unknown
 [request](https://fetch.spec.whatwg.org/#concept-request).

[no such script]
: Tried to remove an unknown [preload
 script](#preload-script).

[no such storage partition]
: Tried to access data in a non-existent storage partition.

[no such user context]
: Tried to reference an unknown [user
 context](#user-context).

[no such web extension]
: Tried to reference an unknown web extension.

[unable to close browser]
: Tried to close the browser, but failed to do so.

[unable to set cookie]
: Tried to create a cookie, but the user agent rejected it.

[underspecified storage partition]
: Tried to interact with data in a storage partition which was not
 adequately specified.

[unable to set file input]
: Tried to set a file input, but failed to do so.

[unavailable network data]
: Tried to get network data which was not collected or already
 evicted.

```
ErrorCode = "invalid argument" /
 "invalid selector" /
 "invalid session id" /
 "invalid web extension" /
 "move target out of bounds" /
 "no such alert" /
 "no such network collector" /
 "no such element" /
 "no such frame" /
 "no such handle" /
 "no such history entry" /
 "no such intercept" /
 "no such network data" /
 "no such node" /
 "no such request" /
 "no such script" /
 "no such storage partition" /
 "no such user context" /
 "no such web extension" /
 "session not created" /
 "unable to capture screen" /
 "unable to close browser" /
 "unable to set cookie" /
 "unable to set file input" /
 "unavailable network data" /
 "underspecified storage partition" /
 "unknown command" /
 "unknown error" /
 "unsupported operation"
```

### 3.6. Events

An [event] is a
notification, sent by the [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) to the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends), signaling that something of interest has occurred on
the [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends).

- An [event type] is defined by a
 [`local end definition`](#cddl-module-local-end-definition) fragment containing a group. Each such group has two
 fields:

 - `method` which is a string literal of the form
 `[module name].[event name]`. This is the [event
 name].

 - `params` which defines a mapping containing event data. The
 populated value of this map is the [event
 parameters].

- A [remote end event trigger] which defines
 when the event is triggered and steps to construct the [event
 type](#event-event-type)
 data.

- Optionally, a set of [remote end subscribe
 steps], which define steps to take
 when a local end subscribes to an event. Where defined these steps
 have an associated [subscribe priority] which is an integer controlling the order in
 which the steps are run when multiple events are enabled at once, with
 lower integers indicating steps that run earlier.

A [BiDi session](#bidi-session)
has [subscriptions] which is a
[list](https://infra.spec.whatwg.org/#list) of
[subscriptions](#event-subscriptions).

A [BiDi session](#bidi-session)
has a [known subscription ids] which is a
[set](https://infra.spec.whatwg.org/#ordered-set) of all [subscription
ids](#subscription-subscription-id) that have been issued to the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends) but which have not yet been unsubscribed.

A [subscription] is a
[struct](https://infra.spec.whatwg.org/#struct) consisting of a [subscription
id] (a string), [event
names] (a
[set](https://infra.spec.whatwg.org/#ordered-set) of event names), [top-level traversable
ids] (a
[set](https://infra.spec.whatwg.org/#ordered-set) of IDs of [top-level
traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable)) and [user context ids] (a
[set](https://infra.spec.whatwg.org/#ordered-set) of IDs of [user
contexts](#user-context)).

A [subscription](#event-subscription) `subscription` is
[global] if `subscription`'s [top-level
traversable
ids](#subscription-top-level-traversable-ids) is an empty set and `subscription`'s [user
context
ids](#subscription-user-context-ids) is an empty set.

The [set of sessions for which an event is
enabled] given `event name` and
`navigables` is:

1. Let `sessions` be a new
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If [event is
 enabled](#event-is-enabled) with `session`,
 `event name` and `navigables`, append
 `session` to `sessions`.

3. Return `sessions`.

To determine if an [event is enabled] given `session`,
`event name` and `navigables`:

 `navigables` is a set because a [shared
worker](https://html.spec.whatwg.org/multipage/workers.html#shared-workers) can be associated with multiple contexts.

1. Let `top-level traversables` be [get top-level
 traversables](#get-top-level-traversables) with `navigables`.

2. For each `subscription` in `session`'s
 [subscriptions](#event-subscriptions):

 1. If `subscription`'s [event
 names](#subscription-event-names) do not
 [contains](https://infra.spec.whatwg.org/#list-contain) `event name`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. If `subscription` is
 [global](#subscription-global) return true.

 3. If [user context
 ids](#subscription-user-context-ids) is not empty:

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `navigable` in
 `top-level traversables`:

 1. If `subscription`'s [user context
 ids](#subscription-user-context-ids)
 [contains](https://infra.spec.whatwg.org/#list-contain) `navigable`'s [associated
 user
 context](#associated-user-context)'s [user context
 id](#user-context-user-context-id), return true.

 4. Otherwise:

 1. Let `subscription top-level traversables` be [get
 navigables by
 ids](#get-navigables-by-ids) with `subscription`'s [top-level
 traversable
 ids](#subscription-top-level-traversable-ids).

 2. If the
 [intersection](https://infra.spec.whatwg.org/#set-intersection) of `top-level traversables` and
 `subscription top-level traversables` is not
 [empty](https://infra.spec.whatwg.org/#list-empty) return true.

3. Return false.

The [set of top-level traversables for which an event is
enabled] given
`event name` and `session` is:

1. Let `result` be a new
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. For each `subscription` in `session`'s
 [subscriptions](#event-subscriptions):

 1. If `subscription`'s [event
 names](#subscription-event-names) [does not
 contain](https://infra.spec.whatwg.org/#list-contain) `event name`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. If `subscription`'s is
 [global](#subscription-global):

 1. For each `traversable` in remote end's [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable):

 1. [Append](https://infra.spec.whatwg.org/#set-append) `traversable` to
 `result`.

 2. [Break](https://infra.spec.whatwg.org/#iteration-break).

 3. Otherwise, if [user context
 ids](#subscription-user-context-ids) is not empty:

 1. For each `traversable` in remote end's [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable):

 1. [Append](https://infra.spec.whatwg.org/#set-append) `traversable` to
 `result` if `subscription`'s [user
 context
 ids](#subscription-user-context-ids)
 [contains](https://infra.spec.whatwg.org/#list-contain) `traversable`'s [associated
 user
 context](#associated-user-context)'s [user context
 id](#user-context-user-context-id).

 4. Otherwise:

 1. Let `top-level traversables` be [get navigables
 by
 ids](#get-navigables-by-ids) with `subscription`'s [top-level
 traversable
 ids](#subscription-top-level-traversable-ids).

 2. [Append](https://infra.spec.whatwg.org/#set-append) each item of
 `top-level traversables` to `result`.

3. Return `result`.

To [obtain a set of event names] given a `name`:

1. Let `events` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. If `name` contains a U+002E (period):

 1. If `name` is the [event
 name](#event-event-name) for an event, append `name` to
 `events` and return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `events`.

 2. Return an
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument)

3. Otherwise `name` is interpreted as representing all the
 events in a module. If `name` is not a [module
 name](#module-module-name) return an
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

4. Append the [event
 name](#event-event-name)
 for each [event](#event) in the
 module with name `name` to `events`.

5. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `events`.

## 4. Transport

Message transport is provided using the WebSocket protocol.
[\[RFC6455\]](#biblio-rfc6455 "The WebSocket Protocol")

 In the terms of the WebSocket protocol, the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends) is the client and the [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) is the server / remote host.

 The encoding of [commands](#command) and [events](#event)
as messages is similar to JSON-RPC, but this specification does not
normatively reference it.
[\[JSON-RPC\]](#biblio-json-rpc "JSON-RPC 2.0 Specification")
The normative requirements on [remote
ends](https://w3c.github.io/webdriver/#dfn-remote-ends) are instead given as a precise processing model, while
no normative requirements are given for [local
ends](https://w3c.github.io/webdriver/#dfn-local-ends).

A [WebSocket listener] is a network endpoint that is able to accept
incoming
[WebSocket](#biblio-rfc6455 "The WebSocket Protocol")
connections.

A [WebSocket listener](#websocket-listener) has a [host], a [port], a
[secure flag], and a [list of WebSocket
resources].

When a [WebSocket
listener](#websocket-listener) `listener` is created, a [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) must start to listen for WebSocket connections on the
host and port given by `listener`'s
[host](#listener-host) and
[port](#listener-port). If
`listener`'s [secure
flag](#listener-secure-flag) is set, then connections established from
`listener` must be TLS encrypted.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a
[set](https://infra.spec.whatwg.org/#ordered-set) of [WebSocket
listeners](#websocket-listener) [active listeners], which is initially
empty.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a
[set](https://infra.spec.whatwg.org/#ordered-set) of [WebSocket connections not associated with a
session],
which is initially empty.

A [WebSocket connection] is a network connection that follows the
requirements of the [WebSocket
protocol](#biblio-rfc6455 "The WebSocket Protocol")

A [BiDi session](#bidi-session)
has a
[set](https://infra.spec.whatwg.org/#ordered-set) of [session WebSocket
connections] whose
elements are [WebSocket
connections](#websocket-connection). This is initially empty.

A [BiDi session](#bidi-session)
`session` is [associated with
connection] `connection` if `session`'s [session
WebSocket
connections](#session-websocket-connections) contains `connection`.

 Each [WebSocket
connection](#websocket-connection) is associated with at most one [BiDi
session](#bidi-session).

When a client [establishes a WebSocket
connection](https://datatracker.ietf.org/doc/html/rfc6455#section-4.1) `connection` by connecting to one of the set
of [active listeners](#active-listeners) `listener`, the implementation must proceed
according to the WebSocket [server-side
requirements](https://datatracker.ietf.org/doc/html/rfc6455#section-4.2), with the following steps run when deciding whether to
accept the incoming connection:

1. Let `resource name` be the resource name from [reading
 the client's opening
 handshake](https://datatracker.ietf.org/doc/html/rfc6455#section-4.2.1). If `resource name` is not in
 `listener`'s [list of WebSocket
 resources](#list-of-websocket-resources), then stop running these steps and act as if the
 requested service is not available.

2. If `resource name` is the byte string \"`/session`\", and
 the implementation [supports BiDi-only
 sessions](#supports-bidi-only-sessions):

 1. Run any other implementation-defined steps to decide if the
 connection should be accepted, and if it is not stop running
 these steps and act as if the requested service is not
 available.

 2. Add the connection to [WebSocket connections not associated with
 a
 session](#websocket-connections-not-associated-with-a-session).

 3. Return.

3. [Get a session ID for a WebSocket
 resource](#get-a-session-id-for-a-websocket-resource) with `resource name` and let
 `session id` be that value. If `session id` is
 null then stop running these steps and act as if the requested
 service is not available.

4. If there is a
 [session](https://w3c.github.io/webdriver/#dfn-sessions) in the list of [active
 sessions](https://w3c.github.io/webdriver/#dfn-active-sessions) with `session id` as its [session
 ID](https://w3c.github.io/webdriver/#dfn-session-id) then let `session` be that session.
 Otherwise stop running these steps and act as if the requested
 service is not available.

5. Run any other implementation-defined steps to decide if the
 connection should be accepted, and if it is not stop running these
 steps and act as if the requested service is not available.

6. Otherwise append `connection` to `session`'s
 [session WebSocket
 connections](#session-websocket-connections), and proceed with the WebSocket [server-side
 requirements](https://datatracker.ietf.org/doc/html/rfc6455#section-4.2) when a server chooses to accept an incoming
 connection.

Do we support \> 1 connection for a
single session?

When [a WebSocket message has been
received](https://datatracker.ietf.org/doc/html/rfc6455#section-6.2) for a [WebSocket
connection](#websocket-connection) `connection` with type `type` and
data `data`, a [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) must [handle an incoming
message](#handle-an-incoming-message) given `connection`, `type` and
`data`.

When [the WebSocket closing handshake is
started](https://datatracker.ietf.org/doc/html/rfc6455#section-7.1.3) or when [the WebSocket connection is
closed](https://datatracker.ietf.org/doc/html/rfc6455#section-7.1.4) for a [WebSocket
connection](#websocket-connection) `connection`, a [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) must [handle a connection
closing](#handle-a-connection-closing) given `connection`.

 Both conditions are needed because it is possible for a
WebSocket connection to be closed without a closing handshake.

To [construct a WebSocket resource
name] given a
[session](https://w3c.github.io/webdriver/#dfn-sessions) `session`:

1. If `session` is null, return \"`/session`\"

2. Return the result of concatenating the string \"`/session/`\" with
 `session`'s [session
 ID](https://w3c.github.io/webdriver/#dfn-session-id).

To [construct a WebSocket URL] given a [WebSocket
listener](#websocket-listener) `listener` and
[session](https://w3c.github.io/webdriver/#dfn-sessions) `session`:

1. Let `resource name` be the result of [construct a
 WebSocket resource
 name](#construct-a-websocket-resource-name) with `session`.

2. Return a [WebSocket
 URI](https://datatracker.ietf.org/doc/html/rfc6455#section-3) constructed with host set to
 `listener`'s
 [host](#listener-host),
 port set to `listener`'s
 [port](#listener-port),
 path set to `resource name`, following the wss-URI
 construct if `listener`'s [secure
 flag](#listener-secure-flag) is set and the ws-URL construct otherwise.

To [get a session ID for a WebSocket
resource] given `resource name`:

1. If `resource name` doesn't begin with the byte string
 \"`/session/`\", return null.

2. Let `session id` be the bytes in
 `resource name` following the \"`/session/`\" prefix.

3. If `session id` is not the string representation of a
 [UUID](#biblio-rfc9562 "Universally Unique IDentifiers (UUIDs)"),
 return null.

4. Return `session id`.

To [start listening for a WebSocket
connection] given a
[session](https://w3c.github.io/webdriver/#dfn-sessions) `session`:

1. If there is an existing [WebSocket
 listener](#websocket-listener) in [active
 listeners](#active-listeners) which the [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends) would like to reuse, let `listener` be
 that listener. Otherwise let `listener` be a new
 [WebSocket
 listener](#websocket-listener) with
 [implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) [host](#listener-host), [port](#listener-port), [secure
 flag](#listener-secure-flag), and an empty [list of WebSocket
 resources](#list-of-websocket-resources).

2. Let `resource name` be the result of [construct a
 WebSocket resource
 name](#construct-a-websocket-resource-name) with `session`.

3. Append `resource name` to the [list of WebSocket
 resources](#list-of-websocket-resources) for `listener`.

4. [Append](https://infra.spec.whatwg.org/#set-append) `listener` to the [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends)'s [active
 listeners](#active-listeners).

5. Return `listener`.

 An [intermediary
node](https://w3c.github.io/webdriver/#dfn-intermediary-nodes) handling multiple sessions can use one or many
WebSocket listeners.
[WebDriver](#biblio-webdriver "WebDriver") defines
that an [endpoint
node](https://w3c.github.io/webdriver/#dfn-endpoint-node) supports at most one session at a time, so it's
expected to only have a single listener.

 For an [endpoint
node](https://w3c.github.io/webdriver/#dfn-endpoint-node) the [host](#listener-host) in the above steps will typically be \"`localhost`\".

To [handle an incoming message] given a [WebSocket
connection](#websocket-connection) `connection`, type `type` and
data `data`:

1. If `type` is not
 [text](https://datatracker.ietf.org/doc/html/rfc6455#section-5.2), [send an error
 response](#send-an-error-response) given `connection`, null, and [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument), and finally return.

2. [Assert](https://infra.spec.whatwg.org/#assert): `data` is a [scalar value
 string](https://infra.spec.whatwg.org/#scalar-value-string), because the WebSocket [handling errors in
 UTF-8-encoded
 data](https://datatracker.ietf.org/doc/html/rfc6455#section-8.1) would already have [failed the WebSocket
 connection](https://datatracker.ietf.org/doc/html/rfc6455#section-7.1.7) otherwise.

 (#issue-449f8f30) Nothing seems to define what [status
 code](https://datatracker.ietf.org/doc/html/rfc6455#section-7.4) is used for UTF-8 errors.

3. If there is a [BiDi Session](#bidi-session) [associated with
 connection](#associated-with-connection) `connection`, let `session`
 be that session. Otherwise if `connection` is in
 [WebSocket connections not associated with a
 session](#websocket-connections-not-associated-with-a-session), let `session` be null. Otherwise,
 return.

4. Let `parsed` be the result of [parsing JSON into Infra
 values](https://infra.spec.whatwg.org/#parse-a-json-string-to-an-infra-value) given `data`. If this throws an
 exception, then [send an error
 response](#send-an-error-response) given `connection`, null, and [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument), and finally return.

5. If `session` is not null and not in [active
 sessions](https://w3c.github.io/webdriver/#dfn-active-sessions) then return.

6. Match `parsed` against the
 [`remote end definition`](#cddl-module-remote-end-definition). If this results in a match:

 1. Let `matched` be the
 [map](https://infra.spec.whatwg.org/#ordered-map) representing the matched data.

 2. Assert: `matched`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`id`\", \"`method`\", and \"`params`\".

 3. Let `command id` be `matched`\[\"`id`\"\].

 4. Let `method` be `matched`\[\"`method`\"\]

 5. Let `command` be the command with [command
 name](#command-command-name) `method`.

 6. If `session` is null and `command` is not
 a [static command](#static-command), then [send an error
 response](#send-an-error-response) given `connection`,
 `command id`, and [invalid session
 id](https://w3c.github.io/webdriver/#dfn-invalid-session-id), and return.

 7. Run the following steps in parallel:

 1. Let `result` be the result of running the [remote
 end
 steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) for `command` given
 `session` and [command
 parameters](#command-command-parameters) `matched`\[\"`params`\"\]

 2. If `result` is an
 [error](https://w3c.github.io/webdriver/#errors), then [send an error
 response](#send-an-error-response) given `connection`,
 `command id`, and `result`'s [error
 code](https://w3c.github.io/webdriver/#dfn-error-code), and finally return.

 3. Let `value` be `result`'s data.

 4. Assert: `value` matches the definition for the
 [result
 type](#command-result-type) corresponding to the command with [command
 name](#command-command-name) `method`.

 5. If `method` is \"`session.new`\", let
 `session` be the entry in the list of [active
 sessions](https://w3c.github.io/webdriver/#dfn-active-sessions) whose [session
 ID](https://w3c.github.io/webdriver/#dfn-session-id) is equal to the \"`sessionId`\" property of
 `value`,
 [append](https://infra.spec.whatwg.org/#set-append) `connection` to
 `session`'s [session WebSocket
 connections](#session-websocket-connections), and remove `connection` from
 the [WebSocket connections not associated with a
 session](#websocket-connections-not-associated-with-a-session).

 6. Let `response` be a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `CommandResponse` production
 in the
 [`local end definition`](#cddl-module-local-end-definition) with the `id` field set to
 `command id` and the `value` field set to
 `value`.

 7. Let `serialized` be the result of [serialize an
 infra value to JSON
 bytes](https://infra.spec.whatwg.org/#serialize-an-infra-value-to-json-bytes) given `response`.

 8. [Send a WebSocket
 message](https://datatracker.ietf.org/doc/html/rfc6455#section-6.1) comprised of `serialized` over
 `connection`.

7. Otherwise:

 1. Let `command id` be null.

 2. If `parsed` is a
 [map](https://infra.spec.whatwg.org/#ordered-map) and `parsed`\[\"`id`\"\] exists and
 is an integer greater than or equal to zero, set
 `command id` to that integer.

 3. Let `error code` be [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 4. If `parsed` is a
 [map](https://infra.spec.whatwg.org/#ordered-map) and `parsed`\[\"`method`\"\] exists
 and is a string, but `parsed`\[\"`method`\"\] is not
 in the [set of all command
 names](#set-of-all-command-names), set `error code` to [unknown
 command](https://w3c.github.io/webdriver/#dfn-unknown-command).

 5. [Send an error
 response](#send-an-error-response) given `connection`,
 `command id`, and `error code`.

To [get related navigables] given an [settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#settings-object) `settings`:

1. Let `related navigables` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. If `settings`' [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) is a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window):

 1. Let `navigable` be [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

 2. If `navigable` is not null, append
 `navigable` to `related navigables`.

3. Otherwise if the [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global) specified by `settings` is a
 [`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope), for each `owner` in the [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global)'s [owner
 set](https://html.spec.whatwg.org/multipage/workers.html#concept-WorkerGlobalScope-owner-set):

 1. Let `navigable` be null.

 2. If `owner` is a
 [Document](https://dom.spec.whatwg.org/#concept-document), set `navigable` to
 `owner`'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

 3. If `navigable` is not null, append
 `navigable` to `related navigables`.

4. Return `related navigables`.

To [get navigables by ids] given a
[list](https://infra.spec.whatwg.org/#list) of context ids `navigable ids`:

1. Let `result` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. For each `navigable id` in `navigable ids`:

 1. Let `navigable` be the
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) with id `navigable id` if such
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) exists, and null otherwise.

 2. [Append](https://infra.spec.whatwg.org/#set-append) `navigable` to `result`
 if `navigable` is not null.

3. Return `result`.

To [get top-level traversables] given a
[list](https://infra.spec.whatwg.org/#list) of
[navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigables`:

1. Let `result` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. For each `navigable` in `navigables`:

 1. [Append](https://infra.spec.whatwg.org/#set-append) `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top) to `result`.

3. Return `result`.

To [get valid navigables by ids] given a
[list](https://infra.spec.whatwg.org/#list) of context ids `navigable ids`:

1. Let `result` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. For each `navigable id` in `navigable ids`:

 1. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

 2. [Append](https://infra.spec.whatwg.org/#set-append) `navigable` to `result`.

3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `result`.

To [get valid top-level traversables by
ids] given a
[list](https://infra.spec.whatwg.org/#list) of context ids `navigable ids`:

1. Let `result` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. For each `navigable id` in `navigable ids`:

 1. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

 2. If `navigable` is not a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 3. [Append](https://infra.spec.whatwg.org/#set-append) `navigable` to `result`.

3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `result`.

To [emit an event] given `session`, and `body`:

1. [Assert](https://infra.spec.whatwg.org/#assert): `body` matches the `Event` production.

2. Let `serialized` be the result of [serialize an infra
 value to JSON
 bytes](https://infra.spec.whatwg.org/#serialize-an-infra-value-to-json-bytes) given `body`.

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `connection` in `session`'s
 [session WebSocket
 connections](#session-websocket-connections):

 1. [Send a WebSocket
 message](https://datatracker.ietf.org/doc/html/rfc6455#section-6.1) comprised of `serialized` over
 `connection`.

To [send an error response] given a [WebSocket
connection](#websocket-connection) `connection`, `command id`, and
`error code`:

1. Let `error data` be a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `ErrorResponse` production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `id` field set to
 `command id`, the `error` field set to
 `error code`, the `message` field set to an
 implementation-defined string containing a human-readable definition
 of the error that occurred and the `stacktrace` field optionally set
 to an implementation-defined string containing a stack trace report
 of the active stack frames at the time when the error occurred.

2. Let `response` be the result of [serialize an infra value
 to JSON
 bytes](https://infra.spec.whatwg.org/#serialize-an-infra-value-to-json-bytes) given `error data`.

 `command id` can be null, in which case
 the `id` field will also be set to null, not omitted from
 `response`.

3. [Send a WebSocket
 message](https://datatracker.ietf.org/doc/html/rfc6455#section-6.1) comprised of `response` over
 `connection`.

To [handle a connection closing] given a [WebSocket
connection](#websocket-connection) `connection`:

1. If there is a [BiDi session](#bidi-session) [associated with
 connection](#associated-with-connection) `connection`:

 1. Let `session` be the [BiDi
 session](#bidi-session)
 [associated with
 connection](#associated-with-connection) `connection`.

 2. Remove `connection` from `session`'s
 [session WebSocket
 connections](#session-websocket-connections).

2. Otherwise, if [WebSocket connections not associated with a
 session](#websocket-connections-not-associated-with-a-session)
 [contains](https://infra.spec.whatwg.org/#list-contain) `connection`,
 [remove](https://infra.spec.whatwg.org/#list-remove) `connection` from that set.

 This does not end any
[session](https://w3c.github.io/webdriver/#dfn-sessions).

Need to hook in to the session ending to
allow the UA to close the listener if it wants.

To [close the WebSocket connections] given
`session`:

1. For each `connection` in `session`'s [session
 WebSocket
 connections](#session-websocket-connections):

 1. [Start the WebSocket closing
 handshake](https://datatracker.ietf.org/doc/html/rfc6455#section-7.1.2) with `connection`.

 this will result in the steps in [handle a
 connection
 closing](#handle-a-connection-closing) being run for `connection`, which
 will clean up resources associated with `connection`.

### 4.1. Establishing a Connection

WebDriver clients opt in to a bidirectional connection by requesting the
[WebSocket URL](#websocket-url)
capability with value true.

The [WebDriver new session
algorithm](https://w3c.github.io/webdriver/#dfn-webdriver-new-session-algorithms) defined by this specification, with parameters
`session`, `capabilities`, and `flags`
is:

1. If `flags` contains \"`bidi`\", return.

2. Let `webSocketUrl` be the result of [getting a
 property](https://w3c.github.io/webdriver/#dfn-getting-properties) named \"`webSocketUrl`\" from
 `capabilities`.

3. If `webSocketUrl` is undefined, return.

4. [Assert](https://infra.spec.whatwg.org/#assert): `webSocketUrl` is true.

5. Let `listener` be the result of [start listening for a
 WebSocket
 connection](#start-listening-for-a-websocket-connection) given `session`.

6. Set `webSocketUrl` to the result of [construct a
 WebSocket
 URL](#construct-a-websocket-url) with `listener` and
 `session`.

7. [Set a
 property](https://w3c.github.io/webdriver/#dfn-set-a-property) on `capabilities` named
 \"`webSocketUrl`\" to `webSocketUrl`.

8. Set `session`'s [BiDi
 flag](#bidi-flag) to true.

9. Append \"`bidi`\" to flags.

Implementations should also allow clients to establish a [BiDi
Session](#bidi-session) which
is not a [HTTP
Session](https://w3c.github.io/webdriver/#dfn-http-session). In this case the URL to the WebSocket server is
communicated out-of-band. An implementation that allows this [supports
BiDi-only sessions]. At the
time such an implementation is ready to accept requests to start a
WebDriver session, it must:

1. [Start listening for a WebSocket
 connection](#start-listening-for-a-websocket-connection) given null.

## 5. Sandboxed Script Execution

A common requirement for automation tools is to execute scripts which
have access to the DOM of a document, but don't have information about
any changes to the DOM APIs made by scripts running in the navigable
containing the document.

A [BiDi session](#bidi-session)
has a [sandbox map] which is a weak map in which the keys are
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) objects, and the values are maps between strings and
[`SandboxWindowProxy`](#sandboxwindowproxy) objects.

 The definition of sandboxes here is an attempt to
codify the behaviour of existing implementations. It exposes parts of
the implementations that have previously been considered internal by
specifications, in particular the distinction between the internal state
of platform objects (which is typically implemented as native objects in
the main implementation language of the browser engine) and the
ECMAScript-visible state. Because existing sandbox implementations
happen at a low level in the engine, implementations converging toward
the specification in all details might be a slow process. In the
meantime, implementers are encouraged to provide detailed documentation
on any differences with the specification, and users of this feature are
encouraged to explicitly test that scripts running in sandboxes work in
all implementations.

### 5.1. Sandbox Realms

Each sandbox is a unique ECMAScript
[Realm](https://tc39.es/ecma262/#sec-code-realms). However the sandbox realm provides access to platform
objects in an existing
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) realm via
[`SandboxProxy`](#sandboxproxy) objects.

To [get or create a sandbox realm] given `name` and
`navigable`:

1. If `name` is an empty string, then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. Let `window` be `navigable`'s [active
 window](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-window).

3. If [sandbox map](#sandbox-map)
 does not contain `window`, set [sandbox
 map](#sandbox-map)\[`window`\] to a new
 [map](https://infra.spec.whatwg.org/#ordered-map).

4. Let `sandboxes` be [sandbox
 map](#sandbox-map)\[`window`\].

5. If `sandboxes` does not contain `name`, set
 `sandboxes`\[`name`\] to [create a sandbox
 realm](#create-a-sandbox-realm) with `navigable`.

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data
 `sandboxes`\[`name`\].

To [create a sandbox realm] with `window`:

Define creation of sandbox realm. This
is going to return a
[`SandboxWindowProxy`](#sandboxwindowproxy) wrapping `window`.

To [get a sandbox name] given `target realm`:

1. Let `realms maps` be [get the
 values](https://infra.spec.whatwg.org/#map-getting-the-values) of [sandbox
 map](#sandbox-map).

2. For each `realms map` in `realms maps`:

 1. For each `name` → `realm` in
 `realms map`:

 1. If `realm` is `target realm`, return
 `name`.

3. Return null.

### 5.2. Sandbox Proxy Objects

A [`SandboxProxy`] object is an exotic object that mediates
sandboxed access to objects from another realm. Sandbox proxy objects
are designed to enforce the following restrictions:

- Platform objects are accessible, but property access returns only Web
 IDL-defined properties and not ECMAScript-defined properties (either
 \"expando\" properties that are not present in the underlying
 interface, or ECMAScript-defined properties that shadow a property in
 the underlying interface).

- Setting a property either runs Web IDL-defined setter steps, or sets a
 property on the proxy object. This means that properties written
 outside the sandbox are not accessible, but interface members can be
 used as normal.

There is no [`SandboxProxy`](#sandboxproxy) interface object.

Define in detail how
[`SandboxProxy`](#sandboxproxy) works

To get [unwrapped] `object`:

1. While `object` is
 [`SandboxProxy`](#sandboxproxy) or
 [`SandboxWindowProxy`](#sandboxwindowproxy), set `object` to it's wrapped object.

2. Return `object`.

### 5.3. SandboxWindowProxy

A [`SandboxWindowProxy`] is an exotic object that represents a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object wrapped by a
[`SandboxProxy`](#sandboxproxy) object. This provides sandboxed access to that data in
a
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) global.

Define how this works.

## 6. User Contexts

A [user context] represents a collection of zero or more [top-level
traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) within a [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends). Each [user
context](#user-context) has an
associated [storage
partition](#storage-partition), so that [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) data is not shared between different [user
contexts](#user-context).

Unclear that this is the best way to
formally define the concept of a user context or the interaction with
storage.

 The infra spec uses the term \"user agent\" to refer to
the same concept as [user
contexts](#user-context).
However, this is not compatible with usage of the term \"user agent\" to
mean the entire web client with multiple [user
contexts](#user-context).
Although this difference is not visible to web content, it is observed
via WebDriver, so we avoid using this terminology.

A [user context](#user-context)
has a [user context id], which is a unique
string set upon the user context creation.

A
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) has an [associated user
context], which is a [user
context](#user-context).

When a new [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) is created its [associated user
context](#associated-user-context) is set to a user context in the [set of user
contexts](#set-of-user-contexts).

 In some cases the user context is set by specification
when the [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) is created, however in cases where no such requirements
are present, the [associated user
context](#associated-user-context) for a [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) is implemenation-defined.

Should we specify that [top-level
traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) with a non-null opener have the same [associated user
context](#associated-user-context) as their opener? Need to check if this is something
existing implementations enforce.

A [child
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable)'s [associated user
context](#associated-user-context) is it's
[parent](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-parent)'s [associated user
context](#associated-user-context).

A [user context](#user-context)
which isn't the [associated user
context](#associated-user-context) for any [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) is an [empty user context].

The [default user context] is a [user
context](#user-context) with
[user context
id](#user-context-user-context-id) `"default"`.

An implementation has a [set of user contexts], which is a
[set](https://infra.spec.whatwg.org/#ordered-set) of [user
contexts](#user-context).
Initially this contains the [default user
context](#default-user-context).

Implementations may
[append](https://infra.spec.whatwg.org/#set-append) new [user
contexts](#user-context) to the
[set of user
contexts](#set-of-user-contexts) at any time, for example in response to user actions.

 \"At any time\" here includes during implementation
startup, so a given implementation might always have multiple entries in
the [set of user
contexts](#set-of-user-contexts).

Implementations may
[remove](https://infra.spec.whatwg.org/#list-remove) any [empty user
context](#empty-user-context), with exception of the [default user
context](#default-user-context), from the [set of user
contexts](#set-of-user-contexts) at any time. However they are not required to remove
such [user contexts](#user-context). [User contexts](#user-context) that are not [empty user
contexts](#empty-user-context) must not be removed from the [set of user
contexts](#set-of-user-contexts).

A [BiDi session](#bidi-session)
has a [user context to accept insecure certificates override
map], which is a
[map](https://infra.spec.whatwg.org/#ordered-map) between [user
contexts](#user-context) and
boolean.

A [BiDi session](#bidi-session)
has a [user context to proxy configuration
map], which is a
[map](https://infra.spec.whatwg.org/#ordered-map) between [user
contexts](#user-context) and
[proxy
configuration](https://w3c.github.io/webdriver/#dfn-proxy-configuration).

An [emulated network conditions
struct] is a
[struct](https://infra.spec.whatwg.org/#struct) with:

- [item](https://infra.spec.whatwg.org/#struct-item) named
 [offline] which is a boolean or null.

A [BiDi session](#bidi-session)
has a [emulated network conditions] which is
a [struct](https://infra.spec.whatwg.org/#struct) with an
[item](https://infra.spec.whatwg.org/#struct-item) named [default network
conditions], which is an [emulated network conditions
struct](#emulated-network-conditions-struct) or null, an
[item](https://infra.spec.whatwg.org/#struct-item) named [user context network
conditions], which is a weak map between [user
contexts](#user-context) and
[emulated network conditions
struct](#emulated-network-conditions-struct), and a
[item](https://infra.spec.whatwg.org/#struct-item) named [navigable network
conditions], which is a weak map between
[navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) and [emulated network conditions
struct](#emulated-network-conditions-struct).

When a [user context](#user-context) is
[removed](https://infra.spec.whatwg.org/#list-remove) from the [set of user
contexts](#set-of-user-contexts), [remove user context
subscriptions](#remove-user-context-subscriptions).

To [remove user context
subscriptions]:

1. For each `session` in [active
 sessions](https://w3c.github.io/webdriver/#dfn-active-sessions):

 1. Let `subscriptions to remove` be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

 2. For each `subscription` in `session`'s
 [subscriptions](#event-subscriptions):

 1. If `subscription`'s [user context
 ids](#subscription-user-context-ids)
 [contains](https://infra.spec.whatwg.org/#list-contain) `navigable`'s [associated user
 context](#associated-user-context)'s [user context
 id](#user-context-user-context-id);

 1. [Remove](https://infra.spec.whatwg.org/#list-remove) `navigable`'s [associated
 user
 context](#associated-user-context)'s [user context
 id](#user-context-user-context-id) from `subscription`'s [user
 context
 ids](#subscription-user-context-ids).

 2. If `subscription`'s [user context
 ids](#subscription-user-context-ids) is empty:

 1. [Append](https://infra.spec.whatwg.org/#set-append) `subscription` to
 `subscriptions to remove`.

 3. [Remove](https://infra.spec.whatwg.org/#list-remove) `subscriptions to remove` from
 `session`'s
 [subscriptions](#event-subscriptions).

To [get user context] given `user context id`:

1. For each `user context` in the [set of user
 contexts](#set-of-user-contexts):

2. If `user context`'s [user context
 id](#user-context-user-context-id) equals `user context id`:

 1. Return `user context`.

3. Return null.

To [get valid user contexts] given `user context ids`:

1. Let `result` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. For each `user context id` of
 `user context ids`:

 1. Set `user context` to [get user
 context](#get-user-context) with `user context id`.

 2. If `user context` is null, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such user
 context](#errors-no-such-user-context).

 3. [Append](https://infra.spec.whatwg.org/#set-append) `user context` to
 `result`.

3. Return `result`.

## 7. Modules

### 7.1. The session Module

The [session] module contains commands and events for
monitoring the status of the remote end.

#### 7.1.1. Definition

[`remote end definition`](#cddl-module-remote-end-definition)

```
SessionCommand = (
 session.End //
 session.New //
 session.Status //
 session.Subscribe //
 session.Unsubscribe
)
```

[`local end definition`](#cddl-module-local-end-definition)

```
SessionResult = (
 session.EndResult /
 session.NewResult /
 session.StatusResult /
 session.SubscribeResult /
 session.UnsubscribeResult
)
```

To [end the session] given `session`:

1. Remove `session` from [active
 sessions](https://w3c.github.io/webdriver/#dfn-active-sessions).

2. If [active
 sessions](https://w3c.github.io/webdriver/#dfn-active-sessions) is
 [empty](https://infra.spec.whatwg.org/#list-empty), set the [webdriver-active
 flag](https://w3c.github.io/webdriver/#dfn-webdriver-active-flag) to false.

To [cleanup the session] given `session`:

1. [Close the WebSocket
 connections](#close-the-websocket-connections) with `session`.

2. For each `user context` in the [set of user
 contexts](#set-of-user-contexts):

 1. [Remove](https://infra.spec.whatwg.org/#map-remove) `session`'s [user context to accept
 insecure certificates override
 map](#user-context-to-accept-insecure-certificates-override-map)\[`user context`\].

 2. [Remove](https://infra.spec.whatwg.org/#map-remove) `session`'s [user context to proxy
 configuration
 map](#user-context-to-proxy-configuration-map)\[`user context`\].

3. For each `request id` → (`request`,
 `phase`, `response`) in `session`'s
 [blocked request
 map](#blocked-request-map):

 1. [Resume](#resume) with
 \"`continue request`\", `request id` and
 (`response`, \"`incomplete`\").

4. For each `collector` in `session`'s [network
 collectors](#network-collectors):

 1. Let `collector id` be `collector`'s
 [collector](#network-collector-collector).

 2. For each `collected data` in [collected network
 data](#collected-network-data), [remove collector from
 data](#remove-collector-from-data) with `collected data` and
 `collector id`.

5. If [active
 sessions](https://w3c.github.io/webdriver/#dfn-active-sessions) is
 [empty](https://infra.spec.whatwg.org/#list-empty), [cleanup remote end
 state](#cleanup-remote-end-state).

6. Perform any implementation-specific cleanup steps.

To [cleanup remote end state].

1. [Clear](https://infra.spec.whatwg.org/#map-clear) the [before request sent
 map](#before-request-sent-map).

2. Set the [default cache
 behavior](#default-cache-behavior) to \"`default`\".

3. [Clear](https://infra.spec.whatwg.org/#map-clear) the [navigable cache behavior
 map](#navigable-cache-behavior-map).

4. Perform implementation-defined steps to enable any
 implementation-specific resource caches that are usually enabled in
 the current [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends) configuration.

#### 7.1.2. Types

##### 7.1.2.1. The session.CapabilitiesRequest Type

```
session.CapabilitiesRequest = {
 ? alwaysMatch: session.CapabilityRequest,
 ? firstMatch: [*session.CapabilityRequest]
}
```

The `session.CapabilitiesRequest` type represents the capabilities
requested for a session.

##### 7.1.2.2. The session.CapabilityRequest Type

[`remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
session.CapabilityRequest = {
 ? acceptInsecureCerts: bool,
 ? browserName: text,
 ? browserVersion: text,
 ? platformName: text,
 ? proxy: session.ProxyConfiguration,
 ? unhandledPromptBehavior: session.UserPromptHandler,
 Extensible
}
```

The `session.CapabilityRequest` type represents a specific set of
requested capabilities.

WebDriver BiDi defines [additional WebDriver
capabilities](https://w3c.github.io/webdriver/#dfn-additional-webdriver-capability). The following tables enumerates the capabilities each
implementation must support for WebDriver BiDi.

Capability

[WebSocket URL]

Key

\"`webSocketUrl`\"

Value type

boolean

Description

Defines the current session's support for bidirectional connection.

The [additional capability deserialization
algorithm](https://w3c.github.io/webdriver/#dfn-additional-capability-deserialization-algorithm) for the \"`webSocketUrl`\" capability, with parameter
`value` is:

1. If `value` is not a boolean, return
 [error](https://w3c.github.io/webdriver/#errors) with
 [code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `value`.

The [matched capability serialization
algorithm](https://w3c.github.io/webdriver/#dfn-matched-capability-serialization-algorithm) for the \"`webSocketUrl`\" capability, with parameter
`value` is:

1. If `value` is false, return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

2. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data true.

##### 7.1.2.3. The session.ProxyConfiguration Type

[`remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
session.ProxyConfiguration = {
 session.AutodetectProxyConfiguration //
 session.DirectProxyConfiguration //
 session.ManualProxyConfiguration //
 session.PacProxyConfiguration //
 session.SystemProxyConfiguration
}

session.AutodetectProxyConfiguration = (
 proxyType: "autodetect",
 Extensible
)

session.DirectProxyConfiguration = (
 proxyType: "direct",
 Extensible
)

session.ManualProxyConfiguration = (
 proxyType: "manual",
 ? httpProxy: text,
 ? sslProxy: text,
 ? session.SocksProxyConfiguration,
 ? noProxy: [*text],
 Extensible
)

session.SocksProxyConfiguration = (
 socksProxy: text,
 socksVersion: 0..255,
)

session.PacProxyConfiguration = (
 proxyType: "pac",
 proxyAutoconfigUrl: text,
 Extensible
)

session.SystemProxyConfiguration = (
 proxyType: "system",
 Extensible
)
```

##### 7.1.2.4. The session.UserPromptHandler Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
session.UserPromptHandler = {
 ? alert: session.UserPromptHandlerType,
 ? beforeUnload: session.UserPromptHandlerType,
 ? confirm: session.UserPromptHandlerType,
 ? default: session.UserPromptHandlerType,
 ? file: session.UserPromptHandlerType,
 ? prompt: session.UserPromptHandlerType,
}
```

The `session.UserPromptHandler` type represents the configuration of the
user prompt handler.

 `file` handles file picker. \"accept\" and \"dismiss\"
dismisses the picker. \"ignore\" keeps the picker open.

##### 7.1.2.5. The session.UserPromptHandlerType Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
session.UserPromptHandlerType = "accept" / "dismiss" / "ignore";
```

The `session.UserPromptHandlerType` type represents the behavior of the
user prompt handler.

##### 7.1.2.6. The session.Subscription Type

```
session.Subscription = text
```

The `session.Subscription` type represents a unique subscription
identifier.

##### 7.1.2.7. The session.SubscribeParameters Type

```
session.SubscribeParameters = {
 events: [+text],
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
}
```

The `session.SubscribeParameters` type represents a request to subscribe
to a specific set of events.

##### 7.1.2.8. The session.UnsubscribeByIDRequest Type

```
session.UnsubscribeByIDRequest = {
 subscriptions: [+session.Subscription],
}
```

The `session.UnsubscribeByIDRequest` type represents a request to remove
event subscriptions identified by subscription IDs.

##### 7.1.2.9. The session.UnsubscribeByAttributesRequest Type

```
session.UnsubscribeByAttributesRequest = {
 events: [+text],
}
```

The `session.UnsubscribeByAttributesRequest` type represents a request
to unsubscribe using subscription attributes.

#### 7.1.3. Commands

##### 7.1.3.1. The session.status Command

The [session.status] command returns information
about whether a remote end is in a state in which it can create new
sessions, but may additionally include arbitrary meta information that
is specific to the implementation.

This is a [static command](#static-command).

Command Type

: ```
 session.Status = (
 method: "session.status",
 params: EmptyParams,
 )
 ```

Return Type

: ```
 session.StatusResult = {
 ready: bool,
 message: text,
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session`, and
`command parameters` are:

1. Let `body` be a new
 [map](https://infra.spec.whatwg.org/#ordered-map) with the following properties:

 \"ready\"
 : The [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends)'s [readiness
 state](https://w3c.github.io/webdriver/#dfn-readiness-state).

 \"message\"
 : An implementation-defined string explaining the [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends)'s [readiness
 state](https://w3c.github.io/webdriver/#dfn-readiness-state).

2. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`

##### 7.1.3.2. The session.new Command

The [session.new] command allows creating a
new [BiDi session](#bidi-session).

 A session created this way will not be accessible via
HTTP.

This is a [static command](#static-command).

Command Type

: ```
 session.New = (
 method: "session.new",
 params: session.NewParameters
 )

 session.NewParameters = {
 capabilities: session.CapabilitiesRequest
 }
 ```

Return Type

: ```
 session.NewResult = {
 sessionId: text,
 capabilities: {
 acceptInsecureCerts: bool,
 browserName: text,
 browserVersion: text,
 platformName: text,
 setWindowRect: bool,
 userAgent: text,
 ? proxy: session.ProxyConfiguration,
 ? unhandledPromptBehavior: session.UserPromptHandler,
 ? webSocketUrl: text,
 Extensible
 }
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. If `session` is not null, return an
 [error](https://w3c.github.io/webdriver/#errors) with error code [session not
 created](https://w3c.github.io/webdriver/#dfn-session-not-created).

2. If the implementation is unable to start a new session for any
 reason, return an
 [error](https://w3c.github.io/webdriver/#errors) with error code [session not
 created](https://w3c.github.io/webdriver/#dfn-session-not-created).

3. Let `flags` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing \"`bidi`\".

4. Let `capabilities json` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [process
 capabilities](https://w3c.github.io/webdriver/#dfn-capabilities-processing) with `command parameters` and
 `flags`.

5. Let `capabilities` be [convert a JSON-derived JavaScript
 value to an Infra
 value](https://infra.spec.whatwg.org/#convert-a-json-derived-javascript-value-to-an-infra-value) with `capabilities json`.

6. Let `session` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [create a
 session](https://w3c.github.io/webdriver/#dfn-create-a-session) with `capabilities` and
 `flags`.

7. Set `session`'s [BiDi
 flag](#bidi-flag) to true.

 the connection for this session will be set to the
 current connection by the caller.

8. Let `body` be a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `session.NewResult` production, with
 the `sessionId` field set to `session`'s [session
 ID](https://w3c.github.io/webdriver/#dfn-session-id), and the `capabilities` field set to
 `capabilities`.

9. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

##### 7.1.3.3. The session.end Command

The [session.end] command ends the current
[session](https://w3c.github.io/webdriver/#dfn-sessions).

Command Type

: ```
 session.End = (
 method: "session.end",
 params: EmptyParams
 )
 ```

Return Type

: ```
 session.EndResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. [End the session](#end-the-session) with `session`.

2. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null, and in parallel run the following
 steps:

 1. Wait until the [Send a WebSocket
 message](https://datatracker.ietf.org/doc/html/rfc6455#section-6.1) steps have been called with the response to
 this command.

 (#issue-c10fe58d) this is rather imprecise
 language, but hopefully it's clear that the intent is that we
 send the response to the command before starting shutdown of the
 connections.

 2. [Cleanup the
 session](#cleanup-the-session) with `session`.

##### 7.1.3.4. The session.subscribe Command

The [session.subscribe] command enables certain
events either globally or for a set of navigables.

This needs to be generalized to work
with realms too.

Command Type

: ```
 session.Subscribe = (
 method: "session.subscribe",
 params: session.SubscribeParameters
 )
 ```

Return Type

: ```
 session.SubscribeResult = {
 subscription: session.Subscription,
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `event names` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. For each entry `name` in
 `command parameters`\[\"`events`\"\], let
 `event names` be the
 [union](https://infra.spec.whatwg.org/#set-union) of `event names` and the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [obtain a set of event
 names](#obtain-a-set-of-event-names) with `name`.

3. Let `input user context ids` be [create a
 set](https://infra.spec.whatwg.org/#set-create) with
 `command parameters`\[`userContexts`\].

4. Let `input context ids` be [create a
 set](https://infra.spec.whatwg.org/#set-create) with `command parameters`\[`contexts`\].

5. If `input user context ids` is not empty and
 `input context ids` is not empty, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

6. Let `subscription navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

7. Let `top-level traversable context ids` be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

8. If `input context ids` is not empty:

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid navigables by
 ids](#get-valid-navigables-by-ids) with `input context ids`.

 2. Set `subscription navigables` be [get top-level
 traversables](#get-top-level-traversables) with `navigables`.

 3. For each `navigable` in
 `subscription navigables`:

 1. [Append](https://infra.spec.whatwg.org/#set-append) `navigable`'s [navigable
 id](#navigable-id) to
 `top-level traversable context ids`.

9. Otherwise, if `input user context ids` is not empty:

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `user context id` of
 `input user context ids`:

 1. Let `user context` be [get user
 context](#get-user-context) with `user context id`.

 2. If `user context` is null, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such user
 context](#errors-no-such-user-context).

 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `top-level traversable` in the
 list of all [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) whose [associated user
 context](#associated-user-context) is `user context`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `top-level traversable` to
 `subscription navigables`.

10. Otherwise, set `subscription navigables` to a
 [set](https://infra.spec.whatwg.org/#ordered-set) of all [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top) in the [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends).

11. Let `subscription` be a
 [subscription](#event-subscription) with [subscription
 id](#subscription-subscription-id) set to the string representation of a
 [UUID](#biblio-rfc9562 "Universally Unique IDentifiers (UUIDs)"),
 [event
 names](#subscription-event-names) set to `event names`, [top-level
 traversable
 ids](#subscription-top-level-traversable-ids) set to
 `top-level traversable context ids` and [user context
 ids](#subscription-user-context-ids) set to `input user context ids`.

12. Let `subscribe step events` be a new
 [map](https://infra.spec.whatwg.org/#ordered-map).

13. For each `event name` in the `event names`:

 1. If the [event](#event) with
 [event name](#event-event-name) `event name` does not define [remote
 end subscribe
 steps](#event-remote-end-subscribe-steps), continue;

 2. Let `existing navigables` be a [set of top-level
 traversables for which an event is
 enabled](#set-of-top-level-traversables-for-which-an-event-is-enabled) with `session` and
 `event name`.

 3. Set
 `subscribe step events`\[`event name`\] to
 [difference](https://infra.spec.whatwg.org/#set-difference) of `subscription navigables` and
 `existing navigables`.

14. Append `subscription` to `session`'s
 [subscriptions](#event-subscriptions).

15. Append `subscription`'s [subscription
 id](#subscription-subscription-id) to `session`'s [known subscription
 ids](#event-known-subscription-ids).

16. [Sort in ascending
 order](https://infra.spec.whatwg.org/#map-sort-in-ascending-order) `subscribe step events` using the
 following less than algorithm given two entries with keys
 `event name one` and `event name two`:

 1. Let `event one` be the
 [event](#event) with name
 `event name one`

 2. Let `event two` be the
 [event](#event) with name
 `event name two`

 3. Return true if `event one`'s [subscribe
 priority](#event-subscribe-priority) is less than `event two`'s subscribe
 priority, or false otherwise.

17. If `subscription` is
 [global](#subscription-global), let `include global` be true, otherwise
 let `include global` be false.

18. For each `event name` → `navigables` in
 `subscribe step events`:

 1. Run the [remote end subscribe
 steps](#event-remote-end-subscribe-steps) for the [event](#event) with [event
 name](#event-event-name) `event name` given
 `session`, `navigables` and
 `include global`.

19. Let `body` be a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `session.SubscribeResult` production,
 with the `subscription` field set to `subscription`'s
 [subscription
 id](#subscription-subscription-id).

20. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

##### 7.1.3.5. The session.unsubscribe Command

The [session.unsubscribe] command disables events
either globally or for a set of navigables.

This needs to be generalised to work
with realms too.

Command Type

: ```
 session.Unsubscribe = (
 method: "session.unsubscribe",
 params: session.UnsubscribeParameters,
 )

 session.UnsubscribeParameters = session.UnsubscribeByAttributesRequest / session.UnsubscribeByIDRequest
 ```

Return Type

: ```
 session.UnsubscribeResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. If `command parameters` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`subscriptions`\":

 The condition implies that
 `command parameters` is matching the
 session.UnsubscribeByAttributesRequest production.

 1. Let `event names` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

 2. For each entry `name` in
 `command parameters`\[\"`events`\"\], let
 `event names` be the
 [union](https://infra.spec.whatwg.org/#set-union) of `event names` and the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [obtain a set of event
 names](#obtain-a-set-of-event-names) with `name`.

 3. Let `new subscriptions` to be a
 [list](https://infra.spec.whatwg.org/#list).

 4. Let `matched events` to be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

 5. For each `subscription` of `session`'s
 [subscriptions](#event-subscriptions):

 1. If
 [intersection](https://infra.spec.whatwg.org/#set-intersection) of `subscription`'s [event
 names](#subscription-event-names) and `event names` is an empty
 [set](https://infra.spec.whatwg.org/#ordered-set):

 1. [append](https://infra.spec.whatwg.org/#list-append) `subscription` to
 `new subscriptions`.

 2. [Continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. If `subscription` is not
 [global](#subscription-global):

 1. [append](https://infra.spec.whatwg.org/#list-append) `subscription` to
 `new subscriptions`.

 2. [Continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. Let `subscription event names` be
 [clone](https://infra.spec.whatwg.org/#list-clone) of `subscription`'s [event
 names](#subscription-event-names).

 4. For each `event name` of
 `event names`:

 1. If `subscription event names`
 [contains](https://infra.spec.whatwg.org/#list-contain) `event name`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `event name` to
 `matched events`.

 2. [Remove](https://infra.spec.whatwg.org/#list-remove) `event name` from
 `subscription event names`.

 5. If `subscription event names` is not empty:

 1. Let `cloned subscription` be a
 [subscription](#event-subscription) with [subscription
 id](#subscription-subscription-id) set to `subscription`'s
 [subscription
 id](#subscription-subscription-id), [event
 names](#subscription-event-names) set to a new
 [set](https://infra.spec.whatwg.org/#ordered-set) containing
 `subscription event names`.

 2. [append](https://infra.spec.whatwg.org/#list-append) `cloned subscription` to
 `new subscriptions`.

 6. If `matched events` is not
 [equal](https://infra.spec.whatwg.org/#set-equal) to `event names`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 7. Set `session`'s
 [subscriptions](#event-subscriptions) to `new subscriptions`.

2. Otherwise:

 1. Let `subscriptions` be [create a
 set](https://infra.spec.whatwg.org/#set-create) with
 `command parameters`\[`subscriptions`\].

 2. Let `unknown subscription ids` to
 [difference](https://infra.spec.whatwg.org/#set-difference) between `subscriptions` and
 `session`'s [known subscription
 ids](#event-known-subscription-ids).

 3. If `unknown subscription ids` is not empty:

 1. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 4. Let `subscriptions to remove` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

 5. For each `subscription` in `session`'s
 [subscriptions](#event-subscriptions):

 1. If `subscriptions`
 [contains](https://infra.spec.whatwg.org/#list-contain) `subscription`'s [subscription
 id](#subscription-subscription-id):

 1. [Append](https://infra.spec.whatwg.org/#set-append) `subscription` to
 `subscriptions to remove`.

 6. Set `session`'s [known subscription
 ids](#event-known-subscription-ids) to
 [difference](https://infra.spec.whatwg.org/#set-difference) between `session`'s [known
 subscription
 ids](#event-known-subscription-ids) and `subscriptions`.

 7. [Remove](https://infra.spec.whatwg.org/#list-remove) each item in
 `subscriptions to remove` from `session`'s
 [subscriptions](#event-subscriptions).

3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

### 7.2. The browser Module

The [browser] module contains commands for managing the
remote end browser process.

#### 7.2.1. Definition

[`remote end definition`](#cddl-module-remote-end-definition)

```
BrowserCommand = (
 browser.Close //
 browser.CreateUserContext //
 browser.GetClientWindows //
 browser.GetUserContexts //
 browser.RemoveUserContext //
 browser.SetClientWindowState //
 browser.SetDownloadBehavior
)
```

[`local end definition`](#cddl-module-local-end-definition)

```
BrowserResult = (
 browser.CloseResult /
 browser.CreateUserContextResult /
 browser.GetClientWindowsResult /
 browser.GetUserContextsResult /
 browser.RemoveUserContextResult /
 browser.SetClientWindowStateResult /
 browser.SetDownloadBehaviorResult
)
```

#### 7.2.2. Windows

Each [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) is associated with a single [client
window] which represents a rectangular area
containing the
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) that will be used to render that [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable)'s [active
document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document) when its [visibility
state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is \"`visible`\", as well as any browser-specific user
interface elements associated with displaying the traversable (e.g. any
URL bar, toolbars, or OS window decorations).

A [client window](#client-window) has a [client window id] which is a string uniquely
identifying that window.

A [client window](#client-window) has an [x-coordinate], which
is the number of CSS pixels between the left edge of the [web-exposed
screen
area](https://drafts.csswg.org/cssom-view/#web-exposed-screen-area) and the left edge of the window, or zero if that
doesn't make sense for a particular window.

A [client window](#client-window) has a [y-coordinate], which
is the number of CSS pixels between the top edge of the [web-exposed
screen
area](https://drafts.csswg.org/cssom-view/#web-exposed-screen-area) and the top edge of the window, or zero if that doesn't
make sense for a particular window.

A [client window](#client-window) has a [width], which is the width
of the window's rectangle in CSS pixels.

A [client window](#client-window) has a [height], which is the height
of the window's rectangle in CSS pixels.

To [maximize the client window] `window` an
implementation should either perform steps corresponding to the platform
notion of maximizing `window`, or position
`window` such that its
[x-coordinate](#client-window-x-coordinate) is as close as possible to 0, its
[y-coordinate](#client-window-y-coordinate) is as close as possible to 0, its
[width](#client-window-width) is as close as possible to the width of the
[web-exposed screen
area](https://drafts.csswg.org/cssom-view/#web-exposed-screen-area) and its
[height](#client-window-height) is as close as possible to the height of the
[web-exposed screen
area](https://drafts.csswg.org/cssom-view/#web-exposed-screen-area). If either of these options are supported then
[maximize client window is
supported].

To [minimize the client window] `window` an
implementation should either perform steps corresponding to the platform
notion of minimizing `window`, or otherwise hide
`window` such that all the [active
documents](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document) in [top-level
traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) associated with `window` have [visibility
state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) \"`hidden`\" and `window`'s
[width](#client-window-width) and
[height](#client-window-height) are both as close as possible to 0. If either of these
options are supported then [minimize client window is
supported].

To [restore the client window] `window` an
implementation should ensure that it's neither in a platform-defined
maximized state, nor in a platform-defined minimized state, and that if
there is one or more [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) associated with `window`, at least one of
those has an [active
document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document) in the \"`visible`\" state. If this is supported then
[restore client window is supported].

To [get the client window state] given `window`:

1. Let `documents` be an empty
 [list](https://infra.spec.whatwg.org/#list).

2. Let `visible documents` be an empty
 [list](https://infra.spec.whatwg.org/#list).

3. For each [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) `traversable`:

 1. If `traversable`'s [client
 window](#client-window)
 is not `window` then continue.

 2. Let `document` be `traversable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

 3. [Append](https://infra.spec.whatwg.org/#list-append) `document` to
 `documents`.

 4. If `document`'s [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is \"`visible`\",
 [Append](https://infra.spec.whatwg.org/#list-append) `document` to
 `visible documents`.

4. For each `document` in `visible documents`:

 1. If `document`'s [fullscreen
 element](https://fullscreen.spec.whatwg.org/#fullscreen-element) is not null, return \"`fullscreen`\".

5. If `visible documents` is
 [empty](https://infra.spec.whatwg.org/#list-empty) but `documents` is not
 [empty](https://infra.spec.whatwg.org/#list-empty), or if `window` is otherwise in an
 OS-specific minimized state, return \"`minimized`\".

 This will usually, but not necessarily, mean that
 `window`'s
 [width](#client-window-width) and
 [height](#client-window-height) are equal to 0.

6. If `window` is in an OS-specific maximized state return
 \"`maximized`\".

 This will usually, but not necessarily, mean that
 `window`'s
 [width](#client-window-width) is equal to the width of the [web-exposed screen
 area](https://drafts.csswg.org/cssom-view/#web-exposed-screen-area) and `window`'s
 [height](#client-window-height) is equal to the height of the [web-exposed screen
 area](https://drafts.csswg.org/cssom-view/#web-exposed-screen-area).

7. Return \"`normal`\".

To [set the client window state] given `window` and
`state`:

1. Let `current state` be [get the client window
 state](#get-the-client-window-state) with `window`.

2. If `current state` is \"`fullscreen`\", \"`maximized`\",
 or \"`minimized`\" and is equal to `state`, return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

3. In the following list of conditions and associated steps, run the
 first set of steps for which the associated condition is true:

 \"`fullscreen`\"
 : If not [fullscreen is
 supported](https://fullscreen.spec.whatwg.org/#fullscreen-is-supported) return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

 \"`normal`\"
 : If not [restore client window is
 supported](#restore-client-window-is-supported) for `window` return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

 \"`maximize`\"
 : If not [maximize client window is
 supported](#maximize-client-window-is-supported) for `window` return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

 \"`minimize`\"
 : If not [minimize client window is
 supported](#minimize-client-window-is-supported) for `window` return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

4. Let `documents` be an empty
 [list](https://infra.spec.whatwg.org/#list).

5. For each [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) `traversable`:

 1. If `traversable`'s associated [client
 window](#client-window)
 is not `window` then continue.

 2. Let `document` be `traversable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

 3. Append `document` to `documents`.

6. If `documents` is
 [empty](https://infra.spec.whatwg.org/#list-empty) return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such client
 window](#errors-no-such-client-window).

7. If `current state` is \"`fullscreen`\":

 1. For each `document` in `documents`:

 1. [Fully exit
 fullscreen](https://fullscreen.spec.whatwg.org/#fully-exit-fullscreen) with `document`.

 This is a no-op for documents in window
 that are not fullscreen.

8. Switch on the value of `state`:

 \"`fullscreen`\"

 : 1. For each `document` in `documents`:

 1. If `document`'s [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is \"`visible`\", [fullscreen an
 element](https://fullscreen.spec.whatwg.org/#fullscreen-an-element) with `document`'s [document
 element](https://dom.spec.whatwg.org/#ref-for-dom-document-documentelement).

 2. [Break](https://infra.spec.whatwg.org/#iteration-break).

 \"`normal`\"
 : 1\. [Restore the client
 window](#restore-the-client-window) `window`.

 \"`maximize`\"
 : 1\. [Maximize the client
 window](#maximize-the-client-window) `window`.

 \"`minimize`\"
 : 1\. [Minimize the client
 window](#minimize-the-client-window) `window`.

9. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

#### 7.2.3. Types

##### 7.2.3.1. The browser.ClientWindow Type

```
browser.ClientWindow = text;
```

The `browser.ClientWindow` uniquely identifies a [client
window](#client-window).

##### 7.2.3.2. The browser.ClientWindowInfo Type

```
browser.ClientWindowInfo = {
 active: bool,
 clientWindow: browser.ClientWindow,
 height: js-uint,
 state: "fullscreen" / "maximized" / "minimized" / "normal",
 width: js-uint,
 x: js-int,
 y: js-int,
}
```

The `browser.ClientWindowInfo` type represents properties of a [client
window](#client-window).

To [get the client window info] given
`client window`:

1. Let `client window id` be the [client window
 id](#client-window-id)
 for `client window`.

2. Let `state` be [get the client window
 state](#get-the-client-window-state) with `client window`.

3. If `client window` can receive keyboard input channeled
 from the operating system, let `active` be true,
 otherwise let `active` be false.

 This could mean that a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) whose [client
 window](#client-window) is
 `client window` has [system
 focus](https://html.spec.whatwg.org/multipage/interaction.html#system-focus), or it could mean that the user interface of the
 browser itself currently has focus.

4. Let `client window info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browser.ClientWindowsInfo` production
 with the `clientWindow` field set to `client window id`,
 `state` field set to `state`, the `x` field set to
 `client window`'s
 [x-coordinate](#client-window-x-coordinate), the `y` field set to `client window`'s
 [y-coordinate](#client-window-y-coordinate), the `width` field set to
 `client window`'s
 [width](#client-window-width), the `height` field set to
 `client window`'s
 [height](#client-window-height), and the `active` field set to `active`.

5. Return `client window info`

##### 7.2.3.3. The browser.UserContext Type

```
browser.UserContext = text;
```

The [`browser.UserContext`] unique identifies a [user
context](#user-context).

##### 7.2.3.4. The browser.UserContextInfo Type

```
browser.UserContextInfo = {
 userContext: browser.UserContext
}
```

The `browser.UserContextInfo` type represents properties of a [user
context](#user-context).

#### 7.2.4. Commands

##### 7.2.4.1. The browser.close Command

The [browser.close] command terminates all
WebDriver sessions and cleans up automation state in the remote browser
instance.

Command Type

: ```
 browser.Close = (
 method: "browser.close",
 params: EmptyParams,
 )
 ```

Return Type

: ```
 browser.CloseResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. [End the session](#end-the-session) with `session`.

2. If [active
 sessions](https://w3c.github.io/webdriver/#dfn-active-sessions) is not
 [empty](https://infra.spec.whatwg.org/#list-empty) an implementation may return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unable to close
 browser](#errors-unable-to-close-browser), and then run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel):

 1. Wait until the [Send a WebSocket
 message](https://datatracker.ietf.org/doc/html/rfc6455#section-6.1) steps have been called with the response to
 this command.

 2. [Cleanup the
 session](#cleanup-the-session) with `session`.

 The behaviour in cases where the browser has
 multiple automation sessions is currently unspecified. It might be
 that any session can close the browser, or that only the final open
 session can actually close the browser, or only the first session
 started can. This behaviour might be fully specified in a future
 version of this specification.

3. For each `active session` in [active
 sessions](https://w3c.github.io/webdriver/#dfn-active-sessions):

 1. [End the session](#end-the-session) `active session`.

 2. [Cleanup the
 session](#cleanup-the-session) with `active session`

4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null, and run the following steps [in
 parallel](https://html.spec.whatwg.org/multipage/infrastructure.html#in-parallel).

 1. Wait until the [Send a WebSocket
 message](https://datatracker.ietf.org/doc/html/rfc6455#section-6.1) steps have been called with the response to
 this command.

 2. [Cleanup the
 session](#cleanup-the-session) with `session`.

 3. [Close](https://html.spec.whatwg.org/multipage/document-sequences.html#close-a-top-level-traversable) any [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top) without [prompting to
 unload](https://html.spec.whatwg.org/multipage/browsing-the-web.html#prompt-to-unload-a-document).

 4. Perform implementation defined steps to clean up resources
 associated with the [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends) under automation.

 For example this might include cleanly shutting
 down any OS-level processes associated with the browser under
 automation, removing temporary state, such as user profile data,
 created by the [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends) while under automation, or shutting down the
 [WebSocket
 Listener](#websocket-listener). Because of differences between browsers and
 operating systems it is not possible to specify in detail
 precise invariants [local
 ends](https://w3c.github.io/webdriver/#dfn-local-ends) can depend on here.

##### 7.2.4.2. The browser.createUserContext Command

The [browser.createUserContext] command
creates a [user context](#user-context).

Command Type

: ```
 browser.CreateUserContext = (
 method: "browser.createUserContext",
 params: browser.CreateUserContextParameters,
 )

 browser.CreateUserContextParameters = {
 ? acceptInsecureCerts: bool,
 ? proxy: session.ProxyConfiguration,
 ? unhandledPromptBehavior: session.UserPromptHandler
 }
 ```

Return Type

: ```
 browser.CreateUserContextResult = browser.UserContextInfo
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `user context` be a new [user
 context](#user-context).

2. If `command parameters`
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`acceptInsecureCerts`\":

 If \"`acceptInsecureCerts`\" is set, it overrides
 the [accept insecure
 TLS](https://w3c.github.io/webdriver/#dfn-accept-insecure-tls) flag's behavior.

 1. Let `acceptInsecureCerts` be
 `command parameters`\[\"`acceptInsecureCerts`\"\]:

 2. If `acceptInsecureCerts` is true and [endpoint
 node](https://w3c.github.io/webdriver/#dfn-endpoint-node) doesn't support accepting insecure TLS
 connections, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

 3. [Set](https://infra.spec.whatwg.org/#map-set) `session`'s [user context to accept
 insecure certificates override
 map](#user-context-to-accept-insecure-certificates-override-map)\[`user context`\] to
 `acceptInsecureCerts`.

3. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`unhandledPromptBehavior`\",
 [set](https://infra.spec.whatwg.org/#map-set) [unhandled prompt behavior overrides
 map](#unhandled-prompt-behavior-overrides-map)\[`user context`\] to
 `command parameters`\[\"`unhandledPromptBehavior`\"\].

4. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`proxy`\":

 1. Let `proxy configuration` be
 `command parameters`\[\"`proxy`\"\].

 2. If the [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends) is unable to configure proxy settings per [user
 context](#user-context), or is unable to configure the proxy with
 `proxy configuration`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

 3. [Set](https://infra.spec.whatwg.org/#map-set) `session`'s [user context to proxy
 configuration
 map](#user-context-to-proxy-configuration-map)\[`user context`\] to
 `proxy configuration`.

5. [Append](https://infra.spec.whatwg.org/#set-append) `user context` to the [set of user
 contexts](#set-of-user-contexts).

6. Let `user context info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browser.UserContextInfo` production
 with the `userContext` field set to `user context`'s
 [user context
 id](#user-context-user-context-id).

7. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `user context info`.

##### 7.2.4.3. The browser.getClientWindows Command

The [browser.getClientWindows] command
returns a list of [client
window](#client-window)s.

Command Type

: ```
 browser.GetClientWindows = (
 method: "browser.getClientWindows",
 params: EmptyParams,
 )
 ```

Return Type

: ```
 browser.GetClientWindowsResult = {
 clientWindows: [ * browser.ClientWindowInfo]
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) are:

1. Let `client window ids` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. Let `client windows` be an empty
 [list](https://infra.spec.whatwg.org/#list).

3. For each [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) `traversable`:

 1. Let `client window` be `traversable`'s
 associated [client
 window](#client-window)

 2. Let `client window id` be the [client window
 id](#client-window-id) for `client window`.

 3. If `client window ids`
 [contains](https://infra.spec.whatwg.org/#list-contain) `client window id`, continue.

 4. [Append](https://infra.spec.whatwg.org/#set-append) `client window id` to
 `client window ids`.

 5. Let `client window info` be [get the client window
 info](#get-the-client-window-info) with `client window`.

 6. [Append](https://infra.spec.whatwg.org/#list-append) `client window info` to
 `client windows`.

4. Let `result` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browser.GetClientWindowsResult`
 production with the `clientWindows` field set to
 `client windows`.

5. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `result`.

##### 7.2.4.4. The browser.getUserContexts Command

The [browser.getUserContexts] command
returns a list of [user context](#user-context)s.

Command Type

: ```
 browser.GetUserContexts = (
 method: "browser.getUserContexts",
 params: EmptyParams,
 )
 ```

Return Type

: ```
 browser.GetUserContextsResult = {
 userContexts: [ + browser.UserContextInfo]
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) are:

1. Let `user contexts` be an empty
 [list](https://infra.spec.whatwg.org/#list).

2. For each `user context` in the [set of user
 contexts](#set-of-user-contexts):

 1. Let `user context info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browser.UserContextInfo`
 production with the `userContext` field set to
 `user context`'s [user context
 id](#user-context-user-context-id).

 2. [Append](https://infra.spec.whatwg.org/#list-append) `user context info` to
 `user contexts`.

3. Let `result` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browser.GetUserContextsResult`
 production with the `userContexts` field set to
 `user contexts`.

4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `result`.

##### 7.2.4.5. The browser.removeUserContext Command

The [browser.removeUserContext] command closes
a user context and all navigables in it without running `beforeunload`
handlers.

Command Type

: ```
 browser.RemoveUserContext = (
 method: "browser.removeUserContext",
 params: browser.RemoveUserContextParameters
 )

 browser.RemoveUserContextParameters = {
 userContext: browser.UserContext
 }
 ```

Return Type

: ```
 browser.RemoveUserContextResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. Let `user context id` be
 `command parameters`\[\"`userContext`\"\].

2. If `user context id` is `"default"`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

3. Set `user context` to [get user
 context](#get-user-context) with `user context id`.

4. If `user context` is null, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such user
 context](#errors-no-such-user-context).

5. For each [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top) `navigable`:

 1. If `navigable`'s [associated user
 context](#associated-user-context) is `user context`:

 1. [Close](https://html.spec.whatwg.org/multipage/document-sequences.html#close-a-top-level-traversable) `navigable` without [prompting
 to
 unload](https://html.spec.whatwg.org/multipage/browsing-the-web.html#prompt-to-unload-a-document).

6. [Remove](https://infra.spec.whatwg.org/#list-remove) `user context` for the [set of user
 contexts](#set-of-user-contexts).

7. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.2.4.6. The browser.setClientWindowState Command

The [browser.setClientWindowState] command
sets the dimensions of a [client
window](#client-window).

Command Type

: ```
 browser.SetClientWindowState = (
 method: "browser.setClientWindowState",
 params: browser.SetClientWindowStateParameters
 )

 browser.SetClientWindowStateParameters = {
 clientWindow: browser.ClientWindow,
 (browser.ClientWindowNamedState // browser.ClientWindowRectState)
 }

 browser.ClientWindowNamedState = (
 state: "fullscreen" / "maximized" / "minimized"
 )

 browser.ClientWindowRectState = (
 state: "normal",
 ? width: js-uint,
 ? height: js-uint,
 ? x: js-int,
 ? y: js-int,
 )
 ```

Return Type

: ```
 browser.SetClientWindowStateResult = browser.ClientWindowInfo
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. If the implementation does not support setting the client window
 state at all, then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

2. If there is a [client
 window](#client-window)
 with [client window
 id](#client-window-id)
 `command parameters`\[\"`clientWindow`\"\], let
 `client window` be that [client
 window](#client-window).
 Otherwise return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such client
 window](#errors-no-such-client-window).

3. [Try](https://w3c.github.io/webdriver/#dfn-try) to [set the client window
 state](#set-the-client-window-state) with `client window` and
 `command parameters`\[\"`state`\"\].

4. If `command parameters`\[\"`state`\"\] is \"`normal`\":

 1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`x`\" and the implementation supports
 positioning [client
 windows](#client-window), set the
 [x-coordinate](#client-window-x-coordinate) of `client window` to a value that
 is as close as possible
 `command parameters`\[\"`x`\"\].

 2. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`y`\" and the implementation supports
 positioning [client
 windows](#client-window), set the
 [y-coordinate](#client-window-y-coordinate) of `client window` to a value that
 is as close as possible
 `command parameters`\[\"`y`\"\].

 3. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`width`\" and the implementation supports
 resizing [client
 windows](#client-window), set the
 [width](#client-window-width) of `client window` to a value that
 is as close as possible
 `command parameters`\[\"`width`\"\].

 4. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`width`\" and the implementation supports
 resizing [client
 windows](#client-window), set the
 [width](#client-window-width) of `client window` to a value that
 is as close as possible
 `command parameters`\[\"`width`\"\].

5. Let `client window info` be [get the client window
 info](#get-the-client-window-info) with `client window`.

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `client window info`.

 For simplicity this models all client window operations
as synchronous. Therefore the returned client window dimensions are
expected to be those after the window has reached its new state.

##### 7.2.4.7. The browser.setDownloadBehavior Command

A [download behavior struct] is a
[struct](https://infra.spec.whatwg.org/#struct) with:

- [item](https://infra.spec.whatwg.org/#struct-item) named [allowed] which is a boolean;

- [item](https://infra.spec.whatwg.org/#struct-item) named
 [destinationFolder] which is a string or null.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [download behavior] which is a
[struct](https://infra.spec.whatwg.org/#struct) with an
[item](https://infra.spec.whatwg.org/#struct-item) named [default download
behavior], which is a
[download behavior
struct](#download-behavior-struct) or null, and an
[item](https://infra.spec.whatwg.org/#struct-item) named [user context download
behavior],
which is a weak map between [user
contexts](#user-context) and
[download behavior
struct](#download-behavior-struct).

Command Type

: ```
 browser.SetDownloadBehavior = (
 method: "browser.setDownloadBehavior",
 params: browser.SetDownloadBehaviorParameters
 )

 browser.SetDownloadBehaviorParameters = {
 downloadBehavior: browser.DownloadBehavior / null,
 ? userContexts: [+browser.UserContext]
 }

 browser.DownloadBehavior = {
 (
 browser.DownloadBehaviorAllowed //
 browser.DownloadBehaviorDenied
 )
 }

 browser.DownloadBehaviorAllowed = (
 type: "allowed",
 destinationFolder: text
 )

 browser.DownloadBehaviorDenied = (
 type: "denied"
 )
 ```

Return Type

: ```
 browser.SetDownloadBehaviorResult = EmptyResult
 ```

To [get download behavior] given `navigable`:

1. Let `user context` be `navigable`'s
 [associated user
 context](#associated-user-context).

2. If [download
 behavior](#download-behavior)'s [user context download
 behavior](#download-behavior-user-context-download-behavior)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`, return [download
 behavior](#download-behavior)'s [user context download
 behavior](#download-behavior-user-context-download-behavior)\[`user context`\].

3. Return [download
 behavior](#download-behavior)'s [default download
 behavior](#download-behavior-default-download-behavior).

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. If `command parameters`\[\"`downloadBehavior`\"\] is
 null, let `download behavior` be null.

2. Otherwise:

 1. If
 `command parameters`\[\"`downloadBehavior`\"\]\[\"`type`\"\]
 is \"`allowed`\", let `allowed` be true, otherwise
 let `allowed` be false.

 2. If `command parameters`\[\"`downloadBehavior`\"\]
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`destinationFolder`\", let
 `destinationFolder` be
 `command parameters`\[\"`downloadBehavior`\"\]\[\"`destinationFolder`\"\],
 otherwise let `destinationFolder` be null.

 3. Let `download behavior` be a [download behavior
 struct](#download-behavior-struct) with
 [allowed](#download-behavior-struct-allowed) set to `allowed` and
 [destinationFolder](#download-behavior-struct-destination-folder) set to `destinationFolder`.

3. If the implementation does not support required
 `download behavior`, then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

4. If the `userContexts` field of `command parameters` is
 present:

 1. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 2. For each `user context` of
 `user contexts`:

 1. If `download behavior` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `user context` from [download
 behavior](#download-behavior)'s [user context download
 behavior](#download-behavior-user-context-download-behavior).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) [download
 behavior](#download-behavior)'s [user context download
 behavior](#download-behavior-user-context-download-behavior)\[`user context`\] to
 `download behavior`.

5. Otherwise, set [download
 behavior](#download-behavior)'s [default download
 behavior](#download-behavior-default-download-behavior) to `download behavior`.

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

### 7.3. The browsingContext Module

The [browsingContext] module contains commands and
events relating to
[navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables).

 For historic reasons this module is called
`browsingContext` rather than `navigable`, and the protocol uses the
term `context` to refer to navigables, particularly as a field in
command and response parameters.

The progress of navigation is communicated using an immutable
[struct](https://infra.spec.whatwg.org/#struct) [WebDriver BiDi navigation
status], which has the following
[items](https://infra.spec.whatwg.org/#struct-item):

[id]
: The [navigation
 id](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigation-id) for the navigation, or null when the navigation is
 canceled before making progress.

[status]
: A status code that is either
 \"[`canceled`]\",
 \"[`pending`]\", or
 \"[`complete`]\".

[url]
: The URL which is being loaded in the navigation

[suggestedFilename]
: If the navigation is a download, suggested filename, otherwise null.

[downloadedFilepath]
: If the navigation is a download which is finished and the downloaded
 file is available, absolute filepath of the downloaded file,
 otherwise null.

#### 7.3.1. Definition

[`remote end definition`](#cddl-module-remote-end-definition)

```
BrowsingContextCommand = (
 browsingContext.Activate //
 browsingContext.CaptureScreenshot //
 browsingContext.Close //
 browsingContext.Create //
 browsingContext.GetTree //
 browsingContext.HandleUserPrompt //
 browsingContext.LocateNodes //
 browsingContext.Navigate //
 browsingContext.Print //
 browsingContext.Reload //
 browsingContext.SetViewport //
 browsingContext.TraverseHistory
)
```

[`local end definition`](#cddl-module-local-end-definition)

```
BrowsingContextResult = (
 browsingContext.ActivateResult /
 browsingContext.CaptureScreenshotResult /
 browsingContext.CloseResult /
 browsingContext.CreateResult /
 browsingContext.GetTreeResult /
 browsingContext.HandleUserPromptResult /
 browsingContext.LocateNodesResult /
 browsingContext.NavigateResult /
 browsingContext.PrintResult /
 browsingContext.ReloadResult /
 browsingContext.SetViewportResult /
 browsingContext.TraverseHistoryResult
)

BrowsingContextEvent = (
 browsingContext.ContextCreated //
 browsingContext.ContextDestroyed //
 browsingContext.DomContentLoaded //
 browsingContext.DownloadEnd //
 browsingContext.DownloadWillBegin //
 browsingContext.FragmentNavigated //
 browsingContext.HistoryUpdated //
 browsingContext.Load //
 browsingContext.NavigationAborted //
 browsingContext.NavigationCommitted //
 browsingContext.NavigationFailed //
 browsingContext.NavigationStarted //
 browsingContext.UserPromptClosed //
 browsingContext.UserPromptOpened
)
```

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [device pixel ratio
overrides] which is a weak map between
[navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) and device pixel ratio overrides. It is initially
empty.

 this map is not cleared when the final session ends
i.e. device pixel ratio overrides outlive any WebDriver session.

A [viewport dimensions] is a
[struct](https://infra.spec.whatwg.org/#struct) with:

- [Item](https://infra.spec.whatwg.org/#struct-item) named [height]
 which is an integer;

- [Item](https://infra.spec.whatwg.org/#struct-item) named [width]
 which is an integer.

A [viewport configuration] is a
[struct](https://infra.spec.whatwg.org/#struct) with:

- [Item](https://infra.spec.whatwg.org/#struct-item) named [viewport] which is a [viewport
 dimensions](#viewport-dimensions) or null;

- [Item](https://infra.spec.whatwg.org/#struct-item) named
 [devicePixelRatio] which is a float or null.

An [unhandled prompt behavior struct] is a
[struct](https://infra.spec.whatwg.org/#struct) with:

- [Item](https://infra.spec.whatwg.org/#struct-item) named
 [`alert`] which is a string or null;

- [Item](https://infra.spec.whatwg.org/#struct-item) named
 [`beforeUnload`] which is a string or null;

- [Item](https://infra.spec.whatwg.org/#struct-item) named
 [`confirm`] which is a string or null;

- [Item](https://infra.spec.whatwg.org/#struct-item) named
 [`default`] which is a string or null;

- [Item](https://infra.spec.whatwg.org/#struct-item) named
 [`file`] which is a string or null;

- [Item](https://infra.spec.whatwg.org/#struct-item) named
 [`prompt`] which is a string or null.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [viewport overrides map] which is a weak map
between [user contexts](#user-context) and [viewport
configuration](#viewport-configuration).

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [locale overrides map] which is a weak map between
[navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) or [user
contexts](#user-context) and
string.

A [screen settings] is a
[struct](https://infra.spec.whatwg.org/#struct) with an
[item](https://infra.spec.whatwg.org/#struct-item) named [`height`] which is an integer, an
[item](https://infra.spec.whatwg.org/#struct-item) named [`width`] which is an integer, an
[item](https://infra.spec.whatwg.org/#struct-item) named [`x`]
which is an integer, an
[item](https://infra.spec.whatwg.org/#struct-item) named [`y`]
which is an integer.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [screen settings
overrides] which is a
[struct](https://infra.spec.whatwg.org/#struct) with an
[item](https://infra.spec.whatwg.org/#struct-item) named [user context screen
settings], which is a weak map between [user
contexts](#user-context) and
[screen settings](#screen-settings), and an
[item](https://infra.spec.whatwg.org/#struct-item) named [navigable screen
settings], which is a weak map between
[navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) and [screen
settings](#screen-settings).

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [timezone overrides map] which is a weak map
between
[navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) or [user
contexts](#user-context) and
string.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has an [unhandled prompt behavior overrides
map] which is a weak map between [user
contexts](#user-context) and
[unhandled prompt behavior
struct](#unhandled-prompt-behavior-struct).

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [scripting enabled overrides
map] which is a weak map between
[navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) or [user
contexts](#user-context) and
boolean.

#### 7.3.2. Types

##### 7.3.2.1. The browsingContext.BrowsingContext Type

[`remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
browsingContext.BrowsingContext = text;
```

Each
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) has an associated [navigable id], which is a string uniquely
identifying that navigable. This is implicitly set when the navigable is
created. For navigables with an associated WebDriver [window
handle](https://w3c.github.io/webdriver/#dfn-window-handles) the [navigable
id](#navigable-id) must be the
same as the [window
handle](https://w3c.github.io/webdriver/#dfn-window-handles).

Each
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) also has an [associated storage
partition], which is the [storage
partition](#storage-partition) it uses to persist data.

Each
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) also has an associated [original
opener],
which is a
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) that caused the navigable to open or null, initially
set to null.

To [get a navigable] given `navigable id`:

1. If `navigable id` is null, return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

2. If there is no navigable with [navigable
 id](#navigable-id)
 `navigable id` return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 frame](https://w3c.github.io/webdriver/#dfn-no-such-frame)

3. Let `navigable` be the
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) with id `navigable id`.

4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `navigable`.

##### 7.3.2.2. The browsingContext.Info Type

[`local end definition`](#cddl-module-local-end-definition)

```
browsingContext.InfoList = [*browsingContext.Info]

browsingContext.Info = {
 children: browsingContext.InfoList / null,
 clientWindow: browser.ClientWindow,
 context: browsingContext.BrowsingContext,
 originalOpener: browsingContext.BrowsingContext / null,
 url: text,
 userContext: browser.UserContext,
 ? parent: browsingContext.BrowsingContext / null,
}
```

The `browsingContext.Info` type represents the properties of a
navigable.

To [get the child navigables] given `navigable`:

TODO: make this return a list in document order

1. Let `child navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing all navigables that are a [child
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable) of `navigable`.

2. Return `child navigables`.

To [get the navigable info] given `navigable`,
`max depth` and `include parent id`:

1. Let `navigable id` be the [navigable
 id](#navigable-id) for
 `navigable`.

2. Let `parent navigable` be `navigable`'s
 [parent](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-parent).

3. If `parent navigable` is not null let
 `parent id` be the [navigable
 id](#navigable-id) of
 `parent navigable`. Otherwise let `parent id`
 be null.

4. Let `document` be `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

5. Let `url` be the result of running the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer), given `document`'s
 [URL](https://dom.spec.whatwg.org/#concept-document-url).

 This includes the fragment component of the URL.

6. Let `child infos` be null.

7. If `max depth` is null, or `max depth` is
 greater than 0:

 1. Let `child navigables` be [get the child
 navigables](#get-the-child-navigables) given `navigable`.

 2. Let `child depth` be `max depth` - 1 if
 `max depth` is not null, or null otherwise.

 3. Set `child infos` to an empty
 [list](https://infra.spec.whatwg.org/#list).

 4. For each `child navigable` of
 `child navigables`:

 1. Let `info` be the result of [get the navigable
 info](#get-the-navigable-info) given `child navigable`,
 `child depth`, and false.

 2. Append `info` to `child infos`

8. Let `user context` be `navigable`'s
 [associated user
 context](#associated-user-context).

9. Let `opener id` be the [navigable
 id](#navigable-id) for
 `navigable`'s [original
 opener](#original-opener),
 if `navigable`'s [original
 opener](#original-opener)
 is not null, and null otherwise.

10. Let `top-level traversable` be `navigable`'s
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

11. Let `client window id` be the [client window
 id](#client-window-id)
 for `top-level traversable`'s associated [client
 window](#client-window).

12. Let `navigable info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.Info` production with
 the `context` field set to `navigable id`, the `parent`
 field set to `parent id` if
 `include parent id` is `true`, or unset otherwise, the
 `url` field set to `url`, the `userContext` field set to
 `user context`'s [user context
 id](#user-context-user-context-id), `originalOpener` field set to
 `opener id`, the `children` field set to
 `child infos`, and the `clientWindow` field set to
 `client window id`.

13. Return `navigable info`.

To [await a navigation] given `navigable`,
`request`, `wait condition`, and optionally
`history handling` (default: \"`default`\") and
`ignore cache` (default: false):

1. Let `navigation id` be the string representation of a
 [UUID](#biblio-rfc9562 "Universally Unique IDentifiers (UUIDs)")
 based on truly random, or pseudo-random numbers.

2. [Navigate](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate) `navigable` with resource
 `request`, and using `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document) as the source
 [`Document`](https://dom.spec.whatwg.org/#document), with [navigation
 id](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigation-id) `navigation id`, and [history handling
 behavior](https://html.spec.whatwg.org/multipage/browsing-the-web.html#history-handling-behavior) `history handling`. If
 `ignore cache` is true, the navigation must not load
 resources from the HTTP cache.

 (#issue-40db6a3c) property specify how the
 `ignore cache` flag works. This needs to consider whether
 only the first load of a resource bypasses the cache (i.e. whether
 this is like initially clearing the cache and proceeding like
 normal), or whether resources not directly loaded by the HTML parser
 (e.g. loads initiated by scripts or stylesheets) also bypass the
 cache.

3. Let (`event received`, `navigation status`) be
 [await](#awaits) given
 «\"`navigation started`\", \"`navigation failed`\",
 \"`fragment navigated`\"», and `navigation id`.

4. Assert: `navigation status`'s
 [id](#navigation-status-id) is `navigation id`.

5. If `navigation status`'s
 [status](#navigation-status-status) is \"`complete`\":

 1. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.NavigateResult`
 production, with the `navigation` field set to
 `navigation id`, and the `url` field set to the
 result of the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer) given `navigation status`'s
 [url](#navigation-status-url).

 2. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

 this is the case if the navigation only caused the
 fragment to change.

6. If `navigation status`'s
 [status](#navigation-status-status) is \"`canceled`\" return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unknown
 error](https://w3c.github.io/webdriver/#dfn-unknown-error).

 TODO: is this the right way to handle errors here?

7. Assert: `navigation status`'s
 [status](#navigation-status-status) is \"`pending`\" and `navigation id` is
 not null.

8. If `wait condition` is \"`committed`\", let
 `event name` be \"`committed`\".

9. Otherwise, if `wait condition` is \"`interactive`\", let
 `event name` be \"`domContentLoaded`\".

10. Otherwise, let `event name` be \"`load`\".

11. Let (`event received`, `status`) be
 [await](#awaits) given
 «`event name`, \"`download started`\",
 \"`navigation aborted`\", \"`navigation failed`\"» and
 `navigation id`.

12. If `event received` is \"`navigation failed`\" return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unknown
 error](https://w3c.github.io/webdriver/#dfn-unknown-error).

 (#issue-ceba1469) Are we surfacing enough information
 about what failed and why with an error here? What error code do we
 want? Is there going to be a problem where local ends parse the
 implementation-defined strings to figure out what actually went
 wrong?

13. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.NavigateResult`
 production, with the `navigation` field set to `status`'s
 id, and the `url` field set to the result of the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer) given `status`'s url.

14. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

##### 7.3.2.3. The browsingContext.Locator Type

[`remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
browsingContext.Locator = (
 browsingContext.AccessibilityLocator /
 browsingContext.CssLocator /
 browsingContext.ContextLocator /
 browsingContext.InnerTextLocator /
 browsingContext.XPathLocator
)

browsingContext.AccessibilityLocator = {
 type: "accessibility",
 value: {
 ? name: text,
 ? role: text,
 }
}

browsingContext.CssLocator = {
 type: "css",
 value: text
}

browsingContext.ContextLocator = {
 type: "context",
 value: {
 context: browsingContext.BrowsingContext,
 }
}

browsingContext.InnerTextLocator = {
 type: "innerText",
 value: text,
 ? ignoreCase: bool
 ? matchType: "full" / "partial",
 ? maxDepth: js-uint,
}

browsingContext.XPathLocator = {
 type: "xpath",
 value: text
}
```

The `browsingContext.Locator` type provides details on the strategy for
locating a node in a document.

##### 7.3.2.4. The browsingContext.Navigation Type

[`remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
browsingContext.Navigation = text;
```

The `browsingContext.Navigation` type is a unique string identifying an
ongoing navigation.

TODO: Link to the definition in the HTML spec.

##### 7.3.2.5. The browsingContext.NavigationInfo Type

[`local end definition`](#cddl-module-local-end-definition):

```
browsingContext.BaseNavigationInfo = (
 context: browsingContext.BrowsingContext,
 navigation: browsingContext.Navigation / null,
 timestamp: js-uint,
 url: text,
)

browsingContext.NavigationInfo = {
 browsingContext.BaseNavigationInfo
}
```

The `browsingContext.NavigationInfo` type provides details of an ongoing
navigation.

To [get the navigation info], given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and [navigation
status](#webdriver-bidi-navigation-status) `navigation status`:

1. Let `navigable id` be the [navigable
 id](#navigable-id) for
 `navigable`.

2. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

3. Let `timestamp` be a [time
 value](https://tc39.es/ecma262/#sec-time-values-and-time-range) representing the current date and time in UTC.

4. Let `url` be `navigation status`'s
 [url](#navigation-status-url).

5. Return a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.NavigationInfo`
 production, with the `context` field set to
 `navigable id`, the `navigation` field set to
 `navigation id`, the `timestamp` field set to
 `timestamp`, and the `url` field set to the result of the
 [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer) given `url`.

##### 7.3.2.6. The browsingContext.ReadinessState Type

```
browsingContext.ReadinessState = "none" / "interactive" / "complete"
```

The `browsingContext.ReadinessState` type represents the stage of
document loading at which a navigation command will return.

##### 7.3.2.7. The browsingContext.UserPromptType Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
browsingContext.UserPromptType = "alert" / "beforeunload" / "confirm" / "prompt";
```

The `browsingContext.UserPromptType` type represents the possible user
prompt types.

#### 7.3.3. Commands

##### 7.3.3.1. The browsingContext.activate Command

The [browsingContext.activate] command
activates and focuses the given [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable).

Command Type

: ```
 browsingContext.Activate = (
 method: "browsingContext.activate",
 params: browsingContext.ActivateParameters
 )

 browsingContext.ActivateParameters = {
 context: browsingContext.BrowsingContext
 }
 ```

Return Type

: ```
 browsingContext.ActivateResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. Let `navigable id` be the value of the
 `command parameters`\[\"`context`\"\] field.

2. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

3. If `navigable` is not a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

4. Return [activate a
 navigable](#activate-a-navigable) with `navigable`.

To [activate a navigable] given `navigable`:

1. Run implementation-specific steps so that `navigable`'s
 [system visibility
 state](https://html.spec.whatwg.org/multipage/document-sequences.html#system-visibility-state) becomes
 [visible](https://html.spec.whatwg.org/multipage/document-sequences.html#system-visibility-state). If this is not possible
 return
 [error](https://w3c.github.io/webdriver/#errors) with error code [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

 This can have the side effect of making currently
 [visible](https://html.spec.whatwg.org/multipage/document-sequences.html#system-visibility-state)
 [navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables)
 [hidden](https://html.spec.whatwg.org/multipage/document-sequences.html#system-visibility-state).

 This can change the underlying OS state by causing
 the window to become unminimized or by other side effects related to
 changing the [system visibility
 state](https://html.spec.whatwg.org/multipage/document-sequences.html#system-visibility-state).

2. Run implementation-specific steps to set the [system
 focus](https://html.spec.whatwg.org/multipage/interaction.html#system-focus) on the `navigable` if it is not focused.

 This does not change the [focused area of the
 document](https://html.spec.whatwg.org/multipage/interaction.html#focused-area-of-the-document) except as mandated by other specifications.

3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.3.3.2. The browsingContext.captureScreenshot Command

The
[browsingContext.captureScreenshot] command
captures an image of the given navigable, and returns it as a
Base64-encoded string.

Command Type

: ```
 browsingContext.CaptureScreenshot = (
 method: "browsingContext.captureScreenshot",
 params: browsingContext.CaptureScreenshotParameters
 )

 browsingContext.CaptureScreenshotParameters = {
 context: browsingContext.BrowsingContext,
 ? origin: ("viewport" / "document") .default "viewport",
 ? format: browsingContext.ImageFormat,
 ? clip: browsingContext.ClipRectangle,
 }

 browsingContext.ImageFormat = {
 type: text,
 ? quality: 0.0..1.0,
 }

 browsingContext.ClipRectangle = (
 browsingContext.BoxClipRectangle /
 browsingContext.ElementClipRectangle
 )

 browsingContext.ElementClipRectangle = {
 type: "element",
 element: script.SharedReference
 }

 browsingContext.BoxClipRectangle = {
 type: "box",
 x: float,
 y: float,
 width: float,
 height: float
 }
 ```

Return Type

: ```
 browsingContext.CaptureScreenshotResult = {
 data: text
 }
 ```

To [normalize rect] given `rect`:

 This ensures that the resulting rect has positive
[width
dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension) and [height
dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension).

1. Let `x` be `rect`'s [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate).

2. Let `y` be `rect`'s [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate).

3. Let `width` be `rect`'s [width
 dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension).

4. Let `height` be `rect`'s [height
 dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension).

5. If `width` is less than 0, set `x` to
 `x` + `width` and then set `width`
 to -`width`.

6. If `height` is less than 0, set `y` to
 `y` + `height` and then set
 `height` to -`height`.

7. Return a new
 [`DOMRectReadOnly`](https://drafts.csswg.org/geometry/#domrectreadonly) with [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate) `x`, [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate) `y`, [width
 dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension) `width` and [height
 dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension) `height`.

To [rectangle intersection] given `rect1` and
`rect2`

1. Let `rect1` be [normalize
 rect](#normalize-rect) with
 `rect1`.

2. Let `rect2` be [normalize
 rect](#normalize-rect)
 with `rect2`.

3. Let `x1_0` be `rect1`'s [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate).

4. Let `x2_0` be `rect2`'s [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate).

5. Let `x1_1` be `rect1`'s [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate) plus `rect1`'s [width
 dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension).

6. Let `x2_1` be `rect2`'s [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate) plus `rect2`'s [width
 dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension).

7. Let `x_0` be the maximum element of «`x1_0`,
 `x2_0`».

8. Let `x_1` be the minimum element of «`x1_1`,
 `x2_1`».

9. Let `y1_0` be `rect1`'s [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate).

10. Let `y2_0` be `rect2`'s [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate).

11. Let `y1_1` be `rect1`'s [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate) plus `rect1`'s [height
 dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension).

12. Let `y2_1` be `rect2`'s [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate) plus `rect2`'s [height
 dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension).

13. Let `y_0` be the maximum element of «`y1_0`,
 `y2_0`».

14. Let `y_1` be the minimum element of «`y1_1`,
 `y2_1`».

15. If `x_1` is less than `x_0`, let
 `width` be 0. Otherwise let `width` be
 `x_1` - `x_0`.

16. If `y_1` is less than `y_0`, let
 `height` be 0. Otherwise let `height` be
 `y_1` - `y_0`.

17. Return a new
 [`DOMRectReadOnly`](https://drafts.csswg.org/geometry/#domrectreadonly) with [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate) `x_0`, [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate) `y_0`, [width
 dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension) `width` and [height
 dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension) `height`.

To [render document to a canvas] given `document` and
`rect`:

1. Let `ratio` be [determine the device pixel
 ratio](https://drafts.csswg.org/cssom-view-1/#determine-the-device-pixel-ratio) given `document`'s [default
 view](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-defaultview).

2. Let `paint width` be `rect`'s [width
 dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension) multiplied by `ratio`, rounded to the
 nearest integer, so it matches the width of `rect` in
 device pixels.

3. Let `paint height` be `rect`'s [height
 dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension) multiplied by `ratio`, rounded to the
 nearest integer, so it matches the height of `rect` in
 device pixels.

4. Let `canvas` be a new
 [`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement) with
 [`width`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-width) `paint width` and
 [`height`](https://html.spec.whatwg.org/multipage/canvas.html#dom-canvas-height) `paint height`.

5. Let `canvas context` be the result of running the [2D
 context creation
 algorithm](https://html.spec.whatwg.org/multipage/canvas.html#2d-context-creation-algorithm) with `canvas` and null.

6. Set `canvas`'s [context
 mode](https://html.spec.whatwg.org/multipage//canvas.html#offscreencanvas-context-mode) to
 [2D](https://html.spec.whatwg.org/multipage/canvas.html#concept-canvas-2d).

7. Complete implementation specific steps equivalent to drawing the
 region of the framebuffer representing the region of
 `document` covered by `rect` to
 `canvas context`, such that each pixel in the framebuffer
 corresponds to a pixel in `canvas context` with
 (`rect`'s [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate), `rect`'s [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate)) in viewport coordinates corresponding to (0,0) in
 `canvas context` and (`rect`'s [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate) + `rect`'s [width
 dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension), `rect`'s [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate) + `rect`'s [height
 dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension)) corresponding to (`paint width`,
 `paint height`).

8. Return
 [canvas](https://svgwg.org/svg2-draft/coords.html#TermCanvas).

To [encode a canvas as Base64] given `canvas` and
`format`:

1. If `format` is not null, let `type` be the
 `type` field of `format`, and let `quality` be
 the `quality` field of `format`.

2. Otherwise, let `type` be \"image/png\" and let
 `quality` be
 [undefined](https://tc39.es/ecma262/#sec-undefined-value).

3. Let `file` be [a serialization of the bitmap as a
 file](https://html.spec.whatwg.org/multipage/canvas.html#a-serialisation-of-the-bitmap-as-a-file) for `canvas` with `type` and
 `quality`.

4. Let `encoded string` be the [forgiving-base64
 encode](https://infra.spec.whatwg.org/#forgiving-base64-encode) of `file`.

5. Return success with data `encoded string`.

To [get the origin rectangle] given `document` and
`origin`:

1. If `origin` is `"viewport"`:

 1. Let `viewport` be `document`'s [visual
 viewport](https://drafts.csswg.org/cssom-view/#visual-viewport).

 2. Let `viewport rect` be a
 [`DOMRectReadOnly`](https://drafts.csswg.org/geometry/#domrectreadonly) with [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate) `viewport` [page
 left](https://drafts.csswg.org/cssom-view/#dom-visualviewport-pageleft), [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate) `viewport` [page
 top](https://drafts.csswg.org/cssom-view/#dom-visualviewport-pagetop), [width
 dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension) `viewport` width, and [height
 dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension) `viewport` height.

 3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `viewport rect`.

2. Assert: `origin` is `"document"`.

3. Let `document element` be the [document
 element](https://dom.spec.whatwg.org/#ref-for-dom-document-documentelement) for `document`.

4. Let `document rect` be a
 [`DOMRectReadOnly`](https://drafts.csswg.org/geometry/#domrectreadonly) with [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate) 0, [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate) 0, [width
 dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension) `document element` [scroll
 height](https://drafts.csswg.org/cssom-view/#dom-element-scrollheight), and [height
 dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension) `document element` [scroll
 width](https://drafts.csswg.org/cssom-view/#dom-element-scrollwidth).

5. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `document rect`.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `navigable id` be the value of the `context` field of
 `command parameters` if present, or null otherwise.

2. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

3. If the implementation is unable to capture a screenshot of
 `navigable` for any reason then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

4. Let `document` be `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

5. Immediately after the next invocation of the [run the animation
 frame
 callbacks](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#run-the-animation-frame-callbacks) algorithm for `document`:

 (#issue-b2b83ca0) This ought to be integrated into the
 update rendering algorithm in some more explicit way.

6. Let `origin` be the value of the `context` field of
 `command parameters` if present, or \"viewport\"
 otherwise.

7. Let `origin rect` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get the origin
 rectangle](#get-the-origin-rectangle) given `origin` and
 `document`.

8. Let `clip rect` be `origin rect`.

9. If `command parameters` contains \"`clip`\":

 1. Let `clip` be
 `command parameters`\[\"`clip`\"\].

 2. Run the steps under the first matching condition:

 `clip` matches the `browsingContext.ElementClipRectangle` production:

 : 1. Let `environment settings` be the
 [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is `document`.

 2. Let `realm` be
 `environment settings`' [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component.

 3. Let `element` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize remote
 reference](#deserialize-remote-reference) with
 `clip`\[\"`element`\"\], `realm`,
 and `session`.

 4. If `element` doesn't implement
 [`Element`](https://dom.spec.whatwg.org/#element) return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 element](https://w3c.github.io/webdriver/#dfn-no-such-element).

 5. If `element`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document) is not `document`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 element](https://w3c.github.io/webdriver/#dfn-no-such-element).

 6. Let `viewport rect` be [get the origin
 rectangle](#get-the-origin-rectangle) given \"`viewport`\" and
 `document`.

 7. Let `element rect` be [get the bounding
 box](https://drafts.csswg.org/cssom-view-1/#element-get-the-bounding-box) for `element`.

 8. Let `clip rect` be a
 [`DOMRectReadOnly`](https://drafts.csswg.org/geometry/#domrectreadonly) with [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate) `element rect`\[\"`x`\"\] +
 `viewport rect`\[\"`x`\"\], [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate) `element rect`\[\"`y`\"\] +
 `viewport rect`\[\"`y`\"\], width
 `element rect`\[\"`width`\"\], and height
 `element rect`\[\"`height`\"\].

 `clip` matches the `browsingContext.BoxClipRectangle` production:

 : 1. Let `clip x` be `clip`\[\"`x`\"\]
 plus `origin rect`'s [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate).

 2. Let `clip y` be `clip`\[\"`y`\"\]
 plus `origin rect`'s [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate).

 3. Let `clip rect` be a
 [`DOMRectReadOnly`](https://drafts.csswg.org/geometry/#domrectreadonly) with [x
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-x-coordinate) `clip x`, [y
 coordinate](https://drafts.fxtf.org/geometry/#rectangle-y-coordinate) `clip y`, width
 `clip`\[\"`width`\"\], and height
 `clip`\[\"`height`\"\].

10. All coordinates are now measured from the origin of
 the document.

11. Let `rect` be the [rectangle
 intersection](#rectangle-intersection) of `origin rect` and
 `clip rect`.

12. If `rect`'s [width
 dimension](https://drafts.fxtf.org/geometry/#rectangle-width-dimension) is 0 or `rect`'s [height
 dimension](https://drafts.fxtf.org/geometry/#rectangle-height-dimension) is 0, return
 [error](https://w3c.github.io/webdriver/#errors) with error code [unable to capture
 screen](https://w3c.github.io/webdriver/#dfn-unable-to-capture-screen).

13. Let `canvas` be [render document to a
 canvas](#render-document-to-a-canvas) with `document` and `rect`.

14. Let `format` be the `format` field of
 `command parameters`.

15. Let `encoding result` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [encode a canvas as
 Base64](#encode-a-canvas-as-base64) with `canvas` and `format`.

16. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `browsingContext.CaptureScreenshotResult` production, with the
 `data` field set to `encoding result`.

17. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

##### 7.3.3.3. The browsingContext.close Command

The [browsingContext.close] command closes
a [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable).

Command Type

: ```
 browsingContext.Close = (
 method: "browsingContext.close",
 params: browsingContext.CloseParameters
 )

 browsingContext.CloseParameters = {
 context: browsingContext.BrowsingContext,
 ? promptUnload: bool .default false
 }
 ```

Return Type

: ```
 browsingContext.CloseResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. Let `navigable id` be the value of the `context` field of
 `command parameters`.

2. Let `prompt unload` be the value of the `promptUnload`
 field of `command parameters`.

3. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

4. Assert: `navigable` is not null.

5. If `navigable` is not a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

6. If `prompt unload` is true:

 1. [Close](https://html.spec.whatwg.org/multipage/document-sequences.html#close-a-top-level-traversable) `navigable`.

7. Otherwise:

 1. [Close](https://html.spec.whatwg.org/multipage/document-sequences.html#close-a-top-level-traversable) `navigable` without [prompting to
 unload](https://html.spec.whatwg.org/multipage/browsing-the-web.html#prompt-to-unload-a-document).

8. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

There is an open discussion about the
behavior when closing the last [top-level
traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable). We could expect to close the browser, close the
session or leave this up to the implementation. [\[w3c/webdriver-bidi
Issue #170\]](https://github.com/w3c/webdriver-bidi/issues/170)

##### 7.3.3.4. The browsingContext.create Command

The [browsingContext.create] command
creates a new
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables), either in a new tab or in a new window, and returns
its [navigable id](#navigable-id).

Command Type

: ```
 browsingContext.Create = (
 method: "browsingContext.create",
 params: browsingContext.CreateParameters
 )

 browsingContext.CreateType = "tab" / "window"

 browsingContext.CreateParameters = {
 type: browsingContext.CreateType,
 ? referenceContext: browsingContext.BrowsingContext,
 ? background: bool .default false,
 ? userContext: browser.UserContext
 }
 ```

Return Type

: ```
 browsingContext.CreateResult = {
 context: browsingContext.BrowsingContext
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. Let `type` be the value of the `type` field of
 `command parameters`.

2. Let `reference navigable id` be the value of the
 `referenceContext` field of `command parameters`, if
 present, or null otherwise.

3. If `reference navigable id` is not null, let
 `reference navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `reference navigable id`. Otherwise
 let `reference navigable` be null.

4. If `reference navigable` is not null and is not a
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

5. If the implementation is unable to create a new [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) for any reason then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

6. Let `user context` be the [default user
 context](#default-user-context) if `reference navigable` is null, and
 `reference navigable`' [associated user
 context](#associated-user-context) otherwise.

7. Let `user context id` be the value of the `userContext`
 field of `command parameters` if present, or null
 otherwise.

8. If `user context id` is not null, set
 `user context` to the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get user
 context](#get-user-context) with `user context id`.

9. If `user context` is null, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such user
 context](#errors-no-such-user-context).

10. If the implementation is unable to create a new [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) with [associated user
 context](#associated-user-context) `user context` for any reason, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

11. Let `traversable` be the result of trying to [create a
 new top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#creating-a-new-top-level-traversable) steps with null and empty string, and setting the
 [associated user
 context](#associated-user-context) for the newly created [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) to `user context`. Which OS window the
 new [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) is created in depends on `type` and
 `reference navigable`:

 - If `type` is \"`tab`\" and the implementation supports
 multiple [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable)s in the same OS window:

 - The new [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) should reuse an existing OS window, if any.

 - If `reference navigable` is not null, the new
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) should reuse the window containing
 `reference navigable`, if any. If the top-level
 traversables inside an OS window have a definite ordering, the
 new [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) should be immediately after
 `reference navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top) in that ordering.

 - If `type` is \"`window`\", and the implementation
 supports multiple [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) in separate OS windows, the created [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) should be in a new OS window.

 - Otherwise, the details of how the [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) is presented to the user are implementation
 defined.

12. If the value of the `command parameters`' `background`
 field is false:

 1. Let `activate result` be the result of [activate a
 navigable](#activate-a-navigable) with the newly created
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables).

 2. If `activate result` is an
 [error](https://w3c.github.io/webdriver/#errors), return `activate result`.

 Do not invoke the [focusing
 steps](https://html.spec.whatwg.org/multipage/interaction.html#focusing-steps) for the created navigable if `background` is true.

13. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.CreateResult`
 production, with the `context` field set to
 `traversable`'s [navigable
 id](#navigable-id).

14. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

##### 7.3.3.5. The browsingContext.getTree Command

The [browsingContext.getTree] command
returns a tree of all descendent navigables including the given parent
itself, or all top-level contexts when no parent is provided.

Command Type

: ```
 browsingContext.GetTree = (
 method: "browsingContext.getTree",
 params: browsingContext.GetTreeParameters
 )

 browsingContext.GetTreeParameters = {
 ? maxDepth: js-uint,
 ? root: browsingContext.BrowsingContext,
 }
 ```

Return Type

: ```
 browsingContext.GetTreeResult = {
 contexts: browsingContext.InfoList
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `root id` be the value of the `root` field of
 `command parameters` if present, or null otherwise.

2. Let `max depth` be the value of the `maxDepth` field of
 `command parameters` if present, or null otherwise.

3. Let `navigables` be an empty
 [list](https://infra.spec.whatwg.org/#list).

4. If `root id` is not null, append the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) given `root id` to
 `navigables`. Otherwise append all [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top) to `navigables`.

5. Let `navigables infos` be an empty
 [list](https://infra.spec.whatwg.org/#list).

6. For each `navigable` of `navigables`:

 1. Let `info` be the result of [get the navigable
 info](#get-the-navigable-info) given `navigable`,
 `max depth`, and true.

 2. Append `info` to `navigables infos`

7. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.GetTreeResult`
 production, with the `contexts` field set to
 `navigables infos`.

8. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

##### 7.3.3.6. The browsingContext.handleUserPrompt Command

The
[browsingContext.handleUserPrompt] command
allows closing an open prompt

Command Type

: ```
 browsingContext.HandleUserPrompt = (
 method: "browsingContext.handleUserPrompt",
 params: browsingContext.HandleUserPromptParameters
 )

 browsingContext.HandleUserPromptParameters = {
 context: browsingContext.BrowsingContext,
 ? accept: bool,
 ? userText: text,
 }
 ```

Return Type

: ```
 browsingContext.HandleUserPromptResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `navigable id` be the value of the `context` field of
 `command parameters`.

2. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

3. Let `accept` be the value of the `accept` field of
 `command parameters` if present, or true otherwise.

4. Let `userText` be the value of the `userText` field of
 `command parameters` if present, or the empty string
 otherwise.

5. If `navigable` is currently showing a simple dialog from
 a call to
 [alert](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-alert) then acknowledge the prompt.

 Otherwise if `navigable` is currently showing a simple
 dialog from a call to
 [confirm](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-confirm), then respond positively if `accept` is
 true, or respond negatively if `accept` is false.

 Otherwise if `navigable` is currently showing a simple
 dialog from a call to
 [prompt](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-prompt), then respond with the string value
 `userText` if `accept` is true, or abort if
 `accept` is false.

 Otherwise, if `navigable` is currently showing a prompt
 as part of the [prompt to
 unload](https://html.spec.whatwg.org/multipage/browsing-the-web.html#prompt-to-unload-a-document) steps, then confirm the navigation if
 `accept` is true, otherwise refuse the navigation.

 Otherwise return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 alert](https://w3c.github.io/webdriver/#dfn-no-such-alert).

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.3.3.7. The browsingContext.locateNodes Command

The [browsingContext.locateNodes] command
returns a list of all nodes matching the specified locator.

Command Type

: ```
 browsingContext.LocateNodes = (
 method: "browsingContext.locateNodes",
 params: browsingContext.LocateNodesParameters
 )

 browsingContext.LocateNodesParameters = {
 context: browsingContext.BrowsingContext,
 locator: browsingContext.Locator,
 ? maxNodeCount: (js-uint .ge 1),
 ? serializationOptions: script.SerializationOptions,
 ? startNodes: [ + script.SharedReference ]
 }
 ```

Return Type

: ```
 browsingContext.LocateNodesResult = {
 nodes: [ * script.NodeRemoteValue ]
 }
 ```

To [locate nodes using CSS] with given `navigable`,
`context nodes`, `selector`,
`maximum returned node count`, and `session`:

1. Let `returned nodes` be an empty
 [list](https://infra.spec.whatwg.org/#list).

2. Let `parse result` be the result of [parse a
 selector](https://drafts.csswg.org/selectors-4/#parse-a-selector) given `selector`.

3. If `parse result` is failure, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 selector](https://w3c.github.io/webdriver/#dfn-invalid-selector).

4. For each `context node` of `context nodes`:

 1. Let `elements` be the result of [match a selector
 against a
 tree](https://drafts.csswg.org/selectors-4/#match-a-selector-against-a-tree) with `parse result` and
 `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document)
 [root](https://dom.spec.whatwg.org/#concept-tree-root) using [scoping
 root](https://drafts.csswg.org/selectors-4/#scoping-root) `context node`.

 2. For each `element` in `elements`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `element` to
 `returned nodes`.

 2. If `maximum returned node count` is not null and
 [size](https://infra.spec.whatwg.org/#list-size) of `returned nodes` is equal to
 `maximum returned node count`, return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `returned nodes`.

5. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `returned nodes`.

To [locate the container element] given `navigable`:

1. Let `returned nodes` be an empty
 [list](https://infra.spec.whatwg.org/#list).

2. If `navigable`'s
 [container](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-container) is not null, append `navigable`'s
 [container](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-container) to `returned nodes`.

3. Return `returned nodes`.

To [locate nodes using XPath] with given
`navigable`, `context nodes`,
`selector`, and `maximum returned node count`:

 Owing to the unmaintained state of the XPath
specification, this algorithm is phrased as if making calls to the XPath
DOM APIs. However this is to be understood as equivalent to
spec-internal calls directly accessing the underlying algorithms,
without going via the ECMAScript runtime.

1. Let `returned nodes` be an empty
 [list](https://infra.spec.whatwg.org/#list).

2. For each `context node` of `context nodes`:

 1. Let `evaluate result` be the result of calling
 [evaluate](https://dom.spec.whatwg.org/#dom-xpathevaluatorbase-evaluate) on `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document), with arguments `selector`,
 `context node`, null,
 [ORDERED_NODE_SNAPSHOT_TYPE](https://dom.spec.whatwg.org/#dom-xpathresult-ordered_node_snapshot_type), and null. If this throws a
 \"[SyntaxError](https://webidl.spec.whatwg.org/#syntaxerror)\"
 [DOMException](https://webidl.spec.whatwg.org/#idl-DOMException), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 selector](https://w3c.github.io/webdriver/#dfn-invalid-selector); otherwise, if this throws any other exception
 return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unknown
 error](https://w3c.github.io/webdriver/#dfn-unknown-error).

 2. Let `index` be 0.

 3. Let `length` be the result of getting the
 `snapshotLength` property from `evaluate result`.

 4. Repeat, while `index` is less than
 `length`:

 1. Let `node` be the result of calling
 [snapshotItem](https://dom.spec.whatwg.org/#dom-xpathresult-snapshotitem) with `evaluate result` as this
 and `index` as the argument.

 2. [Append](https://infra.spec.whatwg.org/#list-append) `node` to
 `returned nodes`.

 3. If `maximum returned node count` not null and
 [size](https://infra.spec.whatwg.org/#list-size) of `returned nodes` is equal to
 `maximum returned node count`, return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `returned nodes`.

 4. Set `index` to `index` + 1.

3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `returned nodes`.

To [locate nodes using inner text] with given
`context nodes`, `selector`,
`max depth`, `match type`,
`ignore case`, and `maximum returned node count`:

1. If `selector` is the empty string, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 selector](https://w3c.github.io/webdriver/#dfn-invalid-selector).

2. Let `returned nodes` be an empty
 [list](https://infra.spec.whatwg.org/#list).

3. If `ignore case` is false, let `search text`
 be `selector`. Otherwise, let `search text` be
 the result of
 [toUppercase](https://www.unicode.org/versions/Unicode15.0.0/ch03.pdf#G34078) with `selector` according to the
 [Unicode Default Case Conversion
 algorithm](https://www.unicode.org/versions/Unicode15.0.0/ch03.pdf#G34944).

4. For each `context node` in `context nodes`:

 1. If `context node` implements
 [`Document`](https://dom.spec.whatwg.org/#document) or
 [`DocumentFragment`](https://dom.spec.whatwg.org/#documentfragment):

 when traversing the document or document
 fragment, `max depth` is not decreased intentionally to make the
 search result with `document` and `document.documentElement`
 equivalent.

 1. Let `child nodes` be an empty
 [list](https://infra.spec.whatwg.org/#list).

 2. For each node `child` in the
 [children](https://dom.spec.whatwg.org/#concept-tree-child) of `context node`.

 1. [Append](https://infra.spec.whatwg.org/#list-append) `child` to
 `child nodes`.

 3. [Extend](https://infra.spec.whatwg.org/#list-extend) `returned nodes` with the result
 of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [locate nodes using inner
 text](#locate-nodes-using-inner-text) with `child nodes`,
 `selector`, `max depth`,
 `match type`, `ignore case`, and
 `maximum returned node count`.

 2. If `context node` does not implement
 [`HTMLElement`](https://html.spec.whatwg.org/multipage/dom.html#htmlelement) then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. Let `node inner text` be the result of calling the
 [innerText getter
 steps](https://html.spec.whatwg.org/multipage/dom.html#dom-innertext) with `context node` as the
 [this](https://webidl.spec.whatwg.org/#this) value.

 4. If `ignore case` is false, let `node text`
 be `node inner text`. Otherwise, let
 `node text` be the result of
 [toUppercase](https://www.unicode.org/versions/Unicode15.0.0/ch03.pdf#G34078) with `node inner text` according to
 the [Unicode Default Case Conversion
 algorithm](https://www.unicode.org/versions/Unicode15.0.0/ch03.pdf#G34944).

 5. If `search text` is a [code point
 substring](https://infra.spec.whatwg.org/#code-point-substring) of `node text`, perform the
 following steps:

 1. Let `child nodes` be an empty
 [list](https://infra.spec.whatwg.org/#list) and, for each node `child` in
 the
 [children](https://dom.spec.whatwg.org/#concept-tree-child) of `context node`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `child` to
 `child nodes`.

 2. If
 [size](https://infra.spec.whatwg.org/#list-size) of `child nodes` is equal to 0
 or `max depth` is equal to 0, perform the
 following steps:

 1. If `match type` is `"full"` and
 `node text`
 [is](https://infra.spec.whatwg.org/#string-is) `search text`,
 [append](https://infra.spec.whatwg.org/#list-append) `context node` to
 `returned nodes`.

 2. Otherwise, if `match type` is `"partial"`,
 [append](https://infra.spec.whatwg.org/#list-append) `context node` to
 `returned nodes`.

 3. Otherwise, perform the following steps:

 1. Let `child max depth` be null if
 `max depth` is null, or
 `max depth` - 1 otherwise.

 2. Let `child node matches` be the result of
 [locate nodes using inner
 text](#locate-nodes-using-inner-text) with `child nodes`,
 `selector`, `child max depth` ,
 `match type`, `ignore case`, and
 `maximum returned node count`.

 3. If
 [size](https://infra.spec.whatwg.org/#list-size) of `child node matches` is
 equal to 0 and `match type` is `"partial"`,
 append `context node` to
 `returned nodes`. Otherwise,
 [extend](https://infra.spec.whatwg.org/#list-extend) `returned nodes` with
 `child node matches`.

5. If `maximum returned node count` is not null,
 [remove](https://infra.spec.whatwg.org/#list-remove) all entries in `returned nodes` with an
 index greater than or equal to
 `maximum returned node count`.

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `returned nodes`.

To [collect nodes using accessibility
attributes] with given
`context nodes`, `selector`,
`maximum returned node count`, and
`returned nodes`:

1. If `returned nodes` is null:

 1. Set `returned nodes` to an empty
 [list](https://infra.spec.whatwg.org/#list).

2. For each `context node` in `context nodes`:

 1. Let `match` be true.

 2. If `context node` implements
 [`Element`](https://dom.spec.whatwg.org/#element):

 1. If `selector`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`role`\":

 1. Let `role` be the [computed
 role](https://www.w3.org/TR/core-aam-1.2/#roleMappingComputedRole) of `context node`.

 2. If `selector`\[\"`role`\"\] [is
 not](https://infra.spec.whatwg.org/#string-is) `role`:

 1. Set `match` to false.

 2. If `selector`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`name`\":

 1. Let `name` be the [accessible
 name](https://www.w3.org/TR/accname-1.2/#dfn-accessible-name) of `context node`.

 2. If `selector`\[\"`name`\"\] [is
 not](https://infra.spec.whatwg.org/#string-is) `name`:

 1. Set `match` to false.

 3. Otherwise, set `match` to false.

 4. If `match` is true:

 1. If `maximum returned node count` is not null and
 [size](https://infra.spec.whatwg.org/#list-size) of `returned nodes` is equal to
 `maximum returned node count`,
 [break](https://infra.spec.whatwg.org/#iteration-break).

 2. [Append](https://infra.spec.whatwg.org/#list-append) `context node` to
 `returned nodes`.

 5. Let `child nodes` be an empty
 [list](https://infra.spec.whatwg.org/#list) and, for each node `child` in the
 [children](https://dom.spec.whatwg.org/#concept-tree-child) of `context node`:

 1. If `child` implements
 [`Element`](https://dom.spec.whatwg.org/#element),
 [append](https://infra.spec.whatwg.org/#list-append) `child` to
 `child nodes`.

 6. [Try](https://w3c.github.io/webdriver/#dfn-try) to [collect nodes using
 accessibility
 attributes](#collect-nodes-using-accessibility-attributes) with `child nodes`,
 `selector`, `maximum returned node count`,
 and `returned nodes`.

3. Return `returned nodes`.

To [locate nodes using accessibility
attributes] with given
`context nodes`, `selector`, and
`maximum returned node count`:

1. If `selector` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`role`\" and `selector` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`name`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 selector](https://w3c.github.io/webdriver/#dfn-invalid-selector).

2. Return the result of [collect nodes using accessibility
 attributes](#collect-nodes-using-accessibility-attributes) with `context nodes`,
 `selector`, `maximum returned node count`, and
 null.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `navigable id` be
 `command parameters`\[\"`context`\"\].

2. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

3. Assert: `navigable` is not null.

4. Let `realm` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a realm from a
 navigable](#get-a-realm-from-a-navigable) with [navigable
 id](#navigable-id) of
 `navigable` and null.

5. Let `locator` be
 `command parameters`\[\"`locator`\"\].

6. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`startNodes`\", let
 `start nodes parameter` be
 `command parameters`\[\"`startNodes`\"\]. Otherwise let
 `start nodes parameter` be null.

7. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`maxNodeCount`\", let
 `maximum returned node count` be
 `command parameters`\[\"`maxNodeCount`\"\]. Otherwise,
 let `maximum returned node count` be null.

8. Let `context nodes` be an empty
 [list](https://infra.spec.whatwg.org/#list).

9. If `start nodes parameter` is null,
 [append](https://infra.spec.whatwg.org/#list-append) the [document
 element](https://dom.spec.whatwg.org/#ref-for-dom-document-documentelement) of `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document) to `context nodes`. Otherwise, for each
 `serialized start node` in
 `start nodes parameter`:

 1. Let `start node` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize shared
 reference](#deserialize-shared-reference) given `serialized start node`,
 `realm` and `session`.

 2. [Append](https://infra.spec.whatwg.org/#list-append) `start node` to
 `context nodes`.

10. Assert
 [size](https://infra.spec.whatwg.org/#list-size) of `context nodes` is greater than 0.

11. Let `type` be `locator`\[\"`type`\"\].

12. In the following list of conditions and associated steps, run the
 first set of steps for which the associated condition is true:

 `type` is the string \"`css`\"

 : 1. Let `selector` be
 `locator`\[\"`value`\"\].

 2. Let `result nodes` be a result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [locate nodes using
 css](#locate-nodes-using-css) given `navigable`,
 `context nodes`, `selector` and
 `maximum returned nodes`.

 `type` is the string \"`xpath`\"

 : 1. Let `selector` be
 `locator`\[\"`value`\"\].

 2. Let `result nodes` be a result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [locate nodes using
 xpath](#locate-nodes-using-xpath) given `navigable`,
 `context nodes`, `selector` and
 `maximum returned nodes`.

 `type` is the string \"`innerText`\"

 : 1. Let `selector` be
 `locator`\[\"`value`\"\].

 2. If `locator`
 [contains](https://infra.spec.whatwg.org/#map-exists) `maxDepth`, let `max depth` be
 `locator`\[\"`maxDepth`\"\]. Otherwise, let
 `max depth` be null.

 3. If `locator`
 [contains](https://infra.spec.whatwg.org/#map-exists) `ignoreCase`, let `ignore case`
 be `locator`\[\"`ignoreCase`\"\]. Otherwise, let
 `ignore case` be false.

 4. If `locator`
 [contains](https://infra.spec.whatwg.org/#map-exists) `matchType`, let `match type` be
 `locator`\[\"`matchType`\"\]. Otherwise, let
 `match type` be \"full\".

 5. Let `result nodes` be a result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [locate nodes using inner
 text](#locate-nodes-using-inner-text) given `context nodes`,
 `selector`, `max depth`,
 `match type`, `ignore case` and
 `maximum returned node count`.

 `type` is the string \"`accessibility`\"

 : 1. Let `selector` be
 `locator`\[\"`value`\"\].

 2. Let `result nodes` be [locate nodes using
 accessibility
 attributes](#locate-nodes-using-accessibility-attributes) given `context nodes`,
 `selector`, and
 `maximum returned node count`.

 `type` is the string \"`context`\"

 : 1. If `start nodes parameter` is not null, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) \"`invalid argument`\".

 2. Let `selector` be
 `locator`\[\"`value`\"\].

 3. Let `context id` be
 `selector`\[\"`context`\"\].

 4. Let `child navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `context id`.

 5. If `child navigable`'s
 [parent](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-parent) is not `navigable`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) \"`invalid argument`\".

 6. Let `result nodes` be [locate the container
 element](#locate-the-container-element) given `child navigable`.

 7. Assert: For each `node` in
 `result nodes`, `node`'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable) is `navigable`.

13. Assert: `maximum returned node count` is null or
 [size](https://infra.spec.whatwg.org/#list-size) of `result nodes` is less than or equal
 to `maximum returned node count`.

14. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`serializationOptions`\", let
 `serialization options` be
 `command parameters`\[\"`serializationOptions`\"\].
 Otherwise, let `serialization options` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.SerializationOptions`
 production with the fields set to their default values.

15. Let `result ownership` be \"none\".

16. Let `serialized nodes` be an empty
 [list](https://infra.spec.whatwg.org/#list).

17. For each `result node` in `result nodes`:

 1. Let `serialized node` be the result of [serialize as
 a remote
 value](#serialize-as-a-remote-value) with `result node`,
 `serialization options`,
 `result ownership`, a new
 [map](https://infra.spec.whatwg.org/#ordered-map) as serialization internal map,
 `realm` and `session`.

 2. [Append](https://infra.spec.whatwg.org/#list-append) `serialized node` to
 `serialized nodes`.

18. Let `result` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.LocateNodesResult`
 production, with the `nodes` field set
 `serialized nodes`.

19. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `result`.

##### 7.3.3.8. The browsingContext.navigate Command

The [browsingContext.navigate] command
navigates a navigable to the given URL.

Command Type

: ```
 browsingContext.Navigate = (
 method: "browsingContext.navigate",
 params: browsingContext.NavigateParameters
 )

 browsingContext.NavigateParameters = {
 context: browsingContext.BrowsingContext,
 url: text,
 ? wait: browsingContext.ReadinessState,
 }
 ```

Return Type

: ```
 browsingContext.NavigateResult = {
 navigation: browsingContext.Navigation / null,
 url: text,
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `navigable id` be the value of the `context` field of
 `command parameters`.

2. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

3. Assert: `navigable` is not null.

4. Let `wait condition` be \"`committed`\".

5. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) `wait` and
 `command parameters`\[`wait`\] is not \"`none`\", set
 `wait condition` to
 `command parameters`\[`wait`\].

6. Let `url` be the value of the `url` field of
 `command parameters`.

7. Let `document` be `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

8. Let `base` be `document`'s [base
 URL](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script-base-url).

9. Let `url record` be the result of applying the [URL
 parser](https://url.spec.whatwg.org/#concept-url-parser) to `url`, with [base
 URL](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script-base-url) `base`.

10. If `url record` is failure, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

11. Let `request` be a new
 [request](https://fetch.spec.whatwg.org/#concept-request) whose URL is `url record`.

12. Return the result of [await a
 navigation](#await-a-navigation) with `navigable`, `request`
 and `wait condition`.

##### 7.3.3.9. The browsingContext.print Command

The [browsingContext.print] command
creates a paginated representation of a document, and returns it as a
PDF document represented as a Base64-encoded string.

Command Type

: ```
 browsingContext.Print = (
 method: "browsingContext.print",
 params: browsingContext.PrintParameters
 )

 browsingContext.PrintParameters = {
 context: browsingContext.BrowsingContext,
 ? background: bool .default false,
 ? margin: browsingContext.PrintMarginParameters,
 ? orientation: ("portrait" / "landscape") .default "portrait",
 ? page: browsingContext.PrintPageParameters,
 ? pageRanges: [*(js-uint / text)],
 ? scale: (0.1..2.0) .default 1.0,
 ? shrinkToFit: bool .default true,
 }

 browsingContext.PrintMarginParameters = {
 ? bottom: (float .ge 0.0) .default 1.0,
 ? left: (float .ge 0.0) .default 1.0,
 ? right: (float .ge 0.0) .default 1.0,
 ? top: (float .ge 0.0) .default 1.0,
 }

 ; Minimum size is 1pt x 1pt. Conversion follows from
 ; https://www.w3.org/TR/css3-values/#absolute-lengths
 browsingContext.PrintPageParameters = {
 ? height: (float .ge 0.0352) .default 27.94,
 ? width: (float .ge 0.0352) .default 21.59,
 }
 ```

Return Type

: ```
 browsingContext.PrintResult = {
 data: text
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `navigable id` be the value of the `context` field of
 `command parameters`.

2. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

3. If the implementation is unable to provide a paginated
 representation of `navigable` for any reason then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

4. Let `margin` be the value of the `margin` field of
 `command parameters` if present, or otherwise a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `browsingContext.PrintMarginParameters` with the fields set to their
 default values.

5. Let `page size` be the value of the `page` field of
 `command parameters` if present, or otherwise a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.PrintPageParameters`
 with the fields set to their default values.

 The minimum page size is 1 point, which is (2.54 / 72)
cm as per [absolute
lengths](https://drafts.csswg.org/css-values-3/#absolute-lengths).

1. Let `page ranges` be the value of the `pageRanges` field
 of `command parameters` if present or an empty
 [list](https://infra.spec.whatwg.org/#list) otherwise.

2. Let `document` be `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

3. Immediately after the next invocation of the [run the animation
 frame
 callbacks](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#run-the-animation-frame-callbacks) algorithm for `document`:

 (#issue-b2b83ca0①) This ought to be integrated into
 the update rendering algorithm in some more explicit way.

 1. Let `pdf data` be the result taking UA-specific steps
 to generate a paginated representation of `document`,
 with the CSS [media
 type](https://drafts.csswg.org/mediaqueries-4/#media-type) set to `print`, encoded as a PDF, with the
 following paper settings:

 Property

 Value

 Width in cm

 `page size`\[\"`width`\"\] if
 `command parameters`\[\"`orientation`\"\] is
 \"`portrait`\" otherwise `page size`\[\"`height`\"\]

 Height in cm

 `page size`\[\"`height`\"\] if
 `command parameters`\[\"`orientation`\"\] is
 \"`portrait`\" otherwise `page size`\[\"`width`\"\]

 Top margin, in cm

 `margin`\[\"`top`\"\]

 Bottom margin, in cm

 `margin`\[\"`bottom`\"\]

 Left margin, in cm

 `margin`\[\"`left`\"\]

 Right margin, in cm

 `margin`\[\"`right`\"\]

 In addition, the following formatting hints should be applied by
 the UA:

 If `command parameters`\[\"`scale`\"\] is not equal to `1`:
 : Zoom the size of the content by a factor
 `command parameters`\[\"`scale`\"\]

 If `command parameters`\[\"`background`\"\] is false:
 : Suppress output of background images

 If `command parameters`\[\"`shrinkToFit`\"\] is true:
 : Resize the content to match the page width, overriding any
 page width specified in the content

 2. If `page ranges` is not
 [empty](https://infra.spec.whatwg.org/#list-empty), let `pages` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [parse a page
 range](https://w3c.github.io/webdriver/#dfn-parse-a-page-range) with `page ranges` and the number of
 pages contained in `pdf data`, then remove any pages
 from `pdf data` whose one-based index is not
 contained in `pages`.

 3. Let `encoding result` be the result of calling
 [Base64
 Encode](https://datatracker.ietf.org/doc/html/rfc4648#section-4) on `pdf data`.

 4. Let `encoded data` be `encoding result`'s
 data.

 5. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.PrintResult`
 production, with the `data` field set to
 `encoded data`.

 6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

##### 7.3.3.10. The browsingContext.reload Command

The [browsingContext.reload] command
reloads a navigable.

Command Type

: ```
 browsingContext.Reload = (
 method: "browsingContext.reload",
 params: browsingContext.ReloadParameters
 )

 browsingContext.ReloadParameters = {
 context: browsingContext.BrowsingContext,
 ? ignoreCache: bool,
 ? wait: browsingContext.ReadinessState,
 }
 ```

Return Type

: ```
 browsingContext.ReloadResult = browsingContext.NavigateResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. Let `navigable id` be the value of the `context` field of
 `command parameters`.

2. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

3. Assert: `navigable` is not null.

4. Let `ignore cache` be the the value of the `ignoreCache`
 field of `command parameters` if present, or false
 otherwise.

5. Let `wait condition` be \"`committed`\".

6. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) `wait` and
 `command parameters`\[`wait`\] is not \"`none`\", set
 `wait condition` to
 `command parameters`\[`wait`\].

7. Let `document` be `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

8. Let `url` be `document`'s
 [URL](https://dom.spec.whatwg.org/#concept-document-url).

9. Let `request` be a new
 [request](https://fetch.spec.whatwg.org/#concept-request) whose URL is `url`.

10. Return the result of [await a
 navigation](#await-a-navigation) with `navigable`, `request`,
 `wait condition`, history handling \"`reload`\", and
 ignore cache `ignore cache`.

##### 7.3.3.11. The browsingContext.setViewport Command

The [browsingContext.setViewport] command
modifies specific viewport characteristics (e.g. viewport width and
viewport height) on the given top-level traversable.

Command Type

: ```
 browsingContext.SetViewport = (
 method: "browsingContext.setViewport",
 params: browsingContext.SetViewportParameters
 )

 browsingContext.SetViewportParameters = {
 ? context: browsingContext.BrowsingContext,
 ? viewport: browsingContext.Viewport / null,
 ? devicePixelRatio: (float .gt 0.0) / null,
 ? userContexts: [+browser.UserContext],
 }

 browsingContext.Viewport = {
 width: js-uint,
 height: js-uint,
 }
 ```

Return Type

: ```
 browsingContext.SetViewportResult = EmptyResult
 ```

To [set device pixel ratio override] given
`navigable` and `device pixel ratio`:

1. If `device pixel ratio` is not null:

 1. For
 [document](https://dom.spec.whatwg.org/#concept-document) currently loaded in a specified
 `navigable`:

 1. When the [select an image source from a source
 set](https://html.spec.whatwg.org/multipage/images.html#select-an-image-source-from-a-source-set) steps are run, act as if the
 implementation's pixel density was set to
 `device pixel ratio` when selecting an image.

 2. For the purposes of the [resolution media
 feature](https://drafts.csswg.org/mediaqueries-4/#resolution), act as if the implementation's resolution
 is `device pixel ratio` dppx scaled by the page
 zoom.

 2. [Set](https://infra.spec.whatwg.org/#map-set) [device pixel ratio
 overrides](#device-pixel-ratio-overrides)\[`navigable`\] to
 `device pixel ratio`.

 This will take an effect because of the patch
 of [§ 8.3.1 Determine the device pixel
 ratio](#patchs-determine-the-device-pixel-ratio).

2. Otherwise:

 1. For
 [document](https://dom.spec.whatwg.org/#concept-document) currently loaded in a specified
 `navigable`:

 1. When the [select an image source from a source
 set](https://html.spec.whatwg.org/multipage/images.html#select-an-image-source-from-a-source-set) steps are run, use the implementation's
 default behavior, without any changes made by previous
 invocations of these steps.

 2. For the purposes of the [resolution media
 feature](https://drafts.csswg.org/mediaqueries-4/#resolution), use the implementation's default behavior,
 without any changes made by previous invocations of these
 steps.

 2. [Remove](https://infra.spec.whatwg.org/#map-remove) `navigable` from [device pixel ratio
 overrides](#device-pixel-ratio-overrides).

3. Run [evaluate media queries and report
 changes](https://drafts.csswg.org/cssom-view/#evaluate-media-queries-and-report-changes) for
 [document](https://dom.spec.whatwg.org/#concept-document) currently loaded in a specified
 `navigable`.

To [set viewport] given given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and
[viewport](#viewport-configuration-viewport) `viewport`:

1. If `viewport` is not null, set the width of
 `navigable`'s [layout
 viewport](https://drafts.csswg.org/cssom-view/#layout-viewport) to be the `viewport`'s
 [width](#viewport-dimensions-width) in CSS pixels and set the height of the
 `navigable`'s [layout
 viewport](https://drafts.csswg.org/cssom-view/#layout-viewport) to be the `viewport`'s
 [height](#viewport-dimensions-height) in CSS pixels.

2. Otherwise, set the `navigable`'s [layout
 viewport](https://drafts.csswg.org/cssom-view/#layout-viewport) to the implementation-defined default.

After creating a document in a new
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and before the [run WebDriver
BiDi preload
scripts](#run-webdriver-bidi-preload-scripts) algorithm is invoked:

TODO: Move it as a hook in the html spec instead.

1. Let `user context` be `navigable`'s
 [associated user
 context](#associated-user-context).

2. If `navigable` is a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable):

 1. If [geolocation overrides
 map](#geolocation-overrides-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`, [set emulated
 position
 data](https://www.w3.org/TR/geolocation/#dfn-set-emulated-position-data) with `navigable` and [geolocation
 overrides
 map](#geolocation-overrides-map)\[`user context`\].

 2. If [forced colors mode theme overrides
 map](#forced-colors-mode-theme-overrides-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`:

 1. Let `theme` be [forced colors mode theme
 overrides
 map](#forced-colors-mode-theme-overrides-map)\[`user context`\].

 2. [Set emulated forced colors theme
 data](https://drafts.csswg.org/css-color-adjust-1/#set-emulated-forced-colors-theme-data) with `navigable` and
 `theme`.

 3. If [screen orientation overrides
 map](#screen-orientation-overrides-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`, [set emulated screen
 orientation](#set-emulated-screen-orientation) with `navigable` and [screen
 orientation overrides
 map](#screen-orientation-overrides-map)\[`user context`\].

3. If [viewport overrides
 map](#viewport-overrides-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`:

 1. If `navigable` is a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) and [viewport overrides
 map](#viewport-overrides-map)\[`user context`\]\'s
 [viewport](#viewport-configuration-viewport) is not null:

 1. [Set viewport](#set-viewport) with `navigable` and [viewport
 overrides
 map](#viewport-overrides-map)\[`user context`\]\'s
 [viewport](#viewport-configuration-viewport).

 2. If [viewport overrides
 map](#viewport-overrides-map)\[`user context`\]\'s
 [devicePixelRatio](#viewport-configuration-devicepixelratio) is not null:

 1. [Set device pixel ratio
 override](#set-device-pixel-ratio-override) with `navigable` and [viewport
 overrides
 map](#viewport-overrides-map)\[`user context`\]\'s
 [devicePixelRatio](#viewport-configuration-devicepixelratio).

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. If the implementation is unable to adjust the [layout
 viewport](https://drafts.csswg.org/cssom-view/#layout-viewport) parameters with the given
 `command parameters` for any reason, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

2. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`context`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

3. Let `navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

4. If the `context` field of `command parameters` is
 present:

 1. Let `navigable id` be the value of the `context`
 field of `command parameters`.

 2. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

 3. If `navigable` is not a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 4. [Append](https://infra.spec.whatwg.org/#set-append) `navigable` to
 `navigables`.

5. Otherwise, if the `userContexts` field of
 `command parameters` is present:

 1. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 2. For each `user context` of
 `user contexts`:

 1. [Set](https://infra.spec.whatwg.org/#map-set) [viewport overrides
 map](#viewport-overrides-map)\[`user context`\] to a struct.

 2. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`viewport`\":

 1. Set [viewport overrides
 map](#viewport-overrides-map)\[`user context`\]\'s
 [viewport](#viewport-configuration-viewport) to
 `command parameters`\[\"`viewport`\"\].

 3. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`devicePixelRatio`\":

 1. Set [viewport overrides
 map](#viewport-overrides-map)\[`user context`\]\'s
 [devicePixelRatio](#viewport-configuration-devicepixelratio) to
 `command parameters`\[\"`devicePixelRatio`\"\].

 4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `top-level traversable` of the
 list of all [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) whose [associated user
 context](#associated-user-context) is `user context`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `top-level traversable` to
 `navigables`.

6. Otherwise, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

7. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) the `viewport` field:

 1. Let `viewport` be the
 `command parameters`\[\"`viewport`\"\].

 2. For each `navigable` of `navigables`:

 1. [Set viewport](#set-viewport) with `navigable` and
 `viewport`.

 2. Run the [CSSOM View § 13.1 Resizing
 viewports](https://drafts.csswg.org/cssom-view-1/#resizing-viewports)
 steps with `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

8. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) the `devicePixelRatio` field:

 1. Let `device pixel ratio` be the
 `command parameters`\[\"`devicePixelRatio`\"\].

 2. For each `navigable` of `navigables`:

 1. For the `navigable` and all [descendant
 navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#descendant-navigables):

 1. [Set device pixel ratio
 override](#set-device-pixel-ratio-override) with `navigable` and
 `device pixel ratio`.

9. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.3.3.12. The browsingContext.traverseHistory Command

The
[browsingContext.traverseHistory] command
traverses the history of a given navigable by a delta.

Command Type

: ```
 browsingContext.TraverseHistory = (
 method: "browsingContext.traverseHistory",
 params: browsingContext.TraverseHistoryParameters
 )

 browsingContext.TraverseHistoryParameters = {
 context: browsingContext.BrowsingContext,
 delta: js-int,
 }
 ```

Return Type

: ```
 browsingContext.TraverseHistoryResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with
 `command parameters`\[\"`context`\"\].

2. If `navigable` is not a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

3. Assert: `navigable` is not null.

4. Let `delta` be
 `command parameters`\[\"`delta`\"\].

5. Let `resume id` be a unique string.

6. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) on `navigable`'s [session history
 traversal
 queue](https://html.spec.whatwg.org/multipage/document-sequences.html#tn-session-history-traversal-queue) to run the following steps:

 1. Let `all steps` be the result of [getting all used
 history
 steps](https://html.spec.whatwg.org/multipage/browsing-the-web.html#getting-all-used-history-steps) for `navigable`.

 2. Let `current index` be the index of
 `navigable`'s [current session history
 step](https://html.spec.whatwg.org/multipage/document-sequences.html#tn-current-session-history-step) within `all steps`.

 3. Let `target index` be `current index` plus
 `delta`.

 4. Let `valid entry` be false if
 `all steps`\[`target index`\] does not
 exist, or true otherwise.

 5. [Resume](#resume) with
 \"`check history`\", `resume id`, and
 `valid entry`.

7. Let `is valid entry` be [await](#awaits) with «\"`check history`\"», and
 `resume id`.

8. If `is valid entry` is false, return
 [error](https://w3c.github.io/webdriver/#errors) with error code [no such history
 entry](#errors-no-such-history-entry).

9. [Traverse the history by a
 delta](https://html.spec.whatwg.org/multipage/browsing-the-web.html#traverse-the-history-by-a-delta) given `delta` and
 `navigable`.

 (#issue-0ad20a58) There is a race condition in the
 algorithm as written because by the time we try to navigate the
 target session history entry might not exist. Once we support
 waiting for history to navigate we can handle this more robustly.

10. TODO: Support waiting for the history traversal to complete.

11. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `browsingContext.TraverseHistoryResult` production.

12. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

The [WebDriver BiDi page show] steps given `context`
and [navigation
status](#webdriver-bidi-navigation-status) `navigation status` are:

Do we want to expose a
\`browsingContext.pageShow event? In that case we'd need to call this
whenever \`pageshow\` is going to be emitted, not just on bfcache
restore, and also add the persisted status to the data.

1. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

2. [Resume](#resume) with
 \"`page show`\", `navigation id`, and
 `navigation status`.

The [WebDriver BiDi pop state] steps given `context`
and [navigation
status](#webdriver-bidi-navigation-status) `navigation status` are:

1. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

2. [Resume](#resume) with
 \"`pop state`\", `navigation id`, and
 `navigation status`.

#### 7.3.4. Events

##### 7.3.4.1. The browsingContext.contextCreated Event

Event Type

: ```
 browsingContext.ContextCreated = (
 method: "browsingContext.contextCreated",
 params: browsingContext.Info
 )
 ```

To [Recursively emit context created
events] given `session` and
`navigable`:

1. [Emit a context created
 event](#emit-a-context-created-event) with `session` and
 `navigable`.

2. For each child navigable, `child`, of
 `navigable`:

 1. [Recursively emit context created
 events](#recursively-emit-context-created-events) given `session` and
 `child`.

To [Emit a context created event] given `session` and
`navigable`:

1. Let `params` be the result of [get the navigable
 info](#get-the-navigable-info) given `navigable`, 0, and true.

2. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.ContextCreated`
 production, with the `params` field set to `params`.

3. [Emit an event](#emit-an-event) with `session` and `body`.

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi navigable
created] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `opener navigable`:

1. Set `navigable`'s [original
 opener](#original-opener)
 to `opener navigable`, if `opener navigable`
 is provided.

2. If the [navigable cache
 behavior](#navigable-cache-behavior) with `navigable` is \"`bypass`\", then
 perform implementation-defined steps to disable any
 implementation-specific resource caches for network requests
 originating from `navigable`.

3. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

4. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.contextCreated`\" and
 `related navigables`:

 1. [Emit a context created
 event](#emit-a-context-created-event) given `session` and
 `navigable`.

The [remote end subscribe
steps](#event-remote-end-subscribe-steps), with [subscribe
priority](#event-subscribe-priority) 1, given `session`, `navigables`
and `include global` are:

1. For each `navigable` in `navigables`:

 1. [Recursively emit context created
 events](#recursively-emit-context-created-events) given `session` and
 `navigable`.

##### 7.3.4.2. The browsingContext.contextDestroyed Event

Event Type

: ```
 browsingContext.ContextDestroyed = (
 method: "browsingContext.contextDestroyed",
 params: browsingContext.Info
 )
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is:

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi navigable
destroyed] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable`:

1. Let `params` be the result of [get the navigable
 info](#get-the-navigable-info), given `navigable`, null, and true.

2. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.ContextDestroyed`
 production, with the `params` field set to `params`.

3. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`'s
 [parent](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-parent), if that is not null, or an empty
 [set](https://infra.spec.whatwg.org/#ordered-set) otherwise.

4. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.contextDestroyed`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

 2. Let `subscriptions to remove` be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

 3. For each `subscription` in `session`'s
 [subscriptions](#event-subscriptions):

 1. If `subscription`'s [top-level traversable
 ids](#subscription-top-level-traversable-ids)
 [contains](https://infra.spec.whatwg.org/#list-contain) `navigable`'s [navigable
 id](#navigable-id);

 1. [Remove](https://infra.spec.whatwg.org/#list-remove) `navigable`'s [navigable
 id](#navigable-id) from `subscription`'s
 [top-level traversable
 ids](#subscription-top-level-traversable-ids).

 2. If `subscription`'s [top-level traversable
 ids](#subscription-top-level-traversable-ids) is empty:

 1. [Append](https://infra.spec.whatwg.org/#set-append) `subscription` to
 `subscriptions to remove`.

 4. [Remove](https://infra.spec.whatwg.org/#list-remove) `subscriptions to remove` from
 `session`'s
 [subscriptions](#event-subscriptions).

It's unclear if we ought to only fire
this event for browsing contexts that have active documents; navigation
can also cause contexts to become inaccessible but not yet get discarded
because bfcache.

##### 7.3.4.3. The browsingContext.navigationStarted Event

Event Type

: ```
 browsingContext.NavigationStarted = (
 method: "browsingContext.navigationStarted",
 params: browsingContext.NavigationInfo
 )
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi navigation
started] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and [navigation
status](#webdriver-bidi-navigation-status) `navigation status`:

1. Let `params` be the result of [get the navigation
 info](#get-the-navigation-info) given `navigable` and
 `navigation status`.

2. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.NavigationStarted`
 production, with the `params` field set to `params`.

3. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

4. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

5. [Resume](#resume) with
 \"`navigation started`\", `navigation id`, and
 `navigation status`.

6. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.navigationStarted`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.3.4.4. The browsingContext.fragmentNavigated Event

Event Type

: ```
 browsingContext.FragmentNavigated = (
 method: "browsingContext.fragmentNavigated",
 params: browsingContext.NavigationInfo
 )
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi fragment
navigated] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and [navigation
status](#webdriver-bidi-navigation-status) `navigation status`:

1. Let `params` be the result of [get the navigation
 info](#get-the-navigation-info) given `navigable` and
 `navigation status`.

2. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.FragmentNavigated`
 production, with the `params` field set to `params`.

3. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

4. Let `related navigable` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

5. [Resume](#resume) with
 \"`fragment navigated`\", `navigation id`, and
 `navigation status`.

6. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.fragmentNavigated`\" and
 `related navigable`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.3.4.5. The browsingContext.historyUpdated Event

Event Type

: ```
 browsingContext.HistoryUpdated = (
 method: "browsingContext.historyUpdated",
 params: browsingContext.HistoryUpdatedParameters
 )

 browsingContext.HistoryUpdatedParameters = {
 context: browsingContext.BrowsingContext,
 timestamp: js-uint,
 url: text
 }
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi history
updated] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable`:

1. Let `url` be the result of running the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer), given `navigable`'s [active browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-bc)'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document)'s
 [URL](https://dom.spec.whatwg.org/#concept-document-url).

2. Let `timestamp` be a [time
 value](https://tc39.es/ecma262/#sec-time-values-and-time-range) representing the current date and time in UTC.

3. Let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `browsingContext.HistoryUpdatedParameters` production, with the
 `url` field set to `url`, the `timestamp` field set to
 `timestamp` and the `context` field set to
 `navigable`'s [navigable
 id](#navigable-id).

4. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.HistoryUpdated`
 production, with the `params` field set to `params`.

5. Let `related browsing contexts` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`'s [active
 browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-bc).

6. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.historyUpdated`\" and
 `related browsing contexts`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.3.4.6. The browsingContext.domContentLoaded Event

Event Type

: ```
 browsingContext.DomContentLoaded = (
 method: "browsingContext.domContentLoaded",
 params: browsingContext.NavigationInfo
 )
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi DOM content
loaded] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and [navigation
status](#webdriver-bidi-navigation-status) `navigation status`:

1. Let `params` be the result of [get the navigation
 info](#get-the-navigation-info) given `navigable` and
 `navigation status`.

2. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.DomContentLoaded`
 production, with the `params` field set to `params`.

3. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

4. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

5. [Resume](#resume) with
 \"`domContentLoaded`\", `navigation id`, and
 `navigation status`.

6. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.domContentLoaded`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.3.4.7. The browsingContext.load Event

Event Type

: ```
 browsingContext.Load = (
 method: "browsingContext.load",
 params: browsingContext.NavigationInfo
 )
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi load
complete] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and [navigation
status](#webdriver-bidi-navigation-status) `navigation status`:

1. Let `params` be the result of [get the navigation
 info](#get-the-navigation-info) given `navigable` and
 `navigation status`.

2. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.Load` production,
 with the `params` field set to `params`.

3. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

4. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

5. [Resume](#resume) with \"`load`\",
 `navigation id` and `navigation status`.

6. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.load`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.3.4.8. The browsingContext.downloadWillBegin Event

Event Type

: ```
 browsingContext.DownloadWillBegin = (
 method: "browsingContext.downloadWillBegin",
 params: browsingContext.DownloadWillBeginParams
 )

 browsingContext.DownloadWillBeginParams = {
 suggestedFilename: text,
 browsingContext.BaseNavigationInfo
 }
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi download will
begin] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and [navigation
status](#webdriver-bidi-navigation-status) `navigation status`:

1. Let `navigation info` be the result of [get the
 navigation
 info](#get-the-navigation-info) given `navigable` and
 `navigation status`.

2. Let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `browsingContext.DownloadWillBeginParams` production, with the
 `context` field set to
 `navigation info`\[\"`context`\"\], the `navigation`
 field set to `navigation info`\[\"`navigation`\"\], the
 `timestamp` field set to
 `navigation info`\[\"`timestamp`\"\], the `url` field set
 to `navigation info`\[\"`url`\"\] and `suggestedFilename`
 field set to `navigation status`'s
 [suggestedFilename](#navigation-status-suggested-filename).

3. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.DownloadWillBegin`
 production, with the `params` field set to `params`.

4. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

5. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

6. [Resume](#resume) with
 \"`download started`\", `navigation id`, and
 `navigation status`.

7. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.downloadWillBegin`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

8. Let `download behavior` be [get download
 behavior](#get-download-behavior) with `navigable`.

9. Return `download behavior`.

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi download
started] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and [navigation
status](#webdriver-bidi-navigation-status) `navigation status`:

Remove after HTML spec switched to
[WebDriver BiDi download will
begin](#webdriver-bidi-download-will-begin) (https://github.com/whatwg/html/pull/11474).

1. Let `navigation info` be the result of [get the
 navigation
 info](#get-the-navigation-info) given `navigable` and
 `navigation status`.

2. Let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `browsingContext.DownloadWillBeginParams` production, with the
 `context` field set to
 `navigation info`\[\"`context`\"\], the `navigation`
 field set to `navigation info`\[\"`navigation`\"\], the
 `timestamp` field set to
 `navigation info`\[\"`timestamp`\"\], the `url` field set
 to `navigation info`\[\"`url`\"\] and `suggestedFilename`
 field set to `navigation status`'s
 [suggestedFilename](#navigation-status-suggested-filename).

3. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.DownloadWillBegin`
 production, with the `params` field set to `params`.

4. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

5. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

6. [Resume](#resume) with
 \"`download started`\", `navigation id`, and
 `navigation status`.

7. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.downloadWillBegin`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.3.4.9. The browsingContext.downloadEnd Event

Event Type

: ```
 browsingContext.DownloadEnd = (
 method: "browsingContext.downloadEnd",
 params: browsingContext.DownloadEndParams
 )

 browsingContext.DownloadEndParams = {
 (
 browsingContext.DownloadCanceledParams //
 browsingContext.DownloadCompleteParams
 )
 }

 browsingContext.DownloadCanceledParams = (
 status: "canceled",
 browsingContext.BaseNavigationInfo
 )

 browsingContext.DownloadCompleteParams = (
 status: "complete",
 filepath: text / null,
 browsingContext.BaseNavigationInfo
 )
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi download
end] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and [navigation
status](#webdriver-bidi-navigation-status) `navigation status`:

1. Let `navigation info` be the result of [get the
 navigation
 info](#get-the-navigation-info) given `navigable` and
 `navigation status`.

2. Assert `navigation info`\[\"`status`\"\] is equal to
 either \"`complete`\" or \"`canceled`\".

3. If `navigation info`\[\"`status`\"\] is \"`complete`\",
 let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `browsingContext.DownloadCompleteParams` production, with the
 `filepath` field set to `navigation status`'s
 [downloadedFilepath](#navigation-status-downloaded-filepath), the `context` field set to
 `navigation info`\[\"`context`\"\], the `navigation`
 field set to `navigation info`\[\"`navigation`\"\], the
 `timestamp` field set to
 `navigation info`\[\"`timestamp`\"\], and the `url` field
 set to `navigation info`\[\"`url`\"\].

 `filepath` can be null for completed downloads if
 the filepath is not available for whatever reason.

4. Otherwise, let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `browsingContext.DownloadCanceledParams` production, with the
 `context` field set to
 `navigation info`\[\"`context`\"\], the `navigation`
 field set to `navigation info`\[\"`navigation`\"\], the
 `timestamp` field set to
 `navigation info`\[\"`timestamp`\"\], and the `url` field
 set to `navigation info`\[\"`url`\"\].

5. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.DownloadEnd`
 production, with the `params` field set to `params`.

6. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

7. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.downloadEnd`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.3.4.10. The browsingContext.navigationAborted Event

Event Type

: ```
 browsingContext.NavigationAborted = (
 method: "browsingContext.navigationAborted",
 params: browsingContext.NavigationInfo
 )
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi navigation
aborted] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and [navigation
status](#webdriver-bidi-navigation-status) `navigation status`:

1. Let `params` be the result of [get the navigation
 info](#get-the-navigation-info) given `navigable` and
 `navigation status`.

2. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.NavigationAborted`
 production, with the `params` field set to `params`.

3. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

4. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

5. [Resume](#resume) with
 \"`navigation aborted`\", `navigation id`, and
 `navigation status`.

6. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.navigationAborted`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.3.4.11. The browsingContext.navigationCommitted Event

Event Type

: ```
 browsingContext.NavigationCommitted = (
 method: "browsingContext.navigationCommitted",
 params: browsingContext.NavigationInfo
 )
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi navigation
committed] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and [navigation
status](#webdriver-bidi-navigation-status) `navigation status`:

1. Let `params` be the result of [get the navigation
 info](#get-the-navigation-info) given `navigable` and
 `navigation status`.

2. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.NavigationCommitted`
 production, with the `params` field set to `params`.

3. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

4. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

5. [Resume](#resume) with
 \"`navigation committed`\", `navigation id`, and
 `navigation status`.

6. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.navigationCommitted`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.3.4.12. The browsingContext.navigationFailed Event

Event Type

: ```
 browsingContext.NavigationFailed = (
 method: "browsingContext.navigationFailed",
 params: browsingContext.NavigationInfo
 )
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi navigation
failed] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable` and [navigation
status](#webdriver-bidi-navigation-status) `navigation status`:

1. Let `params` be the result of [get the navigation
 info](#get-the-navigation-info) given `navigable` and
 `navigation status`.

2. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.NavigationFailed`
 production, with the `params` field set to `params`.

3. Let `navigation id` be `navigation status`'s
 [id](#navigation-status-id).

4. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

5. [Resume](#resume) with
 \"`navigation failed`\", `navigation id`, and
 `navigation status`.

6. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.navigationFailed`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.3.4.13. The browsingContext.userPromptClosed Event

Event Type

: ```
 browsingContext.UserPromptClosed = (
 method: "browsingContext.userPromptClosed",
 params: browsingContext.UserPromptClosedParameters
 )

 browsingContext.UserPromptClosedParameters = {
 context: browsingContext.BrowsingContext,
 accepted: bool,
 type: browsingContext.UserPromptType,
 ? userText: text
 }
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi user prompt
closed] steps given
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) `window`, string `type`, boolean
`accepted` and optional text `user text` (default:
null).

1. Let `navigable` be `window`'s
 [navigable](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-navigable).

2. Let `navigable id` be the [navigable
 id](#navigable-id) for
 `navigable`.

3. Let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `browsingContext.UserPromptClosedParameters` production with the
 `context` field set to `navigable id`, the `accepted`
 field set to `accepted`, the `type` field set to
 `type`, and the `userText` field set to
 `user text` if `user text` is not null or
 omitted otherwise.

4. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `BrowsingContextUserPromptClosedEvent`
 production, with the `params` field set to `params`.

5. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

6. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.userPromptClosed`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.3.4.14. The browsingContext.userPromptOpened Event

Event Type

: ```
 browsingContext.UserPromptOpened = (
 method: "browsingContext.userPromptOpened",
 params: browsingContext.UserPromptOpenedParameters
 )

 browsingContext.UserPromptOpenedParameters = {
 context: browsingContext.BrowsingContext,
 handler: session.UserPromptHandlerType,
 message: text,
 type: browsingContext.UserPromptType,
 ? defaultValue: text
 }
 ```

To [get navigable's user prompt
handler] given `type` and
`navigable`:

1. Let `user context` be `navigable`'s
 [associated user
 context](#associated-user-context).

2. If [unhandled prompt behavior overrides
 map](#unhandled-prompt-behavior-overrides-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`:

 1. Let `unhandled prompt behavior override` be
 [unhandled prompt behavior overrides
 map](#unhandled-prompt-behavior-overrides-map)\[`user context`\].

 2. If
 `unhandled prompt behavior override`\[`type`\]
 is not null, return
 `unhandled prompt behavior override`\[`type`\].

 3. If
 `unhandled prompt behavior override`\[`"default"`\]
 is not null, return
 `unhandled prompt behavior override`\[`"default"`\].

3. Let `handler configuration` be [get the prompt
 handler](https://w3c.github.io/webdriver/#dfn-get-the-prompt-handler) with `type`.

4. Return `handler configuration`'s
 [handler](https://w3c.github.io/webdriver/#dfn-handler).

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi user prompt
opened] steps given
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) `window`, string `type`, string
`message`, and optional text `default value`
(default: null).

1. Let `navigable` be `window`'s
 [navigable](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-navigable).

2. Let `navigable id` be the [navigable
 id](#navigable-id) for
 `navigable`.

3. Let `handler` be [get navigable's user prompt
 handler](#get-navigables-user-prompt-handler) with `type` and `navigable`.

4. Let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `browsingContext.UserPromptOpenedParameters` production with the
 `context` field set to `navigable id`, the `type` field
 set to `type`, the `message` field set to
 `message`, the `defaultValue` field set to
 `default value` if `default value` is not null
 or omitted otherwise, and the `handler` field set to
 `handler`.

5. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `browsingContext.UserPromptOpened`
 production, with the `params` field set to `params`.

6. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

7. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`browsingContext.userPromptOpened`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

8. If `handler` is \"`ignore`\", set handler to \"`none`\".

9. Return `handler`.

### 7.4. The emulation Module

The [emulation] module contains commands and events relating
to emulation of browser APIs.

#### 7.4.1. Definition

[`remote end definition`](#cddl-module-remote-end-definition)

```
EmulationCommand = (
 emulation.SetForcedColorsModeThemeOverride //
 emulation.SetGeolocationOverride //
 emulation.SetLocaleOverride //
 emulation.SetNetworkConditions //
 emulation.SetScreenOrientationOverride //
 emulation.SetScreenSettingsOverride //
 emulation.SetScriptingEnabled //
 emulation.SetTimezoneOverride //
 emulation.SetTouchOverride //
 emulation.SetUserAgentOverride
)
```

```
EmulationResult = (
 emulation.SetForcedColorsModeThemeOverrideResult /
 emulation.SetGeolocationOverrideResult /
 emulation.SetLocaleOverrideResult /
 emulation.SetScreenOrientationOverrideResult /
 emulation.SetScriptingEnabledResult /
 emulation.SetTimezoneOverrideResult /
 emulation.SetTouchOverrideResult /
 emulation.SetUserAgentOverrideResult
)
```

A [BiDi session](#bidi-session)
has an [emulated user agent] which is a
[struct](https://infra.spec.whatwg.org/#struct) with an
[item](https://infra.spec.whatwg.org/#struct-item) named [default user
agent], which is a
string or null, an
[item](https://infra.spec.whatwg.org/#struct-item) named [user context user
agent], which is a
weak map between [user contexts](#user-context) and string, and an
[item](https://infra.spec.whatwg.org/#struct-item) named [navigable user
agent], which is a
weak map between
[navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) and string.

A [BiDi session](#bidi-session)
has [emulated maxTouchPoints], which is a
[struct](https://infra.spec.whatwg.org/#struct) with an
[item](https://infra.spec.whatwg.org/#struct-item) named [default], which is an integer or null, initially null; an
[item](https://infra.spec.whatwg.org/#struct-item) named [user
contexts], which is
a weak map between [user
contexts](#user-context) and
integer, initially empty; and an
[item](https://infra.spec.whatwg.org/#struct-item) named [navigables], which is a weak map between
[navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) and integer, initially empty.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [forced colors mode theme overrides
map] which is a weak map between [user
contexts](#user-context) and
string or null.

A [geolocation override] is a
[struct](https://infra.spec.whatwg.org/#struct) with:

- [item](https://infra.spec.whatwg.org/#struct-item) named [`latitude`] which is a float;

- [item](https://infra.spec.whatwg.org/#struct-item) named
 [`longitude`] which is a float;

- [item](https://infra.spec.whatwg.org/#struct-item) named [`accuracy`] which is a float;

- [item](https://infra.spec.whatwg.org/#struct-item) named [`altitude`] which is a float or null;

- [item](https://infra.spec.whatwg.org/#struct-item) named
 [`altitudeAccuracy`] which is a float or null;

- [item](https://infra.spec.whatwg.org/#struct-item) named [`heading`] which is a float or null;

- [item](https://infra.spec.whatwg.org/#struct-item) named [`speed`] which is a float or null.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [geolocation overrides
map] which is a weak map between [user
contexts](#user-context) and
[geolocation
override](#geolocation-override).

A [screen orientation override] is a
[struct](https://infra.spec.whatwg.org/#struct) with:

- [item](https://infra.spec.whatwg.org/#struct-item) named
 [`natural`] which is a string;

- [item](https://infra.spec.whatwg.org/#struct-item) named [`type`] which is a string;

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [screen orientation overrides
map] which is a weak map between [user
contexts](#user-context) and
[screen orientation
override](#screen-orientation-override).

#### 7.4.2. Commands

##### 7.4.2.1. The emulation.setForcedColorsModeThemeOverride Command

The
[emulation.setForcedColorsModeThemeOverride] command
modifies [forced colors
mode](https://drafts.csswg.org/css-color-adjust-1/#forced-colors-mode) theming characteristics on the given top-level
traversables or user contexts.

Command Type

: ```
 emulation.SetForcedColorsModeThemeOverride = (
 method: "emulation.setForcedColorsModeThemeOverride",
 params: emulation.SetForcedColorsModeThemeOverrideParameters
 )

 emulation.SetForcedColorsModeThemeOverrideParameters = {
 theme: emulation.ForcedColorsModeTheme / null,
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 }

 emulation.ForcedColorsModeTheme = "light" / "dark"
 ```

Return Type

: ```
 emulation.SetForcedColorsModeThemeOverrideResult = EmptyResult
 ```

 Check out the
[`ForcedColorsModeAutomationTheme`](https://drafts.csswg.org/css-color-adjust-1/#enumdef-forcedcolorsmodeautomationtheme) for the corresponding enum mapping in the CSS
specification.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. If `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

3. Let `theme` be
 `command parameters`\[\"`theme`\"\].

4. If `theme` is null, set `theme` to \"`none`\".

5. Let `navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

6. If the `contexts` field of `command parameters` is
 present:

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid top-level traversables by
 ids](#get-valid-top-level-traversables-by-ids) with
 `command parameters`\[\"`contexts`\"\].

7. Otherwise:

 1. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 2. For each `user context` of
 `user contexts`:

 1. [Set](https://infra.spec.whatwg.org/#map-set) [forced colors mode theme overrides
 map](#forced-colors-mode-theme-overrides-map)\[`user context`\] to
 `theme`.

 2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `top-level traversable` of the
 list of all [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) whose [associated user
 context](#associated-user-context) is `user context`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `top-level traversable` to
 `navigables`.

8. For each `navigable` of `navigables`:

 1. [Set emulated forced colors theme
 data](https://drafts.csswg.org/css-color-adjust-1/#set-emulated-forced-colors-theme-data) with `navigable` and
 `theme`.

9. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.4.2.2. The emulation.setGeolocationOverride Command

The
[emulation.setGeolocationOverride] command
modifies geolocation characteristics on the given top-level traversables
or user contexts.

Command Type

: ```
 emulation.SetGeolocationOverride = (
 method: "emulation.setGeolocationOverride",
 params: emulation.SetGeolocationOverrideParameters
 )

 emulation.SetGeolocationOverrideParameters = {
 (
 (coordinates: emulation.GeolocationCoordinates / null) //
 (error: emulation.GeolocationPositionError)
 ),
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 }

 emulation.GeolocationCoordinates = {
 latitude: -90.0..90.0,
 longitude: -180.0..180.0,
 ? accuracy: (float .ge 0.0) .default 1.0,
 ? altitude: float / null .default null,
 ? altitudeAccuracy: (float .ge 0.0) / null .default null,
 ? heading: (0.0...360.0) / null .default null,
 ? speed: (float .ge 0.0) / null .default null,
 }

 emulation.GeolocationPositionError = {
 type: "positionUnavailable"
 }
 ```

Return Type

: ```
 emulation.SetGeolocationOverrideResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`coordinates`\" and
 `command parameters`\[\"`coordinates`\"\]
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`altitudeAccuracy`\" and
 `command parameters`\[\"`coordinates`\"\] doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`altitude`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`error`\":

 1. Assert
 `command parameters`\[\"`error`\"\]\[\"`type`\"\]
 equals \"`positionUnavailable`\".

 2. Let `emulated position data` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching
 [GeolocationPositionError](https://www.w3.org/TR/geolocation/#dom-geolocationpositionerror) production, with `code` field set to
 [POSITION_UNAVAILABLE](https://www.w3.org/TR/geolocation/#dom-geolocationpositionerror-position_unavailable) and `message` field set to the empty string.

 `message` will be ignored by implementation
 according to the geolocation spec.

3. Otherwise, let `emulated position data` be
 `command parameters`\[\"`coordinates`\"\].

4. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

5. If `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

6. Let `navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

7. If the `contexts` field of `command parameters` is
 present:

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid top-level traversables by
 ids](#get-valid-top-level-traversables-by-ids) with
 `command parameters`\[\"`contexts`\"\].

8. Otherwise, if the `userContexts` field of
 `command parameters` is present:

 1. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 2. For each `user context` of
 `user contexts`:

 1. If `emulated position data` is null, remove the
 `user context` from [geolocation overrides
 map](#geolocation-overrides-map).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) [geolocation overrides
 map](#geolocation-overrides-map)\[`user context`\] to
 `emulated position data`.

 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `top-level traversable` of the
 list of all [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) whose [associated user
 context](#associated-user-context) is `user context`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `top-level traversable` to
 `navigables`.

9. For each `navigable` of `navigables`:

 1. Let `user context` be `navigable`'s
 [associated user
 context](#associated-user-context).

 2. If `emulated position data` is null and [geolocation
 overrides
 map](#geolocation-overrides-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`, [set emulated
 position
 data](https://www.w3.org/TR/geolocation/#dfn-set-emulated-position-data) with `navigable` and [geolocation
 overrides
 map](#geolocation-overrides-map)\[`user context`\].

 3. Otherwise, [set emulated position
 data](https://www.w3.org/TR/geolocation/#dfn-set-emulated-position-data) with `navigable` and
 `emulated position data`.

10. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.4.2.3. The emulation.setLocaleOverride Command

The [emulation.setLocaleOverride] command
modifies locale on the given top-level traversables or user contexts.

Command Type

: ```
 emulation.SetLocaleOverride = (
 method: "emulation.setLocaleOverride",
 params: emulation.SetLocaleOverrideParameters
 )

 emulation.SetLocaleOverrideParameters = {
 locale: text / null,
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 }
 ```

Return Type

: ```
 emulation.SetLocaleOverrideResult = EmptyResult
 ```

The [WebDriver BiDi emulated language] steps given an [environment
settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) `environment settings`:

1. Let `related navigables` be the result of [get related
 navigables](#get-related-navigables) given `environment settings`.

2. For each `navigable` of `related navigables`:

 1. Let `top-level traversable` be
 `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

 2. Let `user context` be
 `top-level traversable`'s [associated user
 context](#associated-user-context).

 3. If [locale overrides
 map](#locale-overrides-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `top-level traversable`, return
 [locale overrides
 map](#locale-overrides-map)\[`top-level traversable`\].

 4. If [locale overrides
 map](#locale-overrides-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`, return [locale
 overrides
 map](#locale-overrides-map)\[`user context`\].

3. Return null

TODO: Remove the following algorithm once the update for
navigator.language/s in the html spec is merged.
https://github.com/whatwg/html/pull/11793

[DefaultLocale](https://tc39.es/ecma402/#sec-defaultlocale) algorithm is implementation defined. A WebDriver-BiDi
[remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) must have an implementation that runs the following
steps:

1. Let `realm` be [current Realm
 Record](https://tc39.es/ecma262/#current-realm).

2. Let `environment settings` be the [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component is `realm`.

3. Let `locale override` be the result of [WebDriver BiDi
 emulated
 language](#webdriver-bidi-emulated-language) with `environment settings`.

4. If `locale override` is not null, return
 `locale override`. Otherwise, return the result of
 implementation-defined steps in accordance with the requirements of
 the
 [DefaultLocale](https://tc39.es/ecma402/#sec-defaultlocale) specification.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. If `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

3. Let `emulated locale` be
 `command parameters`\[\"`locale`\"\].

4. If `emulated locale` is not null and
 [IsStructurallyValidLanguageTag](https://tc39.es/ecma402/#sec-isstructurallyvalidlanguagetag)(`emulated locale`) returns false, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

5. Let `navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

6. If the `contexts` field of `command parameters` is
 present:

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid top-level traversables by
 ids](#get-valid-top-level-traversables-by-ids) with
 `command parameters`\[\"`contexts`\"\].

7. Otherwise:

 1. Assert the `userContexts` field of
 `command parameters` is present.

 2. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 3. For each `user context` of
 `user contexts`:

 1. If `emulated locale` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `user context` from [locale
 overrides
 map](#locale-overrides-map).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) [locale overrides
 map](#locale-overrides-map)\[`user context`\] to
 `emulated locale`.

 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `top-level traversable` of the
 list of all [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) whose [associated user
 context](#associated-user-context) is `user context`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `top-level traversable` to
 `navigables`.

8. For each `navigable` of `navigables`:

 1. If `emulated locale` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `navigable` from [locale overrides
 map](#locale-overrides-map).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) [locale overrides
 map](#locale-overrides-map)\[`navigable`\] to
 `emulated locale`.

9. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.4.2.4. The emulation.setNetworkConditions Command

The
[emulation.setNetworkConditions] command
emulates specific network conditions for the given browsing context or
for a user context.

Command Type

: ```
 emulation.SetNetworkConditions = (
 method: "emulation.setNetworkConditions",
 params: emulation.setNetworkConditionsParameters
 )

 emulation.setNetworkConditionsParameters = {
 networkConditions: emulation.NetworkConditions / null,
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 }

 emulation.NetworkConditions = emulation.NetworkConditionsOffline

 emulation.NetworkConditionsOffline = {
 type: "offline"
 }
 ```

Return Type

: ```
 emulation.SetNetworkConditionsResult = EmptyResult
 ```

To [apply network conditions]:

1. For each
 [WebSocket](https://websockets.spec.whatwg.org/#websocket) object `webSocket`:

 1. Let `realm` be `webSocket`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

 2. Let `environment settings` be the [environment
 settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component is `realm`.

 3. If the result of [WebDriver BiDi network is
 offline](#webdriver-bidi-network-is-offline) with `environment settings` is true:

 1. [Fail the WebSocket
 connection](https://datatracker.ietf.org/doc/html/rfc6455#section-7.1.7) `webSocket`.

2. For each
 [WebTransport](https://html.spec.whatwg.org/multipage/nav-history-apis.html#blocking-webtransport) object `webTransport`:

 1. Let `realm` be `webSocket`'s [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

 2. Let `environment settings` be the [environment
 settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component is `realm`.

 3. If the result of [WebDriver BiDi network is
 offline](#webdriver-bidi-network-is-offline) with `environment settings` is true:

 1. [Cleanup
 WebTransport](https://w3c.github.io/webtransport/#webtransport-cleanup) `webTransport`.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` and
`session` are:

1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`context`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. Let `emulated network conditions` be null.

3. If `command parameters`\[\"`networkConditions`\"\] is not
 null and
 `command parameters`\[\"`networkConditions`\"\]\[\"`type`\"\]
 equals \"`offline`\", set `emulated network conditions`
 to a new [emulated network conditions
 struct](#emulated-network-conditions-struct) with
 [offline](#emulated-network-conditions-struct-offline) set to true.

4. If the `contexts` field of `command parameters` is
 present:

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid top-level traversables by
 ids](#get-valid-top-level-traversables-by-ids) with
 `command parameters`\[\"`contexts`\"\].

 2. For each `navigable` of `navigables`:

 1. If `emulated network conditions` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `navigable` from
 `session`'s [emulated network
 conditions](#session-emulated-network-conditions)'s [navigable network
 conditions](#emulated-network-conditions-navigable-network-conditions)

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) `session`'s [emulated network
 conditions](#session-emulated-network-conditions)'s [navigable network
 conditions](#emulated-network-conditions-navigable-network-conditions)\[`navigable`\] to
 `emulated network conditions`.

5. If the `userContexts` field of `command parameters` is
 present:

 1. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 2. For each `user context` of
 `user contexts`:

 1. If `emulated network conditions` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `user context` from
 `session`'s [emulated network
 conditions](#session-emulated-network-conditions)'s [user context network
 conditions](#emulated-network-conditions-user-context-network-conditions).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) `session`'s [emulated network
 conditions](#session-emulated-network-conditions)'s [user context network
 conditions](#emulated-network-conditions-user-context-network-conditions)\[`user context`\] to
 `emulated network conditions`.

6. If `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`context`\",
 [set](https://infra.spec.whatwg.org/#map-set) `session`'s [emulated network
 conditions](#session-emulated-network-conditions)'s [default network
 conditions](#emulated-network-conditions-default-network-conditions) to `emulated network conditions`.

7. [Apply network
 conditions](#apply-network-conditions).

8. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.4.2.5. The emulation.setScreenSettingsOverride Command

The
[emulation.setScreenSettingsOverride] command
emulates [web-exposed screen
area](https://drafts.csswg.org/cssom-view/#web-exposed-screen-area) and [web-exposed available screen
area](https://drafts.csswg.org/cssom-view/#web-exposed-available-screen-area) of the given top-level traversables or user contexts.

Command Type

: ```
 emulation.SetScreenSettingsOverride = (
 method: "emulation.setScreenSettingsOverride",
 params: emulation.SetScreenSettingsOverrideParameters
 )

 emulation.ScreenArea = {
 width: js-uint,
 height: js-uint
 }

 emulation.SetScreenSettingsOverrideParameters = {
 screenArea: emulation.ScreenArea / null,
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 }
 ```

Return Type

: ```
 emulation.SetScreenSettingsOverrideResult = EmptyResult
 ```

The [WebDriver BiDi emulated available screen
area] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable`:

1. Let `top-level traversable` be `navigable`'s
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

2. Let `user context` be
 `top-level traversable`'s [associated user
 context](#associated-user-context).

3. If [screen settings
 overrides](#screen-settings-overrides)
 [contains](https://infra.spec.whatwg.org/#map-exists) `top-level traversable`, return [screen
 settings
 overrides](#screen-settings-overrides)\[`top-level traversable`\].

4. If [screen settings
 overrides](#screen-settings-overrides)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`, return [screen settings
 overrides](#screen-settings-overrides)\[`user context`\].

5. Return null

The [WebDriver BiDi emulated total screen
area] steps given
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) `navigable`:

1. Let `top-level traversable` be `navigable`'s
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

2. Let `user context` be
 `top-level traversable`'s [associated user
 context](#associated-user-context).

3. If [screen settings
 overrides](#screen-settings-overrides)
 [contains](https://infra.spec.whatwg.org/#map-exists) `top-level traversable`, return [screen
 settings
 overrides](#screen-settings-overrides)\[`top-level traversable`\].

4. If [screen settings
 overrides](#screen-settings-overrides)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`, return [screen settings
 overrides](#screen-settings-overrides)\[`user context`\].

5. Return null

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. If `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

3. Let `emulated screen area` be
 `command parameters`\[\"`screenArea`\"\].

4. If `emulated screen area` is not null:

 1. [Set](https://infra.spec.whatwg.org/#map-set) `emulated screen area`\[\"`x`\"\] to
 0.

 2. [Set](https://infra.spec.whatwg.org/#map-set) `emulated screen area`\[\"`y`\"\] to
 0.

5. Let `navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

6. If the `contexts` field of `command parameters` is
 present:

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid top-level traversables by
 ids](#get-valid-top-level-traversables-by-ids) with
 `command parameters`\[\"`contexts`\"\].

 2. Let `target` be [navigable screen
 settings](#screen-settings-overrides-navigable-screen-settings).

 3. For each `navigable` of `navigables`:

 1. If `emulated screen area` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `navigable` from
 `target`.

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set)
 `target`\[`navigable`\] to
 `emulated screen area`.

 4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

7. Otherwise:

 1. Assert the `userContexts` field of
 `command parameters` is present.

 2. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 3. Let `target` be [user context screen
 settings](#screen-settings-overrides-user-context-screen-settings).

 4. For each `user context` of
 `user contexts`:

 1. If `emulated screen area` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `user context` from
 `target`.

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set)
 `target`\[`user context`\] to
 `emulated screen area`.

 5. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.4.2.6. The emulation.setScreenOrientationOverride Command

The
[emulation.setScreenOrientationOverride] command
emulates [screen
orientation](https://www.w3.org/TR/screen-orientation#dom-screenorientation) of the given top-level traversables or user contexts.

Command Type

: ```
 emulation.SetScreenOrientationOverride = (
 method: "emulation.setScreenOrientationOverride",
 params: emulation.SetScreenOrientationOverrideParameters
 )

 emulation.ScreenOrientationNatural = "portrait" / "landscape"
 emulation.ScreenOrientationType = "portrait-primary" / "portrait-secondary" / "landscape-primary" / "landscape-secondary"

 emulation.ScreenOrientation = {
 natural: emulation.ScreenOrientationNatural,
 type: emulation.ScreenOrientationType
 }

 emulation.SetScreenOrientationOverrideParameters = {
 screenOrientation: emulation.ScreenOrientation / null,
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 }
 ```

Return Type

: ```
 emulation.SetScreenOrientationOverrideResult = EmptyResult
 ```

To [set emulated screen orientation] given
`navigable` and `emulated screen orientation`:

Move this algorithm to screen
orientation specification.

1. If `emulated screen orientation` is null:

 1. Set `navigable`'s [current orientation
 angle](https://www.w3.org/TR/screen-orientation#dfn-current-orientation-angle) to implementation-defined default.

 2. Set `navigable`'s [current orientation
 type](https://www.w3.org/TR/screen-orientation#dfn-current-orientation-type) to implementation-defined default.

2. Otherwise:

 1. Let `emulated orientation type` be
 `emulated screen orientation`\[\"`type`\"\].

 2. Let `emulated orientation angle` be the angle
 associated with `emulated orientation type` for
 screens with
 `emulated screen orientation`\[\"`natural`\"\]
 orientations as defined in [screen orientation values
 lists](https://www.w3.org/TR/screen-orientation#dfn-screen-orientation-values-lists).

 3. Set [current orientation
 angle](https://www.w3.org/TR/screen-orientation#dfn-current-orientation-angle) to `emulated orientation angle`.

 4. Set [current orientation
 type](https://www.w3.org/TR/screen-orientation#dfn-current-orientation-type) to `emulated orientation type`.

3. Run the [screen orientation change
 steps](https://www.w3.org/TR/screen-orientation#dfn-screen-orientation-change-steps) with the `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. If the implementation is unable to adjust the [screen
 orientations](https://www.w3.org/TR/screen-orientation#dom-screenorientation) parameters with the given
 `command parameters` for any reason, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

2. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

3. If `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

4. Let `emulated screen orientation` be
 `command parameters`\[\"`screenOrientation`\"\].

5. Let `navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

6. If the `contexts` field of `command parameters` is
 present:

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid top-level traversables by
 ids](#get-valid-top-level-traversables-by-ids) with
 `command parameters`\[\"`contexts`\"\].

7. Otherwise, if the `userContexts` field of
 `command parameters` is present:

 1. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 2. For each `user context` of
 `user contexts`:

 1. If `emulated screen orientation` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `user context` from [screen
 orientation overrides
 map](#screen-orientation-overrides-map).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) [screen orientation overrides
 map](#screen-orientation-overrides-map)\[`user context`\] to
 `emulated screen orientation`.

 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `top-level traversable` of the
 list of all [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) whose [associated user
 context](#associated-user-context) is `user context`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `top-level traversable` to
 `navigables`.

8. For each `navigable` of `navigables`:

 1. Let `user context` be `navigable`'s
 [associated user
 context](#associated-user-context).

 2. If `emulated screen orientation` is null and [screen
 orientation overrides
 map](#screen-orientation-overrides-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`, [set emulated screen
 orientation](#set-emulated-screen-orientation) with `navigable` and [screen
 orientation overrides
 map](#screen-orientation-overrides-map)\[`user context`\].

 3. Otherwise, [set emulated screen
 orientation](#set-emulated-screen-orientation) with `navigable` and
 `emulated screen orientation`.

9. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.4.2.7. The emulation.setUserAgentOverride Command

The
[emulation.setUserAgentOverride] command
modifies User-Agent on the given top-level traversables or user
contexts.

Command Type

: ```
 emulation.SetUserAgentOverride = (
 method: "emulation.setUserAgentOverride",
 params: emulation.SetUserAgentOverrideParameters
 )

 emulation.SetUserAgentOverrideParameters = {
 userAgent: text / null,
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 }
 ```

Return Type

: ```
 emulation.SetUserAgentOverrideResult = EmptyResult
 ```

The [WebDriver BiDi emulated
User-Agent] steps given [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) `environment settings` are:

1. Let `related navigables` be the result of [get related
 navigables](#get-related-navigables) with `environment settings`.

2. For each `navigable` or `related navigables`:

 1. Let `top-level navigable` be `navigable`'s
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

 2. Let `user context` be
 `top-level navigable`'s [associated user
 context](#associated-user-context).

 3. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If `session`'s [emulated user
 agent](#session-emulated-user-agent)'s [navigable user
 agent](#emulated-user-agent-navigable-user-agent) contains `top-level navigable`,
 return `session`'s [emulated user
 agent](#session-emulated-user-agent)'s [navigable user
 agent](#emulated-user-agent-navigable-user-agent)\[`top-level navigable`\].

 4. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If `session`'s [emulated user
 agent](#session-emulated-user-agent)'s [user context user
 agent](#emulated-user-agent-user-context-user-agent) contains `user context`, return
 `session`'s [emulated user
 agent](#session-emulated-user-agent)'s [user context user
 agent](#emulated-user-agent-user-context-user-agent)\[`user context`\].

3. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. Let `default emulated user agent` be
 `session`'s [emulated user
 agent](#session-emulated-user-agent)'s [default user
 agent](#emulated-user-agent-default-user-agent).

 2. If `default emulated user agent` is not null, return
 `default emulated user agent`.

4. Return null.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. Let `emulated user agent` be
 `command parameters`\[\"`userAgent`\"\].

3. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\":

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid top-level traversables by
 ids](#get-valid-top-level-traversables-by-ids) with
 `command parameters`\[\"`contexts`\"\].

 2. For each `navigable` of `navigables`:

 1. If `emulated user agent` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `navigable` from
 `session`'s [emulated user
 agent](#session-emulated-user-agent)'s [navigable user
 agent](#emulated-user-agent-navigable-user-agent).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) `session`'s [emulated user
 agent](#session-emulated-user-agent)'s [navigable user
 agent](#emulated-user-agent-navigable-user-agent)\[`navigable`\] to
 `emulated user agent`.

 3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

4. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\":

 1. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 2. For each `user context` of
 `user contexts`:

 1. If `emulated user agent` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `user context` from
 `session`'s [emulated user
 agent](#session-emulated-user-agent)'s [user context user
 agent](#emulated-user-agent-user-context-user-agent).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) `session`'s [emulated user
 agent](#session-emulated-user-agent)'s [user context user
 agent](#emulated-user-agent-user-context-user-agent)\[`user context`\] to
 `emulated user agent`.

 3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

5. [Set](https://infra.spec.whatwg.org/#map-set) `session`'s [emulated user
 agent](#session-emulated-user-agent)'s [default user
 agent](#emulated-user-agent-default-user-agent) to `emulated user agent`.

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.4.2.8. The emulation.setScriptingEnabled Command

The
[emulation.setScriptingEnabled] command
emulates disabling JavaScript on web pages.

Command Type

: ```
 emulation.SetScriptingEnabled = (
 method: "emulation.setScriptingEnabled",
 params: emulation.SetScriptingEnabledParameters
 )

 emulation.SetScriptingEnabledParameters = {
 enabled: false / null,
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 }
 ```

Return Type

: ```
 emulation.SetScriptingEnabledResult = EmptyResult
 ```

 only emulation of disabled Javascript is supported.

The [WebDriver BiDi scripting is
enabled] steps given [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) `settings` are:

1. Let `navigable` be `settings`'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

2. Let `top-level traversable` be `navigable`'s
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

3. If [scripting enabled overrides
 map](#scripting-enabled-overrides-map) contains `top-level traversable`, return
 [scripting enabled overrides
 map](#scripting-enabled-overrides-map)\[`top-level traversable`\]

4. Let `user context` be
 `top-level traversable`'s [associated user
 context](#associated-user-context).

5. If [scripting enabled overrides
 map](#scripting-enabled-overrides-map) contains `user context`, return
 [scripting enabled overrides
 map](#scripting-enabled-overrides-map)\[`user context`\].

6. Return true.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. If `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

3. Let `emulated scripting enabled status` be
 `command parameters`\[\"`enabled`\"\].

4. If the `contexts` field of `command parameters` is
 present:

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid top-level traversables by
 ids](#get-valid-top-level-traversables-by-ids) with
 `command parameters`\[\"`contexts`\"\].

 2. For each `navigable` of `navigables`:

 1. If `emulated scripting enabled status` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `navigable` from [scripting
 enabled overrides
 map](#scripting-enabled-overrides-map).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) [scripting enabled overrides
 map](#scripting-enabled-overrides-map)\[`navigable`\] to
 `emulated scripting enabled status`.

5. If the `userContexts` field of `command parameters` is
 present:

 1. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 2. For each `user context` of
 `user contexts`:

 1. If `emulated scripting enabled status` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `user context` from [scripting
 enabled overrides
 map](#scripting-enabled-overrides-map).

 2. Otherwise
 [set](https://infra.spec.whatwg.org/#map-set) [scripting enabled overrides
 map](#scripting-enabled-overrides-map)\[`user context`\] to
 `emulated scripting enabled status`.

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.4.2.9. The emulation.setTimezoneOverride Command

The
[emulation.setTimezoneOverride] command
modifies timezone on the given top-level traversables or user contexts.

Command Type

: ```
 emulation.SetTimezoneOverride = (
 method: "emulation.setTimezoneOverride",
 params: emulation.SetTimezoneOverrideParameters
 )

 emulation.SetTimezoneOverrideParameters = {
 timezone: text / null,
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 }
 ```

Return Type

: ```
 emulation.SetTimezoneOverrideResult = EmptyResult
 ```

[SystemTimeZoneIdentifier](https://tc39.es/ecma262/#sec-systemtimezoneidentifier) algorithm is implementation defined. A WebDriver-BiDi
[remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) must have an implementation that runs the following
steps:

1. Let `emulated timezone` be null.

2. Let `realm` be [current Realm
 Record](https://tc39.es/ecma262/#current-realm).

3. Let `environment settings` be the [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component is `realm`.

4. Let `related navigables` be the result of [get related
 navigables](#get-related-navigables) given `environment settings`.

5. For each `navigable` of `related navigables`:

 1. Let `top-level traversable` be
 `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

 2. Let `user context` be
 `top-level traversable`'s [associated user
 context](#associated-user-context).

 3. If [timezone overrides
 map](#timezone-overrides-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `top-level traversable`, set
 `emulated timezone` to [timezone overrides
 map](#timezone-overrides-map)\[`top-level traversable`\].

 4. Otherwise, if [timezone overrides
 map](#timezone-overrides-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`, set
 `emulated timezone` to [timezone overrides
 map](#timezone-overrides-map)\[`user context`\].

6. If `emulated timezone` is not null, return
 `emulated timezone`.

7. Return the result of implementation-defined steps in accordance with
 the requirements of the
 [SystemTimeZoneIdentifier](https://tc39.es/ecma262/#sec-systemtimezoneidentifier) specification.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. If `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters` doesn't
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

3. Let `emulated timezone` be
 `command parameters`\[\"`timezone`\"\].

4. If `emulated timezone` is not null and
 [IsTimeZoneOffsetString](https://tc39.es/ecma262/#sec-istimezoneoffsetstring)(`emulated timezone`) returns false and
 [AvailableNamedTimeZoneIdentifiers](https://tc39.es/ecma262/#sec-availablenamedtimezoneidentifiers) does not
 [contain](https://infra.spec.whatwg.org/#list-contain) `emulated timezone`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

5. Let `navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

6. If the `contexts` field of `command parameters` is
 present:

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid top-level traversables by
 ids](#get-valid-top-level-traversables-by-ids) with
 `command parameters`\[\"`contexts`\"\].

7. Otherwise:

 1. Assert the `userContexts` field of
 `command parameters` is present.

 2. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 3. For each `user context` of
 `user contexts`:

 1. If `emulated timezone` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `user context` from [timezone
 overrides
 map](#timezone-overrides-map).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) [timezone overrides
 map](#timezone-overrides-map)\[`user context`\] to
 `emulated timezone`.

 3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `top-level traversable` of the
 list of all [top-level
 traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) whose [associated user
 context](#associated-user-context) is `user context`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `top-level traversable` to
 `navigables`.

8. For each `navigable` of `navigables`:

 1. If `emulated timezone` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `navigable` from [timezone overrides
 map](#timezone-overrides-map).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) [timezone overrides
 map](#timezone-overrides-map)\[`navigable`\] to
 `emulated timezone`.

9. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.4.2.10. The emulation.setTouchOverride Command

The [emulation.setTouchOverride] command
emulates enabled touch input on web pages.

Command Type

: ```
 emulation.SetTouchOverride = (
 method: "emulation.setTouchOverride",
 params: emulation.SetTouchOverrideParameters
 )

 emulation.SetTouchOverrideParameters = {
 maxTouchPoints: (js-uint .ge 1) / null,
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 }
 ```

Return Type

: ```
 emulation.SetTouchOverrideResult = EmptyResult
 ```

The [WebDriver BiDi emulated max touch
points] steps given [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) `environment settings` are:

1. Let `related navigables` be the result of [get related
 navigables](#get-related-navigables) with `environment settings`.

2. For each `navigable` of `related navigables`:

 1. Let `top-level navigable` be `navigable`'s
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

 2. Let `user context` be
 `top-level navigable`'s [associated user
 context](#associated-user-context).

 3. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If `session`'s [emulated
 maxTouchPoints](#session-emulated-maxtouchpoints)'s
 [navigables](#emulated-maxtouchpoints-navigables) contains `top-level navigable`,
 return `session`'s [emulated
 maxTouchPoints](#session-emulated-maxtouchpoints)'s
 [navigables](#emulated-maxtouchpoints-navigables)\[`top-level navigable`\].

 4. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If `session`'s [emulated
 maxTouchPoints](#session-emulated-maxtouchpoints)'s [user
 contexts](#emulated-maxtouchpoints-user-contexts) contains `user context`, return
 `session`'s [emulated
 maxTouchPoints](#session-emulated-maxtouchpoints)'s [user
 contexts](#emulated-maxtouchpoints-user-contexts)\[`user context`\].

3. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. Let `emulated maxTouchPoints` be
 `session`'s [emulated
 maxTouchPoints](#session-emulated-maxtouchpoints)'s
 [default](#emulated-maxtouchpoints-default).

 2. If `emulated maxTouchPoints` is not null, return
 `emulated maxTouchPoints`.

4. Return null.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

 There is a legacy [expose legacy touch event
APIs](https://www.w3.org/community/reports/touchevents/CG-FINAL-touch-events-20240704/#conditionally-exposing-legacy-touch-event-apis), which can still be used by some existing web contents
as a signal that the user agent is a touch-enabled \"mobile\" device.
Even though the API is legacy, user agent might run
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined) steps to respect the [emulated
maxTouchPoints](#session-emulated-maxtouchpoints) state in the [expose legacy touch event
APIs](https://www.w3.org/community/reports/touchevents/CG-FINAL-touch-events-20240704/#conditionally-exposing-legacy-touch-event-apis).

1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. Let `maxTouchPoints` be
 `command parameters`\[\"`maxTouchPoints`\"\].

3. If the `contexts` field of `command parameters` is
 present:

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid top-level traversables by
 ids](#get-valid-top-level-traversables-by-ids) with
 `command parameters`\[\"`contexts`\"\].

 2. For each `navigable` of `navigables`:

 1. If `maxTouchPoints` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `navigable` from
 `session`'s [emulated
 maxTouchPoints](#session-emulated-maxtouchpoints)'s
 [navigables](#emulated-maxtouchpoints-navigables).

 2. Otherwise,
 [set](https://infra.spec.whatwg.org/#map-set) `session`'s [emulated
 maxTouchPoints](#session-emulated-maxtouchpoints)'s
 [navigables](#emulated-maxtouchpoints-navigables)\[`navigable`\] to
 `maxTouchPoints`.

 3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

4. If the `userContexts` field of `command parameters` is
 present:

 1. Let `user contexts` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid user
 contexts](#get-valid-user-contexts) with
 `command parameters`\[\"`userContexts`\"\].

 2. For each `user context` of
 `user contexts`:

 1. If `maxTouchPoints` is null,
 [remove](https://infra.spec.whatwg.org/#map-remove) `user context` from
 `session`'s [emulated
 maxTouchPoints](#session-emulated-maxtouchpoints)'s [user
 contexts](#emulated-maxtouchpoints-user-contexts).

 2. Otherwise
 [set](https://infra.spec.whatwg.org/#map-set) `session`'s [emulated
 maxTouchPoints](#session-emulated-maxtouchpoints)'s [user
 contexts](#emulated-maxtouchpoints-user-contexts)\[`user context`\] to
 `maxTouchPoints`.

 3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

5. Set `session`'s [emulated
 maxTouchPoints](#session-emulated-maxtouchpoints)'s
 [default](#emulated-maxtouchpoints-default) to `maxTouchPoints`.

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

### 7.5. The network Module

The [network] module contains commands and events relating
to network requests.

#### 7.5.1. Definition

[`remote end definition`](#cddl-module-remote-end-definition)

```
NetworkCommand = (
 network.AddDataCollector //
 network.AddIntercept //
 network.ContinueRequest //
 network.ContinueResponse //
 network.ContinueWithAuth //
 network.DisownData //
 network.FailRequest //
 network.GetData //
 network.ProvideResponse //
 network.RemoveDataCollector //
 network.RemoveIntercept //
 network.SetCacheBehavior //
 network.SetExtraHeaders
)
```

[`local end definition`](#cddl-module-local-end-definition)

```
NetworkResult = (
 network.AddDataCollectorResult /
 network.AddInterceptResult /
 network.ContinueRequestResult /
 network.ContinueResponseResult /
 network.ContinueWithAuthResult /
 network.DisownDataResult /
 network.FailRequestResult /
 network.GetDataResult /
 network.ProvideResponseResult /
 network.RemoveDataCollectorResult /
 network.RemoveInterceptResult /
 network.SetCacheBehaviorResult /
 network.SetExtraHeadersResult
)

NetworkEvent = (
 network.AuthRequired //
 network.BeforeRequestSent //
 network.FetchError //
 network.ResponseCompleted //
 network.ResponseStarted
)
```

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [before request sent
map] which is initially an empty map. It's used to track the
network events for which a `network.beforeRequestSent` event has already
been sent.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [default cache behavior] which is a string. It is
initially \"`default`\".

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [navigable cache behavior
map] which is a weak map between [top-level
traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable) and strings representing cache behavior. It is
initially empty.

A [BiDi session](#bidi-session)
has a [extra headers] which is a
[struct](https://infra.spec.whatwg.org/#struct) with an
[item](https://infra.spec.whatwg.org/#struct-item) named [default headers], which is a [header
list](https://fetch.spec.whatwg.org/#concept-header-list) (initially set to an empty [header
list](https://fetch.spec.whatwg.org/#concept-header-list)), an
[item](https://infra.spec.whatwg.org/#struct-item) named [user context
headers], which is a weak map
between [user contexts](#user-context) and [header
lists](https://fetch.spec.whatwg.org/#concept-header-list), and a
[item](https://infra.spec.whatwg.org/#struct-item) named [navigable
headers], which is a weak map
between
[navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) and [header
lists](https://fetch.spec.whatwg.org/#concept-header-list).

#### 7.5.2. Network Data Collection

A [network data] is a
[struct](https://infra.spec.whatwg.org/#struct) with:

- [Item](https://infra.spec.whatwg.org/#struct-item) named [bytes], which is a
 [`network.BytesValue`](#networkbytesvalue) or null,

- [Item](https://infra.spec.whatwg.org/#struct-item) named [cloned body], which
 is a
 [body](https://fetch.spec.whatwg.org/#concept-body) or null,

- [Item](https://infra.spec.whatwg.org/#struct-item) named [collectors], which
 is a list of
 [`network.Collector`](#networkcollector),

- [Item](https://infra.spec.whatwg.org/#struct-item) named [pending], which
 is a boolean,

- [Item](https://infra.spec.whatwg.org/#struct-item) named [request], which
 is a [request id](#request-id),

- [Item](https://infra.spec.whatwg.org/#struct-item) named [size], which is a js-uint
 or null,

- [Item](https://infra.spec.whatwg.org/#struct-item) named [type], which is a
 [`network.DataType`](#networkdatatype).

A [collector] is a
[struct](https://infra.spec.whatwg.org/#struct) with:

- [Item](https://infra.spec.whatwg.org/#struct-item) named [max encoded item
 size], which is a
 js-uint;

- [item](https://infra.spec.whatwg.org/#struct-item) named [contexts],
 which is a [list](https://infra.spec.whatwg.org/#list) of [navigable
 id](#navigable-id);

- [item](https://infra.spec.whatwg.org/#struct-item) named [data types],
 which is a [list](https://infra.spec.whatwg.org/#list) of
 [`network.DataType`](#networkdatatype);

- [item](https://infra.spec.whatwg.org/#struct-item) named [collector],
 which is a
 [`network.Collector`](#networkcollector);

- [item](https://infra.spec.whatwg.org/#struct-item) named [collector
 type], which is a
 [`network.CollectorType`](#networkcollectortype);

- [item](https://infra.spec.whatwg.org/#struct-item) named [user
 contexts], which is a
 [list](https://infra.spec.whatwg.org/#list) of
 [`browser.UserContext`](#browserusercontext).

 [max encoded item
size](#network-collector-max-encoded-item-size) defines the limit per item (response or request), and
does not limit the size collected by the specific collector. The total
size of all collected resources is limited by [max total collected
size](#max-total-collected-size).

A [BiDi session](#bidi-session)
has [network collectors] which is a
[map](https://infra.spec.whatwg.org/#ordered-map) between
[`network.Collector`](#networkcollector) and a
[collector](#network-collector). It is initially empty.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has [collected network data] which is a list of
[network data](#network-data).
It is initially empty.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a [max total collected
size] which is a js-uint representing the size allocated to
collect network data in [collected network
data](#collected-network-data). Its value is implementation-defined.

 This allows implementations to set resource usage
limits. It is expected that the limits are sufficiently large that users
can depend on collecting data that is fully decoded and handled by the
browser, such as images and fonts used on a webpage.

To [get navigable for request] given request:

1. Let `navigable` be null.

2. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client) is an [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object):

 1. Let `environment settings` be `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client)

 2. If there is a
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) whose [active
 window](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-window) is `environment settings`' [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global), set `navigable` to be that
 navigable.

3. Return `navigable`.

To [match collector for navigable] given `collector`
and `navigable`:

1. If `collector`'s
 [contexts](#network-collector-contexts) is not
 [empty](https://infra.spec.whatwg.org/#list-empty):

 1. If `collector`'s
 [contexts](#network-collector-contexts)
 [contains](https://infra.spec.whatwg.org/#list-contain) `navigable`'s [navigable
 id](#navigable-id),
 return true.

 2. Otherwise, return false.

2. If `collector`'s [user
 contexts](#network-collector-user-contexts) is not
 [empty](https://infra.spec.whatwg.org/#list-empty):

 1. Let `user context` be `navigable`'s
 [associated user
 context](#associated-user-context).

 2. If `collector`'s [user
 contexts](#network-collector-user-contexts)
 [contains](https://infra.spec.whatwg.org/#list-contain) `user context`'s [user context
 id](#user-context-user-context-id), return true.

 3. Otherwise, return false.

3. Return true.

To [clone network request body] given
[request](https://fetch.spec.whatwg.org/#concept-request) `request`:

 This hook is intended to be triggered by the fetch spec
when the request body has been safely extracted. See step 9 of
https://fetch.spec.whatwg.org/#concept-fetch

1. If `request`'s
 [body](https://fetch.spec.whatwg.org/#concept-request-body) is null, return.

2. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If `session`'s [network
 collectors](#network-collectors) is not
 [empty](https://infra.spec.whatwg.org/#list-empty):

 1. Let `collected data` be a [network
 data](#network-data)
 with
 [bytes](#network-data-bytes) set to null, [cloned
 body](#network-data-cloned-body) set to
 [clone](https://fetch.spec.whatwg.org/#concept-body-clone) of `request`'s
 [body](https://fetch.spec.whatwg.org/#concept-request-body),
 [collectors](#network-data-collectors) set to an empty list,
 [pending](#network-data-pending) set to true,
 [request](#network-data-request) set to `request`'s [request
 id](#request-id),
 [size](#network-data-size) set to null,
 [type](#network-data-type) set to \"request\".

 2. [Append](https://infra.spec.whatwg.org/#list-append) `collected data` to [collected
 network
 data](#collected-network-data).

 3. Return.

To [clone network response body] given `request` and
`response body`:

 This hook is intended to be triggered by the fetch spec
when the response is set.

1. If `response body` is null, return.

2. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If `session`'s [network
 collectors](#network-collectors) is not
 [empty](https://infra.spec.whatwg.org/#list-empty):

 1. Let `collected data` be a [network
 data](#network-data)
 with
 [bytes](#network-data-bytes) set to null, [cloned
 body](#network-data-cloned-body) set to
 [clone](https://fetch.spec.whatwg.org/#concept-body-clone) of `response body`,
 [collectors](#network-data-collectors) set to an empty list,
 [pending](#network-data-pending) set to true,
 [request](#network-data-request) set to `request`'s [request
 id](#request-id),
 [size](#network-data-size) set to null,
 [type](#network-data-type) set to \"response\".

 2. [Append](https://infra.spec.whatwg.org/#list-append) `collected data` to [collected
 network
 data](#collected-network-data).

 3. Return.

To [get collected data] given `request id` and
`data type`.

1. For `collected data` of [collected network
 data](#collected-network-data):

 1. If `collected data`'s
 [request](#network-data-request) is `request id` and
 `collected data`'s
 [type](#network-data-type) is `data type`, return
 `collected data`.

2. Return null.

To [maybe abort network response body
collection] given `request`:

1. Let `collected data` be [get collected
 data](#get-collected-data) with `request`'s [request
 id](#request-id) and
 \"response\".

2. If `collected data` is null, return.

3. Set `collected data`'s
 [pending](#network-data-pending) to false.

4. [Resume](#resume) with
 \"`network data collected`\" and (`request`'s [request
 id](#request-id),
 \"response\").

To [maybe collect network request
body] given `request`:

1. Let `collected data` be [get collected
 data](#get-collected-data) with `request`'s [request
 id](#request-id) and
 \"request\".

2. If `collected data` is null, return.

 [NOTE:] This might happen if there are no collectors setup
 when the request is created, and [clone network request
 body](#clone-network-request-body) does not clone the corresponding body. Or if the
 body was null in the first place.

3. [Maybe collect network
 data](#maybe-collect-network-data) with `request`,
 `collected data`, null and \"request\".

To [maybe collect network response
body] given `request` and
`response`:

1. If `response`'s
 [status](https://fetch.spec.whatwg.org/#concept-response-status) is a [redirect
 status](https://fetch.spec.whatwg.org/#redirect-status), return.

 [NOTE:] For redirects, only the final response body is
 stored.

2. Let `collected data` be [get collected
 data](#get-collected-data) with `request`'s [request
 id](#request-id) and
 \"response\".

3. If `collected data` is null, return.

 [NOTE:] This might happen if there are no collectors setup
 when the response is created, and [clone network response
 body](#clone-network-response-body) does not clone the corresponding body. Or if the
 body was null in the first place.

4. Let `size` be `response`'s [response body
 info](https://fetch.spec.whatwg.org/#response-body-info)'s [encoded
 size](https://fetch.spec.whatwg.org/#fetch-timing-info-encoded-body-size).

 [NOTE:] There is a discrepancy between the fact that the
 bytes retrieved from the fetch stream correspond to the decoded
 data, but the encoded (network) size is used in order to calculate
 size limits. Implementations might decide to use a storage model
 such that it uses less size than storing the decoded data, as long
 as the data returned to clients in getData is identical to the
 decoded data. The potential tradeoff between storage and performance
 is up to the implementation.

5. [Maybe collect network
 data](#maybe-collect-network-data) with `request`,
 `collected data`, `size` and \"response\".

To [maybe collect network data] given
[request](https://fetch.spec.whatwg.org/#concept-request) `request`, [network
data](#network-data)
`collected data`, js-uint `size` and
[network.DataType](#networkdatatype) `data type`:

1. Set `collected data`'s
 [pending](#network-data-pending) to false.

2. Let `navigable` be [get navigable for
 request](#get-navigable-for-request) with `request`.

3. If `navigable` is null:

 1. [Remove](https://infra.spec.whatwg.org/#list-remove) `collected data` from [collected
 network
 data](#collected-network-data).

 2. [Resume](#resume) with
 \"`network data collected`\" and (`request`'s
 [request id](#request-id),
 `data type`).

 3. Return.

 (#issue-d19ddfcd) This prevents collecting data not
 related to a navigable. We still need to retrieve the navigable to
 check against the collector configuration but we could still accept
 null here.

4. Let `top-level navigable` be `navigable`'s
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

5. Let `collectors` be an empty list.

6. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. For each `collector` in `session`'s
 [network
 collectors](#network-collectors):

 1. If `collector`'s [data
 types](#network-collector-data-types)
 [contains](https://infra.spec.whatwg.org/#list-contain) `data type` and if [match
 collector for
 navigable](#match-collector-for-navigable) with `collector` and
 `top-level navigable`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `collector` to
 `collectors`.

7. If `collectors` is
 [empty](https://infra.spec.whatwg.org/#list-empty):

 1. [Remove](https://infra.spec.whatwg.org/#list-remove) `collected data` from [collected
 network
 data](#collected-network-data).

 2. [Resume](#resume) with
 \"`network data collected`\" and (`request`'s
 [request id](#request-id),
 `data type`).

 3. Return.

8. Let `bytes` be null.

9. Let `processBody` given `nullOrBytes` be this
 step:

 1. If `nullOrBytes` is not null:

 1. Set `bytes` to [serialize protocol
 bytes](#serialize-protocol-bytes) with `nullOrBytes`.

 2. If `size` is null, set `size` to
 `bytes`'
 [length](https://infra.spec.whatwg.org/#byte-sequence-length).

10. Let `processBodyError` be this step: Do nothing.

11. [Fully
 read](https://fetch.spec.whatwg.org/#body-fully-read) `collected data`'s [cloned
 body](#network-data-cloned-body) given `processBody` and
 `processBodyError`.

12. If `bytes` is not null:

 1. For `collector` in `collectors`:

 1. If `size` is less than or equal to
 `collector`'s [max encoded item
 size](#network-collector-max-encoded-item-size),
 [append](https://infra.spec.whatwg.org/#list-append) `collector`'s
 [collector](#network-collector-collector) to `collected data`'s
 [collectors](#network-data-collectors).

 2. If `collected data`'s
 [collectors](#network-data-collectors) is not
 [empty](https://infra.spec.whatwg.org/#list-empty):

 1. [Allocate size to record
 data](#allocate-size-to-record-data) given `size`.

 2. Set `collected data`'s
 [bytes](#network-data-bytes) to `bytes`.

 3. Set `collected data`'s
 [size](#network-data-size) to `size`.

 3. Otherwise,
 [remove](https://infra.spec.whatwg.org/#list-remove) `collected data` from [collected
 network
 data](#collected-network-data).

13. [Resume](#resume) with
 \"`network data collected`\" and (`request`'s [request
 id](#request-id),
 `data type`).

To [allocate size to record data] given `size`:

1. Let `available size` be [max total collected
 size](#max-total-collected-size).

2. Let `already collected data` be an empty list.

3. For each `collected data` in [collected network
 data](#collected-network-data):

 1. If `collected data`'s
 [bytes](#network-data-bytes) is not null:

 1. Decrease `available size` by
 `collected data`'s
 [size](#network-data-size).

 2. [Append](https://infra.spec.whatwg.org/#list-append) `collected data` to
 `already collected data`

4. If `size` is greater than `available size`:

 1. For each `collected data` in
 `already collected data`:

 1. Increase `available size` by
 `collected data`'s
 [size](#network-data-size).

 2. Set `collected data`'s
 [bytes](#network-data-bytes) field to null.

 3. Set `collected data`'s
 [size](#network-data-size) field to null.

 4. If `available size` is greater than or equal to
 `size`, return.

To [remove collector from data] given
`collected data` and `collector id`:

1. If `collected data`'s
 [collectors](#network-data-collectors)
 [contains](https://infra.spec.whatwg.org/#list-contain) `collector id`:

 1. [Remove](https://infra.spec.whatwg.org/#list-remove) `collector id` from
 `collected data`'s
 [collectors](#network-data-collectors).

 2. If `collected data`'s
 [collectors](#network-data-collectors) is
 [empty](https://infra.spec.whatwg.org/#list-empty):

 1. [Remove](https://infra.spec.whatwg.org/#list-remove) `collected data` from [collected
 network
 data](#collected-network-data).

#### 7.5.3. Network Intercepts

A [network intercept] is a mechanism to allow remote ends to
intercept and modify network requests and responses.

A [BiDi session](#bidi-session)
has an [intercept map] which is a
[map](https://infra.spec.whatwg.org/#ordered-map) between intercept id and a
[struct](https://infra.spec.whatwg.org/#struct) with fields `url patterns`, `phases`, and `contexts`
that define the properties of active network intercepts. It is initially
empty.

A [BiDi session](#bidi-session)
has a [blocked request map], used to track the requests which are
actively being blocked. It is an
[map](https://infra.spec.whatwg.org/#ordered-map) between [request id](#request-id) and a
[struct](https://infra.spec.whatwg.org/#struct) with fields `request`, `phase`, and `response`. It is
initially empty.

To [get the network intercepts] given `session`,
`event`, `request`, and `navigable id`:

1. Let `session intercepts` be `session`'s
 [intercept map](#intercept-map).

2. Let `intercepts` be an empty list.

3. Run the steps under the first matching condition:

 `event` is \"`network.beforeRequestSent`\"
 : Set `phase` to \"`beforeRequestSent`\".

 `event` is \"`network.responseStarted`\"
 : Set `phase` to \"`responseStarted`\".

 `event` is \"`network.authRequired`\"
 : Set `phase` to \"`authRequired`\".

 `event` is \"`network.responseCompleted`\"
 : Return `intercepts`.

4. Let `url` be the result of running the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer) with `request`'s
 [URL](https://fetch.spec.whatwg.org/#concept-request-url).

5. For each `intercept id` → `intercept` of
 `session intercepts`:

 1. If `intercept`'s `contexts` is not null:

 1. If `intercept`'s `contexts` does not
 [contain](https://infra.spec.whatwg.org/#list-contain) `navigable id`:

 1. Continue.

 2. If `intercept`'s `phases`
 [contains](https://infra.spec.whatwg.org/#list-contain) `phase`:

 1. Let `url patterns` be `intercept`'s
 `url patterns`.

 2. If `url patterns` is
 [empty](https://infra.spec.whatwg.org/#list-empty):

 1. [Append](https://infra.spec.whatwg.org/#list-append) `intercept id` to
 `intercepts`.

 2. Continue.

 3. For each `url pattern` in
 `url patterns`:

 1. If [match URL
 pattern](#match-url-pattern) with `url pattern` and
 `url`:

 1. [Append](https://infra.spec.whatwg.org/#list-append) `intercept id` to
 `intercepts`.

 2. Break.

6. Return `intercepts`.

To [update the response] given `session`,
`command` and `command parameters`:

1. Let `blocked requests` be `session`'s [blocked
 request map](#blocked-request-map).

2. Let `request id` be
 `command parameters`\[\"`request`\"\].

3. If `blocked requests` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) `request id` then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 request](#errors-no-such-request).

4. Let (`request`, `phase`,
 `response`) be
 `blocked requests`\[`request id`\].

5. If `phase` is \"`beforeRequestSent`\" and
 `command` is \"`continueResponse`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) \"`invalid argument`\".

 TODO: Consider a different error

6. If `response` is null:

 1. Assert: `phase` is \"`beforeRequestSent`\".

 2. Set `response` to a new
 [response](https://fetch.spec.whatwg.org/#concept-response).

7. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`statusCode`\":

 1. Set `responses`'s
 [status](https://fetch.spec.whatwg.org/#concept-response-status) be
 `command parameters`\[\"`statusCode`\"\].

8. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`reasonPhrase`\":

 1. Set `responses`'s [status
 message](https://fetch.spec.whatwg.org/#concept-response-status-message) be [UTF-8
 encode](https://encoding.spec.whatwg.org/#utf-8-encode) with
 `command parameters`\[\"`reasonPhrase`\"\].

9. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`headers`\":

 1. Let `headers` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [create a headers
 list](#create-a-headers-list) with
 `command parameters`\[\"`headers`\"\].

 2. Set `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list) to `headers`.

10. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`cookies`\":

 1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`headers`\", let `headers` be
 `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list).

 Otherwise:

 1. Let `headers` be an empty [header
 list](https://fetch.spec.whatwg.org/#concept-header-list).

 2. For each `header` in `response`'s
 [headers
 list](https://fetch.spec.whatwg.org/#concept-response-header-list):

 1. Let `name` be `header`'s name.

 2. If
 [byte-lowercase](https://infra.spec.whatwg.org/#byte-lowercase) `name` is not
 \``set-cookie`\`:

 1. Append `header` to `headers`

 2. For `cookie` in
 `command parameters`\[\"`cookies`\"\]:

 1. Let `header value` be [serialize set-cookie
 header](#serialize-set-cookie-header) with `cookie`.

 2. Append (\``Set-Cookie`\`, `header value`) to
 `headers`.

 3. Set `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list) to `headers`.

11. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`credentials`\":

 (#issue-2a7f19c6) This doesn't have a way to cancel
 the auth.

 1. Let `credentials` be
 `command parameters`\[\"`credentials`\"\].

 2. Assert: `credentials`\[\"`type`\"\] is
 \"`password`\".

 3. Set `response`'s authentication credentials to
 (`credentials`\[\"`username`\"\],
 `credentials`\[\"`password`\"\])

12. Return `response`

#### 7.5.4. Types

##### 7.5.4.1. The network.AuthChallenge Type

```
network.AuthChallenge = {
 scheme: text,
 realm: text,
}
```

To [extract challenges] given `response`:

Should we include parameters other than
realm?

1. If `response`'s
 [status](https://fetch.spec.whatwg.org/#concept-response-status) is 401, let `header name` be
 \``WWW-Authenticate`\`. Otherwise if `response`'s
 [status](https://fetch.spec.whatwg.org/#concept-response-status) is 407, let `header name` be
 \``Proxy-Authenticate`\`. Otherwise return null.

2. Let `challenges` be a new
 [list](https://infra.spec.whatwg.org/#list).

3. For each (`name`, `value`) in
 `response`'s [header
 list](https://fetch.spec.whatwg.org/#concept-response-header-list):

 (#issue-fb11fbae) as in Fetch it's unclear if this is
 the right way to handle multiple headers, parsing issues, etc.

 1. If `name` is a
 [byte-case-insensitive](https://infra.spec.whatwg.org/#byte-case-insensitive) match for `header name`:

 1. Let `header challenges` be the result of parsing
 `value` into a list of challenges, each
 consisting of a scheme and a list of parameters, each of
 which is a
 [tuple](https://infra.spec.whatwg.org/#tuple) (name, value), according to the rules of
 [\[RFC9110\]](#biblio-rfc9110 "HTTP Semantics").

 2. For each `header challenge` in
 `header challenges`:

 1. Let `scheme` be
 `header challenge`'s scheme.

 2. Let `realm` be the empty string.

 3. For each (`param name`,
 `param value`) in
 `header challenge`'s parameters:

 1. If `param name` equals \``realm`\` let
 `realm` be [UTF-8
 decode](https://encoding.spec.whatwg.org/#utf-8-decode) `param value`.

 4. Let `challenge` be a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `network.AuthChallenge`
 production, with the `scheme` field set to
 `scheme` and the `realm` field set to
 `realm`.

 3. [Append](https://infra.spec.whatwg.org/#list-append) `challenge` to
 `challenges`.

4. Return `challenges`.

##### 7.5.4.2. The network.AuthCredentials Type

```
network.AuthCredentials = {
 type: "password",
 username: text,
 password: text,
}
```

The `network.AuthCredentials` type represents the response to a request
for authorization credentials.

##### 7.5.4.3. The network.BaseParameters Type

```
network.BaseParameters = (
 context: browsingContext.BrowsingContext / null,
 isBlocked: bool,
 navigation: browsingContext.Navigation / null,
 redirectCount: js-uint,
 request: network.RequestData,
 timestamp: js-uint,
 ? intercepts: [+network.Intercept]
)
```

The `network.BaseParameters` type is an abstract type representing the
data that's common to all network events.

Consider including the \`sharedId\` of
the document node that initiated the request in addition to the context.

To [process a network event] given `session`,
`event`, and `request`:

1. Let `request data` be the result of [get the request
 data](#get-the-request-data) with `request`.

2. Let `navigation` be `request`'s [navigation
 id](https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigation-id).

3. Let `navigable id` be null.

4. Let `top-level navigable id` be null.

5. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client) is an [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object):

 1. Let `environment settings` be `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client).

 2. If there is a
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) whose [active
 window](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-window) is `environment settings`' [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global), set `navigable id` to that
 navigable's [navigable
 id](#navigable-id), and
 set `top-level navigable id` to that navigable's
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top)'s [navigable
 id](#navigable-id).

6. Let `intercepts` be the result of [get the network
 intercepts](#get-the-network-intercepts) with `session`, `event`,
 `request`, and `top-level navigable id`.

7. Let `redirect count` be `request`'s [redirect
 count](https://fetch.spec.whatwg.org/#concept-request-redirect-count).

8. Let `timestamp` be a [time
 value](https://tc39.es/ecma262/#sec-time-values-and-time-range) representing the current date and time in UTC.

9. If `intercepts` is not
 [empty](https://infra.spec.whatwg.org/#list-empty), let `is blocked` be true, otherwise let
 `is blocked` be false.

10. Let `params` be
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `network.BaseParameters` production,
 with the `request` field set to `request data`, the
 `navigation` field set to `navigation`, the `context`
 field set to `navigable id`, the `timestamp` field set to
 `timestamp`, the `redirectCount` field set to
 `redirect count`, the `isBlocked` field set to
 `is blocked`, and `intercepts` field set to
 `intercepts` if `is blocked` is true, or
 omitted otherwise.

11. Return `params`

##### 7.5.4.4. The network.BytesValue Type

```
network.BytesValue = network.StringValue / network.Base64Value;

network.StringValue = {
 type: "string",
 value: text,
}

network.Base64Value = {
 type: "base64",
 value: text,
}
```

The [`network.BytesValue`] type represents binary data sent over the
network. Valid UTF-8 is represented with the `network.StringValue` type,
any other data is represented in Base64-encoded form as
`network.Base64Value`.

To [deserialize protocol bytes] given
`protocol bytes`:

 this takes bytes encoded as a
[`network.BytesValue`](#networkbytesvalue) and returns a [byte
sequence](https://infra.spec.whatwg.org/#byte-sequence).

1. If `protocol bytes` matches the `network.StringValue`
 production, let `bytes` be [UTF-8
 encode](https://encoding.spec.whatwg.org/#utf-8-encode) `protocol bytes`\[\"`value`\"\].

2. Otherwise if `protocol bytes` matches the
 `network.Base64Value` production. Let `bytes` be
 [forgiving-base64
 decode](https://infra.spec.whatwg.org/#forgiving-base64-decode) `protocol bytes`\[\"`value`\"\].

3. Return `bytes`.

To [serialize protocol bytes] given `bytes`:

 this takes a [byte
sequence](https://infra.spec.whatwg.org/#byte-sequence) and returns a
[`network.BytesValue`](#networkbytesvalue).

1. Let `text` be [UTF-8 decode without BOM or
 fail](https://encoding.spec.whatwg.org/#utf-8-decode-without-bom-or-fail) `bytes`.

2. If `text` is failure, return a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `network.Base64Value` production, with
 `value` set to [forgiving-base64
 encode](https://infra.spec.whatwg.org/#forgiving-base64-encode) `bytes`.

3. Return a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `network.StringValue` production, with
 `value` set to `text`.

##### 7.5.4.5. The network.Collector Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.Collector = text
```

The [`network.Collector`] type represents the id of a
[collector](#network-collector).

##### 7.5.4.6. The network.CollectorType Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.CollectorType = "blob"
```

 In the future we might also support the \"stream\"
collector type for clients which want to read the data gathered by a
given collector via a stream.

The [`network.CollectorType`] type represents the different types of data
collectors that can be added.

##### 7.5.4.7. The network.Cookie Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.SameSite = "strict" / "lax" / "none" / "default"

network.Cookie = {
 name: text,
 value: network.BytesValue,
 domain: text,
 path: text,
 size: js-uint,
 httpOnly: bool,
 secure: bool,
 sameSite: network.SameSite,
 ? expiry: js-uint,
 Extensible,
}
```

The `network.Cookie` type represents a cookie.

To [serialize cookie] given `stored cookie`:

1. Let `name` be the result of [UTF-8
 decode](https://encoding.spec.whatwg.org/#utf-8-decode) with `stored cookie`'s name field.

2. Let `value` be [serialize protocol
 bytes](#serialize-protocol-bytes) with `stored cookie`'s value.

3. Let `domain` be `stored cookie`'s domain
 field.

4. Let `path` be `stored cookie`'s path field.

5. Let `expiry` be `stored cookie`'s expiry-time
 field represented as a unix timestamp, if set, or null otherwise.

6. Let `size` be the byte length of the result of
 serializing `stored cookie` as it would be represented in
 a `Cookie` header.

7. Let `http only` be true if `stored cookie`'s
 http-only-flag is true, or false otherwise.

8. Let `secure` be true if `stored cookie`'s
 secure-only-flag is true, or false otherwise.

9. Let `same site` be \"`none`\" if
 `stored cookie`'s same-site-flag is \"`None`\", \"`lax`\"
 if it is \"`Lax`\", \"`strict`\" if it is \"`Strict`\", or
 \"`default`\" if it is \"`Default`\"

10. Return a map matching the `network.Cookie` production, with the
 `name` field set to `name`, the `value` field set to
 `value`, the `domain` field set to `domain`,
 the `path` field set to `path`, the `expiry` field set to
 `expiry` if it's not null, or omitted otherwise, the
 `size` field set to `size`, the `httpOnly` field set to
 `http only`, the `secure` field set to
 `secure`, and the `sameSite` field set to
 `same site`.

##### 7.5.4.8. The network.CookieHeader Type

[`Remote end definition`](#cddl-module-remote-end-definition)

```
network.CookieHeader = {
 name: text,
 value: network.BytesValue,
}
```

The `network.CookieHeader` type represents the subset of cookie data
that's in a `Cookie` request header.

To [serialize cookie header] given `protocol cookie`:

1. Let `name` be [UTF-8
 encode](https://encoding.spec.whatwg.org/#utf-8-encode) `protocol cookie`\[\"`name`\"\].

2. Let `value` be [deserialize protocol
 bytes](#deserialize-protocol-bytes) with `protocol cookie`\[\"`value`\"\].

3. Let `header value` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence) formed by concatenating `name`, \``=`\`,
 and `value`

4. Return `header value`.

##### 7.5.4.9. The network.DataType Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.DataType = "request" / "response"
```

The [`network.DataType`] type represents the different types of
network data that can be collected.

##### 7.5.4.10. The network.FetchTimingInfo Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.FetchTimingInfo = {
 timeOrigin: float,
 requestTime: float,
 redirectStart: float,
 redirectEnd: float,
 fetchStart: float,
 dnsStart: float,
 dnsEnd: float,
 connectStart: float,
 connectEnd: float,
 tlsStart: float,
 requestStart: float,
 responseStart: float,
 responseEnd: float,
}
```

The `network.FetchTimingInfo` type represents the time of each part of
the request, relative to the [time
origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-time-origin) of the
[request](https://fetch.spec.whatwg.org/#concept-request)'s
[client](https://fetch.spec.whatwg.org/#concept-request-client).

To [get the fetch timings] given `request`:

1. Let `global` be `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client).

2. If `global` is null, return a map matching the
 `network.FetchTimingInfo` production, with all fields set to 0.

3. Let `time origin` be [get time origin
 timestamp](https://w3c.github.io/hr-time/#dfn-get-time-origin-timestamp) with `global`.

4. Let `timings` be `request`'s [fetch timing
 info](https://fetch.spec.whatwg.org/#fetch-timing-info).

5. Let `connection timing` be `timings`' [final
 connection timing
 info](https://fetch.spec.whatwg.org/#fetch-timing-info-final-connection-timing-info) if it's not null, or a new [connection timing
 info](https://fetch.spec.whatwg.org/#connection-timing-info) otherwise.

6. Let `request time` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `timings`' [start
 time](https://fetch.spec.whatwg.org/#fetch-timing-info-start-time) and `global`.

7. Let `redirect start` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `timings`' [redirect start
 time](https://fetch.spec.whatwg.org/#fetch-timing-info-redirect-start-time) and `global`.

8. Let `redirect end` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `timings`' [redirect end
 time](https://fetch.spec.whatwg.org/#fetch-timing-info-redirect-end-time) and `global`.

9. Let `fetch start` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `timings`' [post-redirect start
 time](https://fetch.spec.whatwg.org/#fetch-timing-info-post-redirect-start-time) and `global`.

10. Let `DNS start` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `connection timing`'s [domain
 lookup start
 time](https://fetch.spec.whatwg.org/#connection-timing-info-domain-lookup-start-time) and `global`.

11. Let `DNS end` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `connection timing`'s [domain
 lookup end
 time](https://fetch.spec.whatwg.org/#connection-timing-info-domain-lookup-end-time) and `global`.

12. Let `TLS start` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `connection timing`'s [secure
 connection start
 time](https://fetch.spec.whatwg.org/#connection-timing-info-secure-connection-start-time) and `global`.

13. Let `connect start` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `connection timing`'s [connection
 start
 time](https://fetch.spec.whatwg.org/#connection-timing-info-connection-start-time) and `global`.

14. Let `connect end` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `connection timing`'s [connection
 end
 time](https://fetch.spec.whatwg.org/#connection-timing-info-connection-end-time) and `global`.

15. Let `request start` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `timings`' [final network-request
 start
 time](https://fetch.spec.whatwg.org/#fetch-timing-info-final-network-request-start-time) and `global`.

16. Let `response start` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `timings`' [final network-response
 start
 time](https://fetch.spec.whatwg.org/#fetch-timing-info-final-network-response-start-time) and `global`.

17. Let `response end` be [convert fetch
 timestamp](https://w3c.github.io/resource-timing/#dfn-convert-fetch-timestamp) given `timings`' [end
 time](https://fetch.spec.whatwg.org/#fetch-timing-info-end-time) and `global`.

18. Return a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `network.FetchTimingInfo` production
 with the `timeOrigin` field set to `time origin`, the
 `requestTime` field set to `request time`, the
 `redirectStart` field set to `redirect start`, the
 `redirectEnd` field set to `redirect end`, the
 `fetchStart` field set to `fetch start`, the `dnsStart`
 field set to `DNS start`, the `dnsEnd` field set to
 `DNS end`, the `connectStart` field set to
 `connect start`, the `connectEnd` field set to
 `connect end`, the `tlsStart` field set to
 `TLS start`, the `requestStart` field set to
 `request start`, the `responseStart` field set to
 `response start`, and the `responseEnd` field set to
 `response end`.

TODO: Add service worker fields

##### 7.5.4.11. The network.Header Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.Header = {
 name: text,
 value: network.BytesValue,
}
```

The `network.Header` type represents a single request header.

To [serialize header] given `name bytes` and `value bytes`:

1. Let `name` be the result of [UTF-8
 decode](https://encoding.spec.whatwg.org/#utf-8-decode) with `name bytes`.

 Assert: Since header names are constrained to be ASCII-only this
 cannot fail.

2. Let `value` be [serialize protocol
 bytes](#serialize-protocol-bytes) with `value bytes`.

3. Return a map matching the `network.Header` production, with the
 `name` field set to `name`, and the `value` field set to
 `value`.

To [deserialize header] given `protocol header`:

1. Let `name` be [UTF-8
 encode](https://encoding.spec.whatwg.org/#utf-8-encode) `protocol header`\[\"`name`\"\].

2. Let `value` be [deserialize protocol
 bytes](#deserialize-protocol-bytes) with `protocol header`\[\"`value`\"\].

3. Return a
 [header](https://fetch.spec.whatwg.org/#concept-header) (`name`, `value`).

To [create a headers list] given `protocol headers`:

1. Let `headers` be an empty [header
 list](https://fetch.spec.whatwg.org/#concept-header-list).

2. For `header` in `protocol headers`:

 1. Let `deserialized header` be [deserialize
 header](#deserialize-header) with `header`.

 2. If `deserialized header`'s name does not match the
 [field-name
 token](https://httpwg.org/specs/rfc9110.html#fields.names) production, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) \"`invalid argument`\".

 3. If `deserialized header`'s value does not match the
 [header
 value](https://fetch.spec.whatwg.org/#header-value) production, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) \"`invalid argument`\".

 4. Append `deserialized header` to `headers`.

3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `headers`

##### 7.5.4.12. The network.Initiator Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.Initiator = {
 ? columnNumber: js-uint,
 ? lineNumber: js-uint,
 ? request: network.Request,
 ? stackTrace: script.StackTrace,
 ? type: "parser" / "script" / "preflight" / "other"
}
```

The `network.Initiator` type represents the source of a network request.

 The `type` field is included in the definition for
backwards compatibility, but is no longer set by the [get the
initiator](#get-the-initiator) steps, and will be removed in a future revision of this
specification. Its use is expected to be replaced by `initiatorType` and
`destination` on `network.RequestData`.

 The `request` field is included in the definition for
backwards compatibility, but is no longer set by the [get the
initiator](#get-the-initiator) steps, and will be removed in a future revision of this
specification. The `network.Initiator` is included in the
`network.BeforeRequestSentParameters` which also contain the same
request id, making this information redundant. See [§ 7.5.4.3 The
network.BaseParameters Type](#type-network-BaseParameters).

To [get the initiator] given `request`:

1. If `request`'s [initiator
 type](https://fetch.spec.whatwg.org/#request-initiator-type) is \"`fetch`\" or \"`xmlhttprequest`\":

 1. Let `stack trace` be the [current stack
 trace](#current-stack-trace).

 2. If `stack trace` has size of 1 or greater, let
 `line number` be value of the `lineNumber` field in
 `stack trace`\[0\], and let
 `column number` be the value of the `columnNumber`
 field in `stack trace`\[0\]. Otherwise let
 `line number` and `column number` be 0.

 Otherwise, let `stack trace`, `column number`,
 and `line number` all be null.

 TODO: Chrome includes the current parser position as column number /
 line number for parser-inserted resources.

2. Return a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `network.Initiator` production, the
 `columnNumber` field set to `column number` if it's not
 null, or omitted otherwise, the `lineNumber` field set to
 `line number` if it's not null, or omitted otherwise and
 the `stackTrace` field set to `stack trace` if it's not
 null, or omitted otherwise.

##### 7.5.4.13. The network.Intercept Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.Intercept = text
```

The `network.Intercept` type represents the id of a [network
intercept](#network-intercept).

##### 7.5.4.14. The network.Request Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.Request = text;
```

Each network request has an associated [request id], which is a string uniquely
identifying that request. The identifier for a request resulting from a
redirect matches that of the request that initiated it.

##### 7.5.4.15. The network.RequestData Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.RequestData = {
 request: network.Request,
 url: text,
 method: text,
 headers: [*network.Header],
 cookies: [*network.Cookie],
 headersSize: js-uint,
 bodySize: js-uint / null,
 destination: text,
 initiatorType: text / null,
 timings: network.FetchTimingInfo,
}
```

The `network.RequestData` type represents an ongoing network request.

To [get the request data] given `request`:

1. Let `request id` be request's [request
 id](#request-id).

2. Let `url` be the result of running the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer) with `request`'s
 [URL](https://fetch.spec.whatwg.org/#concept-request-url).

3. Let `method` be `request`'s
 [method](https://fetch.spec.whatwg.org/#concept-request-method).

4. Let `body size` be null.

5. Let `body` be request's
 [body](https://fetch.spec.whatwg.org/#concept-request-body).

6. If `body` is a [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence), set `body size` to the length of that
 sequence. Otherwise, if `body` is a
 [body](https://fetch.spec.whatwg.org/#concept-body) then set `body size` to that body's
 [length](https://fetch.spec.whatwg.org/#concept-body-total-bytes).

7. Let `headers size` be the size in bytes of
 `request`'s [headers
 list](https://fetch.spec.whatwg.org/#concept-request-header-list) when serialized as mandated by
 [\[HTTP11\]](#biblio-http11 "HTTP/1.1").

 For protocols which allow header compression, this
 is the compressed size of the headers, as sent over the network.

8. Let `headers` be an empty list.

9. Let `cookies` be an empty list.

10. For each (`name`, `value`) in
 `request`'s [headers
 list](https://fetch.spec.whatwg.org/#concept-request-header-list):

 1. Append the result of [serialize
 header](#serialize-header) with `name` and `value`
 to `headers`.

 2. If `name` is a
 [byte-case-insensitive](https://infra.spec.whatwg.org/#byte-case-insensitive) match for \"`Cookie`\" then:

 1. For each `cookie` in the user agent's [cookie
 store](https://httpwg.org/specs/rfc6265.html#storage-model) that are included in `request`:

 [\[COOKIES\]](#biblio-cookies "HTTP State Management Mechanism")
 defines some baseline requirements for which cookies in the
 store can be included in a request, but user agents are free
 to impose additional constraints.

 1. Append the result of [serialize
 cookie](#serialize-cookie) given `cookie` to
 `cookies`.

11. Let `destination` be `request`'s
 [destination](https://fetch.spec.whatwg.org/#concept-request-destination).

12. Let `initiator type` be `request`'s [initiator
 type](https://fetch.spec.whatwg.org/#request-initiator-type).

13. Let `timings` be [get the fetch
 timings](#get-the-fetch-timings) with `request`.

14. Return a map matching the `network.RequestData` production, with the
 `request` field set to `request id`, `url` field set to
 `url`, the `method` field set to `method`, the
 `headers` field set to `headers`, the
 `cookies` field set to `cookies`, the
 `headersSize` field set to `headers size`, the `bodySize`
 field set to `body size`, the `destination` field set to
 `destination`, the `initiatorType` field set to
 `initiator type`, and the `timings` field set to
 `timings`.

##### 7.5.4.16. The network.ResponseContent Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.ResponseContent = {
 size: js-uint
}
```

The `network.ResponseContent` type represents the decoded response to a
network request.

To [get the response content info] given `response`.

1. Return a new map matching the `network.ResponseContent` production,
 with the `size` field set to `response`'s [response body
 info](https://fetch.spec.whatwg.org/#response-body-info)'s [decoded
 size](https://fetch.spec.whatwg.org/#fetch-timing-info-decoded-body-size)

##### 7.5.4.17. The network.ResponseData Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
network.ResponseData = {
 url: text,
 protocol: text,
 status: js-uint,
 statusText: text,
 fromCache: bool,
 headers: [*network.Header],
 mimeType: text,
 bytesReceived: js-uint,
 headersSize: js-uint / null,
 bodySize: js-uint / null,
 content: network.ResponseContent,
 ?authChallenges: [*network.AuthChallenge],
}
```

The `network.ResponseData` type represents the response to a network
request.

To [get the protocol] given `response`:

1. Let `protocol` be the empty string.

2. If `response`'s [final connection timing
 info](https://fetch.spec.whatwg.org/#fetch-timing-info-final-connection-timing-info) is not null, set `protocol` to
 `response`'s [final connection timing
 info](https://fetch.spec.whatwg.org/#fetch-timing-info-final-connection-timing-info)'s [ALPN negotiated
 protocol](https://fetch.spec.whatwg.org/#connection-timing-info-alpn-negotiated-protocol).

3. If `protocol` is the empty string, or is equal to
 \"`unknown`\":

 1. Set `protocol` to `response`'s
 [url](https://fetch.spec.whatwg.org/#concept-response-url)'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme)

 2. If `protocol` is equal to either \"`http`\" or
 \"`https`\" and `response` has an associated HTTP
 Response.

 [\[FETCH\]](#biblio-fetch "Fetch Standard")
 isn't clear about the relation between a HTTP network response
 and a response object.

 1. Let `http version` be the HTTP Response's Status
 line's HTTP-version
 [\[HTTP11\]](#biblio-http11 "HTTP/1.1").

 2. If `http version` starts with \"`HTTP/`\":

 1. Let `version` be the [code unit
 substring](https://infra.spec.whatwg.org/#code-unit-substring) of `http version` from 5 to
 `http version`'s
 [length](https://infra.spec.whatwg.org/#string-length).

 2. If `version` is \"`0.9`\", set
 `protocol` to \"`http/0.9`\", otherwise if
 `version` is \"`1.0`\", set
 `protocol` to \"`http/1.0`\", otherwise if
 `version` is \"`1.1`\", set
 `protocol` to \"`http/1.1`\".

4. Return `protocol`.

To [get the response data] given `response`:

1. Let `url` be the result of running the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer) with `response`'s
 [URL](https://fetch.spec.whatwg.org/#concept-response-url).

2. Set `protocol` to [get the
 protocol](#get-the-protocol) given `response`.

3. Let `status` be `response`'s
 [status](https://fetch.spec.whatwg.org/#concept-response-status).

4. Let `status text` be `response`'s [status
 message](https://fetch.spec.whatwg.org/#concept-response-status-message).

5. If `response`'s [cache
 state](https://fetch.spec.whatwg.org/#concept-response-cache-state) is \"`local`\", let `from cache` be
 true, otherwise let it be false.

6. Let `headers` be an empty list.

7. Let `mime type` be the
 [essence](https://mimesniff.spec.whatwg.org/#mime-type-essence) of the [computed mime
 type](https://mimesniff.spec.whatwg.org/#computed-mime-type) for `response`.

 this is whatever MIME type the browser is actually
 using, even if it isn't following the exact algorithm in the
 [\[MIMESNIFF\]](#biblio-mimesniff "MIME Sniffing Standard")
 specification.

8. For each (`name`, `value`) in
 `response`'s [headers
 list](https://fetch.spec.whatwg.org/#concept-response-header-list):

 1. Append the result of [serialize
 header](#serialize-header) with `name` and `value`
 to `headers`.

9. Let `bytes received` be the total number of bytes
 transmitted as part of the HTTP response associated with
 `response`.

10. Let `headers size` be the number of bytes transmitted as
 part of the header fields section of the HTTP response.

11. Let `body size` be `response`'s [response body
 info](https://fetch.spec.whatwg.org/#response-body-info)'s [encoded
 size](https://fetch.spec.whatwg.org/#fetch-timing-info-encoded-body-size).

12. Let `content` be the result of [get the response content
 info](#get-the-response-content-info) with `response`.

13. Let `auth challenges` be the result of [extract
 challenges](#extract-challenges) with `response`.

14. Return a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `network.ResponseData` production,
 with the `url` field set to `url`, the `protocol` field
 set to `protocol`, the `status` field set to
 `status`, the `statusText` field set to
 `status text`, the `fromCache` field set to
 `from cache`, the `headers` field set to
 `headers`, the `mimeType` field set to
 `mime type`, the `bytesReceived` field set to
 `bytes received`, the `headersSize` field set to
 `headers size`, the `bodySize` field set to
 `body size`, `content` field set to `content`,
 and the `authChallenges` field set to `auth challenges`
 if it's not null, or omitted otherwise.

##### 7.5.4.18. The network.SetCookieHeader Type

[`Remote end definition`](#cddl-module-remote-end-definition)

```
network.SetCookieHeader = {
 name: text,
 value: network.BytesValue,
 ? domain: text,
 ? httpOnly: bool,
 ? expiry: text,
 ? maxAge: js-int,
 ? path: text,
 ? sameSite: network.SameSite,
 ? secure: bool,
}
```

The `network.SetCookieHeader` represents the data in a `Set-Cookie`
response header.

To [serialize an integer] given `input` that is an integer:

 This produces the shortest representation of
`input` as a string of decimal digits.

1. Let `serialized` be an empty string.

2. Let `value` be `input`.

3. While `value` is greater than 0:

 1. Let `x` be `value` divided by 10.

 2. Let `most significant digits` be the integer part of
 `x`.

 3. Let `y` be `most significant digits`
 multiplied by 10.

 4. Let `least significant digit` be `value` -
 `y`.

 5. Assert: `least significant digit` is an integer in
 the range 0 to 9, inclusive.

 6. Let `codepoint` be the [code
 point](https://infra.spec.whatwg.org/#code-point) whose
 [value](https://infra.spec.whatwg.org/#code-point-value) is U+0030 DIGIT ZERO's
 [value](https://infra.spec.whatwg.org/#code-point-value) + `least significant digit`.

 7. Prepend `codepoint` to `serialized`.

 8. Set `value` to `most significant digits`.

4. Return `serialized`.

To [serialize set-cookie header] given
`protocol cookie`:

1. Let `name` be [UTF-8
 encode](https://encoding.spec.whatwg.org/#utf-8-encode) `protocol cookie`\[\"`name`\"\].

2. Let `value` be [deserialize protocol
 bytes](#deserialize-protocol-bytes) with `protocol cookie`\[\"`value`\"\].

3. Let `header value` be the [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence) formed by concatenating `name`, \``=`\`,
 and `value`.

4. If `protocol cookie`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`expiry`\":

 1. Let `attribute` be \``;Expires=`\`

 2. Append [UTF-8
 encode](https://encoding.spec.whatwg.org/#utf-8-encode) `protocol cookie`\[\"`expiry`\"\] to
 `attribute`.

 3. Append `attribute` to `header value`.

5. If `protocol cookie`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`maxAge`\":

 1. Let `attribute` be \``;Max-Age=`\`

 2. Let `max age string` be [serialize an
 integer](#serialize-an-integer) `protocol cookie`\[\"`maxAge`\"\].

 3. Append [UTF-8
 encode](https://encoding.spec.whatwg.org/#utf-8-encode) `max age string` to
 `attribute`.

 4. Append `attribute` to `header value`.

6. If `protocol cookie`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`domain`\":

 1. Let `attribute` be \``;Domain=`\`

 2. Append [UTF-8
 encode](https://encoding.spec.whatwg.org/#utf-8-encode) `protocol cookie`\[\"`domain`\"\] to
 `attribute`.

 3. Append `attribute` to `header value`.

7. If `protocol cookie`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`path`\":

 1. Let `attribute` be \``;Path=`\`

 2. Append [UTF-8
 encode](https://encoding.spec.whatwg.org/#utf-8-encode) `protocol cookie`\[\"`path`\"\] to
 `attribute`.

 3. Append `attribute` to `header value`.

8. If `protocol cookie`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`secure`\" and
 `protocol cookie`\[\"`secure`\"\] is true:

 1. Append \``;Secure`\` to `header value`.

9. If `protocol cookie`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`httpOnly`\" and
 `protocol cookie`\[\"`httpOnly`\"\] is true:

 1. Append \``;HttpOnly`\` to `header value`.

10. If `protocol cookie`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`sameSite`\":

 1. Let `attribute` be \``;SameSite=`\`

 2. Append [UTF-8
 encode](https://encoding.spec.whatwg.org/#utf-8-encode) `protocol cookie`\[\"`sameSite`\"\]
 to `attribute`.

 3. Append `attribute` to `header value`.

11. Return `header value`.

##### 7.5.4.19. The network.UrlPattern Type

[`Remote end definition`](#cddl-module-remote-end-definition)

```
network.UrlPattern = (
 network.UrlPatternPattern /
 network.UrlPatternString
)

network.UrlPatternPattern = {
 type: "pattern",
 ?protocol: text,
 ?hostname: text,
 ?port: text,
 ?pathname: text,
 ?search: text,
}

network.UrlPatternString = {
 type: "string",
 pattern: text,
}
```

A `network.UrlPattern` represents a pattern used for matching request
URLs for [network
intercepts](#network-intercept).

When URLs are matched against a `network.UrlPattern` the URL is parsed,
and each component is compared for equality with the corresponding field
in the pattern, if present. Missing fields from the pattern always
match.

 This syntax is designed with future extensibility in
mind. In particular the syntax forbids characters that are treated
specially in the
[\[URLPattern\]](#biblio-urlpattern "URL Pattern Standard")
specification. These can be escaped by prefixing them with a U+005C (\\)
character.

To [unescape URL pattern] given `pattern`

1. Let `forbidden characters` be the
 [set](https://infra.spec.whatwg.org/#ordered-set) of codepoints «U+0028 ((), U+0029 ()), U+002A (\*),
 U+007B ({), U+007D (})»

2. Let `result` be the empty string.

3. Let `is escaped character` be false.

4. For each `codepoint` in `pattern`:

 1. If `is escaped character` is false:

 1. If `forbidden characters`
 [contains](https://infra.spec.whatwg.org/#list-contain) `codepoint`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 2. If `codepoint` is U+005C (\\):

 1. Set `is escaped character` to true.

 2. Continue.

 2. Append `codepoint` to result.

 3. Set `is escaped character` to false.

5. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `result`.

To [parse URL pattern], given `pattern`:

1. Let `has protocol` be true.

2. Let `has hostname` be true.

3. Let `has port` be true.

4. Let `has pathname` be true.

5. Let `has search` be true.

6. If `pattern` matches the `network.UrlPatternPattern`
 production:

 1. Let `pattern url` be the empty string.

 2. If `pattern`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`protocol`\":

 1. If `pattern`\[\"`protocol`\"\] is the empty
 string, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 2. Let `protocol` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [unescape URL
 Pattern](#unescape-url-pattern) with
 `pattern`\[\"`protocol`\"\].

 3. For each `codepoint` in `protocol`:

 1. If `codepoint` is not [ASCII
 alphanumeric](https://infra.spec.whatwg.org/#ascii-alphanumeric) and «U+002B (+), U+002D (-), U+002E
 (.)» does not
 [contain](https://infra.spec.whatwg.org/#list-contain) `codepoint`:

 1. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) invalid argument.

 4. Append `protocol` to `pattern url`.

 3. Otherwise:

 1. Set `has protocol` to false.

 2. Append \"`http`\" to `pattern url`.

 4. Let `scheme` be [ASCII
 lowercase](https://infra.spec.whatwg.org/#ascii-lowercase) with `pattern url`.

 5. Append \"`:`\" to `pattern url`.

 6. If `scheme` [is
 special](https://url.spec.whatwg.org/#is-special), append \"`//`\" to `pattern url`.

 7. If `pattern`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`hostname`\":

 1. If `pattern`\[\"`hostname`\"\] is the empty
 string, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 2. If `scheme` is \"`file`\" return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 3. Let `hostname` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [unescape URL
 Pattern](#unescape-url-pattern) with
 `pattern`\[\"`hostname`\"\].

 4. Let `inside brackets` be false.

 5. For each `codepoint` in `hostname`:

 1. If «U+002F (/), U+003F (?), U+0023 (#)»
 [contains](https://infra.spec.whatwg.org/#list-contain) `codepoint`:

 1. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 2. If `inside brackets` is false and
 `codepoint` is U+003A (:):

 1. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 3. If `codepoint` is U+005B (\[), set
 `inside brackets` to true.

 4. If `codepoint` is U+005D (\]), set
 `inside brackets` to false.

 6. Append `hostname` to `pattern url`.

 8. Otherwise:

 1. If `scheme` is not \"`file`\", append
 \"`placeholder`\" to `pattern url`.

 2. Set `has hostname` to false.

 9. If `pattern`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`port`\":

 1. If `pattern`\[\"`port`\"\] is the empty string,
 return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 2. Let `port` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [unescape URL
 Pattern](#unescape-url-pattern) with `pattern`\[\"`port`\"\].

 3. Append \"`:`\" to `pattern url`.

 4. For each `codepoint` in `port`:

 1. If `codepoint` is not an [ASCII
 digit](https://infra.spec.whatwg.org/#ascii-digit):

 1. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 5. Append `port` to `pattern url`.

 10. Otherwise:

 1. Set `has port` to false.

 11. If `pattern`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`pathname`\":

 1. Let `pathname` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [unescape URL
 Pattern](#unescape-url-pattern) with
 `pattern`\[\"`pathname`\"\].

 2. If `pathname` does not [start
 with](https://infra.spec.whatwg.org/#string-starts-with) U+002F (/), then append \"`/`\" to
 `pattern url`.

 3. For each `codepoint` in `pathname`:

 1. If «U+003F (?), U+0023 (#)»
 [contains](https://infra.spec.whatwg.org/#list-contain) `codepoint`:

 1. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 4. Append `pathname` to `pattern url`.

 12. Otherwise:

 1. Set `has pathname` to false.

 13. If `pattern`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`search`\":

 1. Let `search` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [unescape URL
 pattern](#unescape-url-pattern) with `pattern`\[\"`search`\"\].

 2. If `search` does not [start
 with](https://infra.spec.whatwg.org/#string-starts-with) U+003F (?), then append \"`?`\" to
 `pattern url`.

 3. For each `codepoint` in `search`:

 1. If `codepoint` is U+0023 (#):

 1. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 4. Append `search` to `pattern url`.

 14. Otherwise:

 1. Set `has search` to false.

7. Otherwise, if `pattern` matches the
 `network.UrlPatternString` production:

 1. Let `pattern url` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [unescape URL
 pattern](#unescape-url-pattern) with `pattern`\[\"`pattern`\"\].

8. Let `url` be the result of
 [parsing](https://url.spec.whatwg.org/#concept-url-parser) `pattern url`.

9. If `url` is failure, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

10. Let `parsed` be a struct with the following fields:

 protocol
 : `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) if `has protocol` is true, or null
 otherwise.

 hostname
 : `url`'s
 [host](https://url.spec.whatwg.org/#concept-url-host) if `has hostname` is true, or null
 otherwise.

 port

 : 1. If `has port` is false:

 1. null.

 2. Otherwise:

 1. If `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) [is
 special](https://url.spec.whatwg.org/#is-special) and `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme)'s [default
 port](https://url.spec.whatwg.org/#default-port) is not null, and `url`'s
 [port](https://url.spec.whatwg.org/#concept-url-port) is null or is equal to
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme)'s [default
 port](https://url.spec.whatwg.org/#default-port):

 1. The empty string.

 2. Otherwise, if `url`'s
 [port](https://url.spec.whatwg.org/#concept-url-port) is not null:

 1. [Serialize an
 integer](#serialize-an-integer) with `url`'s
 [port](https://url.spec.whatwg.org/#concept-url-port).

 3. Otherwise:

 1. null.

 pathname

 : 1. If `has pathname` is false:

 1. null.

 2. Otherwise:

 1. The result of running the [URL path
 serializer](https://url.spec.whatwg.org/#url-path-serializer) with `url`, if
 `url`'s
 [path](https://url.spec.whatwg.org/#concept-url-path) is not the empty string and is not
 [empty](https://infra.spec.whatwg.org/#list-empty), or null otherwise.

 search

 : 1. If `has search` is false:

 1. null.

 2. Otherwise:

 1. The empty string if `url`'s
 [query](https://url.spec.whatwg.org/#concept-url-query) is null, or `url`'s
 [query](https://url.spec.whatwg.org/#concept-url-query) otherwise.

11. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `parsed`.

To [match URL pattern] given `url pattern` and
`url string`:

1. Let `url` be the result of
 [parsing](https://url.spec.whatwg.org/#concept-url-parser) `url string`.

2. If `url pattern`'s protocol is not null and is not equal
 to `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme), return false.

3. If `url pattern`'s hostname is not null and is not equal
 to `url`'s
 [host](https://url.spec.whatwg.org/#concept-url-host), return false.

4. If `url pattern`'s port is not null:

 1. Let `port` be null.

 2. If `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) [is
 special](https://url.spec.whatwg.org/#is-special) and `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme)'s [default
 port](https://url.spec.whatwg.org/#default-port) is not null, and `url`'s
 [port](https://url.spec.whatwg.org/#concept-url-port) is null or is equal to
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme)'s [default
 port](https://url.spec.whatwg.org/#default-port):

 1. Set `port` to the empty string.

 3. Otherwise, if `url`'s
 [port](https://url.spec.whatwg.org/#concept-url-port), is not null:

 1. Set `port` to [serialize an
 integer](#serialize-an-integer) with `url`'s
 [port](https://url.spec.whatwg.org/#concept-url-port).

 4. If `url pattern`'s port is not equal to
 `port`, return false.

5. If `url pattern`'s pathname is not null and is not equal
 to the result of running the [URL path
 serializer](https://url.spec.whatwg.org/#url-path-serializer) with `url`, return false.

6. If `url pattern`'s search is not null:

 1. Let `url query` be `url`'s
 [query](https://url.spec.whatwg.org/#concept-url-query).

 2. If `url query` is null, set `url query` to
 the empty string.

 3. If `url pattern`'s search is not equal to
 `url query`, return false.

7. Return true.

#### 7.5.5. Commands

##### 7.5.5.1. The network.addDataCollector Command

The [network.addDataCollector] adds a
[collector](#network-collector).

Command Type

: ```
 network.AddDataCollector = (
 method: "network.addDataCollector",
 params: network.AddDataCollectorParameters
 )

 network.AddDataCollectorParameters = {
 dataTypes: [+network.DataType],
 maxEncodedDataSize: js-uint,
 ? collectorType: network.CollectorType .default "blob",
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 }
 ```

Return Type

: ```
 network.AddDataCollectorResult = {
 collector: network.Collector
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `collector id` be the string representation of a
 [UUID](#biblio-rfc9562 "Universally Unique IDentifiers (UUIDs)").

2. Let `input context ids` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

3. If the `contexts` field of `command parameters` is
 present, set `input context ids` to [create a
 set](https://infra.spec.whatwg.org/#set-create) with `command parameters`\[`contexts`\].

4. Let `data types` be [create a
 set](https://infra.spec.whatwg.org/#set-create) with
 `command parameters`\[\"`dataTypes`\"\].

5. Let `max encoded item size` be
 `command parameters` \[\"`maxEncodedDataSize`\"\].

 The `maxEncodedDataSize` parameter represents [max
 encoded item
 size](#network-collector-max-encoded-item-size) and limits the size of each request collected by
 the given collector, not the total collector's collected size.

 Different implementations might support different
 encodings, which means the encoded size might be different between
 browsers. Therefore, for the same data collector configuration, some
 network data might fit the [max encoded item
 size](#network-collector-max-encoded-item-size) only in some implementations.

6. Let `collector type` be `command parameters`
 \[\"`collectorType`\"\].

7. Let `input user context ids` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

8. If the `userContexts` field of `command parameters` is
 present, set `input user context ids` to [create a
 set](https://infra.spec.whatwg.org/#set-create) with
 `command parameters`\[`userContexts`\].

9. If `input user context ids` is not empty and
 `input context ids` is not empty, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

10. If `max encoded item size` is 0 or
 `max encoded item size` is greater than [max total
 collected
 size](#max-total-collected-size), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

11. If `input context ids` is not
 [empty](https://infra.spec.whatwg.org/#list-empty):

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid navigables by
 ids](#get-valid-navigables-by-ids) with `input context ids`.

 2. For each `navigable` in `navigables`:

 1. If `navigable` is not a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

12. Otherwise, if `input user context ids` is not
 [empty](https://infra.spec.whatwg.org/#list-empty):

 1. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `user context id` of
 `input user context ids`:

 1. Let `user context` be [get user
 context](#get-user-context) with `user context id`.

 2. If `user context` is null, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such user
 context](#errors-no-such-user-context).

13. Let `collector` be a
 [collector](#network-collector) with [max encoded item
 size](#network-collector-max-encoded-item-size) field set to `max encoded item size`,
 [data
 types](#network-collector-data-types) field set to `data types`,
 [collector](#network-collector-collector) field set to `collector id`, [collector
 type](#network-collector-collector-type) field set to `collector type`,
 [contexts](#network-collector-contexts) field set to `input context ids`, [user
 contexts](#network-collector-user-contexts) field set to `input user context ids`.

14. Set `session`'s [network
 collectors](#network-collectors)\[`collector id`\] to
 `collector`.

15. Return a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `network.AddDataCollectorResult`
 production with the `collector` field set to
 `collector id`.

##### 7.5.5.2. The network.addIntercept Command

The [network.addIntercept] command adds a
[network intercept](#network-intercept).

Command Type

: ```
 network.AddIntercept = (
 method: "network.addIntercept",
 params: network.AddInterceptParameters
 )

 network.AddInterceptParameters = {
 phases: [+network.InterceptPhase],
 ? contexts: [+browsingContext.BrowsingContext],
 ? urlPatterns: [*network.UrlPattern],
 }

 network.InterceptPhase = "beforeRequestSent" / "responseStarted" /
 "authRequired"
 ```

Return Type

: ```
 network.AddInterceptResult = {
 intercept: network.Intercept
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `intercept` be the string representation of a
 [UUID](#biblio-rfc9562 "Universally Unique IDentifiers (UUIDs)").

2. Let `url patterns` be the `urlPatterns` field of
 `command parameters` if present, or an empty
 [list](https://infra.spec.whatwg.org/#list) otherwise.

3. Let `navigables` be null.

4. If the `contexts` field of `command parameters` is
 present:

 1. Set `navigables` to an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

 2. For each `navigable id` of
 `command parameters`\[\"`contexts`\"\]

 1. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

 2. If `navigable` is not a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 3. Append `navigable` to `navigables`.

 3. If `navigables` is an empty
 [set](https://infra.spec.whatwg.org/#ordered-set), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

5. Let `intercept map` be `session`'s [intercept
 map](#intercept-map).

6. Let `parsed patterns` be an empty
 [list](https://infra.spec.whatwg.org/#list).

7. For each `url pattern` in `url patterns`:

 1. Let `parsed` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [parse url
 pattern](#parse-url-pattern) with `url pattern`.

 2. [Append](https://infra.spec.whatwg.org/#list-append) `parsed` to
 `parsed patterns`.

8. Set `intercept map`\[`intercept`\] to a struct
 with `url patterns` `parsed patterns`, `phases`
 `command parameters`\[\"`phases`\"\] and
 `browsingContexts` `navigables`.

9. Return a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `network.AddInterceptResult`
 production with the `intercept` field set to `intercept`.

##### 7.5.5.3. The network.continueRequest Command

The [network.continueRequest] command
continues a request that's blocked by a [network
intercept](#network-intercept).

Command Type

: ```
 network.ContinueRequest = (
 method: "network.continueRequest",
 params: network.ContinueRequestParameters
 )

 network.ContinueRequestParameters = {
 request: network.Request,
 ?body: network.BytesValue,
 ?cookies: [*network.CookieHeader],
 ?headers: [*network.Header],
 ?method: text,
 ?url: text,
 }
 ```

Return Type

: ```
 network.ContinueRequestResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `blocked requests` be `session`'s [blocked
 request map](#blocked-request-map).

2. Let `request id` be
 `command parameters`\[\"`request`\"\].

3. If `blocked requests` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) `request id` then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 request](#errors-no-such-request).

4. Let (`request`, `phase`,
 `response`) be
 `blocked requests`\[`request id`\].

5. If `phase` is not \"`beforeRequestSent`\", then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 (#issue-674c4ab4) consider a
 \"`request already sent`\" error.

6. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`url`\":

 1. Let `url record` be the result of applying the [URL
 parser](https://url.spec.whatwg.org/#concept-url-parser) to
 `command parameters`\[\"`url`\"\], with [base
 URL](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script-base-url) null.

 2. If `url record` is failure, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 TODO: Should we also resume here?

 3. Let `request`'s
 [url](https://fetch.spec.whatwg.org/#concept-request-url) be `url record`.

7. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`method`\":

 1. Let `method` be
 `command parameters`\[\"`method`\"\].

 2. If `method` does not match the [method
 token](https://httpwg.org/specs/rfc9110.html#method.overview) production, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) \"`invalid argument`\".

 3. Let `request`'s
 [method](https://fetch.spec.whatwg.org/#concept-request-method) be `method`.

8. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`headers`\":

 1. Let `headers` be an empty [header
 list](https://fetch.spec.whatwg.org/#concept-header-list).

 2. For `header` in
 `command parameters`\[\"`headers`\"\]:

 1. Let `deserialized header` be [deserialize
 header](#deserialize-header) with `header`.

 2. If `deserialized header`'s name does not match
 the [field-name
 token](https://httpwg.org/specs/rfc9110.html#fields.names) production, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) \"`invalid argument`\".

 3. If `deserialized header`'s value does not match
 the [header
 value](https://fetch.spec.whatwg.org/#header-value) production, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) \"`invalid argument`\".

 4. Append `deserialized header` to
 `headers`.

 3. Set `request`'s [headers
 list](https://fetch.spec.whatwg.org/#concept-request-header-list) to `headers`.

9. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`cookies`\":

 1. Let `cookie header` be an empty [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence).

 2. For each `cookie` in
 `command parameters`\[\"`cookies`\"\]:

 1. If `cookie header` is not empty, append \``;`\`
 to `cookie header`.

 2. Append [serialize cookie
 header](#serialize-cookie-header) with `cookie` to
 `cookie header`.

 3. Let `found cookie header` be false.

 4. For each `header` in `request`'s [headers
 list](https://fetch.spec.whatwg.org/#concept-request-header-list):

 1. Let `name` be `header`'s name.

 2. If
 [byte-lowercase](https://infra.spec.whatwg.org/#byte-lowercase) `name` is \``cookie`\`:

 1. Set `header`'s value to
 `cookie header`.

 2. Set `found cookie header` to true.

 3. Break.

 5. If `found cookie header` is false:

 1. Append the
 [header](https://fetch.spec.whatwg.org/#concept-header) (\``Cookie`\`, `cookie header`)
 to `request`'s [headers
 list](https://fetch.spec.whatwg.org/#concept-request-header-list).

10. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`body`\":

 1. Let `body` be [deserialize protocol
 bytes](#deserialize-protocol-bytes) with
 `command parameters`\[\"`body`\"\].

 2. Set `request`'s
 [body](https://fetch.spec.whatwg.org/#concept-request-body) to `body`.

11. [Resume](#resume) with
 \"`continue request`\", `request id`, and (null,
 \"`incomplete`\").

12. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.5.5.4. The network.continueResponse Command

The [network.continueResponse] command
continues a response that's blocked by a [network
intercept](#network-intercept). It can be called in the `responseStarted` phase, to
modify the status and headers of the response, but still provide the
network response body.

Command Type

: ```
 network.ContinueResponse = (
 method: "network.continueResponse",
 params: network.ContinueResponseParameters
 )

 network.ContinueResponseParameters = {
 request: network.Request,
 ?cookies: [*network.SetCookieHeader]
 ?credentials: network.AuthCredentials,
 ?headers: [*network.Header],
 ?reasonPhrase: text,
 ?statusCode: js-uint,
 }
 ```

Return Type

: ```
 network.ContinueResponseResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `request id` be
 `command parameters`\[\"`request`\"\].

2. Let `response` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [update the
 response](#update-the-response) with `session`, \"`continueResponse`\"
 and `command parameters`.

3. [Resume](#resume) with
 \"`continue request`\", `request id`, and
 (`response`, \"`incomplete`\").

4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.5.5.5. The network.continueWithAuth Command

The [network.continueWithAuth] command
continues a response that's blocked by a [network
intercept](#network-intercept) at the `authRequired` phase.

Command Type

: ```
 network.ContinueWithAuth = (
 method: "network.continueWithAuth",
 params: network.ContinueWithAuthParameters
 )

 network.ContinueWithAuthParameters = {
 request: network.Request,
 (network.ContinueWithAuthCredentials // network.ContinueWithAuthNoCredentials)
 }

 network.ContinueWithAuthCredentials = (
 action: "provideCredentials",
 credentials: network.AuthCredentials
 )

 network.ContinueWithAuthNoCredentials = (
 action: "default" / "cancel"
 )
 ```

Return Type

: ```
 network.ContinueWithAuthResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `blocked requests` be `session`'s [blocked
 request map](#blocked-request-map).

2. Let `request id` be
 `command parameters`\[\"`request`\"\].

3. If `blocked requests` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) `request id` then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 request](#errors-no-such-request).

4. Let (`request`, `phase`,
 `response`) be
 `blocked requests`\[`request id`\].

5. If `phase` is not \"`authRequired`\", then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

6. If `command parameters` \"`action`\" is \"`cancel`\", set
 `response`'s authentication credentials to
 \"`cancelled`\".

7. If `command parameters` \"`action`\" is
 \"`provideCredentials`\":

 1. Let `credentials` be
 `command parameters`\[\"`credentials`\"\].

 2. Assert: `credentials`\[\"`type`\"\] is
 \"`password`\".

 3. Set `response`'s authentication credentials to
 (`credentials`\[\"`username`\"\],
 `credentials`\[\"`password`\"\])

8. [Resume](#resume) with
 \"`continue request`\", `request id`, and
 (`response`, \"`incomplete`\").

9. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.5.5.6. The network.disownData Command

The [network.disownData] command releases a
collected network data for a given
[collector](#network-collector).

Command Type

: ```
 network.DisownData = (
 method: "network.disownData",
 params: network.disownDataParameters
 )

 network.disownDataParameters = {
 dataType: network.DataType,
 collector: network.Collector,
 request: network.Request,
 }
 ```

Return Type

: ```
 network.DisownDataResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `data type` be the value of the \"`dataType`\" field
 in `command parameters`.

2. Let `collector id` be the value of the \"`collector`\"
 field in `command parameters`.

3. Let `request id` be the value of the \"`request`\" field
 in `command parameters`.

4. Let `collectors` be `session`'s [network
 collectors](#network-collectors).

5. If `collectors` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) `collector id`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such network
 collector](#errors-no-such-network-collector).

6. Let `collected data` be [get collected
 data](#get-collected-data) with `request id` and
 `data type`.

7. If `collected data` is null, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such network
 data](#errors-no-such-network-data).

8. [Remove collector from
 data](#remove-collector-from-data) with `collected data` and
 `collector id`.

9. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data
 [null](https://tc39.es/ecma262/#sec-null-value).

##### 7.5.5.7. The network.failRequest Command

The [network.failRequest] command fails a fetch
that's blocked by a [network
intercept](#network-intercept).

Command Type

: ```
 network.FailRequest = (
 method: "network.failRequest",
 params: network.FailRequestParameters
 )

 network.FailRequestParameters = {
 request: network.Request,
 }
 ```

Return Type

: ```
 network.FailRequestResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `blocked requests` be `session`'s [blocked
 request map](#blocked-request-map).

2. Let `request id` be
 `command parameters`\[\"`request`\"\].

3. If `blocked requests` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) `request id` then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 request](#errors-no-such-request).

4. Let (`request`, `phase`,
 `response`) be
 `blocked requests`\[`request id`\].

5. If `phase` is \"`authRequired`\", then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

6. Let `response` be a new [network
 error](https://fetch.spec.whatwg.org/#concept-network-error).

 (#issue-6015124b) Allow setting the precise kind of
 error [\[Issue
 #508\]](https://github.com/w3c/webdriver-bidi/issues/508)

7. [Resume](#resume) with
 \"`continue request`\", `request id`, and
 (`response`, \"`complete`\").

8. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.5.5.8. The network.getData Command

The [network.getData] command retrieves a network
data if it is available.

Command Type

: ```
 network.GetData = (
 method: "network.getData",
 params: network.GetDataParameters
 )

 network.GetDataParameters = {
 dataType: network.DataType,
 ? collector: network.Collector,
 ? disown: bool .default false,
 request: network.Request,
 }
 ```

Return Type

: ```
 network.GetDataResult = {
 bytes: network.BytesValue,
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `data type` be
 `command parameters`\[\"`dataType`\"\].

2. Let `request id` be
 `command parameters`\[\"`request`\"\].

3. Let `collector id` be null.

4. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`collector`\":

 1. Let `collectors` be `session`'s [network
 collectors](#network-collectors).

 2. If `collectors` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) `collector id`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such network
 collector](#errors-no-such-network-collector).

 3. Set `collector id` to
 `command parameters`\[\"`collector`\"\].

5. Let `disown` be
 `command parameters`\[\"`disown`\"\].

6. If `disown` is true and `collector id` is
 null, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

7. Let `collected data` be [get collected
 data](#get-collected-data) given `request id` and
 `data type`.

8. If `collected data` is null:

 1. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such network
 data](#errors-no-such-network-data).

9. If `collected data`'s
 [pending](#network-data-pending) is true:

 1. [Await](#awaits) with
 \"network data collected\" and (`request id`,
 `data type`).

10. If `collector id` is not null and if
 `collected data`'s
 [collectors](#network-data-collectors) does not
 [contain](https://infra.spec.whatwg.org/#list-contain) `collector id`:

 1. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such network
 data](#errors-no-such-network-data).

11. Let `bytes` be `collected data`'s
 [bytes](#network-data-bytes).

12. If `bytes` is null,

 1. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unavailable network
 data](#errors-unavailable-network-data).

13. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `network.GetDataResult` production,
 with the `bytes` field set to `bytes`.

14. If `disown` is true, [remove collector from
 data](#remove-collector-from-data) with `collected data` and
 `collector id`.

15. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

##### 7.5.5.9. The network.provideResponse Command

The [network.provideResponse] command
continues a request that's blocked by a [network
intercept](#network-intercept), by providing a complete response.

 This will not prevent the request going through the
normal request lifecycle, and therefore emitting other events as it
progresses.

Command Type

: ```
 network.ProvideResponse = (
 method: "network.provideResponse",
 params: network.ProvideResponseParameters
 )

 network.ProvideResponseParameters = {
 request: network.Request,
 ?body: network.BytesValue,
 ?cookies: [*network.SetCookieHeader],
 ?headers: [*network.Header],
 ?reasonPhrase: text,
 ?statusCode: js-uint,
 }
 ```

Return Type

: ```
 network.ProvideResponseResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `request id` be
 `command parameters`\[\"`request`\"\].

2. Let `response` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [update the
 response](#update-the-response) with `session`, \"`provideResponse`\",
 and `command parameters`.

3. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`body`\":

 1. Let `body` be [deserialize protocol
 bytes](#deserialize-protocol-bytes) with
 `command parameters`\[\"`body`\"\].

 2. Set `response`'s
 [body](https://fetch.spec.whatwg.org/#concept-response-body) to `body` [as a
 body](https://fetch.spec.whatwg.org/#byte-sequence-as-a-body).

4. [Resume](#resume) with
 \"`continue request`\", `request id`, and
 (`response`,\"`complete`\").

5. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.5.5.10. The network.removeDataCollector Command

The [network.removeDataCollector] command
removes a [collector](#network-collector).

Command Type

: ```
 network.RemoveDataCollector = (
 method: "network.removeDataCollector",
 params: network.RemoveDataCollectorParameters
 )

 network.RemoveDataCollectorParameters = {
 collector: network.Collector
 }
 ```

Return Type

: ```
 network.RemoveDataCollectorResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `collector id` be the value of the \"`collector`\"
 field in `command parameters`.

2. Let `collectors` be `session`'s [network
 collectors](#network-collectors).

3. If `collectors` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) `collector id`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such network
 collector](#errors-no-such-network-collector).

4. [Remove](https://infra.spec.whatwg.org/#map-remove) `collector id` from
 `session`'s [network
 collectors](#network-collectors).

5. For `collected data` in [collected network
 data](#collected-network-data), [remove collector from
 data](#remove-collector-from-data) with `collected data` and
 `collector id`.

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data
 [null](https://tc39.es/ecma262/#sec-null-value).

##### 7.5.5.11. The network.removeIntercept Command

The [network.removeIntercept] command
removes a [network
intercept](#network-intercept).

Command Type

: ```
 network.RemoveIntercept = (
 method: "network.removeIntercept",
 params: network.RemoveInterceptParameters
 )

 network.RemoveInterceptParameters = {
 intercept: network.Intercept
 }
 ```

Return Type

: ```
 network.RemoveInterceptResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `intercept` be the value of the \"`intercept`\" field
 in `command parameters`.

2. Let `intercept map` be `session`'s [intercept
 map](#intercept-map).

3. If `intercept map` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) `intercept`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 intercept](#errors-no-such-intercept).

4. [Remove](https://infra.spec.whatwg.org/#map-remove) `intercept` from
 `intercept map`.

 removal of an intercept does not affect requests that
have been already blocked by this intercept. Only future requests or
future phases of existing requests will be affected.

1. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data
 [null](https://tc39.es/ecma262/#sec-null-value).

##### 7.5.5.12. The network.setCacheBehavior Command

The [network.setCacheBehavior] command
configures the network cache behavior for certain requests.

Command Type

: ```
 network.SetCacheBehavior = (
 method: "network.setCacheBehavior",
 params: network.SetCacheBehaviorParameters
 )

 network.SetCacheBehaviorParameters = {
 cacheBehavior: "default" / "bypass",
 ? contexts: [+browsingContext.BrowsingContext]
 }
 ```

Return Type

: ```
 network.SetCacheBehaviorResult = EmptyResult
 ```

The [WebDriver BiDi cache behavior] steps given
[request](https://fetch.spec.whatwg.org/#concept-request) `request` are:

1. Let `navigable` be null.

2. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client) is an [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object):

 1. Let `environment settings` be `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client).

 2. If there is a
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) whose [active
 window](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-window) is `environment settings`' [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global), set `navigable` to that navigable's
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

3. If `navigable` is not null and [navigable cache behavior
 map](#navigable-cache-behavior-map)
 [contains](https://infra.spec.whatwg.org/#list-contain) `navigable`, return [navigable cache
 behavior
 map](#navigable-cache-behavior-map)\[`navigable`\].

4. Return [default cache
 behavior](#default-cache-behavior).

The [navigable cache behavior] steps given
`navigable` are:

1. Let `top-level navigable` be `navigable`'s
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

2. If [navigable cache behavior
 map](#navigable-cache-behavior-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `top-level navigable`, return [navigable
 cache behavior
 map](#navigable-cache-behavior-map)\[`top-level navigable`\].

3. Return [default cache
 behavior](#default-cache-behavior).

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `behavior` be
 `command parameters`\[\"`cacheBehavior`\"\].

2. If `command parameters` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\":

 1. Set the [default cache
 behavior](#default-cache-behavior) to `behavior`.

 2. [Clear](https://infra.spec.whatwg.org/#map-clear) [navigable cache behavior
 map](#navigable-cache-behavior-map).

 3. Switch on the value of behavior:

 \"`bypass`\"
 : Perform implementation-defined steps to disable any
 implementation-specific resource caches.

 \"`default`\"
 : Perform implementation-defined steps to enable any
 implementation-specific resource caches that are usually
 enabled in the current [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends) configuration.

 4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

3. Let `navigables` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

4. For each `navigable id` of
 `command parameters`\[\"`contexts`\"\]:

 1. Let `context` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

 2. If `context` is not a [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 3. [Append](https://infra.spec.whatwg.org/#list-append) `context` to
 `navigables`.

5. For each `navigable` in `navigables`:

 1. If [navigable cache behavior
 map](#navigable-cache-behavior-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `navigable`, and [navigable cache
 behavior
 map](#navigable-cache-behavior-map)\[`navigable`\] is equal to
 `behavior` then continue.

 2. Switch on the value of behavior:

 \"`bypass`\"
 : Perform implementation-defined steps to disable any
 implementation-specific resource caches for network requests
 originating from any browsing context for which
 `navigable` is the [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context).

 \"`default`\"
 : Perform implementation-defined steps to enable any
 implementation-specific resource caches that are usually
 enabled in the current [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends) configuration for network requests
 originating from any browsing context for which
 `navigable` is the [top-level browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-browsing-context).

 3. If `behavior` is equal to [default cache
 behavior](#default-cache-behavior):

 1. If [navigable cache behavior
 map](#navigable-cache-behavior-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `navigable`,
 [remove](https://infra.spec.whatwg.org/#map-remove) [navigable cache behavior
 map](#navigable-cache-behavior-map)\[`navigable`\].

 4. Otherwise:

 1. Set [navigable cache behavior
 map](#navigable-cache-behavior-map)\[`navigable`\] to
 `behavior`.

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.5.5.13. The network.setExtraHeaders Command

The [network.setExtraHeaders] command allows
specifying headers that will extend, or overwrite, existing request
headers.

Command Type

: ```
 network.SetExtraHeaders = (
 method: "network.setExtraHeaders",
 params: network.SetExtraHeadersParameters
 )

 network.SetExtraHeadersParameters = {
 headers: [*network.Header]
 ? contexts: [+browsingContext.BrowsingContext]
 ? userContexts: [+browser.UserContext]
 }
 ```

Return Type

: ```
 network.SetExtraHeadersResult = EmptyResult
 ```

To [update headers] given `request` and `headers`:

1. Let `request headers` be `request`'s [header
 list](https://fetch.spec.whatwg.org/#concept-request-header-list).

2. For each `header` in `headers`:

 1. [Set](https://fetch.spec.whatwg.org/#concept-header-list-set) `header` in
 `request headers`.

 This always overwrites the existing value, if
 any. In particular it doesn't append cookies to an existing
 \`Set-Cookie\` header.

To [update request headers] given `session`,
`request`, and `related navigables`:

1. Assert: `related navigables`'s
 [size](https://infra.spec.whatwg.org/#list-size) is 0 or 1.

 That means this will not work for workers
 associated with multiple navigables. In that case it's unclear in
 which order to override the headers.

2. [Update headers](#update-headers) with `request` and
 `session`'s [extra
 headers](#session-extra-headers)\' [default
 headers](#extra-headers-default-headers)

3. Let `user context headers` be `session`'s
 [extra
 headers](#session-extra-headers)\' [user context
 headers](#extra-headers-user-context-headers).

4. For `navigable` in `related navigables`:

 1. Let `user context` be `navigable`'s
 [associated user
 context](#associated-user-context).

 2. If `user context headers`
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context` then [update
 headers](#update-headers) with `request` and
 `user context headers`\[`user context`\]

5. Let `navigable headers` be `session`'s [extra
 headers](#session-extra-headers)\' [navigable
 headers](#extra-headers-navigable-headers).

6. For `navigable` in `related navigables`:

 1. Let `top-level traversable` be
 `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

 2. If `navigable headers` contains
 `top-level traversable` [update
 headers](#update-headers) with `request` and
 `navigable headers`\[`top-level traversable`\].

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. Let `headers` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [create a headers
 list](#create-a-headers-list) with
 `command parameters`\[\"`headers`\"\].

3. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\":

 1. Let `user contexts` be an empty
 [list](https://infra.spec.whatwg.org/#list).

 2. For `user context id` in
 `command parameters`\[\"`userContexts`\"\]:

 1. Let `user context` be [get user
 context](#get-user-context) with `user context id`.

 2. If `user context` is null, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such user
 context](#errors-no-such-user-context).

 3. [Append](https://infra.spec.whatwg.org/#list-append) `user context` to
 `user contexts`.

 3. Let `target` be `session`'s [extra
 headers](#session-extra-headers)\' [user context
 headers](#extra-headers-user-context-headers)

 4. For `user context` in `user contexts`:

 1. Set `target`\[`user context`\] to
 `headers`.

 5. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

4. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\":

 1. Let `navigables` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get valid top-level traversables by
 ids](#get-valid-top-level-traversables-by-ids) with
 `command parameters`\[\"`contexts`\"\].

 2. Let `target` be `session`'s [extra
 headers](#session-extra-headers)\' [navigable
 headers](#extra-headers-navigable-headers)

 3. For `navigable` in `navigables`:

 1. Set `target`\[`navigable`\] to
 `headers`.

 4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

5. Set `session`'s [extra
 headers](#session-extra-headers)\' [default
 headers](#extra-headers-default-headers) to `headers`.

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

#### 7.5.6. Events

##### 7.5.6.1. The network.authRequired Event

Event Type

: ```
 network.AuthRequired = (
 method: "network.authRequired",
 params: network.AuthRequiredParameters
 )

 network.AuthRequiredParameters = {
 network.BaseParameters,
 response: network.ResponseData
 }
 ```

This event is emitted when the user agent is going to prompt for
authorization credentials.

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi auth
required] steps given
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and
[response](https://fetch.spec.whatwg.org/#concept-response) `response`:

1. Let `redirect count` be `request`'s [redirect
 count](https://fetch.spec.whatwg.org/#concept-request-redirect-count).

2. Assert: [before request sent
 map](#before-request-sent-map)\[`request`\] is equal to
 `redirect count`.

 This implies that every caller needs to ensure that
 the [WebDriver BiDi before request
 sent](#webdriver-bidi-before-request-sent) steps are invoked with `request` before
 these steps.

3. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client) is not null, let `related navigables` be
 the result of [get related
 navigables](#get-related-navigables) with `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client). Otherwise let `related navigables` be
 an empty set.

4. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`network.authRequired`\" and
 `related navigables`:

 1. Let `params` be the result of [process a network
 event](#process-a-network-event) with `session`
 \"`network.authRequired`\", and `request`.

 2. Let `response data` be the result of [get the
 response
 data](#get-the-response-data) with `response`.

 3. Assert: `response data`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`authChallenge`\".

 4. Set the `response` field of `params` to
 `response data`.

 5. Assert: `params` matches the
 `network.AuthRequiredParameters` production.

 6. Let `body` be a map matching the
 `network.AuthRequired` production, with the `params` field set
 to `params`.

 7. [Emit an event](#emit-an-event) with `session` and
 `body`.

 8. If `params`\[\"`isBlocked`\"\] is true:

 1. Let `blocked requests` be `session`'s
 [blocked request
 map](#blocked-request-map).

 2. Let `request id` be `request`'s
 [request id](#request-id).

 3. Set `blocked requests`\[`request id`\]
 to (`request`, \"`authRequired`\",
 `response`).

 4. [Await](#awaits) with
 «\"`continue request`\"», and `request id`.

 5. [Remove](https://infra.spec.whatwg.org/#map-remove)
 `blocked requests`\[`request id`\].

##### 7.5.6.2. The network.beforeRequestSent Event

Event Type

: ```
 network.BeforeRequestSent = (
 method: "network.beforeRequestSent",
 params: network.BeforeRequestSentParameters
 )

 network.BeforeRequestSentParameters = {
 network.BaseParameters,
 ? initiator: network.Initiator,
 }
 ```

This event is emitted before a request is sent (either over the network
or before it's handled by a serviceworker or a local cache).

The steps to check if [request originates in user
context] given `request` and
`user context` are:

1. Let `settings` be `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client).

2. Let `related navigables` be [get related
 navigables](#get-related-navigables) with `settings`.

3. For `navigable` in `related navigables`:

 1. If `navigable`'s [associated user
 context](#associated-user-context) is `user context` return true.

4. Return false.

The steps to [get emulated network
conditions] given `related navigables` are:

1. For each `navigable` of `related navigables`:

 1. Let `top-level traversable` be
 `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

 2. Let `user context` be
 `top-level traversable`'s [associated user
 context](#associated-user-context).

 3. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If `session`'s [emulated network
 conditions](#session-emulated-network-conditions)'s [navigable network
 conditions](#emulated-network-conditions-navigable-network-conditions)
 [contains](https://infra.spec.whatwg.org/#map-exists) `top-level traversable`, return
 `session`'s [emulated network
 conditions](#session-emulated-network-conditions)'s [navigable network
 conditions](#emulated-network-conditions-navigable-network-conditions)\[`top-level traversable`\].

 4. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If `session`'s [emulated network
 conditions](#session-emulated-network-conditions)'s [user context network
 conditions](#emulated-network-conditions-user-context-network-conditions)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`, return
 `session`'s [emulated network
 conditions](#session-emulated-network-conditions)'s [user context network
 conditions](#emulated-network-conditions-user-context-network-conditions)\[`user context`\].

 5. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If `session`'s [emulated network
 conditions](#session-emulated-network-conditions)'s [default network
 conditions](#emulated-network-conditions-default-network-conditions) is not null, return `session`'s
 [emulated network
 conditions](#session-emulated-network-conditions)'s [default network
 conditions](#emulated-network-conditions-default-network-conditions).

2. Return null.

The [WebDriver BiDi network is
offline] steps given [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) `settings` are:

1. Let `navigable` be `settings`'s [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

2. Let `emulated network conditions` be the result of [get
 emulated network
 conditions](#get-emulated-network-conditions) with \[`navigable`\].

3. If `emulated network conditions` is not null and
 `emulated network conditions`'s
 [offline](#emulated-network-conditions-struct-offline) is true, return true.

4. Return false.

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi before request
sent] steps given
[request](https://fetch.spec.whatwg.org/#concept-request) `request`:

1. For each `user context` in the [set of user
 contexts](#set-of-user-contexts):

 1. If the [request originates in user
 context](#request-originates-in-user-context) steps with `request` and
 `user context` return true:

 1. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 `user context` can be in not
 more then one [user context to accept insecure certificates
 override
 map](#user-context-to-accept-insecure-certificates-override-map).

 1. If `session`'s [user context to accept
 insecure certificates override
 map](#user-context-to-accept-insecure-certificates-override-map)
 [contains](https://infra.spec.whatwg.org/#map-exists) `user context`:

 1. Let `accept insecure certificates` be
 `session`'s [user context to accept
 insecure certificates override
 map](#user-context-to-accept-insecure-certificates-override-map)\[`user context`\].

 2. If `accept insecure certificates` is
 true:

 1. Assert [endpoint
 node](https://w3c.github.io/webdriver/#dfn-endpoint-node) supports accepting insecure TLS
 connections.

 2. When running the [Basic Certificate
 Processing](https://datatracker.ietf.org/doc/html/rfc5280#section-6.1.3) steps for `request`,
 skip step a, along with any other
 implementation-defined certificate validation
 steps.

 3. Otherwise, when running the [Basic Certificate
 Processing](https://datatracker.ietf.org/doc/html/rfc5280#section-6.1.3) steps for `request`,
 perform all steps along with any
 implementation-defined certificate validation steps.

 `user context` can be in not
 more then one [user context to proxy configuration
 map](#user-context-to-proxy-configuration-map).

 1. If `session`'s [user context to proxy
 configuration
 map](#user-context-to-proxy-configuration-map)
 [contains](https://infra.spec.whatwg.org/#list-contain) `user context`:

 1. Let `proxy configuration` be
 `session`'s [user context to proxy
 configuration
 map](#user-context-to-proxy-configuration-map)\[`user context`\].

 2. Take implementation-defined steps to ensure that
 `request` uses the proxy settings defined
 by the `proxy configuration`.

 the settings are validated when the
 user context is created and so are assumed to be
 valid at this stage; any error accessing the proxy
 will be reported as a network error when handling
 the request.

2. [Maybe collect network request
 body](#maybe-collect-network-request-body) with `request`.

3. If [before request sent
 map](#before-request-sent-map) does not contain `request`, set [before
 request sent
 map](#before-request-sent-map)\[`request`\] to a new set.

4. Let `redirect count` be `request`'s [redirect
 count](https://fetch.spec.whatwg.org/#concept-request-redirect-count).

5. Add `redirect count` to [before request sent
 map](#before-request-sent-map)\[`request`\].

6. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client) is not null, let `related navigables` be
 the result of [get related
 navigables](#get-related-navigables) with `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client). Otherwise let `related navigables` be
 an empty set.

7. Let `response` be null.

8. Let `response status` be \"`incomplete`\".

9. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. [Update request
 headers](#update-request-headers) with `session`, `request`
 and `related navigables`.

10. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`network.beforeRequestSent`\" and
 `related navigables`:

 1. Let `params` be the result of [process a network
 event](#process-a-network-event) with `session`,
 \"`network.beforeRequestSent`\", and `request`.

 2. Let `initiator` be the result of [get the
 initiator](#get-the-initiator) with `request`.

 3. If `initiator` is not
 [empty](https://infra.spec.whatwg.org/#map-is-empty), set the `initiator` field of
 `params` to `initiator`.

 4. Assert: `params` matches the
 `network.BeforeRequestSentParameters` production.

 5. Let `body` be a map matching the
 `network.BeforeRequestSent` production, with the `params` field
 set to `params`.

 6. [Emit an event](#emit-an-event) with `session` and
 `body`.

 7. If `params`\[\"`isBlocked`\"\] is true, then:

 1. Let `blocked requests` be `session`'s
 [blocked request
 map](#blocked-request-map).

 2. Let `request id` be `request`'s
 [request id](#request-id).

 3. Set `blocked requests`\[`request id`\]
 to (`request`, \"`beforeRequestSent`\", null).

 4. Let (`response`, `status`) be
 [await](#awaits) with
 «\"`continue request`\"», and `request`'s
 [request id](#request-id).

 5. If `status` is \"`complete`\" set
 `response status` to `status`.

 6. [Remove](https://infra.spec.whatwg.org/#map-remove)
 `blocked requests`\[`request id`\].

 While waiting, no further processing of the
 request occurs.

11. Let `emulated network conditions` be the result of [get
 emulated network
 conditions](#get-emulated-network-conditions) with `related navigables`.

12. If `emulated network conditions` is not null and
 `emulated network conditions`'s
 [offline](#emulated-network-conditions-struct-offline) is true, return ([network
 error](https://fetch.spec.whatwg.org/#concept-network-error), \"`complete`\").

13. Return (`response`, `response status`).

Respect return value in Fetch's
\"HTTP-network-or-cache fetch\" algorithm.

##### 7.5.6.3. The network.fetchError Event

Event Type

: ```
 network.FetchError = (
 method: "network.fetchError",
 params: network.FetchErrorParameters
 )

 network.FetchErrorParameters = {
 network.BaseParameters,
 errorText: text,
 }
 ```

This event is emitted when a network request ends in an error.

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi fetch
error] steps given
[request](https://fetch.spec.whatwg.org/#concept-request) `request`:

1. If [before request sent
 map](#before-request-sent-map)\[`request`\] does not contain
 `request`'s [redirect
 count](https://fetch.spec.whatwg.org/#concept-request-redirect-count), then run the [WebDriver BiDi before request
 sent](#webdriver-bidi-before-request-sent) steps with `request`.

 This ensures that a `network.beforeRequestSent` can
 always be emitted before a `network.fetchError`, without the caller
 needing to explicitly invoke the [WebDriver BiDi before request
 sent](#webdriver-bidi-before-request-sent) steps on every error path.

2. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client) is not null, let `related navigables` be
 the result of [get related
 navigables](#get-related-navigables) with `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client). Otherwise let `related navigables` be
 an empty set.

3. [Maybe abort network response body
 collection](#maybe-abort-network-response-body-collection) with `request`.

4. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`network.fetchError`\" and
 `related navigables`:

 1. Let `params` be the result of [process a network
 event](#process-a-network-event) with `session`
 \"`network.fetchError`\", and `request`.

 2. Set the `errorText` field of `params` to an
 implementation-defined string describing the error which caused
 the request to be aborted.

 3. Assert: `params` matches the
 `network.FetchErrorParameters` production.

 4. Let `body` be a map matching the `network.FetchError`
 production, with the `params` field set to `params`.

 5. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.5.6.4. The network.responseCompleted Event

Event Type

: ```
 network.ResponseCompleted = (
 method: "network.responseCompleted",
 params: network.ResponseCompletedParameters
 )

 network.ResponseCompletedParameters = {
 network.BaseParameters,
 response: network.ResponseData,
 }
 ```

This event is emitted after the full response body is received.

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi response
completed] steps given
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and
[response](https://fetch.spec.whatwg.org/#concept-response) `response`:

1. Let `redirect count` be `request`'s [redirect
 count](https://fetch.spec.whatwg.org/#concept-request-redirect-count).

2. Assert: [before request sent
 map](#before-request-sent-map)\[`request`\] contains
 `redirect count`.

 This implies that every caller needs to ensure that
 the [WebDriver BiDi before request
 sent](#webdriver-bidi-before-request-sent) steps are invoked with `request` before
 these steps.

3. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client) is not null, let `related navigables` be
 the result of [get related
 navigables](#get-related-navigables) with `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client). Otherwise let `related navigables` be
 an empty set.

4. [Maybe collect network response
 body](#maybe-collect-network-response-body) with `request` and
 `response`.

5. Let `sessions` be the [set of sessions for which an event
 is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`network.responseCompleted`\" and
 `related navigables`.

6. For each `session` in `sessions`:

 1. Let `params` be the result of [process a network
 event](#process-a-network-event) with `session`
 \"`network.responseCompleted`\", and `request`.

 2. Assert: `params`\[\"`isBlocked`\"\] is false.

 3. Let `response data` be the result of [get the
 response
 data](#get-the-response-data) with `response`.

 4. Set the `response` field of `params` to
 `response data`.

 5. Assert: `params` matches the
 `network.ResponseCompletedParameters` production.

 6. Let `body` be a map matching the
 `network.ResponseCompleted` production, with the `params` field
 set to `params`.

 7. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.5.6.5. The network.responseStarted Event

Event Type

: ```
 network.ResponseStarted = (
 method: "network.responseStarted",
 params: network.ResponseStartedParameters
 )

 network.ResponseStartedParameters = {
 network.BaseParameters,
 response: network.ResponseData,
 }
 ```

This event is emitted after the response headers are received but before
the body is complete.

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi response
started] steps given
[request](https://fetch.spec.whatwg.org/#concept-request) `request` and
[response](https://fetch.spec.whatwg.org/#concept-response) `response`:

1. Let `redirect count` be `request`'s [redirect
 count](https://fetch.spec.whatwg.org/#concept-request-redirect-count).

2. Assert: [before request sent
 map](#before-request-sent-map)\[`request`\] is equal to
 `redirect count`.

 This implies that every caller needs to ensure that
 the [WebDriver BiDi before request
 sent](#webdriver-bidi-before-request-sent) steps are invoked with `request` before
 these steps.

3. If `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client) is not null, let `related navigables` be
 the result of [get related
 navigables](#get-related-navigables) with `request`'s
 [client](https://fetch.spec.whatwg.org/#concept-request-client). Otherwise let `related navigables` be
 an empty set.

4. Let `response status` be \"`incomplete`\".

5. [Clone network response
 body](#clone-network-response-body) with `request` and
 `response`.

6. Let `sessions` be the [set of sessions for which an event
 is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`network.responseStarted`\" and
 `related navigables`.

7. For each `session` in `sessions`:

 1. Let `params` be the result of [process a network
 event](#process-a-network-event) with `session`
 \"`network.responseStarted`\", and `request`.

 2. Let `response data` be the result of [get the
 response
 data](#get-the-response-data) with `response`.

 3. Set the `response` field of `params` to
 `response data`.

 4. Assert: `params` matches the
 `network.ResponseStartedParameters` production.

 5. Let `body` be a map matching the
 `network.ResponseStarted` production, with the `params` field
 set to `params`.

 6. [Emit an event](#emit-an-event) with `session` and
 `body`.

 7. If `params`\[\"`isBlocked`\"\] is true:

 1. Let `blocked requests` be `session`'s
 [blocked request
 map](#blocked-request-map).

 2. Let `request id` be `request`'s
 [request id](#request-id).

 3. Set `blocked requests`\[`request id`\]
 to (`request`, \"`beforeRequestSent`\",
 `response`).

 4. Let (`response`, `status`) be
 [await](#awaits) with
 «\"`continue request`\"», and `request id`.

 5. If `status` is \"`complete`\", set
 `response status` to `status`.

 6. [Remove](https://infra.spec.whatwg.org/#map-remove)
 `blocked requests`\[`request id`\].

8. Return (`response`, `response status`).

### 7.6. The script Module

The [script] module contains commands and events relating
to script realms and execution.

#### 7.6.1. Definition

[`Remote end definition`](#cddl-module-remote-end-definition)

```
ScriptCommand = (
 script.AddPreloadScript //
 script.CallFunction //
 script.Disown //
 script.Evaluate //
 script.GetRealms //
 script.RemovePreloadScript
)
```

[`local end definition`](#cddl-module-local-end-definition)

```
ScriptResult = (
 script.AddPreloadScriptResult /
 script.CallFunctionResult /
 script.DisownResult /
 script.EvaluateResult /
 script.GetRealmsResult /
 script.RemovePreloadScriptResult
)

ScriptEvent = (
 script.Message //
 script.RealmCreated //
 script.RealmDestroyed
)
```

#### 7.6.2. Preload Scripts

A [Preload script] is one which runs on creation of a new
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), before any author-defined script have run.

TODO: Extend this to scripts in other kinds of realms.

A [BiDi session](#bidi-session)
has a [preload script map] which is a
[map](https://infra.spec.whatwg.org/#ordered-map) in which the keys are
[UUID](#biblio-rfc9562 "Universally Unique IDentifiers (UUIDs)")s,
and the values are
[structs](https://infra.spec.whatwg.org/#struct) with an
[item](https://infra.spec.whatwg.org/#struct-item) named `function declaration`, which is a string, an
[item](https://infra.spec.whatwg.org/#struct-item) named `arguments`, which is a list, an
[item](https://infra.spec.whatwg.org/#struct-item) named `contexts`, which is a list or null, an
[item](https://infra.spec.whatwg.org/#struct-item) named `sandbox`, which is a string or null, and an
[item](https://infra.spec.whatwg.org/#struct-item) named `user contexts`, which is a
[set](https://infra.spec.whatwg.org/#ordered-set).

 If executing a [preload
script](#preload-script)
fails, either due to a syntax error, or a runtime exception, an
[\[ECMAScript\]](#biblio-ecmascript "ECMAScript Language Specification")
exception is reported in the realm in which it was being executed, and
other preload scripts run as normal.

To [run WebDriver BiDi preload
scripts] given `environment settings`:

1. Let `document` be `environment settings`'
 [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

2. Let `navigable` be `document`'s
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables).

3. Let `user context` be `navigable`'s
 [associated user
 context](#associated-user-context).

4. Let `user context id` be `user context`'s
 [user context
 id](#user-context-user-context-id).

5. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. For each `preload script` in `session`'s
 [preload script
 map](#preload-script-map)'s
 [values](https://infra.spec.whatwg.org/#map-getting-the-values):

 1. If `preload script`'s `user contexts`'s
 [size](https://infra.spec.whatwg.org/#list-size) is not zero:

 1. If `preload script`'s `user contexts` does
 not
 [contain](https://infra.spec.whatwg.org/#list-contain) `user context id`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. If `preload script`'s `contexts` is not null:

 1. Let `navigable id` be
 `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top)'s id.

 2. If `preload script`'s `contexts` does not
 [contain](https://infra.spec.whatwg.org/#list-contain) `navigable id`,
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. If `preload script`'s `sandbox` is not null, let
 `realm` be [get or create a sandbox
 realm](#get-or-create-a-sandbox-realm) with `preload script`'s
 `sandbox` and `navigable`. Otherwise let
 `realm` be `environment settings`'
 [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component.

 4. Let `exception reporting global` be be
 `environment settings`' [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component's [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global).

 5. Let `arguments` be `preload script`'s
 `arguments`.

 6. Let `deserialized arguments` be an empty list.

 7. For each `argument` in `arguments`:

 1. Let `channel` be [create a
 channel](#create-a-channel) with `session`,
 `realm` and `argument`.

 2. Append `channel` to
 `deserialized arguments`.

 8. Let `base URL` be the [API base
 URL](https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url) of `environment settings`.

 9. Let `options` be the [default script fetch
 options](https://html.spec.whatwg.org/multipage/webappapis.html#default-script-fetch-options).

 10. Let `function declaration` be
 `preload script`'s `function declaration`.

 11. Let (`script`,
 `function body evaluation status`) be the result
 of [evaluate function
 body](#evaluate-function-body) with `function declaration`,
 `environment settings`, `base URL`,
 and `options`.

 12. If `function body evaluation status` is an
 [abrupt
 completion](https://tc39.es/ecma262/#sec-completion-record-specification-type), then [report an
 exception](https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception) given by
 `function body evaluation status`.\[\[Value\]\]
 for `exception reporting global`.

 13. Let `function object` be
 `function body evaluation status`.\[\[Value\]\].

 14. If
 [IsCallable](https://tc39.es/ecma262/#sec-iscallable)(`function object`) is `false`:

 1. Let `error` be a new
 [TypeError](https://webidl.spec.whatwg.org/#exceptiondef-typeerror) object in
 `realm`.

 2. [Report an
 exception](https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception) `error` for
 `exception reporting global`.

 15. [Prepare to run
 script](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-script) with `environment settings`.

 16. Set `evaluation status` to
 [Call](https://tc39.es/ecma262/#sec-call)(`function object`, null,
 `deserialized arguments`).

 17. [Clean up after running
 script](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script) with `environment settings`.

 18. If `evaluation status` is an [abrupt
 completion](https://tc39.es/ecma262/#sec-completion-record-specification-type), then [report an
 exception](https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception) given by
 `evaluation status`.\[\[Value\]\] for
 `exception reporting global`.

#### 7.6.3. Types

##### 7.6.3.1. The script.Channel Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.Channel = text;
```

The [`script.Channel`] type represents the id of a specific channel used to send
custom messages from the [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) to the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends).

##### 7.6.3.2. The script.ChannelValue Type

[`Remote end definition`](#cddl-module-remote-end-definition)

```
script.ChannelValue = {
 type: "channel",
 value: script.ChannelProperties,
}

script.ChannelProperties = {
 channel: script.Channel,
 ? serializationOptions: script.SerializationOptions,
 ? ownership: script.ResultOwnership,
}
```

The `script.ChannelValue` type represents an `ArgumentValue` that can be
deserialized into a function that sends messages from the [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) to the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends).

To [create a channel] given `session`, `realm` and
`protocol value`:

1. Let `channel properties` be
 `protocol value`\[\"`value`\"\].

2. Let `steps` be the following steps given the argument
 `message`:

 1. Let `current realm` be the [current Realm
 Record](https://tc39.es/ecma262/#current-realm).

 2. [Emit a script
 message](#emit-a-script-message) with `session`,
 `current realm`, `channel properties` and
 `message`.

3. Return
 [CreateBuiltinFunction](https://tc39.es/ecma262/#sec-createbuiltinfunction)(`steps`, 1, \"\", « »,
 `realm`).

##### 7.6.3.3. The script.EvaluateResult Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.EvaluateResult = (
 script.EvaluateResultSuccess /
 script.EvaluateResultException
)

script.EvaluateResultSuccess = {
 type: "success",
 result: script.RemoteValue,
 realm: script.Realm
}

script.EvaluateResultException = {
 type: "exception",
 exceptionDetails: script.ExceptionDetails
 realm: script.Realm
}
```

The `script.EvaluateResult` type indicates the return value of a command
that executes script. The `script.EvaluateResultSuccess` variant is used
in cases where the script completes normally and the
`script.EvaluateResultException` variant is used in cases where the
script completes with a thrown exception.

##### 7.6.3.4. The script.ExceptionDetails Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.ExceptionDetails = {
 columnNumber: js-uint,
 exception: script.RemoteValue,
 lineNumber: js-uint,
 stackTrace: script.StackTrace,
 text: text,
}
```

The `script.ExceptionDetails` type represents a JavaScript exception.

To [get exception details] given a `realm`, a [completion
record](https://tc39.es/ecma262/#sec-completion-record-specification-type) `record`, an
`ownership type` and a `session`:

1. Assert: `record`.\[\[Type\]\] is `throw`.

2. Let `text` be an implementation-defined textual
 description of the error represented by `record`.

 TODO: Tighten up the requirements here; people will probably try to
 parse this data with regex or something equally bad.

3. Let `serialization options` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.SerializationOptions`
 production with the fields set to their default values.

4. Let `exception` be the result of [serialize as a remote
 value](#serialize-as-a-remote-value) with `record`.\[\[Value\]\],
 `serialization options`, `ownership type`, a
 new
 [map](https://infra.spec.whatwg.org/#ordered-map) as serialization internal map, `realm`
 and `session`.

5. Let `stack trace` be the [stack trace for an
 exception](#stack-trace-for-an-exception) given `record`.

6. If `stack trace` has size of 1 or greater, let
 `line number` be value of the `lineNumber` field in
 `stack trace`\[0\], and let `column number` be
 the value of the `columnNumber` field `stack trace`\[0\].
 Otherwise let `line number` and
 `column number` be 0.

7. Let `exception details` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.ExceptionDetails` production,
 with the `text` field set to `text`, the `exception`
 field set to `exception`, the `lineNumber` field set to
 `line number`, the `columnNumber` field set to
 `column number`, and the `stackTrace` field set to
 `stack trace`.

8. Return `exception details`.

##### 7.6.3.5. The script.Handle Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.Handle = text;
```

The `script.Handle` type represents a handle to an object owned by the
ECMAScript runtime. The handle is only valid in a specific
[Realm](https://tc39.es/ecma262/#sec-code-realms).

Each ECMAScript
[Realm](https://tc39.es/ecma262/#sec-code-realms) has a corresponding [handle object
map].
This is a strong
[map](https://infra.spec.whatwg.org/#ordered-map) from handle ids to their corresponding objects.

##### 7.6.3.6. The script.InternalId Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.InternalId = text;
```

The `script.InternalId` type represents the id of a previously
serialized `script.RemoteValue` during
[serialization](#serialize-as-a-remote-value).

##### 7.6.3.7. The script.LocalValue Type

[`Remote end definition`](#cddl-module-remote-end-definition)

```
script.LocalValue = (
 script.RemoteReference /
 script.PrimitiveProtocolValue /
 script.ChannelValue /
 script.ArrayLocalValue /
 { script.DateLocalValue } /
 script.MapLocalValue /
 script.ObjectLocalValue /
 { script.RegExpLocalValue } /
 script.SetLocalValue
)

script.ListLocalValue = [*script.LocalValue];

script.ArrayLocalValue = {
 type: "array",
 value: script.ListLocalValue,
}

script.DateLocalValue = (
 type: "date",
 value: text
)

script.MappingLocalValue = [*[(script.LocalValue / text), script.LocalValue]];

script.MapLocalValue = {
 type: "map",
 value: script.MappingLocalValue,
}

script.ObjectLocalValue = {
 type: "object",
 value: script.MappingLocalValue,
}

script.RegExpValue = {
 pattern: text,
 ? flags: text,
}

script.RegExpLocalValue = (
 type: "regexp",
 value: script.RegExpValue,
)

script.SetLocalValue = {
 type: "set",
 value: script.ListLocalValue,
}
```

The [`script.LocalValue`] type represents values which can be
deserialized into ECMAScript. This includes both primitive and
non-primitive values as well as [remote
references](#scriptremotereference) and [channels](#scriptchannel).

To [deserialize key-value list] given
`serialized key-value list`, `realm` and
`session`:

1. Let `deserialized key-value list` be a new list.

2. For each `serialized key-value` in the
 `serialized key-value list`:

 1. If
 [size](https://infra.spec.whatwg.org/#list-size) of `serialized key-value` is not 2,
 return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 2. Let `serialized key` be
 `serialized key-value`\[0\].

 3. If `serialized key` is a `string`, let
 `deserialized key` be `serialized key`.

 4. Otherwise let `deserialized key` be result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to given [deserialize local
 value](#deserialize-local-value) with `serialized key`,
 `realm` and `session`.

 5. Let `serialized value` be
 `serialized key-value`\[1\].

 6. Let `deserialized value` be result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize local
 value](#deserialize-local-value) given `serialized value`,
 `realm` and `session`.

 7. Append
 [CreateArrayFromList](https://tc39.es/ecma262/#sec-createarrayfromlist)(«`deserialized key`,
 `deserialized value`») to
 `deserialized key-value list`.

3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `deserialized key-value list`.

To [deserialize value list] given `serialized value list`,
`realm` and `session`:

1. Let `deserialized values` be a new list.

2. For each `serialized value` in the
 `serialized value list`:

 1. Let `deserialized value` be result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize local
 value](#deserialize-local-value) given `serialized value`,
 `realm` and `session`.

 2. Append `deserialized value` to
 `deserialized values`;

3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `deserialized values`.

To [deserialize local value] given `local protocol value`,
`realm` and `session`:

1. If `local protocol value` matches the
 [script.RemoteReference](#scriptremotereference) production, return [deserialize remote
 reference](#deserialize-remote-reference) of given `local protocol value`,
 `realm` and `session`.

2. If `local protocol value` matches the
 [script.PrimitiveProtocolValue](#scriptprimitiveprotocolvalue) production, return [deserialize primitive protocol
 value](#deserialize-primitive-protocol-value) with `local protocol value`.

3. If `local protocol value` matches the
 `script.ChannelValue` production, return [create a
 channel](#create-a-channel) with `session`, `realm` and
 `local protocol value`.

4. Let `type` be the value of the `type` field of
 `local protocol value` or undefined if no such a field.

5. Let `value` be the value of the `value` field of
 `local protocol value` or undefined if no such a field.

6. In the following list of conditions and associated steps, run the
 first set of steps for which the associated condition is true:

 `type` is the string \"`array`\"

 : 1. Let `deserialized value list` be a result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize value
 list](#deserialize-value-list) given `value`,
 `realm` and `session`.

 2. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data
 [CreateArrayFromList](https://tc39.es/ecma262/#sec-createarrayfromlist)(`deserialized value list`).

 `type` is the string \"`date`\"

 : 1. If `value` does not match [Date Time String
 Format](https://tc39.es/ecma262/#sec-date-time-string-format), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 2. Let `date result` be
 [Construct](https://tc39.es/ecma262/#sec-construct)([Date](https://tc39.es/ecma262/#sec-date-constructor), `value`).

 3. Assert: `date result` is not an [abrupt
 completion](https://tc39.es/ecma262/#sec-completion-record-specification-type).

 4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `date result`.

 `type` is the string \"`map`\"

 : 1. Let `deserialized key-value list` be a result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize key-value
 list](#deserialize-key-value-list) with `value`, `realm`
 and `session`.

 2. Let `iterable` be
 [CreateArrayFromList](https://tc39.es/ecma262/#sec-createarrayfromlist)(`deserialized key-value list`)

 3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data
 [Map](https://tc39.es/ecma262/#sec-map-iterable)(`iterable`).

 `type` is the string \"`object`\"

 : 1. Let `deserialized key-value list` be a result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize key-value
 list](#deserialize-key-value-list) with `value`, `realm`
 and `session`.

 2. Let `iterable` be
 [CreateArrayFromList](https://tc39.es/ecma262/#sec-createarrayfromlist)(`deserialized key-value list`)

 3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data
 [Object.fromEntries](https://tc39.es/ecma262/#sec-object.fromentries)(`iterable`).

 `type` is the string \"`regexp`\"

 : 1. Let `pattern` be the value of the `pattern` field
 of `local protocol value`.

 2. Let `flags` be the value of the `flags` field of
 `local protocol value` or undefined if no such a
 field.

 3. Let `regex_result` be
 [Regexp](https://tc39.es/ecma262/#sec-regexp-pattern-flags)(`pattern`, `flags`).
 If this throws exception, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `regex_result`.

 `type` is the string \"`set`\"

 : 1. Let `deserialized value list` be a result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize value
 list](#deserialize-value-list) given `value`,
 `realm` and `session`.

 2. Let `iterable` be
 [CreateArrayFromList](https://tc39.es/ecma262/#sec-createarrayfromlist)(`deserialized key-value list`)

 3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data [Set
 object](https://tc39.es/ecma262/#sec-set-objects)(`iterable`).

 otherwise
 : Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

##### 7.6.3.8. The script.PreloadScript Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.PreloadScript = text;
```

The `script.PreloadScript` type represents a handle to a script that
will run on realm creation.

##### 7.6.3.9. The script.Realm Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.Realm = text;
```

Each
[realm](https://tc39.es/ecma262/#sec-code-realms) has an associated [realm id], which is a string uniquely
identifying that realm. This is implicitly set when the realm is
created.

The [realm id](#realm-id) for a realm
is opaque and must not be derivable from the handle id of the
corresponding global object in the [handle object
map](#handle-object-map) or,
where relevant, from the [navigable
id](#navigable-id) of any
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables).

 this is to ensure that users do not rely on
implementation-specific relationships between different ids.

To [get a realm] given `realm id`:

1. If `realm id` is null, return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

2. If there is no
 [realm](https://tc39.es/ecma262/#sec-code-realms) with [id](#realm-id) `realm id` return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 frame](https://w3c.github.io/webdriver/#dfn-no-such-frame)

3. Let `realm` be the
 [realm](https://tc39.es/ecma262/#sec-code-realms) with [id](#realm-id) `realm id`.

4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `realm`

This has the wrong error code

##### 7.6.3.10. The script.PrimitiveProtocolValue Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.PrimitiveProtocolValue = (
 script.UndefinedValue /
 script.NullValue /
 script.StringValue /
 script.NumberValue /
 script.BooleanValue /
 script.BigIntValue
)

script.UndefinedValue = {
 type: "undefined",
}

script.NullValue = {
 type: "null",
}

script.StringValue = {
 type: "string",
 value: text,
}

script.SpecialNumber = "NaN" / "-0" / "Infinity" / "-Infinity";

script.NumberValue = {
 type: "number",
 value: number / script.SpecialNumber,
}

script.BooleanValue = {
 type: "boolean",
 value: bool,
}

script.BigIntValue = {
 type: "bigint",
 value: text,
}
```

The [script.PrimitiveProtocolValue] represents values which can
only be represented by value, never by reference.

To [serialize primitive protocol
value] given a `value`:

1. Let `remote value` be undefined.

2. In the following list of conditions and associated steps, run the
 first set of steps for which the associated condition is true, if
 any:

 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is undefined
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.UndefinedValue` production
 in the
 [`local end definition`](#cddl-module-local-end-definition).

 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is Null
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.NullValue` production in
 the
 [`local end definition`](#cddl-module-local-end-definition).

 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is String

 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.StringValue` production in
 the
 [`local end definition`](#cddl-module-local-end-definition), with the `value` property set to
 `value`.

 (#issue-d33a79cf) This doesn't handle lone
 surrogates

 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is Number

 : 1. Switch on the value of `value`:

 NaN
 : Let `serialized` be `"NaN"`

 -0
 : Let `serialized` be `"-0"`

 Infinity
 : Let `serialized` be `"Infinity"`

 -Infinity
 : Let `serialized` be `"-Infinity"`

 Otherwise:
 : Let `serialized` be `value`

 2. Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.NumberValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `value` property set to
 `serialized`.

 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is Boolean
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.BooleanValue` production
 in the
 [`local end definition`](#cddl-module-local-end-definition), with the `value` property set to
 `value`.

 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is BigInt
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.BigIntValue` production in
 the
 [`local end definition`](#cddl-module-local-end-definition), with the `value` property set to the result
 of running the
 [ToString](https://tc39.es/ecma262/#sec-tostring) operation on `value`.

3. Return `remote value`

To [deserialize primitive protocol
value] given a
`primitive protocol value`:

1. Let `type` be the value of the `type` field of
 `primitive protocol value`.

2. Let `value` be undefined.

3. If `primitive protocol value` has field `value`:

 1. Let `value` be the value of the `value` field of
 `primitive protocol value`.

4. In the following list of conditions and associated steps, run the
 first set of steps for which the associated condition is true:

 `type` is the string \"`undefined`\"
 : Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data
 [undefined](https://tc39.es/ecma262/#sec-undefined-value).

 `type` is the string \"`null`\"
 : Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data
 [null](https://tc39.es/ecma262/#sec-null-value).

 `type` is the string \"`string`\"
 : Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `value`.

 `type` is the string \"`number`\"

 : 1. If
 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is Number, return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `value`.

 2. Assert:
 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is String.

 3. If `value` is the string \"`NaN`\", return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data NaN.

 4. Let `number_result` be
 [StringToNumber](https://tc39.es/ecma262/#sec-stringtonumber)(`value`).

 5. If `number_result` is NaN, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument)

 6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `number_result`.

 `type` is the string \"`boolean`\"
 : Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `value`.

 `type` is the string \"`bigint`\"

 : 1. Let `bigint_result` be
 [StringToBigInt](https://tc39.es/ecma262/#sec-stringtobigint)(`value`).

 2. If `bigint_result` is undefined, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument)

 3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `bigint_result`.

5. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument)

##### 7.6.3.11. The script.RealmInfo Type

[`Local end definition`](#cddl-module-local-end-definition)

```
script.RealmInfo = (
 script.WindowRealmInfo /
 script.DedicatedWorkerRealmInfo /
 script.SharedWorkerRealmInfo /
 script.ServiceWorkerRealmInfo /
 script.WorkerRealmInfo /
 script.PaintWorkletRealmInfo /
 script.AudioWorkletRealmInfo /
 script.WorkletRealmInfo
)

script.BaseRealmInfo = (
 realm: script.Realm,
 origin: text
)

script.WindowRealmInfo = {
 script.BaseRealmInfo,
 type: "window",
 context: browsingContext.BrowsingContext,
 ? sandbox: text
}

script.DedicatedWorkerRealmInfo = {
 script.BaseRealmInfo,
 type: "dedicated-worker",
 owners: [script.Realm]
}

script.SharedWorkerRealmInfo = {
 script.BaseRealmInfo,
 type: "shared-worker"
}

script.ServiceWorkerRealmInfo = {
 script.BaseRealmInfo,
 type: "service-worker"
}

script.WorkerRealmInfo = {
 script.BaseRealmInfo,
 type: "worker"
}

script.PaintWorkletRealmInfo = {
 script.BaseRealmInfo,
 type: "paint-worklet"
}

script.AudioWorkletRealmInfo = {
 script.BaseRealmInfo,
 type: "audio-worklet"
}

script.WorkletRealmInfo = {
 script.BaseRealmInfo,
 type: "worklet"
}
```

 there's a 1:1 relationship between the
`script.RealmInfo` variants and values of `script.RealmType`.

The `script.RealmInfo` type represents the properties of a realm.

To [get the navigable] with given `realm`:

1. Let `global object` be the [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global) of the `realm`.

2. Let `global object` be the
 [unwrapped](#unwrapped)
 `global object`.

3. If `global object` is not a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object, return `null`.

4. Let `document` be `global object`'s wrapped
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

5. Return `document`'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

To [get the worker's owners] with given `global object`:

1. Assert: `global object` is a
 [`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope) object.

2. Let `owners` be an empty
 [list](https://infra.spec.whatwg.org/#list).

3. For each `owner` in the `global object`'s
 associated [owner
 set](https://html.spec.whatwg.org/multipage/workers.html#concept-WorkerGlobalScope-owner-set):

 1. Let `owner environment settings` be
 `owner`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object).

 2. Let `owner realm info` be the result of [get the
 realm info](#get-the-realm-info) given `owner environment settings`.

 3. If `owner realm info` is null, continue.

 4. Append `owner realm info`\[\"`id`\"\] to
 `owners`.

4. Return `owners`.

To [get the realm info] given `environment settings`:

1. Let `realm` be `environment settings`' [realm
 execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component.

2. Let `realm id` be the [realm
 id](#realm-id) for
 `realm`.

3. Let `origin` be the [serialization of an
 origin](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) given `environment settings`'s
 `origin`.

4. Let `global object` be the [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global) specified by `environment settings`

5. Run the steps under the first matching condition:

 `global object` is a [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object

 : 1. Let `document` be
 `environment settings`' [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

 2. Let `navigable` be `document`'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

 3. If `navigable` is null, return null.

 4. Let `navigable id` be the [navigable
 id](#navigable-id)
 for `navigable`.

 5. Let `realm info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.WindowRealmInfo`
 production, with the `realm` field set to
 `realm id`, the `origin` field set to
 `origin`, and the `context` field set to
 `navigable id`.

 `global object` is [`SandboxWindowProxy`](#sandboxwindowproxy) object
 : TODO: Unclear if this is the right formulation for handling
 sandboxes.
 1. Let `document` be `global object`'s
 wrapped
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

 2. Let `navigable` be `document`'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

 3. If `navigable` is null, return null.

 4. Let `navigable id` be the [navigable
 id](#navigable-id)
 for `navigable`.

 5. Let `sandbox name` be the result of [get a
 sandbox
 name](#get-a-sandbox-name) given `realm`.

 6. Assert: `sandbox name` is not null.

 7. Let `realm info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.WindowRealmInfo`
 production, with the `realm` field set to
 `realm id`, the `origin` field set to
 `origin`, the `context` field set to
 `navigable id`, and the `sandbox` field set to
 `sandbox name`.

 `global object` is a [`DedicatedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#dedicatedworkerglobalscope) object

 : 1. Let `owners` be the result of [get the worker's
 owners](#get-the-workers-owners) given `global object`.

 2. Assert: `owners` has precisely one item.

 3. Let `realm info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `script.DedicatedWorkerRealmInfo` production, with the
 `realm` field set to `realm id`, the `origin`
 field set to `origin`, and the `owners` field set
 to `owners`.

 `global object` is a [`SharedWorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#sharedworkerglobalscope) object

 : 1. Let `realm info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.SharedWorkerRealmInfo`
 production, with the `realm` field set to
 `realm id`, and the `origin` field set to
 `origin`.

 `global object` is a [`ServiceWorkerGlobalScope`](https://w3c.github.io/ServiceWorker/#serviceworkerglobalscope) object

 : 1. Let `realm info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `script.ServiceWorkerRealmInfo` production, with the `realm`
 field set to `realm id`, and the `origin` field
 set to `origin`.

 `global object` is a [`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope) object

 : 1. Let `realm info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.WorkerRealmInfo`
 production, with the `realm` field set to
 `realm id`, and the `origin` field set to
 `origin`.

 `global object` is a [`PaintWorkletGlobalScope`](https://drafts.css-houdini.org/css-paint-api-1/#paintworkletglobalscope) object

 : 1. Let `realm info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.PaintWorkletRealmInfo`
 production, with the `realm` field set to
 `realm id`, and the `origin` field set to
 `origin`.

 `global object` is a [`AudioWorkletGlobalScope`](https://webaudio.github.io/web-audio-api/#AudioWorkletGlobalScope) object

 : 1. Let `realm info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.AudioWorkletRealmInfo`
 production, with the `realm` field set to
 `realm id`, and the `origin` field set to
 `origin`.

 `global object` is a [`WorkletGlobalScope`](https://html.spec.whatwg.org/multipage/worklets.html#workletglobalscope) object

 : 1. Let `realm info` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.WorkletRealmInfo`
 production, with the `realm` field set to
 `realm id`, and the `origin` field set to
 `origin`.

 Otherwise:

 : 1. Let `realm info` be null.

6. Return `realm info`

 Future variations of this specification will retain the
invariant that the last component of the type name after splitting on
\"`-`\" will always be \"`worker`\" for globals implementing
[`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope), and \"`worklet`\" for globals implementing
[`WorkletGlobalScope`](https://html.spec.whatwg.org/multipage/worklets.html#workletglobalscope).

##### 7.6.3.12. The script.RealmType Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.RealmType = "window" / "dedicated-worker" / "shared-worker" / "service-worker" /
 "worker" / "paint-worklet" / "audio-worklet" / "worklet"
```

The `script.RealmType` type represents the different types of Realm.

##### 7.6.3.13. The script.RemoteReference Type

[`Remote end definition`](#cddl-module-remote-end-definition)

```
script.RemoteReference = (
 script.SharedReference /
 script.RemoteObjectReference
)

script.SharedReference = {
 sharedId: script.SharedId
 ? handle: script.Handle,
 Extensible
}

script.RemoteObjectReference = {
 handle: script.Handle,
 ? sharedId: script.SharedId
 Extensible
}
```

The [`script.RemoteReference`] type is either a
`script.RemoteObjectReference` representing a remote reference to an
existing ECMAScript object in [handle object
map](#handle-object-map) in
the given
[Realm](https://tc39.es/ecma262/#sec-code-realms), or is a `script.SharedReference` representing a
reference to a
[node](https://dom.spec.whatwg.org/#concept-node).

handle \"stale object reference\" case.

 if the provided reference has both `handle` and
`sharedId`, the algorithm will ignore `handle` and respect only
`sharedId`.

To [deserialize remote reference] given
`remote reference`, `realm` and
`session`:

1. Assert `remote reference` matches the
 `script.RemoteReference` production.

2. If `remote reference` matches the
 `script.SharedReference` production, return [deserialize shared
 reference](#deserialize-shared-reference) with `remote reference`,
 `realm` and `session`.

3. Return [deserialize remote object
 reference](#deserialize-remote-object-reference) with `remote reference` and
 `realm`.

To [deserialize remote object
reference] given `remote object reference`
and `realm`:

1. Let `handle id` be the value of the `handle` field of
 `remote object reference`.

2. Let `handle map` be `realm`'s [handle object
 map](#handle-object-map)

3. If `handle map` does not contain `handle id`,
 then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 handle](#errors-no-such-handle).

4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data
 `handle map`\[`handle id`\].

To [deserialize shared reference] given
`shared reference`, `realm` and
`session`:

1. Assert `shared reference` matches the
 `script.SharedReference` production.

2. Let `navigable` be [get the
 navigable](#get-the-navigable) with `realm`.

3. If `navigable` is `null`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 node](#errors-no-such-node).

 This happens when the realm isn't a Window global.

4. Let `shared id` be the value of the `sharedId` field of
 `shared reference`.

5. Let `node` be result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 node](https://w3c.github.io/webdriver/#dfn-get-a-node) with `session`, `navigable`
 and `shared id`.

6. If `node` is `null`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 node](#errors-no-such-node).

7. Let `environment settings` be the [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component is `realm`.

8. If `node`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) is not [same origin
 domain](https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain) with `environment settings`'s
 [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin) then return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 node](#errors-no-such-node).

 This ensures that WebDriver-BiDi can not be used to
 pass objects between realms that do not otherwise permit script
 access.

9. Let `realm global object` be the [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global) of the `realm`.

10. If the `realm global object` is
 [`SandboxWindowProxy`](#sandboxwindowproxy) object, set `node` to the
 [`SandboxProxy`](#sandboxproxy) wrapping `node` in the
 `realm`.

11. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `node`.

##### 7.6.3.14. The script.RemoteValue Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.RemoteValue = (
 script.PrimitiveProtocolValue /
 script.SymbolRemoteValue /
 script.ArrayRemoteValue /
 script.ObjectRemoteValue /
 script.FunctionRemoteValue /
 script.RegExpRemoteValue /
 script.DateRemoteValue /
 script.MapRemoteValue /
 script.SetRemoteValue /
 script.WeakMapRemoteValue /
 script.WeakSetRemoteValue /
 script.GeneratorRemoteValue /
 script.ErrorRemoteValue /
 script.ProxyRemoteValue /
 script.PromiseRemoteValue /
 script.TypedArrayRemoteValue /
 script.ArrayBufferRemoteValue /
 script.NodeListRemoteValue /
 script.HTMLCollectionRemoteValue /
 script.NodeRemoteValue /
 script.WindowProxyRemoteValue
)

script.ListRemoteValue = [*script.RemoteValue];

script.MappingRemoteValue = [*[(script.RemoteValue / text), script.RemoteValue]];

script.SymbolRemoteValue = {
 type: "symbol",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.ArrayRemoteValue = {
 type: "array",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
 ? value: script.ListRemoteValue,
}

script.ObjectRemoteValue = {
 type: "object",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
 ? value: script.MappingRemoteValue,
}

script.FunctionRemoteValue = {
 type: "function",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.RegExpRemoteValue = {
 script.RegExpLocalValue,
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.DateRemoteValue = {
 script.DateLocalValue,
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.MapRemoteValue = {
 type: "map",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
 ? value: script.MappingRemoteValue,
}

script.SetRemoteValue = {
 type: "set",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
 ? value: script.ListRemoteValue
}

script.WeakMapRemoteValue = {
 type: "weakmap",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.WeakSetRemoteValue = {
 type: "weakset",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.GeneratorRemoteValue = {
 type: "generator",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.ErrorRemoteValue = {
 type: "error",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.ProxyRemoteValue = {
 type: "proxy",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.PromiseRemoteValue = {
 type: "promise",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.TypedArrayRemoteValue = {
 type: "typedarray",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.ArrayBufferRemoteValue = {
 type: "arraybuffer",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
}

script.NodeListRemoteValue = {
 type: "nodelist",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
 ? value: script.ListRemoteValue,
}

script.HTMLCollectionRemoteValue = {
 type: "htmlcollection",
 ? handle: script.Handle,
 ? internalId: script.InternalId,
 ? value: script.ListRemoteValue,
}

script.NodeRemoteValue = {
 type: "node",
 ? sharedId: script.SharedId,
 ? handle: script.Handle,
 ? internalId: script.InternalId,
 ? value: script.NodeProperties,
}

script.NodeProperties = {
 nodeType: js-uint,
 childNodeCount: js-uint,
 ? attributes: {*text => text},
 ? children: [*script.NodeRemoteValue],
 ? localName: text,
 ? mode: "open" / "closed",
 ? namespaceURI: text,
 ? nodeValue: text,
 ? shadowRoot: script.NodeRemoteValue / null,
}

script.WindowProxyRemoteValue = {
 type: "window",
 value: script.WindowProxyProperties,
 ? handle: script.Handle,
 ? internalId: script.InternalId
}

script.WindowProxyProperties = {
 context: browsingContext.BrowsingContext
}
```

Add WASM types?

Should WindowProxy get attributes in a
similar style to Node?

handle String / Number / etc. wrapper
objects specially?

Values accessible from the ECMAScript runtime are represented by a
mirror object, specified as `script.RemoteValue`. The value's type is
specified in the `type` property. In the case of JSON-representable
primitive values, this contains the value in the `value` property; in
the case of non-JSON-representable primitives, the `value` property
contains a string representation of the value.

For non-primitive objects, the `handle` property, when present, contains
a unique string handle to the object. The handle is unique for each
serialization. The remote end will keep objects with a corresponding
handle alive until such a time that `script.disown` is called with that
handle, or the realm itself is to be discarded (e.g. due to navigation).

For some non-primitive types, the `value` property contains a
representation of the data in the ECMAScript object; for container types
this can contain further `script.RemoteValue` instances. The `value`
property can be null or omitted if there is a duplicate object i.e. the
object has already been serialized in the current `script.RemoteValue`,
perhaps as part of a cycle, or otherwise when the maximum serialization
depth is reached.

In case of duplicated objects in the same `script.RemoteValue`, the
value is provided only for one of the remote values, while the
unique-per-ECMAScript-object `internalId` is provided for all the
duplicated objects for a given serialization.

[Nodes](https://dom.spec.whatwg.org/#concept-node) are also represented by `script.RemoteValue` instances.
These have a partial serialization of the node in the value property.

reconsider mirror objects\' lifecycle.

 mirror objects do not keep the original object alive in
the runtime. If an object is discarded in the runtime, subsequent
attempts to access it via the protocol will result in an error.

To get the [handle for an object] given `realm`,
`ownership type` and `object`:

1. If `ownership type` is equal \"`none`\", return `null`.

2. Let `handle id` be a new, unique, string handle for
 `object`.

3. Let `handle map` be `realm`'s [handle object
 map](#handle-object-map)

4. Set `handle map`\[`handle id`\] to
 `object`.

5. Return `handle id` as a result.

To [get shared id for a node] given `node`, and
`session`:

1. Let `node` be [unwrapped](#unwrapped) `node`.

2. If `node` does not implement
 [`Node`](https://dom.spec.whatwg.org/#node), return null.

3. Let `navigable` be `node`'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

4. If `navigable` is null, return null.

5. Return [get or create a node
 reference](https://w3c.github.io/webdriver/#dfn-get-or-create-a-node-reference) with `session`, `navigable`
 and `node`.

To [set internal ids if needed] given
`serialization internal map`, `remote value` and
`object`:

1. If the `serialization internal map` does not contain
 `object`, set
 `serialization internal map`\[`object`\] to
 `remote value`.

2. Otherwise, run the following steps:

 1. Let `previously serialized remote value` be
 `serialization internal map`\[`object`\].

 2. If `previously serialized remote value` does not have
 a field `internalId`, run the following steps:

 1. Let `internal id` be the string representation of
 a
 [UUID](#biblio-rfc9562 "Universally Unique IDentifiers (UUIDs)")
 based on truly random, or pseudo-random numbers.

 2. Set the `internalId` field of
 `previously serialized remote value` to
 `internal id`.

 3. Set the `internalId` field of `remote value` to a
 field `internalId` in
 `previously serialized remote value`.

To [serialize as a remote value] given `value`,
`serialization options`, an `ownership type`, a
`serialization internal map`, a `realm` and a
`session`:

1. Let `remote value` be a result of [serialize primitive
 protocol
 value](#serialize-primitive-protocol-value) given a `value`.

2. If `remote value` is not undefined, return
 `remote value`.

3. Let `handle id` be the [handle for an
 object](#handle-for-an-object) with `realm`,
 `ownership type` and `value`.

4. Set `ownership type` to \"`none`\".

5. Let `known object` be `true`, if `value` is in
 the `serialization internal map`, otherwise `false`.

6. In the following list of conditions and associated steps, run the
 first set of steps for which the associated condition is true:

 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is Symbol
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.SymbolRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted otherwise.

 [IsArray](https://tc39.es/ecma262/#sec-isarray)(`value`)
 : Let `remote value` be [serialize an
 Array-like](#serialize-an-array-like) with `session`,
 `script.ArrayRemoteValue`, `handle id`,
 `known object`, `value`,
 `serialization options`, `ownership type`,
 `serialization internal map`, `realm`, and
 `session`.

 [IsRegExp](https://tc39.es/ecma262/#sec-isregexp)(`value`)

 : 1. Let `pattern` be
 [ToString](https://tc39.es/ecma262/#sec-tostring)([Get](https://tc39.es/ecma262/#sec-get-o-p)(`value`, \"source\")).

 2. Let `flags` be
 [ToString](https://tc39.es/ecma262/#sec-tostring)([Get](https://tc39.es/ecma262/#sec-get-o-p)(`value`, \"flags\")).

 3. Let `serialized` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.RegExpValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `pattern` property set to the
 `pattern` and the the `flags` property set to the
 `flags`.

 4. Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.RegExpRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted
 otherwise, and the `value` property set to
 `serialized`.

 `value` has a \[\[DateValue\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots).

 : 1. Set `serialized` to
 [Call](https://tc39.es/ecma262/#sec-call)([Date.prototype.toISOString](https://tc39.es/ecma262/#sec-date.prototype.toisostring), `value`).

 2. Assert: `serialized` is not a [throw
 completion](https://tc39.es/ecma262/#sec-completion-record-specification-type).

 3. Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.DateRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted
 otherwise, and the value set to `serialized`.

 `value` has a \[\[MapData\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots)

 : 1. Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.MapRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted
 otherwise.

 2. [Set internal ids if
 needed](#set-internal-ids-if-needed) with
 `serialization internal map`,
 `remote value` and `value`.

 3. Let `serialized` be null.

 4. If `known object` is `false`, and
 `serialization options`\[\"`maxObjectDepth`\"\]
 is not 0, run the following steps:

 1. Let `serialized` be the result of [serialize
 as a
 mapping](#serialize-as-a-mapping) with
 [CreateMapIterator](https://tc39.es/ecma262/#sec-createmapiterator)(`value`, key+value),
 `serialization options`,
 `ownership type`,
 `serialization internal map`,
 `realm`, and `session`.

 5. If `serialized` is not null, set field `value` of
 `remote value` to `serialized`.

 `value` has a \[\[SetData\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots)

 : 1. Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.SetRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted
 otherwise.

 2. [Set internal ids if
 needed](#set-internal-ids-if-needed) with
 `serialization internal map`,
 `remote value` and `value`.

 3. Let `serialized` be null.

 4. If `known object` is `false`, and
 `serialization options`\[\"`maxObjectDepth`\"\]
 is not 0, run the following steps:

 1. Let `serialized` be the result of [serialize
 as a
 list](#serialize-as-a-list) with
 [CreateSetIterator](https://tc39.es/ecma262/#sec-createsetiterator)(`value`, value),
 `serialization options`,
 `ownership type`,
 `serialization internal map`,
 `realm`, and `session`.

 5. If `serialized` is not null, set field `value` of
 `remote value` to `serialized`.

 `value` has a \[\[WeakMapData\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots)
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.WeakMapRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted otherwise.

 `value` has a \[\[WeakSetData\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots)
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.WeakSetRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted otherwise.

 `value` has a \[\[GeneratorState\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots) or \[\[AsyncGeneratorState\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots)
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.GeneratorRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted otherwise.

 `value` has an \[\[ErrorData\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots)
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.ErrorRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted otherwise.

 `value` has a \[\[ProxyHandler\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots) and a \[\[ProxyTarget\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots)
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.ProxyRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted otherwise.

 [IsPromise](https://tc39.es/ecma262/#sec-ispromise)(`value`)
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.PromiseRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted otherwise.

 `value` has a \[\[TypedArrayName\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots)
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.TypedArrayRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted otherwise.

 `value` has an \[\[ArrayBufferData\]\] [internal slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots)
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.ArrayBufferRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted otherwise.

 `value` is a [platform object](https://webidl.spec.whatwg.org/#dfn-platform-object) that implements [`NodeList`](https://dom.spec.whatwg.org/#nodelist)
 : Let `remote value` be [serialize an
 Array-like](#serialize-an-array-like) with
 `script.NodeListRemoteValue`,`handle id`,
 `known object`, `value`,
 `serialization options`, `ownership type`,
 `serialization internal map`, `realm`, and
 `session`.

 `value` is a [platform object](https://webidl.spec.whatwg.org/#dfn-platform-object) that implements [`HTMLCollection`](https://dom.spec.whatwg.org/#htmlcollection)
 : Let `remote value` be [serialize an
 Array-like](#serialize-an-array-like) with `script.HTMLCollectionRemoteValue`,
 `handle id`, `known object`,
 `value`, `serialization options`,
 `ownership type`, `known object`,
 `serialization internal map`, `realm`, and
 `session`.

 `value` is a [platform object](https://webidl.spec.whatwg.org/#dfn-platform-object) that implements [`Node`](https://dom.spec.whatwg.org/#node)

 : 1. Let `shared id` be [get shared id for a
 node](#get-shared-id-for-a-node) with `value` and
 `session`.

 2. Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.NodeRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `sharedId` property set to
 `shared id` if it's not null, or omitted
 otherwise, and the `handle` property set to
 `handle id` if it's not null, or omitted
 otherwise.

 3. [Set internal ids if
 needed](#set-internal-ids-if-needed) with
 `serialization internal map`,
 `remote value` and `value`.

 4. Let `serialized` be null.

 5. If `known object` is `false`, run the following
 steps:

 1. Let `serialized` be a
 [map](https://infra.spec.whatwg.org/#ordered-map).

 2. Set `serialized`\[\"`nodeType`\"\] to
 [Get](https://tc39.es/ecma262/#sec-get-o-p)(`value`, \"nodeType\").

 3. Set `node value` to
 [Get](https://tc39.es/ecma262/#sec-get-o-p)(`value`, \"nodeValue\").

 4. If `node value` is not null set
 `serialized`\[\"`nodeValue`\"\] to
 `node value`.

 5. If `value` implements
 [`Element`](https://dom.spec.whatwg.org/#element) or
 [`Attr`](https://dom.spec.whatwg.org/#attr):

 1. Set `serialized`\[\"`localName`\"\] to
 [Get](https://tc39.es/ecma262/#sec-get-o-p)(`value`, \"localName\").

 2. Set `serialized`\[\"`namespaceURI`\"\] to
 [Get](https://tc39.es/ecma262/#sec-get-o-p)(`value`,
 \"namespaceURI\")

 6. Let `child node count` be the
 [size](https://infra.spec.whatwg.org/#list-size) of `value`'s
 [children](https://dom.spec.whatwg.org/#concept-tree-child).

 7. Set `serialized`\[\"`childNodeCount`\"\] to
 `child node count`.

 8. If
 `serialization options`\[\"`maxDomDepth`\"\]
 is equal to 0, or if `value` implements
 [`ShadowRoot`](https://dom.spec.whatwg.org/#shadowroot) and
 `serialization options`\[\"`includeShadowTree`\"\]
 is \"`none`\", or if
 `serialization options`\[\"`includeShadowTree`\"\]
 is \"`open`\" and `value`'s
 [mode](https://dom.spec.whatwg.org/#shadowroot-mode) is \"`closed`\", let
 `children` be null.

 Otherwise, let `children` be an empty
 [list](https://infra.spec.whatwg.org/#list) and, for each node `child`
 in the
 [children](https://dom.spec.whatwg.org/#concept-tree-child) of `value`:

 1. Let `child serialization options` be a
 [clone](https://infra.spec.whatwg.org/#map-clone) of
 `serialization options`.

 2. If
 `child serialization options`\[\"`maxDomDepth`\"\]
 is not null, set
 `child serialization options`\[\"`maxDomDepth`\"\]
 to
 `child serialization options`\[\"`maxDomDepth`\"\] -
 1.

 3. Let `serialized` be the result of
 [serialize as a remote
 value](#serialize-as-a-remote-value) with `child`,
 `child serialization options`,
 `ownership type`,
 `serialization internal map`,
 `realm`, and `session`.

 4. Append `serialized` to
 `children`.

 9. If `children` is not null, set
 `serialized`\[\"`children`\"\] to
 `children`.

 10. If `value` implements
 [`Element`](https://dom.spec.whatwg.org/#element):

 1. Let `attributes` be a new
 [map](https://infra.spec.whatwg.org/#ordered-map).

 2. For each `attribute` in
 `value`'s [attribute
 list](https://dom.spec.whatwg.org/#concept-element-attribute):

 1. Let `name` be
 `attribute`'s [qualified
 name](https://dom.spec.whatwg.org/#concept-attribute-qualified-name)

 2. Let `value` be
 `attribute`'s
 [value](https://dom.spec.whatwg.org/#concept-attribute-value).

 3. Set `attributes`\[`name`\]
 to `value`

 3. Set `serialized`\[\"`attributes`\"\] to
 `attributes`.

 4. Let `shadow root` be `value`'s
 [shadow
 root](https://dom.spec.whatwg.org/#concept-element-shadow-root).

 5. If `shadow root` is null, let
 `serialized shadow` be null. Otherwise
 run the following substeps:

 1. Let `serialized shadow` be the result
 of [serialize as a remote
 value](#serialize-as-a-remote-value) with `shadow root`,
 `serialization options`,
 `ownership type`,
 `serialization internal map`,
 `realm`, and `session`.

 6. Set `serialized`\[\"`shadowRoot`\"\] to
 `serialized shadow`.

 11. If `value` implements
 [`ShadowRoot`](https://dom.spec.whatwg.org/#shadowroot), set
 `serialized`\[\"`mode`\"\] to
 `value`'s
 [mode](https://dom.spec.whatwg.org/#shadowroot-mode).

 6. If `serialized` is not null, set field `value` of
 `remote value` to `serialized`.

 `value` is a [platform object](https://webidl.spec.whatwg.org/#dfn-platform-object) that implements [`WindowProxy`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#windowproxy)

 : 1. Let `window` be the value of `value`'s
 \[\[WindowProxy\]\] [internal
 slot](https://tc39.es/ecma262/#sec-object-internal-methods-and-internal-slots).

 2. Let `navigable` be `window`'s
 [navigable](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-navigable).

 3. Let `navigable id` be the [navigable
 id](#navigable-id)
 for `navigable`.

 4. Let `serialized` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.WindowProxyProperties`
 production in the
 [`local end definition`](#cddl-module-local-end-definition) with the `context` property set to
 `navigable id`.

 5. Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the
 `script.WindowProxyRemoteValue` production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted
 otherwise, and the `value` property set to
 `serialized`.

 `value` is a [platform object](https://webidl.spec.whatwg.org/#dfn-platform-object)
 : 1\. Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.ObjectRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted otherwise.

 [IsCallable](https://tc39.es/ecma262/#sec-iscallable)(`value`)
 : Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.FunctionRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted otherwise.

 Otherwise:

 : 1. [Assert](https://infra.spec.whatwg.org/#assert):
 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`value`) is Object

 2. Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.ObjectRemoteValue`
 production in the
 [`local end definition`](#cddl-module-local-end-definition), with the `handle` property set to
 `handle id` if it's not null, or omitted
 otherwise.

 3. [Set internal ids if
 needed](#set-internal-ids-if-needed) with
 `serialization internal map`,
 `remote value` and `value`.

 4. Let `serialized` be null.

 5. If `known object` is `false`, and
 `serialization options`\[\"`maxObjectDepth`\"\]
 is not 0, run the following steps:

 1. Let `serialized` be the result of [serialize
 as a
 mapping](#serialize-as-a-mapping) with
 [EnumerableOwnPropertyNames](https://tc39.es/ecma262/#sec-enumerableownpropertynames)(`value`, key+value),
 `serialization options`,
 `ownership type`,
 `serialization internal map`,
 `realm`, and `session`.

 6. If `serialized` is not null, set field `value` of
 `remote value` to `serialized`.

7. Return `remote value`

`children` and child nodes
are different things. Either `childNodeCount` should reference to
`childNodes`, or it should be renamed to `childrenCount`.

To [serialize an Array-like] given `production`,
`handle id`, `known object`, `value`,
`serialization options`, `ownership type`,
`serialization internal map`, `realm`, and
`session`:

1. Let `remote value` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching `production`, with the `handle`
 property set to `handle id` if it's not null, or omitted
 otherwise.

2. [Set internal ids if
 needed](#set-internal-ids-if-needed) with `serialization internal map`,
 `remote value` and `value`.

3. If `known object` is `false`, and
 `serialization options`\[\"`maxObjectDepth`\"\] is not 0:

 1. Let `serialized` be the result of [serialize as a
 list](#serialize-as-a-list) with
 [CreateArrayIterator](https://tc39.es/ecma262/#sec-createarrayiterator)(`value`, value),
 `serialization options`, `ownership type`,
 `serialization internal map`, `realm`, and
 `session`.

 2. If `serialized` is not null, set field `value` of
 `remote value` to `serialized`.

4. Return `remote value`

To [serialize as a list] given `iterable`,
`serialization options`, `ownership type`,
`serialization internal map`, `realm`, and
`session`:

1. If `serialization options`\[\"`maxObjectDepth`\"\] is not
 null, assert:
 `serialization options`\[\"`maxObjectDepth`\"\] is
 greater than 0.

2. Let `serialized` be a new list.

3. For each `child value` in
 [IteratorToList](https://tc39.es/ecma262/#sec-iteratortolist)([GetIterator](https://tc39.es/ecma262/#sec-getiterator)(`iterable`, sync)):

 1. Let `child serialization options` be a
 [clone](https://infra.spec.whatwg.org/#map-clone) of `serialization options`.

 2. If
 `child serialization options`\[\"`maxObjectDepth`\"\]
 is not null, set
 `child serialization options`\[\"`maxObjectDepth`\"\]
 to
 `child serialization options`\[\"`maxObjectDepth`\"\] -
 1.

 3. Let `serialized child` be the result of [serialize as
 a remote
 value](#serialize-as-a-remote-value) with `child value`,
 `child serialization options`,
 `ownership type`,
 `serialization internal map`, `realm`, and
 `session`.

 4. Append `serialized child` to `serialized`.

4. Return `serialized`

To [serialize as a mapping] given `iterable`,
`serialization options`, `ownership type`,
`serialization internal map`, `realm`, and
`session`:

1. If `serialization options`\[\"`maxObjectDepth`\"\] is not
 null, assert:
 `serialization options`\[\"`maxObjectDepth`\"\] is
 greater than 0.

2. Let `serialized` be a new list.

3. For `item` in
 [IteratorToList](https://tc39.es/ecma262/#sec-iteratortolist)([GetIterator](https://tc39.es/ecma262/#sec-getiterator)(`iterable`, sync)):

 1. Assert:
 [IsArray](https://tc39.es/ecma262/#sec-isarray)(`item`)

 2. Let `property` be
 [CreateListFromArrayLike](https://tc39.es/ecma262/#sec-createlistfromarraylike)(`item`)

 3. Assert: `property` is a list of
 [size](https://infra.spec.whatwg.org/#list-size) 2

 4. Let `key` be `property`\[0\] and let
 `value` be `property`\[1\]

 5. Let `child serialization options` be a
 [clone](https://infra.spec.whatwg.org/#map-clone) of `serialization options`.

 6. If
 `child serialization options`\[\"`maxObjectDepth`\"\]
 is not null, set
 `child serialization options`\[\"`maxObjectDepth`\"\]
 to
 `child serialization options`\[\"`maxObjectDepth`\"\] -
 1.

 7. If
 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`key`) is String, let
 `serialized key` be `child key`, otherwise
 let `serialized key` be the result of [serialize as a
 remote
 value](#serialize-as-a-remote-value) with `child key`,
 `child serialization options`,
 `ownership type`,
 `serialization internal map`, `realm`, and
 `session`.

 8. Let `serialized value` be the result of [serialize as
 a remote
 value](#serialize-as-a-remote-value) with `value`,
 `child serialization options`,
 `ownership type`,
 `serialization internal map`, `realm`, and
 `session`.

 9. Let `serialized child` be
 («`serialized key`, `serialized value`»).

 10. Append `serialized child` to `serialized`.

4. Return `serialized`

##### 7.6.3.15. The script.ResultOwnership Type

```
script.ResultOwnership = "root" / "none"
```

The `script.ResultOwnership` specifies how the serialized value
ownership will be treated.

##### 7.6.3.16. The script.SerializationOptions Type

[`Remote end definition`](#cddl-module-remote-end-definition)

```
script.SerializationOptions = {
 ? maxDomDepth: (js-uint / null) .default 0,
 ? maxObjectDepth: (js-uint / null) .default null,
 ? includeShadowTree: ("none" / "open" / "all") .default "none",
}
```

The `script.SerializationOptions` allows specifying how ECMAScript
objects will be serialized.

##### 7.6.3.17. The script.SharedId Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.SharedId = text;
```

The `script.SharedId` type represents a reference to a DOM
[`Node`](https://dom.spec.whatwg.org/#node) that is usable in any realm (including [Sandbox
Realms](#sandbox-realm)).

##### 7.6.3.18. The script.StackFrame Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.StackFrame = {
 columnNumber: js-uint,
 functionName: text,
 lineNumber: js-uint,
 url: text,
}
```

A frame in a stack trace is represented by a `StackFrame` object. This
has a `url` property, which represents the URL of the script, a
`functionName` property which represents the name of the executing
function, and `lineNumber` and `columnNumber` properties, which
represent the line and column number of the executed code.

##### 7.6.3.19. The script.StackTrace Type

[`Remote end definition`](#cddl-module-remote-end-definition) and
[`local end definition`](#cddl-module-local-end-definition)

```
script.StackTrace = {
 callFrames: [*script.StackFrame],
}
```

The `script.StackTrace` type represents the javascript stack at a point
in script execution.

 The details of how to get a list of stack frames, and
the properties of that list are underspecified, and therefore the
details here are implementation defined.

It is assumed that an implementation is able to generate a [list of
stack frames], which is a list with one entry
for each item in the javascript call stack, starting from the most
recent. Each entry is a single [stack frame] corresponding
to execution of a statement or expression in a script
`script`, which contains the following fields:

[script url]
: The url of the resource containing `script`

[function]
: The name of the function being executed

[line number]
: The zero-based line number of the executed code, relative to the top
 of the resource containing `script`.

[column number]
: The zero-based column number of the executed code, relative to the
 start of the line in the resource containing `script`.

To [construct a stack trace], with a list of stack frames
`stack`:

1. Let `call frames` be a new list.

2. For each [stack frame](#stack-frame) `frame` in `stack`, starting
 from the most recently executed frame, run the following steps:

 1. Let `url` be the result of running the [URL
 serializer](https://url.spec.whatwg.org/#concept-url-serializer), given the
 [URL](https://url.spec.whatwg.org/#concept-url) of `frame`'s [script
 url](#stackframe-script-url).

 2. Let `frame info` be a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.StackFrame` production,
 with the `url` field set to `url`, the `functionName`
 field set to `frame`'s
 [function](#stackframe-function), the `lineNumber` field set to
 `frame`'s [line
 number](#stackframe-line-number) and the `columnNumber` field set to
 `frame`'s [column
 number](#stackframe-column-number).

3. Append `frame info` to `call frames`.

4. Let `stack trace` be a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.StackTrace` production, with
 the `callFrames` property set to `call frames`.

5. Return `stack trace`.

The [current stack trace] is the result of [construct a stack
trace](#construct-a-stack-trace) given a [list of stack
frames](#list-of-stack-frames) representing the callstack of the [running execution
context](https://tc39.es/ecma262/#running-execution-context).

The [stack trace for an exception] with an exception, or a
[Completion
Record](https://tc39.es/ecma262/#sec-completion-record-specification-type) of type `throw`,
`exception`, is given by:

1. If `exception` is a value that has been thrown as an
 exception, let `record` be the [Completion
 Record](https://tc39.es/ecma262/#sec-completion-record-specification-type) created to throw
 `exception`. Otherwise let `record` be
 `exception`.

2. Let `stack` be the [list of stack
 frames](#list-of-stack-frames) corresponding to execution at the point
 `record` was created.

3. Return [construct a stack
 trace](#construct-a-stack-trace) given `stack`.

##### 7.6.3.20. The script.Source Type

[`Local end definition`](#cddl-module-local-end-definition)

```
script.Source = {
 realm: script.Realm,
 ? context: browsingContext.BrowsingContext
}
```

The `script.Source` type represents a `script.Realm` with an optional
`browsingContext.BrowsingContext` in which a script related event
occurred.

To [get the source] given `source realm`:

1. Let `realm` be the [realm
 id](#realm-id) for
 `source realm`.

2. Let `environment settings` be the [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component is `source realm`.

3. If `environment settings` has a [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window):

 1. Let `document` be environment settings' [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

 2. Let `navigable` be `document`'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

 3. Let `navigable id` be the [navigable
 id](#navigable-id) for
 `navigable` if `navigable` is not null.

 Otherwise let `navigable` be null.

4. Let `source` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.Source` production with the
 `realm` field set to `realm`, and the `context` field set
 to `navigable id` if `navigable` is not null,
 or unset otherwise.

5. Return `source`.

##### 7.6.3.21. The script.Target Type

[`Remote end definition`](#cddl-module-remote-end-definition)

```
script.RealmTarget = {
 realm: script.Realm
}

script.ContextTarget = {
 context: browsingContext.BrowsingContext,
 ? sandbox: text
}

script.Target = (
 script.ContextTarget /
 script.RealmTarget
)
```

The `script.Target` type represents a value that is either a
`script.Realm` or a `browsingContext.BrowsingContext`. This is useful in
cases where a navigable identifier can stand in for the realm associated
with the navigable's active document.

To [get a realm from a navigable] given `navigable id`
and `sandbox`:

1. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

2. If `sandbox` is null or is an empty string:

 1. Let `document` be `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

 2. Let `environment settings` be the [environment
 settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is `document`.

 3. Let `realm` be `environment settings`'
 [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component.

3. Otherwise: let `realm` be result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get or create a sandbox
 realm](#get-or-create-a-sandbox-realm) given `sandbox` and
 `navigable`.

4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `realm`

(#issue-89e6b783①) This has the wrong error code

To [get a realm from a target] given `target`:

1. If `target` matches the `script.ContextTarget`
 production:

 1. Let `sandbox` be null.

 2. If `target`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`sandbox`\", set `sandbox` to
 `target`\[\"`sandbox`\"\].

 3. Let `realm` be [get a realm from a
 navigable](#get-a-realm-from-a-navigable) with `target`\[\"`context`\"\] and
 `sandbox`.

2. Otherwise:

 1. Assert: `target` matches the `script.RealmTarget`
 production.

 2. Let `realm id` be the value of the `realm` field of
 `target`.

 3. Let `realm` be [get a
 realm](#get-a-realm) given
 `realm id`.

3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `realm`

(#issue-89e6b783②) This has the wrong error code

#### 7.6.4. Commands

##### 7.6.4.1. The script.addPreloadScript Command

The [script.addPreloadScript] command adds a
[preload script](#preload-script).

Command Type

: ```
 script.AddPreloadScript = (
 method: "script.addPreloadScript",
 params: script.AddPreloadScriptParameters
 )

 script.AddPreloadScriptParameters = {
 functionDeclaration: text,
 ? arguments: [*script.ChannelValue],
 ? contexts: [+browsingContext.BrowsingContext],
 ? userContexts: [+browser.UserContext],
 ? sandbox: text
 }
 ```

Return Type

: ```
 script.AddPreloadScriptResult = {
 script: script.PreloadScript
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. If `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`userContexts`\" and
 `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`contexts`\", return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

2. Let `function declaration` be the `functionDeclaration`
 field of `command parameters`.

3. Let `arguments` be the `arguments` field of
 `command parameters` if present, or an empty
 [list](https://infra.spec.whatwg.org/#list) otherwise.

4. Let `user contexts` to be a
 [set](https://infra.spec.whatwg.org/#ordered-set).

5. Let `navigables` be null.

6. If the `contexts` field of `command parameters` is
 present:

 1. Set `navigables` to an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

 2. For each `navigable id` of
 `command parameters`\[\"`contexts`\"\]

 1. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

 2. If `navigable` is not a [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#top-level-traversable), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).

 3. Append `navigable` to `navigables`.

7. Otherwise, if `command parameters`
 [contains](https://infra.spec.whatwg.org/#map-exists) `userContexts`:

 1. Set `user contexts` to [create a
 set](https://infra.spec.whatwg.org/#set-create) with
 `command parameters`\[\"`userContexts`\"\].

 2. For each `user context id` of
 `user contexts`:

 1. Set `user context` to [get user
 context](#get-user-context) with `user context id`.

 2. If `user context` is null, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such user
 context](#errors-no-such-user-context).

8. Let `sandbox` be the value of the \"`sandbox`\" field in
 `command parameters`, if present, or null otherwise.

9. Let `script` be the string representation of a
 [UUID](#biblio-rfc9562 "Universally Unique IDentifiers (UUIDs)").

10. Let `preload script map` be `session`'s
 [preload script
 map](#preload-script-map).

11. Set `preload script map`\[`script`\] to a
 struct with `function declaration`
 `function declaration`, `arguments`
 `arguments`, `contexts` `navigables`,
 `sandbox` `sandbox`, and `user contexts`
 `user contexts`.

12. Return a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.AddPreloadScriptResult` with
 the `script` field set to `script`.

##### 7.6.4.2. The script.disown Command

The [script.disown] command disowns the given
handles. This does not guarantee the handled object will be garbage
collected, as there can be other handles or strong ECMAScript
references.

Command Type

: ```
 script.Disown = (
 method: "script.disown",
 params: script.DisownParameters
 )

 script.DisownParameters = {
 handles: [*script.Handle]
 target: script.Target;
 }
 ```

Return Type

: ```
 script.DisownResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. Let `realm` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a realm from a
 target](#get-a-realm-from-a-target) given the value of the `target` field of
 `command parameters`.

2. Let `handles` the value of the `handles` field of
 `command parameters`.

3. For each `handle id` of `handles`:

 1. Let `handle map` be `realm`'s [handle
 object map](#handle-object-map)

 2. If `handle map` contains `handle id`,
 remove `handle id` from the `handle map`.

4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.6.4.3. The script.callFunction Command

The [script.callFunction] command calls a provided
function with given arguments in a given realm.

`RealmInfo` can be either a realm or a navigable.

 In case of an arrow function in `functionDeclaration`,
the `this` argument doesn't affect function's `this` binding.

Command Type

: ```
 script.CallFunction = (
 method: "script.callFunction",
 params: script.CallFunctionParameters
 )

 script.CallFunctionParameters = {
 functionDeclaration: text,
 awaitPromise: bool,
 target: script.Target,
 ? arguments: [*script.LocalValue],
 ? resultOwnership: script.ResultOwnership,
 ? serializationOptions: script.SerializationOptions,
 ? this: script.LocalValue,
 ? userActivation: bool .default false,
 }
 ```

Return Type

: ```
 script.CallFunctionResult = script.EvaluateResult
 ```

TODO: Add timeout argument as described
in the script.evaluate.

To [deserialize arguments] with given `realm`,
`serialized arguments list` and `session`:

1. Let `deserialized arguments list` be an empty
 [list](https://infra.spec.whatwg.org/#list).

2. For each `serialized argument` of
 `serialized arguments list`:

 1. Let `deserialized argument` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize local
 value](#deserialize-local-value) given `serialized argument`,
 `realm` and `session`.

 2. Append `deserialized argument` to the
 `deserialized arguments list`.

3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `deserialized arguments list`.

To [evaluate function body] given `function declaration`,
`environment settings`, `base URL`, and
`options`:

 the `function declaration` is parenthesized
and evaluated.

1. Let `bypassDisabledScripting` be true.

2. Let `parenthesized function declaration` be
 [concatenate](https://infra.spec.whatwg.org/#string-concatenate) «\"`(`\", `function declaration`,
 \"`)`\"»

3. Let `function script` be the result of [create a classic
 script](https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-classic-script) with
 `parenthesized function declaration`,
 `environment settings`, `base URL`,
 `options` and `bypassDisabledScripting`.

4. [Prepare to run
 script](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-script) with `environment settings`.

5. Let `function body evaluation status` be
 [ScriptEvaluation](https://tc39.es/ecma262/#sec-runtime-semantics-scriptevaluation)(`function script`'s record).

6. [Clean up after running
 script](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script) with `environment settings`.

7. Return (`function script`,
 `function body evaluation status`).

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `realm` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a realm from a
 target](#get-a-realm-from-a-target) given the value of the `target` field of
 `command parameters`.

2. Let `realm id` be `realm`'s [realm
 id](#realm-id).

3. Let `environment settings` be the [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component is `realm`.

4. Let `command arguments` be the value of the `arguments`
 field of `command parameters`.

5. Let `deserialized arguments` be an empty
 [list](https://infra.spec.whatwg.org/#list).

6. If `command arguments` is not null, set
 `deserialized arguments` to the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize
 arguments](#deserialize-arguments) given `realm`,
 `command arguments` and `session`.

7. Let `this parameter` be the value of the `this` field of
 `command parameters`.

8. Let `this object` be null.

9. If `this parameter` is not null, set
 `this object` to the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize local
 value](#deserialize-local-value) given `this parameter`,
 `realm` and `session`.

10. Let `function declaration` be the value of the
 `functionDeclaration` field of `command parameters`.

11. Let `await promise` be the value of the `awaitPromise`
 field of `command parameters`.

12. Let `serialization options` be the value of the
 `serializationOptions` field of `command parameters`, if
 present, or otherwise a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.SerializationOptions`
 production with the fields set to their default values.

13. Let `result ownership` be the value of the
 `resultOwnership` field of `command parameters`, if
 present, or `none` otherwise.

14. Let `base URL` be the [API base
 URL](https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url) of `environment settings`.

15. Let `options` be the [default script fetch
 options](https://html.spec.whatwg.org/multipage/webappapis.html#default-script-fetch-options).

16. Let (`script`,
 `function body evaluation status`) be the result of
 [evaluate function
 body](#evaluate-function-body) with `function declaration`,
 `environment settings`, `base URL`, and
 `options`.

17. If `function body evaluation status`.\[\[Type\]\] is
 `throw`:

 1. Let `exception details` be the result of [get
 exception
 details](#get-exception-details) given `realm`,
 `function body evaluation status`,
 `result ownership` and `session`.

 2. Return a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.EvaluateResultException`
 production, with the `exceptionDetails` field set to
 `exception details`.

18. Let `function object` be
 `function body evaluation status`.\[\[Value\]\].

19. If
 [IsCallable](https://tc39.es/ecma262/#sec-iscallable)(`function object`) is `false`:

 1. Return an
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument)

20. If `command parameters`\[\"`userActivation`\"\] is true,
 run [activation
 notification](https://html.spec.whatwg.org/multipage/interaction.html#activation-notification) steps.

21. [Prepare to run
 script](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-script) with `environment settings`.

22. Set `evaluation status` to
 [Call](https://tc39.es/ecma262/#sec-call)(`function object`,
 `this object`, `deserialized arguments`).

23. If `evaluation status`.\[\[Type\]\] is `normal`, and
 `await promise` is `true`, and
 [IsPromise](https://tc39.es/ecma262/#sec-ispromise)(`evaluation status`.\[\[Value\]\]):

 1. Set `evaluation status` to
 [Await](https://tc39.es/ecma262/#await)(`evaluation status`.\[\[Value\]\]).

24. [Clean up after running
 script](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script) with `environment settings`.

25. If `evaluation status`.\[\[Type\]\] is `throw`:

 1. Let `exception details` be the result of [get
 exception
 details](#get-exception-details) given `realm`,
 `evaluation status`, `result ownership`
 and `session`.

 2. Return a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.EvaluateResultException`
 production, with the `exceptionDetails` field set to
 `exception details`.

26. Assert: `evaluation status`.\[\[Type\]\] is `normal`.

27. Let `result` be the result of [serialize as a remote
 value](#serialize-as-a-remote-value) with `evaluation status`.\[\[Value\]\],
 `serialization options`, `result ownership`, a
 new
 [map](https://infra.spec.whatwg.org/#ordered-map) as serialization internal map, `realm`
 and `session`.

28. Return a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.EvaluateResultSuccess`
 production, with the `realm` field set to `realm id`, and
 the `result` field set to `result`.

##### 7.6.4.4. The script.evaluate Command

The [script.evaluate] command evaluates a
provided script in a given realm. For convenience a navigable can be
provided in place of a realm, in which case the realm used is the realm
of the browsing context's active document.

The method returns the value of executing the provided script, unless it
returns a promise and `awaitPromise` is true, in which case the resolved
value of the promise is returned.

Command Type

: ```
 script.Evaluate = (
 method: "script.evaluate",
 params: script.EvaluateParameters
 )

 script.EvaluateParameters = {
 expression: text,
 target: script.Target,
 awaitPromise: bool,
 ? resultOwnership: script.ResultOwnership,
 ? serializationOptions: script.SerializationOptions,
 ? userActivation: bool .default false,
 }
 ```

Return Type
: ` script.EvaluateResult `

TODO: Add timeout argument. It's not totally clear how this ought to
work; in Chrome it seems like the timeout doesn't apply to the promise
resolve step, but that likely isn't what clients want.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `realm` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a realm from a
 target](#get-a-realm-from-a-target) given the value of the `target` field of
 `command parameters`.

2. Let `realm id` be `realm`'s [realm
 id](#realm-id).

3. Let `environment settings` be the [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component is `realm`.

4. Let `source` be the value of the `expression` field of
 `command parameters`.

5. Let `await promise` be the value of the `awaitPromise`
 field of `command parameters`.

6. Let `serialization options` be the value of the
 `serializationOptions` field of `command parameters`, if
 present, or otherwise a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.SerializationOptions`
 production with the fields set to their default values.

7. Let `result ownership` be the value of the
 `resultOwnership` field of `command parameters`, if
 present, or `none` otherwise.

8. Let `options` be the [default script fetch
 options](https://html.spec.whatwg.org/multipage/webappapis.html#default-script-fetch-options).

9. Let `base URL` be the [API base
 URL](https://html.spec.whatwg.org/multipage/webappapis.html#api-base-url) of `environment settings`.

10. Let `bypassDisabledScripting` be true.

11. Let `script` be the result of [create a classic
 script](https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-classic-script) with `source`,
 `environment settings`, `base URL`,
 `options` and `bypassDisabledScripting`.

12. If `command parameters`\[\"`userActivation`\"\] is true,
 run [activation
 notification](https://html.spec.whatwg.org/multipage/interaction.html#activation-notification) steps.

13. [Prepare to run
 script](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-script) with `environment settings`.

14. Set `evaluation status` to
 [ScriptEvaluation](https://tc39.es/ecma262/#sec-runtime-semantics-scriptevaluation)(`script`'s record).

15. If `evaluation status`.\[\[Type\]\] is `normal`,
 `await promise` is true, and
 [IsPromise](https://tc39.es/ecma262/#sec-ispromise)(`evaluation status`.\[\[Value\]\]):

 1. Set `evaluation status` to
 [Await](https://tc39.es/ecma262/#await)(`evaluation status`.\[\[Value\]\]).

16. [Clean up after running
 script](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script) with `environment settings`.

17. If `evaluation status`.\[\[Type\]\] is `throw`:

 1. Let `exception details` be the result of [get
 exception
 details](#get-exception-details) with `realm`,
 `evaluation status`, `result ownership`
 and `session`.

 2. Return a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.EvaluateResultException`
 production, with the `realm` field set to `realm id`,
 and the `exceptionDetails` field set to
 `exception details`.

18. Assert: `evaluation status`.\[\[Type\]\] is `normal`.

19. Let `result` be the result of [serialize as a remote
 value](#serialize-as-a-remote-value) with `evaluation status`.\[\[Value\]\],
 `serialization options`, `result ownership`, a
 new
 [map](https://infra.spec.whatwg.org/#ordered-map) as serialization internal map, `realm`
 and `session`.

20. Return a new
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.EvaluateResultSuccess`
 production, with the with the `realm` field set to
 `realm id`, and the `result` field set to
 `result`.

##### 7.6.4.5. The script.getRealms Command

The [script.getRealms] command returns a list of
all realms, optionally filtered to
[realms](https://tc39.es/ecma262/#sec-code-realms) of a specific type, or to the realm associated with a
[navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables)'s [active
document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

Command Type

: ```
 script.GetRealms = (
 method: "script.getRealms",
 params: script.GetRealmsParameters
 )

 script.GetRealmsParameters = {
 ? context: browsingContext.BrowsingContext,
 ? type: script.RealmType,
 }
 ```

Return Type

: ```
 script.GetRealmsResult = {
 realms: [*script.RealmInfo]
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `environment settings` be a
 [list](https://infra.spec.whatwg.org/#list) of all the [environment settings
 objects](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) that have their [execution ready
 flag](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-execution-ready-flag) set.

2. If `command parameters` contains `context`:

 1. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with
 `command parameters`\[\"`context`\"\].

 2. Let `document` be `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

 3. Let `navigable environment settings` be a
 [list](https://infra.spec.whatwg.org/#list).

 4. For each `settings` of
 `environment settings`:

 1. If any of the following conditions hold:

 - The [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) of `settings`' [relevant
 global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) is `document`

 - The [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global) specified by `settings` is a
 [`WorkerGlobalScope`](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope) with `document` in its [owner
 set](https://html.spec.whatwg.org/multipage/workers.html#concept-WorkerGlobalScope-owner-set)

 Append `settings` to
 `navigable environment settings`.

 5. Set `environment settings` to
 `navigable environment settings`.

3. Let `realms` be a list.

4. For each `settings` of `environment settings`:

 1. Let `realm info` be the result of [get the realm
 info](#get-the-realm-info) given `settings`.

 2. If `command parameters` contains `type` and
 `realm info`\[\"`type`\"\] is not equal to
 `command parameters`\[\"`type`\"\] then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 3. If `realm info` is not null, append
 `realm info` to `realms`.

5. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.GetRealmsResult` production,
 with the `realms` field set to `realms`.

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

Extend this to also allow realm parents
e.g. for nested workers? Or get all ancestor workers.

We might want to have a more
sophisticated filter system than just a literal match.

##### 7.6.4.6. The script.removePreloadScript Command

The [script.removePreloadScript] command
removes a [preload script](#preload-script).

Command Type

: ```
 script.RemovePreloadScript = (
 method: "script.removePreloadScript",
 params: script.RemovePreloadScriptParameters
 )

 script.RemovePreloadScriptParameters = {
 script: script.PreloadScript
 }
 ```

Return Type

: ```
 script.RemovePreloadScriptResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `script` be the value of the \"`script`\" field in
 `command parameters`.

2. Let `preload script map` be `session`'s
 [preload script
 map](#preload-script-map).

3. If `preload script map` does not
 [contain](https://infra.spec.whatwg.org/#map-exists) `script`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 script](#errors-no-such-script).

4. [Remove](https://infra.spec.whatwg.org/#list-remove) `script` from
 `preload script map`.

5. Return null

#### 7.6.5. Events

##### 7.6.5.1. The script.message Event

Event Type

: ```
 script.Message = (
 method: "script.message",
 params: script.MessageParameters
 )

 script.MessageParameters = {
 channel: script.Channel,
 data: script.RemoteValue,
 source: script.Source,
 }
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is the [emit a script message] steps, given
`session`, `realm`,
`channel properties`, and `message`:

1. Let `environment settings` be the [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component is `realm`.

2. Let `related navigables` be the result of [get related
 navigables](#get-related-navigables) given `environment settings`.

3. If [event is enabled](#event-is-enabled) given `session`, \"`script.message`\"
 and `related navigables`:

 1. If `channel properties`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`serializationOptions`\", let
 `serialization options` be the value of the
 `serializationOptions` field of `channel properties`.
 Otherwise let `serialization options` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.SerializationOptions`
 production with the fields set to their default values.

 2. Let if `channel properties`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`ownership`\", let
 `ownership type` be
 `channel properties`\[\"`ownership`\"\]. Otherwise
 let `ownership type` be \"`none`\".

 3. Let `data` be the result of [serialize as a remote
 value](#serialize-as-a-remote-value) given `message`,
 `serialization options`, `ownership type`,
 a new
 [map](https://infra.spec.whatwg.org/#ordered-map) as serialization internal map and
 `realm`.

 4. Let `source` be the [get the
 source](#get-the-source) with `realm`.

 5. Let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.MessageParameters`
 production, with the `channel` field set to
 `channel properties`\[\"`channel`\"\], the `data`
 field set to `data`, and the `source` field set to
 `source`.

 6. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.Message` production, with
 the `params` field set to `params`.

 7. [Emit an event](#emit-an-event) with `session` and
 `body`.

##### 7.6.5.2. The script.realmCreated Event

Event Type

: ```
 script.RealmCreated = (
 method: "script.realmCreated",
 params: script.RealmInfo
 )
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is:

When any of the [set up a window environment settings
object](https://html.spec.whatwg.org/multipage/nav-history-apis.html#set-up-a-window-environment-settings-object), [set up a worker environment settings
object](https://html.spec.whatwg.org/multipage/workers.html#set-up-a-worker-environment-settings-object) or [set up a worklet environment settings
object](https://html.spec.whatwg.org/multipage/worklets.html#set-up-a-worklet-environment-settings-object) algorithms are invoked, immediately prior to returning
the settings object:

1. Let `environment settings` be the newly created
 [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object).

2. Let `realm info` be the result of [get the realm
 info](#get-the-realm-info) given `environment settings`.

3. If `realm info` is null, return.

4. Let `related navigables` be the result of [get related
 navigables](#get-related-navigables) given `environment settings`.

5. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.RealmCreated` production, with
 the `params` field set to `realm info`.

6. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`script.realmCreated`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

The [remote end subscribe
steps](#event-remote-end-subscribe-steps) with [subscribe
priority](#event-subscribe-priority) 2, given `session`, `navigables`
and `include global` are:

1. Let `environment settings` be a list of all the
 [environment settings
 objects](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) that have their [execution ready
 flag](https://html.spec.whatwg.org/multipage/webappapis.html#concept-environment-execution-ready-flag) set.

2. For each `settings` of `environment settings`:

 1. Let `related navigables` be a new
 [set](https://infra.spec.whatwg.org/#ordered-set).

 2. If the [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) of `settings`' [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global) is a
 [Document](https://dom.spec.whatwg.org/#concept-document):

 1. Let `navigable` be `settings`'s
 [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window)'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable).

 2. If `navigable` is null, continue.

 3. Let `top-level traversible` be
 `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

 4. If `top-level traversible` is not in
 `navigables`, continue.

 5. Append `top-level traversible` to
 `related navigables`.

 Otherwise, if `include global` is false, continue.

 3. Let `realm info` be the result of [get the realm
 info](#get-the-realm-info) given `settings`.

 4. If `realm info` is null, continue.

 5. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.RealmCreated` production,
 with the `params` field set to `realm info`.

 6. If [event is
 enabled](#event-is-enabled) given `session`,
 \"`script.realmCreated`\" and `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

Should the order here be better defined?

##### 7.6.5.3. The script.realmDestroyed Event

Event Type

: ```
 script.RealmDestroyed = (
 method: "script.realmDestroyed",
 params: script.RealmDestroyedParameters
 )

 script.RealmDestroyedParameters = {
 realm: script.Realm
 }
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is:

Define the following [unloading document cleanup
steps](https://html.spec.whatwg.org/multipage/document-lifecycle.html#unloading-document-cleanup-steps) with `document`:

1. Let `related navigables` be an empty
 [set](https://infra.spec.whatwg.org/#ordered-set).

2. Append `document`'s
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables) to `related navigables`.

3. For each `worklet global scope` in
 `document`'s [worklet global
 scopes](https://html.spec.whatwg.org/multipage/worklets.html#concept-document-worklet-global-scopes):

 1. Let `realm` be `worklet global scope`'s
 [relevant
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm).

 2. Let `realm id` be the [realm
 id](#realm-id) for
 `realm`.

 3. Let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.RealmDestroyedParameters`
 production, with the `realm` field set of `realm id`.

 4. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.RealmDestroyed`
 production, with the `params` field set to `params`.

 5. For each `session` in the [set of sessions for which
 an event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`script.realmDestroyed`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

4. Let `environment settings` be the [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is `document`.

5. Let `realm` be `environment settings`' [realm
 execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component.

6. Let `realm id` be the [realm
 id](#realm-id) for
 `realm`.

7. Let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.RealmDestroyedParameters`
 production, with the `realm` field set to `realm id`.

8. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.RealmDestroyed` production,
 with the `params` field set to `params`.

9. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`script.realmDestroyed`\" and
 `related navigables`:

 1. [Emit an event](#emit-an-event) with `session` and
 `body`.

Whenever a [worker event
loop](https://html.spec.whatwg.org/multipage/webappapis.html#worker-event-loop-2) `event loop` is destroyed, either because
the worker comes to the end of its lifecycle, or prematurely via the
[terminate a
worker](https://html.spec.whatwg.org/multipage/workers.html#terminate-a-worker) algorithm:

1. Let `environment settings` be the [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) for which `event loop` is the
 [responsible event
 loop](https://html.spec.whatwg.org/multipage/webappapis.html#responsible-event-loop).

2. Let `related navigables` be the result of [get related
 navigables](#get-related-navigables) given `environment settings`.

3. Let `realm` be `environment settings`'s
 [environment settings object's
 Realm](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object's-realm).

4. Let `realm id` be the [realm
 id](#realm-id) for
 `realm`.

5. Let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.RealmDestroyedParameters`
 production, with the `realm` field set of `realm id`.

6. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.RealmDestroyed` production,
 with the `params` field set to `params`.

### 7.7. The storage Module

The [storage] module contains functionality and events
related to storage.

A [storage partition] is a namespace within which the user agent
may organize persistent data such as
[cookies](https://httpwg.org/specs/rfc6265.html) and local storage.

A [storage partition key] is a
[map](https://infra.spec.whatwg.org/#ordered-map) which uniquely identifies a [storage
partition](#storage-partition).

#### 7.7.1. Definition

[`Remote end definition`](#cddl-module-remote-end-definition)

```
StorageCommand = (
 storage.DeleteCookies //
 storage.GetCookies //
 storage.SetCookie
)
```

[`Local end definition`](#cddl-module-local-end-definition)

```
StorageResult = (
 storage.DeleteCookiesResult /
 storage.GetCookiesResult /
 storage.SetCookieResult
)
```

#### 7.7.2. Types

##### 7.7.2.1. The storage.PartitionKey Type

[`Local end definition`](#cddl-module-local-end-definition)

```
storage.PartitionKey = {
 ? userContext: text,
 ? sourceOrigin: text,
 Extensible,
}
```

The `storage.PartitionKey` type represents a [storage partition
key](#storage-partition-key).

The following [table of standard storage partition key
attributes] enumerates attributes with
well-known meanings which a [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) may choose to support. An implementation may define
additional [extension storage partition key
attributes](#extension-storage-partition-key-attributes).

Attribute

Definition

\"`userContext`\"

A [user context
id](#user-context-user-context-id)

\"`sourceOrigin"`

The [serialization of the
origin](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin) of resources that can access the storage partition

[Remote
ends](https://w3c.github.io/webdriver/#dfn-remote-ends) may support any number of [extension storage partition
key attributes]. In order
to avoid conflicts with other implementations, these attributes must
begin with a unique identifier for the vendor and user-agent followed by
U+003A (:).

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a
[map](https://infra.spec.whatwg.org/#ordered-map) of [default values for storage partition key
attributes]
which contains zero or more entries. Each key must be a member of the
[table of standard storage partition key
attributes](#table-of-standard-storage-partition-key-attributes) where the [storage partition
key](#storage-partition-key) corresponds to a standard storage partition, or an
[extension storage partition key
attribute](#extension-storage-partition-key-attributes) where it does not, and the values represent the default
value of that partition key that will be used when the user doesn't
provide an explicit value. The precise entries are
implementation-defined and are determined by the storage partitioning
adopted by the implementation.

A [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends) has a
[list](https://infra.spec.whatwg.org/#list) of [required partition key
attributes] which
contains zero or more entries. Each key must be a member of the [table
of standard storage partition key
attributes](#table-of-standard-storage-partition-key-attributes) where the [storage partition
key](#storage-partition-key) corresponds to a standard storage partition, or an
[extension storage partition key
attribute](#extension-storage-partition-key-attributes) where it does not. The precise entries are
implementation-defined and are determined by the storage partitioning
adopted by the implementation. This list includes only partition keys
for which no default is available. As such the list must not share any
entries with the keys of [default values for storage partition key
attributes](#default-values-for-storage-partition-key-attributes).

To [deserialize filter] given `filter`:

1. Let `deserialized filter` to be an empty
 [map](https://infra.spec.whatwg.org/#ordered-map).

2. For each `name` → `value` in
 `filter`:

 1. Let `deserialized name` be the field name
 corresponding to the JSON key `name` in the [table
 for cookie
 conversion](https://w3c.github.io/webdriver/#dfn-table-for-cookie-conversion).

 2. If `name` is \"`value`\", set
 `deserialized value` to [deserialize protocol
 bytes](#deserialize-protocol-bytes) with `value`, otherwise let
 `deserialized value` be `value`.

 3. [Set](https://infra.spec.whatwg.org/#map-set)
 `deserialized filter`\[`deserialized name`\]
 to `deserialized value`.

3. Return `deserialized filter`.

To [expand a storage partition spec] given
`partition spec`:

1. If `partition spec` is null:

 1. Set `partition spec` to an empty
 [map](https://infra.spec.whatwg.org/#ordered-map).

2. Otherwise, if `partition spec`\[\"`type`\"\] is
 \"`context`\":

 1. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) given
 `partition spec`\[\"`context`\"\].

 2. Let `partition key` be the
 [key](#storage-partition-key) of `navigable`'s [associated storage
 partition](#associated-storage-partition).

 3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `partition key`.

3. Let `partition key` be an empty
 [map](https://infra.spec.whatwg.org/#ordered-map).

4. For each `name` → `default value` in the
 [default values for storage partition key
 attributes](#default-values-for-storage-partition-key-attributes):

 1. Let `value` be
 `partition spec`\[`name`\] if it
 [exists](https://infra.spec.whatwg.org/#map-exists) or `default value` otherwise.

 2. [Set](https://infra.spec.whatwg.org/#map-set) `partition key`\[`name`\]
 to `value`.

5. For each `name` in the remote end's [required partition
 key
 attributes](#required-partition-key-attributes):

 1. If `partition spec`\[`name`\]
 [exists](https://infra.spec.whatwg.org/#map-exists):

 1. [Set](https://infra.spec.whatwg.org/#map-set)
 `partition key`\]\[`name`\] to
 `partition spec`\[`name`\].

 2. Otherwise:

 1. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [underspecified storage
 partition](#errors-underspecified-storage-partition).

6. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `partition key`.

To [get the cookie store] given `storage partition key`:

1. If `storage partition key` uniquely identifies an extant
 [storage partition](#storage-partition):

 1. Let `store` be the [cookie
 store](https://httpwg.org/specs/rfc6265.html#storage-model) of that [storage
 partition](#storage-partition).

 2. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `store`.

2. Return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such storage
 partition](#errors-no-such-storage-partition).

To [match cookie] given `stored cookie` and `filter`:

1. For each `name` → `value` in
 `filter`:

 1. If `stored cookie`\[`name`\] does not
 equal `value`:

 1. Return false.

2. Return true.

To [get matching cookies] given `cookie store` and
`filter`:

1. Let `cookies` be a new list.

2. Set `deserialized filter` to [deserialize
 filter](#deserialize-filter) with `filter`.

3. For each `stored cookie` in `cookie store`:

 1. If [match cookie](#match-cookie) with `stored cookie` and
 `deserialized filter` is true:

 1. Append `stored cookie` to `cookies`.

4. Return `cookies`.

#### 7.7.3. Commands

##### 7.7.3.1. The storage.getCookies Command

The [storage.getCookies] command retrieves zero or
more
[cookies](https://httpwg.org/specs/rfc6265.html) which [match](#match-cookie) a set of provided parameters.

Command Type

: ```
 storage.GetCookies = (
 method: "storage.getCookies",
 params: storage.GetCookiesParameters
 )

 storage.CookieFilter = {
 ? name: text,
 ? value: network.BytesValue,
 ? domain: text,
 ? path: text,
 ? size: js-uint,
 ? httpOnly: bool,
 ? secure: bool,
 ? sameSite: network.SameSite,
 ? expiry: js-uint,
 Extensible,
 }

 storage.BrowsingContextPartitionDescriptor = {
 type: "context",
 context: browsingContext.BrowsingContext
 }

 storage.StorageKeyPartitionDescriptor = {
 type: "storageKey",
 ? userContext: text,
 ? sourceOrigin: text,
 Extensible,
 }

 storage.PartitionDescriptor = (
 storage.BrowsingContextPartitionDescriptor /
 storage.StorageKeyPartitionDescriptor
 )

 storage.GetCookiesParameters = {
 ? filter: storage.CookieFilter,
 ? partition: storage.PartitionDescriptor,
 }
 ```

Return Type

: ```
 storage.GetCookiesResult = {
 cookies: [*network.Cookie],
 partitionKey: storage.PartitionKey,
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `filter` be the value of the `filter` field of
 `command parameters` if it is present or an empty
 [map](https://infra.spec.whatwg.org/#ordered-map) if it isn't.

2. Let `partition spec` be the value of the `partition`
 field of `command parameters` if it is present or null if
 it isn't.

3. Let `partition key` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [expand a storage partition
 spec](#expand-a-storage-partition-spec) with `partition spec`.

4. Let `store` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get the cookie
 store](#get-the-cookie-store) with `partition key`.

5. Let `cookies` be the result of [get matching
 cookies](#get-matching-cookies) with `store` and `filter`.

6. Let `serialized cookies` be a new list.

7. For each `cookie` in `cookies`:

 1. Let `serialized cookie` be the result of [serialize
 cookie](#serialize-cookie) given `cookie`.

 2. Append `serialized cookie` to
 `serialized cookies`.

8. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `storage.GetCookiesResult` production,
 with the `cookies` field set to `serialized cookies` and
 the `partitionKey` field set to `partition key`.

9. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

##### 7.7.3.2. The storage.setCookie Command

The [storage.setCookie] command creates a new
[cookie](https://httpwg.org/specs/rfc6265.html) in a cookie store, replacing any cookie in that store
which matches according to
[\[COOKIES\]](#biblio-cookies "HTTP State Management Mechanism").

Command Type

: ```
 storage.SetCookie = (
 method: "storage.setCookie",
 params: storage.SetCookieParameters,
 )

 storage.PartialCookie = {
 name: text,
 value: network.BytesValue,
 domain: text,
 ? path: text,
 ? httpOnly: bool,
 ? secure: bool,
 ? sameSite: network.SameSite,
 ? expiry: js-uint,
 Extensible,
 }

 storage.SetCookieParameters = {
 cookie: storage.PartialCookie,
 ? partition: storage.PartitionDescriptor,
 }
 ```

Return Type

: ```
 storage.SetCookieResult = {
 partitionKey: storage.PartitionKey
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `cookie spec` be the value of the `cookie` field of
 `command parameters`.

2. Let `partition spec` be the value of the `partition`
 field of `command parameters` if it is present or null if
 it isn't.

3. Let `partition key` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [expand a storage partition
 spec](#expand-a-storage-partition-spec) with `partition spec`.

4. Let `store` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get the cookie
 store](#get-the-cookie-store) with `partition key`.

5. Let `deserialized value` be [deserialize protocol
 bytes](#deserialize-protocol-bytes) with `cookie spec`\[\"`value`\"\].

6. [Create a
 cookie](https://w3c.github.io/webdriver/#dfn-creating-a-cookie) in `store` using [cookie
 name](https://w3c.github.io/webdriver/#dfn-cookie-name) `cookie spec`\[\"`name`\"\], [cookie
 value](https://w3c.github.io/webdriver/#dfn-cookie-value) `deserialized value`, [cookie
 domain](https://w3c.github.io/webdriver/#dfn-cookie-domain) `cookie spec`\[\"`domain`\"\], and an
 attribute-value list of the following cookie concepts listed in the
 [table for cookie
 conversion](https://w3c.github.io/webdriver/#dfn-table-for-cookie-conversion):

 [Cookie path](https://w3c.github.io/webdriver/#dfn-cookie-path)

 : `cookie spec`\[\"`path`\"\] if it exists, otherwise
 \"`/`\".

 [Cookie secure only](https://w3c.github.io/webdriver/#dfn-cookie-secure-only)

 : `cookie spec`\[\"`secure`\"\] if it exists, otherwise
 false.

 [Cookie HTTP only](https://w3c.github.io/webdriver/#dfn-cookie-http-only)

 : `cookie spec`\[\"`httpOnly`\"\] if it exists,
 otherwise false.

 [Cookie expiry time](https://w3c.github.io/webdriver/#dfn-cookie-expiry-time)

 : `cookie spec`\[\"`expiry`\"\] if it exists, otherwise
 leave unset to indicate that this is a session cookie.

 The cookie's expiry value might be limited by
 the remote end in accordance with the [Cookie Lifetime
 Limits](https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis-20.html#cookie-lifetime-limits).

 [Cookie same site](https://w3c.github.io/webdriver/#dfn-cookie-same-site)

 : `cookie spec`\[\"`sameSite`\"\] if it exists,
 otherwise leave unset to indicate that no same site policy is
 defined.

 If this step is aborted without inserting a cookie into the cookie
 store, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unable to set
 cookie](#errors-unable-to-set-cookie).

7. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `storage.SetCookieResult` production,
 with the `partitionKey` field set to `partition key`.

8. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

##### 7.7.3.3. The storage.deleteCookies Command

The [storage.deleteCookies] command
removes zero or more
[cookies](https://httpwg.org/specs/rfc6265.html) which [match](#match-cookie) a set of provided parameters.

Command Type

: ```
 storage.DeleteCookies = (
 method: "storage.deleteCookies",
 params: storage.DeleteCookiesParameters,
 )

 storage.DeleteCookiesParameters = {
 ? filter: storage.CookieFilter,
 ? partition: storage.PartitionDescriptor,
 }
 ```

Return Type

: ```
 storage.DeleteCookiesResult = {
 partitionKey: storage.PartitionKey
 }
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `filter` be the value of the `filter` field of
 `command parameters` if it is present or an empty
 [map](https://infra.spec.whatwg.org/#ordered-map) if it isn't.

2. Let `partition spec` be the value of the `partition`
 field of `command parameters` if it is present or null if
 it isn't.

3. Let `partition key` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [expand a storage partition
 spec](#expand-a-storage-partition-spec) with `partition spec`.

4. Let `store` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get the cookie
 store](#get-the-cookie-store) with `partition key`.

5. Let `cookies` be the result of [get matching
 cookies](#get-matching-cookies) with `store` and `filter`.

6. For each `cookie` in `cookies`:

 1. Remove `cookie` from `store`.

7. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `storage.DeleteCookiesResult`
 production, with the `partitionKey` field set to
 `partition key`.

8. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `body`.

### 7.8. The log Module

The [log] module contains functionality and events
related to logging.

A [BiDi Session](#bidi-session)
has a [log event buffer] which is a
[map](https://infra.spec.whatwg.org/#ordered-map) from [navigable
id](#navigable-id) to a list of
log events for that context that have not been emitted. User agents may
impose a maximum size on this buffer, subject to the condition that if
events A and B happen in the same context with A occurring before B, and
both are added to the buffer, the entry for B must not be removed before
the entry for A.

To [buffer a log event] given `session`,
`navigables` and `event`:

1. Let `buffer` be `session`'s [log event
 buffer](#log-event-buffer).

2. Let `navigable ids` be a new list.

3. For each `navigable` of `navigables`:

 1. Append the [navigable id](#navigable-id) for `navigable` to
 `navigable ids`.

4. For each `navigable id` in `navigable ids`:

 1. Let `other navigables` be an empty
 [list](https://infra.spec.whatwg.org/#list)

 2. For each `other id` in `navigable ids`:

 3. If `other id` is not equal to
 `navigable id`, append `other id` to
 `other navigables`.

 4. If `buffer` does not contain
 `navigable id`, let
 `buffer`\[`navigable id`\] be a new list.

 5. Append (`event`, `other navigables`) to
 `buffer`\[`navigable id`\].

 we store the other navigables here so that each event
is only emitted once. In practice this is only relevant for workers that
can be associated with multiple navigables.

Do we want to key this on browsing
context or top-level traversable? The difference is in what happens if
an event occurs in a frame and that frame is then navigated before the
local end subscribes to log events for the top level navigable.

#### 7.8.1. Definition

[`Local end definition`](#cddl-module-local-end-definition)

```
LogEvent = (
 log.EntryAdded
)
```

#### 7.8.2. Types

##### 7.8.2.1. log.LogEntry

[`Local end definition`](#cddl-module-local-end-definition)

```
log.Level = "debug" / "info" / "warn" / "error"

log.Entry = (
 log.GenericLogEntry /
 log.ConsoleLogEntry /
 log.JavascriptLogEntry
)

log.BaseLogEntry = (
 level: log.Level,
 source: script.Source,
 text: text / null,
 timestamp: js-uint,
 ? stackTrace: script.StackTrace,
)

log.GenericLogEntry = {
 log.BaseLogEntry,
 type: text,
}

log.ConsoleLogEntry = {
 log.BaseLogEntry,
 type: "console",
 method: text,
 args: [*script.RemoteValue],
}

log.JavascriptLogEntry = {
 log.BaseLogEntry,
 type: "javascript",
}
```

Each log event is represented by a `log.Entry` object. This has a `type`
property which represents the type of log entry added, a `level`
property representing severity, a `source` property representing the
origin of the log entry, a `text` property with the log message string
itself, and a `timestamp` property corresponding to the time the log
entry was generated. Specific variants of the `log.Entry` are used to
represent logs from different sources, and provide additional fields
specific to the entry type.

#### 7.8.3. Events

##### 7.8.3.1. The log.entryAdded Event

Event Type

: ```
 log.EntryAdded = (
 method: "log.entryAdded",
 params: log.Entry,
 )
 ```

The [remote end event
trigger](#event-remote-end-event-trigger) is:

Define the following [console
steps](#console-steps) with
`method`, `args`, and `options`:

1. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If `method` is \"`error`\" or \"`assert`\", let
 `level` be \"`error`\". If `method` is
 \"`debug`\" or \"`trace`\" let `level` be
 \"`debug`\". If `method` is \"`warn`\", let
 `level` be \"`warn`\". Otherwise let
 `level` be \"`info`\".

 2. Let `timestamp` be a [time
 value](https://tc39.es/ecma262/#sec-time-values-and-time-range) representing the current date and time in UTC.

 3. Let `text` be an empty string.

 4. If
 [Type](https://tc39.es/ecma262/#sec-ecmascript-data-types-and-values)(`args`\[0\]) is String, and
 `args`\[0\] contains a [formatting
 specifier](https://console.spec.whatwg.org#formatting-specifiers), let `formatted args` be
 [Formatter](https://console.spec.whatwg.org#formatter)(`args`). Otherwise let
 `formatted args` be `args`.

 The formatter operation is underdefined in the
 console specification, formatting can be inconsistent between
 different implementations.

 5. For each `arg` in `formatted args`:

 1. If `arg` is not the first entry in
 `args`, append a U+0020 SPACE to
 `text`.

 2. If `arg` is a [primitive ECMAScript
 value](https://tc39.es/ecma262/#sec-primitive-value), append
 [ToString](https://tc39.es/ecma262/#sec-tostring)(`arg`) to `text`.
 Otherwise append an implementation-defined string to
 `text`.

 6. Let `realm` be the [realm
 id](#realm-id) of the
 [current Realm
 Record](https://tc39.es/ecma262/#current-realm).

 7. Let `serialized args` be a new list.

 8. Let `serialization options` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `script.SerializationOptions`
 production with the fields set to their default values.

 9. For each `arg` of `args`:

 1. Let `serialized arg` be the result of [serialize
 as a remote
 value](#serialize-as-a-remote-value) with `arg` as value,
 `serialization options`, `none` as ownership
 type, a new
 [map](https://infra.spec.whatwg.org/#ordered-map) as serialization internal map,
 `realm` and `session`.

 2. Add `serialized arg` to
 `serialized args`.

 10. Let `source` be the result of [get the
 source](#get-the-source) given [current Realm
 Record](https://tc39.es/ecma262/#current-realm).

 11. Let `stack` be the [current stack
 trace](#current-stack-trace).

 12. Let `entry` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `log.ConsoleLogEntry` production,
 with the the `level` field set to `level`, the `text`
 field set to `text`, the `timestamp` field set to
 `timestamp`, the `stackTrace` field set to
 `stack`, the `method` field set to
 `method`, the `source` field set to
 `source`, and the `args` field set to
 `serialized args`.

 13. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `log.EntryAdded` production, with
 the `params` field set to `entry`.

 14. Let `settings` be the [current settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object)

 15. Let `related navigables` be the result of [get
 related
 navigables](#get-related-navigables) given `settings`.

 16. If [event is
 enabled](#event-is-enabled) with `session`, \"`log.entryAdded`\"
 and `related navigables`, [emit an
 event](#emit-an-event)
 with `session` and `body`.

 Otherwise, [buffer a log
 event](#buffer-a-log-event) with `session`,
 `related browsing contexts`, and `body`.

Define the following [error reporting
steps](#error-reporting-steps) with arguments `script`,
`line number`, `column number`,
`message` and `handled`:

1. If `handled` is true return.

2. Let `settings` be `script`'s [settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#settings-object).

3. Let `timestamp` be a [time
 value](https://tc39.es/ecma262/#sec-time-values-and-time-range) representing the current date and time in UTC.

4. Let `stack` be the [stack trace for an
 exception](#stack-trace-for-an-exception) with the exception corresponding to the error being
 reported.

5. Let `source` be the result of [get the
 source](#get-the-source)
 given [current Realm
 Record](https://tc39.es/ecma262/#current-realm).

6. Let `entry` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `log.JavascriptLogEntry` production,
 with `level` set to \"`error`\", `text` set to `message`,
 `source` set to `source`, `timestamp` set to
 `timestamp`, and the `stackTrace` field set to
 `stack`.

7. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `log.EntryAdded` production, with the
 `params` field set to `entry`.

8. Let `related navigables` be the result of [get related
 navigables](#get-related-navigables) given `settings`.

9. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. If [event is
 enabled](#event-is-enabled) with `session`, \"`log.entryAdded`\"
 and `related navigables`, [emit an
 event](#emit-an-event)
 with `session` and `body`.

 Otherwise, [buffer a log
 event](#buffer-a-log-event) with `session`,
 `related browsing contexts`, and `body`.

Lots more things require logging. CDP
has LogEntryAdded types xml, javascript, network, storage, appcache,
rendering, security, deprecation, worker, violation, intervention,
recommendation, other. These are in addition to the js exception and
console API types that are represented by different methods.

Allow implementation-defined log types

The [remote end subscribe
steps](#event-remote-end-subscribe-steps), with [subscribe
priority](#event-subscribe-priority) 10, given `session`, `navigables`
and `include global` are:

1. For each `navigable id` → `events` in
 `session`'s [log event
 buffer](#log-event-buffer):

 1. Let `maybe context` be the result of [getting a
 navigable](#get-a-navigable) given `navigable id`.

 2. If `maybe context` is an
 [error](https://w3c.github.io/webdriver/#errors), remove `navigable id` from [log
 event buffer](#log-event-buffer) and continue.

 3. Let `navigable` be `maybe context`'s data

 4. Let `top level navigable` be `navigable`'s
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

 5. If `include global` is true and
 `top level navigable` is not in
 `navigables`, or if `include global` is
 false and `top level navigable` is in
 `navigables`:

 1. For each (`event`, `other navigables`)
 in `events`:

 1. [Emit an event](#emit-an-event) with `session` and
 `event`.

 2. For each `other context id` in
 `other navigables`:

 1. If [log event
 buffer](#log-event-buffer) contains
 `other context id`, remove
 `event` from [log event
 buffer](#log-event-buffer)\[`other context id`\].

### 7.9. The input Module

The [input] module contains functionality for simulated
user input.

#### 7.9.1. Definition

[`remote end definition`](#cddl-module-remote-end-definition)

```
InputCommand = (
 input.PerformActions //
 input.ReleaseActions //
 input.SetFiles
)
```

```
InputResult = (
 input.PerformActionsResult /
 input.ReleaseActionsResult /
 input.SetFilesResult
)
```

[`local end definition`](#cddl-module-local-end-definition)

```
InputEvent = (
 input.FileDialogOpened
)
```

#### 7.9.2. Types

##### 7.9.2.1. input.ElementOrigin

The `input.ElementOrigin` type represents an
[`Element`](https://dom.spec.whatwg.org/#element) that will be used as a coordinate origin.

```
input.ElementOrigin = {
 type: "element",
 element: script.SharedReference
}
```

The [is `input.ElementOrigin`] steps given `object` are:

1. If `object` is a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `input.ElementOrigin` production,
 return true.

2. Return false.

To [get Element from `input.ElementOrigin`
steps] given `session`:

1. Return the following steps, given `origin` and
 `navigable`:

 1. Assert: `origin` matches `input.ElementOrigin`.

 2. Let `document` be `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

 3. Let `reference` be
 `origin`\[\"`element`\"\]

 4. Let `environment settings` be the [environment
 settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is `document`.

 5. Let `realm` be `environment settings`'
 [realm execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component.

 6. Let `element` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize remote
 reference](#deserialize-remote-reference) with `reference`,
 `realm`, and `session`.

 7. If `element` doesn't implement
 [`Element`](https://dom.spec.whatwg.org/#element) return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 element](https://w3c.github.io/webdriver/#dfn-no-such-element).

 8. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `element`.

#### 7.9.3. Commands

##### 7.9.3.1. The input.performActions Command

The [input.performActions] command
performs a specified sequence of user input actions.

 for a detailed description of the behavior of this
command, see the
[actions](https://w3c.github.io/webdriver/#actions) section of
[\[WEBDRIVER\]](#biblio-webdriver "WebDriver").

Command Type

: ```
 input.PerformActions = (
 method: "input.performActions",
 params: input.PerformActionsParameters
 )

 input.PerformActionsParameters = {
 context: browsingContext.BrowsingContext,
 actions: [*input.SourceActions]
 }

 input.SourceActions = (
 input.NoneSourceActions /
 input.KeySourceActions /
 input.PointerSourceActions /
 input.WheelSourceActions
 )

 input.NoneSourceActions = {
 type: "none",
 id: text,
 actions: [*input.NoneSourceAction]
 }

 input.NoneSourceAction = input.PauseAction

 input.KeySourceActions = {
 type: "key",
 id: text,
 actions: [*input.KeySourceAction]
 }

 input.KeySourceAction = (
 input.PauseAction /
 input.KeyDownAction /
 input.KeyUpAction
 )

 input.PointerSourceActions = {
 type: "pointer",
 id: text,
 ? parameters: input.PointerParameters,
 actions: [*input.PointerSourceAction]
 }

 input.PointerType = "mouse" / "pen" / "touch"

 input.PointerParameters = {
 ? pointerType: input.PointerType .default "mouse"
 }

 input.PointerSourceAction = (
 input.PauseAction /
 input.PointerDownAction /
 input.PointerUpAction /
 input.PointerMoveAction
 )

 input.WheelSourceActions = {
 type: "wheel",
 id: text,
 actions: [*input.WheelSourceAction]
 }

 input.WheelSourceAction = (
 input.PauseAction /
 input.WheelScrollAction
 )

 input.PauseAction = {
 type: "pause",
 ? duration: js-uint
 }

 input.KeyDownAction = {
 type: "keyDown",
 value: text
 }

 input.KeyUpAction = {
 type: "keyUp",
 value: text
 }

 input.PointerUpAction = {
 type: "pointerUp",
 button: js-uint,
 }

 input.PointerDownAction = {
 type: "pointerDown",
 button: js-uint,
 input.PointerCommonProperties
 }

 input.PointerMoveAction = {
 type: "pointerMove",
 x: float,
 y: float,
 ? duration: js-uint,
 ? origin: input.Origin,
 input.PointerCommonProperties
 }

 input.WheelScrollAction = {
 type: "scroll",
 x: js-int,
 y: js-int,
 deltaX: js-int,
 deltaY: js-int,
 ? duration: js-uint,
 ? origin: input.Origin .default "viewport",
 }

 input.PointerCommonProperties = (
 ? width: js-uint .default 1,
 ? height: js-uint .default 1,
 ? pressure: float .default 0.0,
 ? tangentialPressure: float .default 0.0,
 ? twist: (0..359) .default 0,
 ; 0 .. Math.PI / 2
 ? altitudeAngle: (0.0..1.5707963267948966) .default 0.0,
 ; 0 .. 2 * Math.PI
 ? azimuthAngle: (0.0..6.283185307179586) .default 0.0,
 )

 input.Origin = "viewport" / "pointer" / input.ElementOrigin
 ```

Return Type

: ```
 input.PerformActionsResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `session` and
`command parameters` are:

1. Let `navigable id` be the value of the `context` field of
 `command parameters`.

2. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

3. Let `input state` be [get the input
 state](https://w3c.github.io/webdriver/#dfn-get-the-input-state) with `session` and
 `navigable`'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

4. Let `actions options` be a new [actions
 options](https://w3c.github.io/webdriver/#dfn-actions-options) with the [is element
 origin](https://w3c.github.io/webdriver/#dfn-is-element-origin) steps set to [is
 input.ElementOrigin](#is-inputelementorigin), and the [get element
 origin](https://w3c.github.io/webdriver/#dfn-get-element-origin) steps set to the result of [get Element from
 input.ElementOrigin
 steps](#get-element-from-inputelementorigin-steps) given `session`.

5. Let `actions by tick` be the result of trying to [extract
 an action
 sequence](https://w3c.github.io/webdriver/#dfn-extract-an-action-sequence) with `input state`,
 `command parameters`, and `actions options`.

6. [Try](https://w3c.github.io/webdriver/#dfn-try) to [dispatch
 actions](https://w3c.github.io/webdriver/#dfn-dispatch-actions) with `input state`,
 `actions by tick`, `navigable`, and
 `actions options`.

7. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.9.3.2. The input.releaseActions Command

The [input.releaseActions] command resets
the input state associated with the current session.

Command Type

: ```
 input.ReleaseActions = (
 method: "input.releaseActions",
 params: input.ReleaseActionsParameters
 )

 input.ReleaseActionsParameters = {
 context: browsingContext.BrowsingContext,
 }
 ```

Return Type

: ```
 input.ReleaseActionsResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session`, and
`command parameters` are:

1. Let `navigable id` be the value of the `context` field of
 `command parameters`.

2. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

3. Let `top-level traversable` be `navigable`'s
 [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top).

4. Let `input state` be [get the input
 state](https://w3c.github.io/webdriver/#dfn-get-the-input-state) with `session` and
 `top-level traversable`.

5. Let `actions options` be a new [actions
 options](https://w3c.github.io/webdriver/#dfn-actions-options) with the [is element
 origin](https://w3c.github.io/webdriver/#dfn-is-element-origin) steps set to [is
 input.ElementOrigin](#is-inputelementorigin), and the [get element
 origin](https://w3c.github.io/webdriver/#dfn-get-element-origin) steps set to [get Element from input.ElementOrigin
 steps](#get-element-from-inputelementorigin-steps) given `session`.

6. Let `undo actions` be `input state`'s [input
 cancel
 list](https://w3c.github.io/webdriver/#dfn-input-cancel-list) in reverse order.

7. [Try](https://w3c.github.io/webdriver/#dfn-try) to [dispatch tick
 actions](https://w3c.github.io/webdriver/#dfn-dispatch-tick-actions) with `undo actions`, 0,
 `navigable`, and `actions options`.

8. [Reset the input
 state](https://w3c.github.io/webdriver/#dfn-reset-the-input-state) with `session` and
 `top-level traversable`.

9. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

##### 7.9.3.3. The input.setFiles Command

The [input.setFiles] command sets the `files`
property of a given `input` element with type `file` to a set of file
paths.

Command Type

: ```
 input.SetFiles = (
 method: "input.setFiles",
 params: input.SetFilesParameters
 )

 input.SetFilesParameters = {
 context: browsingContext.BrowsingContext,
 element: script.SharedReference,
 files: [*text]
 }
 ```

Return Type

: ```
 input.SetFilesResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) given `session` and
`command parameters` are:

1. Let `navigable id` be the value of the
 `command parameters`\[\"`context`\"\] field.

2. Let `navigable` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [get a
 navigable](#get-a-navigable) with `navigable id`.

3. Let `document` be `navigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

4. Let `environment settings` be the [environment settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) whose [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s [associated
 `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is `document`.

5. Let `realm` be `environment settings`'s [realm
 execution
 context](https://html.spec.whatwg.org/multipage/webappapis.html#realm-execution-context)'s Realm component.

6. Let `element` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [deserialize remote
 reference](#deserialize-remote-reference) with
 `command parameters`\[\"`element`\"\],
 `realm`, and `session`.

7. If `element` doesn't implement
 [`Element`](https://dom.spec.whatwg.org/#element), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such
 element](https://w3c.github.io/webdriver/#dfn-no-such-element).

8. If `element` doesn't implement
 [`HTMLInputElement`](https://html.spec.whatwg.org/multipage/input.html#htmlinputelement), `element`'s
 [`type`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type) is not in the [File Upload
 state](https://html.spec.whatwg.org/multipage/input.html#file-upload-state-(type=file)), or `element` is
 [disabled](https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#concept-fe-disabled), return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unable to set file
 input](#errors-unable-to-set-file-input).

9. If the
 [size](https://infra.spec.whatwg.org/#list-size) of `files` is greater than 1 and
 `element`'s
 [`multiple`](https://html.spec.whatwg.org/multipage/input.html#attr-input-multiple) attribute is not set, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unable to set file
 input](#errors-unable-to-set-file-input).

10. Let `files` be the value of the
 `command parameters`\[\"`files`\"\] field.

11. Let `selected files` be `element`'s [selected
 files](https://html.spec.whatwg.org/multipage/input.html#concept-input-type-file-selected).

12. If the
 [size](https://infra.spec.whatwg.org/#list-size) of the
 [intersection](https://infra.spec.whatwg.org/#set-intersection) of `files` and
 `selected files` is equal to the
 [size](https://infra.spec.whatwg.org/#list-size) of `selected files` and equal to the
 [size](https://infra.spec.whatwg.org/#list-size) of `files`, [queue an element
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-an-element-task) on the [user interaction task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#user-interaction-task-source) given `element` to fire an event named
 `cancel` at `element`, with the `bubbles` attribute
 initialized to true.

 Cancellation in a browser is typically determined
 by changes in file selection. In other words, if there is no change,
 a \"cancel\" event is sent.

13. Otherwise, [update the file
 selection](https://html.spec.whatwg.org/multipage/input.html#update-the-file-selection) for `element` with `files` as
 the user's selection.

14. If, for any reason, the remote end is unable to set the [selected
 files](https://html.spec.whatwg.org/multipage/input.html#concept-input-type-file-selected) of `element` to the files with paths
 given in `files`, return error with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

 For example remote ends might be unable to set
 [selected
 files](https://html.spec.whatwg.org/multipage/input.html#concept-input-type-file-selected) to files that do not currently exist on the
 filesystem.

15. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

#### 7.9.4. Events

##### 7.9.4.1. The input.fileDialogOpened Event

Event Type

: ```
 input.FileDialogOpened = (
 method: "input.fileDialogOpened",
 params: input.FileDialogInfo
 )

 input.FileDialogInfo = {
 context: browsingContext.BrowsingContext,
 ? element: script.SharedReference,
 multiple: bool,
 }
 ```

A [WebDriver BiDi file picker
options] is a
[struct](https://infra.spec.whatwg.org/#struct) with an
[item](https://infra.spec.whatwg.org/#struct-item) named
[multiple] which is a boolean.

The [remote end event
trigger](#event-remote-end-event-trigger) is the [WebDriver BiDi file dialog
opened] steps, given
[element](https://dom.spec.whatwg.org/#concept-element) `element` and optionally [WebDriver BiDi
file picker
options](#webdriver-bidi-file-picker-options) `file picker options` (default: null):

1. Let `navigable` be the `element`'s [node
 document](https://dom.spec.whatwg.org/#concept-node-document)'s
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigables).

2. Let `navigable id` be `navigable`'s [navigable
 id](#navigable-id).

3. Let `multiple` be `false`.

4. If `element` is not null and `element`'s
 [`multiple`](https://html.spec.whatwg.org/multipage/input.html#attr-input-multiple) attribute is set, set `multiple`
 to `true`.

5. If `file picker options` is not null and
 `file picker options`'s
 [multiple](#webdriver-bidi-file-picker-options-multiple) is true, set `multiple` to `true`.

6. Let `related navigables` be a
 [set](https://infra.spec.whatwg.org/#ordered-set) containing `navigable`.

7. For each `session` in the [set of sessions for which an
 event is
 enabled](#set-of-sessions-for-which-an-event-is-enabled) given \"`input.fileDialogOpened`\" and
 `related navigables`:

 1. Let `params` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `input.FileDialogInfo` production
 with the `context` field set to `navigable id` and
 `multiple` field set to `multiple`.

 2. If `element` is not null:

 1. Let `shared id` be [get shared id for a
 node](#get-shared-id-for-a-node) with `element` and
 `session`.

 2. Set `params`\[\"`element`\"\] to
 `shared id`.

 3. Let `body` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `input.fileDialogOpened`
 production, with the `params` field set to `params`.

 4. [Emit an event](#emit-an-event) with `session` and
 `body`.

8. Let `dismissed` be false.

9. For each `session` in [active BiDi
 sessions](#active-bidi-sessions):

 1. Let `user prompt handler` be `session`'s
 [user prompt
 handler](https://w3c.github.io/webdriver/#dfn-user-prompt-handler).

 2. If `user prompt handler` is not null:

 3. Assert `user prompt handler` is a
 [map](https://infra.spec.whatwg.org/#ordered-map).

 4. If `user prompt handler`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`file`\":

 1. If `user prompt handler`\[\"`file`\"\] is not
 equal to \"`ignore`\", set `dismissed` to true.

 5. Otherwise if `user prompt handler`
 [contains](https://infra.spec.whatwg.org/#map-exists) \"`default`\" and
 `user prompt handler`\[\"`default`\"\] is not equal
 to \"`ignore`\", set `dismissed` to true.

10. Return `dismissed`.

### 7.10. The webExtension Module

The [webExtension] module contains
functionality for managing and interacting with web extensions.

#### 7.10.1. Definition

[`remote end definition`](#cddl-module-remote-end-definition)

```
WebExtensionCommand = (
 webExtension.Install //
 webExtension.Uninstall
)
```

[`local end definition`](#cddl-module-local-end-definition)

```
WebExtensionResult = (
 webExtension.InstallResult /
 webExtension.UninstallResult
)
```

#### 7.10.2. Types

##### 7.10.2.1. The webExtension.Extension Type

```
webExtension.Extension = text
```

The `webExtension.Extension` type represents a web extension id within a
[remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends).

#### 7.10.3. Commands

##### 7.10.3.1. The webExtension.install Command

The [webExtension.install] command
installs a web extension in the [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends).

Command Type

: ```
 webExtension.Install = (
 method: "webExtension.install",
 params: webExtension.InstallParameters
 )

 webExtension.InstallParameters = {
 extensionData: webExtension.ExtensionData,
 }

 webExtension.ExtensionData = (
 webExtension.ExtensionArchivePath /
 webExtension.ExtensionBase64Encoded /
 webExtension.ExtensionPath
 )

 webExtension.ExtensionPath = {
 type: "path",
 path: text,
 }

 webExtension.ExtensionArchivePath = {
 type: "archivePath",
 path: text,
 }

 webExtension.ExtensionBase64Encoded = {
 type: "base64",
 value: text,
 }
 ```

Return Type

: ```
 webExtension.InstallResult = {
 extension: webExtension.Extension
 }
 ```

To [extract a zip archive] given `bytes`:

1. Perform implementation defined steps to decode `bytes`
 using the zip compression algorithm. TODO: Find a better reference
 for zip decoding.

2. If the previous step failed (e.g. because `bytes` did not
 represent valid zip-compressed data) then return
 [error](https://w3c.github.io/webdriver/#errors) with error code [invalid web
 extension](#errors-invalid-web-extension). Otherwise let `entry` be a [directory
 entry](https://fs.spec.whatwg.org/#directory) containing the extracted filesystem entries.

3. Return `entry`.

To [expand a web extension data spec] given
`extension data spec`:

1. Let `type` be
 `extension data spec`\[\"`type`\"\].

2. If installing a web extension using `type` isn't
 supported return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

3. In the following list of conditions and associated steps, run the
 first set of steps for which the associated condition is true:

 `type` is the string \"`path`\"

 : 1. Let `path` be
 `extension data spec`\[\"`path`\"\].

 2. Let `locator` be a [directory
 locator](https://fs.spec.whatwg.org/#directory-locator) with
 [path](https://fs.spec.whatwg.org/#locator-path) `path` and
 [root](https://fs.spec.whatwg.org/#locator-root) corresponding to the root of the file
 system.

 3. Let `entry` be [locate an
 entry](https://fs.spec.whatwg.org/#locating-an-entry) given `locator`.

 `type` is the string \"`archivePath`\"

 : 1. Let `archive path` be
 `extension data spec`\[\"`path`\"\].

 2. Let `locator` be a [file
 locator](https://fs.spec.whatwg.org/#file-locator) with
 [path](https://fs.spec.whatwg.org/#locator-path) `archive path` and
 [root](https://fs.spec.whatwg.org/#locator-root) corresponding to the root of the file
 system.

 3. Let `archive entry` be [locate an
 entry](https://fs.spec.whatwg.org/#locating-an-entry) given `locator`.

 4. If `archive entry` is null, return null.

 5. Let `bytes` be `archive entry`'s
 [binary
 data](https://fs.spec.whatwg.org/#file-entry-binary-data).

 6. Let `entry` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [extract a zip
 archive](#extract-a-zip-archive) given `bytes`.

 `type` is the string \"`base64`\"

 : 1. Let `bytes` be [forgiving-base64
 decode](https://infra.spec.whatwg.org/#forgiving-base64-decode)
 `extension data spec`\[\"`value`\"\].

 2. If `bytes` is failure, return null.

 3. Let `entry` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [extract a zip
 archive](#extract-a-zip-archive) given `bytes`.

4. Return `entry`.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. If installing web extensions isn't supported return
 [error](https://w3c.github.io/webdriver/#errors) with error code [unsupported
 operation](https://w3c.github.io/webdriver/#dfn-unsupported-operation).

2. Let `extension data spec` be
 `command parameters`\[\"`extensionData`\"\].

3. Let `extension directory entry` be the result of
 [trying](https://w3c.github.io/webdriver/#dfn-try) to [expand a web extension data
 spec](#expand-a-web-extension-data-spec) with `extension data spec`.

4. If `extension directory entry` is null, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid web
 extension](#errors-invalid-web-extension).

5. Perform implementation defined steps to install a web extension from
 `extension directory entry`. If this fails, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid web
 extension](#errors-invalid-web-extension). Otherwise let `extension id` be the
 unique identifier of the newly installed web extension.

6. Let `result` be a
 [map](https://infra.spec.whatwg.org/#ordered-map) matching the `webExtension.InstallResult`
 production with the `extension` field set to
 `extension id`.

7. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `result`.

 Browsers might install the web extension only
temporarily by default so that they will be automatically uninstalled
during the next shutdown.

##### 7.10.3.2. The webExtension.uninstall Command

The [webExtension.uninstall] command
uninstalls a web extension for the [remote
end](https://w3c.github.io/webdriver/#dfn-remote-ends).

Command Type

: ```
 webExtension.Uninstall = (
 method: "webExtension.uninstall",
 params: webExtension.UninstallParameters
 )

 webExtension.UninstallParameters = {
 extension: webExtension.Extension,
 }
 ```

Return Type

: ```
 webExtension.UninstallResult = EmptyResult
 ```

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) with `command parameters` are:

1. Let `extension` be
 `command parameters`\[\"`extension`\"\].

2. If the [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends) has no web extension with id equal to
 `extension`, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [no such web
 extension](#errors-no-such-web-extension).

3. Perform any implementation-defined steps to remove the web extension
 from the [remote
 end](https://w3c.github.io/webdriver/#dfn-remote-ends). If this fails, return
 [error](https://w3c.github.io/webdriver/#errors) with [error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [unknown
 error](https://w3c.github.io/webdriver/#dfn-unknown-error).

4. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data null.

## 8. Patches to Other Specifications

This specification requires some changes to external specifications to
provide the necessary integration points. It is assumed that these
patches will be committed to the other specifications as part of the
standards process.

### 8.1. HTML

The [report an
error](https://html.spec.whatwg.org/multipage/webappapis.html#report-the-error) algorithm is modified with an additional step at the
end:

1. Call any [error reporting steps] defined in external
 specifications with `script`, `line`,
 `col`, `message`, and true if the error is
 handled, or false otherwise.

### 8.2. Console

Other specifications can define [console steps].

1. At the point when the
 [Printer](https://console.spec.whatwg.org#printer) operation is called with arguments
 `name`, `printerArgs` and `options`
 (which is undefined if the argument is not provided), call any
 [console steps](#console-steps) defined in external specification with arguments
 `name`, `printerArgs`, and
 `options`.

### 8.3. CSS

#### 8.3.1. Determine the device pixel ratio

Insert the following steps at the start of the [determine the device
pixel
ratio](https://drafts.csswg.org/cssom-view-1/#determine-the-device-pixel-ratio) algorithm:

1. If [device pixel ratio
 overrides](#device-pixel-ratio-overrides)
 [contains](https://infra.spec.whatwg.org/#map-exists) `window`'s
 [navigable](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-navigable), return [device pixel ratio
 overrides](#device-pixel-ratio-overrides)\[`window`'s
 [navigable](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-navigable)\].

## 9. Appendices

*This section is non-normative.*

### 9.1. External specifications

 the list is not exhaustive and might not be up to date.

The following external specifications define additional WebDriver BiDi
modules:

1. [Permissions](https://www.w3.org/TR/permissions/)

2. [nav-speculation](https://wicg.github.io/nav-speculation/prefetch.html)

3. [Web Bluetooth](https://webbluetoothcg.github.io/web-bluetooth/)

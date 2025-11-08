## Terminology

This specification depends on the Infra Standard. [INFRA]

Most terminology used in this specification is from CSS, DOM, HTML, and Web IDL. [CSS] [DOM] [HTML] [WEBIDL]


## Model

All [elements](https://dom.spec.whatwg.org/#concept-element) have an associated [fullscreen flag](#fullscreen-flag). Unless stated otherwise it is unset.

All [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) [elements](https://dom.spec.whatwg.org/#concept-element) have an associated [iframe fullscreen flag](#iframe-fullscreen-flag). Unless stated otherwise it is unset.

All [documents](https://dom.spec.whatwg.org/#concept-document) have an associated [fullscreen element](#fullscreen-element). The [fullscreen element](#fullscreen-element) is the topmost [element](https://dom.spec.whatwg.org/#concept-element) in the [document](https://dom.spec.whatwg.org/#concept-document)'s [top layer](https://drafts.csswg.org/css-position-4/#document-top-layer) whose [fullscreen flag](#fullscreen-flag) is set, if any, and null otherwise.

All [documents](https://dom.spec.whatwg.org/#concept-document) have an associated [list of pending fullscreen events](#list-of-pending-fullscreen-events), which is an [ordered set](https://infra.spec.whatwg.org/#ordered-set) of ([string](https://infra.spec.whatwg.org/#string), [element](https://dom.spec.whatwg.org/#concept-element)) [tuples](https://infra.spec.whatwg.org/#tuple). It is initially empty.

To [fullscreen an `element`](#fullscreen-an-element):

1.  Let `hideUntil` be the result of running [topmost popover ancestor](https://html.spec.whatwg.org/multipage/popover.html#topmost-popover-ancestor) given `element`, null, and false.

2.  If `hideUntil` is null, then set `hideUntil` to `element`'s node document.

3.  Run [hide all popovers until](https://html.spec.whatwg.org/multipage/popover.html#hide-all-popovers-until) given `hideUntil`, false, and true.

4.  Set `element`'s [fullscreen flag](#fullscreen-flag).

5.  [Remove from the top layer immediately](https://drafts.csswg.org/css-position-4/#remove-an-element-from-the-top-layer-immediately) given `element`.

6.  [Add to the top layer](https://drafts.csswg.org/css-position-4/#add-an-element-to-the-top-layer) given `element`.

To [unfullscreen an `element`](#unfullscreen-an-element), unset `element`'s [fullscreen flag](#fullscreen-flag) and [iframe fullscreen flag](#iframe-fullscreen-flag) (if any), and [remove from the top layer immediately](https://drafts.csswg.org/css-position-4/#remove-an-element-from-the-top-layer-immediately) given `element`.

To [unfullscreen a `document`](#unfullscreen-a-document), [unfullscreen](#unfullscreen-an-element) all [elements](https://dom.spec.whatwg.org/#concept-element), within `document`'s [top layer](https://drafts.csswg.org/css-position-4/#document-top-layer), whose [fullscreen flag](#fullscreen-flag) is set.


To [fully exit fullscreen](#fully-exit-fullscreen) a [document](https://dom.spec.whatwg.org/#concept-document) `document`, run these steps:

1.  If `document`'s [fullscreen element](#fullscreen-element) is null, terminate these steps.

2.  [Unfullscreen elements](#unfullscreen-an-element) whose [fullscreen flag](#fullscreen-flag) is set, within `document`'s [top layer](https://drafts.csswg.org/css-position-4/#document-top-layer), except for `document`'s [fullscreen element](#fullscreen-element).

3.  [Exit fullscreen](#exit-fullscreen) `document`.


Whenever the [removing steps](https://dom.spec.whatwg.org/#concept-node-remove-ext) run with a `removedNode`, run these steps:

1.  Let `document` be `removedNode`'s [node document](https://dom.spec.whatwg.org/#concept-node-document).

2.  Let `nodes` be `removedNode`'s [shadow-including inclusive descendants](https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-descendant) that have their [fullscreen flag](#fullscreen-flag) set, in [shadow-including tree order](https://dom.spec.whatwg.org/#concept-shadow-including-tree-order).

3.  [For each](https://infra.spec.whatwg.org/#list-iterate) `node` in `nodes`:

    1.  If `node` is `document`'s [fullscreen element](#fullscreen-element), [exit fullscreen](#exit-fullscreen) `document`.

    2.  Otherwise, [unfullscreen `node`](#unfullscreen-an-element).

    3.  If `document`'s [top layer](https://drafts.csswg.org/css-position-4/#document-top-layer) [contains](https://infra.spec.whatwg.org/#list-contain) `node`, [remove from the top layer immediately](https://drafts.csswg.org/css-position-4/#remove-an-element-from-the-top-layer-immediately) given `node`.

        Other specifications can add and remove elements from [top layer](https://drafts.csswg.org/css-position-4/#document-top-layer), so `node` might not be `document`'s [fullscreen element](#fullscreen-element). For example, `node` could be an open [`dialog`](https://html.spec.whatwg.org/multipage/interactive-elements.html#the-dialog-element) element.


Whenever the [unloading document cleanup steps](https://html.spec.whatwg.org/multipage/document-lifecycle.html#unloading-document-cleanup-steps) run with a `document`, [fully exit fullscreen](#fully-exit-fullscreen) `document`.


[Fullscreen is supported](#fullscreen-is-supported) if there is no previously-established user preference, security risk, or platform limitation.


To [run the fullscreen steps](#run-the-fullscreen-steps) for a [document](https://dom.spec.whatwg.org/#concept-document) `document`, run these steps:

1.  Let `pendingEvents` be `document`'s [list of pending fullscreen events](#list-of-pending-fullscreen-events).

2.  [Empty](https://infra.spec.whatwg.org/#list-empty) `document`'s [list of pending fullscreen events](#list-of-pending-fullscreen-events).

3.  [For each](https://infra.spec.whatwg.org/#list-iterate) (`type`, `element`) in `pendingEvents`:

    1.  Let `target` be `element` if `element` is [connected](https://dom.spec.whatwg.org/#connected) and its [node document](https://dom.spec.whatwg.org/#concept-node-document) is `document`, and otherwise let `target` be `document`.

    2.  [Fire an event](https://dom.spec.whatwg.org/#concept-event-fire) named `type`, with its [`bubbles`](https://dom.spec.whatwg.org/#dom-event-bubbles) and [`composed`](https://dom.spec.whatwg.org/#dom-event-composed) attributes set to true, at `target`.

These steps integrate with the [event loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop) defined in HTML. [[HTML](#biblio-html)]


## API

```idl
enum FullscreenNavigationUI {
  "auto",
  "show",
  "hide"
};

dictionary FullscreenOptions {
  FullscreenNavigationUI navigationUI = "auto";
};

partial interface Element {
  Promise<undefined> requestFullscreen(optional FullscreenOptions options = {});

  attribute EventHandler onfullscreenchange;
  attribute EventHandler onfullscreenerror;
};

partial interface Document {
  [LegacyLenientSetter] readonly attribute boolean fullscreenEnabled;
  [LegacyLenientSetter, Unscopable] readonly attribute boolean fullscreen; // historical

  Promise<undefined> exitFullscreen();

  attribute EventHandler onfullscreenchange;
  attribute EventHandler onfullscreenerror;
};

partial interface mixin DocumentOrShadowRoot {
  [LegacyLenientSetter] readonly attribute Element? fullscreenElement;
};
```

`promise` = `element` . `requestFullscreen([options])`

:   Displays `element` fullscreen and resolves `promise` when done.

    When supplied, `options`'s `navigationUI` member indicates whether showing navigation UI while in fullscreen is preferred or not. If set to "`show`", navigation simplicity is preferred over screen space, and if set to "`hide`", more screen space is preferred. User agents are always free to honor user preference over the application's. The default value "`auto`" indicates no application preference.

`document` . `fullscreenEnabled`

:   Returns true if `document` has the ability to display elements fullscreen and fullscreen is supported, or false otherwise.

`promise` = `document` . `exitFullscreen()`

:   Stops `document`'s fullscreen element from being displayed fullscreen and resolves `promise` when done.

`document` . `fullscreenElement`

:   Returns `document`'s fullscreen element.

`shadowroot` . `fullscreenElement`

:   Returns `shadowroot`'s fullscreen element.

A **fullscreen element ready check** for an element `element` returns true if all of the following are true, and false otherwise:

- `element` is connected.

- `element`'s node document is allowed to use the "fullscreen" feature.

- `element` namespace is not the HTML namespace or `element`'s popover visibility state is hidden.

The `requestFullscreen(options)` method steps are:

1.  Let `pendingDoc` be this's node document.

2.  Let `promise` be a new promise.

3.  If `pendingDoc` is not fully active, then reject `promise` with a `TypeError` exception and return `promise`.

4.  Let `error` be false.

5.  If any of the following conditions are false, then set `error` to true:

    - This's namespace is the HTML namespace or this is an SVG `svg` or MathML `math` element. [SVG] [MATHML]

    - This is not a `dialog` element.

    - The fullscreen element ready check for this returns true.

    - Fullscreen is supported.

    - This's relevant global object has transient activation or the algorithm is triggered by a user generated orientation change.

6.  If `error` is false, then consume user activation given `pendingDoc`'s relevant global object.

7.  Return `promise`, and run the remaining steps in parallel.

8.  If `error` is false, then resize `pendingDoc`'s node navigable's top-level traversable's active document's viewport's dimensions, optionally taking into account `options`["`navigationUI`"]:

    value | viewport dimensions
    ---|---
    "`hide`" | full dimensions of the screen of the output device
    "`show`" | dimensions of the screen of the output device clamped to allow the user agent to show page navigation controls
    "`auto`" | user-agent defined, but matching one of the above

    Optionally display a message how the end user can revert this.

9.  If any of the following conditions are false, then set `error` to true:

    - This's node document is `pendingDoc`.

    - The fullscreen element ready check for this returns true.

10. If `error` is true:

    1.  Append (`fullscreenerror`, this) to `pendingDoc`'s list of pending fullscreen events.

    2.  Reject `promise` with a `TypeError` exception and terminate these steps.

11. Let `fullscreenElements` be an ordered set initially consisting of this.

12. While true:

    1.  Let `last` be the last item of `fullscreenElements`.

    2.  Let `container` be `last`'s node navigable's container.

    3.  If `container` is null, then break.

    4.  Append `container` to `fullscreenElements`.

13. For each `element` in `fullscreenElements`:

    1.  Let `doc` be `element`'s node document.

    2.  If `element` is `doc`'s fullscreen element, continue.

        No need to notify observers when nothing has changed.

    3.  If `element` is this and this is an `iframe` element, then set `element`'s iframe fullscreen flag.

    4.  Fullscreen `element` within `doc`.

    5.  Append (`fullscreenchange`, `element`) to `doc`'s list of pending fullscreen events.

    The order in which elements are fullscreened is not observable, because run the fullscreen steps is invoked in tree order.

14. Resolve `promise` with undefined.

Implementations with out-of-process navigables are left as an exercise to the reader. Input welcome on potential improvements.

The `fullscreenEnabled` getter steps are to return true if this is allowed to use the "fullscreen" feature and fullscreen is supported, and false otherwise.

The `fullscreen` getter steps are to return false if this's fullscreen element is null, and true otherwise.

Use the `fullscreenElement` attribute instead.

The `fullscreenElement` getter steps are:

1.  If this is a shadow root and its host is not connected, then return null.

2.  Let `candidate` be the result of retargeting fullscreen element against this.

3.  If `candidate` and this are in the same tree, then return `candidate`.

4.  Return null.

A document is said to be a **simple fullscreen document** if there is exactly one element in its top layer that has its fullscreen flag set.

A document with two elements in its top layer can be a simple fullscreen document. For example, in addition to the fullscreen element there could be an open `dialog` element.

To **collect documents to unfullscreen** given `doc`, run these steps:

1.  Let `docs` be an ordered set consisting of `doc`.

2.  While true:

    1.  Let `lastDoc` be `docs`'s last document.

    2.  Assert: `lastDoc`'s fullscreen element is not null.

    3.  If `lastDoc` is not a simple fullscreen document, break.

    4.  Let `container` be `lastDoc`'s node navigable's container.

    5.  If `container` is null, then break.

    6.  If `container`'s iframe fullscreen flag is set, break.

    7.  Append `container`'s node document to `docs`.

3.  Return `docs`.

    This is the set of documents for which the fullscreen element will be unfullscreened, but the last document in `docs` might have more than one element in its top layer with the fullscreen flag set, in which case that document will still remain in fullscreen.

To **exit fullscreen** a document `doc`, run these steps:

1.  Let `promise` be a new promise.

2.  If `doc` is not fully active or `doc`'s fullscreen element is null, then reject `promise` with a `TypeError` exception and return `promise`.

3.  Let `resize` be false.

4.  Let `docs` be the result of collecting documents to unfullscreen given `doc`.

5.  Let `topLevelDoc` be `doc`'s node navigable's top-level traversable's active document.

6.  If `topLevelDoc` is in `docs`, and it is a simple fullscreen document, then set `doc` to `topLevelDoc` and `resize` to true.

7.  If `doc`'s fullscreen element is not connected:

    1.  Append (`fullscreenchange`, `doc`'s fullscreen element) to `doc`'s list of pending fullscreen events.

    2.  Unfullscreen `doc`'s fullscreen element.

8.  Return `promise`, and run the remaining steps in parallel.

9.  Run the fully unlock the screen orientation steps with `doc`.

10. If `resize` is true, resize `doc`'s viewport to its "normal" dimensions.

11. If `doc`'s fullscreen element is null, then resolve `promise` with undefined and terminate these steps.

12. Let `exitDocs` be the result of collecting documents to unfullscreen given `doc`.

13. Let `descendantDocs` be an ordered set consisting of `doc`'s descendant navigables' active documents whose fullscreen element is non-null, if any, in tree order.

14. For each `exitDoc` in `exitDocs`:

    1.  Append (`fullscreenchange`, `exitDoc`'s fullscreen element) to `exitDoc`'s list of pending fullscreen events.

    2.  If `resize` is true, unfullscreen `exitDoc`.

    3.  Otherwise, unfullscreen `exitDoc`'s fullscreen element.

15. For each `descendantDoc` in `descendantDocs`:

    1.  Append (`fullscreenchange`, `descendantDoc`'s fullscreen element) to `descendantDoc`'s list of pending fullscreen events.

    2.  Unfullscreen `descendantDoc`.

    The order in which documents are unfullscreened is not observable, because run the fullscreen steps is invoked in tree order.

16. Resolve `promise` with undefined.

The `exitFullscreen()` method steps are to return the result of running exit fullscreen on this.

The following are the event handlers (and their corresponding event handler event types) that must be supported by `Element` and `Document` objects as event handler IDL attributes:

event handler | event handler event type
---|---
`onfullscreenchange` | `fullscreenchange`
`onfullscreenerror` | `fullscreenerror`

These are not supported by `ShadowRoot` or `Window` objects, and there are no corresponding event handler content attributes for `Element` objects in any namespace.


## UI

User agents are encouraged to implement native media fullscreen controls in terms of `requestFullscreen()` and `exitFullscreen()`.

If the user initiates a [close request](https://html.spec.whatwg.org/multipage/interaction.html#close-request), this will trigger the fully exit fullscreen algorithm as part of the [close request steps](https://html.spec.whatwg.org/multipage/interaction.html#close-request-steps). This takes precedence over any [close watchers](https://html.spec.whatwg.org/multipage/interaction.html#close-watcher).

The user agent may end any fullscreen session without a [close request](https://html.spec.whatwg.org/multipage/interaction.html#close-request) or call to `exitFullscreen()` whenever the user agent deems it necessary.


## Rendering

This section is to be interpreted equivalently to the Rendering section of HTML. [HTML]


### `:fullscreen` pseudo-class

The `:fullscreen` pseudo-class must match any element `element` for which one of the following conditions is true:

- `element`'s fullscreen flag is set.

- `element` is a shadow host and the result of retargeting its node document's fullscreen element against `element` is `element`.

This makes it different from the `fullscreenElement` API, which returns the topmost fullscreen element.


### User-agent level style sheet defaults

``` css
@namespace "http://www.w3.org/1999/xhtml";

*|*:not(:root):fullscreen {
  position:fixed !important;
  inset:0 !important;
  margin:0 !important;
  box-sizing:border-box !important;
  min-width:0 !important;
  max-width:none !important;
  min-height:0 !important;
  max-height:none !important;
  width:100% !important;
  height:100% !important;
  transform:none !important;

  /* intentionally not !important */
  object-fit:contain;
}

iframe:fullscreen {
  border:none !important;
  padding:0 !important;
}

*|*:not(:root):fullscreen::backdrop {
  background:black;
}
```


# Permissions Policy Integration

This specification defines a [policy-controlled feature](https://w3c.github.io/webappsec-permissions-policy/#policy-controlled-feature) identified by the string "fullscreen". Its [default allowlist](https://w3c.github.io/webappsec-permissions-policy/#policy-controlled-feature-default-allowlist) is `'self'`.

Note: A [document](https://dom.spec.whatwg.org/#concept-document)'s [permissions policy](https://html.spec.whatwg.org/multipage/dom.html#concept-document-permissions-policy) determines whether any content in that document is allowed to go fullscreen. If disabled in any document, no content in the document will be [allowed to use](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use) fullscreen.

The [`allowfullscreen`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allowfullscreen) attribute of the HTML [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element affects the [container policy](https://w3c.github.io/webappsec-permissions-policy/#container-policy) for any document nested in that iframe. Unless overridden by the [`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow) attribute, setting [`allowfullscreen`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allowfullscreen) on an iframe is equivalent to `<iframe allow="fullscreen *">`, as described in [Permissions Policy § 6.3.1 allowfullscreen](https://w3c.github.io/webappsec-permissions-policy/#iframe-allowfullscreen-attribute).


## Security and Privacy Considerations

User agents should ensure, e.g. by means of an overlay, that the end user is aware something is displayed fullscreen. User agents should provide a means of exiting fullscreen that always works and advertise this to the user. This is to prevent a site from spoofing the end user by recreating the user agent or even operating system environment when fullscreen. See also the definition of `requestFullscreen()`.

To enable content in a [child navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable) to go fullscreen, it needs to be specifically allowed via permissions policy, either through the [`allowfullscreen`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allowfullscreen) attribute of the HTML [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element, or an appropriate declaration in the [`allow`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-allow) attribute of the HTML [`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element) element, or through a `[Permissions-Policy](https://w3c.github.io/webappsec-permissions-policy/#permissions-policy-header)` HTTP header delivered with the [document](https://dom.spec.whatwg.org/#concept-document) through which it is nested.

This prevents e.g. content from third parties to go fullscreen without explicit permission.


## Previously-hosted definitions

This specification previously hosted the definitions of [::backdrop](https://drafts.csswg.org/css-position-4/#selectordef-backdrop) and the concept of the document's [top layer](https://drafts.csswg.org/css-position-4/#document-top-layer).
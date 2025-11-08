## Introduction

*This section is informative.*

This standard defines an interface definition language, Web IDL, that can be used to describe interfaces that are intended to be implemented in web browsers. Web IDL is an IDL variant with a number of features that allow the behavior of common script objects in the web platform to be specified more readily. How interfaces described with Web IDL correspond to constructs within JavaScript execution environments is also detailed here.

Concretely, Web IDL provides a syntax for specifying the surface APIs of web platform objects, as well as JavaScript bindings that detail how those APIs manifest as JavaScript constructs. This ensures common tasks, such as installing global properties, processing numeric inputs, or exposing iteration behavior, remain uniform across web platform specifications: such specifications describe their interfaces using Web IDL, and then use prose to specify API-specific details.

The term "JavaScript" is used to refer to ECMA-262, rather than the official term ECMAScript, since the term JavaScript is more widely known.


## Interface definition language

This section describes a language, *Web IDL*, which can be used to define interfaces for APIs in the Web platform. A specification that defines Web APIs can include one or more IDL fragments that describe the interfaces (the state and behavior that objects can exhibit) for the APIs defined by that specification. An IDL fragment is a sequence of definitions that matches the Definitions grammar symbol. The set of IDL fragments that an implementation supports is not ordered. See IDL grammar for the complete grammar and an explanation of the notation used.

The different kinds of definitions that can appear in an IDL fragment are: interfaces, partial interface definitions, interface mixins, partial mixin definitions, callback functions, callback interfaces, namespaces, partial namespace definitions, dictionaries, partial dictionary definitions, typedefs and includes statements. These are all defined in the following sections.

Each definition (matching Definition) can be preceded by a list of extended attributes (matching ExtendedAttributeList), which can control how the definition will be handled in language bindings. The extended attributes defined by this specification that are language binding agnostic are discussed in § 2.14 Extended attributes, while those specific to the JavaScript language binding are discussed in § 3.3 Extended attributes.

```syntax
[extended_attributes]
interface identifier {
  /* interface_members... */
};
```

```grammar
Definitions ::
    ExtendedAttributeList Definition Definitions
    ε
```

```grammar
Definition ::
    CallbackOrInterfaceOrMixin
    Namespace
    Partial
    Dictionary
    Enum
    Typedef
    IncludesStatement
```

The following is an example of an IDL fragment.

```
[Exposed=Window]
interface Paint { };

[Exposed=Window]
interface SolidColor : Paint {
  attribute double red;
  attribute double green;
  attribute double blue;
};

[Exposed=Window]
interface Pattern : Paint {
  attribute DOMString imageURL;
};

[Exposed=Window]
interface GraphicalWindow {
  constructor();
  readonly attribute unsigned long width;
  readonly attribute unsigned long height;

  attribute Paint currentPaint;

  undefined drawRectangle(double x, double y, double width, double height);

  undefined drawText(double x, double y, DOMString text);
};
```

Here, four interfaces are being defined. The `GraphicalWindow` interface has two read only attributes, one writable attribute, and two operations defined on it. Objects that implement the `GraphicalWindow` interface will expose these attributes and operations in a manner appropriate to the particular language being used.

In JavaScript, the attributes on the IDL interfaces will be exposed as accessor properties and the operations as data properties whose value is a built-in function object on a prototype object for all `GraphicalWindow` objects; each JavaScript object that implements `GraphicalWindow` will have that prototype object in its prototype chain.

The constructor operation that appears on `GraphicalWindow` causes a constructor to exist in JavaScript implementations, so that calling `new GraphicalWindow()` would return a new object that implemented the interface.

All interfaces have the \[`Exposed`\] extended attribute, which ensures the interfaces are only available in realms whose global object is a `Window` object.


## Names

Every [interface](#dfn-interface), [partial interface definition](#dfn-partial-interface), [namespace](#dfn-namespace), [partial namespace definition](#dfn-partial-namespace), [dictionary](#dfn-dictionary), [partial dictionary definition](#dfn-partial-dictionary), [enumeration](#dfn-enumeration), [callback function](#dfn-callback-function), [callback interface](#dfn-callback-interface) and [typedef](#dfn-typedef) (together called [named definitions](#dfn-named-definition)) and every [constant](#dfn-constant), [attribute](#dfn-attribute), and [dictionary member](#dfn-dictionary-member) has an [identifier](#dfn-identifier), as do some [operations](#dfn-operation). The identifier is determined by an identifier token somewhere in the declaration:

- For [named definitions](#dfn-named-definition), the identifier token that appears directly after the interface, namespace, dictionary, enum or callback keyword determines the identifier of that definition.

  ```syntax
  interface interface_identifier { /* interface_members... */ };
  partial interface interface_identifier { /* interface_members... */ };
  namespace namespace_identifier { /* namespace_members... */ };
  partial namespace namespace_identifier { /* namespace_members... */ };
  dictionary dictionary_identifier { /* dictionary_members... */ };
  partial dictionary dictionary_identifier { /* dictionary_members... */ };
  enum enumeration_identifier { "enum", "values" /* , ... */ };
  callback callback_identifier = return_type (/* arguments... */);
  callback interface callback_interface_identifier { /* interface_members... */ };
  ```

- For [attributes](#dfn-attribute), [typedefs](#dfn-typedef) and [dictionary members](#dfn-dictionary-member), the final identifier token before the semicolon at the end of the declaration determines the identifier.

  ```syntax
  [extended_attributes]
  interface identifier {
    attribute type attribute_identifier;
  };

  typedef type typedef_identifier;

  dictionary identifier {
    type dictionary_member_identifier;
  };
  ```

- For [constants](#dfn-constant), the identifier token before the equals sign determines the identifier.

  ```syntax
  const type constant_identifier = 42;
  ```

- For [operations](#dfn-operation), the identifier token that appears after the return type but before the opening parenthesis (that is, one that is matched as part of the OptionalOperationName grammar symbol in an OperationRest) determines the identifier of the operation. If there is no such identifier token, then the operation does not have an identifier.

  ```syntax
  interface interface_identifier {
    return_type operation_identifier(/* arguments... */);
  };
  ```

[Note:]{.marker} Operations can have no identifier when they are being used to declare a [special kind of operation](#dfn-special-operation), such as a getter or setter.

For all of these constructs, the [identifier](#dfn-identifier) is the value of the identifier token with any leading U+005F (\_) removed.

[Note:]{.marker} A leading U+005F (\_) is used to escape an identifier from looking like a reserved word so that, for example, an interface named "`interface`" can be defined. The leading U+005F (\_) is dropped to unescape the identifier.

Operation arguments can take a slightly wider set of identifiers. In an operation declaration, the identifier of an argument is specified immediately after its type and is given by either an identifier token or by one of the keywords that match the ArgumentNameKeyword symbol. If one of these keywords is used, it need not be escaped with a leading underscore.

```syntax
interface interface_identifier {
  return_type operation_identifier(argument_type argument_identifier /* , ... */);
};
```

```grammar
ArgumentNameKeyword ::
    attribute
    callback
    const
    constructor
    deleter
    dictionary
    enum
    getter
    includes
    inherit
    interface
    iterable
    maplike
    mixin
    namespace
    partial
    readonly
    required
    setlike
    setter
    static
    stringifier
    typedef
    unrestricted
```

If an identifier token is used, then the [identifier](#dfn-identifier) of the operation argument is the value of that token with any leading U+005F (\_) removed. If instead one of the ArgumentNameKeyword keyword token is used, then the [identifier](#dfn-identifier) of the operation argument is simply that token.

The [identifier](#dfn-identifier) of any of the abovementioned IDL constructs (except operation arguments) must not be "`constructor`", "`toString`", or begin with a U+005F (\_). These are known as [reserved identifiers](#dfn-reserved-identifier).

Although the "`toJSON`" [identifier](#dfn-identifier) is not a [reserved identifier](#dfn-reserved-identifier), it must only be used for [regular operations](#dfn-regular-operation) that convert objects to [JSON types](#dfn-json-types), as described in § 2.5.3.1 toJSON.

[Note:]{.marker} Further restrictions on identifier names for particular constructs can be made in later sections.

Within the set of [IDL fragments](#dfn-idl-fragment) that a given implementation supports, the [identifier](#dfn-identifier) of every [interface](#dfn-interface), [namespace](#dfn-namespace), [dictionary](#dfn-dictionary), [enumeration](#dfn-enumeration), [callback function](#dfn-callback-function), [callback interface](#dfn-callback-interface) and [typedef](#dfn-typedef) must not be the same as the identifier of any other [interface](#dfn-interface), [namespace](#dfn-namespace), [dictionary](#dfn-dictionary), [enumeration](#dfn-enumeration), [callback function](#dfn-callback-function), [callback interface](#dfn-callback-interface) or [typedef](#dfn-typedef).

Within an [IDL fragment](#dfn-idl-fragment), a reference to a [definition](#dfn-definition) need not appear after the declaration of the referenced definition. References can also be made across [IDL fragments](#dfn-idl-fragment).

Therefore, the following [IDL fragment](#dfn-idl-fragment) is valid:

```
[Exposed=Window]
interface B : A {
  undefined f(SequenceOfLongs x);
};

[Exposed=Window]
interface A {
};

typedef sequence<long> SequenceOfLongs;
```

The following [IDL fragment](#dfn-idl-fragment) demonstrates how [identifiers](#dfn-identifier) are given to definitions and [interface members](#dfn-interface-member).

```
// Typedef identifier: "number"
typedef double number;

// Interface identifier: "System"
[Exposed=Window]
interface System {

  // Operation identifier:          "createObject"
  // Operation argument identifier: "interface"
  object createObject(DOMString _interface);

  // Operation argument identifier: "interface"
  sequence<object> getObjects(DOMString interface);

  // Operation has no identifier; it declares a getter.
  getter DOMString (DOMString keyName);
};

// Interface identifier: "TextField"
[Exposed=Window]
interface TextField {

  // Attribute identifier: "const"
  attribute boolean _const;

  // Attribute identifier: "value"
  attribute DOMString? _value;
};
```

Note that while the second [attribute](#dfn-attribute) on the `TextField` [interface](#dfn-interface) need not have been escaped with an underscore (because "`value`" is not a keyword in the IDL grammar), it is still unescaped to obtain the attribute's [identifier](#dfn-identifier).


### Interfaces

[IDL fragments](#dfn-idl-fragment) are used to describe object oriented systems. In such systems, objects are entities that have identity and which are encapsulations of state and behavior. An **interface** is a definition (matching interface [InterfaceRest](#prod-InterfaceRest)) that declares some state and behavior that an object implementing that interface will expose.

```syntax
[extended_attributes]
interface identifier {
  /* interface_members... */
};
```

An interface is a specification of a set of **interface members** (matching [InterfaceMembers](#prod-InterfaceMembers)). These are the [members](#dfn-member) that appear between the braces in the interface declaration.

Interfaces in Web IDL describe how objects that implement the interface behave. In bindings for object oriented languages, it is expected that an object that implements a particular IDL interface provides ways to inspect and modify the object's state and to invoke the behavior described by the interface.

An interface can be defined to **inherit** from another interface. If the identifier of the interface is followed by a U+003A (:) and an [identifier](#dfn-identifier), then that identifier identifies the inherited interface. An object that implements an interface that inherits from another also implements that inherited interface. The object therefore will also have members that correspond to the interface members from the inherited interface.

```syntax
interface identifier : identifier_of_inherited_interface {
  /* interface_members... */
};
```

The order that members appear in has significance for property enumeration in the [JavaScript binding](#js-interfaces).

Interfaces may specify an interface member that has the same name as one from an inherited interface. Objects that implement the derived interface will expose the member on the derived interface. It is language binding specific whether the overridden member can be accessed on the object.

Consider the following two interfaces.

```
[Exposed=Window]
interface A {
  undefined f();
  undefined g();
};

[Exposed=Window]
interface B : A {
  undefined f();
  undefined g(DOMString x);
};
```

In the JavaScript language binding, an instance of `B` will have a prototype chain that looks like the following:

    [Object.prototype: the Object prototype object]
         ↑
    [A.prototype: interface prototype object for A]
         ↑
    [B.prototype: interface prototype object for B]
         ↑
    [instanceOfB]

Calling `instanceOfB.f()` in JavaScript will invoke the f defined on `B`. However, the f from `A` can still be invoked on an object that implements `B` by calling `A.prototype.f.call(instanceOfB)`.

The **inherited interfaces** of a given interface `A` is the set of all interfaces that `A` inherits from, directly or indirectly. If `A` does not [inherit](#dfn-inherit) from another interface, then the set is empty. Otherwise, the set includes the interface `B` that `A` [inherits](#dfn-inherit) from and all of `B`'s [inherited interfaces](#dfn-inherited-interfaces).

An interface must not be declared such that its inheritance hierarchy has a cycle. That is, an interface `A` cannot inherit from itself, nor can it inherit from another interface `B` that inherits from `A`, and so on.

The [list](https://infra.spec.whatwg.org/#list) of **inclusive inherited interfaces** of an [interface](#dfn-interface) `I` is defined as follows:

1. Let `result` be « ».

2. Let `interface` be `I`.

3. While `interface` is not null:

   1. [Append](https://infra.spec.whatwg.org/#list-append) `interface` to `result`.

   2. Set `interface` to the [interface](#dfn-interface) that `I` [inherits](#dfn-inherit) from, if any, and null otherwise.

4. Return `result`.

Note that general multiple inheritance of interfaces is not supported, and objects also cannot implement arbitrary sets of interfaces. Objects can be defined to implement a single given interface `A`, which means that it also implements all of `A`'s [inherited interfaces](#dfn-inherited-interfaces). In addition, an [includes statement](#includes-statement) can be used to define that objects implementing an [interface](#dfn-interface) `A` will always also include the [members](#interface-mixin-member) of the [interface mixins](#interface-mixin) `A` [includes](#include).

Each interface member can be preceded by a list of [extended attributes](#dfn-extended-attribute) (matching [ExtendedAttributeList](#prod-ExtendedAttributeList)), which can control how the interface member will be handled in language bindings.

```syntax
[extended_attributes]
interface identifier {

  [extended_attributes]
  const type constant_identifier = 42;

  [extended_attributes]
  attribute type identifier;

  [extended_attributes]
  return_type identifier(/* arguments... */);
};
```

The IDL for interfaces can be split into multiple parts by using **partial interface** definitions (matching partial interface [PartialInterfaceRest](#prod-PartialInterfaceRest)). The [identifier](#dfn-identifier) of a partial interface definition must be the same as the identifier of an interface definition. All of the members that appear on each of the partial interfaces are considered to be members of the interface itself.

```syntax
interface SomeInterface {
  /* interface_members... */
};

partial interface SomeInterface {
  /* interface_members... */
};
```

Note: Partial interface definitions are intended for use as a specification editorial aide, allowing the definition of an interface to be separated over more than one section of the document, and sometimes multiple documents.

The order of appearance of an [interface](#dfn-interface) definition and any of its [partial interface](#dfn-partial-interface) definitions does not matter.

Note: A partial interface definition cannot specify that the interface [inherits](#dfn-inherit) from another interface. Inheritance is to be specified on the original [interface](#dfn-interface) definition.

The relevant language binding determines how interfaces correspond to constructs in the language.

The following extended attributes are applicable to interfaces: \[[`CrossOriginIsolated`](#CrossOriginIsolated)\], \[[`Exposed`](#Exposed)\], \[[`Global`](#Global)\], \[[`LegacyFactoryFunction`](#LegacyFactoryFunction)\], \[[`LegacyNoInterfaceObject`](#LegacyNoInterfaceObject)\], \[[`LegacyOverrideBuiltIns`](#LegacyOverrideBuiltIns)\], \[[`LegacyWindowAlias`](#LegacyWindowAlias)\], and \[[`SecureContext`](#SecureContext)\].

The following extended attributes are applicable to [partial interfaces](#dfn-partial-interface): \[[`CrossOriginIsolated`](#CrossOriginIsolated)\], \[[`Exposed`](#Exposed)\], \[[`LegacyOverrideBuiltIns`](#LegacyOverrideBuiltIns)\], and \[[`SecureContext`](#SecureContext)\].

[Interfaces](#dfn-interface) must be annotated with an \[[`Exposed`](#Exposed)\] [extended attribute](#dfn-extended-attribute).

The **qualified name** of an [interface](#dfn-interface) `interface` is defined as follows:

1. Let `identifier` be the [identifier](#dfn-identifier) of `interface`.

2. If `interface` has a \[[`LegacyNamespace`](#LegacyNamespace)\] [extended attribute](#dfn-extended-attribute), then:

   1. Let `namespace` be the identifier argument of the \[[`LegacyNamespace`](#LegacyNamespace)\] [extended attribute](#dfn-extended-attribute).

   2. Return the [concatenation](https://infra.spec.whatwg.org/#string-concatenate) of « `namespace`, `identifier` » with separator U+002E (.).

3. Return `identifier`.

```grammar
CallbackOrInterfaceOrMixin ::
    callback CallbackRestOrInterface
    interface InterfaceOrMixin
```

```grammar
InterfaceOrMixin ::
    InterfaceRest
    MixinRest
```

```grammar
InterfaceRest ::
    identifier Inheritance { InterfaceMembers } ;
```

```grammar
Partial ::
    partial PartialDefinition
```

```grammar
PartialDefinition ::
    interface PartialInterfaceOrPartialMixin
    PartialDictionary
    Namespace
```

```grammar
PartialInterfaceOrPartialMixin ::
    PartialInterfaceRest
    MixinRest
```

```grammar
PartialInterfaceRest ::
    identifier { PartialInterfaceMembers } ;
```

```grammar
InterfaceMembers ::
    ExtendedAttributeList InterfaceMember InterfaceMembers
    ε
```

```grammar
InterfaceMember ::
    PartialInterfaceMember
    Constructor
```

```grammar
PartialInterfaceMembers ::
    ExtendedAttributeList PartialInterfaceMember PartialInterfaceMembers
    ε
```

```grammar
PartialInterfaceMember ::
    Const
    Operation
    Stringifier
    StaticMember
    Iterable
    AsyncIterable
    ReadOnlyMember
    ReadWriteAttribute
    ReadWriteMaplike
    ReadWriteSetlike
    InheritAttribute
```

```grammar
Inheritance ::
    : identifier
    ε
```

The following [IDL fragment](#dfn-idl-fragment) demonstrates the definition of two mutually referential [interfaces](#dfn-interface). Both `Human` and `Dog` inherit from `Animal`. Objects that implement either of those two interfaces will thus have a `name` attribute.

```
[Exposed=Window]
interface Animal {
  attribute DOMString name;
};

[Exposed=Window]
interface Human : Animal {
  attribute Dog? pet;
};

[Exposed=Window]
interface Dog : Animal {
  attribute Human? owner;
};
```

The following [IDL fragment](#dfn-idl-fragment) defines simplified versions of a DOM [interfaces](#dfn-interface) and a [callback interface](#dfn-callback-interface).

```
[Exposed=Window]
interface Node {
  readonly attribute DOMString nodeName;
  readonly attribute Node? parentNode;
  Node appendChild(Node newChild);
  undefined addEventListener(DOMString type, EventListener listener);
};

callback interface EventListener {
  undefined handleEvent(Event event);
};
```

Plain objects can implement a [callback interface](#dfn-callback-interface) like `EventListener`:

```
var node = getNode();                                // Obtain an instance of Node.

var listener = {
  handleEvent: function(event) {
    // ...
  }
};
node.addEventListener("click", listener);            // This works.

node.addEventListener("click", function() { ... });  // As does this.
```

It is not possible for such an object to implement an [interface](#dfn-interface) like `Node`, however:

```
var node = getNode();  // Obtain an instance of Node.

var newNode = {
  nodeName: "span",
  parentNode: null,
  appendChild: function(newchild) {
    // ...
  },
  addEventListener: function(type, listener) {
    // ...
  }
};
node.appendChild(newNode);  // This will throw a TypeError exception.
```


## Interface mixins

An **interface mixin** is a definition (matching interface MixinRest) that declares state and behavior that can be included by one or more interfaces, and that are exposed by objects that implement an interface that includes the interface mixin.

```
interface mixin identifier {
  /* mixin_members... */
};
```

**Note:** Interface mixins, much like partial interfaces, are intended for use as a specification editorial aide, allowing a coherent set of functionalities to be grouped together, and included in multiple interfaces, possibly across documents. They are not meant to be exposed through language bindings. Guidance on when to choose partial interfaces, interface mixins, or partial interface mixins can be found in § 2.3.1 Using mixins and partials.

An interface mixin is a specification of a set of **interface mixin members** (matching MixinMembers), which are the constants, regular operations, regular attributes, and stringifiers that appear between the braces in the interface mixin declaration.

These constants, regular operations, regular attributes, and stringifiers describe the behaviors that can be implemented by an object, as if they were specified on the interface that includes them.

Static attributes, static operations, special operations, and iterable, asynchronously iterable, maplike, and setlike declarations cannot appear in interface mixin declarations.

As with interfaces, the IDL for interface mixins can be split into multiple parts by using **partial interface mixin** definitions (matching partial interface MixinRest). The identifier of a partial interface mixin definition must be the same as the identifier of an interface mixin definition. All of the members that appear on each of the partial interface mixin definitions are considered to be members of the interface mixin itself, and---by extension---of the interfaces that include the interface mixin.

```
interface mixin SomeMixin {
  /* mixin_members... */
};

partial interface mixin SomeMixin {
  /* mixin_members... */
};
```

The order that members appear in has significance for property enumeration in the JavaScript binding.

Note that unlike interfaces or dictionaries, interface mixins do not create types.

Of the extended attributes defined in this specification, only the \[`CrossOriginIsolated`\], \[`Exposed`\], and \[`SecureContext`\] extended attributes are applicable to interface mixins.

An **includes statement** is a definition (matching IncludesStatement) used to declare that all objects implementing an interface `I` (identified by the first identifier) must additionally include the members of interface mixin `M` (identified by the second identifier). Interface `I` is said to **include** interface mixin `M`.

```
interface_identifier includes mixin_identifier;
```

The first identifier must reference a interface `I`. The second identifier must reference an interface mixin `M`.

Each member of `M` is considered to be a member of each interface `I`, `J`, `K`, ... that includes `M`, as if a copy of each member had been made. So for a given member `m` of `M`, interface `I` is considered to have a member `m`~`I`~, interface `J` is considered to have a member `m`~`J`~, interface `K` is considered to have a member `m`~`K`~, and so on. The **host interfaces** of `m`~`I`~, `m`~`J`~, and `m`~`K`~, are `I`, `J`, and `K` respectively.

**Note:** In JavaScript, this implies that each regular operation declared as a member of interface mixin `M`, and exposed as a data property with a built-in function object value, is a distinct built-in function object in each interface prototype object whose associated interface includes `M`. Similarly, for attributes, each copy of the accessor property has distinct built-in function objects for its getters and setters.

The order of appearance of includes statements affects the order in which interface mixin are included by their host interface.

Member order isn't clearly specified, in particular when interface mixins are defined in separate documents. It is discussed in issue #432.

No extended attributes defined in this specification are applicable to includes statements.

The following IDL fragment defines an interface, `Entry`, and an interface mixin, `Observable`. The includes statement specifies that `Observable`'s members are always included on objects implementing `Entry`.

```
interface Entry {
  readonly attribute unsigned short entryType;
  // ...
};

interface mixin Observable {
  undefined addEventListener(DOMString type,
                        EventListener listener,
                        boolean useCapture);
  // ...
};

Entry includes Observable;
```

A JavaScript implementation would thus have an `addEventListener` property in the prototype chain of every `Entry`:

```
var e = getEntry();          // Obtain an instance of Entry.
typeof e.addEventListener;   // Evaluates to "function".
```

```
CallbackOrInterfaceOrMixin ::
    callback CallbackRestOrInterface
    interface InterfaceOrMixin
```

```
InterfaceOrMixin ::
    InterfaceRest
    MixinRest
```

```
Partial ::
    partial PartialDefinition
```

```
PartialDefinition ::
    interface PartialInterfaceOrPartialMixin
    PartialDictionary
    Namespace
```

```
MixinRest ::
    mixin identifier { MixinMembers } ;
```

```
MixinMembers ::
    ExtendedAttributeList MixinMember MixinMembers
    ε
```

```
MixinMember ::
    Const
    RegularOperation
    Stringifier
    OptionalReadOnly AttributeRest
```

```
IncludesStatement ::
    identifier includes identifier ;
```


### Using mixins and partials

*This section is informative.*

Interface mixins allow the sharing of attributes, constants, and operations across *multiple* interfaces. If you're only planning to extend a single interface, you might consider using a partial interface instead.

For example, instead of:

```
interface mixin WindowSessionStorage {
  readonly attribute Storage sessionStorage;
};
Window includes WindowSessionStorage;
```

do:

```
partial interface Window {
  readonly attribute Storage sessionStorage;
};
```

Additionally, you can rely on extending interface mixins exposed by other specifications to target common use cases, such as exposing a set of attributes, constants, or operations across both window and worker contexts.

For example, instead of the common but verbose:

```
interface mixin GlobalCrypto {
  readonly attribute Crypto crypto;
};

Window includes GlobalCrypto;
WorkerGlobalScope includes GlobalCrypto;
```

you can extend the `WindowOrWorkerGlobalScope` interface mixin using a partial interface mixin:

```
partial interface mixin WindowOrWorkerGlobalScope {
  readonly attribute Crypto crypto;
};
```


## Callback interfaces

A **callback interface** is a definition matching callback interface identifier { CallbackInterfaceMembers } ;. It can be implemented by any object, as described in § 2.12 Objects implementing interfaces.

Note: A callback interface is not an interface. The name and syntax are left over from earlier versions of this standard, where these concepts had more in common.

A callback interface is a specification of a set of **callback interface members** (matching CallbackInterfaceMembers). These are the members that appear between the braces in the interface declaration.

```syntax
callback interface identifier {
  /* interface_members... */
};
```

Note: See also the similarly named callback function definition.

Callback interfaces must define exactly one regular operation.

**Warning**

Specification authors should not define callback interfaces unless required to describe the requirements of existing APIs. Instead, a callback function should be used.

The definition of `EventListener` as a callback interface is an example of an existing API that needs to allow objects with a given property (in this case `handleEvent`) to be considered to implement the interface. For new APIs, and those for which there are no compatibility concerns, using a callback function will allow only a function object (in the JavaScript language binding).

Callback interfaces which declare constants must be annotated with an \[`Exposed`\] extended attribute.

```grammar
CallbackRestOrInterface ::
    CallbackRest
    interface identifier { CallbackInterfaceMembers } ;
```

```grammar
CallbackInterfaceMembers ::
    ExtendedAttributeList CallbackInterfaceMember CallbackInterfaceMembers
    ε
```

```grammar
CallbackInterfaceMember ::
    Const
    RegularOperation
```


### Members

[Interfaces](#dfn-interface), [interface mixins](#interface-mixin), and [namespaces](#dfn-namespace) are specifications of a set of **members** (respectively matching [InterfaceMembers](#prod-InterfaceMembers), [MixinMembers](#prod-MixinMembers), and [NamespaceMembers](#prod-NamespaceMembers)), which are the [constants](#dfn-constant), [attributes](#dfn-attribute), [operations](#dfn-operation), and other declarations that appear between the braces of their declarations. [Attributes](#dfn-attribute) describe the state that an object implementing the [interface](#dfn-interface), [interface mixin](#interface-mixin), or [namespace](#dfn-namespace) will expose, and [operations](#dfn-operation) describe the behaviors that can be invoked on the object. [Constants](#dfn-constant) declare named constant values that are exposed as a convenience to users of objects in the system.

When an [interface](#dfn-interface) [includes](#include) an [interface mixin](#interface-mixin), each [member](#dfn-member) of the interface mixin is also considered a member of the interface. In contrast, [inherited](#dfn-inherit) interface members are not considered members of the interface.

The [constructor steps](#constructor-steps), [getter steps](#getter-steps), [setter steps](#setter-steps), and [method steps](#method-steps) for the various [members](#dfn-member) defined on an [interface](#dfn-interface) or [interface mixin](#interface-mixin) have access to a **this** value, which is an IDL value of the [interface](#dfn-interface) type that the member is declared on or that [includes](#include) the [interface mixin](#interface-mixin) the member is declared on.

[Setter steps](#setter-steps) also have access to **the given value**, which is an IDL value of the type the [attribute](#dfn-attribute) is declared as.

[Interfaces](#dfn-interface), [interface mixins](#interface-mixin), [callback interfaces](#dfn-callback-interface) and [namespaces](#dfn-namespace) each support a different set of [members](#dfn-member), which are specified in [§ 2.2 Interfaces](#idl-interfaces), [§ 2.3 Interface mixins](#idl-interface-mixins), [§ 2.4 Callback interfaces](#idl-callback-interfaces), and [§ 2.6 Namespaces](#idl-namespaces), and summarized in the following informative table:

|                                                         | [Interfaces](#dfn-interface) | [Callback interfaces](#dfn-callback-interface) | [Interface mixins](#interface-mixin) | [Namespaces](#dfn-namespace)                                      |
|---------------------------------------------------------|------------------------------|------------------------------------------------|--------------------------------------|-------------------------------------------------------------------|
| [Constants](#dfn-constant)                              | ●                            | ●                                              | ●                                    |                                                                   |
| [Regular attributes](#dfn-regular-attribute)            | ●                            |                                                | ●                                    | Only [read only](#dfn-read-only) attributes                       |
| [Static attributes](#dfn-static-attribute)              | ●                            |                                                |                                      |                                                                   |
| [Regular Operations](#dfn-regular-operation)            | ●                            | ●                                              | ●                                    | ●                                                                 |
| [Stringifiers](#dfn-stringifier)                        | ●                            |                                                | ●                                    |                                                                   |
| [Special Operations](#dfn-special-operation)            | ●                            |                                                |                                      |                                                                   |
| [Static Operations](#dfn-static-operation)              | ●                            |                                                |                                      |                                                                   |
| [Iterable declarations](#dfn-iterable-declaration)      | ●                            |                                                |                                      |                                                                   |
| [Asynchronously iterable declarations](#dfn-async-iterable-declaration) | ●                 |                                                |                                      |                                                                   |
| [Maplike declarations](#dfn-maplike-declaration)        | ●                            |                                                |                                      |                                                                   |
| [Setlike declarations](#dfn-setlike-declaration)        | ●                            |                                                |                                      |                                                                   |


#### Constants

A **constant** is a declaration (matching [Const](#prod-Const)) used to bind a constant value to a name. Constants can appear on [interfaces](#dfn-interface) and [callback interfaces](#dfn-callback-interface).

Constants have in the past primarily been used to define named integer codes in the style of an enumeration. The Web platform is moving away from this design pattern in favor of the use of strings. Editors who wish to use this feature are strongly advised to discuss this by [filing an issue](https://github.com/whatwg/webidl/issues/new?title=Intent%20to%20use%20Constants) before proceeding.

```
const type constant_identifier = 42;
```

The [identifier](#dfn-identifier) of a [constant](#dfn-constant) must not be the same as the identifier of another [interface member](#dfn-interface-member) or [callback interface member](#callback-interface-member) defined on the same [interface](#dfn-interface) or [callback interface](#dfn-callback-interface). The identifier also must not be "`length`", "`name`" or "`prototype`".

These three names are the names of properties that are defined on the [interface object](#dfn-interface-object) in the JavaScript language binding.

The type of a constant (matching [ConstType](#prod-ConstType)) must not be any type other than a [primitive type](#dfn-primitive-type). If an [identifier](#dfn-identifier) is used, it must reference a [typedef](#dfn-typedef) whose type is a primitive type.

The [ConstValue](#prod-ConstValue) part of a constant declaration gives the value of the constant, which can be one of the two boolean literal tokens (true and false), an [integer](#prod-integer) token, a [decimal](#prod-decimal) token, or one of the three special floating point constant values (-Infinity, Infinity and NaN).

These values -- in addition to strings and the empty sequence -- can also be used to specify the [default value of a dictionary member](#dfn-dictionary-member-default-value) or [of an optional argument](#dfn-optional-argument-default-value). Note that strings, the empty sequence \[\], and the default dictionary {} cannot be used as the value of a [constant](#dfn-constant).

The value of the boolean literal tokens true and false are the IDL [`boolean`](#idl-boolean) values `true` and `false`.

The value of an [integer](#prod-integer) token is an integer whose value is determined as follows:

1. Let `S` be the sequence of [scalar values](https://infra.spec.whatwg.org/#scalar-value) matched by the [integer](#prod-integer) token.

2. Let `sign` be −1 if `S` begins with U+002D (-), and 1 otherwise.

3. Let `base` be the base of the number based on the [scalar values](https://infra.spec.whatwg.org/#scalar-value) that follow the optional leading U+002D (-):

   U+0030 (0), U+0058 (X)  
   U+0030 (0), U+0078 (x)

   : The base is 16.

   U+0030 (0)

   : The base is 8.

   Otherwise

   : The base is 10.

4. Let `number` be the result of interpreting all remaining [scalar values](https://infra.spec.whatwg.org/#scalar-value) following the optional leading U+002D (-) character and any [scalar values](https://infra.spec.whatwg.org/#scalar-value) indicating the base as an integer specified in base `base`.

5. Return `sign` × `number`.

The type of an [integer](#prod-integer) token is the same as the type of the constant, dictionary member or optional argument it is being used as the value of. The value of the [integer](#prod-integer) token must not lie outside the valid range of values for its type, as given in [§ 2.13 Types](#idl-types).

The value of a [decimal](#prod-decimal) token is either an IEEE 754 single-precision floating point number or an IEEE 754 double-precision floating point number, depending on the type of the constant, dictionary member or optional argument it is being used as the value for, determined as follows:

1. Let `S` be the sequence of [scalar values](https://infra.spec.whatwg.org/#scalar-value) matched by the [decimal](#prod-decimal) token.

2. Let `result` be the Mathematical Value that would be obtained if `S` were parsed as a JavaScript [NumericLiteral](https://tc39.es/ecma262/#sec-literals-numeric-literals).

3. If the [decimal](#prod-decimal) token is being used as the value for a [`float`](#idl-float) or [`unrestricted float`](#idl-unrestricted-float), then the value of the [decimal](#prod-decimal) token is the IEEE 754 single-precision floating point number closest to `result`.

4. Otherwise, the [decimal](#prod-decimal) token is being used as the value for a [`double`](#idl-double) or [`unrestricted double`](#idl-unrestricted-double), and the value of the [decimal](#prod-decimal) token is the IEEE 754 double-precision floating point number closest to `result`. [\[IEEE-754\]](#biblio-ieee-754)

The value of a constant value specified as Infinity, -Infinity, or NaN is either an IEEE 754 single-precision floating point number or an IEEE 754 double-precision floating point number, depending on the type of the constant, dictionary member, or optional argument it is being used as the value for:

Type [`unrestricted float`](#idl-unrestricted-float), constant value Infinity

: The value is the IEEE 754 single-precision positive infinity value.

Type [`unrestricted double`](#idl-unrestricted-double), constant value Infinity

: The value is the IEEE 754 double-precision positive infinity value.

Type [`unrestricted float`](#idl-unrestricted-float), constant value -Infinity

: The value is the IEEE 754 single-precision negative infinity value.

Type [`unrestricted double`](#idl-unrestricted-double), constant value -Infinity

: The value is the IEEE 754 double-precision negative infinity value.

Type [`unrestricted float`](#idl-unrestricted-float), constant value NaN

: The value is the IEEE 754 single-precision NaN value with the bit pattern 0x7fc00000.

Type [`unrestricted double`](#idl-unrestricted-double), constant value NaN

: The value is the IEEE 754 double-precision NaN value with the bit pattern 0x7ff8000000000000.

The type of a [decimal](#prod-decimal) token is the same as the type of the constant, dictionary member or optional argument it is being used as the value of. The value of the [decimal](#prod-decimal) token must not lie outside the valid range of values for its type, as given in [§ 2.13 Types](#idl-types). Also, Infinity, -Infinity and NaN must not be used as the value of a [`float`](#idl-float) or [`double`](#idl-double).

The value of the null token is the special null value that is a member of the [nullable types](#dfn-nullable-type). The type of the null token is the same as the type of the constant, dictionary member or optional argument it is being used as the value of.

If `VT` is the type of the value assigned to a constant, and `DT` is the type of the constant, dictionary member or optional argument itself, then these types must be compatible, which is the case if `DT` and `VT` are identical, or `DT` is a [nullable type](#dfn-nullable-type) whose [inner type](#dfn-inner-type) is `VT`.

[Constants](#dfn-constant) are not associated with particular instances of the [interface](#dfn-interface) or [callback interface](#dfn-callback-interface) on which they appear. It is language binding specific whether [constants](#dfn-constant) are exposed on instances.

The JavaScript language binding does however allow [constants](#dfn-constant) to be accessed through objects implementing the IDL [interfaces](#dfn-interface) on which the [constants](#dfn-constant) are declared. For example, with the following IDL:

```
[Exposed=Window]
interface A {
  const short rambaldi = 47;
};
```

the constant value can be accessed in JavaScript either as `A.rambaldi` or `instanceOfA.rambaldi`.

The following extended attributes are applicable to constants: \[[`CrossOriginIsolated`](#CrossOriginIsolated)\], \[[`Exposed`](#Exposed)\], and \[[`SecureContext`](#SecureContext)\].

```
Const ::
    const ConstType identifier = ConstValue ;
```

```
ConstValue ::
    BooleanLiteral
    FloatLiteral
    integer
```

```
BooleanLiteral ::
    true
    false
```

```
FloatLiteral ::
    decimal
    -Infinity
    Infinity
    NaN
```

```
ConstType ::
    PrimitiveType
    identifier
```

The following [IDL fragment](#dfn-idl-fragment) demonstrates how [constants](#dfn-constant) of the above types can be defined.

```
[Exposed=Window]
interface Util {
  const boolean DEBUG = false;
  const octet LF = 10;
  const unsigned long BIT_MASK = 0x0000fc00;
  const double AVOGADRO = 6.022e23;
};
```


#### Attributes

An **attribute** is an [interface member](#dfn-interface-member) or [namespace member](#dfn-namespace-member) (matching inherit [AttributeRest](#prod-AttributeRest), static [OptionalReadOnly](#prod-OptionalReadOnly) [AttributeRest](#prod-AttributeRest), stringifier [OptionalReadOnly](#prod-OptionalReadOnly) [AttributeRest](#prod-AttributeRest), [OptionalReadOnly](#prod-OptionalReadOnly) [AttributeRest](#prod-AttributeRest), or [AttributeRest](#prod-AttributeRest)) that is used to declare data fields with a given type and [identifier](#dfn-identifier) whose value can be retrieved and (in some cases) changed. There are two kinds of attributes:

1. **regular attributes**, which are those used to declare that objects implementing the [interface](#dfn-interface) will have a data field member with the given [identifier](#dfn-identifier)

   ```
   interface interface_identifier {
     attribute type identifier;
   };
   ```

2. **static attributes**, which are used to declare attributes that are not associated with a particular object implementing the interface

   ```
   interface interface_identifier {
     static attribute type identifier;
   };
   ```

If an attribute has no static keyword, then it declares a **regular attribute**. Otherwise, it declares a [static attribute](#dfn-static-attribute). Note that in addition to being [interface members](#dfn-interface-member), [read only](#dfn-read-only) [regular attributes](#dfn-regular-attribute) can be [namespace members](#dfn-namespace-member) as well.

The **getter steps** of an attribute `attr` should be introduced using text of the form "The `attr` getter steps are:" followed by a list, or "The `attr` getter steps are to" followed by an inline description.

The **setter steps** of an attribute `attr` should be introduced using text of the form "The `attr` setter steps are:" followed by a list, or "The `attr` setter steps are to" followed by an inline description.

When defining [getter steps](#getter-steps), you implicitly have access to [this](#this). When defining [setter steps](#setter-steps), you implicitly have access to [this](#this) and [the given value](#the-given-value).

The [identifier](#dfn-identifier) of an [attribute](#dfn-attribute) must not be the same as the identifier of another [interface member](#dfn-interface-member) defined on the same [interface](#dfn-interface). The identifier of a static attribute must not be "`prototype`".

The type of the attribute is given by the type (matching [Type](#prod-Type)) that appears after the attribute keyword. If the [Type](#prod-Type) is an [identifier](#dfn-identifier) or an identifier followed by ?, then the identifier must identify an [interface](#dfn-interface), [enumeration](#dfn-enumeration), [callback function](#dfn-callback-function), [callback interface](#dfn-callback-interface) or [typedef](#dfn-typedef).

The type of the attribute, after resolving typedefs, must not be a [nullable](#dfn-nullable-type) or non-nullable version of any of the following types:

- a [sequence type](#sequence-type)

- an [async sequence type](#async-sequence-type)

- a [dictionary type](#idl-dictionary)

- a [record type](#record-type)

- a [union type](#dfn-union-type) that has a nullable or non-nullable sequence type, dictionary, or record as one of its [flattened member types](#dfn-flattened-union-member-types)

The attribute is **read only** if the readonly keyword is used before the attribute keyword. An object that implements the interface on which a read only attribute is defined will not allow assignment to that attribute. It is language binding specific whether assignment is simply disallowed by the language, ignored or an exception is thrown.

```
interface interface_identifier {
  readonly attribute type identifier;
};
```

Attributes whose type is a [promise type](#dfn-promise-type) must be [read only](#dfn-read-only). Additionally, they cannot have any of the [extended attributes](#dfn-extended-attribute) \[[`LegacyLenientSetter`](#LegacyLenientSetter)\], \[[`PutForwards`](#PutForwards)\], \[[`Replaceable`](#Replaceable)\], or \[[`SameObject`](#SameObject)\].

A [regular attribute](#dfn-regular-attribute) that is not [read only](#dfn-read-only) can be declared to **inherit its getter** from an ancestor interface. This can be used to make a read only attribute in an ancestor interface be writable on a derived interface. An attribute [inherits its getter](#dfn-inherit-getter) if its declaration includes inherit in the declaration. The read only attribute from which the attribute inherits its getter is the attribute with the same identifier on the closest ancestor interface of the one on which the inheriting attribute is defined. The attribute whose getter is being inherited must be of the same type as the inheriting attribute.

The grammar ensures that inherit does not appear on a [read only](#dfn-read-only) attribute or a [static attribute](#dfn-static-attribute).

```
[Exposed=Window]
interface Ancestor {
  readonly attribute TheType theIdentifier;
};

[Exposed=Window]
interface Derived : Ancestor {
  inherit attribute TheType theIdentifier;
};
```

When the stringifier keyword is used in a [regular attribute](#dfn-regular-attribute) declaration, it indicates that objects implementing the interface will be stringified to the value of the attribute. See [§ 2.5.5 Stringifiers](#idl-stringifiers) for details.

```
interface interface_identifier {
  stringifier attribute DOMString identifier;
};
```

The following [extended attributes](#dfn-extended-attribute) are applicable to regular and static attributes: \[[`CrossOriginIsolated`](#CrossOriginIsolated)\], \[[`Exposed`](#Exposed)\], \[[`SameObject`](#SameObject)\], and \[[`SecureContext`](#SecureContext)\].

The following [extended attributes](#dfn-extended-attribute) are applicable only to regular attributes: \[[`LegacyLenientSetter`](#LegacyLenientSetter)\], \[[`LegacyLenientThis`](#LegacyLenientThis)\], \[[`PutForwards`](#PutForwards)\], \[[`Replaceable`](#Replaceable)\], \[[`LegacyUnforgeable`](#LegacyUnforgeable)\].

```
ReadOnlyMember ::
    readonly ReadOnlyMemberRest
```

```
ReadOnlyMemberRest ::
    AttributeRest
    MaplikeRest
    SetlikeRest
```

```
ReadWriteAttribute ::
    AttributeRest
```

```
InheritAttribute ::
    inherit AttributeRest
```

```
AttributeRest ::
    attribute TypeWithExtendedAttributes AttributeName ;
```

```
AttributeName ::
    AttributeNameKeyword
    identifier
```

```
AttributeNameKeyword ::
    required
```

```
OptionalReadOnly ::
    readonly
    ε
```

The following [IDL fragment](#dfn-idl-fragment) demonstrates how [attributes](#dfn-attribute) can be declared on an [interface](#dfn-interface):

```
[Exposed=Window]
interface Animal {

  // A simple attribute that can be set to any string value.
  readonly attribute DOMString name;

  // An attribute whose value can be assigned to.
  attribute unsigned short age;
};

[Exposed=Window]
interface Person : Animal {

  // An attribute whose getter behavior is inherited from Animal, and need not be
  // specified in the description of Person.
  inherit attribute DOMString name;
};
```


#### Operations

An **operation** is an [interface member](#dfn-interface-member), [callback interface member](#callback-interface-member) or [namespace member](#dfn-namespace-member) (matching static [RegularOperation](#prod-RegularOperation), stringifier, [RegularOperation](#prod-RegularOperation) or [SpecialOperation](#prod-SpecialOperation)) that defines a behavior that can be invoked on objects implementing the interface. There are three kinds of operation:

1. [regular operations](#dfn-regular-operation), which are those used to declare that objects implementing the [interface](#dfn-interface) will have a method with the given [identifier](#dfn-identifier)

   ```
   interface interface_identifier {
     return_type identifier(/* arguments... */);
   };
   ```

2. [special operations](#dfn-special-operation), which are used to declare special behavior on objects implementing the interface, such as object indexing and stringification

   ```
   interface interface_identifier {
     /* special_keyword */ return_type identifier(/* arguments... */);
     /* special_keyword */ return_type (/* arguments... */);
   };
   ```

3. [static operations](#dfn-static-operation), which are used to declare operations that are not associated with a particular object implementing the interface

   ```
   interface interface_identifier {
     static return_type identifier(/* arguments... */);
   };
   ```

If an operation has an identifier but no static keyword, then it declares a **regular operation**. If the operation has a [special keyword](#dfn-special-keyword) used in its declaration (that is, any keyword matching [Special](#prod-Special), or the stringifier keyword), then it declares a special operation. A single operation can declare both a regular operation and a special operation; see [§ 2.5.6 Special operations](#idl-special-operations) for details on special operations. Note that in addition to being [interface members](#dfn-interface-member), regular operations can also be [callback interface members](#callback-interface-member) and [namespace members](#dfn-namespace-member).

If an operation has no identifier, then it must be declared to be a special operation using one of the special keywords.

The identifier of a [regular operation](#dfn-regular-operation) or [static operation](#dfn-static-operation) must not be the same as the identifier of a [constant](#dfn-constant) or [attribute](#dfn-attribute) defined on the same [interface](#dfn-interface), [callback interface](#dfn-callback-interface) or [namespace](#dfn-namespace). The identifier of a static operation must not be "`prototype`".

The identifier can be the same as that of another operation on the interface, however. This is how operation overloading is specified.

The [identifier](#dfn-identifier) of a [static operation](#dfn-static-operation) can be the same as the identifier of a [regular operation](#dfn-regular-operation) defined on the same [interface](#dfn-interface).

The **return type** of the operation is given by the type (matching [Type](#prod-Type)) that appears before the operation's optional [identifier](#dfn-identifier). If the return type is an [identifier](#dfn-identifier) followed by ?, then the identifier must identify an [interface](#dfn-interface), [dictionary](#dfn-dictionary), [enumeration](#dfn-enumeration), [callback function](#dfn-callback-function), [callback interface](#dfn-callback-interface) or [typedef](#dfn-typedef).

An operation's arguments (matching [ArgumentList](#prod-ArgumentList)) are given between the parentheses in the declaration. Each individual argument is specified as a type (matching [Type](#prod-Type)) followed by an [identifier](#dfn-identifier) (matching [ArgumentName](#prod-ArgumentName)).

For expressiveness, the identifier of an operation argument can also be specified as one of the keywords matching the [ArgumentNameKeyword](#prod-ArgumentNameKeyword) symbol without needing to escape it.

If the [Type](#prod-Type) of an operation argument is an identifier followed by ?, then the identifier must identify an [interface](#dfn-interface), [enumeration](#dfn-enumeration), [callback function](#dfn-callback-function), [callback interface](#dfn-callback-interface), or [typedef](#dfn-typedef). If the operation argument type is an [identifier](#dfn-identifier) not followed by ?, then the identifier must identify any one of those definitions or a [dictionary](#dfn-dictionary).

If the operation argument type, after resolving typedefs, is a [nullable type](#dfn-nullable-type), its [inner type](#dfn-inner-type) must not be a [dictionary type](#idl-dictionary).

```
interface interface_identifier {
  return_type identifier(type identifier, type identifier /* , ... */);
};
```

The identifier of each argument must not be the same as the identifier of another argument in the same operation declaration.

Each argument can be preceded by a list of [extended attributes](#dfn-extended-attribute) (matching [ExtendedAttributeList](#prod-ExtendedAttributeList)), which can control how a value passed as the argument will be handled in language bindings.

```
interface interface_identifier {
  return_type identifier([extended_attributes] type identifier, [extended_attributes] type identifier /* , ... */);
};
```

The following [IDL fragment](#dfn-idl-fragment) demonstrates how [regular operations](#dfn-regular-operation) can be declared on an [interface](#dfn-interface):

```
[Exposed=Window]
interface Dimensions {
  attribute unsigned long width;
  attribute unsigned long height;
};

[Exposed=Window]
interface Button {

  // An operation that takes no arguments and returns a boolean.
  boolean isMouseOver();

  // Overloaded operations.
  undefined setDimensions(Dimensions size);
  undefined setDimensions(unsigned long width, unsigned long height);
};
```

An operation or [constructor operation](#idl-constructors) is considered to be **variadic** if the final argument uses the \... token just after the argument type. Declaring an operation to be variadic indicates that the operation can be invoked with any number of arguments after that final argument. Those extra implied formal arguments are of the same type as the final explicit argument in the operation declaration. The final argument can also be omitted when invoking the operation. An argument must not be declared with the \... token unless it is the final argument in the operation's argument list.

```
interface interface_identifier {
  return_type identifier(type... identifier);
  return_type identifier(type identifier, type... identifier);
};
```

[Extended attributes](#dfn-extended-attribute) that [take an argument list](#dfn-xattr-argument-list) (\[[`LegacyFactoryFunction`](#LegacyFactoryFunction)\], of those defined in this specification) and [callback functions](#dfn-callback-function) are also considered to be [variadic](#dfn-variadic) when the \... token is used in their argument lists.

The following [IDL fragment](#dfn-idl-fragment) defines an interface `OrderedMap` which allows retrieving and setting values by name or by index number:

```
[Exposed=Window]
interface IntegerSet {
  readonly attribute unsigned long cardinality;

  undefined union(long... ints);
  undefined intersection(long... ints);
};
```

In the JavaScript binding, variadic operations are implemented by functions that can accept the subsequent arguments:

```
var s = getIntegerSet();  // Obtain an instance of IntegerSet.

s.union();                // Passing no arguments corresponding to 'ints'.
s.union(1, 4, 7);         // Passing three arguments corresponding to 'ints'.
```

A binding for a language that does not support variadic functions might specify that an explicit array or list of integers be passed to such an operation.

An argument is considered to be an **optional argument** if it is declared with the optional keyword. The final argument of a [variadic](#dfn-variadic) operation is also considered to be an optional argument. Declaring an argument to be optional indicates that the argument value can be omitted when the operation is invoked. The final argument in an operation must not explicitly be declared to be optional if the operation is [variadic](#dfn-variadic).

```
interface interface_identifier {
  return_type identifier(type identifier, optional type identifier);
};
```

Optional arguments can also have a **default value** specified. If the argument's identifier is followed by a U+003D (=) and a value (matching [DefaultValue](#prod-DefaultValue)), then that gives the optional argument its [default value](#dfn-optional-argument-default-value). The implicitly optional final argument of a [variadic](#dfn-variadic) operation must not have a default value specified. The default value is the value to be assumed when the operation is called with the corresponding argument omitted.

```
interface interface_identifier {
  return_type identifier(type identifier, optional type identifier = "value");
};
```

It is strongly suggested not to use a [default value](#dfn-optional-argument-default-value) of true for [`boolean`](#idl-boolean)-typed arguments, as this can be confusing for authors who might otherwise expect the default conversion of undefined to be used (i.e., false). [\[API-DESIGN-PRINCIPLES\]](#biblio-api-design-principles)

If the type of an argument is a [dictionary type](#idl-dictionary) or a [union type](#dfn-union-type) that has a [dictionary type](#idl-dictionary) as one of its [flattened member types](#dfn-flattened-union-member-types), and that dictionary type and its ancestors have no [required](#required-dictionary-member) [members](#dfn-dictionary-member), and the argument is either the final argument or is followed only by [optional arguments](#dfn-optional-argument), then the argument must be specified as optional and have a default value provided.

This is to encourage API designs that do not require authors to pass an empty dictionary value when they wish only to use the dictionary's default values.

Usually the default value provided will be {}, but in the case of a [union type](#dfn-union-type) that has a dictionary type as one of its [flattened member types](#dfn-flattened-union-member-types) a default value could be provided that initializes some other member of the union.

When a boolean literal token (true or false), the null token, an [integer](#prod-integer) token, a [decimal](#prod-decimal) token or one of the three special floating point literal values (Infinity, -Infinity or NaN) is used as the [default value](#dfn-optional-argument-default-value), it is interpreted in the same way as for a [constant](#dfn-constant).

When the undefined token is used as the [default value](#dfn-optional-argument-default-value), the value is the IDL [`undefined`](#idl-undefined) value.

Optional argument default values can also be specified using a [string](#prod-string) token, whose value is a [string type](#dfn-string-type) determined as follows:

1. Let `S` be the sequence of [scalar values](https://infra.spec.whatwg.org/#scalar-value) matched by the [string](#prod-string) token with its leading and trailing U+0022 (") [scalar values](https://infra.spec.whatwg.org/#scalar-value) removed.

2. Depending on the type of the argument:

   [`DOMString`](#idl-DOMString)  
   [`USVString`](#idl-USVString)  
   an [enumeration](#dfn-enumeration) type

   : The value of the [string](#prod-string) token is `S`.

   [`ByteString`](#idl-ByteString)

   : Assert: `S` doesn't contain any [code points](https://infra.spec.whatwg.org/#code-point) higher than U+00FF.

     The value of the [string](#prod-string) token is the [isomorphic encoding](https://infra.spec.whatwg.org/#isomorphic-encode) of `S`.

If the type of the [optional argument](#dfn-optional-argument) is an [enumeration](#dfn-enumeration), then its [default value](#dfn-optional-argument-default-value) if specified must be one of the [enumeration's values](#dfn-enumeration-value).

Optional argument default values can also be specified using the two token value \[\], which represents an empty sequence value. The type of this value is the same as the type of the optional argument it is being used as the default value of. That type must be a [sequence type](#sequence-type), a [nullable type](#dfn-nullable-type) whose [inner type](#dfn-inner-type) is a [sequence type](#sequence-type) or a [union type](#dfn-union-type) or [nullable](#dfn-nullable-type) union type that has a [sequence type](#sequence-type) in its [flattened member types](#dfn-flattened-union-member-types).

Optional argument default values can also be specified using the two token value {}, which represents a default-initialized (as if from ES null or an object with no properties) dictionary value. The type of this value is the same as the type of the optional argument it is being used as the default value of. That type must be a [dictionary type](#idl-dictionary), or a [union type](#dfn-union-type) that has a [dictionary type](#idl-dictionary) in its [flattened member types](#dfn-flattened-union-member-types).

The following [IDL fragment](#dfn-idl-fragment) defines an [interface](#dfn-interface) with a single [operation](#dfn-operation) that can be invoked with two different argument list lengths:

```
[Exposed=Window]
interface ColorCreator {
  object createColor(double v1, double v2, double v3, optional double alpha);
};
```

It is equivalent to an [interface](#dfn-interface) that has two [overloaded](#dfn-overloaded) [operations](#dfn-operation):

```
[Exposed=Window]
interface ColorCreator {
  object createColor(double v1, double v2, double v3);
  object createColor(double v1, double v2, double v3, double alpha);
};
```

The following [IDL fragment](#dfn-idl-fragment) defines an [interface](#dfn-interface) with an operation that takes a dictionary argument:

```
dictionary LookupOptions {
  boolean caseSensitive = false;
};

[Exposed=Window]
interface AddressBook {
  boolean hasAddressForName(USVString name, optional LookupOptions options = {});
};
```

If `hasAddressForName` is called with only one argument, the second argument will be a default-initialized `LookupOptions` dictionary, which will cause `caseSensitive` to be set to false.

The following extended attributes are applicable to operations: \[[`CrossOriginIsolated`](#CrossOriginIsolated)\], \[[`Default`](#Default)\], \[[`Exposed`](#Exposed)\], \[[`LegacyUnforgeable`](#LegacyUnforgeable)\], \[[`NewObject`](#NewObject)\], and \[[`SecureContext`](#SecureContext)\].

The **method steps** of an operation `operation` should be introduced using text of the form "The `operation`(`arg1`, `arg2`, ...) method steps are:" followed by a list, or "The `operation`(`arg1`, `arg2`, ...) method steps are to" followed by an inline description.

When defining [method steps](#method-steps), you implicitly have access to [this](#this).

```
DefaultValue ::
    ConstValue
    string
    [ ]
    { }
    null
    undefined
```

```
Operation ::
    RegularOperation
    SpecialOperation
```

```
RegularOperation ::
    Type OperationRest
```

```
SpecialOperation ::
    Special RegularOperation
```

```
Special ::
    getter
    setter
    deleter
```

```
OperationRest ::
    OptionalOperationName ( ArgumentList ) ;
```

```
OptionalOperationName ::
    OperationName
    ε
```

```
OperationName ::
    OperationNameKeyword
    identifier
```

```
OperationNameKeyword ::
    includes
```

```
ArgumentList ::
    Argument Arguments
    ε
```

```
Arguments ::
    , Argument Arguments
    ε
```

```
Argument ::
    ExtendedAttributeList ArgumentRest
```

```
ArgumentRest ::
    optional TypeWithExtendedAttributes ArgumentName Default
    Type Ellipsis ArgumentName
```

```
ArgumentName ::
    ArgumentNameKeyword
    identifier
```

```
Ellipsis ::
    ...
    ε
```

```
ArgumentNameKeyword ::
    attribute
    callback
    const
    constructor
    deleter
    dictionary
    enum
    getter
    includes
    inherit
    interface
    iterable
    maplike
    mixin
    namespace
    partial
    readonly
    required
    setlike
    setter
    static
    stringifier
    typedef
    unrestricted
```


##### toJSON

By declaring a `toJSON` [regular operation](#dfn-regular-operation), an [interface](#dfn-interface) specifies how to convert the objects that implement it to [JSON types](#dfn-json-types).

The `toJSON` [regular operation](#dfn-regular-operation) is reserved for this usage. It must take zero arguments and return a [JSON type](#dfn-json-types).

The **JSON types** are:

- [numeric types](#dfn-numeric-type),

- [`boolean`](#idl-boolean),

- [string types](#dfn-string-type),

- [nullable types](#dfn-nullable-type) whose [inner type](#dfn-inner-type) is a [JSON type](#dfn-json-types),

- [annotated types](#annotated-types) whose [inner type](#annotated-types-inner-type) is a [JSON type](#dfn-json-types),

- [union types](#dfn-union-type) whose [member types](#dfn-union-member-type) are [JSON types](#dfn-json-types),

- [typedefs](#dfn-typedef) whose [type being given a new name](#type-being-given-a-new-name) is a [JSON type](#dfn-json-types),

- [sequence types](#sequence-type) whose parameterized type is a [JSON type](#dfn-json-types),

- [frozen array types](#dfn-frozen-array-type) whose parameterized type is a [JSON type](#dfn-json-types),

- [dictionary types](#idl-dictionary) where the types of all [members](#dfn-dictionary-member) declared on the dictionary and all its [inherited dictionaries](#dfn-inherited-dictionaries) are [JSON types](#dfn-json-types),

- [records](#idl-record) where all of their [values](https://infra.spec.whatwg.org/#map-getting-the-values) are [JSON types](#dfn-json-types),

- [`object`](#idl-object),

- [interface types](#idl-interface) that have a `toJSON` operation declared on themselves or one of their [inherited interfaces](#dfn-inherited-interfaces).

How the `toJSON` [regular operation](#dfn-regular-operation) is made available on an object in a language binding, and how exactly the [JSON types](#dfn-json-types) are converted into a JSON string, is language binding specific.

In the JavaScript language binding, this is done by exposing a `toJSON` method which returns the [JSON type](#dfn-json-types) converted into a JavaScript value that can be turned into a JSON string by the [`JSON.stringify()`](https://tc39.es/ecma262/#sec-json.stringify) function. Additionally, in the JavaScript language binding, the `toJSON` operation can take a \[[`Default`](#Default)\] [extended attribute](#dfn-extended-attribute), in which case the [default toJSON steps](#default-tojson-steps) are exposed instead.

The following [IDL fragment](#dfn-idl-fragment) defines an interface `Transaction` that has a `toJSON` method defined in prose:

```
[Exposed=Window]
interface Transaction {
  readonly attribute DOMString from;
  readonly attribute DOMString to;
  readonly attribute double amount;
  readonly attribute DOMString description;
  readonly attribute unsigned long number;
  TransactionJSON toJSON();
};

dictionary TransactionJSON {
  Account from;
  Account to;
  double amount;
  DOMString description;
};
```

The `toJSON` [regular operation](#dfn-regular-operation) of `Transaction` [interface](#dfn-interface) could be defined as follows:

The `toJSON()` method steps are:

1. Let `json` be a new [map](https://infra.spec.whatwg.org/#ordered-map).

2. [For each](https://infra.spec.whatwg.org/#list-iterate) attribute [identifier](#dfn-identifier) `attr` in « "from", "to", "amount", "description" »:

   1. Let `value` be the result of running the [getter steps](#getter-steps) of `attr` on [this](#this).

   2. Set `json`\[`attr`\] to `value`.

3. Return `json`.

In the JavaScript language binding, there would exist a `toJSON()` method on `Transaction` objects:

```
// Get an instance of Transaction.
var txn = getTransaction();

// Evaluates to an object like this:
// {
//   from: "Bob",
//   to: "Alice",
//   amount: 50,
//   description: "books"
// }
txn.toJSON();

// Evaluates to a string like this:
// '{"from":"Bob","to":"Alice","amount":50,"description":"books"}'
JSON.stringify(txn);
```


#### Constructor operations

If an [interface](#dfn-interface) has a **constructor operation** member (matching [Constructor](#prod-Constructor)), it indicates that it is possible to create objects that [implement](#implements) the [interface](#dfn-interface) using a [constructor](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#constructor).

Multiple [constructor operations](#idl-constructors) may appear on a given [interface](#dfn-interface). For each [constructor operation](#idl-constructors) on the [interface](#dfn-interface), there will be a way to attempt to construct an instance by passing the specified arguments.

The **constructor steps** of a [constructor operation](#idl-constructors) that is a member of an interface named `interface` should be introduced using text of the form "The `new `interface`(`arg1`, `arg2`, ...)` constructor steps are:" followed by a list, or "The `new `interface`(`arg1`, `arg2`, ...)` constructor steps are to" followed by an inline description.

The [constructor steps](#constructor-steps) must do nothing, initialize the value passed as [this](#this), or throw an exception.

If the constructor does not initialize [this](#this), one can write "The `new Example(`init`)` constructor steps are to do nothing."

See [§ 3.7.1 Interface object](#interface-object) for details on how a [constructor operation](#idl-constructors) is to be implemented.

The following IDL defines two interfaces. The second has [constructor operations](#idl-constructors), while the first does not.

```
[Exposed=Window]
interface NodeList {
  Node item(unsigned long index);
  readonly attribute unsigned long length;
};

[Exposed=Window]
interface Circle {
  constructor();
  constructor(double radius);
  attribute double r;
  attribute double cx;
  attribute double cy;
  readonly attribute double circumference;
};
```

A JavaScript implementation supporting these interfaces would implement a \[\[Construct\]\] internal method on the `Circle` interface object which would return a new object that [implements](#implements) the interface. It would take either zero or one argument.

It is unclear whether the `NodeList` interface object would implement a \[\[Construct\]\] internal method. In any case, trying to use it as a constructor will cause a [`TypeError`](#exceptiondef-typeerror) to be thrown. [\[whatwg/webidl Issue #698\]](https://github.com/whatwg/webidl/issues/698)

```
var x = new Circle();      // This uses the zero-argument constructor to create a
                           // reference to a platform object that implements the
                           // Circle interface.

var y = new Circle(1.25);  // This also creates a Circle object, this time using
                           // the one-argument constructor.

var z = new NodeList();    // This would throw a TypeError, since no
                           // constructor is declared.
```

```
Constructor ::
    constructor ( ArgumentList ) ;
```


#### Stringifiers

When an [interface](#dfn-interface) has a **stringifier**, it indicates that objects that implement the interface have a non-default conversion to a string. Stringifiers can be specified using a stringifier keyword, which creates a stringifier operation when used alone.

```
interface interface_identifier {
  stringifier;
};
```

Prose accompanying the interface must define the **stringification behavior** of the interface.

The stringifier keyword can also be placed on an [attribute](#dfn-attribute). In this case, the string to convert the object to is the value of the attribute. The stringifier keyword must not be placed on an attribute unless it is declared to be of type [`DOMString`](#idl-DOMString) or [`USVString`](#idl-USVString). It also must not be placed on a [static attribute](#dfn-static-attribute).

```
interface interface_identifier {
  stringifier attribute DOMString identifier;
};
```

On a given [interface](#dfn-interface), there must exist at most one stringifier.

```
Stringifier ::
    stringifier StringifierRest
```

```
StringifierRest ::
    OptionalReadOnly AttributeRest
    ;
```

The following [IDL fragment](#dfn-idl-fragment) defines an interface that will stringify to the value of its `name` attribute:

```
[Exposed=Window]
interface Student {
  constructor();
  attribute unsigned long id;
  stringifier attribute DOMString name;
};
```

In the JavaScript binding, using a `Student` object in a context where a string is expected will result in the value of the object's `name` property being used:

```
var s = new Student();
s.id = 12345678;
s.name = '周杰倫';

var greeting = 'Hello, ' + s + '!';  // Now greeting == 'Hello, 周杰倫!'.
```

The following [IDL fragment](#dfn-idl-fragment) defines an interface that has custom stringification behavior that is not specified in the IDL itself.

```
[Exposed=Window]
interface Student {
  constructor();
  attribute unsigned long id;
  attribute DOMString? familyName;
  attribute DOMString givenName;

  stringifier;
};
```

Thus, there needs to be prose to explain the stringification behavior. We assume that the `familyName` and `givenName` attributes are backed by family name and given name concepts, respectively.

> The [stringification behavior](#dfn-stringification-behavior) steps are:
>
> 1. If [this](#this)'s family name is null, then return [this](#this)'s given name.
>
> 2. Return the concatenation of [this](#this)'s given name, followed by U+0020 SPACE, followed by [this](#this)'s family name.

A JavaScript implementation of the IDL would behave as follows:

```
var s = new Student();
s.id = 12345679;
s.familyName = 'Smithee';
s.givenName = 'Alan';

var greeting = 'Hi ' + s;  // Now greeting == 'Hi Alan Smithee'.
```


#### Special operations

A **special operation** is a declaration of a certain kind of special behavior on objects implementing the interface on which the special operation declarations appear. Special operations are declared by using a **special keyword** in an operation declaration.

There are three kinds of special operations. The table below indicates for a given kind of special operation what special keyword is used to declare it and what the purpose of the special operation is:

| Special operation | Keyword | Purpose                                                                     |
|-------------------|---------|-----------------------------------------------------------------------------|
| **Getters**       | getter  | Defines behavior for when an object is indexed for property retrieval.      |
| **Setters**       | setter  | Defines behavior for when an object is indexed for property assignment or creation. |
| **Deleters**      | deleter | Defines behavior for when an object is indexed for property deletion.       |

Not all language bindings support all of the four kinds of special object behavior. When special operations are declared using operations with no identifier, then in language bindings that do not support the particular kind of special operations there simply will not be such functionality.

The following IDL fragment defines an interface with a getter and a setter:

```
[Exposed=Window]
interface Dictionary {
  readonly attribute unsigned long propertyCount;

  getter double (DOMString propertyName);
  setter undefined (DOMString propertyName, double propertyValue);
};
```

In language bindings that do not support property getters and setters, objects implementing [Dictionary](#dfn-dictionary) will not have that special behavior.

Defining a special operation with an [identifier](#dfn-identifier) is equivalent to separating the special operation out into its own declaration without an identifier. This approach is allowed to simplify [method steps](#method-steps) of an interface's operations.

The following two interfaces are equivalent:

```
[Exposed=Window]
interface Dictionary {
  readonly attribute unsigned long propertyCount;

  getter double getProperty(DOMString propertyName);
  setter undefined setProperty(DOMString propertyName, double propertyValue);
};
```

```
[Exposed=Window]
interface Dictionary {
  readonly attribute unsigned long propertyCount;

  double getProperty(DOMString propertyName);
  undefined setProperty(DOMString propertyName, double propertyValue);

  getter double (DOMString propertyName);
  setter undefined (DOMString propertyName, double propertyValue);
};
```

A given [special keyword](#dfn-special-keyword) must not appear twice on an operation.

Getters and setters come in two varieties: ones that take a [`DOMString`](#idl-DOMString) as a property name, known as **named property getters** and **named property setters**, and ones that take an [`unsigned long`](#idl-unsigned-long) as a property index, known as **indexed property getters** and **indexed property setters**. There is only one variety of deleter: **named property deleters**. See [§ 2.5.6.1 Indexed properties](#idl-indexed-properties) and [§ 2.5.6.2 Named properties](#idl-named-properties) for details.

On a given [interface](#dfn-interface), there must exist at most one [named property deleter](#dfn-named-property-deleter), and at most one of each variety of getter and setter.

If an interface has a setter of a given variety, then it must also have a getter of that variety. If it has a [named property deleter](#dfn-named-property-deleter), then it must also have a [named property getter](#dfn-named-property-getter).

Special operations declared using operations must not be [variadic](#dfn-variadic) nor have any [optional arguments](#dfn-optional-argument).

If an object implements more than one [interface](#dfn-interface) that defines a given special operation, then it is undefined which (if any) special operation is invoked for that operation.


##### Indexed properties

An [interface](#dfn-interface) that defines an [indexed property getter](#dfn-indexed-property-getter) is said to **support indexed properties**. By extension, a [platform object](#dfn-platform-object) is said to [support indexed properties](#dfn-support-indexed-properties) if it implements an [interface](#dfn-interface) that itself does.

If an interface [supports indexed properties](#dfn-support-indexed-properties), then the interface definition must be accompanied by a description of what indices the object can be indexed with at any given time. These indices are called the **supported property indices**.

Interfaces that [support indexed properties](#dfn-support-indexed-properties) must define an [integer-typed](#dfn-integer-type) [attribute](#dfn-attribute) named "`length`".

Indexed property getters must be declared to take a single [`unsigned long`](#idl-unsigned-long) argument. Indexed property setters must be declared to take two arguments, where the first is an [`unsigned long`](#idl-unsigned-long).

```
interface interface_identifier {
  getter type identifier(unsigned long identifier);
  setter type identifier(unsigned long identifier, type identifier);

  getter type (unsigned long identifier);
  setter type (unsigned long identifier, type identifier);
};
```

The following requirements apply to the definitions of indexed property getters and setters:

- If an [indexed property getter](#dfn-indexed-property-getter) was specified using an [operation](#dfn-operation) with an [identifier](#dfn-identifier), then the value returned when indexing the object with a given [supported property index](#dfn-supported-property-indices) is the value that would be returned by invoking the operation, passing the index as its only argument. If the operation used to declare the indexed property getter did not have an identifier, then the interface definition must be accompanied by a description of how to **determine the value of an indexed property** for a given index.

- If an [indexed property setter](#dfn-indexed-property-setter) was specified using an operation with an identifier, then the behavior that occurs when indexing the object for property assignment with a given supported property index and value is the same as if the operation is invoked, passing the index as the first argument and the value as the second argument. If the operation used to declare the indexed property setter did not have an identifier, then the interface definition must be accompanied by a description of how to **set the value of an existing indexed property** and how to **set the value of a new indexed property** for a given property index and value.

Note that if an [indexed property getter](#dfn-indexed-property-getter) or [setter](#dfn-indexed-property-setter) is specified using an [operation](#dfn-operation) with an [identifier](#dfn-identifier), then indexing an object with an integer that is not a [supported property index](#dfn-supported-property-indices) does not necessarily elicit the same behavior as invoking the operation with that index. The actual behavior in this case is language binding specific.

In the JavaScript language binding, a regular property lookup is done. For example, take the following IDL:

```
[Exposed=Window]
interface A {
  getter DOMString toWord(unsigned long index);
};
```

Assume that an object implementing `A` has [supported property indices](#dfn-supported-property-indices) in the range 0 ≤ `index` \< 2. Also assume that toWord is defined to return its argument converted into an English word. The behavior when invoking the [operation](#dfn-operation) with an out of range index is different from indexing the object directly:

```
var a = getA();

a.toWord(0);  // Evalautes to "zero".
a[0];         // Also evaluates to "zero".

a.toWord(5);  // Evaluates to "five".
a[5];         // Evaluates to undefined, since there is no property "5".
```

The following [IDL fragment](#dfn-idl-fragment) defines an interface `OrderedMap` which allows retrieving and setting values by name or by index number:

```
[Exposed=Window]
interface OrderedMap {
  readonly attribute unsigned long size;

  getter any getByIndex(unsigned long index);
  setter undefined setByIndex(unsigned long index, any value);

  getter any get(DOMString name);
  setter undefined set(DOMString name, any value);
};
```

Since all of the special operations are declared using operations with identifiers, the only additional prose that is necessary is that which describes what keys those sets have. Assuming that the `get()` operation is defined to return null if an attempt is made to look up a non-existing entry in the `OrderedMap`, then the following two sentences would suffice:

> An object `map` implementing `OrderedMap` supports indexed properties with indices in the range 0 ≤ `index` \< `map.size`.
>
> Such objects also support a named property for every name that, if passed to `get()`, would return a non-null value.

As described in [§ 3.9 Legacy platform objects](#js-legacy-platform-objects), a JavaScript implementation would create properties on a [legacy platform object](#dfn-legacy-platform-object) implementing `OrderedMap` that correspond to entries in both the named and indexed property sets. These properties can then be used to interact with the object in the same way as invoking the object's methods, as demonstrated below:

```
// Assume map is a legacy platform object implementing the OrderedMap interface.
var map = getOrderedMap();
var x, y;

x = map[0];       // If map.length > 0, then this is equivalent to:
                  //
                  //   x = map.getByIndex(0)
                  //
                  // since a property named "0" will have been placed on map.
                  // Otherwise, x will be set to undefined, since there will be
                  // no property named "0" on map.

map[1] = false;   // This will do the equivalent of:
                  //
                  //   map.setByIndex(1, false)

y = map.apple;    // If there exists a named property named "apple", then this
                  // will be equivalent to:
                  //
                  //   y = map.get('apple')
                  //
                  // since a property named "apple" will have been placed on
                  // map.  Otherwise, y will be set to undefined, since there
                  // will be no property named "apple" on map.

map.berry = 123;  // This will do the equivalent of:
                  //
                  //   map.set('berry', 123)

delete map.cake;  // If a named property named "cake" exists, then the "cake"
                  // property will be deleted, and then the equivalent to the
                  // following will be performed:
                  //
                  //   map.remove("cake")
```


##### Named properties

An [interface](#dfn-interface) that defines a [named property getter](#dfn-named-property-getter) is said to **support named properties**. By extension, a [platform object](#dfn-platform-object) is said to [support named properties](#dfn-support-named-properties) if it implements an [interface](#dfn-interface) that itself does.

If an interface [supports named properties](#dfn-support-named-properties), then the interface definition must be accompanied by a description of the ordered set of names that can be used to index the object at any given time. These names are called the **supported property names**.

Named property getters and deleters must be declared to take a single [`DOMString`](#idl-DOMString) argument. Named property setters must be declared to take two arguments, where the first is a [`DOMString`](#idl-DOMString).

```
interface interface_identifier {
  getter type identifier(DOMString identifier);
  setter type identifier(DOMString identifier, type identifier);
  deleter type identifier(DOMString identifier);

  getter type (DOMString identifier);
  setter type (DOMString identifier, type identifier);
  deleter type (DOMString identifier);
};
```

The following requirements apply to the definitions of named property getters, setters and deleters:

- If a [named property getter](#dfn-named-property-getter) was specified using an [operation](#dfn-operation) with an [identifier](#dfn-identifier), then the value returned when indexing the object with a given [supported property name](#dfn-supported-property-names) is the value that would be returned by invoking the operation, passing the name as its only argument. If the operation used to declare the named property getter did not have an identifier, then the interface definition must be accompanied by a description of how to **determine the value of a named property** for a given property name.

- If a [named property setter](#dfn-named-property-setter) was specified using an operation with an identifier, then the behavior that occurs when indexing the object for property assignment with a given supported property name and value is the same as if the operation is invoked, passing the name as the first argument and the value as the second argument. If the operation used to declare the named property setter did not have an identifier, then the interface definition must be accompanied by a description of how to **set the value of an existing named property** and how to **set the value of a new named property** for a given property name and value.

- If a [named property deleter](#dfn-named-property-deleter) was specified using an operation with an identifier, then the behavior that occurs when indexing the object for property deletion with a given supported property name is the same as if the operation is invoked, passing the name as the only argument. If the operation used to declare the named property deleter did not have an identifier, then the interface definition must be accompanied by a description of how to **delete an existing named property** for a given property name.

As with [indexed properties](#idl-indexed-properties), if an [named property getter](#dfn-named-property-getter), [setter](#dfn-named-property-setter) or [deleter](#dfn-named-property-deleter) is specified using an [operation](#dfn-operation) with an [identifier](#dfn-identifier), then indexing an object with a name that is not a [supported property name](#dfn-supported-property-names) does not necessarily elicit the same behavior as invoking the operation with that name; the behavior is language binding specific.


#### Static attributes and operations

**Static attributes** and **static operations** are ones that are not associated with a particular instance of the [interface](#dfn-interface) on which it is declared, and is instead associated with the interface itself. Static attributes and operations are declared by using the static keyword in their declarations.

It is language binding specific whether it is possible to invoke a static operation or get or set a static attribute through a reference to an instance of the interface.

```
StaticMember ::
    static StaticMemberRest
```

```
StaticMemberRest ::
    OptionalReadOnly AttributeRest
    RegularOperation
```

The following [IDL fragment](#dfn-idl-fragment) defines an interface `Circle` that has a static operation declared on it:

```
[Exposed=Window]
interface Point { /* ... */ };

[Exposed=Window]
interface Circle {
  attribute double cx;
  attribute double cy;
  attribute double radius;

  static readonly attribute long triangulationCount;
  static Point triangulate(Circle c1, Circle c2, Circle c3);
};
```

In the JavaScript language binding, the [function object](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#function-object) for `triangulate` and the accessor property for `triangulationCount` will exist on the [interface object](#dfn-interface-object) for `Circle`:

```
var circles = getCircles();           // an Array of Circle objects

typeof Circle.triangulate;            // Evaluates to "function"
typeof Circle.triangulationCount;     // Evaluates to "number"
Circle.prototype.triangulate;         // Evaluates to undefined
Circle.prototype.triangulationCount;  // Also evaluates to undefined
circles[0].triangulate;               // As does this
circles[0].triangulationCount;        // And this

// Call the static operation
var triangulationPoint = Circle.triangulate(circles[0], circles[1], circles[2]);

// Find out how many triangulations we have done
window.alert(Circle.triangulationCount);
```


#### Overloading

If a [regular operation](#dfn-regular-operation) or [static operation](#dfn-static-operation) defined on an [interface](#dfn-interface) has an [identifier](#dfn-identifier) that is the same as the identifier of another operation on that interface of the same kind (regular or static), then the operation is said to be **overloaded**. When the identifier of an overloaded operation is used to invoke one of the operations on an object that implements the interface, the number and types of the arguments passed to the operation determine which of the overloaded operations is actually invoked. [Constructor operations](#idl-constructors) can be overloaded too. There are some restrictions on the arguments that overloaded operations and constructors can be specified to take, and in order to describe these restrictions, the notion of an *effective overload set* is used.

A set of overloaded [operations](#dfn-operation) must either:

- contain no [operations](#dfn-operation) whose [return type](#dfn-return-type) is a [promise type](#dfn-promise-type);

- only contain [operations](#dfn-operation) whose [return type](#dfn-return-type) is a [promise type](#dfn-promise-type).

[Operations](#dfn-operation) must not be overloaded across [interface](#dfn-interface), [partial interface](#dfn-partial-interface), [interface mixin](#interface-mixin), and [partial interface mixin](#partial-interface-mixin) definitions.

For example, the overloads for both `f` and `g` are disallowed:

```
[Exposed=Window]
interface A {
  undefined f();
};

partial interface A {
  undefined f(double x);
  undefined g();
};

partial interface A {
  undefined g(DOMString x);
};
```

Note that [constructor operations](#idl-constructors) and \[[`LegacyFactoryFunction`](#LegacyFactoryFunction)\] [extended attributes](#dfn-extended-attribute) are disallowed from appearing on [partial interface](#dfn-partial-interface) definitions, so there is no need to also disallow overloading for constructors.

An **effective overload set** represents the allowable invocations for a particular [operation](#dfn-operation), constructor (specified with a [constructor operation](#idl-constructors) or \[[`LegacyFactoryFunction`](#LegacyFactoryFunction)\]), or [callback function](#dfn-callback-function). The algorithm to [compute the effective overload set](#compute-the-effective-overload-set) operates on one of the following four types of IDL constructs, and listed with them below are the inputs to the algorithm needed to compute the set.

For regular operations  
For static operations

: - the [interface](#dfn-interface) on which the [operations](#dfn-operation) are to be found

  - the [identifier](#dfn-identifier) of the operations

  - the number of arguments to be passed

For constructors

: - the [interface](#dfn-interface) on which the [constructor operations](#idl-constructors) are to be found

  - the number of arguments to be passed

For legacy factory functions

: - the [interface](#dfn-interface) on which the \[[`LegacyFactoryFunction`](#LegacyFactoryFunction)\] [extended attributes](#dfn-extended-attribute) are to be found

  - the [identifier](#dfn-identifier) of the legacy factory function

  - the number of arguments to be passed

An [effective overload set](#dfn-effective-overload-set) is used, among other things, to determine whether there are ambiguities in the overloaded operations and constructors specified on an interface.

The [items](https://infra.spec.whatwg.org/#list-item) of an [effective overload set](#dfn-effective-overload-set) are [tuples](https://infra.spec.whatwg.org/#tuple) of the form ([callable](#effective-overload-set-tuple-callable), [type list](#type-list), [optionality list](#optionality-list)) whose [items](https://infra.spec.whatwg.org/#struct-item) are described below:

- A **callable** is an [operation](#dfn-operation) if the [effective overload set](#dfn-effective-overload-set) is for [regular operations](#dfn-regular-operation), [static operations](#dfn-static-operation), or [constructor operations](#idl-constructors); and it is an [extended attribute](#dfn-extended-attribute) if the [effective overload set](#dfn-effective-overload-set) is for [legacy factory functions](#dfn-legacy-factory-function).

- A **type list** is a [list](https://infra.spec.whatwg.org/#list) of IDL types.

- An **optionality list** is a [list](https://infra.spec.whatwg.org/#list) of three possible **optionality values** -- "required", "optional" or "variadic" -- indicating whether the argument at a given index was declared as being [optional](#dfn-optional-argument) or corresponds to a [variadic](#dfn-variadic) argument.

Each [tuple](https://infra.spec.whatwg.org/#tuple) represents an allowable invocation of the operation, constructor, or callback function with an argument value list of the given types. Due to the use of [optional arguments](#dfn-optional-argument) and [variadic](#dfn-variadic) operations and constructors, there may be multiple items in an [effective overload set](#dfn-effective-overload-set) identifying the same operation or constructor.

The algorithm below describes how to **compute the effective overload set**. The following input variables are used, if they are required:

- the identifier of the operation or legacy factory function is `A`

- the argument count is `N`

- the interface is `I`

Whenever an argument of an extended attribute is mentioned, it is referring to an argument of the extended attribute's [named argument list](#dfn-xattr-named-argument-list).

1. Let `S` be an [ordered set](https://infra.spec.whatwg.org/#ordered-set).

2. Let `F` be an [ordered set](https://infra.spec.whatwg.org/#ordered-set) with [items](https://infra.spec.whatwg.org/#list-item) as follows, according to the kind of [effective overload set](#dfn-effective-overload-set):

   For regular operations

   : The elements of `F` are the [regular operations](#dfn-regular-operation) with identifier `A` defined on interface `I`.

   For static operations

   : The elements of `F` are the [static operations](#dfn-static-operation) with identifier `A` defined on interface `I`.

   For constructors

   : The elements of `F` are the [constructor operations](#idl-constructors) on interface `I`.

   For legacy factory functions

   : The elements of `F` are the \[[`LegacyFactoryFunction`](#LegacyFactoryFunction)\] [extended attributes](#dfn-extended-attribute) on interface `I` whose [named argument lists'](#dfn-xattr-named-argument-list) identifiers are `A`.

3. Let `maxarg` be the maximum number of arguments the operations, legacy factory functions, or callback functions in `F` are declared to take. For [variadic](#dfn-variadic) operations and legacy factory functions, the argument on which the ellipsis appears counts as a single argument.

   So `undefined f(long x, long... y);` is considered to be declared to take two arguments.

4. Let `max` be [max](https://tc39.es/ecma262/#eqn-max)(`maxarg`, `N`).

5. [For each](https://infra.spec.whatwg.org/#list-iterate) operation or extended attribute `X` in `F`:

   1. Let `arguments` be the [list](https://infra.spec.whatwg.org/#list) of arguments `X` is declared to take.

   2. Let `n` be the [size](https://infra.spec.whatwg.org/#list-size) of `arguments`.

   3. Let `types` be a [type list](#type-list).

   4. Let `optionalityValues` be an [optionality list](#optionality-list).

   5. [For each](https://infra.spec.whatwg.org/#list-iterate) `argument` in `arguments`:

      1. [Append](https://infra.spec.whatwg.org/#list-append) the type of `argument` to `types`.

      2. [Append](https://infra.spec.whatwg.org/#list-append) "variadic" to `optionalityValues` if `argument` is a final, variadic argument, "optional" if `argument` is [optional](#dfn-optional-argument), and "required" otherwise.

   6. [Append](https://infra.spec.whatwg.org/#set-append) the [tuple](https://infra.spec.whatwg.org/#tuple) (`X`, `types`, `optionalityValues`) to `S`.

   7. If `X` is declared to be [variadic](#dfn-variadic), then:

      1. [For each](https://infra.spec.whatwg.org/#list-iterate) `i` in [the range](https://infra.spec.whatwg.org/#the-range) `n` to `max` − 1, inclusive:

         1. Let `t` be a [type list](#type-list).

         2. Let `o` be an [optionality list](#optionality-list).

         3. [For each](https://infra.spec.whatwg.org/#list-iterate) `j` in [the range](https://infra.spec.whatwg.org/#the-range) 0 to `n` − 1, inclusive:

            1. [Append](https://infra.spec.whatwg.org/#list-append) `types`\[`j`\] to `t`.

            2. [Append](https://infra.spec.whatwg.org/#list-append) `optionalityValues`\[`j`\] to `o`.

         4. [For each](https://infra.spec.whatwg.org/#list-iterate) `j` in [the range](https://infra.spec.whatwg.org/#the-range) `n` to `i`, inclusive:

            1. [Append](https://infra.spec.whatwg.org/#list-append) `types`\[`n` − 1\] to `t`.

            2. [Append](https://infra.spec.whatwg.org/#list-append) "variadic" to `o`.

         5. [Append](https://infra.spec.whatwg.org/#set-append) the [tuple](https://infra.spec.whatwg.org/#tuple) (`X`, `t`, `o`) to `S`.

   8. Let `i` be `n` − 1.

   9. [While](https://infra.spec.whatwg.org/#iteration-while) `i` ≥ 0:

      1. If `arguments`\[`i`\] is not [optional](#dfn-optional-argument) (i.e., it is not marked as "optional" and is not a final, variadic argument), then [break](https://infra.spec.whatwg.org/#iteration-break).

      2. Let `t` be a [type list](#type-list).

      3. Let `o` be an [optionality list](#optionality-list).

      4. [For each](https://infra.spec.whatwg.org/#list-iterate) `j` in [the range](https://infra.spec.whatwg.org/#the-range) 0 to `i` − 1, inclusive:

         1. [Append](https://infra.spec.whatwg.org/#list-append) `types`\[`j`\] to `t`.

         2. [Append](https://infra.spec.whatwg.org/#list-append) `optionalityValues`\[`j`\] to `o`.

      5. [Append](https://infra.spec.whatwg.org/#set-append) the [tuple](https://infra.spec.whatwg.org/#tuple) (`X`, `t`, `o`) to `S`.

         if `i` is 0, this means to add to `S` the tuple (`X`, « », « »); (where "« »" represents an [empty list](https://infra.spec.whatwg.org/#list-is-empty)).

      6. Set `i` to `i` − 1.

6. Return `S`.

For the following interface:

```
[Exposed=Window]
interface A {
  /* f1 */ undefined f(DOMString a);
  /* f2 */ undefined f(Node a, DOMString b, double... c);
  /* f3 */ undefined f();
  /* f4 */ undefined f(Event a, DOMString b, optional DOMString c, double... d);
};
```

assuming `Node` and `Event` are two other interfaces of which no object can implement both, the [effective overload set](#dfn-effective-overload-set) for [regular operations](#dfn-regular-operation) with identifier `f` and argument count 4 is:

```
«
  (f1, « DOMString »,                           « required »),
  (f2, « Node, DOMString »,                     « required, required »),
  (f2, « Node, DOMString, double »,             « required, required, variadic »),
  (f2, « Node, DOMString, double, double »,     « required, required, variadic, variadic »),
  (f3, « »,                                     « »),
  (f4, « Event, DOMString »,                    « required, required »),
  (f4, « Event, DOMString, DOMString »,         « required, required, optional »),
  (f4, « Event, DOMString, DOMString, double », « required, required, optional, variadic »)
»
```

Two types are **distinguishable** if the following algorithm returns *true*.

1. If one type [includes a nullable type](#dfn-includes-a-nullable-type) and the other type either [includes a nullable type](#dfn-includes-a-nullable-type), is a [union type](#dfn-union-type) with [flattened member types](#dfn-flattened-union-member-types) including a [dictionary type](#idl-dictionary), or is a [dictionary type](#idl-dictionary), return *false*.

   None of the following pairs are distinguishable:
   - [`double`](#idl-double)`?` and `Dictionary1`
   - `(Interface1 or `[`long`](#idl-long)`)?` and `(Interface2 or `[`DOMString`](#idl-DOMString)`)?`
   - `(Interface1 or `[`long`](#idl-long)`?)` and `(Interface2 or `[`DOMString`](#idl-DOMString)`)?`
   - `(Interface1 or `[`long`](#idl-long)`?)` and `(Interface2 or `[`DOMString`](#idl-DOMString)`?)`
   - `(Dictionary1 or `[`long`](#idl-long)`)` and `(Interface2 or `[`DOMString`](#idl-DOMString)`)?`
   - `(Dictionary1 or `[`long`](#idl-long)`)` and `(Interface2 or `[`DOMString`](#idl-DOMString)`?)`

2. If both types are either a [union type](#dfn-union-type) or [nullable](#dfn-nullable-type) [union type](#dfn-union-type), return *true* if each member type of the one is distinguishable with each member type of the other, or *false* otherwise.

3. If one type is a [union type](#dfn-union-type) or nullable union type, return *true* if each [member type](#dfn-union-member-type) of the union type is distinguishable with the non-union type, or *false* otherwise.

4. Consider the two "innermost" types derived by taking each type's [inner type](#annotated-types-inner-type) if it is an [annotated type](#annotated-types), and then taking its [inner type](#dfn-inner-type) inner type if the result is a [nullable type](#dfn-nullable-type). If these two innermost types appear or are in categories appearing in the following table and there is a "●" mark in the corresponding entry or there is a letter in the corresponding entry and the designated additional requirement below the table is satisfied, then return *true*. Otherwise return *false*.

   Categories:

   interface-like

   : - [interface types](#idl-interface)

     - [buffer source types](#dfn-buffer-source-type)

   dictionary-like

   : - [dictionary types](#idl-dictionary)

     - [record types](#record-type)

     - [callback interface types](#idl-callback-interface)

   sequence-like

   : - [sequence types](#sequence-type)

     - [frozen array types](#dfn-frozen-array-type)

   | | undefined | boolean | numeric types | bigint | string types | object | symbol | interface-like | callback function | dictionary-like | async sequence | sequence-like |
   |---|---|---|---|---|---|---|---|---|---|---|---|---|
   | undefined | | ● | ● | ● | ● | ● | ● | ● | ● | | ● | ● |
   | boolean | | | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● |
   | numeric types | | | | (b) | ● | ● | ● | ● | ● | ● | ● | ● |
   | bigint | | | | | ● | ● | ● | ● | ● | ● | ● | ● |
   | string types | | | | | | ● | ● | ● | ● | ● | (d) | ● |
   | object | | | | | | | ● | | | | | |
   | symbol | | | | | | | | ● | ● | ● | ● | ● |
   | interface-like | | | | | | | | (a) | ● | ● | ● | ● |
   | callback function | | | | | | | | | | (c) | ● | ● |
   | dictionary-like | | | | | | | | | | | ● | ● |
   | async sequence | | | | | | | | | | | | |
   | sequence-like | | | | | | | | | | | | |

   a. The two identified interface-like types are not the same, and no single [platform object](#dfn-platform-object) implements both interface-like types.

   b. The types are distinguishable, but there is [a separate restriction on their use in overloading](#limit-bigint-numeric-overloading) below. Please also note [the advice about using unions of these types](#limit-bigint-numeric-unions).

   c. A [callback function](#dfn-callback-function) that does not have \[[`LegacyTreatNonObjectAsNull`](#LegacyTreatNonObjectAsNull)\] extended attribute is distinguishable from a type in the dictionary-like category.

      For example, when converting an ECMAScript value to [union type](#dfn-union-type) which includes a [callback function](#dfn-callback-function) and a dictionary-like type, if the value is [callable](https://tc39.es/ecma262/#sec-iscallable), then it is converted to a [callback function](#dfn-callback-function). Otherwise, it is converted to a dictionary-like type.

   d. The types are distinguishable, but when converting from an ECMAScript value, a [string object](https://tc39.es/ecma262/#sec-string-objects) is never converted to an [async sequence type](#async-sequence-type) (even if it has a [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) method), if a [string type](#dfn-string-type) is also in the overload set or union.

   [`double`](#idl-double) and [`DOMString`](#idl-DOMString) are distinguishable because there is a ● at the intersection of [numeric types](#dfn-numeric-type) with [string types](#dfn-string-type).

   [`double`](#idl-double) and [`long`](#idl-long) are not distinguishable because they are both [numeric types](#dfn-numeric-type), and there is no ● or letter at the intersection of [numeric types](#dfn-numeric-type) with [numeric types](#dfn-numeric-type).

   Given:
   ```
   callback interface CBIface {
       undefined handle();
   };

   [Exposed=Window]
   interface Iface {
       attribute DOMString attr2;
   };

   dictionary Dict {
       DOMString field1;
   };
   ```

   `CBIface` is distinguishable from `Iface` because there's a ● at the intersection of dictionary-like and interface-like, but it is not distinguishable from `Dict` because there's no ● at the intersection of dictionary-like and itself.

   [Promise types](#dfn-promise-type) do not appear in the above table, and as a consequence are not distinguishable with any other type.

If there is more than one [item](https://infra.spec.whatwg.org/#list-item) in an [effective overload set](#dfn-effective-overload-set) that has a given [type list](#type-list) [size](https://infra.spec.whatwg.org/#list-size), then for those items there must be an index `i` such that for each pair of items the types at index `i` are [distinguishable](#dfn-distinguishable). The lowest such index is termed the **distinguishing argument index** for the items of the [effective overload set](#dfn-effective-overload-set) with the given type list size.

An [effective overload set](#dfn-effective-overload-set) must not contain more than one [item](https://infra.spec.whatwg.org/#list-item) with the same [type list](#type-list) [size](https://infra.spec.whatwg.org/#list-size), where one [item](https://infra.spec.whatwg.org/#list-item) has a [`bigint`](#idl-bigint) argument at the [distinguishing argument index](#dfn-distinguishing-argument-index) and another has a [numeric type](#dfn-numeric-type) argument at the [distinguishing argument index](#dfn-distinguishing-argument-index).

Consider the [effective overload set](#dfn-effective-overload-set) shown in the previous example. There are multiple items in the set with type lists 2, 3 and 4. For each of these type list size, the [distinguishing argument index](#dfn-distinguishing-argument-index) is 0, since `Node` and `Event` are [distinguishable](#dfn-distinguishable).

The following use of overloading however is invalid:

```
[Exposed=Window]
interface B {
  undefined f(DOMString x);
  undefined f(USVString x);
};
```

since [`DOMString`](#idl-DOMString) and [`USVString`](#idl-USVString) are not distinguishable.

In addition, for each index `j`, where `j` is less than the [distinguishing argument index](#dfn-distinguishing-argument-index) for a given type list size, the types at index `j` in all of the items' type lists must be the same, and the [optionality values](#dfn-optionality-value) at index `j` in all of the items' optionality lists must be the same.

The following is invalid:

```
[Exposed=Window]
interface B {
  /* f1 */ undefined f(DOMString w);
  /* f2 */ undefined f(long w, double x, Node y, Node z);
  /* f3 */ undefined f(double w, double x, DOMString y, Node z);
};
```

For argument count 4, the [effective overload set](#dfn-effective-overload-set) is:

```
«
  (f1, « DOMString »,                       « required »),
  (f2, « long, double, Node, Node »,        « required, required, required, required »),
  (f3, « double, double, DOMString, Node », « required, required, required, required »)
»
```

Looking at items with type list size 4, the [distinguishing argument index](#dfn-distinguishing-argument-index) is 2, since `Node` and [`DOMString`](#idl-DOMString) are [distinguishable](#dfn-distinguishable). However, since the arguments in these two overloads at index 0 are different, the overloading is invalid.


##### Overloading vs. union types

*This section is informative.*

For specifications defining IDL [operations](#dfn-operation), it might seem that [overloads](#dfn-overloaded) and a combination of [union types](#dfn-union-type) and [optional arguments](#dfn-optional-argument) have some feature overlap.

It is first important to note that [overloads](#dfn-overloaded) have different behaviors than [union types](#dfn-union-type) or [optional arguments](#dfn-optional-argument), and one *cannot* be fully defined using the other (unless, of course, additional prose is provided, which can defeat the purpose of the Web IDL type system). For example, consider the [`stroke()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-stroke) operations defined on the [`CanvasDrawPath`](https://html.spec.whatwg.org/multipage/canvas.html#canvasdrawpath) interface [\[HTML\]](#biblio-html):

```
interface CanvasDrawPathExcerpt {
  undefined stroke();
  undefined stroke(Path2D path);
};
```

Per the JavaScript language binding, calling `stroke(undefined)` on an object implementing `CanvasDrawPathExcerpt` would attempt to call the second overload, yielding a [`TypeError`](#exceptiondef-typeerror) since undefined cannot be [converted](#js-to-interface) to a [`Path2D`](https://html.spec.whatwg.org/multipage/canvas.html#path2d). However, if the operations were instead defined with [optional arguments](#dfn-optional-argument) and merged into one,

```
interface CanvasDrawPathExcerptOptional {
  undefined stroke(optional Path2D path);
};
```

the [overload resolution algorithm](#dfn-overload-resolution-algorithm) would treat the `path` argument as missing given the same call `stroke(undefined)`, and not throw any exceptions.

For this particular example, the latter behavior is actually what Web developers would generally expect. If [`CanvasDrawPath`](https://html.spec.whatwg.org/multipage/canvas.html#canvasdrawpath) were to be designed today, [optional arguments](#dfn-optional-argument) would be used for `stroke()`.

Additionally, there are semantic differences as well. [Union types](#dfn-union-type) are usually used in the sense that "any of the types would work in about the same way". In contrast, [overloaded](#dfn-overloaded) operations are designed to map well to language features such as C++ overloading, and are usually a better fit for operations with more substantial differences in what they do given arguments of different types. However, in most cases, operations with such substantial differences are best off with different names to avoid confusion for Web developers, since the JavaScript language does not provide language-level overloading. As such, overloads are rarely appropriate for new APIs, instead often appearing in legacy APIs or in specialized circumstances.

That being said, we offer the following recommendations and examples in case of difficulties to determine what Web IDL language feature to use:

- In the unusual case where the operation needs to return values of different types for different argument types, [overloading](#dfn-overloaded) will result in more expressive IDL fragments. This is almost never appropriate API design, and separate operations with distinct names usually are a better choice for such cases.

  Suppose there is an operation `calculate()` that accepts a [`long`](#idl-long), [`DOMString`](#idl-DOMString), or `CalculatableInterface` (an [interface type](#idl-interface)) as its only argument, and returns a value of the same type as its argument. It would be clearer to write the IDL fragment using [overloaded](#dfn-overloaded) operations as

  ```
  interface A {
    long calculate(long input);
    DOMString calculate(DOMString input);
    CalculatableInterface calculate(CalculatableInterface input);
  };
  ```

  than using a [union type](#dfn-union-type) with a [typedef](#dfn-typedef) as

  ```
  typedef (long or DOMString or CalculatableInterface) Calculatable;
  interface A {
    Calculatable calculate(Calculatable input);
  };
  ```

  which does not convey the fact that the return value is always of the same type as `input`.

  If the specified `calculate()` is a new API and does not have any compatibility concerns, it is suggested to use different names for the overloaded operations, perhaps as

  ```
  interface A {
    long calculateNumber(long input);
    DOMString calculateString(DOMString input);
    CalculatableInterface calculateCalculatableInterface(CalculatableInterface input);
  };
  ```

  which allows Web developers to write explicit and unambiguous code.

- When the operation has significantly different semantics for different argument types or lengths, [overloading](#dfn-overloaded) is preferred. Again, in such scenarios, it is usually better to create separate operations with distinct names, but legacy APIs sometimes follow this pattern.

  As an example, the [`supports(property, value)`](https://drafts.csswg.org/css-conditional-3/#dom-css-supports) and [`supports(conditionText)`](https://drafts.csswg.org/css-conditional-3/#dom-css-supports-conditiontext) operations of the [`CSS`](https://drafts.csswg.org/cssom-1/#namespacedef-css) interface are defined as the following IDL fragment [\[CSS3-CONDITIONAL\]](#biblio-css3-conditional) [\[CSSOM\]](#biblio-cssom).

  ```
  partial interface CSS {
    static boolean supports(CSSOMString property, CSSOMString value);
    static boolean supports(CSSOMString conditionText);
  };
  ```

  Using [optional arguments](#dfn-optional-argument) one can rewrite the IDL fragment as follows:

  ```
  partial interface CSSExcerptOptional {
    static boolean supports(CSSOMString propertyOrConditionText, optional CSSOMString value);
  };
  ```

  Even though the IDL is shorter in the second version, two distinctively different concepts are conflated in the first argument. Without [overloads](#dfn-overloaded), the question "is `property` or `conditionText` paired with `value`?" is much more difficult to answer without reading the [method steps](#method-steps) of the operation. This makes the second version remarkably less readable than the first.

  Another consideration is that the [method steps](#method-steps) for [overloaded](#dfn-overloaded) operations can be specified in separate blocks, which can aid in both reading and writing specifications. This is not the case for [optional arguments](#dfn-optional-argument). This means that in the first case the specification author can write the [method steps](#method-steps) of the operations as:

  The `supports(``property`, `value`)` method steps are:

  1. ...

  ---

  The `supports(``conditionText`)` method steps are:

  1. ...

  Yet using `value` as an [optional argument](#dfn-optional-argument), the specification author has to use more boilerplate-style text to effectively replicate the [overload resolution algorithm](#dfn-overload-resolution-algorithm).

  The `supports(``propertyOrConditionText`, `value`)` method steps are:

  1. If `value` is given, then:

     1. Let `property` be `propertyOrConditionText`.

     2. ...

  2. Otherwise:

     1. Let `conditionText` be `propertyOrConditionText`.

     2. ...

  If the two overloads have little to no shared parts, it is better to leave overload resolution to the IDL mechanism.

- If the operation accepts multiple types for multiple arguments with no coupling between types of different arguments, [union types](#dfn-union-type) can sometimes be the only viable solution.

  ```
  typedef (long long or DOMString or CalculatableInterface) SupportedArgument;
  interface A {
    undefined add(SupportedArgument operand1, SupportedArgument operand2);
  };
  ```

  For the `add()` operation above, to specify it using [overloads](#dfn-overloaded) would require

  ```
  interface A {
    undefined add(long long operand1, long long operand2);
    undefined add(long long operand1, DOMString operand2);
    undefined add(long long operand1, CalculatableInterface operand2);
    undefined add(DOMString operand1, long long operand2);
    undefined add(DOMString operand1, DOMString operand2);
    undefined add(DOMString operand1, CalculatableInterface operand2);
    undefined add(CalculatableInterface operand1, long long operand2);
    undefined add(CalculatableInterface operand1, DOMString operand2);
    undefined add(CalculatableInterface operand1, CalculatableInterface operand2);
  };
  ```

  and nine times the corresponding prose!

- Specification authors are encouraged to treat missing argument and undefined argument the same way in the JavaScript language binding.

  Given the following IDL fragment:

  ```
  interface A {
    undefined foo();
    undefined foo(Node? arg);
  };
  ```

  Using the JavaScript language binding, calling `foo(undefined)` and `foo(null)` would both run the steps corresponding to the `foo(``arg`)` operation, with `arg` set to null, while `foo()` alone would go to the first overload. This can be a surprising behavior for many API users. Instead, specification authors are encouraged to use an [optional argument](#dfn-optional-argument), which would categorize both `foo()` and `foo(undefined)` as "`arg` is missing".

  ```
  interface A {
    undefined foo(optional Node? arg);
  };
  ```

  In general, optionality is best expressed using the optional keyword, and not using overloads.

When the case fits none of the categories above, it is up to the specification author to choose the style, since it is most likely that either style would sufficiently and conveniently describe the intended behavior. However, the definition and [conversion algorithms](#js-to-union) of [union types](#dfn-union-type) and [optional arguments](#dfn-optional-argument) are simpler to implement and reason about than [those](#dfn-overload-resolution-algorithm) of [overloads](#dfn-overloaded), and usually result in more idiomatic APIs in the JavaScript language binding. Thus, unless any other considerations apply, [union types](#dfn-union-type), [optional arguments](#dfn-optional-argument), or both are the default choice.

Specifications are also free to mix and match union types and overloads, if the author finds it appropriate and convenient.


#### Iterable declarations

An [interface](#dfn-interface) can be declared to be **iterable** by using an **iterable declaration** (matching [Iterable](#prod-Iterable)) in the body of the interface.

```
interface interface_identifier {
  iterable<value_type>;
  iterable<key_type, value_type>;
};
```

Objects implementing an interface that is declared to be iterable support being iterated over to obtain a sequence of values.

In the JavaScript language binding, an interface that is iterable will have `entries`, `forEach`, `keys`, `values`, and [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) properties on its [interface prototype object](#dfn-interface-prototype-object).

If a single type parameter is given, then the interface has a **value iterator** and provides values of the specified type. If two type parameters are given, then the interface has a **pair iterator** and provides [value pairs](#value-pair) with the given types.

A **value pair**, given a key type and a value type, is a [struct](https://infra.spec.whatwg.org/#struct) with two [items](https://infra.spec.whatwg.org/#struct-item):

1. an [item](https://infra.spec.whatwg.org/#struct-item) whose [name](https://infra.spec.whatwg.org/#struct-name) is "key", which is referred to as the [value pair](#value-pair)'s **key**, and whose value is an IDL value of the key type;

2. an [item](https://infra.spec.whatwg.org/#struct-item) whose [name](https://infra.spec.whatwg.org/#struct-name) is "value", which is referred to as the [value pair](#value-pair)'s **value**, and whose value is an IDL value of the value type.

A [value iterator](#dfn-value-iterator) must only be declared on an interface that [supports indexed properties](#dfn-support-indexed-properties). The value-type of the [value iterator](#dfn-value-iterator) must be the same as the type returned by the [indexed property getter](#dfn-indexed-property-getter). A [value iterator](#dfn-value-iterator) is implicitly defined to iterate over the object's indexed properties.

A [pair iterator](#dfn-pair-iterator) must not be declared on an interface that [supports indexed properties](#dfn-support-indexed-properties).

Prose accompanying an [interface](#dfn-interface) with a [pair iterator](#dfn-pair-iterator) must define a [list](https://infra.spec.whatwg.org/#list) of [value pairs](#value-pair) for each instance of the [interface](#dfn-interface), which is the list of **value pairs to iterate over**.

The JavaScript forEach method that is generated for a [value iterator](#dfn-value-iterator) invokes its callback like Array.prototype.forEach does, and the forEach method for a [pair iterator](#dfn-pair-iterator) invokes its callback like Map.prototype.forEach does.

Since [value iterators](#dfn-value-iterator) are currently allowed only on interfaces that [support indexed properties](#dfn-support-indexed-properties), it makes sense to use an Array-like forEach method. There could be a need for [value iterators](#dfn-value-iterator) (a) on interfaces that do not [support indexed properties](#dfn-support-indexed-properties), or (b) with a forEach method that instead invokes its callback like Set.prototype.forEach (where the key is the same as the value). If you're creating an API that needs such a forEach method, please [file an issue](https://github.com/whatwg/webidl/issues/new?title=Enhancement%20request%20for%20Iterables).

This is how [array iterator objects](https://tc39.es/ecma262/#sec-array-iterator-objects) work. For interfaces that [support indexed properties](#dfn-support-indexed-properties), the iterator objects returned by `entries`, `keys`, `values`, and [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) are actual [array iterator objects](https://tc39.es/ecma262/#sec-array-iterator-objects).

[Interfaces](#dfn-interface) with an [iterable declaration](#dfn-iterable-declaration) must not have any [attributes](#dfn-attribute), [constants](#dfn-constant), or [regular operations](#dfn-regular-operation) named "`entries`", "`forEach`", "`keys`", or "`values`", or have any [inherited interfaces](#dfn-inherited-interfaces) that have [attributes](#dfn-attribute), [constants](#dfn-constant), or [regular operations](#dfn-regular-operation) with these names.

Consider the following interface `SessionManager`, which allows access to a number of `Session` objects keyed by username:

```
[Exposed=Window]
interface SessionManager {
  Session getSessionForUser(DOMString username);

  iterable<DOMString, Session>;
};

[Exposed=Window]
interface Session {
  readonly attribute DOMString username;
  // ...
};
```

The behavior of the iterator could be defined like so:

> The [value pairs to iterate over](#dfn-value-pairs-to-iterate-over) are the list of [value pairs](#value-pair) with the [key](#value-pair-key) being the username and the [value](#value-pair-value) being the open `Session` object on the `SessionManager` object corresponding to that username, sorted by username.

In the JavaScript language binding, the [interface prototype object](#dfn-interface-prototype-object) for the `SessionManager` [interface](#dfn-interface) has a `values` method that is a function, which, when invoked, returns an iterator object that itself has a `next` method that returns the next value to be iterated over. It has `keys` and `entries` methods that iterate over the usernames of session objects and username/`Session` object pairs, respectively. It also has a [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) method that allows a `SessionManager` to be used in a `for..of` loop that has the same value as the `entries` method:

```
// Get an instance of SessionManager.
// Assume that it has sessions for two users, "anna" and "brian".
var sm = getSessionManager();

typeof SessionManager.prototype.values;            // Evaluates to "function"
var it = sm.values();                              // values() returns an iterator object
String(it);                                        // Evaluates to "[object SessionManager Iterator]"
typeof it.next;                                    // Evaluates to "function"

// This loop will log "anna" and then "brian".
for (;;) {
  let result = it.next();
  if (result.done) {
    break;
  }
  let session = result.value;
  console.log(session.username);
}

// This loop will also log "anna" and then "brian".
for (let username of sm.keys()) {
  console.log(username);
}

// Yet another way of accomplishing the same.
for (let [username, session] of sm) {
  console.log(username);
}
```

An interface must not have more than one [iterable declaration](#dfn-iterable-declaration). The [inherited interfaces](#dfn-inherited-interfaces) of an interface with an [iterable declaration](#dfn-iterable-declaration) must not also have an [iterable declaration](#dfn-iterable-declaration). An interface with an [iterable declaration](#dfn-iterable-declaration) and its [inherited interfaces](#dfn-inherited-interfaces) must not have a [maplike declaration](#dfn-maplike-declaration), [setlike declaration](#dfn-setlike-declaration), or [asynchronously iterable declaration](#dfn-async-iterable-declaration).

The following extended attributes are applicable to [iterable declarations](#dfn-iterable-declaration): \[[`CrossOriginIsolated`](#CrossOriginIsolated)\], \[[`Exposed`](#Exposed)\], and \[[`SecureContext`](#SecureContext)\].

```
Iterable ::
    iterable < TypeWithExtendedAttributes OptionalType > ;
```

```
OptionalType ::
    , TypeWithExtendedAttributes
    ε
```


#### Asynchronously iterable declarations

An [interface](#dfn-interface) can be declared to be asynchronously iterable by using an **asynchronously iterable declaration** (matching [AsyncIterable](#prod-AsyncIterable)) in the body of the [interface](#dfn-interface).

```
interface interface_identifier {
  async_iterable<value_type>;
  async_iterable<value_type>(/* arguments... */);
  async_iterable<key_type, value_type>;
  async_iterable<key_type, value_type>(/* arguments... */);
};
```

Objects that [implement](#implements) an [interface](#dfn-interface) that is declared to be asynchronously iterable support being iterated over asynchronously to obtain a sequence of values.

If a single type parameter is given, then the interface has a **value asynchronously iterable declaration** and asynchronously provides values of the specified type. If two type parameters are given, then the interface has a **pair asynchronously iterable declaration** and asynchronously provides [value pairs](#value-pair) with the given types.

If given, an [asynchronously iterable declaration](#dfn-async-iterable-declaration)'s arguments (matching [ArgumentList](#prod-ArgumentList)) must all be [optional arguments](#dfn-optional-argument).

In the JavaScript language binding, an interface that is asynchronously iterable will have [`%Symbol.asyncIterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) and `values` properties on its [interface prototype object](#dfn-interface-prototype-object). If the interface has a [pair asynchronously iterable declaration](#pair-asynchronously-iterable-declaration), it will additionally have `entries` and `keys` properties. All of these methods can be passed optional arguments, which correspond to the argument list in the [asynchronously iterable declaration](#dfn-async-iterable-declaration), and are processed by the [asynchronous iterator initialization steps](#asynchronous-iterator-initialization-steps), if any exist.

With this in mind, the requirement that all arguments be optional ensures that, in the JavaScript binding, `for`-`await`-`of` can work directly on instances of the interface, since `for`-`await`-`of` calls the [`%Symbol.asyncIterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) method with no arguments.

Prose accompanying an [interface](#dfn-interface) with an [asynchronously iterable declaration](#dfn-async-iterable-declaration) must define a **get the next iteration result** algorithm. This algorithm receives the instance of the [interface](#dfn-interface) that is being iterated, as well as the async iterator itself (which can be useful for storing state). It must return a [`Promise`](#idl-promise) that either rejects, resolves with a special **end of iteration** value to signal the end of the iteration, or resolves with one of the following:

for [value asynchronously iterable declarations](#value-asynchronously-iterable-declaration):

: a value of the type given in the declaration;

for [pair asynchronously iterable declarations](#pair-asynchronously-iterable-declaration):

: a [tuple](https://infra.spec.whatwg.org/#tuple) containing a value of the first type given in the declaration, and a value of the second type given in the declaration.

The prose may also define an **asynchronous iterator return** algorithm. This algorithm receives the instance of the [interface](#dfn-interface) that is being iterated, the async iterator itself, and a single argument value of type [`any`](#idl-any). This algorithm is invoked in the case of premature termination of the async iterator. It must return a [`Promise`](#idl-promise); if that promise fulfills, its fulfillment value will be ignored, but if it rejects, that failure will be passed on to users of the async iterator API.

In the JavaScript binding, this algorithm allows customizing the behavior when the async iterator's `return()` method is invoked. This most commonly occurs when a `break` or `return` statement causes an exit from a `for`-`await`-`of` loop.

We could add a similar hook for `throw()`. So far there has been no need, but if you are creating an API that needs such capabilities, please [file an issue](https://github.com/whatwg/webidl/issues/new?title=Enhancement%20request%20for%20Async%20Iterables).

The prose may also define **asynchronous iterator initialization steps**. These receive the instance of the [interface](#dfn-interface) being iterated, the newly-created iterator object, and a [list](https://infra.spec.whatwg.org/#list) of IDL values representing the arguments passed, if any.

[Interfaces](#dfn-interface) with an [asynchronously iterable declaration](#dfn-async-iterable-declaration) must not have any [attributes](#dfn-attribute), [constants](#dfn-constant), or [regular operations](#dfn-regular-operation) named "`entries`", "`keys`", or "`values`", or have any [inherited interfaces](#dfn-inherited-interfaces) that have [attributes](#dfn-attribute), [constants](#dfn-constant), or [regular operations](#dfn-regular-operation) with these names.

Consider the following interface `SessionManager`, which allows access to a number of `Session` objects keyed by username:

```
[Exposed=Window]
interface SessionManager {
  Session getSessionForUser(DOMString username);

  async_iterable<DOMString, Session>;
};

[Exposed=Window]
interface Session {
  readonly attribute DOMString username;
  // ...
};
```

The behavior of the iterator could be defined like so:

> The [asynchronous iterator initialization steps](#asynchronous-iterator-initialization-steps) for a `SessionManager` async iterator `iterator` are:
>
> 1. Set `iterator`'s **current state** to "not yet started".
>
> To [get the next iteration result](#dfn-get-the-next-iteration-result) for a `SessionManager` `manager` and its async iterator `iterator`:
>
> 1. Let `promise` be a new promise.
>
> 2. Let `key` be the following value, if it exists, or null otherwise:
>
>    If `iterator`'s [current state](#sessionmanager-async-iterator-current-state) is "not yet started"
>
>    : the smallest username in `manager`'s open sessions, in lexicographical order
>
>    Otherwise
>
>    : the smallest username in `manager`'s open sessions that is greater than `iterator`'s current state, in lexicographical order
>
>    `iterator`'s [current state](#sessionmanager-async-iterator-current-state) might no longer be present in the open sessions.
>
> 3. If `key` is null, then:
>
>    1. Resolve `promise` with [end of iteration](#end-of-iteration).
>
> 4. Otherwise:
>
>    1. Let `session` be the `Session` object corresponding to `key`.
>
>    2. Resolve `promise` with (`username`, `session`).
>
>    3. Set `iterator`'s [current state](#sessionmanager-async-iterator-current-state) to `username`.
>
> 5. Return `promise`.

In the JavaScript language binding, the [interface prototype object](#dfn-interface-prototype-object) for the `SessionManager` [interface](#dfn-interface) has a `values` method that is a function, which, when invoked, returns an asynchronous iterator object that itself has a `next` method that returns the next value to be iterated over. It has `keys` and `entries` methods that iterate over the usernames of session objects and (username, `Session`) object pairs, respectively. It also has a [`%Symbol.asyncIterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) method that allows a `SessionManager` to be used in a `for await..of` loop that has the same value as the `entries` method:

```
// Get an instance of SessionManager.
// Assume that it has sessions for two users, "anna" and "brian".
var sm = getSessionManager();

typeof SessionManager.prototype.values;            // Evaluates to "function"
var it = sm.values();                              // values() returns an iterator object
typeof it.next;                                    // Evaluates to "function"

// This loop will log "anna" and then "brian".
for await (let username of sm.keys()) {
  console.log(username);
}

// Yet another way of accomplishing the same.
for await (let [username, session] of sm) {
  console.log(username);
}
```

An [interface](#dfn-interface) must not have more than one [asynchronously iterable declaration](#dfn-async-iterable-declaration). The [inherited interfaces](#dfn-inherited-interfaces) of an [interface](#dfn-interface) with an [asynchronously iterable declaration](#dfn-async-iterable-declaration) must not also have an [asynchronously iterable declaration](#dfn-async-iterable-declaration). An [interface](#dfn-interface) with an [asynchronously iterable declaration](#dfn-async-iterable-declaration) and its [inherited interfaces](#dfn-inherited-interfaces) must not have a [maplike declaration](#dfn-maplike-declaration), [setlike declaration](#dfn-setlike-declaration), or [iterable declaration](#dfn-iterable-declaration).

The following extended attributes are applicable to [asynchronously iterable declarations](#dfn-async-iterable-declaration): \[[`CrossOriginIsolated`](#CrossOriginIsolated)\], \[[`Exposed`](#Exposed)\], and \[[`SecureContext`](#SecureContext)\].

these [extended attributes](#dfn-extended-attribute) are not currently taken into account. When they are, the effect will be as you would expect.

```
AsyncIterable ::
    async_iterable < TypeWithExtendedAttributes OptionalType > OptionalArgumentList ;
```

```
OptionalArgumentList ::
    ( ArgumentList )
    ε
```


#### Maplike declarations

An [interface](#dfn-interface) can be declared to be **maplike** by using a **maplike declaration** (matching [ReadWriteMaplike](#prod-ReadWriteMaplike) or readonly [MaplikeRest](#prod-MaplikeRest)) in the body of the interface.

```
interface interface_identifier {
  readonly maplike<key_type, value_type>;
  maplike<key_type, value_type>;
};
```

Objects implementing an interface that is declared to be maplike represent an [ordered map](https://infra.spec.whatwg.org/#ordered-map) of key--value pairs, initially empty, known as that object's **map entries**. The types used for the keys and values are given in the angle brackets of the maplike declaration. Keys are required to be unique.

Specification authors can modify the contents of the [map entries](#dfn-map-entries), which will automatically be reflected in the contents of the object as observed by JavaScript code.

Maplike interfaces support an API for querying the map entries appropriate for the language binding. If the readonly keyword is not used, then it also supports an API for modifying the map entries.

In the JavaScript language binding, the API for interacting with the map entries is similar to that available on JavaScript [`Map`](https://tc39.es/ecma262/multipage/keyed-collections.html#sec-map-objects) objects. If the readonly keyword is used, this includes `entries`, `forEach`, `get`, `has`, `keys`, `values`, [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) methods, and a `size` getter. For read--write maplikes, it also includes `clear`, `delete`, and `set` methods.

Maplike interfaces must not have any [attributes](#dfn-attribute), [constants](#dfn-constant), or [regular operations](#dfn-regular-operation) named "`entries`", "`forEach`", "`get`", "`has`", "`keys`", "`size`", or "`values`", or have any [inherited interfaces](#dfn-inherited-interfaces) that have [attributes](#dfn-attribute), [constants](#dfn-constant), or [regular operations](#dfn-regular-operation) with these names.

Read--write maplike interfaces must not have any [attributes](#dfn-attribute) or [constants](#dfn-constant) named "`clear`", "`delete`", or "`set`", or have any [inherited interfaces](#dfn-inherited-interfaces) that have [attributes](#dfn-attribute) or [constants](#dfn-constant) with these names.

Read-write maplike interfaces *can* have *regular operations* named "`clear`", "`delete`", or "`set`", which will override the default implementation of those methods (defined in [§ 3.7.11 Maplike declarations](#js-maplike)). If such regular operations are defined, they must match the input and output expectations of each method, defined in their default implementation sections.

An interface must not have more than one [maplike declaration](#dfn-maplike-declaration). The [inherited interfaces](#dfn-inherited-interfaces) of a maplike interface must not also have a [maplike declaration](#dfn-maplike-declaration). A maplike interface and its [inherited interfaces](#dfn-inherited-interfaces) must not have an [iterable declaration](#dfn-iterable-declaration), an [asynchronously iterable declaration](#dfn-async-iterable-declaration), a [setlike declaration](#dfn-setlike-declaration), or an [indexed property getter](#dfn-indexed-property-getter).

```
ReadWriteMaplike ::
    MaplikeRest
```

```
MaplikeRest ::
    maplike < TypeWithExtendedAttributes , TypeWithExtendedAttributes > ;
```

No [extended attributes](#dfn-extended-attribute) defined in this specification are applicable to [maplike declarations](#dfn-maplike-declaration).

Add example.


#### Setlike declarations

An [interface](#dfn-interface) can be declared to be **setlike** by using a **setlike declaration** (matching [ReadWriteSetlike](#prod-ReadWriteSetlike) or readonly [SetlikeRest](#prod-SetlikeRest)) in the body of the interface.

```
interface interface_identifier {
  readonly setlike<type>;
  setlike<type>;
};
```

Objects implementing an interface that is declared to be setlike represent an [ordered set](https://infra.spec.whatwg.org/#ordered-set) of values, initially empty, known as that object's **set entries**. The type of the values is given in the angle brackets of the setlike declaration. Values are required to be unique.

Specification authors can modify the contents of the [set entries](#dfn-set-entries), which will automatically be reflected in the contents of the object as observed by JavaScript code.

Setlike interfaces support an API for querying the set entries appropriate for the language binding. If the readonly keyword is not used, then it also supports an API for modifying the set entries.

In the JavaScript language binding, the API for interacting with the set entries is similar to that available on JavaScript [`Set`](https://tc39.es/ecma262/multipage/keyed-collections.html#sec-set-objects) objects. If the readonly keyword is used, this includes `entries`, `forEach`, `has`, `keys`, `values`, [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) methods, and a `size` getter. For read--write setlikes, it also includes `add`, `clear`, and `delete` methods.

Setlike interfaces must not have any [attributes](#dfn-attribute), [constants](#dfn-constant), or [regular operations](#dfn-regular-operation) named "`entries`", "`forEach`", "`has`", "`keys`", "`size`", or "`values`", or have any [inherited interfaces](#dfn-inherited-interfaces) that have [attributes](#dfn-attribute), [constants](#dfn-constant), or [regular operations](#dfn-regular-operation) with these names.

Read--write setlike interfaces must not have any [attributes](#dfn-attribute) or [constants](#dfn-constant) named "`add`", "`clear`", or "`delete`", or have any [inherited interfaces](#dfn-inherited-interfaces) that have [attributes](#dfn-attribute) or [constants](#dfn-constant) with these names.

Read-write setlike interfaces *can* have *regular operations* named "`add`", "`clear`", or "`delete`", which will override the default implementation of those methods (defined in [§ 3.7.12 Setlike declarations](#js-setlike)). If such regular operations are defined, they must match the input and output expectations of each method, defined in their default implementation sections.

An interface must not have more than one [setlike declaration](#dfn-setlike-declaration). The [inherited interfaces](#dfn-inherited-interfaces) of a setlike interface must not also have a [setlike declaration](#dfn-setlike-declaration). A setlike interface and its [inherited interfaces](#dfn-inherited-interfaces) must not have an [iterable declaration](#dfn-iterable-declaration), an [asynchronously iterable declaration](#dfn-async-iterable-declaration), a [maplike declaration](#dfn-maplike-declaration), or an [indexed property getter](#dfn-indexed-property-getter).

```
ReadWriteSetlike ::
    SetlikeRest
```

```
SetlikeRest ::
    setlike < TypeWithExtendedAttributes > ;
```

No [extended attributes](#dfn-extended-attribute) defined in this specification are applicable to [setlike declarations](#dfn-setlike-declaration).

Add example.


### Namespaces

A **namespace** is a definition (matching Namespace) that declares a global singleton with associated behaviors.

``` syntax
namespace identifier {
  /* namespace_members... */
};
```

A namespace is a specification of a set of **namespace members** (matching NamespaceMembers), which are the regular operations, read only regular attributes, and constants that appear between the braces in the namespace declaration. These operations and attributes describe the behaviors packaged into the namespace.

As with interfaces, the IDL for namespaces can be split into multiple parts by using **partial namespace** definitions (matching partial Namespace). The identifier of a partial namespace definition must be the same as the identifier of a namespace definition. All of the members that appear on each of the partial namespace definitions are considered to be members of the namespace itself.

``` syntax
namespace SomeNamespace {
  /* namespace_members... */
};

partial namespace SomeNamespace {
  /* namespace_members... */
};
```

Note: As with partial interface definitions, partial namespace definitions are intended for use as a specification editorial aide, allowing the definition of a namespace to be separated over more than one section of the document, and sometimes multiple documents.

The order that members appear in has significance for property enumeration in the JavaScript binding.

Note that unlike interfaces or dictionaries, namespaces do not create types.

Of the extended attributes defined in this specification, only the \[`CrossOriginIsolated`\], \[`Exposed`\], and \[`SecureContext`\] extended attributes are applicable to namespaces.

Namespaces must be annotated with the \[`Exposed`\] extended attribute.

``` grammar
Partial ::
    partial PartialDefinition
```

``` grammar
PartialDefinition ::
    interface PartialInterfaceOrPartialMixin
    PartialDictionary
    Namespace
```

``` grammar
Namespace ::
    namespace identifier { NamespaceMembers } ;
```

``` grammar
NamespaceMembers ::
    ExtendedAttributeList NamespaceMember NamespaceMembers
    ε
```

``` grammar
NamespaceMember ::
    RegularOperation
    readonly AttributeRest
    Const
```

The following IDL fragment defines a namespace.

``` highlight
namespace VectorUtils {
  readonly attribute Vector unit;
  double dotProduct(Vector x, Vector y);
  Vector crossProduct(Vector x, Vector y);
};
```

A JavaScript implementation would then expose a global `VectorUtils` data property which was a simple object (with prototype `%Object.prototype%`) with enumerable data properties for each declared operation, and enumerable get-only accessors for each declared attribute:

``` highlight
Object.getPrototypeOf(VectorUtils);                         // Evaluates to Object.prototype.
Object.keys(VectorUtils);                                   // Evaluates to ["dotProduct", "crossProduct"].
Object.getOwnPropertyDescriptor(VectorUtils, "dotProduct"); // Evaluates to { value: <a function>, enumerable: true, configurable: true, writable: true }.
Object.getOwnPropertyDescriptor(VectorUtils, "unit");       // Evaluates to { get: <a function>, enumerable: true, configurable: true }.
```


### Dictionaries

A **dictionary** is a definition (matching Dictionary) used to define an [ordered map](https://infra.spec.whatwg.org/#ordered-map) data type with a fixed, ordered set of [entries](https://infra.spec.whatwg.org/#map-entry), termed **dictionary members**, where [keys](https://infra.spec.whatwg.org/#map-getting-the-keys) are strings and [values](https://infra.spec.whatwg.org/#map-getting-the-values) are of a particular type specified in the definition.

``` syntax
dictionary identifier {
  /* dictionary_members... */
};
```

Dictionary instances do not retain a reference to their language-specific representations (e.g., the corresponding JavaScript object). So for example, returning a dictionary from an operation will result in a new JavaScript object being created from the current values of the dictionary. And, an operation that accepts a dictionary as an argument will perform a one-time conversion from the given JavaScript value into the dictionary, based on the current properties of the JavaScript object. Modifications to the dictionary will not be reflected in the corresponding JavaScript object, and vice-versa.

Dictionaries must not be used as the type of an attribute or constant.

A dictionary can be defined to **inherit** from another dictionary. If the identifier of the dictionary is followed by a colon and a identifier, then that identifier identifies the inherited dictionary. The identifier must identify a dictionary.

A dictionary must not be declared such that its inheritance hierarchy has a cycle. That is, a dictionary `A` cannot inherit from itself, nor can it inherit from another dictionary `B` that inherits from `A`, and so on.

``` syntax
dictionary Base {
  /* dictionary_members... */
};

dictionary Derived : Base {
  /* dictionary_members... */
};
```

The **inherited dictionaries** of a given dictionary `D` is the set of all dictionaries that `D` inherits from, directly or indirectly. If `D` does not inherit from another dictionary, then the set is empty. Otherwise, the set includes the dictionary `E` that `D` inherits from and all of `E`'s inherited dictionaries.

Dictionary members can be specified as **required**, meaning that converting a language-specific value to a dictionary requires providing a value for that member. Any dictionary member that is not required is **optional**.

Note that specifying dictionary members as required only has an observable effect when converting other representations of dictionaries (like a JavaScript value supplied as an argument to an operation) to an IDL dictionary. Specification authors should leave the members optional in all other cases, including when a dictionary type is used solely as the return type of operations.

A given dictionary value of type `D` can have [entries](https://infra.spec.whatwg.org/#map-entry) for each of the dictionary members defined on `D` and on any of `D`'s inherited dictionaries. Dictionary members that are specified as required, or that are specified as having a default value, will always have such corresponding [entries](https://infra.spec.whatwg.org/#map-entry). Other members' entries might or might not [exist](https://infra.spec.whatwg.org/#map-exists) in the dictionary value.

In the JavaScript binding, a value of undefined for the property corresponding to a dictionary member is treated the same as omitting that property. Thus, it will cause an error if the member is required, or will trigger the default value if one is present, or will result in no [entry](https://infra.spec.whatwg.org/#map-entry) existing in the dictionary value otherwise.

As with operation argument default values, it is strongly encouraged not to use true as the default value for `boolean`-typed dictionary members, as this can be confusing for authors who might otherwise expect the default conversion of undefined to be used (i.e., false). [API-DESIGN-PRINCIPLES]

An [ordered map](https://infra.spec.whatwg.org/#ordered-map) with string [keys](https://infra.spec.whatwg.org/#map-getting-the-keys) can be implicitly treated as a dictionary value of a specific dictionary `D` if all of its [entries](https://infra.spec.whatwg.org/#map-entry) correspond to dictionary members, as long as those entries have the correct types, and there are [entries](https://infra.spec.whatwg.org/#map-entry) present for any required or defaulted dictionary members.

``` highlight
dictionary Descriptor {
  DOMString name;
  sequence<unsigned long> serviceIdentifiers;
};
```

A `Descriptor` dictionary could be created as in the following steps:

1.  Let `identifiers` be « 1, 3, 7 ».

2.  Return «[ "name" → "test", "serviceIdentifiers" → `identifiers` ]».


Each dictionary member (matching DictionaryMember) is specified as a type (matching Type) followed by an identifier (given by an identifier token following the type). The identifier is the key name of the key--value pair. If the Type is an identifier followed by ?, then the identifier must identify an interface, enumeration, callback function, callback interface or typedef. If the dictionary member type is an identifier not followed by ?, then the identifier must identify any one of those definitions or a dictionary.

If the type of the dictionary member, after resolving typedefs, is a nullable type, its inner type must not be a dictionary type.

``` syntax
dictionary identifier {
  type identifier;
};
```

If the identifier for an optional dictionary member is followed by a U+003D (=) and a value (matching DefaultValue), then that gives the dictionary member its **default value**, which is the value used by default when author code or specification text does not provide a value for that member.

``` syntax
dictionary identifier {
  type identifier = "value";
};
```

When a boolean literal token (true or false), the null token, an integer token, a decimal token, one of the three special floating point literal values (Infinity, -Infinity or NaN), a string token, the two token sequence [], or the two token sequence {} is used as the default value, it is interpreted in the same way as for an operation's optional argument default value.

If the type of the dictionary member is an enumeration, then its default value if specified must be one of the enumeration's values.

If the type of the dictionary member is preceded by the required keyword, the member is considered a required dictionary member.

``` syntax
dictionary identifier {
  required type identifier;
};
```

The type of a dictionary member must not include the dictionary it appears on. A type includes a dictionary `D` if at least one of the following is true:

- the type is `D`

- the type is a dictionary that inherits from `D`

- the type is a nullable type whose inner type includes `D`

- the type is a sequence type or frozen array whose element type includes `D`

- the type is a union type, one of whose member types includes `D`

- the type is a dictionary, one of whose members or inherited members has a type that includes `D`

- the type is `record<K, V>` where `V` includes `D`

As with interfaces, the IDL for dictionaries can be split into multiple parts by using **partial dictionary** definitions (matching partial Dictionary). The identifier of a partial dictionary definition must be the same as the identifier of a dictionary definition. All of the members that appear on each of the partial dictionary definitions are considered to be members of the dictionary itself.

``` syntax
dictionary SomeDictionary {
  /* dictionary_members... */
};

partial dictionary SomeDictionary {
  /* dictionary_members... */
};
```

Note: As with partial interface definitions, partial dictionary definitions are intended for use as a specification editorial aide, allowing the definition of an interface to be separated over more than one section of the document, and sometimes multiple documents.

The order of the dictionary members on a given dictionary is such that inherited dictionary members are ordered before non-inherited members, and the dictionary members on the one dictionary definition (including any partial dictionary definitions) are ordered lexicographically by the Unicode codepoints that comprise their identifiers.

For example, with the following definitions:

``` highlight
dictionary B : A {
  long b;
  long a;
};

dictionary A {
  long c;
  long g;
};

dictionary C : B {
  long e;
  long f;
};

partial dictionary A {
  long h;
  long d;
};
```

the order of the dictionary members of a dictionary value of type `C` is c, d, g, h, a, b, e, f.

Dictionaries need to have their members ordered because in some language bindings the behavior observed when passing a dictionary value to a platform object depends on the order the dictionary members are fetched. For example, consider the following additional interface:

``` highlight
[Exposed=Window]
interface Something {
  undefined f(A a);
};
```

and this JavaScript code:

``` highlight
var something = getSomething();  // Get an instance of Something.
var x = 0;

var dict = { };
Object.defineProperty(dict, "d", { get: function() { return ++x; } });
Object.defineProperty(dict, "c", { get: function() { return ++x; } });

something.f(dict);
```

The order that the dictionary members are fetched in determines what values they will be taken to have. Since the order for `A` is defined to be c then d, the value for c will be 1 and the value for d will be 2.


The identifier of a dictionary member must not be the same as that of another dictionary member defined on the dictionary or on that dictionary's inherited dictionaries.

No extended attributes are applicable to dictionaries.

``` grammar
Partial ::
    partial PartialDefinition
```

``` grammar
PartialDefinition ::
    interface PartialInterfaceOrPartialMixin
    PartialDictionary
    Namespace
```

``` grammar
Dictionary ::
    dictionary identifier Inheritance { DictionaryMembers } ;
```

``` grammar
DictionaryMembers ::
    DictionaryMember DictionaryMembers
    ε
```

``` grammar
DictionaryMember ::
    ExtendedAttributeList DictionaryMemberRest
```

``` grammar
DictionaryMemberRest ::
    required TypeWithExtendedAttributes identifier ;
    Type identifier Default ;
```

``` grammar
PartialDictionary ::
    dictionary identifier { DictionaryMembers } ;
```

``` grammar
Default ::
    = DefaultValue
    ε
```

``` grammar
DefaultValue ::
    ConstValue
    string
    [ ]
    { }
    null
    undefined
```

``` grammar
Inheritance ::
    : identifier
    ε
```


One use of dictionary types is to allow a number of optional arguments to an operation without being constrained as to the order they are specified at the call site. For example, consider the following IDL fragment:

``` highlight
[Exposed=Window]
interface Point {
  constructor();
  attribute double x;
  attribute double y;
};

dictionary PaintOptions {
  DOMString fillPattern = "black";
  DOMString strokePattern;
  Point position;
};

[Exposed=Window]
interface GraphicsContext {
  undefined drawRectangle(double width, double height, optional PaintOptions options);
};
```

In a JavaScript implementation of the IDL, an Object can be passed in for the optional `PaintOptions` dictionary:

``` highlight
// Get an instance of GraphicsContext.
var ctx = getGraphicsContext();

// Draw a rectangle.
ctx.drawRectangle(300, 200, { fillPattern: "red", position: new Point(10, 10) });
```

The members of `PaintOptions` are optional. If `fillPattern` is omitted, the definition of `drawRectangle` can assume that it has the given default values and not include explicit wording to handle its omission. `drawRectangle` needs to explicitly handle the case where `strokePattern` and `position` are omitted.


### Exceptions

An **exception** is a type of object that represents an error and which can be thrown or treated as a first class value by implementations. Web IDL has a number of pre-defined exceptions that specifications can reference and throw in their definition of operations, attributes, and so on. Custom exception types can also be defined, as interfaces that inherit from `DOMException`.

A **simple exception** is identified by one of the following types:

- `EvalError`

- `RangeError`

- `ReferenceError`

- `TypeError`

- `URIError`

These correspond to all of the JavaScript [error objects](https://tc39.es/ecma262/#sec-error-objects) (apart from `SyntaxError` and `Error`, which are deliberately omitted as they are reserved for use by the JavaScript parser and by authors, respectively). The meaning of each simple exception matches its corresponding error object in the JavaScript specification.

The second kind of exception is a `DOMException`, which provides further programmatically-introspectable detail on the error that occurred by giving a name. Such names are drawn from the `DOMException` names table below.

As `DOMException` is an interface type, it can be used as a type in IDL. This allows for example an operation to be declared to have a `DOMException` return type. This is generally a bad pattern, however, as exceptions are meant to be thrown and not returned.

The final kind of exception is a derived interface of `DOMException`. These are more complicated, and thus described in the dedicated section § 2.8.2 DOMException derived interfaces.

Simple exceptions can be **created** by providing their type name. A `DOMException` can be created by providing its name followed by `DOMException`. Exceptions can also be **thrown**, by providing the same details required to create one. In both cases, the caller may provide additional information about what the exception indicates, which is useful when constructing the exception's message.

Here is are some examples of wording to use to create and throw exceptions. To throw a new simple exception whose type is `TypeError`:

> Throw a `TypeError`.

To throw a new `DOMException` with name "`NotAllowedError`":

> Throw a "`NotAllowedError`" `DOMException`.

To create a new `DOMException` with name "`SyntaxError`":

> Let `object` be a newly created "`SyntaxError`" `DOMException`.

To reject a promise with a new `DOMException` with name "`OperationError`":

> Reject `p` with an "`OperationError`" `DOMException`.

An example of including additional information used to construct the exception message would be:

> Throw a "`SyntaxError`" `DOMException` indicating that the given value had disallowed trailing spaces.

Such additional context is most helpful to implementers when it is not immediately obvious why the exception is being thrown, e.g., because there are many different steps in the algorithm which throw a "`SyntaxError`" `DOMException`. In contrast, if your specification throws a "`NotAllowedError`" `DOMException` immediately after checking if the user has provided permission to use a given feature, it's fairly obvious what sort of message the implementation ought to construct, and so specifying it is not necessary.

The resulting behavior from creating and throwing an exception is language binding specific.

See § 3.14.3 Creating and throwing exceptions for details on what creating and throwing an exception entails in the JavaScript language binding.


#### Base `DOMException` error names

The **`DOMException` names table** below lists all the allowed names for instances of the base `DOMException` interface, along with a description of what such names mean, and legacy numeric error code values.

Interfaces inheriting from `DOMException`, in the manner described in § 2.8.2 DOMException derived interfaces, will have their own names, not listed in this table.

When creating or throwing a `DOMException`, specifications must use one of these names. If a specification author believes none of these names are a good fit for their case, they must [file an issue](https://github.com/whatwg/webidl/issues/new?title=DOMException%20name%20proposal) to discuss adding a new name to the shared namespace, so that the community can coordinate such efforts. Note that adding new use-case-specific names is only important if you believe web developers will discriminate multiple error conditions arising from a single API.

The `DOMException` names marked as deprecated are kept for legacy purposes, but their usage is discouraged.

Note: Don't confuse the "`SyntaxError`" `DOMException` defined here with JavaScript's `SyntaxError`. "`SyntaxError`" `DOMException` is used to report parsing errors in web APIs, for example when parsing selectors, while the JavaScript `SyntaxError` is reserved for the JavaScript parser. To help disambiguate this further, always favor the "`SyntaxError`" `DOMException` notation over just using `SyntaxError` to refer to the `DOMException`.

| Name | Description | Legacy code name and value |
|------|-------------|---------------------------|
| "`IndexSizeError`" | **Deprecated.** Use `RangeError` instead. | `INDEX_SIZE_ERR` (1) |
| "`HierarchyRequestError`" | The operation would yield an incorrect [node tree](https://dom.spec.whatwg.org/#concept-node-tree). | `HIERARCHY_REQUEST_ERR` (3) |
| "`WrongDocumentError`" | The object is in the wrong [document](https://dom.spec.whatwg.org/#concept-document). | `WRONG_DOCUMENT_ERR` (4) |
| "`InvalidCharacterError`" | The string contains invalid characters. | `INVALID_CHARACTER_ERR` (5) |
| "`NoModificationAllowedError`" | The object can not be modified. | `NO_MODIFICATION_ALLOWED_ERR` (7) |
| "`NotFoundError`" | The object can not be found here. | `NOT_FOUND_ERR` (8) |
| "`NotSupportedError`" | The operation is not supported. | `NOT_SUPPORTED_ERR` (9) |
| "`InUseAttributeError`" | The attribute is in use by another [element](https://dom.spec.whatwg.org/#concept-element). | `INUSE_ATTRIBUTE_ERR` (10) |
| "`InvalidStateError`" | The object is in an invalid state. | `INVALID_STATE_ERR` (11) |
| "`SyntaxError`" | The string did not match the expected pattern. | `SYNTAX_ERR` (12) |
| "`InvalidModificationError`" | The object can not be modified in this way. | `INVALID_MODIFICATION_ERR` (13) |
| "`NamespaceError`" | The operation is not allowed by Namespaces in XML. | `NAMESPACE_ERR` (14) |
| "`InvalidAccessError`" | **Deprecated.** Use `TypeError` for invalid arguments, "`NotSupportedError`" `DOMException` for unsupported operations, and "`NotAllowedError`" `DOMException` for denied requests instead. | `INVALID_ACCESS_ERR` (15) |
| "`TypeMismatchError`" | **Deprecated.** Use `TypeError` instead. | `TYPE_MISMATCH_ERR` (17) |
| "`SecurityError`" | The operation is insecure. | `SECURITY_ERR` (18) |
| "`NetworkError`" | A network error occurred. | `NETWORK_ERR` (19) |
| "`AbortError`" | The operation was aborted. | `ABORT_ERR` (20) |
| "`URLMismatchError`" | **Deprecated.** | `URL_MISMATCH_ERR` (21) |
| "`QuotaExceededError`" | **Deprecated.** Use the `QuotaExceededError` `DOMException`-derived interface instead. | `QUOTA_EXCEEDED_ERR` (22) |
| "`TimeoutError`" | The operation timed out. | `TIMEOUT_ERR` (23) |
| "`InvalidNodeTypeError`" | The supplied [node](https://dom.spec.whatwg.org/#boundary-point-node) is incorrect or has an incorrect ancestor for this operation. | `INVALID_NODE_TYPE_ERR` (24) |
| "`DataCloneError`" | The object can not be cloned. | `DATA_CLONE_ERR` (25) |
| "`EncodingError`" | The encoding operation (either encoded or decoding) failed. | --- |
| "`NotReadableError`" | The I/O read operation failed. | --- |
| "`UnknownError`" | The operation failed for an unknown transient reason (e.g. out of memory). | --- |
| "`ConstraintError`" | A mutation operation in a transaction failed because a constraint was not satisfied. | --- |
| "`DataError`" | Provided data is inadequate. | --- |
| "`TransactionInactiveError`" | A request was placed against a transaction which is currently not active, or which is finished. | --- |
| "`ReadOnlyError`" | The mutating operation was attempted in a "readonly" transaction. | --- |
| "`VersionError`" | An attempt was made to open a database using a lower version than the existing version. | --- |
| "`OperationError`" | The operation failed for an operation-specific reason. | --- |
| "`NotAllowedError`" | The request is not allowed by the user agent or the platform in the current context, possibly because the user denied permission. | --- |
| "`OptOutError`" | The user opted out of the process. | --- |


#### `DOMException` derived interfaces

When an exception needs to carry additional programmatically-introspectable information, beyond what can be provided with a `DOMException`'s name, specification authors can create an interface which inherits from `DOMException`. Such interfaces need to follow certain rules, in order to have a predictable shape for developers. Specifically:

- The identifier of the interface must end with `Error`, and must not be any of the names in the `DOMException` names table.

- The interface must have a constructor operation which sets the instance's name to the interface's identifier.

- Their constructor operation must take as its first parameter an optional `DOMString` named `message` defaulting to the empty string, and must set the instance's message to `message`.

- Their constructor operation should take as its second parameter a dictionary containing the additional information that needs to be exposed.

- They should have read only attributes, whose names are the same as the members of the constructor dictionary, which return the values accepted by the constructor operation.

- They should be [serializable objects](https://html.spec.whatwg.org/multipage/structured-data.html#serializable-objects), whose [serialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps) and [deserialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps) preserve the additional information.

These requirements mean that the inherited `code` property of these interfaces will always return 0.

To create or throw a `DOMException` derived interface, supply its interface identifier as well as the additional information needed to construct it.

To throw an instance of `QuotaExceededError`:

> Throw a `QuotaExceededError` whose quota is 42 and requested is 50.


#### Predefined `DOMException` derived interfaces

This standard so far defines one predefined `DOMException` derived interface:

```idl
[Exposed=*, Serializable]
interface QuotaExceededError : DOMException {
  constructor(optional DOMString message = "", optional QuotaExceededErrorOptions options = {});

  readonly attribute double? quota;
  readonly attribute double? requested;
};

dictionary QuotaExceededErrorOptions {
  double quota;
  double requested;
};
```

The `QuotaExceededError` exception can be thrown when a quota is exceeded. It has two properties that are optionally present, to give more information to the web developer about their request compared to the quota value.

Previous versions of this standard defined "`QuotaExceededError`" as one of the base `DOMException` error names. It has been upgraded to a full interface to support including such information.

Every `QuotaExceededError` instance has a **requested** and a **quota**, both numbers or null. They are both initially null.

The `new QuotaExceededError(message, options)` constructor steps are:

1. Set this's name to "`QuotaExceededError`".

2. Set this's message to `message`.

3. If `options`["`quota`"] is present:

   1. If `options`["`quota`"] is less than 0, then throw a `RangeError`.

   2. Set this's quota to `options`["`quota`"].

4. If `options`["`requested`"] is present:

   1. If `options`["`requested`"] is less than 0, then throw a `RangeError`.

   2. Set this's requested to `options`["`requested`"].

5. If this's quota is not null, this's requested is not null, and this's requested is less than this's quota, then throw a `RangeError`.

The `quota` getter steps are to return this's quota.

The `requested` getter steps are to return this's requested.

The `QuotaExceededError` interface inherits the `DOMException` interface's `code` getter, which will always return 22. However, relying on this value is discouraged (for both `QuotaExceededError` and `DOMException`); it is better to use the `name` getter.

`QuotaExceededError` objects are [serializable objects](https://html.spec.whatwg.org/multipage/structured-data.html#serializable-objects).

Their [serialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps), given `value` and `serialized`, are:

1. Run the `DOMException` [serialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps) given `value` and `serialized`.

2. Set `serialized`.[[Quota]] to `value`'s quota.

3. Set `serialized`.[[Requested]] to `value`'s requested.

Their [deserialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps), given `serialized` and `value`, are:

1. Run the `DOMException` [deserialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps) given `serialized` and `value`.

2. Set `value`'s quota to `serialized`.[[Quota]].

3. Set `value`'s requested to `serialized`.[[Requested]].

Specifications that create or throw a `QuotaExceededError` must not provide a requested and quota that are both non-null and where requested is less than quota.


## Enumerations

An **enumeration** is a definition (matching Enum) used to declare a type whose valid values are a set of predefined strings. Enumerations can be used to restrict the possible `DOMString` values that can be assigned to an attribute or passed to an operation.

```syntax
enum identifier { "enum", "values" /* , ... */ };
```

The **enumeration values** are specified as a comma-separated list of string literals. The list of enumeration values must not include duplicates.

It is strongly suggested that enumeration values be all lowercase, and that multiple words be separated using dashes or not be separated at all, unless there is a specific reason to use another value naming scheme. For example, an enumeration value that indicates an object should be created could be named "`createobject`" or "`create-object`". Consider related uses of enumeration values when deciding whether to dash-separate or not separate enumeration value words so that similar APIs are consistent.

The behavior when a string value that is not a valid enumeration value is used when assigning to an attribute, or passed as an operation argument, whose type is the enumeration, is language binding specific.

Note: In the JavaScript binding, assignment of an invalid string value to an attribute is ignored, while passing such a value in other contexts (for example as an operation argument) results in an exception being thrown.

No extended attributes defined in this specification are applicable to enumerations.

```grammar
Enum ::
    enum identifier { EnumValueList } ;
```

```grammar
EnumValueList ::
    string EnumValueListComma
```

```grammar
EnumValueListComma ::
    , EnumValueListString
    ε
```

```grammar
EnumValueListString ::
    string EnumValueListComma
    ε
```

The following IDL fragment defines an enumeration that is used as the type of an attribute and an operation argument:

```idl
enum MealType { "rice", "noodles", "other" };

[Exposed=Window]
interface Meal {
  attribute MealType type;
  attribute double size;     // in grams

  undefined initialize(MealType type, double size);
};
```

A JavaScript implementation would restrict the strings that can be assigned to the type property or passed to the initializeMeal function to those identified in the enumeration.

```js
var meal = getMeal();                // Get an instance of Meal.

meal.initialize("rice", 200);        // Operation invoked as normal.

try {
  meal.initialize("sandwich", 100);  // Throws a TypeError.
} catch (e) {
}

meal.type = "noodles";               // Attribute assigned as normal.
meal.type = "dumplings";             // Attribute assignment ignored.
meal.type == "noodles";              // Evaluates to true.
```


## Callback functions

The "Custom DOM Elements" spec wants to use callback function types for platform object provided functions. Should we rename "callback functions" to just "functions" to make it clear that they can be used for both purposes?

A **callback function** is a definition (matching callback CallbackRest) used to declare a function type.

```
callback identifier = return_type (/* arguments... */);
```

Note: See also the similarly named callback interfaces.

The identifier on the left of the equals sign gives the name of the callback function and the return type and argument list (matching Type and ArgumentList) on the right side of the equals sign gives the signature of the callback function type.

Callback functions must not be used as the type of a constant.

The following extended attribute is applicable to callback functions: [`LegacyTreatNonObjectAsNull`].

```grammar
CallbackOrInterfaceOrMixin ::
    callback CallbackRestOrInterface
    interface InterfaceOrMixin
```

```grammar
CallbackRest ::
    identifier = Type ( ArgumentList ) ;
```

The following IDL fragment defines a callback function used for an API that invokes a user-defined function when an operation is complete.

```
callback AsyncOperationCallback = undefined (DOMString status);

[Exposed=Window]
interface AsyncOperations {
  undefined performOperation(AsyncOperationCallback whenFinished);
};
```

In the JavaScript language binding, a function object is passed as the operation argument.

```
var ops = getAsyncOperations();  // Get an instance of AsyncOperations.

ops.performOperation(function(status) {
  window.alert("Operation finished, status is " + status + ".");
});
```


## Typedefs

A **typedef** is a definition (matching [Typedef](#prod-Typedef)) used to declare a new name for a type. This new name is not exposed by language bindings; it is purely used as a shorthand for referencing the type in the IDL.

```syntax
typedef type identifier;
```

The **type being given a new name** is specified after the typedef keyword (matching [TypeWithExtendedAttributes](#prod-Type)), and the [identifier](#prod-identifier) token following the type gives the name.

The [Type](#prod-Type) must not be the identifier of the same or another typedef.

No extended attributes defined in this specification are applicable to typedefs.

```
Typedef ::
    typedef TypeWithExtendedAttributes identifier ;
```

The following IDL fragment demonstrates the use of typedefs to allow the use of a short identifier instead of a long sequence type.

```highlight
[Exposed=Window]
interface Point {
  attribute double x;
  attribute double y;
};

typedef sequence<Point> Points;

[Exposed=Window]
interface Widget {
  boolean pointWithinBounds(Point p);
  boolean allPointsWithinBounds(Points ps);
};
```


## Objects implementing interfaces

In a given implementation of a set of IDL fragments, an object can be described as being a platform object.

Platform objects are objects that implement an interface.

Legacy platform objects are platform objects that implement an interface which does not have a \[`Global`{.idl}\] extended attribute, and which supports indexed properties, named properties, or both.

In a browser, for example, the browser-implemented DOM objects (implementing interfaces such as `Node`{.idl} and `Document`{.idl}) that provide access to a web page's contents to JavaScript running in the page would be platform objects. These objects might be exotic objects, implemented in a language like C++, or they might be native JavaScript objects. Regardless, an implementation of a given set of IDL fragments needs to be able to recognize all platform objects that are created by the implementation. This might be done by having some internal state that records whether a given object is indeed a platform object for that implementation, or perhaps by observing that the object is implemented by a given internal C++ class. How exactly platform objects are recognized by a given implementation of a set of IDL fragments is implementation specific.

All other objects in the system would not be treated as platform objects. For example, assume that a web page opened in a browser loads a JavaScript library that implements DOM Core. This library would be considered to be a different implementation from the browser provided implementation. The objects created by the JavaScript library that implement the `Node`{.idl} interface will not be treated as platform objects that implement `Node`{.idl} by the browser implementation.

Callback interfaces, on the other hand, can be implemented by any JavaScript object. This allows Web APIs to invoke author-defined operations. For example, the DOM Events implementation allows authors to register callbacks by providing objects that implement the [`EventListener`{.idl}](https://dom.spec.whatwg.org/#callbackdef-eventlistener) interface.


### Types

This section lists the types supported by Web IDL, the set of values or Infra type corresponding to each type, and how constants of that type are represented.

The following types are known as **integer types**: `byte`, `octet`, `short`, `unsigned short`, `long`, `unsigned long`, `long long` and `unsigned long long`.

The following types are known as **numeric types**: the integer types, `float`, `unrestricted float`, `double` and `unrestricted double`.

The **primitive types** are `bigint`, `boolean` and the numeric types.

The **string types** are `DOMString`, all enumeration types, `ByteString` and `USVString`.

The **buffer types** are `ArrayBuffer` and `SharedArrayBuffer`.

The **typed array types** are `Int8Array`, `Int16Array`, `Int32Array`, `Uint8Array`, `Uint16Array`, `Uint32Array`, `Uint8ClampedArray`, `BigInt64Array`, `BigUint64Array`, `Float16Array`, `Float32Array`, and `Float64Array`.

The **buffer view types** are `DataView` and the typed array types.

The **buffer source types** are the buffer types and the buffer view types.

The `object` type, all interface types, and all callback interface types are known as **object types**.

When conversions are made from language binding specific types to IDL types in order to invoke an operation or assign a value to an attribute, all conversions necessary will be performed before the specified functionality of the operation or attribute assignment is carried out. If the conversion cannot be performed, then the operation will not run or the attribute will not be updated. In some language bindings, type conversions could result in an exception being thrown. In such cases, these exceptions will be propagated to the code that made the attempt to invoke the operation or assign to the attribute.

```
Type ::
    SingleType
    UnionType Null
```

```
TypeWithExtendedAttributes ::
    ExtendedAttributeList Type
```

```
SingleType ::
    DistinguishableType
    any
    PromiseType
```

```
UnionType ::
    ( UnionMemberType or UnionMemberType UnionMemberTypes )
```

```
UnionMemberType ::
    ExtendedAttributeList DistinguishableType
    UnionType Null
```

```
UnionMemberTypes ::
    or UnionMemberType UnionMemberTypes
    ε
```

```
DistinguishableType ::
    PrimitiveType Null
    StringType Null
    identifier Null
    sequence < TypeWithExtendedAttributes > Null
    async_sequence < TypeWithExtendedAttributes > Null
    object Null
    symbol Null
    BufferRelatedType Null
    FrozenArray < TypeWithExtendedAttributes > Null
    ObservableArray < TypeWithExtendedAttributes > Null
    RecordType Null
    undefined Null
```

```
ConstType ::
    PrimitiveType
    identifier
```

```
PrimitiveType ::
    UnsignedIntegerType
    UnrestrictedFloatType
    boolean
    byte
    octet
    bigint
```

```
UnrestrictedFloatType ::
    unrestricted FloatType
    FloatType
```

```
FloatType ::
    float
    double
```

```
UnsignedIntegerType ::
    unsigned IntegerType
    IntegerType
```

```
IntegerType ::
    short
    long OptionalLong
```

```
OptionalLong ::
    long
    ε
```

```
StringType ::
    ByteString
    DOMString
    USVString
```

```
PromiseType ::
    Promise < Type >
```

```
RecordType ::
    record < StringType , TypeWithExtendedAttributes >
```

```
Null ::
    ?
    ε
```


#### any

The `any` type is the union of all other possible non-union types.

The `any` type is like a discriminated union type, in that each of its values has a specific non-`any` type associated with it. For example, one value of the `any` type is the `unsigned long` 150, while another is the `long` 150. These are distinct values.

The particular type of an `any` value is known as its **specific type**. (Values of union types also have specific types.)


#### undefined

The `undefined` type has a unique value.

`undefined` constant values in IDL are represented with the undefined token.

`undefined` must not be used as the type of an argument in any circumstance (in an operation, callback function, constructor operation, etc), or as the type of a dictionary member, whether directly or in a union. Instead, use an optional argument or a non-required dictionary member.

Note: This value was previously spelled `void`, and more limited in how it was allowed to be used.


#### boolean

The `boolean` type corresponds to booleans.

`boolean` constant values in IDL are represented with the true and false tokens.


#### byte

The `byte` type corresponds to 8-bit signed integers.

`byte` constant values in IDL are represented with integer tokens.


#### octet

The `octet` type corresponds to 8-bit unsigned integers.

`octet` constant values in IDL are represented with integer tokens.


#### short

The `short` type corresponds to 16-bit signed integers.

`short` constant values in IDL are represented with integer tokens.


#### unsigned short

The `unsigned short` type corresponds to 16-bit unsigned integers.

`unsigned short` constant values in IDL are represented with integer tokens.


#### long

The `long` type corresponds to 32-bit signed integers.

`long` constant values in IDL are represented with integer tokens.


#### unsigned long

The `unsigned long` type corresponds to 32-bit unsigned integers.

`unsigned long` constant values in IDL are represented with integer tokens.


#### long long

The `long long` type corresponds to 64-bit signed integers.

`long long` constant values in IDL are represented with integer tokens.


#### unsigned long long

The `unsigned long long` type corresponds to 64-bit unsigned integers.

`unsigned long long` constant values in IDL are represented with integer tokens.


#### float

The `float` type is a floating point numeric type that corresponds to the set of finite single-precision 32-bit IEEE 754 floating point numbers.

`float` constant values in IDL are represented with decimal tokens.

Unless there are specific reasons to use a 32-bit floating point type, specifications should use `double` rather than `float`, since the set of values that a `double` can represent more closely matches a JavaScript Number.


#### unrestricted float

The `unrestricted float` type is a floating point numeric type that corresponds to the set of all possible single-precision 32-bit IEEE 754 floating point numbers, finite, non-finite, and special "not a number" values (NaNs).

`unrestricted float` constant values in IDL are represented with decimal tokens.


#### double

The `double` type is a floating point numeric type that corresponds to the set of finite double-precision 64-bit IEEE 754 floating point numbers.

`double` constant values in IDL are represented with decimal tokens.


#### unrestricted double

The `unrestricted double` type is a floating point numeric type that corresponds to the set of all possible double-precision 64-bit IEEE 754 floating point numbers, finite, non-finite, and special "not a number" values (NaNs).

`unrestricted double` constant values in IDL are represented with decimal tokens.


#### bigint

The `bigint` type is an arbitrary integer type, unrestricted in range.

`bigint` constant values in IDL are represented with integer tokens.


#### DOMString

The `DOMString` type corresponds to strings.

Note: null is not a value of type `DOMString`. To allow null, a nullable `DOMString`, written as `DOMString?` in IDL, needs to be used.

Note: A `DOMString` value might include unmatched surrogate code points. Use `USVString` if this is not desirable.

There is no way to represent a constant `DOMString` value in IDL, although `DOMString` dictionary member default values and operation optional argument default values can be set to the value of a string literal.


#### ByteString

The `ByteString` type corresponds to byte sequences.

There is no way to represent a constant `ByteString` value in IDL, although `ByteString` dictionary member default values and operation optional argument default values can be set to the value of a string literal.

Specifications should only use `ByteString` for interfacing with protocols that use bytes and strings interchangeably, such as HTTP. In general, strings should be represented with `DOMString` values, even if it is expected that values of the string will always be in ASCII or some 8-bit character encoding. Sequences or frozen arrays with `octet` or `byte` elements, `Uint8Array`, or `Int8Array` should be used for holding 8-bit data rather than `ByteString`.


#### USVString

The `USVString` type corresponds to scalar value strings. Depending on the context, these can be treated as sequences of code units or scalar values.

There is no way to represent a constant `USVString` value in IDL, although `USVString` dictionary member default values and operation optional argument default values can be set to the value of a string literal.

Specifications should only use `USVString` for APIs that perform text processing and need a string of scalar values to operate on. Most APIs that use strings should instead be using `DOMString`, which does not make any interpretations of the code units in the string. When in doubt, use `DOMString`.


#### object

The `object` type corresponds to the set of all possible non-null object references.

There is no way to represent a constant `object` value in IDL.

To denote a type that includes all possible object references plus the null value, use the nullable type `object?`.


#### symbol

The `symbol` type corresponds to the set of all possible symbol values. Symbol values are opaque, non-`object` values which nevertheless have identity (i.e., are only equal to themselves).

There is no way to represent a constant `symbol` value in IDL.


#### Interface types

An identifier that identifies an interface is used to refer to a type that corresponds to the set of all possible non-null references to objects that implement that interface.

An IDL value of the interface type is represented just by an object reference.

There is no way to represent a constant object reference value for a particular interface type in IDL.

To denote a type that includes all possible references to objects implementing the given interface plus the null value, use a nullable type.


#### Callback interface types

An identifier that identifies a callback interface is used to refer to a type that corresponds to the set of all possible non-null references to objects.

An IDL value of the interface type is represented by a tuple of an object reference and a **callback context**. The callback context is a language binding specific value, and is used to store information about the execution context at the time the language binding specific object reference is converted to an IDL value.

Note: For JavaScript objects, the callback context is used to hold a reference to the incumbent settings object at the time the Object value is converted to an IDL callback interface type value. See § 3.2.16 Callback interface types.

There is no way to represent a constant object reference value for a particular callback interface type in IDL.

To denote a type that includes all possible references to objects plus the null value, use a nullable type.


#### Dictionary types

An identifier that identifies a dictionary is used to refer to a type that corresponds to the set of all dictionaries that adhere to the dictionary definition.

The literal syntax for ordered maps may also be used to represent dictionaries, when it is implicitly understood from context that the map is being treated as an instance of a specific dictionary type. However, there is no way to represent a constant dictionary value inside IDL fragments.


#### Enumeration types

An identifier that identifies an enumeration is used to refer to a type whose values are the set of strings (sequences of code units, as with `DOMString`) that are the enumeration's values.

Like `DOMString`, there is no way to represent a constant enumeration value in IDL, although enumeration-typed dictionary member default values and operation optional argument default values can be set to the value of a string literal.


#### Callback function types

An identifier that identifies a callback function is used to refer to a type whose values are references to objects that are functions with the given signature.

Note: If the \[`LegacyTreatNonObjectAsNull`\] extended attribute is specified on the definition of the callback function, the values can be references to objects that are not functions.

An IDL value of the callback function type is represented by a tuple of an object reference and a callback context.

Note: As with callback interface types, the callback context is used to hold a reference to the incumbent settings object at the time a JavaScript Object value is converted to an IDL callback function type value. See § 3.2.19 Callback function types.

There is no way to represent a constant callback function value in IDL.


#### Nullable types --- T?

A **nullable type** is an IDL type constructed from an existing type (called the **inner type**), which just allows the additional value null to be a member of its set of values. Nullable types are represented in IDL by placing a U+003F (?) character after an existing type. The inner type must not be:

- `any`,
- a promise type,
- an observable array type,
- another nullable type, or
- a union type that itself includes a nullable type or has a dictionary type as one of its flattened member types.

Note: Although dictionary types can in general be nullable, they cannot when used as the type of an operation argument or a dictionary member.

Nullable type constant values in IDL are represented in the same way that constant values of their inner type would be represented, or with the null token.

For example, a type that allows the values true, false and null is written as `boolean?`:

```
[Exposed=Window]
interface NetworkFetcher {
  undefined get(optional boolean? areWeThereYet = false);
};
```

The following interface has two attributes: one whose value can be a `DOMString` or the null value, and another whose value can be a reference to a `Node` object or the null value:

```
[Exposed=Window]
interface Node {
  readonly attribute DOMString? namespaceURI;
  readonly attribute Node? parentNode;
  // ...
};
```


#### Sequence types --- sequence<T>

The **sequence<T> type** is a parameterized type whose values are (possibly zero-length) lists of values of type T.

Sequences are always passed by value. In language bindings where a sequence is represented by an object of some kind, passing a sequence to a platform object will not result in a reference to the sequence being kept by that object. Similarly, any sequence returned from a platform object will be a copy and modifications made to it will not be visible to the platform object.

The literal syntax for lists may also be used to represent sequences, when it is implicitly understood from context that the list is being treated as a sequences. However, there is no way to represent a constant sequence value inside IDL fragments.

Sequences must not be used as the type of an attribute or constant.

Note: This restriction exists so that it is clear to specification writers and API users that sequences are copied rather than having references to them passed around. Instead of a writable attribute of a sequence type, it is suggested that a pair of operations to get and set the sequence is used.

Any list can be implicitly treated as a `sequence<T>`, as long as it contains only items that are of type T.


#### Async sequence types --- async_sequence<T>

An **async sequence type** is a parameterized type whose values are references to objects that can produce an asynchronously iterable, possibly infinite, sequence of values of type T.

Unlike sequences, which are fixed-length lists where all values are known in advance, the asynchronously iterable sequences created by async sequences are lazy. Their values may be produced asynchronously only during iteration, and thus the values or length might not be known at the time the async sequence is created.

Async sequences are passed by reference in language bindings where they are represented by an object. This means that passing an async sequence to a platform object will result in a reference to the async sequence being kept by that object. Similarly, any async sequence returned from a platform object will be a reference to the same object and modifications made to it will be visible to the platform object. This is in contrast to sequences, which are always passed by value.

Note: Async sequences cannot be constructed from IDL. If returned from an operation, or used as the type of a dictionary member, the async sequence will have originated from the host environment and have been turned into an IDL type via a language binding. Instead of returning an async sequence from an IDL operation, the operation might want to return an interface that has an asynchronously iterable declaration.

Async sequences must not be used as the type of an attribute or constant.

There is no way to represent an async sequence value in IDL.


#### Record types --- record<K, V>

A **record type** is a parameterized type whose values are ordered maps with keys that are instances of K and values that are instances of V. K must be one of `DOMString`, `USVString`, or `ByteString`.

The literal syntax for ordered maps may also be used to represent records, when it is implicitly understood from context that the map is being treated as a record. However, there is no way to represent a constant record value inside IDL fragments.

Records are always passed by value. In language bindings where a record is represented by an object of some kind, passing a record to a platform object will not result in a reference to the record being kept by that object. Similarly, any record returned from a platform object will be a copy and modifications made to it will not be visible to the platform object.

Records must not be used as the type of an attribute or constant.

Any ordered map can be implicitly treated as a `record<K, V>`, as long as it contains only entries whose keys are all of of type K and whose values are all of type V.


#### Promise types --- Promise<T>

A **promise type** is a parameterized type whose values are references to objects that "is used as a place holder for the eventual results of a deferred (and possibly asynchronous) computation result of an asynchronous operation". See section 25.4 of the JavaScript specification for details on the semantics of promise objects.

Promise types are non-nullable, but T may be nullable.

There is no way to represent a promise value in IDL.


#### Union types

A **union type** is a type whose set of values is the union of those in two or more other types. Union types (matching UnionType) are written as a series of types separated by the or keyword with a set of surrounding parentheses. The types which comprise the union type are known as the union's **member types**.

Note: For example, you might write `(Node or DOMString)` or `(double or sequence<double>)`. When applying a ? suffix to a union type as a whole, it is placed after the closing parenthesis, as in `(Node or DOMString)?`.

Note that the member types of a union type do not descend into nested union types. So for `(double or (sequence<long> or Event) or (Node or DOMString)?)` the member types are `double`, `(sequence<long> or Event)` and `(Node or DOMString)?`.

Like the `any` type, values of union types have a specific type, which is the particular member type that matches the value.

The **flattened member types** of a union type, possibly annotated, is a set of types determined as follows:

1. Let T be the union type.
2. Initialize S to ∅.
3. For each member type U of T:
   1. If U is an annotated type, then set U to be the inner type of U.
   2. If U is a nullable type, then set U to be the inner type of U.
   3. If U is a union type, then add to S the flattened member types of U.
   4. Otherwise, U is not a union type. Add U to S.
4. Return S.

Note: For example, the flattened member types of the union type `(Node or (sequence<long> or Event) or (XMLHttpRequest or DOMString)? or sequence<(sequence<double> or NodeList)>)` are the six types `Node`, `sequence<long>`, `Event`, `XMLHttpRequest`, `DOMString` and `sequence<(sequence<double> or NodeList)>`.

The **number of nullable member types** of a union type is an integer determined as follows:

1. Let T be the union type.
2. Initialize n to 0.
3. For each member type U of T:
   1. If U is a nullable type, then:
      1. Set n to n + 1.
      2. Set U to be the inner type of U.
   2. If U is a union type, then:
      1. Let m be the number of nullable member types of U.
      2. Set n to n + m.
4. Return n.

The `any` type must not be used as a union member type.

The number of nullable member types of a union type must be 0 or 1, and if it is 1 then the union type must also not have a dictionary type in its flattened member types.

A type **includes a nullable type** if:

- the type is a nullable type, or
- the type is an annotated type and its inner type is a nullable type, or
- the type is a union type and its number of nullable member types is 1.

Each pair of flattened member types in a union type, T and U, must be distinguishable.

It is possible to create a union of `bigint` and a numeric type. However, this is generally only supposed to be used for interfaces such as NumberFormat, which formats the values rather than using them in calculations. It would not be appropriate to accept such a union, only to then convert values of the numeric type to a `bigint` for further processing, as this runs the risk of introducing precision errors. Please file an issue before using this feature.

A type **includes undefined** if:

- the type is `undefined`, or
- the type is a nullable type and its inner type includes undefined, or
- the type is an annotated type and its inner type includes undefined, or
- the type is a union type and one of its member types includes undefined.

Union type constant values in IDL are represented in the same way that constant values of their member types would be represented.

```
UnionType ::
    ( UnionMemberType or UnionMemberType UnionMemberTypes )
```

```
UnionMemberType ::
    ExtendedAttributeList DistinguishableType
    UnionType Null
```

```
UnionMemberTypes ::
    or UnionMemberType UnionMemberTypes
    ε
```

```
DistinguishableType ::
    PrimitiveType Null
    StringType Null
    identifier Null
    sequence < TypeWithExtendedAttributes > Null
    async_sequence < TypeWithExtendedAttributes > Null
    object Null
    symbol Null
    BufferRelatedType Null
    FrozenArray < TypeWithExtendedAttributes > Null
    ObservableArray < TypeWithExtendedAttributes > Null
    RecordType Null
    undefined Null
```


#### Annotated types

Additional types can be created from existing ones by specifying certain extended attributes on the existing types. Such types are called **annotated types**, and the types they annotate are called **inner types**.

`[Clamp] long` defines a new annotated type, whose behavior is based on that of the inner type `long`, but modified as specified by the \[`Clamp`\] extended attribute.

The following extended attributes are **applicable to types**: \[`AllowResizable`\], \[`AllowShared`\], \[`Clamp`\], \[`EnforceRange`\], and \[`LegacyNullToEmptyString`\].

The **extended attributes associated with** an IDL type `type` are determined as follows:

1. Let `extended attributes` be a new empty set.
2. If `type` appears as part of a TypeWithExtendedAttributes production, append each of the extended attributes present in the production's ExtendedAttributeList to `extended attributes`.
3. If `type` is a member type of a union type U, append each of the extended attributes associated with U to `extended attributes`.
4. If `type` appears as part of a Type production directly within an Argument production, append to `extended attributes` all of the extended attributes present in the production's ExtendedAttributeList that are applicable to types.
5. If `type` appears as part of a Type production directly within a DictionaryMember production, append to `extended attributes` all of the extended attributes present in the production's ExtendedAttributeList that are applicable to types.
6. If `type` is a typedef, append the extended attributes associated with the type being given a new name to `extended attributes`.
7. Return `extended attributes`.

For any type, the extended attributes associated with it must only contain extended attributes that are applicable to types.


#### Buffer source types

There are a number of types that correspond to sets of all possible non-null references to objects that represent a buffer of data or a view on to a buffer of data. The table below lists these types and the kind of buffer or view they represent.

| Type | Kind of buffer |
|------|----------------|
| `ArrayBuffer` | An object that holds a pointer (which can be null) to a buffer of a fixed number of bytes |
| `SharedArrayBuffer` | An object that holds a pointer (which cannot be null) to a shared buffer of a fixed number of bytes |
| `DataView` | A view on to a buffer type instance that allows typed access to integers and floating point values stored at arbitrary offsets into the buffer |
| `Int8Array` | A view on to a buffer type instance that exposes it as an array of two's complement signed integers of the given size in bits |
| `Int16Array` | |
| `Int32Array` | |
| `BigInt64Array` | |
| `Uint8Array` | A view on to a buffer type instance that exposes it as an array of unsigned integers of the given size in bits |
| `Uint16Array` | |
| `Uint32Array` | |
| `BigUint64Array` | |
| `Uint8ClampedArray` | A view on to a buffer type instance that exposes it as an array of 8-bit unsigned integers with clamped conversions |
| `Float16Array` | A view on to a buffer type instance that exposes it as an array of IEEE 754 floating point numbers of the given size in bits; Float16Array corresponds to the ECMAScript proposal. |
| `Float32Array` | |
| `Float64Array` | |

Note: These types all correspond to classes defined in JavaScript.

There is no way to represent a constant value of any of these types in IDL.

At the specification prose level, IDL buffer source types are simply references to objects. To inspect or manipulate the bytes inside the buffer, specification prose needs to use the algorithms in § 3.2.26 Buffer source types.

```
BufferRelatedType ::
    ArrayBuffer
    SharedArrayBuffer
    DataView
    Int8Array
    Int16Array
    Int32Array
    Uint8Array
    Uint16Array
    Uint32Array
    Uint8ClampedArray
    BigInt64Array
    BigUint64Array
    Float16Array
    Float32Array
    Float64Array
```


#### Frozen array types --- FrozenArray<T>

A **frozen array type** is a parameterized type whose values are references to objects that hold a fixed length array of unmodifiable values. The values in the array are of type T.

Frozen array types must only be used as the type of regular attributes or static attributes defined on an interface.

The following IDL fragment defines an interface with two frozen array attributes, one read only and one not.

```
[Exposed=Window]
interface PersonalPreferences {
    readonly attribute FrozenArray<DOMString> favoriteColors;
    attribute FrozenArray<DOMString> favoriteFoods;

    undefined randomizeFavoriteColors();
};
```

The behavior of these attributes could be defined like so:

> Each `PersonalPreferences` has associated **favorite colors**, a `FrozenArray`<`DOMString`>, initially equal to the result of creating a frozen array from « "`purple`", "`aquamarine`" ».
>
> Each `PersonalPreferences` has an associated **favorite foods**, a `FrozenArray`<`DOMString`>, initially equal to the result of creating a frozen array from the empty list.
>
> The `favoriteColors` getter steps are to return this's favorite colors.
>
> The `favoriteFoods` getter steps are to return this's favorite foods.
>
> The `favoriteFoods` setter steps are to set this's favorite foods to the given value.
>
> The `randomizeFavoriteColors()` method steps are:
>
> 1. Let `newFavoriteColors` be a list of two strings representing colors, chosen randomly.
> 2. Set this's favorite colors to the result of creating a frozen array from `newFavoriteColors`.

Since FrozenArray<T> values are references, they are unlike sequence types, which are lists of values that are passed by value.

There is no way to represent a constant frozen array value in IDL.


#### Observable array types --- ObservableArray<T>

An **observable array type** is a parameterized type whose values are references to a combination of a mutable list of objects of type T, as well as behavior to perform when author code modifies the contents of the list.

The parameterized type T must not be a dictionary type, sequence type, record type, or observable array type. However, T may be nullable.

Similar to sequence types and frozen array types, observable array types wrap around JavaScript array types, imposing additional semantics on their usage.

Observable array types must only be used as the type of regular attributes defined on an interface.

For an attribute whose type is an observable array type, specification authors can specify a series of algorithms:

- **set an indexed value**, which accepts an IDL value that is about to be set in the observable array, and the index at which it is being set;
- **delete an indexed value**, which accepts an IDL value that is about to be removed from the observable array, and the index from which it is being removed.

Both of these algorithms are optional, and if not provided, the default behavior will be to do nothing. Either algorithm may throw an exception, e.g., to reject invalid values.

Note that when JavaScript code sets an existing index to a new value, this will first call the delete an indexed value algorithm to remove the existing value, and then the set an indexed value algorithm with the new value.

Every regular attribute whose type is an observable array type has a **backing list**, which is a list, initially empty. Specification authors can modify the contents of the backing list, which will automatically be reflected in the contents of the observable array as observed by JavaScript code. Similarly, any modifications by JavaScript code to the contents of the observable array will be reflected back into the backing list, after passing through the set an indexed value and delete an indexed value algorithms.

There is no way to represent a constant observable array value in IDL.

The following IDL fragment defines an interface with an observable array attribute:

```
[Exposed=Window]
interface Building {
  attribute ObservableArray<Employee> employees;
};
```

The behavior of the attribute could be defined like so:

> The set an indexed value algorithm for `Building`'s `employees` attribute, given `employee` and `index`, is:
>
> 1. If `employee` is not allowed to enter the building today, then throw a "`NotAllowedError`" `DOMException`.
> 2. If `index` is greater than or equal to 200, then throw a `QuotaExceededError` whose quota is 200 and requested is `index`.
> 3. Put `employee` to work!
>
> The delete an indexed value algorithm for `Building`'s `employees` attribute, given `employee` and `index`, is:
>
> 1. Alert security that `employee` has left the building.

Then, JavaScript code could manipulate the `employees` property in various ways:

```
// Get an instance of Building.
const building = getBuilding();

building.employees.push(new Employee("A"));
building.employees.push(new Employee("B"));
building.employees.push(new Employee("C"));

building.employees.splice(2, 1);
const employeeB = building.employees.pop();

building.employees = [new Employee("D"), employeeB, new Employee("C")];

building.employees.length = 0;

// Will throw:
building.employees.push("not an Employee; a string instead");
```

All of these manipulations would pass through the above-defined set an indexed value algorithm, potentially throwing if the conditions described there were met. They would also perform the appropriate side effects listed there and in the delete an indexed value algorithm.

Another thing to note about the above code example is how all of the JavaScript array methods from `%Array.prototype%` work on the observable array. Indeed, it fully behaves like an `Array` instance:

```
const normalArray = [];

// If building.employees were defined as an indexed property getter interface: normalArray
// would contains a single item, building.employees.
//
// For observable arrays (and frozen arrays): normalArray contains all of the items inside
// of building.employees.
normalArray.concat(building.employees);

// names is a JavaScript Array.
const names = building.employees.map(employee => employee.name);

// Passes various brand checks:
console.assert(building.employees instanceof Array);
console.assert(Array.isArray(building.employees));
console.assert(building.employees.constructor === Array);

// Even is treated as an array by JSON.stringify! (Note the outer []s.)
console.assert(JSON.stringify(building.employees) === `[{}]`);
```


## Extended attributes

An [extended attribute](#dfn-extended-attribute) is an annotation that can appear on [definitions](#dfn-definition), types as [annotated types](#annotated-types), [interface members](#dfn-interface-member), [interface mixin members](#interface-mixin-member), [callback interface members](#callback-interface-member), [namespace members](#dfn-namespace-member), [dictionary members](#dfn-dictionary-member), and [operation](#dfn-operation) arguments, and is used to control how language bindings will handle those constructs. Extended attributes are specified with an ExtendedAttributeList, which is a square bracket enclosed, comma separated list of ExtendedAttributes.

The ExtendedAttribute grammar symbol matches nearly any sequence of tokens, however the [extended attributes](#dfn-extended-attribute) defined in this document only accept a more restricted syntax. Any extended attribute encountered in an [IDL fragment](#dfn-idl-fragment) is matched against the following grammar symbols to determine which form (or forms) it is in:

| Grammar symbol | Form | Example |
|----------------|------|---------|
| ExtendedAttributeNoArgs | takes no arguments | `[Replaceable]` |
| ExtendedAttributeArgList | takes an argument list | Not currently used; previously used by `[Constructor(double x, double y)]` |
| ExtendedAttributeNamedArgList | takes a named argument list | `[LegacyFactoryFunction=Image(DOMString src)]` |
| ExtendedAttributeIdent | takes an identifier | `[PutForwards=name]` |
| ExtendedAttributeString | takes a string | `[Reflect="popover"]` |
| ExtendedAttributeInteger | takes an integer | `[ReflectDefault=2]` |
| ExtendedAttributeDecimal | takes a decimal | `[ReflectDefault=2.0]` |
| ExtendedAttributeIntegerList | takes an integer list | `[ReflectRange=(2, 600)]` |
| ExtendedAttributeIdentList | takes an identifier list | `[Exposed=(Window,Worker)]` |
| ExtendedAttributeWildcard | takes a wildcard | `[Exposed=*]` |

This specification defines a number of extended attributes that are applicable to the JavaScript language binding, which are described in § 3.3 Extended attributes. Each extended attribute definition will state which of the above five forms are allowed.

```
ExtendedAttributeList ::
    [ ExtendedAttribute ExtendedAttributes ]
    ε
```

```
ExtendedAttributes ::
    , ExtendedAttribute ExtendedAttributes
    ε
```

```
ExtendedAttribute ::
    ( ExtendedAttributeInner ) ExtendedAttributeRest
    [ ExtendedAttributeInner ] ExtendedAttributeRest
    { ExtendedAttributeInner } ExtendedAttributeRest
    Other ExtendedAttributeRest
```

```
ExtendedAttributeRest ::
    ExtendedAttribute
    ε
```

```
ExtendedAttributeInner ::
    ( ExtendedAttributeInner ) ExtendedAttributeInner
    [ ExtendedAttributeInner ] ExtendedAttributeInner
    { ExtendedAttributeInner } ExtendedAttributeInner
    OtherOrComma ExtendedAttributeInner
    ε
```

```
Other ::
    integer
    decimal
    identifier
    string
    other
    -
    -Infinity
    .
    ...
    :
    ;
    <
    =
    >
    ?
    *
    ByteString
    DOMString
    FrozenArray
    Infinity
    NaN
    ObservableArray
    Promise
    USVString
    any
    bigint
    boolean
    byte
    double
    false
    float
    long
    null
    object
    octet
    or
    optional
    record
    sequence
    short
    symbol
    true
    unsigned
    undefined
    ArgumentNameKeyword
    BufferRelatedType
```

```
OtherOrComma ::
    Other
    ,
```

```
IdentifierList ::
    identifier Identifiers
```

```
Identifiers ::
    , identifier Identifiers
    ε
```

```
IntegerList ::
    integer Integers
```

```
Integers ::
    , integer Integers
    ε
```

```
ExtendedAttributeNoArgs ::
    identifier
```

```
ExtendedAttributeArgList ::
    identifier ( ArgumentList )
```

```
ExtendedAttributeIdent ::
    identifier = identifier
```

```
ExtendedAttributeString ::
    identifier = string
```

```
ExtendedAttributeInteger ::
    identifier = integer
```

```
ExtendedAttributeDecimal ::
    identifier = decimal
```

```
ExtendedAttributeWildcard ::
    identifier = *
```

```
ExtendedAttributeIdentList ::
    identifier = ( IdentifierList )
```

```
ExtendedAttributeIntegerList ::
    identifier = ( IntegerList )
```

```
ExtendedAttributeNamedArgList ::
    identifier = identifier ( ArgumentList )
```


## JavaScript binding

This section describes how definitions written with the IDL defined in § 2 Interface definition language correspond to particular constructs in JavaScript, as defined by the ECMAScript Language Specification [ECMA-262].

Unless otherwise specified, objects defined in this section are ordinary objects as described in [ECMAScript § 10.1 Ordinary Object Internal Methods and Internal Slots](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinary-object-internal-methods-and-internal-slots), and if the object is a [function object](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#function-object), [ECMAScript § 10.3 Built-in Function Objects](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-built-in-function-objects).

This section may redefine certain internal methods and internal slots of objects. Other specifications may also override the definitions of any internal method or internal slots of a platform object that is an instance of an interface. These objects with changed semantics shall be treated in accordance with the rules for exotic objects.

As overriding internal JavaScript object methods is a low level operation and can result in objects that behave differently from ordinary objects, this facility should not be used unless necessary for security or compatibility. This is currently used to define the `HTMLAllCollection` and `Location` interfaces. [HTML]

Unless otherwise specified, exotic objects defined in this section and other specifications have the same [internal slots](https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots) as ordinary objects, and all of the internal methods for which alternative definitions are not given are the same as [those](https://tc39.es/ecma262/#sec-ordinary-object-internal-methods-and-internal-slots) of ordinary objects.

Unless otherwise specified, the [[Extensible]] internal slot of objects defined in this section has the value true.

Unless otherwise specified, the [[Prototype]] internal slot of objects defined in this section is [`%Object.prototype%`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-properties-of-the-object-prototype-object).

Some objects described in this section are defined to have a **class string**, which is the string to include in the string returned from `Object.prototype.toString`.

If an object has a class string `classString`, then the object must, at the time it is created, have a property whose name is the [`%Symbol.toStringTag%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) symbol with PropertyDescriptor{[[Writable]]: false, [[Enumerable]]: false, [[Configurable]]: true, [[Value]]: `classString`}.

Algorithms in this section use the conventions described in [ECMAScript § 5.2 Algorithm Conventions](https://tc39.es/ecma262/multipage/notational-conventions.html#sec-algorithm-conventions), such as the use of steps and substeps, the use of mathematical operations, and so on. This section may also reference abstract operations and notations defined in other parts of ECMA-262.

When an algorithm says to **throw** a `Something`Error then this means to construct a new JavaScript `Something`Error object in the [current realm](https://tc39.es/ecma262/#current-realm) and to throw it, just as the algorithms in ECMA-262 do.

Note that algorithm steps can call in to other algorithms and abstract operations and not explicitly handle exceptions that are thrown from them. When an exception is thrown by an algorithm or abstract operation and it is not explicitly handled by the caller, then it is taken to end the algorithm and propagate out to its caller, and so on.

Consider the following algorithm:

1. Let `x` be the JavaScript value passed in to this algorithm.

2. Let `y` be the result of calling [?](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [ToString](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tostring)(`x`).

3. Return `y`.

Since [ToString](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tostring) can throw an exception (for example if passed the object `({ toString: function() { throw 1 } })`), and the exception is not handled in the above algorithm, if one is thrown then it causes this algorithm to end and for the exception to propagate out to its caller, if there is one.


## JavaScript environment

In a JavaScript implementation of a given set of IDL fragments, there will exist a number of JavaScript objects that correspond to definitions in those IDL fragments. These objects are termed the **initial objects**, and comprise the following:

- interface objects

- legacy callback interface objects

- legacy factory functions

- interface prototype objects

- named properties objects

- iterator prototype objects

- attribute getters

- attribute setters

- the function objects that correspond to operations

- the function objects that correspond to stringifiers

Each [realm](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm) must have its own unique set of each of the initial objects, created before control enters any JavaScript execution context associated with the realm, but after the [global object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global) for that realm is created. The [[Prototype]]s of all initial objects in a given [realm](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm) must come from that same [realm](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm).

In an HTML user agent, multiple [realms](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm) can exist when multiple frames or windows are created. Each frame or window will have its own set of initial objects, which the following HTML document demonstrates:

```
<!DOCTYPE html>
<title>Different Realms</title>
<iframe id=a></iframe>
<script>
var iframe = document.getElementById("a");
var w = iframe.contentWindow;              // The global object in the frame

Object == w.Object;                        // Evaluates to false, per ECMA-262
Node == w.Node;                            // Evaluates to false
iframe instanceof w.Node;                  // Evaluates to false
iframe instanceof w.Object;                // Evaluates to false
iframe.appendChild instanceof Function;    // Evaluates to true
iframe.appendChild instanceof w.Function;  // Evaluates to false
</script>
```

Note: All interfaces define which [realms](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm) they are exposed in. This allows, for example, [realms](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm) for Web Workers to expose different sets of supported interfaces from those exposed in realms for Web pages.

Although at the time of this writing the JavaScript specification does not reflect this, every JavaScript object must have an **associated [realm](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm)**. The mechanisms for associating objects with realms are, for now, underspecified. However, we note that in the case of platform objects, the associated realm is equal to the object's [relevant realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), and for non-exotic [function objects](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#function-object) (i.e. not [callable](https://tc39.es/ecma262/#sec-iscallable) proxies, and not bound functions) the associated realm is equal to the value of the [function object](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#function-object)'s [[Realm]] internal slot.


### JavaScript type mapping

This section describes how types in the IDL map to types in JavaScript.

Each sub-section below describes how values of a given IDL type are represented in JavaScript. For each IDL type, it is described how JavaScript values are converted to an IDL value when passed to a platform object expecting that type, and how IDL values of that type are converted to JavaScript values when returned from a platform object.

Note that the sub-sections and algorithms below also apply to annotated types created by applying extended attributes to the types named in their headers.


#### any

Since the IDL `any` type is the union of all other IDL types, it can correspond to any JavaScript value type.

A JavaScript value `V` is converted to an IDL `any` value by running the following algorithm:

1.  If `V` is undefined, then return the unique `undefined` IDL value.

2.  If `V` is null, then return the null `object?` reference.

3.  If `V` is a Boolean, then return the `boolean` value that represents the same truth value.

4.  If `V` is a Number, then return the result of converting `V` to an `unrestricted double`.

5.  If `V` is a BigInt, then return the result of converting `V` to a `bigint`.

6.  If `V` is a String, then return the result of converting `V` to a `DOMString`.

7.  If `V` is a Symbol, then return the result of converting `V` to a `symbol`.

8.  If `V` is an Object, then return an IDL `object` value that references `V`.

An IDL `any` value is converted to a JavaScript value according to the rules for converting the specific type of the IDL `any` value as described in the remainder of this section.


#### undefined

A JavaScript value `V` is converted to an IDL `undefined` value by returning the unique `undefined` value, ignoring `V`.

The unique IDL `undefined` value is converted to the JavaScript undefined value.


#### boolean

A JavaScript value `V` is converted to an IDL `boolean` value by running the following algorithm:

1.  Let `x` be the result of computing ToBoolean(`V`).

2.  Return the IDL `boolean` value that is the one that represents the same truth value as the JavaScript Boolean value `x`.

The IDL `boolean` value `true` is converted to the JavaScript true value and the IDL `boolean` value `false` is converted to the JavaScript false value.


#### Integer types

Mathematical operations used in this section, including those defined in ECMAScript § 5.2 Algorithm Conventions, are to be understood as computing exact mathematical results on mathematical real numbers.

In effect, where `x` is a Number value, "operating on `x`" is shorthand for "operating on the mathematical real number that represents the same numeric value as `x`".


##### byte

A JavaScript value `V` is converted to an IDL `byte` value by running the following algorithm:

1.  Let `x` be ? ConvertToInt(`V`, 8, "`signed`").

2.  Return the IDL `byte` value that represents the same numeric value as `x`.

The result of converting an IDL `byte` value to a JavaScript value is a Number that represents the same numeric value as the IDL `byte` value. The Number value will be an integer in the range [−128, 127].


##### octet

A JavaScript value `V` is converted to an IDL `octet` value by running the following algorithm:

1.  Let `x` be ? ConvertToInt(`V`, 8, "`unsigned`").

2.  Return the IDL `octet` value that represents the same numeric value as `x`.

The result of converting an IDL `octet` value to a JavaScript value is a Number that represents the same numeric value as the IDL `octet` value. The Number value will be an integer in the range [0, 255].


##### short

A JavaScript value `V` is converted to an IDL `short` value by running the following algorithm:

1.  Let `x` be ? ConvertToInt(`V`, 16, "`signed`").

2.  Return the IDL `short` value that represents the same numeric value as `x`.

The result of converting an IDL `short` value to a JavaScript value is a Number that represents the same numeric value as the IDL `short` value. The Number value will be an integer in the range [−32768, 32767].


##### unsigned short

A JavaScript value `V` is converted to an IDL `unsigned short` value by running the following algorithm:

1.  Let `x` be ? ConvertToInt(`V`, 16, "`unsigned`").

2.  Return the IDL `unsigned short` value that represents the same numeric value as `x`.

The result of converting an IDL `unsigned short` value to a JavaScript value is a Number that represents the same numeric value as the IDL `unsigned short` value. The Number value will be an integer in the range [0, 65535].


##### long

A JavaScript value `V` is converted to an IDL `long` value by running the following algorithm:

1.  Let `x` be ? ConvertToInt(`V`, 32, "`signed`").

2.  Return the IDL `long` value that represents the same numeric value as `x`.

The result of converting an IDL `long` value to a JavaScript value is a Number that represents the same numeric value as the IDL `long` value. The Number value will be an integer in the range [−2147483648, 2147483647].


##### unsigned long

A JavaScript value `V` is converted to an IDL `unsigned long` value by running the following algorithm:

1.  Let `x` be ? ConvertToInt(`V`, 32, "`unsigned`").

2.  Return the IDL `unsigned long` value that represents the same numeric value as `x`.

The result of converting an IDL `unsigned long` value to a JavaScript value is a Number that represents the same numeric value as the IDL `unsigned long` value. The Number value will be an integer in the range [0, 4294967295].


##### long long

A JavaScript value `V` is converted to an IDL `long long` value by running the following algorithm:

1.  Let `x` be ? ConvertToInt(`V`, 64, "`signed`").

2.  Return the IDL `long long` value that represents the same numeric value as `x`.

The result of converting an IDL `long long` value to a JavaScript value is a Number value that represents the closest numeric value to the `long long`, choosing the numeric value with an *even significand* if there are two equally close values. If the `long long` is in the range [−2^53^ + 1, 2^53^ − 1], then the Number will be able to represent exactly the same value as the `long long`.


##### unsigned long long

A JavaScript value `V` is converted to an IDL `unsigned long long` value by running the following algorithm:

1.  Let `x` be ? ConvertToInt(`V`, 64, "`unsigned`").

2.  Return the IDL `unsigned long long` value that represents the same numeric value as `x`.

The result of converting an IDL `unsigned long long` value to a JavaScript value is a Number value that represents the closest numeric value to the `unsigned long long`, choosing the numeric value with an *even significand* if there are two equally close values. If the `unsigned long long` is less than or equal to 2^53^ − 1, then the Number will be able to represent exactly the same value as the `unsigned long long`.


##### Abstract operations

IntegerPart(`n`):

1.  Let `r` be floor(abs(`n`)).

2.  If `n` < 0, then return -1 × `r`.

3.  Otherwise, return `r`.

ConvertToInt(`V`, `bitLength`, `signedness`):

1.  If `bitLength` is 64, then:

    1.  Let `upperBound` be 2^53^ − 1.

    2.  If `signedness` is "`unsigned`", then let `lowerBound` be 0.

    3.  Otherwise let `lowerBound` be −2^53^ + 1.

        Note: this ensures `long long` types associated with \[`EnforceRange`\] or \[`Clamp`\] extended attributes are representable in JavaScript's Number type as unambiguous integers.

2.  Otherwise, if `signedness` is "`unsigned`", then:

    1.  Let `lowerBound` be 0.

    2.  Let `upperBound` be 2^`bitLength`^ − 1.

3.  Otherwise:

    1.  Let `lowerBound` be -2^`bitLength` − 1^.

    2.  Let `upperBound` be 2^`bitLength` − 1^ − 1.

4.  Let `x` be ? ToNumber(`V`).

5.  If `x` is −0, then set `x` to +0.

6.  If the conversion is to an IDL type associated with the \[`EnforceRange`\] extended attribute, then:

    1.  If `x` is NaN, +∞, or −∞, then throw a `TypeError`.

    2.  Set `x` to IntegerPart(`x`).

    3.  If `x` < `lowerBound` or `x` > `upperBound`, then throw a `TypeError`.

    4.  Return `x`.

7.  If `x` is not NaN and the conversion is to an IDL type associated with the \[`Clamp`\] extended attribute, then:

    1.  Set `x` to min(max(`x`, `lowerBound`), `upperBound`).

    2.  Round `x` to the nearest integer, choosing the even integer if it lies halfway between two, and choosing +0 rather than −0.

    3.  Return `x`.

8.  If `x` is NaN, +0, +∞, or −∞, then return +0.

9.  Set `x` to IntegerPart(`x`).

10. Set `x` to `x` modulo 2^`bitLength`^.

11. If `signedness` is "`signed`" and `x` ≥ 2^`bitLength` − 1^, then return `x` − 2^`bitLength`^.

12. Otherwise, return `x`.


#### float

A JavaScript value `V` is converted to an IDL `float` value by running the following algorithm:

1.  Let `x` be ? ToNumber(`V`).

2.  If `x` is NaN, +∞, or −∞, then throw a `TypeError`.

3.  Let `S` be the set of finite IEEE 754 single-precision floating point values except −0, but with two special values added: 2^128^ and −2^128^.

4.  Let `y` be the number in `S` that is closest to `x`, selecting the number with an *even significand* if there are two equally close values. (The two special values 2^128^ and −2^128^ are considered to have even significands for this purpose.)

5.  If `y` is 2^128^ or −2^128^, then throw a `TypeError`.

6.  If `y` is +0 and `x` is negative, return −0.

7.  Return `y`.

The result of converting an IDL `float` value to a JavaScript value is the Number value that represents the same numeric value as the IDL `float` value.


#### unrestricted float

A JavaScript value `V` is converted to an IDL `unrestricted float` value by running the following algorithm:

1.  Let `x` be ? ToNumber(`V`).

2.  If `x` is NaN, then return the IDL `unrestricted float` value that represents the IEEE 754 NaN value with the bit pattern 0x7fc00000 [IEEE-754].

3.  Let `S` be the set of finite IEEE 754 single-precision floating point values except −0, but with two special values added: 2^128^ and −2^128^.

4.  Let `y` be the number in `S` that is closest to `x`, selecting the number with an *even significand* if there are two equally close values. (The two special values 2^128^ and −2^128^ are considered to have even significands for this purpose.)

5.  If `y` is 2^128^, return +∞.

6.  If `y` is −2^128^, return −∞.

7.  If `y` is +0 and `x` is negative, return −0.

8.  Return `y`.

Note: Since there is only a single JavaScript NaN value, it must be canonicalized to a particular single precision IEEE 754 NaN value. The NaN value mentioned above is chosen simply because it is the quiet NaN with the lowest value when its bit pattern is interpreted as an 32-bit unsigned integer.

The result of converting an IDL `unrestricted float` value to a JavaScript value is a Number:

1.  If the IDL `unrestricted float` value is a NaN, then the Number value is NaN.

2.  Otherwise, the Number value is the one that represents the same numeric value as the IDL `unrestricted float` value.


#### double

A JavaScript value `V` is converted to an IDL `double` value by running the following algorithm:

1.  Let `x` be ? ToNumber(`V`).

2.  If `x` is NaN, +∞, or −∞, then throw a `TypeError`.

3.  Return the IDL `double` value that represents the same numeric value as `x`.

The result of converting an IDL `double` value to a JavaScript value is the Number value that represents the same numeric value as the IDL `double` value.


#### unrestricted double

A JavaScript value `V` is converted to an IDL `unrestricted double` value by running the following algorithm:

1.  Let `x` be ? ToNumber(`V`).

2.  If `x` is NaN, then return the IDL `unrestricted double` value that represents the IEEE 754 NaN value with the bit pattern 0x7ff8000000000000 [IEEE-754].

3.  Return the IDL `unrestricted double` value that represents the same numeric value as `x`.

Note: Since there is only a single JavaScript NaN value, it must be canonicalized to a particular double precision IEEE 754 NaN value. The NaN value mentioned above is chosen simply because it is the quiet NaN with the lowest value when its bit pattern is interpreted as an 64-bit unsigned integer.

The result of converting an IDL `unrestricted double` value to a JavaScript value is a Number:

1.  If the IDL `unrestricted double` value is a NaN, then the Number value is NaN.

2.  Otherwise, the Number value is the one that represents the same numeric value as the IDL `unrestricted double` value.


#### bigint

A JavaScript value `V` is converted to an IDL `bigint` value by running the following algorithm:

1.  Let `x` be ? ToBigInt(`V`).

2.  Return the IDL `bigint` value that represents the same numeric value as `x`.

The result of converting an IDL `bigint` value to a JavaScript value is a BigInt:

1.  Return the `BigInt` value that represents the same numeric value as the IDL `bigint` value.

A JavaScript value `V` is converted to a numeric type or bigint to an IDL numeric type `T` or `bigint` value by running the following algorithm:

1.  Let `x` be ? ToNumeric(`V`).

2.  If `x` is a BigInt, then

    1.  Return the IDL `bigint` value that represents the same numeric value as `x`.

3.  Assert: `x` is a Number.

4.  Return the result of converting `x` to `T`.


#### DOMString

A JavaScript value `V` is converted to an IDL `DOMString` value by running the following algorithm:

1.  If `V` is null and the conversion is to an IDL type associated with the \[`LegacyNullToEmptyString`\] extended attribute, then return the `DOMString` value that represents the empty string.

2.  Let `x` be ? ToString(`V`).

3.  Return the IDL `DOMString` value that represents the same sequence of code units as the one the JavaScript String value `x` represents.

The result of converting an IDL `DOMString` value to a JavaScript value is the String value that represents the same sequence of code units that the IDL `DOMString` represents.


#### ByteString

A JavaScript value `V` is converted to an IDL `ByteString` value by running the following algorithm:

1.  Let `x` be ? ToString(`V`).

2.  If the value of any element of `x` is greater than 255, then throw a `TypeError`.

3.  Return an IDL `ByteString` value whose length is the length of `x`, and where the value of each element is the value of the corresponding element of `x`.

The result of converting an IDL `ByteString` value to a JavaScript value is a String value whose length is the length of the `ByteString`, and the value of each element of which is the value of the corresponding element of the `ByteString`.


#### USVString

A JavaScript value `V` is converted to an IDL `USVString` value by running the following algorithm:

1.  Let `string` be the result of converting `V` to a `DOMString`.

2.  Return an IDL `USVString` value that is the result of converting `string` to a sequence of scalar values.

The result of converting an IDL `USVString` value `S` to a JavaScript value is `S`.


#### object

IDL `object` values are represented by JavaScript Object values.

A JavaScript value `V` is converted to an IDL `object` value by running the following algorithm:

1.  If `V` is not an Object, then throw a `TypeError`.

2.  Return the IDL `object` value that is a reference to the same object as `V`.

The result of converting an IDL `object` value to a JavaScript value is the Object value that represents a reference to the same object that the IDL `object` represents.


#### symbol

IDL `symbol` values are represented by JavaScript Symbol values.

A JavaScript value `V` is converted to an IDL `symbol` value by running the following algorithm:

1.  If `V` is not a Symbol, then throw a `TypeError`.

2.  Return the IDL `symbol` value that is a reference to the same symbol as `V`.

The result of converting an IDL `symbol` value to a JavaScript value is the Symbol value that represents a reference to the same symbol that the IDL `symbol` represents.


#### Interface types

IDL interface type values are represented by JavaScript Object values (including function objects).

A JavaScript value `V` is converted to an IDL interface type value by running the following algorithm (where `I` is the interface):

1.  If `V` implements `I`, then return the IDL interface type value that represents a reference to that platform object.

2.  Throw a `TypeError`.

The result of converting an IDL interface type value to a JavaScript value is the Object value that represents a reference to the same object that the IDL interface type value represents.


#### Callback interface types

IDL callback interface type values are represented by JavaScript Object values (including function objects).

A JavaScript value `V` is converted to an IDL callback interface type value by running the following algorithm:

1.  If `V` is not an Object, then throw a `TypeError`.

2.  Return the IDL callback interface type value that represents a reference to `V`, with the incumbent settings object as the callback context.

The result of converting an IDL callback interface type value to a JavaScript value is the Object value that represents a reference to the same object that the IDL callback interface type value represents.


#### Dictionary types

IDL dictionary type values are represented by JavaScript Object values. Properties on the object (or its prototype chain) correspond to dictionary members.

A JavaScript value `jsDict` is converted to an IDL dictionary type value by running the following algorithm (where `D` is the dictionary type):

1.  If `jsDict` is not an Object and `jsDict` is neither undefined nor null, then throw a `TypeError`.

2.  Let `idlDict` be an empty ordered map, representing a dictionary of type `D`.

3.  Let `dictionaries` be a list consisting of `D` and all of `D`'s inherited dictionaries, in order from least to most derived.

4.  For each dictionary `dictionary` in `dictionaries`, in order:

    1.  For each dictionary member `member` declared on `dictionary`, in lexicographical order:

        1.  Let `key` be the identifier of `member`.

        2.  If `jsDict` is either undefined or null, then:

            1.  Let `jsMemberValue` be undefined.

        3.  Otherwise,

            1.  Let `jsMemberValue` be ? Get(`jsDict`, `key`).

        4.  If `jsMemberValue` is not undefined, then:

            1.  Let `idlMemberValue` be the result of converting `jsMemberValue` to an IDL value whose type is the type `member` is declared to be of.

            2.  Set `idlDict`[`key`] to `idlMemberValue`.

        5.  Otherwise, if `jsMemberValue` is undefined but `member` has a default value, then:

            1.  Let `idlMemberValue` be `member`'s default value.

            2.  Set `idlDict`[`key`] to `idlMemberValue`.

        6.  Otherwise, if `jsMemberValue` is undefined and `member` is required, then throw a `TypeError`.

5.  Return `idlDict`.

Note: The order that dictionary members are looked up on the JavaScript object are not necessarily the same as the object's property enumeration order.

An IDL dictionary value `V` is converted to a JavaScript Object value by running the following algorithm (where `D` is the dictionary):

1.  Let `O` be OrdinaryObjectCreate(`%Object.prototype%`).

2.  Let `dictionaries` be a list consisting of `D` and all of `D`'s inherited dictionaries, in order from least to most derived.

3.  For each dictionary `dictionary` in `dictionaries`, in order:

    1.  For each dictionary member `member` declared on `dictionary`, in lexicographical order:

        1.  Let `key` be the identifier of `member`.

        2.  If `V`[`key`] exists, then:

            1.  Let `idlValue` be `V`[`key`].

            2.  Let `value` be the result of converting `idlValue` to a JavaScript value.

            3.  Perform ! CreateDataPropertyOrThrow(`O`, `key`, `value`).

            Recall that if `member` has a default value, then `key` will always exist in `V`.

4.  Return `O`.


#### Enumeration types

IDL enumeration types are represented by JavaScript String values.

A JavaScript value `V` is converted to an IDL enumeration type value as follows (where `E` is the enumeration):

1.  Let `S` be the result of calling ? ToString(`V`).

2.  If `S` is not one of `E`'s enumeration values, then throw a `TypeError`.

3.  Return the enumeration value of type `E` that is equal to `S`.

The result of converting an IDL enumeration type value to a JavaScript value is the String value that represents the same sequence of code units as the enumeration value.


#### Callback function types

IDL callback function types are represented by JavaScript function objects, except in the \[`LegacyTreatNonObjectAsNull`\] case, when they can be any object.

A JavaScript value `V` is converted to an IDL callback function type value by running the following algorithm:

1.  If the result of calling IsCallable(`V`) is false and the conversion to an IDL value is not being performed due to `V` being assigned to an attribute whose type is a nullable callback function that is annotated with \[`LegacyTreatNonObjectAsNull`\], then throw a `TypeError`.

2.  Return the IDL callback function type value that represents a reference to the same object that `V` represents, with the incumbent settings object as the callback context.

The result of converting an IDL callback function type value to a JavaScript value is a reference to the same object that the IDL callback function type value represents.


#### Nullable types --- `T`?

IDL nullable type values are represented by values of either the JavaScript type corresponding to the inner IDL type, or the JavaScript null value.

A JavaScript value `V` is converted to an IDL nullable type `T`? value (where `T` is the inner type) as follows:

1.  If `V` is not an Object, and the conversion to an IDL value is being performed due to `V` being assigned to an attribute whose type is a nullable callback function that is annotated with \[`LegacyTreatNonObjectAsNull`\], then return the IDL nullable type `T`? value null.

2.  Otherwise, if `V` is undefined, and `T` includes undefined, return the unique `undefined` value.

3.  Otherwise, if `V` is null or undefined, then return the IDL nullable type `T`? value null.

4.  Otherwise, return the result of converting `V` using the rules for the inner IDL type `T`.

The result of converting an IDL nullable type value to a JavaScript value is:

1.  If the IDL nullable type `T`? value is null, then the JavaScript value is null.

2.  Otherwise, the JavaScript value is the result of converting the IDL nullable type value to the inner IDL type `T`.


#### Sequences --- sequence<`T`>

IDL sequence<`T`> values are represented by JavaScript Array values.

A JavaScript value `V` is converted to an IDL sequence<`T`> value as follows:

1.  If `V` is not an Object, throw a `TypeError`.

2.  Let `method` be ? GetMethod(`V`, `%Symbol.iterator%`).

3.  If `method` is undefined, throw a `TypeError`.

4.  Return the result of creating a sequence from `V` and `method`.

An IDL sequence value `S` of type sequence<`T`> is converted to a JavaScript Array object as follows:

1.  Let `n` be the length of `S`.

2.  Let `A` be a new Array object created as if by the expression `[]`.

3.  Initialize `i` to be 0.

4.  While `i` < `n`:

    1.  Let `V` be the value in `S` at index `i`.

    2.  Let `E` be the result of converting `V` to a JavaScript value.

    3.  Let `P` be the result of calling ! ToString(`i`).

    4.  Perform ! CreateDataPropertyOrThrow(`A`, `P`, `E`).

    5.  Set `i` to `i` + 1.

5.  Return `A`.


##### Creating a sequence from an iterable

To create an IDL value of type sequence<`T`> given an iterable `iterable` and an iterator getter `method`, perform the following steps:

1.  Let `iteratorRecord` be ? GetIteratorFromMethod(`iterable`, `method`).

2.  Initialize `i` to be 0.

3.  Repeat

    1.  Let `next` be ? IteratorStepValue(`iteratorRecord`).

    2.  If `next` is done, then return an IDL sequence value of type sequence<`T`> of length `i`, where the value of the element at index `j` is S~j~.

    3.  Initialize S~i~ to the result of converting `next` to an IDL value of type `T`.

    4.  Set `i` to `i` + 1.

The following interface defines an attribute of a sequence type as well as an operation with an argument of a sequence type.

```
[Exposed=Window]
interface Canvas {

  sequence<DOMString> getSupportedImageCodecs();

  undefined drawPolygon(sequence<double> coordinates);
  sequence<double> getLastDrawnPolygon();

  // ...
};
```

In a JavaScript implementation of this interface, an Array object with elements of type String is used to represent a `sequence<DOMString>`, while an Array with elements of type Number represents a `sequence<double>`. The Array objects are effectively passed by value; every time the `getSupportedImageCodecs()` function is called a new Array is returned, and whenever an Array is passed to `drawPolygon` no reference will be kept after the call completes.

```
// Obtain an instance of Canvas.  Assume that getSupportedImageCodecs()
// returns a sequence with two DOMString values: "image/png" and "image/svg+xml".
var canvas = getCanvas();

// An Array object of length 2.
var supportedImageCodecs = canvas.getSupportedImageCodecs();

// Evaluates to "image/png".
supportedImageCodecs[0];

// Each time canvas.getSupportedImageCodecs() is called, it returns a
// new Array object.  Thus modifying the returned Array will not
// affect the value returned from a subsequent call to the function.
supportedImageCodecs[0] = "image/jpeg";

// Evaluates to "image/png".
canvas.getSupportedImageCodecs()[0];

// This evaluates to false, since a new Array object is returned each call.
canvas.getSupportedImageCodecs() == canvas.getSupportedImageCodecs();

// An Array of Numbers...
var a = [0, 0, 100, 0, 50, 62.5];

// ...can be passed to a platform object expecting a sequence<double>.
canvas.drawPolygon(a);

// Each element will be converted to a double by first calling ToNumber().
// So the following call is equivalent to the previous one, except that
// "hi" will be alerted before drawPolygon() returns.
a = [false, "",
     { valueOf: function() { alert("hi"); return 100; } }, 0,
     "50", new Number(62.5)];
canvas.drawPolygon(a);

// Modifying an Array that was passed to drawPolygon() is guaranteed not to
// have an effect on the Canvas, since the Array is effectively passed by value.
a[4] = 20;
var b = canvas.getLastDrawnPolygon();
alert(b[4]);    // This would alert "50".
```


#### Async sequences --- async_sequence<`T`>

In the JavaScript binding, IDL async sequence values are represented by a struct with the following items:

- object, a JavaScript value

- method, a JavaScript value

- type, either "`sync`" or "`async`"

A JavaScript value `V` is converted to an IDL async_sequence<`T`> value as follows:

1.  If `V` is not an Object, then throw a `TypeError`.

2.  Let `method` be ? GetMethod(obj, `%Symbol.asyncIterator%`).

3.  If `method` is undefined:

    1.  Set `syncMethod` to ? GetMethod(obj, `%Symbol.iterator%`).

    2.  If `syncMethod` is undefined, throw a `TypeError`.

    3.  Return an IDL async sequence value with object set to `V`, method set to `syncMethod`, and type set to "`sync`".

4.  Return an IDL async sequence value with object set to `V`, method set to `method`, and type set to "`async`".

An IDL async_sequence<`T`> value `V` is converted to a JavaScript object as follows:

1.  Return `V`'s object.


##### Iterating async sequences

An async sequence is not directly iterated over. Instead, it is first opened to create an async iterator. The async iterator can be asynchronously iterated over to produce values.

Async iterators are structs with the following items:

- underlying record, an Iterator Record

- type parameter, an IDL type representing the type of values produced by the async iterator

To open an `async_sequence<T>` `sequence`:

1.  Let `iterator` be ? GetIteratorFromMethod(`sequence`'s object, `sequence`'s method).

2.  If `sequence`'s type is "`sync`", set `iterator` to CreateAsyncFromSyncIterator(`iterator`).

3.  Return an async iterator value with underlying record set to `iterator` and type parameter set to `T`.

To get the next value of an async iterator `iterator`:

1.  Let `nextResult` be IteratorNext(`iterator`'s underlying record).

2.  If `nextResult` is an abrupt completion, return a promise rejected with `nextResult`.[[Value]].

3.  Let `nextPromise` be a promise resolved with `nextResult`.[[Value]].

4.  Return the result of reacting to `nextPromise` with the following fulfillment steps, given `iterResult`:

    1.  If `iterResult` is not an Object, throw a `TypeError`.

    2.  Let `done` be ? IteratorComplete(`iterResult`).

    3.  If `done` is true:

        1.  Return end of iteration.

    4.  Otherwise:

        1.  Let `V` be ? IteratorValue(`iterResult`).

        2.  Let `value` be the result of converting `V` to an IDL value of type `iterator`'s type parameter.

        3.  Return `value`.

To close an `async iterator<T>` `iterator`, with an ECMAScript value `reason`:

1.  Let `iteratorRecord` be `iterator`'s underlying record.

2.  Let `iteratorObj` be `iteratorRecord`.[[Iterator]].

3.  Let `returnMethod` be GetMethod(`iteratorObj`, "`return`").

4.  If `returnMethod` is an abrupt completion, return a promise rejected with `returnMethod`.[[Value]].

5.  If `returnMethod` is undefined, return a promise resolved with `undefined`.

6.  Let `returnResult` be Call(`returnMethod`.[[Value]], `iteratorObj`, « `reason` »).

7.  If `returnResult` is an abrupt completion, return a promise rejected with `returnResult`.[[Value]].

8.  Let `returnPromise` be a promise resolved with `returnResult`.[[Value]].

9.  Return the result of reacting to `returnPromise` with the following fulfillment steps, given `returnPromiseResult`:

    1.  If `returnPromiseResult` is not an Object, throw a `TypeError`.

    2.  Return `undefined`.

`concatN` is an operation that returns a promise that will be fulfilled with the concatenation of all the strings yielded by the async sequence passed to it. It stops concatenating and closes the iterator once the async sequence has yielded `maxN` strings.

    interface I {
      Promise<DOMString> concatN(async_sequence<DOMString> strings, unsigned long maxN);
    };

The `concatN(sequence, maxN)` method steps are:

1.  Let `promise` be a new promise.

2.  Let `result` be the empty string.

3.  Let `n` be 0.

4.  Let `iterator` be the result of opening `sequence`.

5.  Let `step` be a sequence of steps that will be used to process the async sequence:

    1.  Let `next` be the result of getting the next value of `iterator`.

    2.  React to `next`:

        - If `next` was fulfilled with value `v`:

          1.  If `v` is end of iteration, resolve `promise` with `result`.

          2.  Set `result` to the result of concatenating `result` and `v`.

          3.  Set `n` to `n` + 1.

          4.  If `n` is `maxN`, then:

              1.  Let `finish` be the result of closing `iterator` with reason `undefined`.

              2.  React to `finish`:

                  - If `finish` was fulfilled, resolve `promise` with `result`.

                  - If `finish` was rejected with reason `r`, reject `promise` with `r`.

          5.  Otherwise:

              1.  Call `step`.

        - If `next` was rejected with reason `r`, reject `promise` with `r`.

6.  Call `step`.

7.  Return `promise`.


#### Records --- record<`K`, `V`>

IDL record<`K`, `V`> values are represented by JavaScript Object values.

A JavaScript value `O` is converted to an IDL `record`<`K`, `V`> value as follows:

1.  If `O` is not an Object, throw a `TypeError`.

2.  Let `result` be a new empty instance of `record`<`K`, `V`>.

3.  Let `keys` be ? `O`.[[OwnPropertyKeys]]().

4.  For each `key` of `keys`:

    1.  Let `desc` be ? `O`.[[GetOwnProperty]](`key`).

    2.  If `desc` is not undefined and `desc`.[[Enumerable]] is true:

        1.  Let `typedKey` be `key` converted to an IDL value of type `K`.

        2.  Let `value` be ? Get(`O`, `key`).

        3.  Let `typedValue` be `value` converted to an IDL value of type `V`.

        4.  Set `result`[`typedKey`] to `typedValue`.

            Note: It's possible that `typedKey` is already in `result`, if `K` is `USVString` and `key` contains unpaired surrogates.

5.  Return `result`.

An IDL `record`<…> value `D` is converted to a JavaScript value as follows:

1.  Let `result` be OrdinaryObjectCreate(`%Object.prototype%`).

2.  For each `key` → `value` of `D`:

    1.  Let `jsKey` be `key` converted to a JavaScript value.

    2.  Let `jsValue` be `value` converted to a JavaScript value.

    3.  Let `created` be ! CreateDataProperty(`result`, `jsKey`, `jsValue`).

    4.  Assert: `created` is true.

3.  Return `result`.

Passing the JavaScript value `{b: 3, a: 4}` as a `record`<DOMString, double> argument would result in the IDL value «[ "`b`" → 3, "`a`" → 4 ]».

Records only consider own enumerable properties, so given an IDL operation `record<DOMString, double> identity(record<DOMString, double> arg)` which returns its argument, the following code passes its assertions:

```
let proto = {a: 3, b: 4};
let obj = {__proto__: proto, d: 5, c: 6}
Object.defineProperty(obj, "e", {value: 7, enumerable: false});
let result = identity(obj);
console.assert(result.a === undefined);
console.assert(result.b === undefined);
console.assert(result.e === undefined);
let entries = Object.entries(result);
console.assert(entries[0][0] === "d");
console.assert(entries[0][1] === 5);
console.assert(entries[1][0] === "c");
console.assert(entries[1][1] === 6);
```

Record keys and values can be constrained, although keys can only be constrained among the three string types. The following conversions have the described results:

  Value                            Passed to type                                                                        Result
  -------------------------------- ------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------
  `{"😞": 1}`                      `record`<ByteString, double>   `TypeError`
  `{"\uD83D": 1}`                  `record`<USVString, double>    «[ "`\uFFFD`" → 1 ]»
  `{"\uD83D": {hello: "world"}}`   `record`<DOMString, double>    «[ "`\uD83D`" → 0 ]»


#### Promise types --- Promise<`T`>

IDL promise type values are represented by JavaScript PromiseCapability records.

A JavaScript value `V` is converted to an IDL `Promise`<`T`> value as follows:

1.  Let `promiseCapability` be ? NewPromiseCapability(`%Promise%`).

2.  Perform ? Call(`promiseCapability`.[[Resolve]], undefined, « `V` »).

3.  Return `promiseCapability`.

The result of converting an IDL promise type value to a JavaScript value is the value of the [[Promise]] field of the record that IDL promise type represents.


##### Creating and manipulating Promises

To create a new `Promise`<`T`> in a realm `realm`, perform the following steps:

1.  Let `constructor` be `realm`.[[Intrinsics]].[[`%Promise%`]].

2.  Return ? NewPromiseCapability(`constructor`).

To create a resolved promise of type `Promise`<`T`>, with `x` (a value of type `T`) in a realm `realm`, perform the following steps:

1.  Let `value` be the result of converting `x` to a JavaScript value.

2.  Let `constructor` be `realm`.[[Intrinsics]].[[`%Promise%`]].

3.  Let `promiseCapability` be ? NewPromiseCapability(`constructor`).

4.  Perform ! Call(`promiseCapability`.[[Resolve]], undefined, « `value` »).

5.  Return `promiseCapability`.

To create a rejected promise of type `Promise`<`T`>, with reason `r` (a JavaScript value) in a realm `realm`, perform the following steps:

1.  Let `constructor` be `realm`.[[Intrinsics]].[[`%Promise%`]].

2.  Let `promiseCapability` be ? NewPromiseCapability(`constructor`).

3.  Perform ! Call(`promiseCapability`.[[Reject]], undefined, « `r` »).

4.  Return `promiseCapability`.

To resolve a `Promise`<`T`> `p` with `x` (a value of type `T`), perform the following steps:

1.  If `x` is not given, then let it be the `undefined` value.

2.  Let `value` be the result of converting `x` to a JavaScript value.

3.  Perform ! Call(`p`.[[Resolve]], undefined, « `value` »).

If `T` is `undefined`, then the `x` argument is optional, allowing a simpler "resolve p" usage.

To reject a `Promise`<`T`> `p` with reason `r` (a JavaScript value), perform the following steps:

1.  Perform ! Call(`p`.[[Reject]], undefined, « `r` »).

To react to a `Promise`<`T`> `promise`, given one or two sets of steps to perform, covering when the promise is fulfilled, rejected, or both, perform the following steps:

1.  Let `onFulfilledSteps` be the following steps given argument `V`:

    1.  Let `value` be the result of converting `V` to an IDL value of type `T`.

    2.  If there is a set of steps to be run if the promise was fulfilled, then let `result` be the result of performing them, given `value` if `T` is not `undefined`. Otherwise, let `result` be `value`.

    3.  Return `result`, converted to a JavaScript value.

2.  Let `onFulfilled` be CreateBuiltinFunction(`onFulfilledSteps`, « »):

3.  Let `onRejectedSteps` be the following steps given argument `R`:

    1.  Let `reason` be the result of converting `R` to an IDL value of type `any`.

    2.  If there is a set of steps to be run if the promise was rejected, then let `result` be the result of performing them, given `reason`. Otherwise, let `result` be a promise rejected with `reason`.

    3.  Return `result`, converted to a JavaScript value.

4.  Let `onRejected` be CreateBuiltinFunction(`onRejectedSteps`, « »):

5.  Let `constructor` be `promise`.[[Promise]].[[Realm]].[[Intrinsics]].[[`%Promise%`]].

6.  Let `newCapability` be ? NewPromiseCapability(`constructor`).

    Note: Not all callers will use the returned `Promise`. Implementations might wish to avoid creating `newCapability` in those cases.

7.  Perform PerformPromiseThen(`promise`.[[Promise]], `onFulfilled`, `onRejected`, `newCapability`).

8.  Return `newCapability`.

Note: This algorithm will behave in a very similar way to the `promise.then()` method. In particular, if the steps return a value of type `U` or `Promise`<`U`>, this algorithm returns a `Promise`<`U`> as well.

To perform some steps upon fulfillment of a `Promise`<`T`> `promise` given some steps `steps` taking a value of type `T`, perform the following steps:

1.  Return the result of reacting to `promise`:

    - If `promise` was fulfilled with value `v`, then:

      1.  Perform `steps` with `v`.

To perform some steps upon rejection of a `Promise`<`T`> `promise` given some steps `steps` taking a JavaScript value, perform the following steps:

1.  Return the result of reacting to `promise`:

    - If `promise` was rejected with reason `r`, then:

      1.  Perform `steps` with `r`.

To wait for all with a list of `Promise`<`T`> values `promises`, with success steps `successSteps` that take a list of `T` values and failure steps `failureSteps` that take a rejection reason `any` value, perform the following steps:

1.  Let `fullfilledCount` be 0.

2.  Let `rejected` be false.

3.  Let `rejectionHandlerSteps` be the following steps given `arg`:

    1.  If `rejected` is true, abort these steps.

    2.  Set `rejected` to true.

    3.  Perform `failureSteps` given `arg`.

4.  Let `rejectionHandler` be CreateBuiltinFunction(`rejectionHandlerSteps`, « »):

5.  Let `total` be `promises`'s size.

6.  If `total` is 0, then:

    1.  Queue a microtask to perform `successSteps` given « ».

    2.  Return.

7.  Let `index` be 0.

8.  Let `result` be a list containing `total` null values.

9.  For each `promise` of `promises`:

    1.  Let `promiseIndex` be `index`.

    2.  Let `fulfillmentHandler` be the following steps given `arg`:

        1.  Set `result`[`promiseIndex`] to `arg`.

        2.  Set `fullfilledCount` to `fullfilledCount` + 1.

        3.  If `fullfilledCount` equals `total`, then perform `successSteps` given `result`.

    3.  Let `fulfillmentHandler` be CreateBuiltinFunction(`fulfillmentHandler`, « »):

    4.  Perform PerformPromiseThen(`promise`, `fulfillmentHandler`, `rejectionHandler`).

    5.  Set `index` to `index` + 1.

To get a promise for waiting for all with a list of `Promise`<`T`> values `promises` and a realm `realm`, perform the following steps:

1.  Let `promise` be a new promise of type `Promise`<`sequence`<`T`>> in `realm`.

2.  Let `successSteps` be the following steps, given `results`:

    1.  Resolve `promise` with `results`.

3.  Let `failureSteps` be the following steps, given `reason`:

    1.  Reject `promise` with `reason`.

4.  Wait for all with `promises`, given `successSteps` and `failureSteps`.

5.  Return `promise`.

This definition is useful when you wish to aggregate the results of multiple promises, and then produce another promise from them, in the same way that `Promise.all()` functions for JavaScript code. If you do not need to produce another promise, then waiting for all is likely better.

To mark as handled a `Promise`<`T`> `promise`, set `promise`.[[Promise]].[[PromiseIsHandled]] to true.

This definition is useful for promises for which you expect rejections to often be ignored; it ensures such promises do not cause `unhandledrejection` events. The most common use case is for promise properties, which the web developer might or might not consult. An example is the `writableStreamWriter.closed` promise.


##### Examples

`delay` is an operation that returns a promise that will be fulfilled in a number of milliseconds. It illustrates how simply you can resolve a promise, with one line of prose.

```
interface I {
  Promise<undefined> delay(unrestricted double ms);
};
```

The `delay(ms)` method steps are:

1.  Let `realm` be this's relevant realm.

2.  Let `taskSource` be some appropriate task source.

3.  If `ms` is NaN, let `ms` be +0; otherwise let `ms` be the maximum of `ms` and +0.

4.  Let `p` be a new promise in `realm`.

5.  Run the following steps in parallel:

    1.  Wait `ms` milliseconds.

    2.  Queue a task on `taskSource` to resolve `p`.

6.  Return `p`.

The `validatedDelay` operation is much like the `delay` function, except it will validate its arguments. This shows how to use rejected promises to signal immediate failure before even starting any asynchronous operations.

```
interface I {
  Promise<undefined> validatedDelay(unrestricted double ms);
};
```

The `validatedDelay(ms)` method steps are:

1.  Let `realm` be this's relevant realm.

2.  Let `taskSource` be some appropriate task source.

3.  If `ms` is NaN, return a promise rejected with a `TypeError` in `realm`.

4.  If `ms` < 0, return a promise rejected with a `RangeError` in `realm`.

5.  Let `p` be a new promise in `realm`.

6.  Run the following steps in parallel:

    1.  Wait `ms` milliseconds.

    2.  Queue a task on `taskSource` to resolve `p`.

7.  Return `p`.

`addDelay` is an operation that adds an extra number of milliseconds of delay between `promise` settling and the returned promise settling.

```
interface I {
  Promise<any> addDelay(Promise<any> promise, unrestricted double ms);
};
```

The `addDelay(ms, promise)` method steps are:

1.  Let `realm` be this's relevant realm.

2.  Let `taskSource` be some appropriate task source.

3.  If `ms` is NaN, let `ms` be +0; otherwise let `ms` be the maximum of `ms` and +0.

4.  Let `p` be a new promise in `realm`.

5.  React to `promise`:

    - If `promise` was fulfilled with value `v`, then:

      1.  Run the following steps in parallel:

          1.  Wait `ms` milliseconds.

          2.  Queue a task on `taskSource` to resolve `p` with `v`.

    - If `promise` was rejected with reason `r`, then:

      1.  Run the following steps in parallel:

          1.  Wait `ms` milliseconds.

          2.  Queue a task on `taskSource` to reject `p` with `r`.

6.  Return `p`.

`environment.ready` is an attribute that signals when some part of some environment, e.g. a DOM document, becomes "ready". It illustrates how to encode environmental asynchronicity.

```
interface Environment {
  readonly attribute Promise<undefined> ready;
};
```

Every `Environment` object must have a ready promise, which is a `Promise`<`undefined`>.

The `ready` attribute getter steps are:

1.  Return this's ready promise.

To create an `Environment` object in a realm `realm`, perform the following steps:

1.  Let `taskSource` be some appropriate task source.

2.  Let `environment` be new `Environment` object in `realm`.

3.  Set `environment`'s ready promise to a new promise in `realm`.

4.  Run the following steps in parallel:

    1.  Do some asynchronous work.

    2.  If `environment` becomes ready successfully, then queue a task on `taskSource` to resolve `environment`'s ready promise.

    3.  If `environment` fails to become ready, then queue a task on `taskSource` to reject `environment`'s ready promise with a "`NetworkError`" `DOMException`.

5.  Return `environment`.

`addBookmark` is an operation that requests that the user add the current web page as a bookmark. It's drawn from some iterative design work and illustrates a more real-world scenario of appealing to environmental asynchrony, as well as immediate rejections.

```
interface I {
  Promise<undefined> addBookmark();
};
```

The `addBookmark()` method steps are:

1.  Let `taskSource` be some appropriate task source.

2.  If this method was not invoked as a result of explicit user action, return a promise rejected with a "`SecurityError`" `DOMException`.

3.  If the document's mode of operation is standalone, return a promise rejected with a "`NotSupportedError`" `DOMException`.

4.  Let `promise` be a new promise.

5.  Let `info` be the result of getting a web application's metadata.

6.  Run the following steps in parallel:

    1.  Using `info`, and in a manner that is user-agent specific, allow the end user to make a choice as to whether they want to add the bookmark.

        1.  If the end-user aborts the request to add the bookmark (e.g., they hit escape, or press a "cancel" button), then queue a task on `taskSource` to reject `promise` with an "`AbortError`" `DOMException`.

        2.  Otherwise, queue a task on `taskSource` to resolve `promise`.

7.  Return `promise`.

Several places in [SERVICE-WORKERS] use get a promise to wait for all. `batchRequest` illustrates a simplified version of one of their uses. It takes as input a sequence of URLs, and returns a promise for a sequence of `Response` objects created by fetching the corresponding URL. If any of the fetches fail, it will return a promise rejected with that failure.

```
interface I {
  Promise<sequence<Response>> batchRequest(sequence<USVString> urls);
};
```

The `batchRequest(urls)` method steps are:

1.  Let `responsePromises` be « ».

2.  For each `url` of `urls`:

    1.  Let `p` be the result of calling `fetch()` with `url`.

    2.  Append `p` to `responsePromises`.

3.  Let `p` be the result of getting a promise to wait for all with `responsePromises`.

4.  Return `p`.


#### Union types

IDL union type values are represented by JavaScript values that correspond to the union's member types.

To convert a JavaScript value `V` to an IDL union type value is done as follows:

1.  If the union type includes undefined and `V` is undefined, then return the unique `undefined` value.

2.  If the union type includes a nullable type and `V` is null or undefined, then return the IDL value null.

3.  Let `types` be the flattened member types of the union type.

4.  If `V` is null or undefined, then:

    1.  If `types` includes a dictionary type, then return the result of converting `V` to that dictionary type.

5.  If `V` is a platform object, then:

    1.  If `types` includes an interface type that `V` implements, then return the IDL value that is a reference to the object `V`.

    2.  If `types` includes `object`, then return the IDL value that is a reference to the object `V`.

6.  If `V` is an Object, `V` has an [[ArrayBufferData]] internal slot, and IsSharedArrayBuffer(`V`) is false, then:

    1.  If `types` includes `ArrayBuffer`, then return the result of converting `V` to `ArrayBuffer`.

    2.  If `types` includes `object`, then return the IDL value that is a reference to the object `V`.

7.  If `V` is an Object, `V`, has an [[ArrayBufferData]] internal slot, and IsSharedArrayBuffer(`V`) is true, then:

    1.  If `types` includes `SharedArrayBuffer`, then return the result of converting `V` to `SharedArrayBuffer`.

    2.  If `types` includes `object`, then return the IDL value that is a reference to the object `V`.

8.  If `V` is an Object and `V` has a [[DataView]] internal slot, then:

    1.  If `types` includes `DataView`, then return the result of converting `V` to `DataView`.

    2.  If `types` includes `object`, then return the IDL value that is a reference to the object `V`.

9.  If `V` is an Object and `V` has a [[TypedArrayName]] internal slot, then:

    1.  If `types` includes a typed array type whose name is the value of `V`'s [[TypedArrayName]] internal slot, then return the result of converting `V` to that type.

    2.  If `types` includes `object`, then return the IDL value that is a reference to the object `V`.

10. If IsCallable(`V`) is true, then:

    1.  If `types` includes a callback function type, then return the result of converting `V` to that callback function type.

    2.  If `types` includes `object`, then return the IDL value that is a reference to the object `V`.

11. If `V` is an Object, then:

    1.  If `types` includes an async sequence type, then

        1.  If `types` does not include a string type or `V` does not have a [[StringData]] internal slot, then

            1.  Let `asyncMethod` be ? GetMethod(`V`, `%Symbol.asyncIterator%`).

            2.  If `asyncMethod` is not undefined, return an IDL async sequence value with object set to `V`, method set to `syncMethod`, and type set to "`async`".

            3.  Let `syncMethod` be ? GetMethod(`V`, `%Symbol.iterator%`).

            4.  If `syncMethod` is not undefined, return an IDL async sequence value with object set to `V`, method set to `syncMethod`, and type set to "`sync`".

    2.  If `types` includes a sequence type, then

        1.  Let `method` be ? GetMethod(`V`, `%Symbol.iterator%`).

        2.  If `method` is not undefined, return the result of creating a sequence of that type from `V` and `method`.

    3.  If `types` includes a frozen array type, then

        1.  Let `method` be ? GetMethod(`V`, `%Symbol.iterator%`).

        2.  If `method` is not undefined, return the result of creating a frozen array of that type from `V` and `method`.

    4.  If `types` includes a dictionary type, then return the result of converting `V` to that dictionary type.

    5.  If `types` includes a record type, then return the result of converting `V` to that record type.

    6.  If `types` includes a callback interface type, then return the result of converting `V` to that callback interface type.

    7.  If `types` includes `object`, then return the IDL value that is a reference to the object `V`.

12. If `V` is a Boolean, then:

    1.  If `types` includes `boolean`, then return the result of converting `V` to `boolean`.

13. If `V` is a Number, then:

    1.  If `types` includes a numeric type, then return the result of converting `V` to that numeric type.

14. If `V` is a BigInt, then:

    1.  If `types` includes `bigint`, then return the result of converting `V` to `bigint`

15. If `types` includes a string type, then return the result of converting `V` to that type.

16. If `types` includes a numeric type and `bigint`, then return the result of converting `V` to either that numeric type or `bigint`.

17. If `types` includes a numeric type, then return the result of converting `V` to that numeric type.

18. If `types` includes `boolean`, then return the result of converting `V` to `boolean`.

19. If `types` includes `bigint`, then return the result of converting `V` to `bigint`.

20. Throw a `TypeError`.

An IDL union type value is converted to a JavaScript value according to the rules for converting the specific type of the IDL union type value as described in this section (§ 3.2 JavaScript type mapping).


#### Buffer source types

A value of an IDL `ArrayBuffer` is represented by an object of the corresponding JavaScript class. If it is not associated with the \[`AllowResizable`\] extended attribute, it can only be backed by JavaScript `ArrayBuffer` objects `V` for which IsFixedLengthArrayBuffer(`V`) is true.

A value of an IDL `SharedArrayBuffer` is represented by an object of the corresponding JavaScript class. If it is not associated with the \[`AllowResizable`\] extended attribute, it can only be backed by JavaScript `SharedArrayBuffer` objects `V` for which IsFixedLengthArrayBuffer(`V`) is true.

Values of the IDL buffer view types are represented by objects of the corresponding JavaScript class, with the following additional restrictions on those objects.

- If the type is not associated with either the \[`AllowResizable`\] or \[`AllowShared`\] extended attribute, if applicable, they can only be backed by JavaScript `ArrayBuffer` objects `V` for which IsFixedLengthArrayBuffer(`V`) is true.
- If the type is associated with the \[`AllowResizable`\] extended attribute but not with the \[`AllowShared`\] extended attribute, if applicable, they can only be backed by JavaScript `ArrayBuffer` objects.
- If the type is associated with the \[`AllowShared`\] extended attribute but not with the \[`AllowResizable`\] extended attribute, they can only be backed by JavaScript `ArrayBuffer` and `SharedArrayBuffer` objects `V` for which IsFixedLengthArrayBuffer(`V`) is true.
- If the type is associated with both the \[`AllowResizable`\] and the \[`AllowShared`\] extended attributes, they can be backed by any JavaScript `ArrayBuffer` or `SharedArrayBuffer` object.

A JavaScript value `V` is converted to an IDL `ArrayBuffer` value by running the following algorithm:

1.  If `V` is not an Object, or `V` does not have an [[ArrayBufferData]] internal slot, then throw a `TypeError`.

2.  If IsSharedArrayBuffer(`V`) is true, then throw a `TypeError`.

3.  If the conversion is not to an IDL type associated with the \[`AllowResizable`\] extended attribute, and IsFixedLengthArrayBuffer(`V`) is false, then throw a `TypeError`.

4.  Return the IDL `ArrayBuffer` value that is a reference to the same object as `V`.

A JavaScript value `V` is converted to an IDL `SharedArrayBuffer` value by running the following algorithm:

1.  If `V` is not an Object, or `V` does not have an [[ArrayBufferData]] internal slot, then throw a `TypeError`.

2.  If IsSharedArrayBuffer(`V`) is false, then throw a `TypeError`.

3.  If the conversion is not to an IDL type associated with the \[`AllowResizable`\] extended attribute, and IsFixedLengthArrayBuffer(`V`) is false, then throw a `TypeError`.

4.  Return the IDL `SharedArrayBuffer` value that is a reference to the same object as `V`.

A JavaScript value `V` is converted to an IDL `DataView` value by running the following algorithm:

1.  If `V` is not an Object, or `V` does not have a [[DataView]] internal slot, then throw a `TypeError`.

2.  If the conversion is not to an IDL type associated with the \[`AllowShared`\] extended attribute, and IsSharedArrayBuffer(`V`.[[ViewedArrayBuffer]]) is true, then throw a `TypeError`.

3.  If the conversion is not to an IDL type associated with the \[`AllowResizable`\] extended attribute, and IsFixedLengthArrayBuffer(`V`.[[ViewedArrayBuffer]]) is false, then throw a `TypeError`.

4.  Return the IDL `DataView` value that is a reference to the same object as `V`.

A JavaScript value `V` is converted to an IDL `Int8Array`, `Int16Array`, `Int32Array`, `Uint8Array`, `Uint16Array`, `Uint32Array`, `Uint8ClampedArray`, `BigInt64Array`, `BigUint64Array`, `Float16Array`, `Float32Array`, or `Float64Array` value by running the following algorithm:

1.  Let `T` be the IDL type `V` is being converted to.

2.  If `V` is not an Object, or `V` does not have a [[TypedArrayName]] internal slot with a value equal to `T`'s name, then throw a `TypeError`.

3.  If the conversion is not to an IDL type associated with the \[`AllowShared`\] extended attribute, and IsSharedArrayBuffer(`V`.[[ViewedArrayBuffer]]) is true, then throw a `TypeError`.

4.  If the conversion is not to an IDL type associated with the \[`AllowResizable`\] extended attribute, and IsFixedLengthArrayBuffer(`V`.[[ViewedArrayBuffer]]) is false, then throw a `TypeError`.

5.  Return the IDL value of type `T` that is a reference to the same object as `V`.

The result of converting an IDL value of any buffer source type to a JavaScript value is the Object value that represents a reference to the same object that the IDL value represents.

------------------------------------------------------------------------

To create an `ArrayBuffer` from a byte sequence `bytes` in a realm `realm`:

1.  Let `jsArrayBuffer` be ? AllocateArrayBuffer(`realm`.[[Intrinsics]].[[`%ArrayBuffer%`]], `bytes`'s length).

2.  Let `arrayBuffer` be the result of converting `jsArrayBuffer` to an IDL value of type `ArrayBuffer`.

3.  Write `bytes` into `arrayBuffer`.

4.  Return `arrayBuffer`.

To create a `SharedArrayBuffer` from a byte sequence `bytes` in a realm `realm`:

1.  Let `jsSharedArrayBuffer` be ? AllocateSharedArrayBuffer(`realm`.[[Intrinsics]].[[`%SharedArrayBuffer%`]], `bytes`'s length).

2.  Let `sharedArrayBuffer` be the result of converting `jsSharedArrayBuffer` to an IDL value of type `SharedArrayBuffer`.

3.  Write `bytes` into `sharedArrayBuffer`.

4.  Return `sharedArrayBuffer`.

To create one of the `ArrayBufferView` types from a byte sequence `bytes` in a realm `realm`:

1.  Assert: if the type is not `DataView`, then `bytes`'s length modulo the element size of that type is 0.

2.  Let `arrayBuffer` be the result of creating an `ArrayBuffer` from `bytes` in `realm`.

3.  Let `jsArrayBuffer` be the result of converting `arrayBuffer` to a JavaScript value.

4.  Let `constructor` be the appropriate constructor from `realm`.[[Intrinsics]] for the type of `ArrayBufferView` being created.

5.  Let `jsView` be ! Construct(`constructor`, « `jsArrayBuffer` »).

6.  Return the result of converting `jsView` into the given type.

To get a copy of the bytes held by the buffer source given a buffer source type instance `bufferSource`:

1.  Let `jsBufferSource` be the result of converting `bufferSource` to a JavaScript value.

2.  Let `jsArrayBuffer` be `jsBufferSource`.

3.  Let `offset` be 0.

4.  Let `length` be 0.

5.  If `jsBufferSource` has a [[ViewedArrayBuffer]] internal slot, then:

    1.  Set `jsArrayBuffer` to `jsBufferSource`.[[ViewedArrayBuffer]].

    2.  Set `offset` to `jsBufferSource`.[[ByteOffset]].

    3.  Set `length` to `jsBufferSource`.[[ByteLength]].

6.  Otherwise:

    1.  Assert: `jsBufferSource` is an `ArrayBuffer` or `SharedArrayBuffer` object.

    2.  Set `length` to `jsBufferSource`.[[ArrayBufferByteLength]].

7.  If IsDetachedBuffer(`jsArrayBuffer`) is true, then return the empty byte sequence.

8.  Let `bytes` be a new byte sequence of length equal to `length`.

9.  For `i` in the range `offset` to `offset` + `length` − 1, inclusive, set `bytes`[`i` − `offset`] to GetValueFromBuffer(`jsArrayBuffer`, `i`, Uint8, true, Unordered).

10. Return `bytes`.

The byte length of a buffer source type instance `bufferSource` is the value returned by the following steps:

1.  Let `jsBufferSource` be the result of converting `bufferSource` to a JavaScript value.

2.  If `jsBufferSource` has a [[ViewedArrayBuffer]] internal slot, then return `jsBufferSource`.[[ByteLength]].

3.  Return `jsBufferSource`.[[ArrayBufferByteLength]].

The underlying buffer of a buffer source type instance `bufferSource` is the value returned by the following steps:

1.  If `bufferSource` is a buffer type instance, then return `bufferSource`.

2.  Let `jsBufferView` be the result of converting `bufferSource` to a JavaScript value.

3.  Let `jsBuffer` be `jsBufferView`.[[ViewedArrayBuffer]].

4.  If IsSharedArrayBuffer(`jsBuffer`) is false, then return the result of converting `jsBuffer` to an IDL value of type `ArrayBuffer`.

5.  Return the result of converting `jsBuffer` to an IDL value of type `SharedArrayBuffer`.

To write a byte sequence `bytes` into a buffer type instance `arrayBuffer`, optionally given a `startingOffset` (default 0):

1.  Let `jsArrayBuffer` be the result of converting `arrayBuffer` to a JavaScript value.

2.  Assert: `bytes`'s length ≤ `jsArrayBuffer`.[[ArrayBufferByteLength]] − `startingOffset`.

3.  For `i` in the range `startingOffset` to `startingOffset` + `bytes`'s length − 1, inclusive, perform SetValueInBuffer(`jsArrayBuffer`, `i`, Uint8, `bytes`[`i` - `startingOffset`], true, Unordered).

To write a byte sequence `bytes` into an `ArrayBufferView` `view`, optionally given a `startingOffset` (default 0):

1.  Let `jsView` be the result of converting `view` to a JavaScript value.

2.  Assert: `bytes`'s length ≤ `jsView`.[[ByteLength]] − `startingOffset`.

3.  Assert: if `view` is not a `DataView`, then `bytes`'s length modulo the element size of `view`'s type is 0.

4.  Let `arrayBuffer` be the result of converting `jsView`.[[ViewedArrayBuffer]] to an IDL value of type `ArrayBuffer`.

5.  Write `bytes` into `arrayBuffer` with *startingOffset* set to `jsView`.[[ByteOffset]] + `startingOffset`.

Extreme care must be taken when writing specification text that writes into a buffer source type instance, as the underlying data can easily be changed by the script author or other APIs at unpredictable times. This is especially true if a `SharedArrayBuffer` object is involved.

For the non-shared cases, a more recommended pattern is to transfer the `ArrayBuffer` first if possible, to ensure the writes cannot overlap with other modifications, and then give the new `ArrayBuffer` instance to author code as necessary. Alternately, you can get a copy of the bytes held by the buffer source, modify those bytes, and then use them to create a new `ArrayBuffer` or `ArrayBufferView` to give back to author code.

To detach an `ArrayBuffer` `arrayBuffer`:

1.  Let `jsArrayBuffer` be the result of converting `arrayBuffer` to a JavaScript value.

2.  Perform ? DetachArrayBuffer(`jsArrayBuffer`).

This will throw an exception if `jsArrayBuffer` has an [[ArrayBufferDetachKey]] that is not undefined, such as is the case with the value of `WebAssembly.Memory`'s `buffer` attribute. [WASM-JS-API-1]

Detaching a buffer that is already detached is a no-op.

A buffer source type instance `bufferSource` is detached if the following steps return true:

1.  Let `jsArrayBuffer` be the result of converting `bufferSource` to a JavaScript value.

2.  If `jsArrayBuffer` has a [[ViewedArrayBuffer]] internal slot, then set `jsArrayBuffer` to `jsArrayBuffer`.[[ViewedArrayBuffer]].

3.  Return IsDetachedBuffer(`jsArrayBuffer`).

A buffer source type instance `bufferSource` is transferable if the following steps return true:

1.  Let `jsArrayBuffer` be the result of converting `bufferSource` to a JavaScript value.

2.  If `jsArrayBuffer` has a [[ViewedArrayBuffer]] internal slot, then set `jsArrayBuffer` to `jsArrayBuffer`.[[ViewedArrayBuffer]].

3.  If IsSharedArrayBuffer(`jsArrayBuffer`) is true, then return false.

4.  If IsDetachedBuffer(`jsArrayBuffer`) is true, then return false.

5.  If `jsArrayBuffer`.[[ArrayBufferDetachKey]] is not undefined, then return false.

6.  Return true.

To transfer an `ArrayBuffer` `arrayBuffer`, optionally given a realm `targetRealm`:

1.  Let `jsArrayBuffer` be the result of converting `arrayBuffer` to a JavaScript value.

2.  If IsDetachedBuffer(`jsArrayBuffer`) is false, then throw a `TypeError`.

3.  Let `arrayBufferData` be `jsArrayBuffer`.[[ArrayBufferData]].

4.  Let `arrayBufferByteLength` be `jsArrayBuffer`.[[ArrayBufferByteLength]].

5.  Perform ? DetachArrayBuffer(`jsArrayBuffer`).

6.  If `targetRealm` is not given, let `targetRealm` be the current realm.

7.  Let `jsTransferred` be ? AllocateArrayBuffer(`targetRealm`.[[Intrinsics]].[[`%ArrayBuffer%`]], 0).

8.  Set `jsTransferred`.[[ArrayBufferData]] to `arrayBufferData`.

9.  Set `jsTransferred`.[[ArrayBufferByteLength]] to `arrayBufferByteLength`.

10. Return the result of converting `jsTransferred` to an IDL value of type `ArrayBuffer`.

This will throw an exception under any of the following circumstances:

- `arrayBuffer` cannot be detached, for the reasons explained in that algorithm's definition;

- `arrayBuffer` is already detached;

- Sufficient memory cannot be allocated in `realm`. Generally this will only be the case if `realm` is in a different agent cluster than the one in which `arrayBuffer` was allocated. If they are in the same agent cluster, then implementations will just change the backing pointers to get the same observable results with better performance and no allocations.


#### Frozen arrays --- FrozenArray<`T`>

Values of frozen array types are represented by frozen JavaScript Array object references.

A JavaScript value `V` is converted to an IDL FrozenArray<`T`> value by running the following algorithm:

1.  Let `values` be the result of converting `V` to IDL type sequence<`T`>.

2.  Return the result of creating a frozen array from `values`.

To create a frozen array from a sequence of values of type `T`, follow these steps:

1.  Let `array` be the result of converting the sequence of values of type `T` to a JavaScript value.

2.  Perform ! SetIntegrityLevel(`array`, "`frozen`").

3.  Return `array`.

The result of converting an IDL FrozenArray<`T`> value to a JavaScript value is the Object value that represents a reference to the same object that the IDL FrozenArray<`T`> represents.


##### Creating a frozen array from an iterable

To create an IDL value of type FrozenArray<`T`> given an iterable `iterable` and an iterator getter `method`, perform the following steps:

1.  Let `values` be the result of creating a sequence of type sequence<`T`> from `iterable` and `method`.

2.  Return the result of creating a frozen array from `values`.


#### Observable arrays --- ObservableArray<`T`>

Values of observable array types are represented by observable array exotic objects.

Instead of the usual conversion algorithms, observable array types have special handling as part of the attribute getter and attribute setter algorithms.

In the JavaScript binding, JavaScript objects that represent platform objects have a backing observable array exotic object for each regular attribute of an observable array type. These are created and managed as part of the define the attributes algorithm.

The backing list for an observable array attribute in the JavaScript binding, given a platform object `obj` and an attribute `attribute`, is the list returned by the following algorithm:

1.  Assert: `obj` implements an interface with the regular attribute `attribute`.

2.  Let `oa` be `obj`'s backing observable array exotic object for `attribute`.

3.  Return `oa`.[[ProxyHandler]].[[BackingList]].


### Extended attributes

This section defines a number of extended attributes whose presence affects the JavaScript binding.


#### \[AllowResizable\]

If the \[`AllowResizable`\] extended attribute appears on a buffer type, it creates a new IDL type that allows for the respective corresponding JavaScript `ArrayBuffer` or `SharedArrayBuffer` object to be resizable.

If the \[`AllowResizable`\] extended attribute appears on one of the buffer view types and the \[`AllowShared`\] extended attribute does not, it creates a new IDL type that allows the buffer view type to be backed by a JavaScript `ArrayBuffer` that is resizable, instead of only by a fixed-length `ArrayBuffer`.

If the \[`AllowResizable`\] extended attribute and the \[`AllowShared`\] extended attribute both appear on one of the buffer view types, it creates a new IDL type that allows the buffer view type to be additionally backed by a JavaScript `SharedArrayBuffer` that is growable.

The \[`AllowResizable`\] extended attribute must take no arguments.

A type that is not a buffer source type must not be associated with the \[`AllowResizable`\] extended attribute.

See the rules for converting JavaScript values to IDL buffer source types in § 3.2.26 Buffer source types for the specific requirements that the use of \[`AllowResizable`\] entails.

See the example in § 3.3.2 \[AllowShared\] for example usage of both \[`AllowResizable`\] and \[`AllowShared`\].


#### \[AllowShared\]

If the \[`AllowShared`\] extended attribute appears on one of the buffer view types, it creates a new IDL type that allows the object to be backed by an `SharedArrayBuffer` instead of only by an `ArrayBuffer`.

The \[`AllowShared`\] extended attribute must take no arguments.

A type that is not a buffer view type must not be associated with the \[`AllowShared`\] extended attribute.

See the rules for converting JavaScript values to IDL buffer view types in § 3.2.26 Buffer source types for the specific requirements that the use of \[`AllowShared`\] entails.

The following IDL fragment demonstrates the possible combinations of the \[`AllowResizable`\] and \[`AllowShared`\] extended attribute:

```
[Exposed=Window]
interface ExampleBufferFeature {
  undefined writeInto(ArrayBufferView dest);
  undefined writeIntoResizable([AllowResizable] ArrayBufferView dest);
  undefined writeIntoShared([AllowShared] ArrayBufferView dest);
  undefined writeIntoSharedResizable([AllowResizable, AllowShared] ArrayBufferView dest);
};
```

With this definition,

- A call to `writeInto` with any buffer view type backed by either a resizable `ArrayBuffer` instance or a `SharedArrayBuffer` instance, will throw a `TypeError` exception.
- A call to `writeIntoResizable` with any buffer view type backed by a `SharedArrayBuffer` instance, will throw a `TypeError` exception.
- A call to `writeIntoShared` with any buffer view type backed by a resizable `ArrayBuffer` instance or a growable `SharedArrayBuffer` instance, will throw a `TypeError` exception.
- A call to `writeIntoSharedResizable` will accept any buffer view type backed by a `ArrayBuffer` instance or a `SharedArrayBuffer` instance.


#### \[Clamp\]

If the \[`Clamp`\] extended attribute appears on one of the integer types, it creates a new IDL type such that that when a JavaScript Number is converted to the IDL type, out-of-range values will be clamped to the range of valid values, rather than using the operators that use a modulo operation (ToInt32, ToUint32, etc.).

The \[`Clamp`\] extended attribute must take no arguments.

A type annotated with the \[`Clamp`\] extended attribute must not appear in a read only attribute. A type must not be associated with both the \[`Clamp`\] and \[`EnforceRange`\] extended attributes. A type that is not an integer type must not be associated with the \[`Clamp`\] extended attribute.

See the rules for converting JavaScript values to the various IDL integer types in § 3.2.4 Integer types for the specific requirements that the use of \[`Clamp`\] entails.

In the following IDL fragment, two operations are declared that take three `octet` arguments; one uses the \[`Clamp`\] extended attribute on all three arguments, while the other does not:

```
[Exposed=Window]
interface GraphicsContext {
  undefined setColor(octet red, octet green, octet blue);
  undefined setColorClamped([Clamp] octet red, [Clamp] octet green, [Clamp] octet blue);
};
```

A call to `setColorClamped` with Number values that are out of range for an `octet` are clamped to the range \[0, 255\].

```
// Get an instance of GraphicsContext.
var context = getGraphicsContext();

// Calling the non-[Clamp] version uses ToUint8 to coerce the Numbers to octets.
// This is equivalent to calling setColor(255, 255, 1).
context.setColor(-1, 255, 257);

// Call setColorClamped with some out of range values.
// This is equivalent to calling setColorClamped(0, 255, 255).
context.setColorClamped(-1, 255, 257);
```


#### \[CrossOriginIsolated\]

If the \[`CrossOriginIsolated`\] extended attribute appears on an interface, partial interface, interface mixin, partial interface mixin, callback interface, namespace, partial namespace, interface member, interface mixin member, or namespace member, it indicates that the construct is exposed only within an environment whose cross-origin isolated capability is true. The \[`CrossOriginIsolated`\] extended attribute must not be used on any other construct.

The \[`CrossOriginIsolated`\] extended attribute must take no arguments.

If \[`CrossOriginIsolated`\] appears on an overloaded operation, then it must appear on all overloads.

The \[`CrossOriginIsolated`\] extended attribute must not be specified both on

- an interface member and its interface or partial interface;

- an interface mixin member and its interface mixin or partial interface mixin;

- a namespace member and its namespace or partial namespace.

Note: This is because adding the \[`CrossOriginIsolated`\] extended attribute on a member when its containing definition is also annotated with the \[`CrossOriginIsolated`\] extended attribute does not further restrict the exposure of the member.

An interface without the \[`CrossOriginIsolated`\] extended attribute must not inherit from another interface that does specify \[`CrossOriginIsolated`\].

The following IDL fragment defines an interface with one operation that is executable from all contexts, and two which are executable only from cross-origin isolated contexts.

```
[Exposed=Window]
interface ExampleFeature {
  // This call will succeed in all contexts.
  Promise <Result> calculateNotSoSecretResult();

  // This operation will not be exposed to a non-isolated context. In such a context,
  // there will be no "calculateSecretResult" property on ExampleFeature.prototype.
  [CrossOriginIsolated] Promise<Result> calculateSecretResult();

  // The same applies here: the attribute will not be exposed to a non-isolated context,
  // and in such a context there will be no "secretBoolean" property on
  // ExampleFeature.prototype.
  [CrossOriginIsolated] readonly attribute boolean secretBoolean;
};

// HighResolutionTimer will not be exposed in a non-isolated context, nor will its members.
// In such a context, there will be no "HighResolutionTimer" property on Window.
[Exposed=Window, CrossOriginIsolated]
interface HighResolutionTimer {
  DOMHighResTimeStamp getHighResolutionTime();
};

// The interface mixin members defined below will never be exposed in a
// non-isolated context, regardless of whether the interface that includes them is. That is, in
// non-isolated context, there will be no "snap" property on ExampleFeature.prototype.
[CrossOriginIsolated]
interface mixin Snapshotable {
  Promise<boolean> snap();
};
ExampleFeature includes Snapshotable;

// On the other hand, the following interface mixin members will be exposed to a
// non-isolated context when included by a host interface that doesn't have the
// [CrossOriginIsolated] extended attribute. That is, in a non-isolated context, there will
// be a "log" property on ExampleFeature.prototype.
interface mixin Loggable {
  Promise<boolean> log();
};
ExampleFeature includes Loggable;
```


#### \[Default\]

If the \[`Default`\] extended attribute appears on a regular operation, then it indicates that the appropriate default method steps must be carried out when the operation is invoked.

The \[`Default`\] extended attribute must take no arguments.

The \[`Default`\] extended attribute must not be used on anything other than a regular operation that has default method steps defined.

As an example, the \[`Default`\] extended attribute is suitable for use on `toJSON` regular operations:

```
[Exposed=Window]
interface Animal {
  attribute DOMString name;
  attribute unsigned short age;
  [Default] object toJSON();
};

[Exposed=Window]
interface Human : Animal {
  attribute Dog? pet;
  [Default] object toJSON();
};

[Exposed=Window]
interface Dog : Animal {
  attribute DOMString? breed;
};
```

In the JavaScript language binding, there would exist a `toJSON()` method on `Animal`, `Human`, and (via inheritance) `Dog` objects:

```
// Get an instance of Human.
var alice = getHuman();

// Evaluates to an object like this (notice how "pet" still holds
// an instance of Dog at this point):
//
// {
//   name: "Alice",
//   age: 59,
//   pet: Dog
// }
alice.toJSON();

// Evaluates to an object like this (notice how "breed" is absent,
// as the Dog interface doesn't use the default toJSON steps):
//
// {
//   name: "Tramp",
//   age: 6
// }
alice.pet.toJSON();

// Evaluates to a string like this:
// '{"name":"Alice","age":59,"pet":{"name":"Tramp","age":6}}'
JSON.stringify(alice);
```


#### \[EnforceRange\]

If the \[`EnforceRange`\] extended attribute appears on one of the integer types, it creates a new IDL type such that that when a JavaScript Number is converted to the IDL type, out-of-range values will cause an exception to be thrown, rather than being converted to a valid value using using the operators that use a modulo operation (ToInt32, ToUint32, etc.). The Number will be rounded toward zero before being checked against its range.

The \[`EnforceRange`\] extended attribute must take no arguments.

A type annotated with the \[`EnforceRange`\] extended attribute must not appear in a read only attribute. A type must not be associated with both the \[`Clamp`\] and \[`EnforceRange`\] extended attributes. A type that is not an integer type must not be associated with the \[`EnforceRange`\] extended attribute.

See the rules for converting JavaScript values to the various IDL integer types in § 3.2 JavaScript type mapping for the specific requirements that the use of \[`EnforceRange`\] entails.

In the following IDL fragment, two operations are declared that take three `octet` arguments; one uses the \[`EnforceRange`\] extended attribute on all three arguments, while the other does not:

```
[Exposed=Window]
interface GraphicsContext {
  undefined setColor(octet red, octet green, octet blue);
  undefined setColorEnforcedRange([EnforceRange] octet red, [EnforceRange] octet green, [EnforceRange] octet blue);
};
```

In a JavaScript implementation of the IDL, a call to setColorEnforcedRange with Number values that are out of range for an `octet` will result in an exception being thrown.

```
// Get an instance of GraphicsContext.
var context = getGraphicsContext();

// Calling the non-[EnforceRange] version uses ToUint8 to coerce the Numbers to octets.
// This is equivalent to calling setColor(255, 255, 1).
context.setColor(-1, 255, 257);

// When setColorEnforcedRange is called, Numbers are rounded towards zero.
// This is equivalent to calling setColor(0, 255, 255).
context.setColorEnforcedRange(-0.9, 255, 255.2);

// The following will cause a TypeError to be thrown, since even after
// rounding the first and third argument values are out of range.
context.setColorEnforcedRange(-1, 255, 256);
```


#### \[Exposed\]

When the \[`Exposed`\] extended attribute appears on an interface, partial interface, interface mixin, partial interface mixin, callback interface, namespace, partial namespace, or an individual interface member, interface mixin member, or namespace member, it indicates that the construct is exposed on that particular set of global interfaces.

The \[`Exposed`\] extended attribute must either take an identifier, take an identifier list or take a wildcard. Each of the identifiers mentioned must be a global name of some interface and be unique.

The own exposure set is either a set of identifiers or the special value `*`, defined as follows:

If the \[`Exposed`\] extended attribute takes an identifier `I`

: The own exposure set is the set « `I` ».

If the \[`Exposed`\] extended attribute takes an identifier list `I`

: The own exposure set is the set `I`.

If the \[`Exposed`\] extended attribute takes a wildcard

: The own exposure set is `*`.

`[Exposed=*]` is to be used with care. It is only appropriate when an API does not expose significant new capabilities. If the API might be restricted or disabled in some environments, it is preferred to list the globals explicitly.

The exposure set intersection of a construct `C` and interface-or-null `H` is defined as follows:

1. Assert: `C` is an interface member, interface mixin member, namespace member, partial interface, partial interface mixin, partial namespace, or interface mixin.

2. Assert: `H` is an interface or null.

3. If `H` is null, return `C`'s own exposure set.

4. If `C`'s own exposure set is `*`, return `H`'s exposure set.

5. If `H`'s exposure set is `*`, return `C`'s own exposure set.

6. Return the intersection of `C`'s own exposure set and `H`'s exposure set.

To get the exposure set of a construct `C`, run the following steps:

1. Assert: `C` is an interface, callback interface, namespace, interface member, interface mixin member, or namespace member.

2. Let `H` be `C`'s host interface if `C` is an interface mixin member, or null otherwise.

3. If `C` is an interface member, interface mixin member, or namespace member, then:

   1. If the \[`Exposed`\] extended attribute is specified on `C`, return the exposure set intersection of `C` and `H`.

   2. Set `C` to the interface, partial interface, interface mixin, partial interface mixin, namespace, or partial namespace `C` is declared on.

4. If `C` is a partial interface, partial interface mixin, or partial namespace, then:

   1. If the \[`Exposed`\] extended attribute is specified on `C`, return the exposure set intersection of `C` and `H`.

   2. Set `C` to the original interface, interface mixin, or namespace definition of `C`.

5. If `C` is an interface mixin, then:

   1. Assert: `H` is not null.

   2. If the \[`Exposed`\] extended attribute is specified on `C`, return the exposure set intersection of `C` and `H`.

   3. Set `C` to `H`.

6. Assert: `C` is an interface, callback interface or namespace.

7. Assert: The \[`Exposed`\] extended attribute is specified on `C`.

8. Return `C`'s own exposure set.

If \[`Exposed`\] appears on an overloaded operation, then it must appear identically on all overloads.

The \[`Exposed`\] extended attribute must not be specified both on an interface member, interface mixin member, or namespace member, and on the partial interface, partial interface mixin, or partial namespace definition the member is declared on.

Note: This is because adding an \[`Exposed`\] extended attribute on a partial interface, partial interface mixin, or partial namespace is shorthand for annotating each of its members.

If \[`Exposed`\] appears on a partial interface or partial namespace, then the partial's own exposure set must be a subset of the exposure set of the partial's original interface or namespace.

If \[`Exposed`\] appears on an interface or namespace member, then the member's exposure set must be a subset of the exposure set of the interface or namespace it is a member of.

If \[`Exposed`\] appears both on a partial interface mixin and its original interface mixin, then the partial interface mixin's own exposure set must be a subset of the interface mixin's own exposure set.

If \[`Exposed`\] appears both on an interface mixin member and the interface mixin it is a member of, then the interface mixin members's own exposure set must be a subset of the interface mixin's own exposure set.

If an interface `X` inherits from another interface `Y` then the exposure set of `X` must be a subset of the exposure set of `Y`.

Note: As an interface mixin can be included by different interfaces, the exposure set of its members is a function of the interface that includes them. If the interface mixin member, partial interface mixin, or interface mixin is annotated with an \[`Exposed`\] extended attribute, then the interface mixin member's exposure set is the intersection of the relevant construct's own exposure set with the host interface's exposure set. Otherwise, it is the host interface's exposure set.

An interface, callback interface, namespace, or member `construct` is exposed in a given realm `realm` if the following steps return true:

1. If `construct`'s exposure set is not `*`, and `realm`.[[GlobalObject]] does not implement an interface that is in `construct`'s exposure set, then return false.

2. If `realm`'s settings object is not a secure context, and `construct` is conditionally exposed on \[`SecureContext`\], then return false.

3. If `realm`'s settings object's cross-origin isolated capability is false, and `construct` is conditionally exposed on \[`CrossOriginIsolated`\], then return false.

4. Return true.

An interface, callback interface, namespace, or member `construct` is conditionally exposed on a given extended attribute `exposure condition` if the following steps return true:

1. Assert: `construct` is an interface, callback interface, namespace, interface member, interface mixin member, or namespace member.

2. Let `H` be `construct`'s host interface if `construct` is an interface mixin member, or null otherwise.

3. If `construct` is an interface member, interface mixin member, or namespace member, then:

   1. If the `exposure condition` extended attribute is specified on `construct`, then return true.

   2. Otherwise, set `construct` to be the interface, partial interface, interface mixin, partial interface mixin, namespace, or partial namespace `construct` is declared on.

4. If `construct` is a partial interface, partial interface mixin, or partial namespace, then:

   1. If the `exposure condition` extended attribute is specified on `construct`, then return true.

   2. Otherwise, set `construct` to be the original interface, interface mixin, or namespace definition of `construct`.

5. If `construct` is an interface mixin, then:

   1. If the `exposure condition` extended attribute is specified on `construct`, then return true.

   2. Otherwise, set `construct` to `H`.

6. Assert: `construct` is an interface, callback interface or namespace.

7. If the `exposure condition` extended attribute is specified on `construct`, then return true.

8. Otherwise, return false.

Note: Since it is not possible for the relevant settings object for a JavaScript global object to change whether it is a secure context or cross-origin isolated capability over time, an implementation's decision to create properties for an interface or interface member can be made once, at the time the initial objects are created.

See § 3.7 Interfaces, § 3.7.5 Constants, § 3.7.6 Attributes, § 3.7.7 Operations, and for the specific requirements that the use of \[`Exposed`\] entails.

\[`Exposed`\] is intended to be used to control whether interfaces, callback interfaces, namespaces, or individual interface, mixin or namespace members are available for use in workers, `Worklet`, `Window`, or any combination of the above.

The following IDL fragment shows how that might be achieved:

```
[Exposed=Window, Global=Window]
interface Window {
  // ...
};

// By using the same identifier Worker for both SharedWorkerGlobalScope
// and DedicatedWorkerGlobalScope, both can be addressed in an [Exposed]
// extended attribute at once.
[Exposed=Worker, Global=Worker]
interface SharedWorkerGlobalScope : WorkerGlobalScope {
  // ...
};

[Exposed=Worker, Global=Worker]
interface DedicatedWorkerGlobalScope : WorkerGlobalScope {
  // ...
};

// Dimensions is available for use in workers and on the main thread.
[Exposed=(Window,Worker)]
interface Dimensions {
  constructor(double width, double height);
  readonly attribute double width;
  readonly attribute double height;
};

// WorkerNavigator is only available in workers.  Evaluating WorkerNavigator
// in the global scope of a worker would give you its interface object, while
// doing so on the main thread will give you a ReferenceError.
[Exposed=Worker]
interface WorkerNavigator {
  // ...
};

// Node is only available on the main thread.  Evaluating Node
// in the global scope of a worker would give you a ReferenceError.
[Exposed=Window]
interface Node {
  // ...
};

// MathUtils is available for use in workers and on the main thread.
[Exposed=(Window,Worker)]
namespace MathUtils {
  double someComplicatedFunction(double x, double y);
};

// WorkerUtils is only available in workers.  Evaluating WorkerUtils
// in the global scope of a worker would give you its namespace object, while
// doing so on the main thread will give you a ReferenceError.
[Exposed=Worker]
namespace WorkerUtils {
  undefined setPriority(double x);
};

// NodeUtils is only available in the main thread.  Evaluating NodeUtils
// in the global scope of a worker would give you a ReferenceError.
[Exposed=Window]
namespace NodeUtils {
  DOMString getAllText(Node node);
};
```


#### \[Global\]

If the \[`Global`\] extended attribute appears on an interface, it indicates that objects implementing this interface will be used as the global object in a realm.

The \[`Global`\] extended attribute also defines the global names for the interface:

If the \[`Global`\] extended attribute takes an identifier

: « the given identifier »

If the \[`Global`\] extended attribute takes an identifier list

: the identifier list

The \[`Global`\] extended attribute must be one of the forms given above.

Note: The global names for the interface are the identifiers that can be used to reference it in the \[`Exposed`\] extended attribute. A single name can be shared across multiple different global interfaces, allowing an interface to more easily use \[`Exposed`\] to expose itself to all of them at once. For example, "`Worker`" is used to refer to several distinct types of threading-related global interfaces.

For these global interfaces, the structure of the prototype chain and how properties corresponding to interface members will be reflected on the prototype objects will be different from other interfaces. Specifically:

1. Any named properties will be exposed on an object in the prototype chain -- the named properties object -- rather than on the object itself.

2. Interface members from the interface will correspond to properties on the object itself rather than on interface prototype objects.

All realms have an is global prototype chain mutable boolean, which can be set when the realm is created. Its value can not change during the lifetime of the realm. By default it is set to false.

This allows the `ShadowRealm` global to have a mutable prototype.

Note:

Placing named properties on an object in the prototype chain is done so that variable declarations and bareword assignments will shadow the named property with a property on the global object itself.

Placing properties corresponding to interface members on the object itself will mean that common feature detection methods like the following will work:

```
var indexedDB = window.indexedDB || window.webkitIndexedDB ||
                window.mozIndexedDB || window.msIndexedDB;

var requestAnimationFrame = window.requestAnimationFrame ||
                            window.mozRequestAnimationFrame || ...;
```

Because of the way variable declarations are handled in JavaScript, the code above would result in the `window.indexedDB` and `window.requestAnimationFrame` evaluating to undefined, as the shadowing variable property would already have been created before the assignment is evaluated.

If the \[`Global`\] extended attributes is used on an interface, then:

- The interface must not define a named property setter.

- The interface must not define indexed property getters or setters.

- The interface must not define a constructor operation.

- The interface must not also be declared with the \[`LegacyOverrideBuiltIns`\] extended attribute.

- The interface must not inherit from another interface with the \[`LegacyOverrideBuiltIns`\] extended attribute.

- Any other interface must not inherit from it.

If \[`Global`\] is specified on a partial interface definition, then that partial interface definition must be the part of the interface definition that defines the named property getter.

The \[`Global`\] extended attribute must not be used on an interface that can have more than one object implementing it in the same realm.

Note: This is because the named properties object, which exposes the named properties, is in the prototype chain, and it would not make sense for more than one object's named properties to be exposed on an object that all of those objects inherit from.

If an interface is declared with the \[`Global`\] extended attribute, then there must not be more than one member across the interface with the same identifier. There also must not be more than one stringifier or more than one iterable declaration, asynchronously iterable declaration, maplike declaration or setlike declaration across those interfaces.

Note: This is because all of the members of the interface get flattened down on to the object that implements the interface.

See § 3.7.4 Named properties object for the specific requirements that the use of \[`Global`\] entails for named properties, and § 3.7.5 Constants, § 3.7.6 Attributes and § 3.7.7 Operations for the requirements relating to the location of properties corresponding to interface members.

The `Window` interface exposes frames as properties on the `Window` object. Since the `Window` object also serves as the JavaScript global object, variable declarations or assignments to the named properties will result in them being replaced by the new value. Variable declarations for attributes will not create a property that replaces the existing one.

```
[Exposed=Window, Global=Window]
interface Window {
  getter any (DOMString name);
  attribute DOMString name;
  // ...
};
```

The following HTML document illustrates how the named properties on the `Window` object can be shadowed, and how the property for an attribute will not be replaced when declaring a variable of the same name:

```
<!DOCTYPE html>
<title>Variable declarations and assignments on Window</title>
<iframe name=abc></iframe>
<!-- Shadowing named properties -->
<script>
  window.abc;    // Evaluates to the iframe's Window object.
  abc = 1;       // Shadows the named property.
  window.abc;    // Evaluates to 1.
</script>

<!-- Preserving properties for IDL attributes -->
<script>
  Window.prototype.def = 2;         // Places a property on the prototype.
  window.hasOwnProperty("length");  // Evaluates to true.
  length;                           // Evaluates to 1.
  def;                              // Evaluates to 2.
</script>
<script>
  var length;                       // Variable declaration leaves existing property.
  length;                           // Evaluates to 1.
  var def;                          // Variable declaration creates shadowing property.
  def;                              // Evaluates to undefined.
</script>
```


#### \[NewObject\]

If the \[`NewObject`\] extended attribute appears on a regular or static operation, then it indicates that when calling the operation, a reference to a newly created object must always be returned.

The \[`NewObject`\] extended attribute must take no arguments.

The \[`NewObject`\] extended attribute must not be used on anything other than a regular or static operation whose return type is an interface type or a promise type.

As an example, this extended attribute is suitable for use on the `createElement()` operation on the `Document` interface, since a new object is always returned when it is called.

```
[Exposed=Window]
interface Document : Node {
  [NewObject] Element createElement(DOMString localName);
  // ...
};
```


#### \[PutForwards\]

If the \[`PutForwards`\] extended attribute appears on a read only regular attribute declaration whose type is an interface type, it indicates that assigning to the attribute will have specific behavior. Namely, the assignment is "forwarded" to the attribute (specified by the extended attribute argument) on the object that is currently referenced by the attribute being assigned to.

The \[`PutForwards`\] extended attribute must take an identifier. Assuming that:

- `A` is the attribute on which the \[`PutForwards`\] extended attribute appears,

- `I` is the interface on which `A` is declared,

- `J` is the interface type that `A` is declared to be of, and

- `N` is the identifier argument of the extended attribute,

then there must be another attribute `B` declared on `J` whose identifier is `N`. Assignment of a value to the attribute `A` on an object implementing `I` will result in that value being assigned to attribute `B` of the object that `A` references, instead.

Note that \[`PutForwards`\]-annotated attributes can be chained. That is, an attribute with the \[`PutForwards`\] extended attribute can refer to an attribute that itself has that extended attribute. There must not exist a cycle in a chain of forwarded assignments. A cycle exists if, when following the chain of forwarded assignments, a particular attribute on an interface is encountered more than once.

An attribute with the \[`PutForwards`\] extended attribute must not also be declared with the \[`LegacyLenientSetter`\] or \[`Replaceable`\] extended attributes.

The \[`PutForwards`\] extended attribute must not be used on an attribute that is not read only.

The \[`PutForwards`\] extended attribute must not be used on a static attribute.

The \[`PutForwards`\] extended attribute must not be used on an attribute declared on a namespace.

See the Attributes section for how \[`PutForwards`\] is to be implemented.

The following IDL fragment defines interfaces for names and people. The \[`PutForwards`\] extended attribute is used on the `name` attribute of the `Person` interface to indicate that assignments to that attribute result in assignments to the `full` attribute of the `Person` object:

```
[Exposed=Window]
interface Name {
  attribute DOMString full;
  attribute DOMString family;
  attribute DOMString given;
};

[Exposed=Window]
interface Person {
  [PutForwards=full] readonly attribute Name name;
  attribute unsigned short age;
};
```

In the JavaScript binding, this would allow assignments to the `name` property:

```
var p = getPerson();           // Obtain an instance of Person.

p.name = 'John Citizen';       // This statement...
p.name.full = 'John Citizen';  // ...has the same behavior as this one.
```


#### \[Replaceable\]

If the \[`Replaceable`\] extended attribute appears on a read only regular attribute, it indicates that setting the corresponding property on the platform object will result in an own property with the same name being created on the object which has the value being assigned. This property will shadow the accessor property corresponding to the attribute, which exists on the interface prototype object.

The \[`Replaceable`\] extended attribute must take no arguments.

An attribute with the \[`Replaceable`\] extended attribute must not also be declared with the \[`LegacyLenientSetter`\] or \[`PutForwards`\] extended attributes.

The \[`Replaceable`\] extended attribute must not be used on an attribute that is not read only.

The \[`Replaceable`\] extended attribute must not be used on a static attribute.

The \[`Replaceable`\] extended attribute must not be used on an attribute declared on a namespace.

See § 3.7.6 Attributes for the specific requirements that the use of \[`Replaceable`\] entails.

The following IDL fragment defines an interface with an operation that increments a counter, and an attribute that exposes the counter's value, which is initially 0:

```
[Exposed=Window]
interface Counter {
  [Replaceable] readonly attribute unsigned long value;
  undefined increment();
};
```

Assigning to the `value` property on a platform object implementing `Counter` will shadow the property that corresponds to the attribute:

```
var counter = getCounter();                              // Obtain an instance of Counter.
counter.value;                                           // Evaluates to 0.

counter.hasOwnProperty("value");                         // Evaluates to false.
Object.getPrototypeOf(counter).hasOwnProperty("value");  // Evaluates to true.

counter.increment();
counter.increment();
counter.value;                                           // Evaluates to 2.

counter.value = 'a';                                     // Shadows the property with one that is unrelated
                                                         // to Counter::value.

counter.hasOwnProperty("value");                         // Evaluates to true.

counter.increment();
counter.value;                                           // Evaluates to 'a'.

delete counter.value;                                    // Reveals the original property.
counter.value;                                           // Evaluates to 3.
```


#### \[SameObject\]

If the \[`SameObject`\] extended attribute appears on a read only attribute, then it indicates that when getting the value of the attribute on a given object, the same value must always be returned.

The \[`SameObject`\] extended attribute must take no arguments.

The \[`SameObject`\] extended attribute must not be used on anything other than a read only attribute whose type is an interface type or `object`.

As an example, this extended attribute is suitable for use on the `implementation` attribute on the `Document` interface since the same object is always returned for a given `Document` object.

```
[Exposed=Window]
interface Document : Node {
  [SameObject] readonly attribute DOMImplementation implementation;
  // ...
};
```


#### \[SecureContext\]

If the \[`SecureContext`\] extended attribute appears on an interface, partial interface, interface mixin, partial interface mixin, callback interface, namespace, partial namespace, interface member, interface mixin member, or namespace member, it indicates that the construct is exposed only within a secure context. The \[`SecureContext`\] extended attribute must not be used on any other construct.

The \[`SecureContext`\] extended attribute must take no arguments.

If \[`SecureContext`\] appears on an overloaded operation, then it must appear on all overloads.

The \[`SecureContext`\] extended attribute must not be specified both on

- an interface member and its interface or partial interface;

- an interface mixin member and its interface mixin or partial interface mixin;

- a namespace member and its namespace or partial namespace.

Note: This is because adding the \[`SecureContext`\] extended attribute on a member when its containing definition is also annotated with the \[`SecureContext`\] extended attribute does not further restrict the exposure of the member.

An interface without the \[`SecureContext`\] extended attribute must not inherit from another interface that does specify \[`SecureContext`\].

\[`SecureContext`\] must not be specified on a construct is that is conditionally exposed on \[`CrossOriginIsolated`\]. (Doing so would be redundant, since every environment which is cross-origin isolated is also a secure context.)

The following IDL fragment defines an interface with one operation that is executable from all contexts, and two which are executable only from secure contexts.

```
[Exposed=Window]
interface ExampleFeature {
  // This call will succeed in all contexts.
  Promise <Result> calculateNotSoSecretResult();

  // This operation will not be exposed to a non-secure context. In such a context,
  // there will be no "calculateSecretResult" property on ExampleFeature.prototype.
  [SecureContext] Promise<Result> calculateSecretResult();

  // The same applies here: the attribute will not be exposed to a non-secure context,
  // and in a non-secure context there will be no "secretBoolean" property on
  // ExampleFeature.prototype.
  [SecureContext] readonly attribute boolean secretBoolean;
};

// HeartbeatSensor will not be exposed in a non-secure context, nor will its members.
// In such a context, there will be no "HeartbeatSensor" property on Window.
[Exposed=Window, SecureContext]
interface HeartbeatSensor {
  Promise<float> getHeartbeatsPerMinute();
};

// The interface mixin members defined below will never be exposed in a non-secure context,
// regardless of whether the interface that includes them is. That is, in a non-secure
// context, there will be no "snap" property on ExampleFeature.prototype.
[SecureContext]
interface mixin Snapshotable {
  Promise<boolean> snap();
};
ExampleFeature includes Snapshotable;

// On the other hand, the following interface mixin members will be exposed to a non-secure
// context when included by a host interface that doesn't have the [SecureContext] extended
// attribute. That is, in a non-secure context, there will be a "log" property on
// ExampleFeature.prototype.
interface mixin Loggable {
  Promise<boolean> log();
};
ExampleFeature includes Loggable;
```


#### \[Unscopable\]

If the \[`Unscopable`\] extended attribute appears on a regular attribute or regular operation, it indicates that an object that implements an interface with the given interface member will not include its property name in any object environment record with it as its base object. The result of this is that bare identifiers matching the property name will not resolve to the property in a `with` statement. This is achieved by including the property name on the interface prototype object's `%Symbol.unscopables%` property's value.

The \[`Unscopable`\] extended attribute must take no arguments.

The \[`Unscopable`\] extended attribute must not appear on anything other than a regular attribute or regular operation.

The \[`Unscopable`\] extended attribute must not be used on an attribute declared on a namespace.

See § 3.7.3 Interface prototype object for the specific requirements that the use of \[`Unscopable`\] entails.

Note:

For example, with the following IDL:

```
[Exposed=Window]
interface Thing {
  undefined f();
  [Unscopable] g();
};
```

the `f` property can be referenced with a bare identifier in a `with` statement but the `g` property cannot:

```
var thing = getThing();  // An instance of Thing
with (thing) {
  f;                     // Evaluates to a Function object.
  g;                     // Throws a ReferenceError.
}
```


### Legacy extended attributes

This section defines a number of extended attributes whose presence affects the JavaScript binding. Unlike those in § 3.3 Extended attributes, these exist only so that legacy Web platform features can be specified. They should not be used in specifications, unless required to specify the behavior of legacy APIs.

Editors who believe they have a good reason for using these extended attributes are strongly advised to discuss this by [filing an issue](https://github.com/whatwg/webidl/issues/new?title=Intent%20to%20use%20a%20legacy%20extended%20attribute) before proceeding.


#### [LegacyFactoryFunction]

Instead of using this feature, give your interface a constructor operation.

If the [`LegacyFactoryFunction`{.idl}](#LegacyFactoryFunction) extended attribute appears on an interface, it indicates that the JavaScript global object will have a property with the specified name whose value is a function that can create objects that implement the interface. Multiple [`LegacyFactoryFunction`{.idl}](#LegacyFactoryFunction) extended attributes may appear on a given interface.

The [`LegacyFactoryFunction`{.idl}](#LegacyFactoryFunction) extended attribute must take a named argument list. The identifier that occurs directly after the "=" is the [`LegacyFactoryFunction`{.idl}](#LegacyFactoryFunction)'s identifier. For each [`LegacyFactoryFunction`{.idl}](#LegacyFactoryFunction) extended attribute on the interface, there will be a way to construct an object that implements the interface by passing the specified arguments to the constructor that is the value of the aforementioned property.

The identifier used for the legacy factory function must not be the same as that used by a [`LegacyFactoryFunction`{.idl}](#LegacyFactoryFunction) extended attribute on another interface, must not be the same as an identifier used by a [`LegacyWindowAlias`{.idl}](#LegacyWindowAlias) extended attribute on this interface or another interface, must not be the same as an identifier of an interface that has an interface object, and must not be one of the reserved identifiers.

The [`LegacyFactoryFunction`{.idl}](#LegacyFactoryFunction) and [`Global`{.idl}](#Global) extended attributes must not be specified on the same interface.

See § 3.7.2 Legacy factory functions for details on how legacy factory functions are to be implemented.

The following IDL defines an interface that uses the [`LegacyFactoryFunction`{.idl}](#LegacyFactoryFunction) extended attribute.

``` highlight
[Exposed=Window,
 LegacyFactoryFunction=Audio(DOMString src)]
interface HTMLAudioElement : HTMLMediaElement {
  // ...
};
```

A JavaScript implementation that supports this interface will allow the construction of `HTMLAudioElement`{.idl} objects using the `Audio`{.idl} function.

``` highlight
typeof Audio;                   // Evaluates to 'function'.

var a2 = new Audio('a.flac');   // Creates an HTMLAudioElement using the
                                // one-argument constructor.
```

As an additional legacy quirk, these factory functions will have a `prototype` property equal to the `prototype` of the original interface:

``` highlight
console.assert(Audio.prototype === HTMLAudioElement.prototype);
```


#### [LegacyLenientSetter]

If the [`LegacyLenientSetter`{.idl}](#LegacyLenientSetter) extended attribute appears on a read only regular attribute, it indicates that a no-op setter will be generated for the attribute's accessor property. This results in erroneous assignments to the property in strict mode to be ignored rather than causing an exception to be thrown.

Pages have been observed where authors have attempted to polyfill an IDL attribute by assigning to the property, but have accidentally done so even if the property exists. In strict mode, this would cause an exception to be thrown, potentially breaking page. Without [`LegacyLenientSetter`{.idl}](#LegacyLenientSetter), this could prevent a browser from shipping the feature.

The [`LegacyLenientSetter`{.idl}](#LegacyLenientSetter) extended attribute must take no arguments. It must not be used on anything other than a read only regular attribute.

An attribute with the [`LegacyLenientSetter`{.idl}](#LegacyLenientSetter) extended attribute must not also be declared with the [`PutForwards`{.idl}](#PutForwards) or [`Replaceable`{.idl}](#Replaceable) extended attributes.

The [`LegacyLenientSetter`{.idl}](#LegacyLenientSetter) extended attribute must not be used on an attribute declared on a namespace.

See the Attributes section for how [`LegacyLenientSetter`{.idl}](#LegacyLenientSetter) is to be implemented.

The following IDL fragment defines an interface that uses the [`LegacyLenientSetter`{.idl}](#LegacyLenientSetter) extended attribute.

``` highlight
[Exposed=Window]
interface Example {
  [LegacyLenientSetter] readonly attribute DOMString x;
  readonly attribute DOMString y;
};
```

A JavaScript implementation that supports this interface will have a setter on the accessor property that correspond to x, which allows any assignment to be ignored in strict mode.

``` highlight
"use strict";

var example = getExample();  // Get an instance of Example.

// Fine; while we are in strict mode, there is a setter that is a no-op.
example.x = 1;

// Throws a TypeError, since we are in strict mode and there is no setter.
example.y = 1;
```


#### [LegacyLenientThis]

If the [`LegacyLenientThis`{.idl}](#LegacyLenientThis) extended attribute appears on a regular attribute, it indicates that invocations of the attribute's getter or setter with a this value that is not an object that implements the interface on which the attribute appears will be ignored.

The [`LegacyLenientThis`{.idl}](#LegacyLenientThis) extended attribute must take no arguments. It must not be used on a static attribute.

The [`LegacyLenientThis`{.idl}](#LegacyLenientThis) extended attribute must not be used on an attribute declared on a namespace.

See the Attributes section for how [`LegacyLenientThis`{.idl}](#LegacyLenientThis) is to be implemented.

The following IDL fragment defines an interface that uses the [`LegacyLenientThis`{.idl}](#LegacyLenientThis) extended attribute.

``` highlight
[Exposed=Window]
interface Example {
  [LegacyLenientThis] attribute DOMString x;
  attribute DOMString y;
};
```

A JavaScript implementation that supports this interface will allow the getter and setter of the accessor property that corresponds to x to be invoked with something other than an `Example`{.idl} object.

``` highlight
var example = getExample();  // Get an instance of Example.
var obj = { };

// Fine.
example.x;

// Ignored, since the this value is not an Example object and [LegacyLenientThis] is used.
Object.getOwnPropertyDescriptor(Example.prototype, "x").get.call(obj);

// Also ignored, since Example.prototype is not an Example object and [LegacyLenientThis] is used.
Example.prototype.x;

// Throws a TypeError, since Example.prototype is not an Example object.
Example.prototype.y;
```


#### [LegacyNamespace]

Instead of using this feature, interface names can be formed with a naming convention of starting with a particular prefix for a set of interfaces, as part of the identifier, without the intervening dot.

If the [`LegacyNamespace`{.idl}](#LegacyNamespace) extended attribute appears on an interface, it indicates that the interface object for this interface will not be created as a property of the global object, but rather as a property of the namespace identified by the argument to the extended attribute.

The [`LegacyNamespace`{.idl}](#LegacyNamespace) extended attribute must take an identifier. This identifier must be the identifier of a namespace definition.

The [`LegacyNamespace`{.idl}](#LegacyNamespace) and [`LegacyNoInterfaceObject`{.idl}](#LegacyNoInterfaceObject) extended attributes must not be specified on the same interface.

See § 3.13.1 Namespace object for details on how an interface is exposed on a namespace.

The following IDL fragment defines a namespace and an interface which uses [`LegacyNamespace`{.idl}](#LegacyNamespace) to be defined inside of it.

``` highlight
namespace Foo { };

[LegacyNamespace=Foo]
interface Bar {
  constructor();
};
```

In a JavaScript implementation of the above namespace and interface, the constructor Bar can be accessed as follows:

``` highlight
var instance = new Foo.Bar();
```


#### [LegacyNoInterfaceObject]

If the [`LegacyNoInterfaceObject`{.idl}](#LegacyNoInterfaceObject) extended attribute appears on an interface, it indicates that an interface object will not exist for the interface in the JavaScript binding.

The [`LegacyNoInterfaceObject`{.idl}](#LegacyNoInterfaceObject) extended attribute must take no arguments.

The [`LegacyNoInterfaceObject`{.idl}](#LegacyNoInterfaceObject) extended attribute must not be specified on an interface that has any constructors or static operations defined on it.

An interface that does not have the [`LegacyNoInterfaceObject`{.idl}](#LegacyNoInterfaceObject) extended attribute specified must not inherit from an interface that has the [`LegacyNoInterfaceObject`{.idl}](#LegacyNoInterfaceObject) extended attribute specified.

See § 3.7 Interfaces for the specific requirements that the use of [`LegacyNoInterfaceObject`{.idl}](#LegacyNoInterfaceObject) entails.

The following IDL fragment defines two interfaces, one whose interface object is exposed on the JavaScript global object, and one whose isn't:

``` highlight
[Exposed=Window]
interface Storage {
  undefined addEntry(unsigned long key, any value);
};

[Exposed=Window,
 LegacyNoInterfaceObject]
interface Query {
  any lookupEntry(unsigned long key);
};
```

A JavaScript implementation of the above IDL would allow manipulation of `Storage`{.idl}'s prototype, but not `Query`{.idl}'s.

``` highlight
typeof Storage;                        // evaluates to "object"

// Add some tracing alert() call to Storage.addEntry.
var fn = Storage.prototype.addEntry;
Storage.prototype.addEntry = function(key, value) {
  alert('Calling addEntry()');
  return fn.call(this, key, value);
};

typeof Query;                          // evaluates to "undefined"
var fn = Query.prototype.lookupEntry;  // exception, Query isn't defined
```


#### [LegacyNullToEmptyString]

If the [`LegacyNullToEmptyString`{.idl}](#LegacyNullToEmptyString) extended attribute appears on the [`DOMString`{.idl}](#idl-DOMString) or [`USVString`{.idl}](#idl-USVString) type, it creates a new IDL type such that that when a JavaScript null is converted to the IDL type, it will be handled differently from its default handling. Instead of being stringified to "`null`", which is the default, it will be converted to the empty string.

The [`LegacyNullToEmptyString`{.idl}](#LegacyNullToEmptyString) extended attribute must not be associated with a type that is not [`DOMString`{.idl}](#idl-DOMString) or [`USVString`{.idl}](#idl-USVString).

Note: This means that even `DOMString?`{.idl} must not use [`LegacyNullToEmptyString`{.idl}](#LegacyNullToEmptyString), since null is a valid value of that type.

See § 3.2.10 DOMString for the specific requirements that the use of [`LegacyNullToEmptyString`{.idl}](#LegacyNullToEmptyString) entails.

The following IDL fragment defines an interface that has one attribute whose type has the extended attribute, and one operation whose argument's type has the extended attribute:

``` highlight
[Exposed=Window]
interface Dog {
  attribute DOMString name;
  attribute [LegacyNullToEmptyString] DOMString owner;

  boolean isMemberOfBreed([LegacyNullToEmptyString] DOMString breedName);
};
```

A JavaScript implementation implementing the `Dog`{.idl} interface would convert a null value assigned to the `owner` property or passed as the argument to the `isMemberOfBreed` function to the empty string rather than "`null`":

``` highlight
var d = getDog();         // Assume d is a platform object implementing the Dog
                          // interface.

d.name = null;            // This assigns the string "null" to the .name
                          // property.

d.owner = null;           // This assigns the string "" to the .owner property.

d.isMemberOfBreed(null);  // This passes the string "" to the isMemberOfBreed
                          // function.
```


#### [LegacyOverrideBuiltIns]

If the [`LegacyOverrideBuiltIns`{.idl}](#LegacyOverrideBuiltIns) extended attribute appears on an interface, it indicates that for a legacy platform object implementing the interface, properties corresponding to all of the object's supported property names will appear to be on the object, regardless of what other properties exist on the object or its prototype chain. This means that named properties will always shadow any properties that would otherwise appear on the object. This is in contrast to the usual behavior, which is for named properties to be exposed only if there is no property with the same name on the object itself or somewhere on its prototype chain.

The [`LegacyOverrideBuiltIns`{.idl}](#LegacyOverrideBuiltIns) extended attribute must take no arguments and must not appear on an interface that does not define a named property getter or that also is declared with the [`Global`{.idl}](#Global) extended attribute. If the extended attribute is specified on a partial interface definition, then that partial interface definition must be the part of the interface definition that defines the named property getter.

If the [`LegacyOverrideBuiltIns`{.idl}](#LegacyOverrideBuiltIns) extended attribute is specified on a partial interface definition, it is considered to appear on the interface itself.

See § 3.9 Legacy platform objects and § 3.9.3 [[DefineOwnProperty]] for the specific requirements that the use of [`LegacyOverrideBuiltIns`{.idl}](#LegacyOverrideBuiltIns) entails.

The following IDL fragment defines two interfaces, one that has a named property getter and one that does not.

``` highlight
[Exposed=Window]
interface StringMap {
  readonly attribute unsigned long length;
  getter DOMString lookup(DOMString key);
};

[Exposed=Window,
 LegacyOverrideBuiltIns]
interface StringMap2 {
  readonly attribute unsigned long length;
  getter DOMString lookup(DOMString key);
};
```

In a JavaScript implementation of these two interfaces, getting certain properties on objects implementing the interfaces will result in different values:

``` highlight
// Obtain an instance of StringMap.  Assume that it has "abc", "length" and
// "toString" as supported property names.
var map1 = getStringMap();

// This invokes the named property getter.
map1.abc;

// This fetches the "length" property on the object that corresponds to the
// length attribute.
map1.length;

// This fetches the "toString" property from the object's prototype chain.
map1.toString;

// Obtain an instance of StringMap2.  Assume that it also has "abc", "length"
// and "toString" as supported property names.
var map2 = getStringMap2();

// This invokes the named property getter.
map2.abc;

// This also invokes the named property getter, despite the fact that the "length"
// property on the object corresponds to the length attribute.
map2.length;

// This too invokes the named property getter, despite the fact that "toString" is
// a property in map2's prototype chain.
map2.toString;
```


#### [LegacyTreatNonObjectAsNull]

If the [`LegacyTreatNonObjectAsNull`{.idl}](#LegacyTreatNonObjectAsNull) extended attribute appears on a callback function, then it indicates that any value assigned to an attribute whose type is a nullable callback function will be converted more loosely: if the value is not an object, it will be converted to null, and if the value is not callable, it will be converted to a callback function value that does nothing when called.

See § 3.2.20 Nullable types --- T?, § 3.2.19 Callback function types and § 3.12 Invoking callback functions for the specific requirements that the use of [`LegacyTreatNonObjectAsNull`{.idl}](#LegacyTreatNonObjectAsNull) entails.

The following IDL fragment defines an interface that has one attribute whose type is a [`LegacyTreatNonObjectAsNull`{.idl}](#LegacyTreatNonObjectAsNull)-annotated callback function and another whose type is a callback function without the extended attribute:

``` highlight
callback OccurrenceHandler = undefined (DOMString details);

[LegacyTreatNonObjectAsNull]
callback ErrorHandler = undefined (DOMString details);

[Exposed=Window]
interface Manager {
  attribute OccurrenceHandler? handler1;
  attribute ErrorHandler? handler2;
};
```

In a JavaScript implementation, assigning a value that is not an object (such as a Number value), or that is not callable to handler1 will have different behavior from that when assigning to handler2:

``` highlight
var manager = getManager();  // Get an instance of Manager.

manager.handler1 = function() { };
manager.handler1;            // Evaluates to the function.

try {
  manager.handler1 = 123;    // Throws a TypeError.
} catch (e) {
}

try {
  manager.handler1 = {};     // Throws a TypeError.
} catch (e) {
}

manager.handler2 = function() { };
manager.handler2;            // Evaluates to the function.

manager.handler2 = 123;
manager.handler2;            // Evaluates to null.

manager.handler2 = {};
manager.handler2;            // Evaluates to the object.
```


#### [LegacyUnenumerableNamedProperties]

If the [`LegacyUnenumerableNamedProperties`{.idl}](#LegacyUnenumerableNamedProperties) extended attribute appears on a interface that supports named properties, it indicates that all the interface's named properties are unenumerable.

The [`LegacyUnenumerableNamedProperties`{.idl}](#LegacyUnenumerableNamedProperties) extended attribute must take no arguments and must not appear on an interface that does not define a named property getter.

If the [`LegacyUnenumerableNamedProperties`{.idl}](#LegacyUnenumerableNamedProperties) extended attribute is specified on an interface, then it applies to all its derived interfaces and must not be specified on any of them.

See § 3.9.1 [[GetOwnProperty]] for the specific requirements that the use of [`LegacyUnenumerableNamedProperties`{.idl}](#LegacyUnenumerableNamedProperties) entails.


#### [LegacyUnforgeable]

If the [`LegacyUnforgeable`{.idl}](#LegacyUnforgeable) extended attribute appears on regular attributes or non-static operations, it indicates that the attribute or operation will be reflected as a JavaScript property in a way that means its behavior cannot be modified and that performing a property lookup on the object will always result in the attribute's property value being returned. In particular, the property will be non-configurable and will exist as an own property on the object itself rather than on its prototype.

An attribute or operation is said to be unforgeable on a given interface `A` if the attribute or operation is declared on `A`, and is annotated with the [`LegacyUnforgeable`{.idl}](#LegacyUnforgeable) extended attribute.

The [`LegacyUnforgeable`{.idl}](#LegacyUnforgeable) extended attribute must take no arguments.

The [`LegacyUnforgeable`{.idl}](#LegacyUnforgeable) extended attribute must not appear on anything other than a regular attribute or a non-static operation. If it does appear on an operation, then it must appear on all operations with the same identifier on that interface.

The [`LegacyUnforgeable`{.idl}](#LegacyUnforgeable) extended attribute must not be used on an attribute declared on a namespace.

If an attribute or operation `X` is unforgeable on an interface `A`, and `A` is one of the inherited interfaces of another interface `B`, then `B` must not have a regular attribute or non-static operation with the same identifier as `X`.

For example, the following is disallowed:

``` highlight
[Exposed=Window]
interface A1 {
  [LegacyUnforgeable] readonly attribute DOMString x;
};
[Exposed=Window]
interface B1 : A1 {
  undefined x();  // Invalid; would be shadowed by A1's x.
};

[Exposed=Window]
interface B2 : A1 { };
B2 includes M1;
interface mixin M1 {
  undefined x();  // Invalid; B2's copy of x would be shadowed by A1's x.
};
```

See § 3.7.6 Attributes, § 3.7.7 Operations, § 3.8 Platform objects implementing interfaces, § 3.9 Legacy platform objects and § 3.9.3 [[DefineOwnProperty]] for the specific requirements that the use of [`LegacyUnforgeable`{.idl}](#LegacyUnforgeable) entails.

The following IDL fragment defines an interface that has two attributes, one of which is designated as [`LegacyUnforgeable`{.idl}](#LegacyUnforgeable):

``` highlight
[Exposed=Window]
interface System {
  [LegacyUnforgeable] readonly attribute DOMString username;
  readonly attribute long long loginTime;
};
```

In a JavaScript implementation of the interface, the username attribute will be exposed as a non-configurable property on the object itself:

``` highlight
var system = getSystem();                      // Get an instance of System.

system.hasOwnProperty("username");             // Evaluates to true.
system.hasOwnProperty("loginTime");            // Evaluates to false.
System.prototype.hasOwnProperty("username");   // Evaluates to false.
System.prototype.hasOwnProperty("loginTime");  // Evaluates to true.

try {
  // This call would fail, since the property is non-configurable.
  Object.defineProperty(system, "username", { value: "administrator" });
} catch (e) { }

// This defineProperty call would succeed, because System.prototype.loginTime
// is configurable.
var forgedLoginTime = 5;
Object.defineProperty(System.prototype, "loginTime", { value: forgedLoginTime });

system.loginTime;  // So this now evaluates to forgedLoginTime.
```


#### [LegacyWindowAlias]

If the [`LegacyWindowAlias`{.idl}](#LegacyWindowAlias) extended attribute appears on an interface, it indicates that the [`Window`{.idl}](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) interface will have a property for each identifier mentioned in the extended attribute, whose value is the interface object for the interface.

The [`LegacyWindowAlias`{.idl}](#LegacyWindowAlias) extended attribute must either take an identifier or take an identifier list. The identifiers that occur after the "=" are the [`LegacyWindowAlias`{.idl}](#LegacyWindowAlias)'s identifiers.

Each of the identifiers of [`LegacyWindowAlias`{.idl}](#LegacyWindowAlias) must not be the same as one used by a [`LegacyWindowAlias`{.idl}](#LegacyWindowAlias) extended attribute on this interface or another interface, must not be the same as the identifier used by a [`LegacyFactoryFunction`{.idl}](#LegacyFactoryFunction) extended attribute on this interface or another interface, must not be the same as an identifier of an interface that has an interface object, and must not be one of the reserved identifiers.

The [`LegacyWindowAlias`{.idl}](#LegacyWindowAlias) and [`LegacyNoInterfaceObject`{.idl}](#LegacyNoInterfaceObject) extended attributes must not be specified on the same interface.

The [`LegacyWindowAlias`{.idl}](#LegacyWindowAlias) and [`LegacyNamespace`{.idl}](#LegacyNamespace) extended attributes must not be specified on the same interface.

The [`LegacyWindowAlias`{.idl}](#LegacyWindowAlias) extended attribute must not be specified on an interface that does not include the [`Window`{.idl}](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) interface in its exposure set.

An interface must not have more than one [`LegacyWindowAlias`{.idl}](#LegacyWindowAlias) extended attributes specified.

See § 3.7 Interfaces for details on how legacy window aliases are to be implemented.

The following IDL defines an interface that uses the [`LegacyWindowAlias`{.idl}](#LegacyWindowAlias) extended attribute.

``` highlight
[Exposed=Window,
 LegacyWindowAlias=WebKitCSSMatrix]
interface DOMMatrix : DOMMatrixReadOnly {
  // ...
};
```

A JavaScript implementation that supports this interface will expose two properties on the [`Window`{.idl}](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) object with the same value and the same characteristics; one for exposing the interface object normally, and one for exposing it with a legacy name.

``` highlight
WebKitCSSMatrix === DOMMatrix;     // Evaluates to true.

var m = new WebKitCSSMatrix();     // Creates a new object that
                                   // implements DOMMatrix.

m.constructor === DOMMatrix;       // Evaluates to true.
m.constructor === WebKitCSSMatrix; // Evaluates to true.
{}.toString.call(m);               // Evaluates to '[object DOMMatrix]'.
```


## Security

Certain algorithms in the sections below are defined to perform a security check on a given object. This check is used to determine whether a given operation invocation or attribute access should be allowed. The security check takes the following three inputs:

1. the platform object on which the operation invocation or attribute access is being done,

2. the identifier of the operation or attribute, and

3. the type of the function object -- "`method`" (when it corresponds to an IDL operation), or "`getter`" or "`setter`" (when it corresponds to the getter or setter function of an IDL attribute).

Note: The HTML Standard defines how a security check is performed. [[HTML]](#biblio-html)


### Overload resolution algorithm

In order to define how function invocations are resolved, the **overload resolution algorithm** is defined. Its input is an effective overload set, `S`, and a list of JavaScript values, `args`. Its output is a pair consisting of the operation or extended attribute of one of `S`'s entries and a list of IDL values or the special value "missing". The algorithm behaves as follows:

1.  Let `maxarg` be the length of the longest type list of the entries in `S`.

2.  Let `n` be the size of `args`.

3.  Initialize `argcount` to be min(`maxarg`, `n`).

4.  Remove from `S` all entries whose type list is not of length `argcount`.

5.  If `S` is empty, then throw a `TypeError`.

6.  Initialize `d` to −1.

7.  Initialize `method` to undefined.

8.  If there is more than one entry in `S`, then set `d` to be the distinguishing argument index for the entries of `S`.

9.  Initialize `values` to be an empty list, where each entry will be either an IDL value or the special value "missing".

10. Initialize `i` to 0.

11. While `i` < `d`:

    1.  Let `V` be `args`[`i`].

    2.  Let `type` be the type at index `i` in the type list of any entry in `S`.

        Note: All entries in `S` at this point have the same type and optionality value at index `i`.

    3.  Let `optionality` be the value at index `i` in the list of optionality values of any entry in `S`.

    4.  If `optionality` is "optional" and `V` is undefined, then:

        1.  If the argument at index `i` is declared with a default value, then append to `values` that default value.

        2.  Otherwise, append to `values` the special value "missing".

    5.  Otherwise, append to `values` the result of converting `V` to IDL type `type`.

    6.  Set `i` to `i` + 1.

12. If `i` = `d`, then:

    1.  Let `V` be `args`[`i`].

        Note: This is the argument that will be used to resolve which overload is selected.

    2.  If `V` is undefined, and there is an entry in `S` whose list of optionality values has "optional" at index `i`, then remove from `S` all other entries.

    3.  Otherwise: if `V` is null or undefined, and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - a nullable type

        - a dictionary type

        - an annotated type whose inner type is one of the above types

        - a union type or annotated union type that includes a nullable type or that has a dictionary type in its flattened members

        then remove from `S` all other entries.

    4.  Otherwise: if `V` is a platform object, and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - an interface type that `V` implements

        - `object`

        - a nullable version of any of the above types

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    5.  Otherwise: if `V` is an Object, `V` has an \[\[ArrayBufferData\]\] internal slot, and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - `ArrayBuffer`

        - `SharedArrayBuffer`

        - `object`

        - a nullable version of either of the above types

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    6.  Otherwise: if `V` is an Object, `V` has a \[\[DataView\]\] internal slot, and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - `DataView`

        - `object`

        - a nullable version of either of the above types

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    7.  Otherwise: if `V` is an Object, `V` has a \[\[TypedArrayName\]\] internal slot, and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - a typed array type whose name is equal to the value of `V`'s \[\[TypedArrayName\]\] internal slot

        - `object`

        - a nullable version of either of the above types

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    8.  Otherwise: if IsCallable(`V`) is true, and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - a callback function type

        - `object`

        - a nullable version of any of the above types

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    9.  Otherwise: if `V` is an Object and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - an async sequence type

        - a nullable version of any of the above types

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        and the following are not all true,

        - `V` has a \[\[StringData\]\] internal slot

        - `S` has one of the following types at position `i` of its type list,

          - a string type

          - a nullable version of a string type

          - an annotated type whose inner type is a string type

          - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        and after performing the following steps,

        1.  Let `method` be ? GetMethod(`V`, `%Symbol.asyncIterator%`).

        2.  If `method` is undefined, then set `method` to ? GetMethod(`V`, `%Symbol.iterator%`).

        `method` is not undefined, then remove from `S` all other entries.

    10. Otherwise: if `V` is an Object and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - a sequence type

        - a nullable version of any of the above types

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        and after performing the following steps,

        1.  Let `method` be ? GetMethod(`V`, `%Symbol.iterator%`).

        `method` is not undefined, then remove from `S` all other entries.

    11. Otherwise: if `V` is an Object and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - a callback interface type

        - a dictionary type

        - a record type

        - `object`

        - a nullable version of any of the above types

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    12. Otherwise: if `V` is a Boolean and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - `boolean`

        - a nullable `boolean`

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    13. Otherwise: if `V` is a Number and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - a numeric type

        - a nullable numeric type

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    14. Otherwise: if `V` is a BigInt and there is an entry in `S` that has one of the following types at position `i` of its type list,

        - `bigint`

        - a nullable `bigint`

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    15. Otherwise: if there is an entry in `S` that has one of the following types at position `i` of its type list,

        - a string type

        - a nullable version of any of the above types

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    16. Otherwise: if there is an entry in `S` that has one of the following types at position `i` of its type list,

        - a numeric type

        - a nullable numeric type

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    17. Otherwise: if there is an entry in `S` that has one of the following types at position `i` of its type list,

        - `boolean`

        - a nullable `boolean`

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    18. Otherwise: if there is an entry in `S` that has one of the following types at position `i` of its type list,

        - `bigint`

        - a nullable `bigint`

        - an annotated type whose inner type is one of the above types

        - a union type, nullable union type, or annotated union type that has one of the above types in its flattened member types

        then remove from `S` all other entries.

    19. Otherwise: if there is an entry in `S` that has `any` at position `i` of its type list, then remove from `S` all other entries.

    20. Otherwise: throw a `TypeError`.

13. Let `callable` be the operation or extended attribute of the single entry in `S`.

14. If `i` = `d` and `method` is not undefined, then

    1.  Let `V` be `args`[`i`].

    2.  Let `T` be the type at index `i` in the type list of the remaining entry in `S`.

    3.  Assert: `T` is a sequence type.

    4.  Append to `values` the result of creating a sequence of type `T` from `V` and `method`.

    5.  Set `i` to `i` + 1.

15. While `i` < `argcount`:

    1.  Let `V` be `args`[`i`].

    2.  Let `type` be the type at index `i` in the type list of the remaining entry in `S`.

    3.  Let `optionality` be the value at index `i` in the list of optionality values of the remaining entry in `S`.

    4.  If `optionality` is "optional" and `V` is undefined, then:

        1.  If the argument at index `i` is declared with a default value, then append to `values` that default value.

        2.  Otherwise, append to `values` the special value "missing".

    5.  Otherwise, append to `values` the result of converting `V` to IDL type `type`.

    6.  Set `i` to `i` + 1.

16. While `i` is less than the number of arguments `callable` is declared to take:

    1.  If `callable`'s argument at index `i` is declared with a default value, then append to `values` that default value.

    2.  Otherwise, if `callable`'s argument at index `i` is not variadic, then append to `values` the special value "missing".

    3.  Set `i` to `i` + 1.

17. Return the pair <`callable`, `values`>.

Note: The overload resolution algorithm performs both the identification of which overloaded operation, constructor, etc. is being called, and the conversion of the JavaScript argument values to their corresponding IDL values. Informally, it operates as follows.

First, the selection of valid overloads is done by considering the number of JavaScript arguments that were passed in to the function:

- If there are more arguments passed in than the longest overload argument list, then they are ignored.

- After ignoring these trailing arguments, only overloads that can take this exact number of arguments are considered. If there are none, then a `TypeError` is thrown.

Once we have a set of possible overloads with the right number of arguments, the JavaScript values are converted from left to right. The nature of the restrictions on overloading means that if we have multiple possible overloads at this point, then there will be one position in the argument list that will be used to distinguish which overload we will finally select; this is the distinguishing argument index.

We first convert the arguments to the left of the distinguishing argument. (There is a requirement that an argument to the left of the distinguishing argument index has the same type as in the other overloads, at the same index.) Then we inspect the type of the JavaScript value that is passed in at the distinguishing argument index to determine which IDL type it can correspond to. This allows us to select the final overload that will be invoked. If the value passed in is undefined and there is an overload with an optional argument at this position, then we will choose that overload. If there is no valid overload for the type of value passed in here, then we throw a `TypeError`. Generally, the inspection of the value at the distinguishing argument index does not have any side effects, and the only side effects in the overload resolution algorithm are the result of converting the JavaScript values to IDL values. (An exception exists when one of the overloads has an async sequence type, sequence type or frozen array type at the distinguishing argument index. In this case, we attempt to get the `%Symbol.asyncIterator%` / `%Symbol.iterator%` property to determine the appropriate overload, and perform the conversion of the distinguishing argument separately before continuing with the next step.)

At this point, we have determined which overload to use. We now convert the remaining arguments, from the distinguishing argument onwards, again ignoring any additional arguments that were ignored due to being passed after the last possible argument.

When converting an optional argument's JavaScript value to its equivalent IDL value, undefined will be converted into the optional argument's default value, if it has one, or a special value "missing" otherwise.

Optional arguments corresponding to a final, variadic argument do not treat undefined as a special "missing" value, however. The undefined value is converted to the type of variadic argument as would be done for a non-optional argument.


### Interfaces

For every interface that is exposed in a given realm and that is not declared with the [[`LegacyNoInterfaceObject`](#LegacyNoInterfaceObject)] or [[`LegacyNamespace`](#LegacyNamespace)] extended attributes, a corresponding property exists on the realm's global object. The name of the property is the identifier of the interface, and its value is an object called the **interface object**. The characteristics of an interface object are described in § 3.7.1 Interface object.

If the [[`LegacyWindowAlias`](#LegacyWindowAlias)] extended attribute was specified on an exposed interface, then for each identifier in [[`LegacyWindowAlias`](#LegacyWindowAlias)]'s identifiers there exists a corresponding property on the [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) global object. The name of the property is the given identifier, and its value is a reference to the interface object for the interface.

In addition, for every [[`LegacyFactoryFunction`](#LegacyFactoryFunction)] extended attribute on an exposed interface, a corresponding property exists on the JavaScript global object. The name of the property is the [[`LegacyFactoryFunction`](#LegacyFactoryFunction)]'s identifier, and its value is an object called a **legacy factory function**, which allows creation of objects that implement the interface. The characteristics of a legacy factory function are described in § 3.7.2 Legacy factory functions.

Some JavaScript methods defined in this section will perform an implementation check in their opening steps, to ensure they're being called on the correct kind of object and that the method is valid to call from the current context.

To **implementation-check an object** `jsValue` against the interface `interface`, with the identifier `name` and the type `type`:

1.  Let `object` to ? [ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(`jsValue`).

2.  If `object` is a platform object, then perform a security check, passing:

    - the platform object `object`

    - the identifier `name`

    - the type `type`

3.  If `object` does not implement `interface`, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

4.  Return `object`.


#### Interface object

The interface object for a given interface is a built-in function object. It has properties that correspond to the constants and static operations defined on that interface, as described in sections § 3.7.5 Constants and § 3.7.7 Operations.

If the interface is declared with a constructor operation, then the interface object can be called as a constructor to create an object that implements that interface. Calling that interface as a function will throw an exception.

Interface objects whose interfaces are not declared with a constructor operation will throw when called, both as a function and as a constructor.

An interface object for an interface has an associated object called the interface prototype object. This object has properties that correspond to the regular attributes and regular operations defined on the interface, and is described in more detail in § 3.7.3 Interface prototype object.

**Note:** Since an interface object is a function object the `typeof` operator will return "function" when applied to an interface object.

An interface may have **overridden constructor steps**, which can change the behavior of the interface object when called or constructed. By default interfaces do not have such steps.

The interface object for a given interface `I` with identifier `id` and in realm `realm` is **created** as follows:

1.  Let `steps` be `I`'s overridden constructor steps if they exist, or the following steps otherwise:

    1.  If `I` was not declared with a constructor operation, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

    2.  If [`NewTarget`](https://tc39.es/ecma262/#sec-built-in-function-objects) is undefined, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

    3.  Let `args` be the passed arguments.

    4.  Let `n` be the size of `args`.

    5.  Let `id` be the identifier of interface `I`.

    6.  Compute the effective overload set for constructors with identifier `id` on interface `I` and with argument count `n`, and let `S` be the result.

    7.  Let <`constructor`, `values`> be the result of passing `S` and `args` to the overload resolution algorithm.

    8.  Let `object` be the result of internally creating a new object implementing `I`, with `realm` and [`NewTarget`](https://tc39.es/ecma262/#sec-built-in-function-objects).

    9.  Perform the constructor steps of `constructor` with `object` as this and `values` as the argument values.

    10. Let `O` be `object`, converted to a JavaScript value.

    11. Assert: `O` is an object that implements `I`.

    12. Assert: `O`.[[Realm]] is `realm`.

    13. Return `O`.

2.  Let `constructorProto` be `realm`.[[Intrinsics]].[[`%Function.prototype%`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-properties-of-the-function-prototype-object)].

3.  If `I` inherits from some other interface `P`, then set `constructorProto` to the interface object of `P` in `realm`.

4.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « [[Unforgeables]] », `realm`, `constructorProto`).

5.  Let `unforgeables` be [OrdinaryObjectCreate](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinaryobjectcreate)(null).

6.  Define the unforgeable regular operations of `I` on `unforgeables`, given `realm`.

7.  Define the unforgeable regular attributes of `I` on `unforgeables`, given `realm`.

8.  Set `F`.[[Unforgeables]] to `unforgeables`.

    **Note:** this object is never exposed to user code. It exists only to ensure all instances of an interface with an unforgeable member use the same JavaScript function objects for attribute getters, attribute setters and operation functions.

9.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, `id`).

10. Let `length` be 0.

11. If `I` was declared with a constructor operation, then

    1.  Compute the effective overload set for constructors with identifier `id` on interface `I` and with argument count 0, and let `S` be the result.

    2.  Set `length` to the length of the shortest argument list of the entries in `S`.

12. Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, `length`).

13. Let `proto` be the result of creating an interface prototype object of interface `I` in `realm`.

14. Perform ! [DefinePropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-definepropertyorthrow)(`F`, "`prototype`", PropertyDescriptor{[[Value]]: `proto`, [[Writable]]: false, [[Enumerable]]: false, [[Configurable]]: false}).

15. Define the constants of interface `I` on `F` given `realm`.

16. Define the static attributes of interface `I` on `F` given `realm`.

17. Define the static operations of interface `I` on `F` given `realm`.

18. Return `F`.


#### Legacy factory functions

A legacy factory function that exists due to one or more [[`LegacyFactoryFunction`](#LegacyFactoryFunction)] extended attributes with a given identifier is a built-in function object. It allows constructing objects that implement the interface on which the [[`LegacyFactoryFunction`](#LegacyFactoryFunction)] extended attributes appear.

The legacy factory function with identifier `id` for a given interface `I` in realm `realm` is **created** as follows:

1.  Let `steps` be the following steps:

    1.  If [`NewTarget`](https://tc39.es/ecma262/#sec-built-in-function-objects) is undefined, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

    2.  Let `args` be the passed arguments.

    3.  Let `n` be the size of `args`.

    4.  Compute the effective overload set for legacy factory functions with identifier `id` on interface `I` and with argument count `n`, and let `S` be the result.

    5.  Let <`constructor`, `values`> be the result of passing `S` and `args` to the overload resolution algorithm.

    6.  Let `object` be the result of internally creating a new object implementing `I`, with `realm` and [`NewTarget`](https://tc39.es/ecma262/#sec-built-in-function-objects).

    7.  Perform the constructor steps of `constructor` with `object` as this and `values` as the argument values.

    8.  Let `O` be `object`, converted to a JavaScript value.

    9.  Assert: `O` is an object that implements `I`.

    10. Assert: `O`.[[Realm]] is `realm`.

    11. Return `O`.

2.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « », `realm`).

3.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, `id`).

4.  Compute the effective overload set for legacy factory functions with identifier `id` on interface `I` and with argument count 0, and let `S` be the result.

5.  Let `length` be the length of the shortest argument list of the entries in `S`.

6.  Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, `length`).

7.  Let `proto` be the interface prototype object of interface `I` in `realm`.

8.  Perform ! [DefinePropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-definepropertyorthrow)(`F`, "`prototype`", PropertyDescriptor{[[Value]]: `proto`, [[Writable]]: false, [[Enumerable]]: false, [[Configurable]]: false}).

9.  Return `F`.


#### Interface prototype object

There will exist an **interface prototype object** for every interface defined, regardless of whether the interface was declared with the [[`LegacyNoInterfaceObject`](#LegacyNoInterfaceObject)] extended attribute.

The interface prototype object for a given interface `interface` and realm `realm` is **created** as follows:

1.  Let `proto` be null.

2.  If `interface` is declared with the [[`Global`](#Global)] extended attribute, and `interface` supports named properties, then set `proto` to the result of creating a named properties object for `interface` and `realm`.

3.  Otherwise, if `interface` is declared to inherit from another interface, then set `proto` to the interface prototype object in `realm` of that inherited interface.

4.  Otherwise, if `interface` is the [`DOMException`](#idl-DOMException) interface, then set `proto` to `realm`.[[Intrinsics]].[[`%Error.prototype%`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-properties-of-the-error-prototype-object)].

5.  Otherwise, set `proto` to `realm`.[[Intrinsics]].[[`%Object.prototype%`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-properties-of-the-object-prototype-object)].

6.  Assert: `proto` is an Object.

7.  Let `interfaceProtoObj` be null.

8.  If `realm`'s is global prototype chain mutable is true, then:

    1.  Set `interfaceProtoObj` to [OrdinaryObjectCreate](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinaryobjectcreate)(`proto`).

9.  Otherwise, if `interface` is declared with the [[`Global`](#Global)] extended attribute, or `interface` is in the set of inherited interfaces of an interface that is declared with the [[`Global`](#Global)] extended attribute, then:

    1.  Set `interfaceProtoObj` to [MakeBasicObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-makebasicobject)(« [[Prototype]], [[Extensible]] »).

    2.  Set `interfaceProtoObj`.[[Prototype]] to `proto`.

    3.  Set the internal methods of `interfaceProtoObj` which are specific to immutable prototype exotic objects to the definitions specified in ECMA-262 Immutable prototype exotic objects.

10. Otherwise, set `interfaceProtoObj` to [OrdinaryObjectCreate](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinaryobjectcreate)(`proto`).

11. If `interface` has any member declared with the [[`Unscopable`](#Unscopable)] extended attribute, then:

    1.  Let `unscopableObject` be [OrdinaryObjectCreate](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinaryobjectcreate)(null).

    2.  For each exposed member `member` of `interface` that is declared with the [[`Unscopable`](#Unscopable)] extended attribute:

        1.  Let `id` be `member`'s identifier.

        2.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`unscopableObject`, `id`, true).

    3.  Let `desc` be the PropertyDescriptor{[[Value]]: `unscopableObject`, [[Writable]]: false, [[Enumerable]]: false, [[Configurable]]: true}.

    4.  Perform ! [DefinePropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-definepropertyorthrow)(`interfaceProtoObj`, [`%Symbol.unscopables%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols), `desc`).

12. If `interface` is not declared with the [[`Global`](#Global)] extended attribute, then:

    1.  Define the regular attributes of `interface` on `interfaceProtoObj` given `realm`.

    2.  Define the regular operations of `interface` on `interfaceProtoObj` given `realm`.

    3.  Define the iteration methods of `interface` on `interfaceProtoObj` given `realm`.

    4.  Define the asynchronous iteration methods of `interface` on `interfaceProtoObj` given `realm`.

13. Define the constants of `interface` on `interfaceProtoObj` given `realm`.

14. If the [[`LegacyNoInterfaceObject`](#LegacyNoInterfaceObject)] extended attribute was not specified on `interface`, then:

    1.  Let `constructor` be the interface object of `interface` in `realm`.

    2.  Let `desc` be the PropertyDescriptor{[[Writable]]: true, [[Enumerable]]: false, [[Configurable]]: true, [[Value]]: `constructor`}.

    3.  Perform ! [DefinePropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-definepropertyorthrow)(`interfaceProtoObj`, "`constructor`", `desc`).

15. Return `interfaceProtoObj`.

**Note:** The interface prototype object of an interface that is defined with the [[`LegacyNoInterfaceObject`](#LegacyNoInterfaceObject)] extended attribute will be accessible. For example, with the following IDL:

```
[Exposed=Window,
 LegacyNoInterfaceObject]
interface Foo {
};

partial interface Window {
  attribute Foo foo;
};
```

it is not possible to access the interface prototype object through the interface object (since it does not exist as `window.Foo`). However, an instance of `Foo` can expose the interface prototype object by calling its [[GetPrototypeOf]] internal method -- `Object.getPrototypeOf(window.foo)` in this example.

The class string of an interface prototype object is the interface's qualified name.


#### Named properties object

For every interface declared with the [[`Global`](#Global)] extended attribute that supports named properties, there will exist an object known as the **named properties object** for that interface on which named properties are exposed.

The named properties object for a given interface `interface` and realm `realm`, is **created** as follows:

1.  Let `proto` be null.

2.  If `interface` is declared to inherit from another interface, then set `proto` to the interface prototype object in `realm` for the inherited interface.

3.  Otherwise, set `proto` to `realm`.[[Intrinsics]].[[`%Object.prototype%`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-properties-of-the-object-prototype-object)].

4.  Let `obj` be [MakeBasicObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-makebasicobject)(« [[Prototype]], [[Extensible]] »).

5.  Set `obj`.[[GetOwnProperty]] as specified in § 3.7.4.1 [[GetOwnProperty]].

6.  Set `obj`.[[DefineOwnProperty]] as specified in § 3.7.4.2 [[DefineOwnProperty]].

7.  Set `obj`.[[Delete]] as specified in § 3.7.4.3 [[Delete]].

8.  Set `obj`.[[SetPrototypeOf]] as specified in § 3.7.4.4 [[SetPrototypeOf]].

9.  Set `obj`.[[PreventExtensions]] as specified in § 3.7.4.5 [[PreventExtensions]].

10. Set `obj`.[[Prototype]] to `proto`.

11. Return `obj`.

**Note:** The [[OwnPropertyKeys]] internal method of a named properties object continues to use [OrdinaryOwnPropertyKeys](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinaryownpropertykeys), unlike the counterpart for legacy platform objects. Since named properties are not "real" own properties, they will not be returned by this internal method.

The class string of a named properties object is the concatenation of the interface's identifier and the string "`Properties`".


##### [[GetOwnProperty]]

When the [[GetOwnProperty]] internal method of a named properties object `O` is called with property key `P`, the following steps are taken:

1.  Let `A` be the interface for the named properties object `O`.

2.  Let `object` be `O`.[[Realm]]'s global object.

3.  Assert: `object` implements `A`.

4.  If the result of running the named property visibility algorithm with property name `P` and object `object` is true, then:

    1.  Let `operation` be the operation used to declare the named property getter.

    2.  Let `value` be an uninitialized variable.

    3.  If `operation` was defined without an identifier, then set `value` to the result of performing the steps listed in the interface description to determine the value of a named property with `P` as the name.

    4.  Otherwise, `operation` was defined with an identifier. Set `value` to the result of performing the steps listed in the description of `operation` with `P` as the only argument value.

    5.  Let `desc` be a newly created Property Descriptor with no fields.

    6.  Set `desc`.[[Value]] to the result of converting `value` to a JavaScript value.

    7.  If `A` implements an interface with the [[`LegacyUnenumerableNamedProperties`](#LegacyUnenumerableNamedProperties)] extended attribute, then set `desc`.[[Enumerable]] to false, otherwise set it to true.

    8.  Set `desc`.[[Writable]] to true and `desc`.[[Configurable]] to true.

    9.  Return `desc`.

5.  Return [OrdinaryGetOwnProperty](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinarygetownproperty)(`O`, `P`).


##### [[DefineOwnProperty]]

When the [[DefineOwnProperty]] internal method of a named properties object is called, the following steps are taken:

1.  Return false.


##### [[Delete]]

When the [[Delete]] internal method of a named properties object is called, the following steps are taken:

1.  Return false.


##### [[SetPrototypeOf]]

When the [[SetPrototypeOf]] internal method of a named properties object `O` is called with JavaScript language value `V`, the following step is taken:

1.  If `O`'s associated realm's is global prototype chain mutable is true, return ? [OrdinarySetPrototypeOf](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinarysetprototypeof)(`O`, `V`).

2.  Return ? [SetImmutablePrototype](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-set-immutable-prototype)(`O`, `V`).


##### [[PreventExtensions]]

When the [[PreventExtensions]] internal method of a named properties object is called, the following steps are taken:

1.  Return false.

    **Note:** this keeps named properties object extensible by making [[PreventExtensions]] fail.


#### Constants

Constants are exposed on interface objects, legacy callback interface objects, interface prototype objects, and on the single object that implements the interface, when an interface is declared with the [[`Global`](#Global)] extended attribute.

To **define the constants** of interface, callback interface, or namespace `definition` on `target`, given realm `realm`, run the following steps:

1.  For each constant `const` that is a member of `definition`:

    1.  If `const` is not exposed in `realm`, then continue.

    2.  Let `value` be the result of converting `const`'s IDL value to a JavaScript value.

    3.  Let `desc` be the PropertyDescriptor{[[Writable]]: false, [[Enumerable]]: true, [[Configurable]]: false, [[Value]]: `value`}.

    4.  Let `id` be `const`'s identifier.

    5.  Perform ! [DefinePropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-definepropertyorthrow)(`target`, `id`, `desc`).


#### Attributes

Static attributes are exposed on the interface object. Regular attributes are exposed on the interface prototype object, unless the attribute is unforgeable or if the interface was declared with the [[`Global`](#Global)] extended attribute, in which case they are exposed on every object that implements the interface.

To **define the regular attributes** of interface or namespace `definition` on `target`, given realm `realm`, run the following steps:

1.  Let `attributes` be the list of regular attributes that are members of `definition`.

2.  Remove from `attributes` all the attributes that are unforgeable.

3.  Define the attributes `attributes` of `definition` on `target` given `realm`.

To **define the static attributes** of interface or namespace `definition` on `target`, given realm `realm`, run the following steps:

1.  Let `attributes` be the list of static attributes that are members of `definition`.

2.  Define the attributes `attributes` of `definition` on `target` given `realm`.

To **define the unforgeable regular attributes** of interface or namespace `definition` on `target`, given realm `realm`, run the following steps:

1.  Let `attributes` be the list of unforgeable regular attributes that are members of `definition`.

2.  Define the attributes `attributes` of `definition` on `target` given `realm`.

To **define the attributes** `attributes` of interface or namespace `definition` on `target` given realm `realm`, run the following steps:

1.  For each attribute `attr` of `attributes`:

    1.  If `attr` is not exposed in `realm`, then continue.

    2.  Let `getter` be the result of creating an attribute getter given `attr`, `definition`, and `realm`.

    3.  Let `setter` be the result of creating an attribute setter given `attr`, `definition`, and `realm`.

        **Note:** the algorithm to create an attribute setter returns undefined if `attr` is read only.

    4.  Let `configurable` be false if `attr` is unforgeable and true otherwise.

    5.  Let `desc` be the PropertyDescriptor{[[Get]]: `getter`, [[Set]]: `setter`, [[Enumerable]]: true, [[Configurable]]: `configurable`}.

    6.  Let `id` be `attr`'s identifier.

    7.  Perform ! [DefinePropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-definepropertyorthrow)(`target`, `id`, `desc`).

    8.  If `attr`'s type is an observable array type with type argument `T`, then set `target`'s backing observable array exotic object for `attr` to the result of creating an observable array exotic object in `realm`, given `T`, `attr`'s set an indexed value algorithm, and `attr`'s delete an indexed value algorithm.

The **attribute getter** is created as follows, given an attribute `attribute`, a namespace or interface `target`, and a realm `realm`:

1.  Let `steps` be the following series of steps:

    1.  Try running the following steps:

        1.  Let `idlObject` be null.

        2.  If `target` is an interface, and `attribute` is a regular attribute:

            1.  Let `jsValue` be the this value, if it is not null or undefined, or `realm`'s global object otherwise. (This will subsequently cause a [`TypeError`](#exceptiondef-typeerror) in a few steps, if the global object does not implement `target` and [[`LegacyLenientThis`](#LegacyLenientThis)] is not specified.)

            2.  If `jsValue` is a platform object, then perform a security check, passing `jsValue`, `attribute`'s identifier, and "getter".

            3.  If `jsValue` does not implement `target`, then:

                1.  If `attribute` was specified with the [[`LegacyLenientThis`](#LegacyLenientThis)] extended attribute, then return undefined.

                2.  Otherwise, throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

            4.  If `attribute`'s type is an observable array type, then return `jsValue`'s backing observable array exotic object for `attribute`.

            5.  Set `idlObject` to the IDL interface type value that represents a reference to `jsValue`.

        3.  Let `R` be the result of running the getter steps of `attribute` with `idlObject` as this.

        4.  Return the result of converting `R` to a JavaScript value of the type `attribute` is declared as.

    And then, if an exception `E` was thrown:

    1.  If `attribute`'s type is a promise type, then return ! [Call]([`%Promise.reject%`](https://tc39.es/ecma262/#sec-promise.reject), [`%Promise%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-constructor), «`E`»).

    2.  Otherwise, end these steps and allow the exception to propagate.

2.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « », `realm`).

3.  Let `name` be the string "`get `" prepended to `attribute`'s identifier.

4.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, `name`).

5.  Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, 0).

6.  Return `F`.

The **attribute setter** is created as follows, given an attribute `attribute`, a namespace or interface `target`, and a realm `realm`:

1.  If `target` is a namespace:

    1.  Assert: `attribute` is read only.

    2.  Return undefined.

2.  If `attribute` is read only and does not have a [[`LegacyLenientSetter`](#LegacyLenientSetter)], [[`PutForwards`](#PutForwards)] or [[`Replaceable`](#Replaceable)] extended attribute, return undefined; there is no attribute setter function.

3.  Assert: `attribute`'s type is not a promise type.

4.  Let `steps` be the following series of steps:

    1.  Let `V` be undefined.

    2.  If any arguments were passed, then set `V` to the value of the first argument passed.

    3.  Let `id` be `attribute`'s identifier.

    4.  Let `idlObject` be null.

    5.  If `attribute` is a regular attribute:

        1.  Let `jsValue` be the this value, if it is not null or undefined, or `realm`'s global object otherwise. (This will subsequently cause a [`TypeError`](#exceptiondef-typeerror) in a few steps, if the global object does not implement `target` and [[`LegacyLenientThis`](#LegacyLenientThis)] is not specified.)

        2.  If `jsValue` is a platform object, then perform a security check, passing `jsValue`, `id`, and "setter".

        3.  Let `validThis` be true if `jsValue` implements `target`, or false otherwise.

        4.  If `validThis` is false and `attribute` was not specified with the [[`LegacyLenientThis`](#LegacyLenientThis)] extended attribute, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

        5.  If `attribute` is declared with the [[`Replaceable`](#Replaceable)] extended attribute, then:

            1.  Perform ? [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`jsValue`, `id`, `V`).

            2.  Return undefined.

        6.  If `validThis` is false, then return undefined.

        7.  If `attribute` is declared with a [[`LegacyLenientSetter`](#LegacyLenientSetter)] extended attribute, then return undefined.

        8.  If `attribute` is declared with a [[`PutForwards`](#PutForwards)] extended attribute, then:

            1.  Let `Q` be ? [Get](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-get-o-p)(`jsValue`, `id`).

            2.  If `Q` is not an Object, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

            3.  Let `forwardId` be the identifier argument of the [[`PutForwards`](#PutForwards)] extended attribute.

            4.  Perform ? [Set](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-set-o-p-v-throw)(`Q`, `forwardId`, `V`, false).

            5.  Return undefined.

        9.  Set `idlObject` to the IDL interface type value that represents a reference to `jsValue`.

        10. If `attribute`'s type is an observable array type with type argument `T`:

            1.  Let `newValues` be the result of converting `V` to an IDL value of type sequence<`T`>.

            2.  Let `oa` be `idlObject`'s `attribute`'s backing observable array exotic object.

            3.  Set the length of `oa`.[[ProxyHandler]] to 0.

            4.  Let `i` be 0.

            5.  While `i` < `newValues`'s size:

                1.  Perform the algorithm steps given by `oa`.[[ProxyHandler]].[[SetAlgorithm]], given `newValues`[`i`] and `i`.

                2.  Append `newValues`[`i`] to `oa`.[[ProxyHandler]].[[BackingList]].

            6.  Return undefined.

    6.  Let `idlValue` be determined as follows:

        `attribute`'s type is an enumeration

        :   1.  Let `S` be ? [ToString](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tostring)(`V`).

            2.  If `S` is not one of the enumeration's values, then return undefined.

            3.  Otherwise, `idlValue` is the enumeration value equal to `S`.

        Otherwise
        :   `idlValue` is the result of converting `V` to an IDL value of `attribute`'s type.

    7.  Perform the setter steps of `attribute`, with `idlObject` as this and `idlValue` as the given value.

    8.  Return undefined

5.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « », `realm`).

6.  Let `name` be the string "`set `" prepended to `id`.

7.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, `name`).

8.  Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, 1).

9.  Return `F`.

**Note:** Although there is only a single property for an IDL attribute, since accessor property getters and setters are passed a this value for the object on which property corresponding to the IDL attribute is accessed, they are able to expose instance-specific data.

**Note:** Attempting to assign to a property corresponding to a read only attribute results in different behavior depending on whether the script doing so is in strict mode. When in strict mode, such an assignment will result in a [`TypeError`](#exceptiondef-typeerror) being thrown. When not in strict mode, the assignment attempt will be ignored.


#### Operations

For each unique identifier of an exposed operation defined on the interface, there exist a corresponding property. Static operations are exposed of the interface object. Regular operations are exposed on the interface prototype object, unless the operation is unforgeable or the interface was declared with the [[`Global`](#Global)] extended attribute, in which case they are exposed on every object that implements the interface.

To **define the regular operations** of interface or namespace `definition` on `target`, given realm `realm`, run the following steps:

1.  Let `operations` be the list of regular operations that are members of `definition`.

2.  Remove from `operations` all the operations that are unforgeable.

3.  Define the operations `operations` of `definition` on `target` given `realm`.

To **define the static operations** of interface or namespace `definition` on `target`, given realm `realm`, run the following steps:

1.  Let `operations` be the list of static operations that are members of `definition`.

2.  Define the operations `operations` of `definition` on `target` given `realm`.

To **define the unforgeable regular operations** of interface or namespace `definition` on `target`, given realm `realm`, run the following steps:

1.  Let `operations` be the list of unforgeable regular operations that are members of `definition`.

2.  Define the operations `operations` of `definition` on `target` given `realm`.

To **define the operations** `operations` of interface or namespace `definition` on `target`, given realm `realm`, run the following steps:

1.  For each operation `op` of `operations`:

    1.  If `op` is not exposed in `realm`, then continue.

    2.  Let `method` be the result of creating an operation function given `op`, `definition`, and `realm`.

    3.  Let `modifiable` be false if `op` is unforgeable and true otherwise.

    4.  Let `desc` be the PropertyDescriptor{[[Value]]: `method`, [[Writable]]: `modifiable`, [[Enumerable]]: true, [[Configurable]]: `modifiable`}.

    5.  Let `id` be `op`'s identifier.

    6.  Perform ! [DefinePropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-definepropertyorthrow)(`target`, `id`, `desc`).

To **create an operation function**, given an operation `op`, a namespace or interface `target`, and a realm `realm`:

1.  Let `id` be `op`'s identifier.

2.  Let `steps` be the following series of steps, given function argument values `args`:

    1.  Try running the following steps:

        1.  Let `idlObject` be null.

        2.  If `target` is an interface, and `op` is not a static operation:

            1.  Let `jsValue` be the this value, if it is not null or undefined, or `realm`'s global object otherwise. (This will subsequently cause a [`TypeError`](#exceptiondef-typeerror) in a few steps, if the global object does not implement `target` and [[`LegacyLenientThis`](#LegacyLenientThis)] is not specified.)

            2.  If `jsValue` is a platform object, then perform a security check, passing `jsValue`, `id`, and "method".

            3.  If `jsValue` does not implement the interface `target`, throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

            4.  Set `idlObject` to the IDL interface type value that represents a reference to `jsValue`.

        3.  Let `n` be the size of `args`.

        4.  Compute the effective overload set for regular operations (if `op` is a regular operation) or for static operations (if `op` is a static operation) with identifier `id` on `target` and with argument count `n`, and let `S` be the result.

        5.  Let <`operation`, `values`> be the result of passing `S` and `args` to the overload resolution algorithm.

        6.  Let `R` be null.

        7.  If `operation` is declared with a [[`Default`](#Default)] extended attribute, then:

            1.  Assert: `operation` has default method steps.

            2.  Set `R` to the result of running the default method steps for `operation`, with `idlObject` as this and `values` as the argument values.

        8.  Otherwise, set `R` to the result of running the method steps of `operation`, with `idlObject` as this and `values` as the argument values.

        9.  Return `R`, converted to a JavaScript value.

    And then, if an exception `E` was thrown:

    1.  If `op` has a return type that is a promise type, then return ! [Call]([`%Promise.reject%`](https://tc39.es/ecma262/#sec-promise.reject), [`%Promise%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-constructor), «`E`»).

    2.  Otherwise, end these steps and allow the exception to propagate.

3.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « », `realm`).

4.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, `id`).

5.  Compute the effective overload set for regular operations (if `op` is a regular operation) or for static operations (if `op` is a static operation) with identifier `id` on `target` and with argument count 0, and let `S` be the result.

6.  Let `length` be the length of the shortest argument list in the entries in `S`.

7.  Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, `length`).

8.  Return `F`.


##### Default operations

A regular operation **has default method steps** if its identifier appears in the first column of the following table. In that case, its **default method steps** are those given by the algorithm linked from the second column of the table, and the operation must have the return type given in the third column of the table.

  Identifier   Default method steps       Return type
  ------------ -------------------------- -------------
  "`toJSON`"   The default toJSON steps   [`object`](#idl-object)

A regular operation that does not have default method steps must not be declared with a [[`Default`](#Default)] extended attribute.


###### Default toJSON operation

The **default toJSON steps** for an interface `I` are:

1.  Let `map` be a new ordered map.

2.  Let `stack` be the result of creating an inheritance stack for interface `I`.

3.  Invoke collect attribute values of an inheritance stack given this, `stack`, and `map`.

4.  Let `result` be [OrdinaryObjectCreate](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinaryobjectcreate)([`%Object.prototype%`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-properties-of-the-object-prototype-object)).

5.  For each `key` → `value` of `map`,

    1.  Let `k` be `key` converted to a JavaScript value.

    2.  Let `v` be `value` converted to a JavaScript value.

    3.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`result`, `k`, `v`).

6.  Return `result`.

To **collect attribute values of an inheritance stack** given a platform object `object`, a stack `stack`, and an ordered map `map`:

1.  Let `I` be the result of popping from `stack`.

2.  Invoke collect attribute values given `object`, `I`, and `map`.

3.  If `stack` is not empty, then invoke collect attribute values of an inheritance stack given `object`, `stack`, and `map`.

To **collect attribute values** given a platform object `object`, an interface `I`, and an ordered map `map`:

1.  If a `toJSON` operation with a [[`Default`](#Default)] extended attribute is declared on `I`, then for each exposed regular attribute `attr` that is an interface member of `I`, in order:

    1.  Let `id` be the identifier of `attr`.

    2.  Let `value` be the result of running the getter steps of `attr` with `object` as this.

    3.  If `value` is a JSON type, then set `map`[`id`] to `value`.

To **create an inheritance stack** for interface `I`, run the following steps:

1.  Let `stack` be a new stack.

2.  Push `I` onto `stack`.

3.  While `I` inherits from an interface,

    1.  Let `I` be that interface.

    2.  Push `I` onto `stack`.

4.  Return `stack`.

Only regular attributes of interfaces that declare a `toJSON` operation with a [[`Default`](#Default)] extended attribute are included, even if an inherited interface declares such a `toJSON` operation. For example, consider the following IDL fragment:

```webidl
[Exposed=Window]
interface A {
  [Default] object toJSON();
  attribute DOMString a;
};

[Exposed=Window]
interface B : A {
  attribute DOMString b;
};

[Exposed=Window]
interface C : B {
  [Default] object toJSON();
  attribute DOMString c;
};
```

Calling the `toJSON()` method of an object implementing interface `C` defined above would return the following JSON object:

```
{
    "a": "...",
    "c": "..."
}
```

Calling the `toJSON()` method of an object implementing interface `A` (or `B`) defined above would return:

```
{
    "a": "..."
}
```

A `toJSON` operation can also be declared on an interface mixin (or partial interface) and is equivalent to declaring it on the original interface. For example, consider the following IDL fragment:

```webidl
[Exposed=Window]
interface D {
  attribute DOMString d;
};

interface mixin M {
  [Default] object toJSON();
  attribute DOMString m;
};

D includes M;
```

Calling the `toJSON()` method of an object implementing interface `D` defined above would return:

```
{
    "d": "...",
    "m": "..."
}
```


#### Stringifiers

If the interface has an exposed stringifier, then there must exist a property with the following characteristics:

- The name of the property is "`toString`".

- If the stringifier is unforgeable on the interface or if the interface was declared with the [[`Global`](#Global)] extended attribute, then the property exists on every object that implements the interface. Otherwise, the property exists on the interface prototype object.

- The property has attributes { [[Writable]]: `B`, [[Enumerable]]: true, [[Configurable]]: `B` }, where `B` is false if the stringifier is unforgeable on the interface, and true otherwise.

- The value of the property is a built-in function object, which behaves as follows:

  1.  Let `thisValue` be the this value.

  2.  Let `O` be ? [ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(`thisValue`).

  3.  If `O` is a platform object, then perform a security check, passing:

      - the platform object `O`,

      - the identifier of the stringifier, and

      - the type "`method`".

  4.  If `O` does not implement the interface on which the stringifier was declared, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

  5.  Let `V` be an uninitialized variable.

  6.  Depending on how `stringifier` was specified:

      as a declaration

      :   Set `V` to the result of performing the stringification behavior of the interface.

      on an attribute

      :   Set `V` to the result of running the getter steps of the attribute (or those listed in the getter steps of the inherited attribute, if this attribute is declared to inherit its getter), with `O` as this.

  7.  Return the result of converting `V` to a String value.

- The value of the function object's `length` property is the Number value 0.

- The value of the function object's `name` property is the String value "`toString`".


#### Iterable declarations

To **define the iteration methods** of interface `definition` on `target`, given realm `realm`, run the following steps:

1.  If `definition` has an indexed property getter, then:

    1.  Perform [DefineMethodProperty](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-definemethodproperty)(`target`, [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols), [`%Array.prototype.values%`](https://tc39.es/ecma262/#sec-array.prototype.values), false).

    2.  If `definition` has a value iterator, then:

        1.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`target`, "`entries`", [`%Array.prototype.entries%`](https://tc39.es/ecma262/#sec-array.prototype.entries)).

        2.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`target`, "`keys`", [`%Array.prototype.keys%`](https://tc39.es/ecma262/#sec-array.prototype.keys)).

        3.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`target`, "`values`", [`%Array.prototype.values%`](https://tc39.es/ecma262/#sec-array.prototype.values)).

        4.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`target`, "`forEach`", [`%Array.prototype.forEach%`](https://tc39.es/ecma262/#sec-array.prototype.foreach)).

2.  Otherwise, if `definition` has a pair iterator, then:

    1.  Define the [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) and `entries` methods:

        1.  Let `steps` be the following series of steps:

            1.  Let `jsValue` be ? [ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(this value).

            2.  If `jsValue` is a platform object, then perform a security check, passing `jsValue`, "`%Symbol.iterator%`", and "`method`".

            3.  If `jsValue` does not implement `definition`, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

            4.  Return a newly created default iterator object for `definition`, with `jsValue` as its target, "`key+value`" as its kind, and index set to 0.

        2.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « », `realm`).

        3.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, "`entries`").

        4.  Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, 0).

        5.  Perform [DefineMethodProperty](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-definemethodproperty)(`target`, [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols), `F`, false).

        6.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`target`, "`entries`", `F`).

    2.  Define the `keys` method:

        1.  Let `steps` be the following series of steps:

            1.  Let `jsValue` be ? [ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(this value).

            2.  If `jsValue` is a platform object, then perform a security check, passing `jsValue`, "`keys`", and "`method`".

            3.  If `jsValue` does not implement `definition`, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

            4.  Return a newly created default iterator object for `definition`, with `jsValue` as its target, "`key`" as its kind, and index set to 0.

        2.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « », `realm`).

        3.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, "`keys`").

        4.  Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, 0).

        5.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`target`, "`keys`", `F`).

    3.  Define the `values` method:

        1.  Let `steps` be the following series of steps:

            1.  Let `jsValue` be ? [ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(this value).

            2.  If `jsValue` is a platform object, then perform a security check, passing `jsValue`, "`values`", and "`method`".

            3.  If `jsValue` does not implement `definition`, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

            4.  Return a newly created default iterator object for `definition`, with `jsValue` as its target, "`value`" as its kind, and index set to 0.

        2.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « », `realm`).

        3.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, "`values`").

        4.  Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, 0).

        5.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`target`, "`values`", `F`).

    4.  Define the `forEach` method:

        1.  Let `steps` be the following series of steps, given function argument values `callback` and `thisArg`:

            1.  Let `jsValue` be ? [ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(this value).

            2.  If `jsValue` is a platform object, then perform a security check, passing `jsValue`, "`forEach`", and "`method`".

            3.  If `jsValue` does not implement `definition`, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

            4.  Let `idlCallback` be `callback`, converted to a [`Function`](#Function).

            5.  Let `idlObject` be the IDL interface type value that represents a reference to `jsValue`.

            6.  Let `pairs` be `idlObject`'s list of value pairs to iterate over.

            7.  Let `i` be 0.

            8.  While `i` < `pairs`'s size:

                1.  Let `pair` be `pairs`[`i`].

                2.  Invoke `idlCallback` with « `pair`'s value, `pair`'s key, `idlObject` » and with `thisArg` as the callback this value.

                3.  Set `pairs` to `idlObject`'s current list of value pairs to iterate over. (It might have changed.)

                4.  Set `i` to `i` + 1.

        2.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « », `realm`).

        3.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, "`forEach`").

        4.  Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, 1).

        5.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`target`, "`forEach`", `F`).


##### Default iterator objects

A **default iterator object** for a given interface, target and iteration kind is an object whose [[Prototype]] internal slot is the iterator prototype object for the interface.

A default iterator object has three internal values:

- its **target**, which is an object whose values are to be iterated,

- its **kind**, which is the iteration kind,

- its **index**, which is the current index into the values to be iterated.

**Note:** Default iterator objects are only used for pair iterators; value iterators, as they are currently restricted to iterating over an object's supported indexed properties, use standard JavaScript Array iterator objects.

**Note:** Default iterator objects do not have class strings; when `Object.prototype.toString()` is called on a default iterator object of a given interface, the class string of the iterator prototype object of that interface is used.


##### Iterator prototype object

The **iterator prototype object** for a given interface is an object that exists for every interface that has a pair iterator. It serves as the prototype for default iterator objects for the interface.

The [[Prototype]] internal slot of an iterator prototype object must be [`%Iterator.prototype%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-%25iterator.prototype%25-object).

The **iterator result** for a value pair `pair` and a kind `kind` is given by the following steps:

1.  Let `result` be a value determined by the value of `kind`:

    "`key`"

    :   1.  Let `idlKey` be `pair`'s key.

        2.  Let `key` be the result of converting `idlKey` to a JavaScript value.

        3.  `result` is `key`.

    "`value`"

    :   1.  Let `idlValue` be `pair`'s value.

        2.  Let `value` be the result of converting `idlValue` to a JavaScript value.

        3.  `result` is `value`.

    "`key+value`"

    :   1.  Let `idlKey` be `pair`'s key.

        2.  Let `idlValue` be `pair`'s value.

        3.  Let `key` be the result of converting `idlKey` to a JavaScript value.

        4.  Let `value` be the result of converting `idlValue` to a JavaScript value.

        5.  Let `array` be ! [ArrayCreate](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-arraycreate)(2).

        6.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`array`, "`0`", `key`).

        7.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`array`, "`1`", `value`).

        8.  `result` is `array`.

2.  Return [CreateIteratorResultObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createiterresultobject)(`result`, false).

An iterator prototype object must have a `next` data property with attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true } and whose value is a built-in function object that behaves as follows:

1.  Let `interface` be the interface for which the iterator prototype object exists.

2.  Let `thisValue` be the this value.

3.  Let `object` be ? [ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(`thisValue`).

4.  If `object` is a platform object, then perform a security check, passing:

    - the platform object `object`,

    - the identifier "`next`", and

    - the type "`method`".

5.  If `object` is not a default iterator object for `interface`, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

6.  Let `index` be `object`'s index.

7.  Let `kind` be `object`'s kind.

8.  Let `values` be `object`'s target's value pairs to iterate over.

9.  Let `len` be the length of `values`.

10. If `index` is greater than or equal to `len`, then return [CreateIteratorResultObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createiterresultobject)(undefined, true).

11. Let `pair` be the entry in `values` at index `index`.

12. Set `object`'s index to `index` + 1.

13. Return the iterator result for `pair` and `kind`.

The class string of an iterator prototype object for a given interface is the result of concatenating the identifier of the interface and the string "` Iterator`".


#### Asynchronous iterable declarations

To **define the asynchronous iteration methods** of interface `definition` on `target`, given realm `realm`, run the following steps:

1.  If `definition` does not have an an asynchronously iterable declaration (of either sort), then return.

2.  Assert: `definition` does not have an indexed property getter or an iterable declaration.

3.  If `definition` has a pair asynchronously iterable declaration, then define the [`%Symbol.asyncIterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) and `entries` methods:

    1.  Let `steps` be the following series of steps, given function argument values `args`:

        1.  Let `jsValue` be ? [ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(this value).

        2.  If `jsValue` is a platform object, then perform a security check, passing `jsValue`, "`%Symbol.asyncIterator%`", and "`method`".

        3.  If `jsValue` does not implement `definition`, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

        4.  Let `idlObject` be the IDL interface type value that represents a reference to `jsValue`.

        5.  Let `idlArgs` be the result of converting arguments for an asynchronous iterator method given `args`.

        6.  Let `iterator` be a newly created default asynchronous iterator object for `definition` with `idlObject` as its target, "`key+value`" as its kind, and is finished set to false.

        7.  Run the asynchronous iterator initialization steps for `definition` with `idlObject`, `iterator`, and `idlArgs`, if any such steps exist.

        8.  Return `iterator`.

    2.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « », `realm`).

    3.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, "`entries`").

    4.  Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, 0).

    5.  Perform [DefineMethodProperty](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-definemethodproperty)(`target`, [`%Symbol.asyncIterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols), `F`, false).

    6.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`target`, "`entries`", `F`).

4.  If `definition` has a pair asynchronously iterable declaration, then define the `keys` method:

    1.  Let `steps` be the following series of steps, given function argument values `args`:

        1.  Let `jsValue` be ? [ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(this value).

        2.  If `jsValue` is a platform object, then perform a security check, passing `jsValue`, "`keys`", and "`method`".

        3.  If `jsValue` does not implement `definition`, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

        4.  Let `idlObject` be the IDL interface type value that represents a reference to `jsValue`.

        5.  Let `idlArgs` be the result of converting arguments for an asynchronous iterator method given `args`.

        6.  Let `iterator` be a newly created default asynchronous iterator object for `definition` with `idlObject` as its target, "`key`" as its kind, and is finished set to false.

        7.  Run the asynchronous iterator initialization steps for `definition` with `idlObject`, `iterator`, and `idlArgs`, if any such steps exist.

        8.  Return `iterator`.

    2.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « », `realm`).

    3.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, "`keys`").

    4.  Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, 0).

    5.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`target`, "`keys`", `F`).

5.  Define the `values`, and possibly [`%Symbol.asyncIterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols), methods:

    1.  Let `steps` be the following series of steps, given function argument values `args`:

        1.  Let `jsValue` be ? [ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(this value).

        2.  If `jsValue` is a platform object, then perform a security check, passing `jsValue`, "`values`", and "`method`".

        3.  If `jsValue` does not implement `definition`, then throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

        4.  Let `idlObject` be the IDL interface type value that represents a reference to `jsValue`.

        5.  Let `idlArgs` be the result of converting arguments for an asynchronous iterator method given `args`.

        6.  Let `iterator` be a newly created default asynchronous iterator object for `definition` with `idlObject` as its target, "`value`" as its kind, and is finished set to false.

        7.  Run the asynchronous iterator initialization steps for `definition` with `idlObject`, `iterator`, and `idlArgs`, if any such steps exist.

        8.  Return `iterator`.

    2.  Let `F` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`steps`, « », `realm`).

    3.  Perform [SetFunctionName](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionname)(`F`, "`values`").

    4.  Perform [SetFunctionLength](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-setfunctionlength)(`F`, 0).

    5.  Perform ! [CreateDataPropertyOrThrow](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createdatapropertyorthrow)(`target`, "`values`", `F`).

    6.  If `definition` has a value asynchronously iterable declaration, then perform ! [DefineMethodProperty](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-definemethodproperty)(`target`, [`%Symbol.asyncIterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols), `F`, false).

To **convert arguments for an asynchronous iterator method**, given an interface `definition` that has an asynchronously iterable declaration and a list of JavaScript values `args`:

1.  Let `idlArgs` be an empty list.

2.  Let `argCount` be the number of arguments of `definition`'s asynchronously iterable declaration, or 0 if the asynchronously iterable declaration does not have an argument list.

3.  Let `i` be 0.

4.  While `i` < `argCount`:

    1.  If `i` ≥ `args`'s size, or if `args`[`i`] is undefined, then:

        1.  If the argument to the asynchronously iterable declaration at index `i` is declared with a default value, then append that default value to `idlArgs`.

        2.  Otherwise, append to `idlArgs` the special value "missing".

    2.  Otherwise, append to `idlArgs` the result of converting `args`[`i`] to the IDL type given in the asynchronously iterable declaration's argument list at index `i`.

    3.  Set `i` to `i` + 1.

5.  Return `idlArgs`.


##### Default asynchronous iterator objects

A **default asynchronous iterator object** for a given interface, target and iteration kind is an object whose [[Prototype]] internal slot is the asynchronous iterator prototype object for the interface.

A default asynchronous iterator object has internal values:

- its **target**, which is an object whose values are to be iterated,

- its **kind**, which is the iteration kind,

- its **ongoing promise**, which is a [`Promise`](#idl-promise) or null,

- its **is finished**, which is a boolean.

**Note:** Default asynchronous iterator objects do not have class strings; when `Object.prototype.toString()` is called on a default asynchronous iterator object of a given interface, the class string of the asynchronous iterator prototype object of that interface is used.


##### Asynchronous iterator prototype object

The **asynchronous iterator prototype object** for a given interface is an object that exists for every interface that has an asynchronously iterable declaration. It serves as the prototype for default asynchronous iterator objects for the interface.

The [[Prototype]] internal slot of an asynchronous iterator prototype object must be [`%AsyncIteratorPrototype%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-asynciteratorprototype).

An asynchronous iterator prototype object must have a `next` data property with attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true } and whose value is a built-in function object that behaves as follows:

1.  Let `interface` be the interface for which the asynchronous iterator prototype object exists.

2.  Let `thisValidationPromiseCapability` be ! [NewPromiseCapability](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-newpromisecapability)([`%Promise%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-constructor)).

3.  Let `thisValue` be the this value.

4.  Let `object` be [Completion]([ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(`thisValue`)).

5.  [IfAbruptRejectPromise](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-ifabruptrejectpromise)(`object`, `thisValidationPromiseCapability`).

6.  If `object` is a platform object, then perform a security check, passing:

    - the platform object `object`,

    - the identifier "`next`", and

    - the type "`method`".

    If this threw an exception `e`, then:

    1.  Perform ! [Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)(`thisValidationPromiseCapability`.[[Reject]], undefined, « `e` »).

    2.  Return `thisValidationPromiseCapability`.[[Promise]].

7.  If `object` is not a default asynchronous iterator object for `interface`, then:

    1.  Let `error` be a new [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

    2.  Perform ! [Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)(`thisValidationPromiseCapability`.[[Reject]], undefined, « `error` »).

    3.  Return `thisValidationPromiseCapability`.[[Promise]].

8.  Let `nextSteps` be the following steps:

    1.  Let `nextPromiseCapability` be ! [NewPromiseCapability](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-newpromisecapability)([`%Promise%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-constructor)).

    2.  If `object`'s is finished is true, then:

        1.  Let `result` be [CreateIteratorResultObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createiterresultobject)(undefined, true).

        2.  Perform ! [Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)(`nextPromiseCapability`.[[Resolve]], undefined, « `result` »).

        3.  Return `nextPromiseCapability`.[[Promise]].

    3.  Let `kind` be `object`'s kind.

    4.  Let `nextPromise` be the result of getting the next iteration result with `object`'s target and `object`.

    5.  Let `fulfillSteps` be the following steps, given `next`:

        1.  Set `object`'s ongoing promise to null.

        2.  If `next` is end of iteration, then:

            1.  Set `object`'s is finished to true.

            2.  Return [CreateIteratorResultObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createiterresultobject)(undefined, true).

        3.  Otherwise, if `interface` has a pair asynchronously iterable declaration:

            1.  Assert: `next` is a value pair.

            2.  Return the iterator result for `next` and `kind`.

        4.  Otherwise:

            1.  Assert: `interface` has a value asynchronously iterable declaration.

            2.  Assert: `next` is a value of the type that appears in the declaration.

            3.  Let `value` be `next`, converted to a JavaScript value.

            4.  Return [CreateIteratorResultObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createiterresultobject)(`value`, false).

    6.  Let `onFulfilled` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`fulfillSteps`, « »).

    7.  Let `rejectSteps` be the following steps, given `reason`:

        1.  Set `object`'s ongoing promise to null.

        2.  Set `object`'s is finished to true.

        3.  Throw `reason`.

    8.  Let `onRejected` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`rejectSteps`, « »).

    9.  Perform [PerformPromiseThen](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-performpromisethen)(`nextPromise`, `onFulfilled`, `onRejected`, `nextPromiseCapability`).

    10. Return `nextPromiseCapability`.[[Promise]].

9.  Let `ongoingPromise` be `object`'s ongoing promise.

10. If `ongoingPromise` is not null, then:

    1.  Let `afterOngoingPromiseCapability` be ! [NewPromiseCapability](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-newpromisecapability)([`%Promise%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-constructor)).

    2.  Let `onSettled` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`nextSteps`, « »).

    3.  Perform [PerformPromiseThen](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-performpromisethen)(`ongoingPromise`, `onSettled`, `onSettled`, `afterOngoingPromiseCapability`).

    4.  Set `object`'s ongoing promise to `afterOngoingPromiseCapability`.[[Promise]].

11. Otherwise:

    1.  Set `object`'s ongoing promise to the result of running `nextSteps`.

12. Return `object`'s ongoing promise.

If an asynchronous iterator return algorithm is defined for the interface, then the asynchronous iterator prototype object must have a `return` data property with attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true } and whose value is a built-in function object, taking one argument `value`, that behaves as follows:

1.  Let `interface` be the interface for which the asynchronous iterator prototype object exists.

2.  Let `returnPromiseCapability` be ! [NewPromiseCapability](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-newpromisecapability)([`%Promise%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-constructor)).

3.  Let `thisValue` be the this value.

4.  Let `object` be [Completion]([ToObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-toobject)(`thisValue`)).

5.  [IfAbruptRejectPromise](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-ifabruptrejectpromise)(`object`, `returnPromiseCapability`).

6.  If `object` is a platform object, then perform a security check, passing:

    - the platform object `object`,

    - the identifier "`return`", and

    - the type "`method`".

    If this threw an exception `e`, then:

    1.  Perform ! [Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)(`returnPromiseCapability`.[[Reject]], undefined, « `e` »).

    2.  Return `returnPromiseCapability`.[[Promise]].

7.  If `object` is not a default asynchronous iterator object for `interface`, then:

    1.  Let `error` be a new [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

    2.  Perform ! [Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)(`returnPromiseCapability`.[[Reject]], undefined, « `error` »).

    3.  Return `returnPromiseCapability`.[[Promise]].

8.  Let `returnSteps` be the following steps:

    1.  Let `returnPromiseCapability` be ! [NewPromiseCapability](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-newpromisecapability)([`%Promise%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-constructor)).

    2.  If `object`'s is finished is true, then:

        1.  Let `result` be [CreateIteratorResultObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createiterresultobject)(`value`, true).

        2.  Perform ! [Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)(`returnPromiseCapability`.[[Resolve]], undefined, « `result` »).

        3.  Return `returnPromiseCapability`.[[Promise]].

    3.  Set `object`'s is finished to true.

    4.  Return the result of running the asynchronous iterator return algorithm for `interface`, given `object`'s target, `object`, and `value`.

9.  Let `ongoingPromise` be `object`'s ongoing promise.

10. If `ongoingPromise` is not null, then:

    1.  Let `afterOngoingPromiseCapability` be ! [NewPromiseCapability](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-newpromisecapability)([`%Promise%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-constructor)).

    2.  Let `onSettled` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`returnSteps`, « »).

    3.  Perform [PerformPromiseThen](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-performpromisethen)(`ongoingPromise`, `onSettled`, `onSettled`, `afterOngoingPromiseCapability`).

    4.  Set `object`'s ongoing promise to `afterOngoingPromiseCapability`.[[Promise]].

11. Otherwise:

    1.  Set `object`'s ongoing promise to the result of running `returnSteps`.

12. Let `fulfillSteps` be the following steps:

    1.  Return [CreateIteratorResultObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createiterresultobject)(`value`, true).

13. Let `onFulfilled` be [CreateBuiltinFunction](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-createbuiltinfunction)(`fulfillSteps`, « »).

14. Perform [PerformPromiseThen](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-performpromisethen)(`object`'s ongoing promise, `onFulfilled`, undefined, `returnPromiseCapability`).

15. Return `returnPromiseCapability`.[[Promise]].

The class string of an asynchronous iterator prototype object for a given interface is the result of concatenating the identifier of the interface and the string "` AsyncIterator`".


#### Maplike declarations

If an interface `A` is declared with a maplike declaration, then there exists a number of additional properties on `A`'s interface prototype object. These additional properties are described in the sub-sections below.


##### size

There must exist a `size` property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Get]]: `G`, [[Enumerable]]: true, [[Configurable]]: true }, where `G` is the interface's **map size getter**, defined below.

- The map size getter is a built-in function object whose behavior when invoked is as follows:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`size`" and type "`getter`".

  2.  Let `map` be the map entries of the IDL value that represents a reference to `O`.

  3.  Return `map`'s size, converted to a JavaScript value.

  The value of the function object's `length` property is the Number value 0.

  The value of the function object's `name` property is the String value "`get size`".


##### %Symbol.iterator%

There must exist a data property whose name is the [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) symbol on `A`'s interface prototype object with attributes { [[Writable]]: true, [[Enumerable]]: false, [[Configurable]]: true } and whose value is the function object that is the value of the `entries` property.

To **create a map iterator** from a map `map` and a `kind` which is either "`key+value`", "`key`", or "`value`":

1.  Let `closure` be a new Abstract Closure with no parameters that captures `map` and `kind` and performs the following steps when called:

    1.  For each `key` → `value` of `map`:

        1.  Set `key` and `value` to each converted to a JavaScript value.

        2.  If `kind` is "`key`", let `result` be `key`.

        3.  Else if `kind` is "`value`", let `result` be `value`.

        4.  Else, let `result` be [CreateArrayFromList](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createarrayfromlist)(« `key`, `value` »).

        5.  Perform ? [GeneratorYield](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-generatoryield)([CreateIteratorResultObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createiterresultobject)(`result`, false)).

        **Note:** The size of `map`, and the order of its entries, might have changed while execution of this abstract operation was paused by Yield.

    2.  Return undefined.

2.  Return [CreateIteratorFromClosure](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-createiteratorfromclosure)(`closure`, "`%MapIteratorPrototype%`", [`%MapIteratorPrototype%`](https://tc39.es/ecma262/multipage/keyed-collections.html#sec-%25mapiteratorprototype%25-object)).


##### entries

There must exist an `entries` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object whose behavior when invoked is as follows:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`entries`" and type "`method`".

  2.  Let `map` be the map entries of the IDL value that represents a reference to `O`.

  3.  Return the result of creating a map iterator from `map` with kind "`key+value`".

The value of the function object's `length` property is the Number value 0.

The value of the function object's `name` property is the String value "`entries`".


##### keys

There must exist a `keys` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object whose behavior when invoked is as follows:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`keys`" and type "`method`".

  2.  Let `map` be the map entries of the IDL value that represents a reference to `O`.

  3.  Return the result of creating a map iterator from `map` with kind "`key`".

The value of the function object's `length` property is the Number value 0.

The value of the function object's `name` property is the String value "`keys`".


##### values

There must exist a `values` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object whose behavior when invoked is as follows:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`values`" and type "`method`".

  2.  Let `map` be the map entries of the IDL value that represents a reference to `O`.

  3.  Return the result of creating a map iterator from `map` with kind "`value`".

The value of the function object's `length` property is the Number value 0.

The value of the function object's `name` property is the String value "`values`".


##### forEach

There must exist a `forEach` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object whose behavior when invoked is as follows:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`forEach`" and type "`method`".

  2.  Let `map` be the map entries of the IDL value that represents a reference to `O`.

  3.  Let `callbackFn` be the first argument passed to the function, or undefined if not supplied.

  4.  If [IsCallable](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-iscallable)(`callbackFn`) is false, throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

  5.  Let `thisArg` be the second argument passed to the function, or undefined if not supplied.

  6.  For each `key` → `value` of `map`:

      1.  Let `jsKey` and `jsValue` be `key` and `value` converted to a JavaScript value.

      2.  Perform ? [Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)(`callbackFn`, `thisArg`, « `jsValue`, `jsKey`, `O` »).

  7.  Return undefined.

The value of the function object's `length` property is the Number value 1.

The value of the function object's `name` property is the String value "`forEach`".


##### get

There must exist a `get` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object that behaves as follows when invoked:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`get`" and type "`method`".

  2.  Let `map` be the map entries of the IDL value that represents a reference to `O`.

  3.  Let `keyType` be the key type specified in the maplike declaration.

  4.  Let `keyArg` be the first argument passed to this function, or undefined if not supplied.

  5.  Let `key` be `keyArg` converted to an IDL value of type `keyType`.

  6.  If `key` is -0, set `key` to +0.

  7.  If `map`[`key`] exists, then return `map`[`key`], converted to a JavaScript value.

The value of the function object's `length` property is the Number value 1.

The value of the function object's `name` property is the String value "`get`".


##### has

There must exist a `has` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object that behaves as follows when invoked:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`has`" and type "`method`".

  2.  Let `map` be the map entries of the IDL value that represents a reference to `O`.

  3.  Let `keyType` be the key type specified in the maplike declaration.

  4.  Let `keyArg` be the first argument passed to this function, or undefined if not supplied.

  5.  Let `key` be `keyArg` converted to an IDL value of type `keyType`.

  6.  If `key` is -0, set `key` to +0.

  7.  If `map`[`key`] exists, then return true; otherwise return false.

The value of the function object's `length` property is the Number value 1.

The value of the function object's `name` property is the String value "`has`".


##### set

If `A` does not declare a member with identifier "`set`", and `A` was declared with a read--write maplike declaration, then there must exist a `set` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object that behaves as follows when invoked:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`set`" and type "`method`".

  2.  Let `map` be the map entries of the IDL value that represents a reference to `O`.

  3.  Let `keyType` be the key type specified in the maplike declaration, and `valueType` be the value type.

  4.  Let `keyArg` be the first argument passed to this function, or undefined if not supplied.

  5.  Let `key` be `keyArg` converted to an IDL value of type `keyType`.

  6.  If `key` is -0, set `key` to +0.

  7.  Let `valueArg` be the second argument passed to this function, or undefined if not supplied.

  8.  Let `value` be `valueArg` converted to an IDL value of type `valueType`.

  9.  Set `map`[`key`] to `value`.

  10. Return `O`.

The value of the function object's `length` property is the Number value 2.

The value of the function object's `name` property is the String value "`set`".


##### delete

If `A` does not declare a member with identifier "`delete`", and `A` was declared with a read--write maplike declaration, then there must exist a `delete` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object that behaves as follows when invoked:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`delete`" and type "`method`".

  2.  Let `map` be the map entries of the IDL value that represents a reference to `O`.

  3.  Let `keyType` be the key type specified in the maplike declaration.

  4.  Let `keyArg` be the first argument passed to this function, or undefined if not supplied.

  5.  Let `key` be `keyArg` converted to an IDL value of type `keyType`.

  6.  If `key` is -0, set `key` to +0.

  7.  Let `retVal` be true if `map`[`key`] exists, or else false.

  8.  Remove `map`[`key`].

  9.  Return `retVal`.

The value of the function object's `length` property is the Number value 1.

The value of the function object's `name` property is the String value "`delete`".


##### clear

If `A` does not declare a member with identifier "`clear`", and `A` was declared with a read--write maplike declaration, then there must exist a `clear` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object that behaves as follows when invoked:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`clear`" and type "`method`".

  2.  Let `map` be the map entries of the IDL value that represents a reference to `O`.

  3.  Clear `map`.

      **Note:** The map is preserved because there may be existing iterators, currently suspended, iterating over it.

  4.  Return undefined.

The value of the function object's `length` property is the Number value 0.

The value of the function object's `name` property is the String value "`clear`".


#### Setlike declarations

If an interface `A` is declared with a setlike declaration, then there exists a number of additional properties on `A`'s interface prototype object. These additional properties are described in the sub-sections below.


##### size

A `size` property must exist on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Get]]: `G`, [[Enumerable]]: true, [[Configurable]]: true }, where `G` is the interface's **set size getter**, defined below.

- The set size getter is a built-in function object whose behavior when invoked is as follows:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`size`" and type "`getter`".

  2.  Let `set` be the set entries of the IDL value that represents a reference to `O`.

  3.  Return `set`'s size, converted to a JavaScript value.

  The value of the function object's `length` property is the Number value 0.

  The value of the function object's `name` property is the String value "`get size`".


##### %Symbol.iterator%

There must exist a data property whose name is the [`%Symbol.iterator%`](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-well-known-symbols) symbol on `A`'s interface prototype object with attributes { [[Writable]]: true, [[Enumerable]]: false, [[Configurable]]: true } and whose value is the function object that is the value of the `values` property.

To **create a set iterator** from a set `set` and a `kind` which is either "`key+value`" or "`value`":

1.  Let `closure` be a new Abstract Closure with no parameters that captures `set` and `kind` and performs the following steps when called:

    1.  For each `entry` of `set`:

        1.  Set `entry` to be `entry` converted to a JavaScript value.

        2.  If `kind` is "`value`", let `result` be `entry`.

        3.  Else, let `result` be [CreateArrayFromList](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createarrayfromlist)(« `entry`, `entry` »).

        4.  Perform ? [GeneratorYield](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-generatoryield)([CreateIteratorResultObject](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-createiterresultobject)(`result`, false)).

        **Note:** The size of `set`, and the order of its entries, might have changed while execution of this abstract operation was paused by Yield.

    2.  Return undefined.

2.  Return [CreateIteratorFromClosure](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-createiteratorfromclosure)(`closure`, "`%SetIteratorPrototype%`", [`%SetIteratorPrototype%`](https://tc39.es/ecma262/multipage/keyed-collections.html#sec-%25setiteratorprototype%25-object)).


##### keys

A `keys` data property must exist on `A`'s interface prototype object with attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true } and whose value is the function object that is the value of the `values` property.


##### forEach

There must exist a `forEach` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object whose behavior when invoked is as follows:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`forEach`" and type "`method`".

  2.  Let `set` be the set entries of the IDL value that represents a reference to `O`.

  3.  Let `callbackFn` be the first argument passed to the function, or undefined if not supplied.

  4.  If [IsCallable](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-iscallable)(`callbackFn`) is false, throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror).

  5.  Let `thisArg` be the second argument passed to the function, or undefined if not supplied.

  6.  For each `value` of `set`:

      1.  Let `jsValue` be `value` converted to a JavaScript value.

      2.  Perform ? [Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)(`callbackFn`, `thisArg`, « `jsValue`, `jsValue`, `O`»).

  7.  Return undefined.

The value of the function object's `length` property is the Number value 1.

The value of the function object's `name` property is the String value "`forEach`".


##### has

There must exist a `has` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object that behaves as follows when invoked:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`has`" and type "`method`".

  2.  Let `set` be the set entries of the IDL value that represents a reference to `O`.

  3.  Let `valueType` be the value type specified in the setlike declaration.

  4.  Let `valueArg` be the first argument passed to this function, or undefined if not supplied.

  5.  Let `value` be `valueArg` converted to an IDL value of type `valueType`.

  6.  If `value` is -0, set `value` to +0.

  7.  If `set` contains `value`, then return true, otherwise return false.

The value of the function object's `length` property is a Number value 1.

The value of the function object's `name` property is the String value "`has`".


##### add

If `A` does not declare a member with identifier "`add`", and `A` was declared with a read--write setlike declaration, then there must exist an `add` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object that behaves as follows when invoked:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`add`" and type "`method`".

  2.  Let `set` be the set entries of the IDL value that represents a reference to `O`.

  3.  Let `valueType` be the value type specified in the setlike declaration.

  4.  Let `valueArg` be the first argument passed to this function, or undefined if not supplied.

  5.  Let `value` be `valueArg` converted to an IDL value of type `valueType`.

  6.  If `value` is -0, set `value` to +0.

  7.  Append `value` to `set`.

  8.  Return `O`.

The value of the function object's `length` property is the Number value 1.

The value of the function object's `name` property is the String value "`add`".


##### delete

If `A` does not declare a member with identifier "`delete`", and `A` was declared with a read--write setlike declaration, then there must exist a `delete` data property on `A`'s interface prototype object with the following characteristics:

- The property has attributes { [[Writable]]: true, [[Enumerable]]: true, [[Configurable]]: true }.

- The value of the property is a built-in function object that behaves as follows when invoked:

  1.  Let `O` be the this value, implementation-checked against `A` with identifier "`delete`" and type "`method`".

  2.  Let `set` be `O`'s set entries.

  3.  Let `valueType` be the value type specified in the setlike declaration.

  4.  Let `valueArg` be the first argument passed to this function, or undefined if not supplied.

  5.  Let `value` be `valueArg` converted to an IDL value of type `valueType`.

  6.  If `value` is -0, set `value` to +0.

  7.  Let `retVal` be true if `set` contains `value`, or else false.

  8.  Remove `value` from `set`.

  9.  Return `retVal`.

The value of the function object's `length` property is the Number value 1.

The value of the function object's `name` property is the String value "`delete`".


### Platform objects implementing interfaces

A JavaScript value `value` **is a platform object** if `value` is an Object and if `value` has a [[PrimaryInterface]] internal slot.

A JavaScript value `value` **implements** an interface `interface` if `value` is a platform object and the inclusive inherited interfaces of `value`.[[PrimaryInterface]] contains `interface`.

Specifications may reference the concept "`object` implements `interface`" in various ways, including "`object` is an `interface` object".

Every platform object is associated with a realm, just as the initial objects are. This realm is stored in the platform object's [[Realm]] slot. It is the responsibility of specifications using Web IDL to state which realm (or, by proxy, which global object) each platform object is associated with. In particular, the algorithms below associate the new platform object with the realm given as an argument.

To **create a new object implementing the interface** `interface`, with a realm `realm`, perform the following steps:

1. Return the result of internally creating a new object implementing `interface`, with `realm` and undefined.

To **internally create a new object implementing the interface** `interface`, with a realm `realm` and a JavaScript value `newTarget`, perform the following steps:

1. Assert: `interface` is exposed in `realm`.

2. If `newTarget` is undefined, then:

   1. Let `prototype` be the interface prototype object for `interface` in `realm`.

3. Otherwise:

   1. Assert: IsCallable(`newTarget`) is true.

   2. Let `prototype` be ? Get(`newTarget`, "prototype").

   3. If `prototype` is not an Object, then:

      1. Let `targetRealm` be ? GetFunctionRealm(`newTarget`).

      2. Set `prototype` to the interface prototype object for `interface` in `targetRealm`.

4. Let `slots` be « [[Prototype]], [[Extensible]], [[Realm]], [[PrimaryInterface]] ».

5. If `interface` is `DOMException`, append [[ErrorData]] to `slots`.

6. Let `instance` be MakeBasicObject(`slots`).

7. Set `instance`.[[Realm]] to `realm`.

8. Set `instance`.[[PrimaryInterface]] to `interface`.

9. Set `instance`.[[Prototype]] to `prototype`.

10. Let `interfaces` be the inclusive inherited interfaces of `interface`.

11. For every interface `ancestor interface` in `interfaces`:

    1. Let `unforgeables` be the value of the [[Unforgeables]] slot of the interface object of `ancestor interface` in `realm`.

    2. Let `keys` be ! `unforgeables`.[[OwnPropertyKeys]]().

    3. For each element `key` of `keys`:

       1. Let `descriptor` be ! `unforgeables`.[[GetOwnProperty]](`key`).

       2. Perform ! DefinePropertyOrThrow(`instance`, `key`, `descriptor`).

12. If `interface` is declared with the [`Global`] extended attribute, then:

    1. Define the regular operations of `interface` on `instance`, given `realm`.

    2. Define the regular attributes of `interface` on `instance`, given `realm`.

    3. Define the iteration methods of `interface` on `instance` given `realm`.

    4. Define the asynchronous iteration methods of `interface` on `instance` given `realm`.

    5. Define the global property references on `instance`, given `realm`.

    6. Set `instance`.[[SetPrototypeOf]] as defined in § 3.8.1 [[SetPrototypeOf]].

13. Otherwise, if `interfaces` contains an interface which supports indexed properties, named properties, or both:

    1. Set `instance`.[[GetOwnProperty]] as defined in § 3.9.1 [[GetOwnProperty]].

    2. Set `instance`.[[Set]] as defined in § 3.9.2 [[Set]].

    3. Set `instance`.[[DefineOwnProperty]] as defined in § 3.9.3 [[DefineOwnProperty]].

    4. Set `instance`.[[Delete]] as defined in § 3.9.4 [[Delete]].

    5. Set `instance`.[[PreventExtensions]] as defined in § 3.9.5 [[PreventExtensions]].

    6. Set `instance`.[[OwnPropertyKeys]] as defined in § 3.9.6 [[OwnPropertyKeys]].

14. Return `instance`.

To **define the global property references** on `target`, given realm `realm`, perform the following steps:

1. Let `interfaces` be a list that contains every interface that is exposed in `realm`.

2. Sort `interfaces` in such a way that if `A` and `B` are items of `interfaces`, and `A` inherits from `B`, `A` has a higher index in `interfaces` than `B`.

3. For every `interface` of `interfaces`:

   1. If `interface` is not declared with the [`LegacyNoInterfaceObject`] or [`LegacyNamespace`] extended attributes, then:

      1. Let `id` be `interface`'s identifier.

      2. Let `interfaceObject` be the result of creating an interface object for `interface` with `id` in `realm`.

      3. Perform DefineMethodProperty(`target`, `id`, `interfaceObject`, false).

      4. If the `interface` is declared with a [`LegacyWindowAlias`] extended attribute, and `target` implements the `Window` interface, then:

         1. For every identifier `id` in [`LegacyWindowAlias`]'s identifiers:

            1. Perform DefineMethodProperty(`target`, `id`, `interfaceObject`, false).

   2. If the `interface` is declared with a [`LegacyFactoryFunction`] extended attribute, then:

      1. For every identifier `id` in [`LegacyFactoryFunction`]'s identifiers:

         1. Let `legacyFactoryFunction` be the result of creating a legacy factory function with `id` for `interface` in `realm`.

         2. Perform DefineMethodProperty(`target`, `id`, `legacyFactoryFunction`, false).

4. For every callback interface `interface` that is exposed in `realm` and on which constants are defined:

   1. Let `id` be `interface`'s identifier.

   2. Let `interfaceObject` be the result of creating a legacy callback interface object for `interface` with `id` in `realm`.

   3. Perform DefineMethodProperty(`target`, `id`, `interfaceObject`, false).

5. For every namespace `namespace` that is exposed in `realm`:

   1. Let `id` be `namespace`'s identifier.

   2. Let `namespaceObject` be the result of creating a namespace object for `namespace` in `realm`.

   3. Perform DefineMethodProperty(`target`, `id`, `namespaceObject`, false).

**Note:** The set of interfaces that a platform object implements does not change over the lifetime of the object.

Multiple platform objects with different global objects will share a reference to the same interface in their [[PrimaryInterface]] internal slots. For example, a page could contain a same-origin iframe, with the iframe's method being called on the main page's element of the same kind, with no exception thrown.

Interface mixins do not participate directly in the evaluation of the implements algorithm. Instead, each interface that the interface mixin is included in has its own "copy" of each member of the interface mixin, and the corresponding operation function checks that the receiver implements the particular interface which includes the interface mixin.

The **primary interface** of a platform object is the value of the object's [[PrimaryInterface]] internal slot, which is the most-derived interface that it implements.

The realm that a given platform object is associated with can **change** after it has been created. When the realm associated with a platform object is changed, its [[Prototype]] internal slot must be immediately updated to be the interface prototype object of the primary interface from the platform object's newly associated realm.

Additionally, platform objects which implement an interface which has a [`Global`] extended attribute get properties declaratively from:

- § 3.7.8 Stringifiers,

- § 3.7.11 Maplike declarations, and

- § 3.7.12 Setlike declarations.

Define those properties imperatively instead.


#### [[SetPrototypeOf]]

When the [[SetPrototypeOf]] internal method of a platform object `O` that implements an interface with the [`Global`] extended attribute is called with JavaScript language value `V`, the following step is taken:

1. If `O`'s associated realm's is global prototype chain mutable is true, return ? OrdinarySetPrototypeOf(`O`, `V`).

2. Return ? SetImmutablePrototype(`O`, `V`).

**Note:** For `Window` objects, it is unobservable whether this is implemented, since the presence of the `WindowProxy` object ensures that [[SetPrototypeOf]] is never called on a `Window` object directly. For other global objects, however, this is necessary.


### Legacy platform objects

Legacy platform objects will appear to have additional properties that correspond to their indexed and named properties. These properties are not "real" own properties on the object, but are made to look like they are by being exposed by the [[GetOwnProperty]] internal method.

It is permissible for an object to implement multiple interfaces that support indexed properties. However, if so, and there are conflicting definitions as to the object's supported property indices, then it is undefined what additional properties the object will appear to have, or what its exact behavior will be with regard to its indexed properties. The same applies for named properties.

The indexed property getter that is defined on the derived-most interface that the legacy platform object implements is the one that defines the behavior when indexing the object with an array index. Similarly for indexed property setters. This way, the definitions of these special operations from ancestor interfaces can be overridden.

A property name is an **unforgeable property name** on a given platform object `O` if the object implements an interface that has an interface member with that identifier and that interface member is unforgeable on any of the interfaces that `O` implements.

Support for getters is handled in § 3.9.1 [[GetOwnProperty]], and for setters in § 3.9.3 [[DefineOwnProperty]] and § 3.9.2 [[Set]].

Additionally, legacy platform objects have internal methods as defined in:

- § 3.9.4 [[Delete]],
- § 3.9.5 [[PreventExtensions]], and
- § 3.9.6 [[OwnPropertyKeys]].


#### [[GetOwnProperty]]

The [[GetOwnProperty]] internal method of every legacy platform object `O` must behave as follows when called with property name `P`:

1. Return ? LegacyPlatformObjectGetOwnProperty(`O`, `P`, false).


#### [[Set]]

The [[Set]] internal method of every legacy platform object `O` must behave as follows when called with property name `P`, value `V`, and JavaScript language value `Receiver`:

1. If `O` and `Receiver` are the same object, then:

    1. If `O` implements an interface with an indexed property setter and `P` is an array index, then:

        1. Invoke the indexed property setter on `O` with `P` and `V`.
        2. Return true.

    2. If `O` implements an interface with a named property setter and `P` is a String, then:

        1. Invoke the named property setter on `O` with `P` and `V`.
        2. Return true.

2. Let `ownDesc` be ? LegacyPlatformObjectGetOwnProperty(`O`, `P`, true).

3. Perform ? OrdinarySetWithOwnDescriptor(`O`, `P`, `V`, `Receiver`, `ownDesc`).


#### [[DefineOwnProperty]]

When the [[DefineOwnProperty]] internal method of a legacy platform object `O` is called with property key `P` and Property Descriptor `Desc`, the following steps must be taken:

1. If `O` supports indexed properties and `P` is an array index, then:

    1. If the result of calling IsDataDescriptor(`Desc`) is false, then return false.
    2. If `O` does not implement an interface with an indexed property setter, then return false.
    3. Invoke the indexed property setter on `O` with `P` and `Desc`.[[Value]].
    4. Return true.

2. If `O` supports named properties, `O` does not implement an interface with the [[`Global`]] extended attribute, `P` is a String, and `P` is not an unforgeable property name of `O`, then:

    1. Let `creating` be true if `P` is not a supported property name, and false otherwise.

    2. If `O` implements an interface with the [[`LegacyOverrideBuiltIns`]] extended attribute or `O` does not have an own property named `P`, then:

        1. If `creating` is false and `O` does not implement an interface with a named property setter, then return false.

        2. If `O` implements an interface with a named property setter, then:

            1. If the result of calling IsDataDescriptor(`Desc`) is false, then return false.
            2. Invoke the named property setter on `O` with `P` and `Desc`.[[Value]].
            3. Return true.

3. Return ! OrdinaryDefineOwnProperty(`O`, `P`, `Desc`).


#### [[Delete]]

The [[Delete]] internal method of every legacy platform object `O` must behave as follows when called with property name `P`.

1. If `O` supports indexed properties and `P` is an array index, then:

    1. Let `index` be the result of calling ! ToUint32(`P`).
    2. If `index` is not a supported property index, then return true.
    3. Return false.

2. If `O` supports named properties, `O` does not implement an interface with the [[`Global`]] extended attribute and the result of calling the named property visibility algorithm with property name `P` and object `O` is true, then:

    1. If `O` does not implement an interface with a named property deleter, then return false.

    2. Let `operation` be the operation used to declare the named property deleter.

    3. If `operation` was defined without an identifier, then:

        1. Perform the steps listed in the interface description to delete an existing named property with `P` as the name.
        2. If the steps indicated that the deletion failed, then return false.

    4. Otherwise, `operation` was defined with an identifier:

        1. Perform method steps of `operation` with `O` as this and « `P` » as the argument values.
        2. If `operation` was declared with a return type of `boolean` and the steps returned false, then return false.

    5. Return true.

3. If `O` has an own property with name `P`, then:

    1. If the property is not configurable, then return false.
    2. Otherwise, remove the property from `O`.

4. Return true.


#### [[PreventExtensions]]

When the [[PreventExtensions]] internal method of a legacy platform object is called, the following steps are taken:

1. Return false.

Note: this keeps legacy platform objects extensible by making [[PreventExtensions]] fail for them.


#### [[OwnPropertyKeys]]

This document does not define a complete property enumeration order for platform objects implementing interfaces (or for platform objects representing exceptions). However, it does for legacy platform objects by defining the [[OwnPropertyKeys]] internal method as follows.

When the [[OwnPropertyKeys]] internal method of a legacy platform object `O` is called, the following steps are taken:

1. Let `keys` be a new empty list of JavaScript String and Symbol values.

2. If `O` supports indexed properties, then for each `index` of `O`'s supported property indices, in ascending numerical order, append ! ToString(`index`) to `keys`.

3. If `O` supports named properties, then for each `P` of `O`'s supported property names that is visible according to the named property visibility algorithm, append `P` to `keys`.

4. For each `P` of `O`'s own property keys that is a String, in ascending chronological order of property creation, append `P` to `keys`.

5. For each `P` of `O`'s own property keys that is a Symbol, in ascending chronological order of property creation, append `P` to `keys`.

6. Assert: `keys` has no duplicate items.

7. Return `keys`.


#### Abstract operations

To determine if a property name `P` **is an array index**, the following algorithm is applied:

1. If `P` is not a String, then return false.
2. Let `index` be CanonicalNumericIndexString(`P`).
3. If `index` is undefined, then return false.
4. If IsInteger(`index`) is false, then return false.
5. If `index` is −0, then return false.
6. If `index` < 0, then return false.
7. If `index` ≥ 2^32^ − 1, then return false.

    Note: 2^32^ − 1 is the maximum array length allowed by JavaScript.

8. Return true.

The **named property visibility algorithm** is used to determine if a given named property is exposed on an object. Some named properties are not exposed on an object depending on whether the [[`LegacyOverrideBuiltIns`]] extended attribute was used. The algorithm operates as follows, with property name `P` and object `O`:

1. If `P` is not a supported property name of `O`, then return false.

2. If `O` has an own property named `P`, then return false.

    Note: This will include cases in which `O` has unforgeable properties, because in practice those are always set up before objects have any supported property names, and once set up will make the corresponding named properties invisible.

3. If `O` implements an interface that has the [[`LegacyOverrideBuiltIns`]] extended attribute, then return true.

4. Let `prototype` be `O`.[[GetPrototypeOf]]().

5. While `prototype` is not null:

    1. If `prototype` is not a named properties object, and `prototype` has an own property named `P`, then return false.
    2. Set `prototype` to `prototype`.[[GetPrototypeOf]]().

6. Return true.

Note: This ensures that for objects with named properties, property resolution is done in the following order:

1. Indexed properties.
2. Own properties, including unforgeable attributes and operations.
3. Then, if [[`LegacyOverrideBuiltIns`]]:
    1. Named properties.
    2. Properties from the prototype chain.
4. Otherwise, if not [[`LegacyOverrideBuiltIns`]]:
    1. Properties from the prototype chain.
    2. Named properties.

To **invoke an indexed property setter** on a platform object `O` with property name `P` and JavaScript value `V`, the following steps must be performed:

1. Let `index` be the result of calling ? ToUint32(`P`).
2. Let `creating` be true if `index` is not a supported property index, and false otherwise.
3. Let `operation` be the operation used to declare the indexed property setter.
4. Let `T` be the type of the second argument of `operation`.
5. Let `value` be the result of converting `V` to an IDL value of type `T`.
6. If `operation` was defined without an identifier, then:

    1. If `creating` is true, then perform the steps listed in the interface description to set the value of a new indexed property with `index` as the index and `value` as the value.
    2. Otherwise, `creating` is false. Perform the steps listed in the interface description to set the value of an existing indexed property with `index` as the index and `value` as the value.

7. Otherwise, `operation` was defined with an identifier. Perform the method steps of `operation` with `O` as this and « `index`, `value` » as the argument values.

To **invoke a named property setter** on a platform object `O` with property name `P` and JavaScript value `V`, the following steps must be performed:

1. Let `creating` be true if `P` is not a supported property name, and false otherwise.
2. Let `operation` be the operation used to declare the named property setter.
3. Let `T` be the type of the second argument of `operation`.
4. Let `value` be the result of converting `V` to an IDL value of type `T`.
5. If `operation` was defined without an identifier, then:

    1. If `creating` is true, then perform the steps listed in the interface description to set the value of a new named property with `P` as the name and `value` as the value.
    2. Otherwise, `creating` is false. Perform the steps listed in the interface description to set the value of an existing named property with `P` as the name and `value` as the value.

6. Otherwise, `operation` was defined with an identifier. Perform the method steps of `operation` with `O` as this and « `P`, `value` » as the argument values.

The **LegacyPlatformObjectGetOwnProperty** abstract operation performs the following steps when called with an object `O`, a property name `P`, and a boolean `ignoreNamedProps` value:

1. If `O` supports indexed properties and `P` is an array index, then:

    1. Let `index` be the result of calling ! ToUint32(`P`).

    2. If `index` is a supported property index, then:

        1. Let `operation` be the operation used to declare the indexed property getter.
        2. Let `value` be an uninitialized variable.
        3. If `operation` was defined without an identifier, then set `value` to the result of performing the steps listed in the interface description to determine the value of an indexed property with `index` as the index.
        4. Otherwise, `operation` was defined with an identifier. Set `value` to the result of performing the method steps of `operation` with `O` as this and « `index` » as the argument values.
        5. Let `desc` be a newly created Property Descriptor with no fields.
        6. Set `desc`.[[Value]] to the result of converting `value` to a JavaScript value.
        7. If `O` implements an interface with an indexed property setter, then set `desc`.[[Writable]] to true, otherwise set it to false.
        8. Set `desc`.[[Enumerable]] and `desc`.[[Configurable]] to true.
        9. Return `desc`.

    3. Set `ignoreNamedProps` to true.

2. If `O` supports named properties and `ignoreNamedProps` is false, then:

    1. If the result of running the named property visibility algorithm with property name `P` and object `O` is true, then:

        1. Let `operation` be the operation used to declare the named property getter.
        2. Let `value` be an uninitialized variable.
        3. If `operation` was defined without an identifier, then set `value` to the result of performing the steps listed in the interface description to determine the value of a named property with `P` as the name.
        4. Otherwise, `operation` was defined with an identifier. Set `value` to the result of performing the method steps of `operation` with `O` as this and « `P` » as the argument values.
        5. Let `desc` be a newly created Property Descriptor with no fields.
        6. Set `desc`.[[Value]] to the result of converting `value` to a JavaScript value.
        7. If `O` implements an interface with a named property setter, then set `desc`.[[Writable]] to true, otherwise set it to false.
        8. If `O` implements an interface with the [[`LegacyUnenumerableNamedProperties`]] extended attribute, then set `desc`.[[Enumerable]] to false, otherwise set it to true.
        9. Set `desc`.[[Configurable]] to true.
        10. Return `desc`.

3. Return OrdinaryGetOwnProperty(`O`, `P`).


### Observable array exotic objects

An **observable array exotic object** is a specific type of JavaScript Proxy exotic object which is created using the proxy traps defined in this section. They are defined in this manner because the JavaScript specification includes special treatment for Proxy exotic objects that have `Array` instances as their proxy target, and we want to ensure that observable array types are exposed to JavaScript code with this special treatment intact.

The proxy traps used by observable array exotic objects work to ensure a number of invariants beyond those of normal `Array` instances:

- The arrays have no holes, i.e. every property in the inclusive range 0 through `observableArray.length` − 1 will be filled with a value compatible with the specified Web IDL type, and no array index properties will exist outside that range.

- The property descriptors for important properties cannot be changed from their default configuration; indexed properties always remain as configurable, enumerable, and writable data properties, while the `length` property remains as a non-configurable, non-enumerable, and writable data property.

- Adding additional properties to the array cannot be prevented using, for example, `Object.preventExtensions()`.

To **create an observable array exotic object** in a realm `realm`, given Web IDL type `T` and algorithms `setAlgorithm` and `deleteAlgorithm`:

1.  Let `innerArray` be ! ArrayCreate(0).

2.  Let `handler` be OrdinaryObjectCreate(null, « [[Type]], [[SetAlgorithm]], [[DeleteAlgorithm]], [[BackingList]] »).

3.  Set `handler`.[[Type]] to `T`.

4.  Set `handler`.[[SetAlgorithm]] to `setAlgorithm`.

5.  Set `handler`.[[DeleteAlgorithm]] to `deleteAlgorithm`.

6.  Let `defineProperty` be CreateBuiltinFunction(the steps from § 3.10.1 defineProperty, « », `realm`).

7.  Perform ! CreateDataPropertyOrThrow(`handler`, "`defineProperty`", `defineProperty`).

8.  Let `deleteProperty` be CreateBuiltinFunction(the steps from § 3.10.2 deleteProperty, « », `realm`).

9.  Perform ! CreateDataPropertyOrThrow(`handler`, "`deleteProperty`", `deleteProperty`).

10. Let `get` be CreateBuiltinFunction(the steps from § 3.10.3 get, « », `realm`).

11. Perform ! CreateDataPropertyOrThrow(`handler`, "`get`", `get`).

12. Let `getOwnPropertyDescriptor` be CreateBuiltinFunction(the steps from § 3.10.4 getOwnPropertyDescriptor, « », `realm`).

13. Perform ! CreateDataPropertyOrThrow(`handler`, "`getOwnPropertyDescriptor`", `getOwnPropertyDescriptor`).

14. Let `has` be CreateBuiltinFunction(the steps from § 3.10.5 has, « », `realm`).

15. Perform ! CreateDataPropertyOrThrow(`handler`, "`has`", `has`).

16. Let `ownKeys` be CreateBuiltinFunction(the steps from § 3.10.6 ownKeys, « », `realm`).

17. Perform ! CreateDataPropertyOrThrow(`handler`, "`ownKeys`", `ownKeys`).

18. Let `preventExtensions` be CreateBuiltinFunction(the steps from § 3.10.7 preventExtensions, « », `realm`).

19. Perform ! CreateDataPropertyOrThrow(`handler`, "`preventExtensions`", `preventExtensions`).

20. Let `set` be CreateBuiltinFunction(the steps from § 3.10.8 set, « », `realm`).

21. Perform ! CreateDataPropertyOrThrow(`handler`, "`set`", `set`).

22. Return ! ProxyCreate(`innerArray`, `handler`).


#### `defineProperty`

The steps for the `defineProperty` proxy trap for observable array exotic objects, given `O`, `P`, and `descriptorObj` are as follows:

1.  Let `handler` be the this value.

2.  Let `descriptor` be ! ToPropertyDescriptor(`descriptorObj`).

3.  If `P` is "length", then:

    1.  If IsAccessorDescriptor(`descriptor`) is true, then return false.

    2.  If `descriptor`.[[Configurable]] is present and has the value true, then return false.

    3.  If `descriptor`.[[Enumerable]] is present and has the value true, then return false.

    4.  If `descriptor`.[[Writable]] is present and has the value false, then return false.

    5.  If `descriptor`.[[Value]] is present, then return the result of setting the length given `handler` and `descriptor`.[[Value]].

    6.  Return true.

4.  If `P` is an array index, then:

    1.  If IsAccessorDescriptor(`descriptor`) is true, then return false.

    2.  If `descriptor`.[[Configurable]] is present and has the value false, then return false.

    3.  If `descriptor`.[[Enumerable]] is present and has the value false, then return false.

    4.  If `descriptor`.[[Writable]] is present and has the value false, then return false.

    5.  If `descriptor`.[[Value]] is present, then return the result of setting the indexed value given `handler`, `P`, and `descriptor`.[[Value]].

    6.  Return true.

5.  Return ? `O`.[[DefineOwnProperty]](`P`, `descriptor`).


#### `deleteProperty`

The steps for the `deleteProperty` proxy trap for observable array exotic objects, given `O` and `P`, are as follows:

1.  Let `handler` be the this value.

2.  If `P` is "length", then return false.

3.  If `P` is an array index, then:

    1.  Let `oldLen` be `handler`.[[BackingList]]'s size.

    2.  Let `index` be ! ToUint32(`P`).

    3.  If `index` ≠ `oldLen` − 1, then return false.

    4.  Perform the algorithm steps given by `handler`.[[DeleteAlgorithm]], given `handler`.[[BackingList]][`index`] and `index`.

    5.  Remove the last item from `handler`.[[BackingList]].

    6.  Return true.

4.  Return ? `O`.[[Delete]](`P`).


#### `get`

The steps for the `get` proxy trap for observable array exotic objects, given `O`, `P`, and `Receiver`, are as follows:

1.  Let `handler` be the this value.

2.  Let `length` be `handler`.[[BackingList]]'s size.

3.  If `P` is "length", then return `length`.

4.  If `P` is an array index, then:

    1.  Let `index` be ! ToUint32(`P`).

    2.  If `index` ≥ `length`, then return undefined.

    3.  Let `jsValue` be the result of converting `handler`.[[BackingList]][`index`] to a JavaScript value.

    4.  Assert: the above step never throws an exception.

    5.  Return `jsValue`.

5.  Return ? `O`.[[Get]](`P`, `Receiver`).


#### `getOwnPropertyDescriptor`

The steps for the `getOwnPropertyDescriptor` proxy trap for observable array exotic objects, given `O` and `P`, are as follows:

1.  Let `handler` be the this value.

2.  Let `length` be `handler`.[[BackingList]]'s size.

3.  If `P` is "length", then return ! FromPropertyDescriptor(PropertyDescriptor{[[Configurable]]: false, [[Enumerable]]: false, [[Writable]]: true, [[Value]]: `length` }).

4.  If `P` is an array index, then

    1.  Let `index` be ! ToUint32(`P`).

    2.  If `index` ≥ `length`, then return undefined.

    3.  Let `jsValue` be the result of converting `handler`.[[BackingList]][`index`] to a JavaScript value.

    4.  Assert: the above step never throws an exception.

    5.  Return FromPropertyDescriptor(PropertyDescriptor{[[Configurable]]: true, [[Enumerable]]: true, [[Writable]]: true, [[Value]]: `jsValue` }).

5.  Return FromPropertyDescriptor(? `O`.[[GetOwnProperty]](`P`)).


#### `has`

The steps for the `has` proxy trap for observable array exotic objects, given `O` and `P`, are as follows:

1.  Let `handler` be the this value.

2.  If `P` is "length", then return true.

3.  If `P` is an array index, then:

    1.  Let `index` be ! ToUint32(`P`).

    2.  If `index` < `handler`.[[BackingList]]'s size, then return true.

    3.  Return false.

4.  Return ? `O`.[[HasProperty]](`P`).


#### `ownKeys`

The steps for the `ownKeys` proxy trap for observable array exotic objects, given `O`, are as follows:

1.  Let `handler` be the this value.

2.  Let `length` be `handler`.[[BackingList]]'s size.

3.  Let `keys` be an empty list.

4.  Let `i` be 0.

5.  While `i` < `length`:

    1.  Append ! ToString(`i`) to `keys`.

    2.  Set `i` to `i` + 1.

6.  Extend `keys` with ! `O`.[[OwnPropertyKeys]]().

7.  Return CreateArrayFromList(`keys`).


#### `preventExtensions`

The steps for the `preventExtensions` proxy trap for observable array exotic objects are as follows:

1.  Return false.


#### `set`

The steps for the `set` proxy trap for observable array exotic objects, given `O`, `P`, `V`, and `Receiver`, are as follows:

1.  Let `handler` be the this value.

2.  If `P` is "length", then return the result of setting the length given `handler` and `V`.

3.  If `P` is an array index, then return the result of setting the indexed value given `handler`, `P`, and `V`.

4.  Return ? `O`.[[Set]](`P`, `V`, `Receiver`).


#### Abstract operations

To **set the length** of an observable array exotic object given `handler` and `newLen`:

1.  Let `uint32Len` be ? ToUint32(`newLen`).

2.  Let `numberLen` be ? ToNumber(`newLen`).

3.  If `uint32Len` ≠ `numberLen`, then throw a `RangeError` exception.

4.  Let `oldLen` be `handler`.[[BackingList]]'s size.

5.  If `uint32Len` > `oldLen`, then return false.

6.  Let `indexToDelete` be `oldLen` − 1.

7.  While `indexToDelete` ≥ `uint32Len`:

    1.  Perform the algorithm steps given by `handler`.[[DeleteAlgorithm]], given `handler`.[[BackingList]][`indexToDelete`] and `indexToDelete`.

    2.  Remove the last item from `handler`.[[BackingList]].

    3.  Set `indexToDelete` to `indexToDelete` − 1.

8.  Return true.

To **set the indexed value** of an observable array exotic object given `handler`, `P`, and `V`:

1.  Let `oldLen` be `handler`.[[BackingList]]'s size.

2.  Let `index` be ! ToUint32(`P`).

3.  If `index` > `oldLen`, return false.

4.  Let `idlValue` be the result of converting `V` to the type given by `handler`.[[Type]].

5.  If `index` < `oldLen`, then:

    1.  Perform the algorithm steps given by `handler`.[[DeleteAlgorithm]], given `handler`.[[BackingList]][`index`] and `index`.

6.  Perform the algorithm steps given by `handler`.[[SetAlgorithm]], given `idlValue` and `index`.

7.  If `index` = `oldLen`, then append `idlValue` to `handler`.[[BackingList]].

8.  Otherwise, set `handler`.[[BackingList]][`index`] to `idlValue`.

9.  Return true.


### Callback interfaces

As described in § 2.12 Objects implementing interfaces, callback interfaces can be implemented in script by any JavaScript object. The following cases explain how a callback interface's operation is invoked on a given object:

- If the object is callable, then the implementation of the operation is the callable object itself.

- Otherwise, the implementation of the operation is calling the result of invoking the internal [[Get]] method on the object with a property name that is the identifier of the operation.

Note that JavaScript objects need not have properties corresponding to constants on them to be considered as implementing callback interfaces that happen to have constants declared on them.

A **Web IDL arguments list** is a list of values each of which is either an IDL value or the special value "missing", which represents a missing optional argument.

To **convert a Web IDL arguments list to a JavaScript arguments list**, given a Web IDL arguments list `args`, perform the following steps:

1. Let `jsArgs` be an empty list.

2. Let `i` be 0.

3. Let `count` be 0.

4. While `i` < `args`'s size:

    1. If `args`[`i`] is the special value "missing", then append undefined to `jsArgs`.

    2. Otherwise, `args`[`i`] is an IDL value:

        1. Let `convertResult` be the result of converting `args`[`i`] to a JavaScript value. Rethrow any exceptions.

        2. Append `convertResult` to `jsArgs`.

        3. Set `count` to `i` + 1.

    3. Set `i` to `i` + 1.

5. Truncate `jsArgs` to contain `count` items.

6. Return `jsArgs`.

To **call a user object's operation**, given a callback interface type value `value`, operation name `opName`, Web IDL arguments list `args`, and optional **callback this value** `thisArg`, perform the following steps. These steps will either return an IDL value or throw an exception.

1. Let `completion` be an uninitialized variable.

2. If `thisArg` was not given, let `thisArg` be undefined.

3. Let `O` be the JavaScript object corresponding to `value`.

4. Let `realm` be `O`'s associated realm.

5. Let `relevant settings` be `realm`'s settings object.

6. Let `stored settings` be `value`'s callback context.

7. Prepare to run script with `relevant settings`.

8. Prepare to run a callback with `stored settings`.

9. Let `X` be `O`.

10. If IsCallable(`O`) is false, then:

    1. Let `getResult` be Completion(Get(`O`, `opName`)).

    2. If `getResult` is an abrupt completion, set `completion` to `getResult` and jump to the step labeled *return*.

    3. Set `X` to `getResult`.[[Value]].

    4. If IsCallable(`X`) is false, then set `completion` to Completion Record { [[Type]]: throw, [[Value]]: a newly created `TypeError` object, [[Target]]: empty }, and jump to the step labeled *return*.

    5. Set `thisArg` to `O` (overriding the provided value).

11. Let `jsArgs` be the result of converting `args` to a JavaScript arguments list. If this throws an exception, set `completion` to the completion value representing the thrown exception and jump to the step labeled *return*.

12. Let `callResult` be Completion(Call(`X`, `thisArg`, `jsArgs`)).

13. If `callResult` is an abrupt completion, set `completion` to `callResult` and jump to the step labeled *return*.

14. Set `completion` to the result of converting `callResult`.[[Value]] to an IDL value of the same type as the operation's return type. If this throws an exception, set `completion` to the completion value representing the thrown exception.

15. *Return:* at this point `completion` will be set to an IDL value or an abrupt completion.

    1. Clean up after running a callback with `stored settings`.

    2. Clean up after running script with `relevant settings`.

    3. If `completion` is an IDL value, return `completion`.

    4. If `completion` is an abrupt completion and the operation has a return type that is *not* a promise type, throw `completion`.[[Value]].

    5. Let `rejectedPromise` be ! Call(`%Promise.reject%`, `%Promise%`, «`completion`.[[Value]]»).

    6. Return the result of converting `rejectedPromise` to the operation's return type.


#### Legacy callback interface object

For every callback interface that is exposed in a given realm and on which constants are defined, a corresponding property exists on the realm's global object. The name of the property is the identifier of the callback interface, and its value is an object called the **legacy callback interface object**.

The legacy callback interface object for a given callback interface is a built-in function object. It has properties that correspond to the constants defined on that interface, as described in sections § 3.7.5 Constants.

Note: Since a legacy callback interface object is a function object the `typeof` operator will return "function" when applied to a legacy callback interface object.

The legacy callback interface object for a given callback interface `interface` with identifier `id` and in realm `realm` is **created** as follows:

1. Let `steps` be the following steps:

    1. Throw a `TypeError`.

2. Let `F` be CreateBuiltinFunction(`steps`, « », `realm`).

3. Perform SetFunctionName(`F`, `id`).

4. Perform SetFunctionLength(`F`, 0).

5. Define the constants of `interface` on `F` given `realm`.

6. Return `F`.


### Invoking callback functions

A JavaScript [callable](https://tc39.es/ecma262/#sec-iscallable) object that is being used as a callback function value is called in a manner similar to how operations on callback interface values are called (as described in the previous section).

To **invoke** a callback function type value `callable` with a Web IDL arguments list `args`, exception behavior `exceptionBehavior` (either "`report`" or "`rethrow`"), and an optional callback this value `thisArg`, perform the following steps. These steps will either return an IDL value or throw an exception.

The `exceptionBehavior` argument must be supplied if, and only if, `callable`'s return type is not a promise type. If `callable`'s return type is neither `undefined` nor `any`, it must be "`rethrow`".

Until call sites are updated to respect this, specifications which fail to provide a value here when it would be mandatory should be understood as supplying "`rethrow`".

1.  Let `completion` be an uninitialized variable.

2.  If `thisArg` was not given, let `thisArg` be undefined.

3.  Let `F` be the JavaScript object corresponding to `callable`.

4.  If [IsCallable](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-iscallable)(`F`) is false:

    1.  Note: This is only possible when the callback function came from an attribute marked with \[`LegacyTreatNonObjectAsNull`\].

    2.  Return the result of converting undefined to the callback function's return type.

5.  Let `realm` be `F`'s associated realm.

6.  Let `relevant settings` be `realm`'s [settings object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-settings-object).

7.  Let `stored settings` be `callable`'s callback context.

8.  [Prepare to run script](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-script) with `relevant settings`.

9.  [Prepare to run a callback](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-a-callback) with `stored settings`.

10. Let `jsArgs` be the result of converting `args` to a JavaScript arguments list. If this throws an exception, set `completion` to the completion value representing the thrown exception and jump to the step labeled *return*.

11. Let `callResult` be [Completion](https://tc39.es/ecma262/#sec-completion-record-specification-type)([Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)(`F`, `thisArg`, `jsArgs`)).

12. If `callResult` is an [abrupt completion](https://tc39.es/ecma262/#sec-completion-record-specification-type), set `completion` to `callResult` and jump to the step labeled *return*.

13. Set `completion` to the result of converting `callResult`.[[Value]] to an IDL value of the same type as `callable`'s return type. If this throws an exception, set `completion` to the completion value representing the thrown exception.

14. *Return:* at this point `completion` will be set to an IDL value or an [abrupt completion](https://tc39.es/ecma262/#sec-completion-record-specification-type).

    1.  [Clean up after running a callback](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-a-callback) with `stored settings`.

    2.  [Clean up after running script](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script) with `relevant settings`.

    3.  If `completion` is an IDL value, return `completion`.

    4.  [Assert](https://infra.spec.whatwg.org/#assert): `completion` is an [abrupt completion](https://tc39.es/ecma262/#sec-completion-record-specification-type).

    5.  If `exceptionBehavior` is "`rethrow`", throw `completion`.[[Value]].

    6.  Otherwise, if `exceptionBehavior` is "`report`":

        1.  [Assert](https://infra.spec.whatwg.org/#assert): `callable`'s return type is `undefined` or `any`.

        2.  [Report an exception](https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception) `completion`.[[Value]] for `realm`'s [global object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global).

        3.  Return the unique `undefined` IDL value.

    7.  [Assert](https://infra.spec.whatwg.org/#assert): `callable`'s return type is a promise type.

    8.  Let `rejectedPromise` be [!](https://tc39.es/ecma262/#sec-returnifabrupt-shorthands) [Call](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-call)([`%Promise.reject%`](https://tc39.es/ecma262/#sec-promise.reject), [`%Promise%`](https://tc39.es/ecma262/multipage/control-abstraction-objects.html#sec-promise-constructor), «`completion`.[[Value]]»).

    9.  Return the result of converting `rejectedPromise` to the callback function's return type.


Some callback functions are instead used as [constructors](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#constructor). Such callback functions must not have a return type that is a promise type.

To **construct** a callback function type value `callable` with a Web IDL arguments list `args`, perform the following steps. These steps will either return an IDL value or throw an exception.

1.  Let `completion` be an uninitialized variable.

2.  Let `F` be the JavaScript object corresponding to `callable`.

3.  If [IsConstructor](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-isconstructor)(`F`) is false, throw a [`TypeError`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-native-error-types-used-in-this-standard-typeerror) exception.

4.  Let `realm` be `F`'s associated realm.

5.  Let `relevant settings` be `realm`'s [settings object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-settings-object).

6.  Let `stored settings` be `callable`'s callback context.

7.  [Prepare to run script](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-script) with `relevant settings`.

8.  [Prepare to run a callback](https://html.spec.whatwg.org/multipage/webappapis.html#prepare-to-run-a-callback) with `stored settings`.

9.  Let `jsArgs` be the result of converting `args` to a JavaScript arguments list. If this throws an exception, set `completion` to the completion value representing the thrown exception and jump to the step labeled *return*.

10. Let `callResult` be [Completion](https://tc39.es/ecma262/#sec-completion-record-specification-type)([Construct](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-construct)(`F`, `jsArgs`)).

11. If `callResult` is an [abrupt completion](https://tc39.es/ecma262/#sec-completion-record-specification-type), set `completion` to `callResult` and jump to the step labeled *return*.

12. Set `completion` to the result of converting `callResult`.[[Value]] to an IDL value of the same type as `callable`'s return type. If this throws an exception, set `completion` to the completion value representing the thrown exception.

13. *Return:* at this point `completion` will be set to an IDL value or an [abrupt completion](https://tc39.es/ecma262/#sec-completion-record-specification-type).

    1.  [Clean up after running a callback](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-a-callback) with `stored settings`.

    2.  [Clean up after running script](https://html.spec.whatwg.org/multipage/webappapis.html#clean-up-after-running-script) with `relevant settings`.

    3.  If `completion` is an [abrupt completion](https://tc39.es/ecma262/#sec-completion-record-specification-type), throw `completion`.[[Value]].

    4.  Return `completion`.


## Namespaces

For every [namespace](#dfn-namespace) that is [exposed](#dfn-exposed) in a given [realm](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm), a corresponding property exists on the [realm](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm)'s [global object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-global). The name of the property is the [identifier](#dfn-identifier) of the namespace, and its value is an object called the namespace object.

The characteristics of a namespace object are described in § Namespace object.


### Namespace object

The namespace object for a given [namespace](#dfn-namespace) `namespace` and [realm](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#realm) `realm` is created as follows:

1.  Let `namespaceObject` be [OrdinaryObjectCreate](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-ordinaryobjectcreate)(`realm`.[[Intrinsics]].[[`%Object.prototype%`]]).

2.  [Define the regular attributes](#define-the-regular-attributes) of `namespace` on `namespaceObject` given `realm`.

3.  [Define the regular operations](#define-the-regular-operations) of `namespace` on `namespaceObject` given `realm`.

4.  [Define the constants](#define-the-constants) of `namespace` on `namespaceObject` given `realm`.

5.  For each [exposed](#dfn-exposed) [interface](#dfn-interface) `interface` which has the [[`LegacyNamespace`](#LegacyNamespace)] extended attribute with the identifier of `namespace` as its argument,

    1.  Let `id` be `interface`'s [identifier](#dfn-identifier).

    2.  Let `interfaceObject` be the result of [creating an interface object](#create-an-interface-object) for `interface` with `id` in `realm`.

    3.  Perform [DefineMethodProperty](https://tc39.es/ecma262/multipage/ordinary-and-exotic-objects-behaviours.html#sec-definemethodproperty)(`namespaceObject`, `id`, `interfaceObject`, false).

6.  Return `namespaceObject`.

The [class string](#dfn-class-string) of a [namespace object](#dfn-namespace-object) is the [namespace](#dfn-namespace)'s [identifier](#dfn-identifier).


### Exceptions


#### `DOMException` custom bindings

In the JavaScript binding, the interface prototype object for `DOMException` has its \[\[Prototype\]\] internal slot set to the intrinsic object `%Error.prototype%`, as defined in the create an interface prototype object abstract operation. It also has an \[\[ErrorData\]\] slot, like all built-in exceptions.

Additionally, if an implementation gives native `Error` objects special powers or nonstandard properties (such as a `stack` property), it should also expose those on `DOMException` objects.


#### Exception objects

Simple exceptions are represented by native JavaScript objects of the corresponding type.

A `DOMException` is represented by a platform object that implements the `DOMException` interface.


#### Creating and throwing exceptions

To create a simple exception of type `T`:

1.  Let `message` be an implementation-defined message appropriate for the exceptional situation. The calling specification may contain information to to help implementations construct this message.

    Implementations need to be cautious not to leak sensitive or secured information when constructing this message, e.g., by including the URL of a cross-origin frame, or information which could identify the user.

2.  Let `args` be « `message` ».

3.  Let `constructor` be current realm.\[\[Intrinsics\]\].\[\[%`T`%\]\].

4.  Return ! Construct(`constructor`, `args`).

To create a `DOMException` given a string `name`:

1.  Assert: `name` appears in the `DOMException` names table.

2.  Let `ex` be a new `DOMException` created in the current realm.

3.  Set `ex`'s name to `name`.

4.  Set `ex`'s message to an implementation-defined message appropriate for the exceptional situation. The calling specification may contain information to to help implementations construct this message.

    Implementations need to be cautious not to leak sensitive or secured information when constructing this message, e.g., by including the URL of a cross-origin frame, or information which could identify the user.

5.  Return `ex`.

To create a `DOMException` derived interface given the interface identifier `type` and additional initialization instructions:

1.  Let `ex` be a new instance of the interface identified by `type`, created in the current realm.

2.  Set `ex`'s name to `type`.

3.  Set `ex`'s message to an implementation-defined message appropriate for the exceptional situation. The calling specification may contain information to to help implementations construct this message.

    Implementations need to be cautious not to leak sensitive or secured information when constructing this message, e.g., by including the URL of a cross-origin frame, or information which could identify the user.

4.  Perform any additional initialization on `ex` as described by the caller.

5.  Return `ex`.

To throw an exception:

1.  Let `O` be the result of creating an exception with the same arguments.

2.  Throw `O`.

Note: The above algorithms restrict objects representing exceptions propagating out of a function object to be ones that are associated with the realm of that function object (i.e., the current realm at the time the function executes). For example, consider the IDL:

```
[Exposed=Window]
interface MathUtils {
  // If x is negative, throws a "NotSupportedError" DOMException.
  double computeSquareRoot(double x);
};
```

If we apply `computeSquareRoot` to a `MathUtils` object from a different realm, then the exception thrown will be from the realm of the method, not the object it is applied to:

```
const myMU = window.getMathUtils();          // A MathUtils object from this realm
const otherMU = otherWindow.getMathUtils();  // A MathUtils object from a different realm

myMU instanceof Object;                      // Evaluates to true.
otherMU instanceof Object;                   // Evaluates to false.
otherMU instanceof otherWindow.Object;       // Evaluates to true.

try {
  otherMU.doComputation.call(myMU, -1);
} catch (e) {
  console.assert(!(e instanceof DOMException));
  console.assert(e instanceof otherWindow.DOMException);
}
```


#### Handling exceptions

Unless specified otherwise, whenever JavaScript runtime semantics are invoked due to requirements in this document and end due to an exception being thrown, that exception must propagate to the caller, and if not caught there, to its caller, and so on.

Per Document conventions, an algorithm specified in this document may intercept thrown exceptions, either by specifying the exact steps to take if an exception was thrown, or by explicitly handling abrupt completions.

The following IDL fragment defines two interfaces and an exception. The `valueOf` attribute on `ExceptionThrower` is defined to throw an exception whenever an attempt is made to get its value.

```
[Exposed=Window]
interface Dahut {
  attribute DOMString type;
};

[Exposed=Window]
interface ExceptionThrower {
  // This attribute always throws a NotSupportedError and never returns a value.
  attribute long valueOf;
};
```

Assuming a JavaScript implementation supporting this interface, the following code demonstrates how exceptions are handled:

```
var d = getDahut();              // Obtain an instance of Dahut.
var et = getExceptionThrower();  // Obtain an instance of ExceptionThrower.

try {
  d.type = { toString: function() { throw "abc"; } };
} catch (e) {
  // The string "abc" is caught here, since as part of the conversion
  // from the native object to a string, the anonymous function
  // was invoked, and none of the [[DefaultValue]], ToPrimitive or
  // ToString algorithms are defined to catch the exception.
}

try {
  d.type = { toString: { } };
} catch (e) {
  // An exception is caught here, since an attempt is made to invoke
  // [[Call]] on the native object that is the value of toString
  // property.
}

try {
  d.type = Symbol();
} catch (e) {
  // An exception is caught here, since an attempt is made to invoke
  // the JavaScript ToString abstract operation on a Symbol value.
}

d.type = et;
// An uncaught "NotSupportedError" DOMException is thrown here, since the
// [[DefaultValue]] algorithm attempts to get the value of the
// "valueOf" property on the ExceptionThrower object.  The exception
// propagates out of this block of code.
```


## Common definitions

This section specifies some common definitions that all conforming implementations must support.


### ArrayBufferView

```idl
typedef (Int8Array or Int16Array or Int32Array or
         Uint8Array or Uint16Array or Uint32Array or Uint8ClampedArray or
         BigInt64Array or BigUint64Array or
         Float16Array or Float32Array or Float64Array or DataView) ArrayBufferView;
```

The `ArrayBufferView` typedef is used to represent objects that provide a view on to an `ArrayBuffer` or `SharedArrayBuffer` (when \[`AllowShared`\] is used).


## BufferSource

```idl
typedef (ArrayBufferView or ArrayBuffer) BufferSource;
```

The `BufferSource` typedef is used to represent objects that are either themselves an `ArrayBuffer` or which provide a view on to an `ArrayBuffer`.

Note: `[AllowShared]` cannot be used with `BufferSource` as `ArrayBuffer` does not support it. Use `AllowSharedBufferSource` instead.


### AllowSharedBufferSource

```idl
typedef (ArrayBuffer or SharedArrayBuffer or [AllowShared] ArrayBufferView) AllowSharedBufferSource;
```

The `AllowSharedBufferSource` typedef is used to represent objects that are either themselves an `ArrayBuffer` or `SharedArrayBuffer` or which provide a view on to an `ArrayBuffer` or `SharedArrayBuffer`.


### DOMException

The `DOMException` type is an interface type defined by the following IDL fragment:

```idl
[Exposed=*,
 Serializable]
interface DOMException { // but see below note about JavaScript binding
  constructor(optional DOMString message = "", optional DOMString name = "Error");
  readonly attribute DOMString name;
  readonly attribute DOMString message;
  readonly attribute unsigned short code;

  const unsigned short INDEX_SIZE_ERR = 1;
  const unsigned short DOMSTRING_SIZE_ERR = 2;
  const unsigned short HIERARCHY_REQUEST_ERR = 3;
  const unsigned short WRONG_DOCUMENT_ERR = 4;
  const unsigned short INVALID_CHARACTER_ERR = 5;
  const unsigned short NO_DATA_ALLOWED_ERR = 6;
  const unsigned short NO_MODIFICATION_ALLOWED_ERR = 7;
  const unsigned short NOT_FOUND_ERR = 8;
  const unsigned short NOT_SUPPORTED_ERR = 9;
  const unsigned short INUSE_ATTRIBUTE_ERR = 10;
  const unsigned short INVALID_STATE_ERR = 11;
  const unsigned short SYNTAX_ERR = 12;
  const unsigned short INVALID_MODIFICATION_ERR = 13;
  const unsigned short NAMESPACE_ERR = 14;
  const unsigned short INVALID_ACCESS_ERR = 15;
  const unsigned short VALIDATION_ERR = 16;
  const unsigned short TYPE_MISMATCH_ERR = 17;
  const unsigned short SECURITY_ERR = 18;
  const unsigned short NETWORK_ERR = 19;
  const unsigned short ABORT_ERR = 20;
  const unsigned short URL_MISMATCH_ERR = 21;
  const unsigned short QUOTA_EXCEEDED_ERR = 22;
  const unsigned short TIMEOUT_ERR = 23;
  const unsigned short INVALID_NODE_TYPE_ERR = 24;
  const unsigned short DATA_CLONE_ERR = 25;
};
```

Note: as discussed in § 3.14.1 DOMException custom bindings, the JavaScript binding imposes additional requirements beyond the normal ones for interface types.

Each `DOMException` object has an associated name and message, both strings.

The `new DOMException(message, name)` constructor steps are:

1.  Set this's name to `name`.

2.  Set this's message to `message`.

The `name` getter steps are to return this's name.

The `message` getter steps are to return this's message.

The `code` getter steps are to return the legacy code indicated in the `DOMException` names table for this's name, or 0 if no such entry exists in the table.

`DOMException` objects are serializable objects.

Their serialization steps, given `value` and `serialized`, are:

1.  Set `serialized`.[[Name]] to `value`'s name.
2.  Set `serialized`.[[Message]] to `value`'s message.
3.  User agents should attach a serialized representation of any interesting accompanying data which are not yet specified, notably the `stack` property, to `serialized`.

Their deserialization steps, given `value` and `serialized`, are:

1.  Set `value`'s name to `serialized`.[[Name]].
2.  Set `value`'s message to `serialized`.[[Message]].
3.  If any other data is attached to `serialized`, then deserialize and attach it to `value`.


### Function

```idl
callback Function = any (any... arguments);
```

The `Function` callback function type is used for representing function values with no restriction on what arguments are passed to it or what kind of value is returned from it.


### VoidFunction

```idl
callback VoidFunction = undefined ();
```

The `VoidFunction` callback function type is used for representing function values that take no arguments and do not return any value.


## Extensibility

*This section is informative.*

Extensions to language binding requirements can be specified using extended attributes that do not conflict with those defined in this document. Extensions for private, project-specific use ought not be included in IDL fragments appearing in other specifications. It is recommended that extensions that are required for use in other specifications be coordinated with the group responsible for work on Web IDL, which at the time of writing is the [W3C Web Platform Working Group](http://www.w3.org/WebPlatform/WG/), for possible inclusion in a future version of this document.

Extensions to any other aspect of the IDL language are strongly discouraged.


## Legacy constructs

*This section is informative.*

Legacy Web IDL constructs exist only so that legacy Web platform features can be specified. They are generally prefixed with the "`Legacy`" string. It is strongly discouraged to use legacy Web IDL constructs in specifications unless required to specify the behavior of legacy Web platform features, or for consistency with such features. Editors who wish to use legacy Web IDL constructs are strongly advised to discuss this by [filing an issue](https://github.com/whatwg/webidl/issues/new?title=Intent%20to%20use%20a%20legacy%20Web%20IDL%20construct) before proceeding.

Marking a construct as legacy does not, in itself, imply that it is about to be removed from this specification. It does suggest however, that it is a good candidate for future removal from this specification, whenever various heuristics indicate that the Web platform features it helps specify can be removed altogether or can be modified to rely on non-legacy Web IDL constructs instead.


## Referencing this specification

*This section is informative.*

It is expected that other specifications that define Web platform interfaces using one or more IDL fragments will reference this specification. It is suggested that those specifications include a sentence such as the following, to indicate that the IDL is to be interpreted as described in this specification:

> The IDL fragment in Appendix A of this specification must, in conjunction with the IDL fragments defined in this specification's normative references, be interpreted as required for *conforming sets of IDL fragments*, as described in the "Web IDL" specification. \[WEBIDL\]

In addition, it is suggested that the conformance class for user agents in referencing specifications be linked to the conforming implementation class from this specification:

> A conforming FooML user agent must also be a *conforming implementation* of the IDL fragment in Appendix A of this specification, as described in the "Web IDL" specification. \[WEBIDL\]


## Privacy and Security Considerations

This specification defines a conversion layer between JavaScript and IDL values. An incorrect implementation of this layer can lead to security issues.

This specification also provides the ability to use JavaScript values directly, through the `any` and `object` IDL types. These values need to be handled carefully to avoid security issues. In particular, user script can run in response to nearly any manipulation of these values, and invalidate the expectations of specifications or implementations using them.

This specification makes it possible to interact with `SharedArrayBuffer` objects, which can be used to build timing attacks. Specifications that use these objects need to consider such attacks.


## IDL grammar

This section defines an LL(1) grammar whose start symbol, Definitions, matches an entire IDL fragment.

Each production in the grammar has on its right hand side either a non-zero sequence of terminal and non-terminal symbols, or an epsilon (ε) which indicates no symbols. Symbols that begin with an uppercase letter are non-terminal symbols. Symbols in monospaced fonts are terminal symbols. Symbols in sans-serif font that begin with a lowercase letter are terminal symbols that are matched by the regular expressions (using Perl 5 regular expression syntax [PERLRE]) as follows:

  ------------ ----- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  integer      `=`   `-?([1-9][0-9]*|0[Xx][0-9A-Fa-f]+|0[0-7]*)`
  decimal      `=`   `-?(([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)([Ee][+-]?[0-9]+)?|[0-9]+[Ee][+-]?[0-9]+)`
  identifier   `=`   `[_-]?[A-Za-z][0-9A-Z_a-z-]*`
  string       `=`   `"[^"]*"`
  whitespace   `=`   `[\t\n\r ]+`
  comment      `=`   `\/\/.*|\/\*(.|\n)*?\*\/`
  other        `=`   `[^\t\n\r 0-9A-Za-z]`
  ------------ ----- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

The tokenizer operates on a sequence of scalar values. When tokenizing, the longest possible match must be used. For example, if the input text is "a1", it is tokenized as a single identifier, and not as a separate identifier and integer. If the longest possible match could match one of the above named terminal symbols or one of the other terminal symbols from the grammar, it must be tokenized as the latter. Thus, the input text "long" is tokenized as the terminal symbol long rather than an identifier called "`long`", and "." is tokenized as the terminal symbol . rather than an other.

The IDL syntax is case sensitive, both for the monospaced terminal symbols used in the grammar and the values used for identifier terminals. Thus, for example, the input text "Const" is tokenized as an identifier rather than the terminal symbol const, an interface with identifier "`A`" is distinct from one named "`a`", and an extended attribute \[`legacyfactoryfunction`\] will not be recognized as the \[`LegacyFactoryFunction`\] extended attribute.

Implicitly, any number of whitespace and comment terminals are allowed between every other terminal in the input text being parsed. Such whitespace and comment terminals are ignored while parsing.

The following LL(1) grammar, starting with Definitions, matches an IDL fragment:

```grammar
Definitions ::
    ExtendedAttributeList Definition Definitions
    ε

Definition ::
    CallbackOrInterfaceOrMixin
    Namespace
    Partial
    Dictionary
    Enum
    Typedef
    IncludesStatement

ArgumentNameKeyword ::
    attribute
    callback
    const
    constructor
    deleter
    dictionary
    enum
    getter
    includes
    inherit
    interface
    iterable
    maplike
    mixin
    namespace
    partial
    readonly
    required
    setlike
    setter
    static
    stringifier
    typedef
    unrestricted

CallbackOrInterfaceOrMixin ::
    callback CallbackRestOrInterface
    interface InterfaceOrMixin

InterfaceOrMixin ::
    InterfaceRest
    MixinRest

InterfaceRest ::
    identifier Inheritance { InterfaceMembers } ;

Partial ::
    partial PartialDefinition

PartialDefinition ::
    interface PartialInterfaceOrPartialMixin
    PartialDictionary
    Namespace

PartialInterfaceOrPartialMixin ::
    PartialInterfaceRest
    MixinRest

PartialInterfaceRest ::
    identifier { PartialInterfaceMembers } ;

InterfaceMembers ::
    ExtendedAttributeList InterfaceMember InterfaceMembers
    ε

InterfaceMember ::
    PartialInterfaceMember
    Constructor

PartialInterfaceMembers ::
    ExtendedAttributeList PartialInterfaceMember PartialInterfaceMembers
    ε

PartialInterfaceMember ::
    Const
    Operation
    Stringifier
    StaticMember
    Iterable
    AsyncIterable
    ReadOnlyMember
    ReadWriteAttribute
    ReadWriteMaplike
    ReadWriteSetlike
    InheritAttribute

Inheritance ::
    : identifier
    ε

MixinRest ::
    mixin identifier { MixinMembers } ;

MixinMembers ::
    ExtendedAttributeList MixinMember MixinMembers
    ε

MixinMember ::
    Const
    RegularOperation
    Stringifier
    OptionalReadOnly AttributeRest

IncludesStatement ::
    identifier includes identifier ;

CallbackRestOrInterface ::
    CallbackRest
    interface identifier { CallbackInterfaceMembers } ;

CallbackInterfaceMembers ::
    ExtendedAttributeList CallbackInterfaceMember CallbackInterfaceMembers
    ε

CallbackInterfaceMember ::
    Const
    RegularOperation

Const ::
    const ConstType identifier = ConstValue ;

ConstValue ::
    BooleanLiteral
    FloatLiteral
    integer

BooleanLiteral ::
    true
    false

FloatLiteral ::
    decimal
    -Infinity
    Infinity
    NaN

ConstType ::
    PrimitiveType
    identifier

ReadOnlyMember ::
    readonly ReadOnlyMemberRest

ReadOnlyMemberRest ::
    AttributeRest
    MaplikeRest
    SetlikeRest

ReadWriteAttribute ::
    AttributeRest

InheritAttribute ::
    inherit AttributeRest

AttributeRest ::
    attribute TypeWithExtendedAttributes AttributeName ;

AttributeName ::
    AttributeNameKeyword
    identifier

AttributeNameKeyword ::
    required

OptionalReadOnly ::
    readonly
    ε

DefaultValue ::
    ConstValue
    string
    [ ]
    { }
    null
    undefined

Operation ::
    RegularOperation
    SpecialOperation

RegularOperation ::
    Type OperationRest

SpecialOperation ::
    Special RegularOperation

Special ::
    getter
    setter
    deleter

OperationRest ::
    OptionalOperationName ( ArgumentList ) ;

OptionalOperationName ::
    OperationName
    ε

OperationName ::
    OperationNameKeyword
    identifier

OperationNameKeyword ::
    includes

ArgumentList ::
    Argument Arguments
    ε

Arguments ::
    , Argument Arguments
    ε

Argument ::
    ExtendedAttributeList ArgumentRest

ArgumentRest ::
    optional TypeWithExtendedAttributes ArgumentName Default
    Type Ellipsis ArgumentName

ArgumentName ::
    ArgumentNameKeyword
    identifier

Ellipsis ::
    ...
    ε

Constructor ::
    constructor ( ArgumentList ) ;

Stringifier ::
    stringifier StringifierRest

StringifierRest ::
    OptionalReadOnly AttributeRest
    ;

StaticMember ::
    static StaticMemberRest

StaticMemberRest ::
    OptionalReadOnly AttributeRest
    RegularOperation

Iterable ::
    iterable < TypeWithExtendedAttributes OptionalType > ;

OptionalType ::
    , TypeWithExtendedAttributes
    ε

AsyncIterable ::
    async_iterable < TypeWithExtendedAttributes OptionalType > OptionalArgumentList ;

OptionalArgumentList ::
    ( ArgumentList )
    ε

ReadWriteMaplike ::
    MaplikeRest

MaplikeRest ::
    maplike < TypeWithExtendedAttributes , TypeWithExtendedAttributes > ;

ReadWriteSetlike ::
    SetlikeRest

SetlikeRest ::
    setlike < TypeWithExtendedAttributes > ;

Namespace ::
    namespace identifier { NamespaceMembers } ;

NamespaceMembers ::
    ExtendedAttributeList NamespaceMember NamespaceMembers
    ε

NamespaceMember ::
    RegularOperation
    readonly AttributeRest
    Const

Dictionary ::
    dictionary identifier Inheritance { DictionaryMembers } ;

DictionaryMembers ::
    DictionaryMember DictionaryMembers
    ε

DictionaryMember ::
    ExtendedAttributeList DictionaryMemberRest

DictionaryMemberRest ::
    required TypeWithExtendedAttributes identifier ;
    Type identifier Default ;

PartialDictionary ::
    dictionary identifier { DictionaryMembers } ;

Default ::
    = DefaultValue
    ε

Enum ::
    enum identifier { EnumValueList } ;

EnumValueList ::
    string EnumValueListComma

EnumValueListComma ::
    , EnumValueListString
    ε

EnumValueListString ::
    string EnumValueListComma
    ε

CallbackRest ::
    identifier = Type ( ArgumentList ) ;

Typedef ::
    typedef TypeWithExtendedAttributes identifier ;

Type ::
    SingleType
    UnionType Null

TypeWithExtendedAttributes ::
    ExtendedAttributeList Type

SingleType ::
    DistinguishableType
    any
    PromiseType

UnionType ::
    ( UnionMemberType or UnionMemberType UnionMemberTypes )

UnionMemberType ::
    ExtendedAttributeList DistinguishableType
    UnionType Null

UnionMemberTypes ::
    or UnionMemberType UnionMemberTypes
    ε

DistinguishableType ::
    PrimitiveType Null
    StringType Null
    identifier Null
    sequence < TypeWithExtendedAttributes > Null
    async_sequence < TypeWithExtendedAttributes > Null
    object Null
    symbol Null
    BufferRelatedType Null
    FrozenArray < TypeWithExtendedAttributes > Null
    ObservableArray < TypeWithExtendedAttributes > Null
    RecordType Null
    undefined Null

PrimitiveType ::
    UnsignedIntegerType
    UnrestrictedFloatType
    boolean
    byte
    octet
    bigint

UnrestrictedFloatType ::
    unrestricted FloatType
    FloatType

FloatType ::
    float
    double

UnsignedIntegerType ::
    unsigned IntegerType
    IntegerType

IntegerType ::
    short
    long OptionalLong

OptionalLong ::
    long
    ε

StringType ::
    ByteString
    DOMString
    USVString

PromiseType ::
    Promise < Type >

RecordType ::
    record < StringType , TypeWithExtendedAttributes >

Null ::
    ?
    ε

BufferRelatedType ::
    ArrayBuffer
    SharedArrayBuffer
    DataView
    Int8Array
    Int16Array
    Int32Array
    Uint8Array
    Uint16Array
    Uint32Array
    Uint8ClampedArray
    BigInt64Array
    BigUint64Array
    Float16Array
    Float32Array
    Float64Array

ExtendedAttributeList ::
    [ ExtendedAttribute ExtendedAttributes ]
    ε

ExtendedAttributes ::
    , ExtendedAttribute ExtendedAttributes
    ε

ExtendedAttribute ::
    ( ExtendedAttributeInner ) ExtendedAttributeRest
    [ ExtendedAttributeInner ] ExtendedAttributeRest
    { ExtendedAttributeInner } ExtendedAttributeRest
    Other ExtendedAttributeRest

ExtendedAttributeRest ::
    ExtendedAttribute
    ε

ExtendedAttributeInner ::
    ( ExtendedAttributeInner ) ExtendedAttributeInner
    [ ExtendedAttributeInner ] ExtendedAttributeInner
    { ExtendedAttributeInner } ExtendedAttributeInner
    OtherOrComma ExtendedAttributeInner
    ε

Other ::
    integer
    decimal
    identifier
    string
    other
    -
    -Infinity
    .
    ...
    :
    ;
    <
    =
    >
    ?
    *
    ByteString
    DOMString
    FrozenArray
    Infinity
    NaN
    ObservableArray
    Promise
    USVString
    any
    bigint
    boolean
    byte
    double
    false
    float
    long
    null
    object
    octet
    or
    optional
    record
    sequence
    short
    symbol
    true
    unsigned
    undefined
    ArgumentNameKeyword
    BufferRelatedType

OtherOrComma ::
    Other
    ,

IdentifierList ::
    identifier Identifiers

Identifiers ::
    , identifier Identifiers
    ε

IntegerList ::
    integer Integers

Integers ::
    , integer Integers
    ε

ExtendedAttributeNoArgs ::
    identifier

ExtendedAttributeArgList ::
    identifier ( ArgumentList )

ExtendedAttributeIdent ::
    identifier = identifier

ExtendedAttributeString ::
    identifier = string

ExtendedAttributeInteger ::
    identifier = integer

ExtendedAttributeDecimal ::
    identifier = decimal

ExtendedAttributeWildcard ::
    identifier = *

ExtendedAttributeIdentList ::
    identifier = ( IdentifierList )

ExtendedAttributeIntegerList ::
    identifier = ( IntegerList )

ExtendedAttributeNamedArgList ::
    identifier = identifier ( ArgumentList )
```

Note: The Other non-terminal matches any single terminal symbol except for (, ), \[, \], {, } and ,.

While the ExtendedAttribute non-terminal matches any non-empty sequence of terminal symbols (as long as any parentheses, square brackets or braces are balanced, and the , token appears only within those balanced brackets), only a subset of those possible sequences are used by the extended attributes defined in this specification --- see § 2.14 Extended attributes for the syntaxes that are used by these extended attributes.


## Document conventions

The following typographic conventions are used in this document:

- Defining instances of terms: example term

- Links to terms defined in this document or elsewhere: example term

- Grammar terminals: sometoken

- Grammar non-terminals: ExampleGrammarNonTerminal

- Grammar symbols: identifier

- IDL types: `unsigned long`

- JavaScript classes: `Map`

- JavaScript language types: Object

- Code snippets: `a = b + obj.f()`

- Scalar values: U+0030 (0)

- Extended attributes: \[`ExampleExtendedAttribute`\]

- Variable names in prose and algorithms: `exampleVariableName`.

- IDL informal syntax examples:

  ```
  [extended_attributes]
  interface identifier {
    /* interface_members... */
  };
  ```

  (Specific parts of the syntax discussed in surrounding prose are highlighted.)

- IDL grammar snippets:

  ```
  ExampleGrammarNonTerminal ::
      OtherNonTerminal sometoken
      other AnotherNonTerminal
      ε  // nothing
  ```

- Non-normative notes:

  Note: This is a note.

- Non-normative examples:

  This is an example.

- Normative warnings:

  This is a warning.

- Code blocks:

  ```
  // This is an IDL code block.
  [Exposed=Window]
  interface Example {
    attribute long something;
  };
  ```

  ```
  // This is a JavaScript code block.
  window.onload = function() { window.alert("loaded"); };
  ```

The following conventions are used in the algorithms in this document:

- Algorithms use the conventions of the JavaScript specification, including the ! and ? notation for unwrapping Completion Records.

- Algorithms sometimes treat returning/throwing values and returning Completion Records interchangeably. That is, an algorithm that uses return/throw terminology may be treated as returning a Completion Record, while one that returns a Completion Record may be treated as returning a value or throwing an exception. Similarly, to catch exceptions, defining the behavior to adopt when an exception was thrown and checking if the Completion Record's \[\[Type\]\] field is "throw" are equivalent.

- Completion Records are extended by allowing them to contain values that are not JavaScript values, such as Web IDL values.


## Conformance

Everything in this specification is normative except for diagrams, examples, notes and sections marked as being informative.

This specification depends on the Infra Standard. [INFRA]

The following conformance classes are defined by this specification:

conforming set of IDL fragments

:   A set of IDL fragments is considered to be a conforming set of IDL fragments if, taken together, they satisfy all of the must-, required- and shall-level criteria in this specification that apply to IDL fragments.

conforming implementation

:   A user agent is considered to be a conforming implementation relative to a conforming set of IDL fragments if it satisfies all of the must-, required- and shall-level criteria in this specification that apply to implementations for all language bindings that the user agent supports.

conforming JavaScript implementation

:   A user agent is considered to be a conforming JavaScript implementation relative to a conforming set of IDL fragments if it satisfies all of the must-, required- and shall-level criteria in this specification that apply to implementations for the JavaScript language binding.
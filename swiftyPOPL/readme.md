# SwiftyPOPL: A Swift-style Protocol-Oriented Programming Language

**Author:** Runbang Yan  
**Institution:** School of Computer Science, Peking University

SwiftyPOPL is a small Swift-like language for studying protocol-oriented programming through typed elaboration. The implemented compiler front end parses a Swift-style surface language, resolves nominal declarations, type checks protocols and generics, elaborates programs into a core calculus, and then reuses the core parser/typechecker/evaluator to run the generated program.

The project focuses on the type-theoretic core of Swift-style protocols:

- protocol declarations as method interfaces
- extension-based conformances as dictionary evidence
- constrained generics as explicit dictionary-passing functions
- first-class polymorphic function values
- boxed protocol values written as `any P`
- existential-safe method calls on `any P`

## Project Layout

```text
src/
  interpreter.mbt                    # end-to-end surface interpreter entry point
  core/                              # TAPL-style core calculus
    syntax.mbt                       # core syntax, contexts, shifting/substitution
    core.mbt                         # core evaluator and typechecker
    parser.mbty / lexer.mbtx         # core grammar and lexer sources
    main.mbt                         # standalone core interpreter
  surface/parser/
    syntax/                          # surface AST, lexer, parser, diagnostics
    resolver/                        # pass 1: nominal type resolution and method normalization
    checker/                         # pass 2: type checking and conformance checking
    elaborator/                      # pass 3: dictionary/existential elaboration to core syntax
  surface/theory/main.tex            # course paper

examples/                            # complete end-to-end example programs
test/should_pass/                    # accepted regression examples
test/should_fail/                    # rejected regression examples
beamer/                              # presentation slides
docs/                                # implementation notes for individual passes
```

Generated parser/lexer files such as `parser.mbt` and `lexer.mbt` are produced from the `.mbty` and `.mbtx` sources by MoonBit pre-build commands.

## Implemented Surface Language

The current surface language supports:

- `Int`, `Bool`, `String`, and `Unit`
- `struct` declarations with fields and methods
- `protocol` declarations with method requirements
- `extension S: P` conformance declarations
- Swift-style external argument labels
- generic functions and generic methods
- constrained type parameters such as `<T: P>` and `<T: P & Q>`
- explicit generic instantiation such as `f<Int>(x: 1)`
- first-class polymorphic function values and polymorphic function fields
- `any P` existential protocol values
- casts of the form `e as any P`
- method calls and method-value selection on existential values when the visible signature does not mention protocol `Self`
- `if` / `if-else`
- integer operators `+`, `-`, `<`, `>`, `<=`, `>=`
- Boolean operators `!`, `&&`, `||`

Important restrictions:

- generic type arguments must be explicit; there is no implicit generic inference
- `any P` does not itself satisfy `P`; methods on existentials are handled by generated unpacking
- existential method selection is rejected if visible parameters or results mention protocol `Self`
- there is no surface-level explicit existential unpack
- there are no associated types, classes, enums, mutation, inheritance, modules, overload resolution, or protocol extensions with default implementations
- surface `Int` elaborates to core `Nat`, so subtraction is saturating (`0 - 1` evaluates to `0`)
- string concatenation is not implemented
- user-defined recursion is not part of the surface fragment

## Compilation Pipeline

Running a surface program uses this pipeline:

```text
surface source
  -> surface lexer/parser
  -> resolver
  -> checker
  -> typed AST
  -> elaborator
  -> core concrete syntax
  -> core parser/typechecker/evaluator
```

The passes have the following responsibilities:

- `syntax`: tokenizes and parses the Swift-like surface syntax into an AST.
- `resolver`: collects nominal type names, resolves `Self`, distinguishes structs/protocols/type variables, and turns methods into receiver-first functions.
- `checker`: checks values, calls, labels, generic constraints, protocol conformances, member access, and existential safety.
- `elaborator`: emits readable core syntax using dictionary passing and existential packages.
- `core`: typechecks and evaluates the elaborated core program.

## Running Programs

Install the MoonBit toolchain first. From the project root, check that the project builds:

```bash
moon check
```

Run a complete SwiftyPOPL program with the end-to-end interpreter:

```bash
moon run src -- examples/table_view_delegate.swift
```

The interpreter prints generated core bindings and evaluated results with their core types. For example:

```bash
moon run src -- examples/first_class_polymorphic_identity.swift
moon run src -- examples/ios_settings_screen.swift
```

Run an accepted regression example:

```bash
moon run src -- test/should_pass/struct_basic.swift
moon run src -- test/should_pass/existential_generic_method.swift
```

Run a rejected regression example and expect an error message:

```bash
moon run src -- test/should_fail/existential_self_method_rejected.swift
moon run src -- test/should_fail/existential_missing_conformance.swift
```

The debugging front-end prints the typed surface program and generated core syntax without evaluating it:

```bash
moon run src/surface/parser -- examples/table_view_delegate.swift
```

The standalone core interpreter can run core programs directly:

```bash
moon run src/core -- src/core/test.f
```

## Examples

The `examples/` directory contains seven complete programs:

- `table_view_delegate.swift`: existential table-view delegate object
- `table_view_height_delegate.swift`: existential row-height callback
- `existential_callback_delegate.swift`: existential callback returning `Bool`
- `ios_settings_screen.swift`: larger iOS-style example with existential delegates, constrained generics, and a polymorphic function field
- `first_class_polymorphic_identity.swift`: polymorphic function stored in a top-level value
- `first_class_polymorphic_struct_field.swift`: polymorphic function stored in a struct field
- `constrained_polymorphic_protocol.swift`: constrained generic function and dictionary passing

## Tests

The test files are organized as simple source-level regression examples:

- `test/should_pass/`: programs that should parse, typecheck, elaborate, core-check, and evaluate
- `test/should_fail/`: programs that should be rejected by the resolver or checker

Representative positive cases cover:

- struct construction and field access
- Swift-style labels
- extension methods
- protocol conformance
- generic type variables and constrained generic calls
- first-class polymorphic method values
- existential packaging and existential method calls
- integer and Boolean operator elaboration
- local variable shadowing

Representative negative cases cover:

- duplicate top-level declarations
- missing protocol methods
- missing conformance evidence for `as any P`
- unsafe existential methods whose visible signature mentions `Self`
- label mismatches
- unsupported string concatenation
- variables used outside their scope

## Formalization

The paper in `src/surface/theory/main.tex` describes:

- the surface syntax
- the surface type system
- protocol satisfaction and evidence
- elaboration to a core calculus
- dictionary translation for protocols
- existential encoding for `any P`
- preservation of typing from surface elaboration to core typing

The proof relies on the standard soundness theorem for the core calculus and focuses on showing that well-typed surface programs elaborate to well-typed core programs.

## Implementation Status

The current implementation is complete for the formalized fragment described above. It is intentionally not a full Swift model. The implementation is designed for the TAPL course project goal: making the static meaning of protocol-oriented programming explicit through a small typed language and a dictionary/existential elaboration.

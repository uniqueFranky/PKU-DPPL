# miniPOPL: A Minimal Protocol-Oriented Programming Language

**Subtitle:** Distilling Swift's Associated Types to Their Type-Theoretic Essence

---

## 1. Introduction

**miniPOPL** (Minimal Protocol-Oriented Programming Language) is a statically-typed 
functional language that extends System F with Swift-style protocols and associated 
types. Following the tradition of pedagogical languages like miniJava, miniML, and 
miniKanren, miniPOPL strips away syntactic sugar and runtime complexity to expose 
the **core type-theoretic mechanisms** that make protocol-oriented programming possible.

### 1.1 Design Philosophy: Minimalism with Purpose

The "mini" in miniPOPL reflects three principles:

1. **Minimal syntax**: No classes, no inheritance, no subtyping—only protocols, 
   implementations, and functions.

2. **Minimal runtime**: Everything compiles to pure System F via dictionary passing. 
   No virtual dispatch, no reflection, no dynamic features.

3. **Minimal but complete**: Despite its simplicity, miniPOPL can express realistic 
   protocol-oriented patterns like the `Graph` abstraction with multiple associated types.

### 1.2 Motivation: The Type Parameter Explosion Problem

Consider modeling a graph abstraction. In languages without associated types, 
all internal types must be exposed as parameters:

```swift
// Without associated types: verbose and leaky
protocol Graph<Vertex, Edge> {
    func addEdge(u: Vertex, v: Vertex, e: Edge) -> Void
    func neighbors(v: Vertex) -> List<Vertex>
}

// Every function must carry V and E explicitly
func bfs<V, E, G: Graph<V, E>>(graph: G, start: V) -> List<V> {
    // Implementation details of G leak into the signature
    ...
}
```

**The problem:** Clients must know about `Vertex` and `Edge` even when these are 
implementation details. This violates encapsulation and creates "type parameter 
explosion" in complex abstractions.

**miniPOPL's solution (via associated types):**

```swift
// With associated types: clean and encapsulated
protocol Graph {
    associatedtype Vertex
    associatedtype Edge
    func addEdge(u: Vertex, v: Vertex, e: Edge) -> Void
    func neighbors(v: Vertex) -> List<Vertex>
}

// Clean signature: internal types are hidden
func bfs<G: Graph>(graph: G, start: G.Vertex) -> List<G.Vertex> {
    // G.Vertex is a type projection—no leaky parameters
    ...
}
```

Associated types enable **type-level encapsulation**: protocols declare type members 
that are determined by the implementer, not the caller.

---

## 2. Language Overview

### 2.1 Core Features

miniPOPL supports exactly three constructs for protocol-oriented programming:

#### Feature 1: Protocol Declaration

```swift
protocol Container {
    associatedtype Item
    func add(self, item: Item) -> Void
    func get(self) -> Item
}
```

Protocols can declare multiple associated types:

```swift
protocol Graph {
    associatedtype Vertex
    associatedtype Edge
    func addEdge(self, u: Vertex, v: Vertex, e: Edge) -> Void
    func neighbors(self, v: Vertex) -> List<Vertex>
}
```

#### Feature 2: Protocol Implementation

```swift
struct IntStack {
    data: List<Int>
}

impl Container for IntStack {
    type Item = Int  // Bind associated type to concrete type
    
    func add(self, item: Int) -> Void {
        self.data = Cons(item, self.data)
    }
    
    func get(self) -> Int {
        match self.data {
            Cons(x, _) => x
            Nil => error("empty stack")
        }
    }
}
```

#### Feature 3: Type Projections in Generic Code

```swift
func duplicate<C: Container>(c: C, item: C.Item) -> Void {
    c.add(item)
    c.add(item)  // C.Item is used as a first-class type
}
```

The notation `C.Item` is a **type projection**: it extracts the associated type 
`Item` from the concrete implementation of `C`.

### 2.2 Complete Example: Generic Graph Algorithms

```swift
// Protocol definition
protocol Graph {
    associatedtype Vertex
    associatedtype Edge
    func addEdge(self, u: Vertex, v: Vertex, e: Edge) -> Void
    func neighbors(self, v: Vertex) -> List<Vertex>
}

// Concrete implementation: city map
struct CityMap {
    adjacency: Map<String, List<(String, Int)>>
}

impl Graph for CityMap {
    type Vertex = String
    type Edge = Int
    
    func addEdge(self, u: String, v: String, distance: Int) -> Void {
        let neighbors = Map.get(self.adjacency, u)
        let updated = Cons((v, distance), neighbors)
        self.adjacency = Map.set(self.adjacency, u, updated)
    }
    
    func neighbors(self, city: String) -> List<String> {
        let edges = Map.get(self.adjacency, city)
        List.map(edges, lambda (pair) -> fst(pair))
    }
}

// Generic BFS that works with any Graph implementation
func bfs<G: Graph>(graph: G, start: G.Vertex) -> List<G.Vertex> 
    where G.Vertex: Eq  // Stretch goal: type equality constraints
{
    var visited: Set<G.Vertex> = Set.empty()
    var queue: Queue<G.Vertex> = Queue.singleton(start)
    var result: List<G.Vertex> = Nil
    
    while !Queue.isEmpty(queue) {
        let (v, rest) = Queue.dequeue(queue)
        queue = rest
        
        if !Set.contains(visited, v) {
            visited = Set.insert(visited, v)
            result = Cons(v, result)
            
            let ns = graph.neighbors(v)
            queue = Queue.enqueueAll(queue, ns)
        }
    }
    
    return List.reverse(result)
}

// Usage: types are inferred
let map = CityMap { adjacency = Map.empty() }
let reachable = bfs(map, "Beijing")  // Type: List<String>
```

---

## 3. Formal Semantics

### 3.1 Syntax

miniPOPL extends System F with the following constructs:

$$
\begin{align}
\text{Types} \quad \tau ::= &\ X \mid \tau_1 \to \tau_2 \mid \forall X. \tau \mid T.A \mid \text{Int} \mid \text{Bool} \\
\text{Terms} \quad e ::= &\ x \mid \lambda x{:}\tau. e \mid e_1\ e_2 \mid \Lambda X. e \mid e[\tau] \\
&\ | \text{ let } x = e_1 \text{ in } e_2 \mid n \mid \text{true} \mid \text{false} \\
\text{Protocols} \quad P ::= &\ \text{protocol } P \{ \overline{\text{associatedtype } A}; \overline{m} \} \\
\text{Impls} \quad I ::= &\ \text{impl } P \text{ for } T \{ \overline{\text{type } A = \tau}; \overline{f} \} \\
\text{Decls} \quad D ::= &\ P \mid I \mid \text{func } f \langle \overline{X{:}P} \rangle (\overline{x{:}\tau}) \to \tau = e
\end{align}
$$

### 3.2 Type System

miniPOPL's type system extends System F with two key judgments:

#### Judgment 1: Protocol Conformance
$$
\Gamma \vdash T : P
$$
"Type $T$ implements protocol $P$"

**Rule:**
$$
\frac{(\text{impl } P \text{ for } T \{ \ldots \}) \in \Gamma}
     {\Gamma \vdash T : P}
$$

#### Judgment 2: Type Projection
$$
\Gamma \vdash T.A \equiv \tau
$$
"In context $\Gamma$, the type projection $T.A$ resolves to concrete type $\tau$"

**Rule:**
$$
\frac{\Gamma \vdash T : P \quad A \in \text{assoc}(P) \quad (\text{impl } P \text{ for } T \{ \text{type } A = \tau; \ldots \}) \in \Gamma}
     {\Gamma \vdash T.A \equiv \tau}
$$

#### Key Typing Rule: Generic Functions with Protocol Constraints

$$
\frac{\Gamma, X, X{:}P \vdash e : \tau}
     {\Gamma \vdash \Lambda X{:}P. e : \forall X{:}P. \tau}
$$

When checking the body $e$, the context knows that $X$ implements $P$, so:
- Methods of $P$ can be called on values of type $X$
- Associated types can be accessed via projections like $X.A$

### 3.3 Translation to System F (Dictionary Passing)

miniPOPL compiles to pure System F using the **dictionary-passing translation**. 
This is the key technical contribution: proving that protocol-oriented programming 
requires no special runtime support.

#### Step 1: Protocols → Dictionary Types

A protocol with associated types becomes a record type parameterized by those types:

```
protocol Container {
    associatedtype Item
    func add(self, item: Item) -> Void
    func get(self) -> Item
}

⟦Container⟧ = ∀Self. ∀Item. {
    add : Self → Item → Void,
    get : Self → Item
}
```

#### Step 2: Implementations → Dictionary Values

An implementation becomes a concrete dictionary value:

```
impl Container for IntStack {
    type Item = Int
    func add(self, item: Int) -> Void { ... }
    func get(self) -> Int { ... }
}

⟦impl Container for IntStack⟧ = 
    ΛSelf. ΛItem. {
        add = λs:Self. λi:Item. ⟦...⟧,
        get = λs:Self. ⟦...⟧
    }
```

#### Step 3: Generic Functions → Dictionary Parameters

A function with protocol constraints receives extra dictionary parameters:

```
func duplicate<C: Container>(c: C, item: C.Item) -> Void {
    c.add(item)
    c.add(item)
}

⟦duplicate⟧ = 
    ΛC. ΛItem. λ(dict: ⟦Container⟧ C Item). λ(c: C). λ(item: Item).
        let add = dict.add in
        (add c item); (add c item)
```

#### Step 4: Type Projections → Type Parameters

When the source code writes `C.Item`, the translation introduces a fresh type 
variable and threads it through the dictionary:

```
// Source: C.Item appears in the signature
func process<C: Container>(c: C, item: C.Item) -> C.Item

// Translation: Item becomes an explicit type parameter
⟦process⟧ = ΛC. ΛItem. λ(dict: ⟦Container⟧ C Item). λ(c: C). λ(item: Item). ...
```

### 3.4 Type Soundness

**Theorem (Type Preservation):**
If $\vdash e : \tau$ in miniPOPL, then $\vdash \llbracket e \rrbracket : \llbracket \tau \rrbracket$ 
in System F.

**Proof Sketch:**
By structural induction on the typing derivation. The key cases are:

1. **Protocol method call**: When miniPOPL types `c.add(item)` where `c: C` and 
   `C: Container`, the translation extracts the `add` method from the dictionary 
   and applies it. Since the dictionary has type `⟦Container⟧ C Item`, the method 
   has type `C → Item → Void`, which matches the call site.

2. **Type projection**: When miniPOPL types `x: C.Item`, the translation replaces 
   `C.Item` with the concrete type `τ` bound in the implementation. The dictionary 
   ensures all methods operate on this concrete type.

3. **Generic instantiation**: When calling `duplicate(myStack, 42)`, the translation 
   instantiates the type parameters `C` and `Item` and passes the appropriate 
   dictionary `⟦impl Container for IntStack⟧`.

**Corollary (Progress):**
Well-typed miniPOPL programs don't get stuck (assuming the System F translation 
has progress).

---

## 4. Implementation Plan

### Phase 1: Foundation (Week 1-2)
**Goal:** Extend System F with basic protocols (no associated types yet)

**Tasks:**
- Extend the parser to recognize `protocol` and `impl` syntax
- Add an **instance environment** to the type checker:
  ```
  InstanceEnv = Map<(Type, Protocol), ImplBlock>
  ```
- Implement type checking for protocol constraints: `<T: Protocol>`
- Implement dictionary-passing translation for protocols without associated types

**Deliverable:** This program should compile and run:
```swift
protocol Showable {
    func show(self) -> String
}

impl Showable for Int {
    func show(self) -> String { intToString(self) }
}

func display<T: Showable>(x: T) -> Void {
    print(x.show())
}

let main = display(42)  // Prints "42"
```

**Test Strategy:**
- Unit tests for parser (protocol/impl blocks)
- Unit tests for instance environment lookup
- Integration test: compile and run the above program

---

### Phase 2: Associated Types (Week 3-4)
**Goal:** Add `associatedtype` and type projections

**Tasks:**
- Extend AST with `AssociatedType` nodes
- Implement **type projection resolution**: when checking `T.Item`, look up the 
  implementation of `T` to find the binding `type Item = τ`
- Extend dictionary translation to include type parameters for associated types
- Update the type checker to handle `C.Item` as a first-class type

**Algorithm: Type Projection Resolution**
```
resolve(Γ, T, A):
    1. Find protocol P such that (T: P) ∈ Γ and A ∈ assoc(P)
    2. Look up (impl P for T { type A = τ; ... }) in Γ
    3. Return τ
    4. If not found, raise "unresolved type projection T.A"
```

**Deliverable:** The `Container` example from Section 2.1 should work:
```swift
protocol Container {
    associatedtype Item
    func add(self, item: Item) -> Void
    func get(self) -> Item
}

struct IntStack { ... }
impl Container for IntStack {
    type Item = Int
    ...
}

func duplicate<C: Container>(c: C, item: C.Item) -> Void {
    c.add(item)
    c.add(item)
}
```

**Test Strategy:**
- Unit tests for type projection resolution
- Test error messages for unresolved projections
- Integration test: compile and run `duplicate`

---

### Phase 3: Multiple Associated Types (Week 5)
**Goal:** Support protocols with multiple associated types (e.g., `Graph`)

**Tasks:**
- Extend the resolution algorithm to handle multiple projections
- Implement the `Graph` example with `Vertex` and `Edge`
- Add comprehensive test suite covering:
  - Multiple associated types in one protocol
  - Multiple protocol constraints on one type parameter
  - Type projections in function return types

**Deliverable:** The `Graph` example from Section 2.2 should work.

**Test Strategy:**
- Test `Graph` with different implementations (adjacency list, adjacency matrix)
- Test `bfs` with different vertex types (String, Int, custom structs)
- Stress test: protocol with 3+ associated types

---

### Phase 4 (Stretch Goal): Type Equality Constraints
**Goal:** Support `where T.Item == Int` constraints

**Tasks:**
- Implement a **type normalization environment** that tracks equalities
- Add constraint solving for type equality
- This requires significant additional complexity (inspired by System $F_C$)

**Note:** This is explicitly optional. If time is limited, focus on Phases 1-3.

---

## 5. Technical Challenges

### 5.1 Challenge: Type Projection Resolution

**Problem:** When the type checker encounters `T.Item`, it must:
1. Determine which protocol `P` declares `Item`
2. Find the implementation of `P` for `T`
3. Extract the binding `type Item = τ`
4. Substitute `τ` for `T.Item` everywhere

**Solution:** Maintain an **instance environment** during type checking:
```
Γ_impl : Map<(Type, Protocol), Map<AssocTypeName, Type>>
```

Example:
```
Γ_impl[( IntStack, Container )] = { Item ↦ Int }
```

When checking `C.Item`:
```
resolve(Γ, C, Item) = 
    let P = findProtocol(Γ, C, hasAssocType(Item)) in
    Γ_impl[(C, P)][Item]
```

**Edge Case:** What if `C` implements multiple protocols that declare `Item`?
- **Solution:** Require explicit disambiguation: `C as Container.Item`
- **For miniPOPL:** Disallow this case (keep it simple)

### 5.2 Challenge: Dictionary Generation

**Problem:** For each `impl` block, we must generate a System F record value.

**Solution:** During translation, maintain a global dictionary map:
```
Dicts : Map<(Type, Protocol), SystemF.Term>
```

When translating `impl Container for IntStack { ... }`:
```
Dicts[(IntStack, Container)] = 
    ΛSelf. ΛItem. {
        add = λs:Self. λi:Item. ⟦...⟧,
        get = λs:Self. ⟦...⟧
    }
```

When translating a call to `duplicate(myStack, 42)`:
```
duplicate [IntStack] [Int] Dicts[(IntStack, Container)] myStack 42
```

**Optimization (stretch goal):** Cache dictionary lookups to avoid redundant 
instantiations.

### 5.3 Challenge: Soundness Proof

**Problem:** Proving that the translation preserves typing.

**Approach:**
1. Define a **logical relation** between miniPOPL types and System F types:
   ```
   ⟦T.A⟧ = τ  where (impl P for T { type A = τ }) ∈ Γ
   ```

2. Prove **type preservation** by induction on typing derivations:
   ```
   If Γ ⊢ e : τ in miniPOPL, then ⟦Γ⟧ ⊢ ⟦e⟧ : ⟦τ⟧ in System F
   ```

3. Key lemma: **Dictionary well-typedness**
   ```
   If (impl P for T { ... }) is well-formed, 
   then Dicts[(T, P)] : ⟦P⟧ T ⟦T.A₁⟧ ... ⟦T.Aₙ⟧
   ```

**For the project:** A detailed proof sketch (2-3 pages) is sufficient. Full 
mechanization in Coq/Agda is out of scope.

---

## 6. Evaluation Criteria

The project will be considered successful if:

✅ **Correctness:** All examples in Section 2 type-check and translate correctly

✅ **Expressiveness:** The language can encode realistic protocol-oriented patterns 
(e.g., `Container`, `Graph`, `Iterator`)

✅ **Soundness:** A formal argument demonstrates type preservation under translation

✅ **Code Quality:** 
- Clean separation between parser, type checker, and translator
- Comprehensive test suite (unit + integration tests)
- Well-documented code with examples

✅ **Documentation:**
- Final report explaining design decisions
- User guide with example programs
- Comparison with Swift/Rust/Haskell

---

## 7. Related Work

### 7.1 Pedagogical Languages
- **miniJava** (Appel): A subset of Java for teaching compilers
- **miniML** (Harper): A minimal ML for teaching type theory
- **miniKanren** (Friedman): A minimal logic programming language

miniPOPL follows this tradition: strip away complexity to expose core ideas.

### 7.2 Associated Types in Other Languages

| Language | Feature | Syntax | Notes |
|----------|---------|--------|-------|
| **Swift** | Associated types | `associatedtype Item` | Our primary inspiration |
| **Rust** | Associated types | `type Item;` | Similar, but no higher-rank types |
| **Haskell** | Type families | `type family Item c` | More powerful but complex |
| **Scala** | Type members | `type Item` | Supports path-dependent types |

### 7.3 Theoretical Foundations
- **System F** (Girard, Reynolds): Our compilation target
- **System $F_C$** (Weirich et al.): Extends F with type equality coercions
- **Type Classes** (Wadler & Blott): The original dictionary-passing paper
- **ML Modules** (MacQueen): Abstract types in a module system

---

## 8. Timeline

| Week | Phase | Milestone | Deliverable |
|------|-------|-----------|-------------|
| 1-2  | Phase 1 | Basic protocols | Protocols without associated types work |
| 3-4  | Phase 2 | Associated types | `Container` example works |
| 5    | Phase 3 | Multiple assoc types | `Graph` example works |
| 6    | Testing & docs | Final polish | Report + presentation + demo |

---

## 9. Success Metrics

### Minimum Viable Product (MVP):
- ✅ Phases 1-2 complete
- ✅ `Container` example works end-to-end
- ✅ Basic soundness argument

### Target Goal:
- ✅ Phases 1-3 complete
- ✅ `Graph` example works end-to-end
- ✅ Detailed soundness proof sketch
- ✅ Comprehensive test suite

### Stretch Goals:
- ✅ Phase 4 (type equality constraints)
- ✅ Multiple protocol constraints (`<T: P1 + P2>`)
- ✅ Protocol inheritance (`protocol Eq: Comparable`)

---

## 10. References

[1] Apple Inc. "The Swift Programming Language: Protocols"  
    https://docs.swift.org/swift-book/LanguageGuide/Protocols.html

[2] Wadler, P., & Blott, S. (1989). "How to make ad-hoc polymorphism less ad hoc"  
    *POPL '89*

[3] Chakravarty, M., et al. (2005). "Associated Types with Class"  
    *POPL '05*

[4] Weirich, S., et al. (2011). "System FC with Explicit Kind Equality"  
    *ICFP '11*

[5] Pierce, B. C. (2002). *Types and Programming Languages*  
    MIT Press (Chapter 23: Universal Types)

[6] Appel, A. W. (1998). *Modern Compiler Implementation in ML*  
    Cambridge University Press (miniJava reference)

---

## Appendix A: Complete Grammar

```
Program    ::= Decl*

Decl       ::= ProtocolDecl | ImplDecl | FuncDecl | StructDecl

ProtocolDecl ::= 'protocol' ID '{' AssocType* MethodSig* '}'
AssocType    ::= 'associatedtype' ID
MethodSig    ::= 'func' ID '(' 'self' (',' Param)* ')' '->' Type

ImplDecl   ::= 'impl' ID 'for' Type '{' TypeBinding* FuncDecl* '}'
TypeBinding ::= 'type' ID '=' Type

FuncDecl   ::= 'func' ID TypeParams? '(' Params ')' '->' Type '=' Expr
TypeParams ::= '<' (ID ':' ID),+ '>'
Params     ::= (ID ':' Type),*

StructDecl ::= 'struct' ID '{' (ID ':' Type),* '}'

Type       ::= ID                    // Base type or type variable
             | Type '->' Type        // Function type
             | Type '.' ID           // Type projection
             | 'List' '<' Type '>'   // Built-in list type
             | '(' Type ')'          // Parenthesized type

Expr       ::= ID | Literal
             | Expr '(' Args ')'              // Function call
             | Expr '.' ID '(' Args ')'       // Method call
             | 'lambda' '(' Params ')' '->' Expr
             | 'let' ID '=' Expr 'in' Expr
             | 'match' Expr '{' (Pattern '=>' Expr),+ '}'

Pattern    ::= ID | ID '(' (Pattern),* ')'

Args       ::= (Expr),*
Literal    ::= Integer | 'true' | 'false' | String
```

---

## Appendix B: Example Programs

### Example 1: Stack with Container Protocol
```swift
protocol Container {
    associatedtype Item
    func add(self, item: Item) -> Void
    func get(self) -> Item
    func isEmpty(self) -> Bool
}

struct Stack {
    data: List<Int>
}

impl Container for Stack {
    type Item = Int
    
    func add(self, item: Int) -> Void {
        self.data = Cons(item, self.data)
    }
    
    func get(self) -> Int {
        match self.data {
            Cons(x, rest) => {
                self.data = rest
                return x
            }
            Nil => error("empty stack")
        }
    }
    
    func isEmpty(self) -> Bool {
        match self.data {
            Nil => true
            _ => false
        }
    }
}

func sumContainer<C: Container>(c: C) -> C.Item 
    where C.Item == Int  // Stretch goal
{
    var sum = 0
    while !c.isEmpty() {
        sum = sum + c.get()
    }
    return sum
}
```

### Example 2: Graph with BFS
```swift
protocol Graph {
    associatedtype Vertex
    associatedtype Edge
    func neighbors(self, v: Vertex) -> List<Vertex>
}

struct AdjList {
    adj: Map<Int, List<Int>>
}

impl Graph for AdjList {
    type Vertex = Int
    type Edge = Unit
    
    func neighbors(self, v: Int) -> List<Int> {
        Map.getOrDefault(self.adj, v, Nil)
    }
}

func bfs<G: Graph>(graph: G, start: G.Vertex) -> List<G.Vertex> {
    // ... BFS implementation using G.Vertex abstractly
}
```



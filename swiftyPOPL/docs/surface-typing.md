# Surface Typing 设计说明

本文档记录 `src/surface/theory/typing.tex` 的重写思路、类型系统结构，以及后续形式化证明应如何展开。

目标是给 SwiftyPOPL 的 surface language 一个可以支撑证明的类型系统，而不是只描述实现里的 checker 行为。因此该系统刻意采用推导规则形式，并把 source 层概念和后续 IR/core 层概念分开。

## 1. 设计目标

Surface 类型系统服务三个目的：

1. 精确定义用户语言中哪些程序是 well-typed。
2. 为 `TypedAST -> IR` 的 elaboration 提供证明目标。
3. 支撑最终结论：well-typed surface program elaborates to well-typed core program，因此不会在 core 执行时 stuck。

该系统不直接证明 surface operational safety，因为 surface language 暂时不需要自己的运行语义。真正的 progress/preservation 建议只在 core calculus 上证明。

证明链条如下：

```text
Surface well-typed
  => elaboration preserves typing
  => IR well-typed
  => lowering preserves typing
  => Core well-typed
  => Core progress + preservation
```

## 2. 文件位置

主要形式化文件：

- `src/surface/theory/typing.tex`

该文件已完全重写，不依赖之前的 `typing.tex` 内容。

编译检查命令：

```bash
cd src/surface/theory
pdflatex -interaction=nonstopmode typing.tex
```

当前能正常生成 PDF。剩余警告主要来自 `acmart` 模板要求 keywords/CCS，以及少量排版 underfull warning。

## 3. Surface 语法范围

`typing.tex` 中定义的 surface syntax 覆盖：

- 基础类型：`Int`、`Bool`、`String`、`Unit`
- nominal struct type：`S`
- type variable：`X`
- contextual `Self`
- existential protocol type：`any P`
- function scheme：

```text
forall X_i : P_i. (label_j : tau_j) -> tau
```

表达式覆盖：

- literals
- variables
- `self`
- function value
- function call
- explicit generic instantiation
- member access
- struct construction
- `if-else`
- `e as any P`

声明覆盖：

- `let`
- top-level `func`
- `struct`
- `protocol`
- `extension S : P`

注意：实现当前还没有完整解析/检查 `any P`，但类型系统中保留它，因为这是项目目标里 existential abstraction 的 surface 构造。

## 4. 环境设计

类型系统使用四类环境。

### 4.1 Global Environment `Psi`

`Psi` 是全局环境，拆成五个有限映射：

```text
Psi = (Psi_S, Psi_P, Psi_C, Psi_M, Psi_V)
```

含义：

```text
Psi_S(S)     = fields of struct S
Psi_P(P)     = method requirements of protocol P
Psi_C(S, P)  = methods implementing extension S : P
Psi_M(S)     = methods available on struct S
Psi_V(x)     = top-level value/function type
```

这和实现中的 `build_env` 思路一致，但形式化里显式拆开，便于证明。

### 4.2 Generic Constraint Context `Omega`

`Omega` 记录当前作用域中的类型变量及协议约束：

```text
Omega ::= . | Omega, X : P1 ... Pn
```

例如：

```swift
func f<T: Show & Eq>(x: T) -> String
```

会在函数体内产生：

```text
Omega(T) = {Show, Eq}
```

### 4.3 Local Value Context `Gamma`

`Gamma` 记录局部值变量：

```text
Gamma ::= . | Gamma, x : tau
```

函数参数、局部 `let`、方法中的 `self` 都进入 `Gamma`。

### 4.4 Self Resolver `rho`

`rho` 记录当前 `Self` 的解析上下文：

```text
rho ::= bottom | S | P
```

含义：

- `bottom`：顶层，不能使用 `Self`
- `S`：struct/extension 作用域，`Self` 解析为具体 struct `S`
- `P`：protocol 作用域，`Self` 保持为抽象 receiver type

这个设计对应当前 resolver 中的：

- `StructOwner(name)`
- `ExtensionOwner(name)`
- `ProtocolOwner(name)`

## 5. 类型良构

`typing.tex` 中的类型良构 judgment：

```text
Psi; Omega; rho |- tau ok
```

核心规则：

- base types always ok
- struct type `S` 要求 `S in dom(Psi_S)`
- type variable `X` 要求 `X in dom(Omega)`
- `Self` 要求 `rho != bottom`
- `any P` 要求 `P in dom(Psi_P)`
- function scheme 会先扩展 `Omega`，再检查参数和返回类型

`Self` 的解析通过辅助函数定义：

```text
resolve_S(Self) = S
resolve_P(Self) = Self
```

也就是说：

- struct/extension 中的 `Self` 是 concrete
- protocol 中的 `Self` 是 abstract

## 6. 协议满足关系

协议满足 judgment：

```text
Psi; Omega |- tau |> P
```

含义是类型 `tau` 有协议 `P` 的 evidence。

目前只有两种来源：

1. Concrete struct conformance

```text
(S, P) in dom(Psi_C)
--------------------
Psi; Omega |- S |> P
```

2. Type variable bound

```text
X : ... P ... in Omega
----------------------
Psi; Omega |- X |> P
```

`any P` 不自动满足 `P`。这是有意设计：existential package 不能直接当作 underlying conforming type 使用，必须通过 core/IR 中的 unpack 打开。

## 7. 函数、调用和 labels

函数类型统一写成 scheme：

```text
forall X_i : P_i. (label_j : tau_j) -> tau
```

无泛型参数时，`forall` 部分为空。

调用被拆成两步：

1. 如果函数是泛型，先显式实例化：

```text
e<T>
```

2. 再调用：

```text
e(args)
```

也就是说，当前类型系统和实现保持一致：不做隐式泛型实参推导。

Label matching 单独定义为辅助 judgment：

```text
Psi; Omega; Gamma; rho |- args <= params => orderedArgs
```

它负责：

- positional arguments 必须匹配 unlabeled 参数
- labeled arguments 按 label 匹配
- positional arguments 不能出现在 labeled arguments 之后
- label 不能重复
- 所有参数必须被提供

主 typing rule 不直接展开这些细节，避免规则过大。

## 8. 方法调用

方法在形式化里被统一成带显式 receiver 的函数。

例如 struct method：

```swift
struct Box {
  func id<T>(x: T) -> T { x }
}
```

在环境中记录成：

```text
id : forall T. (self : Box, x : T) -> T
```

当 source 写：

```swift
b.id
```

类型系统返回去掉 receiver 后的函数类型：

```text
forall T. (x : T) -> T
```

这对应规则 `T-StructMethod`。

对 constrained type variable：

```swift
func f<T: Show>(x: T) -> String {
  x.show()
}
```

如果 `Show` 中有：

```text
show : (Self) -> String
```

则 `x.show` 的类型是：

```text
() -> String
```

形式化中通过 `T-ConstrainedMethod` 完成：

```text
X : P in Omega
Psi_P(P)(m) = forall Y. (Self, ...) -> tau
------------------------------------------------
x.m : [X/Self](forall Y. (...) -> tau)
```

如果多个 protocol constraints 都提供同名方法，则要求 method resolution unambiguous。这和当前 checker 中对多约束同名方法的处理一致。

## 9. `any P`

`typing.tex` 中加入了 introduction rule：

```text
Psi; Omega; Gamma; rho |- e : tau
Psi; Omega |- tau |> P
---------------------------------
Psi; Omega; Gamma; rho |- e as any P : any P
```

这个规则说明：只有当 `tau` 有 `P` 的 conformance evidence 时，才能打包为 `any P`。

后续 elaboration 应该把它翻译为 existential package：

```text
pack [tau, { value = E, dict = D }] as exists X. { value : X, dict : Dict[P, X] }
```

目前不定义 surface-level unpack。这样可以让 existential elimination 留在 IR/core 中，由 elaboration 控制。

## 10. Statement Sequence Typing

Statement sequence judgment：

```text
Psi; Omega; Gamma; rho |- ss : tau
```

规则：

- 空语句序列类型为 `Unit`
- 如果最后一个 expression statement 类型为 `tau`，整个 block 类型为 `tau`
- 中间 expression statement 的结果被丢弃
- `let` 只影响后续 statements
- function declaration 可以将函数名加入后续环境

当前规则允许 recursive function，因为 `S-Fun` 中函数名在函数体内可见。

如果后续决定 surface 不支持递归，只需要从 `S-Fun` 和 `D-Fun` 的函数体检查 premise 中移除 `f : sigma`。

## 11. Declaration Well-Formedness

声明检查基于两阶段：

```text
collect(decls) = Psi
Psi |- decl ok
```

`collect` 是 partial function，只有在以下条件满足时有定义：

- 顶层名字不重复
- 所有 struct/protocol 名字已声明
- 单个 struct/protocol/extension 内 method 名字不重复
- top-level value/function type 可收集

这对应当前实现中的：

- resolver 先收集 top-level struct/protocol names
- checker 再 build env 并检查 bodies/conformance

声明规则包括：

- `D-Struct`
- `D-Protocol`
- `D-Extension`
- `D-Let`
- `D-Fun`

其中 `D-Extension` 是协议一致性检查的核心。

## 12. Conformance Checking

Extension 检查规则：

```text
Psi_P(P) = { m_i : sigma_i }
extension S : P 中存在对应 md_i : sigma_i'
match(S, P, sigma_i', sigma_i)
------------------------------------------------
Psi |- extension S : P { md_i } ok
```

`match` 定义为：

```text
match(S, P, sigma_impl, sigma_req)
iff
sigma_impl = [S / Self] sigma_req
```

这和当前 checker 中 `subst_protocol_self` 的逻辑一致。

## 13. 与 IR 的关系

Surface 类型系统本身不应该直接面对 core 的 de Bruijn index、record encoding、existential package 细节。

建议后续加入 IR 后，定义 elaboration judgment：

```text
Psi; Omega; Gamma; rho |- e : tau ~~> E
```

其中 `E` 是 IR expression。

证明目标：

```text
if Psi; Omega; Gamma; rho |- e : tau ~~> E
then [[Psi; Omega; Gamma; rho]] |-IR E : [[tau]]
```

这里 `[[tau]]` 是 surface type 到 IR type 的翻译。

典型翻译：

```text
[[Int]]       = Int
[[Bool]]      = Bool
[[String]]    = String
[[Unit]]      = Unit
[[S]]         = record type of fields of S
[[X]]         = X
[[any P]]     = exists X. { value : X, dict : Dict[P, X] }
[[forall X:P. (tau) -> tau']]
              = forall X. Dict[P, X] -> [[tau]] -> [[tau']]
```

Method call 的 elaboration：

```text
x.show()
```

如果 `x : S`：

```text
dict_S_Show.show(x)
```

如果 `x : X` 且 `X : Show`：

```text
d_X_Show.show(x)
```

## 14. 证明路线

建议证明分三层。

### 14.1 Surface Lemmas

需要先证明基础 lemma：

1. Weakening

```text
Psi; Omega; Gamma; rho |- e : tau
=> Psi; Omega; Gamma, x : tau_x; rho |- e : tau
```

2. Type substitution

```text
Psi; Omega, X:P, Omega'; Gamma; rho |- e : tau
Psi; Omega |- tau' |> P
------------------------------------------------
Psi; Omega, [tau'/X]Omega'; [tau'/X]Gamma; rho
  |- [tau'/X]e : [tau'/X]tau
```

3. Value substitution

```text
Psi; Omega; Gamma, x:tau_x; rho |- e : tau
Psi; Omega; Gamma; rho |- v : tau_x
--------------------------------------------
Psi; Omega; Gamma; rho |- [v/x]e : tau
```

### 14.2 Elaboration Preservation

主定理：

```text
If Psi; Omega; Gamma; rho |- e : tau ~~> E,
then [[Psi; Omega; Gamma; rho]] |-IR E : [[tau]].
```

关键 cases：

- `T-TypeApp`：需要使用 type substitution lemma
- `T-StructMethod`：需要证明 method table lookup 翻译成合法 dictionary/record projection
- `T-ConstrainedMethod`：需要证明 `Omega` 中的 protocol bound 翻译成 IR dictionary parameter
- `T-AsAny`：需要证明 protocol satisfaction judgment 能产生 package 所需的 dictionary evidence

### 14.3 IR to Core Preservation

如果后续 IR 是 named core + dictionary sugar，则 lowering 证明应当比较机械：

```text
If Delta |-IR E : T and E lowers to t,
then lower(Delta) |-Core t : lower(T).
```

核心复杂点：

- named variables 到 de Bruijn indices
- records 到 core records
- existentials 到 core `Some/Pack/Unpack`
- polymorphism 到 core `All/TAbs/TApp`

### 14.4 Core Type Soundness

最终只需要在 core 上证明：

```text
Progress:
If empty |-Core t : T, then t is a value or exists t'. t -> t'.

Preservation:
If empty |-Core t : T and t -> t', then empty |-Core t' : T.
```

结合前两个 preservation theorem，可得：

```text
well-typed surface program cannot elaborate to a stuck core program
```

## 15. 与当前实现的关系

当前实现已经基本对应这个类型系统的无 `any P` 子集：

- `ResolvedType::StructType` 对应 surface `S`
- `ResolvedType::TypeVariable` 对应 `X`
- `ResolvedType::AbstractSelfType(P)` 对应 protocol 中未替换的 `Self`
- `ResolvedType::Function` 对应 function scheme
- `Env.structs` 对应 `Psi_S`
- `Env.protocols` 对应 `Psi_P`
- `Env.conformance` 对应 `Psi_C`
- `Env.ext_methods` 和 struct methods 对应 `Psi_M`
- `Env.top_values` 对应 `Psi_V`
- `type_constraints` 对应 `Omega`

当前尚未覆盖或需要后续实现的部分：

1. `any P` 的 parser/resolver/checker 支持。
2. 字典 evidence 的显式 IR 表示。
3. `TypedAST -> IR` elaboration。
4. `IR -> core.Term` lowering。
5. 结构化错误和源码位置。

## 16. 后续建议

短期建议：

1. 保持 `typing.tex` 作为规范文档，不要让它追随实现中的所有临时细节。
2. 新增 IR AST，先覆盖无 existential 的 dictionary-passing 子集。
3. 给 IR 写 typing rules，再补一份 `docs/ir-typing.md`。
4. 实现 `TypedAST -> IR` 后，用 pretty-printer 对照 `typing.tex` 的 elaboration intuition。
5. 最后加入 `any P`，把它落到 existential package。

这样项目结构会比较清晰：

```text
surface parser/resolver/checker
  -> surface typing specification
  -> typed elaboration to IR
  -> IR typing
  -> lowering to core
  -> core soundness
```

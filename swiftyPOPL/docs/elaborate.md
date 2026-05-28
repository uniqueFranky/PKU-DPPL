# Elaborate 阶段设计与实现说明

本文档记录当前 SwiftyPOPL 的 elaboration 实现：把 surface `TypedProgram` 翻译成 core concrete syntax string，再复用现有 core parser 将 named core syntax 转换为 de Bruijn core term 并解释执行。

## 1. 设计决策

当前没有引入正式 IR。

采用的路线是：

```text
Surface source
  -> surface parser
  -> resolver
  -> checker
  -> TypedProgram
  -> elaborator
  -> core concrete syntax string
  -> core parser
  -> de Bruijn core Term
  -> core typechecker/evaluator
```

选择生成 core concrete syntax string 的原因：

1. 现有 core parser 已经支持 named syntax 到 de Bruijn index 的转换。
2. 直接生成 `core.Term` 需要 elaborator 手动维护 context、index、type variable index，容易出错。
3. 对 TAPL 课程项目来说，生成 readable core syntax 更利于展示 dictionary passing 和 existential encoding。
4. 证明层面仍可写成 `Surface elaborates to Core`，string renderer 只是工程实现细节。

## 2. 相关文件

新增 elaborator 包：

- `src/surface/parser/elaborator/moon.pkg.json`
- `src/surface/parser/elaborator/elaborate.mbt`

surface parser main 已接入 elaborator：

- `src/surface/parser/main.mbt`

根级 interpreter：

- `src/interpreter.mbt`
- `src/moon.pkg.json`

core 暴露运行接口：

- `src/core/main.mbt`

新增接口：

```moonbit
pub fn run_string(code : String, fname? : String = "<elaborated>") -> Unit raise
```

## 3. 当前支持范围

当前 elaborator 覆盖 checker 已支持的大部分核心子集：

- `Int` -> core `Nat`
- `Bool`
- `String`
- `Unit`
- `Int` arithmetic/comparison operators: `+`, `-`, `<`, `>`, `<=`, `>=`
- Boolean operators: `!`, `&&`, `||`
- struct type -> core record type
- struct construction -> core record value
- field access -> core projection
- top-level `let` -> core binding
- top-level function -> core binding
- function expression -> core lambda
- generic function -> core type lambda
- explicit generic instantiation -> core type application
- struct method -> top-level core function
- `extension S: P` -> protocol dictionary value
- concrete protocol method call -> dictionary projection + function application
- constrained generic dictionary parameter insertion
- `any P` type -> core existential type
- `e as any P` -> existential package with value and dictionary evidence
- method call on `any P` -> core existential unpack + dictionary method call

`any P` 的当前实现是受限的 existential elimination：surface 语言仍不暴露显式 `unpack`，checker 只允许调用不在可见签名中泄漏 `Self` 的 existential method。这样可以避免从 `any P` 中返回抽象 `Self` 后在 surface 层失去可表达类型。

当前暂未支持：

- string concatenation, because the current core language has no string concat primitive
- robust string escaping
- complete source-level diagnostic mapping after elaboration
- automatic execution from `src/surface/parser/main.mbt`，该入口目前只打印 typed program 和 core syntax；直接执行请使用根级 `src/interpreter.mbt`

## 4. 类型翻译

核心函数：

```moonbit
fn type_to_core(env : ElabEnv, ty : @resolver.ResolvedType) -> String raise
```

主要翻译：

```text
surface Int        -> core Nat
surface Bool       -> core Bool
surface String     -> core String
surface Unit       -> core Unit
surface Struct S   -> core record type
surface TypeVar T  -> core type variable T
surface Function   -> core arrow type wrapped by All
```

例如：

```swift
struct Box {
  let x: Int
}
```

翻译为 core type：

```text
{x:Nat}
```

泛型函数：

```swift
func id<T>(x: T) -> T { x }
```

翻译为 core type：

```text
All T. T -> T
```

## 5. Struct 翻译

Struct declaration 本身不生成 core command。它只进入 elaboration environment，供后续类型翻译、构造和字段访问使用。

构造：

```swift
Box(x: 1)
```

翻译为：

```text
{x=1}
```

字段访问：

```swift
b.x
```

翻译为：

```text
(b).x
```

## 5.1 基础运算翻译

新增的 surface operators 不扩展 core 语法，而是展开到已有 core 构造。

Bool operators 翻译为 core conditional，因此 `&&` / `||` 保留短路语义：

```text
!e       -> if E then false else true
e1 && e2 -> if E1 then E2 else false
e1 || e2 -> if E1 then true else E2
```

`Int` 当前仍翻译为 core `Nat`，所以 arithmetic/comparison 通过内联 closed core functions 实现：

```text
add : Nat -> Nat -> Nat
sub : Nat -> Nat -> Nat
lt  : Nat -> Nat -> Bool
```

对应 operator 翻译为：

```text
e1 + e2  -> add E1 E2
e1 - e2  -> sub E1 E2
e1 < e2  -> lt E1 E2
e1 > e2  -> lt E2 E1
e1 <= e2 -> if lt E2 E1 then false else true
e1 >= e2 -> if lt E1 E2 then false else true
```

这里 `sub` 是 saturating subtraction，因为 core `pred 0 = 0`。因此 `0 - 1` 的 SwiftyPOPL/core 结果是 `0`，不是 Swift signed `Int` 的 `-1`。

Parser 对 `<` 采用词法消歧：无空格的 `f<T>` 作为泛型实例化，带空格的 `x < y` 作为小于比较。差分测试生成器应生成 `x < y`，不要生成 `x<y`。

## 6. Method 翻译

Surface method 被翻译成 top-level core function。

例如：

```swift
struct Box {
  let x: Int
  func id<T>(x: T) -> T { x }
}
```

翻译为：

```text
method_Box_id = lambda T. lambda self:{x:Nat}. lambda x:T. x;
```

方法访问：

```swift
b.id
```

会翻译为 receiver 已应用的函数：

```text
method_Box_id b
```

显式泛型方法调用：

```swift
b.id<Int>(1)
```

翻译为：

```text
(((method_Box_id) [Nat]) (b)) (1)
```

这里必须先做 type application，再传 receiver。

## 7. Protocol 和 Extension 翻译

Protocol declaration 不直接生成 core command。它进入 elaboration environment，作为 dictionary type 的来源。

例如：

```swift
protocol Show {
  func show() -> String
}
```

对 `Box` 的 dictionary type 为：

```text
{show:{x:Nat}->String}
```

Extension：

```swift
extension Box: Show {
  func show() -> String { "box" }
}
```

翻译为 dictionary value：

```text
dict_Box_Show = {show=lambda self:{x:Nat}. "box"};
```

Protocol method call：

```swift
b.show()
```

翻译为：

```text
(dict_Box_Show.show) (b)
```

这正是 dictionary passing：conformance evidence 由 `dict_Box_Show` 显式传递。

零参数 method value 在 surface 中仍然是 `() -> T`，不是 `Unit -> T`。当前 core 没有真正的零参数函数，因此 elaborator 用 `Unit` thunk 编码：

```swift
let f: () -> String = b.show
f()
```

翻译为：

```text
f = (lambda __swifty_method_receiver:{x:Nat}.
       lambda _:Unit. (dict_Box_Show.show) (__swifty_method_receiver)) (b);
(f) (unit);
```

## 8. Constrained Generic 翻译

带协议约束的泛型参数会引入显式 dictionary 参数。

Surface：

```swift
func f<T: Show>(x: T) -> String {
  x.show()
}
```

目标 core 形状：

```text
f =
  lambda T.
  lambda dict_T_Show:{show:T->String}.
  lambda x:T.
    (dict_T_Show.show) (x);
```

当前实现中：

- `env_add_constraints` 给 constrained type parameter 生成 dictionary parameter 名。
- `dict_param_name(T, P)` 生成形如 `dict_T_P` 的变量名。
- `generic_evidence_args` 在 explicit generic instantiation 后插入 dictionary arguments。
- `evidence_for` 根据 actual type 决定使用 concrete dictionary 还是 type-variable dictionary。

例如：

```swift
f<Box>(b)
```

会变成：

```text
((f [BoxCoreType]) dict_Box_Show) b
```

如果 actual type 是 type variable `T` 且 `T: Show`，则使用当前作用域中的 `dict_T_Show`。

## 9. Block 和 Local Declaration 翻译

Surface block 的类型由最后一个 expression statement 决定。

局部 `let` 会翻译为 lambda application。

Surface：

```swift
let x: Int = 1
x
```

Core：

```text
(lambda x:Nat. x) (1)
```

中间 expression statement 会通过 dummy `Unit` lambda 丢弃结果：

```text
(lambda _:Unit. rest) (expr)
```

## 10. Existential 翻译

`any P` 被翻译成 core existential：

```text
{Some X, {value:X, dict:Dict[P, X]}}
```

其中 dictionary type 由 protocol requirement 生成。例如：

```swift
protocol Show {
  func show() -> String
}
```

对应的 existential core type 形状为：

```text
{Some X, {value:X, dict:{show:X->String}}}
```

打包：

```swift
let s: any Show = b as any Show
```

会翻译为：

```text
{*{x:Nat}, {value=b, dict=dict_Box_Show}} as {Some X, {value:X, dict:{show:X->String}}}
```

调用 existential method：

```swift
s.show()
```

会由 elaborator 控制 unpack：

```text
let {X, opened_Show} = s in (opened_Show.dict.show opened_Show.value)
```

checker 会拒绝在 visible signature 中提到 `Self` 的 existential method，例如：

```swift
protocol Clone {
  func clone() -> Self
}

let c: any Clone = b as any Clone
c.clone()
```

这类调用当前会在 checker 阶段报错，而不是生成 core。

## 11. 根级 Interpreter

新增 `src/interpreter.mbt` 用于直接执行 SwiftyPOPL 源码。

运行方式：

```bash
moon run src -- path/to/file.swift
```

执行流程：

1. 读取 SwiftyPOPL source file。
2. 调用 surface lexer/parser。
3. 调用 resolver。
4. 调用 checker。
5. 调用 elaborator 生成 core syntax string。
6. 调用 `@core.run_string`。
7. core parser 将 named syntax 转为 de Bruijn。
8. core typechecker/evaluator 输出最终结果。

示例：

```bash
moon run src -- test/should_pass/type_checker_success.swift
```

输出包含 core 的绑定和最终表达式结果：

```text
method_Box_id = lambda T. lambda self:{x:Nat}. lambda x:T. x
  : All T. {x:Nat} -> T -> T
dict_Box_Show = {show=lambda self:{x:Nat}. "box"}
  : {show:{x:Nat}->String}
b = {x=1}
  : {x:Nat}
x = 1
  : Nat
y = 1
  : Nat
"box"
  : String
```

## 12. 当前验证

最近一次静态检查和样例抽查显示以下路径可用：

```bash
moon check .
moon run src -- test/should_pass/type_checker_success.swift
moon run src -- test/should_pass/existential_show_success.swift
moon run src -- test/should_fail/existential_self_method_rejected.swift
moon run src -- test/should_pass/generic_type_variables.swift
```

`type_checker_success.swift` 的输出包含 dictionary passing：

```text
method_Box_id = lambda T. lambda self:{x:Nat}. lambda x:T. x
  : All T. {x:Nat} -> T -> T
dict_Box_Show = {show=lambda self:{x:Nat}. "box"}
  : {show:{x:Nat}->String}
b = {x=1}
  : {x:Nat}
x = 1
  : Nat
y = 1
  : Nat
"box"
  : String
```

`existential_show_success.swift` 的输出包含 existential package：

```text
s = {*{x:Nat}, {value={x=1}, dict={show=lambda self:{x:Nat}. "box"}}} as {Some X, {value:X,dict:{show:X->String}}}
  : {Some X, {value:X,dict:{show:X->String}}}
"box"
  : String
```

`existential_self_method_rejected.swift` 预期失败，当前错误为：

```text
TypeError: existential method "clone" mentions Self in its visible signature
```

注意：仓库目前还没有统一的 should-pass / should-fail 自动测试 runner，`test/` 目录主要是手工样例集合。

## 13. 已知工程问题

### 13.1 Root 包导入 core main package

`moon check .` 当前会提示：

```text
Package `swifty` depends on main package `swifty/core`
```

这目前只是 warning，不影响运行。

如果要彻底消除，需要把 core 拆成：

```text
src/corelib     // reusable parser/typechecker/evaluator API
src/core        // CLI main
```

当前为了避免大规模重构，暂时保留现状。

### 13.2 Core string escaping

当前 `string_lit` 只保守支持现有简单字符串测试：

```moonbit
fn string_lit(s : String) -> String {
  "\"\{s}\""
}
```

后续需要补充 escaping：

- `"`
- `\`
- newline

### 13.3 Diagnostics

Elaboration 后 core parser/typechecker 报错的位置来自 generated core string，不会自动映射回 source location。

如果后续需要更好的诊断，需要在 TypedAST 中保留 source span，并在 elaborator 中维护 source-to-core mapping。

### 13.4 Existential 限制

当前 existential 支持覆盖：

- `any P` 类型解析、检查和 core 类型翻译
- `e as any P` 打包
- 非泛型、existential-safe 的 protocol method 调用

仍未覆盖：

- surface-level 显式 unpack
- 更复杂的 `Self`、关联类型、opaque type 等 Swift 特性

## 14. 后续建议

短期建议：

1. 给 elaborator 增加 should-pass 测试脚本，自动比较 elaborated core 是否能被 core interpreter 接受。
2. 补充 constrained generic 和 existential method 的正向/反向测试样例，确保 dictionary evidence 与 unpack 路径持续可用。
3. 为 existential generic method 补充更多反向测试，尤其是 `Self` 通过可见签名逃逸的情况。
4. 把 core 拆成 reusable library package，消除 root interpreter 导入 main package 的 warning。
5. 为 generated core string 加 pretty mode，方便论文展示和 debug。

推荐实现顺序：

```text
1. Stabilize current dictionary-passing and existential elaboration
2. Add automated tests for should-pass / should-fail examples
3. Add negative tests for existential generic method safety
4. Improve diagnostics and source span preservation
5. Refactor core package split
```

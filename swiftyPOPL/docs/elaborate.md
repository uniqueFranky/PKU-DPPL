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

当前 elaborator 覆盖 checker 已支持的大部分非 existential 子集：

- `Int` -> core `Nat`
- `Bool`
- `String`
- `Unit`
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

当前暂未支持：

- `any P`，因为 surface parser/checker 还没有对应 AST
- method call on existential package
- robust string escaping
- complete source-level diagnostic mapping after elaboration
- automatic execution from `src/surface/parser/main.mbt`，该入口目前只打印 typed program 和 core syntax

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

## 10. 根级 Interpreter

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

## 11. 当前验证

已运行：

```bash
moon check src/surface/parser
moon check .
moon run src/surface/parser -- test/should_pass/type_checker_success.swift
moon run src -- test/should_pass/type_checker_success.swift
moon run src/surface/parser -- test/should_pass/extension_methods.swift
moon run src/surface/parser -- test/should_pass/struct_basic.swift
```

`type_checker_success.swift` 的 elaborated core 已进一步写入临时 core 文件，并用现有 core interpreter 验证通过：

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

`generic_type_variables.swift` 目前仍在 checker 阶段报：

```text
TypeError: variable type mismatch
```

这不是 elaborator 引入的问题。

## 12. 已知工程问题

### 12.1 Root 包导入 core main package

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

### 12.2 Core string escaping

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

### 12.3 Diagnostics

Elaboration 后 core parser/typechecker 报错的位置来自 generated core string，不会自动映射回 source location。

如果后续需要更好的诊断，需要在 TypedAST 中保留 source span，并在 elaborator 中维护 source-to-core mapping。

## 13. 后续建议

短期建议：

1. 给 elaborator 增加 should-pass 测试脚本，自动比较 elaborated core 是否能被 core interpreter 接受。
2. 补充 constrained generic 的正向测试样例，确保 dictionary parameter insertion 覆盖 type-variable evidence。
3. 加入 `any P` 的 parser/checker/elaborator 支持。
4. 把 core 拆成 reusable library package，消除 root interpreter 导入 main package 的 warning。
5. 为 generated core string 加 pretty mode，方便论文展示和 debug。

推荐实现顺序：

```text
1. Stabilize current no-existential elaboration
2. Add tests for dictionary passing
3. Add any P pack
4. Add existential unpack/method call if needed
5. Refactor core package split
```

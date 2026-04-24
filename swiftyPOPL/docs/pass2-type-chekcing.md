# Pass 2 类型检查设计与实现说明

本文档记录 `surface parser` 第二遍语义分析（Pass 2）的设计目标、规则、实现结构、当前覆盖范围与已知限制。

## 1. 目标与范围

Pass 2 的核心目标是：在 Pass 1 产出的 `ResolvedProgram` 上执行类型检查，生成带类型信息的 `TypedProgram`（TypedAST）。

本阶段聚焦：

1. 表达式类型检查（含函数调用、成员访问、if、泛型实例化等）。
2. 值符号绑定（局部/顶层标识符解析）。
3. 调用与成员解析（函数调用/方法调用/字段访问）。
4. 协议一致性检查（`extension S: P` 的实现完整性与签名匹配）。
5. 泛型显式实例化与约束检查（必须显式 `GenericInst`）。

不在本阶段处理：

- 全局类型推导（尤其隐式泛型实参推导）。
- 跨文件符号合并（仍以单文件输入为前提）。
- 复杂重载与最优重载决议。
- 带源码位置信息的细粒度错误定位（当前错误仅字符串）。

## 2. 数据结构设计（TypedAST）

定义位置：`src/surface/parser/checker/ast.mbt`。

### 2.1 关键元信息

- `SymbolBinding`
  - `LocalValue(name)`
  - `TopLevelValue(name)`
  - `TypeParam(name)`（预留）
- `CallResolution`
  - `FunctionCall(name)`
  - `MethodCall(owner, method)`
  - `ConstructorCall(name)`（预留）
  - `FunctionValueCall`
- `MemberResolution`
  - `Field(owner, name)`
  - `Method(owner, name)`

### 2.2 TypedExpr（每个表达式携带类型）

- `IntLit/BoolLit/StringLit/Self/Ident/...` 均显式携带 `ResolvedType`。
- `Call` 节点包含参数、调用解析信息与返回类型。
- `Access` 节点包含成员解析信息与成员类型。
- `GenericInst` 节点包含实例化后的函数类型。

### 2.3 TypedProgram

- `stmts : Array[TypedStmt]`
- `top_types : Array[(String, ResolvedType)]`（沿用 Pass1）

## 3. 核心规则与语义

## 3.1 基本类型检查

- 字面量：
  - `IntLit -> Int`
  - `BoolLit -> Bool`
  - `StringLit -> String`
- `if/ifElse`：
  - 条件必须为 `Bool`
  - `ifElse` 两分支类型必须相同
  - `if` 表达式结果记为 `Unit`

## 3.2 值符号绑定

- 标识符优先查局部环境，再查顶层类型表。
- `Self` 仅在方法环境可用（通过预注入的 `self` 绑定）。

## 3.3 调用参数规则

- 通用调用遵循：
  - positional 参数必须在所有 labeled 参数之前；
  - labeled 参数可交换顺序；
  - 重复 label 报错；
  - 参数类型必须与签名匹配。
- `Construct` 当前只支持 labeled 参数（不支持 positional）。

## 3.4 泛型与约束

- 泛型函数调用必须显式实例化（`GenericInst`），不做隐式推断。
- 实例化时检查：
  - 类型参数个数匹配；
  - `Constrained` 约束满足（如 `T: P`）。
- 实例化后执行类型替换，得到具体参数类型与返回类型。

## 3.5 成员访问与方法解析

- 对 `StructType`：
  - 优先字段，再方法（含 extension 引入的方法）。
- 对 `TypeVariable`：
  - 从其协议约束集中查找同名方法。
  - 多约束同名方法时按完整函数签名（类型参数、值参数/标签、返回类型）判定：
    - 若同名且签名完全重复：报错（重复约束方法）。
    - 若同名但签名不同：报错（歧义）。

## 3.6 协议实现检查（conformance）

对每个 `extension S: P`：

1. `P` 中每个要求方法必须被实现。
2. 方法签名必须匹配。
3. 比较前执行协议 `Self` 替换：
   - 将协议方法签名中的 `AbstractSelfType(P)` 替换为 `StructType(S)` 后再比较。

> 这一步是必要的：否则协议方法中的抽象 `Self` 与实现中的具体 `StructType` 无法直接相等。

## 4. 实现结构

实现主文件：`src/surface/parser/checker/check.mbt`。

主流程：

1. `build_env(program)`
   - 收集 struct/protocol 信息、extension 方法集合、conformance 关系。
2. `check_protocol_conformance(env)`
   - 先做协议实现完整性与签名检查。
3. `check_stmt_array / check_decl / check_expr`
   - 递归类型检查并构造 TypedAST。
4. 输出 `TypedProgram`。

入口函数：

- `pub fn check(program : @resolver.ResolvedProgram) -> TypedProgram raise`

## 5. 工程接入

### 5.1 包与文件

- 新增目录：`src/surface/parser/checker/`
  - `ast.mbt`
  - `check.mbt`
  - `moon.pkg.json`

### 5.2 main 流程

`src/surface/parser/main.mbt` 现在流程为：

1. parse tokens
2. parse program
3. `resolve`（Pass1）
4. `check`（Pass2）
5. 打印 `Typed program`

并新增对 `@checker.TypeError(msg)` 的捕获打印，便于调试。

## 6. 已添加测试样例

位置：`src/surface/parser/test/`

- `type_checker_success.swift`：正常路径（协议、扩展、字段、方法、泛型显式实例化）。
- `type_checker_missing_protocol_method.swift`：缺失协议方法实现。
- `type_checker_argument_order.swift`：参数次序与标签规则相关。

## 7. 当前限制与后续建议

当前限制：

1. 错误信息尚未结构化（缺少源码位置信息、expected/actual 明细）。
2. `Construct` 仅支持 labeled 参数。
3. `SymbolBinding::TypeParam` 预留但尚未在类型位置形成完整绑定产物。
4. 仍是单文件语义检查。

后续建议：

1. 在 ResolvedAST 中保留 `Info`，升级 TypeError 为带位置的结构化错误。
2. 引入更细粒度诊断（调用处参数索引、label 名、expected/actual 类型）。
3. 明确 elaboration 所需绑定信息并在 TypedAST 中补齐。
4. 在 Pass3 中将 TypedAST 系统化展开到 core term。

# Pass 1 语义分析设计与实现说明

本文档记录 `surface parser` 第一遍语义分析（Pass 1）的设计目标、规则、实现结构与当前状态。

## 1. 目标与范围

Pass 1 的核心目标是：将 parser 产出的 AST（`@syntax.Program`）转换为 `ResolvedAST`，并在转换过程中完成**类型名解析与声明层语义归一化**，不做求值与类型推导。

本阶段聚焦：

1. 区分 `UDT` 对应的是 `struct`、`protocol` 还是类型变量。
2. 收集顶层函数/变量声明类型（仅取注解，不依赖表达式推导）。
3. 在声明作用域中解析 `Self`：
   - struct/extension 中 `Self -> StructType(owner)`
   - protocol 中 `Self -> AbstractSelfType(protocolName)`
4. 将 struct/protocol/extension 中的 `func` 归一化为方法，并注入首参 `self`。
5. 对重名、未定义类型、非法类型用法进行立即报错（fail-fast）。

不在本阶段处理：

- 表达式求值
- 类型推导/一致性检查
- 名字绑定（如 `Ident` 解析到具体值定义）
- 跨文件解析（仅当前文件）

## 2. 数据结构设计（ResolvedAST）

`ResolvedAST` 定义在 `src/surface/parser/resolver/ast.mbt`，核心点如下：

- `ResolvedType`
  - `StructType(name)`
  - `ProtocolType(name)`（当前仅允许在受限语境）
  - `TypeVariable(name)`
  - `AbstractSelfType(protocolName)`
  - `Function(...)`
- `ResolvedDecl`
  - 显式区分 `FunctionDef/FunctionDecl` 与 `MethodDef/MethodDecl`
  - `StructDef/StructDecl/Protocol/Extension`
- `ResolvedProgram`
  - `stmts : Array[ResolvedStmt]`
  - `top_types : Array[(String, ResolvedType)]`

这套设计保证了后续阶段能直接区分“函数 vs 方法”，避免再从上下文反推。

## 3. 语义规则

## 3.1 顶层命名与类型收集

- 从顶层声明中收集 `struct` 名称与 `protocol` 名称。
- 顶层同名（结构、协议、函数、变量等）一律报错。
- 本阶段只看当前文件，不做 import 合并。

## 3.2 `UDT` 解析规则

对任意 `UDT(name)`：

1. 若 `name` 在当前类型变量作用域中：`TypeVariable(name)`
2. 否则若 `name` 是已收集 struct 名：`StructType(name)`
3. 否则若 `name` 是已收集 protocol 名：
   - 在允许 protocol 类型的语境：`ProtocolType(name)`
   - 否则报错（协议类型不能直接作为值类型）
4. 否则报错（未定义类型）

## 3.3 `Self` 解析规则

- `StructOwner(name)` / `ExtensionOwner(name)` 中：`Self -> StructType(name)`
- `ProtocolOwner(name)` 中：`Self -> AbstractSelfType(name)`
- 顶层使用 `Self`：报错

## 3.4 方法识别与 `self` 注入

按声明位置识别：

- 顶层 `func` => 普通函数（`Function*`）
- struct/protocol/extension 内 `func` => 方法（`Method*`）

方法签名/参数注入规则：

- 在参数列表首位插入 `self` 参数：
  - struct/extension: `self : StructType(owner)`
  - protocol: `self : AbstractSelfType(ownerProtocol)`

注意：

- 字段 `let f: <...>(...) -> ...` 仍是字段，不转方法。

## 3.5 顶层类型表 `top_types`

在 `TopLevel` 下：

- `let x : T = ...` 记录 `(x, resolve(T))`
- `func f...` 记录 `f` 的函数类型
- 不依赖函数体/初始化表达式推导

非顶层声明不加入 `top_types`。

## 4. 实现流程

实现位于 `src/surface/parser/resolver/resolve.mbt`，主流程：

1. `stmt_list_to_array`
   - 将 parser 的链式 `StmtList` 转成数组，便于遍历
2. `collect_top_types`
   - 提取并验证顶层命名
3. `resolve_stmt_array`
   - 遍历语句，分别调用 `resolve_decl` / `resolve_expr`
4. `resolve_decl`
   - 做声明级语义归一化（方法识别、self 注入、top_types 记录）
5. `resolve_expr`
   - 递归处理表达式结构，并解析表达式中显式出现的类型位
6. `resolve_type` / `resolve_type_params`
   - 完成 `UDT`/`Self`/泛型参数作用域解析

入口：

- `pub fn resolve(program : @syntax.Program) -> ResolvedProgram raise`

## 5. 错误策略

采用 fail-fast：

- 发现重复命名、非法 `Self`、未定义类型、非法协议类型位置时，立即 `raise ResolveError`。
- 不做错误收集。

## 6. main 接入与调试

当前 `main` 调用流程：

1. parse tokens
2. parse program
3. 调用 `@resolver.resolve(prog)`
4. 打印 resolved 结果

为调试 resolver，`main` 的异常分支目前会打印错误对象，便于观察 pass1 报错触发点。

## 7. 当前限制与后续建议

当前限制：

- 单文件语义解析
- 未做表达式级名字绑定
- 未做类型一致性校验（仅转换/归一化）

后续建议：

1. 增加跨文件符号表（import 合并）
2. 增加 `ResolvedExpr` 的标识符绑定信息
3. 新增 pass2：类型检查与约束验证
4. 将 resolver 报错升级为携带源码位置信息的错误格式

# SwiftyPOPL: A swift-style Protocol-Oriented Programming Language
**作者:** Runbang Yan | **所属机构:** 计算机科学学院

---

## 🧭 项目背景与动机

传统的面向对象编程（OOP）高度依赖类继承，虽然支持代码复用，但也带来了显著的局限性。现代编程语言正逐渐摆脱以继承为中心的设计，转向基于能力（Capabilities）和接口一致性（Interface Conformance）的抽象。

### 传统 OOP 的局限性
- **脆弱的基类问题 (Fragile Base Class):** 基类的修改可能会意外破坏子类的功能。
- **层级臃肿:** 通过继承进行复用通常会导致极深且臃肿的类层次结构。
- **设计负担:** 每次添加新实体时，都需要费心设计其在类层次结构中的位置。

### 范式转变与面向协议编程 (POP)
现代语言更倾向于接口抽象，例如 Go 语言的 Interfaces 和 Rust 的 Traits。Swift 则大力推崇**面向协议编程 (POP)**。当抽象以协议为核心时，多态就成为了关键。POP 能够自然地与以下特性结合：
- **参数化与特设多态 (Parametric and Ad-hoc polymorphism):** 用于泛型编程和协议约束。
- **一等函数多态 (First-class polymorphism):** 用于传递带有协议约束的多态函数。
- **存在类型抽象 (Existential abstraction):** 用于一等抽象协议值（即 `any Protocol`）。

---

## 🎯 研究目标与语言设计

Swift 作为一门复杂的工业级语言，其协议特性与其他语言特性交织复杂，难以直接形式化。本项目旨在引入 **SwiftyPOPL**，一种轻量级、易于形式化的核心语言。

- **Swifty:** 体现其轻量级设计和受 Swift 启发的表层语法。
- **POPL:** 体现其面向协议的编程范式。

项目的核心目标是设计一个能够捕捉面向协议抽象、多种形式的多态以及存在类型协议值本质的小型语言，并专注于研究带有 `any P` 的 Swift 风格协议抽象及其存在类型安全的子集。

### 语言特性范围 (Scope)

以下是 SwiftyPOPL 支持与不支持的特性对比：

| **特性分类** | **包含在内 (In Scope)** | **排除在外 (Out of Scope)** |
| :--- | :--- | :--- |
| **数据结构** | Structs (基础数据聚合) | 结构体或协议之间的继承 |
| **协议与约束** | 定义/实现接口，简单的泛型类型约束 | 协议中的关联类型 (Associated types) |
| **多态支持** | 参数化多态、特设多态、一等多态函数 | 不透明类型 (Opaque types, `some P`) |
| **存在类型** | `any P` (将值与实现协议的证据打包) | 引用类型与副作用 (References and side effects) |

---

## 💻 核心代码示例

以下是 SwiftyPOPL 核心特性的表层语法示例：

### 1. 协议声明与实现
```swift
protocol Show {
  func show() -> String
}

struct IntBox {
  let value: Int
}

struct BoolBox {
  let value: Bool
}

extension IntBox: Show {
  func show() -> String {
    return "IntBox(\(value))"
  }
}

extension BoolBox: Show {
  func show() -> String {
    return "BoolBox(\(value))"
  }
}
```

### 2. 参数化多态 + 协议
```swift
protocol Show {
  func show() -> String
}

protocol Eq {
  func eq(_ other: Self) -> Bool
}

func describeIfEqual<T: Show & Eq>(_ x: T, _ y: T) -> String {
  if x.eq(y) {
    return x.show()
  } else {
    return "not equal"
  }
}
```

### 3. 一等多态 + 协议
```swift
func makePrinter() -> <T: Show>(T) -> String {
  return func <T: Show>(_ x: T) -> String {
    x.show()
  }
}
```

### 4. 特设多态 + 存在类型 (Existentials)
```swift
func makeSomething(_ b: Bool) -> any Show { 
  if b { 
    return IntBox(value: 42) as any Show
  } else { 
    return BoolBox(value: true)  as any Show
  } 
}

let anyShow: any Show = makeSomething(true)
anyShow.show()
```

---

## 📐 形式化问题与演算设计

本项目提出了五个核心的形式化研究问题（Q1-Q5），并围绕这些问题设计了演算模型。

### 核心研究问题
1. **表层形式化:** 如何在一个小型类型化语言中形式化 Swift 风格的协议抽象？
2. **核心形式化:** 如何为面向协议的特性设计核心演算？
3. **推导/展开 (Elaboration):** 面向协议的特性应如何展开为小型核心演算？
4. **存在类型安全:** 为了安全地打包存在类型，需要哪些类型化限制？
5. **元理论:** 如何证明核心演算的类型可靠性（Type Soundness），以及展开过程在源语言到核心语言之间保持类型一致？

### 演算设计 (Calculus Design)
- **源语言 (Source Language):** 具备上述特性的类 Swift 表层语言。
- **核心语言 (Core Language):** 一个小型的类型化演算（SystemF + 记录 records + 存在类型 existentials），包含：变量、Lambda 抽象/应用、类型抽象/应用、记录与投影、存在类型的打包/解包，以及基础类型（Int, Bool, String）。

### 展开规则 (Elaboration)
- 协议声明 ➡️ 字典记录类型 (dictionary record types)
- 协议实现 ➡️ 字典值 (dictionary values)
- 带有协议约束的泛型函数 ➡️ 带有显式字典参数的函数
- 协议方法调用 ➡️ 字典投影 + 函数应用
- 存在类型协议值 (`any P`) ➡️ 存在类型包 (existential packages)

---

## 🚀 最终目标与限制

为了保持语言的易处理性，设计上做出了部分限制：仅允许受限的、存在类型安全的协议片段打包为 `any P`，并且在特定位置强制要求显式类型注解。

### 最终交付目标

1. **语言设计 (Language Design)**
   - 类 Swift 表层语言的语法定义。
   - 形式化的核心演算 (System F + records + existentials)。
   - 表层语言与核心语言的类型化规则。
   - 从表层语言到核心语言的展开规则。
2. **工程实现 (Implementation)**
   - 一个针对表层语言的类型检查器，能够生成展开后的核心项。
   - 一个核心语言的解释器。
   - 一套示例程序。
3. **元理论 (Meta Theory)**
   - 核心语言 Progress 和 Preservation 属性的（粗略）证明。
   - 展开过程从表层语言到核心语言保持类型一致的（严格）证明。

*(注：项目进度安排 Schedules 待定)*

protocol Identity {
  func id<T>(x: T) -> T
  func describe<T: Printable>(x: T) -> String
}

protocol Printable {
  func print() -> String
}

struct Box {}

struct Label {
  let value: String
}

extension Box: Identity {
  func id<T>(x: T) -> T { x }
  func describe<T: Printable>(x: T) -> String { x.print() }
}

extension Label: Printable {
  func print() -> String { self.value }
}

let box: Box = Box()
let label: Label = Label(value: "label")
let erased: any Identity = box as any Identity
let immediate: Int = erased.id<Int>(x: 1)
let f: <T>(x: T) -> T = erased.id
let saved: String = f<String>(x: "ok")
let described: String = erased.describe<Label>(x: label)
let describe: <T: Printable>(x: T) -> String = erased.describe
let describedAgain: String = describe<Label>(x: label)

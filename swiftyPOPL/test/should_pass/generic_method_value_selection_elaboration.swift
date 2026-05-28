struct Box {
  func id<T>(x: T) -> T { x }
}

let b: Box = Box()
let f: <T>(x: T) -> T = b.id
let y: Int = f<Int>(x: 1)
f<Bool>(x: true)
protocol Clone {
  func clone() -> Self
}

struct Box {
  let x: Int
}

extension Box: Clone {
  func clone() -> Self { self }
}

let b: Box = Box(x: 1)
let c: any Clone = b as any Clone
c.clone()

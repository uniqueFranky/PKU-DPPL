protocol Show {
  func show() -> String
}

struct Box {
  let x: Int
}

let b: Box = Box(x: 1)
let s: any Show = b as any Show

protocol Named {
  func name() -> String
}

struct Screen {
  let identifier: Int
}

extension Screen: Named {
  func name() -> String { "Home" }
}

func keepNamed<T: Named>(item: T) -> T {
  item
}

let screen: Screen = Screen(identifier: 1)
let kept: Screen = keepNamed<Screen>(item: screen)
kept.name()

protocol Named {
  func name() -> String
}

struct Screen {
  let identifier: Int
}

extension Screen: Named {
  func name() -> String { "Home" }
}

func displayName<T: Named>(item: T) -> String {
  item.name()
}

let screen: Screen = Screen(identifier: 1)
displayName<Screen>(item: screen)

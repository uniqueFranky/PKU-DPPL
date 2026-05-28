struct Mapper {
  let apply: <T>(T) -> T
}

let mapper: Mapper = Mapper(apply: func <T>(_ value: T) -> T {
  value
})

let chosen: Int = mapper.apply<Int>(7)
chosen

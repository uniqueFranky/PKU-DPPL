protocol P {
    func foo() -> Self
}
struct Box {
    func foo() -> Self { self }
    let f: <T: P>(x: T) -> T = func <T: P>(x: T) -> T { x }
}

func id<T>(x: T) -> T { x }

func useConstrained<T: P>(x: T) -> T { x }

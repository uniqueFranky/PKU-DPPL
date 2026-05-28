protocol P {
    func foo() -> Self
}
struct Box {
    func foo() -> Self { self }
    let f: <T: P>(T) -> T = func <T: P>(_ x: T) -> T { x }
}

func id<T>(x: T) -> T { x }

func useConstrained<T: P>(x: T) -> T { x }

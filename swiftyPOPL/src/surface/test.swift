func poly<T: P, S: P & PP, L>(x: T) -> Bool {
    x.foo(1)
}

poly<S, O, I>(1)

let polyF: <T: P, S: P & PP>(T, S) -> Bool = func <T: P, S: P & PP>(x: T, y: S) -> Bool {
    x.foo(1)
}


let f: <T, S>(T) -> T = 
    if cond
    { func <T>(x: T) -> T { x } }
    else { func <T>(x: T) -> T { x } }

f<T1><T2>(x)
f<T1, T2>(x)


S(x: 123, y: false)


struct S

struct S {
    let x: Int
}

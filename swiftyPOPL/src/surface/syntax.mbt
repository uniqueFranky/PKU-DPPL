enum Type {
  Int
  Bool
  String
  Unit
  UDT(String)
  Function(Array[Type], Type)
} derive(Show)


enum Expr {
  IntLit(Int)
  BoolLit(Bool)
  StringLit(String)
  Variable(String)
  Call(Expr, Array[Expr])
  If(Expr, Expr, Expr)
  Let(Expr, Expr)
} derive(Show)

enum Decl {
  Variable(String, Type, Expr)
  Function(String, Array[(String, Type)], Type, Array[Stmt])
  Struct(String, Array[(String, Type)], Array[Decl])
  Protocol(String, Array[Decl])
} derive(Show)

enum Stmt {
  Decl(Decl)
  Expr(Expr)
} derive(Show)

type Program = Array[Stmt]

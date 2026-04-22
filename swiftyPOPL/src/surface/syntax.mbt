enum Type {
  Int
  Bool
  String
  Unit
  Self
  UDT(String)
  Function(Array[Type], Type)
} derive(Show)


enum ArgExpr {
  Positional(Expr)
  Named(String, Expr)
} derive(Show)

enum ParamExpr {
  Unlabeled(String, Type)
  Labeled(String, String, Type)
} derive(Show)

enum FuncSig {
  Plain(String, Array[ParamExpr], Type) // name, args (name, label, type), return type
} derive(Show)

enum Expr {
  IntLit(Int)
  BoolLit(Bool)
  StringLit(String)
  Self
  Variable(String)
  Call(Expr, Array[ArgExpr])
  Access(Expr, Expr)
  IfElse(Expr, StmtList, StmtList)
  If(Expr, StmtList)
  Function(Array[ParamExpr], Type, StmtList)
} derive(Show)

enum Decl {
  Variable(String, Type, Expr)
  FuncDef(FuncSig, StmtList)
  FuncDecl(FuncSig)
  Field(String, Type)
  Struct(String, Array[Decl])
  Protocol(String, Array[Decl])
} derive(Show)

enum Stmt {
  Decl(Decl)
  Expr(Expr)
} derive(Show)

enum StmtList {
  Stmt(Stmt)
  StmtList(Stmt, StmtList)
} derive(Show)

type Program =  StmtList

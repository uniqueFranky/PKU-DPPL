enum Type {
  Int
  Bool
  String
  Unit
  Self
  UDT(String)
  Function(Array[TypeParam], Array[Type], Type) 
} derive(Show)

enum ArgExpr {
  Positional(Expr)
  Named(String, Expr)
} derive(Show)

enum ParamExpr {
  Unlabeled(String, Type)
  Labeled(String, String, Type)
} derive(Show)

enum TypeParam {
  Generic(String)
  Constrained(String, Array[Type])
} derive(Show)

enum FuncSig {
  Sig(String, Array[TypeParam], Array[ParamExpr], Type)
} derive(Show)

enum Expr {
  IntLit(Int)
  BoolLit(Bool)
  StringLit(String)
  Self
  Ident(String)
  Call(Expr, Array[ArgExpr])
  Construct(String, Array[ArgExpr])
  GenericInst(Expr, Array[Type]) 
  Access(Expr, String)
  IfElse(Expr, StmtList, StmtList)
  If(Expr, StmtList)
  Function(Array[TypeParam], Array[ParamExpr], Type, StmtList)
} derive(Show)

enum Decl {
  Variable(String, Type, Expr)
  FuncDef(FuncSig, StmtList)
  FuncDecl(FuncSig)
  Field(String, Type)
  Struct(String, Array[Decl])
  Protocol(String, Array[Decl])
  Extension(Type, String, Array[Decl]) 
} derive(Show)

enum Stmt {
  Decl(Decl)
  Expr(Expr)
} derive(Show)

enum StmtList {
  Stmt(Stmt)
  StmtList(Stmt, StmtList)
} derive(Show)

type Program = StmtList

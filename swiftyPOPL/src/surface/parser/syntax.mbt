pub enum Type {
  Int
  Bool
  String
  Unit
  Self
  UDT(String)
  Function(Array[TypeParam], Array[ParamSig], Type) 
} derive(Show, Hash, Eq)

pub enum ArgExpr {
  Positional(Expr)
  Named(String, Expr)
} derive(Show)

pub enum ParamDecl {
  ParamDecl(Option[String], String, Type)
} derive(Show)

pub enum ParamSig {
  ParamSig(Option[String], Type)
} derive(Show, Hash, Eq)

pub enum TypeParam {
  Generic(String)
  Constrained(String, Array[Type])
} derive(Show, Hash, Eq)

pub enum FuncSig {
  Sig(String, Array[TypeParam], Array[ParamSig], Type)
} derive(Show, Hash, Eq)

pub enum Expr {
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
  Function(Array[TypeParam], Array[ParamDecl], Type, StmtList)
} derive(Show)

pub enum Decl {
  Variable(String, Type, Expr)
  FuncDef(String, Array[TypeParam], Array[ParamDecl], Type, StmtList)
  FuncDecl(FuncSig)
  Field(String, Type)
  StructDef(String, Array[Decl])
  StructDecl(String)
  Protocol(String, Array[Decl])
  Extension(Type, String, Array[Decl]) 
} derive(Show)


pub enum Stmt {
  Decl(Decl)
  Expr(Expr)
} derive(Show)

pub enum StmtList {
  Stmt(Stmt)
  StmtList(Stmt, StmtList)
} derive(Show)

pub type Program = StmtList

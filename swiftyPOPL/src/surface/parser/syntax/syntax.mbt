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
  IntLit(Info, Int)
  BoolLit(Info, Bool)
  StringLit(Info, String)
  Self(Info)
  Ident(Info, String)
  Call(Info, Expr, Array[ArgExpr])
  Construct(Info, String, Array[ArgExpr])
  GenericInst(Info, Expr, Array[Type]) 
  Access(Info, Expr, String)
  IfElse(Info, Expr, StmtList, StmtList)
  If(Info, Expr, StmtList)
  Function(Info, Array[TypeParam], Array[ParamDecl], Type, StmtList)
} derive(Show)

pub enum Decl {
  Variable(Info, String, Type, Expr)
  FuncDef(Info, String, Array[TypeParam], Array[ParamDecl], Type, StmtList)
  FuncDecl(Info, FuncSig)
  Field(Info, String, Type)
  StructDef(Info, String, Array[Decl])
  StructDecl(Info, String)
  Protocol(Info, String, Array[Decl])
  Extension(Info, Type, String, Array[Decl]) 
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

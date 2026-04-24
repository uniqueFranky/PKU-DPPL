pub(all) enum ResolvedType {
  Int
  Bool
  String
  Unit
  StructType(String)
  ProtocolType(String)
  TypeVariable(String)
  AbstractSelfType(String)
  Function(Array[ResolvedTypeParam], Array[ResolvedParamSig], ResolvedType)
} derive(Show)

pub(all) enum ResolvedTypeParam {
  Generic(String)
  Constrained(String, Array[ResolvedType])
} derive(Show)

pub(all) enum ResolvedParamDecl {
  ParamDecl(Option[String], String, ResolvedType)
} derive(Show)

pub(all) enum ResolvedParamSig {
  ParamSig(Option[String], ResolvedType)
} derive(Show)

pub(all) enum ResolvedFuncSig {
  Sig(String, Array[ResolvedTypeParam], Array[ResolvedParamSig], ResolvedType)
} derive(Show)

pub(all) enum ResolvedExpr {
  IntLit(Int)
  BoolLit(Bool)
  StringLit(String)
  Self
  Ident(String)
  Call(ResolvedExpr, Array[ResolvedArgExpr])
  Construct(String, Array[ResolvedArgExpr])
  GenericInst(ResolvedExpr, Array[ResolvedType])
  Access(ResolvedExpr, String)
  IfElse(ResolvedExpr, Array[ResolvedStmt], Array[ResolvedStmt])
  If(ResolvedExpr, Array[ResolvedStmt])
  Function(
    Array[ResolvedTypeParam],
    Array[ResolvedParamDecl],
    ResolvedType,
    Array[ResolvedStmt],
  )
} derive(Show)

pub(all) enum ResolvedArgExpr {
  Positional(ResolvedExpr)
  Named(String, ResolvedExpr)
} derive(Show)

pub(all) enum ResolvedDecl {
  Variable(String, ResolvedType, ResolvedExpr)
  Field(String, ResolvedType)
  FunctionDef(
    String,
    Array[ResolvedTypeParam],
    Array[ResolvedParamDecl],
    ResolvedType,
    Array[ResolvedStmt],
  )
  FunctionDecl(ResolvedFuncSig)
  MethodDef(
    String,
    Array[ResolvedTypeParam],
    Array[ResolvedParamDecl],
    ResolvedType,
    Array[ResolvedStmt],
  )
  MethodDecl(ResolvedFuncSig)
  StructDef(String, Array[ResolvedDecl])
  StructDecl(String)
  Protocol(String, Array[ResolvedDecl])
  Extension(String, String, Array[ResolvedDecl])
} derive(Show)

pub(all) enum ResolvedStmt {
  Decl(ResolvedDecl)
  Expr(ResolvedExpr)
} derive(Show)

pub struct ResolvedProgram {
  stmts : Array[ResolvedStmt]
  top_types : Array[(String, ResolvedType)]
} derive(Show)

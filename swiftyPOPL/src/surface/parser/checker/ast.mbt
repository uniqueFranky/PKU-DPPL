pub enum SymbolBinding {
  LocalValue(String)
  TopLevelValue(String)
  TypeParam(String)
} derive(Show)

pub enum CallResolution {
  FunctionCall(String)
  MethodCall(String, String)
  ConstructorCall(String)
  FunctionValueCall
} derive(Show)

pub enum MemberResolution {
  Field(String, String)
  Method(String, String)
} derive(Show)

pub enum TypedArgExpr {
  Positional(TypedExpr)
  Named(String, TypedExpr)
} derive(Show)

pub enum TypedExpr {
  IntLit(Int, @resolver.ResolvedType)
  BoolLit(Bool, @resolver.ResolvedType)
  StringLit(String, @resolver.ResolvedType)
  Self(@resolver.ResolvedType)
  Ident(String, SymbolBinding, @resolver.ResolvedType)
  Call(TypedExpr, Array[TypedArgExpr], CallResolution, @resolver.ResolvedType)
  Construct(String, Array[TypedArgExpr], @resolver.ResolvedType)
  GenericInst(TypedExpr, Array[@resolver.ResolvedType], @resolver.ResolvedType)
  Access(TypedExpr, String, MemberResolution, @resolver.ResolvedType)
  IfElse(TypedExpr, Array[TypedStmt], Array[TypedStmt], @resolver.ResolvedType)
  If(TypedExpr, Array[TypedStmt], @resolver.ResolvedType)
  Function(
    Array[@resolver.ResolvedTypeParam],
    Array[@resolver.ResolvedParamDecl],
    @resolver.ResolvedType,
    Array[TypedStmt],
    @resolver.ResolvedType,
  )
} derive(Show)

pub enum TypedDecl {
  Variable(String, @resolver.ResolvedType, TypedExpr)
  Field(String, @resolver.ResolvedType)
  FunctionDef(
    String,
    Array[@resolver.ResolvedTypeParam],
    Array[@resolver.ResolvedParamDecl],
    @resolver.ResolvedType,
    Array[TypedStmt],
  )
  FunctionDecl(@resolver.ResolvedFuncSig)
  MethodDef(
    String,
    Array[@resolver.ResolvedTypeParam],
    Array[@resolver.ResolvedParamDecl],
    @resolver.ResolvedType,
    Array[TypedStmt],
  )
  MethodDecl(@resolver.ResolvedFuncSig)
  StructDef(String, Array[TypedDecl])
  StructDecl(String)
  Protocol(String, Array[TypedDecl])
  Extension(String, String, Array[TypedDecl])
} derive(Show)

pub enum TypedStmt {
  Decl(TypedDecl)
  Expr(TypedExpr)
} derive(Show)

pub struct TypedProgram {
  stmts : Array[TypedStmt]
  top_types : Array[(String, @resolver.ResolvedType)]
} derive(Show)

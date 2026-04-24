priv suberror ResolveError {
  ResolveError(String)
}

fn fail[T](msg : String) -> T raise {
  raise ResolveError(msg)
}

priv enum Owner {
  TopLevel
  StructOwner(String)
  ProtocolOwner(String)
  ExtensionOwner(String)
}

fn empty_syntax_stmts() -> Array[@syntax.Stmt] {
  []
}

fn empty_syntax_decls() -> Array[@syntax.Decl] {
  []
}

fn empty_strings() -> Array[String] {
  []
}

fn empty_type_params() -> Array[ResolvedTypeParam] {
  []
}

fn empty_resolved_stmts() -> Array[ResolvedStmt] {
  []
}

fn empty_top_types() -> Array[(String, ResolvedType)] {
  []
}

fn contains(xs : Array[String], x : String) -> Bool {
  xs.any(fn(y) { y == x })
}

fn push_unique(xs : Array[String], x : String, what : String) -> Array[String] raise {
  if contains(xs, x) {
    fail("duplicate \{what} name \"\{x}\"")
  } else {
    xs.add([x])
  }
}

fn stmt_list_to_array(list : @syntax.StmtList) -> Array[@syntax.Stmt] {
  loop (list, empty_syntax_stmts()) {
    (@syntax.Stmt(s), acc) => break acc.add([s])
    (@syntax.StmtList(s, rest), acc) => continue (rest, acc.add([s]))
  }
}

fn stmt_array_to_decl_array(stmts : Array[@syntax.Stmt]) -> Array[@syntax.Decl] {
  loop (stmts, empty_syntax_decls()) {
    ([], acc) => break acc
    ([stmt, ..rest], acc) =>
      match stmt {
        @syntax.Expr(_) => continue ([..rest], acc)
        @syntax.Decl(d) => continue ([..rest], acc.add([d]))
      }
  }
}

fn func_sig_name(sig : @syntax.FuncSig) -> String {
  match sig {
    @syntax.Sig(name, _, _, _) => name
  }
}

fn decl_name_opt(decl : @syntax.Decl) -> String? {
  match decl {
    @syntax.Variable(_, name, _, _) => Some(name)
    @syntax.Field(_, name, _) => Some(name)
    @syntax.FuncDef(_, name, _, _, _, _) => Some(name)
    @syntax.FuncDecl(_, sig) => Some(func_sig_name(sig))
    @syntax.StructDef(_, name, _) => Some(name)
    @syntax.StructDecl(_, name) => Some(name)
    @syntax.Protocol(_, name, _) => Some(name)
    @syntax.Extension(_, _, _, _) => None
  }
}

fn ensure_unique_names(decls : Array[@syntax.Decl], what : String) -> Unit raise {
  loop (decls, empty_strings()) {
    ([], _) => ()
    ([decl, ..rest], seen) =>
      match decl_name_opt(decl) {
        None => continue ([..rest], seen)
        Some(name) => continue ([..rest], push_unique(seen, name, what))
      }
  }
}

fn collect_top_types(stmts : Array[@syntax.Stmt]) -> (Array[String], Array[String]) raise {
  let decls = stmt_array_to_decl_array(stmts)
  ensure_unique_names(decls, "top-level")
  loop (decls, empty_strings(), empty_strings()) {
    ([], structs, protocols) => break (structs, protocols)
    ([decl, ..rest], structs, protocols) =>
      match decl {
        @syntax.StructDef(_, name, _) => continue ([..rest], structs.add([name]), protocols)
        @syntax.StructDecl(_, name) => continue ([..rest], structs.add([name]), protocols)
        @syntax.Protocol(_, name, _) => continue ([..rest], structs, protocols.add([name]))
        _ => continue ([..rest], structs, protocols)
      }
  }
}

fn resolve_type_params(
  tparams : Array[@syntax.TypeParam],
  struct_names : Array[String],
  protocol_names : Array[String],
  owner : Owner,
  outer_type_vars : Array[String],
) -> (Array[ResolvedTypeParam], Array[String]) raise {
  loop (tparams, empty_type_params(), outer_type_vars, empty_strings()) {
    ([], resolved, vars, _) => break (resolved, vars)
    ([tparam, ..rest], resolved, vars, seen_names) =>
      match tparam {
        @syntax.Generic(name) => {
          if contains(seen_names, name) {
            fail("invalid type parameter \"\{name}\"")
          }
          if contains(struct_names, name) {
            fail("invalid type parameter \"\{name}\"")
          }
          if contains(protocol_names, name) {
            fail("invalid type parameter \"\{name}\"")
          }
          continue (
            [..rest],
            resolved.add([ResolvedTypeParam::Generic(name)]),
            vars.add([name]),
            seen_names.add([name]),
          )
        }
        @syntax.Constrained(name, constraints) => {
          if contains(seen_names, name) {
            fail("invalid type parameter \"\{name}\"")
          }
          if contains(struct_names, name) {
            fail("invalid type parameter \"\{name}\"")
          }
          if contains(protocol_names, name) {
            fail("invalid type parameter \"\{name}\"")
          }
          let vars2 = vars.add([name])
          let resolved_constraints = constraints.map(fn(c) {
            resolve_type(c, struct_names, protocol_names, owner, vars2, true)
          })
          continue (
            [..rest],
            resolved.add([ResolvedTypeParam::Constrained(name, resolved_constraints)]),
            vars2,
            seen_names.add([name]),
          )
        }
      }
  }
}

fn resolve_type(
  ty : @syntax.Type,
  struct_names : Array[String],
  protocol_names : Array[String],
  owner : Owner,
  type_vars : Array[String],
  allow_protocol_type : Bool,
) -> ResolvedType raise {
  match ty {
    @syntax.Int => ResolvedType::Int
    @syntax.Bool => ResolvedType::Bool
    @syntax.String => ResolvedType::String
    @syntax.Unit => ResolvedType::Unit
    @syntax.Self =>
      match owner {
        TopLevel => fail("Self is only valid in struct/protocol/extension scopes")
        StructOwner(name) => ResolvedType::StructType(name)
        ProtocolOwner(name) => ResolvedType::AbstractSelfType(name)
        ExtensionOwner(name) => ResolvedType::StructType(name)
      }
    @syntax.UDT(name) =>
      if contains(type_vars, name) {
        ResolvedType::TypeVariable(name)
      } else if contains(struct_names, name) {
        ResolvedType::StructType(name)
      } else if contains(protocol_names, name) {
        if allow_protocol_type {
          ResolvedType::ProtocolType(name)
        } else {
          fail("protocol type \"\{name}\" cannot be used as a value type")
        }
      } else {
        fail("undefined type \"\{name}\"")
      }
    @syntax.Function(tparams, params, ret) => {
      let (resolved_tparams, scoped_vars) = resolve_type_params(
        tparams,
        struct_names,
        protocol_names,
        owner,
        type_vars,
      )
      let resolved_params = params.map(fn(p) {
        match p {
          @syntax.ParamSig(label, pty) =>
            ResolvedParamSig::ParamSig(
              label,
              resolve_type(
                pty,
                struct_names,
                protocol_names,
                owner,
                scoped_vars,
                false,
              ),
            )
        }
      })
      ResolvedType::Function(
        resolved_tparams,
        resolved_params,
        resolve_type(ret, struct_names, protocol_names, owner, scoped_vars, false),
      )
    }
  }
}

fn resolve_expr(
  expr : @syntax.Expr,
  struct_names : Array[String],
  protocol_names : Array[String],
  owner : Owner,
  type_vars : Array[String],
) -> ResolvedExpr raise {
  match expr {
    @syntax.IntLit(_, i) => ResolvedExpr::IntLit(i)
    @syntax.BoolLit(_, b) => ResolvedExpr::BoolLit(b)
    @syntax.StringLit(_, s) => ResolvedExpr::StringLit(s)
    @syntax.Self(_) => ResolvedExpr::Self
    @syntax.Ident(_, name) => ResolvedExpr::Ident(name)
    @syntax.Call(_, f, args) =>
      ResolvedExpr::Call(
        resolve_expr(f, struct_names, protocol_names, owner, type_vars),
        args.map(fn(a) {
          match a {
            @syntax.Positional(e) =>
              ResolvedArgExpr::Positional(
                resolve_expr(e, struct_names, protocol_names, owner, type_vars),
              )
            @syntax.Named(label, e) =>
              ResolvedArgExpr::Named(
                label,
                resolve_expr(e, struct_names, protocol_names, owner, type_vars),
              )
          }
        }),
      )
    @syntax.Construct(_, name, args) =>
      ResolvedExpr::Construct(
        name,
        args.map(fn(a) {
          match a {
            @syntax.Positional(e) =>
              ResolvedArgExpr::Positional(
                resolve_expr(e, struct_names, protocol_names, owner, type_vars),
              )
            @syntax.Named(label, e) =>
              ResolvedArgExpr::Named(
                label,
                resolve_expr(e, struct_names, protocol_names, owner, type_vars),
              )
          }
        }),
      )
    @syntax.GenericInst(_, f, tys) =>
      ResolvedExpr::GenericInst(
        resolve_expr(f, struct_names, protocol_names, owner, type_vars),
        tys.map(fn(ty) {
          resolve_type(ty, struct_names, protocol_names, owner, type_vars, false)
        }),
      )
    @syntax.Access(_, base, name) =>
      ResolvedExpr::Access(resolve_expr(base, struct_names, protocol_names, owner, type_vars), name)
    @syntax.IfElse(_, cond, then_body, else_body) =>
      ResolvedExpr::IfElse(
        resolve_expr(cond, struct_names, protocol_names, owner, type_vars),
        resolve_stmt_array(
          stmt_list_to_array(then_body),
          struct_names,
          protocol_names,
          owner,
          type_vars,
        ).0,
        resolve_stmt_array(
          stmt_list_to_array(else_body),
          struct_names,
          protocol_names,
          owner,
          type_vars,
        ).0,
      )
    @syntax.If(_, cond, then_body) =>
      ResolvedExpr::If(
        resolve_expr(cond, struct_names, protocol_names, owner, type_vars),
        resolve_stmt_array(
          stmt_list_to_array(then_body),
          struct_names,
          protocol_names,
          owner,
          type_vars,
        ).0,
      )
    @syntax.Function(_, tparams, params, ret, body) => {
      let (resolved_tparams, scoped_vars) = resolve_type_params(
        tparams,
        struct_names,
        protocol_names,
        owner,
        type_vars,
      )
      let resolved_params = params.map(fn(p) {
        match p {
          @syntax.ParamDecl(label, name, ty) =>
            ResolvedParamDecl::ParamDecl(
              label,
              name,
              resolve_type(ty, struct_names, protocol_names, owner, scoped_vars, false),
            )
        }
      })
      ResolvedExpr::Function(
        resolved_tparams,
        resolved_params,
        resolve_type(ret, struct_names, protocol_names, owner, scoped_vars, false),
        resolve_stmt_array(
          stmt_list_to_array(body),
          struct_names,
          protocol_names,
          owner,
          scoped_vars,
        ).0,
      )
    }
  }
}

fn resolve_decl(
  decl : @syntax.Decl,
  struct_names : Array[String],
  protocol_names : Array[String],
  owner : Owner,
  type_vars : Array[String],
) -> (ResolvedDecl, Array[(String, ResolvedType)]) raise {
  match decl {
    @syntax.Variable(_, name, ty, expr) => {
      let resolved_ty = resolve_type(ty, struct_names, protocol_names, owner, type_vars, false)
      let top_types = match owner {
        TopLevel => [(name, resolved_ty)]
        _ => []
      }
      (
        ResolvedDecl::Variable(
          name,
          resolved_ty,
          resolve_expr(expr, struct_names, protocol_names, owner, type_vars),
        ),
        top_types,
      )
    }
    @syntax.Field(_, name, ty) => {
      let resolved_ty = resolve_type(ty, struct_names, protocol_names, owner, type_vars, false)
      let top_types = match owner {
        TopLevel => [(name, resolved_ty)]
        _ => []
      }
      (ResolvedDecl::Field(name, resolved_ty), top_types)
    }
    @syntax.FuncDef(_, name, tparams, params, ret, body) => {
      let (resolved_tparams, scoped_vars) = resolve_type_params(
        tparams,
        struct_names,
        protocol_names,
        owner,
        type_vars,
      )
      let resolved_params = params.map(fn(p) {
        match p {
          @syntax.ParamDecl(label, pname, pty) =>
            ResolvedParamDecl::ParamDecl(
              label,
              pname,
              resolve_type(pty, struct_names, protocol_names, owner, scoped_vars, false),
            )
        }
      })
      let resolved_ret = resolve_type(
        ret,
        struct_names,
        protocol_names,
        owner,
        scoped_vars,
        false,
      )
      let resolved_body = resolve_stmt_array(
        stmt_list_to_array(body),
        struct_names,
        protocol_names,
        owner,
        scoped_vars,
      ).0
      match owner {
        TopLevel => {
          let fn_ty = ResolvedType::Function(
            resolved_tparams,
            resolved_params.map(fn(p) {
              match p {
                ResolvedParamDecl::ParamDecl(label, _, pty) =>
                  ResolvedParamSig::ParamSig(label, pty)
              }
            }),
            resolved_ret,
          )
          (
            ResolvedDecl::FunctionDef(
              name,
              resolved_tparams,
              resolved_params,
              resolved_ret,
              resolved_body,
            ),
            [(name, fn_ty)],
          )
        }
        StructOwner(owner_name) => (
          ResolvedDecl::MethodDef(
            name,
            resolved_tparams,
            [ResolvedParamDecl::ParamDecl(None, "self", ResolvedType::StructType(owner_name))]
              .add(resolved_params),
            resolved_ret,
            resolved_body,
          ),
          [],
        )
        ProtocolOwner(owner_name) => (
          ResolvedDecl::MethodDef(
            name,
            resolved_tparams,
            [ResolvedParamDecl::ParamDecl(None, "self", ResolvedType::AbstractSelfType(owner_name))]
              .add(resolved_params),
            resolved_ret,
            resolved_body,
          ),
          [],
        )
        ExtensionOwner(owner_name) => (
          ResolvedDecl::MethodDef(
            name,
            resolved_tparams,
            [ResolvedParamDecl::ParamDecl(None, "self", ResolvedType::StructType(owner_name))]
              .add(resolved_params),
            resolved_ret,
            resolved_body,
          ),
          [],
        )
      }
    }
    @syntax.FuncDecl(_, sig) => {
      let (name, tparams, params, ret) = match sig {
        @syntax.Sig(n, tps, ps, r) => (n, tps, ps, r)
      }
      let (resolved_tparams, scoped_vars) = resolve_type_params(
        tparams,
        struct_names,
        protocol_names,
        owner,
        type_vars,
      )
      let resolved_params = params.map(fn(p) {
        match p {
          @syntax.ParamSig(label, pty) =>
            ResolvedParamSig::ParamSig(
              label,
              resolve_type(pty, struct_names, protocol_names, owner, scoped_vars, false),
            )
        }
      })
      let resolved_ret = resolve_type(
        ret,
        struct_names,
        protocol_names,
        owner,
        scoped_vars,
        false,
      )
      match owner {
        TopLevel => {
          let fn_ty = ResolvedType::Function(resolved_tparams, resolved_params, resolved_ret)
          (
            ResolvedDecl::FunctionDecl(
              ResolvedFuncSig::Sig(name, resolved_tparams, resolved_params, resolved_ret),
            ),
            [(name, fn_ty)],
          )
        }
        StructOwner(owner_name) => (
          ResolvedDecl::MethodDecl(
            ResolvedFuncSig::Sig(
              name,
              resolved_tparams,
              [ResolvedParamSig::ParamSig(None, ResolvedType::StructType(owner_name))]
                .add(resolved_params),
              resolved_ret,
            ),
          ),
          [],
        )
        ProtocolOwner(owner_name) => (
          ResolvedDecl::MethodDecl(
            ResolvedFuncSig::Sig(
              name,
              resolved_tparams,
              [ResolvedParamSig::ParamSig(None, ResolvedType::AbstractSelfType(owner_name))]
                .add(resolved_params),
              resolved_ret,
            ),
          ),
          [],
        )
        ExtensionOwner(owner_name) => (
          ResolvedDecl::MethodDecl(
            ResolvedFuncSig::Sig(
              name,
              resolved_tparams,
              [ResolvedParamSig::ParamSig(None, ResolvedType::StructType(owner_name))]
                .add(resolved_params),
              resolved_ret,
            ),
          ),
          [],
        )
      }
    }
    @syntax.StructDef(_, name, members) => {
      ensure_unique_names(members, "member")
      let resolved_members = members.map(fn(m) {
        resolve_decl(m, struct_names, protocol_names, StructOwner(name), type_vars).0
      })
      (ResolvedDecl::StructDef(name, resolved_members), [])
    }
    @syntax.StructDecl(_, name) => (ResolvedDecl::StructDecl(name), [])
    @syntax.Protocol(_, name, members) => {
      ensure_unique_names(members, "member")
      let resolved_members = members.map(fn(m) {
        resolve_decl(m, struct_names, protocol_names, ProtocolOwner(name), type_vars).0
      })
      (ResolvedDecl::Protocol(name, resolved_members), [])
    }
    @syntax.Extension(_, target_ty, protocol_name, members) => {
      if not(contains(protocol_names, protocol_name)) {
        fail("extension target protocol \"\{protocol_name}\" is undefined")
      }
      let target_resolved = resolve_type(
        target_ty,
        struct_names,
        protocol_names,
        TopLevel,
        type_vars,
        false,
      )
      let struct_name = match target_resolved {
        ResolvedType::StructType(n) => n
        _ => fail("extension target must be a struct type")
      }
      ensure_unique_names(members, "member")
      let resolved_members = members.map(fn(m) {
        resolve_decl(
          m,
          struct_names,
          protocol_names,
          ExtensionOwner(struct_name),
          type_vars,
        ).0
      })
      (ResolvedDecl::Extension(struct_name, protocol_name, resolved_members), [])
    }
  }
}

fn resolve_stmt_array(
  stmts : Array[@syntax.Stmt],
  struct_names : Array[String],
  protocol_names : Array[String],
  owner : Owner,
  type_vars : Array[String],
) -> (Array[ResolvedStmt], Array[(String, ResolvedType)]) raise {
  loop (stmts, empty_resolved_stmts(), empty_top_types()) {
    ([], resolved, top_types) => break (resolved, top_types)
    ([stmt, ..rest], resolved, top_types) =>
      match stmt {
        @syntax.Expr(expr) =>
          continue (
            [..rest],
            resolved.add([
              ResolvedStmt::Expr(
                resolve_expr(expr, struct_names, protocol_names, owner, type_vars),
              ),
            ]),
            top_types,
          )
        @syntax.Decl(decl) => {
          let (resolved_decl, decl_top_types) = resolve_decl(
            decl,
            struct_names,
            protocol_names,
            owner,
            type_vars,
          )
          continue (
            [..rest],
            resolved.add([ResolvedStmt::Decl(resolved_decl)]),
            top_types.add(decl_top_types),
          )
        }
      }
  }
}

pub fn resolve(program : @syntax.Program) -> ResolvedProgram raise {
  let stmts = stmt_list_to_array(program)
  let (struct_names, protocol_names) = collect_top_types(stmts)
  let (resolved_stmts, top_types) = resolve_stmt_array(
    stmts,
    struct_names,
    protocol_names,
    TopLevel,
    empty_strings(),
  )
  { stmts: resolved_stmts, top_types }
}

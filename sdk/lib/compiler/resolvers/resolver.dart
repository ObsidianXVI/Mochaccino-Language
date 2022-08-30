library mochaccino.sdk.compiler.resolver;

import 'package:mochaccino_sdk/sdk.dart';
import 'package:mochaccino_sdk/barista/lib/interface/interface.dart';

part './name_resolver.dart';
part './type_resolver.dart';

enum StructType {
  none,
  struct,
  substruct,
}

enum FunctionType {
  none,
  function,
  method,
  initialiser,
}

class Stack<E> {
  final List<E> stack = [];

  bool get isEmpty => stack.isEmpty;
  int get size => stack.length;

  void push(E element) => stack.add(element);
  E pop() => stack.removeLast();
  E peek() => stack.last;
  E get(int index) => stack[index];
}

abstract class Resolver {
  final Interpreter _interpreter;

  Resolver(this._interpreter);

  void resolve(List<Statement> statements) {
    for (Statement statement in statements) {
      resolveStmt(statement);
    }
  }

  void resolveStmt(Statement stmt) {
    if (stmt is InitialiserStmt) {
      resolveVarStmt(stmt);
    } else if (stmt is FuncDecl) {
      resolveFuncDecl(stmt);
    } else if (stmt is ExpressionStmt) {
      resolveExpressionStmt(stmt);
    } else if (stmt is IfStmt) {
      resolveIfStmt(stmt);
    } else if (stmt is ReturnStmt) {
      resolveReturnStmt(stmt);
    } else if (stmt is WhileStmt) {
      resolveWhileStmt(stmt);
    } else if (stmt is StructDecl) {
      resolveStructDecl(stmt);
    }
  }

  void resolveVarStmt(InitialiserStmt stmt);

  void resolveFuncDecl(FuncDecl stmt);

  void resolveExpressionStmt(ExpressionStmt stmt);

  void resolveIfStmt(IfStmt stmt);

  void resolveReturnStmt(ReturnStmt stmt);

  void resolveWhileStmt(WhileStmt stmt);

  void resolveStructDecl(StructDecl stmt);

  void resolveBlockStmt(BlockStmt stmt);

  void resolveExpression(Expression expr) {
    if (expr is VariableReference) {
      resolveVariableReference(expr);
    } else if (expr is VariableAssignment) {
      resolveVariableAssignment(expr);
    } else if (expr is BinaryExp) {
      resolveBinaryExpr(expr);
    } else if (expr is InvocationExpression) {
      resolveInvocationExpr(expr);
    } else if (expr is Group) {
      resolveGroupExpr(expr);
    } else if (expr is LogicalExp) {
      resolveLogicalExpr(expr);
    } else if (expr is UnaryExp) {
      resolveUnaryExpr(expr);
    } else if (expr is GetExpression) {
      resolveGetExpression(expr);
    } else if (expr is SetExpression) {
      resolveSetExpression(expr);
    } else if (expr is ThisReference) {
      resolveThisReference(expr);
    } else if (expr is SuperReference) {
      resolveSuperReference(expr);
    }
  }

  void resolveVariableReference(VariableReference expr);
  void resolveVariableAssignment(VariableAssignment expr);
  void resolveBinaryExpr(BinaryExp expr);
  void resolveInvocationExpr(InvocationExpression expr);
  void resolveGroupExpr(Group expr);
  void resolveLogicalExpr(LogicalExp expr);
  void resolveUnaryExpr(UnaryExp expr);
  void resolveGetExpression(GetExpression expr);
  void resolveSetExpression(SetExpression expr);
  void resolveThisReference(ThisReference expr);
  void resolveSuperReference(SuperReference expr);
}

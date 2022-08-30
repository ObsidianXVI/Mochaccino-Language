final String src = """
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
""";
void main() {
  final List<String> lines = src.split('\n');
  lines.forEach((String ln) {
    if (ln.trim().startsWith('resolve')) {
      final String exprType =
          ln.trim().replaceAll('resolve', '').replaceAll('(expr);', '');
      print('void ${ln.trim().replaceAll('(expr);', '')}($exprType expr);');
    }
  });
}

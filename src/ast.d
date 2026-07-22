module ast;

import std.conv;
import std.string;

abstract class ASTNode {
    abstract string toC();
}

class NumberNode : ASTNode {
    double val;
    bool isFloat;
    this(double val, bool isFloat = false) { this.val = val; this.isFloat = isFloat; }
    override string toC() { return isFloat ? to!string(val) : to!string(cast(long)val); }
}

class StringNode : ASTNode {
    string val;
    this(string val) { this.val = val; }
    override string toC() { return "\"" ~ val ~ "\""; }
}

class BoolNode : ASTNode {
    bool val;
    this(bool val) { this.val = val; }
    override string toC() { return val ? "true" : "false"; }
}

class VarNode : ASTNode {
    string name;
    this(string name) { this.name = name; }
    override string toC() { return name; }
}

class BinaryOpNode : ASTNode {
    string op;
    ASTNode left, right;
    this(string op, ASTNode left, ASTNode right) { this.op = op; this.left = left; this.right = right; }
    override string toC() { return "(" ~ left.toC() ~ " " ~ op ~ " " ~ right.toC() ~ ")"; }
}

class UnaryOpNode : ASTNode {
    string op;
    ASTNode expr;
    this(string op, ASTNode expr) { this.op = op; this.expr = expr; }
    override string toC() { return "(" ~ op ~ expr.toC() ~ ")"; }
}

class AssignNode : ASTNode {
    string name;
    ASTNode expr;
    ASTNode index;
    this(string name, ASTNode expr, ASTNode index = null) { this.name = name; this.expr = expr; this.index = index; }
    override string toC() {
        if (index !is null) return name ~ "[" ~ index.toC() ~ "] = " ~ expr.toC() ~ ";";
        return name ~ " = " ~ expr.toC() ~ ";";
    }
}

class CompoundAssignNode : ASTNode {
    string name, op;
    ASTNode expr;
    this(string name, string op, ASTNode expr) { this.name = name; this.op = op; this.expr = expr; }
    override string toC() { return name ~ " " ~ op ~ " " ~ expr.toC() ~ ";"; }
}

class ListNode : ASTNode {
    ASTNode[] elems;
    this(ASTNode[] elems) { this.elems = elems; }
    override string toC() {
        string res = "{";
        foreach (i, e; elems) { res ~= e.toC(); if (i < elems.length - 1) res ~= ", "; }
        return res ~ "}";
    }
}

class TupleNode : ASTNode {
    ASTNode[] elems;
    this(ASTNode[] elems) { this.elems = elems; }
    override string toC() {
        string res = "{";
        foreach (i, e; elems) { res ~= e.toC(); if (i < elems.length - 1) res ~= ", "; }
        return res ~ "}";
    }
}

class DictNode : ASTNode {
    ASTNode[] keys, values;
    this(ASTNode[] keys, ASTNode[] values) { this.keys = keys; this.values = values; }
    override string toC() { return "/* PyDict initialization */ NULL"; }
}

class SetNode : ASTNode {
    ASTNode[] elems;
    this(ASTNode[] elems) { this.elems = elems; }
    override string toC() { return "/* PySet initialization */ NULL"; }
}

class ListCompNode : ASTNode {
    ASTNode expr;
    string varName;
    ASTNode iterExpr;
    this(ASTNode expr, string varName, ASTNode iterExpr) {
        this.expr = expr; this.varName = varName; this.iterExpr = iterExpr;
    }
    override string toC() { return "/* List Comprehension */ NULL"; }
}

class IndexNode : ASTNode {
    string name;
    ASTNode index;
    this(string name, ASTNode index) { this.name = name; this.index = index; }
    override string toC() { return name ~ "[" ~ index.toC() ~ "]"; }
}

class CallNode : ASTNode {
    string name;
    ASTNode[] args;
    this(string name, ASTNode[] args) { this.name = name; this.args = args; }
    override string toC() {
        if (name == "len") return "(sizeof(" ~ args[0].toC() ~ ")/sizeof(" ~ args[0].toC() ~ "[0]))";
        if (name == "print") {
            string res = "printf(";
            foreach(i, a; args) { res ~= a.toC(); if(i < args.length - 1) res ~= ", "; }
            return res ~ ")";
        }
        if (name == "input") return "py_input()";
        string res = name ~ "(";
        foreach (i, a; args) { res ~= a.toC(); if (i < args.length - 1) res ~= ", "; }
        return res ~ ")";
    }
}

class MemberAccessNode : ASTNode {
    ASTNode obj;
    string member;
    this(ASTNode obj, string member) { this.obj = obj; this.member = member; }
    override string toC() { return obj.toC() ~ "." ~ member; }
}

class MethodCallNode : ASTNode {
    ASTNode obj;
    string method;
    ASTNode[] args;
    this(ASTNode obj, string method, ASTNode[] args) {
        this.obj = obj; this.method = method; this.args = args;
    }
    override string toC() {
        if (method == "append") return "py_list_append(&" ~ obj.toC() ~ ", " ~ args[0].toC() ~ ")";
        string res = obj.toC() ~ "_" ~ method ~ "(&" ~ obj.toC();
        foreach(a; args) { res ~= ", " ~ a.toC(); }
        return res ~ ")";
    }
}

class IfNode : ASTNode {
    ASTNode cond;
    ASTNode[] thenB, elseB;
    this(ASTNode cond, ASTNode[] thenB, ASTNode[] elseB) { this.cond = cond; this.thenB = thenB; this.elseB = elseB; }
    override string toC() {
        string res = "if (" ~ cond.toC() ~ ") {\n";
        foreach (s; thenB) res ~= "    " ~ s.toC() ~ "\n";
        res ~= "}";
        if (elseB.length > 0) {
            res ~= " else {\n";
            foreach (s; elseB) res ~= "    " ~ s.toC() ~ "\n";
            res ~= "}";
        }
        return res;
    }
}

class WhileNode : ASTNode {
    ASTNode cond;
    ASTNode[] body;
    this(ASTNode cond, ASTNode[] body) { this.cond = cond; this.body = body; }
    override string toC() {
        string res = "while (" ~ cond.toC() ~ ") {\n";
        foreach (s; body) res ~= "    " ~ s.toC() ~ "\n";
        return res ~ "}";
    }
}

class ForNode : ASTNode {
    string varName;
    ASTNode startExpr, stopExpr;
    ASTNode[] body;
    this(string varName, ASTNode startExpr, ASTNode stopExpr, ASTNode[] body) {
        this.varName = varName; this.startExpr = startExpr; this.stopExpr = stopExpr; this.body = body;
    }
    override string toC() {
        string res = "for (int " ~ varName ~ " = " ~ startExpr.toC() ~ "; " ~ varName ~ " < " ~ stopExpr.toC() ~ "; " ~ varName ~ "++) {\n";
        foreach (s; body) res ~= "    " ~ s.toC() ~ "\n";
        return res ~ "}";
    }
}

class FunctionDefNode : ASTNode {
    string name;
    string[] params;
    ASTNode[] body;
    this(string name, string[] params, ASTNode[] body) { this.name = name; this.params = params; this.body = body; }
    override string toC() {
        string res = "void " ~ name ~ "(";
        foreach (i, p; params) { res ~= "int " ~ p; if (i < params.length - 1) res ~= ", "; }
        res ~= ") {\n";
        foreach (s; body) res ~= "    " ~ s.toC() ~ "\n";
        return res ~ "}";
    }
}

class ClassDefNode : ASTNode {
    string name, parentName;
    ASTNode[] body;
    this(string name, string parentName, ASTNode[] body) {
        this.name = name; this.parentName = parentName; this.body = body;
    }
    override string toC() {
        string res = "typedef struct {\n";
        if (parentName.length > 0) res ~= "    " ~ parentName ~ " base;\n";
        res ~= "} " ~ name ~ ";\n";
        foreach (s; body) res ~= s.toC() ~ "\n";
        return res;
    }
}

class ReturnNode : ASTNode {
    ASTNode expr;
    this(ASTNode expr) { this.expr = expr; }
    override string toC() { return "return " ~ (expr ? expr.toC() : "") ~ ";"; }
}

class BreakNode : ASTNode { override string toC() { return "break;"; } }
class ContinueNode : ASTNode { override string toC() { return "continue;"; } }
class PassNode : ASTNode { override string toC() { return "/* pass */;"; } }

class ImportNode : ASTNode {
    string modName, aliasName;
    this(string modName, string aliasName = "") { this.modName = modName; this.aliasName = aliasName; }
    override string toC() { return "#include \"" ~ modName ~ ".h\""; }
}

class RaiseNode : ASTNode {
    ASTNode expr;
    this(ASTNode expr) { this.expr = expr; }
    override string toC() { return "py_raise(" ~ expr.toC() ~ ");"; }
}

class TryExceptNode : ASTNode {
    ASTNode[] tryBody, exceptBody, finallyBody;
    this(ASTNode[] tryBody, ASTNode[] exceptBody, ASTNode[] finallyBody = []) {
        this.tryBody = tryBody; this.exceptBody = exceptBody; this.finallyBody = finallyBody;
    }
    override string toC() {
        string res = "if (setjmp(py_exception_env) == 0) {\n";
        foreach (s; tryBody) res ~= "    " ~ s.toC() ~ "\n";
        res ~= "} else {\n";
        foreach (s; exceptBody) res ~= "    " ~ s.toC() ~ "\n";
        res ~= "}";
        if (finallyBody.length > 0) {
            res ~= " {\n";
            foreach (s; finallyBody) res ~= "    " ~ s.toC() ~ "\n";
            res ~= "}";
        }
        return res;
    }
}

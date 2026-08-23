module codegen;

import ast;
import std.string;
import std.conv;
import std.array;

class CCodegen {
    private string[] textSection;
    private string[string] variableTypes;
    private int[string] arraySizes;
    private int listCounter = 0;
    private string[] globalDeclarations;
    private string[] mainAssignments;
    private string[] mainStmts;
    private string[] functionDefs;
    private string[] includes;
    private string[string] arrayNames;

    this() {
        textSection ~= "#include <tice.h>";
        textSection ~= "#include <ti/screen.h>";
        textSection ~= "#include <stdio.h>";
        textSection ~= "#include <stdlib.h>";
        textSection ~= "#include <stdbool.h>";
        textSection ~= "#include <string.h>";
        textSection ~= "#include <keypadc.h>";
        textSection ~= "#include <setjmp.h>";
        textSection ~= "#include <math.h>";
        textSection ~= "#ifndef RAND_MAX";
        textSection ~= "#define RAND_MAX 32767";
        textSection ~= "#endif";
        textSection ~= "jmp_buf py_exception_env;";
        textSection ~= "void py_raise(int err) { longjmp(py_exception_env, err); }";
        textSection ~= "typedef enum {";
        textSection ~= "    PY_INT,";
        textSection ~= "    PY_FLOAT,";
        textSection ~= "    PY_STRING,";
        textSection ~= "    PY_LIST,";
        textSection ~= "    PY_TUPLE,";
        textSection ~= "    PY_BOOL";
        textSection ~= "} PyType;";
        textSection ~= "typedef struct {";
        textSection ~= "    PyType type;";
        textSection ~= "    union {";
        textSection ~= "        long i;";
        textSection ~= "        double f;";
        textSection ~= "        const char* s;";
        textSection ~= "        void* l;";
        textSection ~= "        bool b;";
        textSection ~= "    };";
        textSection ~= "} PyValue;";
        textSection ~= "char* py_input(void) {";
        textSection ~= "    static char buf[64];";
        textSection ~= "    memset(buf, 0, sizeof(buf));";
        textSection ~= "    os_GetStringInput(\":\", buf, sizeof(buf) - 1);";
        textSection ~= "    return buf;";
        textSection ~= "}";
        textSection ~= "static char py_str_bufs[4][256];";
        textSection ~= "static int py_str_buf_idx = 0;";
        textSection ~= "char* py_str_concat(const char* s1, const char* s2) {";
        textSection ~= "    py_str_buf_idx = (py_str_buf_idx + 1) % 4;";
        textSection ~= "    char* buf = py_str_bufs[py_str_buf_idx];";
        textSection ~= "    buf[0] = '\\0';";
        textSection ~= "    strncat(buf, s1, 255);";
        textSection ~= "    strncat(buf, s2, 255 - strlen(buf));";
        textSection ~= "    return buf;";
        textSection ~= "}";
        textSection ~= "PyValue py_add(PyValue a, PyValue b) {";
        textSection ~= "    if (a.type == PY_INT && b.type == PY_INT) return (PyValue){PY_INT, .i = a.i + b.i};";
        textSection ~= "    if (a.type == PY_FLOAT && b.type == PY_FLOAT) return (PyValue){PY_FLOAT, .f = a.f + b.f};";
        textSection ~= "    if (a.type == PY_INT && b.type == PY_FLOAT) return (PyValue){PY_FLOAT, .f = (double)a.i + b.f};";
        textSection ~= "    if (a.type == PY_FLOAT && b.type == PY_INT) return (PyValue){PY_FLOAT, .f = a.f + (double)b.i};";
        textSection ~= "    if (a.type == PY_STRING) return (PyValue){PY_STRING, .s = py_str_concat(a.s, b.s)};";
        textSection ~= "    return (PyValue){PY_INT, .i = 0};";
        textSection ~= "}";
        textSection ~= "PyValue py_sub(PyValue a, PyValue b) {";
        textSection ~= "    if (a.type == PY_INT && b.type == PY_INT) return (PyValue){PY_INT, .i = a.i - b.i};";
        textSection ~= "    if (a.type == PY_FLOAT && b.type == PY_FLOAT) return (PyValue){PY_FLOAT, .f = a.f - b.f};";
        textSection ~= "    if (a.type == PY_INT && b.type == PY_FLOAT) return (PyValue){PY_FLOAT, .f = (double)a.i - b.f};";
        textSection ~= "    if (a.type == PY_FLOAT && b.type == PY_INT) return (PyValue){PY_FLOAT, .f = a.f - (double)b.i};";
        textSection ~= "    return (PyValue){PY_INT, .i = 0};";
        textSection ~= "}";
        textSection ~= "PyValue py_mul(PyValue a, PyValue b) {";
        textSection ~= "    if (a.type == PY_INT && b.type == PY_INT) return (PyValue){PY_INT, .i = a.i * b.i};";
        textSection ~= "    if (a.type == PY_FLOAT && b.type == PY_FLOAT) return (PyValue){PY_FLOAT, .f = a.f * b.f};";
        textSection ~= "    if (a.type == PY_INT && b.type == PY_FLOAT) return (PyValue){PY_FLOAT, .f = (double)a.i * b.f};";
        textSection ~= "    if (a.type == PY_FLOAT && b.type == PY_INT) return (PyValue){PY_FLOAT, .f = a.f * (double)b.i};";
        textSection ~= "    return (PyValue){PY_INT, .i = 0};";
        textSection ~= "}";
        textSection ~= "PyValue py_div(PyValue a, PyValue b) {";
        textSection ~= "    if (a.type == PY_INT && b.type == PY_INT) return (PyValue){PY_INT, .i = a.i / b.i};";
        textSection ~= "    if (a.type == PY_FLOAT && b.type == PY_FLOAT) return (PyValue){PY_FLOAT, .f = a.f / b.f};";
        textSection ~= "    if (a.type == PY_INT && b.type == PY_FLOAT) return (PyValue){PY_FLOAT, .f = (double)a.i / b.f};";
        textSection ~= "    if (a.type == PY_FLOAT && b.type == PY_INT) return (PyValue){PY_FLOAT, .f = a.f / (double)b.i};";
        textSection ~= "    return (PyValue){PY_INT, .i = 0};";
        textSection ~= "}";
        textSection ~= "bool py_lt(PyValue a, PyValue b) {";
        textSection ~= "    if (a.type == PY_INT && b.type == PY_INT) return a.i < b.i;";
        textSection ~= "    if (a.type == PY_FLOAT && b.type == PY_FLOAT) return a.f < b.f;";
        textSection ~= "    return false;";
        textSection ~= "}";
        textSection ~= "bool py_gt(PyValue a, PyValue b) {";
        textSection ~= "    if (a.type == PY_INT && b.type == PY_INT) return a.i > b.i;";
        textSection ~= "    if (a.type == PY_FLOAT && b.type == PY_FLOAT) return a.f > b.f;";
        textSection ~= "    return false;";
        textSection ~= "}";
        textSection ~= "bool py_eq(PyValue a, PyValue b) {";
        textSection ~= "    if (a.type == PY_INT && b.type == PY_INT) return a.i == b.i;";
        textSection ~= "    if (a.type == PY_FLOAT && b.type == PY_FLOAT) return a.f == b.f;";
        textSection ~= "    if (a.type == PY_STRING) return strcmp(a.s, b.s) == 0;";
        textSection ~= "    return false;";
        textSection ~= "}";
        textSection ~= "bool py_ne(PyValue a, PyValue b) { return !py_eq(a, b); }";
        textSection ~= "bool py_le(PyValue a, PyValue b) { return py_lt(a, b) || py_eq(a, b); }";
        textSection ~= "bool py_ge(PyValue a, PyValue b) { return py_gt(a, b) || py_eq(a, b); }";
    }

    public string getSourceCode() {
        return textSection.join("\n");
    }

    private void trackVar(string varName, string type = "int") {
        if (varName !in variableTypes) {
            if (type == "int_array") type = "PyValue_array";
            variableTypes[varName] = type;
        }
    }

    private bool isStringExpr(ASTNode node) {
        if (node is null) return false;
        if (cast(StringNode)node) return true;
        if (auto var = cast(VarNode)node) {
            string* t = var.name in variableTypes;
            return t !is null && (*t == "const char*" || *t == "char*");
        }
        if (auto binOp = cast(BinaryOpNode)node) {
            return binOp.op == "+" && (isStringExpr(binOp.left) || isStringExpr(binOp.right));
        }
        if (auto call = cast(CallNode)node) {
            if (call.name == "input" || call.name == "str") return true;
        }
        return false;
    }

    private string getNextListId() {
        listCounter++;
        return "list_data_" ~ to!string(listCounter);
    }

    void generate(ASTNode[] ast) {
        variableTypes.clear();
        arraySizes.clear();
        arrayNames.clear();
        globalDeclarations = [];
        mainAssignments = [];
        mainStmts = [];
        functionDefs = [];
        includes = [];

        foreach (node; ast) {
            if (auto assign = cast(AssignNode)node) {
                if (cast(ListNode)assign.expr || cast(TupleNode)assign.expr) {
                    variableTypes[assign.name] = "PyValue_array";
                    auto listNode = cast(ListNode)assign.expr;
                    auto tupleNode = cast(TupleNode)assign.expr;
                    int size = listNode ? cast(int)listNode.elems.length : cast(int)tupleNode.elems.length;
                    arraySizes[assign.name] = size;
                    
                    string arrayName = getNextListId();
                    arrayNames[assign.name] = arrayName;
                    
                    auto elems = listNode ? listNode.elems : tupleNode.elems;
                    foreach (i, elem; elems) {
                        mainAssignments ~= assign.name ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ "; ";
                    }
                } else if (cast(DictNode)assign.expr || cast(SetNode)assign.expr) {
                    trackVar(assign.name, "void*");
                } else if (auto numNode = cast(NumberNode)assign.expr) {
                    trackVar(assign.name, numNode.isFloat ? "float" : "int");
                } else if (isStringExpr(assign.expr)) {
                    trackVar(assign.name, "const char*");
                } else if (auto callNode = cast(CallNode)assign.expr) {
                    if (callNode.name == "input" || callNode.name == "str") {
                        trackVar(assign.name, "const char*");
                    } else {
                        trackVar(assign.name, "int");
                    }
                } else if (auto mCall = cast(MethodCallNode)assign.expr) {
                    if (compileNode(mCall.obj) == "random" && mCall.method == "random") {
                        trackVar(assign.name, "float");
                    } else {
                        trackVar(assign.name, "int");
                    }
                } else {
                    trackVar(assign.name, "int");
                }
            } else if (auto compAssign = cast(CompoundAssignNode)node) {
                trackVar(compAssign.name, "int");
            } else if (auto forNode = cast(ForNode)node) {
                trackVar(forNode.varName, "int");
            }
        }

        foreach (node; ast) {
            if (cast(ImportNode)node) {
                string inc = compileNode(node);
                if (inc.length > 0) includes ~= inc;
            } else if (cast(FunctionDefNode)node || cast(ClassDefNode)node) {
                functionDefs ~= compileNode(node);
            } else if (auto assign = cast(AssignNode)node) {
                if (cast(ListNode)assign.expr || cast(TupleNode)assign.expr) continue;
                mainStmts ~= compileNode(node);
            } else {
                mainStmts ~= compileNode(node);
            }
        }

        foreach (inc; includes) textSection ~= inc ~ "\n";
        
        if (variableTypes.length > 0) {
            textSection ~= "";
            foreach (varName, type; variableTypes) {
                if (type == "PyValue_array") {
                    textSection ~= "PyValue " ~ varName ~ "[" ~ to!string(arraySizes[varName]) ~ "];\n";
                } else if (type == "const char*") {
                    textSection ~= "const char* " ~ varName ~ " = \"\";\n";
                } else if (type == "void*") {
                    textSection ~= "void* " ~ varName ~ " = NULL;\n";
                } else if (type == "PyValue") {
                    textSection ~= "PyValue " ~ varName ~ " = {PY_INT, .i = 0};\n";
                } else {
                    textSection ~= type ~ " " ~ varName ~ " = 0;\n";
                }
            }
            textSection ~= "";
        }

        foreach (decl; globalDeclarations) textSection ~= decl ~ "\n";
        
        foreach (fn; functionDefs) {
            textSection ~= fn ~ "\n";
        }

        textSection ~= "int main(void) {\n";
        textSection ~= "    os_ClrHome();\n";
        if (mainAssignments.length > 0) {
            foreach (assign; mainAssignments) {
                textSection ~= "    " ~ assign ~ "\n";
            }
            textSection ~= "";
        }

        foreach (stmt; mainStmts) {
            if (stmt.length > 0) {
                string line = stmt;
                if (!line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                textSection ~= "    " ~ line ~ "\n";
            }
        }

        textSection ~= "    while (!os_GetCSC());\n";
        textSection ~= "    return 0;\n";
        textSection ~= "}";
    }

    private string compileBlock(ASTNode[] nodes) {
        string code = "";
        foreach (stmt; nodes) {
            string line = compileNode(stmt);
            if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
            code ~= "        " ~ line ~ "\n";
        }
        return code;
    }

    private string compileNode(ASTNode node) {
        if (node is null) return "";

        if (auto num = cast(NumberNode)node) {
            return "(PyValue){" ~ (num.isFloat ? "PY_FLOAT, .f = " : "PY_INT, .i = ") ~ to!string(num.val) ~ "}";
        }
        else if (auto b = cast(BoolNode)node) {
            return "(PyValue){" ~ (b.val ? "PY_BOOL, .b = true" : "PY_BOOL, .b = false") ~ "}";
        }
        else if (auto strNode = cast(StringNode)node) {
            return "(PyValue){" ~ "PY_STRING, .s = " ~ "\"" ~ strNode.val ~ "\"" ~ "}";
        }
        else if (auto var = cast(VarNode)node) {
            return var.name;
        }
        else if (auto unOp = cast(UnaryOpNode)node) {
            return unOp.op ~ compileNode(unOp.expr);
        }
        else if (auto binOp = cast(BinaryOpNode)node) {
            if (binOp.op == "+" && (isStringExpr(binOp.left) || isStringExpr(binOp.right))) {
                if (cast(StringNode)binOp.left && cast(StringNode)binOp.right) {
                    auto lStr = cast(StringNode)binOp.left;
                    auto rStr = cast(StringNode)binOp.right;
                    return "(PyValue){" ~ "PY_STRING, .s = " ~ "\"" ~ lStr.val ~ rStr.val ~ "\"" ~ "}";
                }
                return "py_add(" ~ compileNode(binOp.left) ~ ", " ~ compileNode(binOp.right) ~ ")";
            }

            string left = compileNode(binOp.left);
            string right = compileNode(binOp.right);

            if (binOp.op == "-") return "py_sub(" ~ left ~ ", " ~ right ~ ")";
            if (binOp.op == "*") return "py_mul(" ~ left ~ ", " ~ right ~ ")";
            if (binOp.op == "/") return "py_div(" ~ left ~ ", " ~ right ~ ")";
            if (binOp.op == "<") return "py_lt(" ~ left ~ ", " ~ right ~ ")";
            if (binOp.op == ">") return "py_gt(" ~ left ~ ", " ~ right ~ ")";
            if (binOp.op == "==") return "py_eq(" ~ left ~ ", " ~ right ~ ")";
            if (binOp.op == "!=") return "py_ne(" ~ left ~ ", " ~ right ~ ")";
            if (binOp.op == "<=") return "py_le(" ~ left ~ ", " ~ right ~ ")";
            if (binOp.op == ">=") return "py_ge(" ~ left ~ ", " ~ right ~ ")";

            return left ~ " " ~ binOp.op ~ " " ~ right;
        }
        else if (auto listNode = cast(ListNode)node) {
            string arrayName = getNextListId();
            globalDeclarations ~= "PyValue " ~ arrayName ~ "[" ~ to!string(listNode.elems.length) ~ "];\n";
            foreach (i, elem; listNode.elems) {
                mainAssignments ~= arrayName ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ "; ";
            }
            return "(PyValue){" ~ "PY_LIST, .l = " ~ arrayName ~ "}";
        }
        else if (auto tupleNode = cast(TupleNode)node) {
            string arrayName = getNextListId();
            globalDeclarations ~= "PyValue " ~ arrayName ~ "[" ~ to!string(tupleNode.elems.length) ~ "];\n";
            foreach (i, elem; tupleNode.elems) {
                mainAssignments ~= arrayName ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ "; ";
            }
            return "(PyValue){" ~ "PY_TUPLE, .l = " ~ arrayName ~ "}";
        }
        else if (cast(DictNode)node || cast(SetNode)node || cast(ListCompNode)node) {
            return "NULL";
        }
        else if (auto indexNode = cast(IndexNode)node) {
            return indexNode.name ~ "[" ~ compileNode(indexNode.index) ~ "]";
        }
        else if (auto assign = cast(AssignNode)node) {
            if (cast(ListNode)assign.expr || cast(TupleNode)assign.expr) {
                // Handled in Pass 1
                return "";
            }
            if (assign.index !is null) {
                return assign.name ~ "[" ~ compileNode(assign.index) ~ "] = " ~ compileNode(assign.expr) ~ ";";
            }
            return assign.name ~ " = " ~ compileNode(assign.expr) ~ ";";
        }
        else if (auto compAssign = cast(CompoundAssignNode)node) {
            return compAssign.name ~ " " ~ compAssign.op ~ " " ~ compileNode(compAssign.expr) ~ ";";
        }
        else if (auto call = cast(CallNode)node) {
            if (call.name == "print") {
                string result = "";
                foreach (arg; call.args) {
                    if (isStringExpr(arg)) {
                        result ~= "printf(\"%s\\n\", " ~ compileNode(arg) ~ "); ";
                    } else if (auto numArg = cast(NumberNode)arg) {
                        result ~= numArg.isFloat ? "printf(\"%f\\n\", " ~ compileNode(arg) ~ "); " : "printf(\"%d\\n\", " ~ compileNode(arg) ~ "); ";
                    } else if (auto varArg = cast(VarNode)arg) {
                        string* t = varArg.name in variableTypes;
                        if (t !is null && (*t == "const char*" || *t == "char*")) {
                            result ~= "printf(\"%s\\n\", " ~ compileNode(arg) ~ "); ";
                        } else if (t !is null && (*t == "float" || *t == "double")) {
                            result ~= "printf(\"%f\\n\", " ~ compileNode(arg) ~ "); ";
                        } else {
                            result ~= "printf(\"%d\\n\", " ~ compileNode(arg) ~ "); ";
                        }
                    } else {
                        result ~= "printf(\"%d\\n\", " ~ compileNode(arg) ~ "); ";
                    }
                }
                return result;
            } else if (call.name == "len") {
                return "(sizeof(" ~ compileNode(call.args[0]) ~ ") / sizeof(" ~ compileNode(call.args[0]) ~ "[0]))";
            } else if (call.name == "input") {
                return "py_input()";
            } else {
                string argsList = "";
                foreach (i, arg; call.args) {
                    argsList ~= compileNode(arg) ~ (i + 1 < call.args.length ? ", " : "");
                }
                return call.name ~ "(" ~ argsList ~ ")";
            }
        }
        else if (auto mCall = cast(MethodCallNode)node) {
            if (compileNode(mCall.obj) == "random" && mCall.method == "random") {
                return "((float)rand() / (float)RAND_MAX)";
            }
            string argsList = "";
            foreach (i, arg; mCall.args) {
                argsList ~= compileNode(arg) ~ (i + 1 < mCall.args.length ? ", " : "");
            }
            return mCall.toC();
        }
        else if (auto returnNode = cast(ReturnNode)node) {
            return "return " ~ (returnNode.expr ? compileNode(returnNode.expr) : "");
        }
        else if (auto ifNode = cast(IfNode)node) {
            string code = "if (" ~ compileNode(ifNode.cond) ~ ") {\n";
            code ~= compileBlock(ifNode.thenB);
            code ~= "    }";
            if (ifNode.elseB.length > 0) {
                code ~= " else {\n";
                code ~= compileBlock(ifNode.elseB);
                code ~= "    }";
            }
            return code;
        }
        else if (auto whileNode = cast(WhileNode)node) {
            string code = "while (" ~ compileNode(whileNode.cond) ~ ") {\n";
            code ~= compileBlock(whileNode.body);
            code ~= "    }";
            return code;
        }
        else if (auto forNode = cast(ForNode)node) {
            string start = forNode.startExpr ? compileNode(forNode.startExpr) : "0";
            string stop = compileNode(forNode.stopExpr);
            string code = "for (" ~ forNode.varName ~ " = " ~ start ~ "; " ~ forNode.varName ~ " < " ~ stop ~ "; " ~ forNode.varName ~ "++) {\n";
            code ~= compileBlock(forNode.body);
            code ~= "    }";
            return code;
        }
        else if (auto fnDef = cast(FunctionDefNode)node) {
            string params = "";
            foreach (i, p; fnDef.params) {
                params ~= "int " ~ p ~ (i + 1 < fnDef.params.length ? ", " : "");
            }
            string code = "int " ~ fnDef.name ~ "(" ~ params ~ ") {\n";
            foreach (stmt; fnDef.body) {
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "    " ~ line ~ "\n";
            }
            code ~= "}";
            return code;
        }
        else if (auto classDef = cast(ClassDefNode)node) {
            string code = "typedef struct {\n";
            if (classDef.parentName.length > 0) {
                code ~= "    " ~ classDef.parentName ~ " base;\n";
            }
            code ~= "} " ~ classDef.name ~ ";\n";
            foreach (stmt; classDef.body) {
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= line ~ "\n";
            }
            return code;
        }
        else if (auto imp = cast(ImportNode)node) {
            if (imp.modName == "random") return "#include <stdlib.h>";
            if (imp.modName == "math") return "#include <math.h>";
            return "#include \"" ~ imp.modName ~ ".h\"";
        }
        else if (auto raise = cast(RaiseNode)node) {
            return "py_raise(" ~ compileNode(raise.expr) ~ ");";
        }
        else if (auto tryExcept = cast(TryExceptNode)node) {
            string code = "if (setjmp(py_exception_env) == 0) {\n";
            code ~= compileBlock(tryExcept.tryBody);
            code ~= "    } else {\n";
            code ~= compileBlock(tryExcept.exceptBody);
            code ~= "    }";
            if (tryExcept.finallyBody.length > 0) {
                code ~= " {\n";
                code ~= compileBlock(tryExcept.finallyBody);
                code ~= "    }";
            }
            return code;
        }
        return "";
    }
}

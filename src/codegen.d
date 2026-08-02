module codegen;

import ast;
import std.string;
import std.conv;
import std.array;

class CCodegen {
    private string[] textSection;
    private string[string] variableTypes;
    private int[string] arraySizes;

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
        textSection ~= "void py_list_append(void* list, int val) { (void)list; (void)val; }";
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
    }

    public string getSourceCode() {
        return textSection.join("\n");
    }

    private void trackVar(string varName, string type = "int") {
        if (varName !in variableTypes) {
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

    void generate(ASTNode[] ast) {
        foreach (node; ast) {
            if (auto assign = cast(AssignNode)node) {
                if (auto listNode = cast(ListNode)assign.expr) {
                    variableTypes[assign.name] = "int_array";
                    arraySizes[assign.name] = cast(int)listNode.elems.length;
                } else if (auto tupleNode = cast(TupleNode)assign.expr) {
                    variableTypes[assign.name] = "int_array";
                    arraySizes[assign.name] = cast(int)tupleNode.elems.length;
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

        string[] includes;
        string[] functionDefs;
        string[] mainStmts;

        foreach (node; ast) {
            if (cast(ImportNode)node) {
                string inc = compileNode(node);
                if (inc.length > 0) includes ~= inc;
            } else if (cast(FunctionDefNode)node || cast(ClassDefNode)node) {
                functionDefs ~= compileNode(node);
            } else {
                mainStmts ~= compileNode(node);
            }
        }

        foreach (inc; includes) {
            if (inc.length > 0) textSection ~= inc;
        }

        if (includes.length > 0) textSection ~= "";

        if (variableTypes.length > 0) {
            foreach (varName, type; variableTypes) {
                if (type == "int_array") {
                    textSection ~= "int " ~ varName ~ "[" ~ to!string(arraySizes[varName]) ~ "];";
                } else if (type == "const char*") {
                    textSection ~= "const char* " ~ varName ~ " = \"\";";
                } else if (type == "void*") {
                    textSection ~= "void* " ~ varName ~ " = NULL;";
                } else {
                    textSection ~= type ~ " " ~ varName ~ " = 0;";
                }
            }
            textSection ~= "";
        }

        foreach (fn; functionDefs) {
            textSection ~= fn;
            textSection ~= "";
        }

        textSection ~= "int main(void) {";
        textSection ~= "    os_ClrHome();";
        textSection ~= "";

        foreach (stmt; mainStmts) {
            if (stmt.length > 0) {
                string line = stmt;
                if (!line.endsWith(";") && !line.endsWith("}")) {
                    line ~= ";";
                }
                textSection ~= "    " ~ line;
            }
        }

        textSection ~= "";
        textSection ~= "    while (!os_GetCSC());";
        textSection ~= "    return 0;";
        textSection ~= "}";
    }

    private string compileNode(ASTNode node) {
        if (node is null) return "";

        if (auto num = cast(NumberNode)node) {
            return num.isFloat ? to!string(num.val) : to!string(cast(long)num.val);
        }
        else if (auto b = cast(BoolNode)node) {
            return b.val ? "true" : "false";
        }
        else if (auto strNode = cast(StringNode)node) {
            return "\"" ~ strNode.val ~ "\"";
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
                    return "\"" ~ lStr.val ~ rStr.val ~ "\"";
                }
                return "py_str_concat(" ~ compileNode(binOp.left) ~ ", " ~ compileNode(binOp.right) ~ ")";
            }
            return compileNode(binOp.left) ~ " " ~ binOp.op ~ " " ~ compileNode(binOp.right);
        }
        else if (auto listNode = cast(ListNode)node) {
            string res = "{";
            foreach (i, elem; listNode.elems) {
                res ~= compileNode(elem) ~ (i + 1 < listNode.elems.length ? ", " : "");
            }
            return res ~ "}";
        }
        else if (auto tupleNode = cast(TupleNode)node) {
            string res = "{";
            foreach (i, elem; tupleNode.elems) {
                res ~= compileNode(elem) ~ (i + 1 < tupleNode.elems.length ? ", " : "");
            }
            return res ~ "}";
        }
        else if (cast(DictNode)node) {
            return "NULL";
        }
        else if (cast(SetNode)node) {
            return "NULL";
        }
        else if (cast(ListCompNode)node) {
            return "NULL";
        }
        else if (auto indexNode = cast(IndexNode)node) {
            return indexNode.name ~ "[" ~ compileNode(indexNode.index) ~ "]";
        }
        else if (auto assign = cast(AssignNode)node) {
            if (auto listNode = cast(ListNode)assign.expr) {
                string initCode = "";
                foreach (i, elem; listNode.elems) {
                    initCode ~= assign.name ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ "; ";
                }
                return initCode;
            }
            if (auto tupleNode = cast(TupleNode)assign.expr) {
                string initCode = "";
                foreach (i, elem; tupleNode.elems) {
                    initCode ~= assign.name ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ "; ";
                }
                return initCode;
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
            return compileNode(mCall.obj) ~ "." ~ mCall.method ~ "(" ~ argsList ~ ")";
        }
        else if (auto returnNode = cast(ReturnNode)node) {
            return "return " ~ compileNode(returnNode.expr) ~ ";";
        }
        else if (auto ifNode = cast(IfNode)node) {
            string code = "if (" ~ compileNode(ifNode.cond) ~ ") {\n";
            foreach (stmt; ifNode.thenBody) {
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "        " ~ line ~ "\n";
            }
            code ~= "    }";
            foreach (elif; ifNode.elifs) {
                code ~= " else if (" ~ compileNode(elif.cond) ~ ") {\n";
                foreach (stmt; elif.bodyStmts) {
                    string line = compileNode(stmt);
                    if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                    code ~= "        " ~ line ~ "\n";
                }
                code ~= "    }";
            }
            if (ifNode.elseBody.length > 0) {
                code ~= " else {\n";
                foreach (stmt; ifNode.elseBody) {
                    string line = compileNode(stmt);
                    if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                    code ~= "        " ~ line ~ "\n";
                }
                code ~= "    }";
            }
            return code;
        }
        else if (auto whileNode = cast(WhileNode)node) {
            string code = "while (" ~ compileNode(whileNode.cond) ~ ") {\n";
            foreach (stmt; whileNode.bodyStmts) {
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "        " ~ line ~ "\n";
            }
            code ~= "    }";
            return code;
        }
        else if (auto forNode = cast(ForNode)node) {
            if (forNode.rangeStop !is null) {
                string start = forNode.rangeStart ? compileNode(forNode.rangeStart) : "0";
                string stop = compileNode(forNode.rangeStop);
                string step = forNode.rangeStep ? compileNode(forNode.rangeStep) : "1";
                string code = "for (" ~ forNode.varName ~ " = " ~ start ~ "; " ~ forNode.varName ~ " < " ~ stop ~ "; " ~ forNode.varName ~ " += " ~ step ~ ") {\n";
                foreach (stmt; forNode.bodyStmts) {
                    string line = compileNode(stmt);
                    if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                    code ~= "        " ~ line ~ "\n";
                }
                code ~= "    }";
                return code;
            }
        }
        else if (auto fnDef = cast(FunctionDefNode)node) {
            string params = "";
            foreach (i, p; fnDef.params) {
                params ~= "int " ~ p ~ (i + 1 < fnDef.params.length ? ", " : "");
            }
            string code = "int " ~ fnDef.name ~ "(" ~ params ~ ") {\n";
            foreach (stmt; fnDef.bodyStmts) {
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "    " ~ line ~ "\n";
            }
            code ~= "}";
            return code;
        }
        else if (auto classDef = cast(ClassDefNode)node) {
            string code = "typedef struct {\n";
            foreach (stmt; classDef.bodyStmts) {
                if (auto fn = cast(FunctionDefNode)stmt) {
                    code ~= "    // Method " ~ fn.name ~ "\n";
                }
            }
            code ~= "} " ~ classDef.name ~ ";";
            return code;
        }
        else if (auto imp = cast(ImportNode)node) {
            if (imp.modName == "random") return "#include <stdlib.h>";
            return "#include \"" ~ imp.modName ~ ".h\"";
        }
        else if (auto raise = cast(RaiseNode)node) {
            return "py_raise(" ~ compileNode(raise.expr) ~ ");";
        }
        else if (auto tryExcept = cast(TryExceptNode)node) {
            string code = "if (setjmp(py_exception_env) == 0) {\n";
            foreach (stmt; tryExcept.tryBody) {
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "        " ~ line ~ "\n";
            }
            code ~= "    } else {\n";
            foreach (stmt; tryExcept.exceptBody) {
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "        " ~ line ~ "\n";
            }
            code ~= "    }";
            if (tryExcept.finallyBody.length > 0) {
                code ~= " {\n";
                foreach (stmt; tryExcept.finallyBody) {
                    string line = compileNode(stmt);
                    if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                    code ~= "        " ~ line ~ "\n";
                }
                code ~= "    }";
            }
            return code;
        }
        return "";
    }
}

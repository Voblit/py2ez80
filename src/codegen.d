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
        textSection ~= "#include <stdio.h>";
        textSection ~= "#include <stdlib.h>";
        textSection ~= "#include <stdbool.h>";
        textSection ~= "#include <string.h>";
        textSection ~= "#include <keypadc.h>";
        textSection ~= "#include <setjmp.h>";
        textSection ~= "#include <math.h>";
        textSection ~= "";
        textSection ~= "// Prototypes & Helpers";
        textSection ~= "#ifndef RAND_MAX";
        textSection ~= "#define RAND_MAX 32767";
        textSection ~= "#endif";
        textSection ~= "int scanf(const char *format, ...);";
        textSection ~= "double sqrt(double x);";
        textSection ~= "";
        textSection ~= "// Polyfills & Runtime Support";
        textSection ~= "jmp_buf py_exception_env;";
        textSection ~= "void py_raise(int err) { longjmp(py_exception_env, err); }";
        textSection ~= "void py_list_append(void* list, int val) { (void)list; (void)val; }";
        textSection ~= "char* py_input(void) { static char buf[64]; scanf(\"%63s\", buf); return buf; }";
        textSection ~= "";
    }

    private void trackVar(string varName, string type = "int") {
        if (varName !in variableTypes) {
            variableTypes[varName] = type;
        }
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
                } else if (cast(StringNode)assign.expr) {
                    trackVar(assign.name, "const char*");
                } else if (auto callNode = cast(CallNode)assign.expr) {
                    if (callNode.name == "input") {
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
            textSection ~= "// Global Variables";
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
        textSection ~= "    // Wait for keypress before exiting";
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
                    if (cast(StringNode)arg) {
                        result ~= "printf(\"%s\\n\", " ~ compileNode(arg) ~ "); ";
                    } else if (auto numArg = cast(NumberNode)arg) {
                        result ~= numArg.isFloat ? "printf(\"%f\\n\", " ~ compileNode(arg) ~ "); " : "printf(\"%d\\n\", " ~ compileNode(arg) ~ "); ";
                    } else if (auto varArg = cast(VarNode)arg) {
                        string* t = varArg.name in variableTypes;
                        if (t !is null && (*t == "const char*")) {
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
        else if (auto member = cast(MemberAccessNode)node) {
            return compileNode(member.obj) ~ "." ~ member.member;
        }
        else if (auto mCall = cast(MethodCallNode)node) {
            string objName = compileNode(mCall.obj);
            if (objName == "math") {
                string argsList = "";
                foreach (i, arg; mCall.args) {
                    argsList ~= compileNode(arg) ~ (i + 1 < mCall.args.length ? ", " : "");
                }
                return mCall.method ~ "(" ~ argsList ~ ")";
            }
            if (objName == "random") {
                if (mCall.method == "randint") {
                    string a = compileNode(mCall.args[0]);
                    string b = compileNode(mCall.args[1]);
                    return "((rand() % ((" ~ b ~ ") - (" ~ a ~ ") + 1)) + (" ~ a ~ "))";
                }
                else if (mCall.method == "randrange") {
                    if (mCall.args.length == 1) {
                        string stop = compileNode(mCall.args[0]);
                        return "(rand() % (" ~ stop ~ "))";
                    } else if (mCall.args.length >= 2) {
                        string start = compileNode(mCall.args[0]);
                        string stop = compileNode(mCall.args[1]);
                        return "((" ~ start ~ ") + (rand() % ((" ~ stop ~ ") - (" ~ start ~ "))))";
                    }
                }
                else if (mCall.method == "random") {
                    return "((double)rand() / (double)RAND_MAX)";
                }
                else if (mCall.method == "seed") {
                    string seedVal = compileNode(mCall.args[0]);
                    return "srand((unsigned int)(" ~ seedVal ~ "))";
                }
            }
            if (mCall.method == "append") {
                return "py_list_append(&" ~ objName ~ ", " ~ compileNode(mCall.args[0]) ~ ")";
            }
            string argsList = "&" ~ objName;
            foreach (arg; mCall.args) {
                argsList ~= ", " ~ compileNode(arg);
            }
            return objName ~ "_" ~ mCall.method ~ "(" ~ argsList ~ ")";
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
        else if (auto ifNode = cast(IfNode)node) {
            string code = "if (" ~ compileNode(ifNode.cond) ~ ") {\n";
            foreach (stmt; ifNode.thenB) {
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "        " ~ line ~ "\n";
            }
            code ~= "    }";
            if (ifNode.elseB.length > 0) {
                code ~= " else {\n";
                foreach (stmt; ifNode.elseB) {
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
            foreach (stmt; whileNode.body) {
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "        " ~ line ~ "\n";
            }
            code ~= "    }";
            return code;
        }
        else if (auto forNode = cast(ForNode)node) {
            string code = "for (" ~ forNode.varName ~ " = " ~ compileNode(forNode.startExpr) ~ "; " ~
                          forNode.varName ~ " < " ~ compileNode(forNode.stopExpr) ~ "; " ~
                          forNode.varName ~ "++) {\n";
            foreach (stmt; forNode.body) {
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "        " ~ line ~ "\n";
            }
            code ~= "    }";
            return code;
        }
        else if (cast(BreakNode)node) return "break;";
        else if (cast(ContinueNode)node) return "continue;";
        else if (cast(PassNode)node) return "/* pass */;";
        else if (auto ret = cast(ReturnNode)node) {
            return "return " ~ (ret.expr ? compileNode(ret.expr) : "") ~ ";";
        }
        else if (auto fn = cast(FunctionDefNode)node) {
            string params = "";
            foreach (i, p; fn.params) {
                params ~= "int " ~ p ~ (i + 1 < fn.params.length ? ", " : "");
            }
            string code = "int " ~ fn.name ~ "(" ~ params ~ ") {\n";
            foreach (stmt; fn.body) {
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "    " ~ line ~ "\n";
            }
            code ~= "}";
            return code;
        }
        else if (auto imp = cast(ImportNode)node) {
            if (imp.modName == "math") return "#include <math.h>";
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

    string getSourceCode() {
        return textSection.join("\n");
    }
}

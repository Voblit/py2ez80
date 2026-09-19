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
    private string modulePrefix = "";


    private bool useHetero = false;
    private bool useException = false;
    private bool useListAppend = false;
    private bool useInput = false;
    private bool useStrConcat = false;

    this(string modulePrefix = "") {
        this.modulePrefix = modulePrefix;
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

    private string getNextListId() {
        listCounter++;
        return "list_data_" ~ to!string(listCounter);
    }

    private bool isHeterogeneousElems(ASTNode[] elems) {
        bool hasString = false;
        bool hasFloat = false;
        bool hasInt = false;
        bool hasNested = false;

        foreach (elem; elems) {
            if (auto subList = cast(ListNode)elem) {
                hasNested = true;
                if (isHeterogeneousElems(subList.elems)) return true;
            } else if (auto subTuple = cast(TupleNode)elem) {
                hasNested = true;
                if (isHeterogeneousElems(subTuple.elems)) return true;
            }
            if (cast(StringNode)elem) hasString = true;
            if (auto num = cast(NumberNode)elem) {
                if (num.isFloat) hasFloat = true;
                else hasInt = true;
            }
        }

        return hasNested || (hasString && (hasFloat || hasInt)) || (hasFloat && hasInt);
    }

    private void analyzeAST(ASTNode[] ast) {
        foreach (node; ast) {
            analyzeNode(node);
        }
    }

    private void analyzeNode(ASTNode node) {
        if (node is null) return;

        if (cast(RaiseNode)node || cast(TryExceptNode)node) {
            useException = true;
        }

        if (auto binOp = cast(BinaryOpNode)node) {
            if (binOp.op == "+" && (isStringExpr(binOp.left) || isStringExpr(binOp.right))) {
                if (!(cast(StringNode)binOp.left && cast(StringNode)binOp.right)) {
                    useStrConcat = true;
                }
            }
            analyzeNode(binOp.left);
            analyzeNode(binOp.right);
        }

        if (auto call = cast(CallNode)node) {
            if (call.name == "input") useInput = true;
            if (call.name == "append") useListAppend = true;
            foreach (arg; call.args) analyzeNode(arg);
        }

        if (auto mCall = cast(MethodCallNode)node) {
            if (mCall.method == "append") useListAppend = true;
            foreach (arg; mCall.args) analyzeNode(arg);
        }

        if (auto assign = cast(AssignNode)node) {
            analyzeNode(assign.expr);
            if (cast(ListNode)assign.expr || cast(TupleNode)assign.expr) {
                auto listNode = cast(ListNode)assign.expr;
                auto tupleNode = cast(TupleNode)assign.expr;
                auto elems = listNode ? listNode.elems : tupleNode.elems;
                
                if (isHeterogeneousElems(elems)) {
                    useHetero = true;
                }
            }
        }

        if (auto assign = cast(AssignNode)node) {
            if (cast(ListNode)assign.expr || cast(TupleNode)assign.expr) {
                auto listNode = cast(ListNode)assign.expr;
                auto tupleNode = cast(TupleNode)assign.expr;
                auto elems = listNode ? listNode.elems : tupleNode.elems;
                
                if (useHetero || isHeterogeneousElems(elems)) {
                    variableTypes[assign.name] = "PyValue_array";
                    arraySizes[assign.name] = cast(int)elems.length;
                } else {
                    bool hasString = false;
                    bool hasFloat = false;

                    foreach (elem; elems) {
                        if (cast(StringNode)elem) hasString = true;
                        if (auto num = cast(NumberNode)elem) {
                            if (num.isFloat) hasFloat = true;
                        }
                    }

                    if (hasString) {
                        variableTypes[assign.name] = "char*[]";
                    } else if (hasFloat) {
                        variableTypes[assign.name] = "double[]";
                    } else {
                        variableTypes[assign.name] = "int[]";
                    }
                    arraySizes[assign.name] = cast(int)elems.length;
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
                if (cast(VarNode)mCall.obj && (cast(VarNode)mCall.obj).name == "random" && mCall.method == "random") {
                    trackVar(assign.name, "float");
                } else {
                    trackVar(assign.name, "int");
                }
            } else {
                trackVar(assign.name, "int");
            }
        } else if (auto compAssign = cast(CompoundAssignNode)node) {
            trackVar(compAssign.name, "int");
            analyzeNode(compAssign.expr);
        } else if (auto forNode = cast(ForNode)node) {
            trackVar(forNode.varName, "int");
            if (forNode.startExpr) analyzeNode(forNode.startExpr);
            if (forNode.stopExpr) analyzeNode(forNode.stopExpr);
            foreach (stmt; forNode.body) analyzeNode(stmt);
        } else if (auto whileNode = cast(WhileNode)node) {
            analyzeNode(whileNode.cond);
            foreach (stmt; whileNode.body) analyzeNode(stmt);
        } else if (auto ifNode = cast(IfNode)node) {
            analyzeNode(ifNode.cond);
            foreach (stmt; ifNode.thenB) analyzeNode(stmt);
            foreach (stmt; ifNode.elseB) analyzeNode(stmt);
        } else if (auto fnDef = cast(FunctionDefNode)node) {
            foreach (stmt; fnDef.body) analyzeNode(stmt);
        } else if (auto tryExcept = cast(TryExceptNode)node) {
            foreach (stmt; tryExcept.tryBody) analyzeNode(stmt);
            foreach (stmt; tryExcept.exceptBody) analyzeNode(stmt);
            foreach (stmt; tryExcept.finallyBody) analyzeNode(stmt);
        }
    }

    void generate(ASTNode[] ast) {
        variableTypes.clear();
        arraySizes.clear();
        globalDeclarations = [];
        mainAssignments = [];
        mainStmts = [];
        functionDefs = [];
        includes = [];
        textSection = [];

        useHetero = false;
        useException = false;
        useListAppend = false;
        useInput = false;
        useStrConcat = false;

        analyzeAST(ast);

        textSection ~= "#include <tice.h>";
        textSection ~= "#include <ti/screen.h>";
        textSection ~= "#include <stdio.h>";
        textSection ~= "#include <stdlib.h>";
        textSection ~= "#include <stdbool.h>";
        textSection ~= "#include <string.h>";
        textSection ~= "#include <keypadc.h>";
        if (useException) textSection ~= "#include <setjmp.h>";
        textSection ~= "#include <math.h>";
        textSection ~= "";
        textSection ~= "#ifndef RAND_MAX";
        textSection ~= "#define RAND_MAX 32767";
        textSection ~= "#endif";
        textSection ~= "";

        if (useException) {
            textSection ~= "static jmp_buf py_exception_env;";
            textSection ~= "static void py_raise(int err) { (void)err; longjmp(py_exception_env, 1); }";
        }

        if (useListAppend) {
            textSection ~= "static void py_list_append(void* list, int val) { (void)list; (void)val; }";
        }

        if (useInput) {
            textSection ~= "static char* py_input(void) {";
            textSection ~= "    static char buf[64];";
            textSection ~= "    memset(buf, 0, sizeof(buf));";
            textSection ~= "    os_GetStringInput(\":\", buf, sizeof(buf) - 1);";
            textSection ~= "    return buf;";
            textSection ~= "}";
        }

        if (useStrConcat || useHetero) {
            textSection ~= "static char py_str_bufs[4][256];";
            textSection ~= "static int py_str_buf_idx = 0;";
            textSection ~= "static char* py_str_concat(const char* s1, const char* s2) {";
            textSection ~= "    py_str_buf_idx = (py_str_buf_idx + 1) % 4;";
            textSection ~= "    char* buf = py_str_bufs[py_str_buf_idx];";
            textSection ~= "    buf[0] = '\\0';";
            textSection ~= "    strncat(buf, s1, 255);";
            textSection ~= "    strncat(buf, s2, 255 - strlen(buf));";
            textSection ~= "    return buf;";
            textSection ~= "}";
        }

        foreach (node; ast) {
            if (auto assign = cast(AssignNode)node) {
                if (cast(ListNode)assign.expr || cast(TupleNode)assign.expr) {
                    auto listNode = cast(ListNode)assign.expr;
                    auto tupleNode = cast(TupleNode)assign.expr;
                    auto elems = listNode ? listNode.elems : tupleNode.elems;
                    
                    foreach (i, elem; elems) {
                        mainAssignments ~= assign.name ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ "; ";
                    }
                }
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

        if (useHetero) {
            textSection ~= "typedef enum { PY_INT, PY_FLOAT, PY_STRING, PY_LIST, PY_TUPLE, PY_BOOL } PyType;\n";
            textSection ~= "typedef struct { PyType type; int size; union { long i; double f; const char* s; void* l; bool b; }; } PyValue;\n";
            textSection ~= "static PyValue py_add(PyValue a, PyValue b) { if (a.type == PY_INT && b.type == PY_INT) return (PyValue){.type = PY_INT, .i = a.i + b.i}; if (a.type == PY_FLOAT && b.type == PY_FLOAT) return (PyValue){.type = PY_FLOAT, .f = a.f + b.f}; if (a.type == PY_INT && b.type == PY_FLOAT) return (PyValue){.type = PY_FLOAT, .f = (double)a.i + b.f}; if (a.type == PY_FLOAT && b.type == PY_INT) return (PyValue){.type = PY_FLOAT, .f = a.f + (double)b.i}; if (a.type == PY_STRING) return (PyValue){.type = PY_STRING, .s = py_str_concat(a.s, b.s)}; return (PyValue){.type = PY_INT, .i = 0}; }\n";
            textSection ~= "static PyValue py_sub(PyValue a, PyValue b) { if (a.type == PY_INT && b.type == PY_INT) return (PyValue){.type = PY_INT, .i = a.i - b.i}; if (a.type == PY_FLOAT && b.type == PY_FLOAT) return (PyValue){.type = PY_FLOAT, .f = a.f - b.f}; if (a.type == PY_INT && b.type == PY_FLOAT) return (PyValue){.type = PY_FLOAT, .f = (double)a.i - b.f}; if (a.type == PY_FLOAT && b.type == PY_INT) return (PyValue){.type = PY_FLOAT, .f = a.f - (double)b.i}; return (PyValue){.type = PY_INT, .i = 0}; }\n";
            textSection ~= "static PyValue py_mul(PyValue a, PyValue b) { if (a.type == PY_INT && b.type == PY_INT) return (PyValue){.type = PY_INT, .i = a.i * b.i}; if (a.type == PY_FLOAT && b.type == PY_FLOAT) return (PyValue){.type = PY_FLOAT, .f = a.f * b.f}; if (a.type == PY_INT && b.type == PY_FLOAT) return (PyValue){.type = PY_FLOAT, .f = (double)a.i * b.f}; if (a.type == PY_FLOAT && b.type == PY_INT) return (PyValue){.type = PY_FLOAT, .f = a.f * (double)b.i}; return (PyValue){.type = PY_INT, .i = 0}; }\n";
            textSection ~= "static PyValue py_div(PyValue a, PyValue b) { if (a.type == PY_INT && b.type == PY_INT) return (PyValue){.type = PY_INT, .i = a.i / b.i}; if (a.type == PY_FLOAT && b.type == PY_FLOAT) return (PyValue){.type = PY_FLOAT, .f = a.f / b.f}; if (a.type == PY_INT && b.type == PY_FLOAT) return (PyValue){.type = PY_FLOAT, .f = (double)a.i / b.f}; if (a.type == PY_FLOAT && b.type == PY_INT) return (PyValue){.type = PY_FLOAT, .f = a.f / (double)b.i}; return (PyValue){.type = PY_INT, .i = 0}; }\n";
            textSection ~= "static bool py_lt(PyValue a, PyValue b) { if (a.type == PY_INT && b.type == PY_INT) return a.i < b.i; if (a.type == PY_FLOAT && b.type == PY_FLOAT) return a.f < b.f; return false; }\n";
            textSection ~= "static bool py_gt(PyValue a, PyValue b) { if (a.type == PY_INT && b.type == PY_INT) return a.i > b.i; if (a.type == PY_FLOAT && b.type == PY_FLOAT) return a.f > b.f; return false; }\n";
            textSection ~= "static bool py_eq(PyValue a, PyValue b) { if (a.type == PY_INT && b.type == PY_INT) return a.i == b.i; if (a.type == PY_FLOAT && b.type == PY_FLOAT) return a.f == b.f; if (a.type == PY_STRING) return strcmp(a.s, b.s) == 0; return false; }\n";
            textSection ~= "static bool py_ne(PyValue a, PyValue b) { return !py_eq(a, b); }\n";
            textSection ~= "static bool py_le(PyValue a, PyValue b) { return py_lt(a, b) || py_eq(a, b); }\n";
            textSection ~= "static bool py_ge(PyValue a, PyValue b) { return py_gt(a, b) || py_eq(a, b); }\n";
            textSection ~= "static void py_print_value(PyValue v) { switch(v.type) { case PY_INT: printf(\"%d\\n\", (int)v.i); break; case PY_FLOAT: printf(\"%f\\n\", v.f); break; case PY_STRING: printf(\"%s\\n\", v.s); break; case PY_BOOL: printf(\"%s\\n\", v.b ? \"true\" : \"false\"); break; case PY_LIST: printf(\"[\"); for(int i = 0; i < v.size; i++) { py_print_value(((PyValue*)v.l)[i]); if (i < v.size - 1) printf(\", \"); }; printf(\"]\\n\"); break; case PY_TUPLE: printf(\"(\"); for(int i = 0; i < v.size; i++) { py_print_value(((PyValue*)v.l)[i]); if (i < v.size - 1) printf(\", \"); }; printf(\")\\n\"); break; default: printf(\"NULL\\n\"); break; } }\n";
        }
        
        if (variableTypes.length > 0) {
            textSection ~= "";
            foreach (varName, type; variableTypes) {
                if (type == "PyValue_array") {
                    textSection ~= "static PyValue " ~ varName ~ "[" ~ to!string(arraySizes[varName]) ~ "];\n";
                } else if (type == "char*[]") {
                    textSection ~= "static char* " ~ varName ~ "[" ~ to!string(arraySizes[varName]) ~ "];\n";
                } else if (type == "double[]") {
                    textSection ~= "static double " ~ varName ~ "[" ~ to!string(arraySizes[varName]) ~ "];\n";
                } else if (type == "int[]") {
                    textSection ~= "static int " ~ varName ~ "[" ~ to!string(arraySizes[varName]) ~ "];\n";
                } else if (type == "const char*") {
                    textSection ~= "static const char* " ~ varName ~ " = \"\";\n";
                } else if (type == "void*") {
                    textSection ~= "static void* " ~ varName ~ " = NULL;\n";
                } else if (type == "PyValue") {
                    textSection ~= "static PyValue " ~ varName ~ " = {.type = PY_INT, .i = 0};\n";
                } else {
                    textSection ~= "static " ~ type ~ " " ~ varName ~ " = 0;\n";
                }
            }
            textSection ~= "";
        }

        foreach (decl; globalDeclarations) textSection ~= decl ~ "\n";
        foreach (fn; functionDefs) textSection ~= fn ~ "\n";

        if (modulePrefix.length == 0) {
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
    }

    private string compileNode(ASTNode node) {
        if (node is null) return "";

        if (auto num = cast(NumberNode)node) {
            if (useHetero) {
                return "(PyValue){.type = " ~ (num.isFloat ? "PY_FLOAT, .f = " : "PY_INT, .i = ") ~ to!string(num.val) ~ "}";
            } else {
                return to!string(cast(long)num.val);
            }
        }
        else if (auto b = cast(BoolNode)node) {
            if (useHetero) {
                return "(PyValue){.type = PY_BOOL, .b = " ~ (b.val ? "true" : "false") ~ "}";
            } else {
                return (b.val ? "true" : "false");
            }
        }
        else if (auto strNode = cast(StringNode)node) {
            if (useHetero) {
                return "(PyValue){.type = PY_STRING, .s = " ~ "\"" ~ strNode.val ~ "\"" ~ "}";
            } else {
                return "\"" ~ strNode.val ~ "\"";
            }
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
                    return "(PyValue){.type = PY_STRING, .s = " ~ "\"" ~ lStr.val ~ rStr.val ~ "\"" ~ "}";
                }
                return "py_str_concat(" ~ compileNode(binOp.left) ~ ", " ~ compileNode(binOp.right) ~ ")";
            }

            string left = compileNode(binOp.left);
            string right = compileNode(binOp.right);

            if (useHetero) {
                if (binOp.op == "-") return "py_sub(" ~ left ~ ", " ~ right ~ ")";
                if (binOp.op == "*") return "py_mul(" ~ left ~ ", " ~ right ~ ")";
                if (binOp.op == "/") return "py_div(" ~ left ~ ", " ~ right ~ ")";
                if (binOp.op == "<") return "py_lt(" ~ left ~ ", " ~ right ~ ")";
                if (binOp.op == ">") return "py_gt(" ~ left ~ ", " ~ right ~ ")";
                if (binOp.op == "==") return "py_eq(" ~ left ~ ", " ~ right ~ ")";
                if (binOp.op == "!=") return "py_ne(" ~ left ~ ", " ~ right ~ ")";
                if (binOp.op == "<=") return "py_le(" ~ left ~ ", " ~ right ~ ")";
                if (binOp.op == ">=") return "py_ge(" ~ left ~ ", " ~ right ~ ")";
            }

            return left ~ " " ~ binOp.op ~ " " ~ right;
        }
        else if (auto listNode = cast(ListNode)node) {
            bool hetero = useHetero || isHeterogeneousElems(listNode.elems);
            string arrayName = getNextListId();

            if (hetero) {
                globalDeclarations ~= "static PyValue " ~ arrayName ~ "[" ~ to!string(listNode.elems.length) ~ "];\n";
                foreach (i, elem; listNode.elems) {
                    mainAssignments ~= arrayName ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ "; ";
                }
                return "(PyValue){.type = PY_LIST, .l = (void*)" ~ arrayName ~ ", .size = " ~ to!string(listNode.elems.length) ~ "}";
            } else {
                bool hasFloat = false;
                bool hasString = false;
                foreach (elem; listNode.elems) {
                    if (auto num = cast(NumberNode)elem) {
                        if (num.isFloat) hasFloat = true;
                    }
                    if (cast(StringNode)elem) hasString = true;
                }
                if (hasString) {
                    globalDeclarations ~= "static char* " ~ arrayName ~ "[" ~ to!string(listNode.elems.length) ~ "];\n";
                } else if (hasFloat) {
                    globalDeclarations ~= "static double " ~ arrayName ~ "[" ~ to!string(listNode.elems.length) ~ "];\n";
                } else {
                    globalDeclarations ~= "static int " ~ arrayName ~ "[" ~ to!string(listNode.elems.length) ~ "];\n";
                }
                foreach (i, elem; listNode.elems) {
                    mainAssignments ~= arrayName ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ "; ";
                }
                return arrayName;
            }
        }
        else if (auto tupleNode = cast(TupleNode)node) {
            bool hetero = useHetero || isHeterogeneousElems(tupleNode.elems);
            string arrayName = getNextListId();

            if (hetero) {
                globalDeclarations ~= "static PyValue " ~ arrayName ~ "[" ~ to!string(tupleNode.elems.length) ~ "];\n";
                foreach (i, elem; tupleNode.elems) {
                    mainAssignments ~= arrayName ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ "; ";
                }
                return "(PyValue){.type = PY_TUPLE, .l = (void*)" ~ arrayName ~ ", .size = " ~ to!string(tupleNode.elems.length) ~ "}";
            } else {
                bool hasFloat = false;
                bool hasString = false;
                foreach (elem; tupleNode.elems) {
                    if (auto num = cast(NumberNode)elem) {
                        if (num.isFloat) hasFloat = true;
                    }
                    if (cast(StringNode)elem) hasString = true;
                }
                if (hasString) {
                    globalDeclarations ~= "static char* " ~ arrayName ~ "[" ~ to!string(tupleNode.elems.length) ~ "];\n";
                } else if (hasFloat) {
                    globalDeclarations ~= "static double " ~ arrayName ~ "[" ~ to!string(tupleNode.elems.length) ~ "];\n";
                } else {
                    globalDeclarations ~= "static int " ~ arrayName ~ "[" ~ to!string(tupleNode.elems.length) ~ "];\n";
                }
                foreach (i, elem; tupleNode.elems) {
                    mainAssignments ~= arrayName ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ "; ";
                }
                return arrayName;
            }
        }
        else if (cast(DictNode)node || cast(SetNode)node || cast(ListCompNode)node) {
            return "NULL";
        }
        else if (auto indexNode = cast(IndexNode)node) {
            return indexNode.name ~ "[" ~ compileNode(indexNode.index) ~ "]";
        }
        else if (auto assign = cast(AssignNode)node) {
            if (cast(ListNode)assign.expr || cast(TupleNode)assign.expr) {
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
                    if (auto varArg = cast(VarNode)arg) {
                        string* t = varArg.name in variableTypes;
                        if (t !is null && *t == "PyValue_array") {
                            result ~= "py_print_value((PyValue){.type = PY_LIST, .l = (void*)" ~ varArg.name ~ ", .size = " ~ to!string(arraySizes[varArg.name]) ~ "}); ";
                            continue;
                        }
                    }
                    if (useHetero) {
                        result ~= "py_print_value(" ~ compileNode(arg) ~ "); ";
                    } else {
                        if (isStringExpr(arg)) {
                            result ~= "printf(\"%s\\n\", " ~ compileNode(arg) ~ "); ";
                        } else if (auto numArg = cast(NumberNode)arg) {
                            result ~= numArg.isFloat ? "printf(\"%f\\n\", " ~ compileNode(arg) ~ "); " : "printf(\"%d\\n\", (int)(" ~ compileNode(arg) ~ ")); ";
                        } else if (auto varArg = cast(VarNode)arg) {
                            string* t = varArg.name in variableTypes;
                            if (t !is null && (*t == "const char*" || *t == "char*")) {
                                result ~= "printf(\"%s\\n\", " ~ compileNode(arg) ~ "); ";
                            } else if (t !is null && (*t == "float" || *t == "double")) {
                                result ~= "printf(\"%f\\n\", " ~ compileNode(arg) ~ "); ";
                            } else {
                                result ~= "printf(\"%d\\n\", (int)(" ~ compileNode(arg) ~ ")); ";
                            }
                        } else {
                            result ~= "printf(\"%d\\n\", (int)(" ~ compileNode(arg) ~ ")); ";
                        }
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
            if (cast(VarNode)mCall.obj && (cast(VarNode)mCall.obj).name == "random" && mCall.method == "random") {
                return "((float)rand() / (float)RAND_MAX)";
            }
            if (auto varObj = cast(VarNode)mCall.obj) {
                string argsList = "";
                foreach (i, arg; mCall.args) {
                    argsList ~= compileNode(arg) ~ (i + 1 < mCall.args.length ? ", " : "");
                }
                return varObj.name ~ "_" ~ mCall.method ~ "(" ~ argsList ~ ")";
            }
            return mCall.toC();
        }
        else if (auto returnNode = cast(ReturnNode)node) {
            return "return " ~ (returnNode.expr ? compileNode(returnNode.expr) : "0") ~ ";";
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
            string fnName = modulePrefix.length > 0 ? modulePrefix ~ "_" ~ fnDef.name : fnDef.name;
            string code = "int " ~ fnName ~ "(" ~ params ~ ") {\n";
            bool hasReturn = false;
            foreach (stmt; fnDef.body) {
                if (cast(ReturnNode)stmt) hasReturn = true;
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "    " ~ line ~ "\n";
            }
            if (!hasReturn) {
                code ~= "    return 0;\n";
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

    private string compileBlock(ASTNode[] nodes) {
        string code = "";
        foreach (stmt; nodes) {
            string line = compileNode(stmt);
            if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
            code ~= "        " ~ line ~ "\n";
        }
        return code;
    }
}
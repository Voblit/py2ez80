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
    private string[string] fnReturnTypes;
    private string[string] fnReturnElems;
    private string[][string] fnParamNames;
    private string[][string] fnLocalList;
    private string[string] listElemTypes;
    private string[] functionProtos;
    private bool[string] localKeys;
    private bool[string] topNames;
    private bool[string] declaredGlobals;
    private bool[string] dynLists;
    private string currentFn = "";
    private bool typesChanged = false;
    private bool finalPass = false;
    private int tmpCounter = 0;
    private long[string] constVals;

    private bool useHetero = false;
    private bool useException = false;
    private bool useListAppend = false;
    private bool useInput = false;
    private bool useStrConcat = false;
    private bool useMath = false;
    private bool useRandom = false;
    private bool useGraphics = false;

    this(string modulePrefix = "") {
        this.modulePrefix = modulePrefix;
    }

    public string getSourceCode() {
        return textSection.join("\n");
    }

    private string varKey(string name) {
        if (currentFn.length > 0) {
            string k = currentFn ~ "::" ~ name;
            if (k in localKeys) return k;
        }
        return name;
    }

    private void trackVar(string varName, string type = "int") {
        string key = varKey(varName);
        if (key !in variableTypes) {
            variableTypes[key] = type;
            typesChanged = true;
        }
    }

    private string typeOfVar(string name) {
        string* t = varKey(name) in variableTypes;
        return t is null ? "" : *t;
    }

    private string elemKnown(string name) {
        string* t = varKey(name) in listElemTypes;
        return t is null ? "" : *t;
    }

    private string elemOf(string name) {
        string e = elemKnown(name);
        return e.length == 0 ? "int" : e;
    }

    private bool isCmpOp(string op) {
        return op == "==" || op == "!=" || op == "<" || op == ">" || op == "<=" || op == ">=" || op == "&&" || op == "||";
    }

    private string exprType(ASTNode node) {
        if (node is null) return "";
        if (auto num = cast(NumberNode)node) return num.isFloat ? "float" : "int";
        if (cast(BoolNode)node) return "int";
        if (cast(StringNode)node) return "const char*";
        if (auto var = cast(VarNode)node) return typeOfVar(var.name);
        if (auto unOp = cast(UnaryOpNode)node) {
            if (unOp.op == "!") return "int";
            return exprType(unOp.expr);
        }
        if (auto binOp = cast(BinaryOpNode)node) {
            if (repeatListOf(binOp) !is null) return "PyList*";
            if (isCmpOp(binOp.op)) return "int";
            string lt = exprType(binOp.left);
            string rt = exprType(binOp.right);
            if (binOp.op == "+" && (lt == "const char*" || rt == "const char*")) return "const char*";
            if (lt == "float" || rt == "float") return "float";
            if (lt.length == 0 || rt.length == 0) return "";
            return "int";
        }
        if (auto call = cast(CallNode)node) {
            if (call.name == "input" || call.name == "str") return "const char*";
            if (call.name == "float") return "float";
            if (call.name == "int" || call.name == "len") return "int";
            if (call.name in fnParamNames) {
                string* r = call.name in fnReturnTypes;
                return r is null ? "" : *r;
            }
            return "int";
        }
        if (auto mCall = cast(MethodCallNode)node) {
            auto objVar = cast(VarNode)mCall.obj;
            if (objVar !is null && objVar.name == "random" && mCall.method == "random") return "float";
            if (objVar !is null && typeOfVar(objVar.name) == "PyList*" && mCall.method == "pop") return elemOf(objVar.name);
            return "int";
        }
        if (auto idx = cast(IndexNode)node) {
            string bt = typeOfVar(idx.name);
            if (bt == "const char*" || bt == "char*[]") return "const char*";
            if (bt == "PyList*") return elemOf(idx.name);
            if (bt == "double[]") return "float";
            if (bt == "int[]") return "int";
            return "";
        }
        return "";
    }

    private bool isStringExpr(ASTNode node) {
        return exprType(node) == "const char*";
    }

    private string boxFor(string type, string c) {
        if (type == "const char*") return "(void*)(" ~ c ~ ")";
        if (type == "float") return "py_box_double(" ~ c ~ ")";
        return "(void*)(intptr_t)(" ~ c ~ ")";
    }

    private string unboxPtr(string ptrC, string type) {
        if (type == "const char*") return "((const char*)" ~ ptrC ~ ")";
        if (type == "float") return "(*(double*)" ~ ptrC ~ ")";
        return "((int)(intptr_t)" ~ ptrC ~ ")";
    }

    private string strArg(ASTNode node) {
        string c = compileNode(node);
        if (useHetero) return c;
        string t = exprType(node);
        if (t == "int") return "py_str_from_int(" ~ c ~ ")";
        if (t == "float") return "py_str_from_float(" ~ c ~ ")";
        return c;
    }

    private string cStr(string v) {
        string res = "";
        for (size_t i = 0; i < v.length; i++) {
            if (v[i] == '\\' && i + 1 < v.length) {
                res ~= v[i];
                res ~= v[i + 1];
                i++;
            } else if (v[i] == '"') {
                res ~= "\\\"";
            } else {
                res ~= v[i];
            }
        }
        return res;
    }

    private string cTypeOf(string t) {
        if (t == "int[]") return "int*";
        if (t == "double[]") return "double*";
        if (t == "char*[]") return "const char**";
        if (t == "PyValue_array") return "PyValue*";
        if (t.length == 0) return "int";
        return t;
    }

    private string defaultFor(string t) {
        if (t == "float") return "0.0";
        if (t == "const char*") return "\"\"";
        if (t == "PyList*" || t == "void*") return "NULL";
        return "0";
    }

    private bool constInt(ASTNode node, ref long v) {
        if (auto num = cast(NumberNode)node) {
            if (num.isFloat) return false;
            v = cast(long)num.val;
            return true;
        }
        if (auto var = cast(VarNode)node) {
            long* c = var.name in constVals;
            if (c is null) return false;
            v = *c;
            return true;
        }
        if (auto un = cast(UnaryOpNode)node) {
            if (un.op != "-") return false;
            long inner;
            if (!constInt(un.expr, inner)) return false;
            v = -inner;
            return true;
        }
        if (auto bin = cast(BinaryOpNode)node) {
            long l;
            long r;
            if (!constInt(bin.left, l) || !constInt(bin.right, r)) return false;
            if (bin.op == "+") v = l + r;
            else if (bin.op == "-") v = l - r;
            else if (bin.op == "*") v = l * r;
            else if (bin.op == "/" && r != 0) v = l / r;
            else return false;
            return true;
        }
        return false;
    }

    private ListNode repeatListOf(ASTNode expr) {
        auto bin = cast(BinaryOpNode)expr;
        if (bin is null || bin.op != "*") return null;
        if (auto l = cast(ListNode)bin.left) return l;
        if (auto r = cast(ListNode)bin.right) return r;
        return null;
    }

    private ASTNode repeatCountOf(ASTNode expr) {
        auto bin = cast(BinaryOpNode)expr;
        if (cast(ListNode)bin.left) return bin.right;
        return bin.left;
    }

    private string stripParens(string c) {
        if (c.length < 2 || c[0] != '(' || c[$ - 1] != ')') return c;
        int depth = 0;
        for (size_t i = 0; i < c.length; i++) {
            if (c[i] == '(') depth++;
            if (c[i] == ')') depth--;
            if (depth == 0 && i + 1 < c.length) return c;
        }
        return c[1 .. $ - 1];
    }

    private bool hasTryStmt(ASTNode[] nodes) {
        foreach (node; nodes) {
            if (cast(TryExceptNode)node) return true;
            if (auto ifNode = cast(IfNode)node) {
                if (hasTryStmt(ifNode.thenB) || hasTryStmt(ifNode.elseB)) return true;
            }
            if (auto whileNode = cast(WhileNode)node) {
                if (hasTryStmt(whileNode.body)) return true;
            }
            if (auto forNode = cast(ForNode)node) {
                if (hasTryStmt(forNode.body)) return true;
            }
        }
        return false;
    }

    private bool isDynList(string name, ListNode listNode) {
        if (currentFn.length > 0) return true;
        if (listNode.elems.length == 0) return true;
        return (varKey(name) in dynLists) !is null;
    }

    private bool isStaticListAssign(AssignNode assign) {
        if (assign.index !is null) return false;
        if (cast(TupleNode)assign.expr) return true;
        auto rep = repeatListOf(assign.expr);
        if (rep !is null) {
            long n;
            if (currentFn.length > 0) return false;
            if ((varKey(assign.name) in dynLists) !is null) return false;
            if (!constInt(repeatCountOf(assign.expr), n)) return false;
            return n >= 0 && n * rep.elems.length <= 2000;
        }
        auto listNode = cast(ListNode)assign.expr;
        if (listNode is null) return false;
        return !isDynList(assign.name, listNode);
    }

    private string buildDynList(string name, ListNode listNode) {
        string et = elemOf(name);
        string code = name ~ " = py_list_new();";
        foreach (elem; listNode.elems) {
            code ~= " py_list_append(" ~ name ~ ", " ~ boxFor(et, compileNode(elem)) ~ ");";
        }
        return code;
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

    private void collectAssigned(ASTNode[] nodes, ref bool[string] names) {
        foreach (node; nodes) {
            if (auto assign = cast(AssignNode)node) {
                if (assign.index is null) names[assign.name] = true;
            } else if (auto compAssign = cast(CompoundAssignNode)node) {
                names[compAssign.name] = true;
            } else if (auto forNode = cast(ForNode)node) {
                names[forNode.varName] = true;
                collectAssigned(forNode.body, names);
            } else if (auto whileNode = cast(WhileNode)node) {
                collectAssigned(whileNode.body, names);
            } else if (auto ifNode = cast(IfNode)node) {
                collectAssigned(ifNode.thenB, names);
                collectAssigned(ifNode.elseB, names);
            } else if (auto tryExcept = cast(TryExceptNode)node) {
                collectAssigned(tryExcept.tryBody, names);
                collectAssigned(tryExcept.exceptBody, names);
                collectAssigned(tryExcept.finallyBody, names);
            } else if (auto globalNode = cast(GlobalNode)node) {
                declaredGlobals[globalNode.varName] = true;
            }
        }
    }

    private void registerFunction(FunctionDefNode fn) {
        fnParamNames[fn.name] = fn.params;
        bool[string] names;
        collectAssigned(fn.body, names);
        string[] ordered;
        foreach (p; fn.params) ordered ~= p;
        foreach (n; names.keys) {
            if (n in declaredGlobals) continue;
            bool isParam = false;
            foreach (p; fn.params) {
                if (p == n) isParam = true;
            }
            if (isParam) continue;
            if (n in topNames) continue;
            ordered ~= n;
        }
        fnLocalList[fn.name] = ordered;
        foreach (n; ordered) localKeys[fn.name ~ "::" ~ n] = true;
    }

    private void countAssigns(ASTNode[] nodes, ref int[string] counts) {
        foreach (node; nodes) {
            if (auto assign = cast(AssignNode)node) {
                if (assign.index is null) counts[assign.name] += 1;
            } else if (auto compAssign = cast(CompoundAssignNode)node) {
                counts[compAssign.name] += 2;
            } else if (auto forNode = cast(ForNode)node) {
                counts[forNode.varName] += 2;
                countAssigns(forNode.body, counts);
            } else if (auto whileNode = cast(WhileNode)node) {
                countAssigns(whileNode.body, counts);
            } else if (auto ifNode = cast(IfNode)node) {
                countAssigns(ifNode.thenB, counts);
                countAssigns(ifNode.elseB, counts);
            } else if (auto tryExcept = cast(TryExceptNode)node) {
                countAssigns(tryExcept.tryBody, counts);
                countAssigns(tryExcept.exceptBody, counts);
                countAssigns(tryExcept.finallyBody, counts);
            }
        }
    }

    private void collectScopes(ASTNode[] ast) {
        foreach (node; ast) {
            if (cast(FunctionDefNode)node || cast(ClassDefNode)node) continue;
            ASTNode[] one = [node];
            collectAssigned(one, topNames);
        }
        bool[string] scratch;
        foreach (node; ast) {
            if (auto fn = cast(FunctionDefNode)node) collectAssigned(fn.body, scratch);
        }
        foreach (node; ast) {
            if (auto fn = cast(FunctionDefNode)node) registerFunction(fn);
        }
        int[string] assignCounts;
        foreach (node; ast) {
            if (cast(FunctionDefNode)node || cast(ClassDefNode)node) continue;
            ASTNode[] one = [node];
            countAssigns(one, assignCounts);
        }
        foreach (g; declaredGlobals.keys) assignCounts[g] += 2;
        foreach (node; ast) {
            if (auto assign = cast(AssignNode)node) {
                if (assign.index is null && assignCounts[assign.name] == 1) {
                    long v;
                    if (constInt(assign.expr, v)) constVals[assign.name] = v;
                }
            }
        }
    }

    private void scanAppends(ASTNode[] nodes, string fn) {
        foreach (node; nodes) {
            if (auto mCall = cast(MethodCallNode)node) {
                if (mCall.method == "append") {
                    if (auto objVar = cast(VarNode)mCall.obj) {
                        string localKey = fn ~ "::" ~ objVar.name;
                        dynLists[(localKey in localKeys) ? localKey : objVar.name] = true;
                    }
                }
            } else if (auto fnDef = cast(FunctionDefNode)node) {
                scanAppends(fnDef.body, fnDef.name);
            } else if (auto forNode = cast(ForNode)node) {
                scanAppends(forNode.body, fn);
            } else if (auto whileNode = cast(WhileNode)node) {
                scanAppends(whileNode.body, fn);
            } else if (auto ifNode = cast(IfNode)node) {
                scanAppends(ifNode.thenB, fn);
                scanAppends(ifNode.elseB, fn);
            } else if (auto tryExcept = cast(TryExceptNode)node) {
                scanAppends(tryExcept.tryBody, fn);
                scanAppends(tryExcept.exceptBody, fn);
                scanAppends(tryExcept.finallyBody, fn);
            }
        }
    }

    private void trackExprVar(string name, ASTNode expr) {
        string t = exprType(expr);
        if (t.length == 0) {
            if (!finalPass) return;
            t = "int";
        }
        trackVar(name, t);
        if (t == "PyList*") {
            string key = varKey(name);
            if (key !in listElemTypes) {
                string et = "";
                if (auto srcVar = cast(VarNode)expr) {
                    et = elemKnown(srcVar.name);
                } else if (auto srcCall = cast(CallNode)expr) {
                    string* r = srcCall.name in fnReturnElems;
                    if (r !is null) et = *r;
                }
                if (et.length > 0) {
                    listElemTypes[key] = et;
                    typesChanged = true;
                }
            }
        }
    }

    private void typeCallArgs(CallNode call) {
        string[] pn = fnParamNames[call.name];
        foreach (i, arg; call.args) {
            if (i >= pn.length) break;
            string key = call.name ~ "::" ~ pn[i];
            string t = exprType(arg);
            if (t.length == 0 || key in variableTypes) continue;
            variableTypes[key] = t;
            typesChanged = true;
            if (t == "PyList*") {
                if (auto argVar = cast(VarNode)arg) {
                    string et = elemKnown(argVar.name);
                    if (et.length > 0) listElemTypes[key] = et;
                }
            }
        }
    }

    private void analyzeAST(ASTNode[] ast) {
        collectScopes(ast);
        scanAppends(ast, "");
        finalPass = false;
        foreach (pass; 0 .. 8) {
            typesChanged = false;
            currentFn = "";
            foreach (node; ast) {
                analyzeNode(node);
            }
            if (!typesChanged) break;
        }
        finalPass = true;
        currentFn = "";
        foreach (node; ast) {
            analyzeNode(node);
        }
        finalPass = false;
        currentFn = "";
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

        if (auto unOp = cast(UnaryOpNode)node) {
            analyzeNode(unOp.expr);
        }

        if (auto indexNode = cast(IndexNode)node) {
            analyzeNode(indexNode.index);
        }

        if (auto call = cast(CallNode)node) {
            if (call.name == "input") useInput = true;
            if (call.name == "append") useListAppend = true;
            foreach (arg; call.args) analyzeNode(arg);
            if (call.name in fnParamNames) typeCallArgs(call);
        }

        if (auto mCall = cast(MethodCallNode)node) {
            if (mCall.method == "append") useListAppend = true;
            if (auto objVar = cast(VarNode)mCall.obj) {
                if (objVar.name == "math") useMath = true;
                if (objVar.name == "random") useRandom = true;
                if (objVar.name == "graphics") useGraphics = true;
                if (mCall.method == "append" && mCall.args.length == 1) {
                    string key = varKey(objVar.name);
                    if (key !in listElemTypes) {
                        string et = exprType(mCall.args[0]);
                        if (et.length > 0) {
                            listElemTypes[key] = et;
                            typesChanged = true;
                        }
                    }
                }
            }
            foreach (arg; mCall.args) analyzeNode(arg);
        }

        if (auto assign = cast(AssignNode)node) {
            analyzeNode(assign.expr);
            if (assign.index !is null) analyzeNode(assign.index);
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
            auto dynNode = cast(ListNode)assign.expr;
            if (assign.index !is null) {
            } else if (dynNode !is null && isDynList(assign.name, dynNode)) {
                trackVar(assign.name, "PyList*");
                string key = varKey(assign.name);
                if (dynNode.elems.length > 0 && key !in listElemTypes) {
                    string et = exprType(dynNode.elems[0]);
                    if (et.length > 0) {
                        listElemTypes[key] = et;
                        typesChanged = true;
                    }
                }
            } else if (repeatListOf(assign.expr) !is null) {
                auto rep = repeatListOf(assign.expr);
                if (isStaticListAssign(assign)) {
                    long n;
                    constInt(repeatCountOf(assign.expr), n);
                    bool hasString = false;
                    bool hasFloat = false;
                    foreach (elem; rep.elems) {
                        string et = exprType(elem);
                        if (et == "const char*") hasString = true;
                        if (et == "float") hasFloat = true;
                    }
                    variableTypes[assign.name] = hasString ? "char*[]" : (hasFloat ? "double[]" : "int[]");
                    arraySizes[assign.name] = cast(int)(n * rep.elems.length);
                } else {
                    trackVar(assign.name, "PyList*");
                    string key = varKey(assign.name);
                    if (rep.elems.length > 0 && key !in listElemTypes) {
                        string et = exprType(rep.elems[0]);
                        if (et.length > 0) {
                            listElemTypes[key] = et;
                            typesChanged = true;
                        }
                    }
                }
            } else if (cast(ListNode)assign.expr || cast(TupleNode)assign.expr) {
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
            } else {
                trackExprVar(assign.name, assign.expr);
            }
        } else if (auto compAssign = cast(CompoundAssignNode)node) {
            trackExprVar(compAssign.name, compAssign.expr);
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
            string savedFn = currentFn;
            currentFn = fnDef.name;
            foreach (stmt; fnDef.body) analyzeNode(stmt);
            currentFn = savedFn;
        } else if (auto retNode = cast(ReturnNode)node) {
            if (retNode.expr !is null) {
                analyzeNode(retNode.expr);
                if (currentFn.length > 0 && currentFn !in fnReturnTypes) {
                    string t = exprType(retNode.expr);
                    if (t.length > 0) {
                        fnReturnTypes[currentFn] = t;
                        typesChanged = true;
                        if (t == "PyList*") {
                            if (auto retVar = cast(VarNode)retNode.expr) {
                                string et = elemKnown(retVar.name);
                                if (et.length > 0) fnReturnElems[currentFn] = et;
                            }
                        }
                    }
                }
            }
        } else if (auto tryExcept = cast(TryExceptNode)node) {
            foreach (stmt; tryExcept.tryBody) analyzeNode(stmt);
            foreach (stmt; tryExcept.exceptBody) analyzeNode(stmt);
            foreach (stmt; tryExcept.finallyBody) analyzeNode(stmt);
        }
    }

    void generate(ASTNode[] ast) {
        variableTypes.clear();
        arraySizes.clear();
        constVals.clear();
        fnReturnTypes.clear();
        fnReturnElems.clear();
        fnParamNames.clear();
        fnLocalList.clear();
        listElemTypes.clear();
        localKeys.clear();
        topNames.clear();
        declaredGlobals.clear();
        dynLists.clear();
        functionProtos = [];
        currentFn = "";
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
        useMath = false;
        useRandom = false;
        useGraphics = false;

        analyzeAST(ast);
        textSection ~= "#pragma clang diagnostic ignored \"-Wunused-function\"";
        textSection ~= "#pragma clang diagnostic ignored \"-Wparentheses-equality\"";
        textSection ~= "#include <tice.h>";
        textSection ~= "#include <ti/screen.h>";
        textSection ~= "#include <stdio.h>";
        textSection ~= "#include <stdlib.h>";
        textSection ~= "#include <stdint.h>";
        textSection ~= "#include <stdbool.h>";
        textSection ~= "#include <string.h>";
        textSection ~= "#include <keypadc.h>";
        if (useException) textSection ~= "#include <setjmp.h>";
        textSection ~= "#include <math.h>";
        if (useGraphics) textSection ~= "#include <graphx.h>";
        textSection ~= "";
        textSection ~= "#ifndef RAND_MAX";
        textSection ~= "#define RAND_MAX 32767";
        textSection ~= "#endif";
        textSection ~= "";

        if (useMath) {
            textSection ~= "static double math_sqrt(double x) { return sqrt(x); }";
        }
        if (useRandom) {
            textSection ~= "static void random_seed(int seed) { srand(seed); }";
            textSection ~= "static int random_randint(int a, int b) { return a + (rand() % (b - a + 1)); }";
        }
        
        textSection ~= "typedef struct { void** data; int size; int capacity; } PyList;";
        textSection ~= "static PyList* py_list_new(void) {";
        textSection ~= "    PyList* l = (PyList*)malloc(sizeof(PyList));";
        textSection ~= "    l->size = 0; l->capacity = 8;";
        textSection ~= "    l->data = malloc(8 * sizeof(void*));";
        textSection ~= "    return l;";
        textSection ~= "}";
        textSection ~= "static void py_list_append(PyList* l, void* val) {";
        textSection ~= "    if (l->size >= l->capacity) {";
        textSection ~= "        l->capacity *= 2;";
        textSection ~= "        l->data = realloc(l->data, l->capacity * sizeof(void*));";
        textSection ~= "    }";
        textSection ~= "    l->data[l->size++] = val;";
        textSection ~= "}";

        if (useException) {
            textSection ~= "static jmp_buf py_exception_env;";
            textSection ~= "static void py_raise(int err) { (void)err; longjmp(py_exception_env, 1); }";
        }

        textSection ~= "static void* py_box_double(double d) { double* p = (double*)malloc(sizeof(double)); *p = d; return p; }";
        textSection ~= "static void* py_list_pop(PyList* l) { return l->data[--l->size]; }";
        textSection ~= "static void py_print_list(PyList* l, int kind) {";
        textSection ~= "    int i;";
        textSection ~= "    printf(\"[\");";
        textSection ~= "    for (i = 0; i < l->size; i++) {";
        textSection ~= "        if (i) printf(\", \");";
        textSection ~= "        if (kind == 1) printf(\"'%s'\", (const char*)l->data[i]);";
        textSection ~= "        else if (kind == 2) printf(\"%f\", *(double*)l->data[i]);";
        textSection ~= "        else printf(\"%d\", (int)(intptr_t)l->data[i]);";
        textSection ~= "    }";
        textSection ~= "    printf(\"]\");";
        textSection ~= "}";

        if (useInput) {
            textSection ~= "static char* py_input(void) {";
            textSection ~= "    char buf[64];";
            textSection ~= "    memset(buf, 0, sizeof(buf));";
            textSection ~= "    os_GetStringInput(\":\", buf, sizeof(buf) - 1);";
            textSection ~= "    char* out = (char*)malloc(strlen(buf) + 1);";
            textSection ~= "    strcpy(out, buf);";
            textSection ~= "    return out;";
            textSection ~= "}";
        }
        textSection ~= "static char* py_str_concat(const char* s1, const char* s2) {";
        textSection ~= "    char* buf = (char*)malloc(strlen(s1) + strlen(s2) + 1);";
        textSection ~= "    strcpy(buf, s1);";
        textSection ~= "    strcat(buf, s2);";
        textSection ~= "    return buf;";
        textSection ~= "}";
        textSection ~= "static const char* py_str_from_int(int n) {";
        textSection ~= "    char* buf = (char*)malloc(16);";
        textSection ~= "    sprintf(buf, \"%d\", n);";
        textSection ~= "    return buf;";
        textSection ~= "}";
        textSection ~= "static const char* py_str_from_float(double f) {";
        textSection ~= "    char* buf = (char*)malloc(32);";
        textSection ~= "    sprintf(buf, \"%f\", f);";
        textSection ~= "    return buf;";
        textSection ~= "}";
        textSection ~= "static char py_chars[256][2];";
        textSection ~= "static const char* py_str_char(const char* s, int i) {";
        textSection ~= "    unsigned char c = (unsigned char)s[i];";
        textSection ~= "    py_chars[c][0] = (char)c;";
        textSection ~= "    py_chars[c][1] = 0;";
        textSection ~= "    return py_chars[c];";
        textSection ~= "}";

        foreach (node; ast) {
            if (auto assign = cast(AssignNode)node) {
                if (isStaticListAssign(assign)) {
                    auto repList = repeatListOf(assign.expr);
                    if (repList !is null) {
                        long repCount;
                        constInt(repeatCountOf(assign.expr), repCount);
                        string fill = "{ int _r; for (_r = 0; _r < " ~ to!string(repCount) ~ "; _r++) {";
                        foreach (i, elem; repList.elems) {
                            fill ~= " " ~ assign.name ~ "[_r * " ~ to!string(repList.elems.length) ~ " + " ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ ";";
                        }
                        mainAssignments ~= fill ~ " } }";
                    } else {
                        auto listNode = cast(ListNode)assign.expr;
                        auto tupleNode = cast(TupleNode)assign.expr;
                        auto elems = listNode ? listNode.elems : tupleNode.elems;

                        foreach (i, elem; elems) {
                            mainAssignments ~= assign.name ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ ";";
                        }
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
                if (isStaticListAssign(assign)) continue;
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
                if (varName.indexOf("::") >= 0) continue;
                if (type == "PyValue_array") {
                    textSection ~= "static PyValue " ~ varName ~ "[" ~ to!string(arraySizes[varName]) ~ "];\n";
                } else if (type == "char*[]") {
                    textSection ~= "static const char* " ~ varName ~ "[" ~ to!string(arraySizes[varName]) ~ "];\n";
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
        foreach (proto; functionProtos) textSection ~= proto ~ "\n";
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
                return "(PyValue){.type = PY_STRING, .s = " ~ "\"" ~ cStr(strNode.val) ~ "\"" ~ "}";
            } else {
                return "\"" ~ cStr(strNode.val) ~ "\"";
            }
        }
        else if (auto var = cast(VarNode)node) {
            return var.name;
        }
        else if (auto unOp = cast(UnaryOpNode)node) {
            if (!useHetero && unOp.op == "-") {
                if (cast(NumberNode)unOp.expr) return "-" ~ compileNode(unOp.expr);
            }
            return unOp.op ~ "(" ~ compileNode(unOp.expr) ~ ")";
        }
        else if (auto binOp = cast(BinaryOpNode)node) {
            if (auto repList = repeatListOf(binOp)) {
                string repType = repList.elems.length > 0 ? exprType(repList.elems[0]) : "int";
                if (repType.length == 0) repType = "int";
                tmpCounter++;
                string lv = "_rl" ~ to!string(tmpCounter);
                string iv = "_ri" ~ to!string(tmpCounter);
                string repCode = "({ PyList* " ~ lv ~ " = py_list_new(); int " ~ iv ~ "; for (" ~ iv ~ " = 0; " ~ iv ~ " < " ~ compileNode(repeatCountOf(binOp)) ~ "; " ~ iv ~ "++) {";
                foreach (elem; repList.elems) {
                    repCode ~= " py_list_append(" ~ lv ~ ", " ~ boxFor(repType, compileNode(elem)) ~ ");";
                }
                return repCode ~ " } " ~ lv ~ "; })";
            }
            if (binOp.op == "+" && (isStringExpr(binOp.left) || isStringExpr(binOp.right))) {
                if (cast(StringNode)binOp.left && cast(StringNode)binOp.right) {
                    auto lStr = cast(StringNode)binOp.left;
                    auto rStr = cast(StringNode)binOp.right;
                    if (useHetero) {
                        return "(PyValue){.type = PY_STRING, .s = " ~ "\"" ~ cStr(lStr.val) ~ cStr(rStr.val) ~ "\"" ~ "}";
                    }
                    return "\"" ~ cStr(lStr.val) ~ cStr(rStr.val) ~ "\"";
                }
                return "py_str_concat(" ~ strArg(binOp.left) ~ ", " ~ strArg(binOp.right) ~ ")";
            }

            string left = compileNode(binOp.left);
            string right = compileNode(binOp.right);

            if (!useHetero && (isStringExpr(binOp.left) || isStringExpr(binOp.right)) &&
                (binOp.op == "==" || binOp.op == "!=" || binOp.op == "<" || binOp.op == ">" || binOp.op == "<=" || binOp.op == ">=")) {
                return "(strcmp(" ~ left ~ ", " ~ right ~ ") " ~ binOp.op ~ " 0)";
            }

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

            return "(" ~ left ~ " " ~ binOp.op ~ " " ~ right ~ ")";
        }
        else if (auto listNode = cast(ListNode)node) {
            bool hetero = useHetero || isHeterogeneousElems(listNode.elems);
            string arrayName = getNextListId();

            if (hetero) {
                globalDeclarations ~= "static PyValue " ~ arrayName ~ "[" ~ to!string(listNode.elems.length) ~ "];\n";
                foreach (i, elem; listNode.elems) {
                    mainAssignments ~= arrayName ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ ";";
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
                    globalDeclarations ~= "static const char* " ~ arrayName ~ "[" ~ to!string(listNode.elems.length) ~ "];\n";
                } else if (hasFloat) {
                    globalDeclarations ~= "static double " ~ arrayName ~ "[" ~ to!string(listNode.elems.length) ~ "];\n";
                } else {
                    globalDeclarations ~= "static int " ~ arrayName ~ "[" ~ to!string(listNode.elems.length) ~ "];\n";
                }
                foreach (i, elem; listNode.elems) {
                    mainAssignments ~= arrayName ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ ";";
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
                    mainAssignments ~= arrayName ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ ";";
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
                    globalDeclarations ~= "static const char* " ~ arrayName ~ "[" ~ to!string(tupleNode.elems.length) ~ "];\n";
                } else if (hasFloat) {
                    globalDeclarations ~= "static double " ~ arrayName ~ "[" ~ to!string(tupleNode.elems.length) ~ "];\n";
                } else {
                    globalDeclarations ~= "static int " ~ arrayName ~ "[" ~ to!string(tupleNode.elems.length) ~ "];\n";
                }
                foreach (i, elem; tupleNode.elems) {
                    mainAssignments ~= arrayName ~ "[" ~ to!string(i) ~ "] = " ~ compileNode(elem) ~ ";";
                }
                return arrayName;
            }
        }
        else if (cast(DictNode)node || cast(SetNode)node || cast(ListCompNode)node) {
            return "NULL";
        }
        else if (auto indexNode = cast(IndexNode)node) {
            string baseType = typeOfVar(indexNode.name);
            if (baseType == "const char*") {
                return "py_str_char(" ~ indexNode.name ~ ", " ~ compileNode(indexNode.index) ~ ")";
            }
            if (baseType == "PyList*") {
                return unboxPtr(indexNode.name ~ "->data[" ~ compileNode(indexNode.index) ~ "]", elemOf(indexNode.name));
            }
            return indexNode.name ~ "[" ~ compileNode(indexNode.index) ~ "]";
        }
        else if (auto assign = cast(AssignNode)node) {
            if (assign.index is null && repeatListOf(assign.expr) !is null) {
                if (isStaticListAssign(assign)) return "";
                return assign.name ~ " = " ~ compileNode(assign.expr) ~ ";";
            }
            if (auto dynList = cast(ListNode)assign.expr) {
                if (assign.index is null && isDynList(assign.name, dynList)) {
                    return buildDynList(assign.name, dynList);
                }
                return "";
            }
            if (cast(TupleNode)assign.expr) {
                return "";
            }
            if (assign.index !is null) {
                if (typeOfVar(assign.name) == "PyList*") {
                    return assign.name ~ "->data[" ~ compileNode(assign.index) ~ "] = " ~ boxFor(elemOf(assign.name), compileNode(assign.expr)) ~ ";";
                }
                return assign.name ~ "[" ~ compileNode(assign.index) ~ "] = " ~ compileNode(assign.expr) ~ ";";
            }
            return assign.name ~ " = " ~ compileNode(assign.expr) ~ ";";
        }
        else if (auto compAssign = cast(CompoundAssignNode)node) {
            if (!useHetero && compAssign.op == "+=" && typeOfVar(compAssign.name) == "const char*") {
                return compAssign.name ~ " = py_str_concat(" ~ compAssign.name ~ ", " ~ strArg(compAssign.expr) ~ ");";
            }
            return compAssign.name ~ " " ~ compAssign.op ~ " " ~ compileNode(compAssign.expr) ~ ";";
        }
        else if (auto call = cast(CallNode)node) {
            if (call.name == "str") {
                if (isStringExpr(call.args[0])) return compileNode(call.args[0]);
                if (exprType(call.args[0]) == "float") return "py_str_from_float(" ~ compileNode(call.args[0]) ~ ")";
                return "py_str_from_int(" ~ compileNode(call.args[0]) ~ ")";
            }
            if (call.name == "int") {
                if (isStringExpr(call.args[0])) return "atoi(" ~ compileNode(call.args[0]) ~ ")";
                return "(int)(" ~ compileNode(call.args[0]) ~ ")";
            }
            if (call.name == "float") {
                if (isStringExpr(call.args[0])) return "(double)atof(" ~ compileNode(call.args[0]) ~ ")";
                return "(double)(" ~ compileNode(call.args[0]) ~ ")";
            }
            if (call.name == "print") {
                string result = "";
                foreach (i, arg; call.args) {
                    if (auto varArg = cast(VarNode)arg) {
                        string* t = varKey(varArg.name) in variableTypes;
                        if (t !is null && *t == "PyValue_array") {
                            result ~= "py_print_value((PyValue){.type = PY_LIST, .l = (void*)" ~ varArg.name ~ ", .size = " ~ to!string(arraySizes[varArg.name]) ~ "}); ";
                            continue;
                        }
                    }
                    if (useHetero) {
                        result ~= "py_print_value(" ~ compileNode(arg) ~ "); ";
                        continue;
                    }
                    if (i > 0) result ~= "printf(\" \"); ";
                    string argType = exprType(arg);
                    if (auto boolArg = cast(BoolNode)arg) {
                        result ~= "printf(\"%s\", " ~ (boolArg.val ? "\"True\"" : "\"False\"") ~ "); ";
                    } else if (argType == "const char*") {
                        result ~= "printf(\"%s\", " ~ compileNode(arg) ~ "); ";
                    } else if (argType == "float") {
                        result ~= "printf(\"%f\", " ~ compileNode(arg) ~ "); ";
                    } else if (argType == "PyList*") {
                        string kind = "0";
                        if (auto listArg = cast(VarNode)arg) {
                            string et = elemOf(listArg.name);
                            kind = et == "const char*" ? "1" : (et == "float" ? "2" : "0");
                        }
                        result ~= "py_print_list(" ~ compileNode(arg) ~ ", " ~ kind ~ "); ";
                    } else {
                        result ~= "printf(\"%d\", (int)(" ~ compileNode(arg) ~ ")); ";
                    }
                }
                if (!useHetero) result ~= "printf(\"\\n\"); ";
                return result;
            } else if (call.name == "len") {
                string argC = compileNode(call.args[0]);
                if (isStringExpr(call.args[0])) {
                    return "(int)strlen(" ~ argC ~ ")";
                }
                if (exprType(call.args[0]) == "PyList*") {
                    return argC ~ "->size";
                }
                return "(sizeof(" ~ argC ~ ") / sizeof(" ~ argC ~ "[0]))";
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
            if (auto listObj = cast(VarNode)mCall.obj) {
                if (typeOfVar(listObj.name) == "PyList*") {
                    if (mCall.method == "append" && mCall.args.length == 1) {
                        return "py_list_append(" ~ listObj.name ~ ", " ~ boxFor(elemOf(listObj.name), compileNode(mCall.args[0])) ~ ")";
                    }
                    if (mCall.method == "pop") {
                        return unboxPtr("py_list_pop(" ~ listObj.name ~ ")", elemOf(listObj.name));
                    }
                }
            }
            if (auto varObj = cast(VarNode)mCall.obj) {
                if (varObj.name == "graphics") {
                    string argsList = "";
                    foreach (i, arg; mCall.args) {
                        argsList ~= compileNode(arg) ~ (i + 1 < mCall.args.length ? ", " : "");
                    }
                    if (mCall.method == "init") return "gfx_Begin(); gfx_SetDrawBuffer()";
                    if (mCall.method == "end") return "gfx_End()";
                    if (mCall.method == "swap") return "gfx_SwapDraw()";
                    if (mCall.method == "fill") return "gfx_FillScreen(" ~ argsList ~ ")";
                    if (mCall.method == "color") return "gfx_SetColor(" ~ argsList ~ ")";
                    if (mCall.method == "set_rgb") {
                        if (mCall.args.length == 4) {
                            string idx = compileNode(mCall.args[0]);
                            string r = compileNode(mCall.args[1]);
                            string g = compileNode(mCall.args[2]);
                            string b = compileNode(mCall.args[3]);
                            return "gfx_palette[" ~ idx ~ "] = gfx_RGBTo1555(" ~ r ~ ", " ~ g ~ ", " ~ b ~ ")";
                        }
                    }
                    if (mCall.method == "rect") return "gfx_Rectangle(" ~ argsList ~ ")";
                    if (mCall.method == "circle") return "gfx_Circle(" ~ argsList ~ ")";
                    if (mCall.method == "line") return "gfx_Line(" ~ argsList ~ ")";
                    if (mCall.method == "text") {
                        if (mCall.args.length == 3) {
                            string txt = compileNode(mCall.args[0]);
                            string x = compileNode(mCall.args[1]);
                            string y = compileNode(mCall.args[2]);
                            return "gfx_PrintStringXY(" ~ txt ~ ", " ~ x ~ ", " ~ y ~ ")";
                        }
                    }
                    if (mCall.method == "text_color") {
                        if (mCall.args.length == 1) {
                            return "gfx_SetTextFGColor(" ~ compileNode(mCall.args[0]) ~ ")";
                        }
                    }
                }

                string argsList = "";
                foreach (i, arg; mCall.args) {
                    argsList ~= compileNode(arg) ~ (i + 1 < mCall.args.length ? ", " : "");
                }
                return varObj.name ~ "_" ~ mCall.method ~ "(" ~ argsList ~ ")";
            }
            return mCall.toC();
        }
        else if (auto returnNode = cast(ReturnNode)node) {
            string* retT = currentFn in fnReturnTypes;
            return "return " ~ (returnNode.expr ? compileNode(returnNode.expr) : defaultFor(retT is null ? "int" : *retT)) ~ ";";
        }
        else if (auto ifNode = cast(IfNode)node) {
            string code = "if (" ~ stripParens(compileNode(ifNode.cond)) ~ ") {\n";
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
            string code = "while (" ~ stripParens(compileNode(whileNode.cond)) ~ ") {\n";
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
            string savedFn = currentFn;
            currentFn = fnDef.name;
            string retType = "int";
            string* rt = fnDef.name in fnReturnTypes;
            if (rt !is null) retType = *rt;
            string params = "";
            foreach (i, p; fnDef.params) {
                params ~= cTypeOf(typeOfVar(p)) ~ " " ~ p ~ (i + 1 < fnDef.params.length ? ", " : "");
            }
            if (fnDef.params.length == 0) params = "void";
            string fnName = modulePrefix.length > 0 ? modulePrefix ~ "_" ~ fnDef.name : fnDef.name;
            string header = cTypeOf(retType) ~ " " ~ fnName ~ "(" ~ params ~ ")";
            functionProtos ~= header ~ ";";
            string code = header ~ " {\n";
            string staticInits = "";
            if (fnDef.name in fnLocalList) {
                foreach (localName; fnLocalList[fnDef.name]) {
                    bool isParam = false;
                    foreach (p; fnDef.params) {
                        if (p == localName) isParam = true;
                    }
                    if (isParam) continue;
                    string lt = typeOfVar(localName);
                    if (lt.length == 0) lt = "int";
                    if (hasTryStmt(fnDef.body)) {
                        code ~= "    static " ~ cTypeOf(lt) ~ " " ~ localName ~ ";\n";
                        staticInits ~= "    " ~ localName ~ " = " ~ defaultFor(lt) ~ ";\n";
                    } else {
                        code ~= "    " ~ cTypeOf(lt) ~ " " ~ localName ~ " = " ~ defaultFor(lt) ~ ";\n";
                    }
                }
            }
            code ~= staticInits;
            bool hasReturn = false;
            foreach (stmt; fnDef.body) {
                if (cast(ReturnNode)stmt) hasReturn = true;
                string line = compileNode(stmt);
                if (line.length > 0 && !line.endsWith(";") && !line.endsWith("}")) line ~= ";";
                code ~= "    " ~ line ~ "\n";
            }
            if (!hasReturn) {
                code ~= "    return " ~ defaultFor(retType) ~ ";\n";
            }
            code ~= "}";
            currentFn = savedFn;
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
        else if (cast(BreakNode)node) {
            return "break;";
        }
        else if (cast(ContinueNode)node) {
            return "continue;";
        }
        else if (auto imp = cast(ImportNode)node) {
            if (imp.modName == "random") return "#include <stdlib.h>";
            if (imp.modName == "math") return "#include <math.h>";
            if (imp.modName == "graphics") return "#include <graphx.h>";
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
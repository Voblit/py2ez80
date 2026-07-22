module parser;
import lexer;
import ast;
import std.conv;
import std.string;
class Parser {
    private Token[] tokens;
    private size_t idx = 0;
    this(Token[] tokens) { this.tokens = tokens; }
    private Token peek() { return tokens[idx]; }
    private Token consume() { return tokens[idx++]; }
    private bool match(TokenType type) {
        if (peek().type == type) { idx++; return true; }
        return false;
    }
    private void expect(TokenType type, string msg) {
        if (!match(type)) {
            throw new Exception("Parser Error on line " ~ to!string(peek().line) ~ ": " ~ msg ~ " (Got: '" ~ peek().value ~ "')");
        }
    }
    ASTNode[] parseProgram() {
        ASTNode[] statements;
        while (peek().type != TokenType.EOF) {
            if (peek().type == TokenType.Newline || peek().type == TokenType.Comma) { consume(); continue; }
            statements ~= parseStatement();
        }
        return statements;
    }
    private ASTNode parseStatement() {
        if (match(TokenType.KwIf)) return parseIf();
        if (match(TokenType.KwWhile)) return parseWhile();
        if (match(TokenType.KwFor)) return parseFor();
        if (match(TokenType.KwDef)) return parseFunctionDef();
        if (match(TokenType.KwClass)) return parseClassDef();
        if (match(TokenType.KwTry)) return parseTryExcept();
        if (match(TokenType.KwImport)) return parseImport();
        if (match(TokenType.KwBreak)) return new BreakNode();
        if (match(TokenType.KwContinue)) return new ContinueNode();
        if (match(TokenType.KwPass)) return new PassNode();
        if (match(TokenType.KwRaise)) return new RaiseNode(parseExpression());
        if (match(TokenType.KwReturn)) return new ReturnNode(peek().type == TokenType.Newline ? null : parseExpression());
        if (peek().type == TokenType.Identifier) {
            size_t save = idx;
            string varName = consume().value;
            if (peek().type == TokenType.PlusAssign || peek().type == TokenType.MinusAssign ||
                peek().type == TokenType.StarAssign || peek().type == TokenType.SlashAssign) {
                string op = consume().value;
                auto expr = parseExpression();
                return new CompoundAssignNode(varName, op, expr);
            }
            ASTNode indexNode = null;
            if (match(TokenType.LBracket)) {
                indexNode = parseExpression();
                expect(TokenType.RBracket, "Expected ']'");
            }
            if (match(TokenType.Assign)) {
                auto expr = parseExpression();
                return new AssignNode(varName, expr, indexNode);
            }
            idx = save;
        }
        return parseExpression();
    }
    private ASTNode parseIf() {
        auto cond = parseExpression();
        expect(TokenType.Colon, "Expected ':'");
        expect(TokenType.Newline, "Expected newline");
        expect(TokenType.Indent, "Expected indented block");
        ASTNode[] thenB;
        while (peek().type != TokenType.Dedent && peek().type != TokenType.EOF) {
            if (peek().type == TokenType.Newline) { consume(); continue; }
            thenB ~= parseStatement();
        }
        expect(TokenType.Dedent, "Expected dedent");
        ASTNode[] elseB;
        if (match(TokenType.KwElif)) elseB ~= parseIf();
        else if (match(TokenType.KwElse)) {
            expect(TokenType.Colon, "Expected ':'");
            expect(TokenType.Newline, "Expected newline");
            expect(TokenType.Indent, "Expected indented block");
            while (peek().type != TokenType.Dedent && peek().type != TokenType.EOF) {
                if (peek().type == TokenType.Newline) { consume(); continue; }
                elseB ~= parseStatement();
            }
            expect(TokenType.Dedent, "Expected dedent");
        }
        return new IfNode(cond, thenB, elseB);
    }
    private ASTNode parseWhile() {
        auto cond = parseExpression();
        expect(TokenType.Colon, "Expected ':'");
        expect(TokenType.Newline, "Expected newline");
        expect(TokenType.Indent, "Expected indented block");
        ASTNode[] body;
        while (peek().type != TokenType.Dedent && peek().type != TokenType.EOF) {
            if (peek().type == TokenType.Newline) { consume(); continue; }
            body ~= parseStatement();
        }
        expect(TokenType.Dedent, "Expected dedent");
        return new WhileNode(cond, body);
    }
    private ASTNode parseFor() {
        string varName = consume().value;
        expect(TokenType.KwIn, "Expected 'in'");
        expect(TokenType.KwRange, "Expected 'range'");
        expect(TokenType.LParen, "Expected '('");
        auto arg1 = parseExpression();
        ASTNode startExpr = new NumberNode(0);
        ASTNode stopExpr = arg1;
        if (match(TokenType.Comma)) {
            startExpr = arg1;
            stopExpr = parseExpression();
        }
        expect(TokenType.RParen, "Expected ')'");
        expect(TokenType.Colon, "Expected ':'");
        expect(TokenType.Newline, "Expected newline");
        expect(TokenType.Indent, "Expected indented block");
        ASTNode[] body;
        while (peek().type != TokenType.Dedent && peek().type != TokenType.EOF) {
            if (peek().type == TokenType.Newline) { consume(); continue; }
            body ~= parseStatement();
        }
        expect(TokenType.Dedent, "Expected dedent");
        return new ForNode(varName, startExpr, stopExpr, body);
    }
    private ASTNode parseFunctionDef() {
        string name = consume().value;
        expect(TokenType.LParen, "Expected '('");
        string[] params;
        if (peek().type != TokenType.RParen) {
            do { params ~= consume().value; } while (match(TokenType.Comma));
        }
        expect(TokenType.RParen, "Expected ')'");
        expect(TokenType.Colon, "Expected ':'");
        expect(TokenType.Newline, "Expected newline");
        expect(TokenType.Indent, "Expected indented block");
        ASTNode[] body;
        while (peek().type != TokenType.Dedent && peek().type != TokenType.EOF) {
            if (peek().type == TokenType.Newline) { consume(); continue; }
            body ~= parseStatement();
        }
        expect(TokenType.Dedent, "Expected dedent");
        return new FunctionDefNode(name, params, body);
    }
    private ASTNode parseClassDef() {
        string className = consume().value;
        string parentName = "";
        if (match(TokenType.LParen)) {
            if (peek().type != TokenType.RParen) parentName = consume().value;
            expect(TokenType.RParen, "Expected ')'");
        }
        expect(TokenType.Colon, "Expected ':'");
        expect(TokenType.Newline, "Expected newline");
        expect(TokenType.Indent, "Expected indented block");
        ASTNode[] body;
        while (peek().type != TokenType.Dedent && peek().type != TokenType.EOF) {
            if (peek().type == TokenType.Newline) { consume(); continue; }
            body ~= parseStatement();
        }
        expect(TokenType.Dedent, "Expected dedent");
        return new ClassDefNode(className, parentName, body);
    }
    private ASTNode parseTryExcept() {
        expect(TokenType.Colon, "Expected ':'");
        expect(TokenType.Newline, "Expected newline");
        expect(TokenType.Indent, "Expected indented block");
        ASTNode[] tryBody;
        while (peek().type != TokenType.Dedent && peek().type != TokenType.EOF) {
            if (peek().type == TokenType.Newline) { consume(); continue; }
            tryBody ~= parseStatement();
        }
        expect(TokenType.Dedent, "Expected dedent");
        expect(TokenType.KwExcept, "Expected 'except'");
        if (peek().type == TokenType.Identifier) consume();
        expect(TokenType.Colon, "Expected ':'");
        expect(TokenType.Newline, "Expected newline");
        expect(TokenType.Indent, "Expected indented block");
        ASTNode[] exceptBody;
        while (peek().type != TokenType.Dedent && peek().type != TokenType.EOF) {
            if (peek().type == TokenType.Newline) { consume(); continue; }
            exceptBody ~= parseStatement();
        }
        expect(TokenType.Dedent, "Expected dedent");
        ASTNode[] finallyBody;
        if (match(TokenType.KwFinally)) {
            expect(TokenType.Colon, "Expected ':'");
            expect(TokenType.Newline, "Expected newline");
            expect(TokenType.Indent, "Expected indented block");
            while (peek().type != TokenType.Dedent && peek().type != TokenType.EOF) {
                if (peek().type == TokenType.Newline) { consume(); continue; }
                finallyBody ~= parseStatement();
            }
            expect(TokenType.Dedent, "Expected dedent");
        }
        return new TryExceptNode(tryBody, exceptBody, finallyBody);
    }
    private ASTNode parseImport() {
        string modName = consume().value;
        return new ImportNode(modName);
    }
    private ASTNode parseExpression() { return parseLogicalOr(); }
    private ASTNode parseLogicalOr() {
        auto left = parseLogicalAnd();
        while (match(TokenType.KwOr)) left = new BinaryOpNode("||", left, parseLogicalAnd());
        return left;
    }
    private ASTNode parseLogicalAnd() {
        auto left = parseEquality();
        while (match(TokenType.KwAnd)) left = new BinaryOpNode("&&", left, parseEquality());
        return left;
    }
    private ASTNode parseEquality() {
        auto left = parseRelational();
        while (peek().type == TokenType.EqualEqual || peek().type == TokenType.NotEqual) {
            string op = consume().value;
            left = new BinaryOpNode(op, left, parseRelational());
        }
        return left;
    }
    private ASTNode parseRelational() {
        auto left = parseAdditive();
        while (peek().type == TokenType.Less || peek().type == TokenType.Greater ||
               peek().type == TokenType.LessEqual || peek().type == TokenType.GreaterEqual) {
            string op = consume().value;
            left = new BinaryOpNode(op, left, parseAdditive());
        }
        return left;
    }
    private ASTNode parseAdditive() {
        auto left = parseTerm();
        while (peek().type == TokenType.Plus || peek().type == TokenType.Minus) {
            string op = consume().value;
            left = new BinaryOpNode(op, left, parseTerm());
        }
        return left;
    }
    private ASTNode parseTerm() {
        auto left = parseUnary();
        while (peek().type == TokenType.Star || peek().type == TokenType.Slash || peek().type == TokenType.Percent) {
            string op = consume().value;
            left = new BinaryOpNode(op, left, parseUnary());
        }
        return left;
    }
    private ASTNode parseUnary() {
        if (match(TokenType.KwNot)) return new UnaryOpNode("!", parseUnary());
        if (match(TokenType.Minus)) return new UnaryOpNode("-", parseUnary());
        return parseFactor();
    }
    private ASTNode parseFactor() {
        if (peek().type == TokenType.Number) {
            string val = consume().value;
            return new NumberNode(to!double(val), val.indexOf('.') != -1);
        }
        if (match(TokenType.KwTrue)) return new BoolNode(true);
        if (match(TokenType.KwFalse)) return new BoolNode(false);
        if (peek().type == TokenType.StringLiteral) return new StringNode(consume().value);
        if (match(TokenType.LBracket)) {
            ASTNode[] elems;
            if (peek().type != TokenType.RBracket) {
                auto first = parseExpression();
                if (match(TokenType.KwFor)) {
                    string varName = consume().value;
                    expect(TokenType.KwIn, "Expected 'in'");
                    auto iter = parseExpression();
                    expect(TokenType.RBracket, "Expected ']'");
                    return new ListCompNode(first, varName, iter);
                }
                elems ~= first;
                while (match(TokenType.Comma)) {
                    if (peek().type == TokenType.RBracket) break;
                    elems ~= parseExpression();
                }
            }
            expect(TokenType.RBracket, "Expected ']'");
            return new ListNode(elems);
        }
        if (match(TokenType.LParen)) {
            auto first = parseExpression();
            if (match(TokenType.Comma)) {
                ASTNode[] elems = [first];
                do {
                    if (peek().type == TokenType.RParen) break;
                    elems ~= parseExpression();
                } while (match(TokenType.Comma));
                expect(TokenType.RParen, "Expected ')'");
                return new TupleNode(elems);
            }
            expect(TokenType.RParen, "Expected ')'");
            return first;
        }
        if (match(TokenType.LBrace)) {
            ASTNode[] keys, values;
            if (peek().type != TokenType.RBrace) {
                auto first = parseExpression();
                if (match(TokenType.Colon)) {
                    keys ~= first;
                    values ~= parseExpression();
                    while (match(TokenType.Comma)) {
                        if (peek().type == TokenType.RBrace) break;
                        keys ~= parseExpression();
                        expect(TokenType.Colon, "Expected ':'");
                        values ~= parseExpression();
                    }
                    expect(TokenType.RBrace, "Expected '}'");
                    return new DictNode(keys, values);
                } else {
                    keys ~= first;
                    while (match(TokenType.Comma)) {
                        if (peek().type == TokenType.RBrace) break;
                        keys ~= parseExpression();
                    }
                    expect(TokenType.RBrace, "Expected '}'");
                    return new SetNode(keys);
                }
            }
            expect(TokenType.RBrace, "Expected '}'");
            return new DictNode([], []);
        }
        if (peek().type == TokenType.Identifier) {
            string name = consume().value;
            ASTNode base = new VarNode(name);
            while (peek().type == TokenType.Dot || peek().type == TokenType.LParen || peek().type == TokenType.LBracket) {
                if (match(TokenType.Dot)) {
                    string member = consume().value;
                    if (match(TokenType.LParen)) {
                        ASTNode[] args;
                        if (peek().type != TokenType.RParen) {
                            do { args ~= parseExpression(); } while (match(TokenType.Comma));
                        }
                        expect(TokenType.RParen, "Expected ')'");
                        base = new MethodCallNode(base, member, args);
                    } else {
                        base = new MemberAccessNode(base, member);
                    }
                } else if (match(TokenType.LParen)) {
                    ASTNode[] args;
                    if (peek().type != TokenType.RParen) {
                        do { args ~= parseExpression(); } while (match(TokenType.Comma));
                    }
                    expect(TokenType.RParen, "Expected ')'");
                    base = new CallNode(name, args);
                } else if (match(TokenType.LBracket)) {
                    auto idxExpr = parseExpression();
                    expect(TokenType.RBracket, "Expected ']'");
                    base = new IndexNode(name, idxExpr);
                }
            }
            return base;
        }
        throw new Exception("Unexpected token in expression: '" ~ peek().value ~ "' on line " ~ to!string(peek().line));
    }
}
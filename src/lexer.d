module lexer;

import std.ascii;
import std.conv;
import std.string;

enum TokenType {
    Identifier, Number, StringLiteral, Assign, 
    Plus, Minus, Star, Slash, Percent,
    EqualEqual, NotEqual, Less, Greater, LessEqual, GreaterEqual,
    PlusAssign, MinusAssign, StarAssign, SlashAssign,
    Colon, Indent, Dedent, Newline,
    KwIf, KwElif, KwElse, KwWhile, KwFor, KwIn, KwRange,
    KwDef, KwReturn, KwAnd, KwOr, KwNot, KwTrue, KwFalse,
    KwBreak, KwContinue, KwPass, KwClass, KwTry, KwExcept, KwFinally, KwRaise, KwImport, KwFrom,
    LParen, RParen, LBracket, RBracket, LBrace, RBrace, Comma, Dot, EOF
}

struct Token {
    TokenType type;
    string value;
    size_t line;
}

class Lexer {
    private string src;
    private size_t pos = 0;
    private size_t line = 1;
    private int[] indentStack = [0];

    this(string src) { this.src = src; }

    Token[] tokenize() {
        Token[] tokens;

        while (pos < src.length) {
            char c = src[pos];

            if (c == '\n') {
                tokens ~= Token(TokenType.Newline, "\\n", line);
                pos++; line++;
                size_t indentLen = 0;
                while (pos < src.length && (src[pos] == ' ' || src[pos] == '\t')) {
                    indentLen += (src[pos] == '\t') ? 4 : 1;
                    pos++;
                }

                if (pos < src.length && src[pos] != '\n' && src[pos] != '#') {
                    int currentIndent = indentStack[$-1];
                    if (cast(int)indentLen > currentIndent) {
                        indentStack ~= cast(int)indentLen;
                        tokens ~= Token(TokenType.Indent, "", line);
                    } else {
                        while (indentStack.length > 1 && cast(int)indentLen < indentStack[$-1]) {
                            indentStack = indentStack[0 .. $-1];
                            tokens ~= Token(TokenType.Dedent, "", line);
                        }
                    }
                }
                continue;
            }

            if (isWhite(c)) { pos++; continue; }

            if (c == '#') {
                while (pos < src.length && src[pos] != '\n') pos++;
                continue;
            }

            if (c == '"' || c == '\'') {
                char quote = c; pos++; size_t start = pos;
                while (pos < src.length && src[pos] != quote) pos++;
                string strVal = src[start .. pos];
                if (pos < src.length) pos++;
                tokens ~= Token(TokenType.StringLiteral, strVal, line);
                continue;
            }

            if (isAlpha(c) || c == '_') {
                size_t start = pos;
                while (pos < src.length && (isAlphaNum(src[pos]) || src[pos] == '_')) pos++;
                string val = src[start .. pos];
                TokenType t = TokenType.Identifier;

                if (val == "if") t = TokenType.KwIf;
                else if (val == "elif") t = TokenType.KwElif;
                else if (val == "else") t = TokenType.KwElse;
                else if (val == "while") t = TokenType.KwWhile;
                else if (val == "for") t = TokenType.KwFor;
                else if (val == "in") t = TokenType.KwIn;
                else if (val == "range") t = TokenType.KwRange;
                else if (val == "def") t = TokenType.KwDef;
                else if (val == "return") t = TokenType.KwReturn;
                else if (val == "and") t = TokenType.KwAnd;
                else if (val == "or") t = TokenType.KwOr;
                else if (val == "not") t = TokenType.KwNot;
                else if (val == "True") t = TokenType.KwTrue;
                else if (val == "False") t = TokenType.KwFalse;
                else if (val == "break") t = TokenType.KwBreak;
                else if (val == "continue") t = TokenType.KwContinue;
                else if (val == "pass") t = TokenType.KwPass;
                else if (val == "class") t = TokenType.KwClass;
                else if (val == "try") t = TokenType.KwTry;
                else if (val == "except") t = TokenType.KwExcept;
                else if (val == "finally") t = TokenType.KwFinally;
                else if (val == "raise") t = TokenType.KwRaise;
                else if (val == "import") t = TokenType.KwImport;
                else if (val == "from") t = TokenType.KwFrom;

                tokens ~= Token(t, val, line);
                continue;
            }

            if (isDigit(c)) {
                size_t start = pos;
                while (pos < src.length && (isDigit(src[pos]) || src[pos] == '.')) pos++;
                tokens ~= Token(TokenType.Number, src[start .. pos], line);
                continue;
            }

            if (pos + 1 < src.length) {
                string pair = src[pos .. pos+2];
                if (pair == "==") { tokens ~= Token(TokenType.EqualEqual, "==", line); pos += 2; continue; }
                if (pair == "!=") { tokens ~= Token(TokenType.NotEqual, "!=", line); pos += 2; continue; }
                if (pair == "<=") { tokens ~= Token(TokenType.LessEqual, "<=", line); pos += 2; continue; }
                if (pair == ">=") { tokens ~= Token(TokenType.GreaterEqual, ">=", line); pos += 2; continue; }
                if (pair == "+=") { tokens ~= Token(TokenType.PlusAssign, "+=", line); pos += 2; continue; }
                if (pair == "-=") { tokens ~= Token(TokenType.MinusAssign, "-=", line); pos += 2; continue; }
                if (pair == "*=") { tokens ~= Token(TokenType.StarAssign, "*=", line); pos += 2; continue; }
                if (pair == "/=") { tokens ~= Token(TokenType.SlashAssign, "/=", line); pos += 2; continue; }
            }

            switch (c) {
                case '=': tokens ~= Token(TokenType.Assign, "=", line); break;
                case '+': tokens ~= Token(TokenType.Plus, "+", line); break;
                case '-': tokens ~= Token(TokenType.Minus, "-", line); break;
                case '*': tokens ~= Token(TokenType.Star, "*", line); break;
                case '/': tokens ~= Token(TokenType.Slash, "/", line); break;
                case '%': tokens ~= Token(TokenType.Percent, "%", line); break;
                case '<': tokens ~= Token(TokenType.Less, "<", line); break;
                case '>': tokens ~= Token(TokenType.Greater, ">", line); break;
                case ':': tokens ~= Token(TokenType.Colon, ":", line); break;
                case '(': tokens ~= Token(TokenType.LParen, "(", line); break;
                case ')': tokens ~= Token(TokenType.RParen, ")", line); break;
                case '[': tokens ~= Token(TokenType.LBracket, "[", line); break;
                case ']': tokens ~= Token(TokenType.RBracket, "]", line); break;
                case '{': tokens ~= Token(TokenType.LBrace, "{", line); break;
                case '}': tokens ~= Token(TokenType.RBrace, "}", line); break;
                case ',': tokens ~= Token(TokenType.Comma, ",", line); break;
                case '.': tokens ~= Token(TokenType.Dot, ".", line); break;
                default: break;
            }
            pos++;
        }

        while (indentStack.length > 1) {
            indentStack = indentStack[0 .. $-1];
            tokens ~= Token(TokenType.Dedent, "", line);
        }

        tokens ~= Token(TokenType.EOF, "", line);
        return tokens;
    }
}
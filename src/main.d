import std.stdio;
import std.file;
import std.path;
import std.process;
import std.string;
import std.algorithm;

import lexer;
import parser;
import codegen;

enum RESET   = "\033[0m";
enum RED     = "\033[31m";
enum GREEN   = "\033[32m";
enum YELLOW  = "\033[33m";
enum CYAN    = "\033[36m";

void main(string[] args) {
    bool onlyC = false;
    bool multi = false;
    bool isWizard = false;
    string[] files;

    foreach (arg; args[1 .. $]) {
        if (arg == "--only-c") onlyC = true;
        else if (arg == "--multi") multi = true;
        else if (arg == "--wizard") isWizard = true;
        else files ~= arg;
    }

    if (isWizard || files.length == 0) {
        write(CYAN ~ "file(s)?: " ~ RESET);
        string input = readln().strip();
        if (input.length == 0) return;

        files = input.split();

        write(CYAN ~ "compile to c only? y/n: " ~ RESET);
        string ans = readln().strip().toLower();
        if (ans == "y" || ans == "yes") onlyC = true;
    }

    if (!multi && files.length > 1) {
        files = files[0 .. 1];
    }

    foreach (inFile; files) {
        runPipeline(inFile, onlyC);
    }
}

void runPipeline(string inFile, bool onlyC) {
    if (!exists(inFile)) {
        stderr.writeln(RED ~ "Error: Input file '" ~ inFile ~ "' does not exist." ~ RESET);
        return;
    }

    string rawName = stripExtension(baseName(inFile)).toUpper();
    string appName = rawName[0 .. min($, 8)];

    string currentDir = getcwd();
    
    if (onlyC) {
        string cOutFile = appName ~ ".c";
        writeln(CYAN ~ "[1/1] Transpiling " ~ inFile ~ " -> " ~ cOutFile ~ "..." ~ RESET);

        try {
            string pythonSource = readText(inFile);
            auto lexer = new Lexer(pythonSource);
            auto tokens = lexer.tokenize();
            auto parser = new Parser(tokens);
            auto ast = parser.parseProgram();
            auto generator = new CCodegen();
            generator.generate(ast);

            std.file.write(cOutFile, generator.getSourceCode());
            writeln(GREEN ~ "[Success] Output native C file: " ~ buildPath(currentDir, cOutFile) ~ RESET);
        } catch (Exception e) {
            stderr.writeln(RED ~ "Error: Transpilation failed: " ~ e.msg ~ RESET);
        }
        return;
    }

    string cedevDir = buildPath(currentDir, "CEdev");
    string projectDir = buildPath(cedevDir, "build_project");
    string srcDir = buildPath(projectDir, "src");

    if (!exists(cedevDir)) {
        stderr.writeln(RED ~ "Error: 'CEdev' folder not found at " ~ cedevDir ~ RESET);
        return;
    }

    mkdirRecurse(srcDir);

    string cOutFile = buildPath(srcDir, "main.c");
    string makefileFile = buildPath(projectDir, "Makefile");

    writeln(CYAN ~ "[1/4] Transpiling " ~ inFile ~ " -> " ~ cOutFile ~ "..." ~ RESET);

    string pythonSource = readText(inFile);

    auto lexer = new Lexer(pythonSource);
    auto tokens = lexer.tokenize();

    auto parser = new Parser(tokens);
    auto ast = parser.parseProgram();

    auto generator = new CCodegen();
    generator.generate(ast);

    std.file.write(cOutFile, generator.getSourceCode());

    string makefileContent = 
"NAME = " ~ appName ~ "\n" ~
"DESCRIPTION = \"Py2eZ80 Generated App\"\n" ~
"COMPRESSED = NO\n" ~
"ARCHIVED = NO\n" ~
"\n" ~
"CFLAGS = -Wall -Wextra -Oz\n" ~
"CXXFLAGS = -Wall -Wextra -Oz\n" ~
"\n" ~
"include $(shell cedev-config --makefile)\n";

    std.file.write(makefileFile, makefileContent);

    writeln(CYAN ~ "[2/4] Invoking CEdev toolchain for " ~ appName ~ "..." ~ RESET);

    string buildCmd = "cmd.exe /c \"cd /d \"" ~ projectDir ~ "\" && \"..\\cedev.bat\" make\"";
    auto pid = spawnShell(buildCmd);
    int exitCode = wait(pid);

    if (exitCode != 0) {
        stderr.writeln(RED ~ "Error: CEdev compilation failed!" ~ RESET);
        return;
    }

    string outputBinaryName = appName ~ ".8xp";
    string builtBinary = buildPath(projectDir, "bin", outputBinaryName);
    string rootBinary = buildPath(currentDir, outputBinaryName);

    if (exists(builtBinary)) {
        writeln(CYAN ~ "[3/4] Copying " ~ outputBinaryName ~ " to root project directory..." ~ RESET);
        copy(builtBinary, rootBinary);
        writeln(GREEN ~ "[4/4] Success! Final calculator output: " ~ rootBinary ~ RESET);
    } else {
        stderr.writeln(RED ~ "Error: Could not find compiled binary at " ~ builtBinary ~ RESET);
    }
}

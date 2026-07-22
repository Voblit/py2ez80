import std.stdio;
import std.file;
import std.path;
import std.process;
import std.string;
import std.algorithm;

import lexer;
import parser;
import codegen;

void main(string[] args) {
    if (args.length < 2) {
        writeln("Usage: py2ez80 <input.py>");
        return;
    }

    string inFile = args[1];
    if (!exists(inFile)) {
        stderr.writeln("Error: Input file '", inFile, "' does not exist.");
        return;
    }

    string rawName = stripExtension(baseName(inFile)).toUpper();
    string appName = rawName[0 .. min($, 8)];

    string currentDir = getcwd();
    string cedevDir = buildPath(currentDir, "CEdev");
    string projectDir = buildPath(cedevDir, "build_project");
    string srcDir = buildPath(projectDir, "src");

    if (!exists(cedevDir)) {
        stderr.writeln("Error: 'CEdev' folder not found at ", cedevDir);
        return;
    }

    mkdirRecurse(srcDir);

    string cOutFile = buildPath(srcDir, "main.c");
    string makefileFile = buildPath(projectDir, "Makefile");

    writeln("[1/4] Transpiling ", inFile, " -> ", cOutFile, "...");

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

    writeln("[2/4] Invoking CEdev toolchain for ", appName, "...");

    string buildCmd = "cmd.exe /c \"cd /d \"" ~ projectDir ~ "\" && \"..\\cedev.bat\" make\"";
    auto pid = spawnShell(buildCmd);
    int exitCode = wait(pid);

    if (exitCode != 0) {
        stderr.writeln("Error: CEdev compilation failed!");
        return;
    }

    string outputBinaryName = appName ~ ".8xp";
    string builtBinary = buildPath(projectDir, "bin", outputBinaryName);
    string rootBinary = buildPath(currentDir, outputBinaryName);

    if (exists(builtBinary)) {
        writeln("[3/4] Copying ", outputBinaryName, " to root project directory...");
        copy(builtBinary, rootBinary);
        writeln("[4/4] Success! Final calculator output: ", rootBinary);
    } else {
        stderr.writeln("Error: Could not find compiled binary at ", builtBinary);
    }
}

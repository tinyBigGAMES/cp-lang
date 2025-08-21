{===============================================================================
              _
  __ _ __ ___| |__ _ _ _  __ _ ™
 / _| '_ \___| / _` | ' \/ _` |
 \__| .__/   |_\__,_|_||_\__, |
    |_|                  |___/
    C Power | Pascal Clarity

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://cp-lang.org/

 See LICENSE file for license agreement
===============================================================================}

program CPTestbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  UELTestbed in 'UELTestbed.pas',
  CPLang.Common in '..\..\src\CPLang.Common.pas',
  CPLang.Compiler in '..\..\src\CPLang.Compiler.pas',
  CPLang.Errors in '..\..\src\CPLang.Errors.pas',
  CPLang.Include in '..\..\src\CPLang.Include.pas',
  CPLang.IRContext in '..\..\src\CPLang.IRContext.pas',
  CPLang.JIT in '..\..\src\CPLang.JIT.pas',
  CPLang.Lexer in '..\..\src\CPLang.Lexer.pas',
  CPLang.LLVM in '..\..\src\CPLang.LLVM.pas',
  CPLang.Parser in '..\..\src\CPLang.Parser.pas',
  CPLang.Platform in '..\..\src\CPLang.Platform.pas',
  CPLang.Resources in '..\..\src\CPLang.Resources.pas',
  CPLang.Semantic in '..\..\src\CPLang.Semantic.pas',
  CPLang.SourceMap in '..\..\src\CPLang.SourceMap.pas',
  CPLang.Symbols in '..\..\src\CPLang.Symbols.pas',
  CPLang.TypeChecker in '..\..\src\CPLang.TypeChecker.pas',
  CPLang.Types in '..\..\src\CPLang.Types.pas',
  CPLang.CodeGen in '..\..\src\CPLang.CodeGen.pas';

begin
  RunTests();
end.

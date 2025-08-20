{===============================================================================
   ___    _
  | __|__| |   __ _ _ _  __ _ ™
  | _|___| |__/ _` | ' \/ _` |
  |___|  |____\__,_|_||_\__, |
                        |___/
    C Power | Pascal Clarity

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.

 https://github.com/tinyBigGAMES/e-lang

 See LICENSE file for license agreement
===============================================================================}

program ELTestbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  UELTestbed in 'UELTestbed.pas',
  ELang.Common in '..\..\src\ELang.Common.pas',
  ELang.Compiler in '..\..\src\ELang.Compiler.pas',
  ELang.Errors in '..\..\src\ELang.Errors.pas',
  ELang.Include in '..\..\src\ELang.Include.pas',
  ELang.IRContext in '..\..\src\ELang.IRContext.pas',
  ELang.JIT in '..\..\src\ELang.JIT.pas',
  ELang.Lexer in '..\..\src\ELang.Lexer.pas',
  ELang.LLVM in '..\..\src\ELang.LLVM.pas',
  ELang.Parser in '..\..\src\ELang.Parser.pas',
  ELang.Platform in '..\..\src\ELang.Platform.pas',
  ELang.Resources in '..\..\src\ELang.Resources.pas',
  ELang.Semantic in '..\..\src\ELang.Semantic.pas',
  ELang.SourceMap in '..\..\src\ELang.SourceMap.pas',
  ELang.Symbols in '..\..\src\ELang.Symbols.pas',
  ELang.TypeChecker in '..\..\src\ELang.TypeChecker.pas',
  ELang.Types in '..\..\src\ELang.Types.pas',
  ELang.CodeGen in '..\..\src\ELang.CodeGen.pas';

begin
  RunTests();
end.

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

unit UELTestbed;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.IOUtils,
  CPLang.Types,
  CPLang.Common,
  CPLang.Compiler,
  CPLang.Parser,
  CPLang.SourceMap,
  CPLang.Errors,
  CPLang.JIT,
  CPLang.Platform;

procedure RunTests();

implementation

procedure DisplayAST(const ANode: TCPASTNode; const AIndent: Integer = 0);
var
  LIndex: Integer;
  LIndentStr: string;
begin
  if not Assigned(ANode) then
    Exit;

  LIndentStr := StringOfChar(' ', AIndent * 2);

  CPPrintLn('%s%s: %s', [LIndentStr, GetEnumName(TypeInfo(TCPASTNodeType), Ord(ANode.NodeType)), ANode.Value]);

  for LIndex := 0 to ANode.ChildCount() - 1 do
    DisplayAST(ANode.GetChild(LIndex), AIndent + 1);
end;

procedure DisplayErrors(const ACompiler: TCPCompiler);
var
  LErrors: TArray<TCPCompilerError>;
  LWarnings: TArray<TCPCompilerError>;
  LError: TCPCompilerError;
begin
  LErrors := ACompiler.GetErrors();
  LWarnings := ACompiler.GetWarnings();

  if Length(LErrors) > 0 then
  begin
    CPPrintLn('=== COMPILATION ERRORS ===');
    for LError in LErrors do
    begin
      CPPrintLn('ERROR: %s', [LError.ToString()]);
    end;
    CPPrintLn('');
  end;

  if Length(LWarnings) > 0 then
  begin
    CPPrintLn('=== COMPILATION WARNINGS ===');
    for LError in LWarnings do
    begin
      CPPrintLn(Format('WARNING: %s', [LError.ToString()]));
    end;
    CPPrintLn('');
  end;
end;

procedure CompileFile(const AFileName: string);
var
  LCompiler: TCPCompiler;
  LResult: TCPCompilationResult;
begin
  CPPrintLn('=== CP-Lang Compiler Test ===');
  CPPrintLn('');

  LCompiler := TCPCompiler.Create();
  try
    try  // ← EXCEPTION HANDLING BLOCK
      LCompiler.OnProgress := procedure (const AProgressInfo: TCPProgressInfo)
        begin
          CPPrint(#13+'[%3d%%] %s - %s (%s)', [
            AProgressInfo.OverallPercent,
            AProgressInfo.PhaseDescription,
            AProgressInfo.ElapsedTime,
            AProgressInfo.DetailMessage
          ]);
          CPClearToEOL();
        end;

      LResult := LCompiler.CompileFile(AFileName);
      try  // ← RESOURCE CLEANUP FOR LResult
        if not LResult.MergedSource.IsEmpty then
        begin
          CPPrintLn('');
          CPPrintLn('--- SOURCE ---');
          CPPrintLn(LResult.MergedSource);
        end;

        CPPrintLn('');
        CPPrintLn('Phase reached: %s', [GetEnumName(TypeInfo(TCPCompilationPhase), Ord(LResult.Phase))]);
        CPPrintLn('Success: %s', [BoolToStr(LResult.Success, True)]);
        CPPrintLn('Merged source: %d characters', [Length(LResult.MergedSource)]);
        CPPrintLn('Tokens generated: %d', [LResult.TokenCount]);
        CPPrintLn('Errors: %d, Warnings: %d', [LResult.ErrorCount, LResult.WarningCount]);
        CPPrintLn('');

        if LResult.Success then
        begin
          CPPrintLn('=== COMPILATION SUCCESSFUL ===');
          CPPrintLn('');

          CPPrintLn('--- IR SOURCE ---');
          CPPrintLn(LResult.GeneratedIR);

          CPPrintLn('--- JIT ---');
          CPPrintLn('Exit Code: %d', [CPJITIRFromString(LResult.GeneratedIR)]);

          if Assigned(LResult.AST) then
          begin
            CPPrintLn('=== AST STRUCTURE ===');
            DisplayAST(LResult.AST);
            CPPrintLn('');
          end;

          CPPrintLn('=== TYPE SYSTEM INFO ===');
          CPPrintLn('int32: %s (size: %d bytes)', [
            LCompiler.TypeManager.GetBasicType(btInt32).GetTypeName(),
            LCompiler.TypeManager.GetBasicType(btInt32).GetSize()
          ]);
          CPPrintLn('char: %s (size: %d bytes)', [
            LCompiler.TypeManager.GetBasicType(btChar).GetTypeName(),
            LCompiler.TypeManager.GetBasicType(btChar).GetSize()
          ]);
          CPPrintLn('');
        end
        else
        begin
          CPPrintLn('=== COMPILATION FAILED ===');
          CPPrintLn('');
          DisplayErrors(LCompiler);
        end;

      finally
        LResult.Free();  // ← ALWAYS CLEANUP LResult
      end;

    except  // ← EXCEPTION HANDLERS COME AFTER ALL try/finally BLOCKS
      on E: ECPException do
      begin
        CPPrintLn('');
        CPPrintLn('=== UNHANDLED COMPILATION ERROR ===');
        CPPrintLn('Error: %s', [E.Message]);
        CPPrintLn('Category: %s', [E.ErrorCategory]);
        if E.SourceFileName <> '' then
        begin
          CPPrintLn('Location: %s', [E.GetFormattedLocation()]);
          if E.ContextInfo <> '' then
            CPPrintLn('Context: %s', [E.ContextInfo]);
          if E.Suggestion <> '' then
            CPPrintLn('Suggestion: %s', [E.Suggestion]);
        end;
        CPPrintLn('');
      end;
      on E: Exception do
      begin
        CPPrintLn('');
        CPPrintLn('=== INTERNAL COMPILER ERROR ===');
        CPPrintLn(Format('Error: %s', [E.Message]));
        CPPrintLn(Format('Type: %s', [E.ClassName]));
        CPPrintLn('This indicates a bug in the compiler itself.');
        CPPrintLn('');
      end;
    end;

  finally
    LCompiler.Free();  // ← ALWAYS CLEANUP LCompiler
  end;
end;

procedure RunTests();
begin
  try
    CompileFile('test.cp');
  except
    on E: ECPException do
    begin
      CPPrintLn('');
      CPPrintLn('=== E-LANG COMPILATION ERROR ===');
      CPPrintLn(Format('Error: %s', [E.Message]));
      CPPrintLn(Format('Category: %s', [E.ErrorCategory]));
      if E.SourceFileName <> '' then
      begin
        CPPrintLn(Format('Location: %s', [E.GetFormattedLocation()]));
        if E.ContextInfo <> '' then
          CPPrintLn(Format('Context: %s', [E.ContextInfo]));
        if E.Suggestion <> '' then
          CPPrintLn(Format('Suggestion: %s', [E.Suggestion]));
      end;
    end;
    on E: Exception do
    begin
      CPPrintLn('Fatal system error: ' + E.Message);
      CPPrintLn('Type: ' + E.ClassName);
      CPPrintLn('Press Enter to exit...');
    end;
  end;

  CPPause();
end;

end.

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

unit UELTestbed;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.IOUtils,
  ELang.Types,
  ELang.Common,
  ELang.Compiler,
  ELang.Parser,
  ELang.SourceMap,
  ELang.Errors,
  ELang.JIT,
  ELang.Platform;

procedure RunTests();

implementation

procedure DisplayAST(const ANode: TELASTNode; const AIndent: Integer = 0);
var
  LIndex: Integer;
  LIndentStr: string;
begin
  if not Assigned(ANode) then
    Exit;

  LIndentStr := StringOfChar(' ', AIndent * 2);

  WriteLn(Format('%s%s: %s', [LIndentStr, GetEnumName(TypeInfo(TELASTNodeType), Ord(ANode.NodeType)), ANode.Value]));

  for LIndex := 0 to ANode.ChildCount() - 1 do
    DisplayAST(ANode.GetChild(LIndex), AIndent + 1);
end;

procedure DisplayErrors(const ACompiler: TELCompiler);
var
  LErrors: TArray<TELCompilerError>;
  LWarnings: TArray<TELCompilerError>;
  LError: TELCompilerError;
begin
  LErrors := ACompiler.GetErrors();
  LWarnings := ACompiler.GetWarnings();

  if Length(LErrors) > 0 then
  begin
    WriteLn('=== COMPILATION ERRORS ===');
    for LError in LErrors do
    begin
      WriteLn(Format('ERROR: %s', [LError.ToString()]));
    end;
    WriteLn('');
  end;

  if Length(LWarnings) > 0 then
  begin
    WriteLn('=== COMPILATION WARNINGS ===');
    for LError in LWarnings do
    begin
      WriteLn(Format('WARNING: %s', [LError.ToString()]));
    end;
    WriteLn('');
  end;
end;

procedure CompileFile(const AFileName: string);
var
  LCompiler: TELCompiler;
  LResult: TELCompilationResult;
begin
  WriteLn('=== E-Lang Compiler Test ===');
  WriteLn('');

  if not TFile.Exists(AFileName) then
  begin
    WriteLn('Error: File not found: ' + AFileName);
    Exit;
  end;

  LCompiler := TELCompiler.Create();
  try
    try  // ← EXCEPTION HANDLING BLOCK
      LCompiler.OnProgress := procedure (const AProgressInfo: TELProgressInfo)
        begin
          Write(Format(#13+'[%3d%%] %s - %s (%s)', [
            AProgressInfo.OverallPercent,
            AProgressInfo.PhaseDescription,
            AProgressInfo.ElapsedTime,
            AProgressInfo.DetailMessage
          ]));
        end;

      //WriteLn('Compiling: ' + AFileName);
      //WriteLn('');
      LResult := LCompiler.CompileFile(AFileName);
      try  // ← RESOURCE CLEANUP FOR LResult
        writeln;
        writeln('--- SOURCE ---');
        writeln(LResult.MergedSource);

        WriteLn;
        WriteLn(Format('Phase reached: %s', [GetEnumName(TypeInfo(TELCompilationPhase), Ord(LResult.Phase))]));
        WriteLn(Format('Success: %s', [BoolToStr(LResult.Success, True)]));
        WriteLn(Format('Merged source: %d characters', [Length(LResult.MergedSource)]));
        WriteLn(Format('Tokens generated: %d', [LResult.TokenCount]));
        WriteLn(Format('Errors: %d, Warnings: %d', [LResult.ErrorCount, LResult.WarningCount]));
        WriteLn('');

        if LResult.Success then
        begin
          WriteLn('=== COMPILATION SUCCESSFUL ===');
          WriteLn('');

          writeln('--- IR SOURCE ---');
          writeln(LResult.GeneratedIR);

          WriteLn('--- JIT ---');
          WriteLn('Exit Code: ', ELJITIRFromString(LResult.GeneratedIR));

          (*
          if Assigned(LResult.AST) then
          begin
            WriteLn('=== AST STRUCTURE ===');
            DisplayAST(LResult.AST);
            WriteLn('');
          end;

          WriteLn('=== TYPE SYSTEM INFO ===');
          WriteLn(Format('int32: %s (size: %d bytes)', [
            LCompiler.TypeManager.GetBasicType(btInt32).GetTypeName(),
            LCompiler.TypeManager.GetBasicType(btInt32).GetSize()
          ]));
          WriteLn(Format('char: %s (size: %d bytes)', [
            LCompiler.TypeManager.GetBasicType(btChar).GetTypeName(),
            LCompiler.TypeManager.GetBasicType(btChar).GetSize()
          ]));
          WriteLn('');
          *)
        end
        else
        begin
          WriteLn('=== COMPILATION FAILED ===');
          WriteLn('');
          DisplayErrors(LCompiler);
        end;

      finally
        LResult.Free();  // ← ALWAYS CLEANUP LResult
      end;

    except  // ← EXCEPTION HANDLERS COME AFTER ALL try/finally BLOCKS
      on E: EELException do
      begin
        WriteLn('');
        WriteLn('=== UNHANDLED COMPILATION ERROR ===');
        WriteLn(Format('Error: %s', [E.Message]));
        WriteLn(Format('Category: %s', [E.ErrorCategory]));
        if E.SourceFileName <> '' then
        begin
          WriteLn(Format('Location: %s', [E.GetFormattedLocation()]));
          if E.ContextInfo <> '' then
            WriteLn(Format('Context: %s', [E.ContextInfo]));
          if E.Suggestion <> '' then
            WriteLn(Format('Suggestion: %s', [E.Suggestion]));
        end;
        WriteLn('');
      end;
      on E: Exception do
      begin
        WriteLn('');
        WriteLn('=== INTERNAL COMPILER ERROR ===');
        WriteLn(Format('Error: %s', [E.Message]));
        WriteLn(Format('Type: %s', [E.ClassName]));
        WriteLn('This indicates a bug in the compiler itself.');
        WriteLn('');
      end;
    end;

  finally
    LCompiler.Free();  // ← ALWAYS CLEANUP LCompiler
  end;
end;


procedure RunTests();
begin
  try
    CompileFile('test.e');
  except
    on E: EELException do
    begin
      WriteLn('');
      WriteLn('=== E-LANG COMPILATION ERROR ===');
      WriteLn(Format('Error: %s', [E.Message]));
      WriteLn(Format('Category: %s', [E.ErrorCategory]));
      if E.SourceFileName <> '' then
      begin
        WriteLn(Format('Location: %s', [E.GetFormattedLocation()]));
        if E.ContextInfo <> '' then
          WriteLn(Format('Context: %s', [E.ContextInfo]));
        if E.Suggestion <> '' then
          WriteLn(Format('Suggestion: %s', [E.Suggestion]));
      end;
      WriteLn('');
      WriteLn('Press Enter to exit...');
      ReadLn;
    end;
    on E: Exception do
    begin
      WriteLn('Fatal system error: ' + E.Message);
      WriteLn('Type: ' + E.ClassName);
      WriteLn('Press Enter to exit...');
      ReadLn;
    end;
  end;

  ELPause();
end;

end.

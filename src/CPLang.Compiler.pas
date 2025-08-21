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

unit CPLang.Compiler;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Diagnostics,
  System.Generics.Collections,
  CPLang.Common,
  CPLang.Include,
  CPLang.Lexer,
  CPLang.Parser,
  CPLang.Types,
  CPLang.Symbols,
  CPLang.Semantic,
  CPLang.CodeGen,
  CPLang.SourceMap,
  CPLang.Errors,
  CPLang.LLVM;

type
  { TCPCompilationPhase }
  TCPCompilationPhase = (
    cpIncludeProcessing,
    cpLexicalAnalysis,
    cpSyntaxAnalysis,
    cpSemanticAnalysis,
    cpCodeGeneration,
    cpComplete
  );

  { TCPCompilationResult }
  TCPCompilationResult = class
  private
    FSuccess: Boolean;
    FPhase: TCPCompilationPhase;
    FAST: TCPASTNode;
    FGeneratedIR: string;
    FMergedSource: string;
    FTokenCount: Integer;
    FErrorCount: Integer;
    FWarningCount: Integer;
    
  public
    constructor Create();
    destructor Destroy(); override;
    
    property Success: Boolean read FSuccess write FSuccess;
    property Phase: TCPCompilationPhase read FPhase write FPhase;
    property AST: TCPASTNode read FAST write FAST;
    property GeneratedIR: string read FGeneratedIR write FGeneratedIR;
    property MergedSource: string read FMergedSource write FMergedSource;
    property TokenCount: Integer read FTokenCount write FTokenCount;
    property ErrorCount: Integer read FErrorCount write FErrorCount;
    property WarningCount: Integer read FWarningCount write FWarningCount;
  end;

  { TCPProgressInfo }
  TCPProgressInfo = record
    PhaseDescription: string;
    OverallPercent: Integer;
    PhasePercent: Integer;
    ElapsedTime: string;
    EstimatedRemaining: string;
    CurrentFile: string;
    DetailMessage: string;
    ItemsProcessed: string;
    TotalItems: string;
    IsComplete: Boolean;
  end;

  { TCPCompilerProgress }
  TCPCompilerProgress = reference to procedure(const AProgressInfo: TCPProgressInfo);

  { TCPCompiler }
  TCPCompiler = class
  private
    FIncludeManager: TCPIncludeManager;
    FLexer: TCPLexer;
    FParser: TCPParser;
    FTypeManager: TCPTypeManager;
    FSemanticAnalyzer: TCPSemanticAnalyzer;
    FErrorCollector: TCPErrorCollector;
    
    FCurrentResult: TCPCompilationResult;
    FTokens: TArray<TCPToken>;
    FMainFileName: string; // Store main filename for module name
    
    // Progress reporting fields
    FProgressCallback: TCPCompilerProgress;
    FOverallStopwatch: TStopwatch;
    FPhaseStopwatch: TStopwatch;
    FProgressUpdateInterval: Integer;
    FLastProgressReport: Int64;
    FCurrentPhaseWeight: Double;
    FPhaseStartProgress: Double;
    
    function ProcessIncludes(const AMainFileName: string): Boolean;
    function PerformLexicalAnalysis(): Boolean;
    function PerformSyntaxAnalysis(): Boolean;
    function PerformSemanticAnalysis(): Boolean;
    function PerformCodeGeneration(): Boolean;
    {$HINTS OFF}
    function CreateCompilationError(const AMessage: string; const AToken: TCPToken): TCPCompilerError;
    {$HINTS ON}
    
    // Progress reporting methods
    procedure ReportProgress(const APhaseProgress: Double; const ADetailMessage: string = '');
    function FormatElapsedTime(const AMilliseconds: Int64): string;
    function FormatEstimatedTime(const AMilliseconds: Int64): string;
    function CalculateOverallProgress(const APhaseProgress: Double): Integer;
    function GetPhaseDescription(const APhase: TCPCompilationPhase): string;
    {$HINTS OFF}
    function FormatItemCount(const ACount: Integer; const AItemType: string): string;
    {$HINTS ON}
    function GetPhaseWeight(const APhase: TCPCompilationPhase): Double;
    procedure StartPhase(const APhase: TCPCompilationPhase);
    {$HINTS OFF}
    procedure CheckProgressUpdate(const AItemsProcessed, ATotalItems: Integer; const ADetailMessage: string = '');
    {$HINTS ON}

  public
    constructor Create();
    destructor Destroy(); override;
    
    function CompileFile(const AFileName: string): TCPCompilationResult;
    function CompileSource(const ASource: string; const AFileName: string): TCPCompilationResult;
    
    function GetErrors(): TArray<TCPCompilerError>;
    function GetWarnings(): TArray<TCPCompilerError>;
    function GetErrorsByPhase(const APhase: TCPCompilationPhase): TArray<TCPCompilerError>;
    
    function HasErrors(): Boolean;
    function HasWarnings(): Boolean;
    function ErrorCount(): Integer;
    function WarningCount(): Integer;
    
    procedure ClearErrors();
    function GetSourcePosition(const ACharIndex: Integer): TCPSourcePosition;
    function GetSourceLine(const ACharIndex: Integer): string;
    
    // Access to internal components (for advanced usage)
    property IncludeManager: TCPIncludeManager read FIncludeManager;
    property TypeManager: TCPTypeManager read FTypeManager;
    property SemanticAnalyzer: TCPSemanticAnalyzer read FSemanticAnalyzer;
    property ErrorCollector: TCPErrorCollector read FErrorCollector;
    property OnProgress: TCPCompilerProgress read FProgressCallback write FProgressCallback;
  end;

{ Routines }
function CPCompileFile(const AFileName: string): TCPCompilationResult;
function CPCompileSource(const ASource: string; const AFileName: string = '<source>'): TCPCompilationResult;

implementation

{ Routines }
function CPCompileFile(const AFileName: string): TCPCompilationResult;
var
  LCompiler: TCPCompiler;
begin
  LCompiler := TCPCompiler.Create();
  try
    Result := LCompiler.CompileFile(AFileName);
  finally
    LCompiler.Free();
  end;
end;

function CPCompileSource(const ASource: string; const AFileName: string): TCPCompilationResult;
var
  LCompiler: TCPCompiler;
begin
  LCompiler := TCPCompiler.Create();
  try
    Result := LCompiler.CompileSource(ASource, AFileName);
  finally
    LCompiler.Free();
  end;
end;

{ TCPCompilationResult }
constructor TCPCompilationResult.Create();
begin
  inherited;
  FSuccess := False;
  FPhase := cpIncludeProcessing;
  FAST := nil;
  FGeneratedIR := '';
  FMergedSource := '';
  FTokenCount := 0;
  FErrorCount := 0;
  FWarningCount := 0;
end;

destructor TCPCompilationResult.Destroy();
begin
  FAST.Free();
  inherited;
end;

{ Progress reporting methods }

function TCPCompiler.GetPhaseWeight(const APhase: TCPCompilationPhase): Double;
begin
  if APhase = cpIncludeProcessing then
    Result := 0.10
  else if APhase = cpLexicalAnalysis then
    Result := 0.20
  else if APhase = cpSyntaxAnalysis then
    Result := 0.30
  else if APhase = cpSemanticAnalysis then
    Result := 0.25
  else if APhase = cpCodeGeneration then
    Result := 0.15
  else if APhase = cpComplete then
    Result := 0.00
  else
    Result := 0.0;
end;

function TCPCompiler.GetPhaseDescription(const APhase: TCPCompilationPhase): string;
begin
  if APhase = cpIncludeProcessing then
    Result := 'Include Processing'
  else if APhase = cpLexicalAnalysis then
    Result := 'Lexical Analysis'
  else if APhase = cpSyntaxAnalysis then
    Result := 'Syntax Analysis'
  else if APhase = cpSemanticAnalysis then
    Result := 'Semantic Analysis'
  else if APhase = cpCodeGeneration then
    Result := 'Code Generation'
  else if APhase = cpComplete then
    Result := 'Complete'
  else
    Result := 'Unknown';
end;

function TCPCompiler.FormatElapsedTime(const AMilliseconds: Int64): string;
var
  LSeconds: Integer;
  LMinutes: Integer;
begin
  LSeconds := AMilliseconds div 1000;
  if LSeconds < 60 then
    Result := Format('%.1fs', [LSeconds + (AMilliseconds mod 1000) / 1000.0])
  else
  begin
    LMinutes := LSeconds div 60;
    LSeconds := LSeconds mod 60;
    Result := Format('%dm %ds', [LMinutes, LSeconds]);
  end;
end;

function TCPCompiler.FormatEstimatedTime(const AMilliseconds: Int64): string;
var
  LSeconds: Integer;
  LMinutes: Integer;
begin
  if AMilliseconds <= 0 then
  begin
    Result := '--';
    Exit;
  end;
  
  LSeconds := AMilliseconds div 1000;
  if LSeconds < 60 then
    Result := Format('%ds', [LSeconds])
  else
  begin
    LMinutes := LSeconds div 60;
    LSeconds := LSeconds mod 60;
    if LSeconds > 0 then
      Result := Format('%dm %ds', [LMinutes, LSeconds])
    else
      Result := Format('%dm', [LMinutes]);
  end;
end;

function TCPCompiler.FormatItemCount(const ACount: Integer; const AItemType: string): string;
begin
  if ACount >= 1000 then
    Result := Format('%s %s', [FormatFloat('#,##0', ACount), AItemType])
  else
    Result := Format('%d %s', [ACount, AItemType]);
end;

function TCPCompiler.CalculateOverallProgress(const APhaseProgress: Double): Integer;
var
  LOverallProgress: Double;
begin
  LOverallProgress := FPhaseStartProgress + (FCurrentPhaseWeight * APhaseProgress);
  Result := Round(LOverallProgress * 100);
  if Result > 100 then
    Result := 100;
end;

procedure TCPCompiler.StartPhase(const APhase: TCPCompilationPhase);
begin
  // Update current phase info
  FCurrentPhaseWeight := GetPhaseWeight(APhase);
  
  // Calculate where this phase starts in overall progress
  FPhaseStartProgress := 0.0;
  if APhase > cpIncludeProcessing then
    FPhaseStartProgress := FPhaseStartProgress + GetPhaseWeight(cpIncludeProcessing);
  if APhase > cpLexicalAnalysis then
    FPhaseStartProgress := FPhaseStartProgress + GetPhaseWeight(cpLexicalAnalysis);
  if APhase > cpSyntaxAnalysis then
    FPhaseStartProgress := FPhaseStartProgress + GetPhaseWeight(cpSyntaxAnalysis);
  if APhase > cpSemanticAnalysis then
    FPhaseStartProgress := FPhaseStartProgress + GetPhaseWeight(cpSemanticAnalysis);
  if APhase > cpCodeGeneration then
    FPhaseStartProgress := FPhaseStartProgress + GetPhaseWeight(cpCodeGeneration);
  
  // Start phase timing
  FPhaseStopwatch := TStopwatch.StartNew();
  
  // Report phase start
  ReportProgress(0.0, 'Starting ' + GetPhaseDescription(APhase).ToLower());
end;

procedure TCPCompiler.ReportProgress(const APhaseProgress: Double; const ADetailMessage: string);
var
  LProgressInfo: TCPProgressInfo;
  LPhasePercent: Integer;
  LElapsedMs: Int64;
  LEstimatedTotal: Int64;
  LEstimatedRemaining: Int64;
begin
  if not Assigned(FProgressCallback) then
    Exit;

  // Calculate percentages
  LPhasePercent := Round(APhaseProgress * 100);
  if LPhasePercent > 100 then
    LPhasePercent := 100;

  // Fill progress info record
  LProgressInfo.PhaseDescription := GetPhaseDescription(FCurrentResult.Phase);
  LProgressInfo.OverallPercent := CalculateOverallProgress(APhaseProgress);
  LProgressInfo.PhasePercent := LPhasePercent;
  LProgressInfo.ElapsedTime := FormatElapsedTime(FOverallStopwatch.ElapsedMilliseconds);

  // Calculate estimated remaining time
  if LProgressInfo.OverallPercent > 0 then
  begin
    LElapsedMs := FOverallStopwatch.ElapsedMilliseconds;
    LEstimatedTotal := Round(LElapsedMs / (LProgressInfo.OverallPercent / 100.0));
    LEstimatedRemaining := LEstimatedTotal - LElapsedMs;
    LProgressInfo.EstimatedRemaining := FormatEstimatedTime(LEstimatedRemaining);
  end
  else
    LProgressInfo.EstimatedRemaining := '--';
    
  LProgressInfo.CurrentFile := '';
  LProgressInfo.DetailMessage := ADetailMessage;
  LProgressInfo.ItemsProcessed := '';
  LProgressInfo.TotalItems := '';
  LProgressInfo.IsComplete := (LProgressInfo.OverallPercent >= 100);
  
  // Call the progress callback
  FProgressCallback(LProgressInfo);
end;

procedure TCPCompiler.CheckProgressUpdate(const AItemsProcessed, ATotalItems: Integer; const ADetailMessage: string);
var
  LCurrentTicks: Int64;
  LPhaseProgress: Double;
begin
  if not Assigned(FProgressCallback) then
    Exit;
    
  // Only check timing periodically to avoid overhead
  if (AItemsProcessed mod FProgressUpdateInterval) <> 0 then
    Exit;
    
  LCurrentTicks := TStopwatch.GetTimeStamp;
  
  // Avoid too frequent updates (minimum 50ms between updates)
  if (LCurrentTicks - FLastProgressReport) < (TStopwatch.Frequency div 20) then
    Exit;
    
  if ATotalItems > 0 then
    LPhaseProgress := AItemsProcessed / ATotalItems
  else
    LPhaseProgress := 0.0;
    
  ReportProgress(LPhaseProgress, ADetailMessage);
  FLastProgressReport := LCurrentTicks;
end;

{ Compilation methods }

{ TELCompiler }

constructor TCPCompiler.Create();
begin
  inherited;
  FIncludeManager := TCPIncludeManager.Create();
  FLexer := TCPLexer.Create();
  FParser := TCPParser.Create();
  FTypeManager := TCPTypeManager.Create();
  FErrorCollector := TCPErrorCollector.Create();
  FSemanticAnalyzer := TCPSemanticAnalyzer.Create(FTypeManager, FErrorCollector, FIncludeManager.SourceMapper, '');

  FCurrentResult := nil;
  FMainFileName := '';
  SetLength(FTokens, 0);

  // Initialize progress reporting
  FProgressCallback := nil;
  FProgressUpdateInterval := 100; // Default: report every 100 items
  FLastProgressReport := 0;
  FCurrentPhaseWeight := 0.0;
  FPhaseStartProgress := 0.0;

  // Add default include paths
  FIncludeManager.AddIncludePath('.\include');
end;

destructor TCPCompiler.Destroy();
begin
  FSemanticAnalyzer.Free();
  FErrorCollector.Free();
  FTypeManager.Free();
  FParser.Free();
  FLexer.Free();
  FIncludeManager.Free();
  inherited;
end;

function TCPCompiler.CompileFile(const AFileName: string): TCPCompilationResult;
var
  LUnusedWarnings: TArray<TCPCompilerError>;
  LWarning: TCPCompilerError;
begin
  Result := TCPCompilationResult.Create();
  FCurrentResult := Result;
  FMainFileName := AFileName; // Store filename for module name
  
  // Start overall timing
  FOverallStopwatch := TStopwatch.StartNew();
  
  try
    // Phase 1: Include Processing
    Result.Phase := cpIncludeProcessing;
    StartPhase(cpIncludeProcessing);
    if not ProcessIncludes(AFileName) then
      Exit;
      
    // Phase 2: Lexical Analysis
    Result.Phase := cpLexicalAnalysis;
    StartPhase(cpLexicalAnalysis);
    if not PerformLexicalAnalysis() then
      Exit;
      
    // Phase 3: Syntax Analysis
    Result.Phase := cpSyntaxAnalysis;
    StartPhase(cpSyntaxAnalysis);
    if not PerformSyntaxAnalysis() then
      Exit;
      
    // Phase 4: Semantic Analysis
    Result.Phase := cpSemanticAnalysis;
    StartPhase(cpSemanticAnalysis);
    if not PerformSemanticAnalysis() then
      Exit;
      
    // Add unused symbol warnings
    LUnusedWarnings := FSemanticAnalyzer.GetUnusedSymbolWarnings();
    for LWarning in LUnusedWarnings do
      FErrorCollector.AddError(LWarning);
      
    // Phase 5: Code Generation  
    Result.Phase := cpCodeGeneration;
    StartPhase(cpCodeGeneration);
    if not PerformCodeGeneration() then
      Exit;
      
    // Compilation successful
    Result.Phase := cpComplete;
    Result.Success := True;
    
    // Report completion
    StartPhase(cpComplete);
    ReportProgress(1.0, 'Compilation completed successfully');
    
  except
    on E: Exception do
    begin
      // Convert unhandled exceptions to compiler errors
      FErrorCollector.AddError(
        TCPCompilerError.Create(
          'Internal compiler error: ' + E.Message,
          'Internal',
          AFileName,
          0, 0,
          esFatal
        )
      );
      Result.Success := False;
    end;
  end;
  
  // Update result statistics
  Result.ErrorCount := FErrorCollector.ErrorCount();
  Result.WarningCount := FErrorCollector.WarningCount();
end;

function TCPCompiler.CompileSource(const ASource: string; const AFileName: string): TCPCompilationResult;
var
  LUnusedWarnings: TArray<TCPCompilerError>;
  LWarning: TCPCompilerError;
begin
  // For source compilation, we skip include processing
  Result := TCPCompilationResult.Create();
  FCurrentResult := Result;
  FMainFileName := AFileName; // Store filename for module name
  
  // Start overall timing
  FOverallStopwatch := TStopwatch.StartNew();
  
  try
    // Set the source directly
    Result.MergedSource := ASource;
    
    // Phase 2: Lexical Analysis
    Result.Phase := cpLexicalAnalysis;
    StartPhase(cpLexicalAnalysis);
    FLexer.SetSource(ASource, nil, AFileName); // No source mapper for direct source
    FTokens := FLexer.TokenizeAll();
    Result.TokenCount := Length(FTokens);
    
    if FErrorCollector.HasErrors() then
      Exit;
      
    // Phase 3: Syntax Analysis
    Result.Phase := cpSyntaxAnalysis;
    StartPhase(cpSyntaxAnalysis);
    if not PerformSyntaxAnalysis() then
      Exit;
      
    // Phase 4: Semantic Analysis
    Result.Phase := cpSemanticAnalysis;
    StartPhase(cpSemanticAnalysis);
    if not PerformSemanticAnalysis() then
      Exit;
      
    // Add unused symbol warnings
    LUnusedWarnings := FSemanticAnalyzer.GetUnusedSymbolWarnings();
    for LWarning in LUnusedWarnings do
      FErrorCollector.AddError(LWarning);
      
    // Phase 5: Code Generation  
    Result.Phase := cpCodeGeneration;
    StartPhase(cpCodeGeneration);
    if not PerformCodeGeneration() then
      Exit;
      
    // Compilation successful
    Result.Phase := cpComplete;
    Result.Success := True;
    
    // Report completion
    StartPhase(cpComplete);
    ReportProgress(1.0, 'Compilation completed successfully');
    
  except
    on E: Exception do
    begin
      FErrorCollector.AddError(
        TCPCompilerError.Create(
          'Internal compiler error: ' + E.Message,
          'Internal',
          AFileName,
          0, 0,
          esFatal
        )
      );
      Result.Success := False;
    end;
  end;
  
  Result.ErrorCount := FErrorCollector.ErrorCount();
  Result.WarningCount := FErrorCollector.WarningCount();
end;

function TCPCompiler.ProcessIncludes(const AMainFileName: string): Boolean;
begin
  Result := False;
  
  try
    FCurrentResult.MergedSource := FIncludeManager.ProcessMainFile(AMainFileName);
    Result := True;
  except
    on E: ECPException do
    begin
      FErrorCollector.AddError(
        TCPCompilerError.Create(
          E.Message,
          'Include',
          E.SourceFileName,
          E.LineNumber,
          E.ColumnNumber,
          esError
        )
      );
    end;
    on E: Exception do
    begin
      FErrorCollector.AddError(
        TCPCompilerError.Create(
          'Include processing failed: ' + E.Message,
          'Include',
          AMainFileName,
          0, 0,
          esError
        )
      );
    end;
  end;
end;

function TCPCompiler.PerformLexicalAnalysis(): Boolean;
begin
  Result := False;
  
  try
    FLexer.SetSource(FCurrentResult.MergedSource, FIncludeManager.SourceMapper, FMainFileName);
    FTokens := FLexer.TokenizeAll();
    FCurrentResult.TokenCount := Length(FTokens);
    Result := True;
  except
    on E: Exception do
    begin
      FErrorCollector.AddError(
        TCPCompilerError.Create(
          'Lexical analysis failed: ' + E.Message,
          'Lexical',
          FMainFileName,
          0, 0,
          esError
        )
      );
    end;
  end;
end;

function TCPCompiler.PerformSyntaxAnalysis(): Boolean;
var
  LAST: TCPASTNode;
begin
  Result := False;
  
  try
    LAST := FParser.Parse(FTokens);
    FCurrentResult.AST := LAST;
    Result := True;
  except
    on E: ECPException do
    begin
      // Use source position from the exception
      FErrorCollector.AddParseError(
        E.Message,
        'Parse error',
        [],
        E.SourceFileName,
        E.LineNumber,
        E.ColumnNumber
      );
    end;
    on E: Exception do
    begin
      FErrorCollector.AddError(
        TCPCompilerError.Create(
          'Syntax analysis failed: ' + E.Message,
          'Syntax',
          '<unknown>',
          0, 0,
          esError
        )
      );
    end;
  end;
end;

function TCPCompiler.PerformSemanticAnalysis(): Boolean;
begin
  Result := False;
  
  try
    if not Assigned(FCurrentResult.AST) then
    begin
      FErrorCollector.AddError(
        TCPCompilerError.Create(
          'No AST generated - syntax analysis failed',
          'Semantic',
          FMainFileName,
          0, 0,
          esError
        )
      );
      Exit;
    end;
    
    // Set the main filename for proper error reporting
    FSemanticAnalyzer.SetMainFileName(FMainFileName);
    
    // Perform comprehensive semantic analysis
    Result := FSemanticAnalyzer.Analyze(FCurrentResult.AST);
    
    // Check for main function requirement
    if not FSemanticAnalyzer.HasMainFunction then
    begin
      FErrorCollector.AddSemanticError(
        'Program must have a main function', 
        'main', 
        FMainFileName, 0, 0
      );
      Result := False;
    end;
    
  except
    on E: ECPException do
    begin
      FErrorCollector.AddSemanticError(
        E.Message,
        E.RelatedSymbol,
        E.SourceFileName,
        E.LineNumber,
        E.ColumnNumber
      );
      Result := False;
    end;
    on E: Exception do
    begin
      FErrorCollector.AddError(
        TCPCompilerError.Create(
          'Semantic analysis failed: ' + E.Message,
          'Semantic',
          FMainFileName,
          0, 0,
          esError
        )
      );
      Result := False;
    end;
  end;
end;

function TCPCompiler.PerformCodeGeneration(): Boolean;
var
  LCodeGen: TCPCodeGen;
  LGeneratedIR: string;
  LModuleName: string;
begin
  Result := False;
  
  try
    if not Assigned(FCurrentResult.AST) then
    begin
      FErrorCollector.AddError(
        TCPCompilerError.Create(
          'No AST available for code generation',
          'CodeGen',
          FMainFileName,
          0, 0,
          esError
        )
      );
      Exit;
    end;
    
    // Extract module name from the main file name
    if FMainFileName <> '' then
      LModuleName := ExtractFileName(FMainFileName)
    else
      LModuleName := 'elang_module';
    
    LCodeGen := TCPCodeGen.Create(FErrorCollector, LModuleName);
    try
      LGeneratedIR := LCodeGen.Generate(FCurrentResult.AST);
      FCurrentResult.GeneratedIR := LGeneratedIR; // Store generated IR text
      Result := (LGeneratedIR <> '') and not FErrorCollector.HasErrors();
    finally
      LCodeGen.Free();
    end;
    
  except
    on E: Exception do
    begin
      FErrorCollector.AddError(
        TCPCompilerError.Create(
          'Code generation failed: ' + E.Message,
          'CodeGen',
          FMainFileName,
          0, 0,
          esError
        )
      );
    end;
  end;
end;

function TCPCompiler.CreateCompilationError(const AMessage: string; const AToken: TCPToken): TCPCompilerError;
begin
  Result := TCPCompilerError.Create(
    AMessage,
    'Compilation',
    AToken.SourcePos.FileName,
    AToken.SourcePos.Line,
    AToken.SourcePos.Column,
    esError
  );
end;

function TCPCompiler.GetErrors(): TArray<TCPCompilerError>;
begin
  Result := FErrorCollector.GetErrors();
end;

function TCPCompiler.GetWarnings(): TArray<TCPCompilerError>;
begin
  Result := FErrorCollector.GetWarnings();
end;

function TCPCompiler.GetErrorsByPhase(const APhase: TCPCompilationPhase): TArray<TCPCompilerError>;
var
  LPhaseName: string;
begin
  if APhase = cpIncludeProcessing then
    LPhaseName := 'Include'
  else if APhase = cpLexicalAnalysis then
    LPhaseName := 'Lexical'
  else if APhase = cpSyntaxAnalysis then
    LPhaseName := 'Syntax'
  else if APhase = cpSemanticAnalysis then
    LPhaseName := 'Semantic'
  else if APhase = cpCodeGeneration then
    LPhaseName := 'CodeGen'
  else
    LPhaseName := 'Unknown';
  
  Result := FErrorCollector.GetErrorsByCategory(LPhaseName);
end;

function TCPCompiler.HasErrors(): Boolean;
begin
  Result := FErrorCollector.HasErrors();
end;

function TCPCompiler.HasWarnings(): Boolean;
begin
  Result := FErrorCollector.HasWarnings();
end;

function TCPCompiler.ErrorCount(): Integer;
begin
  Result := FErrorCollector.ErrorCount();
end;

function TCPCompiler.WarningCount(): Integer;
begin
  Result := FErrorCollector.WarningCount();
end;

procedure TCPCompiler.ClearErrors();
begin
  FErrorCollector.Clear();
end;

function TCPCompiler.GetSourcePosition(const ACharIndex: Integer): TCPSourcePosition;
begin
  Result := FIncludeManager.GetSourcePosition(ACharIndex);
end;

function TCPCompiler.GetSourceLine(const ACharIndex: Integer): string;
begin
  Result := FIncludeManager.GetSourceLine(ACharIndex);
end;

end.

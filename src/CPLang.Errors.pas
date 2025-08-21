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

unit CPLang.Errors;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  CPLang.Common;

type
  { TCPErrorSeverity }
  TCPErrorSeverity = (esInfo, esWarning, esError, esFatal);

  { ECPException }
  ECPException = class(Exception)
  private
    FErrorCode: Integer;
    FErrorCategory: string;
    FSourceFileName: string;
    FLineNumber: Integer;
    FColumnNumber: Integer;
    FContextInfo: string;
    FSuggestion: string;
    FRelatedSymbol: string;
    FExpectedType: string;
    FActualType: string;
    
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; const AArgs: array of const); overload;
    constructor Create(const AMessage: string; const AArgs: array of const; 
      const AFileName: string; const ALine, AColumn: Integer); overload;
    constructor Create(const AMessage: string; const AArgs: array of const; 
      const ASymbol, AFileName: string; const ALine, AColumn: Integer); overload;
    constructor Create(const AMessage: string; const AArgs: array of const; 
      const AExpectedType, AActualType, AFileName: string; const ALine, AColumn: Integer); overload;
    constructor Create(const AMessage: string; const AArgs: array of const; 
      const AContext, ASuggestion: string); overload;

    property ErrorCode: Integer read FErrorCode write FErrorCode;
    property ErrorCategory: string read FErrorCategory write FErrorCategory;
    property SourceFileName: string read FSourceFileName write FSourceFileName;
    property LineNumber: Integer read FLineNumber write FLineNumber;
    property ColumnNumber: Integer read FColumnNumber write FColumnNumber;
    property ContextInfo: string read FContextInfo write FContextInfo;
    property Suggestion: string read FSuggestion write FSuggestion;
    property RelatedSymbol: string read FRelatedSymbol write FRelatedSymbol;
    property ExpectedType: string read FExpectedType write FExpectedType;
    property ActualType: string read FActualType write FActualType;

    function GetDetailedMessage(): string;
    function GetFormattedLocation(): string;
    function GetErrorWithSuggestion(): string;
  end;

  { TCPCompilerError }
  TCPCompilerError = class
  private
    FMessage: string;
    FErrorCategory: string;
    FSeverity: TCPErrorSeverity;
    FSourceFileName: string;
    FLine: Integer;
    FColumn: Integer;
    
    // Rich context (optional fields)
    FTokenContext: string;
    FExpectedTokens: TArray<string>;
    FRelatedSymbol: string;
    FExpectedType: string;
    FActualType: string;
    FSuggestion: string;

  public
    constructor Create(const AMessage, ACategory: string; const AFileName: string; 
      const ALine, AColumn: Integer; const ASeverity: TCPErrorSeverity = esError); overload;
      
    // Fluent setters for context
    function WithTokenContext(const AContext: string; const AExpected: TArray<string>): TCPCompilerError;
    function WithSymbol(const ASymbol: string): TCPCompilerError;
    function WithTypes(const AExpected, AActual: string): TCPCompilerError;
    function WithSuggestion(const ASuggestion: string): TCPCompilerError;
    
    function ToString: string; override;
    function GetFormattedLocation: string;
    
    // Properties (read-only)
    property Message: string read FMessage;
    property ErrorCategory: string read FErrorCategory;
    property Severity: TCPErrorSeverity read FSeverity;
    property SourceFileName: string read FSourceFileName;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    property TokenContext: string read FTokenContext;
    property ExpectedTokens: TArray<string> read FExpectedTokens;
    property RelatedSymbol: string read FRelatedSymbol;
    property ExpectedType: string read FExpectedType;
    property ActualType: string read FActualType;
    property Suggestion: string read FSuggestion;
  end;

  { TCPErrorCollector }
  TCPErrorCollector = class
  private
    FErrors: TObjectList<TCPCompilerError>;
    FErrorSignatures: THashSet<string>; // For deduplication

  public
    constructor Create;
    destructor Destroy; override;
    
    procedure AddError(const AError: TCPCompilerError);
    procedure AddParseError(const AMessage: string; const ATokenContext: string; 
      const AExpected: TArray<string>; const AFileName: string; const ALine, AColumn: Integer);
    procedure AddSemanticError(const AMessage: string; const ASymbol: string;
      const AFileName: string; const ALine, AColumn: Integer);
    procedure AddTypeError(const AMessage: string; const AExpected, AActual: string;
      const AFileName: string; const ALine, AColumn: Integer);
    procedure AddWarning(const AMessage, ACategory: string; const AFileName: string; 
      const ALine, AColumn: Integer);
      
    // Internal deduplication helper
    function GenerateErrorSignature(const AMessage, AFileName: string; const ALine, AColumn: Integer): string;
      
    function GetErrors: TArray<TCPCompilerError>;
    function GetWarnings: TArray<TCPCompilerError>;
    function GetErrorsByCategory(const ACategory: string): TArray<TCPCompilerError>;
    
    function HasErrors: Boolean;
    function HasWarnings: Boolean;
    function ErrorCount: Integer;
    function WarningCount: Integer;
    
    procedure Clear;
  end;

implementation

{ ECPException }
constructor ECPException.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := 0;
  FErrorCategory := 'General';
  FSourceFileName := '';
  FLineNumber := 0;
  FColumnNumber := 0;
  FContextInfo := '';
  FSuggestion := '';
  FRelatedSymbol := '';
  FExpectedType := '';
  FActualType := '';
end;

constructor ECPException.Create(const AMessage: string; const AArgs: array of const);
begin
  try
    inherited Create(Format(AMessage, AArgs));
  except
    on E: Exception do
      inherited Create(AMessage + ' [Format Error: ' + E.Message + ']');
  end;

  FErrorCode := 0;
  FErrorCategory := 'General';
  FSourceFileName := '';
  FLineNumber := 0;
  FColumnNumber := 0;
  FContextInfo := '';
  FSuggestion := '';
  FRelatedSymbol := '';
  FExpectedType := '';
  FActualType := '';
end;

constructor ECPException.Create(const AMessage: string; const AArgs: array of const;
                               const AFileName: string; const ALine, AColumn: Integer);
begin
  try
    inherited Create(Format(AMessage, AArgs));
  except
    on E: Exception do
      inherited Create(AMessage + ' [Format Error: ' + E.Message + ']');
  end;

  FErrorCode := 0;
  FErrorCategory := 'Syntax';
  FSourceFileName := AFileName;
  FLineNumber := ALine;
  FColumnNumber := AColumn;
  FContextInfo := '';
  FSuggestion := '';
  FRelatedSymbol := '';
  FExpectedType := '';
  FActualType := '';
end;

constructor ECPException.Create(const AMessage: string; const AArgs: array of const;
                               const ASymbol, AFileName: string; const ALine, AColumn: Integer);
begin
  try
    inherited Create(Format(AMessage, AArgs));
  except
    on E: Exception do
      inherited Create(AMessage + ' [Format Error: ' + E.Message + ']');
  end;

  FErrorCode := 0;
  FErrorCategory := 'Semantic';
  FSourceFileName := AFileName;
  FLineNumber := ALine;
  FColumnNumber := AColumn;
  FContextInfo := '';
  FSuggestion := '';
  FRelatedSymbol := ASymbol;
  FExpectedType := '';
  FActualType := '';
end;

constructor ECPException.Create(const AMessage: string; const AArgs: array of const;
                               const AExpectedType, AActualType, AFileName: string;
                               const ALine, AColumn: Integer);
begin
  try
    inherited Create(Format(AMessage, AArgs));
  except
    on E: Exception do
      inherited Create(AMessage + ' [Format Error: ' + E.Message + ']');
  end;

  FErrorCode := 0;
  FErrorCategory := 'Type';
  FSourceFileName := AFileName;
  FLineNumber := ALine;
  FColumnNumber := AColumn;
  FContextInfo := '';
  FSuggestion := '';
  FRelatedSymbol := '';
  FExpectedType := AExpectedType;
  FActualType := AActualType;
end;

constructor ECPException.Create(const AMessage: string; const AArgs: array of const;
                               const AContext, ASuggestion: string);
begin
  try
    inherited Create(Format(AMessage, AArgs));
  except
    on E: Exception do
      inherited Create(AMessage + ' [Format Error: ' + E.Message + ']');
  end;

  FErrorCode := 0;
  FErrorCategory := 'Validation';
  FSourceFileName := '';
  FLineNumber := 0;
  FColumnNumber := 0;
  FContextInfo := AContext;
  FSuggestion := ASuggestion;
  FRelatedSymbol := '';
  FExpectedType := '';
  FActualType := '';
end;

function ECPException.GetDetailedMessage(): string;
begin
  Result := Message;

  if FSourceFileName <> '' then
  begin
    Result := Result + sLineBreak + 'File: ' + FSourceFileName;
    if FLineNumber > 0 then
    begin
      Result := Result + sLineBreak + 'Line: ' + IntToStr(FLineNumber);
      if FColumnNumber > 0 then
        Result := Result + ', Column: ' + IntToStr(FColumnNumber);
    end;
  end;

  if FErrorCategory <> '' then
    Result := Result + sLineBreak + 'Category: ' + FErrorCategory;

  if FRelatedSymbol <> '' then
    Result := Result + sLineBreak + 'Symbol: ' + FRelatedSymbol;

  if (FExpectedType <> '') and (FActualType <> '') then
    Result := Result + sLineBreak + 'Expected: ' + FExpectedType + ', Got: ' + FActualType;

  if FContextInfo <> '' then
    Result := Result + sLineBreak + 'Context: ' + FContextInfo;

  if FSuggestion <> '' then
    Result := Result + sLineBreak + 'Suggestion: ' + FSuggestion;
end;

function ECPException.GetFormattedLocation(): string;
begin
  Result := '';

  if FSourceFileName <> '' then
  begin
    Result := FSourceFileName;
    if FLineNumber > 0 then
    begin
      Result := Result + '(' + IntToStr(FLineNumber);
      if FColumnNumber > 0 then
        Result := Result + ',' + IntToStr(FColumnNumber);
      Result := Result + ')';
    end;
  end;
end;

function ECPException.GetErrorWithSuggestion(): string;
begin
  Result := Message;

  if FSuggestion <> '' then
    Result := Result + sLineBreak + sLineBreak + 'Suggestion: ' + FSuggestion;
end;

{ TELCompilerError }

constructor TCPCompilerError.Create(const AMessage, ACategory: string; const AFileName: string;
  const ALine, AColumn: Integer; const ASeverity: TCPErrorSeverity);
begin
  inherited Create;
  FMessage := AMessage;
  FErrorCategory := ACategory;
  FSeverity := ASeverity;
  FSourceFileName := AFileName;
  FLine := ALine;
  FColumn := AColumn;
  FTokenContext := '';
  SetLength(FExpectedTokens, 0);
  FRelatedSymbol := '';
  FExpectedType := '';
  FActualType := '';
  FSuggestion := '';
end;

function TCPCompilerError.WithTokenContext(const AContext: string; const AExpected: TArray<string>): TCPCompilerError;
begin
  FTokenContext := AContext;
  FExpectedTokens := AExpected;
  Result := Self;
end;

function TCPCompilerError.WithSymbol(const ASymbol: string): TCPCompilerError;
begin
  FRelatedSymbol := ASymbol;
  Result := Self;
end;

function TCPCompilerError.WithTypes(const AExpected, AActual: string): TCPCompilerError;
begin
  FExpectedType := AExpected;
  FActualType := AActual;
  Result := Self;
end;

function TCPCompilerError.WithSuggestion(const ASuggestion: string): TCPCompilerError;
begin
  FSuggestion := ASuggestion;
  Result := Self;
end;

function TCPCompilerError.ToString: string;
var
  LFirst: Boolean;
  LToken: string;
begin
  Result := FMessage;

  if FSourceFileName <> '' then
  begin
    Result := Result + sLineBreak + 'File: ' + FSourceFileName;
    if FLine > 0 then
    begin
      Result := Result + sLineBreak + 'Line: ' + IntToStr(FLine);
      if FColumn > 0 then
        Result := Result + ', Column: ' + IntToStr(FColumn);
    end;
  end;

  if FErrorCategory <> '' then
    Result := Result + sLineBreak + 'Category: ' + FErrorCategory;

  if FTokenContext <> '' then
    Result := Result + sLineBreak + 'Context: ' + FTokenContext;

  if Length(FExpectedTokens) > 0 then
  begin
    Result := Result + sLineBreak + 'Expected: ';
    LFirst := True;
    for LToken in FExpectedTokens do
    begin
      if not LFirst then
        Result := Result + ', ';
      Result := Result + LToken;
      LFirst := False;
    end;
  end;
    
  if FRelatedSymbol <> '' then
    Result := Result + sLineBreak + 'Symbol: ' + FRelatedSymbol;
    
  if (FExpectedType <> '') and (FActualType <> '') then
    Result := Result + sLineBreak + 'Expected: ' + FExpectedType + ', Got: ' + FActualType;
    
  if FSuggestion <> '' then
    Result := Result + sLineBreak + 'Suggestion: ' + FSuggestion;
end;

function TCPCompilerError.GetFormattedLocation: string;
begin
  Result := '';
  
  if FSourceFileName <> '' then
  begin
    Result := FSourceFileName;
    if FLine > 0 then
    begin
      Result := Result + '(' + IntToStr(FLine);
      if FColumn > 0 then
        Result := Result + ',' + IntToStr(FColumn);
      Result := Result + ')';
    end;
  end;
end;

{ TELErrorCollector }

constructor TCPErrorCollector.Create;
begin
  inherited;

  FErrors := TObjectList<TCPCompilerError>.Create(True);
  FErrorSignatures := THashSet<string>.Create();
end;

destructor TCPErrorCollector.Destroy;
begin
  FErrors.Free;
  FErrorSignatures.Free;

  inherited;
end;

procedure TCPErrorCollector.AddError(const AError: TCPCompilerError);
var
  LSignature: string;
begin
  if not Assigned(AError) then
    Exit;
    
  // Generate error signature for deduplication
  LSignature := GenerateErrorSignature(AError.Message, AError.SourceFileName, AError.Line, AError.Column);
  
  // Only add if this exact error hasn't been seen before
  if not FErrorSignatures.Contains(LSignature) then
  begin
    FErrorSignatures.Add(LSignature);
    FErrors.Add(AError);
  end
  else
  begin
    // Free the duplicate error since we're not adding it
    AError.Free;
  end;
end;

procedure TCPErrorCollector.AddParseError(const AMessage: string; const ATokenContext: string;
  const AExpected: TArray<string>; const AFileName: string; const ALine, AColumn: Integer);
var
  LError: TCPCompilerError;
begin
  LError := TCPCompilerError.Create(AMessage, 'Syntax', AFileName, ALine, AColumn, esError);
  LError.WithTokenContext(ATokenContext, AExpected);
  AddError(LError);
end;

procedure TCPErrorCollector.AddSemanticError(const AMessage: string; const ASymbol: string;
  const AFileName: string; const ALine, AColumn: Integer);
var
  LError: TCPCompilerError;
begin
  LError := TCPCompilerError.Create(AMessage, 'Semantic', AFileName, ALine, AColumn, esError);
  LError.WithSymbol(ASymbol);
  AddError(LError);
end;

procedure TCPErrorCollector.AddTypeError(const AMessage: string; const AExpected, AActual: string;
  const AFileName: string; const ALine, AColumn: Integer);
var
  LError: TCPCompilerError;
begin
  LError := TCPCompilerError.Create(AMessage, 'Type', AFileName, ALine, AColumn, esError);
  LError.WithTypes(AExpected, AActual);
  AddError(LError);
end;

procedure TCPErrorCollector.AddWarning(const AMessage, ACategory: string; const AFileName: string;
  const ALine, AColumn: Integer);
var
  LWarning: TCPCompilerError;
begin
  LWarning := TCPCompilerError.Create(AMessage, ACategory, AFileName, ALine, AColumn, esWarning);
  AddError(LWarning);
end;

function TCPErrorCollector.GetErrors: TArray<TCPCompilerError>;
var
  LIndex: Integer;
  LCount: Integer;
  LError: TCPCompilerError;
begin
  LCount := 0;
  for LError in FErrors do
  begin
    if LError.Severity = esError then
      Inc(LCount);
  end;
  
  SetLength(Result, LCount);
  LIndex := 0;
  for LError in FErrors do
  begin
    if LError.Severity = esError then
    begin
      Result[LIndex] := LError;
      Inc(LIndex);
    end;
  end;
end;

function TCPErrorCollector.GetWarnings: TArray<TCPCompilerError>;
var
  LIndex: Integer;
  LCount: Integer;
  LError: TCPCompilerError;
begin
  LCount := 0;
  for LError in FErrors do
  begin
    if LError.Severity = esWarning then
      Inc(LCount);
  end;
  
  SetLength(Result, LCount);
  LIndex := 0;
  for LError in FErrors do
  begin
    if LError.Severity = esWarning then
    begin
      Result[LIndex] := LError;
      Inc(LIndex);
    end;
  end;
end;

function TCPErrorCollector.GetErrorsByCategory(const ACategory: string): TArray<TCPCompilerError>;
var
  LIndex: Integer;
  LCount: Integer;
  LError: TCPCompilerError;
begin
  LCount := 0;
  for LError in FErrors do
  begin
    if LError.ErrorCategory = ACategory then
      Inc(LCount);
  end;
  
  SetLength(Result, LCount);
  LIndex := 0;
  for LError in FErrors do
  begin
    if LError.ErrorCategory = ACategory then
    begin
      Result[LIndex] := LError;
      Inc(LIndex);
    end;
  end;
end;

function TCPErrorCollector.HasErrors: Boolean;
var
  LError: TCPCompilerError;
begin
  for LError in FErrors do
  begin
    if LError.Severity = esError then
      Exit(True);
  end;
  Result := False;
end;

function TCPErrorCollector.HasWarnings: Boolean;
var
  LError: TCPCompilerError;
begin
  for LError in FErrors do
  begin
    if LError.Severity = esWarning then
      Exit(True);
  end;
  Result := False;
end;

function TCPErrorCollector.ErrorCount: Integer;
var
  LError: TCPCompilerError;
begin
  Result := 0;
  for LError in FErrors do
  begin
    if LError.Severity = esError then
      Inc(Result);
  end;
end;

function TCPErrorCollector.WarningCount: Integer;
var
  LError: TCPCompilerError;
begin
  Result := 0;
  for LError in FErrors do
  begin
    if LError.Severity = esWarning then
      Inc(Result);
  end;
end;

procedure TCPErrorCollector.Clear;
begin
  FErrors.Clear;
  FErrorSignatures.Clear;
end;

function TCPErrorCollector.GenerateErrorSignature(const AMessage, AFileName: string; const ALine, AColumn: Integer): string;
begin
  // Create unique signature: message|filename|line|column
  Result := Format('%s|%s|%d|%d', [AMessage, AFileName, ALine, AColumn]);
end;

end.

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

unit CPLang.Semantic;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  CPLang.Common,
  CPLang.Parser,
  CPLang.Types,
  CPLang.Symbols,
  CPLang.TypeChecker,
  CPLang.Errors,
  CPLang.SourceMap;

type
  { TCPParameterInfo }
  TCPParameterInfo = record
    ParameterName: string;
    ParameterType: TCPType;
    Modifier: string; // 'ref', 'const', or empty
    DeclaredNode: TCPASTNode;
  end;

  { TCPSemanticAnalyzer }
  TCPSemanticAnalyzer = class
  private
    FSymbolTable: TCPSymbolTable;
    FTypeManager: TCPTypeManager;
    FTypeChecker: TCPTypeChecker;
    FErrorCollector: TCPErrorCollector;
    FSourceMapper: TCPSourceMapper;
    FMainFileName: string;
    FHasMainFunction: Boolean;
    FCurrentFunction: TCPSymbol;
    FInLoop: Boolean;
    
    procedure AnalyzeNode(const ANode: TCPASTNode);
    procedure AnalyzeProgram(const ANode: TCPASTNode);
    procedure AnalyzeVariableDecl(const ANode: TCPASTNode);
    procedure AnalyzeFunctionDecl(const ANode: TCPASTNode);
    procedure AnalyzeMainFunction(const ANode: TCPASTNode);
    procedure AnalyzeTypeDecl(const ANode: TCPASTNode);
    procedure AnalyzeStatementBlock(const ANode: TCPASTNode);
    {$HINTS OFF}
    procedure AnalyzeStatement(const ANode: TCPASTNode);
    {$HINTS ON}
    procedure AnalyzeAssignment(const ANode: TCPASTNode);
    procedure AnalyzeIfStatement(const ANode: TCPASTNode);
    procedure AnalyzeWhileStatement(const ANode: TCPASTNode);
    procedure AnalyzeForStatement(const ANode: TCPASTNode);
    procedure AnalyzeRepeatStatement(const ANode: TCPASTNode);
    procedure AnalyzeCaseStatement(const ANode: TCPASTNode);
    procedure AnalyzeReturnStatement(const ANode: TCPASTNode);
    procedure AnalyzeCallStatement(const ANode: TCPASTNode);
    procedure AnalyzeBreakStatement(const ANode: TCPASTNode);
    procedure AnalyzeContinueStatement(const ANode: TCPASTNode);
    procedure AnalyzeGotoStatement(const ANode: TCPASTNode);
    procedure AnalyzeExpression(const ANode: TCPASTNode);
    procedure AnalyzeFunctionCall(const ANode: TCPASTNode);
    
    function ProcessFunctionHeader(const ANode: TCPASTNode): TCPSymbol;
    function ProcessParameterList(const ANode: TCPASTNode): TArray<TCPType>;
    function ExtractParameterInfo(const ANode: TCPASTNode): TArray<TCPParameterInfo>;
    function HasVariadicParameters(const ANode: TCPASTNode): Boolean;
    function ResolveTypeFromNode(const ANode: TCPASTNode): TCPType;
    function GetNodePosition(const ANode: TCPASTNode): TCPSourcePosition;
    function GetLineColumnFromPosition(const ACharIndex: Integer): TCPLineColumn;
    function ValidateMainFunction(const ANode: TCPASTNode): Boolean;
    
  public
    constructor Create(const ATypeManager: TCPTypeManager;
      const AErrorCollector: TCPErrorCollector; const ASourceMapper: TCPSourceMapper = nil; const AMainFileName: string = '<source>');
    destructor Destroy(); override;
    
    function Analyze(const AAST: TCPASTNode): Boolean;
    procedure SetMainFileName(const AFileName: string);
    function GetUnusedSymbolWarnings(): TArray<TCPCompilerError>;
    
    property SymbolTable: TCPSymbolTable read FSymbolTable;
    property HasMainFunction: Boolean read FHasMainFunction;
  end;

implementation

{ TCPSemanticAnalyzer }
constructor TCPSemanticAnalyzer.Create(const ATypeManager: TCPTypeManager;
  const AErrorCollector: TCPErrorCollector; const ASourceMapper: TCPSourceMapper; const AMainFileName: string);
begin
  inherited Create();
  FTypeManager := ATypeManager;
  FErrorCollector := AErrorCollector;
  FSourceMapper := ASourceMapper;
  FMainFileName := AMainFileName;
  FSymbolTable := TCPSymbolTable.Create();
  FTypeChecker := TCPTypeChecker.Create(FTypeManager, FSymbolTable, FErrorCollector, FMainFileName, FSourceMapper);
  FHasMainFunction := False;
  FCurrentFunction := nil;
  FInLoop := False;
end;

destructor TCPSemanticAnalyzer.Destroy();
begin
  FTypeChecker.Free();
  FSymbolTable.Free();
  inherited;
end;

procedure TCPSemanticAnalyzer.SetMainFileName(const AFileName: string);
begin
  FMainFileName := AFileName;
  if Assigned(FTypeChecker) then
    FTypeChecker.SetMainFileName(AFileName);
end;

function TCPSemanticAnalyzer.GetNodePosition(const ANode: TCPASTNode): TCPSourcePosition;
var
  LLineColumn: TCPLineColumn;
begin
  if Assigned(ANode) and (ANode.Position > 0) and Assigned(FSourceMapper) then
  begin
    // Map character position through source mapper for includes
    Result := FSourceMapper.MapPosition(ANode.Position);
  end
  else if Assigned(ANode) and (ANode.Position > 0) then
  begin
    // Fallback: calculate position from character index without source mapping
    LLineColumn := GetLineColumnFromPosition(ANode.Position);
    Result := TCPSourcePosition.Create(FMainFileName, LLineColumn.Line, LLineColumn.Column, ANode.Position);
  end
  else
  begin
    // Last resort: use main filename with no position
    Result := TCPSourcePosition.Create(FMainFileName, 0, 0, 0);
  end;
end;

function TCPSemanticAnalyzer.GetLineColumnFromPosition(const ACharIndex: Integer): TCPLineColumn;
begin
  // Fallback position calculation when source mapper not available
  if Assigned(FSourceMapper) then
    Result := FSourceMapper.GetMergedLineColumn(ACharIndex)
  else
  begin
    Result.Line := 1;
    Result.Column := ACharIndex;
  end;
end;

function TCPSemanticAnalyzer.Analyze(const AAST: TCPASTNode): Boolean;
var
  LPos: TCPSourcePosition;
begin
  Result := False;
  FHasMainFunction := False;
  
  try
    if not Assigned(AAST) then
    begin
      FErrorCollector.AddSemanticError('No AST provided for semantic analysis', '', FMainFileName, 0, 0);
      Exit;
    end;
    
    AnalyzeNode(AAST);
    
    // Check for mandatory main function
    if not FHasMainFunction then
    begin
      LPos := GetNodePosition(AAST);
      FErrorCollector.AddSemanticError('Program must have a main function', '', LPos.FileName, LPos.Line, LPos.Column);
    end;
    
    Result := not FErrorCollector.HasErrors();
    
  except
    on E: Exception do
    begin
      LPos := GetNodePosition(AAST);
      FErrorCollector.AddSemanticError('Internal semantic analysis error: ' + E.Message, '', LPos.FileName, LPos.Line, LPos.Column);
    end;
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeNode(const ANode: TCPASTNode);
var
  LIndex: Integer;
begin
  if not Assigned(ANode) then
    Exit;
    
  case ANode.NodeType of
    astProgram: AnalyzeProgram(ANode);
    astVariableDecl: AnalyzeVariableDecl(ANode);
    astFunctionDecl: AnalyzeFunctionDecl(ANode);
    astMainFunction: AnalyzeMainFunction(ANode);
    astTypeDecl: AnalyzeTypeDecl(ANode);
    astStatementBlock: AnalyzeStatementBlock(ANode);
    astAssignment: AnalyzeAssignment(ANode);
    astIfStatement: AnalyzeIfStatement(ANode);
    astWhileStatement: AnalyzeWhileStatement(ANode);
    astForStatement: AnalyzeForStatement(ANode);
    astRepeatStatement: AnalyzeRepeatStatement(ANode);
    astCaseStatement: AnalyzeCaseStatement(ANode);
    astReturnStatement: AnalyzeReturnStatement(ANode);
    astCallStatement: AnalyzeCallStatement(ANode);
    astBreakStatement: AnalyzeBreakStatement(ANode);
    astContinueStatement: AnalyzeContinueStatement(ANode);
    astGotoStatement: AnalyzeGotoStatement(ANode);
    astFunctionCall: AnalyzeFunctionCall(ANode);
    astExpression, astBinaryOp, astUnaryOp, astIdentifier, astLiteral,
    astArrayAccess, astMemberAccess: AnalyzeExpression(ANode);
  else
    // For other node types, recursively analyze children
    for LIndex := 0 to ANode.ChildCount() - 1 do
      AnalyzeNode(ANode.GetChild(LIndex));
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeProgram(const ANode: TCPASTNode);
var
  LIndex: Integer;
begin
  // Analyze all top-level declarations
  for LIndex := 0 to ANode.ChildCount() - 1 do
    AnalyzeNode(ANode.GetChild(LIndex));
end;

procedure TCPSemanticAnalyzer.AnalyzeVariableDecl(const ANode: TCPASTNode);
var
  LTypeNode: TCPASTNode;
  LVariableType: TCPType;
  LIdentifierNode: TCPASTNode;
  LVariableName: string;
  LSymbol: TCPSymbol;
  LIndex: Integer;
  LInitExpression: TCPASTNode;
  LInitType: TCPType;
  LPos: TCPSourcePosition;
  LIdentifierCount: Integer;
  LHasInitialization: Boolean;
begin
  if ANode.ChildCount() < 2 then
    Exit;
  
  // Count identifiers (all astIdentifier children)
  LIdentifierCount := 0;
  for LIndex := 0 to ANode.ChildCount() - 1 do
  begin
    if ANode.GetChild(LIndex).NodeType = astIdentifier then
      Inc(LIdentifierCount);
  end;
  
  // Type is always at index LIdentifierCount
  // Initialization (if present) is at index LIdentifierCount + 1
  LHasInitialization := ANode.ChildCount() > LIdentifierCount + 1;
  
  if LIdentifierCount >= ANode.ChildCount() then
    Exit; // No type node found
    
  LTypeNode := ANode.GetChild(LIdentifierCount);
  LVariableType := ResolveTypeFromNode(LTypeNode);
  
  if not Assigned(LVariableType) then
  begin
    LPos := GetNodePosition(LTypeNode);
    FErrorCollector.AddSemanticError('Cannot resolve variable type', '', LPos.FileName, LPos.Line, LPos.Column);
    Exit;
  end;
  
  // Process each identifier
  for LIndex := 0 to LIdentifierCount - 1 do
  begin
    LIdentifierNode := ANode.GetChild(LIndex);
    if LIdentifierNode.NodeType = astIdentifier then
    begin
      LVariableName := LIdentifierNode.Value;
      
      // Check for redeclaration in current scope
      if FSymbolTable.CheckForRedeclaration(LVariableName, LIdentifierNode) then
      begin
        LPos := GetNodePosition(LIdentifierNode);
        FErrorCollector.AddSemanticError(
          Format('Variable "%s" is already declared in current scope', [LVariableName]),
          LVariableName, LPos.FileName, LPos.Line, LPos.Column
        );
        Continue;
      end;
      
      // Declare the symbol
      try
        LSymbol := FSymbolTable.DeclareSymbol(LVariableName, skVariable, LVariableType, LIdentifierNode);
        
        // Check for initialization
        if LHasInitialization then
        begin
          LInitExpression := ANode.GetChild(LIdentifierCount + 1);
          if Assigned(LInitExpression) then
          begin
            LInitType := FTypeChecker.InferExpressionType(LInitExpression);
            if Assigned(LInitType) then
            begin
              if FTypeChecker.CheckAssignmentCompatibility(LVariableType, LInitType, LInitExpression) then
                LSymbol.IsInitialized := True;
            end;
          end;
        end;
        
      except
      on E: ECPException do
      begin
      LPos := GetNodePosition(LIdentifierNode);
        FErrorCollector.AddSemanticError(E.Message, LVariableName, LPos.FileName, LPos.Line, LPos.Column);
        end;
        end;
    end;
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeFunctionDecl(const ANode: TCPASTNode);
var
  LFunctionSymbol: TCPSymbol;
  LOldFunction: TCPSymbol;
  LIsExternal: Boolean;
  LParameterInfo: TArray<TCPParameterInfo>;
  LParam: TCPParameterInfo;
  LParamSymbol: TCPSymbol;
  LPos: TCPSourcePosition;
begin
  if ANode.ChildCount() < 2 then
    Exit;
    
  // Process function header (declaration)
  LFunctionSymbol := ProcessFunctionHeader(ANode.GetChild(0));
  if not Assigned(LFunctionSymbol) then
    Exit;
  
  // Check if this is an external function
  LIsExternal := (ANode.ChildCount() >= 2) and 
                 (ANode.GetChild(1).NodeType = astLiteral);
    
  // Enter function scope
  FSymbolTable.EnterScope('function');
  LOldFunction := FCurrentFunction;
  FCurrentFunction := LFunctionSymbol;
  
  try
    // Add parameters to function scope
    if LFunctionSymbol.SymbolType is TCPFunctionType then
    begin
      // Extract parameter information from the function header and add to scope
      LParameterInfo := ExtractParameterInfo(ANode.GetChild(0));
      for LParam in LParameterInfo do
      begin
        try
          LParamSymbol := FSymbolTable.DeclareSymbol(
            LParam.ParameterName, 
            skParameter, 
            LParam.ParameterType, 
            LParam.DeclaredNode
          );
          LParamSymbol.IsInitialized := True; // Parameters are always initialized
        except
          on E: ECPException do
          begin
            LPos := GetNodePosition(LParam.DeclaredNode);
            FErrorCollector.AddSemanticError(
              Format('Parameter declaration error: %s', [E.Message]),
              LParam.ParameterName, LPos.FileName, LPos.Line, LPos.Column
            );
          end;
        end;
      end;
    end;
    
    // Analyze function body only for non-external functions
    if not LIsExternal and (ANode.ChildCount() >= 2) then
      AnalyzeNode(ANode.GetChild(1));
      
  finally
    FCurrentFunction := LOldFunction;
    FSymbolTable.ExitScope();
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeMainFunction(const ANode: TCPASTNode);
var
  LMainSymbol: TCPSymbol;
  LOldFunction: TCPSymbol;
begin
  FHasMainFunction := True;
  
  if not ValidateMainFunction(ANode) then
    Exit;
  
  // Process main function header (same as regular functions)
  LMainSymbol := ProcessFunctionHeader(ANode.GetChild(0));
  if not Assigned(LMainSymbol) then
    Exit;
    
  // Enter function scope for main
  FSymbolTable.EnterScope('main_function');
  LOldFunction := FCurrentFunction;
  FCurrentFunction := LMainSymbol;
  
  try
    // Analyze main function body (second child is the statement block)
    if ANode.ChildCount() >= 2 then
      AnalyzeNode(ANode.GetChild(1));
  finally
    FCurrentFunction := LOldFunction;
    FSymbolTable.ExitScope();
  end;
end;

function TCPSemanticAnalyzer.ValidateMainFunction(const ANode: TCPASTNode): Boolean;
var
  LPos: TCPSourcePosition;
begin
  Result := True;
  
  if ANode.ChildCount() < 2 then
  begin
    LPos := GetNodePosition(ANode);
    FErrorCollector.AddSemanticError('Main function is malformed', 'main', LPos.FileName, LPos.Line, LPos.Column);
    Exit(False);
  end;
  
  // Main function should have 2 children: header and statement block
  // The signature is validated in ProcessFunctionHeader
end;

procedure TCPSemanticAnalyzer.AnalyzeTypeDecl(const ANode: TCPASTNode);
var
  LTypeName: string;
  LTypeSpec: TCPType;
  //LSymbol: TCPSymbol;
  LPos: TCPSourcePosition;
begin
  if ANode.ChildCount() < 2 then
    Exit;

  if ANode.GetChild(0).NodeType = astIdentifier then
  begin
    LTypeName := ANode.GetChild(0).Value;
    LTypeSpec := ResolveTypeFromNode(ANode.GetChild(1));

    if Assigned(LTypeSpec) then
    begin
      try
        //LSymbol := FSymbolTable.DeclareSymbol(LTypeName, skType, LTypeSpec, ANode.GetChild(0));
        FSymbolTable.DeclareSymbol(LTypeName, skType, LTypeSpec, ANode.GetChild(0));
        FTypeManager.RegisterType(LTypeName, LTypeSpec);
      except
        on E: ECPException do
        begin
          LPos := GetNodePosition(ANode.GetChild(0));
          FErrorCollector.AddSemanticError(E.Message, LTypeName, LPos.FileName, LPos.Line, LPos.Column);
        end;
      end;
    end;
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeStatementBlock(const ANode: TCPASTNode);
var
  LIndex: Integer;
begin
  FSymbolTable.EnterScope('block');
  try
    for LIndex := 0 to ANode.ChildCount() - 1 do
      AnalyzeNode(ANode.GetChild(LIndex));
  finally
    FSymbolTable.ExitScope();
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeStatement(const ANode: TCPASTNode);
begin
  AnalyzeNode(ANode);
end;

procedure TCPSemanticAnalyzer.AnalyzeAssignment(const ANode: TCPASTNode);
var
  LLValueType: TCPType;
  LRValueType: TCPType;
begin
  if ANode.ChildCount() < 2 then
    Exit;
    
  LLValueType := FTypeChecker.InferExpressionType(ANode.GetChild(0));
  LRValueType := FTypeChecker.InferExpressionType(ANode.GetChild(1));
  
  if Assigned(LLValueType) and Assigned(LRValueType) then
  begin
    FTypeChecker.CheckAssignmentCompatibility(LLValueType, LRValueType, ANode);
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeIfStatement(const ANode: TCPASTNode);
var
  LConditionType: TCPType;
  LPos: TCPSourcePosition;
begin
  if ANode.ChildCount() < 2 then
    Exit;
    
  // Analyze condition
  LConditionType := FTypeChecker.InferExpressionType(ANode.GetChild(0));
  if Assigned(LConditionType) then
  begin
    if not (LConditionType is TCPBasicTypeInfo) or
       (TCPBasicTypeInfo(LConditionType).BasicType <> btBool) then
    begin
      LPos := GetNodePosition(ANode.GetChild(0));
      FErrorCollector.AddTypeError(
        'If condition must be boolean',
        'bool',
        LConditionType.GetTypeName(),
        LPos.FileName, LPos.Line, LPos.Column
      );
    end;
  end;
  
  // Analyze then statement
  AnalyzeNode(ANode.GetChild(1));
  
  // Analyze else statement if present
  if ANode.ChildCount() >= 3 then
    AnalyzeNode(ANode.GetChild(2));
end;

procedure TCPSemanticAnalyzer.AnalyzeWhileStatement(const ANode: TCPASTNode);
var
  LConditionType: TCPType;
  LOldInLoop: Boolean;
  LPos: TCPSourcePosition;
begin
  if ANode.ChildCount() < 2 then
    Exit;
    
  // Analyze condition
  LConditionType := FTypeChecker.InferExpressionType(ANode.GetChild(0));
  if Assigned(LConditionType) then
  begin
    if not (LConditionType is TCPBasicTypeInfo) or
       (TCPBasicTypeInfo(LConditionType).BasicType <> btBool) then
    begin
      LPos := GetNodePosition(ANode.GetChild(0));
      FErrorCollector.AddTypeError(
        'While condition must be boolean',
        'bool',
        LConditionType.GetTypeName(),
        LPos.FileName, LPos.Line, LPos.Column
      );
    end;
  end;
  
  // Analyze body
  LOldInLoop := FInLoop;
  FInLoop := True;
  try
    AnalyzeNode(ANode.GetChild(1));
  finally
    FInLoop := LOldInLoop;
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeForStatement(const ANode: TCPASTNode);
var
  LOldInLoop: Boolean;
  LVariableType: TCPType;
  //LStartType: TCPType;
  //LEndType: TCPType;
  LPos: TCPSourcePosition;
begin
  if ANode.ChildCount() < 4 then
    Exit;

  // Analyze loop variable (should be integer)
  LVariableType := FTypeChecker.InferExpressionType(ANode.GetChild(0));
  //LStartType := FTypeChecker.InferExpressionType(ANode.GetChild(1));
  //LEndType := FTypeChecker.InferExpressionType(ANode.GetChild(2));
  
  // Validate types
  if Assigned(LVariableType) and not (LVariableType is TCPBasicTypeInfo) then
  begin
    LPos := GetNodePosition(ANode.GetChild(0));
    FErrorCollector.AddTypeError(
      'For loop variable must be integer type',
      'integer',
      LVariableType.GetTypeName(),
      LPos.FileName, LPos.Line, LPos.Column
    );
  end;
  
  // Analyze body
  LOldInLoop := FInLoop;
  FInLoop := True;
  try
    AnalyzeNode(ANode.GetChild(3));
  finally
    FInLoop := LOldInLoop;
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeRepeatStatement(const ANode: TCPASTNode);
var
  LOldInLoop: Boolean;
  LConditionType: TCPType;
  LIndex: Integer;
  LPos: TCPSourcePosition;
begin
  LOldInLoop := FInLoop;
  FInLoop := True;
  try
    // Analyze all statements except the last (which is the condition)
    for LIndex := 0 to ANode.ChildCount() - 2 do
      AnalyzeNode(ANode.GetChild(LIndex));
      
    // Analyze condition (last child)
    if ANode.ChildCount() > 0 then
    begin
      LConditionType := FTypeChecker.InferExpressionType(ANode.GetChild(ANode.ChildCount() - 1));
      if Assigned(LConditionType) then
      begin
        if not (LConditionType is TCPBasicTypeInfo) or
           (TCPBasicTypeInfo(LConditionType).BasicType <> btBool) then
        begin
          LPos := GetNodePosition(ANode.GetChild(ANode.ChildCount() - 1));
          FErrorCollector.AddTypeError(
            'Repeat condition must be boolean',
            'bool',
            LConditionType.GetTypeName(),
            LPos.FileName, LPos.Line, LPos.Column
          );
        end;
      end;
    end;
  finally
    FInLoop := LOldInLoop;
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeCaseStatement(const ANode: TCPASTNode);
var
  LIndex: Integer;
begin
  // Simplified case analysis
  if ANode.ChildCount() >= 1 then
  begin
    // Analyze case expression
    FTypeChecker.InferExpressionType(ANode.GetChild(0));
    
    // Analyze case items (simplified)
    for LIndex := 1 to ANode.ChildCount() - 1 do
      AnalyzeNode(ANode.GetChild(LIndex));
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeReturnStatement(const ANode: TCPASTNode);
var
  LReturnType: TCPType;
  LExpectedReturnType: TCPType;
  LPos: TCPSourcePosition;
begin
  if not Assigned(FCurrentFunction) then
  begin
    LPos := GetNodePosition(ANode);
    FErrorCollector.AddSemanticError('Return statement outside function', '', LPos.FileName, LPos.Line, LPos.Column);
    Exit;
  end;
  
  LExpectedReturnType := nil;
  if FCurrentFunction.SymbolType is TCPFunctionType then
    LExpectedReturnType := TCPFunctionType(FCurrentFunction.SymbolType).ReturnType;
  
  if ANode.ChildCount() > 0 then
  begin
    // Return with value
    LReturnType := FTypeChecker.InferExpressionType(ANode.GetChild(0));
    
    if not Assigned(LExpectedReturnType) then
    begin
      LPos := GetNodePosition(ANode);
      FErrorCollector.AddSemanticError('Procedure cannot return a value', '', LPos.FileName, LPos.Line, LPos.Column);
    end
    else if Assigned(LReturnType) then
    begin
      FTypeChecker.CheckAssignmentCompatibility(LExpectedReturnType, LReturnType, ANode);
    end;
  end
  else
  begin
    // Return without value
    if Assigned(LExpectedReturnType) then
    begin
      LPos := GetNodePosition(ANode);
      FErrorCollector.AddSemanticError('Function must return a value', '', LPos.FileName, LPos.Line, LPos.Column);
    end;
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeCallStatement(const ANode: TCPASTNode);
begin
  // Analyze the expression (which should be a function call)
  if ANode.ChildCount() > 0 then
    AnalyzeExpression(ANode.GetChild(0));
end;

procedure TCPSemanticAnalyzer.AnalyzeBreakStatement(const ANode: TCPASTNode);
var
  LPos: TCPSourcePosition;
begin
  if not FInLoop then
  begin
    LPos := GetNodePosition(ANode);
    FErrorCollector.AddSemanticError('Break statement outside loop', '', LPos.FileName, LPos.Line, LPos.Column);
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeContinueStatement(const ANode: TCPASTNode);
var
  LPos: TCPSourcePosition;
begin
  if not FInLoop then
  begin
    LPos := GetNodePosition(ANode);
    FErrorCollector.AddSemanticError('Continue statement outside loop', '', LPos.FileName, LPos.Line, LPos.Column);
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeGotoStatement(const ANode: TCPASTNode);
begin
  // Simplified goto analysis - would need label tracking for full implementation
  if ANode.ChildCount() > 0 then
  begin
    // TODO: Validate that the label exists
  end;
end;

procedure TCPSemanticAnalyzer.AnalyzeExpression(const ANode: TCPASTNode);
begin
  // Let the type checker handle expression analysis
  FTypeChecker.InferExpressionType(ANode);
end;

procedure TCPSemanticAnalyzer.AnalyzeFunctionCall(const ANode: TCPASTNode);
begin
  // Function calls are handled by the type checker in InferExpressionType
  FTypeChecker.InferExpressionType(ANode);
end;

function TCPSemanticAnalyzer.ProcessFunctionHeader(const ANode: TCPASTNode): TCPSymbol;
var
  LFunctionName: string;
  LParameterTypes: TArray<TCPType>;
  LReturnType: TCPType;
  LFunctionType: TCPFunctionType;
  LIsFunction: Boolean;
  LIsVariadic: Boolean;
  LPos: TCPSourcePosition;
begin
  Result := nil;
  
  if ANode.ChildCount() < 1 then
    Exit;
    
  // Get function name from FIRST child (index 0)
  if ANode.GetChild(0).NodeType = astIdentifier then
    LFunctionName := ANode.GetChild(0).Value
  else
    Exit;
    
  LIsFunction := ANode.Value = 'function';
  
  // Process parameters from SECOND child (index 1)
  if ANode.ChildCount() >= 2 then
  begin
    LParameterTypes := ProcessParameterList(ANode.GetChild(1));
    LIsVariadic := HasVariadicParameters(ANode.GetChild(1));
  end
  else
  begin
    SetLength(LParameterTypes, 0);
    LIsVariadic := False;
  end;
    
  // Process return type for functions from THIRD child (index 2)
  if LIsFunction and (ANode.ChildCount() >= 3) then
    LReturnType := ResolveTypeFromNode(ANode.GetChild(2))
  else
    LReturnType := nil;
    
  // Create function type with variadic flag
  LFunctionType := FTypeManager.CreateFunctionType(LParameterTypes, LReturnType, LIsVariadic);
  
  // Declare function symbol
  try
    Result := FSymbolTable.DeclareSymbol(LFunctionName, skFunction, LFunctionType, ANode.GetChild(0));
  except
    on E: ECPException do
    begin
      LPos := GetNodePosition(ANode.GetChild(0));
      FErrorCollector.AddSemanticError(E.Message, LFunctionName, LPos.FileName, LPos.Line, LPos.Column);
    end;
  end;
end;

function TCPSemanticAnalyzer.ProcessParameterList(const ANode: TCPASTNode): TArray<TCPType>;
var
  LParameterTypes: TList<TCPType>;
  LIndex: Integer;
  LParamNode: TCPASTNode;
  LParamType: TCPType;
  LIdentifierCount: Integer;
  LIdentifierIndex: Integer;
begin
  LParameterTypes := TList<TCPType>.Create();
  try
    for LIndex := 0 to ANode.ChildCount() - 1 do
    begin
      LParamNode := ANode.GetChild(LIndex);
      
      // Check for variadic parameter (...)
      if (LParamNode.NodeType = astParameterList) and (LParamNode.Value = '...') then
      begin
        // Variadic parameter found - don't add to parameter types, just note it
        Continue;
      end;
      
      if LParamNode.ChildCount() >= 2 then
      begin
        // Last child is type, preceding children are identifiers
        LParamType := ResolveTypeFromNode(LParamNode.GetChild(LParamNode.ChildCount() - 1));
        
        if Assigned(LParamType) then
        begin
          // Count identifiers (all children except the last one which is the type)
          LIdentifierCount := LParamNode.ChildCount() - 1;
          
          // Add the type for each identifier
          for LIdentifierIndex := 0 to LIdentifierCount - 1 do
            LParameterTypes.Add(LParamType);
        end;
      end;
    end;
    
    Result := LParameterTypes.ToArray();
  finally
    LParameterTypes.Free();
  end;
end;

function TCPSemanticAnalyzer.ExtractParameterInfo(const ANode: TCPASTNode): TArray<TCPParameterInfo>;
var
  LParameterList: TList<TCPParameterInfo>;
  LParameterListNode: TCPASTNode;
  LIndex: Integer;
  LParamNode: TCPASTNode;
  LParamType: TCPType;
  LModifier: string;
  LIdentifierCount: Integer;
  LIdentifierIndex: Integer;
  LIdentifierNode: TCPASTNode;
  LParamInfo: TCPParameterInfo;
begin
  LParameterList := TList<TCPParameterInfo>.Create();
  try
    // Get the parameter list node (second child of function header)
    if (ANode.ChildCount() >= 2) then
    begin
      LParameterListNode := ANode.GetChild(1);
      
      for LIndex := 0 to LParameterListNode.ChildCount() - 1 do
      begin
        LParamNode := LParameterListNode.GetChild(LIndex);
        
        if LParamNode.ChildCount() >= 2 then
        begin
          // Extract modifier from node value
          LModifier := LParamNode.Value;
          
          // Last child is type, preceding children are identifiers
          LParamType := ResolveTypeFromNode(LParamNode.GetChild(LParamNode.ChildCount() - 1));
          
          if Assigned(LParamType) then
          begin
            // Count identifiers (all children except the last one which is the type)
            LIdentifierCount := LParamNode.ChildCount() - 1;
            
            // Create parameter info for each identifier
            for LIdentifierIndex := 0 to LIdentifierCount - 1 do
            begin
              LIdentifierNode := LParamNode.GetChild(LIdentifierIndex);
              if LIdentifierNode.NodeType = astIdentifier then
              begin
                LParamInfo.ParameterName := LIdentifierNode.Value;
                LParamInfo.ParameterType := LParamType;
                LParamInfo.Modifier := LModifier;
                LParamInfo.DeclaredNode := LIdentifierNode;
                LParameterList.Add(LParamInfo);
              end;
            end;
          end;
        end;
      end;
    end;
    
    Result := LParameterList.ToArray();
  finally
    LParameterList.Free();
  end;
end;

function TCPSemanticAnalyzer.HasVariadicParameters(const ANode: TCPASTNode): Boolean;
var
  LIndex: Integer;
  LParamNode: TCPASTNode;
begin
  Result := False;
  
  for LIndex := 0 to ANode.ChildCount() - 1 do
  begin
    LParamNode := ANode.GetChild(LIndex);
    
    // Check for variadic parameter (...)
    if (LParamNode.NodeType = astParameterList) and (LParamNode.Value = '...') then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TCPSemanticAnalyzer.ResolveTypeFromNode(const ANode: TCPASTNode): TCPType;
begin
  Result := FTypeManager.ResolveType(ANode);
end;

function TCPSemanticAnalyzer.GetUnusedSymbolWarnings(): TArray<TCPCompilerError>;
var
  LUnusedSymbols: TArray<TCPSymbol>;
  LWarnings: TList<TCPCompilerError>;
  LSymbol: TCPSymbol;
  LWarning: TCPCompilerError;
begin
  LWarnings := TList<TCPCompilerError>.Create();
  try
    LUnusedSymbols := FSymbolTable.GetUnusedSymbols();
    
    for LSymbol in LUnusedSymbols do
    begin
      LWarning := TCPCompilerError.Create(
        Format('Unused variable: %s', [LSymbol.SymbolName]),
        'Semantic',
        LSymbol.FileName,
        LSymbol.DeclaredLine,
        LSymbol.DeclaredColumn,
        esWarning
      ).WithSymbol(LSymbol.SymbolName);
      
      LWarnings.Add(LWarning);
    end;
    
    Result := LWarnings.ToArray();
  finally
    LWarnings.Free();
  end;
end;

end.

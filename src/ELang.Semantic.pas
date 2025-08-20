{===============================================================================
   ___    _
  | __|__| |   __ _ _ _  __ _ ™
  | _|___| |__/ _` | ' \/ _` |
  |___|  |____\__,_|_||_\__, |
                        |___/
    C Power | Pascal Clarity

 Copyright © 2025-present tinyBigGAMES™ LLC
 All Rights Reserved.
===============================================================================}

unit ELang.Semantic;

{$I ELang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  ELang.Common,
  ELang.Parser,
  ELang.Types,
  ELang.Symbols,
  ELang.TypeChecker,
  ELang.Errors,
  ELang.SourceMap;

type
  { TELParameterInfo }
  TELParameterInfo = record
    ParameterName: string;
    ParameterType: TELType;
    Modifier: string; // 'ref', 'const', or empty
    DeclaredNode: TELASTNode;
  end;

  { TELSemanticAnalyzer }
  TELSemanticAnalyzer = class(TELObject)
  private
    FSymbolTable: TELSymbolTable;
    FTypeManager: TELTypeManager;
    FTypeChecker: TELTypeChecker;
    FErrorCollector: TELErrorCollector;
    FSourceMapper: TELSourceMapper;
    FHasMainFunction: Boolean;
    FCurrentFunction: TELSymbol;
    FInLoop: Boolean;
    
    procedure AnalyzeNode(const ANode: TELASTNode);
    procedure AnalyzeProgram(const ANode: TELASTNode);
    procedure AnalyzeVariableDecl(const ANode: TELASTNode);
    procedure AnalyzeFunctionDecl(const ANode: TELASTNode);
    procedure AnalyzeMainFunction(const ANode: TELASTNode);
    procedure AnalyzeTypeDecl(const ANode: TELASTNode);
    procedure AnalyzeStatementBlock(const ANode: TELASTNode);
    procedure AnalyzeStatement(const ANode: TELASTNode);
    procedure AnalyzeAssignment(const ANode: TELASTNode);
    procedure AnalyzeIfStatement(const ANode: TELASTNode);
    procedure AnalyzeWhileStatement(const ANode: TELASTNode);
    procedure AnalyzeForStatement(const ANode: TELASTNode);
    procedure AnalyzeRepeatStatement(const ANode: TELASTNode);
    procedure AnalyzeCaseStatement(const ANode: TELASTNode);
    procedure AnalyzeReturnStatement(const ANode: TELASTNode);
    procedure AnalyzeCallStatement(const ANode: TELASTNode);
    procedure AnalyzeBreakStatement(const ANode: TELASTNode);
    procedure AnalyzeContinueStatement(const ANode: TELASTNode);
    procedure AnalyzeGotoStatement(const ANode: TELASTNode);
    procedure AnalyzeExpression(const ANode: TELASTNode);
    procedure AnalyzeFunctionCall(const ANode: TELASTNode);
    
    function ProcessFunctionHeader(const ANode: TELASTNode): TELSymbol;
    function ProcessParameterList(const ANode: TELASTNode): TArray<TELType>;
    function ExtractParameterInfo(const ANode: TELASTNode): TArray<TELParameterInfo>;
    function HasVariadicParameters(const ANode: TELASTNode): Boolean;
    function ResolveTypeFromNode(const ANode: TELASTNode): TELType;
    function GetNodePosition(const ANode: TELASTNode): TELSourcePosition;
    function GetLineColumnFromPosition(const ACharIndex: Integer): TELLineColumn;
    function ValidateMainFunction(const ANode: TELASTNode): Boolean;
    
  public
    constructor Create(const ATypeManager: TELTypeManager; 
      const AErrorCollector: TELErrorCollector; const ASourceMapper: TELSourceMapper = nil); reintroduce;
    destructor Destroy(); override;
    
    function Analyze(const AAST: TELASTNode): Boolean;
    function GetUnusedSymbolWarnings(): TArray<TELCompilerError>;
    
    property SymbolTable: TELSymbolTable read FSymbolTable;
    property HasMainFunction: Boolean read FHasMainFunction;
  end;

implementation

{ TELSemanticAnalyzer }

constructor TELSemanticAnalyzer.Create(const ATypeManager: TELTypeManager; 
  const AErrorCollector: TELErrorCollector; const ASourceMapper: TELSourceMapper);
begin
  inherited Create();
  FTypeManager := ATypeManager;
  FErrorCollector := AErrorCollector;
  FSourceMapper := ASourceMapper;
  FSymbolTable := TELSymbolTable.Create();
  FTypeChecker := TELTypeChecker.Create(FTypeManager, FSymbolTable, FErrorCollector);
  FHasMainFunction := False;
  FCurrentFunction := nil;
  FInLoop := False;
end;

destructor TELSemanticAnalyzer.Destroy();
begin
  FTypeChecker.Free();
  FSymbolTable.Free();
  inherited;
end;

function TELSemanticAnalyzer.GetNodePosition(const ANode: TELASTNode): TELSourcePosition;
begin
  if Assigned(ANode) and (ANode.Position > 0) and Assigned(FSourceMapper) then
  begin
    // Map character position through source mapper for includes
    Result := FSourceMapper.MapPosition(ANode.Position);
  end
  else if Assigned(ANode) and (ANode.Position > 0) then
  begin
    // Fallback: calculate position from character index without source mapping
    var LLineColumn := GetLineColumnFromPosition(ANode.Position);
    Result := TELSourcePosition.Create('<source>', LLineColumn.Line, LLineColumn.Column, ANode.Position);
  end
  else
  begin
    // Last resort: unknown position
    Result := TELSourcePosition.Create('<unknown>', 0, 0, 0);
  end;
end;

function TELSemanticAnalyzer.GetLineColumnFromPosition(const ACharIndex: Integer): TELLineColumn;
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

function TELSemanticAnalyzer.Analyze(const AAST: TELASTNode): Boolean;
begin
  Result := False;
  FHasMainFunction := False;
  
  try
    if not Assigned(AAST) then
    begin
      FErrorCollector.AddSemanticError('No AST provided for semantic analysis', '', '<source>', 0, 0);
      Exit;
    end;
    
    AnalyzeNode(AAST);
    
    // Check for mandatory main function
    if not FHasMainFunction then
    begin
      var LPos := GetNodePosition(AAST);
      FErrorCollector.AddSemanticError('Program must have a main function', '', LPos.FileName, LPos.Line, LPos.Column);
    end;
    
    Result := not FErrorCollector.HasErrors();
    
  except
    on E: Exception do
    begin
      var LPos := GetNodePosition(AAST);
      FErrorCollector.AddSemanticError('Internal semantic analysis error: ' + E.Message, '', LPos.FileName, LPos.Line, LPos.Column);
    end;
  end;
end;

procedure TELSemanticAnalyzer.AnalyzeNode(const ANode: TELASTNode);
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
    for var LIndex := 0 to ANode.ChildCount() - 1 do
      AnalyzeNode(ANode.GetChild(LIndex));
  end;
end;

procedure TELSemanticAnalyzer.AnalyzeProgram(const ANode: TELASTNode);
var
  LIndex: Integer;
begin
  // Analyze all top-level declarations
  for LIndex := 0 to ANode.ChildCount() - 1 do
    AnalyzeNode(ANode.GetChild(LIndex));
end;

procedure TELSemanticAnalyzer.AnalyzeVariableDecl(const ANode: TELASTNode);
var
  LTypeNode: TELASTNode;
  LVariableType: TELType;
  LIdentifierNode: TELASTNode;
  LVariableName: string;
  LSymbol: TELSymbol;
  LIndex: Integer;
  LInitExpression: TELASTNode;
  LInitType: TELType;
begin
  if ANode.ChildCount() < 2 then
    Exit;
    
  // Last child is the type specification
  LTypeNode := ANode.GetChild(ANode.ChildCount() - 1);
  LVariableType := ResolveTypeFromNode(LTypeNode);
  
  if not Assigned(LVariableType) then
  begin
    var LPos := GetNodePosition(LTypeNode);
    FErrorCollector.AddSemanticError('Cannot resolve variable type', '', LPos.FileName, LPos.Line, LPos.Column);
    Exit;
  end;
  
  // All children except the last are identifiers (and potentially initialization)
  for LIndex := 0 to ANode.ChildCount() - 2 do
  begin
    LIdentifierNode := ANode.GetChild(LIndex);
    if LIdentifierNode.NodeType = astIdentifier then
    begin
      LVariableName := LIdentifierNode.Value;
      
      // Check for redeclaration in current scope
      if FSymbolTable.CheckForRedeclaration(LVariableName, LIdentifierNode) then
      begin
        var LPos := GetNodePosition(LIdentifierNode);
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
        if (ANode.ChildCount() >= 3) and (LIndex = ANode.ChildCount() - 3) then
        begin
          // There might be an initialization expression
          LInitExpression := ANode.GetChild(ANode.ChildCount() - 2);
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
      on E: EELException do
      begin
      var LPos := GetNodePosition(LIdentifierNode);
        FErrorCollector.AddSemanticError(E.Message, LVariableName, LPos.FileName, LPos.Line, LPos.Column);
        end;
        end;
    end;
  end;
end;

procedure TELSemanticAnalyzer.AnalyzeFunctionDecl(const ANode: TELASTNode);
var
  LFunctionSymbol: TELSymbol;
  LOldFunction: TELSymbol;
  LIsExternal: Boolean;
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
    if LFunctionSymbol.SymbolType is TELFunctionType then
    begin
      // Extract parameter information from the function header and add to scope
      var LParameterInfo := ExtractParameterInfo(ANode.GetChild(0));
      for var LParam in LParameterInfo do
      begin
        try
          var LParamSymbol := FSymbolTable.DeclareSymbol(
            LParam.ParameterName, 
            skParameter, 
            LParam.ParameterType, 
            LParam.DeclaredNode
          );
          LParamSymbol.IsInitialized := True; // Parameters are always initialized
        except
          on E: EELException do
          begin
            var LPos := GetNodePosition(LParam.DeclaredNode);
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

procedure TELSemanticAnalyzer.AnalyzeMainFunction(const ANode: TELASTNode);
var
  LMainSymbol: TELSymbol;
  LOldFunction: TELSymbol;
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

function TELSemanticAnalyzer.ValidateMainFunction(const ANode: TELASTNode): Boolean;
begin
  Result := True;
  
  if ANode.ChildCount() < 2 then
  begin
    var LPos := GetNodePosition(ANode);
    FErrorCollector.AddSemanticError('Main function is malformed', 'main', LPos.FileName, LPos.Line, LPos.Column);
    Exit(False);
  end;
  
  // Main function should have 2 children: header and statement block
  // The signature is validated in ProcessFunctionHeader
end;

procedure TELSemanticAnalyzer.AnalyzeTypeDecl(const ANode: TELASTNode);
var
  LTypeName: string;
  LTypeSpec: TELType;
  LSymbol: TELSymbol;
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
        LSymbol := FSymbolTable.DeclareSymbol(LTypeName, skType, LTypeSpec, ANode.GetChild(0));
        FTypeManager.RegisterType(LTypeName, LTypeSpec);
      except
        on E: EELException do
        begin
          var LPos := GetNodePosition(ANode.GetChild(0));
          FErrorCollector.AddSemanticError(E.Message, LTypeName, LPos.FileName, LPos.Line, LPos.Column);
        end;
      end;
    end;
  end;
end;

procedure TELSemanticAnalyzer.AnalyzeStatementBlock(const ANode: TELASTNode);
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

procedure TELSemanticAnalyzer.AnalyzeStatement(const ANode: TELASTNode);
begin
  AnalyzeNode(ANode);
end;

procedure TELSemanticAnalyzer.AnalyzeAssignment(const ANode: TELASTNode);
var
  LLValueType: TELType;
  LRValueType: TELType;
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

procedure TELSemanticAnalyzer.AnalyzeIfStatement(const ANode: TELASTNode);
var
  LConditionType: TELType;
begin
  if ANode.ChildCount() < 2 then
    Exit;
    
  // Analyze condition
  LConditionType := FTypeChecker.InferExpressionType(ANode.GetChild(0));
  if Assigned(LConditionType) then
  begin
    if not (LConditionType is TELBasicTypeInfo) or 
       (TELBasicTypeInfo(LConditionType).BasicType <> btBool) then
    begin
      var LPos := GetNodePosition(ANode.GetChild(0));
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

procedure TELSemanticAnalyzer.AnalyzeWhileStatement(const ANode: TELASTNode);
var
  LConditionType: TELType;
  LOldInLoop: Boolean;
begin
  if ANode.ChildCount() < 2 then
    Exit;
    
  // Analyze condition
  LConditionType := FTypeChecker.InferExpressionType(ANode.GetChild(0));
  if Assigned(LConditionType) then
  begin
    if not (LConditionType is TELBasicTypeInfo) or 
       (TELBasicTypeInfo(LConditionType).BasicType <> btBool) then
    begin
      var LPos := GetNodePosition(ANode.GetChild(0));
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

procedure TELSemanticAnalyzer.AnalyzeForStatement(const ANode: TELASTNode);
var
  LOldInLoop: Boolean;
  LVariableType: TELType;
  LStartType: TELType;
  LEndType: TELType;
begin
  if ANode.ChildCount() < 4 then
    Exit;
    
  // Analyze loop variable (should be integer)
  LVariableType := FTypeChecker.InferExpressionType(ANode.GetChild(0));
  LStartType := FTypeChecker.InferExpressionType(ANode.GetChild(1));
  LEndType := FTypeChecker.InferExpressionType(ANode.GetChild(2));
  
  // Validate types
  if Assigned(LVariableType) and not (LVariableType is TELBasicTypeInfo) then
  begin
    var LPos := GetNodePosition(ANode.GetChild(0));
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

procedure TELSemanticAnalyzer.AnalyzeRepeatStatement(const ANode: TELASTNode);
var
  LOldInLoop: Boolean;
  LConditionType: TELType;
  LIndex: Integer;
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
        if not (LConditionType is TELBasicTypeInfo) or 
           (TELBasicTypeInfo(LConditionType).BasicType <> btBool) then
        begin
          var LPos := GetNodePosition(ANode.GetChild(ANode.ChildCount() - 1));
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

procedure TELSemanticAnalyzer.AnalyzeCaseStatement(const ANode: TELASTNode);
begin
  // Simplified case analysis
  if ANode.ChildCount() >= 1 then
  begin
    // Analyze case expression
    FTypeChecker.InferExpressionType(ANode.GetChild(0));
    
    // Analyze case items (simplified)
    for var LIndex := 1 to ANode.ChildCount() - 1 do
      AnalyzeNode(ANode.GetChild(LIndex));
  end;
end;

procedure TELSemanticAnalyzer.AnalyzeReturnStatement(const ANode: TELASTNode);
var
  LReturnType: TELType;
  LExpectedReturnType: TELType;
begin
  if not Assigned(FCurrentFunction) then
  begin
    var LPos := GetNodePosition(ANode);
    FErrorCollector.AddSemanticError('Return statement outside function', '', LPos.FileName, LPos.Line, LPos.Column);
    Exit;
  end;
  
  LExpectedReturnType := nil;
  if FCurrentFunction.SymbolType is TELFunctionType then
    LExpectedReturnType := TELFunctionType(FCurrentFunction.SymbolType).ReturnType;
  
  if ANode.ChildCount() > 0 then
  begin
    // Return with value
    LReturnType := FTypeChecker.InferExpressionType(ANode.GetChild(0));
    
    if not Assigned(LExpectedReturnType) then
    begin
      var LPos := GetNodePosition(ANode);
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
      var LPos := GetNodePosition(ANode);
      FErrorCollector.AddSemanticError('Function must return a value', '', LPos.FileName, LPos.Line, LPos.Column);
    end;
  end;
end;

procedure TELSemanticAnalyzer.AnalyzeCallStatement(const ANode: TELASTNode);
begin
  // Analyze the expression (which should be a function call)
  if ANode.ChildCount() > 0 then
    AnalyzeExpression(ANode.GetChild(0));
end;

procedure TELSemanticAnalyzer.AnalyzeBreakStatement(const ANode: TELASTNode);
begin
  if not FInLoop then
  begin
    var LPos := GetNodePosition(ANode);
    FErrorCollector.AddSemanticError('Break statement outside loop', '', LPos.FileName, LPos.Line, LPos.Column);
  end;
end;

procedure TELSemanticAnalyzer.AnalyzeContinueStatement(const ANode: TELASTNode);
begin
  if not FInLoop then
  begin
    var LPos := GetNodePosition(ANode);
    FErrorCollector.AddSemanticError('Continue statement outside loop', '', LPos.FileName, LPos.Line, LPos.Column);
  end;
end;

procedure TELSemanticAnalyzer.AnalyzeGotoStatement(const ANode: TELASTNode);
begin
  // Simplified goto analysis - would need label tracking for full implementation
  if ANode.ChildCount() > 0 then
  begin
    // TODO: Validate that the label exists
  end;
end;

procedure TELSemanticAnalyzer.AnalyzeExpression(const ANode: TELASTNode);
begin
  // Let the type checker handle expression analysis
  FTypeChecker.InferExpressionType(ANode);
end;

procedure TELSemanticAnalyzer.AnalyzeFunctionCall(const ANode: TELASTNode);
begin
  // Function calls are handled by the type checker in InferExpressionType
  FTypeChecker.InferExpressionType(ANode);
end;

function TELSemanticAnalyzer.ProcessFunctionHeader(const ANode: TELASTNode): TELSymbol;
var
  LFunctionName: string;
  LParameterTypes: TArray<TELType>;
  LReturnType: TELType;
  LFunctionType: TELFunctionType;
  LIsFunction: Boolean;
  LIsVariadic: Boolean;
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
    on E: EELException do
    begin
      var LPos := GetNodePosition(ANode.GetChild(0));
      FErrorCollector.AddSemanticError(E.Message, LFunctionName, LPos.FileName, LPos.Line, LPos.Column);
    end;
  end;
end;

function TELSemanticAnalyzer.ProcessParameterList(const ANode: TELASTNode): TArray<TELType>;
var
  LParameterTypes: TList<TELType>;
  LIndex: Integer;
  LParamNode: TELASTNode;
  LParamType: TELType;
  LIdentifierCount: Integer;
  LIdentifierIndex: Integer;
begin
  LParameterTypes := TList<TELType>.Create();
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

function TELSemanticAnalyzer.ExtractParameterInfo(const ANode: TELASTNode): TArray<TELParameterInfo>;
var
  LParameterList: TList<TELParameterInfo>;
  LParameterListNode: TELASTNode;
  LIndex: Integer;
  LParamNode: TELASTNode;
  LParamType: TELType;
  LModifier: string;
  LIdentifierCount: Integer;
  LIdentifierIndex: Integer;
  LIdentifierNode: TELASTNode;
  LParamInfo: TELParameterInfo;
begin
  LParameterList := TList<TELParameterInfo>.Create();
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

function TELSemanticAnalyzer.HasVariadicParameters(const ANode: TELASTNode): Boolean;
var
  LIndex: Integer;
  LParamNode: TELASTNode;
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

function TELSemanticAnalyzer.ResolveTypeFromNode(const ANode: TELASTNode): TELType;
begin
  Result := FTypeManager.ResolveType(ANode);
end;

function TELSemanticAnalyzer.GetUnusedSymbolWarnings(): TArray<TELCompilerError>;
var
  LUnusedSymbols: TArray<TELSymbol>;
  LWarnings: TList<TELCompilerError>;
  LSymbol: TELSymbol;
  LWarning: TELCompilerError;
begin
  LWarnings := TList<TELCompilerError>.Create();
  try
    LUnusedSymbols := FSymbolTable.GetUnusedSymbols();
    
    for LSymbol in LUnusedSymbols do
    begin
      LWarning := TELCompilerError.Create(
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

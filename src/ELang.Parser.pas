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

unit ELang.Parser;

{$I ELang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  ELang.Common,
  ELang.Lexer,
  ELang.Errors;

type
  { TELASTNodeType }
  TELASTNodeType = (
    astProgram,
    astMainFunction,
    astVariableDecl,
    astFunctionDecl,
    astTypeDecl,
    astStatementBlock,
    astAssignment,
    astIfStatement,
    astWhileStatement,
    astForStatement,
    astRepeatStatement,
    astCaseStatement,
    astReturnStatement,
    astCallStatement,
    astBreakStatement,
    astContinueStatement,
    astGotoStatement,
    astLabelStatement,
    astExpression,
    astBinaryOp,
    astUnaryOp,
    astIdentifier,
    astLiteral,
    astArrayAccess,
    astMemberAccess,
    astFunctionCall,
    astTypeSpec,
    astParameterList,
    astArgumentList
  );

  { TELASTNode }
  TELASTNode = class
  private
    FNodeType: TELASTNodeType;
    FValue: string;
    FPosition: Integer;
    FChildren: TObjectList<TELASTNode>;
    
  public
    constructor Create(const ANodeType: TELASTNodeType; const AValue: string = '');
    destructor Destroy(); override;
    
    procedure AddChild(const AChild: TELASTNode);
    function GetChild(const AIndex: Integer): TELASTNode;
    function ChildCount(): Integer;
    
    property NodeType: TELASTNodeType read FNodeType;
    property Value: string read FValue write FValue;
    property Position: Integer read FPosition write FPosition;
  end;

  { TELParser }
  TELParser = class(TELObject)
  private
    FTokens: TArray<TELToken>;
    FCurrentIndex: Integer;
    FCurrentToken: TELToken;
    
    procedure AdvanceToken();
    function PeekToken(const AOffset: Integer = 1): TELToken;
    function IsAtEnd(): Boolean;
    function Match(const ATokenType: TELTokenType): Boolean;
    function Consume(const ATokenType: TELTokenType; const AMessage: string): TELToken;
    function Check(const ATokenType: TELTokenType): Boolean;
    
    // Grammar rules - direct from BNF
    function ParseProgram(): TELASTNode;
    function ParseMainFunction(): TELASTNode;
    function ParseDeclaration(): TELASTNode;
    function ParseVariableDeclaration(): TELASTNode;
    function ParseFunctionDeclaration(): TELASTNode;
    function ParseTypeDeclaration(): TELASTNode;
    function ParseFunctionHeader(): TELASTNode;
    function ParseParameterList(): TELASTNode;
    function ParseParamDef(): TELASTNode;
    function ParseTypeSpec(): TELASTNode;
    function ParseBasicType(): TELASTNode;
    function ParsePointerType(): TELASTNode;
    function ParseArrayType(): TELASTNode;
    function ParseRecordType(): TELASTNode;
    function ParseStatement(): TELASTNode;
    function ParseStatementBlock(): TELASTNode;
    function ParseStatementList(): TELASTNode;
    function ParseAssignmentStatement(): TELASTNode;
    function ParseIfStatement(): TELASTNode;
    function ParseWhileStatement(): TELASTNode;
    function ParseForStatement(): TELASTNode;
    function ParseRepeatStatement(): TELASTNode;
    function ParseCaseStatement(): TELASTNode;
    function ParseReturnStatement(): TELASTNode;
    function ParseCallStatement(): TELASTNode;
    function ParseCaseItem(): TELASTNode;
    function ParseCaseLabels(): TELASTNode;
    function ParseExpression(): TELASTNode;
    function ParseConditionalExpression(): TELASTNode;
    function ParseLogicalOrExpression(): TELASTNode;
    function ParseLogicalAndExpression(): TELASTNode;
    function ParseEqualityExpression(): TELASTNode;
    function ParseRelationalExpression(): TELASTNode;
    function ParseAdditiveExpression(): TELASTNode;
    function ParseMultiplicativeExpression(): TELASTNode;
    function ParseUnaryExpression(): TELASTNode;
    function ParsePostfixExpression(): TELASTNode;
    function ParsePrimaryExpression(): TELASTNode;
    function ParseArgumentList(): TELASTNode;
    function ParseLValue(): TELASTNode;
    
  public
    constructor Create(); override;
    destructor Destroy(); override;
    
    function Parse(const ATokens: TArray<TELToken>): TELASTNode;
  end;

implementation

{ TELASTNode }

constructor TELASTNode.Create(const ANodeType: TELASTNodeType; const AValue: string);
begin
  inherited Create();
  FNodeType := ANodeType;
  FValue := AValue;
  FPosition := 0;
  FChildren := TObjectList<TELASTNode>.Create(True);
end;

destructor TELASTNode.Destroy();
begin
  FChildren.Free();
  inherited;
end;

procedure TELASTNode.AddChild(const AChild: TELASTNode);
begin
  if Assigned(AChild) then
    FChildren.Add(AChild);
end;

function TELASTNode.GetChild(const AIndex: Integer): TELASTNode;
begin
  if (AIndex >= 0) and (AIndex < FChildren.Count) then
    Result := FChildren[AIndex]
  else
    Result := nil;
end;

function TELASTNode.ChildCount(): Integer;
begin
  Result := FChildren.Count;
end;

{ TELParser }

constructor TELParser.Create();
begin
  inherited;
  SetLength(FTokens, 0);
  FCurrentIndex := 0;
  FCurrentToken.TokenType := ttEOF;
end;

destructor TELParser.Destroy();
begin
  inherited;
end;

function TELParser.Parse(const ATokens: TArray<TELToken>): TELASTNode;
begin
  FTokens := ATokens;
  FCurrentIndex := 0;
  if Length(FTokens) > 0 then
    FCurrentToken := FTokens[0]
  else
    FCurrentToken.TokenType := ttEOF;
    
  Result := ParseProgram();
end;

procedure TELParser.AdvanceToken();
begin
  if FCurrentIndex < High(FTokens) then
  begin
    Inc(FCurrentIndex);
    FCurrentToken := FTokens[FCurrentIndex];
  end
  else
  begin
    FCurrentToken.TokenType := ttEOF;
  end;
end;

function TELParser.PeekToken(const AOffset: Integer): TELToken;
var
  LIndex: Integer;
begin
  LIndex := FCurrentIndex + AOffset;
  if LIndex < Length(FTokens) then
    Result := FTokens[LIndex]
  else
    Result.TokenType := ttEOF;
end;

function TELParser.IsAtEnd(): Boolean;
begin
  Result := FCurrentToken.TokenType = ttEOF;
end;

function TELParser.Match(const ATokenType: TELTokenType): Boolean;
begin
  if Check(ATokenType) then
  begin
    AdvanceToken();
    Result := True;
  end
  else
    Result := False;
end;

function TELParser.Consume(const ATokenType: TELTokenType; const AMessage: string): TELToken;
begin
  if Check(ATokenType) then
  begin
    Result := FCurrentToken;
    AdvanceToken();
  end
  else
    raise EELException.Create('Parse error: %s. Got %s', [AMessage, FCurrentToken.Value], 
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
end;

function TELParser.Check(const ATokenType: TELTokenType): Boolean;
begin
  if IsAtEnd() then
    Result := False
  else
    Result := FCurrentToken.TokenType = ATokenType;
end;

function TELParser.ParseProgram(): TELASTNode;
var
  LProgram: TELASTNode;
  LDeclaration: TELASTNode;
begin
  LProgram := TELASTNode.Create(astProgram);
  
  // Parse all declarations and functions in any order
  while not IsAtEnd() do
  begin
    LDeclaration := ParseDeclaration();
    if Assigned(LDeclaration) then
      LProgram.AddChild(LDeclaration);
  end;
  
  Result := LProgram;
end;

function TELParser.ParseMainFunction(): TELASTNode;
var
  LMainFunc: TELASTNode;
  LHeader: TELASTNode;
  LBlock: TELASTNode;
begin
  LMainFunc := TELASTNode.Create(astMainFunction);
  
  LHeader := ParseFunctionHeader();
  LMainFunc.AddChild(LHeader);
  
  LBlock := ParseStatementBlock();
  LMainFunc.AddChild(LBlock);
  
  Result := LMainFunc;
end;

function TELParser.ParseDeclaration(): TELASTNode;
begin
  case FCurrentToken.TokenType of
    ttVar, ttConst:
      Result := ParseVariableDeclaration();
    ttFunction:
      if PeekToken().TokenType = ttMain then
        Result := ParseMainFunction()
      else
        Result := ParseFunctionDeclaration();
    ttProcedure:
      Result := ParseFunctionDeclaration();
    ttType:
      Result := ParseTypeDeclaration();
  else
    Result := ParseStatement();
  end;
end;

function TELParser.ParseVariableDeclaration(): TELASTNode;
var
  LVarDecl: TELASTNode;
  LTypeSpec: TELASTNode;
begin
  LVarDecl := TELASTNode.Create(astVariableDecl);
  
  if Match(ttVar) or Match(ttConst) then
  begin
    // identifier_list
    repeat
      LVarDecl.AddChild(TELASTNode.Create(astIdentifier, FCurrentToken.Value));
      Consume(ttIdentifier, 'Expected identifier');
    until not Match(ttComma);
    
    Consume(ttColon, 'Expected ":"');
    
    LTypeSpec := ParseTypeSpec();
    LVarDecl.AddChild(LTypeSpec);
    
    // Optional initialization
    if Match(ttAssign) then
    begin
      LVarDecl.AddChild(ParseExpression());
    end;
    
    Consume(ttSemicolon, 'Expected ";"');
  end;
  
  Result := LVarDecl;
end;

function TELParser.ParseFunctionDeclaration(): TELASTNode;
var
  LFuncDecl: TELASTNode;
  LHeader: TELASTNode;
  LBlock: TELASTNode;
  LExternalNode: TELASTNode;
begin
  LFuncDecl := TELASTNode.Create(astFunctionDecl);
  
  LHeader := ParseFunctionHeader();
  LFuncDecl.AddChild(LHeader);
  
  // Check for external declaration: "external" STRING_LITERAL ";"
  if Check(ttExternal) then
  begin
    AdvanceToken(); // consume "external"
    LExternalNode := TELASTNode.Create(astLiteral, FCurrentToken.Value);
    Consume(ttStringLiteral, 'Expected library name');
    LFuncDecl.AddChild(LExternalNode);
    Consume(ttSemicolon, 'Expected ";"');
  end
  else
  begin
    // Regular function with body
    LBlock := ParseStatementBlock();
    LFuncDecl.AddChild(LBlock);
  end;
  
  Result := LFuncDecl;
end;

function TELParser.ParseTypeDeclaration(): TELASTNode;
var
  LTypeDecl: TELASTNode;
  LTypeSpec: TELASTNode;
begin
  LTypeDecl := TELASTNode.Create(astTypeDecl);
  
  Consume(ttType, 'Expected "type"');
  LTypeDecl.AddChild(TELASTNode.Create(astIdentifier, FCurrentToken.Value));
  Consume(ttIdentifier, 'Expected identifier');
  Consume(ttEqual, 'Expected "="');
  
  LTypeSpec := ParseTypeSpec();
  LTypeDecl.AddChild(LTypeSpec);
  
  Consume(ttSemicolon, 'Expected ";"');
  
  Result := LTypeDecl;
end;

function TELParser.ParseFunctionHeader(): TELASTNode;
var
  LHeader: TELASTNode;
  LParams: TELASTNode;
  LReturnType: TELASTNode;
begin
  LHeader := TELASTNode.Create(astFunctionDecl);
  
  if Match(ttFunction) then
    LHeader.Value := 'function'
  else if Match(ttProcedure) then
    LHeader.Value := 'procedure'
  else
    raise EELException.Create('Expected "function" or "procedure"', [], 
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
    
  // Handle function name (could be identifier or special 'main' keyword)
  if FCurrentToken.TokenType = ttMain then
  begin
    LHeader.AddChild(TELASTNode.Create(astIdentifier, 'main'));
    AdvanceToken();
  end
  else
  begin
    LHeader.AddChild(TELASTNode.Create(astIdentifier, FCurrentToken.Value));
    Consume(ttIdentifier, 'Expected function name');
  end;
  
  LParams := ParseParameterList();
  LHeader.AddChild(LParams);
  
  if LHeader.Value = 'function' then
  begin
    Consume(ttColon, 'Expected ":"');
    LReturnType := ParseTypeSpec();
    LHeader.AddChild(LReturnType);
  end;
  
  Result := LHeader;
end;

function TELParser.ParseParameterList(): TELASTNode;
var
  LParams: TELASTNode;
  LParam: TELASTNode;
  LEllipsis: TELASTNode;
begin
  LParams := TELASTNode.Create(astParameterList);
  
  Consume(ttLeftParen, 'Expected "("');
  
  if not Check(ttRightParen) then
  begin
    // Check for standalone ellipsis: "..."
    if Check(ttEllipsis) then
    begin
      LEllipsis := TELASTNode.Create(astParameterList, '...');
      AdvanceToken();
      LParams.AddChild(LEllipsis);
    end
    else
    begin
      // Parse regular parameters: param_def ("," param_def)* ("," "...")?
      repeat
        LParam := ParseParamDef();
        LParams.AddChild(LParam);
        
        if Match(ttComma) then
        begin
          // Check if next token is ellipsis
          if Check(ttEllipsis) then
          begin
            LEllipsis := TELASTNode.Create(astParameterList, '...');
            AdvanceToken();
            LParams.AddChild(LEllipsis);
            Break; // End parameter list after ellipsis
          end;
          // Continue loop to parse next parameter
        end
        else
          Break; // No comma, end of parameter list
      until False;
    end;
  end;
  
  Consume(ttRightParen, 'Expected ")"');
  
  Result := LParams;
end;

function TELParser.ParseParamDef(): TELASTNode;
var
  LParam: TELASTNode;
  LTypeSpec: TELASTNode;
begin
  LParam := TELASTNode.Create(astParameterList);
  
  // Optional parameter modifier
  if Check(ttRef) or Check(ttConst) then
  begin
    LParam.Value := FCurrentToken.Value;
    AdvanceToken();
  end;
  
  // identifier_list
  repeat
    LParam.AddChild(TELASTNode.Create(astIdentifier, FCurrentToken.Value));
    Consume(ttIdentifier, 'Expected parameter name');
  until not Match(ttComma);
  
  Consume(ttColon, 'Expected ":"');
  
  LTypeSpec := ParseTypeSpec();
  LParam.AddChild(LTypeSpec);
  
  Result := LParam;
end;

function TELParser.ParseTypeSpec(): TELASTNode;
begin
  case FCurrentToken.TokenType of
    ttInt, ttChar, ttBool, ttFloat, ttDouble,
    ttInt8, ttInt16, ttInt32, ttInt64,
    ttUInt8, ttUInt16, ttUInt32, ttUInt64:
      Result := ParseBasicType();
    ttPower: // ^
      Result := ParsePointerType();
    ttArray:
      Result := ParseArrayType();
    ttRecord:
      Result := ParseRecordType();
    ttIdentifier:
      begin
        Result := TELASTNode.Create(astTypeSpec, FCurrentToken.Value);
        AdvanceToken();
      end;
  else
    raise EELException.Create('Expected type specification', [], 
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
  end;
end;

function TELParser.ParseBasicType(): TELASTNode;
begin
  Result := TELASTNode.Create(astTypeSpec, FCurrentToken.Value);
  AdvanceToken();
end;

function TELParser.ParsePointerType(): TELASTNode;
var
  LPointer: TELASTNode;
  LTargetType: TELASTNode;
begin
  LPointer := TELASTNode.Create(astTypeSpec, '^');
  Consume(ttPower, 'Expected "^"');
  
  LTargetType := ParseTypeSpec();
  LPointer.AddChild(LTargetType);
  
  Result := LPointer;
end;

function TELParser.ParseArrayType(): TELASTNode;
var
  LArray: TELASTNode;
  LSize: TELASTNode;
  LElementType: TELASTNode;
begin
  LArray := TELASTNode.Create(astTypeSpec, 'array');
  Consume(ttArray, 'Expected "array"');
  Consume(ttLeftBracket, 'Expected "["');
  
  if not Check(ttRightBracket) then
  begin
    LSize := ParseExpression();
    LArray.AddChild(LSize);
  end;
  
  Consume(ttRightBracket, 'Expected "]"');
  Consume(ttOf, 'Expected "of"');
  
  LElementType := ParseTypeSpec();
  LArray.AddChild(LElementType);
  
  Result := LArray;
end;

function TELParser.ParseRecordType(): TELASTNode;
var
  LRecord: TELASTNode;
  LField: TELASTNode;
  LFieldType: TELASTNode;
begin
  LRecord := TELASTNode.Create(astTypeSpec, 'record');
  Consume(ttRecord, 'Expected "record"');
  
  // field_list
  while not Check(ttEnd) do
  begin
    // field_def: identifier_list : type_spec
    LField := TELASTNode.Create(astVariableDecl);
    
    repeat
      LField.AddChild(TELASTNode.Create(astIdentifier, FCurrentToken.Value));
      Consume(ttIdentifier, 'Expected field name');
    until not Match(ttComma);
    
    Consume(ttColon, 'Expected ":"');
    
    LFieldType := ParseTypeSpec();
    LField.AddChild(LFieldType);
    
    LRecord.AddChild(LField);
    
    if not Match(ttSemicolon) then
      Break;
  end;
  
  Consume(ttEnd, 'Expected "end"');
  
  Result := LRecord;
end;

function TELParser.ParseStatement(): TELASTNode;
begin
  case FCurrentToken.TokenType of
    ttBegin:
      Result := ParseStatementBlock();
    ttIf:
      Result := ParseIfStatement();
    ttWhile:
      Result := ParseWhileStatement();
    ttFor:
      Result := ParseForStatement();
    ttRepeat:
      Result := ParseRepeatStatement();
    ttCase:
      Result := ParseCaseStatement();
    ttReturn:
      Result := ParseReturnStatement();
    ttBreak:
      begin
        Result := TELASTNode.Create(astBreakStatement);
        AdvanceToken();
        Consume(ttSemicolon, 'Expected ";"');
      end;
    ttContinue:
      begin
        Result := TELASTNode.Create(astContinueStatement);
        AdvanceToken();
        Consume(ttSemicolon, 'Expected ";"');
      end;
    ttGoto:
      begin
        Result := TELASTNode.Create(astGotoStatement);
        AdvanceToken();
        Result.AddChild(TELASTNode.Create(astIdentifier, FCurrentToken.Value));
        Consume(ttIdentifier, 'Expected label');
        Consume(ttSemicolon, 'Expected ";"');
      end;
    ttVar, ttConst:
      Result := ParseVariableDeclaration();
  else
    // Could be assignment or function call
    if (FCurrentToken.TokenType = ttIdentifier) and (PeekToken().TokenType = ttAssign) then
      Result := ParseAssignmentStatement()
    else
    begin
      Result := ParseCallStatement();
    end;
  end;
end;

function TELParser.ParseStatementBlock(): TELASTNode;
var
  LBlock: TELASTNode;
  LStatementList: TELASTNode;
begin
  LBlock := TELASTNode.Create(astStatementBlock);
  
  Consume(ttBegin, 'Expected "begin"');
  
  LStatementList := ParseStatementList();
  LBlock.AddChild(LStatementList);
  
  Consume(ttEnd, 'Expected "end"');
  
  Result := LBlock;
end;

function TELParser.ParseStatementList(): TELASTNode;
var
  LStatementList: TELASTNode;
  LStatement: TELASTNode;
begin
  LStatementList := TELASTNode.Create(astStatementBlock);
  
  while not Check(ttEnd) and not Check(ttElse) and not Check(ttUntil) and not IsAtEnd() do
  begin
    // Check if we've hit potential case labels for case statements
    if (FCurrentToken.TokenType in [ttIntegerLiteral, ttIdentifier, ttCharLiteral]) then
    begin
      // Look ahead to see if this might be a case label
      if (FCurrentIndex + 1 < Length(FTokens)) and 
         (FTokens[FCurrentIndex + 1].TokenType in [ttColon, ttComma, ttRange]) then
        Break; // This looks like a case label, stop parsing statements
    end;
    
    LStatement := ParseStatement();
    if Assigned(LStatement) then
      LStatementList.AddChild(LStatement);
  end;
  
  Result := LStatementList;
end;

function TELParser.ParseAssignmentStatement(): TELASTNode;
var
  LAssign: TELASTNode;
  LLValue: TELASTNode;
  LExpression: TELASTNode;
begin
  LAssign := TELASTNode.Create(astAssignment);
  
  LLValue := ParseLValue();
  LAssign.AddChild(LLValue);
  
  Consume(ttAssign, 'Expected ":="');
  
  LExpression := ParseExpression();
  LAssign.AddChild(LExpression);
  
  Consume(ttSemicolon, 'Expected ";"');
  
  Result := LAssign;
end;

function TELParser.ParseIfStatement(): TELASTNode;
var
  LIf: TELASTNode;
  LCondition: TELASTNode;
  LThenStmt: TELASTNode;
  LElseStmt: TELASTNode;
begin
  LIf := TELASTNode.Create(astIfStatement);
  
  Consume(ttIf, 'Expected "if"');
  
  LCondition := ParseExpression();
  LIf.AddChild(LCondition);
  
  Consume(ttThen, 'Expected "then"');
  
  LThenStmt := ParseStatement();
  LIf.AddChild(LThenStmt);
  
  if Match(ttElse) then
  begin
    LElseStmt := ParseStatement();
    LIf.AddChild(LElseStmt);
  end;
  
  Result := LIf;
end;

function TELParser.ParseWhileStatement(): TELASTNode;
var
  LWhile: TELASTNode;
  LCondition: TELASTNode;
  LStatement: TELASTNode;
begin
  LWhile := TELASTNode.Create(astWhileStatement);
  
  Consume(ttWhile, 'Expected "while"');
  
  LCondition := ParseExpression();
  LWhile.AddChild(LCondition);
  
  Consume(ttDo, 'Expected "do"');
  
  LStatement := ParseStatement();
  LWhile.AddChild(LStatement);
  
  Result := LWhile;
end;

function TELParser.ParseForStatement(): TELASTNode;
var
  LFor: TELASTNode;
  LVariable: TELASTNode;
  LStartExpr: TELASTNode;
  LEndExpr: TELASTNode;
  LStatement: TELASTNode;
begin
  LFor := TELASTNode.Create(astForStatement);
  
  Consume(ttFor, 'Expected "for"');
  
  LVariable := TELASTNode.Create(astIdentifier, FCurrentToken.Value);
  Consume(ttIdentifier, 'Expected loop variable');
  LFor.AddChild(LVariable);
  
  Consume(ttAssign, 'Expected ":="');
  
  LStartExpr := ParseExpression();
  LFor.AddChild(LStartExpr);
  
  if Match(ttTo) then
    LFor.Value := 'to'
  else if Match(ttDownto) then
    LFor.Value := 'downto'
  else
    raise EELException.Create('Expected "to" or "downto"', [], 
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
    
  LEndExpr := ParseExpression();
  LFor.AddChild(LEndExpr);
  
  Consume(ttDo, 'Expected "do"');
  
  LStatement := ParseStatement();
  LFor.AddChild(LStatement);
  
  Result := LFor;
end;

function TELParser.ParseRepeatStatement(): TELASTNode;
var
  LRepeat: TELASTNode;
  LStatementList: TELASTNode;
  LCondition: TELASTNode;
begin
  LRepeat := TELASTNode.Create(astRepeatStatement);
  
  Consume(ttRepeat, 'Expected "repeat"');
  
  LStatementList := ParseStatementList();
  LRepeat.AddChild(LStatementList);
  
  Consume(ttUntil, 'Expected "until"');
  
  LCondition := ParseExpression();
  LRepeat.AddChild(LCondition);
  
  Result := LRepeat;
end;

function TELParser.ParseCaseStatement(): TELASTNode;
var
  LCase: TELASTNode;
  LExpression: TELASTNode;
  LCaseItem: TELASTNode;
  LElseClause: TELASTNode;
begin
  LCase := TELASTNode.Create(astCaseStatement);
  
  Consume(ttCase, 'Expected "case"');
  
  LExpression := ParseExpression();
  LCase.AddChild(LExpression);
  
  Consume(ttOf, 'Expected "of"');
  
  // Parse case items
  while not Check(ttEnd) and not Check(ttElse) and not IsAtEnd() do
  begin
    LCaseItem := ParseCaseItem();
    if Assigned(LCaseItem) then
      LCase.AddChild(LCaseItem);
  end;
  
  // Parse optional else clause
  if Match(ttElse) then
  begin
    LElseClause := TELASTNode.Create(astStatementBlock, 'else');
    LElseClause.AddChild(ParseStatementList());
    LCase.AddChild(LElseClause);
  end;
  
  Consume(ttEnd, 'Expected "end"');
  
  Result := LCase;
end;

function TELParser.ParseCaseItem(): TELASTNode;
var
  LCaseItem: TELASTNode;
  LCaseLabels: TELASTNode;
  LStatementList: TELASTNode;
begin
  LCaseItem := TELASTNode.Create(astCaseStatement); // Reusing same type for case items
  
  // Parse case labels
  LCaseLabels := ParseCaseLabels();
  LCaseItem.AddChild(LCaseLabels);
  
  Consume(ttColon, 'Expected ":"');
  
  // Parse statement list according to BNF: case_item ::= case_labels ":" statement_list
  LStatementList := ParseStatementList();
  LCaseItem.AddChild(LStatementList);
  
  Result := LCaseItem;
end;

function TELParser.ParseCaseLabels(): TELASTNode;
var
  LLabels: TELASTNode;
  LLabel: TELASTNode;
  LRangeEnd: TELASTNode;
  LRange: TELASTNode;
begin
  LLabels := TELASTNode.Create(astExpression); // Container for case labels
  
  repeat
    // Parse case label (expression or range)
    LLabel := ParseExpression();
    
    // Check for range (..) 
    if Match(ttRange) then
    begin
      LRangeEnd := ParseExpression();
      // Create a range node
      LRange := TELASTNode.Create(astBinaryOp, '..');
      LRange.AddChild(LLabel);
      LRange.AddChild(LRangeEnd);
      LLabels.AddChild(LRange);
    end
    else
      LLabels.AddChild(LLabel);
      
  until not Match(ttComma);
  
  Result := LLabels;
end;

function TELParser.ParseReturnStatement(): TELASTNode;
var
  LReturn: TELASTNode;
  LExpression: TELASTNode;
begin
  LReturn := TELASTNode.Create(astReturnStatement);
  
  Consume(ttReturn, 'Expected "return"');
  
  if not Check(ttSemicolon) then
  begin
    LExpression := ParseExpression();
    LReturn.AddChild(LExpression);
  end;
  
  Consume(ttSemicolon, 'Expected ";"');
  
  Result := LReturn;
end;

function TELParser.ParseCallStatement(): TELASTNode;
var
  LCall: TELASTNode;
begin
  LCall := TELASTNode.Create(astCallStatement);
  
  LCall.AddChild(ParseExpression());
  
  Consume(ttSemicolon, 'Expected ";"');
  
  Result := LCall;
end;

function TELParser.ParseExpression(): TELASTNode;
begin
  Result := ParseConditionalExpression();
end;

function TELParser.ParseConditionalExpression(): TELASTNode;
var
  LExpr: TELASTNode;
  LThen: TELASTNode;
  LElse: TELASTNode;
  LTernary: TELASTNode;
begin
  LExpr := ParseLogicalOrExpression();
  
  if Match(ttQuestion) then
  begin
    LTernary := TELASTNode.Create(astBinaryOp, '?:');
    LTernary.AddChild(LExpr);
    
    LThen := ParseExpression();
    LTernary.AddChild(LThen);
    
    Consume(ttColon, 'Expected ":"');
    
    LElse := ParseConditionalExpression();
    LTernary.AddChild(LElse);
    
    Result := LTernary;
  end
  else
    Result := LExpr;
end;

function TELParser.ParseLogicalOrExpression(): TELASTNode;
var
  LLeft: TELASTNode;
  LRight: TELASTNode;
  LBinOp: TELASTNode;
begin
  LLeft := ParseLogicalAndExpression();
  
  while Match(ttOr) do
  begin
    LBinOp := TELASTNode.Create(astBinaryOp, 'or');
    LBinOp.AddChild(LLeft);
    
    LRight := ParseLogicalAndExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TELParser.ParseLogicalAndExpression(): TELASTNode;
var
  LLeft: TELASTNode;
  LRight: TELASTNode;
  LBinOp: TELASTNode;
begin
  LLeft := ParseEqualityExpression();
  
  while Match(ttAnd) do
  begin
    LBinOp := TELASTNode.Create(astBinaryOp, 'and');
    LBinOp.AddChild(LLeft);
    
    LRight := ParseEqualityExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TELParser.ParseEqualityExpression(): TELASTNode;
var
  LLeft: TELASTNode;
  LRight: TELASTNode;
  LBinOp: TELASTNode;
  LOperator: string;
begin
  LLeft := ParseRelationalExpression();
  
  while Check(ttEqual) or Check(ttNotEqual) do
  begin
    LOperator := FCurrentToken.Value;
    AdvanceToken();
    
    LBinOp := TELASTNode.Create(astBinaryOp, LOperator);
    LBinOp.AddChild(LLeft);
    
    LRight := ParseRelationalExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TELParser.ParseRelationalExpression(): TELASTNode;
var
  LLeft: TELASTNode;
  LRight: TELASTNode;
  LBinOp: TELASTNode;
  LOperator: string;
begin
  LLeft := ParseAdditiveExpression();
  
  while Check(ttLess) or Check(ttGreater) or Check(ttLessEqual) or Check(ttGreaterEqual) do
  begin
    LOperator := FCurrentToken.Value;
    AdvanceToken();
    
    LBinOp := TELASTNode.Create(astBinaryOp, LOperator);
    LBinOp.AddChild(LLeft);
    
    LRight := ParseAdditiveExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TELParser.ParseAdditiveExpression(): TELASTNode;
var
  LLeft: TELASTNode;
  LRight: TELASTNode;
  LBinOp: TELASTNode;
  LOperator: string;
begin
  LLeft := ParseMultiplicativeExpression();
  
  while Check(ttPlus) or Check(ttMinus) do
  begin
    LOperator := FCurrentToken.Value;
    AdvanceToken();
    
    LBinOp := TELASTNode.Create(astBinaryOp, LOperator);
    LBinOp.AddChild(LLeft);
    
    LRight := ParseMultiplicativeExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TELParser.ParseMultiplicativeExpression(): TELASTNode;
var
  LLeft: TELASTNode;
  LRight: TELASTNode;
  LBinOp: TELASTNode;
  LOperator: string;
begin
  LLeft := ParseUnaryExpression();
  
  while Check(ttMultiply) or Check(ttDivide) or Check(ttDiv) or Check(ttMod) do
  begin
    LOperator := FCurrentToken.Value;
    AdvanceToken();
    
    LBinOp := TELASTNode.Create(astBinaryOp, LOperator);
    LBinOp.AddChild(LLeft);
    
    LRight := ParseUnaryExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TELParser.ParseUnaryExpression(): TELASTNode;
var
  LUnary: TELASTNode;
  LOperator: string;
  LOperand: TELASTNode;
begin
  if Check(ttPlus) or Check(ttMinus) or Check(ttNot) or Check(ttAddressOf) or Check(ttPower) then
  begin
    LOperator := FCurrentToken.Value;
    AdvanceToken();
    
    LUnary := TELASTNode.Create(astUnaryOp, LOperator);
    LOperand := ParseUnaryExpression();
    LUnary.AddChild(LOperand);
    
    Result := LUnary;
  end
  else if Check(ttSizeof) then
  begin
    AdvanceToken();
    Consume(ttLeftParen, 'Expected "("');
    
    LUnary := TELASTNode.Create(astUnaryOp, 'sizeof');
    LOperand := ParseTypeSpec();
    LUnary.AddChild(LOperand);
    
    Consume(ttRightParen, 'Expected ")"');
    
    Result := LUnary;
  end
  else
    Result := ParsePostfixExpression();
end;

function TELParser.ParsePostfixExpression(): TELASTNode;
var
  LExpr: TELASTNode;
  LAccess: TELASTNode;
  LIndex: TELASTNode;
  LArgs: TELASTNode;
  LMember: TELASTNode;
begin
  LExpr := ParsePrimaryExpression();
  
  while True do
  begin
    if Match(ttLeftBracket) then
    begin
      // Array access
      LAccess := TELASTNode.Create(astArrayAccess);
      LAccess.AddChild(LExpr);
      
      LIndex := ParseExpression();
      LAccess.AddChild(LIndex);
      
      Consume(ttRightBracket, 'Expected "]"');
      
      LExpr := LAccess;
    end
    else if Match(ttLeftParen) then
    begin
      // Function call
      LAccess := TELASTNode.Create(astFunctionCall);
      LAccess.AddChild(LExpr);
      
      if not Check(ttRightParen) then
      begin
        LArgs := ParseArgumentList();
        LAccess.AddChild(LArgs);
      end;
      
      Consume(ttRightParen, 'Expected ")"');
      
      LExpr := LAccess;
    end
    else if Match(ttDot) then
    begin
      // Member access
      LAccess := TELASTNode.Create(astMemberAccess);
      LAccess.AddChild(LExpr);
      
      LMember := TELASTNode.Create(astIdentifier, FCurrentToken.Value);
      Consume(ttIdentifier, 'Expected member name');
      LAccess.AddChild(LMember);
      
      LExpr := LAccess;
    end
    else if Match(ttPower) then
    begin
      // Pointer dereference
      LAccess := TELASTNode.Create(astUnaryOp, '^');
      LAccess.AddChild(LExpr);
      
      LExpr := LAccess;
    end
    else
      Break;
  end;
  
  Result := LExpr;
end;

function TELParser.ParsePrimaryExpression(): TELASTNode;
begin
  case FCurrentToken.TokenType of
    ttIdentifier:
      begin
        Result := TELASTNode.Create(astIdentifier, FCurrentToken.Value);
        AdvanceToken();
      end;
    ttIntegerLiteral, ttRealLiteral, ttCharLiteral, ttStringLiteral, ttTrue, ttFalse:
      begin
        Result := TELASTNode.Create(astLiteral, FCurrentToken.Value);
        AdvanceToken();
      end;
    ttLeftParen:
      begin
        AdvanceToken();
        Result := ParseExpression();
        Consume(ttRightParen, 'Expected ")"');
      end;
  else
    raise EELException.Create('Expected primary expression', [], 
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
  end;
end;

function TELParser.ParseArgumentList(): TELASTNode;
var
  LArgs: TELASTNode;
  LArg: TELASTNode;
begin
  LArgs := TELASTNode.Create(astArgumentList);
  
  repeat
    LArg := ParseExpression();
    LArgs.AddChild(LArg);
  until not Match(ttComma);
  
  Result := LArgs;
end;

function TELParser.ParseLValue(): TELASTNode;
var
  LValue: TELASTNode;
  LAccess: TELASTNode;
  LIndex: TELASTNode;
  LMember: TELASTNode;
begin
  case FCurrentToken.TokenType of
    ttIdentifier:
      begin
        LValue := TELASTNode.Create(astIdentifier, FCurrentToken.Value);
        AdvanceToken();
      end;
    ttLeftParen:
      begin
        AdvanceToken();
        LValue := ParseLValue();
        Consume(ttRightParen, 'Expected ")"');
      end;
  else
    raise EELException.Create('Expected lvalue', [], 
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
  end;
  
  // Handle postfix operators for lvalue
  while True do
  begin
    if Match(ttLeftBracket) then
    begin
      LAccess := TELASTNode.Create(astArrayAccess);
      LAccess.AddChild(LValue);
      
      LIndex := ParseExpression();
      LAccess.AddChild(LIndex);
      
      Consume(ttRightBracket, 'Expected "]"');
      
      LValue := LAccess;
    end
    else if Match(ttDot) then
    begin
      LAccess := TELASTNode.Create(astMemberAccess);
      LAccess.AddChild(LValue);
      
      LMember := TELASTNode.Create(astIdentifier, FCurrentToken.Value);
      Consume(ttIdentifier, 'Expected member name');
      LAccess.AddChild(LMember);
      
      LValue := LAccess;
    end
    else if Match(ttPower) then
    begin
      LAccess := TELASTNode.Create(astUnaryOp, '^');
      LAccess.AddChild(LValue);
      
      LValue := LAccess;
    end
    else
      Break;
  end;
  
  Result := LValue;
end;

end.

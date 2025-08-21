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

unit CPLang.Parser;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  CPLang.Common,
  CPLang.Lexer,
  CPLang.Errors;

type
  { TCPASTNodeType }
  TCPASTNodeType = (
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

  { TCPASTNode }
  TCPASTNode = class
  private
    FNodeType: TCPASTNodeType;
    FValue: string;
    FPosition: Integer;
    FChildren: TObjectList<TCPASTNode>;
    
  public
    constructor Create(const ANodeType: TCPASTNodeType; const AValue: string = '');
    destructor Destroy(); override;
    
    procedure AddChild(const AChild: TCPASTNode);
    function GetChild(const AIndex: Integer): TCPASTNode;
    function ChildCount(): Integer;
    
    property NodeType: TCPASTNodeType read FNodeType;
    property Value: string read FValue write FValue;
    property Position: Integer read FPosition write FPosition;
  end;

  { TCPParser }
  TCPParser = class
  private
    FTokens: TArray<TCPToken>;
    FCurrentIndex: Integer;
    FCurrentToken: TCPToken;
    
    procedure AdvanceToken();
    function PeekToken(const AOffset: Integer = 1): TCPToken;
    function IsAtEnd(): Boolean;
    function Match(const ATokenType: TCPTokenType): Boolean;
    function Consume(const ATokenType: TCPTokenType; const AMessage: string): TCPToken;
    function Check(const ATokenType: TCPTokenType): Boolean;
    
    // Helper methods for creating positioned AST nodes
    function CreatePositionedNode(const ANodeType: TCPASTNodeType; const AValue: string = ''): TCPASTNode;
    function CreateIdentifierNode(const AValue: string): TCPASTNode;
    function CreateLiteralNode(const AValue: string): TCPASTNode;
    
    // Grammar rules - direct from BNF
    function ParseProgram(): TCPASTNode;
    function ParseMainFunction(): TCPASTNode;
    function ParseDeclaration(): TCPASTNode;
    function ParseVariableDeclaration(): TCPASTNode;
    function ParseFunctionDeclaration(): TCPASTNode;
    function ParseTypeDeclaration(): TCPASTNode;
    function ParseFunctionHeader(): TCPASTNode;
    function ParseParameterList(): TCPASTNode;
    function ParseParamDef(): TCPASTNode;
    function ParseTypeSpec(): TCPASTNode;
    function ParseBasicType(): TCPASTNode;
    function ParsePointerType(): TCPASTNode;
    function ParseArrayType(): TCPASTNode;
    function ParseRecordType(): TCPASTNode;
    function ParseStatement(): TCPASTNode;
    function ParseStatementBlock(): TCPASTNode;
    function ParseStatementList(): TCPASTNode;
    function ParseAssignmentStatement(): TCPASTNode;
    function ParseIfStatement(): TCPASTNode;
    function ParseWhileStatement(): TCPASTNode;
    function ParseForStatement(): TCPASTNode;
    function ParseRepeatStatement(): TCPASTNode;
    function ParseCaseStatement(): TCPASTNode;
    function ParseReturnStatement(): TCPASTNode;
    function ParseCallStatement(): TCPASTNode;
    function ParseCaseItem(): TCPASTNode;
    function ParseCaseLabels(): TCPASTNode;
    function ParseExpression(): TCPASTNode;
    function ParseConditionalExpression(): TCPASTNode;
    function ParseLogicalOrExpression(): TCPASTNode;
    function ParseLogicalAndExpression(): TCPASTNode;
    function ParseEqualityExpression(): TCPASTNode;
    function ParseRelationalExpression(): TCPASTNode;
    function ParseAdditiveExpression(): TCPASTNode;
    function ParseMultiplicativeExpression(): TCPASTNode;
    function ParseUnaryExpression(): TCPASTNode;
    function ParsePostfixExpression(): TCPASTNode;
    function ParsePrimaryExpression(): TCPASTNode;
    function ParseArgumentList(): TCPASTNode;
    function ParseLValue(): TCPASTNode;
    
  public
    constructor Create();
    destructor Destroy(); override;
    
    function Parse(const ATokens: TArray<TCPToken>): TCPASTNode;
  end;

implementation

{ TCPASTNode }
constructor TCPASTNode.Create(const ANodeType: TCPASTNodeType; const AValue: string);
begin
  inherited Create();
  FNodeType := ANodeType;
  FValue := AValue;
  FPosition := 0;
  FChildren := TObjectList<TCPASTNode>.Create(True);
end;

destructor TCPASTNode.Destroy();
begin
  FChildren.Free();
  inherited;
end;

procedure TCPASTNode.AddChild(const AChild: TCPASTNode);
begin
  if Assigned(AChild) then
    FChildren.Add(AChild);
end;

function TCPASTNode.GetChild(const AIndex: Integer): TCPASTNode;
begin
  if (AIndex >= 0) and (AIndex < FChildren.Count) then
    Result := FChildren[AIndex]
  else
    Result := nil;
end;

function TCPASTNode.ChildCount(): Integer;
begin
  Result := FChildren.Count;
end;

{ TCPParser }
constructor TCPParser.Create();
begin
  inherited;
  SetLength(FTokens, 0);
  FCurrentIndex := 0;
  FCurrentToken.TokenType := ttEOF;
end;

destructor TCPParser.Destroy();
begin
  inherited;
end;

function TCPParser.Parse(const ATokens: TArray<TCPToken>): TCPASTNode;
begin
  FTokens := ATokens;
  FCurrentIndex := 0;
  if Length(FTokens) > 0 then
    FCurrentToken := FTokens[0]
  else
    FCurrentToken.TokenType := ttEOF;
    
  Result := ParseProgram();
end;

procedure TCPParser.AdvanceToken();
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

function TCPParser.PeekToken(const AOffset: Integer): TCPToken;
var
  LIndex: Integer;
begin
  LIndex := FCurrentIndex + AOffset;
  if LIndex < Length(FTokens) then
    Result := FTokens[LIndex]
  else
    Result.TokenType := ttEOF;
end;

function TCPParser.IsAtEnd(): Boolean;
begin
  Result := FCurrentToken.TokenType = ttEOF;
end;

function TCPParser.Match(const ATokenType: TCPTokenType): Boolean;
begin
  if Check(ATokenType) then
  begin
    AdvanceToken();
    Result := True;
  end
  else
    Result := False;
end;

function TCPParser.Consume(const ATokenType: TCPTokenType; const AMessage: string): TCPToken;
begin
  if Check(ATokenType) then
  begin
    Result := FCurrentToken;
    AdvanceToken();
  end
  else
    raise ECPException.Create('Parse error: %s. Got %s', [AMessage, FCurrentToken.Value],
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
end;

function TCPParser.Check(const ATokenType: TCPTokenType): Boolean;
begin
  if IsAtEnd() then
    Result := False
  else
    Result := FCurrentToken.TokenType = ATokenType;
end;

function TCPParser.CreatePositionedNode(const ANodeType: TCPASTNodeType; const AValue: string): TCPASTNode;
begin
  Result := TCPASTNode.Create(ANodeType, AValue);
  Result.Position := FCurrentToken.SourcePos.CharIndex;
end;

function TCPParser.CreateIdentifierNode(const AValue: string): TCPASTNode;
begin
  Result := TCPASTNode.Create(astIdentifier, AValue);
  Result.Position := FCurrentToken.SourcePos.CharIndex;
end;

function TCPParser.CreateLiteralNode(const AValue: string): TCPASTNode;
begin
  Result := TCPASTNode.Create(astLiteral, AValue);
  Result.Position := FCurrentToken.SourcePos.CharIndex;
end;

function TCPParser.ParseProgram(): TCPASTNode;
var
  LProgram: TCPASTNode;
  LDeclaration: TCPASTNode;
begin
  LProgram := TCPASTNode.Create(astProgram);
  
  // Parse all declarations and functions in any order
  while not IsAtEnd() do
  begin
    LDeclaration := ParseDeclaration();
    if Assigned(LDeclaration) then
      LProgram.AddChild(LDeclaration);
  end;
  
  Result := LProgram;
end;

function TCPParser.ParseMainFunction(): TCPASTNode;
var
  LMainFunc: TCPASTNode;
  LHeader: TCPASTNode;
  LBlock: TCPASTNode;
begin
  LMainFunc := TCPASTNode.Create(astMainFunction);
  
  LHeader := ParseFunctionHeader();
  LMainFunc.AddChild(LHeader);
  
  LBlock := ParseStatementBlock();
  LMainFunc.AddChild(LBlock);
  
  Result := LMainFunc;
end;

function TCPParser.ParseDeclaration(): TCPASTNode;
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

function TCPParser.ParseVariableDeclaration(): TCPASTNode;
var
  LVarDecl: TCPASTNode;
  LTypeSpec: TCPASTNode;
begin
  LVarDecl := TCPASTNode.Create(astVariableDecl);
  
  if Match(ttVar) or Match(ttConst) then
  begin
    // identifier_list
    repeat
      LVarDecl.AddChild(CreateIdentifierNode(FCurrentToken.Value));
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

function TCPParser.ParseFunctionDeclaration(): TCPASTNode;
var
  LFuncDecl: TCPASTNode;
  LHeader: TCPASTNode;
  LBlock: TCPASTNode;
  LExternalNode: TCPASTNode;
begin
  LFuncDecl := TCPASTNode.Create(astFunctionDecl);
  
  LHeader := ParseFunctionHeader();
  LFuncDecl.AddChild(LHeader);
  
  // Check for external declaration: "external" STRING_LITERAL ";"
  if Check(ttExternal) then
  begin
    AdvanceToken(); // consume "external"
    LExternalNode := CreateLiteralNode(FCurrentToken.Value);
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

function TCPParser.ParseTypeDeclaration(): TCPASTNode;
var
  LTypeDecl: TCPASTNode;
  LTypeSpec: TCPASTNode;
begin
  LTypeDecl := TCPASTNode.Create(astTypeDecl);
  
  Consume(ttType, 'Expected "type"');
  LTypeDecl.AddChild(CreateIdentifierNode(FCurrentToken.Value));
  Consume(ttIdentifier, 'Expected identifier');
  Consume(ttEqual, 'Expected "="');
  
  LTypeSpec := ParseTypeSpec();
  LTypeDecl.AddChild(LTypeSpec);
  
  Consume(ttSemicolon, 'Expected ";"');
  
  Result := LTypeDecl;
end;

function TCPParser.ParseFunctionHeader(): TCPASTNode;
var
  LHeader: TCPASTNode;
  LParams: TCPASTNode;
  LReturnType: TCPASTNode;
begin
  LHeader := TCPASTNode.Create(astFunctionDecl);
  
  if Match(ttFunction) then
    LHeader.Value := 'function'
  else if Match(ttProcedure) then
    LHeader.Value := 'procedure'
  else
    raise ECPException.Create('Expected "function" or "procedure"', [],
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
    
  // Handle function name (could be identifier or special 'main' keyword)
  if FCurrentToken.TokenType = ttMain then
  begin
    LHeader.AddChild(CreateIdentifierNode('main'));
    AdvanceToken();
  end
  else
  begin
    LHeader.AddChild(CreateIdentifierNode(FCurrentToken.Value));
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

function TCPParser.ParseParameterList(): TCPASTNode;
var
  LParams: TCPASTNode;
  LParam: TCPASTNode;
  LEllipsis: TCPASTNode;
begin
  LParams := TCPASTNode.Create(astParameterList);
  
  Consume(ttLeftParen, 'Expected "("');
  
  if not Check(ttRightParen) then
  begin
    // Check for standalone ellipsis: "..."
    if Check(ttEllipsis) then
    begin
      LEllipsis := TCPASTNode.Create(astParameterList, '...');
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
            LEllipsis := TCPASTNode.Create(astParameterList, '...');
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

function TCPParser.ParseParamDef(): TCPASTNode;
var
  LParam: TCPASTNode;
  LTypeSpec: TCPASTNode;
begin
  LParam := TCPASTNode.Create(astParameterList);
  
  // Optional parameter modifier
  if Check(ttRef) or Check(ttConst) then
  begin
    LParam.Value := FCurrentToken.Value;
    AdvanceToken();
  end;
  
  // identifier_list
  repeat
    LParam.AddChild(CreateIdentifierNode(FCurrentToken.Value));
    Consume(ttIdentifier, 'Expected parameter name');
  until not Match(ttComma);
  
  Consume(ttColon, 'Expected ":"');
  
  LTypeSpec := ParseTypeSpec();
  LParam.AddChild(LTypeSpec);
  
  Result := LParam;
end;

function TCPParser.ParseTypeSpec(): TCPASTNode;
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
        Result := CreatePositionedNode(astTypeSpec, FCurrentToken.Value);
        AdvanceToken();
      end;
  else
    raise ECPException.Create('Expected type specification', [],
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
  end;
end;

function TCPParser.ParseBasicType(): TCPASTNode;
begin
  Result := CreatePositionedNode(astTypeSpec, FCurrentToken.Value);
  AdvanceToken();
end;

function TCPParser.ParsePointerType(): TCPASTNode;
var
  LPointer: TCPASTNode;
  LTargetType: TCPASTNode;
begin
  LPointer := CreatePositionedNode(astTypeSpec, '^');
  Consume(ttPower, 'Expected "^"');
  
  LTargetType := ParseTypeSpec();
  LPointer.AddChild(LTargetType);
  
  Result := LPointer;
end;

function TCPParser.ParseArrayType(): TCPASTNode;
var
  LArray: TCPASTNode;
  LSize: TCPASTNode;
  LElementType: TCPASTNode;
begin
  LArray := CreatePositionedNode(astTypeSpec, 'array');
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

function TCPParser.ParseRecordType(): TCPASTNode;
var
  LRecord: TCPASTNode;
  LField: TCPASTNode;
  LFieldType: TCPASTNode;
begin
  LRecord := CreatePositionedNode(astTypeSpec, 'record');
  Consume(ttRecord, 'Expected "record"');
  
  // field_list
  while not Check(ttEnd) do
  begin
    // field_def: identifier_list : type_spec
    LField := TCPASTNode.Create(astVariableDecl);
    
    repeat
      LField.AddChild(CreateIdentifierNode(FCurrentToken.Value));
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

function TCPParser.ParseStatement(): TCPASTNode;
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
        Result := TCPASTNode.Create(astBreakStatement);
        AdvanceToken();
        Consume(ttSemicolon, 'Expected ";"');
      end;
    ttContinue:
      begin
        Result := TCPASTNode.Create(astContinueStatement);
        AdvanceToken();
        Consume(ttSemicolon, 'Expected ";"');
      end;
    ttGoto:
      begin
        Result := TCPASTNode.Create(astGotoStatement);
        AdvanceToken();
        Result.AddChild(CreateIdentifierNode(FCurrentToken.Value));
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

function TCPParser.ParseStatementBlock(): TCPASTNode;
var
  LBlock: TCPASTNode;
  LStatementList: TCPASTNode;
begin
  LBlock := TCPASTNode.Create(astStatementBlock);
  
  Consume(ttBegin, 'Expected "begin"');
  
  LStatementList := ParseStatementList();
  LBlock.AddChild(LStatementList);
  
  Consume(ttEnd, 'Expected "end"');
  
  Result := LBlock;
end;

function TCPParser.ParseStatementList(): TCPASTNode;
var
  LStatementList: TCPASTNode;
  LStatement: TCPASTNode;
begin
  LStatementList := TCPASTNode.Create(astStatementBlock);
  
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

function TCPParser.ParseAssignmentStatement(): TCPASTNode;
var
  LAssign: TCPASTNode;
  LLValue: TCPASTNode;
  LExpression: TCPASTNode;
begin
  LAssign := TCPASTNode.Create(astAssignment);
  
  LLValue := ParseLValue();
  LAssign.AddChild(LLValue);
  
  Consume(ttAssign, 'Expected ":="');
  
  LExpression := ParseExpression();
  LAssign.AddChild(LExpression);
  
  Consume(ttSemicolon, 'Expected ";"');
  
  Result := LAssign;
end;

function TCPParser.ParseIfStatement(): TCPASTNode;
var
  LIf: TCPASTNode;
  LCondition: TCPASTNode;
  LThenStmt: TCPASTNode;
  LElseStmt: TCPASTNode;
begin
  LIf := TCPASTNode.Create(astIfStatement);
  
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

function TCPParser.ParseWhileStatement(): TCPASTNode;
var
  LWhile: TCPASTNode;
  LCondition: TCPASTNode;
  LStatement: TCPASTNode;
begin
  LWhile := TCPASTNode.Create(astWhileStatement);
  
  Consume(ttWhile, 'Expected "while"');
  
  LCondition := ParseExpression();
  LWhile.AddChild(LCondition);
  
  Consume(ttDo, 'Expected "do"');
  
  LStatement := ParseStatement();
  LWhile.AddChild(LStatement);
  
  Result := LWhile;
end;

function TCPParser.ParseForStatement(): TCPASTNode;
var
  LFor: TCPASTNode;
  LVariable: TCPASTNode;
  LStartExpr: TCPASTNode;
  LEndExpr: TCPASTNode;
  LStatement: TCPASTNode;
begin
  LFor := TCPASTNode.Create(astForStatement);
  
  Consume(ttFor, 'Expected "for"');
  
  LVariable := CreateIdentifierNode(FCurrentToken.Value);
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
    raise ECPException.Create('Expected "to" or "downto"', [],
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
    
  LEndExpr := ParseExpression();
  LFor.AddChild(LEndExpr);
  
  Consume(ttDo, 'Expected "do"');
  
  LStatement := ParseStatement();
  LFor.AddChild(LStatement);
  
  Result := LFor;
end;

function TCPParser.ParseRepeatStatement(): TCPASTNode;
var
  LRepeat: TCPASTNode;
  LStatementList: TCPASTNode;
  LCondition: TCPASTNode;
begin
  LRepeat := TCPASTNode.Create(astRepeatStatement);
  
  Consume(ttRepeat, 'Expected "repeat"');
  
  LStatementList := ParseStatementList();
  LRepeat.AddChild(LStatementList);
  
  Consume(ttUntil, 'Expected "until"');
  
  LCondition := ParseExpression();
  LRepeat.AddChild(LCondition);
  
  Result := LRepeat;
end;

function TCPParser.ParseCaseStatement(): TCPASTNode;
var
  LCase: TCPASTNode;
  LExpression: TCPASTNode;
  LCaseItem: TCPASTNode;
  LElseClause: TCPASTNode;
begin
  LCase := TCPASTNode.Create(astCaseStatement);
  
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
    LElseClause := TCPASTNode.Create(astStatementBlock, 'else');
    LElseClause.AddChild(ParseStatementList());
    LCase.AddChild(LElseClause);
  end;
  
  Consume(ttEnd, 'Expected "end"');
  
  Result := LCase;
end;

function TCPParser.ParseCaseItem(): TCPASTNode;
var
  LCaseItem: TCPASTNode;
  LCaseLabels: TCPASTNode;
  LStatementList: TCPASTNode;
begin
  LCaseItem := TCPASTNode.Create(astCaseStatement); // Reusing same type for case items
  
  // Parse case labels
  LCaseLabels := ParseCaseLabels();
  LCaseItem.AddChild(LCaseLabels);
  
  Consume(ttColon, 'Expected ":"');
  
  // Parse statement list according to BNF: case_item ::= case_labels ":" statement_list
  LStatementList := ParseStatementList();
  LCaseItem.AddChild(LStatementList);
  
  Result := LCaseItem;
end;

function TCPParser.ParseCaseLabels(): TCPASTNode;
var
  LLabels: TCPASTNode;
  LLabel: TCPASTNode;
  LRangeEnd: TCPASTNode;
  LRange: TCPASTNode;
begin
  LLabels := TCPASTNode.Create(astExpression); // Container for case labels
  
  repeat
    // Parse case label (expression or range)
    LLabel := ParseExpression();
    
    // Check for range (..) 
    if Match(ttRange) then
    begin
      LRangeEnd := ParseExpression();
      // Create a range node
      LRange := TCPASTNode.Create(astBinaryOp, '..');
      LRange.AddChild(LLabel);
      LRange.AddChild(LRangeEnd);
      LLabels.AddChild(LRange);
    end
    else
      LLabels.AddChild(LLabel);
      
  until not Match(ttComma);
  
  Result := LLabels;
end;

function TCPParser.ParseReturnStatement(): TCPASTNode;
var
  LReturn: TCPASTNode;
  LExpression: TCPASTNode;
begin
  LReturn := TCPASTNode.Create(astReturnStatement);
  
  Consume(ttReturn, 'Expected "return"');
  
  if not Check(ttSemicolon) then
  begin
    LExpression := ParseExpression();
    LReturn.AddChild(LExpression);
  end;
  
  Consume(ttSemicolon, 'Expected ";"');
  
  Result := LReturn;
end;

function TCPParser.ParseCallStatement(): TCPASTNode;
var
  LCall: TCPASTNode;
begin
  LCall := TCPASTNode.Create(astCallStatement);
  
  LCall.AddChild(ParseExpression());
  
  Consume(ttSemicolon, 'Expected ";"');
  
  Result := LCall;
end;

function TCPParser.ParseExpression(): TCPASTNode;
begin
  Result := ParseConditionalExpression();
end;

function TCPParser.ParseConditionalExpression(): TCPASTNode;
var
  LExpr: TCPASTNode;
  LThen: TCPASTNode;
  LElse: TCPASTNode;
  LTernary: TCPASTNode;
begin
  LExpr := ParseLogicalOrExpression();
  
  if Match(ttQuestion) then
  begin
    LTernary := TCPASTNode.Create(astBinaryOp, '?:');
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

function TCPParser.ParseLogicalOrExpression(): TCPASTNode;
var
  LLeft: TCPASTNode;
  LRight: TCPASTNode;
  LBinOp: TCPASTNode;
begin
  LLeft := ParseLogicalAndExpression();
  
  while Match(ttOr) do
  begin
    LBinOp := TCPASTNode.Create(astBinaryOp, 'or');
    LBinOp.AddChild(LLeft);
    
    LRight := ParseLogicalAndExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TCPParser.ParseLogicalAndExpression(): TCPASTNode;
var
  LLeft: TCPASTNode;
  LRight: TCPASTNode;
  LBinOp: TCPASTNode;
begin
  LLeft := ParseEqualityExpression();
  
  while Match(ttAnd) do
  begin
    LBinOp := TCPASTNode.Create(astBinaryOp, 'and');
    LBinOp.AddChild(LLeft);
    
    LRight := ParseEqualityExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TCPParser.ParseEqualityExpression(): TCPASTNode;
var
  LLeft: TCPASTNode;
  LRight: TCPASTNode;
  LBinOp: TCPASTNode;
  LOperator: string;
begin
  LLeft := ParseRelationalExpression();
  
  while Check(ttEqual) or Check(ttNotEqual) do
  begin
    LOperator := FCurrentToken.Value;
    AdvanceToken();
    
    LBinOp := TCPASTNode.Create(astBinaryOp, LOperator);
    LBinOp.AddChild(LLeft);
    
    LRight := ParseRelationalExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TCPParser.ParseRelationalExpression(): TCPASTNode;
var
  LLeft: TCPASTNode;
  LRight: TCPASTNode;
  LBinOp: TCPASTNode;
  LOperator: string;
begin
  LLeft := ParseAdditiveExpression();
  
  while Check(ttLess) or Check(ttGreater) or Check(ttLessEqual) or Check(ttGreaterEqual) do
  begin
    LOperator := FCurrentToken.Value;
    AdvanceToken();
    
    LBinOp := TCPASTNode.Create(astBinaryOp, LOperator);
    LBinOp.AddChild(LLeft);
    
    LRight := ParseAdditiveExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TCPParser.ParseAdditiveExpression(): TCPASTNode;
var
  LLeft: TCPASTNode;
  LRight: TCPASTNode;
  LBinOp: TCPASTNode;
  LOperator: string;
begin
  LLeft := ParseMultiplicativeExpression();
  
  while Check(ttPlus) or Check(ttMinus) do
  begin
    LOperator := FCurrentToken.Value;
    AdvanceToken();
    
    LBinOp := TCPASTNode.Create(astBinaryOp, LOperator);
    LBinOp.AddChild(LLeft);
    
    LRight := ParseMultiplicativeExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TCPParser.ParseMultiplicativeExpression(): TCPASTNode;
var
  LLeft: TCPASTNode;
  LRight: TCPASTNode;
  LBinOp: TCPASTNode;
  LOperator: string;
begin
  LLeft := ParseUnaryExpression();
  
  while Check(ttMultiply) or Check(ttDivide) or Check(ttDiv) or Check(ttMod) do
  begin
    LOperator := FCurrentToken.Value;
    AdvanceToken();
    
    LBinOp := TCPASTNode.Create(astBinaryOp, LOperator);
    LBinOp.AddChild(LLeft);
    
    LRight := ParseUnaryExpression();
    LBinOp.AddChild(LRight);
    
    LLeft := LBinOp;
  end;
  
  Result := LLeft;
end;

function TCPParser.ParseUnaryExpression(): TCPASTNode;
var
  LUnary: TCPASTNode;
  LOperator: string;
  LOperand: TCPASTNode;
begin
  if Check(ttPlus) or Check(ttMinus) or Check(ttNot) or Check(ttAddressOf) or Check(ttPower) then
  begin
    LOperator := FCurrentToken.Value;
    AdvanceToken();
    
    LUnary := TCPASTNode.Create(astUnaryOp, LOperator);
    LOperand := ParseUnaryExpression();
    LUnary.AddChild(LOperand);
    
    Result := LUnary;
  end
  else if Check(ttSizeof) then
  begin
    AdvanceToken();
    Consume(ttLeftParen, 'Expected "("');
    
    LUnary := TCPASTNode.Create(astUnaryOp, 'sizeof');
    LOperand := ParseTypeSpec();
    LUnary.AddChild(LOperand);
    
    Consume(ttRightParen, 'Expected ")"');
    
    Result := LUnary;
  end
  else
    Result := ParsePostfixExpression();
end;

function TCPParser.ParsePostfixExpression(): TCPASTNode;
var
  LExpr: TCPASTNode;
  LAccess: TCPASTNode;
  LIndex: TCPASTNode;
  LArgs: TCPASTNode;
  LMember: TCPASTNode;
begin
  LExpr := ParsePrimaryExpression();
  
  while True do
  begin
    if Match(ttLeftBracket) then
    begin
      // Array access
      LAccess := TCPASTNode.Create(astArrayAccess);
      LAccess.AddChild(LExpr);
      
      LIndex := ParseExpression();
      LAccess.AddChild(LIndex);
      
      Consume(ttRightBracket, 'Expected "]"');
      
      LExpr := LAccess;
    end
    else if Match(ttLeftParen) then
    begin
      // Function call
      LAccess := TCPASTNode.Create(astFunctionCall);
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
      LAccess := TCPASTNode.Create(astMemberAccess);
      LAccess.AddChild(LExpr);
      
      LMember := CreateIdentifierNode(FCurrentToken.Value);
      Consume(ttIdentifier, 'Expected member name');
      LAccess.AddChild(LMember);
      
      LExpr := LAccess;
    end
    else if Match(ttPower) then
    begin
      // Pointer dereference
      LAccess := TCPASTNode.Create(astUnaryOp, '^');
      LAccess.AddChild(LExpr);
      
      LExpr := LAccess;
    end
    else
      Break;
  end;
  
  Result := LExpr;
end;

function TCPParser.ParsePrimaryExpression(): TCPASTNode;
begin
  case FCurrentToken.TokenType of
    ttIdentifier:
      begin
        Result := CreateIdentifierNode(FCurrentToken.Value);
        AdvanceToken();
      end;
    ttIntegerLiteral, ttRealLiteral, ttCharLiteral, ttStringLiteral, ttTrue, ttFalse:
      begin
        Result := CreateLiteralNode(FCurrentToken.Value);
        AdvanceToken();
      end;
    ttLeftParen:
      begin
        AdvanceToken();
        Result := ParseExpression();
        Consume(ttRightParen, 'Expected ")"');
      end;
  else
    raise ECPException.Create('Expected primary expression', [],
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
  end;
end;

function TCPParser.ParseArgumentList(): TCPASTNode;
var
  LArgs: TCPASTNode;
  LArg: TCPASTNode;
begin
  LArgs := TCPASTNode.Create(astArgumentList);
  
  repeat
    LArg := ParseExpression();
    LArgs.AddChild(LArg);
  until not Match(ttComma);
  
  Result := LArgs;
end;

function TCPParser.ParseLValue(): TCPASTNode;
var
  LValue: TCPASTNode;
  LAccess: TCPASTNode;
  LIndex: TCPASTNode;
  LMember: TCPASTNode;
begin
  case FCurrentToken.TokenType of
    ttIdentifier:
      begin
        LValue := CreateIdentifierNode(FCurrentToken.Value);
        AdvanceToken();
      end;
    ttLeftParen:
      begin
        AdvanceToken();
        LValue := ParseLValue();
        Consume(ttRightParen, 'Expected ")"');
      end;
  else
    raise ECPException.Create('Expected lvalue', [],
      FCurrentToken.SourcePos.FileName, FCurrentToken.SourcePos.Line, FCurrentToken.SourcePos.Column);
  end;
  
  // Handle postfix operators for lvalue
  while True do
  begin
    if Match(ttLeftBracket) then
    begin
      LAccess := TCPASTNode.Create(astArrayAccess);
      LAccess.AddChild(LValue);
      
      LIndex := ParseExpression();
      LAccess.AddChild(LIndex);
      
      Consume(ttRightBracket, 'Expected "]"');
      
      LValue := LAccess;
    end
    else if Match(ttDot) then
    begin
      LAccess := TCPASTNode.Create(astMemberAccess);
      LAccess.AddChild(LValue);
      
      LMember := CreateIdentifierNode(FCurrentToken.Value);
      Consume(ttIdentifier, 'Expected member name');
      LAccess.AddChild(LMember);
      
      LValue := LAccess;
    end
    else if Match(ttPower) then
    begin
      LAccess := TCPASTNode.Create(astUnaryOp, '^');
      LAccess.AddChild(LValue);
      
      LValue := LAccess;
    end
    else
      Break;
  end;
  
  Result := LValue;
end;

end.

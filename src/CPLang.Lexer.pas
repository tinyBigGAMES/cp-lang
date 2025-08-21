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

unit CPLang.Lexer;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  CPLang.Common,
  CPLang.SourceMap;

type
  { TCPTokenType }
  TCPTokenType = (
    // Literals
    ttIdentifier,
    ttIntegerLiteral,
    ttRealLiteral,
    ttCharLiteral,
    ttStringLiteral,
    ttTrue,
    ttFalse,
    
    // Keywords - Control Flow
    ttIf, ttThen, ttElse,
    ttWhile, ttDo,
    ttFor, ttTo, ttDownto,
    ttRepeat, ttUntil,
    ttCase, ttOf,
    ttBreak, ttContinue, ttReturn, ttGoto,
    ttBegin, ttEnd,
    
    // Keywords - Declarations  
    ttFunction, ttProcedure, ttMain,
    ttVar, ttConst, ttRef, ttType,
    ttRecord, ttArray, ttExternal,
    
    // Keywords - Types
    ttInt, ttChar, ttBool, ttFloat, ttDouble,
    ttInt8, ttInt16, ttInt32, ttInt64,
    ttUInt8, ttUInt16, ttUInt32, ttUInt64,
    
    // Keywords - Operators
    ttAnd, ttOr, ttNot, ttDiv, ttMod, ttSizeof,
    
    // Operators
    ttAssign,        // :=
    ttEqual,         // =
    ttNotEqual,      // <>
    ttLess,          // <
    ttGreater,       // >
    ttLessEqual,     // <=
    ttGreaterEqual,  // >=
    ttPlus,          // +
    ttMinus,         // -
    ttMultiply,      // *
    ttDivide,        // /
    ttPower,         // ^
    ttAddressOf,     // @
    ttRange,         // ..
    ttEllipsis,      // ...
    ttQuestion,      // ?
    
    // Punctuation
    ttDot,           // .
    ttComma,         // ,
    ttSemicolon,     // ;
    ttColon,         // :
    ttLeftParen,     // (
    ttRightParen,    // )
    ttLeftBracket,   // [
    ttRightBracket,  // ]
    
    // Special
    ttEOF
  );

  { TCPToken }
  TCPToken = record
    TokenType: TCPTokenType;
    Value: string;
    Position: Integer;        // Character position in merged source
    Line: Integer;           // Line in merged source
    Column: Integer;         // Column in merged source
    SourcePos: TCPSourcePosition; // Original file position
  end;

  { TCPLexer }
  TCPLexer = class
  private
    FKeywords: TDictionary<string, TCPTokenType>;
    FSource: string;
    FSourceFileName: string;
    FPosition: Integer;
    FLine: Integer;
    FColumn: Integer;
    FCurrentChar: Char;
    FSourceMapper: TCPSourceMapper;
    
    procedure InitKeywords();
    procedure AdvanceChar();
    function PeekChar(const AOffset: Integer = 1): Char;
    function IsAtEnd(): Boolean;
    function IsAlpha(const AChar: Char): Boolean;
    function IsDigit(const AChar: Char): Boolean;
    function IsAlphaNumeric(const AChar: Char): Boolean;
    
    procedure SkipWhitespace();
    procedure SkipComment();
    
    function ScanIdentifier(): TCPToken;
    function ScanNumber(): TCPToken;
    function ScanString(): TCPToken;
    function ScanChar(): TCPToken;
    
    function MakeToken(const AType: TCPTokenType; const AValue: string = ''): TCPToken;
    
  public
    constructor Create();
    destructor Destroy(); override;
    
    procedure SetSource(const ASource: string; const ASourceMapper: TCPSourceMapper = nil; const AFileName: string = '<source>');
    function NextToken(): TCPToken;
    function TokenizeAll(): TArray<TCPToken>;
    function GetCurrentSourcePosition(): TCPSourcePosition;
  end;

implementation

{ TCPLexer }
constructor TCPLexer.Create();
begin
  inherited;
  FKeywords := TDictionary<string, TCPTokenType>.Create();
  InitKeywords();
  FSource := '';
  FPosition := 0;
  FCurrentChar := #0;
end;

destructor TCPLexer.Destroy();
begin
  FKeywords.Free();
  inherited;
end;

procedure TCPLexer.InitKeywords();
begin
  // Control flow
  FKeywords.Add('if', ttIf);
  FKeywords.Add('then', ttThen);
  FKeywords.Add('else', ttElse);
  FKeywords.Add('while', ttWhile);
  FKeywords.Add('do', ttDo);
  FKeywords.Add('for', ttFor);
  FKeywords.Add('to', ttTo);
  FKeywords.Add('downto', ttDownto);
  FKeywords.Add('repeat', ttRepeat);
  FKeywords.Add('until', ttUntil);
  FKeywords.Add('case', ttCase);
  FKeywords.Add('of', ttOf);
  FKeywords.Add('break', ttBreak);
  FKeywords.Add('continue', ttContinue);
  FKeywords.Add('return', ttReturn);
  FKeywords.Add('goto', ttGoto);
  FKeywords.Add('begin', ttBegin);
  FKeywords.Add('end', ttEnd);
  
  // Declarations
  FKeywords.Add('function', ttFunction);
  FKeywords.Add('procedure', ttProcedure);
  FKeywords.Add('main', ttMain);
  FKeywords.Add('var', ttVar);
  FKeywords.Add('const', ttConst);
  FKeywords.Add('ref', ttRef);
  FKeywords.Add('type', ttType);
  FKeywords.Add('record', ttRecord);
  FKeywords.Add('array', ttArray);
  FKeywords.Add('external', ttExternal);
  
  // Types
  FKeywords.Add('int', ttInt);
  FKeywords.Add('char', ttChar);
  FKeywords.Add('bool', ttBool);
  FKeywords.Add('float', ttFloat);
  FKeywords.Add('double', ttDouble);
  FKeywords.Add('int8', ttInt8);
  FKeywords.Add('int16', ttInt16);
  FKeywords.Add('int32', ttInt32);
  FKeywords.Add('int64', ttInt64);
  FKeywords.Add('uint8', ttUInt8);
  FKeywords.Add('uint16', ttUInt16);
  FKeywords.Add('uint32', ttUInt32);
  FKeywords.Add('uint64', ttUInt64);
  
  // Boolean literals
  FKeywords.Add('true', ttTrue);
  FKeywords.Add('false', ttFalse);
  
  // Operators
  FKeywords.Add('and', ttAnd);
  FKeywords.Add('or', ttOr);
  FKeywords.Add('not', ttNot);
  FKeywords.Add('div', ttDiv);
  FKeywords.Add('mod', ttMod);
  FKeywords.Add('sizeof', ttSizeof);
end;

procedure TCPLexer.SetSource(const ASource: string; const ASourceMapper: TCPSourceMapper; const AFileName: string);
begin
  FSource := ASource;
  FSourceFileName := AFileName;
  FPosition := 1;
  FLine := 1;
  FColumn := 1;
  FSourceMapper := ASourceMapper;
  if Length(FSource) > 0 then
    FCurrentChar := FSource[1]
  else
    FCurrentChar := #0;
end;

procedure TCPLexer.AdvanceChar();
begin
  if FCurrentChar = #10 then
  begin
    Inc(FLine);
    FColumn := 1;
  end
  else if FCurrentChar = #13 then
  begin
    if (FPosition < Length(FSource)) and (FSource[FPosition + 1] = #10) then
    begin
      // CRLF - skip the LF, will be handled on next call
    end
    else
    begin
      Inc(FLine);
      FColumn := 1;
    end;
  end
  else
    Inc(FColumn);
    
  Inc(FPosition);
  if FPosition <= Length(FSource) then
    FCurrentChar := FSource[FPosition]
  else
    FCurrentChar := #0;
end;

function TCPLexer.PeekChar(const AOffset: Integer): Char;
var
  LPos: Integer;
begin
  LPos := FPosition + AOffset;
  if LPos <= Length(FSource) then
    Result := FSource[LPos]
  else
    Result := #0;
end;

function TCPLexer.IsAtEnd(): Boolean;
begin
  Result := FPosition > Length(FSource);
end;

function TCPLexer.IsAlpha(const AChar: Char): Boolean;
begin
  Result := ((AChar >= 'a') and (AChar <= 'z')) or
            ((AChar >= 'A') and (AChar <= 'Z')) or
            (AChar = '_');
end;

function TCPLexer.IsDigit(const AChar: Char): Boolean;
begin
  Result := (AChar >= '0') and (AChar <= '9');
end;

function TCPLexer.IsAlphaNumeric(const AChar: Char): Boolean;
begin
  Result := IsAlpha(AChar) or IsDigit(AChar);
end;

procedure TCPLexer.SkipWhitespace();
begin
  while (FCurrentChar = ' ') or (FCurrentChar = #9) or 
        (FCurrentChar = #13) or (FCurrentChar = #10) do
    AdvanceChar();
end;

procedure TCPLexer.SkipComment();
begin
  if (FCurrentChar = '/') and (PeekChar() = '/') then
  begin
    // Single line comment
    while (FCurrentChar <> #10) and (FCurrentChar <> #0) do
      AdvanceChar();
  end
  else if (FCurrentChar = '/') and (PeekChar() = '*') then
  begin
    // Multi-line comment
    AdvanceChar(); // Skip /
    AdvanceChar(); // Skip *
    
    while FCurrentChar <> #0 do
    begin
      if (FCurrentChar = '*') and (PeekChar() = '/') then
      begin
        AdvanceChar(); // Skip *
        AdvanceChar(); // Skip /
        Break;
      end;
      AdvanceChar();
    end;
  end;
end;

function TCPLexer.ScanIdentifier(): TCPToken;
var
  LStart: Integer;
  LValue: string;
  LTokenType: TCPTokenType;
begin
  LStart := FPosition;
  
  while IsAlphaNumeric(FCurrentChar) do
    AdvanceChar();
    
  LValue := Copy(FSource, LStart, FPosition - LStart);
  
  if FKeywords.TryGetValue(LValue, LTokenType) then
    Result := MakeToken(LTokenType, LValue)
  else
    Result := MakeToken(ttIdentifier, LValue);
end;

function TCPLexer.ScanNumber(): TCPToken;
var
  LStart: Integer;
  LValue: string;
  LIsFloat: Boolean;
begin
  LStart := FPosition;
  LIsFloat := False;
  
  // Scan integer part
  while IsDigit(FCurrentChar) do
    AdvanceChar();
    
  // Check for decimal point
  if (FCurrentChar = '.') and IsDigit(PeekChar()) then
  begin
    LIsFloat := True;
    AdvanceChar(); // Skip .
    
    while IsDigit(FCurrentChar) do
      AdvanceChar();
  end;
  
  LValue := Copy(FSource, LStart, FPosition - LStart);
  
  if LIsFloat then
    Result := MakeToken(ttRealLiteral, LValue)
  else
    Result := MakeToken(ttIntegerLiteral, LValue);
end;

function TCPLexer.ScanString(): TCPToken;
var
  LStart: Integer;
  LValue: string;
begin
  LStart := FPosition;
  AdvanceChar(); // Skip opening "
  
  while (FCurrentChar <> '"') and (FCurrentChar <> #0) do
  begin
    if FCurrentChar = '\' then
    begin
      AdvanceChar(); // Skip \
      if FCurrentChar <> #0 then
        AdvanceChar(); // Skip escaped char
    end
    else
      AdvanceChar();
  end;
  
  if FCurrentChar = '"' then
    AdvanceChar(); // Skip closing "
    
  LValue := Copy(FSource, LStart, FPosition - LStart);
  Result := MakeToken(ttStringLiteral, LValue);
end;

function TCPLexer.ScanChar(): TCPToken;
var
  LStart: Integer;
  LValue: string;
begin
  LStart := FPosition;
  AdvanceChar(); // Skip opening '
  
  if FCurrentChar = '\' then
  begin
    AdvanceChar(); // Skip \
    if FCurrentChar <> #0 then
      AdvanceChar(); // Skip escaped char
  end
  else if FCurrentChar <> #0 then
    AdvanceChar();
    
  if FCurrentChar = '''' then
    AdvanceChar(); // Skip closing '
    
  LValue := Copy(FSource, LStart, FPosition - LStart);
  Result := MakeToken(ttCharLiteral, LValue);
end;

function TCPLexer.MakeToken(const AType: TCPTokenType; const AValue: string): TCPToken;
begin
  Result.TokenType := AType;
  Result.Value := AValue;
  Result.Position := FPosition;
  Result.Line := FLine;
  Result.Column := FColumn;
  Result.SourcePos := GetCurrentSourcePosition();
end;

function TCPLexer.GetCurrentSourcePosition(): TCPSourcePosition;
begin
  if Assigned(FSourceMapper) then
    Result := FSourceMapper.MapPosition(FPosition)
  else
    Result := TCPSourcePosition.Create(FSourceFileName, FLine, FColumn, FPosition);
end;

function TCPLexer.NextToken(): TCPToken;
begin
  repeat
    SkipWhitespace();
    
    if ((FCurrentChar = '/') and (PeekChar() = '/')) or
       ((FCurrentChar = '/') and (PeekChar() = '*')) then
    begin
      SkipComment();
      Continue;
    end;
    
    Break;
  until False;
  
  if IsAtEnd() then
    Exit(MakeToken(ttEOF));
    
  case FCurrentChar of
    '(':
      begin
        AdvanceChar();
        Result := MakeToken(ttLeftParen, '(');
      end;
    ')':
      begin
        AdvanceChar();
        Result := MakeToken(ttRightParen, ')');
      end;
    '[':
      begin
        AdvanceChar();
        Result := MakeToken(ttLeftBracket, '[');
      end;
    ']':
      begin
        AdvanceChar();
        Result := MakeToken(ttRightBracket, ']');
      end;
    ',':
      begin
        AdvanceChar();
        Result := MakeToken(ttComma, ',');
      end;
    ';':
      begin
        AdvanceChar();
        Result := MakeToken(ttSemicolon, ';');
      end;
    '+':
      begin
        AdvanceChar();
        Result := MakeToken(ttPlus, '+');
      end;
    '-':
      begin
        AdvanceChar();
        Result := MakeToken(ttMinus, '-');
      end;
    '*':
      begin
        AdvanceChar();
        Result := MakeToken(ttMultiply, '*');
      end;
    '/':
      begin
        AdvanceChar();
        Result := MakeToken(ttDivide, '/');
      end;
    '^':
      begin
        AdvanceChar();
        Result := MakeToken(ttPower, '^');
      end;
    '@':
      begin
        AdvanceChar();
        Result := MakeToken(ttAddressOf, '@');
      end;
    '?':
      begin
        AdvanceChar();
        Result := MakeToken(ttQuestion, '?');
      end;
    '"':
      Result := ScanString();
    '''':
      Result := ScanChar();
    ':':
      begin
        if PeekChar() = '=' then
        begin
          AdvanceChar();
          AdvanceChar();
          Result := MakeToken(ttAssign, ':=');
        end
        else
        begin
          AdvanceChar();
          Result := MakeToken(ttColon, ':');
        end;
      end;
    '=':
      begin
        AdvanceChar();
        Result := MakeToken(ttEqual, '=');
      end;
    '<':
      begin
        if PeekChar() = '>' then
        begin
          AdvanceChar();
          AdvanceChar();
          Result := MakeToken(ttNotEqual, '<>');
        end
        else if PeekChar() = '=' then
        begin
          AdvanceChar();
          AdvanceChar();
          Result := MakeToken(ttLessEqual, '<=');
        end
        else
        begin
          AdvanceChar();
          Result := MakeToken(ttLess, '<');
        end;
      end;
    '>':
      begin
        if PeekChar() = '=' then
        begin
          AdvanceChar();
          AdvanceChar();
          Result := MakeToken(ttGreaterEqual, '>=');
        end
        else
        begin
          AdvanceChar();
          Result := MakeToken(ttGreater, '>');
        end;
      end;
    '.':
      begin
        if PeekChar() = '.' then
        begin
          if PeekChar(2) = '.' then
          begin
            AdvanceChar();
            AdvanceChar();
            AdvanceChar();
            Result := MakeToken(ttEllipsis, '...');
          end
          else
          begin
            AdvanceChar();
            AdvanceChar();
            Result := MakeToken(ttRange, '..');
          end;
        end
        else
        begin
          AdvanceChar();
          Result := MakeToken(ttDot, '.');
        end;
      end;
  else
    if IsAlpha(FCurrentChar) then
      Result := ScanIdentifier()
    else if IsDigit(FCurrentChar) then
      Result := ScanNumber()
    else
    begin
      AdvanceChar();
      Result := MakeToken(ttEOF); // Error token - simplified
    end;
  end;
end;

function TCPLexer.TokenizeAll(): TArray<TCPToken>;
var
  LTokens: TList<TCPToken>;
  LToken: TCPToken;
begin
  LTokens := TList<TCPToken>.Create();
  try
    repeat
      LToken := NextToken();
      LTokens.Add(LToken);
    until LToken.TokenType = ttEOF;
    
    Result := LTokens.ToArray();
  finally
    LTokens.Free();
  end;
end;

end.

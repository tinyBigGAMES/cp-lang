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

unit CPLang.SourceMap;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  CPLang.Common;

type
  { TCPSourcePosition }
  TCPSourcePosition = record
    FileName: string;
    Line: Integer;
    Column: Integer;
    CharIndex: Integer;
    
    class function Create(const AFileName: string; const ALine, AColumn, ACharIndex: Integer): TCPSourcePosition; static;
    function ToString(): string;
  end;

  { TCPLineColumn }
  TCPLineColumn = record
    Line: Integer;
    Column: Integer;
  end;

  { TCPSourceMapEntry }
  TCPSourceMapEntry = record
    OriginalFile: string;
    OriginalLine: Integer;
    OriginalColumn: Integer;
    MergedStartChar: Integer;
    MergedEndChar: Integer;
    MergedStartLine: Integer;
    MergedEndLine: Integer;
  end;

  { TCPSourceMapper }
  TCPSourceMapper = class
  private
    FMappings: TList<TCPSourceMapEntry>;
    FMergedSource: string;
    FLineStarts: TList<Integer>; // Character positions where each line starts
    
    procedure BuildLineIndex();
    
  public
    constructor Create();
    destructor Destroy(); override;
    
    procedure SetMergedSource(const ASource: string);
    procedure AddMapping(const AOriginalFile: string; const AOriginalStartLine, AOriginalEndLine: Integer;
      const AMergedStartChar, AMergedEndChar: Integer);
    
    function MapPosition(const AMergedCharIndex: Integer): TCPSourcePosition;
    function GetMergedLineColumn(const ACharIndex: Integer): TCPLineColumn;
    function GetSourceLine(const AMergedLine: Integer): string;
    
    procedure Clear();
  end;

implementation

{ TCPSourcePosition }
class function TCPSourcePosition.Create(const AFileName: string; const ALine, AColumn, ACharIndex: Integer): TCPSourcePosition;
begin
  Result.FileName := AFileName;
  Result.Line := ALine;
  Result.Column := AColumn;
  Result.CharIndex := ACharIndex;
end;

function TCPSourcePosition.ToString(): string;
begin
  Result := Format('%s(%d,%d)', [FileName, Line, Column]);
end;

{ TCPSourceMapper }
constructor TCPSourceMapper.Create();
begin
  inherited;
  FMappings := TList<TCPSourceMapEntry>.Create();
  FLineStarts := TList<Integer>.Create();
  FMergedSource := '';
end;

destructor TCPSourceMapper.Destroy();
begin
  FLineStarts.Free();
  FMappings.Free();
  inherited;
end;

procedure TCPSourceMapper.Clear();
begin
  FMappings.Clear();
  FLineStarts.Clear();
  FMergedSource := '';
end;

procedure TCPSourceMapper.SetMergedSource(const ASource: string);
var
  LIndex: Integer;
  LMapping: TCPSourceMapEntry;
  LMergedPos: TCPLineColumn;
begin
  FMergedSource := ASource;
  BuildLineIndex();
  
  // Now calculate merged line numbers for all mappings
  for LIndex := 0 to FMappings.Count - 1 do
  begin
    LMapping := FMappings[LIndex];
    
    // Calculate merged line numbers now that we have the line index
    LMergedPos := GetMergedLineColumn(LMapping.MergedStartChar);
    LMapping.MergedStartLine := LMergedPos.Line;
    
    LMergedPos := GetMergedLineColumn(LMapping.MergedEndChar);
    LMapping.MergedEndLine := LMergedPos.Line;
    
    // Update the mapping in the list
    FMappings[LIndex] := LMapping;
  end;
end;

procedure TCPSourceMapper.BuildLineIndex();
var
  LIndex: Integer;
begin
  FLineStarts.Clear();
  FLineStarts.Add(1); // Line 1 starts at position 1
  
  for LIndex := 1 to Length(FMergedSource) do
  begin
    if (FMergedSource[LIndex] = #10) or 
       ((FMergedSource[LIndex] = #13) and (LIndex < Length(FMergedSource)) and (FMergedSource[LIndex + 1] <> #10)) then
    begin
      FLineStarts.Add(LIndex + 1);
    end;
  end;
end;

procedure TCPSourceMapper.AddMapping(const AOriginalFile: string; const AOriginalStartLine, AOriginalEndLine: Integer;
  const AMergedStartChar, AMergedEndChar: Integer);
var
  LMapping: TCPSourceMapEntry;
begin
  LMapping.OriginalFile := AOriginalFile;
  LMapping.OriginalLine := AOriginalStartLine;
  LMapping.MergedStartChar := AMergedStartChar;
  LMapping.MergedEndChar := AMergedEndChar;
  
  // Don't calculate merged line numbers yet - will be done in SetMergedSource
  LMapping.MergedStartLine := 0; // Placeholder
  LMapping.MergedEndLine := 0; // Placeholder

  FMappings.Add(LMapping);
end;

function TCPSourceMapper.MapPosition(const AMergedCharIndex: Integer): TCPSourcePosition;
var
  LMapping: TCPSourceMapEntry;
  LMergedPos: TCPLineColumn;
  LOriginalLine: Integer;
  LLineOffset: Integer;
begin
  // Find which mapping contains this character
  for LMapping in FMappings do
  begin
    if (AMergedCharIndex >= LMapping.MergedStartChar) and (AMergedCharIndex <= LMapping.MergedEndChar) then
    begin
      // Get the line position in merged source
      LMergedPos := GetMergedLineColumn(AMergedCharIndex);
      
      // Calculate line offset within this mapping
      LLineOffset := LMergedPos.Line - LMapping.MergedStartLine;
      
      // Map to original line
      LOriginalLine := LMapping.OriginalLine + LLineOffset;

      Result := TCPSourcePosition.Create(LMapping.OriginalFile, LOriginalLine, LMergedPos.Column, AMergedCharIndex);
      Exit;
    end;
  end;

  // Fallback - no mapping found
  LMergedPos := GetMergedLineColumn(AMergedCharIndex);
  Result := TCPSourcePosition.Create('<unknown>', LMergedPos.Line, LMergedPos.Column, AMergedCharIndex);
end;

function TCPSourceMapper.GetMergedLineColumn(const ACharIndex: Integer): TCPLineColumn;
var
  LLineIndex: Integer;
begin
  Result.Line := 1;
  Result.Column := 1;
  
  // Find which line this character is on
  for LLineIndex := FLineStarts.Count - 1 downto 0 do
  begin
    if ACharIndex >= FLineStarts[LLineIndex] then
    begin
      Result.Line := LLineIndex + 1;
      Result.Column := ACharIndex - FLineStarts[LLineIndex] + 1;
      Break;
    end;
  end;
end;

function TCPSourceMapper.GetSourceLine(const AMergedLine: Integer): string;
var
  LStartPos: Integer;
  LEndPos: Integer;
begin
  if (AMergedLine < 1) or (AMergedLine > FLineStarts.Count) then
    Exit('');
    
  LStartPos := FLineStarts[AMergedLine - 1];
  
  if AMergedLine < FLineStarts.Count then
    LEndPos := FLineStarts[AMergedLine] - 1
  else
    LEndPos := Length(FMergedSource);
    
  // Remove line ending characters
  while (LEndPos >= LStartPos) and 
        ((FMergedSource[LEndPos] = #13) or (FMergedSource[LEndPos] = #10)) do
    Dec(LEndPos);
    
  if LEndPos >= LStartPos then
    Result := Copy(FMergedSource, LStartPos, LEndPos - LStartPos + 1)
  else
    Result := '';
end;

end.

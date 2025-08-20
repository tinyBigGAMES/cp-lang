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

unit ELang.SourceMap;

{$I ELang.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  ELang.Common;

type
  { TELSourcePosition }
  TELSourcePosition = record
    FileName: string;
    Line: Integer;
    Column: Integer;
    CharIndex: Integer;
    
    class function Create(const AFileName: string; const ALine, AColumn, ACharIndex: Integer): TELSourcePosition; static;
    function ToString(): string;
  end;

  { TELLineColumn }
  TELLineColumn = record
    Line: Integer;
    Column: Integer;
  end;

  { TELSourceMapEntry }
  TELSourceMapEntry = record
    OriginalFile: string;
    OriginalLine: Integer;
    OriginalColumn: Integer;
    MergedStartChar: Integer;
    MergedEndChar: Integer;
    MergedStartLine: Integer;
    MergedEndLine: Integer;
  end;

  { TELSourceMapper }
  TELSourceMapper = class(TELObject)
  private
    FMappings: TList<TELSourceMapEntry>;
    FMergedSource: string;
    FLineStarts: TList<Integer>; // Character positions where each line starts
    
    procedure BuildLineIndex();
    
  public
    constructor Create(); override;
    destructor Destroy(); override;
    
    procedure SetMergedSource(const ASource: string);
    procedure AddMapping(const AOriginalFile: string; const AOriginalStartLine, AOriginalEndLine: Integer;
      const AMergedStartChar, AMergedEndChar: Integer);
    
    function MapPosition(const AMergedCharIndex: Integer): TELSourcePosition;
    function GetMergedLineColumn(const ACharIndex: Integer): TELLineColumn;
    function GetSourceLine(const AMergedLine: Integer): string;
    
    procedure Clear();
  end;

implementation

{ TELSourcePosition }

class function TELSourcePosition.Create(const AFileName: string; const ALine, AColumn, ACharIndex: Integer): TELSourcePosition;
begin
  Result.FileName := AFileName;
  Result.Line := ALine;
  Result.Column := AColumn;
  Result.CharIndex := ACharIndex;
end;

function TELSourcePosition.ToString(): string;
begin
  Result := Format('%s(%d,%d)', [FileName, Line, Column]);
end;

{ TELSourceMapper }

constructor TELSourceMapper.Create();
begin
  inherited;
  FMappings := TList<TELSourceMapEntry>.Create();
  FLineStarts := TList<Integer>.Create();
  FMergedSource := '';
end;

destructor TELSourceMapper.Destroy();
begin
  FLineStarts.Free();
  FMappings.Free();
  inherited;
end;

procedure TELSourceMapper.Clear();
begin
  FMappings.Clear();
  FLineStarts.Clear();
  FMergedSource := '';
end;

procedure TELSourceMapper.SetMergedSource(const ASource: string);
var
  LIndex: Integer;
  LMapping: TELSourceMapEntry;
  LMergedPos: TELLineColumn;
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

procedure TELSourceMapper.BuildLineIndex();
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

procedure TELSourceMapper.AddMapping(const AOriginalFile: string; const AOriginalStartLine, AOriginalEndLine: Integer;
  const AMergedStartChar, AMergedEndChar: Integer);
var
  LMapping: TELSourceMapEntry;
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

function TELSourceMapper.MapPosition(const AMergedCharIndex: Integer): TELSourcePosition;
var
  LMapping: TELSourceMapEntry;
  LMergedPos: TELLineColumn;
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

      Result := TELSourcePosition.Create(LMapping.OriginalFile, LOriginalLine, LMergedPos.Column, AMergedCharIndex);
      Exit;
    end;
  end;

  // Fallback - no mapping found
  LMergedPos := GetMergedLineColumn(AMergedCharIndex);
  Result := TELSourcePosition.Create('<unknown>', LMergedPos.Line, LMergedPos.Column, AMergedCharIndex);
end;

function TELSourceMapper.GetMergedLineColumn(const ACharIndex: Integer): TELLineColumn;
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

function TELSourceMapper.GetSourceLine(const AMergedLine: Integer): string;
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

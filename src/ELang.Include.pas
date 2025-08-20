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

unit ELang.Include;

{$I ELang.Defines.inc}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Generics.Collections,
  ELang.Common,
  ELang.SourceMap,
  ELang.Errors;

type
  { TELIncludeManager }
  TELIncludeManager = class(TELObject)
  private
    FIncludedFiles: TStringList;
    FIncludePaths: TStringList;
    FSourceMapper: TELSourceMapper;
    FBasePath: string;
    FMergedSource: string;
    
    function ProcessFile(const AFileName: string; var ACurrentCharPos: Integer): string;
    function ResolveIncludePath(const AIncludePath: string; const AIsAngleBracket: Boolean): string;
    function IsAlreadyIncluded(const AFileName: string): Boolean;
    function ValidateAngleBracketInclude(const AInclude: string): Boolean;
    
  public
    constructor Create(); override;
    destructor Destroy(); override;
    
    function ProcessMainFile(const AMainFileName: string): string;
    function GetSourcePosition(const ACharIndex: Integer): TELSourcePosition;
    function GetSourceLine(const ACharIndex: Integer): string;
    procedure Clear();
    
    procedure AddIncludePath(const APath: string);
    procedure ClearIncludePaths();
    function GetIncludePath(const AIndex: Integer): string;
    function GetIncludePathCount(): Integer;
    
    property BasePath: string read FBasePath write FBasePath;
    property SourceMapper: TELSourceMapper read FSourceMapper;
  end;

implementation

{ TELIncludeManager }

constructor TELIncludeManager.Create();
begin
  inherited;
  FIncludedFiles := TStringList.Create();
  FIncludePaths := TStringList.Create();
  FSourceMapper := TELSourceMapper.Create();
  FBasePath := '';
  FMergedSource := '';
end;

destructor TELIncludeManager.Destroy();
begin
  FIncludedFiles.Free();
  FIncludePaths.Free();
  FSourceMapper.Free();
  inherited;
end;

procedure TELIncludeManager.Clear();
begin
  FIncludedFiles.Clear();
  FSourceMapper.Clear();
  FMergedSource := '';
end;

procedure TELIncludeManager.AddIncludePath(const APath: string);
begin
  if not FIncludePaths.Contains(APath) then
    FIncludePaths.Add(APath);
end;

procedure TELIncludeManager.ClearIncludePaths();
begin
  FIncludePaths.Clear();
end;

function TELIncludeManager.GetIncludePath(const AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= FIncludePaths.Count) then
    raise EELException.Create('Include path index out of bounds: %d', [AIndex]);
  Result := FIncludePaths[AIndex];
end;

function TELIncludeManager.GetIncludePathCount(): Integer;
begin
  Result := FIncludePaths.Count;
end;

function TELIncludeManager.ValidateAngleBracketInclude(const AInclude: string): Boolean;
var
  LFileName: string;
begin
  Result := False;
  
  // Check for path separators - not allowed in angle bracket includes
  if (Pos('\', AInclude) > 0) or (Pos('/', AInclude) > 0) then
    Exit;
    
  // Must have .e extension
  LFileName := AInclude.ToLower();
  if not LFileName.EndsWith('.e') then
    Exit;
    
  // Must be a valid filename (not empty after removing extension)
  if LFileName.Length <= 2 then
    Exit;
    
  Result := True;
end;

function TELIncludeManager.ProcessMainFile(const AMainFileName: string): string;
var
  LCurrentCharPos: Integer;
  LLines: TArray<string>;
  LIndex: Integer;
begin
  Clear();
  FBasePath := TPath.GetDirectoryName(TPath.GetFullPath(AMainFileName));
  LCurrentCharPos := 1;
  FMergedSource := ProcessFile(AMainFileName, LCurrentCharPos);
  FSourceMapper.SetMergedSource(FMergedSource);
  
  Result := FMergedSource;
end;

function TELIncludeManager.ProcessFile(const AFileName: string; var ACurrentCharPos: Integer): string;
var
  LFileContent: string;
  LLines: TArray<string>;
  LLine: string;
  LIncludePath: string;
  LIncludeFile: string;
  LIncludeContent: string;
  LLineIndex: Integer;
  LFullPath: string;
  LContentStartPos: Integer;
  LContentStartLine: Integer;
  LContentEndLine: Integer;
  LHasContent: Boolean;
begin
  Result := '';
  
  if not TFile.Exists(AFileName) then
    raise EELException.Create('Include file not found: %s', [AFileName]);
    
  if IsAlreadyIncluded(AFileName) then
    Exit; // Prevent circular includes
    
  LFullPath := TPath.GetFullPath(AFileName);
  FIncludedFiles.Add(LFullPath);
  
  LFileContent := TFile.ReadAllText(AFileName);
  LLines := LFileContent.Split([#13#10, #10, #13], TStringSplitOptions.None);
  
  LContentStartPos := ACurrentCharPos;
  LContentStartLine := 1;
  LHasContent := False;
  
  for LLineIndex := 0 to High(LLines) do
  begin
    LLine := LLines[LLineIndex].Trim();
    
    // Check for #includepath directive FIRST (space required)
    if LLine.StartsWith('#includepath ') then
    begin
      // If we have accumulated content, add mapping for it
      if LHasContent then
      begin
        LContentEndLine := LLineIndex; // Line before the include
        FSourceMapper.AddMapping(LFullPath, LContentStartLine, LContentEndLine, 
          LContentStartPos, ACurrentCharPos - 1);

        LHasContent := False;
      end;
      
      // Extract include path
      LLine := LLine.Substring(13).Trim(); // Remove '#includepath '
      
      if LLine.StartsWith('"') and LLine.EndsWith('"') then
      begin
        LIncludePath := LLine.Substring(1, LLine.Length - 2);
        AddIncludePath(LIncludePath);
      end
      else
        raise EELException.Create('Invalid #includepath directive: path must be enclosed in quotes');
      
      // After includepath, prepare for next content block
      LContentStartPos := ACurrentCharPos;
      LContentStartLine := LLineIndex + 2; // Skip includepath line, next line in 1-based numbering
    end
    // Check for #include directive (space required)
    else if LLine.StartsWith('#include ') then
    begin
      // If we have accumulated content, add mapping for it
      if LHasContent then
      begin
        LContentEndLine := LLineIndex; // Line before the includepath
        FSourceMapper.AddMapping(LFullPath, LContentStartLine, LContentEndLine, 
          LContentStartPos, ACurrentCharPos - 1);

        LHasContent := False;
      end;
      
      // Extract include path
      LLine := LLine.Substring(9).Trim(); // Remove '#include '
      
      if LLine.StartsWith('"') and LLine.EndsWith('"') then
      begin
        // Quoted include - allows paths, relative resolution
        LIncludePath := LLine.Substring(1, LLine.Length - 2);
        LIncludeFile := ResolveIncludePath(LIncludePath, False);
        LIncludeContent := ProcessFile(LIncludeFile, ACurrentCharPos);
        Result := Result + LIncludeContent;
      end
      else if LLine.StartsWith('<') and LLine.EndsWith('>') then
      begin
        // Angle bracket include - filename only, search paths
        LIncludePath := LLine.Substring(1, LLine.Length - 2);
        
        if not ValidateAngleBracketInclude(LIncludePath) then
          raise EELException.Create('Invalid angle bracket include "%s": must be filename.e format only (no paths)', [LIncludePath]);
          
        LIncludeFile := ResolveIncludePath(LIncludePath, True);
        LIncludeContent := ProcessFile(LIncludeFile, ACurrentCharPos);
        Result := Result + LIncludeContent;
      end
      else
        raise EELException.Create('Invalid #include directive: must be "filename" or <filename>');
      
      // After include, prepare for next content block
      LContentStartPos := ACurrentCharPos;
      LContentStartLine := LLineIndex + 2; // Skip include line, next line in 1-based numbering
    end
    else
    begin
      // This is actual source content (not an include/includepath directive)
      if not LHasContent then
      begin
        LContentStartPos := ACurrentCharPos;
        LContentStartLine := LLineIndex + 1;
        LHasContent := True;
      end;
      
      Result := Result + LLines[LLineIndex] + sLineBreak;
      ACurrentCharPos := ACurrentCharPos + Length(LLines[LLineIndex]) + Length(sLineBreak);
    end;
  end;
  
  // Add mapping for any remaining content
  if LHasContent then
  begin
    LContentEndLine := Length(LLines);
    FSourceMapper.AddMapping(LFullPath, LContentStartLine, LContentEndLine, 
      LContentStartPos, ACurrentCharPos - 1);
  end;
end;

function TELIncludeManager.ResolveIncludePath(const AIncludePath: string; const AIsAngleBracket: Boolean): string;
var
  LSearchPaths: string;
  LIndex: Integer;
begin
  if AIsAngleBracket then
  begin
    // Angle bracket include - search in include paths only
    if FIncludePaths.Count = 0 then
      raise EELException.Create('No include paths configured for angle bracket include: <%s>', [AIncludePath]);
    
    // Build semicolon-separated search paths for FileSearch
    LSearchPaths := '';
    for LIndex := 0 to FIncludePaths.Count - 1 do
    begin
      if LIndex > 0 then
        LSearchPaths := LSearchPaths + ';';
      LSearchPaths := LSearchPaths + FIncludePaths[LIndex];
    end;
    
    Result := FileSearch(AIncludePath, LSearchPaths);
    if Result = '' then
      raise EELException.Create('Cannot find angle bracket include <%s> in configured include paths', [AIncludePath]);
  end
  else
  begin
    // Quoted include - use existing resolution logic
    // Try relative to base path first
    Result := TPath.Combine(FBasePath, AIncludePath);
    if TFile.Exists(Result) then
      Exit;
      
    // Try absolute path
    if TPath.IsPathRooted(AIncludePath) and TFile.Exists(AIncludePath) then
    begin
      Result := AIncludePath;
      Exit;
    end;
    
    raise EELException.Create('Cannot resolve include path: %s', [AIncludePath]);
  end;
end;

function TELIncludeManager.IsAlreadyIncluded(const AFileName: string): Boolean;
var
  LFullPath: string;
begin
  LFullPath := TPath.GetFullPath(AFileName);
  Result := FIncludedFiles.IndexOf(LFullPath) >= 0;
end;

function TELIncludeManager.GetSourcePosition(const ACharIndex: Integer): TELSourcePosition;
begin
  Result := FSourceMapper.MapPosition(ACharIndex);
end;

function TELIncludeManager.GetSourceLine(const ACharIndex: Integer): string;
var
  LSourcePos: TELSourcePosition;
begin
  LSourcePos := FSourceMapper.MapPosition(ACharIndex);
  Result := FSourceMapper.GetSourceLine(LSourcePos.Line);
end;

end.
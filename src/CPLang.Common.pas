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


unit CPLang.Common;

{$I CPLang.Defines.inc}

interface

uses
  System.SysUtils,
  CPLang.Platform;

{ Console }
procedure CPClearToEOL();
function  CPPrint(const AText: string): string; overload;
function  CPPrint(const AText: string; const AArgs: array of const): string; overload;
function  CPPrintLn(const AText: string): string; overload;
function  CPPrintLn(const AText: string; const AArgs: array of const): string; overload;
procedure CPPause();

implementation

{ Console }
procedure CPClearToEOL();
begin
  if not CPHasConsole() then Exit;
  Write(#27'[0K');
end;

function CPPrint(const AText: string): string;
begin
  if not CPHasConsole() then Exit;
  Result := AText;
  Write(Result);
end;

function CPPrint(const AText: string; const AArgs: array of const): string;
begin
  if not CPHasConsole() then Exit;
  Result := Format(AText, AArgs);
  Write(Result);
end;

function CPPrintLn(const AText: string): string;
begin
  if not CPHasConsole() then Exit;
  Result := AText;
  WriteLn(Result);
end;

function  CPPrintLn(const AText: string; const AArgs: array of const): string;
begin
  if not CPHasConsole() then Exit;
  Result := Format(AText, AArgs);
  WriteLn(Result);
end;

procedure CPPause();
begin
  CPPrintLn('');
  CPPrint('Press ENTER to continue...');
  ReadLn;
  CPPrintLn('');
end;

end.

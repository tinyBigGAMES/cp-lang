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

unit ELang.Common;

{$I ELang.Defines.inc}

interface

uses
  System.SysUtils;

type
  { TELObject }
  TELObject = class
  public
    constructor Create(); virtual;
    destructor Destroy(); override;
  end;

implementation

{ TELObject }

constructor TELObject.Create();
begin
  inherited;
end;

destructor TELObject.Destroy();
begin
  inherited;
end;

end.

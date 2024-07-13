unit App_Utilities;

interface

uses
  System.Classes,
  System.DateUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.IniFiles,
  System.IOUtils,
  System.RegularExpressions,
  System.SyncObjs,
  System.SysUtils,
  System.Types,

  Vcl.ExtCtrls,
  Vcl.Graphics,

  Winapi.Windows;

type
  TFileProperties = record
  private
    FFileName: string;
    FMajor: Cardinal;
    FMinor: Cardinal;
    FBuild: Cardinal;
    FRevision: Cardinal;
    procedure GetFileVersion(FileName: string);
  public
    constructor Create(FileName: string);
    property FileName: string read FFileName;
    property Major: Cardinal read FMajor;
    property Minor: Cardinal read FMinor;
    property Build: Cardinal read FBuild;
    property Revision: Cardinal read FRevision;
  end;

  TDelayTask = reference to procedure;

  TDelayCall = class(TObject)
  private
    FDelayTask: TDelayTask;
    FTimer: TTimer;
    procedure OnExpired(Sender: TObject);
  public
    constructor Create(DelayTask: TDelayTask);
    destructor Destroy; override;
    procedure Schedule(MilliSecond: Cardinal);
  end;

  TAvailableCharacterType = (acLowerCase, acUpperCase, acDigits);
  TCharSet = set of TAvailableCharacterType;
  EInvalidCharSetException = class(Exception);

  TPasswordGenerator = class(TObject)
  private
    FIniFileName: string;
    FLength: Integer;
    FCharSet: TCharSet;
    function GetRandomizedCharacter(CharSet: TCharSet): Char;
    function IsUseLowerCase: Boolean;
    function IsUseUpperCase: Boolean;
    function IsUseDigits: Boolean;
    procedure EnableUseDigits(Enable: Boolean);
    procedure EnableUseLowerCase(Enable: Boolean);
    procedure EnableUseUpperCase(Enable: Boolean);
  public
    constructor Create(IniFileName: string);
    function Generate: string;
    function Save: Boolean;
    property Length: Integer read FLength write FLength;
    property UseLowerCase: Boolean read IsUseLowerCase write EnableUseLowerCase;
    property UseUpperCase: Boolean read IsUseUpperCase write EnableUseUpperCase;
    property UseDigits: Boolean read IsUseDigits write EnableUseDigits;
  end;

  TPasswordPreferences = record
  private
    FLength: Integer;
    FUseDigits: Boolean;
    FUseLowerCase: Boolean;
    FUseUpperCase: Boolean;
  public
    constructor Create(Length: Integer; UseDigits, UseLowerCase, UseUpperCase: Boolean);
    property Length: Integer read FLength write FLength;
    property UseDigits: Boolean read FUseDigits write FUseDigits;
    property UseLowerCase: Boolean read FUseLowerCase write FUseLowerCase;
    property UseUpperCase: Boolean read FUseUpperCase write FUseUpperCase;
  end;

  TStringUtils = record
  public
    class function RemoveNewLineCode(Paragraph: string): string; static;
  end;

  TPixel = record
    B: byte;
    G: byte;
    R: byte;
  end;
  PPixel = ^TPixel;
  TPixel1DArray = array of          TPixel;
  TPixel2DArray = array of array of TPixel;

  IScaling = interface
  ['{891E8E7D-6BFD-4AD0-8C9D-02198F6A78DA}']
    procedure Scale(var Source, Target: TPixel1DArray; OrgColCount, OrgRowCount, NewColCount, NewRowCount, Lower, Upper: Integer);
  end;

  TNearestNeighborScaling = class(TInterfacedObject, IScaling)
    procedure Scale(var Source, Target: TPixel1DArray; OrgColCount, OrgRowCount, NewColCount, NewRowCount, Lower, Upper: Integer);
  end;

  TBilinearScaling = class(TInterfacedObject, IScaling)
    procedure Scale(var Source, Target: TPixel1DArray; OrgColCount, OrgRowCount, NewColCount, NewRowCount, Lower, Upper: Integer);
  end;

  TLogLevel = (llError, llDebug);
  TNotifyLog = reference to procedure(Line: string);

  TFileComparer = class(TComparer<string>)
  private
    FFilePath: string;
  public
    constructor Create(FilePath: string);
    function Compare(const FileA, FileB: string): Integer; override;
  end;

  TLog = class(TObject)
  private
    class var FLog: TLog;
  private
    FHandlers: TList<TNotifyLog>;
    FGuard: TCriticalSection;
  protected
    FFilePath: string;
    FFileName: string;
    FMaxFileNo: Integer;
    FMaxFileSize: Integer;
    FCurrentFileNo: Integer;
    FCurrentFileSize: Integer;
  public
    class function GetInstance: TLog;
    constructor Create;
    destructor Destroy; override;
    procedure AddEventHandler(Handler: TNotifyLog); virtual;
    procedure Open(MemIniFile: TMemIniFile); virtual;
    procedure Close; virtual;
    procedure Post(Sender: TObject; Level: TLogLevel; Message: string); virtual;
  end;

  ENotPermittedException = class(Exception);

  TFileLog = class(TLog)
  private
    procedure OnPostLog(Line: string);
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TInMemoryLog = class(TLog)
  private
    FQueue: TQueue<string>;
    procedure OnPostLog(Line: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Close; override;
  end;

implementation

constructor TFileProperties.Create(FileName: string);
begin
  FFileName := ExtractFileName(FileName);
  GetFileVersion(FileName);
end;

procedure TFileProperties.GetFileVersion(FileName: string);
var
  ToSetToZero, VersionInfoSize: DWORD;
  PBuffer: Pointer;
  PFileInfo: PVSFixedFileInfo;
begin
  VersionInfoSize := GetFileVersionInfoSize(PChar(FileName), ToSetToZero);
  if VersionInfoSize > 0 then
  begin
    // 結果を受け取るためのバッファを確保
    GetMem(PBuffer, VersionInfoSize);
    try
      // ファイルのバージョン情報のリソースを取得
      GetFileVersionInfo(PChar(FileName), 0, VersionInfoSize, PBuffer);
      // ファイルのバージョン情報を取得
      VerQueryValue(PBuffer, PathDelim, Pointer(PFileInfo), VersionInfoSize);

      FMajor := PFileInfo.dwFileVersionMS shr $0010;
      FMinor := PFileInfo.dwFileVersionMS and $FFFF;
      FBuild := PFileInfo.dwFileVersionLS shr $0010;
      FRevision := PFileInfo.dwFileVersionLS and $FFFF;
    finally
      FreeMem(PBuffer);
    end;
  end;
end;

constructor TDelayCall.Create(DelayTask: TDelayTask);
begin
  FDelayTask := DelayTask;

  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.OnTimer := OnExpired;
end;

destructor TDelayCall.Destroy;
begin
  FTimer.Free;
end;

procedure TDelayCall.OnExpired(Sender: TObject);
begin
  FTimer.Enabled := False;

  if Assigned(FDelayTask) then
    FDelayTask;
end;

procedure TDelayCall.Schedule(MilliSecond: Cardinal);
begin
  FTimer.Enabled := False;
  FTimer.Interval := MilliSecond;
  FTimer.Enabled := True;
end;

constructor TPasswordGenerator.Create(IniFileName: string);
const
  SECTION_NAME = 'PASSWORD';
var
  IniFile: TIniFile;
  Value: Integer;
begin
  inherited Create;

  FIniFileName := IniFileName;
  IniFile := TIniFile.Create(FIniFileName);
  try
    FLength := IniFile.ReadInteger(SECTION_NAME, 'LENGTH', 12);

    Value := IniFile.ReadInteger(SECTION_NAME, 'USE_LOWER_CASE', 1);
    if Value <> 0 then
      Include(FCharSet, acLowerCase);

    Value := IniFile.ReadInteger(SECTION_NAME, 'USE_UPPER_CASE', 1);
    if Value <> 0 then
      Include(FCharSet, acUpperCase);

    Value := IniFile.ReadInteger(SECTION_NAME, 'USE_DIGITS', 1);
    if Value <> 0 then
      Include(FCharSet, acDigits);
  finally
    IniFile.Free;
  end;
end;

function TPasswordGenerator.IsUseLowerCase: Boolean;
begin
  Result := acLowerCase in FCharSet;
end;

function TPasswordGenerator.IsUseUpperCase: Boolean;
begin
  Result := acUpperCase in FCharSet;
end;

function TPasswordGenerator.IsUseDigits: Boolean;
begin
  Result := acDigits in FCharSet;
end;

function TPasswordGenerator.GetRandomizedCharacter(CharSet: TCharSet): Char;
const
  ZERO    = $30;
  LOWER_A = $61;
  UPPER_A = $41;
var
  Value: Integer;
begin
  if CharSet = [] then
    raise EInvalidCharSetException.Create('Neither character type is specified.')
  else if CharSet = [acDigits] then
  begin
    Value := Random(10);
    Result := Chr(ZERO + Value);
  end
  else if CharSet = [acLowerCase] then
  begin
    Value := Random(26);
    Result := Chr(LOWER_A + Value);
  end
  else if CharSet = [acUpperCase] then
  begin
    Value := Random(26);
    Result := Chr(UPPER_A + Value);
  end
  else if CharSet = [acLowerCase, acDigits] then
  begin
    Value := Random(36);
    if Value < 10 then
      Result := Chr(ZERO + Value)
    else
      Result := Chr(LOWER_A + Value - 10);
  end
  else if CharSet = [acUpperCase, acDigits] then
  begin
    Value := Random(36);
    if Value < 10 then
      Result := Chr(ZERO + Value)
    else
      Result := Chr(UPPER_A + Value - 10);
  end
  else if CharSet = [acLowerCase, acUpperCase] then
  begin
    Value := Random(52);
    if Value < 26 then
      Result := Chr(LOWER_A + Value)
    else
      Result := Chr(UPPER_A + Value - 26);
  end
  else
  begin
    Value := Random(62);
    if Value < 10 then
      Result := Chr(ZERO + Value)
    else if Value < 36 then
      Result := Chr(LOWER_A + Value - 10)
    else
      Result := Chr(UPPER_A + Value - 36);
  end;
end;

function TPasswordGenerator.Generate: string;
var
  I: Integer;
  Apendable: TStringBuilder;
begin
  if FCharSet = [] then
    raise EInvalidCharSetException.Create('Neither character type is specified.');

  Apendable := TStringBuilder.Create;
  try
    for I := 0 to FLength - 1 do
      Apendable.Append(GetRandomizedCharacter(FCharSet));

    Result := Apendable.ToString;
  finally
    Apendable.Free;
  end;
end;

function TPassWordGenerator.Save: Boolean;
const
  SECTION_NAME = 'PASSWORD';
var
  IniFile: TIniFile;
begin
  IniFile := TIniFile.Create(FIniFileName);
  try
    IniFile.WriteInteger(SECTION_NAME, 'LENGTH', FLength);

    IniFile.WriteBool(SECTION_NAME, 'USE_DIGITS', IsUseDigits);
    IniFile.WriteBool(SECTION_NAME, 'USE_LOWER_CASE', IsUseLowerCase);
    IniFile.WriteBool(SECTION_NAME, 'USE_UPPER_CASE', IsUseUpperCase);
  except
    on E: Exception do
      Exit(False);
  end;
  IniFile.Free;

  Exit(True);
end;

procedure TPasswordGenerator.EnableUseDigits(Enable: Boolean);
begin
  if Enable then
    Include(FCharSet, acDigits)
  else
    Exclude(FCharSet, acDigits);
end;

procedure TPasswordGenerator.EnableUseLowerCase(Enable: Boolean);
begin
  if Enable then
    Include(FCharSet, acLowerCase)
  else
    Exclude(FCharSet, acLowerCase);
end;

procedure TPasswordGenerator.EnableUseUpperCase(Enable: Boolean);
begin
  if Enable then
    Include(FCharSet, acUpperCase)
  else
    Exclude(FCharSet, acUpperCase);
end;

constructor TPasswordPreferences.Create(Length: Integer; UseDigits: Boolean; UseLowerCase: Boolean; UseUpperCase: Boolean);
begin
  FLength := Length;
  FUseDigits := UseDigits;
  FUseLowerCase := UseLowerCase;
  FUseUpperCase := UseUpperCase;
end;

class function TStringUtils.RemoveNewLineCode(Paragraph: string): string;
const
  LF = #$0A; // \n
  CR = #$0D; // \r
var
  Modifiable: TStringBuilder;
  Value: Char;
begin
  Modifiable := TStringBuilder.Create;
  try
    for Value in Paragraph do
      if (Value <> LF) and
         (Value <> CR) then
        Modifiable.Append(Value);

    Result := Modifiable.ToString;
  finally
    Modifiable.Free;
  end;
end;

procedure TNearestNeighborScaling.Scale(var Source, Target: TPixel1DArray; OrgColCount, OrgRowCount, NewColCount, NewRowCount, Lower, Upper: Integer);
begin

  //
  // | x' |   | s_x  0  0 || x |
  // | y' | = |  0  s_y 0 || y |
  // | 1  |   |  0   0  1 || 1 |
  //
  // s_x = |x'| / |x|
  // s_y = |y'| / |y|
  //
  // | x |   | 1/s_x   0   0 || x' |
  // | y | = |   0   1/s_y 0 || y' |
  // | 1 |   |   0     0   1 || 1  |
  //
  // 1/s_x = |x| / |x'| = (Q_x * |x'| + R_x) / |x'|
  // 1/s_y = |y| / |y'| = (Q_y * |y'| + R_y) / |y'|
  //
  // Q_x = |x| div |x'|, R_x = |x| mod |x'|
  // Q_y = |y| div |y'|, R_y = |y| mod |y'|
  //

  var QX := OrgColCount div NewColCount;
  var RX := OrgColCount mod NewColCount;

  var QY := OrgRowCount div NewRowCount;
  var RY := OrgRowCount mod NewRowCount;

  var OrgY := 0;
  var DifY := 0;

  for var NewY := 0 to NewRowCount - 1 do
  begin
    Inc(DifY, RY);
    if DifY > NewRowCount then
    begin
      Inc(OrgY, 1);
      Dec(DifY, NewRowCount);
    end;
    Inc(OrgY, QY);

    if (NewY < Lower) or
       (NewY > Upper) then continue;

    var OrgX := 0;
    var DifX := 0;
  for var NewX := 0 to NewColCount - 1 do
  begin

//OrgX := ((Q_X * ColCount + R_X) * NewX) div ColCount;
//OrgY := ((Q_Y * RowCount + R_Y) * NewY) div RowCount;

    Target[NewY * NewColCount + NewX] := Source[OrgY * OrgColCount + OrgX];
    Inc(DifX, RX);
    if DifX > NewColCount then
    begin
      Inc(OrgX, 1);
      Dec(DifX, NewColCount);
    end;
    Inc(OrgX, QX);
  end;
  end;
end;

{$POINTERMATH ON}
procedure TBiLinearScaling.Scale(var Source, Target: TPixel1DArray; OrgColCount, OrgRowCount, NewColCount, NewRowCount, Lower, Upper: Integer);
var
  UpperPixelLine: PPixel;
  LowerPixelLine: PPixel;
  Value: TPixel;
begin

  //
  // ここに記載のバイリニア法のアルゴリズムは「Understanding Bilinear Image Resizing」
  // (https://chao-ji.github.io/jekyll/update/2018/07/19/BilinearResize.html)を参照のこと。
  //

  for var NewY := 0 to NewRowCount - 1 do
  begin
    if (NewY < Lower) or
       (NewY > Upper) then continue;

    var QY := (NewY * (OrgRowCount - 1)) div (NewRowCount - 1);
    var RY := (NewY * (OrgRowCount - 1)) mod (NewRowCount - 1);

    UpperPixelLine := @Source[QY * OrgColCount];
    if RY <> 0 then Inc(QY);
    LowerPixelLine := @Source[QY * OrgColCount];
  for var NewX := 0 to NewColCount - 1 do
  begin
    var QX := (NewX * (OrgColCount - 1)) div (NewColCount - 1);
    var RX := (NewX * (OrgColCount - 1)) mod (NewColCount - 1);

    var TL := (UpperPixelLine + QX)^; // 左上(A)
    var BL := (LowerPixelLine + QX)^; // 左下(C)
    if RX <> 0 then Inc(QX);
    var TR := (UpperPixelLine + QX)^; // 右上(B)
    var BR := (LowerPixelLine + QX)^; // 右下(D)

    var WX := RX / (NewColCount - 1);
    var WY := RY / (NewRowCount - 1);

    var B := TL.B * (1.0 - WX) * (1.0 - WY) + TR.B * WX * (1.0 - WY) + BL.B * (1.0 - WX) * WY + BR.B * WX * WY;
    var G := TL.G * (1.0 - WX) * (1.0 - WY) + TR.G * WX * (1.0 - WY) + BL.G * (1.0 - WX) * WY + BR.G * WX * WY;
    var R := TL.R * (1.0 - WX) * (1.0 - WY) + TR.R * WX * (1.0 - WY) + BL.R * (1.0 - WX) * WY + BR.R * WX * WY;

    Value.B := byte(Round(B));
    Value.G := byte(Round(G));
    Value.R := byte(Round(R));

    Target[NewY * NewColCount + NewX] := Value;
  end;
  end;
end;

constructor TFileComparer.Create(FilePath: string);
begin
  FFilePath := FilePath;
end;

function TFileComparer.Compare(const FileA, FileB: string): Integer;
var
  LastWriteTimeA: TDateTime;
  LastWriteTimeB: TDateTime;
begin
  LastWriteTimeA := TFile.GetLastWriteTime(FileA);
  LastWriteTimeB := TFile.GetLastWriteTime(FileB);

  if LastWriteTimeA < LastWriteTimeB then
    Result := +1
  else
  if LastWriteTimeA > LastWriteTimeB then
    Result := -1
  else
    Result := 0;
end;

class function TLog.GetInstance: TLog;
begin
  if FLog = nil then
    FLog := TInMemoryLog.Create;

  Result := FLog;
end;

constructor TLog.Create;
begin
  FHandlers := TList<TNotifyLog>.Create;
  FGuard := TCriticalSection.Create;
end;

destructor TLog.Destroy;
begin
  FHandlers.Free;
  FGuard.Free;
end;

procedure TLog.AddEventHandler(Handler: TNotifyLog);
begin
  FHandlers.Add(Handler);
end;

procedure TLog.Open(MemIniFile: TMemIniFile);
const
  SECTION_NAME = 'LOG';
  INI_FILE_EXTENSION = '.log';
  DIGITS = 3;
var
  Filter: TDirectory.TFilterPredicate;
  Files: TStringDynArray;
begin
  FFilePath := MemIniFile.ReadString(SECTION_NAME, 'FilePath', string.Empty);
  FFileName := MemIniFile.ReadString(SECTION_NAME, 'FileName', string.Empty);

  FMaxFileNo   := MemIniFile.ReadInteger(SECTION_NAME, 'MaxFileNo',   0);
  FMaxFileSize := MemIniFile.ReadInteger(SECTION_NAME, 'MaxFileSize', 0);

  Filter := function(const Path: string; const SearchRec: TSearchRec): Boolean
            var
              Name : string;
              No: Integer;
            begin
              Name := SearchRec.Name;

              if not TRegex.IsMatch(Name, Format('%s-[0-9]{%d}.log',
                                  [ FFileName, DIGITS ])) then Exit(False);

              No := Name.Substring(FFileName.Length + 1, DIGITS).ToInteger;
              if No < FMaxFileNo then Result := Boolean(1)
              else                    Result := Boolean(0);
            end;

  Files := TDirectory.GetFiles(FFilePath, Filter);
  if Length(Files) > 0 then
  begin
    TArray.Sort<string>(Files, TFileComparer.Create(FFilePath));

    Self.FCurrentFileNo := Files[0].Substring(Files[0].Length - INI_FILE_EXTENSION.Length - DIGITS, DIGITS).ToInteger;
    Self.FCurrentFileSize := TFile.GetSize(Files[0]);
  end
  else
  begin
    Self.FCurrentFileNo := 0;
    Self.FCurrentFileSize := 0;
  end;
end;

procedure TLog.Close;
begin
end;

procedure TLog.Post(Sender: TObject; Level: TLogLevel; Message: string);
const
  LOG_LEVEL: array [0 .. 1] of string = ('ERROR', 'DEBUG');
var
  Handler: TNotifyLog;
  TimeStamp: TDateTime;
  Line: string;
  Year, Month, Day, Hour, Minute, Second, MilliSecond: Word;
begin
  TimeStamp := Now;

  DecodeDateTime(TimeStamp,
       Year, Month, Day, Hour, Minute, Second, MilliSecond);

  Line := Format('%.4d/%.2d/%.2d %.2d:%.2d:%.2d.%.3d (%d) [%s]: %s', [ Year, Month, Day, Hour, Minute, Second, MilliSecond, GetTickCount, LOG_LEVEL[Ord(Level)], Message ]);

  FGuard.Enter;
  for Handler in FHandlers do Handler(Line);
  FGuard.Leave;
end;

constructor TFileLog.Create;
begin
  inherited Create;
  AddEventHandler(OnPostLog);
end;

destructor TFileLog.Destroy;
begin
  inherited Destroy;
end;

procedure TFileLog.OnPostLog(Line: string);
var
  FileName: string;
  IsAppend: Boolean;
  Writer: TTextWriter;
begin
  FileName := TPath.Combine(FFilePath,
                          Format('%s-%.3d.log', [ FFileName, FCurrentFileNo ]));

  if FCurrentFileSize > 0 then IsAppend := True
  else                         IsAppend := False;

  Writer := TStreamWriter.Create(FileName, IsAppend);
  try
    Writer.WriteLine(Line);
  finally
    Writer.Free;
  end;
end;

constructor TInMemoryLog.Create;
begin
  inherited Create;
  FQueue := TQueue<string>.Create;
  AddEventHandler(OnPostLog);
end;

destructor TInMemoryLog.Destroy;
begin
  Close;
  FQueue.Free;
  inherited Destroy;
end;

procedure TInMemoryLog.OnPostLog(Line: string);
begin
  FQueue.Enqueue(Line);
end;

procedure TInMemoryLog.Close;
var
  FileName: string;
  IsAppend: Boolean;
  Writer: TTextWriter;
begin
  FileName := TPath.Combine(FFilePath,
                          Format('%s-%.3d.log', [ FFileName, FCurrentFileNo ]));

  if FCurrentFileSize > 0 then IsAppend := True
  else                         IsAppend := False;

  FGuard.Enter;
  Writer := TStreamWriter.Create(FileName, IsAppend);
  try
    while FQueue.Count > 0 do
      Writer.WriteLine(FQueue.Dequeue);
  finally
    Writer.Free;
  end;
  FGuard.Leave;
end;

initialization
  Randomize;

finalization
  TLog.FLog.Free;

end.

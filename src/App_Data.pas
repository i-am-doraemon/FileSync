unit App_Data;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.JSON.Serializers,
  System.JSON.Types,
  System.Math,
  System.SysUtils,
  System.Types;

type
  TFileMeta = record
  private
    FIdNo: Integer;
    FName: string;
    FHash: string;
    FSize: UInt64;
    function GetHash: string;
    function GetSize: UInt64;
  public
    constructor Create(Path: string); overload;
    constructor Create(IdNo: Integer; Name, Hash: string; Size: UInt64); overload;
    property IdNo: Integer read FIdNo;
    property Name: string read FName;
    property Hash: string read FHash;
    property Size: Uint64 read FSize;
    class operator Equal(Left, Right: TFileMeta): Boolean;
  end;

  TFileMetaDynArray = array of TFileMeta;

  TFileMetaProgressEvent = reference to procedure(Sender: TObject; Percent: Integer);
  TFileMetaCompleteEvent = reference to procedure(Sender: TObject; FileMetaDynArray: TFileMetaDynArray);
  TFileMetaErrorEvent    = reference to procedure(Sender: TObject; FileName: string);

  TDoRunInBackground = class(TThread)
  private
    FFiles: TStringDynArray;
    FProgressEvent: TFileMetaProgressEvent;
    FCompleteEvent: TFileMetaCompleteEvent;
    FErrorEvent: TFileMetaErrorEvent;
    procedure FireErrorEvent(Cause: string);
    procedure FireProgressEvent(Count, Total: Integer);
    procedure FireCompleteEvent(FileMetaDynArray: TFileMetaDynArray);
  protected
    procedure Execute; override;
  public
    constructor Create(Files: TStringDynArray; ProgressEvent: TFileMetaProgressEvent;
                                               CompleteEvent: TFileMetaCompleteEvent;
                                               ErrorEvent: TFileMetaErrorEvent);
  end;

  TFileMetaExecutor = record
  private
    FFiles: TStringDynArray;
    FOnProgress: TFileMetaProgressEvent;
    FOnComplete: TFileMetaCompleteEvent;
    FOnError: TFileMetaErrorEvent;
    FThread: TThread;
  public
    constructor Create(Files: TStringDynArray);
    function Start: Boolean;
    procedure Cancel;
    property OnProgress: TFileMetaProgressEvent read FOnProgress write FOnProgress;
    property OnComplete: TFileMetaCompleteEvent read FOnComplete write FOnComplete;
    property OnError: TFileMetaErrorEvent read FOnError write FOnError;
  end;

  TFileComparison = record
    Unique: Integer;
    Result: string;
    Sha256: string;
    FileNameA: string;
    FileNameB: string;
    constructor Create(Unique: Integer; Result, Sha256, FileNameA, FileNameB: string);
  end;

  TFileComparisonList = array of TFileComparison;

  TComparisonResult = record
    Total: Integer;
    FolderA: string;
    FolderB: string;
    FileComparisonList: TFileComparisonList;
  end;

  TFolderComparisonCompleteEvent = reference to procedure(Sender: TObject; IdenticalA, IdenticalB, Left, Right: TList<TFileMeta>);

  TFolderComparator = class(TObject)
  private
    FFolderA: string;
    FFolderB: string;

    FFiles1: TStringDynArray;
    FFiles2: TStringDynArray;

    FExecutor1: TFileMetaExecutor;
    FExecutor2: TFileMetaExecutor;

    FFileHash1: TFileMetaDynArray;
    FFileHash2: TFileMetaDynArray;

    // 比較結果

    FIdenticalL: TList<TFileMeta>; // 同一(左側)
    FIdenticalR: TList<TFileMeta>; // 同一(右側)
    FOnlyL: TList<TFileMeta>;      // 左のみ
    FOnlyR: TList<TFileMeta>;      // 右のみ

    FFolderComparisonCompleteEvent: TFolderComparisonCompleteEvent;

    function Remake(X: TFileMeta; var Count: Integer): TFileMeta;

    procedure OnProgress1(Sender: TObject; Percent: Integer);
    procedure OnProgress2(Sender: TObject; Percent: Integer);

    procedure OnComplete1(Sender: TObject; FileMetaDynArray: TFileMetaDynArray);
    procedure OnComplete2(Sender: TObject; FileMetaDynArray: TFileMetaDynArray);

    procedure OnError1(Sender: TObject; FileName: string);
    procedure OnError2(Sender: TObject; FileName: string);

    procedure Sort;
  public
    constructor Create(Folder1, Folder2: string);
    destructor Destroy; override;

    function CompareAsync(FolderComparisonCompleteEvent: TFolderComparisonCompleteEvent): Boolean;
    function CreateComparisonResult: TComparisonResult;
    function Save(FileName: string): Boolean;
  end;

implementation

constructor TFileMeta.Create(Path: string);
begin
  if not TFile.Exists(Path) then
    raise Exception.Create(Format('ファイル%sは存在しません。', [Path]));

  FName := Path;
  FHash := GetHash;
  FSize := GetSize;
end;

constructor TFileMeta.Create(IdNo: Integer; Name, Hash: string; Size: UInt64);
begin
  FIdNo := IdNo;
  FName := Name;
  FHash := Hash;
  FSize := Size;
end;

function TFileMeta.GetHash: string;
const
  MAX_READ_SIZE = 1024 * 1024; // 1MByte
  MAX_BUFF_SIZE = 1024 * 1024; // 1MByte
var
  Buffer: TBytes;
  Stream: TStream;
  Remain: Int64;
  NumberOfBytesRead: Integer;
  HashGenerator: THashSHA2;
begin
  SetLength(Buffer, MAX_BUFF_SIZE);

  // ファイルの先頭から最大1Mバイトを読み取る

  HashGenerator := THashSHA2.Create(SHA256);

  Stream := nil;
  try
    try
      Stream :=
          TFileStream.Create(FName, fmOpenRead);

      Remain := Min(Stream.Size, MAX_READ_SIZE);
      while Remain > 0 do begin
        NumberOfBytesRead :=
                    Stream.Read(Buffer, Length(Buffer));
        HashGenerator.Update(Buffer, NumberOfBytesRead);
        Dec(Remain, NumberOfBytesRead);
      end;

      Result := HashGenerator.HashAsString;
    except
      on E: Exception do
        raise E;
    end;
  finally
    Stream.Free;
  end;
end;

function TFileMeta.GetSize: UInt64;
var
  Size: Int64;
begin
  Size := TFile.GetSize(FName);
  if Size > 0 then
    Result := Size
  else
    Result := 0000;
end;

class operator TFileMeta.Equal(Left, Right: TFileMeta): Boolean;
begin
  Result := Left.Hash.Equals(Right.Hash);
end;

constructor TDoRunInBackground.Create(Files: TStringDynArray; ProgressEvent: TFileMetaProgressEvent;
                                                              CompleteEvent: TFileMetaCompleteEvent;
                                                              ErrorEvent: TFileMetaErrorEvent);
const
  SUSPEND_AFTER_THREAD_CREATED = True;
begin
  inherited Create(SUSPEND_AFTER_THREAD_CREATED);

  Self.FFiles := Files;
  Self.FProgressEvent := ProgressEvent;
  Self.FCompleteEvent := CompleteEvent;
  Self.FErrorEvent := ErrorEvent;
end;

procedure TDoRunInBackground.FireErrorEvent(Cause: string);
begin
  if Assigned(FErrorEvent) then
    Synchronize(procedure begin
      FErrorEvent(Self, Cause);
    end);
end;

procedure TDoRunInBackground.FireProgressEvent(Count, Total: Integer);
begin
  if Assigned(FProgressEvent) then
    Synchronize(procedure begin
      FProgressEvent(Self, Round(100 * (Count / Total)));
    end);
end;

procedure TDoRunInBackground.FireCompleteEvent(FileMetaDynArray: TFileMetaDynArray);
begin
  if Assigned(FCompleteEvent) then
    Synchronize(procedure begin
      FCompleteEvent(Self, FileMetaDynArray);
    end);
end;

procedure TDoRunInBackground.Execute;
var
  FileMetaDynArray: TFileMetaDynArray;
  Count: Integer;
begin
  SetLength(FileMetaDynArray, Length(FFiles));

  Count := 0;
  for var Each in FFiles do begin
    if Terminated then Exit;

    try
      FileMetaDynArray[Count] :=
                       TFileMeta.Create(Each);
      Inc(Count);
    except
      try
        Exit;
      finally
        FireErrorEvent(Each);
      end;
    end;

    FireProgressEvent(Count, Length(FFiles));
  end;

  FireCompleteEvent(FileMetaDynArray)
end;

constructor TFileMetaExecutor.Create(Files: TStringDynArray);
begin
  FFiles := Files;

  FOnProgress := nil;
  FOnComplete := nil;
  FOnError    := nil;

  FThread := nil;
end;

function TFileMetaExecutor.Start: Boolean;
const
  Y   = True;
  YES = True;
  NON = False;
var
  Running: Boolean;
begin
  Running := False;

  if Assigned(FThread) then
    if FThread.Started and not FThread.Finished then
      Running := Y
    else
      FThread.Free;

  if Running then
    Result := NON
  else begin
    Result  := YES;
    FThread := TDoRunInBackground.Create(FFiles, FOnProgress,
                                                 FOnComplete, FOnError);
    FThread.Start;
  end;
end;

procedure TFileMetaExecutor.Cancel;
begin
  if Assigned(FThread) then begin
    if FThread.Started and not FThread.Finished then begin
      FThread.Terminate;
      FThread.WaitFor;
    end;
    FreeAndNil(FThread);
  end;
end;

constructor TFileComparison.Create(Unique: Integer; Result, Sha256, FileNameA, FileNameB: string);
begin
  Self.Unique := Unique;
  Self.Result := Result;
  Self.Sha256 := Sha256;
  Self.FileNameA := FileNameA;
  Self.FileNameB := FileNameB;
end;

constructor TFolderComparator.Create(Folder1, Folder2: string);
begin
  inherited Create;

  FFiles1 := TDirectory.GetFiles(Folder1);
  FFiles2 := TDirectory.GetFiles(Folder2);

  FFolderA := Folder1;
  FFolderB := Folder2;

  FIdenticalL := TList<TFileMeta>.Create;
  FIdenticalR := TList<TFileMeta>.Create;

  FOnlyL := TList<TFileMeta>.Create;
  FOnlyR := TList<TFileMeta>.Create;
end;

destructor TFolderComparator.Destroy;
begin
  FIdenticalL.Free;
  FIdenticalR.Free;

  FOnlyL.Free;
  FOnlyR.Free;
end;

procedure TFolderComparator.Sort;
begin
  FIdenticalL.Clear;
  FIdenticalR.Clear;
  FOnlyL.Clear;
  FOnlyR.Clear;

  var Count := 0;

  for var A in FFileHash1 do begin
  for var B in FFileHash2 do begin
    if A = B then begin
      var L := A; // 左
      var R := B; // 右

      L.FIdNo := Count;
      R.FIdNo := Count;

      FIdenticalL.Add(L);
      FIdenticalR.Add(R);
      Inc(Count);
    end;
  end;
  end;

  // 左はあるが右はない場合
  for var A in FFileHash1 do begin
    var Found := False;
  for var B in FFileHash2 do begin
    if A = B then
      Found := True;
  end;
    if not Found then
      FOnlyL.Add(Remake(A, Count));
  end;

  // 右はあるが左はない場合
  for var B in FFileHash2 do begin
    var Found := False;
  for var A in FFileHash1 do begin
    if B = A then
      Found := True;
  end;
    if not Found then
      FOnlyR.Add(Remake(B, Count));
  end;

  FFolderComparisonCompleteEvent(Self, FIdenticalL, FIdenticalR, FOnlyL, FOnlyR);
end;

procedure TFolderComparator.OnProgress1(Sender: TObject; Percent: Integer);
begin
end;

function TFolderComparator.CreateComparisonResult: TComparisonResult;
var
  Total, I, J: Integer;
begin
  Total := FIdenticalL.Count + Self.FOnlyL.Count
                             + Self.FOnlyR.Count;
  Result.Total := Total;

  Result.FolderA := FFolderA;
  Result.FolderB := FFolderB;

  SetLength(Result.FileComparisonList, Total);

  I := 0;
  J := 0;

  while I < FIdenticalL.Count do begin
    Result.FileComparisonList[J] := TFileComparison.Create(FIdenticalL[I].IdNo,
                                                          '同一',
                                                          FIdenticalL[I].Hash,
                                                          FIdenticalL[I].Name,
                                                          FIdenticalR[I].Name);
    Inc(I);
    Inc(J);
  end;

  I := 0;
  while I < FOnlyL.Count do begin
    Result.FileComparisonList[J] := TFileComparison.Create(FOnlyL[I].IdNo,
                                                           '左側のみ',
                                                           FOnlyL[I].Hash,
                                                           FOnlyL[I].Name,
                                                           '');
    Inc(I);
    Inc(J);
  end;

  I := 0;
  while I < FOnlyR.Count do begin
    Result.FileComparisonList[J] := TFileComparison.Create(FOnlyR[I].IdNo,
                                                           '右側のみ',
                                                           FOnlyR[I].Hash,
                                                           '',
                                                           FOnlyR[I].Name);
    Inc(I);
    Inc(J);
  end;
end;

function TFolderComparator.Remake(X: TFileMeta; var Count: Integer): TFileMeta;
begin
  Result := X;
  Result.FIdNo := Count;
  Inc(Count);
end;

function TFolderComparator.Save(FileName: string): Boolean;
var
  TextWriter : TTextWriter;
  JSONSerializer: TJSONSerializer;
  Text: string;
begin
  TextWriter := nil;
  try
    TextWriter := TStreamWriter.Create(FileName);

    JSONSerializer := TJSONSerializer.Create;
    JSONSerializer.Formatting := TJSONFormatting.Indented;
    try
      Text := JSONSerializer.Serialize<TComparisonResult>(CreateComparisonResult);
    finally
      JSONSerializer.Free;
    end;

    TextWriter.Write(Text);
    TextWriter.Free;
  except
    on E: Exception do
      try
        Exit(False);
      finally
        TextWriter.Free;
      end;
  end;
  Exit(True);
end;

function TFolderComparator.CompareASync(FolderComparisonCompleteEvent: TFolderComparisonCompleteEvent): Boolean;
begin
  FFolderComparisonCompleteEvent := FolderComparisonCompleteEvent;

  FExecutor1.Cancel;
  FExecutor2.Cancel;

  FExecutor1 := TFileMetaExecutor.Create(FFiles1);
  FExecutor2 := TFileMetaExecutor.Create(FFiles2);

  FExecutor1.OnProgress := OnProgress1;
  FExecutor2.OnProgress := OnProgress2;

  FExecutor1.OnComplete := OnComplete1;
  FExecutor2.OnComplete := OnComplete2;

  FExecutor1.OnError := OnError1;
  FExecutor2.OnError := OnError2;

  FExecutor1.Start;

  Result := True;
end;

procedure TFolderComparator.OnError1(Sender: TObject; FileName: string);
begin
end;

procedure TFolderComparator.OnError2(Sender: TObject; FileName: string);
begin
end;

procedure TFolderComparator.OnProgress2(Sender: TObject; Percent: Integer);
begin
end;

procedure TFolderComparator.OnComplete1(Sender: TObject; FileMetaDynArray: TFileMetaDynArray);
begin
  FFileHash1 := FileMetaDynArray;
  FExecutor2.Start;
end;

procedure TFolderComparator.OnComplete2(Sender: TObject; FileMetaDynArray: TFileMetaDynArray);
begin
  FFileHash2 := FileMetaDynArray;
  Sort;
end;

end.

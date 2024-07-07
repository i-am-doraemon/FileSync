unit App_Data;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.Math,
  System.SysUtils,
  System.Types;

type
  TFileMeta = record
  private
    FName: string;
    FHash: string;
    FSize: UInt64;
    function GetHash: string;
    function GetSize: UInt64;
  public
    constructor Create(Path: string);
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

  TFolderComparisonCompleteEvent = reference to procedure(Sender: TObject; IdenticalA, IdenticalB, Left, Right: TList<TFileMeta>);

  TFolderComparator = class(TObject)
  private
    FFiles1: TStringDynArray;
    FFiles2: TStringDynArray;

    FExecutor1: TFileMetaExecutor;
    FExecutor2: TFileMetaExecutor;

    FFileHash1: TFileMetaDynArray;
    FFileHash2: TFileMetaDynArray;

    FIdenticalL: TList<TFileMeta>; // 同一(左側)
    FIdenticalR: TList<TFileMeta>; // 同一(右側)
    FOnlyL: TList<TFileMeta>;     // 左のみ
    FOnlyR: TList<TFileMeta>;     // 右のみ

    FFolderComparisonCompleteEvent: TFolderComparisonCompleteEvent;

    procedure OnProgress1(Sender: TObject; Percent: Integer);
    procedure OnProgress2(Sender: TObject; Percent: Integer);

    procedure OnComplete1(Sender: TObject; FileMetaDynArray: TFileMetaDynArray);
    procedure OnComplete2(Sender: TObject; FileMetaDynArray: TFileMetaDynArray);

    procedure OnError1(Sender: TObject; FileName: string);
    procedure OnError2(Sender: TObject; FileName: string);

    procedure Sort;
  public
    constructor Create(Folder1, Folder2: string);
    function CompareAsync(FolderComparisonCompleteEvent: TFolderComparisonCompleteEvent): Boolean;
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

function TFileMeta.GetHash: string;
const
  MAX_READ_SIZE = 1024 * 1024; // 1MByte
var
  Stream: TStream;
  Bytes: TBytes;
  NumberOfBytesReadSuccessfully: Integer;
  HashGenerator: THashSHA2;
begin
  // ファイルの先頭から最大1Mバイトを読み取る

  SetLength(Bytes, MAX_READ_SIZE);

  Stream := nil;
  try
    Stream := TFileStream.Create(FName, fmOpenRead); // 読取専用で開く
    NumberOfBytesReadSuccessfully := Stream.Read(Bytes, Length(Bytes));
    Stream.Free;
  except
    try
      Stream.Free;
    finally
      raise Exception.Create(
              Format('ファイル%sのオープンに失敗しました。', [FName]));
    end;
  end;

  // ハッシュ値を計算する

  HashGenerator := THashSHA2.Create(SHA256);
  HashGenerator.Update(Bytes, NumberOfBytesReadSuccessfully);
  Result := HashGenerator.HashAsString;
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

constructor TFolderComparator.Create(Folder1, Folder2: string);
begin
  inherited Create;

  FFiles1 := TDirectory.GetFiles(Folder1);
  FFiles2 := TDirectory.GetFiles(Folder2);
end;

procedure TFolderComparator.Sort;
begin
  var FileHashA := TList<TFileMeta>.Create;
  var FileHashB := TList<TFileMeta>.Create;

  for var I := 0 to Length(FFileHash1) - 1 do
    FileHashA.Add(FFileHash1[I]);

  for var I := 0 to Length(FFileHash2) - 1 do
    FileHashB.Add(FFileHash2[I]);

  FIdenticalL.Free;
  FIdenticalR.Free;
  FOnlyL.Free;
  FOnlyR.Free;

  FIdenticalL := TList<TFileMeta>.Create;
  FIdenticalR := TList<TFileMeta>.Create;
  FOnlyL := TList<TFileMeta>.Create;
  FOnlyR := TList<TFileMeta>.Create;

  for var A in FileHashA do begin
  for var B in FileHashB do begin
    if A = B then begin
      FIdenticalL.Add(A);
      FIdenticalR.Add(B);
    end;
  end;
  end;

  // 左はあるが右はない場合
  for var A in FileHashA do begin
    var Found := False;
  for var B in FileHashB do begin
    if A = B then
      Found := True;
  end;
    if not Found then
      FOnlyL.Add(A);
  end;

  // 右はあるが左はない場合
  for var B in FileHashB do begin
    var Found := False;
  for var A in FileHashA do begin
    if B = A then
      Found := True;
  end;
    if not Found then
      FOnlyR.Add(B);
  end;

  FFolderComparisonCompleteEvent(Self, FIdenticalL, FIdenticalR, FOnlyL, FOnlyR);

  FileHashA.Free;
  FileHashB.Free;
end;

procedure TFolderComparator.OnProgress1(Sender: TObject; Percent: Integer);
begin
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

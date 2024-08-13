unit App_Data;

interface

uses
  App_Data_Collection,
  App_Utilities,

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
  THashProgressEvent = reference to procedure(Sender: TObject; Percent: Integer);
  THashCompleteEvent = reference to procedure(Sender: TObject; Digests: string);
  THashErrorEvent    = reference to procedure(Sender: TObject; Message: string);

  TDoReadFile = class(TThread)
  private
    FFileName: string;
    FBlockingQueue: TBlockingQueue;
    FProgressEvent: THashProgressEvent;
    FCompleteEvent: THashCompleteEvent;
    FErrorEvent   : THashErrorEvent;
  protected
    procedure Execute; override;
  private
    procedure FireErrorEvent(Message: string);
  public
    constructor Create(FileName: string; BlockingQueue: TBlockingQueue; ProgressEvent: THashProgressEvent;
                                                                        CompleteEvent: THashCompleteEvent; ErrorEvent: THashErrorEvent);
  end;

  TDoCalcHash = class(TThread)
  private
    FFileName: string;
    FBlockingQueue: TBlockingQueue;
    FProgressEvent: THashProgressEvent;
    FCompleteEvent: THashCompleteEvent;
    FErrorEvent   : THashErrorEvent;
  protected
    procedure Execute; override;
  private
    procedure FireCompleteEvent(Digests: string);
  public
    constructor Create(FileName: string; BlockingQueue: TBlockingQueue; ProgressEvent: THashProgressEvent;
                                                                        CompleteEvent: THashCompleteEvent; ErrorEvent: THashErrorEvent);
  end;

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
    property IdNo: Integer read FIdNo;
    property Name: string read FName;
    property Hash: string read FHash;
    property Size: Uint64 read FSize;
    class operator Equal(Left, Right: TFileMeta): Boolean;
  end;

  TFileComparison = record
    Unique: Integer;
    Result: string;
    Sha256: string;
    FileNameA: string;
    FileNameB: string;
    Size: Int64;
    constructor Create(Unique: Integer; Result, Sha256, FileNameA, FileNameB: string; Size: Int64);
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

    FBlockingQueue: TBlockingQueue;

    FDoReadFile: TDoReadFile;
    FDoCalcHash: TDoCalcHash;

    FDelayCallA: TDelayCall;
    FDelayCallB: TDelayCall;

    FFileNamesA: TQueue<string>;
    FFileNamesB: TQueue<string>;

    FFileDigestsA: TList<TFileMeta>;
    FFileDigestsB: TList<TFileMeta>;

    // 比較結果

    FIdenticalL: TList<TFileMeta>; // 同一(左側)
    FIdenticalR: TList<TFileMeta>; // 同一(右側)
    FOnlyL: TList<TFileMeta>;      // 左のみ
    FOnlyR: TList<TFileMeta>;      // 右のみ

    FFolderComparisonCompleteEvent: TFolderComparisonCompleteEvent;

    function Remake(X: TFileMeta; var Count: Integer): TFileMeta;

    procedure Categorize;
    procedure Join;

    procedure SetUpNextDigestA;
    procedure SetUpNextDigestB;

    procedure OnHashErrorA(Sender: TObject; Message: string);
    procedure OnHashErrorB(Sender: TObject; Message: string);

    procedure OnHashCompleteA(Sender: TObject; Digest: string);
    procedure OnHashCompleteB(Sender: TObject; Digest: string);

  public
    constructor Create(Folder1, Folder2: string);
    destructor Destroy; override;

    function CompareAsync(FolderComparisonCompleteEvent: TFolderComparisonCompleteEvent): Boolean;
    function CreateComparisonResult: TComparisonResult;
    function Save(FileName: string): Boolean;
    procedure Cancel;
  end;

implementation

constructor TDoReadFile.Create(FileName: string; BlockingQueue: TBlockingQueue; ProgressEvent: THashProgressEvent;
                                                                                CompleteEvent: THashCompleteEvent; ErrorEvent: THashErrorEvent);
const
  SUSPEND_AFTER_THREAD_CREATED = True;
begin
  inherited Create(SUSPEND_AFTER_THREAD_CREATED);

  FFileName := FileName;
  FBlockingQueue := BlockingQueue;

  FProgressEvent := ProgressEvent;
  FCompleteEvent := CompleteEvent;
  FErrorEvent    := ErrorEvent;
end;

procedure TDoReadFile.FireErrorEvent(Message: string);
begin
  if Assigned(FErrorEvent) then
    Synchronize(procedure begin
      FErrorEvent(Self, Message);
    end);
end;

procedure TDoReadFile.Execute;
const
  YES = True;
  NON = False;
  MAX_READ_SIZE = 1 * 1024 * 1024;
var
  Stream: TStream;
  Position, Size, ReadSize: Int64;
  Done: Boolean;
  P: PChunk;
begin
  Stream := nil;
  try
    Stream := TFileStream.Create(
                                FFileName, fmOpenRead);

    Position := 0;
    Size     := Min(Stream.Size, MAX_READ_SIZE);
    Done := NON;

    while not Terminated and
                         not Done do begin
      P := FBlockingQueue.GetWritableChunk;
      if P = nil then
        continue;
      ReadSize := Min(
           MAX_READ_SIZE - Position, Length(P^.Data));
      P^.Size := Stream.Read(P^.Data, ReadSize);

      Inc(Position, P^.Size);
      if Position < Size then
        Done := NON
      else
        Done := YES;
      P^.Last := Done;
      FBlockingQueue.Enqueue;
    end;
    Stream.Free;
  except on E: Exception do begin
      FireErrorEvent(E.Message);
      Stream.Free;
    end;
  end;
end;

constructor TDoCalcHash.Create(FileName: string; BlockingQueue: TBlockingQueue; ProgressEvent: THashProgressEvent;
                                                                                CompleteEvent: THashCompleteEvent; ErrorEvent: THashErrorEvent);
const
  SUSPEND_AFTER_THREAD_CREATED = True;
begin
  inherited Create(SUSPEND_AFTER_THREAD_CREATED);
  FFileName := FileName;
  FBlockingQueue := BlockingQueue;

  FProgressEvent := ProgressEvent;
  FCompleteEvent := CompleteEvent;
  FErrorEvent    := ErrorEvent;
end;

procedure TDoCalcHash.FireCompleteEvent(Digests: string);
begin
  if Assigned(FCompleteEvent) then
    Synchronize(procedure begin
      FCompleteEvent(Self, Digests);
    end);
end;

procedure TDoCalcHash.Execute;
const
  YES = True;
  NON = False;
begin
  var Done := NON;
  var Hash := THashSHA2.Create(SHA256);

  while not Terminated and not Done do begin
    var P := FBlockingQueue.GetReadableChunk;

    if P = nil then
      continue;

    if P^.Last then
      Done := YES;

    Hash.Update(P^.Data, P^.Size);
    FBlockingQueue.Dequeue;
  end;

  if Done then
    FireCompleteEvent(Hash.HashAsString);
end;

constructor TFileMeta.Create(Path: string);
begin
  if not TFile.Exists(Path) then
    raise Exception.Create(Format('ファイル%sは存在しません。', [Path]));

  FName := Path;
//FHash := GetHash;
  FSize := GetSize;
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
  Result := (Left.Hash.Equals(Right.Hash)) and (Left.Size = Right.Size);
end;

constructor TFileComparison.Create(Unique: Integer; Result, Sha256, FileNameA, FileNameB: string; Size: Int64);
begin
  Self.Unique := Unique;
  Self.Result := Result;
  Self.Sha256 := Sha256;
  Self.FileNameA := FileNameA;
  Self.FileNameB := FileNameB;
  Self.Size := Size;
end;

constructor TFolderComparator.Create(Folder1, Folder2: string);
const
  QUEUE_SIZE = 16;
begin
  inherited Create;

  FFileDigestsA := TList<TFileMeta>.Create;
  FFileDigestsB := TList<TFileMeta>.Create;

  FFileNamesA := TQueue<string>.Create;
  FFileNamesB := TQueue<string>.Create;

  for var Each in TDirectory.GetFiles(Folder1) do FFileNamesA.Enqueue(Each);
  for var Each in TDirectory.GetFiles(Folder2) do FFileNamesB.Enqueue(Each);

  FFolderA := Folder1;
  FFolderB := Folder2;

  FBlockingQueue := TBlockingQueue.Create(QUEUE_SIZE);

  FDelayCallA := TDelayCall.Create(SetUpNextDigestA);
  FDelayCallB := TDelayCall.Create(SetUpNextDigestB);

  FIdenticalL := TList<TFileMeta>.Create;
  FIdenticalR := TList<TFileMeta>.Create;

  FOnlyL := TList<TFileMeta>.Create;
  FOnlyR := TList<TFileMeta>.Create;
end;

destructor TFolderComparator.Destroy;
begin
  FDelayCallA.Free;
  FDelayCallB.Free;

  Join;

  FFileDigestsA.Free;
  FFileDigestsB.Free;

  FIdenticalL.Free;
  FIdenticalR.Free;

  FOnlyL.Free;
  FOnlyR.Free;

  FFileNamesA.Free;
  FFileNamesB.Free;

  FBlockingQueue.Free;
end;

procedure TFolderComparator.Categorize;
begin
  FIdenticalL.Clear;
  FIdenticalR.Clear;
  FOnlyL.Clear;
  FOnlyR.Clear;

  var Count := 0;

  for var A in FFileDigestsA do begin
  for var B in FFileDigestsB do begin
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
  for var A in FFileDigestsA do begin
    var Found := False;
  for var B in FFileDigestsB do begin
    if A = B then
      Found := True;
  end;
    if not Found then
      FOnlyL.Add(Remake(A, Count));
  end;

  // 右はあるが左はない場合
  for var B in FFileDigestsB do begin
    var Found := False;
  for var A in FFileDigestsA do begin
    if B = A then
      Found := True;
  end;
    if not Found then
      FOnlyR.Add(Remake(B, Count));
  end;

  FFolderComparisonCompleteEvent(Self, FIdenticalL, FIdenticalR, FOnlyL, FOnlyR);
end;

procedure TFolderComparator.Join;
begin
  if Assigned(FDoReadFile) then begin
    FDoReadFile.Terminate;
    FDoReadFile.WaitFor;
    FDoReadFile.Free;
  end;

  if Assigned(FDoCalcHash) then begin
    FDoCalcHash.Terminate;
    FDoCalcHash.WaitFor;
    FDoCalcHash.Free;
  end;

  FDoReadFile := nil;
  FDoCalcHash := nil;
end;

procedure TFolderComparator.SetUpNextDigestA;
begin
  if FFileNamesA.Count > 0 then begin
    Join;
    FBlockingQueue.Reset;

    FDoReadFile := TDoReadFile.Create(FFileNamesA.Peek,
                            FBlockingQueue, nil, OnHashCompleteA, OnHashErrorA);
    FDoCalcHash := TDoCalcHash.Create(FFileNamesA.Peek,
                            FBlockingQueue, nil, OnHashCompleteA, OnHashErrorA);

    FDoReadFile.Start;
    FDoCalcHash.Start;
  end else
    SetUpNextDigestB;
end;

procedure TFolderComparator.SetUpNextDigestB;
begin
  if FFileNamesB.Count > 0 then begin
    Join;
    FBlockingQueue.Reset;

    FDoReadFile := TDoReadFile.Create(FFileNamesB.Peek,
                            FBlockingQueue, nil, OnHashCompleteB, OnHashErrorB);
    FDoCalcHash := TDoCalcHash.Create(FFileNamesB.Peek,
                            FBlockingQueue, nil, OnHashCompleteB, OnHashErrorB);

    FDoReadFile.Start;
    FDoCalcHash.Start;
  end else begin
    Categorize;
    if Assigned(FFolderComparisonCompleteEvent) then
      FFolderComparisonCompleteEvent(Self, FIdenticalL,
                                           FIdenticalR, FOnlyL, FOnlyR);
  end;
end;

procedure TFolderComparator.Cancel;
begin
  FFileNamesA.Clear;
  FFileNamesB.Clear;

  FDelayCallA.Cancel;
  FDelayCallB.Cancel;

  Join;
end;

procedure TFolderComparator.OnHashErrorA(Sender: TObject; Message: string);
const
  ERROR = 'ERROR';
begin
  var Meta := TFileMeta.Create(FFileNamesA.Dequeue);
  Meta.FHash := ERROR;
  FFileDigestsA.Add(Meta);
  FDelayCallA.Schedule(8);
end;

procedure TFolderComparator.OnHashErrorB(Sender: TObject; Message: string);
const
  ERROR = 'ERROR';
begin
  var Meta := TFileMeta.Create(FFileNamesB.Dequeue);
  Meta.FHash := ERROR;
  FFileDigestsB.Add(Meta);
  FDelayCallB.Schedule(8);
end;

procedure TFolderComparator.OnHashCompleteA(Sender: TObject; Digest: string);
begin
  var Meta := TFileMeta.Create(FFileNamesA.Dequeue);
  Meta.FHash := Digest;
  FFileDigestsA.Add(Meta);
  FDelayCallA.Schedule(8);
end;

procedure TFolderComparator.OnHashCompleteB(Sender: TObject; Digest: string);
begin
  var Meta := TFileMeta.Create(FFileNamesB.Dequeue);
  Meta.FHash := Digest;
  FFileDigestsB.Add(Meta);
  FDelayCallB.Schedule(8);
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
                                                          FIdenticalR[I].Name,
                                                          FIdenticalL[I].Size);
    Inc(I);
    Inc(J);
  end;

  I := 0;
  while I < FOnlyL.Count do begin
    Result.FileComparisonList[J] := TFileComparison.Create(FOnlyL[I].IdNo,
                                                           '左側のみ',
                                                           FOnlyL[I].Hash,
                                                           FOnlyL[I].Name,
                                                           '',
                                                           FOnlyL[I].Size);
    Inc(I);
    Inc(J);
  end;

  I := 0;
  while I < FOnlyR.Count do begin
    Result.FileComparisonList[J] := TFileComparison.Create(FOnlyR[I].IdNo,
                                                           '右側のみ',
                                                           FOnlyR[I].Hash,
                                                           '',
                                                           FOnlyR[I].Name,
                                                           FOnlyR[I].Size);
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
  FDelayCallA.Schedule(8);
  Result := True;
end;

end.

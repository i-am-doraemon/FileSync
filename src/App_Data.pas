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
    FMaxReadSize: Int64;
  protected
    procedure Execute; override;
  private
    procedure FireErrorEvent(Message: string);
  public
    constructor Create(FileName: string; BlockingQueue: TBlockingQueue; ProgressEvent: THashProgressEvent;
                                                                        CompleteEvent: THashCompleteEvent; ErrorEvent: THashErrorEvent);
    procedure SetMaxReadSize(MaxReadSize: Int64);
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

  TFolderComparisonProgressEvent = reference to procedure(Sender: TObject; FileName: string; Nth, Total: Integer);
  TFolderComparisonCompleteEvent = reference to procedure(Sender: TObject);

  TFolderComparator = class(TObject)
  private
    FRecursive: Boolean;

    FFolderA: string;
    FFolderB: string;

    FBlockingQueue: TBlockingQueue;

    FDoReadFile: TDoReadFile;
    FDoCalcHash: TDoCalcHash;

    FDelayCallA: TDelayCall;
    FDelayCallB: TDelayCall;

    CalculatingNow: Boolean;

    FFileNamesA: TQueue<string>;
    FFileNamesB: TQueue<string>;

    FFileDigestsA: TList<TFileMeta>;
    FFileDigestsB: TList<TFileMeta>;

    FMaxReadSize: Int64;

    // イベント

    FFolderComparisonProgressEvent: TFolderComparisonProgressEvent;
    FFolderComparisonCompleteEvent: TFolderComparisonCompleteEvent;

    function Remake(X: TFileMeta; var Count: Integer): TFileMeta;
    function GetTotal: Integer;

    procedure Categorize(IdenticalA, IdenticalB, OnlyA, OnlyB: TList<TFileMeta>);
    procedure Join;

    procedure SetUpNextDigestA;
    procedure SetUpNextDigestB;

    procedure OnHashErrorA(Sender: TObject; Message: string);
    procedure OnHashErrorB(Sender: TObject; Message: string);

    procedure OnHashCompleteA(Sender: TObject; Digest: string);
    procedure OnHashCompleteB(Sender: TObject; Digest: string);

  public
    constructor Create(Folder1, Folder2: string; Recursive: Boolean);
    destructor Destroy; override;

    function CompareAsync(FolderComparisonCompleteEvent: TFolderComparisonCompleteEvent): Boolean;
    procedure Cancel;

    function CreateComparisonResult: TComparisonResult;
    function Save(FileName: string): Boolean;

    property MaxReadSize: Int64 read FMaxReadSize write FMaxReadSize;
    property OnProgress: TFolderComparisonProgressEvent read FFolderComparisonProgressEvent write FFolderComparisonProgressEvent;
  end;

implementation

constructor TDoReadFile.Create(FileName: string; BlockingQueue: TBlockingQueue; ProgressEvent: THashProgressEvent;
                                                                                CompleteEvent: THashCompleteEvent; ErrorEvent: THashErrorEvent);
const
  SUSPEND_AFTER_THREAD_CREATED = True;
  MAX_READ_SIZE = 1 * 1024 * 1024; // バイト
begin
  inherited Create(SUSPEND_AFTER_THREAD_CREATED);

  FFileName := FileName;
  FBlockingQueue := BlockingQueue;

  FProgressEvent := ProgressEvent;
  FCompleteEvent := CompleteEvent;
  FErrorEvent    := ErrorEvent;

  FMaxReadSize := MAX_READ_SIZE;
end;

procedure TDoReadFile.SetMaxReadSize(MaxReadSize: Int64);
begin
  if MaxReadSize < 0 then
    FMaxReadSize := $2000000000 // 128GB
  else
    FMaxReadSize := MaxReadSize;
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
var
  Stream: TStream;
  MaxReadSize, Position, Size, ReadSize: Int64;
  Done: Boolean;
  P: PChunk;
begin
  Stream := nil;
  try
    Stream := TFileStream.Create(
                                FFileName, fmOpenRead);

    Position := 0;
    MaxReadSize := FMaxReadSize;
    Size := Min(Stream.Size, MaxReadSize);
    Done := NON;

    while not Terminated and
                         not Done do begin
      P := FBlockingQueue.GetWritableChunk;
      if P = nil then
        continue;
      ReadSize := Min(
              MaxReadSize - Position, Length(P^.Data));
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

constructor TFolderComparator.Create(Folder1, Folder2: string; Recursive: Boolean);
const
  QUEUE_SIZE = 16;
  DEFAULT_READ_SIZE = 1 * 1024 * 1024; // バイト
begin
  inherited Create;

  CalculatingNow := False;

  FFileDigestsA := TList<TFileMeta>.Create;
  FFileDigestsB := TList<TFileMeta>.Create;

  FRecursive := Recursive;

  FFileNamesA := TQueue<string>.Create;
  FFileNamesB := TQueue<string>.Create;

  FFolderA := Folder1;
  FFolderB := Folder2;

  FBlockingQueue := TBlockingQueue.Create(QUEUE_SIZE);

  FDelayCallA := TDelayCall.Create(SetUpNextDigestA);
  FDelayCallB := TDelayCall.Create(SetUpNextDigestB);

  FMaxReadSize := DEFAULT_READ_SIZE;
end;

destructor TFolderComparator.Destroy;
begin
  FDelayCallA.Free;
  FDelayCallB.Free;

  Join;

  FFileDigestsA.Free;
  FFileDigestsB.Free;

  FFileNamesA.Free;
  FFileNamesB.Free;

  FBlockingQueue.Free;
end;

procedure TFolderComparator.Categorize(IdenticalA, IdenticalB, OnlyA, OnlyB: TList<TFileMeta>);
begin
  var Count := 0;

  for var A in FFileDigestsA do begin
  for var B in FFileDigestsB do begin
    if A = B then begin
      var L := A; // 左
      var R := B; // 右

      L.FIdNo := Count;
      R.FIdNo := Count;

      IdenticalA.Add(L);
      IdenticalB.Add(R);
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
      OnlyA.Add(Remake(A, Count));
  end;

  // 右はあるが左はない場合
  for var B in FFileDigestsB do begin
    var Found := False;
  for var A in FFileDigestsA do begin
    if B = A then
      Found := True;
  end;
    if not Found then
      OnlyB.Add(Remake(B, Count));
  end;
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
var
  FileName: string;
begin
  if FFileNamesA.Count > 0 then begin
    Join;
    FBlockingQueue.Reset;

    FileName := FFileNamesA.Peek;

    FDoReadFile := TDoReadFile.Create(FileName,
                            FBlockingQueue, nil, OnHashCompleteA, OnHashErrorA);
    FDoCalcHash := TDoCalcHash.Create(FileName,
                            FBlockingQueue, nil, OnHashCompleteA, OnHashErrorA);

    FDoReadFile.SetMaxReadSize(FMaxReadSize);

    if Assigned(FFolderComparisonProgressEvent) then
      FFolderComparisonProgressEvent(Self, FileName, FFileDigestsA.Count
                                                   + FFileDigestsB.Count, GetTotal);

    FDoReadFile.Start;
    FDoCalcHash.Start;
  end else
    SetUpNextDigestB;
end;

procedure TFolderComparator.SetUpNextDigestB;
var
  FileName: string;
begin
  if FFileNamesB.Count > 0 then begin
    Join;
    FBlockingQueue.Reset;

    FileName := FFileNamesB.Peek;

    FDoReadFile := TDoReadFile.Create(FileName,
                            FBlockingQueue, nil, OnHashCompleteB, OnHashErrorB);
    FDoCalcHash := TDoCalcHash.Create(FileName,
                            FBlockingQueue, nil, OnHashCompleteB, OnHashErrorB);

    FDoReadFile.SetMaxReadSize(FMaxReadSize);

    if Assigned(FFolderComparisonProgressEvent) then
      FFolderComparisonProgressEvent(Self, FileName, FFileDigestsA.Count
                                                   + FFileDigestsB.Count, GetTotal);

    FDoReadFile.Start;
    FDoCalcHash.Start;
  end else begin
    Join;
    if Assigned(FFolderComparisonCompleteEvent) then
      FFolderComparisonCompleteEvent(Self);
    CalculatingNow := False;
  end;
end;

procedure TFolderComparator.Cancel;
begin
  FFileNamesA.Clear;
  FFileNamesB.Clear;

  FDelayCallA.Cancel;
  FDelayCallB.Cancel;

  Join;

  CalculatingNow := False;
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
  var OnlyA := TList<TFileMeta>.Create;
  var OnlyB := TList<TFileMeta>.Create;

  var IdenticalA := TList<TFileMeta>.Create;
  var IdenticalB := TList<TFileMeta>.Create;

  Categorize(IdenticalA, IdenticalB, OnlyA, OnlyB);

  Total := IdenticalA.Count + OnlyA.Count
                            + OnlyB.Count;
  Result.Total := Total;
  Result.FolderA := FFolderA;
  Result.FolderB := FFolderB;

  SetLength(Result.FileComparisonList, Total);

  I := 0;
  J := 0;

  while I < IdenticalA.Count do begin
    Result.FileComparisonList[J] := TFileComparison.Create(IdenticalA[I].IdNo, '同一', IdenticalA[I].Hash, IdenticalA[I].Name, IdenticalB[I].Name, IdenticalA[I].Size);
    Inc(I);
    Inc(J);
  end;

  I := 0;
  while I < OnlyA.Count do begin
    Result.FileComparisonList[J] := TFileComparison.Create(OnlyA[I].IdNo, '左側のみ', OnlyA[I].Hash, OnlyA[I].Name, '', OnlyA[I].Size);
    Inc(I);
    Inc(J);
  end;

  I := 0;
  while I < OnlyB.Count do begin
    Result.FileComparisonList[J] := TFileComparison.Create(OnlyB[I].IdNo, '右側のみ', OnlyB[I].Hash, '', OnlyB[I].Name, OnlyB[I].Size);
    Inc(I);
    Inc(J);
  end;

  OnlyA.Free;
  OnlyB.Free;
  IdenticalA.Free;
  IdenticalB.Free;
end;

function TFolderComparator.Remake(X: TFileMeta; var Count: Integer): TFileMeta;
begin
  Result := X;
  Result.FIdNo := Count;
  Inc(Count);
end;

function TFolderComparator.GetTotal: Integer;
begin
  Result := FFileNamesA.Count
          + FFileNamesB.Count + FFileDigestsA.Count
                              + FFileDigestsB.Count;
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
var
  Option: TSearchOption;
begin
  if CalculatingNow then
    raise Exception.Create('既に比較中です。');

  FFolderComparisonCompleteEvent := FolderComparisonCompleteEvent;

  FFileNamesA.Clear;
  FFileNamesB.Clear;

  if FRecursive then
    Option := TSearchOption.soAllDirectories
  else
    Option := TSearchOption.soTopDirectoryOnly;

  var FilesA := TDirectory.GetFiles(FFolderA, '*', Option);
  var FilesB := TDirectory.GetFiles(FFolderB, '*', Option);

  for var Each in FilesA do FFileNamesA.Enqueue(Each);
  for var Each in FilesB do FFileNamesB.Enqueue(Each);

  FFileDigestsA.Clear;
  FFileDigestsB.Clear;

  CalculatingNow := True;
  FDelayCallA.Schedule(8);
  Result := True;
end;

end.

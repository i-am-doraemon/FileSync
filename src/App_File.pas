unit App_File;

interface

uses
  System.Classes,
  System.Hash,
  System.IOUtils,
  System.SyncObjs,
  System.SysUtils,

  Vcl.Dialogs;

type
  TChunk = record
  public
    Last: Boolean;
    Data: TBytes;
    Size: Integer;
  end;
  PChunk = ^TChunk;

  TChunkDynArray = array of TChunk;

  TBlockingQueue = class(TObject)
  private
    const
    CHUNK_SIZE = 8 * 1024 * 1024; // 16MByte
    var
    FSize: Integer;
    FHead: Integer;
    FTail: Integer;
    FChunkDynArray: TChunkDynArray;

    FGetWritableChunk: TSemaphore;
    FGetReadableChunk: TSemaphore;

    FLock: TCriticalSection;
  public
    constructor Create(N: Integer);
    destructor Destroy; override;

    function GetWritableChunk: PChunk;
    function GetReadableChunk: PChunk;

    procedure Enqueue;
    procedure Dequeue;
  end;

  TFileCopyCompleteEvent = reference to procedure(Sender: TObject);
  TFileCopyProgressEvent = reference to procedure(Sender: TObject; CopiedSize: Int64);
  TFileCopyErrorEvent    = reference to procedure(Sender: TObject);

  TDoRunInBackground1 = class(TThread)
  private
    FBlockingQueue: TBlockingQueue;

    FFileName: string;

    FProgressEvent: TFileCopyProgressEvent;
    FCompleteEvent: TFileCopyCompleteEvent;
    FErrorEvent   : TFileCopyErrorEvent;

    FLastUpdated: Integer;

    procedure FireErrorEvent;
    procedure FireProgressEvent(Position, Size: Int64);
    procedure FireCompleteEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(BlockingQueue: TBlockingQueue;
                       FileName: string;
                       ProgressEvent: TFileCopyProgressEvent;
                       CompleteEvent: TFileCopyCompleteEvent;
                       ErrorEvent   : TFileCopyErrorEvent);
  end;

  TDoRunInBackground2 = class(TThread)
  private
    FBlockingQueue: TBlockingQueue;
  protected
    procedure Execute; override;
  public
    constructor Create(BlockingQueue: TBlockingQueue);
  end;

  TFileCopy = class(TObject)
  private
    FCopySize: Int64;

    FFullPath1: string;
    FFullPath2: string;

    FOnComplete: TFileCopyCompleteEvent;
    FOnProgress: TFileCopyProgressEvent;
    FOnError   : TFileCopyErrorEvent;

    FThread1: TThread;
    FThread2: TThread;

    FBlockingQueue: TBlockingQueue;
  public
    constructor Create;
    destructor Destroy; override;
    function Start(FullPath1, FullPath2: string): Boolean;
    procedure Cancel;
    property OnComplete: TFileCopyCompleteEvent read FOnComplete write FOnComplete;
    property OnProgress: TFileCopyProgressEvent read FOnProgress write FOnProgress;
    property OnError: TFileCopyErrorEvent read FOnError write FOnError;
    property CopySize: Int64 read FCopySize;
  end;

implementation

constructor TDoRunInBackground1.Create(BlockingQueue: TBlockingQueue;
                                       FileName: string;
                                       ProgressEvent: TFileCopyProgressEvent;
                                       CompleteEvent: TFileCopyCompleteEvent;
                                       ErrorEvent   : TFileCopyErrorEvent);
const
  SUSPEND_AFTER_THREAD_CREATED = True;
begin
  inherited Create(SUSPEND_AFTER_THREAD_CREATED);

  Self.FBlockingQueue := BlockingQueue;

  Self.FFileName := FileName;

  Self.FProgressEvent := ProgressEvent;
  Self.FCompleteEvent := CompleteEvent;
  Self.FErrorEvent    := ErrorEvent;

  FLastUpdated := 0;
end;

procedure TDoRunInBackground1.FireErrorEvent;
begin
  if Assigned(FErrorEvent) then
    Synchronize(procedure begin
      FerrorEvent(Self);
    end);
end;

procedure TDoRunInBackground1.FireProgressEvent(Position, Size: Int64);
var
  Percent: Integer;
begin
  Percent := Round(100 * (Position / Size));
  if Percent > FLastUpdated then begin
    if Assigned(FProgressEvent) then
      Queue(procedure begin
        FProgressEvent(Self, Position);
      end);
    FLastUpdated := Percent;
  end;
end;

procedure TDoRunInBackground1.FireCompleteEvent;
begin
  if Assigned(FCompleteEvent) then
    Synchronize(procedure begin
      FCompleteEvent(Self);
    end);
end;

procedure TDoRunInBackground1.Execute;
const
  MAX_READ_SIZE= 16 * 1024 * 1024;
var
  Source: TStream;
  P: PChunk;
  Position, Size: Int64;
begin
  Source := nil;
  try
    Source := TFileStream.Create(FFileName, fmOpenRead);
  except
    try
      Exit;
    finally
      FireErrorEvent;
    end;
  end;

  try
    Position := 0;
    Size := Source.Size;

    while not Terminated and (Position < Size) do begin
      P := FBlockingQueue.GetWritableChunk;

      P^.Size := Source.Read(
                  P^.Data, Length(P.Data));

      Inc(Position, P^.Size);
      FBlockingQueue.Enqueue;

      Self.FireProgressEvent(Position, Size);
    end;

    Source.Free;
    if not Terminated then
      FireCompleteEvent;
  except
    try
      FireErrorEvent;
    finally
      Source.Free;
    end;
  end;
end;

constructor TDoRunInBackground2.Create(BlockingQueue: TBlockingQueue);
const
  SUSPEND_AFTER_THREAD_CREATED = True;
begin
  inherited Create(SUSPEND_AFTER_THREAD_CREATED);
  FBlockingQueue := BlockingQueue;
end;

procedure TDoRunInBackground2.Execute;
var
  P: PChunk;
  Hash: THashSHA2;
begin
  Hash := THashSHA2.Create(SHA256);
  repeat
    P := FBlockingQueue.GetReadableChunk;
    Hash.Update(P^.Data, P^.Size);
    FBlockingQueue.Dequeue;
  until Self.Terminated or (P^.Size < Length(P^.Data));

  if not Terminated then
    Synchronize(procedure begin
      ShowMessage(Hash.HashAsString);
    end);
end;

constructor TFileCopy.Create;
const
  QUEUE_SIZE = 8;
begin
  inherited Create;
  FBlockingQueue := TBlockingQueue.Create(QUEUE_SIZE);
end;

destructor TFileCopy.Destroy;
begin
  Cancel;
  FBlockingQueue.Free;
  inherited Destroy;
end;

function TFileCopy.Start(FullPath1, FullPath2: string): Boolean;
const
  Y = True;
  YES = True;
  NON = False;
var
  Running: Boolean;
begin
  if TPath.IsRelativePath(FullPath1) then
    raise Exception.Create(Format('コピー元「%s」は絶対パスでなければなりません。', [FullPath1]));
  if TPath.IsRelativePath(FullPath2) then
    raise Exception.Create(Format('コピー先「%s」は絶対パスでなければなりません。', [FullPath2]));

  if TFile.Exists(FullPath1) then else
    raise Exception.Create(Format('コピー元「%s」は存在しません。', [FullPath1]));

  if TFile.Exists(FullPath2) then
    raise Exception.Create(Format('コピー先「%s」が既にあります。', [FullPath2]));

  Running := False;

  if Assigned(FThread1) then
    if FThread1.Started and not FThread1.Finished then
      Running := Y
    else
      FThread1.Free;

  if Running then
    Result := NON
  else begin
    Result := YES;

    Self.FFullPath1 := FullPath1;
    Self.FFullPath2 := FullPath2;
    FCopySize := TFile.GetSize(FullPath1);

    FThread1 := TDoRunInBackground1.Create(FBlockingQueue,
                                           FFullPath1,
                                           FOnProgress,
                                           FOnComplete,
                                           FOnError);

    FThread2 := TDoRunInBackground2.Create(FBlockingQueue);

    FThread1.Start;
    FThread2.Start;
  end;
end;

procedure TFileCopy.Cancel;
var
  P: PChunk;
begin
  if Assigned(FThread1) then begin
    if FThread1.Started and not FThread1.Finished then begin
      FThread1.Terminate;
      FThread1.WaitFor;
    end;
    FreeAndNil(FThread1);
  end;

  P := FBlockingQueue.GetWritableChunk;
  P^.Size := 0;
  FBlockingQueue.Enqueue;

  if Assigned(FThread2) then begin
    if FThread2.Started and not FThread2.Finished then begin
      FThread2.Terminate;
      FThread2.WaitFor;
    end;
    FreeAndNil(FThread2);
  end;
end;

constructor TBlockingQueue.Create(N: Integer);
begin
  inherited Create;

  FSize := N;
  FHead := 0;
  FTail := 0;

  SetLength(FChunkDynArray, N);
  for var I := 0 to N - 1 do
    SetLength(FChunkDynArray[I].Data, CHUNK_SIZE);

  // 利用可能なリソースはN個
  FGetWritableChunk := TSemaphore.Create(nil, N, N, string.Empty);
  // 利用可能なリソースは0個
  FGetReadableChunk := TSemaphore.Create(nil, 0, N, string.Empty);

  FLock := TCriticalSection.Create;
end;

destructor TBlockingQueue.Destroy;
begin
  FreeAndNil(FLock);

  FreeAndNil(FGetReadableChunk);
  FreeAndNil(FGetWritableChunk);

  for var  I := 0 to FSize - 1 do
    FChunkDynArray[I].Data := nil;
  FChunkDynArray := nil;

  inherited Destroy;
end;

function TBlockingQueue.GetWritableChunk: PChunk;
begin
  FGetWritableChunk.Acquire;

  FLock.Enter;
  Result := @FChunkDynArray[FHead];
  FLock.Leave;
end;

procedure TBlockingQueue.Enqueue;
begin
  FLock.Enter;
  FHead := (FHead + 1) mod FSize;
  FLock.Leave;

  Self.FGetReadableChunk.Release;
end;

function TBlockingQueue.GetReadableChunk: PChunk;
begin
  FGetReadableChunk.Acquire;

  FLock.Enter;
  Result := @FChunkDynArray[FTail];
  FLock.Leave;
end;

procedure TBlockingQueue.Dequeue;
begin
  FLock.Enter;
  FTail := (FTail + 1) mod FSize;
  FLock.Leave;

  Self.FGetWritableChunk.Release;
end;

end.

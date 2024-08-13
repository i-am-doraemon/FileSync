unit App_File;

interface

uses
  App_Data_Collection,

  System.Classes,
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  System.Types;

type
  TFileCopyProgressEvent = reference to procedure(Sender: TObject; CopiedSize: Int64);
  TFileCopyCompleteEvent = reference to procedure(Sender: TObject);
  TFileCopyErrorEvent    = reference to procedure(Sender: TObject);

  TDoRunInBackground1 = class(TThread)
  private
    FBlockingQueue: TBlockingQueue;
    FFileName: string;
    FErrorEvent   : TFileCopyErrorEvent;
    procedure FireErrorEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(BlockingQueue: TBlockingQueue;
                       FileName: string;
                       ErrorEvent   : TFileCopyErrorEvent);
  end;

  TDoRunInBackground2 = class(TThread)
  private
    FBlockingQueue: TBlockingQueue;
    FFileName: string;
    FCopySize: Int64;
    FLastWriteTime: TDateTime;
    FLastUpdateValue: Integer;
    FProgressEvent: TFileCopyProgressEvent;
    FCompleteEvent: TFileCopyCompleteEvent;
    FErrorEvent: TFileCopyErrorEvent;
    procedure FireErrorEvent;
    procedure FireProgressEvent(CopiedSize: Int64);
    procedure FireCompleteEvent(Digest: string);
  protected
    procedure Execute; override;
  public
    constructor Create(BlockingQueue: TBlockingQueue;
                       FileName1: string;
                       FileName2: string;
                       ErrorEvent: TFileCopyErrorEvent;
                       ProgressEvent: TFileCopyProgressEvent;
                       CompleteEvent: TFileCopyCompleteEvent);
  end;

  TSourceDestination = record
  private
    FSource     : string;
    FDestination: string;
  public
    constructor Create(Source, Destination: string); overload;
    constructor Create(Folder1, Folder2, FileName: string); overload;
    property Source: string read FSource;
    property Destination: string read FDestination;
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
                                       ErrorEvent   : TFileCopyErrorEvent);
const
  SUSPEND_AFTER_THREAD_CREATED = True;
begin
  inherited Create(SUSPEND_AFTER_THREAD_CREATED);

  Self.FBlockingQueue := BlockingQueue;
  Self.FFileName := FileName;
  Self.FErrorEvent    := ErrorEvent;
end;

procedure TDoRunInBackground1.FireErrorEvent;
begin
  if Assigned(FErrorEvent) then
    Synchronize(procedure begin
      FerrorEvent(Self);
    end);
end;

procedure TDoRunInBackground1.Execute;
const
  YES = Boolean(1); // 真
  NON = Boolean(0); // 偽
  MAX_READ_SIZE= 16 * 1024 * 1024;
var
  Source: TStream;
  P: PChunk;
  Position, Size: Int64;
  Done: Boolean;
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
    Done := False;
    Position := 0;
    Size := Source.Size;

    while not Terminated
                     and not Done do begin
      P := FBlockingQueue.GetWritableChunk;
      if P = nil then
        continue;

      P^.Size := Source.Read(
                  P^.Data, Length(P.Data));

      Inc(Position, P^.Size);
      if Position < Size then
        Done := NON
      else
        Done := YES;

      P^.Last := Done;
      FBlockingQueue.Enqueue;
    end;

    Source.Free;
  except
    try
      FireErrorEvent;
    finally
      Source.Free;
    end;
  end;
end;

constructor TDoRunInBackground2.Create(BlockingQueue: TBlockingQueue;
                                       FileName1: string;
                                       FileName2: string;
                                       ErrorEvent: TFileCopyErrorEvent;
                                       ProgressEvent: TFileCopyProgressEvent;
                                       CompleteEvent: TFileCopyCompleteEvent);
const
  SUSPEND_AFTER_THREAD_CREATED = True;
begin
  inherited Create(SUSPEND_AFTER_THREAD_CREATED);
  FBlockingQueue := BlockingQueue;

  FCopySize := TFile.GetSize(FileName1);
  FLastWriteTime := TFile.GetLastWriteTime(FileName1);

  FFileName := FileName2;

  FProgressEvent := ProgressEvent;
  FCompleteEvent := CompleteEvent;
  FErrorEvent := ErrorEvent;
end;

procedure TDoRunInBackground2.FireErrorEvent;
begin
  if Assigned(FErrorEvent) then
    Synchronize(procedure begin
      FErrorEvent(Self);
    end);
end;

procedure TDoRunInBackground2.FireProgressEvent(CopiedSize: Int64);
var
  Percent: Integer;
begin
  Percent := Round(100 * (CopiedSize / FCopySize));
  if Percent > FLastUpdateValue then begin
    if Assigned(FProgressEvent) then
      Queue(procedure begin
        FProgressEvent(Self, CopiedSize);
      end);
    FLastUpdateValue := Percent;
  end;
end;

procedure TDoRunInBackground2.FireCompleteEvent(Digest: string);
begin
  if Assigned(FCompleteEvent) then
    Synchronize(procedure begin
      FCompleteEvent(Self);
    end);
end;

procedure TDoRunInBackground2.Execute;
var
  Target: TStream;
  Done: Boolean;
  Count: Integer;
  CopiedSize: Int64;
  P: PChunk;
begin
  Target := nil;
  try
    Target := TFileStream.Create(FFileName, fmCreate);
  except
    try
      Exit;
    finally
      FireErrorEvent;
    end;
  end;

  CopiedSize := 0;
  try
    Done := False;
    while not Terminated and not Done do begin
      P := FBlockingQueue.GetReadableChunk;
      if P = nil then
        continue;

      Count := Target.Write(P^.Data, P^.Size);
      Inc(CopiedSize, Count);
      Done := P^.Last;
      FBlockingQueue.Dequeue;

      FireProgressEvent(CopiedSize);
    end;

    Target.Free;
    if CopiedSize < FCopySize then
      FireErrorEvent
    else if Done then begin
      TFile.SetLastWriteTime(FFileName, FLastWriteTime);
      FireCompleteEvent('コピーしました....');
    end;
  except on E: Exception do
    try
      FireErrorEvent;
    finally
      Target.Free;
    end;
  end;
end;

constructor TSourceDestination.Create(Source, Destination: string);
begin
  FSource      := Source;
  FDestination := Destination;
end;

constructor TSourceDestination.Create(Folder1, Folder2, FileName: string);
begin
  FSource      := TPath.Combine(Folder1, FileName);
  FDestination := TPath.Combine(Folder2, FileName);
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
  YES = Boolean(1);
  NON = Boolean(0);
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

  if Assigned(FThread2) then
    if FThread2.Started and not FThread2.Finished then
      Running := Y
    else
      FThread2.Free;

  if Running then
    Result := NON
  else begin
    Result := YES;

    FBlockingQueue.Reset;

    Self.FFullPath1 := FullPath1;
    Self.FFullPath2 := FullPath2;
    FCopySize := TFile.GetSize(FullPath1);

    FThread1 := TDoRunInBackground1.Create(FBlockingQueue,
                                           FFullPath1,
                                           FOnError);

    FThread2 := TDoRunInBackground2.Create(FBlockingQueue,
                                           FFullPath1,
                                           FFullPath2,
                                           FOnError,
                                           FOnProgress,
                                           FOnComplete);

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

  if Assigned(FThread2) then begin
    if FThread2.Started and not FThread2.Finished then begin
      FThread2.Terminate;
      FThread2.WaitFor;
    end;
    FreeAndNil(FThread2);
  end;
end;

end.

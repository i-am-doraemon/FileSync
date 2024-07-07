unit App_File;

interface

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils;

type
  TFileCopyCompleteEvent = reference to procedure(Sender: TObject);
  TFileCopyProgressEvent = reference to procedure(Sender: TObject; CopiedSize: Int64);
  TFileCopyErrorEvent    = reference to procedure(Sender: TObject);

  TDoRunInBackground = class(TThread)
  private
    FFileName1: string;
    FFileName2: string;

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
    constructor Create(FileName1, FileName2: string;
                       ProgressEvent: TFileCopyProgressEvent;
                       CompleteEvent: TFileCopyCompleteEvent;
                       ErrorEvent   : TFileCopyErrorEvent);
  end;

  TFileCopy = class(TObject)
  private
    FCopySize: Int64;

    FFullPath1: string;
    FFullPath2: string;

    FOnComplete: TFileCopyCompleteEvent;
    FOnProgress: TFileCopyProgressEvent;
    FOnError   : TFileCopyErrorEvent;

    FThread: TThread;
  public
    constructor Create(FullPath1, FullPath2: string);
    destructor Destroy; override;
    function Start: Boolean;
    procedure Cancel;
    property OnComplete: TFileCopyCompleteEvent read FOnComplete write FOnComplete;
    property OnProgress: TFileCopyProgressEvent read FOnProgress write FOnProgress;
    property OnError: TFileCopyErrorEvent read FOnError write FOnError;
    property CopySize: Int64 read FCopySize;
  end;

implementation

constructor TDoRunInBackground.Create(FileName1, FileName2: string;
                                      ProgressEvent: TFileCopyProgressEvent;
                                      CompleteEvent: TFileCopyCompleteEvent;
                                      ErrorEvent   : TFileCopyErrorEvent);
const
  SUSPEND_AFTER_THREAD_CREATED = True;
begin
  inherited Create(SUSPEND_AFTER_THREAD_CREATED);

  Self.FFileName1 := FileName1;
  Self.FFileName2 := FileName2;

  Self.FProgressEvent := ProgressEvent;
  Self.FCompleteEvent := CompleteEvent;
  Self.FErrorEvent    := ErrorEvent;

  FLastUpdated := 0;
end;

procedure TDoRunInBackground.FireErrorEvent;
begin
  if Assigned(FErrorEvent) then
    Synchronize(procedure begin
      FerrorEvent(Self);
    end);
end;

procedure TDoRunInBackground.FireProgressEvent(Position, Size: Int64);
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

procedure TDoRunInBackground.FireCompleteEvent;
begin
  if Assigned(FCompleteEvent) then
    Synchronize(procedure begin
      FCompleteEvent(Self);
    end);
end;

procedure TDoRunInBackground.Execute;
const
  MAX_READ_SIZE= 16 * 1024 * 1024;
var
  Source: TStream;
  Buffer: TBytes;
  Count: Integer;
  Position, Size: Int64;
begin
  Source := nil;
  try
    Source := TFileStream.Create(FFileName1, fmOpenRead);
  except
    try
      Exit;
    finally
      FireErrorEvent;
    end;
  end;

  try
    SetLength(Buffer, MAX_READ_SIZE);

    Position := 0;
    Size := Source.Size;

    while not Terminated and (Position < Size) do begin
      Count := Source.Read(
                     Buffer, Length(Buffer));
      Inc(Position, Count);

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

constructor TFileCopy.Create(FullPath1, FullPath2: string);
begin
  inherited Create;

  if TPath.IsRelativePath(FullPath1) then
    raise Exception.Create(Format('コピー元「%s」は絶対パスでなければなりません。', [FullPath1]));
  if TPath.IsRelativePath(FullPath2) then
    raise Exception.Create(Format('コピー先「%s」は絶対パスでなければなりません。', [FullPath2]));

  if TFile.Exists(FullPath1) then else
    raise Exception.Create(Format('コピー元「%s」は存在しません。', [FullPath1]));

  if TFile.Exists(FullPath2) then
    raise Exception.Create(Format('コピー先「%s」が既にあります。', [FullPath2]));

  Self.FFullPath1 := FullPath1;
  Self.FFullPath2 := FullPath2;

  FCopySize := TFile.GetSize(FullPath1);
end;

destructor TFileCopy.Destroy;
begin
  Cancel;
  inherited Destroy;
end;

function TFileCopy.Start: Boolean;
const
  Y = True;
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
    Result := YES;

    FThread := TDoRunInBackground.Create(FFullPath1,
                                         FFullPath2,
                                         FOnProgress,
                                         FOnComplete,
                                         FOnError);
    FThread.Start;
  end;
end;

procedure TFileCopy.Cancel;
begin
  if Assigned(FThread) then begin
    if FThread.Started and not FThread.Finished then begin
      FThread.Terminate;
      FThread.WaitFor;
    end;
    FreeAndNil(FThread);
  end;
end;

end.

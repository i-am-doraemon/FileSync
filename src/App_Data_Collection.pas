unit App_Data_Collection;

interface

uses
  System.SyncObjs,
  System.SysUtils;

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
    CHUNK_SIZE = 8 * 1024 * 1024; // 8[MByte]
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

    procedure Reset;
  end;

implementation

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

procedure TBlockingQueue.Reset;
const
  TIMEOUT = 10; // [ms]
var
  WhyReturned: TWaitResult;
begin
  // プロデューサーが利用可能なリソースを０にする
  repeat
    WhyReturned := FGetWritableChunk.WaitFor(TIMEOUT);
  until WhyReturned = wrTimeout;

  // コンシューマーが利用可能なリソースを０にする
  repeat
    WhyReturned := FGetReadableChunk.WaitFor(TIMEOUT);
  until WhyReturned = wrTimeout;

  // プロデューサーが利用可能なリソースはN個に設定
  FGetWritableChunk.Release(FSize);

  FHead := 0;
  FTail := 0;
end;

function TBlockingQueue.GetWritableChunk: PChunk;
const
  TIMEOUT = 500; // [ms]
var
  WhyReturned: TWaitResult;
begin
//FGetWritableChunk.Acquire;
  WhyReturned := FGetWritableChunk.WaitFor(TIMEOUT);

  if WhyReturned = wrSignaled then begin
    FLock.Enter;
    Result := @FChunkDynArray[FHead];
    FLock.Leave;
  end
  else Result := nil;
end;

procedure TBlockingQueue.Enqueue;
begin
  FLock.Enter;
  FHead := (FHead + 1) mod FSize;
  FLock.Leave;

  Self.FGetReadableChunk.Release;
end;

function TBlockingQueue.GetReadableChunk: PChunk;
const
  TIMEOUT = 500; // [ms]
var
  WhyReturned: TWaitResult;
begin
//FGetReadableChunk.Acquire;
  WhyReturned := FGetReadableChunk.WaitFor(TIMEOUT);

  if WhyReturned = wrSignaled then begin
    FLock.Enter;
    Result := @FChunkDynArray[FTail];
    FLock.Leave;
  end
  else Result := nil;
end;

procedure TBlockingQueue.Dequeue;
begin
  FLock.Enter;
  FTail := (FTail + 1) mod FSize;
  FLock.Leave;

  Self.FGetWritableChunk.Release;
end;

end.

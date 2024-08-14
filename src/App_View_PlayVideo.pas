unit App_View_PlayVideo;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Variants,

  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Forms,
  Vcl.Graphics,

  Winapi.Messages,
  Winapi.Windows, Vcl.ComCtrls, Vcl.ExtCtrls;

type
  PPUint64 = ^PUInt64;
  TMyVideoInitialize = function: Integer;
  TMyVideoGetCodecId = function(FileName: PAnsiChar): Integer;
  TMyVideoCreateM2tsPipeline = function(PPipeline: PPUInt64): Integer;
  TMyVideoCreateH264Pipeline = function(PPipeline: PPUInt64): Integer;
  TMyVideoCreateH265Pipeline = function(PPipeline: PPUInt64): Integer;
  TMyVideoDeletePipeline = function(PPipeline: PUInt64): Integer;
  TMyVideoPlayback = function(Pipeline: PUInt64; FileName: PAnsiChar; Handle: HWnd): Integer;
  TMyVideoStop = function(Pipeline: PUInt64): Integer;
  TMyVideoGetDuration = function(Pipeline: PUInt64): Integer;
  TMyVideoGetPosition = function(Pipeline: PUInt64): Integer;

  TPlayVideo = class(TForm)
    TrackBar: TTrackBar;
    Panel: TPanel;
    StatusBar: TStatusBar;
    Timer: TTimer;
    procedure OnClose(Sender: TObject; var Action: TCloseAction);
    procedure OnStartPlayingBack(Sender: TObject);
  private
    { Private 宣言 }
    FPipeline: PUInt64;
    FDuration: Integer;
    FPosition: Integer;

    FModule: HMODULE;

    MyVideoInitialize: TMyVideoInitialize;
    MyVideoGetCodecId: TMyVideoGetCodecId;

    MyVideoCreateM2tsPipeline: TMyVideoCreateM2tsPipeline;
    MyVideoCreateH264Pipeline: TMyVideoCreateH264Pipeline;
    MyVideoCreateH265Pipeline: TMyVideoCreateH265Pipeline;
    MyVideoDeletePipeline: TMyVideoDeletePipeline;

    MyVideoPlayback: TMyVideoPlayback;
    MyVideoStop: TMyVideoStop;

    MyVideoGetDuration: TMyVideoGetDuration;
    MyVideoGetPosition: TMyVideoGetPosition;

    function ToHhmmssFormat(Seconds: Integer): string;
    procedure OnPlayingBack(Sender: TObject);
  public
    { Public 宣言 }
    constructor Create(Owner: TComponent);

    function LoadDll: Boolean;
    function FreeDll: Boolean;

    procedure Play(FileName: string);
    procedure Stop;
  end;

implementation

{$R *.dfm}

constructor TPlayVideo.Create(Owner: TComponent);
begin
  inherited Create(Owner);
end;

function TPlayVideo.LoadDll: Boolean;
const
  LIBRARY_NAME = 'libmyvideo.dll';
begin
  Result := False;

  FModule := LoadLibrary(LIBRARY_NAME);
  if FModule <> 0 then begin
    MyVideoInitialize := GetProcAddress(FModule, 'myvideo_initialize');
    MyVideoGetCodecId := GetProcAddress(FModule, 'myvideo_get_codec_id');

    MyVideoCreateM2tsPipeline := GetProcAddress(FModule, 'myvideo_create_m2ts_pipeline');
    MyVideoCreateH264Pipeline := GetProcAddress(FModule, 'myvideo_create_h264_pipeline');
    MyVideoCreateH265Pipeline := GetProcAddress(FModule, 'myvideo_create_h265_pipeline');
    MyVideoDeletePipeline := GetProcAddress(FModule, 'myvideo_delete_pipeline');

    MyVideoPlayback := GetProcAddress(FModule, 'myvideo_playback');
    MyVideoStop := GetProcAddress(FModule, 'myvideo_stop');

    MyVideoGetDuration := GetProcAddress(FModule, 'myvideo_get_duration');
    MyVideoGetPosition := GetProcAddress(FModule, 'myvideo_get_position');
  end else begin
    MyVideoInitialize := nil;
    MyVideoGetCodecId := nil;

    MyVideoCreateM2tsPipeline := nil;
    MyVideoCreateH264Pipeline := nil;
    MyVideoCreateH265Pipeline := nil;
    MyVideoDeletePipeline := nil;

    MyVideoPlayback := nil;
    MyVideoStop := nil;

    MyVideoGetDuration := nil;
    MyVideoGetPosition := nil;
  end;

  if Assigned(MyVideoInitialize) and
     Assigned(MyVideoGetCodecId) and
     Assigned(MyVideoCreateM2tsPipeline) and
     Assigned(MyVideoCreateH264Pipeline) and
     Assigned(MyVideoCreateH265Pipeline) and
     Assigned(MyVideoDeletePipeline) and
     Assigned(MyVideoPlayback) and
     Assigned(MyVideoStop) and
     Assigned(MyVideoGetDuration) and
     Assigned(MyVideoGetPosition) then Result := True;

  if Result then
    MyVideoInitialize;
end;

function TPlayVideo.FreeDll: Boolean;
begin
  if FModule <> 0 then
    FreeLibrary(FModule);
  FModule := 0;
end;

function TPlayVideo.ToHhmmssFormat(Seconds: Integer): string;
var
  H, M, S: Integer;
begin
  H := Seconds div (60 * 60);
  M := Seconds mod (60 * 60) div 60;
  S := Seconds mod (60 * 60) mod 60;

  Result := Format('%.2dh%.2dm%.2ds', [H, M, S]);
end;

procedure TPlayVideo.Play(FileName: string);
const
  CODEC_ID_MPEG = $0002;
  CODEC_ID_H264 = $001B;
  CODEC_ID_H265 = $00AD;
const
  NO_ERROR = 0;
  YES = True;
  NON = False;
var
  Utf8: UTF8String;
  CodecID: Integer;
begin
  Utf8 := FileName;

  CodecId := MyVideoGetCodecId(PAnsiChar(Utf8));
  try
    case CodecId of
      CODEC_ID_MPEG: if MyVideoCreateM2TSPipeline(@FPipeline) <> NO_ERROR then
        raise Exception.Create('MPEGのパイプラインの作成に失敗しました。');
      CODEC_ID_H264: if MyVideoCreateH264Pipeline(@FPipeline) <> NO_ERROR then
        raise Exception.Create('H264のパイプラインの作成に失敗しました。');
      CODEC_ID_H265: if MyVideoCreateH265Pipeline(@FPipeline) <> NO_ERROR then
        raise Exception.Create('H265のパイプラインの作成に失敗しました。');
    else
      raise Exception.Create('サポートされないコーデックです。');
    end;
  except
    on E: Exception do
      try
        Exit;
      finally
        ShowMessage(E.Message);
      end;
  end;

  MyVideoPlayback(FPipeline, PAnsiChar(Utf8), Panel.Handle);
  Timer.Enabled := YES;
  ShowModal;
  Timer.Enabled := NON;
end;

procedure TPlayVideo.Stop;
begin
  MyVideoStop(FPipeline);
  MyVideoDeletePipeline(FPipeline);
end;

procedure TPlayVideo.OnClose(Sender: TObject; var Action: TCloseAction);
begin
  Stop;
end;

procedure TPlayVideo.OnStartPlayingBack(Sender: TObject);
begin
  FDuration := MyVideoGetDuration(FPipeline);
  if FDuration > 0 then
    Timer.OnTimer := OnPlayingBack;
end;

procedure TPlayVideo.OnPlayingBack(Sender: TObject);
var
  Duration: string;
  Position: string;
begin
  FPosition := MyVideoGetPosition(FPipeline);
  if FPosition > 0 then begin
    Duration := ToHhmmssFormat(FDuration);
    Position := ToHhmmssFormat(FPosition);
    StatusBar.SimpleText :=
                        Format('%s/%s', [Position, Duration]);
    TrackBar.Position := Round(100 * (FPosition / FDuration));
  end;
end;

end.

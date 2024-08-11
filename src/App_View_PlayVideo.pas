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
    function ToHhmmssFormat(Seconds: Integer): string;
    procedure OnPlayingBack(Sender: TObject);
  public
    { Public 宣言 }
    constructor Create(Owner: TComponent);
    procedure Play(FileName: string);
    procedure Stop;
  end;
  PPUint64 = ^PUInt64;

  function MyVideoInitialize: Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_initialize';
  function MyVideoGetCodecId(FileName: PAnsiChar): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_get_codec_id';
  function MyVideoCreateM2tsPipeline(PPipeline: PPUInt64): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_create_m2ts_pipeline';
  function MyVideoCreateH264Pipeline(PPipeline: PPUInt64): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_create_h264_pipeline';
  function MyVideoCreateH265Pipeline(PPipeline: PPUInt64): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_create_h265_pipeline';
  function MyVideoDeletePipeline(PPipeline: PUInt64): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_delete_pipeline';
  function MyVideoPlayback(Pipeline: PUInt64; FileName: PAnsiChar; Handle: HWnd): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_playback';
  function MyVideoStop(Pipeline: PUInt64): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_stop';
  function MyVideoGetDuration(Pipeline: PUInt64): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_get_duration';
  function MyVideoGetPosition(Pipeline: PUInt64): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_get_position';

implementation

{$R *.dfm}

constructor TPlayVideo.Create(Owner: TComponent);
begin
  inherited Create(Owner);
  MyVideoInitialize;
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

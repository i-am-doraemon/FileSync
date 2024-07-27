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
    { Private éŒ¾ }
    FPipeline: PInteger;
    FDuration: Integer;
    FPosition: Integer;
    function ToHhmmssFormat(Seconds: Integer): string;
    procedure OnPlayingBack(Sender: TObject);
  public
    { Public éŒ¾ }
    constructor Create(Owner: TComponent);
    procedure Play(FileName: string);
    procedure Stop;
  end;

  PPInteger = ^PInteger;

  function MyVideoInitialize: Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_initialize';
  function MyVideoCreateM2tsPipeline(PPipeline: PPInteger): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_create_m2ts_pipeline';
  function MyVideoCreateH264Pipeline(PPipeline: PPInteger): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_create_h264_pipeline';
  function MyVideoCreateH265Pipeline(PPipeline: PPInteger): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_create_h265_pipeline';
  function MyVideoDeletePipeline(PPipeline: PPInteger): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_delete_pipeline';
  function MyVideoPlayback(Pipeline: PInteger; FileName: PAnsiChar; Handle: HWnd): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_playback';
  function MyVideoStop(Pipeline: PInteger): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_stop';
  function MyVideoGetDuration(Pipeline: PInteger): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_get_duration';
  function MyVideoGetPosition(Pipeline: PInteger): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_get_position';

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
  YES = True;
  NON = False;
var
  Utf8: UTF8String;
begin
  MyVideoCreateM2tsPipeline(@FPipeline);

  Utf8 := FileName;
  MyVideoPlayback(FPipeline, PAnsiChar(Utf8), Panel.Handle);
  Timer.Enabled := YES;
  ShowModal;
  Timer.Enabled := NON;
end;

procedure TPlayVideo.Stop;
begin
  MyVideoStop(FPipeline);
  MyVideoDeletePipeline(@FPipeline);
end;

procedure TPlayVideo.OnClose(Sender: TObject; var Action: TCloseAction);
begin
  Stop;
end;

procedure TPlayVideo.OnStartPlayingBack(Sender: TObject);
var
  Duration: Integer;
  H, M, S: Integer;
begin
  FDuration := MyVideoGetDuration(FPipeline);
  if FDuration > 0 then
    Timer.OnTimer := OnPlayingBack;
end;

procedure TPlayVideo.OnPlayingBack(Sender: TObject);
var
  Duration: string;
  Position: string;
  Percent: Integer;
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

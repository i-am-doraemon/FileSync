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
  Winapi.Windows;

type
  TPlayVideo = class(TForm)
    procedure OnClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private êÈåæ }
    Pipeline: PInteger;
  public
    { Public êÈåæ }
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

implementation

{$R *.dfm}

constructor TPlayVideo.Create(Owner: TComponent);
begin
  inherited Create(Owner);
  MyVideoInitialize;
end;

procedure TPlayVideo.Play(FileName: string);
var
  Utf8: UTF8String;
begin
  MyVideoCreateM2tsPipeline(@Pipeline);

  Utf8 := FileName;
  MyVideoPlayback(Pipeline, PAnsiChar(Utf8), Handle);
  ShowModal;
end;

procedure TPlayVideo.Stop;
begin
  MyVideoStop(Pipeline);
  MyVideoDeletePipeline(@Pipeline);
end;

procedure TPlayVideo.OnClose(Sender: TObject; var Action: TCloseAction);
begin
  Stop;
end;

end.

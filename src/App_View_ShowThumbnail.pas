unit App_View_ShowThumbnail;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.Variants,

  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Forms,
  Vcl.Graphics,

  Vcl.ExtCtrls, Vcl.Imaging.pngimage;

type
  TPixel = record
    R: Byte;
    G: Byte;
    B: Byte;
  end;
  PPixel = ^TPixel;

  TMyVideoThumbnail = record
    W: Integer;
    H: Integer;
    PRGBPixel: PByte;
  end;
  PMyVideoThumbnail = ^TMyVideoThumbnail;

  TShowThumbnail = class(TFrame)
    ScrollBox: TScrollBox;
    Image: TImage;
  private
    { Private êÈåæ }
  public
    { Public êÈåæ }
    constructor Create(Owner: TComponent; UTF16FileName: string);
  end;

  function MyVideoMakeThumbnail(FileName: PAnsiChar; PThumbnail: PMyVideoThumbnail): Integer; stdcall; external 'libmyvideo.dll' name 'myvideo_make_thumbnail';

implementation

{$R *.dfm}

{$POINTERMATH ON}
constructor TShowThumbnail.Create(Owner: TComponent; UTF16FileName: string);
var
  UTF8FileName: UTF8String;
  Thumbnail: TMyVideoThumbnail;
  WhyReturned: Integer;
  Bitmap: TBitmap;
  W, H, X, Y: Integer;
  PRGB: PByte;
  P: PPixel;
  Q: PByte;
begin
  inherited Create(Owner);

  UTF8FileName := UTF16FileName;

  WhyReturned := MyVideoMakeThumbnail(PAnsiChar(UTF8FileName), @Thumbnail);
  if WhyReturned = 0 then begin
    W := Thumbnail.W;
    H := Thumbnail.H;
    PRGB := Thumbnail.PRGBPixel;

    Bitmap := TBitmap.Create(W, H);
    Bitmap.PixelFormat :=  pf24bit;

    Q := Thumbnail.PRGBPixel;
    
    for Y := 0 to H - 1 do begin
      P := Bitmap.ScanLine[Y];
    for X := 0 to W - 1 do begin
      P^.B := Q^;
      Inc(Q);
      P^.G := Q^;
      Inc(Q);
      P^.R := Q^;
      Inc(Q);
      Inc(P);
    end;
    end;

    Image.Picture.Bitmap.Assign(Bitmap);
    Bitmap.Free;

    Image.SetBounds(0, 0, W, H);
  end;
end;

end.

unit App_View_ShowProgress;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Variants,

  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Forms,
  Vcl.Graphics, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls;

type
  TShowProgress = class(TForm)
    Panel: TPanel;
    TaskLabel: TLabel;
    ProgressBar: TProgressBar;
    DoCancel: TButton;
    procedure OnDoCancel(Sender: TObject);
  private
    { Private êÈåæ }
    FOnCancel: TNotifyEvent;
    procedure SetDescription(Text: string);
    procedure SetPosition(P: Integer);
  public
    { Public êÈåæ }
    property Description: string write SetDescription;
    property Position: Integer write SetPosition;
    property OnCancel: TNotifyEvent read FOnCancel write FOnCancel;
  end;

implementation

{$R *.dfm}

procedure TShowProgress.OnDoCancel(Sender: TObject);
begin
  if Assigned(FOnCancel) then
    FOnCancel(Sender);
end;

procedure TShowProgress.SetDescription(Text: string);
begin
  Self.TaskLabel.Caption := Text;
end;

procedure TShowProgress.SetPosition(P: Integer);
begin
  ProgressBar.Position := P;
end;

end.

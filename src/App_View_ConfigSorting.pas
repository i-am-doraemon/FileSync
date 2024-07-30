unit App_View_ConfigSorting;

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
  Winapi.Windows, Vcl.ExtCtrls, Vcl.StdCtrls;

type
  TSortEvent = reference to procedure(Sender: TObject; Key1, Key2, Key3: string);

  TConfigSorting = class(TForm)
    Panel: TPanel;

    Key1Label: TLabel;
    Key2Label: TLabel;
    Key3Label: TLabel;

    DoSpecifyKey1: TComboBox;
    DoSpecifyKey2: TComboBox;
    DoSpecifyKey3: TComboBox;

    DoSort: TButton;
    DoCancel: TButton;
    DoReset: TButton;
    procedure OnDoReset(Sender: TObject);
    procedure OnDoSort(Sender: TObject);
  private
    { Private êÈåæ }
    FOnSort: TSortEvent;
  public
    { Public êÈåæ }
    property OnSort: TSortEvent read FOnSort write FOnSort;
  end;

implementation

{$R *.dfm}

procedure TConfigSorting.OnDoReset(Sender: TObject);
begin
  DoSpecifyKey1.ItemIndex := -1;
  DoSpecifyKey2.ItemIndex := -1;
  DoSpecifyKey3.ItemIndex := -1;
end;

procedure TConfigSorting.OnDoSort(Sender: TObject);
begin
  if Assigned(FOnSort) then
    FOnSort(Self, DoSpecifyKey1.Text, DoSpecifyKey2.Text, DoSpecifyKey3.Text);
end;

end.

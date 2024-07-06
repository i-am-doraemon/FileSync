unit App_View_OpenFolder;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Variants,

  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls;

type
  TCompareEvent = reference to procedure(Sender: TObject; Folder1, Folder2: string);

  TOpenFolder = class(TForm)
    Panel: TPanel;

    Folder1Label: TLabel;
    Folder2Label: TLabel;

    DoInput1stFolder: TEdit;
    DoInput2ndFolder: TEdit;
    DoOpenFolderChooser1: TButton;
    DoOpenFolderChooser2: TButton;

    DoCancel: TButton;
    DoCompare: TButton;

    DoShowFolderChooser: TFileOpenDialog;

    procedure OnDoOpenFolderChooser1(Sender: TObject);
    procedure OnDoOpenFolderChooser2(Sender: TObject);
    procedure OnDoCompare(Sender: TObject);
  private
    { Private êÈåæ }
    FOnCompare: TCompareEvent;
  public
    { Public êÈåæ }
    property OnCompare: TCompareEvent read FOnCompare write FOnCompare;
  end;

implementation

{$R *.dfm}

procedure TOpenFolder.OnDoCompare(Sender: TObject);
begin
  if Assigned(FOnCompare) then
    FOnCompare(Self, DoInput1stFolder.Text, DoInput2ndFolder.Text);
end;

procedure TOpenFolder.OnDoOpenFolderChooser1(Sender: TObject);
begin
  if DoShowFolderChooser.Execute then
    DoInput1stFolder.Text := DoShowFolderChooser.FileName;
end;

procedure TOpenFolder.OnDoOpenFolderChooser2(Sender: TObject);
begin
  if DoShowFolderChooser.Execute then
    DoInput2ndFolder.Text := DoShowFolderChooser.FileName;
end;

end.

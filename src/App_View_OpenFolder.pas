unit App_View_OpenFolder;

interface

uses
  System.Classes,
  System.IniFiles,
  System.SysUtils,
  System.Variants,

  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls;

type
  TCompareEvent = reference to procedure(Sender: TObject; Folder1, Folder2: string; Recursive: Boolean);

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
    DoExchangeFolders: TButton;
    DoIncludeSubfolders: TCheckBox;

    procedure OnDoOpenFolderChooser1(Sender: TObject);
    procedure OnDoOpenFolderChooser2(Sender: TObject);
    procedure OnDoCompare(Sender: TObject);
    procedure OnClose(Sender: TObject; var Action: TCloseAction);
    procedure OnDoExchangeFolders(Sender: TObject);
  private
    { Private êÈåæ }
    FOnCompare: TCompareEvent;
  public
    { Public êÈåæ }
    constructor Create(Owner: TComponent); override;
    property OnCompare: TCompareEvent read FOnCompare write FOnCompare;
  end;

implementation

{$R *.dfm}

constructor TOpenFolder.Create(Owner: TComponent);
const
  INI_FILE_EXTENSION = '.ini';
begin
  inherited Create(Owner);

  var IniFile := TIniFile.Create(ChangeFileExt(Application.ExeName, INI_FILE_EXTENSION));
  try
    DoInput1stFolder.Text := IniFile.ReadString('FOLDER', 'PATH1', string.Empty);
    DoInput2ndFolder.Text := IniFile.ReadString('FOLDER', 'PATH2', string.Empty);
  finally
    IniFile.Free;
  end;
end;

procedure TOpenFolder.OnClose(Sender: TObject; var Action: TCloseAction);
const
  INI_FILE_EXTENSION = '.ini';
begin
  var IniFile := TIniFile.Create(ChangeFileExt(Application.ExeName, INI_FILE_EXTENSION));
  try
    if (DoInput1stFolder.Text <> IniFile.ReadString('FOLDER', 'PATH1', string.Empty)) or
       (DoInput2ndFolder.Text <> IniFile.ReadString('FOLDER', 'PATH2', string.Empty)) then begin
        IniFile.WriteString('FOLDER', 'PATH1', DoInput1stFolder.Text);
        IniFile.WriteString('FOLDER', 'PATH2', DoInput2ndFolder.Text);
      end;
  finally
    IniFile.Free;
  end;
end;

procedure TOpenFolder.OnDoCompare(Sender: TObject);
begin
  if Assigned(FOnCompare) then
    FOnCompare(Self, DoInput1stFolder.Text, DoInput2ndFolder.Text, DoIncludeSubfolders.Checked);
end;

procedure TOpenFolder.OnDoExchangeFolders(Sender: TObject);
begin
  var Folder1 := DoInput1stFolder.Text;
  var Folder2 := DoInput2ndFolder.Text;

  DoInput1stFolder.Text := Folder2;
  DoInput2ndFolder.Text := Folder1;
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

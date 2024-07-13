unit App_Start;

interface

uses
  App_Data,
  App_File,
  App_Utilities,
  App_View_OpenFolder,
  App_View_ShowProgress,

  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils,
  System.TimeSpan,
  System.Variants,

  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.Grids,
  Vcl.Menus,
  Vcl.StdCtrls,

  Winapi.Messages,
  Winapi.Windows;

type
  TStart = class(TForm)
    MainMenu: TMainMenu;
    FileMenu: TMenuItem;
    DoOpen: TMenuItem;
    DoTerminateApp: TMenuItem;
    Grid: TStringGrid;
    StatusBar: TStatusBar;
    PopupMenu: TPopupMenu;
    DoCopyLeftToRight: TMenuItem;
    DoCopyRigthToLeft: TMenuItem;
    procedure OnDoOpen(Sender: TObject);
    procedure OnDoTerminateApp(Sender: TObject);
    procedure OnDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure OnMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure OnDoCopyLeftToRight(Sender: TObject);
    procedure OnDoCopyRigthToLeft(Sender: TObject);
    procedure OnClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private 宣言 }
    FFolderComparator: TFolderComparator;
    FShowProgress: TShowProgress;
    FFileCopy: TFileCopy;
    FLastUpdateTime: TDateTime;
    FLastUpdateSize: Int64;
    FQueue: TQueue<TSourceDestination>;
    FDelayCall: TDelayCall;
    function ContainAll(Col, Top, Bottom: Integer; Key: string): Boolean;
    procedure StartCopyFile;
    procedure OnUpdateFileCopy(Sender: TObject; CopiedBytes: Int64);
    procedure OnFinishFileCopy(Sender: TObject);
    procedure OnCancelFileCopy(Sender: TObject);
    procedure OnFailedFileCopy(Sender: TObject);
    procedure OnCompare(Sender: TObject; Folder1, Folder2: string);
    procedure OnDoneCompareFolders(Sender: TObject; IdenticalA, IdenticalB, Left, Right: TList<TFileMeta>);
  public
    { Public 宣言 }
    constructor Create(Owner: TComponent); override;
  end;

var
  Start: TStart;

implementation

{$R *.dfm}

constructor TStart.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  Grid.Cells[0, 0] := 'No';
  Grid.Cells[1, 0] := '比較結果';
  Grid.Cells[4, 0] := 'ハッシュ値(SHA256)';

  FShowProgress := TShowProgress.Create(Self);
  FShowProgress.OnCancel := OnCancelFileCopy;

  FQueue := TQueue<TSourceDestination>.Create;

  FFileCopy := TFileCopy.Create;
  FFileCopy.OnProgress := OnUpdateFileCopy;
  FFileCopy.OnComplete := OnFinishFileCopy;
  FFileCopy.OnError    := OnFailedFileCopy;

  FDelayCall := TDelayCall.Create(StartCopyFile);
end;

function TStart.ContainAll(Col, Top, Bottom: Integer; Key: string): Boolean;
var
  I: Integer;
begin
  for I := Top to Bottom do
    if not Grid.Cells[Col, I].Contains(Key) then
      Exit(False);
  Exit(True);
end;

procedure TStart.StartCopyFile;
var
  SourceDestination:
                   TSourceDestination;
begin
  SourceDestination := FQueue.Dequeue;

  try
    FLastUpdateTime := Now;
    FLastUpdateSize := 000;

    if not FFileCopy.Start(SourceDestination.Source,
                           SourceDestination.Destination) then
      raise Exception.Create('既に別のファイルコピーが進行中です。');

    FShowProgress.Description := Format('「%s」から「%s」へコピーしてます。', [SourceDestination.Source, SourceDestination.Destination]);
    FShowProgress.ShowModal;
  except on E: Exception do
    try
      FQueue.Clear;
    finally
      ShowMessage(E.Message);
    end;
  end;
end;

procedure TStart.OnDoOpen(Sender: TObject);
var
  OpenFolder: TOpenFolder;
begin
  OpenFolder := TOpenFolder.Create(Self);
  OpenFolder.OnCompare := OnCompare;
  OpenFolder.ShowModal;
end;

procedure TStart.OnUpdateFileCopy(Sender: TObject; CopiedBytes: Int64);
var
  CurrentTime: TDateTime;
  Elapsed: TTimeSpan;
  Increment: Double;
  Throughput: Double;
begin
  CurrentTime := Now;

  // ０除算を防止するため経過時間に１ミリ秒を加える
  Elapsed := TTimeSpan.Subtract(CurrentTime, FLastUpdateTime)
                                                + TTimeSpan.FromMilliseconds(1);
  Increment := CopiedBytes - FLastUpdateSize;

  Throughput := Increment / Elapsed.Milliseconds / 1000.0; // 単位はMByte/sに注意

  StatusBar.SimpleText :=
     Format('ファイルをコピー中です。（スループット: %.1f[MB/s]）', [Throughput]);

  FLastUpdateTime := CurrentTime;
  FLastUpdateSize := CopiedBytes;

  FShowProgress.Position := Round(100 * (CopiedBytes / FFileCopy.CopySize));
end;

procedure TStart.OnFinishFileCopy(Sender: TObject);
begin
  StatusBar.SimpleText := string.Empty;
  FShowProgress.ModalResult := mrOK;

  if FQueue.Count > 0 then
    FDelayCall.Schedule(200);
end;

procedure TStart.OnCancelFileCopy(Sender: TObject);
begin
  FFileCopy.Cancel;
end;

procedure TStart.OnFailedFileCopy(Sender: TObject);
begin
  ShowMessage('ファイルのコピーに失敗しました...');
end;

procedure TStart.OnClose(Sender: TObject; var Action: TCloseAction);
begin
  FDelayCall.Free;
  FFileCopy.Free;
  FQueue.Free;
end;

procedure TStart.OnDoCopyLeftToRight(Sender: TObject);
var
  I: Integer;
  FolderNameA: string;
  FolderNameB: string;
begin
  if MessageDlg('選択したファイルをコピーしますか？', mtCustom, [mbOK, mbCancel], 0) = mrCancel then
    Exit;

  FolderNameA := Grid.Cells[2, 0];
  FolderNameB := Grid.Cells[3, 0];

  FQueue.Clear;
  for I := Grid.Selection.Top to Grid.Selection.Bottom do
    FQueue.Enqueue(TSourceDestination.Create(
             FolderNameA, FolderNameB, Grid.Cells[2, I]));
  StartCopyFile;
end;

procedure TStart.OnDoCopyRigthToLeft(Sender: TObject);
var
  I: Integer;
  FolderNameA: string;
  FolderNameB: string;
begin
  if MessageDlg('選択したファイルをコピーしますか？', mtCustom, [mbOK, mbCancel], 0) = mrCancel then
    Exit;

  FolderNameB := Grid.Cells[2, 0];
  FolderNameA := Grid.Cells[3, 0];

  FQueue.Clear;
  for I := Grid.Selection.Top to Grid.Selection.Bottom do
    FQueue.Enqueue(TSourceDestination.Create(
             FolderNameB, FolderNameA, Grid.Cells[3, I]));
  StartCopyFile;
end;

procedure TStart.OnDoneCompareFolders(Sender: TObject; IdenticalA,
                                                       IdenticalB, Left, Right: TList<TFileMeta>);
begin
  Grid.RowCount := IdenticalA.Count + Left.Count + Right.Count + 1;

  for var I := 0 to IdenticalA.Count - 1 do begin
    Grid.Cells[0, I + 1] := I.ToString;
    Grid.Cells[1, I + 1] := '同一';
    Grid.Cells[2, I + 1] := TPath.GetFileName(IdenticalA[I].Name);
    Grid.Cells[3, I + 1] := TPath.GetFileName(IdenticalB[I].Name);
    Grid.Cells[4, I + 1] := IdenticalA[I].Hash;

    var NameA := TPath.GetFileName(IdenticalA[I].Name);
    var NameB := TPath.GetFileName(IdenticalB[I].Name);
  end;

  for var I := 0 to Left.Count - 1 do begin
    Grid.Cells[0, I + 1 + IdenticalA.Count] := (I + IdenticalA.Count).ToString;
    Grid.Cells[1, I + 1 + IdenticalA.Count] := '左側のみ';
    Grid.Cells[2, I + 1 + IdenticalA.Count] := TPath.GetFileName(Left[I].Name);
    Grid.Cells[3, I + 1 + IdenticalA.Count] := string.Empty;
    Grid.Cells[4, I + 1 + IdenticalA.Count] := Left[I].Hash;
  end;

  for var I := 0 to Right.Count - 1 do begin
    Grid.Cells[0, I + 1 + IdenticalA.Count + Left.Count] := (I + IdenticalA.Count + Left.Count).ToString;
    Grid.Cells[1, I + 1 + IdenticalA.Count + Left.Count] := '右側のみ';
    Grid.Cells[2, I + 1 + IdenticalA.Count + Left.Count] := string.Empty;
    Grid.Cells[3, I + 1 + IdenticalA.Count + Left.Count] := TPath.GetFileName(Right[I].Name);
    Grid.Cells[4, I + 1 + IdenticalA.Count + Left.Count] := Right[I].Hash;
  end;

  StatusBar.SimpleText := string.Empty;
end;

procedure TStart.OnCompare(Sender: TObject; Folder1, Folder2: string);
begin
  Grid.Cells[2, 0] := Folder1;
  Grid.Cells[3, 0] := Folder2;

  FFolderComparator.Free;
  FFolderComparator := TFolderComparator.Create(Folder1, Folder2);

  if FFolderComparator.CompareAsync(OnDoneCompareFolders) then
    StatusBar.SimpleText := '指定されたフォルダ内にある各ファイルのハッシュ値を計算中です...'
  else
    ShowMessage('既に実行中です。');
end;

procedure TStart.OnDoTerminateApp(Sender: TObject);
begin
  Close;
end;

procedure TStart.OnDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
begin
  if ARow > 0 then begin
    var NameA := Grid.Cells[2, ARow];
    var NameB := Grid.Cells[3, ARow];

    if NameA.IsEmpty or
       NameB.IsEmpty or
       NameA.Equals(NameB) then
      inherited
    else begin
      Grid.Canvas.Brush.Color := clRed;
      Grid.Canvas.FillRect(Rect);

      Grid.Canvas.Font.Color := clWhite;
      Grid.Canvas.TextOut(Rect.Left + 6, Rect.Top + 4, Grid.Cells[ACol, ARow]);
    end;
  end
  else
    inherited;
end;

procedure TStart.OnMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
const
  YES = True;
  NON = False;
var
  Col, Row: Integer;
  P: TPoint;
begin
  if Button = mbRight then begin
    Grid.MouseToCell(X, Y, Col, Row);
    if (Row >= Grid.Selection.Top   ) and
       (Row <= Grid.Selection.Bottom) then begin

      if ContainAll(1, Grid.Selection.Top, Grid.Selection.Bottom, '左') then begin
        DoCopyLeftToRight.Enabled := YES;
        DoCopyRigthToLeft.Enabled := NON;
      end else
      if ContainAll(1, Grid.Selection.Top, Grid.Selection.Bottom, '右') then begin
        DoCopyLeftToRight.Enabled := NON;
        DoCopyRigthToLeft.Enabled := YES;
      end else begin
        DoCopyLeftToRight.Enabled := NON;
        DoCopyRigthToLeft.Enabled := NON;
      end;

      P := Grid.ClientToScreen(TPoint.Create(X, Y));
      PopupMenu.Popup(P.X, P.Y);
    end;
  end;
end;

end.

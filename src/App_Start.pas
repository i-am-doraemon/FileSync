unit App_Start;

interface

uses
  App_Data,
  App_File,
  App_Utilities,
  App_View_ConfigSorting,
  App_View_OpenFolder,
  App_View_PlayVideo,
  App_View_ShowProgress,

  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.JSON.Serializers,
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
    DataMenu: TMenuItem;

    Grid: TStringGrid;
    StatusBar: TStatusBar;

    DoOpen: TMenuItem;
    DoSort: TMenuItem;
    DoExit: TMenuItem;

    PopupMenu: TPopupMenu;
    DoCopyLeftToRight: TMenuItem;
    DoCopyRigthToLeft: TMenuItem;
    DoWatchThisVideo : TMenuItem;

    DoShowSaveDialog: TSaveDialog;
    DoShowOpenDialog: TOpenDialog;
    DoImport: TMenuItem;
    DoExport: TMenuItem;

    procedure OnDoOpen(Sender: TObject);
    procedure OnDoSort(Sender: TObject);
    procedure OnDoExit(Sender: TObject);
    procedure OnDoCopyLeftToRight(Sender: TObject);
    procedure OnDoCopyRigthToLeft(Sender: TObject);
    procedure OnDoWatchThisVideo(Sender: TObject);

    procedure OnDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure OnMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

    procedure OnDoExport(Sender: TObject);
    procedure OnDoImport(Sender: TObject);

    procedure OnClose(Sender: TObject; var Action: TCloseAction);

  private
    { Private 宣言 }
    FFolderComparator: TFolderComparator;
    FShowCopyProgress: TShowProgress;
    FShowHashProgress: TShowProgress;
    FFileCopy: TFileCopy;
    FLastUpdateTime: TDateTime;
    FLastUpdateSize: Int64;
    FQueue: TQueue<TSourceDestination>;
    FDelayCall: TDelayCall;
    FVideoPlayer: TPlayVideo;
    FSortPreference: TConfigSorting;
    function ContainAll(Col, Top, Bottom: Integer; Key: string): Boolean;
    function IsMultipleRowSelected(Top, Bottom: Integer): Boolean;
    function Sort(Key1, key2, Key3: string): Boolean;
    function Load(TextReader: TTextReader): Boolean;
    procedure SetGrid(ComparisonResult: TComparisonResult);
    procedure StartCopyFile;
    procedure OnSort(Sender: TObject; Key1, Key2, Key3: string);
    procedure OnUpdateFileCopy(Sender: TObject; CopiedBytes: Int64);
    procedure OnFinishFileCopy(Sender: TObject);
    procedure OnCancelFileCopy(Sender: TObject);
    procedure OnFailedFileCopy(Sender: TObject);
    procedure OnCancelHashCalc(Sender: TObject);
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
  Grid.Cells[4, 0] := 'ファイルサイズ';
  Grid.Cells[5, 0] := 'ハッシュ値(SHA256)';

  FShowCopyProgress := TShowProgress.Create(Self);
  FShowHashProgress := TShowProgress.Create(Self);

  FShowCopyProgress.OnCancel := OnCancelFileCopy;
  FShowHashProgress.OnCancel := OnCancelHashCalc;

  FQueue := TQueue<TSourceDestination>.Create;

  FFileCopy := TFileCopy.Create;
  FFileCopy.OnProgress := OnUpdateFileCopy;
  FFileCopy.OnComplete := OnFinishFileCopy;
  FFileCopy.OnError    := OnFailedFileCopy;

  FDelayCall := TDelayCall.Create(StartCopyFile);

  FVideoPlayer := TPlayVideo.Create(Self);

  FSortPreference := TConfigSorting.Create(Self);
  FSortPreference.OnSort := OnSort;
end;

procedure TStart.OnDoWatchThisVideo(Sender: TObject);
var
  FileName: string;
begin
  if Grid.Cells[1, Grid.Row].Contains('右') then
    FileName := TPath.Combine(Grid.Cells[3, 0], Grid.Cells[3, Grid.Row])
  else
    FileName := TPath.Combine(Grid.Cells[2, 0], Grid.Cells[2, Grid.Row]);

  FVideoPlayer.Play(FileName);
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

function TStart.IsMultipleRowSelected(Top, Bottom: Integer): Boolean;
begin
  if Top < Bottom then
    Result := True
  else
    Result := False;
end;

function TStart.Sort(Key1, key2, Key3: string): Boolean;
  procedure Exchange(RowA, RowB: Integer);
  begin
    for var I := 0 to 5 do begin
      var A := Grid.Cells[I, RowA];
      var B := Grid.Cells[I, RowB];
      Grid.Cells[I, RowA] := B;
      Grid.Cells[I, RowB] := A;
    end;
  end;

  function ToColumnIndex(Key: string): Integer;
  const
    E = -1;
  begin
    if Key.Contains('No') then
      Exit(0)
    else if Key.Contains('結果') then
      Exit(1)
    else if Key.Contains('左側') then
      Exit(2)
    else if Key.Contains('右側') then
      Exit(3)
    else if Key.Contains('ファイル') then
      Exit(4)
    else if Key.Contains('ハッシュ') then
      Exit(5)
    else
      Exit(E);
  end;

  function Compare(RowA, RowB: Integer): Int64;
  const
    IDENTICAL = 0;
  begin
    var List := TList<string>.Create;
    try
      if not Key1.IsEmpty then List.Add(Key1);
      if not Key2.IsEmpty then List.Add(Key2);
      if not Key3.IsEmpty then List.Add(Key3);

      for var Key in List do begin
        var Col := ToColumnIndex(key);
        if Col < 0 then
          raise Exception.Create('存在しない列名に対するソートです...');
        if (Col = 0) or         // No, 又は
           (Col = 4) then begin // ファイルサイズ
          var A := Grid.Cells[Col, RowA].ToInt64;
          var B := Grid.Cells[Col, RowB].ToInt64;
          Result := A - B;
        end else begin
          var A := Grid.Cells[Col, RowA];
          var B := Grid.Cells[Col, RowB];
          Result := A.CompareTo(B);
        end;
        if Result <> IDENTICAL then
          break;
      end;
    finally
      List.Free;
    end;
  end;
begin
  // バブルソートで並び替え
  for var I := 1 to Grid.RowCount - 1     do begin
  for var J := 1 to Grid.RowCount - 1 - I do begin
    if Compare(J, J + 1) > 0 then
      Exchange(J, J + 1);
  end;
  end;

  Result := True;
end;

function TStart.Load(TextReader: TTextReader): Boolean;
begin
  var Serializer := TJSONSerializer.Create;
  try
    try
      SetGrid(Serializer.Deserialize
                      <TComparisonResult>(TextReader));
    except
      on E: Exception do
        Exit(False);
    end;
  finally
    Serializer.Free;
  end;
  Exit(True);
end;

procedure TStart.SetGrid(ComparisonResult: TComparisonResult);
begin
  Grid.RowCount := ComparisonResult.Total + 1;

  Grid.Cells[2, 0] := ComparisonResult.FolderA;
  Grid.Cells[3, 0] := ComparisonResult.FolderB;

  var I := 1;
  for var Each in ComparisonResult.FileComparisonList do begin
    Grid.Cells[0, I] := Each.Unique.ToString;
    Grid.Cells[1, I] := Each.Result;
    Grid.Cells[2, I] := TPath.GetFileName(Each.FileNameA);
    Grid.Cells[3, I] := TPath.GetFileName(Each.FileNameB);
    Grid.Cells[4, I] := Each.Size.ToString;
    Grid.Cells[5, I] := Each.Sha256;
    Inc(I);
  end;
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

    FShowCopyProgress.Description := Format('「%s」から「%s」へコピーしてます。', [SourceDestination.Source, SourceDestination.Destination]);
    FShowCopyProgress.ShowModal;
  except on E: Exception do
    try
      FQueue.Clear;
    finally
      ShowMessage(E.Message);
    end;
  end;
end;

procedure TStart.OnSort(Sender: TObject; Key1, Key2, Key3: string);
begin
  Sort(Key1, Key2, Key3);
end;

procedure TStart.OnDoOpen(Sender: TObject);
var
  OpenFolder: TOpenFolder;
begin
  OpenFolder := TOpenFolder.Create(Self);
  OpenFolder.OnCompare := OnCompare;
  OpenFolder.ShowModal;
end;

procedure TStart.OnDoSort(Sender: TObject);
begin
  FSortPreference.ShowModal;
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

  FShowCopyProgress.Position := Round(100 * (CopiedBytes / FFileCopy.CopySize));
end;

procedure TStart.OnFinishFileCopy(Sender: TObject);
begin
  StatusBar.SimpleText := string.Empty;
  FShowCopyProgress.ModalResult := mrOK;

  if FQueue.Count > 0 then
    FDelayCall.Schedule(200);
end;

procedure TStart.OnCancelFileCopy(Sender: TObject);
begin
  FFileCopy.Cancel;
end;

procedure TStart.OnCancelHashCalc(Sender: TObject);
begin
  FFolderComparator.Cancel;
  StatusBar.SimpleText := string.Empty;
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
             FolderNameA, FolderNameB, Grid.Cells[3, I]));
  StartCopyFile;
end;

procedure TStart.OnDoExport(Sender: TObject);
begin
  if DoShowSaveDialog.Execute then
    FFolderComparator.Save(DoShowSaveDialog.FileName);
end;

procedure TStart.OnDoImport(Sender: TObject);
begin
  if DoShowOpenDialog.Execute then begin
    var TextReader := TStreamReader.Create(DoShowOpenDialog.FileName);
    try
      Load(TextReader);
    finally
      TextReader.Free;
    end;
  end;
end;

procedure TStart.OnDoneCompareFolders(Sender: TObject; IdenticalA,
                                                       IdenticalB, Left, Right: TList<TFileMeta>);
begin
  SetGrid(FFolderComparator.CreateComparisonResult);
  StatusBar.SimpleText := string.Empty;
  FShowHashProgress.ModalResult := mrOk;
end;

procedure TStart.OnCompare(Sender: TObject; Folder1, Folder2: string);
begin
  Grid.Cells[2, 0] := Folder1;
  Grid.Cells[3, 0] := Folder2;

  FFolderComparator.Free;
  FFolderComparator := TFolderComparator.Create(Folder1, Folder2);

  if FFolderComparator.CompareAsync(OnDoneCompareFolders) then begin
    StatusBar.SimpleText := '指定されたフォルダ内にある各ファイルのハッシュ値を計算中です...';
    FShowHashProgress.ShowModal;
  end else
    ShowMessage('既に実行中です。');
end;

procedure TStart.OnDoExit(Sender: TObject);
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

      if IsMultipleRowSelected(Grid.Selection.Top, Grid.Selection.Bottom) then
        DoWatchThisVideo.Enabled := NON
      else
        if Grid.Cells[1, Grid.Row].IsEmpty then
          Self.DoWatchThisVideo.Enabled := NON
        else
          Self.DoWatchThisVideo.Enabled := YES;

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

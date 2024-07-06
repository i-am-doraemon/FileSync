program FileSync;

uses
  Vcl.Forms,
  App_Start in 'src\App_Start.pas' {Start},
  App_View_OpenFolder in 'src\App_View_OpenFolder.pas' {OpenFolder},
  App_Data in 'src\App_Data.pas',
  App_File in 'src\App_File.pas',
  App_View_ShowProgress in 'src\App_View_ShowProgress.pas' {ShowProgress};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TStart, Start);
  Application.Run;
end.

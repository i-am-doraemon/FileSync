object ShowProgress: TShowProgress
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #36914#34892#20013'...'
  ClientHeight = 122
  ClientWidth = 372
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object Panel: TPanel
    Left = 0
    Top = 0
    Width = 372
    Height = 122
    Align = alClient
    TabOrder = 0
    ExplicitHeight = 256
    object TaskLabel: TLabel
      Left = 16
      Top = 16
      Width = 169
      Height = 15
      Caption = #12371#12371#12395#36914#34892#20013#12398#12479#12473#12463#12434#26360#12365#12414#12377'...'
    end
    object ProgressBar: TProgressBar
      Left = 16
      Top = 45
      Width = 337
      Height = 17
      TabOrder = 0
    end
    object DoCancel: TButton
      Left = 278
      Top = 80
      Width = 75
      Height = 25
      Caption = #12461#12515#12531#12475#12523
      ModalResult = 2
      TabOrder = 1
      OnClick = OnDoCancel
    end
  end
end

object OpenFolder: TOpenFolder
  Left = 0
  Top = 0
  BorderIcons = []
  Caption = #12501#12457#12523#12480#12434#38283#12367
  ClientHeight = 202
  ClientWidth = 500
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnClose = OnClose
  TextHeight = 15
  object Panel: TPanel
    Left = 0
    Top = 0
    Width = 500
    Height = 202
    Align = alClient
    TabOrder = 0
    ExplicitWidth = 496
    ExplicitHeight = 201
    object Folder1Label: TLabel
      Left = 16
      Top = 16
      Width = 88
      Height = 15
      Caption = #65297#30058#30446#12398#12501#12457#12523#12480
    end
    object Folder2Label: TLabel
      Left = 16
      Top = 80
      Width = 88
      Height = 15
      Caption = #65298#30058#30446#12398#12501#12457#12523#12480
    end
    object DoInput1stFolder: TEdit
      Left = 16
      Top = 37
      Width = 384
      Height = 23
      TabOrder = 0
    end
    object DoOpenFolderChooser1: TButton
      Left = 406
      Top = 36
      Width = 75
      Height = 25
      Caption = #21442#29031
      TabOrder = 1
      OnClick = OnDoOpenFolderChooser1
    end
    object DoInput2ndFolder: TEdit
      Left = 16
      Top = 101
      Width = 384
      Height = 23
      TabOrder = 2
    end
    object DoOpenFolderChooser2: TButton
      Left = 406
      Top = 100
      Width = 75
      Height = 25
      Caption = #21442#29031
      TabOrder = 3
      OnClick = OnDoOpenFolderChooser2
    end
    object DoCancel: TButton
      Left = 406
      Top = 164
      Width = 75
      Height = 25
      Caption = #12461#12515#12531#12475#12523
      ModalResult = 2
      TabOrder = 4
    end
    object DoCompare: TButton
      Left = 325
      Top = 164
      Width = 75
      Height = 25
      Caption = #27604#36611
      ModalResult = 1
      TabOrder = 5
      OnClick = OnDoCompare
    end
    object DoExchangeFolders: TButton
      Left = 406
      Top = 67
      Width = 75
      Height = 27
      Caption = #20837#26367
      TabOrder = 6
      OnClick = OnDoExchangeFolders
    end
  end
  object DoShowFolderChooser: TFileOpenDialog
    FavoriteLinks = <>
    FileTypes = <>
    Options = [fdoPickFolders]
    Left = 56
    Top = 152
  end
end

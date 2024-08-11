object ConfigSorting: TConfigSorting
  Left = 0
  Top = 0
  BorderIcons = [biMinimize, biMaximize]
  Caption = #20006#12409#26367#12360
  ClientHeight = 141
  ClientWidth = 296
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
    Width = 296
    Height = 141
    Align = alClient
    Caption = 'Panel'
    TabOrder = 0
    ExplicitWidth = 292
    ExplicitHeight = 140
    object Key1Label: TLabel
      Left = 8
      Top = 16
      Width = 118
      Height = 15
      Caption = #65297#30058#30446#12395#20778#20808#12377#12427#12461#12540
    end
    object Key2Label: TLabel
      Left = 8
      Top = 45
      Width = 118
      Height = 15
      Caption = #65298#30058#30446#12395#20778#20808#12377#12427#12461#12540
    end
    object Key3Label: TLabel
      Left = 8
      Top = 74
      Width = 118
      Height = 15
      Caption = #65299#30058#30446#12395#20778#20808#12377#12427#12461#12540
    end
    object DoSpecifyKey1: TComboBox
      Left = 132
      Top = 13
      Width = 145
      Height = 23
      Style = csDropDownList
      TabOrder = 0
      Items.Strings = (
        'No'
        #27604#36611#32080#26524
        #24038#20596#12501#12449#12452#12523#21517
        #21491#20596#12501#12449#12452#12523#21517
        #12501#12449#12452#12523#12469#12452#12474
        #12495#12483#12471#12517#20516)
    end
    object DoSpecifyKey2: TComboBox
      Left = 132
      Top = 42
      Width = 145
      Height = 23
      Style = csDropDownList
      TabOrder = 1
      Items.Strings = (
        'No'
        #27604#36611#32080#26524
        #24038#20596#12501#12449#12452#12523#21517
        #21491#20596#12501#12449#12452#12523#21517
        #12501#12449#12452#12523#12469#12452#12474
        #12495#12483#12471#12517#20516)
    end
    object DoSpecifyKey3: TComboBox
      Left = 132
      Top = 71
      Width = 145
      Height = 23
      Style = csDropDownList
      TabOrder = 2
      Items.Strings = (
        'No'
        #27604#36611#32080#26524
        #24038#20596#12501#12449#12452#12523#21517
        #21491#20596#12501#12449#12452#12523#21517
        #12501#12449#12452#12523#12469#12452#12474
        #12495#12483#12471#12517#20516)
    end
    object DoSort: TButton
      Left = 121
      Top = 100
      Width = 75
      Height = 25
      Caption = #12477#12540#12488#12377#12427
      ModalResult = 1
      TabOrder = 3
      OnClick = OnDoSort
    end
    object DoCancel: TButton
      Left = 202
      Top = 100
      Width = 75
      Height = 25
      Caption = #12461#12515#12531#12475#12523
      ModalResult = 2
      TabOrder = 4
    end
    object DoReset: TButton
      Left = 8
      Top = 100
      Width = 75
      Height = 25
      Caption = #12522#12475#12483#12488
      TabOrder = 5
      OnClick = OnDoReset
    end
  end
end

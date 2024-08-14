object Start: TStart
  Left = 0
  Top = 0
  Caption = 'FileSync'
  ClientHeight = 420
  ClientWidth = 540
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu
  OnClose = OnClose
  TextHeight = 15
  object Grid: TStringGrid
    Left = 0
    Top = 0
    Width = 540
    Height = 401
    Align = alClient
    ColCount = 6
    RowCount = 10
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing, goRowMoving, goRowSelect, goThumbTracking, goFixedRowDefAlign]
    TabOrder = 0
    OnDrawCell = OnDrawCell
    OnMouseDown = OnMouseDown
    ExplicitWidth = 536
    ExplicitHeight = 400
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 401
    Width = 540
    Height = 19
    Panels = <>
    SimplePanel = True
    ExplicitTop = 400
    ExplicitWidth = 536
  end
  object MainMenu: TMainMenu
    Left = 496
    Top = 16
    object FileMenu: TMenuItem
      Caption = #12501#12449#12452#12523
      object DoImport: TMenuItem
        Caption = #12501#12449#12452#12523#12434#21462#12426#36796#12416
        OnClick = OnDoImport
      end
      object DoExport: TMenuItem
        Caption = #12501#12449#12452#12523#12434#20986#21147#12377#12427
        OnClick = OnDoExport
      end
      object DoOpen: TMenuItem
        Caption = #38283#12367
        OnClick = OnDoOpen
      end
      object DoExit: TMenuItem
        Caption = #32066#20102
        OnClick = OnDoExit
      end
    end
    object DataMenu: TMenuItem
      Caption = #12487#12540#12479
      object DoSort: TMenuItem
        Caption = #20006#12409#26367#12360#12427
        OnClick = OnDoSort
      end
    end
  end
  object PopupMenu: TPopupMenu
    Left = 496
    Top = 72
    object DoWatchThisVideo: TMenuItem
      Caption = #12371#12398#21205#30011#12434#35222#32884#12377#12427
      OnClick = OnDoWatchThisVideo
    end
    object DoCopyLeftToRight: TMenuItem
      Caption = #24038#20596#12363#12425#21491#20596#12408#12467#12500#12540#12377#12427
      OnClick = OnDoCopyLeftToRight
    end
    object DoCopyRigthToLeft: TMenuItem
      Caption = #21491#20596#12363#12425#24038#20596#12408#12467#12500#12540#12377#12427
      OnClick = OnDoCopyRigthToLeft
    end
  end
  object DoShowSaveDialog: TSaveDialog
    DefaultExt = '*.json'
    Filter = 'JSON|*.JSON,*.json'
    Left = 496
    Top = 128
  end
  object DoShowOpenDialog: TOpenDialog
    DefaultExt = '*.json'
    Filter = 'JSON|*.JSON,*.json'
    Left = 496
    Top = 184
  end
end

object Start: TStart
  Left = 0
  Top = 0
  Caption = 'FileSync'
  ClientHeight = 431
  ClientWidth = 584
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
    Width = 584
    Height = 412
    Align = alClient
    RowCount = 10
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing, goRowMoving, goRowSelect, goThumbTracking, goFixedRowDefAlign]
    TabOrder = 0
    OnDrawCell = OnDrawCell
    OnMouseDown = OnMouseDown
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 412
    Width = 584
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object MainMenu: TMainMenu
    Left = 536
    Top = 16
    object FileMenu: TMenuItem
      Caption = #12501#12449#12452#12523
      object DoOpen: TMenuItem
        Caption = #38283#12367
        OnClick = OnDoOpen
      end
      object DoTerminateApp: TMenuItem
        Caption = #32066#20102
        OnClick = OnDoTerminateApp
      end
    end
  end
  object PopupMenu: TPopupMenu
    Left = 536
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
end

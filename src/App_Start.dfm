object Start: TStart
  Left = 0
  Top = 0
  Caption = 'FileSync'
  ClientHeight = 432
  ClientWidth = 588
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu
  OnClose = OnClose
  TextHeight = 15
  object StatusBar: TStatusBar
    Left = 0
    Top = 413
    Width = 588
    Height = 19
    Panels = <>
    SimplePanel = True
  end
  object Pages: TPageControl
    Left = 0
    Top = 0
    Width = 588
    Height = 413
    ActivePage = ComparisonResult
    Align = alClient
    TabOrder = 1
    object ComparisonResult: TTabSheet
      Caption = #27604#36611#32080#26524
      object Grid: TStringGrid
        Left = 0
        Top = 0
        Width = 580
        Height = 383
        Align = alClient
        RowCount = 10
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing, goRowMoving, goRowSelect, goThumbTracking, goFixedRowDefAlign]
        TabOrder = 0
        OnDrawCell = OnDrawCell
        OnMouseDown = OnMouseDown
      end
    end
  end
  object MainMenu: TMainMenu
    Left = 528
    Top = 24
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
    Left = 528
    Top = 80
    object DoCopyLeftToRight: TMenuItem
      Caption = #24038#20596#12363#12425#21491#20596#12408#12467#12500#12540#12377#12427
      OnClick = OnDoCopyLeftToRight
    end
    object DoCopyRigthToLeft: TMenuItem
      Caption = #21491#20596#12363#12425#24038#20596#12408#12467#12500#12540#12377#12427
      OnClick = OnDoCopyRigthToLeft
    end
    object DoShowThumbnail: TMenuItem
      Caption = #21205#30011#12398#12469#12512#12493#12452#12523#12434#34920#31034#12377#12427
      OnClick = OnDoShowThumbnail
    end
  end
end

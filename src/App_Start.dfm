object Start: TStart
  Left = 0
  Top = 0
  Caption = 'FileSync'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu
  TextHeight = 15
  object Grid: TStringGrid
    Left = 0
    Top = 0
    Width = 624
    Height = 422
    Align = alClient
    RowCount = 10
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goColSizing, goColMoving, goThumbTracking, goFixedRowDefAlign]
    TabOrder = 0
    OnDrawCell = OnDrawCell
    OnMouseDown = OnMouseDown
    ExplicitWidth = 320
    ExplicitHeight = 120
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 422
    Width = 624
    Height = 19
    Panels = <>
    SimplePanel = True
    ExplicitLeft = 320
    ExplicitTop = 240
    ExplicitWidth = 0
  end
  object MainMenu: TMainMenu
    Left = 576
    Top = 8
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
    Left = 576
    Top = 72
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

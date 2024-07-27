object PlayVideo: TPlayVideo
  Left = 0
  Top = 0
  Caption = 'PlayVideo'
  ClientHeight = 442
  ClientWidth = 628
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnClose = OnClose
  TextHeight = 15
  object TrackBar: TTrackBar
    Left = 0
    Top = 378
    Width = 628
    Height = 45
    Align = alBottom
    Max = 100
    TabOrder = 0
    ExplicitTop = 377
    ExplicitWidth = 624
  end
  object Panel: TPanel
    Left = 0
    Top = 0
    Width = 628
    Height = 378
    Align = alClient
    Caption = 'Panel'
    TabOrder = 1
    ExplicitWidth = 624
    ExplicitHeight = 377
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 423
    Width = 628
    Height = 19
    Panels = <>
    SimplePanel = True
    SimpleText = #12371#12371#12395#12513#12483#12475#12540#12472#12434#34920#31034#12375#12414#12377'...'
    ExplicitTop = 422
    ExplicitWidth = 624
  end
  object Timer: TTimer
    Enabled = False
    OnTimer = OnStartPlayingBack
    Left = 584
    Top = 16
  end
end

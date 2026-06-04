Add-Type -AssemblyName System.Drawing

$size = 1024
$bitmap = New-Object System.Drawing.Bitmap($size, $size)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)

$cardPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$x = 40
$y = 40
$w = 944
$h = 944
$r = 210
$d = $r * 2
$cardPath.AddArc($x, $y, $d, $d, 180, 90)
$cardPath.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
$cardPath.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
$cardPath.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
$cardPath.CloseFigure()

$bgRect = New-Object System.Drawing.RectangleF($x, $y, $w, $h)
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  $bgRect,
  [System.Drawing.Color]::FromArgb(255, 19, 122, 83),
  [System.Drawing.Color]::FromArgb(255, 9, 69, 52),
  38
)
$graphics.FillPath($bg, $cardPath)

$highlight = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  (New-Object System.Drawing.RectangleF(110, 100, 800, 320)),
  [System.Drawing.Color]::FromArgb(55, 255, 255, 255),
  [System.Drawing.Color]::FromArgb(0, 255, 255, 255),
  90
)
$graphics.FillEllipse($highlight, 110, 100, 800, 320)

$pin = New-Object System.Drawing.Drawing2D.GraphicsPath
$pin.AddEllipse(280, 180, 464, 464)
$pin.AddPolygon([System.Drawing.Point[]]@(
  (New-Object System.Drawing.Point(512, 900)),
  (New-Object System.Drawing.Point(364, 534)),
  (New-Object System.Drawing.Point(660, 534))
))
$graphics.FillPath([System.Drawing.Brushes]::White, $pin)

$innerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 19, 122, 83))
$graphics.FillEllipse($innerBrush, 386, 286, 252, 252)

$checkPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 38)
$checkPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$checkPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.DrawLines($checkPen, [System.Drawing.Point[]]@(
  (New-Object System.Drawing.Point(438, 404)),
  (New-Object System.Drawing.Point(492, 460)),
  (New-Object System.Drawing.Point(592, 348))
))

$linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(215, 255, 255, 255), 24)
$linePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$linePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.DrawLine($linePen, 300, 760, 724, 760)
$graphics.DrawLine($linePen, 338, 815, 686, 815)
$graphics.DrawLine($linePen, 386, 868, 638, 868)

$output = Join-Path (Get-Location) 'assets/icons/app_icon.png'
$bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)

$linePen.Dispose()
$checkPen.Dispose()
$innerBrush.Dispose()
$pin.Dispose()
$highlight.Dispose()
$bg.Dispose()
$cardPath.Dispose()
$graphics.Dispose()
$bitmap.Dispose()

Write-Output "Created $output"

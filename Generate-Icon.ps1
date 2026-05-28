<#
.SYNOPSIS
    Generates WrapTune.ico — Bicolor Stack mark.
.DESCRIPTION
    Three iso-stacked slabs on a cream rounded tile:
      tile  #F4EFE7
      top   #5EEAD4
      mid   #2BBFA9
      bot   #0E8A7A
    Outputs 256, 48, 32, 20, 16 px sizes in a single .ico file.
#>

Add-Type -AssemblyName System.Drawing

function New-WrapTuneIcon {
    param([int]$Size)

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)

    # Rounded tile background — #F4EFE7
    $bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(244, 239, 231))
    $radius = [Math]::Max(2, [int](0.22 * $Size))
    $rect = New-Object System.Drawing.Rectangle 0, 0, $Size, $Size
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
    $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
    $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $g.FillPath($bgBrush, $path)

    # ─── Iso slabs ─────────────────────────────────────────────────────────
    # All coordinates expressed against a 100×100 viewBox, scaled to $Size.
    $s = $Size / 100.0
    function P([single]$x, [single]$y) {
        New-Object System.Drawing.PointF ($x * $s), ($y * $s)
    }

    $botBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(14, 138, 122))
    $midBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(43, 191, 169))
    $topBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(94, 234, 212))

    # Bottom slab — points: (50,70) (80,56) (50,42) (20,56)
    [System.Drawing.PointF[]]$bot = @((P 50 70), (P 80 56), (P 50 42), (P 20 56))
    # Middle slab — (50,56) (80,42) (50,28) (20,42)
    [System.Drawing.PointF[]]$mid = @((P 50 56), (P 80 42), (P 50 28), (P 20 42))
    # Top slab — (50,42) (80,28) (50,14) (20,28)
    [System.Drawing.PointF[]]$top = @((P 50 42), (P 80 28), (P 50 14), (P 20 28))

    $g.FillPolygon($botBrush, $bot)
    $g.FillPolygon($midBrush, $mid)
    $g.FillPolygon($topBrush, $top)

    # Cleanup
    $bgBrush.Dispose(); $botBrush.Dispose(); $midBrush.Dispose(); $topBrush.Dispose()
    $path.Dispose(); $g.Dispose()

    return $bmp
}

function Save-MultiSizeIco {
    param(
        [System.Drawing.Bitmap[]]$Bitmaps,
        [string]$OutputPath
    )

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms

    $count = $Bitmaps.Count

    # Header
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$count)

    # Encode each bitmap as PNG
    $pngDataList = @()
    foreach ($bmp in $Bitmaps) {
        $pngStream = New-Object System.IO.MemoryStream
        $bmp.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngDataList += , $pngStream.ToArray()
        $pngStream.Dispose()
    }

    # Directory entries
    $dataOffset = 6 + ($count * 16)
    for ($i = 0; $i -lt $count; $i++) {
        $bmp = $Bitmaps[$i]
        $pngData = $pngDataList[$i]
        $w = $bmp.Width
        $h = $bmp.Height

        $bw.Write([byte]$(if ($w -ge 256) { 0 } else { $w }))
        $bw.Write([byte]$(if ($h -ge 256) { 0 } else { $h }))
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$pngData.Length)
        $bw.Write([uint32]$dataOffset)
        $dataOffset += $pngData.Length
    }

    foreach ($pngData in $pngDataList) { $bw.Write($pngData) }

    [System.IO.File]::WriteAllBytes($OutputPath, $ms.ToArray())
    $bw.Dispose(); $ms.Dispose()
}

# Generate
$sizes = @(256, 48, 32, 20, 16)
$bitmaps = @()
foreach ($sz in $sizes) { $bitmaps += New-WrapTuneIcon -Size $sz }

$outputPath = Join-Path $PSScriptRoot 'WrapTune.ico'
Save-MultiSizeIco -Bitmaps $bitmaps -OutputPath $outputPath

foreach ($bmp in $bitmaps) { $bmp.Dispose() }

Write-Host "Icon created: $outputPath" -ForegroundColor Green

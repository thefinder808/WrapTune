<#
.SYNOPSIS
    Generates WrapTune.ico — multi-size icon for the WrapTune app.
.DESCRIPTION
    Creates a modern flat icon: rounded navy square (#1a2332) with a teal
    (#2d8b8b) stylized package box + seafoam (#a8dadc) wrap ribbon/bow.
    Outputs 256, 64, 48, 32, 16 px sizes in a single .ico file.
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

    # Scale factor relative to 256px
    $s = $Size / 256.0

    # Rounded rectangle background — #1a2332 (navy)
    $bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(26, 35, 50))
    $radius = [int](40 * $s)
    $rect = New-Object System.Drawing.Rectangle 0, 0, $Size, $Size
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($rect.X, $rect.Y, $radius * 2, $radius * 2, 180, 90)
    $path.AddArc($rect.Right - $radius * 2, $rect.Y, $radius * 2, $radius * 2, 270, 90)
    $path.AddArc($rect.Right - $radius * 2, $rect.Bottom - $radius * 2, $radius * 2, $radius * 2, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $radius * 2, $radius * 2, $radius * 2, 90, 90)
    $path.CloseFigure()
    $g.FillPath($bgBrush, $path)

    # Subtle darker bottom edge for depth
    $darkBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(50, 0, 0, 0))
    $edgeRect = New-Object System.Drawing.RectangleF (8 * $s), ($Size - 12 * $s), ($Size - 16 * $s), (12 * $s)
    $g.FillRectangle($darkBrush, $edgeRect)

    # Teal pen for box outline — #2d8b8b
    $tealColor = [System.Drawing.Color]::FromArgb(45, 139, 139)
    $penW = [Math]::Max(1, [int](12 * $s))
    $pen = New-Object System.Drawing.Pen $tealColor, $penW
    $pen.StartCap = 'Round'
    $pen.EndCap = 'Round'
    $pen.LineJoin = 'Round'

    # Seafoam pen for ribbon/bow — #a8dadc
    $seafoamColor = [System.Drawing.Color]::FromArgb(168, 218, 220)
    $thinPenW = [Math]::Max(1, [int](8 * $s))
    $thinPen = New-Object System.Drawing.Pen $seafoamColor, $thinPenW
    $thinPen.StartCap = 'Round'
    $thinPen.EndCap = 'Round'
    $thinPen.LineJoin = 'Round'

    $whiteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)

    # --- Draw a box/package shape ---
    # Box body (vertically centered in the icon)
    $bx = 60 * $s
    $by = 99 * $s
    $bw = 136 * $s
    $bh = 105 * $s
    $boxRect = New-Object System.Drawing.RectangleF $bx, $by, $bw, $bh
    $g.DrawRectangle($pen, $bx, $by, $bw, $bh)

    # Box lid / flap (trapezoid on top)
    [System.Drawing.PointF[]]$flapPoints = @(
        (New-Object System.Drawing.PointF ($bx - 8 * $s), ($by)),
        (New-Object System.Drawing.PointF ($bx + 20 * $s), ($by - 30 * $s)),
        (New-Object System.Drawing.PointF ($bx + $bw - 20 * $s), ($by - 30 * $s)),
        (New-Object System.Drawing.PointF ($bx + $bw + 8 * $s), ($by))
    )
    $g.DrawPolygon($pen, $flapPoints)

    # Vertical ribbon (center of box, top to bottom)
    $cx = $bx + $bw / 2
    $g.DrawLine($thinPen, $cx, ($by - 30 * $s), $cx, ($by + $bh))

    # Horizontal ribbon (across box middle)
    $cy = $by + $bh * 0.42
    $g.DrawLine($thinPen, $bx, $cy, ($bx + $bw), $cy)

    # Bow on top — two small loops
    $bowY = $by - 30 * $s
    $loopW = 22 * $s
    $loopH = 16 * $s
    # Left loop
    $g.DrawEllipse($thinPen, ($cx - $loopW - 2 * $s), ($bowY - $loopH), $loopW, $loopH)
    # Right loop
    $g.DrawEllipse($thinPen, ($cx + 2 * $s), ($bowY - $loopH), $loopW, $loopH)

    # --- Cleanup ---
    $pen.Dispose()
    $thinPen.Dispose()
    $bgBrush.Dispose()
    $darkBrush.Dispose()
    $whiteBrush.Dispose()
    $path.Dispose()
    $g.Dispose()

    return $bmp
}

function Save-MultiSizeIco {
    param(
        [System.Drawing.Bitmap[]]$Bitmaps,
        [string]$OutputPath
    )

    # ICO format: header + directory entries + PNG image data
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms

    $count = $Bitmaps.Count

    # ICO header: reserved(2) + type(2) + count(2)
    $bw.Write([uint16]0)       # Reserved
    $bw.Write([uint16]1)       # Type: 1 = ICO
    $bw.Write([uint16]$count)  # Number of images

    # Collect PNG data for each bitmap
    $pngDataList = @()
    foreach ($bmp in $Bitmaps) {
        $pngStream = New-Object System.IO.MemoryStream
        $bmp.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngDataList += , $pngStream.ToArray()
        $pngStream.Dispose()
    }

    # Directory entries: offset starts after header + all directory entries
    # Header = 6 bytes, each dir entry = 16 bytes
    $dataOffset = 6 + ($count * 16)

    for ($i = 0; $i -lt $count; $i++) {
        $bmp = $Bitmaps[$i]
        $pngData = $pngDataList[$i]
        $w = $bmp.Width
        $h = $bmp.Height

        $bw.Write([byte]$(if ($w -ge 256) { 0 } else { $w }))  # Width (0 = 256)
        $bw.Write([byte]$(if ($h -ge 256) { 0 } else { $h }))  # Height
        $bw.Write([byte]0)          # Color palette
        $bw.Write([byte]0)          # Reserved
        $bw.Write([uint16]1)        # Color planes
        $bw.Write([uint16]32)       # Bits per pixel
        $bw.Write([uint32]$pngData.Length)  # Image data size
        $bw.Write([uint32]$dataOffset)      # Offset to image data

        $dataOffset += $pngData.Length
    }

    # Write image data
    foreach ($pngData in $pngDataList) {
        $bw.Write($pngData)
    }

    # Save to file
    [System.IO.File]::WriteAllBytes($OutputPath, $ms.ToArray())

    $bw.Dispose()
    $ms.Dispose()
}

# --- Generate icons at multiple sizes ---
$sizes = @(256, 64, 48, 32, 16)
$bitmaps = @()
foreach ($sz in $sizes) {
    $bitmaps += New-WrapTuneIcon -Size $sz
}

$outputPath = Join-Path $PSScriptRoot 'WrapTune.ico'
Save-MultiSizeIco -Bitmaps $bitmaps -OutputPath $outputPath

# Cleanup
foreach ($bmp in $bitmaps) { $bmp.Dispose() }

Write-Host "Icon created: $outputPath" -ForegroundColor Green

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$SrcPath = Join-Path $PSScriptRoot "..\src\new_background.jpg"
$OutDir = Join-Path $PSScriptRoot "..\src"
$HighPath = Join-Path $OutDir "dashboard_bg_4x.png"
$PngPath = Join-Path $OutDir "dashboard_bg.png"
$HeaderPath = Join-Path $OutDir "dashboard_bg.h"

$W = 320
$H = 240
$S = 4

if (!(Test-Path $SrcPath)) {
  # if original source not present, allow using an existing 4x PNG
  if (Test-Path $HighPath) {
    Write-Host "Source not found; using existing dashboard_bg_4x.png as input"
    $SrcPath = $HighPath
  }
  else {
    throw "Missing src\new_background.jpg and dashboard_bg_4x.png"
  }
}

function New-Bitmap($w, $h) {
  New-Object System.Drawing.Bitmap -ArgumentList @($w, $h, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb))
}

$src = [System.Drawing.Image]::FromFile($SrcPath)
try {
  $targetAspect = [double]$W / [double]$H
  $srcAspect = [double]$src.Width / [double]$src.Height

  if ($srcAspect -gt $targetAspect) {
    $cropH = $src.Height
    $cropW = [int][Math]::Round($cropH * $targetAspect)
    $cropX = [int][Math]::Floor(($src.Width - $cropW) / 2)
    $cropY = 0
  }
  else {
    $cropW = $src.Width
    $cropH = [int][Math]::Round($cropW / $targetAspect)
    $cropX = 0
    $cropY = [int][Math]::Floor(($src.Height - $cropH) / 2)
  }

  $srcRect = New-Object System.Drawing.Rectangle -ArgumentList @($cropX, $cropY, $cropW, $cropH)

  $high = New-Bitmap ($W * $S) ($H * $S)
  $gh = [System.Drawing.Graphics]::FromImage($high)
  try {
    $gh.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gh.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gh.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $dstHigh = New-Object System.Drawing.Rectangle -ArgumentList @(0, 0, ($W * $S), ($H * $S))
    $gh.DrawImage($src, $dstHigh, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $high.Save($HighPath, [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    if ($gh) { $gh.Dispose() }
  }

  $small = New-Bitmap $W $H
  $gs = [System.Drawing.Graphics]::FromImage($small)
  try {
    $gs.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gs.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gs.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $dstSmall = New-Object System.Drawing.Rectangle -ArgumentList @(0, 0, $W, $H)
    $srcHigh = New-Object System.Drawing.Rectangle -ArgumentList @(0, 0, ($W * $S), ($H * $S))
    $gs.DrawImage($high, $dstSmall, $srcHigh, [System.Drawing.GraphicsUnit]::Pixel)
    $small.Save($PngPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("#pragma once")
    [void]$sb.AppendLine("#include <Arduino.h>")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("const int DASHBOARD_BG_W = 320;")
    [void]$sb.AppendLine("const int DASHBOARD_BG_H = 240;")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("const uint16_t DASHBOARD_BG_BITMAP[] PROGMEM = {")
    for ($yy = 0; $yy -lt $H; $yy++) {
      [void]$sb.Append("  ")
      for ($xx = 0; $xx -lt $W; $xx++) {
        $c = $small.GetPixel($xx, $yy)
        $rgb565 = (($c.R -band 0xF8) -shl 8) -bor (($c.G -band 0xFC) -shl 3) -bor ($c.B -shr 3)
        [void]$sb.Append(("0x{0:X4}" -f $rgb565))
        if (($yy -ne ($H - 1)) -or ($xx -ne ($W - 1))) { [void]$sb.Append(", ") }
        if (($xx + 1) % 12 -eq 0 -and $xx -ne ($W - 1)) {
          [void]$sb.AppendLine()
          [void]$sb.Append("  ")
        }
      }
      [void]$sb.AppendLine()
    }
    [void]$sb.AppendLine("};")
    [System.IO.File]::WriteAllText($HeaderPath, $sb.ToString(), [System.Text.Encoding]::ASCII)
  }
  finally {
    if ($gs) { $gs.Dispose() }
    if ($small) { $small.Dispose() }
  }
}
finally {
  if ($high) { $high.Dispose() }
  if ($src) { $src.Dispose() }
}

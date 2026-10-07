$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Compose le splash avec le logo original et le nom dans la police de l'app.
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourcePath = Join-Path $repoRoot 'assets/images/beemview-logo.png'
$fontPath = Join-Path $repoRoot 'assets/fonts/PlusJakartaSans.ttf'
$androidDirectory = Join-Path $repoRoot 'android/app/src/main/res/drawable-nodpi'
$iosDirectory = Join-Path $repoRoot 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
New-Item -ItemType Directory -Force -Path $androidDirectory | Out-Null

# Android 12 conserve un cercle de 192 dp dans un cadre de 288 dp.
# Le logo de 104 dp et le nom de 18,5 dp restent ensemble dans ce cercle.
$logo = [System.Drawing.Bitmap]::new($sourcePath)
$canvas = $null
$graphics = $null
$fonts = [System.Drawing.Text.PrivateFontCollection]::new()
$namePath = [System.Drawing.Drawing2D.GraphicsPath]::new()
$numberPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
$cyan = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#00AFD5'))
$orange = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#FF9800'))
try {
    if ($logo.Width -ne $logo.Height) { throw 'The launch logo must be square.' }
    $canvasSize = [int][Math]::Ceiling($logo.Width * 288 / 104)
    $scale = $canvasSize / 288.0
    $canvas = [System.Drawing.Bitmap]::new($canvasSize, $canvasSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $offset = [int][Math]::Floor(($canvasSize - $logo.Width) / 2)
    $logoTop = [int][Math]::Round(68 * $scale)
    # Une copie directe garde aussi les couleurs des pixels semi-transparents.
    for ($pixelY = 0; $pixelY -lt $logo.Height; $pixelY++) {
        for ($pixelX = 0; $pixelX -lt $logo.Width; $pixelX++) {
            $canvas.SetPixel($pixelX + $offset, $pixelY + $logoTop, $logo.GetPixel($pixelX, $pixelY))
        }
    }

    $fonts.AddFontFile($fontPath)
    $family = $fonts.Families[0]
    $fontSize = [single](18.5 * $scale)
    $namePath.AddString('BeemView', $family, [int][System.Drawing.FontStyle]::Bold, $fontSize, [System.Drawing.PointF]::Empty, [System.Drawing.StringFormat]::GenericTypographic)
    $numberPath.AddString('360', $family, [int][System.Drawing.FontStyle]::Bold, $fontSize, [System.Drawing.PointF]::Empty, [System.Drawing.StringFormat]::GenericTypographic)
    $nameBounds = $namePath.GetBounds()
    $numberBounds = $numberPath.GetBounds()
    $gap = $scale
    $wordmarkWidth = $nameBounds.Width + $gap + $numberBounds.Width
    $wordmarkLeft = ($canvasSize - $wordmarkWidth) / 2
    $wordmarkTop = 186 * $scale - [Math]::Min($nameBounds.Y, $numberBounds.Y)
    foreach ($part in @(
        @{ Path = $namePath; X = $wordmarkLeft - $nameBounds.X },
        @{ Path = $numberPath; X = $wordmarkLeft + $nameBounds.Width + $gap - $numberBounds.X }
    )) {
        $matrix = [System.Drawing.Drawing2D.Matrix]::new()
        try {
            $matrix.Translate([single]$part.X, [single]$wordmarkTop)
            $part.Path.Transform($matrix)
        } finally {
            $matrix.Dispose()
        }
    }
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.FillPath($cyan, $namePath)
    $graphics.FillPath($orange, $numberPath)
    $graphics.Dispose()
    $graphics = $null

    # Refuse un asset que le masque Android pourrait rogner.
    $center = $canvasSize / 2.0
    $safeRadius = 96 * $scale
    for ($pixelY = 0; $pixelY -lt $canvasSize; $pixelY++) {
        for ($pixelX = 0; $pixelX -lt $canvasSize; $pixelX++) {
            if ($canvas.GetPixel($pixelX, $pixelY).A -eq 0) { continue }
            $distance = [Math]::Sqrt([Math]::Pow($pixelX + 0.5 - $center, 2) + [Math]::Pow($pixelY + 0.5 - $center, 2))
            if ($distance -gt $safeRadius) { throw 'Splash branding exceeds the Android 12 safe circle.' }
        }
    }
    $androidAsset = Join-Path $androidDirectory 'beemview_splash.png'
    $canvas.Save($androidAsset, [System.Drawing.Imaging.ImageFormat]::Png)
    foreach ($imageName in @('LaunchImage.png', 'LaunchImage@2x.png', 'LaunchImage@3x.png')) {
        Copy-Item -LiteralPath $androidAsset -Destination (Join-Path $iosDirectory $imageName)
    }
} finally {
    if ($null -ne $graphics) { $graphics.Dispose() }
    if ($null -ne $canvas) { $canvas.Dispose() }
    $namePath.Dispose()
    $numberPath.Dispose()
    $cyan.Dispose()
    $orange.Dispose()
    $fonts.Dispose()
    $logo.Dispose()
}

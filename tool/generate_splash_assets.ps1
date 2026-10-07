$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Copie la marque originale sans changer ses pixels ni les assets de l'app.
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourcePath = Join-Path $repoRoot 'assets/images/beemview-logo.png'
$androidDirectory = Join-Path $repoRoot 'android/app/src/main/res/drawable-nodpi'
$iosDirectory = Join-Path $repoRoot 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
New-Item -ItemType Directory -Force -Path $androidDirectory | Out-Null
Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $androidDirectory 'beemview_logo.png')
foreach ($imageName in @('LaunchImage.png', 'LaunchImage@2x.png', 'LaunchImage@3x.png')) {
    Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $iosDirectory $imageName)
}

# Android 12 masque le tiers exterieur: ce cadre laisse les quatre coins visibles.
# Le logo reste a 128 dp dans le cadre de 288 dp, sans interpolation des pixels.
$logo = [System.Drawing.Bitmap]::new($sourcePath)
$canvas = $null
try {
    if ($logo.Width -ne $logo.Height) { throw 'The launch logo must be square.' }
    $canvasSize = [int][Math]::Ceiling($logo.Width * 288 / 128)
    $canvas = [System.Drawing.Bitmap]::new($canvasSize, $canvasSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $offset = [int][Math]::Floor(($canvasSize - $logo.Width) / 2)
    # Une copie directe garde aussi les couleurs des pixels semi-transparents.
    for ($pixelY = 0; $pixelY -lt $logo.Height; $pixelY++) {
        for ($pixelX = 0; $pixelX -lt $logo.Width; $pixelX++) {
            $canvas.SetPixel($pixelX + $offset, $pixelY + $offset, $logo.GetPixel($pixelX, $pixelY))
        }
    }
    $canvas.Save((Join-Path $androidDirectory 'splash_logo_android12.png'), [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    if ($null -ne $canvas) { $canvas.Dispose() }
    $logo.Dispose()
}

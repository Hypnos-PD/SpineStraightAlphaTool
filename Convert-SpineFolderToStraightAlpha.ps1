<#
.SYNOPSIS
将一个包含 Spine .png/.atlas/.skel 的目录原地转换为 straight alpha 版本。

.DESCRIPTION
快速验证或修复预乘 alpha 黑边问题。


执行流程：
1. 在目标目录里定位原始 .atlas 文件
2. 从 atlas 第一行解析出对应的 .png 文件名
3. 定位同名 .skel 文件
4. 将原始 .png/.atlas/.skel 分别备份为同名 .bak 文件
5. 生成新的原名 .png 文件，并将其从 premultiplied alpha 转为 straight alpha
6. 生成新的原名 .atlas 文件，并将其中的 pma 标记改为 false
7. 生成新的原名 .skel 文件，内容与原始文件一致

这个脚本不会修改 .import 文件，也不会触发 Godot 重新导入。
处理完成后，需要在 Godot 编辑器中对新文件执行一次重新导入。

.PARAMETER FolderPath
包含一套 Spine 资源的目录。目录中应有且仅有一份原始 .atlas，
并且应能解析出对应的 .png 和 .skel 文件。

.PARAMETER Force
如果同名 .bak 备份已经存在，默认会报错退出；传入 -Force 时会先覆盖旧备份。

.EXAMPLE
.\scripts\Convert-SpineFolderToStraightAlpha.ps1 -FolderPath ".\STSVWB\spine\skinDreizehn\vsEudie"

将 vsEudie 目录中的原始 .png/.atlas/.skel 备份为 .bak，
然后在原路径生成 straight alpha 版本的新文件。

.EXAMPLE
.\scripts\Convert-SpineFolderToStraightAlpha.ps1 -FolderPath "D:\SpineExport\characterA" -Force

强制覆盖旧的 .bak 备份，并重新生成一套新文件。
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$FolderPath,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedFolder = (Resolve-Path -LiteralPath $FolderPath).Path

Add-Type -AssemblyName System.Drawing
$referencedAssemblies = @(
    [System.Drawing.Bitmap].Assembly.Location
    [System.Drawing.Rectangle].Assembly.Location
    [System.Object].Assembly.Location
) | Select-Object -Unique

Add-Type -ReferencedAssemblies $referencedAssemblies -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class SpinePngUnpremultiplyHelper
{
    public static int Unpremultiply(Bitmap inputBitmap, Bitmap outputBitmap)
    {
        Rectangle rect = new Rectangle(0, 0, inputBitmap.Width, inputBitmap.Height);
        BitmapData inputData = inputBitmap.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        BitmapData outputData = outputBitmap.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);

        try
        {
            int byteCount = Math.Abs(inputData.Stride) * inputBitmap.Height;
            byte[] inputBytes = new byte[byteCount];
            byte[] outputBytes = new byte[byteCount];
            Marshal.Copy(inputData.Scan0, inputBytes, 0, byteCount);

            int changed = 0;
            for (int offset = 0; offset < byteCount; offset += 4)
            {
                int blue = inputBytes[offset];
                int green = inputBytes[offset + 1];
                int red = inputBytes[offset + 2];
                int alpha = inputBytes[offset + 3];

                int newBlue;
                int newGreen;
                int newRed;

                if (alpha <= 0)
                {
                    newBlue = 0;
                    newGreen = 0;
                    newRed = 0;
                }
                else
                {
                    newBlue = Math.Min(255, (int)Math.Round((blue * 255.0) / alpha));
                    newGreen = Math.Min(255, (int)Math.Round((green * 255.0) / alpha));
                    newRed = Math.Min(255, (int)Math.Round((red * 255.0) / alpha));
                }

                if (newBlue != blue || newGreen != green || newRed != red)
                {
                    changed++;
                }

                outputBytes[offset] = (byte)newBlue;
                outputBytes[offset + 1] = (byte)newGreen;
                outputBytes[offset + 2] = (byte)newRed;
                outputBytes[offset + 3] = (byte)alpha;
            }

            Marshal.Copy(outputBytes, 0, outputData.Scan0, byteCount);
            return changed;
        }
        finally
        {
            inputBitmap.UnlockBits(inputData);
            outputBitmap.UnlockBits(outputData);
        }
    }
}
"@

function Convert-PngToStraightAlpha {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "Input file does not exist: $InputPath"
    }

    $resolvedInputPath = (Resolve-Path -LiteralPath $InputPath).Path
    $sourceBitmap = [System.Drawing.Bitmap]::FromFile($resolvedInputPath)

    try {
        $inputBitmap = [System.Drawing.Bitmap]::new($sourceBitmap.Width, $sourceBitmap.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

        try {
            $graphics = [System.Drawing.Graphics]::FromImage($inputBitmap)

            try {
                $graphics.DrawImage($sourceBitmap, 0, 0, $sourceBitmap.Width, $sourceBitmap.Height)
            }
            finally {
                $graphics.Dispose()
            }

            $working = [System.Drawing.Bitmap]::new($inputBitmap.Width, $inputBitmap.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

            try {
                $changed = [SpinePngUnpremultiplyHelper]::Unpremultiply($inputBitmap, $working)

                $outputDirectory = Split-Path -Parent $OutputPath
                if (-not [string]::IsNullOrWhiteSpace($outputDirectory) -and -not (Test-Path -LiteralPath $outputDirectory)) {
                    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
                }

                $working.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
                return $changed
            }
            finally {
                $working.Dispose()
            }
        }
        finally {
            $inputBitmap.Dispose()
        }
    }
    finally {
        $sourceBitmap.Dispose()
    }
}

function Get-OriginalAtlasFile {
    param([string]$Directory)

    $atlasFiles = @(Get-ChildItem -LiteralPath $Directory -File -Filter '*.atlas' |
        Where-Object { -not $_.Name.EndsWith('.bak', [System.StringComparison]::OrdinalIgnoreCase) } |
        Where-Object { -not $_.BaseName.EndsWith('.unpremultiplied', [System.StringComparison]::OrdinalIgnoreCase) })

    if ($atlasFiles.Count -ne 1) {
        throw "Expected exactly one original .atlas file in $Directory, found $($atlasFiles.Count)."
    }

    return $atlasFiles[0]
}

function Resolve-SkeletonFile {
    param(
        [string]$Directory,
        [System.IO.FileInfo]$AtlasFile
    )

    $skelFiles = @(Get-ChildItem -LiteralPath $Directory -File -Filter '*.skel' |
        Where-Object { -not $_.Name.EndsWith('.bak', [System.StringComparison]::OrdinalIgnoreCase) })

    $matchingByName = @($skelFiles | Where-Object { $_.BaseName -eq $AtlasFile.BaseName })
    if ($matchingByName.Count -eq 1) {
        return $matchingByName[0]
    }

    if ($skelFiles.Count -eq 1) {
        return $skelFiles[0]
    }

    throw "Expected exactly one matching .skel file for $($AtlasFile.Name) in $Directory."
}

function Move-ToBackup {
    param([string]$FilePath)

    $backupPath = $FilePath + '.bak'
    if (Test-Path -LiteralPath $backupPath) {
        if (-not $Force) {
            throw "Backup already exists: $backupPath. Pass -Force to overwrite it."
        }

        Remove-Item -LiteralPath $backupPath -Force
    }

    Move-Item -LiteralPath $FilePath -Destination $backupPath -Force
    return $backupPath
}

function Get-AtlasImageReference {
    param([string[]]$Lines)

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $trimmed = $Lines[$index].Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
            return [pscustomobject]@{
                Index = $index
                Value = $trimmed
            }
        }
    }

    throw 'Atlas file does not contain an image reference line.'
}

function Set-AtlasPmaFalse {
    param(
        [string[]]$Lines,
        [string]$ImageFileName
    )

    $updated = [System.Collections.Generic.List[string]]::new()
    $imageInfo = Get-AtlasImageReference -Lines $Lines
    $pmaUpdated = $false
    $insertAfterIndex = -1

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $line = $Lines[$index]
        $trimmed = $line.Trim()

        if ($index -eq $imageInfo.Index) {
            $updated.Add($ImageFileName)
            continue
        }

        if ($trimmed -match '^filter\s*:') {
            $insertAfterIndex = $updated.Count
            $updated.Add($line)
            continue
        }

        if ($trimmed -match '^pma\s*:') {
            $updated.Add('pma:false')
            $pmaUpdated = $true
            continue
        }

        $updated.Add($line)
    }

    if (-not $pmaUpdated) {
        if ($insertAfterIndex -ge 0) {
            $updated.Insert($insertAfterIndex + 1, 'pma:false')
        }
        else {
            $updated.Insert($imageInfo.Index + 1, 'pma:false')
        }
    }

    return $updated
}

$atlasFile = Get-OriginalAtlasFile -Directory $resolvedFolder
$atlasLines = Get-Content -LiteralPath $atlasFile.FullName
$atlasImage = Get-AtlasImageReference -Lines $atlasLines
$pngPath = Join-Path $resolvedFolder $atlasImage.Value

if (-not (Test-Path -LiteralPath $pngPath)) {
    throw "Atlas image file does not exist: $pngPath"
}

$skelFile = Resolve-SkeletonFile -Directory $resolvedFolder -AtlasFile $atlasFile

$atlasBackupPath = Move-ToBackup -FilePath $atlasFile.FullName
$pngBackupPath = Move-ToBackup -FilePath $pngPath
$skelBackupPath = Move-ToBackup -FilePath $skelFile.FullName

$updatedAtlasLines = Set-AtlasPmaFalse -Lines (Get-Content -LiteralPath $atlasBackupPath) -ImageFileName ([System.IO.Path]::GetFileName($pngPath))
[System.IO.File]::WriteAllLines($atlasFile.FullName, $updatedAtlasLines)

$pixelsChanged = Convert-PngToStraightAlpha -InputPath $pngBackupPath -OutputPath $pngPath
Copy-Item -LiteralPath $skelBackupPath -Destination $skelFile.FullName -Force

Write-Output ("FOLDER={0}" -f $resolvedFolder)
Write-Output ("ATLAS={0}" -f $atlasFile.Name)
Write-Output ("PNG={0}" -f ([System.IO.Path]::GetFileName($pngPath)))
Write-Output ("SKEL={0}" -f $skelFile.Name)
Write-Output ("PIXELS_CHANGED={0}" -f $pixelsChanged)
Write-Output ("BACKUP_ATLAS={0}" -f ([System.IO.Path]::GetFileName($atlasBackupPath)))
Write-Output ("BACKUP_PNG={0}" -f ([System.IO.Path]::GetFileName($pngBackupPath)))
Write-Output ("BACKUP_SKEL={0}" -f ([System.IO.Path]::GetFileName($skelBackupPath)))

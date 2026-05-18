# Spine Straight Alpha Tool

A small PowerShell tool for converting a Spine export folder from premultiplied alpha to straight alpha without reopening Spine.

## What It Does

This repo contains one script:

- `Convert-SpineFolderToStraightAlpha.ps1`
  - Processes a folder containing one Spine `.atlas`, one matching `.png`, and one matching `.skel`.
  - Backs up the original files to `.bak`.
  - Rewrites the PNG in straight alpha form.
  - Rewrites the atlas to `pma:false`.
  - Restores the `.skel` under the original file name.

## Requirements

- Windows PowerShell 7 or newer recommended
- `.png`, `.atlas`, `.skel` files already exported from Spine
- Godot users: reimport the rewritten files after running the tool

## Quick Start

Process one Spine asset folder in place:

```powershell
.\Convert-SpineFolderToStraightAlpha.ps1 -FolderPath ".\yourFolderPath"
```

Force overwrite existing `.bak` backups:

```powershell
.\Convert-SpineFolderToStraightAlpha.ps1 -FolderPath ".\yourFolderPath" -Force
```

## Folder Tool Behavior

Given a folder that contains one original `.atlas`, one referenced `.png`, and one matching `.skel`, the folder tool will:

1. Rename the original `.atlas` to `.atlas.bak`
2. Rename the original `.png` to `.png.bak`
3. Rename the original `.skel` to `.skel.bak`
4. Create a new atlas at the original file name with `pma:false`
5. Create a new PNG at the original file name in straight alpha form
6. Copy the `.skel.bak` back to the original `.skel` file name

## Notes

- The folder tool expects exactly one original `.atlas` in the target folder.
- Existing `.bak` files are preserved unless `-Force` is passed.
- The tool does not rewrite `.import` files.
- In Godot, reimport the regenerated `.png` and `.atlas` after running the tool.

## Repository Layout

```text
scripts/
  Convert-SpineFolderToStraightAlpha.ps1
```

---

## 中文说明

这是一个小型 PowerShell 工具，用来在无 Spine 的前提下，把一整套 Spine 导出目录从 premultiplied alpha 转成 straight alpha。

## 它能做什么

这个仓库目前只有一个脚本：

- `Convert-SpineFolderToStraightAlpha.ps1`
  - 处理一个包含 Spine `.atlas`、对应 `.png` 和对应 `.skel` 的目录
  - 自动把原始文件备份成 `.bak`
  - 把 PNG 改写为 straight alpha 版本
  - 把 atlas 中的 `pma` 改成 `false`
  - 把 `.skel` 按原文件名恢复回来

## 运行要求

- 建议使用 Windows PowerShell 7 或更高版本
- 目录中已经有 Spine 导出的 `.png`、`.atlas`、`.skel`

## 快速开始

原地处理一个 Spine 资源目录：

```powershell
.\Convert-SpineFolderToStraightAlpha.ps1 -FolderPath ".\yourFolderPath"
```

如果目录里已经存在 `.bak`，强制覆盖旧备份：

```powershell
.\Convert-SpineFolderToStraightAlpha.ps1 -FolderPath ".\yourFolderPath" -Force
```

## 脚本行为

如果目标目录里包含一份原始 `.atlas`、atlas 引用的 `.png`，以及一个匹配的 `.skel`，脚本会按这个顺序处理：

1. 把原始 `.atlas` 重命名为 `.atlas.bak`
2. 把原始 `.png` 重命名为 `.png.bak`
3. 把原始 `.skel` 重命名为 `.skel.bak`
4. 在原 atlas 文件名位置生成一个新 atlas，并写入 `pma:false`
5. 在原 png 文件名位置生成一个新的 straight alpha PNG
6. 把 `.skel.bak` 复制回原 `.skel` 文件名

## 注意事项

- 脚本要求目标目录中有且只有一份原始 `.atlas`
- 如果没有传 `-Force`，已有 `.bak` 会被保留，脚本会直接报错退出



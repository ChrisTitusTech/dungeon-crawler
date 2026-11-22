# Prerequisites

Everything needed to build, run, and export the game on Windows or Linux.

## Required tools

| Tool | Version | Used for |
| --- | --- | --- |
| Godot Engine (standard build, not .NET) | 4.7.2 stable (pinned) | Editor, running the game, headless tests, exports |
| Godot export templates | 4.7.2 stable (must match the editor) | Windows and Linux export builds |
| Git | 2.40 or newer | Version control |
| Git LFS | 3.x | Audio and source-art files (see `.gitattributes`) |
| GitHub CLI (`gh`) | 2.x | Optional: pull requests and CI from the terminal |

The Godot version is pinned. Everyone on the project, and CI, must use the same version; upgrade it deliberately in one commit that also updates this file.

GUT 9.7.1 comes with the project under `addons/gut/`. [Upstream source](https://github.com/bitwes/Gut/tree/aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605/addons/gut)

## Windows

```powershell
winget install --id Git.Git -e
winget install --id GitHub.GitLFS -e
winget install --id GitHub.cli -e
winget install --id GodotEngine.GodotEngine -e --version 4.7.2
git lfs install
```

Winget only creates the `godot` and `godot_console` commands when run from an elevated (administrator) terminal. If `godot --version` is not found after installing, either reinstall from an elevated terminal or add two shim files to `%LOCALAPPDATA%\Microsoft\WinGet\Links` (already on `PATH`):

```powershell
$pkg = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Directory -Filter 'GodotEngine.GodotEngine*').FullName
$links = "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
Set-Content "$links\godot.cmd" "@echo off`r`n`"$pkg\Godot_v4.7.2-stable_win64.exe`" %*" -Encoding ASCII
Set-Content "$links\godot_console.cmd" "@echo off`r`n`"$pkg\Godot_v4.7.2-stable_win64_console.exe`" %*" -Encoding ASCII
```

Export templates, either from the editor (**Editor > Manage Export Templates > Download and Install**) or from the terminal:

```powershell
$dst = "$env:APPDATA\Godot\export_templates\4.7.2.stable"
$tmp = "$env:TEMP\godot-templates"
New-Item -ItemType Directory -Force -Path $tmp, $dst | Out-Null
curl.exe -fL -o "$tmp\templates.zip" https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
Expand-Archive "$tmp\templates.zip" -DestinationPath $tmp -Force
Move-Item "$tmp\templates\*" $dst -Force
Remove-Item -Recurse -Force $tmp
```

## Linux

Install Git, Git LFS, and optionally `gh` from your distribution's packages, then run `git lfs install`.

Distribution packages of Godot are often a different version, so install the pinned build directly:

```bash
mkdir -p ~/.local/bin ~/.local/share/godot/export_templates/4.7.2.stable
cd "$(mktemp -d)"
curl -fLO https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip Godot_v4.7.2-stable_linux.x86_64.zip
install -m 755 Godot_v4.7.2-stable_linux.x86_64 ~/.local/bin/godot

curl -fL -o templates.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
unzip templates.zip
mv templates/* ~/.local/share/godot/export_templates/4.7.2.stable/
```

Make sure `~/.local/bin` is on your `PATH`.

## Verify

Open a new terminal so `PATH` changes apply, then run:

| Command | Expected |
| --- | --- |
| `godot --version` | Starts with `4.7.2.stable` |
| `git --version` | 2.40 or newer |
| `git lfs version` | `git-lfs/3.x` |
| `gh --version` | 2.x (optional) |

Export templates are installed if this file exists and contains `4.7.2.stable`:

- Windows: `%APPDATA%\Godot\export_templates\4.7.2.stable\version.txt`
- Linux: `~/.local/share/godot/export_templates/4.7.2.stable/version.txt`

## Hardware

Any machine that runs the Godot 4 editor: a 64-bit x86 CPU and a GPU with Vulkan or OpenGL 3.3 support.

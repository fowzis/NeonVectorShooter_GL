# Building and running NeonVectorShooter_GL

This project targets **.NET 10** (`net10.0`) and **MonoGame 3.8.1** (**DesktopGL** / OpenGL). The MonoGame **content pipeline** builds textures, sounds, fonts, and **HLSL `.fx` effect files** at compile time.

---

## Prerequisites (all platforms)

| Requirement | Notes |
|---------------|--------|
| **.NET SDK 10** | Must satisfy `TargetFramework` `net10.0` in `NeonVectorShooter_GL.csproj`. [Download](https://dotnet.microsoft.com/download). Check with `dotnet --version`. |
| **Internet (first build)** | `dotnet restore` downloads NuGet packages and restores **local tools** from `.config/dotnet-tools.json` (`dotnet-mgcb`, etc.). |

Optional but useful:

| Optional | Notes |
|----------|--------|
| **Git** | To clone and update the repository. |
| **MonoGame for VS Code** (Cursor / VS Code) | [Marketplace: MonoGame for VS Code](https://marketplace.visualstudio.com/items?itemName=r88.monogame). Helps with templates and MGCB; not required for `dotnet build`. |
| **C# Dev Kit** (VS Code) | Recommended by the MonoGame extension for solution-style features. |

---

## Windows

### 1. Install the .NET SDK

Install the **.NET 10 SDK** (or newer in the same major line, per your `global.json` if you add one). Restart the terminal after installation.

### 2. Clone and build

```powershell
git clone <repository-url>
cd NeonVectorShooter_GL
dotnet restore
dotnet build
```

A successful build produces the game under `bin/Debug/net10.0/` (and processed content copied for output). On Windows you typically get an `.exe`; on Linux use **`dotnet run`** or run the generated **`NeonVectorShooter_GL`** host if present.

### 3. Run

```powershell
dotnet run --project NeonVectorShooter_GL.csproj
```

Or open `NeonVectorShooter_GL.sln` in **Visual Studio 2022** / **Visual Studio 2026** and press **F5**.

### 4. Visual Studio Code / Cursor on Windows

- Ensure `.vscode\launch.json` points to **`bin\Debug\net10.0\`** (not `net6.0`).
- **Effect compilation** on Windows uses the normal Microsoft toolchain inside MGFXC; **Wine is not used**.

---

## Linux

### 1. Install the .NET SDK

Install **.NET SDK 10** for your distribution (package feed, tarball, or Microsoft’s install script). Verify:

```bash
dotnet --version
```

### 2. OS packages for the content pipeline

The **MGCB** step needs extra tools on Linux:

| Package / tool | Purpose |
|----------------|---------|
| **Wine** (64-bit, **Wine 8+**) | MGFXC runs the Windows effect compiler under Wine. Ubuntu: `wine` package provides **`/usr/lib/wine/wine64`** even when `/usr/bin/wine64` is missing. |
| **7-Zip** (`7z`) | Used by `scripts/setup-mgfxc-wine.sh` to unpack the .NET Windows SDK zip and the Firefox-based `d3dcompiler_47` payload. |
| **`wget` or non-Snap `curl`** | Large downloads; Snap’s `curl` often fails with `curl: (23)` — prefer **`wget`** (`sudo apt install wget`) or distro `curl`. |

Example (Debian / Ubuntu):

```bash
sudo apt update
sudo apt install -y wine64 winetricks p7zip-full wget
```

If your distro splits Wine differently, ensure a working **64-bit Wine** and that **`wine64`** resolves to the real loader (see repository `scripts/setup-mgfxc-wine.sh`).

### 3. One-time Wine prefix for MGFXC (effects)

HLSL `.fx` files are compiled through **MGFXC**, which expects a Wine prefix with **.NET 6 (Windows) SDK** and **`d3dcompiler_47.dll`**. This repository includes:

- **`scripts/setup-mgfxc-wine.sh`** — downloads dependencies, initializes **`~/.winemonogame`** (or **`$MGFXC_WINE_PATH`**), extracts the SDK and `d3dcompiler_47`.
- **`Directory.Build.targets`** — on Linux, sets **`MGFXC_WINE_PATH`** and prepends **`~/.local/bin`** to **`PATH`** when invoking `dotnet mgcb`, so **IDE builds** find **`wine64`** even if the shell profile does not.

Run once (or after wiping the prefix):

```bash
chmod +x scripts/setup-mgfxc-wine.sh
./scripts/setup-mgfxc-wine.sh
```

Then ensure **`~/.local/bin`** is on your **`PATH`** for interactive terminals (the script links **`wine64`** → **`/usr/lib/wine/wine64`** when appropriate). Example for Bash (`~/.bashrc`):

```bash
[[ -d "$HOME/.local/bin" ]] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH="$HOME/.local/bin:$PATH"
```

`Directory.Build.targets` already prepends **`$HOME/.local/bin`** for **MSBuild**’s `dotnet mgcb` invocation, so **`dotnet build`** from Cursor often works without extra shell configuration.

### 4. Fonts (spritefont)

The content pipeline resolves the **Nova Square** font from **`Content/NovaSquare.ttf`** (bundled in the repo). You do **not** need to install that font system-wide on Linux.

### 5. Clone and build

```bash
git clone <repository-url>
cd NeonVectorShooter_GL
dotnet restore
dotnet build
```

### 6. Run

```bash
dotnet run --project NeonVectorShooter_GL.csproj
```

SDL2 / OpenGL runtime libraries are normally pulled in via NuGet **runtimes** for MonoGame DesktopGL; if the game fails to start with a native library error, install your distro’s **SDL2** and graphics stack packages (names vary by distribution).

---

## What `dotnet build` does here

1. **Restore** — NuGet packages + **`dotnet tool restore`** (see `NeonVectorShooter_GL.csproj` `RestoreDotnetTool` target).
2. **MGCB** — Builds `Content/Content.mgcb` (textures, audio, **`NovaSquare.spritefont`**, **`Shaders/*.fx`**).
3. **C# compile** — Emits `NeonVectorShooter_GL.dll` under `bin/<Configuration>/net10.0/`.

Clean content outputs if MGCB behaves oddly after toolchain changes:

```bash
rm -rf Content/bin Content/obj
dotnet build
```

---

## Troubleshooting

| Symptom | What to check |
|---------|----------------|
| **Linux: MGCB / `.fx` failures, exit code 3** | Run **`./scripts/setup-mgfxc-wine.sh`**; Wine **≥ 8**; **`wine64`** must be the **64-bit loader** (e.g. symlink to **`/usr/lib/wine/wine64`**, not a thin `wine` wrapper). |
| **Linux: `curl: (23)` during setup** | Use **`wget`** or **`/usr/bin/curl`**, not Snap `curl`. |
| **Linux: `Could not find "Nova Square" font`** | Use the repo’s **`Content/NovaSquare.ttf`** and **`NovaSquare.spritefont`** (`FontName` matches the TTF basename). |
| **Debugger: DLL not found, path shows `net6.0`** | Update **`.vscode/launch.json`** `program` to **`bin/Debug/net10.0/NeonVectorShooter_GL.dll`**. |
| **“Just My Code” / Spectre.Console when debugging** | Informational when stepping into optimized CLI dependencies; set **`"justMyCode": false`** in the launch configuration only if you need to debug into that code. |

---

## Reference files in this repo

| File | Role |
|------|------|
| `NeonVectorShooter_GL.csproj` | Target framework, MonoGame packages, tool restore. |
| `Content/Content.mgcb` | Content pipeline definition. |
| `.config/dotnet-tools.json` | Pinned **`dotnet-mgcb`** version. |
| `Directory.Build.targets` | Linux: **`MGFXC_WINE_PATH`** + **`PATH`** for MGCB. |
| `scripts/setup-mgfxc-wine.sh` | Linux: Wine prefix + .NET 6 in Wine + `d3dcompiler_47`. |
| `.vscode/launch.json` | Debug target path (must match **`net10.0`**). |

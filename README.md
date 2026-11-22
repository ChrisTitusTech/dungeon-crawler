# Dungeon Crawler

Working title. A single-player 2D party RPG for Windows and Linux, built in Godot 4 with GDScript.

You are a contestant in a lethal, televised 18-floor dungeon run by a snarky System AI. Explore top-down tile-based floors with a party of up to four, fight visible enemies in JRPG-style menu battles, and survive each floor before it collapses. Factions, crafting, and body-part injuries run underneath.

## Status

The Godot project opens to a placeholder title screen. Grid exploration is next in the [roadmap](docs/roadmap.md).

## Documentation

- [Game design](docs/game-design.md): what the game is and how its systems work.
- [Technical design](docs/technical-design.md): engine, architecture, and project layout.
- [Roadmap](docs/roadmap.md): milestones, backlog, risks, and open questions.
- [Prerequisites](PREREQUISITES.md): tools to install and how to verify them.

## Getting started

Install the tools, then open `project.godot` in the editor or run `godot --editor --path .` from the repo root. Press F5 to run the project. [Prerequisites](PREREQUISITES.md)

### Run tests

From the repo root, import the project and run the GUT suite.

```sh
godot --headless --import
godot --headless --script res://addons/gut/gut_cmdln.gd -gexit
```

On Windows, use `godot_console` to see command output and exit codes.

### Export builds

In the editor, select **Project > Export** and choose **Windows Desktop** or **Linux**. To export from the terminal, create the `build/windows` and `build/linux` output directories, then run these commands from the repo root.

```sh
godot --headless --export-release "Windows Desktop" build/windows/dungeon-crawler.exe
godot --headless --export-release Linux build/linux/dungeon-crawler.x86_64
```

GitHub Actions runs the tests on pushes and pull requests, then uploads both release builds as artifacts. [CI workflow](.github/workflows/ci.yml)

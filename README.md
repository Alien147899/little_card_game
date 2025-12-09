## Little Card Game (Ten and a Half)

A small card game prototype built with [LÖVE](https://love2d.org/) (Love2D).  
The main mode implements the classic “Ten and a Half” (10.5) rules, with:

- Local mode: player vs AI on the same computer.
- LAN prototype: experimental host/join over local network.

This repository only contains the game source code and assets.  
You need a LÖVE runtime installed to run it.

---

## Requirements

- **LÖVE (Love2D) 11.x**
  - Windows: download from <https://love2d.org/>
  - macOS / Linux: install from your package manager or the official site.

---

## Getting Started

### 1. Download the project

Clone with Git:

```bash
git clone https://github.com/Alien147899/little_card_game.git
cd little_card_game
```

or download the ZIP from GitHub and extract it.

### 2. Run the game

From the project root (the folder that contains `main.lua`):

```bash
love .
```

On Windows you can also:

1. Install LÖVE.
2. Drag the `little_card_game` folder onto `love.exe`, **or**
3. Create a shortcut to `love.exe` and set the working directory to this folder.

If LÖVE starts correctly you should see the main menu with the game title and buttons.

---

## Controls & Gameplay

### Menu

- Use the mouse to click buttons:
  - **Local Mode (Player vs AI)** – start a local 10.5 match.
  - **LAN Mode (In Development)** – experimental LAN lobby and play.
  - **Edit Profile** – change player name (avatar is currently disabled).
  - **View Tutorial** – in‑game help pages.

### Table (local / LAN game)

- Drag cards in your hand to reorder them.
- Use the bottom buttons:
  - **Start New Round** – start a new banker/idle round.
  - **Hit** – draw a card.
  - **Stand** – stop drawing and let the other side act.
- Press **Esc** to open the pause menu (return to main menu or resume).

The on‑screen messages explain whose turn it is, who is the banker, and the result of each round.

---

## Project Structure

Only the most relevant files are listed here:

- `main.lua` – game entry point, window setup and scene switching.
- `conf.lua` – LÖVE configuration (window size, title, etc.).
- `config.lua` – game constants, card assets configuration, shader options.
- `game_logic.lua` – core Ten and a Half rules and round flow.
- `ai.lua` – AI logic for the opponent.
- `ui.lua` – card layout and rendering (hover effects, shaders, zones, etc.).
- `scenes/menu.lua` – main menu.
- `scenes/table.lua` – game table scene (cards, buttons, status text).
- `scenes/lan.lua` – LAN lobby and join/host UI.
- `modes/local_mode.lua` – local (player vs AI) flow.
- `modes/lan_mode.lua` – LAN mode state machine.
- `lan/` – low‑level LAN networking helpers (client/host/discovery/queue).
- `assets/` – images, fonts, and other static resources.
- `shaders.lua`, `shaders/` – visual shader effects and shader source.
- `profile.lua` – simple profile storage (player name), saved to `profile.json`.

The directory `old_version/` and large packaged builds are **not** part of this repository on GitHub, to keep the repo size reasonable.

---

## Notes

- The LAN mode is experimental and may be unstable; the local mode is the primary way to play.
- All in‑game messages and comments have been translated to English.

If you run into issues running the game with LÖVE, open an issue on GitHub with your OS version, LÖVE version, and any error messages from the console.


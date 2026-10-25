# Crazy Cage Football (Godot 4 3D)

> **Genre:** 3D Physics Cage Soccer / Micro-Sports  
> **Target Engine:** Godot Engine 4.x (Forward+ / Mobile Renderer, 3D Physics)  
> **Inspired by:** *Zıppır: Kafes Futbolu* (Çağrı Aksay, Bilkent University, ~2001/2002)  
> **Development Standard:** Spec-Driven Intent-Engineering nach Vorlesung *07: Agentic Game Development*

---

## 🎮 High Concept
3D-Käfigfußball ohne Ausball!  
Zwei rollende, elastische Kugel-Spieler mit Comic-Augen treten in einem geschlossenen Drahtgitterkäfig gegeneinander an. Neben flachem Rollen ermöglicht die Schlüsselmechanik **`Zıplama` (Sprung)** spektakuläre Volley-Schüsse, Heber und Kopfballtore über die Käfigwände und Decke.

---

## 🕹️ Steuerung (Local 2-Player Couch Mode)

| Aktion | Spieler 1 (Rot) | Spieler 2 (Blau) | Gamepad | Touch / Tablet |
| :--- | :--- | :--- | :--- | :--- |
| **Bewegung ($X/Z$)** | `W`, `A`, `S`, `D` | Pfeiltasten (`↑`, `←`, `↓`, `→`) | Linker Analogstick | Virtueller Touch-Joystick (links) |
| **Sprung (`Zıplama`)** | `Space` oder `Q` | `Enter` oder `Rechte Shift` | Button A | Touch-Button `[⚽ JUMP]` (rechts) |
| **Sprint / Rammen** | `Linke Shift` | `Rechtes Strg` | Button X | Touch-Button `[⚡ BOOST]` (rechts) |
| **Neustart** | `R` | `R` | Start-Button | Menü-Button / Stats-Screen |
| **Pause / Kamera** | `ESC` / `F` | `ESC` | Start / Y | Quick-Buttons `[⏸️]` & `[🎥]` (oben) |

---

## 🕹️ Hotkeys & System-Steuerung

| Hotkey / Gamepad | Funktion |
| :--- | :--- |
| `[D-Pad]` / Pfeiltasten | Menü- & Lobby-Navigation (Gamepad Focus-Routing) |
| `[A]` / `[Space]` / `[Enter]` | Fokussierte Lobby-Option / Button betätigen |
| `[START]` | Match-Anstoß aus Lobby / Spiel pausieren |
| `[F]` / Gamepad `[Y]` / `[LB]` | Kamera-Fokus umschalten (`Dynamic`, `Ball-Cam`, `Broadcast`) – auch in Lobby |
| `[T]` / Gamepad `[RB]` | Arena-Theme umschalten (`Industrial`, `Sunny`, `Cyber`) |
| `[P]` / Gamepad `[X]` | Power-Ups aktivieren / deaktivieren |
| `[R]` | Match-Neustart / Rematch |
| `[ESC]` / Gamepad `[B]` | Zurück zur Pre-Match-Lobby / Pausemenü schließen |
| `[M]` | Musik stummschalten / reaktivieren |
| `[L]` | Sprache umschalten (Deutsch 🇩🇪 / Englisch 🇬🇧) |
| `[F11]` | Vollbild / Fenstermodus umschalten |

---

## 🏗️ Projekt-Architektur

- **`docs/gdd/MICRO_GDD.md`:** 5-Punkte-Spezifikation (High Concept, Core Loop, Controls, State Space, Scoring).
- **`scripts/config.gd` (`CageConfig`):** Käfig-Dimensionen ($24\times 14\times 7\,\text{m}$), Bounciness-Werte, Sprungkraft, Timer.
- **`scripts/state_manager.gd` (`CageStateManager`):** Match-State-Machine (`KickOff` $\to$ `Playing` $\to$ `Celebration` $\to$ `Reset` $\to$ `MatchOver`).
- **`scripts/player.gd` (`CagePlayer`):** Kugel-Athlet mit Boden-Kinematik, vertikalem `Zıplama`-Sprung und prozedural auf den Ball blickenden Comic-Augen.
- **`scripts/ball.gd` (`SoccerBall`):** Hochelastischer Fußball ($e = 0.82$) mit realistischer Wand- und Bandenreflexion und `continuous_cd`.
- **`scripts/cage_camera.gd` (`CageCamera`):** Dynamische Weitwinkel-Kamera mit Ball- und Spieler-Tracking.
- **`scripts/power_up.gd` (`CagePowerUp`):** 5 Power-Up-Typen (Super-Shot, Speed-Boots, Magnetfuß, Freeze-Tackle, Cage-Shaker).
- **`i18n/`:** Zweisprachige Lokalisierung (Deutsch / Englisch) via Godot `TranslationServer`.
- **`audio/`:** Juhani Junkala Chiptunes, Pfeife (`duduk.wav`), Kicks (`cato.wav`, `pato.wav`).
- **`scenes/main.tscn`:** Hauptszene mit Gitterkäfig, Toren, Netzen und Match-HUD.

---

## 🎵 Musik & Audio-Attribution

Aus der Sammlung *"5 Chiptunes (Action)"* von **Juhani Junkala (SubspaceAudio)** via OpenGameArt ([CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)):
- **Menü-Musik (`audio/music_menu.ogg`):** *"Title Screen"* (Pre-Match Lobby)
- **Match-Musik (`audio/music_action_level1.ogg`):** *"Level 1"* (Gameplay)
- **Fallback-Synthese:** Eingebauter prozeduraler 16-Bit-Chiptune-Synthesizer in `scripts/cage_sound_manager.gd`.
- **Musik-Steuerung:** Taste `[M]` schaltet die Musik stumm. Bei Torerfolg wird die BGM automatisch geduckt.

---

## 🚀 Export & GitHub Release (v0.2.2)

Automatisierte Multiplattform-Builds werden per GitHub Actions (`.github/workflows/export.yml`) bei jedem Git-Tag `v*` erstellt:
- **Windows Desktop:** `CrazyCageFootball-Windows.zip` (`.exe`)
- **Linux:** `CrazyCageFootball-Linux.zip` (`.x86_64`)
- **macOS:** `CrazyCageFootball-macOS.zip` (`.app`)
- **Web (HTML5):** `CrazyCageFootball-Web.zip` (`index.html`)

---

## 🧪 Headless CI/CD & Unit Tests

Das Spiel verfügt über einen vollständig headless lauffähigen Test-Runner:

```bash
godot --headless -s test_gameplay.gd
```
Exits mit `0` bei Erfolg.

---

## 🔮 Geplante Weiterentwicklungen & CI/CD Roadmap

- **macOS Code Signing & Notarisierung in CI/CD:**
  - Automatisches Signieren mit Apple Developer ID (`codesign` mit Hardened Runtime) und Notarisierung via `notarytool` im GitHub-Actions-Workflow (`.github/workflows/export.yml`), damit macOS-Builds ohne Gatekeeper-Warnung direkt startbar sind.
  - Erforderliche GitHub Actions Secrets: `APPLE_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_ID`, `APPLE_ID_PASSWORD`, `APPLE_TEAM_ID`.
- **itch.io Verteilung via Butler:**
  - Automatischer Upload der Web- und Desktop-Artefakte per Butler CLI in eigene Kanäle (`html5`, `windows`, `osx`, `linux`).
- **Mac App Store Distribution:**
  - Bereitstellung mit Sandboxing-Entitlements und Apple Distribution Zertifikat als signiertes `.pkg` via Transporter / `xcrun altool`.


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

| Aktion | Spieler 1 (Rot) | Spieler 2 (Blau) | Gamepad |
| :--- | :--- | :--- | :--- |
| **Bewegung ($X/Z$)** | `W`, `A`, `S`, `D` | Pfeiltasten (`↑`, `←`, `↓`, `→`) | Linker Analogstick |
| **Sprung (`Zıplama`)** | `Space` oder `Q` | `Enter` oder `Rechte Shift` | Button A |
| **Sprint / Rammen** | `Linke Shift` | `Rechtes Strg` | Button X |
| **Neustart** | `R` | `R` | Start-Button |

---

## 🏗️ Projekt-Architektur

- **`docs/gdd/MICRO_GDD.md`:** 5-Punkte-Spezifikation (High Concept, Core Loop, Controls, State Space, Scoring).
- **`scripts/config.gd` (`CageConfig`):** Käfig-Dimensionen ($24\times 14\times 7\,\text{m}$), Bounciness-Werte, Sprungkraft, Timer.
- **`scripts/state_manager.gd` (`CageStateManager`):** Match-State-Machine (`KickOff` $\to$ `Playing` $\to$ `Celebration` $\to$ `Reset` $\to$ `MatchOver`).
- **`scripts/player.gd` (`CagePlayer`):** Kugel-Athlet mit Boden-Kinematik, vertikalem `Zıplama`-Sprung und prozedural auf den Ball blickenden Comic-Augen.
- **`scripts/ball.gd` (`SoccerBall`):** Hochelastischer Fußball ($e = 0.82$) mit realistischer Wand- und Bandenreflexion.
- **`scripts/cage_camera.gd` (`CageCamera`):** Dynamische Weitwinkel-Kamera mit Ball- und Spieler-Tracking.
- **`audio/`:** Originale Sound-Effekte (`duduk.wav` Schiedsrichterpfeife, `cato.wav` & `pato.wav` Ballstöße).
- **`scenes/main.tscn`:** Hauptszene mit Gitterkäfig, Toren, Netzen und Match-HUD.

---

## 🎵 Musik & Audio-Attribution

- **Hintergrundmusik:** *"Level 1"* aus der Sammlung *"5 Chiptunes (Action)"* von **Juhani Junkala (SubspaceAudio)** via OpenGameArt ([CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)).
- **Fallback-Synthese:** Eingebauter prozeduraler 16-Bit-Chiptune-Synthesizer in `scripts/cage_sound_manager.gd`.
- **Musik-Steuerung:** Mit Taste `[M]` kann die Musik jederzeit im Spiel und in der Lobby stummgeschaltet bzw. reaktiviert werden. Bei Torerfolg wird die BGM automatisch kurz geduckt.

---

## 🧪 Headless CI/CD & Unit Tests

Das Spiel verfügt über einen vollständig headless lauffähigen Test-Runner:

```bash
godot --headless -s test_gameplay.gd
```
Exits mit `0` bei Erfolg.

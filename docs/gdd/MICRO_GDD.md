# Micro-GDD: Crazy Cage Football (Godot 4 3D)

> **Standard:** Micro Game Design Document nach Vorlesung *07: Agentic Game Development*  
> **Projekt:** Crazy Cage Football (Godot 4 3D)  
> **Ziel-Engine:** Godot Engine 4.x (Forward+ / Mobile)  
> **Zielordner:** `artifacts/consumers/production/godot/gd-godot-crazy-cage-football`  
> **Vorlage:** *Zıppır: Kafes Futbolu* (Çağrı Aksay, Bilkent University, ~2001/2002)  
> **Status:** Phase 1 Spezifikation (Scaffolding & Core Loop)

---

## 1. High Concept
*Crazy Cage Football* ist ein rasantes 3D-Physik-Fußballspiel für 2 Spieler (1v1, erweiterbar auf 2v2) in einem vollständig geschlossenen Drahtgitterkäfig. Spieler steuern elastische Kugeln mit Comic-Augen und nutzen neben der Bodenbewegung eine gezielte **Sprung-Taste (`Zıplama`)** für spektakuläre Volleys, Heber und Kopfballtore über die Käfigbanden.

---

## 2. Core Loop (5–10 Sekunden)

```mermaid
flowchart LR
    A["Ball anvisieren\n(Positionieren & Tempo)"] --> B{"Taktik"}
    B -->|Flachpass / Schuss| C["Bodenstoß gegen Ball"]
    B -->|Sprung (Zıplama)| D["Im Flug gegen Ball prallen\n(Hoher Heber / Volley)"]
    B -->|Bank Shot| E["Wand-/Deckenreflexion\nr = v - 2(v·n)n"]
    C --> F{"Tor oder Abpraller"}
    D --> F
    E --> F
    F -->|Tor!| G["Trillerpfeife & Torjubel\nReset zum Anstoß"]
    F -->|Kein Tor| A
    G --> A
```

---

## 3. Controls & Input

| Aktion | Spieler 1 (Rot) | Spieler 2 (Blau) | Gamepad (P1/P2) |
| :--- | :--- | :--- | :--- |
| **Bewegung ($X/Z$)** | `W`, `A`, `S`, `D` | Pfeiltasten (`↑`, `←`, `↓`, `→`) | Linker Analogstick / D-Pad |
| **Sprung (`Zıplama`)** | `Space` oder `Q` | `Enter` oder `Rechte Shift` | Button A / Bottom Action |
| **Sprint / Rammen** | `Linke Shift` | `Rechtes Strg` | Button X / Trigger |
| **Pause / Reset** | `P` / `R` | `P` / `R` | Start-Button |

---

## 4. State Space & Entities

### 4.1 Entities
1. **Zıppır Player Ball (`RigidBody3D`):**
   - Radius: $0.6\,\text{m}$, Masse: $3.0\,\text{kg}$.
   - Vertikaler Sprungimpuls: $+10.0\,\text{m/s}$ bei Tastendruck (wenn Bodenkontakt).
   - Comic-Augen blicken prozedural immer auf den Ball (`look_at(ball.position)`).
2. **Fußball (`RigidBody3D`):**
   - Radius: $0.35\,\text{m}$, Masse: $0.45\,\text{kg}$.
   - Physik-Material: `bounce = 0.82` (hohe Elastizität für lebhafte Bandenabpraller), `friction = 0.25`.
3. **Käfig (`StaticBody3D`):**
   - Maße: $24\,\text{m} \times 14\,\text{m} \times 7\,\text{m}$.
   - Feste Seitenbanden ($1\,\text{m}$ hoch), darüber Drahtgitter bis zur Decke ($7\,\text{m}$).
4. **Tore & Netze (`StaticBody3D` + `Area3D`):**
   - Zwei Tore an den Stirnseiten ($4\,\text{m}$ breit, $2\,\text{m}$ hoch).
   - `Area3D` hinter der Torlinie detektiert den Ball für Torerfolge.

### 4.2 State Space des Matches
- `LOBBY` (Steuerungs-Auswahl 1v1 bis 2v2, Team-Toggles und Power-Up Schalter `[P]`)
- `KICKOFF` (Spieler auf Startpositionen, Ball in Spielfeldmitte, wartet auf Anstoß)
- `WARMUP` (3-Sekunden Countdown vor Matchbeginn)
- `PLAYING` (Match läuft, 3-Minuten-Timer zählt herunter)
- `GOAL_SCORED` (Torpfiff ertönt, Freeze-Frame & Torkamera)
- `CELEBRATION` (2 Sekunden Torjubel)
- `RESET` (Sanfter Reset zum Anstoßkreis)
- `MATCH_OVER` (Endstand, Abpfiff, Siegeranzeige)

### 4.3 Zufällige Pickups an den Käfigbanden (Konsolidiert)
In der Lobby per Taste `[P]` ein- und ausschaltbar. Bei aktivem Modus spawnen bis zu 3 rotierende 3D-Tokens entlang der 6 Banden-Zonen:
1. **🔥 Super-Shot / Feuerball:** Nächster Schuss besitzt $2.2\times$ Speed & Flammen-Aura; wirft Verteidiger in der Flugbahn um.
2. **⚡ Speed-Boots:** Sprint-Boost für $6\,\text{s}$ ($+60\,\%$ Beschleunigung, $+55\,\%$ Höchstgeschwindigkeit).
3. **🧲 Magnetfuß / Klebeball:** Zieht den Ball im $3.8\,\text{m}$-Nahbereich magnetisch an für enges Dribbeln.
4. **❄️ Freeze-Tackle:** Der nächste Bodycheck/Tackle friert den Gegenspieler für $2.0\,\text{s}$ als Eisblock ein.
5. **💥 Cage-Shaker:** Sofortige Stoßwelle erschüttert den Käfig und schleudert alle Rivalen mit hoher Wucht von den Banden weg.

---

## 5. Win/Loss & Scoring

- **Punktevergabe:**
  - Überquert der Ball vollständig die Torlinie eines Tores, erhält das gegnerische Team $+1$ Tor.
  - Signalton: Schiedsrichter-Trillerpfeife (`duduk.wav`).
- **Match-Ende:**
  - Reguläre Spielzeit: **3 Minuten (180 s)**.
  - Das Team mit den meisten Toren gewinnt.
  - Bei Torgleichstand: **Golden Goal** (nächstes Tor entscheidet sofort)!

---

## 6. Architekturvorgaben (Godot 4)

- `scripts/config.gd`: Zentral isolierte Physik-, Käfig- und Matchparameter.
- `scripts/state_manager.gd`: Match-State-Machine (`KickOff`, `Playing`, etc.).
- `scripts/player.gd`: Kugel-Kinematik mit horizontalem Rollen und vertikalem `Zıplama`-Sprung.
- `scripts/ball.gd`: Physikalischer Fußball mit Reflexions- und Kugelstoß-Logik.
- `scripts/cage_camera.gd`: Dynamische Weitwinkel-Kamera, die Tore, Ball und Spieler im Blick hält.
- `test_gameplay.gd`: Headless Test-Runner für CI/CD (`godot --headless -s test_gameplay.gd`).

# Takbo, Jusko! 🐕💨

> *"Run, for crying out loud!"*

A top-down survival arcade game rooted in Filipino street culture, where a lone Christmas caroler must outrun a relentless pursuing dog through dynamically distorting urban streets.

**Developed for COSC 304 – Introduction to Artificial Intelligence**
Polytechnic University of the Philippines, College of Computer and Information Sciences

**Proponents:** Argallon, Dazel C. · Babasa, Maria Hanna V. · Borondia, Kurt Ashley T. · Castillo, Julianna Leila T.

---

## Table of Contents

- [About the Game](#about-the-game)
- [Gameplay Overview](#gameplay-overview)
- [Setup & Installation](#setup--installation)
- [AI Components](#ai-components)
  - [Hunter AI — A* Search with Predictive Targeting](#1-hunter-ai--a-search-with-predictive-targeting)
  - [Director AI — Decision Tree System](#2-director-ai--decision-tree-system)
  - [Chaos Engine — Simulated Annealing](#3-chaos-engine--simulated-annealing)
- [Architecture Overview](#architecture-overview)
- [Controls](#controls)
- [Win & Lose Conditions](#win--lose-conditions)
- [References](#references)

---

## About the Game

*Takbo, Jusko!* draws inspiration from classic pursuit-and-evasion titles like Pac-Man, but introduces a defining mechanic: **the environment itself is an active participant**. The map dynamically rotates, flips, and distorts in real time, forcing the player to continuously reassess their orientation and movement strategy.

Unlike conventional arcade survival games, this design deliberately omits standard survival aids — no weapons, no teammates, no power-ups. The experience centers entirely on movement precision, reaction time, and spatial awareness under escalating AI-driven pressure.

---

## Gameplay Overview

| Feature | Detail |
|---|---|
| **Perspective** | Top-down |
| **Goal** | Survive and reach the Barangay Gate within 1 minute 30 seconds |
| **Enemy** | AI-controlled pursuing dog |
| **Map** | Single fixed barangay street map with randomized starting positions |
| **Engine** | Godot 4.x |

### Environmental Distortions

The map can undergo three distinct effects, all triggered contextually by the Director AI:

- **Jitter** — Subtle camera shake when the dog enters close range. Functions as an early warning.
- **Flip** — Sudden 90° or 180° rotation of the entire map. Player position stays constant, but all directional cues invert.
- **Carousel** — Continuous slow rotation that activates in late-game stages, creating persistent disorientation.

---

## Setup & Installation

### Prerequisites

- [Godot Engine 4.x](https://godotengine.org/download) (stable release recommended)
- Git

### Clone the Repository

```bash
git clone https://github.com/<your-username>/takbo-jusko.git
cd takbo-jusko
```

### Running the Game

1. Open **Godot Engine**.
2. Click **Import** and navigate to the cloned project folder.
3. Select the `project.godot` file and click **Import & Edit**.
4. Press **F5** (or click the Play button) to run the game.

### Exporting a Build

1. In Godot, go to **Project → Export**.
2. Add your target platform (Windows, Linux, macOS, HTML5).
3. Click **Export Project** and choose an output directory.

> **Note:** Export templates must be downloaded from within Godot via **Editor → Manage Export Templates** if not already installed.

---

## AI Components

The game's challenge and pacing are driven by three interconnected AI systems, each responsible for a distinct aspect of gameplay. Together, they form a responsive loop that evolves in real time based on player performance.

---

### 1. Hunter AI — A\* Search with Predictive Targeting

**File:** `hunter_ai.gd`

The pursuing dog uses the **A\* (A-star) search algorithm** to compute the optimal path through the grid-based map every frame.

#### How A\* Works Here

The algorithm evaluates map nodes using a combined cost function:

```
f(n) = g(n) + h(n)
```

- `g(n)` — Actual movement cost from the start position to the current node
- `h(n)` — Estimated cost to the target, using **Manhattan Distance**:

```
h(n) = |x_current − x_target| + |y_current − y_target|
```

Movement is restricted to the four cardinal directions (up, down, left, right) — diagonal movement is explicitly excluded.

#### Predictive Targeting

Rather than chasing the player's current position, the Hunter AI **intercepts** the player's predicted future position:

```
Target = Player_Position + (Player_Direction × k)
```

Where `k` is a look-ahead coefficient. The effective lookahead is dynamically scaled by:
- A **confidence score** derived from comparing current velocity to an Exponential Moving Average (EMA) of past velocities
- **Tile distance** between dog and player — lookahead is reduced when the player is very close or very far
- Whether the dog is **stuck** — lookahead is set to 0 to prevent looping behavior

This makes the pursuer feel intelligent and threatening, punishing predictable movement patterns.

---

### 2. Director AI — Decision Tree System

**File:** `director.gd`

The Director AI acts as the game's **invisible game master**, deciding when and how to distort the environment. It uses a **rule-based decision tree** — chosen for its low computational overhead, deterministic behavior, and easy extensibility.

#### Monitored Game-State Variables

| Variable | Effect |
|---|---|
| `distance_to_dog` | Closer proximity → more disorienting effects |
| `stamina_ratio` | Low stamina → aggressive distortions during vulnerable states |
| `time_elapsed` | Later stages → unlock more severe effects |

#### Decision Logic (Simplified)

| Condition | State | Triggered Effect |
|---|---|---|
| `distance <= danger_distance` | `warning` | Jitter |
| `stamina <= low` AND `distance <= close` | `critical_pressure` | Flip 90° |
| `stamina <= low` | `low_stamina_pressure` | Flip 90° |
| `time >= 60s` AND `distance >= safe` AND `stamina > medium` | `late_game_high_pressure` | Carousel |
| `time >= mid` AND `distance >= safe` | `mid_game_pressure` | Flip 180° |
| `distance <= close` | `close_range_pressure` | Flip 90° |
| Mid-range roaming | `mid_range_pressure` | Jitter |
| Default | `stable` | None |

A **cooldown timer** prevents major effects (flips, carousel) from firing too frequently, ensuring distortions feel impactful rather than spammy.

---

### 3. Chaos Engine — Simulated Annealing

**File:** `chaos_engine.gd`

The Chaos Engine uses **Simulated Annealing (SA)** — a probabilistic optimization technique adapted from materials science — to dynamically calibrate overall difficulty based on player performance.

#### Chaos Score Calculation

```
chaos_score = 100 × (0.50 × time_progress + 0.30 × safety_score + 0.20 × stamina_score)
```

This score drives the system's **temperature** `T`:

```
temperature = t_min + (t_max - t_min) × (chaos_score / 100)
```

#### Accept/Reject Probability

The probability of accepting a proposed difficulty spike is:

```
P = e^(−ΔE / T)
```

- **High T** (player performing well) → more likely to accept large difficulty spikes → chaotic, unpredictable experience
- **Low T** (player struggling) → system stabilizes → frequency and intensity of distortions reduce

This prevents both "difficulty spirals" (game becomes unwinnable) and "difficulty floors" (game becomes trivial), keeping players in a **flow state**.

---

## Architecture Overview

The game follows a **modular, layered architecture** centered on a central Game Loop that executes all subsystems every frame in strict sequential order.

```
┌─────────────────────────────────────────────┐
│                Start of Frame               │
└──────────────────────┬──────────────────────┘
                       │
┌──────────────────────▼──────────────────────┐
│               INPUT LAYER                   │
│  Captures WASD / Arrow Keys / Shift Key     │
│  → Outputs: Movement Vector                 │
└──────────────────────┬──────────────────────┘
                       │
┌──────────────────────▼──────────────────────┐
│             GAME LOGIC LAYER                │
│  Updates Position, Stamina, Chaos Score     │
│  Handles Collision Detection                │
└──────────────────────┬──────────────────────┘
                       │
┌──────────────────────▼──────────────────────┐
│             AI SYSTEMS LAYER                │
│  ┌────────────┐ ┌────────────┐ ┌──────────┐ │
│  │ Hunter AI  │ │Director AI │ │  Chaos   │ │
│  │ A* Search  │ │  Dec. Tree │ │  Engine  │ │
│  └────────────┘ └────────────┘ └──────────┘ │
│                                             │
│  → Outputs: Dog Path, Env. Effects, Diff.   │
└──────────────────────┬──────────────────────┘
                       │
┌──────────────────────▼──────────────────────┐
│             RENDERING LAYER                 │
│  Draws Frame, Applies Distortions,          │
│  Updates HUD (Timer, Stamina Bar)           │
└──────────────────────┬──────────────────────┘
                       │
                  (loop back)
```

### Module Responsibilities

| Module | Responsibility |
|---|---|
| **Input Layer** | Captures keyboard input; extracts direction, speed, sprint state |
| **Game Logic Layer** | Validates movement, detects collisions, updates stamina and Chaos Score |
| **AI Systems Layer** | Runs Hunter AI, Director AI, and Chaos Engine in parallel each frame |
| **Rendering Layer** | Draws all game elements and applies visual distortion effects |

All three AI subsystems run **in parallel** within the AI Systems Layer each frame, then their combined output (dog path + environmental effect + difficulty delta) is forwarded to the Rendering Layer.

---

## Controls

| Key | Action |
|---|---|
| `W` / `↑` | Move Up |
| `S` / `↓` | Move Down |
| `A` / `←` | Move Left |
| `D` / `→` | Move Right |
| `Shift` (hold) | Sprint (depletes stamina) |

> **Note:** Controls are always relative to the screen — pressing Up always moves the player upward on screen regardless of map rotation. Players must reorient their mental map, not their control scheme.

---

## Win & Lose Conditions

| Outcome | Condition |
|---|---|
| ✅ **Win** | Reach the **Barangay Gate** before the 1:30 Caroling Timer expires |
| ❌ **Lose** | The Caroling Timer runs out, OR the dog makes contact with the player's hitbox |

---

## References

- Hart, P. E., Nilsson, N. J., & Raphael, B. (1968). A formal basis for the heuristic determination of minimum cost paths. *IEEE Transactions on Systems Science and Cybernetics, 4*(2), 100–107. https://doi.org/10.1109/TSSC.1968.300136

- Kirkpatrick, S., Gelatt, C. D., & Vecchi, M. P. (1983). Optimization by simulated annealing. *Science, 220*(4598), 671–680. https://doi.org/10.1126/science.220.4598.671

- Lawande, S., Jasmine, G., Anbarasi, J., & Izhar, L. I. (2022). A systematic review and analysis of intelligence-based pathfinding algorithms in the field of video games. *Applied Sciences, 12*(11), 5499. https://doi.org/10.3390/app12115499

- Ngo, T. T. B., Le, H. T., & Nguyen, T. H. (2024). Three real-time pathfinding strategies in games: From A* ideas to machine learning approaches. In *Proceedings of ICAISE 2024*. https://doi.org/10.1109/ICAISE65384.2024.00020

- Russell, S., & Norvig, P. (2020). *Artificial Intelligence: A Modern Approach* (4th ed.). Pearson.

- Yannakakis, G. N., & Togelius, J. (2018). *Artificial Intelligence and Games*. Springer. https://doi.org/10.1007/978-3-319-63519-4

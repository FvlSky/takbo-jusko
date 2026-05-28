# Takbo, Jusko!

> A top-down survival arcade game using AI-driven pathfinding,
> environmental chaos, and adaptive difficulty.

Built in partial fulfillment of **COSC 304 – Introduction to Artificial Intelligence**
Polytechnic University of the Philippines, College of Computer and Information Sciences

---

## Play the Game

🎮 **[Play on itch.io](<your-itchio-link>)**

> Requires a modern browser with WebGL 2.0 support.
> Tested on Chrome and Firefox. Safari is not supported.

---

## About

*Takbo, Jusko!* is a Filipino street-culture survival game where the player
controls a lone Christmas caroler navigating narrow urban streets while being
chased by a hostile dog. The environment dynamically rotates, flips, and
distorts in real time — forcing constant spatial reorientation.

**Objective:** Survive until the Caroling Timer expires, or reach the Barangay Gate exit.
**Lose condition:** The dog makes contact with the player's hitbox.

---

## Controls

| Input | Action |
|-------|--------|
| `WASD` / Arrow Keys | Move (screen-relative — always relative to screen, not map) |
| `F1` | Toggle AI debug overlay (A* paths, Chaos Score, SA temperature) |

---

## AI Systems

### 1. Hunter AI — A* Search Algorithm with Predictive Targeting
The pursuing dog uses A* pathfinding with Manhattan distance heuristic on a
cardinal-only grid. Rather than chasing the player's current position, it uses
predictive targeting: 

Target = Player_Position + (Player_Direction × k)

Where `k` is a look-ahead coefficient that causes the dog to intercept
the player's path rather than trail behind.

### 2. Director AI — Decision Tree System
A rule-based decision tree monitors three game-state variables in real time:
- Distance between player and dog
- Player stamina
- Time elapsed

Based on these inputs, it triggers environmental effects:
- **Jitter** — camera shake when dog is close (early warning)
- **Flip** — 90°/180° map rotation (triggered on low stamina + close dog)
- **Carousel** — continuous slow rotation (enabled after 60 seconds)

### 3. Chaos Engine — Simulated Annealing
Dynamically calibrates difficulty using the SA probability function:

P = e^(−ΔE / T)

Where `T` (temperature) represents player performance level. High T = strong
performance → more aggressive difficulty spikes accepted. Low T = struggling
player → system stabilizes to prevent an unrecoverable spiral.

---

## Tech Stack

| Layer | Tool |
|-------|------|
| Game engine | Godot 4 (GDScript — no C#) |
| Design & assets | Figma → PNG export |
| Version control | Git + GitHub + Git LFS |
| Web build | Godot HTML5 / WebAssembly export |
| Deployment | itch.io + GitHub Actions (Butler CI) |

---

## Project Structure
res://
├── scenes/       # All .tscn scene files
├── scripts/      # All .gd script files
│   └── ai/       # pathfinding.gd, director.gd, chaos_engine.gd
├── assets/       # Sprites, audio, fonts (tracked via Git LFS)
└── resources/    # Godot .tres resource files

---

## Local Setup

```bash
# 1. Clone the repo
git clone https://github.com/<username>/takbo-jusko.git
cd takbo-jusko

# 2. Pull LFS assets
git lfs pull

# 3. Open in Godot 4 (standard version, NOT .NET)
#    File → Import Project → select project.godot

# 4. Run the project
#    Press F5 or click the Play button
```

---

## Team

| Member | Role |
|--------|------|
| Argallon, Dazel C. | Player mechanics, Director AI, Chaos Engine, Integration |
| Babasa, Maria Hanna V. | Project setup, Grid/Map, A*, Hunter AI, Web build |
| Borondia, Kurt Ashley T. | Art direction, Documentation, Win/Lose screens, Paper |
| Castillo, Julianna Leila T. | Sprites, HUD, Environmental distortion effects, Menu |

---

## References

- Hart, P. E., Nilsson, N. J., & Raphael, B. (1968). A formal basis for the heuristic determination of minimum cost paths. *IEEE Transactions on Systems Science and Cybernetics, 4*(2), 100–107.
- Kirkpatrick, S., Gelatt, C. D., & Vecchi, M. P. (1983). Optimization by simulated annealing. *Science, 220*(4598), 671–680.
- Russell, S., & Norvig, P. (2020). *Artificial Intelligence: A Modern Approach* (4th ed.). Pearson.
- Yannakakis, G. N., & Togelius, J. (2018). *Artificial Intelligence and Games*. Springer.
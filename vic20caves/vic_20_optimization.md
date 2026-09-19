# Coprime Stride Scanning: Efficient Entity Management on Resource-Constrained Hardware

When developing games for severely resource-constrained systems like the Commodore VIC-20 (which offers as little as 3.5 KB of RAM out of the box), standard game architecture paradigms quickly fall apart. 

Managing dynamic entity states—such as monsters, bombs, falling debris, and hazards—presents two major bottlenecks: **Memory** (storing entity structures) and **Compute Overhead** (preventing entities from being updated multiple times per frame).

This document details an elegant, memory-efficient spatial iteration technique using **coprime stride walking** on a grid torus to handle tile-based entities without secondary buffers or object arrays.

---

## 1. The Problem: The Naive Approaches & Their Pitfalls

### Memory Bottleneck: Object Arrays
Modern and even standard 8-bit games often maintain an array of active entity structures (`struct Monster { int x, y, type, state; }`). 
* On the VIC-20, allocating memory for even 20–30 dynamic objects consumes precious RAM.
* Iterating through arrays and cross-referencing them with tile maps introduces expensive lookups and pointer arithmetic in 6502 assembly.

### Compute Bottleneck: Double Buffering vs. Cascading Updates
To eliminate object arrays, we can treat the **map tiles themselves as entities**. A cell byte defines both the visual tile and its entity logic (e.g., Patrol, Seeker, Bomb, Falling Rock).

However, updating entities directly in place on a single map grid introduces the **Cascading Update Problem**:

1. **The Raster Scan Problem (Stride 1):** If the scan walks linearly ($x = 0 \to N, y = 0 \to M$) and an entity moves to the right ($+1$ in $x$) or down ($+1$ in $y$), the cursor immediately encounters that same entity on the very next step. 
2. **The Result:** Entities moving right or down warp across the board instantaneously in a single frame, moving much faster than entities moving left or up.

```
Linear Scan Direction:  --->--->--->
Entity Position (t=0): [ M ] [   ] [   ]
Step 1 (Scan hits M):  [   ] [ M ] [   ]  <-- Entity moves Right (+1)
Step 2 (Scan at +1):   [   ] [   ] [ M ]  <-- Scan hits M AGAIN! Instant warp!
```

### The Double-Buffer Solution (Too Expensive)
To solve this, a double-buffering approach reads from Map A, plans moves, and writes to Map B. 
* **Cost:** A $32 \times 32$ grid requires $1024 \text{ bytes}$. Maintaining two maps consumes $2048 \text{ bytes}$—over half of the unexpanded VIC-20's total RAM.

---

## 2. The Solution: Coprime Stride Walking on a Torus

Instead of double-buffering or keeping object lists, we update map tiles in-place using a **single cursor** that steps through the map array using a mathematical stride:

$$\text{spotxy}_{t+1} = (\text{spotxy}_t + S) \pmod N$$

Where:
* $N$ is the total number of cells in the grid (e.g., $N = 32 \times 32 = 1024$).
* $S$ is the **stride step size**.
* $\text{gcd}(S, N) = 1$ (meaning $S$ and $N$ are **coprime**).

### Mathematical Property: Complete Cyclic Coverage
By selecting $S$ such that $\gcd(S, N) = 1$, number theory guarantees that the modular additive group $\langle S \rangle$ generates the full cyclic group $\mathbb{Z}_N$. 

In practical terms: **The cursor visits every single cell exactly once per full cycle of $N$ steps before returning to the start position.**

```
+-----------------------------------------------------------------------+
|  Every frame, the 6502 code executes:                                 |
|                                                                       |
|      spotxy = (spotxy + STRIDE) & 1023;                               |
|      if (map[spotxy] is dynamic_entity) update_entity(spotxy);        |
|                                                                       |
|  * Uses 1 single map (1024 bytes saved)                               |
|  * Zero object arrays or dynamic allocation                           |
|  * Fast bitwise AND masking for power-of-two grids (1023 = $03FF)     |
+-----------------------------------------------------------------------+
```

---

## 3. Optimizing the Stride for Directional Balance

While *any* coprime stride visits all cells, not all strides are visually equal.

If an entity moves to a neighboring cell $(x \pm 1, y \pm 1)$, how long will it take for the cursor to hit that new cell?
* If the scan hits the target cell **immediately**, the entity gets a second turn in the same cycle.
* If the scan hits the target cell **far into the future**, the entity waits almost a full cycle.

To ensure directional symmetry (so entities move at visually identical speeds regardless of whether they move Up, Down, Left, or Right), we minimize the variance of the scan gaps across all four cardinal directions.

### Objective Function
For a grid of width $W$ and height $H$ ($N = W \times H$):
* **Right (+1 step offset in memory):** Gap $\Delta_{\text{right}}(S) = (1 \cdot S^{-1}) \pmod N$
* **Left (-1 step offset in memory):** Gap $\Delta_{\text{left}}(S) = (-1 \cdot S^{-1}) \pmod N$
* **Down (+$W$ step offset in memory):** Gap $\Delta_{\text{down}}(S) = (W \cdot S^{-1}) \pmod N$
* **Up (-$W$ step offset in memory):** Gap $\Delta_{\text{up}}(S) = (-W \cdot S^{-1}) \pmod N$

We evaluate strides $S \in [1, N-1]$ where $\gcd(S, N) = 1$, scoring them by the **Standard Deviation** of their directional revisit averages:

$$\text{Score}(S) = \sigma\left( \bar{\Delta}_{\text{right}}, \bar{\Delta}_{\text{left}}, \bar{\Delta}_{\text{down}}, \bar{\Delta}_{\text{up}} \right)$$

A lower score represents a more isotropic (directionally balanced) scan.

---

## 4. Empirical Demonstrations

### Example A: The $8 \times 8$ Grid ($N = 64$)

Let's inspect an $8 \times 8$ grid ($N = 64$, mask `& 63`).

#### Bad Stride ($S = 1$): Highly Asymmetric
When $S = 1$, the scan walks linearly row-by-row.

```
0   1   2   3   4   5   6   7
8   9  10  11  12  13  14  15
16 17  18  19  20  21  22  23
24 25  26  27  28  29  30  31
32 33  34  35  36  37  38  39
40 41  42  43  44  45  46  47
48 49  50  51  52  53  54  55
56 57  58  59  60  61  62  63
```

* **Average Scan Gaps:**
  * **Right (+1):** $1.0$ steps (Immediate re-encounter $\to$ severe speed bias)
  * **Left (-1):** $63.0$ steps
  * **Down (+8):** $8.0$ steps
  * **Up (-8):** $56.0$ steps
* **Bias Ratios:** Left/Right = $63.0$, Up/Down = $7.0$

#### Optimal Stride ($S = 11$): Balanced Distribution
By scoring strides $1 \dots 63$, stride **$S = 11$** (and its symmetrical twin $S = 53$) produces the minimum standard deviation ($\sigma \approx 6.04$).

```
 0  35   6  41  12  47  18  53
24  59  30   1  36   7  42  13
48  19  54  25  60  31   2  37
 8  43  14  49  20  55  26  61
32   3  38   9  44  15  50  21
56  27  62  33   4  39  10  45
16  51  22  57  28  63  34   5
40  11  46  17  52  23  58  29
```

* **Average Scan Gaps:**
  * **Right (+1):** $35.0$ steps
  * **Left (-1):** $29.0$ steps
  * **Down (+8):** $24.0$ steps
  * **Up (-8):** $40.0$ steps
* **Bias Ratios:** Left/Right = $0.83$, Up/Down = $1.67$

Notice how neighbors in all 4 directions have relatively evenly spaced touch times (e.g., cell `0` is surrounded by `35` right, `53` left, `24` down, `40` up), preventing any directional speed zipping!

---

### Example B: The Target $32 \times 32$ Grid ($N = 1024$)

For a $32 \times 32$ playfield ($N = 1024$), we step with formula:

    spotxy = (spotxy + S) & 1023

Evaluating candidate prime strides against directional variance yields **$S = 239$** as the optimal stride step.

* **Prime & Coprime:** $\gcd(239, 1024) = 1$.
* **Full Cycle:** Hits all 1024 cells in exactly 1024 frames/steps without requiring secondary buffers.
* **Isotropic Motion:** Provides the best spatial distribution across 2D grid space, ensuring monsters move smoothly in all 4 directions without directional bias or object array memory overhead.

---

## 5. Assembly Implementation Sketch (MOS 6502)

Here is how compact this technique is in 6502 assembly for the VIC-20:

```assembly
; =====================================================================
; Update 1 cell per frame or loop N times per frame
; spotxy: 16-bit word (0..1023)
; map:    Base memory address of the 32x32 playfield
; =====================================================================

STRIDE = 239            ; Optimal coprime stride for 1024-cell torus

UpdateMapCursor:
    LDA spotxy_lo
    CLC
    ADC #<STRIDE
    STA spotxy_lo
    LDA spotxy_hi
    ADC #>STRIDE
    AND #$03            ; Keep within 0..1023 range (& 1023)
    STA spotxy_hi

    ; Fetch tile from map
    LDY spotxy_lo
    ; Assuming page offset handling for 1024 bytes (4 pages)
    LDA (map_ptr), Y    
    
    ; Evaluate Tile Entity
    CMP #TILE_PATROL
    BEQ DoPatrolLogic
    CMP #TILE_FALLING_BOMB
    BEQ DoGravityLogic
    RTS
```

## 6. Summary

By replacing linear scanning and double-buffering with a **Coprime Stride Walk ($S = 239$ on a $32 \times 32$ grid)**:
1. **RAM Saved:** Eliminates the need for a second $1024$-byte map buffer and object arrays.
2. **CPU Cycles Saved:** No complex array searching, pointer management, or active entity list compaction.
3. **Behavior Correctness:** Eliminates directional "speed zipping" through isotropic scan spacing.
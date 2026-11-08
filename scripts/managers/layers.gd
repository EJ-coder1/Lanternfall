class_name Layers
extends RefCounted
## Physics layer bit values, shared by every script so collision rules stay readable.

const WORLD := 1          # solid ground and walls
const PLAYER := 2         # player body
const ENEMY_BODY := 4     # enemy hurt/contact areas
const PLAYER_ATTACK := 8  # reserved for future player projectiles
const PICKUP := 16        # reserved
const LUMEN := 32         # light-revealed platforms (solid only while lit)

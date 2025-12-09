# Card Asset Guide

## How to add card images

### Option 1: Shared images (recommended, simple)

You only need to prepare two images:
- `card_front.png` – front image used for all cards (unified design)
- `card_back.png` – back image used for all cards (unified design)

**Recommended image size:**
- Width: 96 pixels (can be changed via `config.CARD.width` in `config.lua`)
- Height: 136 pixels (can be changed via `config.CARD.height` in `config.lua`)
- Format: PNG (supports transparency)

### Option 2: Individual images (each card has its own file)

1. In `config.lua`, set `config.ASSETS.USE_INDIVIDUAL_CARDS = true`

2. Place images following this naming rule:
   - Normal cards: `{suit}_{rank}.png`
     - Example: `spades_A.png`, `hearts_2.png`, `clubs_K.png`
     - Suits: `spades`, `hearts`, `clubs`, `diamonds`
     - Ranks: `2`–`10`, `J`, `Q`, `K`, `A`
   - Small joker: `joker_small.png`
   - Big joker: `joker_big.png`

**Recommended image size:**
- Width: 96 pixels
- Height: 136 pixels
- Format: PNG (supports transparency)

## Example folder structure

```
assets/
  cards/
    card_front.png      (option 1: front)
    card_back.png       (option 1: back)
    
    spades_A.png        (option 2: spades A)
    hearts_2.png        (option 2: hearts 2)
    clubs_K.png         (option 2: clubs K)
    joker_small.png     (option 2: small joker)
    joker_big.png       (option 2: big joker)
    ...
```

## Notes

- If no images are provided, the game will fall back to the original solid-color rectangle style.
- Image paths are configured in `config.lua` under `config.ASSETS`.
- Images are automatically scaled to the card size (96x136).


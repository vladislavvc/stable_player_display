# Stable Player Display shader patch for Minecraft 26.1.2

Resource-pack shader patch and conversion workflow for using Stable Player Display with modern Minecraft entity shaders

This setup allows player skin regions to be remapped correctly for:
- head
- right arm
- left arm
- torso
- right leg
- left leg

It is designed around vanilla `entity.vsh` / `entity.fsh` from Minecraft `26.1.2`, with SPD-specific UV remapping added on top

---

## What this project does

This project provides:

1. Modified `entity` shaders for Minecraft `26.1.2`
2. Item definitions for SPD body-part models
3. A Python conversion script for clean AnimatedJava `1.10.0-beta.6` exports

The goal is to make item-display based player-body parts render with the correct skin regions and animation behavior

---

## How it works

The setup is split into three layers:

### 1. Item definitions
Item definitions define the orientation of the body-part items using `transformation`

This is where the final part orientation is handled

### 2. Model files
Model files define the geometry, translation and scale of each body part

They stay neutral and only describe the actual model layout

### 3. Entity shaders
The modified `entity.vsh` / `entity.fsh` remap the player skin UVs so that each body part uses the correct region of the player skin

The shader stays close to vanilla and only adds the SPD-specific remap logic

---

## Supported parts

- `head`
- `right_arm`
- `left_arm`
- `torso`
- `right_leg`
- `left_leg`

The split body parts haven't been touched yet, but maybe I'll do that in the future

---

Tested on:

- Minecraft `26.1.2`

If you use a different version, behavior may differ depending on shader or item-definition changes

---

## Workflow

1. Export your project from AnimatedJava
2. Run the Python script on the clean export
3. Apply the resource pack
4. Spawn/use the resulting item displays

---

## Important notes

- Run the Python converter on a **clean AnimatedJava export**
- Do not run the converter repeatedly on already-patched files
- The shader patch and the item definitions are meant to be used together
- Orientation is handled through item definitions, while skin-part remapping is handled by the shader

---

## Files

### Shaders
- `assets/minecraft/shaders/core/entity.vsh`
- `assets/minecraft/shaders/core/entity.fsh`

### Item definitions
- `assets/aj/items/blueprint/player_display/...`

### Models
- `assets/aj/models/blueprint/player_display/...`

### Script
- `aj-convert.py`

Overall, everything works more or less the same way as shown in the original guide, just adapted for this newer setup

## Credits
- `bradleyq`: Original creator
- `Resonance#3633`: Providing custom models and base templates

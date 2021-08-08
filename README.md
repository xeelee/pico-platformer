# pico-platformer

## Overview

**pico-platformer** is a set of generic functions that can be composed into platform game skeleton for [PICO-8](https://www.lexaloffle.com/pico-8.php) fantasy console. Load `minimal.p8` file to see a basic example. Complete usage is presented in `game.p8` file.

## Features

* player movement and animation system
* object (enemy, collectible, etc.) spawning mechanism
* customizable object movement mechanism
* collision detection integrated with player/objects
* generic timer functionality
* view navigation through separate screens
* background layers
* callback functions for the most common game events

## Development

* copy `platformer.lua` file to PICO-8 carts directory

* include file at the beginning of game code

```lua
#include platformer.lua
```

* create game object in `_init` function

```lua
function _init()
    game=new_game(
        -- place required arguments here
        -- (see minimal.p8 first)
    )
end
```

* update the game

```lua
function _update60()
    game:update()
end
```

* draw the game to the screen

```lua
function _update60()
    game:draw()
end
```

## Sprite flags meaning

* `0` (0x1) - set collision reponse `dangerous` attribute to `true`
* `1` (0x2) - enable floor collision
* `2` (0x4) - enable walls collision
* `3` (0x8) - enable ceiling collision
* `7` (0x80) - force display tile (by default only floor tiles are being displayed)

## See and play [sample game](https://titil.itch.io/pico-platfomer)

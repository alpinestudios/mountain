# Layer Config

Backgrounds are located in res/backgrounds
and structutured by one folder per biome.

Each biome folder cotnains a layer_config.cfg file
This file specifies the layer draw order, layer parallax and haze per layer.
Each layer has it's own sub folder with assets.

asset_probs contains optional probability weights for assets in each layer. We may want some assets to be more common and some to be more rare.

BASE PROBABILITY WEIGHT is 100.

- 00 Is the nearest layer and 99 is in the back
- PLAYSPACE is the constant to define the root playspace layer
- Layer draw order is implicit based on order of layers in the file strucutre

```
{

    {
    00_front : {
        prallax-speed : -0.3;
        haze : #f34a4b3;
        haze-opacity : 0.2;
        
        asset_probs : {
            front_tree_00 : 432, // File inside the 00_front folder.
            front_tree_01 : 23,
        }
    },

    01_bushes : {
        prallax-speed : -0.1;
        haze : #f34a4b3;
        haze-opacity : 0.2;	
    },
    
    PLAYSPACE

    mountains_final_final : {
        prallax-speed : 0.3;
        haze : #f34a4b3;
        haze-opacity : 0.2;	
    }
}

```
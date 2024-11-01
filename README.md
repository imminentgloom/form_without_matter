# form!matter


![form_without_matter](screenshot.png)


Form, without matter. A drum-sequencer for monome norns and grid.

Supports N.B. et al. (installed to /dust/code/nb) and crow.

Four tracks. 96 ppqn. Full access to every substep. Edit steps in time on the grid or program each substep as desired. Play unquantized. Multiple flavours of entropy on tap. Audio-rate fills. Can genereate a large amount of notes rapidly, adjust speed limit to achieve desired level of downstream stability. 

*form!matter strives to be entropically inclusive.*  

Controls, norns:
```
enc 1: bpm 
enc 2: add(cw) random 16th steps or remove(ccw) steps  
enc 3: add(cw) random substeps or remove(ccw) substeps  
```
```
key 1 + enc 1: speed limit
```
```
key 2: play/pause  
key 3: reset
```

Controls, grid:

![form_without_matter](form_without_matter_grid.jpg)

```
loop and fill change with number of buttons held:

fill1-6 + trig:     adds steps if rec is on, plays if off
  loop1 + tracks:   repeats single steps or jumps between held
  loop2 + tracks:   loop single track, press above or below for one step
  loop3 + tracks:   loop all tracks, press above or below for one step
  clear + tracks:   clear any pressed steps
  clear + substeps: clear any pressed substeps
  clear + pattern:  clear pattern
  clear + shift:    clear all steps
  shift + play:     change playback direction
  shift + pattern:  save pattern
```
```
speed limit, skips substeps after each trigger:

      0 = off
   5-10 = ok for norns, depending on bpm
     24 = max, 1 trigger every 16th
```

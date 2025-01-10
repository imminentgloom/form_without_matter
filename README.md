# form!matter


![form_without_matter](screenshot.png)

# (readme not updated for 2.0)

Form, without matter. A drum-sequencer for monome norns and grid.

Supports N.B. et al. and crow.

Four tracks. 96 ppqn. Full access to every substep. Edit steps in time on the grid or program each substep as desired. Play unquantized. Multiple flavours of entropy on tap. Audio-rate fills. Can genereate a large amount of notes rapidly. Adjust speed limit to achieve desired level of downstream stability. 

*form!matter strives to be entropically inclusive.*  

1.2 adds a first pass at note selection, which complicates the interface a bit, and improves interface drawing.

Controls, norns:
```
enc 1: bpm 

enc 2:         add(cw) random 16th steps or remove(ccw) steps  
enc 2 + shift: add(cw) random substeps or remove(ccw) substeps

enc 2 + select: select track

enc 3 + select: select step (either active steps or next substep)

enc 3:           change selected note
enc 3 + shift 1: change all notes on step
enc 3 + shift 2: change all notes on track
enc 3 + shift 3: change all notes

enc 3 + clear:          reset note
enc 3 + select + clear: reset all notes on track

(shift, select and clear are on the grid)
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
```
note editing:

hold select:
enc 2: 






```


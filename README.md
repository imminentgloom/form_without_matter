# form!matter


![form_without_matter](screenshot.png)

# (readme not updated for 2.0)

Form, without matter. A drum-sequencer for monome norns and grid.

Supports N.B. et al.

Four tracks. 96 ppqn. Full access to every substep. Edit steps in time on the grid or program each substep as desired. Play unquantized. Multiple flavours of entropy on tap. Audio-rate fills. Can genereate a large amount of notes rapidly. Adjust speed limit to achieve desired level of downstream stability. 

*form!matter strives to be entropically inclusive.*  

- 2.0: rewrite, added modules for sanity. pattern management on grid, patterns are persistent, edit note/vel/dur  

Controls:
```
note: some functions cover several buttons
      "shift 1/3" means hold any 1 of 3 shift-buttons
```
```
K1: hold to toggle note mode
K2: play/pause
K3: reset
```
```
E1: tempo

normal mode:
   E2 cw: add random notes every step
   E3 cw: add random notes anywhere
   E2/3 ccw: remove notes last first

note mode:
   E2: edit note
   E2 + shift 1/3: edit velocity 
   E2 + shift 2/3: edit duration 
   E3: scroll through active steps
```
```
sequence: toggle notes
substeps: toggle substeps

rec 1-4: disengates controls from track, plays, but does not write

mute 1-4: mute sequence, play is still possible.

trig 1-4: play note, write if rec is enabled.
trig 1-4 + fill n/6: fill track at rates set by ammount of fill held

loop 1/3 + sequence: loops held step, either one or several in order
loop 2/3 + sequence: sets loop points for single track. press above or below for single step
loop 3/3 + sequence: sets loop points for all tracks. press above or below for single step

shift (both modes): shift
shift 1/3 (note mode): edit velocity
shift 2/3 (note mode): edit duration

fill 1-8: hold any n/6 to set fillrate

play: play/pause
play + shift: toggle playback direction

reset: reset

select: choose step and substep(s) to edit

clear + shift: clear sequence
clear + sequence/substeps: clear steps/substeps

pattern 1-4: load pattern
pattern 1-4 + shift: save pattern
pattern 1-4 + clear: clear pattern
pattern 1-4 + select: pattern bank


```


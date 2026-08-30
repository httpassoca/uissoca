# swf change log
Generated files — do not hand-edit. Rebuild with `scripts/patch-swf.sh` (JPEXS importScript).
| swf | patch | what |
|---|---|---|
| hotBar.swf | tools/as3-patches/hotBar.py | slotHolder.initSlot builds 5×29 slots in stacked rows, adds per-slot hit rect + `iggy_uissoca_slot_<i>` icon clip; getSlotOnXY resolves rows from y |

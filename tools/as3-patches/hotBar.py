"""Patch vanilla hotBar.swf ActionScript (exported by JPEXS) for stacked hotbar rows.
Usage: hotBar.py <exported-scripts-dir> <out-scripts-dir>   (writes only the patched files)"""
import sys, os, re, shutil
src, out = sys.argv[1], sys.argv[2]
ROWS = 5
rel = "hotBar_fla/slotHolder_14.as"
s = open(os.path.join(src, rel)).read()

# 1) initSlot: build ROWS*maxSlots slots, lay extra rows above the bar, give every slot an
#    invisible hit rect (mouse) and an "iggy_uissoca_slot_<i>" child the engine can paint icons into.
old_loop = "         while(_loc2_ < (root as MovieClip).maxSlots)\n         {\n            _loc3_ = new Slot();"
assert old_loop in s, "initSlot loop not found"
s = s.replace(old_loop,
"         var uiRowH:Number = this.cellHeight + this.cellSpacing;\n"
"         var uiMax:uint = (root as MovieClip).maxSlots;\n"
"         while(_loc2_ < uiMax * %d)\n         {\n            _loc3_ = new Slot();" % ROWS)
old_pos = "            _loc3_.x = _loc2_ * (this.cellWidth + this.cellSpacing);\n            _loc3_.y = 0;"
assert old_pos in s, "initSlot position lines not found"
s = s.replace(old_pos,
"            _loc3_.x = (_loc2_ % uiMax) * (this.cellWidth + this.cellSpacing);\n"
"            _loc3_.y = -Math.floor(_loc2_ / uiMax) * uiRowH;\n"
"            var uiHit:MovieClip = new MovieClip();\n"
"            uiHit.graphics.beginFill(0,0);\n"
"            uiHit.graphics.drawRect(0,0,this.cellWidth,this.cellHeight);\n"
"            uiHit.graphics.endFill();\n"
"            _loc3_.addChildAt(uiHit,0);\n"
"            var uiIcon:MovieClip = new MovieClip();\n"
"            uiIcon.name = \"iggy_uissoca_slot_\" + _loc2_;\n"
"            _loc3_.addChildAt(uiIcon,1);\n"
"            _loc3_.visible = _loc2_ < uiMax;")

# 2) getSlotOnXY: resolve row from y (rows stack upward: row r spans y in [-r*rowH, -r*rowH+cellHeight]).
old_fn = re.search(r"      public function getSlotOnXY\(param1:Number, param2:Number\) : Number\n      \{.*?\n      \}\n", s, re.S)
assert old_fn, "getSlotOnXY not found"
s = s.replace(old_fn.group(0),
"""      public function getSlotOnXY(param1:Number, param2:Number) : Number
      {
         var uiMax:uint = (root as MovieClip).maxSlots;
         var uiRowH:Number = this.cellHeight + this.cellSpacing;
         var _loc3_:int = int(param1 / (this.cellWidth + this.cellSpacing));
         if(param1 < 0 || param1 > (this.cellWidth + this.cellSpacing) * _loc3_ + this.cellWidth)
         {
            return -1;
         }
         var uiRow:int = param2 <= 0 ? int(Math.ceil(-param2 / uiRowH)) : 0;
         var uiLocal:Number = param2 + uiRow * uiRowH;
         if(uiRow < 0 || uiRow >= %d || uiLocal < 0 || uiLocal > this.cellHeight)
         {
            return -1;
         }
         var uiIdx:int = uiRow * uiMax + _loc3_;
         if(uiIdx >= this.slot_array.length || !this.slot_array[uiIdx].visible)
         {
            return -1;
         }
         return uiIdx;
      }
""" % ROWS)

os.makedirs(os.path.dirname(os.path.join(out, rel)), exist_ok=True)
open(os.path.join(out, rel), "w").write(s)
print("patched", rel)

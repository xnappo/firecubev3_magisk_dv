#!/system/bin/sh
# Dev probe (run on the Cube): how can a binary file be turned into ONE line of hex with this toybox?
# Output -> /data/local/tmp/probe_out.txt
O=/data/local/tmp/probe_out.txt
F=/data/local/tmp/edid_nodv.bin
: > $O
{
  echo "file size: $(wc -c < $F) bytes -> expect 512 hex chars"
  echo "A xxd -p | tr -d '\\n'         : $(xxd -p $F | tr -d '\n' | wc -c)"
  echo "B xxd -p | tr -d '\\012'       : $(xxd -p $F | tr -d '\012' | wc -c)"
  echo "C xxd -p -c 256 (chars+nl)     : $(xxd -p -c 256 $F | wc -c)"
  echo "D od -An -v -tx1 | tr -d ' \\012': $(od -An -v -tx1 $F | tr -d ' \012' | wc -c)"
  echo "E xxd -p lines                 : $(xxd -p $F | wc -l)"
  echo "F xxd -p -c 256 lines          : $(xxd -p -c 256 $F | wc -l)"
  X=$(xxd -p -c 256 $F)
  echo "G var from -c 256 length       : ${#X}"
  echo "H var substring far            : ${X:500:12}"
  Y=$(xxd -p $F | tr -d '\012')
  echo "I var from tr octal length     : ${#Y}"
  Z=$(xxd -p $F)
  echo "J command-substitution only length (newlines inside?): ${#Z}"
  W=$(echo $Z | tr -d ' ')
  echo "K echo \$Z unquoted (newlines->spaces) then strip spaces: ${#W}"
  echo "L roundtrip xxd -r -p          : $(echo $X | xxd -r -p | cmp - $F && echo SAME)"
  echo DONE
} >> $O 2>&1

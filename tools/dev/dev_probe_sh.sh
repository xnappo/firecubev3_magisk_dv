#!/system/bin/sh
# Dev probe (run on the Cube): which string/arithmetic constructs does this mksh support? Output -> /data/local/tmp/probe_out.txt
O=/data/local/tmp/probe_out.txt
: > $O
{
  echo "KSH_VERSION=$KSH_VERSION"
  v=00ff10aa
  i=1
  o=$((i * 2))
  echo "1 literal offset       : [${v:2:2}]            expect ff"
  echo "2 var offset           : [${v:$o:2}]            expect ff"
  echo "3 nested arith offset  : [${v:$((i * 2)):2}]            expect ff"
  echo "4 arith on substring   : [$((0x${v:2:2}))]            expect 255"
  h=${v:2:2}
  echo "5 arith via temp var   : [$((0x$h))]            expect 255"
  echo "6 arith on var offset  : [$((0x${v:$o:2}))]            expect 255"
  echo "7 length               : [${#v}]            expect 8"
  f() { p=$1; echo "[${p:2:2}]"; }
  echo "8 func positional copy : $(f $v)            expect [ff]"
  g() { echo "[${1:2:2}]"; }
  echo "9 func positional raw  : $(g $v)            expect [ff]"
  s=0; for x in 1 2 3; do s=$((s + x)); done
  echo "10 loop sum            : [$s]            expect 6"
  echo "11 printf %02x         : [$(printf '%02x' 171)]            expect ab"
  echo "12 printf %*s          : [$(printf '%*s' 4 '')]            expect 4 spaces"
  echo "13 case glob           : [$(case 00ff in *[!0-9a-f]*) echo bad;; *) echo good;; esac)]            expect good"
  echo "14 od decimal          : [$(printf '\000\377\020' | od -An -v -tu1 | tr -s ' ' | sed 's/^ //')]            expect 0 255 16"
  big=$(xxd -p /data/local/tmp/edid_nodv.bin | tr -d '\n')
  echo "15 big string length   : [${#big}]            expect 512"
  echo "16 big substring       : [${big:0:16}]            expect 00ffffffffffff00"
  echo "17 big substring far   : [${big:500:12}]            expect 12 chars"
  echo DONE
} >> $O 2>&1

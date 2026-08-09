#!/bin/zsh

set -eu

if (( $# > 1 )); then
  print -u2 'usage: stay-awake [minimum-battery-percentage]'
  exit 2
fi

threshold=${1:-10}
if [[ "$threshold" != <-> ]] || (( threshold < 1 || threshold > 100 )); then
  print -u2 'minimum battery percentage must be an integer from 1 to 100'
  exit 2
fi

cleanup() {
  /usr/bin/pmset -a disablesleep 0
}

trap cleanup EXIT
trap 'exit 130' HUP INT TERM

/usr/bin/pmset -a disablesleep 1

battery_info=$(/usr/bin/pmset -g batt)
if ! print -r -- "$battery_info" | /usr/bin/grep -q 'InternalBattery'; then
  print 'no battery detected; staying awake until interrupted'
  while true; do
    /bin/sleep 3600
  done
fi

print "staying awake until the battery reaches ${threshold}%"
while true; do
  pct=$(/usr/bin/pmset -g batt |
    /usr/bin/awk 'match($0, /[0-9]+%/) {
      print substr($0, RSTART, RLENGTH - 1)
      exit
    }')

  if [[ -z "$pct" ]]; then
    print -u2 'could not read battery percentage; restoring sleep'
    exit 1
  fi

  (( pct <= threshold )) && break
  /bin/sleep 60
done

cleanup
trap - EXIT HUP INT TERM
/usr/bin/pmset sleepnow

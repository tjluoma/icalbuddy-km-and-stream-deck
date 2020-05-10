#!/bin/bash
# Purpose: Convert seconds (input) into a readable duration

# SOURCE: 	<https://raw.github.com/livibetter/td.sh/master/td.sh>
# DATE:		2013-01-03

# Converting seconds to human readable time duration.
# Copyright (c) 2010, 2012 Yu-Jie Lin
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

usage() {
  echo "Usage: $(basename "$0") [options] [seconds[ seconds[ seconds[...]]]]

Options:

  -a     prints all number even they are zeros.
  -p[X]  padding for numbers. 'X' is the padding character, default is ' '.
  -P     padding for unit strings.
  -h     this help message.

Note:

  You can \`source $(basename "$0")\` then use \`print_td <seconds>\` in your script.
"
}

units=(second minute hour day)

print_td() {
  t=${1#-}
  nums=($(($t % 60)) $(($t / 60 % 60)) $(($t / 3600 % 24)) $(($t / 86400)))

  result=""
  for ((idx=${#units[@]}-1;idx>=0;idx--)) {
    ((nums[idx] == 0)) && [[ -z $TD_SH_PRINTS_ZEROS ]] && continue;
    # Handling Number Padding
    if (( nums[idx] < 10 )) && [[ ! -z $TD_SH_NUMB_PADDING ]]; then
      result="$result ${TD_SH_NUMB_PADDING}${nums[idx]}"
    else
      result="$result ${nums[idx]}"
    fi

    result="$result ${units[idx]}"
    # Handling Unit Padding
    if ((nums[idx] != 1)); then
      result="${result}s"
    elif [[ ! -z $TD_SH_UNIT_PADDING ]]; then
      result="${result} "
    else
      result="${result}"
    fi
    }
  [[ -z "$result" ]] && result="0 seconds"
  echo "${result# }"
  }

shopt -s extglob

TD_SH_PRINTS_ZEROS=
TD_SH_UNIT_PADDING=
TD_SH_NUMB_PADDING=

for arg in "$@"; do
  case "$arg" in
    ?(-)+([[:digit:]]))
      print_td "$arg"
      ;;
    -a)
      TD_SH_PRINTS_ZEROS="ON"
      ;;
    -P)
      TD_SH_UNIT_PADDING="ON"
      ;;
    -p)
      TD_SH_NUMB_PADDING=" "
      ;;
    -p?)
      TD_SH_NUMB_PADDING=${arg:2:1}
      ;;
    -h)
      usage
      ;;
  esac
done


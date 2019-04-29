#!/bin/sh

######################################################################
#
# PUBNEWS.SH : 新着情報の連絡
#
# Written by Shinichi Yanagido (s.yanagido@gmail.com) on 2019-04-29
#
######################################################################


######################################################################
# Initial Configuration
######################################################################

# === Initialize shell environment ===================================
set -u
umask 0022
export LC_ALL=C
type command >/dev/null 2>&1 && type getconf >/dev/null 2>&1 &&
export PATH="$(command -p getconf PATH)${PATH+:}${PATH-}"
export UNIX_STD=2003  # to make HP-UX conform to POSIX

# === Define the functions for printing usage and exiting ============
print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/}
	Version : 2019-04-29 13:39:24 JST
	USAGE
  exit 1
}
exit_trap() {
  set -- ${1:-} $?  # $? is set as $1 if no argument given
  trap '-' EXIT HUP INT QUIT PIPE ALRM TERM
  [ -d "${Tmp:-}" ] && rm -rf "${Tmp%/*}/_${Tmp##*/_}"
  exit $1
}
error_exit() {
  ${2+:} false && echo "${0##*/}: $2" 1>&2
  exit $1
}

# === Detect home directory of this app. and define more =============
Homedir="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; cd "$d.."; pwd)"
PATH="$Homedir/BIN:$Homedir/TOOL:$PATH" # for additional command
. "$Homedir/CONFIG/COMMON.SHLIB"        # account infomation


######################################################################
# Argument Parsing
######################################################################

# === Print usage and exit if one of the help options is set =========
case "$# ${1:-}" in
  '1 -h'|'1 --help'|'1 --version') print_usage_and_exit;;
esac


######################################################################
# Main Routine
######################################################################

# === tmpディレクトリの作成 ==========================================
trap 'exit_trap' EXIT HUP INT QUIT PIPE ALRM TERM
Tmp=`mktemp -d -t "_${0##*/}.$$.XXXXXXXXXXX"` || error_exit 1 'Failed to mktemp'

# === 配信対象の特定 =================================================
twfer.sh | sed 's/^.*(@\(.*\))$/\1/' | sort >$Tmp/follower
if [ -r "$Dir_tmp/subscriber" ]; then
  join -a 2 "$Dir_tmp/subscriber" $Tmp/follower >$Tmp/subscriber
  mv $Tmp/subscriber "$Dir_tmp/subscriber"
else
  mv $Tmp/follower "$Dir_tmp/subscriber"
fi
[ ! -s "$Dir_tmp/subscriber" ] && error_exit 1 'No subscriber found'

# === 学科掲示板から新着取得 =========================================
message='学科掲示板が更新されました'
if [ "$(getcsnews.sh)" -eq 1 ]; then
  cat "$Dir_tmp/subscriber"                  |
  cut -d ' ' -f 1                            |
  xargs -I @ dmtweet.sh -t @ "$message" 2>&1 >>"$Dir_log/pubnews.sh.log"
fi


######################################################################
# Finish
######################################################################

exit_trap 0

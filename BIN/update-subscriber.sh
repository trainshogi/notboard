#!/bin/sh

######################################################################
#
# UPDATE-SUBSCRIBER.SH : 講読者の更新
#
# Written by Shinichi Yanagido (s.yanagido@gmail.com) on 2019-05-11
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
	Options : -n       |--dry-run
	          -f <file>|--subscriber-file=<file>
	Version : 2019-05-11 01:59:52 JST
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

# === Initialize parameters ==========================================
: ${now:=$(date '+%Y%m%d%H%M%S')}
dryrun=0
date=''
title=''
category=''
from=''
ref=''

# === Read options ===================================================
while :; do
  case "${1:-}" in
    --dry-run|-n)  dryrun=1
                   shift
                   ;;
    --diff-file=*) file=$(printf '%s' "${1#--diff-file=}")
                   [ -n "${file##*/}" ] || error_exit 1 'Invalid --diff-file option'
                   dir=$(printf '%s' "${file##*/}")
                   [ -n "$dir" -a -d "$dir" ] || error_exit 1 "cannot make $file: No such file or directory"
                   shift 1
                   ;;
    -f)            file="${2:-}"
                   [ -n "${file##*/}" ] || error_exit 1 'Invalid -f option'
                   dir=$(printf '%s' "${file%/*}")
                   [ -n "$dir" -a -d "$dir" ] || error_exit 1 "cannot make $file: No such file or directory"
                   shift 2
                   ;;
    --|-)          break
                   ;;
    --*|-*)        error_exit 1 'Invalid option'
                   ;;
    *)             break
                   ;;
  esac
done


######################################################################
# Main Routine
######################################################################

# === ログ置場の作成 =================================================
Dir_log="$Homedir/LOG/update_subscriber_sh/$now"
mkdir -p "$Dir_log"

# === tmpディレクトリの作成 ==========================================
trap 'exit_trap' EXIT HUP INT QUIT PIPE ALRM TERM
Tmp=`mktemp -d -t "_${0##*/}.$$.XXXXXXXXXXX"` || error_exit 1 'Failed to mktemp'

# === フォロワの取得および更新 =======================================
twfer.sh >$Tmp/twfer
cp $Tmp/twfer $Dir_log/LV1.twfer.res
cat $Tmp/twfer | sed 's/^.*(@\(.*\))$/\1/' | sort >$Tmp/follower
[ -r "${file:-}" ] && cp "$file" "$Dir_log/LV3.subscriber.old"
if [ -r "${file:-}" ]; then
  diff "$file" $Tmp/follower |
  grep '[<>]'                |
  sed 's/^</unsubscribed/'   |
  sed 's/^>/subscribed/'
  join -a 2 "$file" $Tmp/follower >$Tmp/subscriber
  [ $dryrun -eq 0 ] && mv $Tmp/subscriber "$file"
else
  sed 's/^/subscriber /' $Tmp/follower
  [ $dryrun -eq 0 -a -n "${file:-}" ] && mv $Tmp/follower "$file"
fi
[ -r "${file:-}" ] && cp "$file" "$Dir_log/LV5.subscriber.new"
[ -s "${file:-}" ] || error_exit 1 'No subscriber found'


######################################################################
# Finish
######################################################################

exit_trap 0

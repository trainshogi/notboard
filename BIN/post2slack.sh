#!/bin/sh

######################################################################
#
# POST2SLACK.SH : SlackへのPOST
#
# Written by Akira Sato (densyashogi@gmail.com) on 2019-07-01
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
	Usage   : echo <message> | ${0##*/} [options]
	Options : -u <url>  |--url=<url>
	Version : 2019-07-01 14:22:00 JST
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
url=''
message=''

# === Read options ===================================================
while :; do
  case "${1:-}" in
    --url)      url=$(printf '%s' "${1#--url=}")
                shift
                ;;
    -u)         url=$2
                shift 2
                ;;
    --|-)       break
                ;;
    --*|-*)     error_exit 1 'Invalid option'
                ;;
    *)          break
                ;;
  esac
done

# === Get direct message =============================================
case $# in
  0) message=$(cat -)
     ;;
  1) case "${1:-}" in
       '--') print_usage_and_exit;;
        '-') message=$(cat -)    ;;
          *) message=$1          ;;
     esac
     ;;
  *) case "$1" in '--') shift;; esac
     message="$*"
     ;;
esac
message=$(printf '%s\n' "$message"       |
          sed "s/'//g"                   |
          sed "s/\"//g"                  )

######################################################################
# Main Routine
######################################################################

# === ログ置場の作成 =================================================
Dir_log="$Homedir/LOG/post2slack_sh/$now"
mkdir -p "$Dir_log"

# === POSTする ======================================================
curl -X POST -H "Content-Type: application/json" -d '{"text":"'"$message"'"}' $url >> $Dir_log/post2slack.log
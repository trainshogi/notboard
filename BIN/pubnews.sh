#!/bin/sh

######################################################################
#
# PUBNEWS.SH : 新着情報の連絡
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
	Usage   : ${0##*/} [options]
	Options : -n|--dry-run
	          -s|--not-update
	          -o|--to-stdout
	          -p|--no-publish
	Version : 2019-05-11 11:17:02 JST
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
noupdate=0
tostdout=0
nopublish=0
date=''
title=''
category=''
from=''
ref=''

# === Read options ===================================================
while :; do
  case "${1:-}" in
    --dry-run|-n)    dryrun=1
                     shift
                     ;;
    --not-update|-s) noupdate=1
                     shift 1
                     ;;
    --to-stdout|-o)  tostdout=1
                     shift 1
                     ;;
    --no-publish|-p) nopublish=1
                     shift 1
                     ;;
    --|-)            break
                     ;;
    --*|-*)          error_exit 1 'Invalid option'
                     ;;
    *)               break
                     ;;
  esac
done


######################################################################
# Main Routine
######################################################################

# === ログ置場の作成 =================================================
Dir_log="$Homedir/LOG/pubnews_sh/$now"
mkdir -p "$Dir_log"

# === tmpディレクトリの作成 ==========================================
trap 'exit_trap' EXIT HUP INT QUIT PIPE ALRM TERM
Tmp=`mktemp -d -t "_${0##*/}.$$.XXXXXXXXXXX"` || error_exit 1 'Failed to mktemp'

# === 配信対象の特定 =================================================
# --- 1.フォロワの取得および更新
[ $noupdate -eq 0 -a $dryrun -eq 0 ] && now=$now \
                                          update-subscriber.sh -f "$Dir_tmp/subscriber"

# === 新着情報を取得して配信 =========================================
# --- 1.新着全てを一時保存
if [ $dryrun -eq 0 ]; then                           #
  now=$now                                           \
    getcsnews.sh   -f "$Dir_tmp/boardcs_latest"      #
  now=$now                                           \
    gettuatnews.sh -f "$Dir_tmp/boardtuat_latest"    #
else                                                 #
  now=$now                                           \
    getcsnews.sh   -n -f "$Dir_tmp/boardcs_latest"   #
  now=$now                                           \
    gettuatnews.sh -n -f "$Dir_tmp/boardtuat_latest" #
fi                                                   >$Tmp/news.field
cp $Tmp/news.field "$Dir_log/LV1.news.field"
# --- 2.管理者に対する通知
cat $Tmp/news.field                                 |
cut -d ' ' -f 1                                     |
uniq                                                |
wc -l                                               |
sed 's/^.*$/'"$(date)"'\\n\0件の新着/'              |
while ISF= read -r line; do                         #
  [ $tostdout -eq 1 ] && echo "$line"               #
  [ $dryrun -eq 1 -o $nopublish -eq 1 ] && continue #
  cat "$Dir_dat/administrator"                      |
  cut -d ' ' -f 1                                   |
  xargs -I @ sh -c 'echo "'"$line"'"                |
                    dmtweet.sh -t @'                #
done
# --- 3.講読者に対する通知
key=''
delimiter=''
cat $Tmp/news.field                                   |
# 1:group 2:key 3:value                               #
while IFS= read -r line; do                           #
  if [ "$key" != "${line%% *}" ]; then                #
    key="${line%% *}"                                 #
    date=''                                           #
    title=''                                          #
    category=''                                       #
    from=''                                           #
    ref=''                                            #
    printf "$delimiter"                               #
    printf '%s' '新着メッセージ\n'                    #
    printf '%s' '____________________\n\n'            #
    delimiter='\n'                                    #
  fi                                                  #
  case "${line#* }" in                                #
    date*)     printf '%s' "$line\n"                  |
               cut -d ' ' -f 3-                       |
               sed -z 's/\n//'                        #
               ;;                                     #
    title*)    printf '%s' "$line\n"                  |
               cut -d ' ' -f 3-                       |
               sed -z 's/\n$//'                       #
               ;;                                     #
    category*) printf '%s' '【'                       #
               printf '%s' "$line\n"                  |
               cut -d ' ' -f 3-                       |
               sed -z 's/\n//'                        |
               sed 's/\\n//'                          #
               printf '%s' '】\n\n'                   #
               ;;                                     #
    from*)     printf '%s' "$line\n"                  |
               cut -d ' ' -f 3-                       |
               sed -z 's/\n//'                        #
               ;;                                     #
    ref*)      printf '%s' "$line\n"                  |
               cut -d ' ' -f 3-                       |
               sed -z 's/\n//'                        #
               printf '%s' '\n'                       #
               ;;                                     #
    *)         printf '%s '"【$(echo $line            |
                                cut -d ' ' -f 2)】\n" #
               printf '%s' "$line\n"                  |
               cut -d ' ' -f 3-                       |
               sed -z 's/\n//'                        #
               ;;                                     #
  esac                                                #
done                                                  |
sed 's/\\n$//'                                        |
sed -z 's/$/\n/'                                      |
while IFS= read -r line; do                           #
  [ $tostdout -eq 1 ] && echo "$line\n"               #
  [ $dryrun -eq 1 -o $nopublish -eq 1 ] && continue   #
  cat "$Dir_tmp/subscriber"                           |
  cut -d ' ' -f 1                                     |
  xargs -I @ sh -c 'echo "'"$line"'"                  |
                    dmtweet.sh -t @'                  #
done


######################################################################
# Finish
######################################################################

exit_trap 0

#!/bin/sh

######################################################################
#
# PUBNEWS.SH : 新着情報の連絡
#
# Written by Shinichi Yanagido (s.yanagido@gmail.com) on 2019-05-05
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
	Version : 2019-05-05 20:51:57 JST
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
date=''
title=''
category=''
from=''
ref=''


######################################################################
# Main Routine
######################################################################

# === tmpディレクトリの作成 ==========================================
trap 'exit_trap' EXIT HUP INT QUIT PIPE ALRM TERM
Tmp=`mktemp -d -t "_${0##*/}.$$.XXXXXXXXXXX"` || error_exit 1 'Failed to mktemp'

# === 配信対象の特定 =================================================
# --- 0.アカウントの正当性確認
used_twitter_id=$(grep MY_scname                                       \
                       "$Homedir/TOOL/kotoriotoko/CONFIG/COMMON.SHLIB" |
                  cut -d '=' -f 2                                      |
                  sed "s/'//g"                                         )
[ "$used_twitter_id" != "$twitter_id" ] && error_exit 1 '配信元情報の整合性がありません'
# --- 1.フォロワの取得および更新
update-subscriber.sh -f "$Dir_tmp/subscriber"

# === 新着情報を取得して配信 =========================================
# --- a.学科掲示板からの取得，配信
key=''
delimiter=''
getcsnews.sh -f "$Dir_tmp/boardcs_latest"                 |
# 1:group 2:key 3:value                                   #
while IFS= read -r line; do                               #
  if [ "$key" != "${line%% *}" ]; then                    #
    key="${line%% *}"                                     #
    date=''                                               #
    title=''                                              #
    category=''                                           #
    from=''                                               #
    ref=''                                                #
    printf "$delimiter"                                   #
    delimiter='\0'                                        #
  fi                                                      #
  case "${line#* }" in                                    #
    date*)     echo '【日付】'                            #
               echo $line | cut -d ' ' -f 3-              #
               ;;                                         #
    title*)    echo '【タイトル】'                        #
               echo $line | cut -d ' ' -f 3-              #
               ;;                                         #
    category*) echo '【カテゴリ】'                        #
               echo $line | cut -d ' ' -f 3-              #
               ;;                                         #
    from*)     echo '【担当者】'                          #
               echo $line | cut -d ' ' -f 3-              #
               ;;                                         #
    ref*)      echo '【詳細】'                            #
               echo $line | cut -d ' ' -f 3-              #
               ;;                                         #
    *)         echo "【$(echo $line | cut -d ' ' -f 2)】" #
               echo $line | cut -d ' ' -f 3-              #
  esac                                                    #
done                                                      |
xargs -0 -I @ sh -c 'cat "'"$Dir_tmp"'/subscriber"  |     #
                     cut -d " " -f 1                |     #
                     xargs -I % dmtweet.sh -t % "@"'
# --- b.学校掲示板からの取得，配信
key=''
delimiter=''
gettuatnews.sh -f "$Dir_tmp/boardtuat_latest"             |
# 1:group 2:key 3:value                                   #
while IFS= read -r line; do                               #
  if [ "$key" != "${line%% *}" ]; then                    #
    key="${line%% *}"                                     #
    date=''                                               #
    title=''                                              #
    category=''                                           #
    from=''                                               #
    ref=''                                                #
    printf "$delimiter"                                   #
    delimiter='\0'                                        #
  fi                                                      #
  case "${line#* }" in                                    #
    date*)     echo '【日付】'                            #
               echo $line | cut -d ' ' -f 3-              #
               ;;                                         #
    title*)    echo '【タイトル】'                        #
               echo $line | cut -d ' ' -f 3-              #
               ;;                                         #
    category*) echo '【カテゴリ】'                        #
               echo $line | cut -d ' ' -f 3-              #
               ;;                                         #
    from*)     echo '【担当者】'                          #
               echo $line | cut -d ' ' -f 3-              #
               ;;                                         #
    ref*)      echo '【詳細】'                            #
               echo $line | cut -d ' ' -f 3-              #
               ;;                                         #
    *)         echo "【$(echo $line | cut -d ' ' -f 2)】" #
               echo $line | cut -d ' ' -f 3-              #
  esac                                                    #
done                                                      |
xargs -0 -I @ sh -c 'cat "'"$Dir_tmp"'/subscriber"  |     #
                     cut -d " " -f 1                |     #
                     xargs -I % dmtweet.sh -t % "@"'


######################################################################
# Finish
######################################################################

exit_trap 0

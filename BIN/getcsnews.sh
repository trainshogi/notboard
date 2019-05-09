#!/bin/sh

######################################################################
#
# GETCSNEWS.SH : 情報科掲示板の新着を出力
#
# Written by Shinichi Yanagido (s.yanagido@gmail.com) on 2019-05-07
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
	Options : -n       |--dry-run
	          -f <file>|--diff-file=<file>
	Version : 2019-05-07 21:38:25 JST
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
PATH="$Homedir/TOOL:$PATH"       # for additional command
. "$Homedir/CONFIG/COMMON.SHLIB" # 共通設定

# === Confirm that the required commands exist =======================
# --- 1.cURL or Wget
if   type curl  >/dev/null 2>&1; then
  CMD_CURL='curl'
elif type wget  >/dev/null 2>&1; then
  CMD_WGET='wget'
else
  error_exit 1 'No HTTP-GET/POST command found.'
fi
# --- 2.iconv or nkf
if   type iconv >/dev/null 2>&1; then
  CMD_ICONV='iconv'
elif type nkf   >/dev/null 2>&1; then
  CMD_NKF='nkf'
else
  error_exit 1 'No convert-encoding command found.'
fi


######################################################################
# Argument Parsing
######################################################################

# === Print usage and exit if one of the help options is set =========
case "$# ${1:-}" in
  '1 -h'|'1 --help'|'1 --version') print_usage_and_exit;;
esac

# === Initialize parameters ==========================================
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

# === 掲示板情報を取得 ===============================================
# --- 0.パラメータおよびtmpディレクトリの設定
readonly url='https://board.cs.tuat.ac.jp' # 掲示板のURL
chenc='Shift_JIS'                          # 文字コード
trap 'exit_trap' EXIT HUP INT QUIT PIPE ALRM TERM
Tmp=`mktemp -d -t "_${0##*/}.$$.XXXXXXXXXXX"` || error_exit 1 'Failed to mktemp'
# --- 1.サイト情報の解析
# 掲示板のパス
board_path=$(if   [ -n "${CMD_WGET:-}" ]; then      #
               "$CMD_WGET" -q -O -                  \
                           --http-user="$CS_id"     \
                           --http-password="$CS_pw" \
                           "$url"                   #
             elif [ -n "${CMD_CURL:-}" ]; then      #
               "$CMD_CURL" -s                       \
                           -u "$CS_id:$CS_pw"       \
                           "$url"                   #
             fi                                     |
             sed 's/\r//'                           |
             parsrx.sh                              |
             grep 'new\.html'                       |
             cut -d ' ' -f 2                        )
[ -z "$board_path" ] && error_exit 1 '掲示一覧が見つかりません'
# 掲示板の文字コード解析
charset=$(if   [ -n "${CMD_WGET:-}" ]; then           #
            "$CMD_WGET" -q -O -                       \
                        --http-user="$CS_id"          \
                        --http-password="$CS_pw"      \
                        "$url$board_path"             \
                        2>&1                          |
            sed 's/\r//'                              |
            cut -b 3-                                 |
            awk '$0=="HTTP/1.1 200 OK"{flg=1} flg==1' |
            grep '^Content-Type:'                     #
          elif [ -n "${CMD_CURL:-}" ]; then           #
            "$CMD_CURL" -sI                           \
                        -u "$CS_id:$CS_pw"            \
                        "$url$board_path"             |
            sed 's/\r//'                              |
            grep '^Content-Type:'                     #
          fi                                          |
          sed 's/[; ]\{1,\}/\n/g'                     |
          grep '^charset'                             |
          cut -d '=' -f 2                             |
          awk '$0!="none"'                            )
if [ -z "$charset" ]; then
  charset=$(if   [ -n "${CMD_WGET:-}" ]; then      #
              "$CMD_WGET" -q -O -                  \
                          --http-user="$CS_id"     \
                          --http-password="$CS_pw" \
                          "$url$board_path"        #
            elif [ -n "${CMD_CURL:-}" ]; then      #
              "$CMD_CURL" -s                       \
                          -u "$CS_id:$CS_pw"       \
                          "$url$board_path"        #
            fi                                     |
            sed 's/\r//'                           |
            grep 'charset'                         |
            sed 's/[\";]/\n/g'                     |
            grep charset                           |
            cut -d '=' -f 2                        )
fi
[ -n "$charset" ] && chenc=$charset
# --- 2.掲示板をフィールド形式で保存
# 1:path 2:key 3:value
if   [ -n "${CMD_WGET:-}" ]; then           #
  "$CMD_WGET" -q -O -                       \
              --http-user="$CS_id"          \
              --http-password="$CS_pw"      \
              "$url$board_path"             #
elif [ -n "${CMD_CURL:-}" ]; then           #
  "$CMD_CURL" -s                            \
              -u "$CS_id:$CS_pw"            \
              "$url$board_path"             #
fi                                          |
sed 's/\r//'                                |
if   [ -n "${CMD_ICONV:-}" ]; then          #
  "$CMD_ICONV" -f $chenc -t UTF-8           #
elif [ -n "${CMD_NKF:-}" ]; then            #
  case "$chenc" in                          #
    Shift_JIS) "$CMD_NKF" -Sw80 ;;          #
    UTF-8)     cat              ;;          #
  esac                                      #
fi                                          |
grep -iv '<meta'                            |
sed 's#<BR>#<BR/>#g'                        |
sed 's#^\([^<]\{1,\}\)#<SPAN>\1</SPAN>#'    |
parsrx.sh                                   |
sed 's/\\n//g'                              |
while IFS= read -r line; do                 #
  case "${line%% *}" in                     #
    */BR)    echo "$ref date     $date"     #
             echo "$ref category $category" #
             echo "$ref title    $title"    #
             echo "$ref from     $from"     #
             echo "$ref ref      $url$ref"  #
             date=''                        #
             from=''                        #
             category=''                    #
             ref=''                         #
             title=''                       #
             ;;                             #
    */SPAN)  date=$(echo ${line#* } |       #
                    sed 's/\[.*$//' )       #
             from=$(echo ${line#*[}      |  #
                    sed 's/([^()]*)\]$//')  #
             category=$(echo ${line##*(} |  #
                        sed 's/)\]$//'   )  #
             ;;                             #
    */@HREF) ref="${line#* }"               #
             ;;                             #
    */A)     title="${line#* }"             #
             ;;                             #
  esac                                      #
done                                        >$Tmp/board
[ -s $Tmp/board ] || error_exit 1 '掲示板情報が取得できません'

# === 更新されたの投稿のみ抽出 =======================================
# --- 1.更新部分の保存
if [ -e "${file:-}" ]; then
  cat $Tmp/board               |
  nl -nrz                      |
  sort -k 2,2 -k 1,1           |
  join -v 2 -2 2 "$file" -     |
  cut -d ' ' -f 2 --complement >$Tmp/news
else
  cp $Tmp/board $Tmp/news
fi
# --- 2.最新の投稿一覧を保存
if [ $dryrun -eq 0 -a -n "${file:-}" ]; then
  cat $Tmp/board  |
  cut -d ' ' -f 1 |
  sort            |
  uniq            >"$file"
fi

# === 更新情報を出力 =================================================
cat $Tmp/news


######################################################################
# Finish
######################################################################

exit_trap 0

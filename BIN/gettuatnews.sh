#!/bin/sh

######################################################################
#
# GETTUATNEWS.SH : 学校掲示板に新着があるか確認する
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
PATH="$Homedir/TOOL:$PATH"       # for additional command
. "$Homedir/CONFIG/COMMON.SHLIB" # 共通設定

# === Confirm that the required commands exist =======================
# --- 1.cURL or Wget
if   type curl    >/dev/null 2>&1; then
  CMD_CURL='curl'
elif type wget    >/dev/null 2>&1; then
  CMD_WGET='wget'
else
  error_exit 1 'No HTTP-GET/POST command found.'
fi


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
key=''
date=''
title=''
category=''
from=''
ref="http://t-board.office.tuat.ac.jp/$CAMPUS/menu.php"

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
Dir_log="$Homedir/LOG/gettuatnews_sh/$now"
mkdir -p "$Dir_log"

# === 掲示板情報を取得 ===============================================
# --- 0.パラメータおよびtmpディレクトリの設定 ------------------------
# 掲示板のURL
readonly url=$(case "$CAMPUS" in                                                   #
                 'A') echo 'http://t-board.office.tuat.ac.jp/A/boar/resAjax.php';; #
                 'T') echo 'http://t-board.office.tuat.ac.jp/T/boar/resAjax.php';; #
                 *)   error_exit 1 'キャンパス情報が不正です';;                    #
               esac                                                                )
trap 'exit_trap' EXIT HUP INT QUIT PIPE ALRM TERM
Tmp=`mktemp -d -t "_${0##*/}.$$.XXXXXXXXXXX"` || error_exit 1 'Failed to mktemp'
# --- 1.サイト情報の解析
# 掲示板の文字コード解析
if   [ -n "${CMD_WGET:-}" ]; then           #
  "$CMD_WGET" -qS --spider -O -             \
              "$url"                        \
              2>&1                          |
  sed 's/\r//'                              |
  cut -b 3-                                 |
  awk '$0=="HTTP/1.1 200 OK"{flg=1} flg==1' |
  grep '^Content-Type:'                     #
elif [ -n "${CMD_CURL:-}" ]; then           #
  "$CMD_CURL" -sI                           \
              "$url"                        |
  sed 's/\r//'                              |
  grep '^Content-Type:'                     #
fi                                          >$Tmp/HEAD.resAjax.php
cp $Tmp/HEAD.resAjax.php "$Dir_log/LV3.HEAD.resAjax.php"
charset=$(cat $Tmp/HEAD.resAjax.php |
          sed 's/[; ]\{1,\}/\n/g'   |
          grep '^charset'           |
          cut -d '=' -f 2           |
          awk '$0!="none"'          )
if   [ -n "${CMD_WGET:-}" ]; then #
  "$CMD_WGET" -q -O - "$url"      #
elif [ -n "${CMD_CURL:-}" ]; then #
  "$CMD_CURL" -s      "$url"      #
fi                                >$Tmp/resAjax.php
cp $Tmp/resAjax.php "$Dir_log/LV1.resAjax.php"
if [ -z "$charset" ]; then
  charset=$(cat $Tmp/resAjax.php |
            sed 's/\r//'         |
            grep 'charset'       |
            sed 's/[\";]/\n/g'   |
            grep charset         |
            cut -d '=' -f 2      )
fi
[ -n "$charset" ] && chenc=$charset
# --- 2.掲示板をフィールド形式で保存
# 1:path 2:key 3:value
cat $Tmp/resAjax.php                                          |
sed 's/\r//'                                                  |
iconv -f $chenc -t UTF-8                                      |
sed 's/\r//g'                                                 |
sed 's#<\(img[^<>]*\)>#<\1/>#g'                               |
sed 's/</\n</g'                                               |
sed 's/>/>\n/g'                                               |
sed 's/^\([^< ]\)/ \1/'                                       |
awk '/^<p class="standout">/ && in_ptag==0 {in_ptag=1; print} #
     /^<\/p>/                || in_ptag==0 {in_ptag=0; print} #
     /^[^<]/                 && in_ptag==1'                   |
parsrx.sh                                                     >$Tmp/board.name
cp $Tmp/board.name "$Dir_log/LV2.resAjax.php.name"
cat $Tmp/board.name                                 |
grep -a '^/table/tbody/tr'                          |
sed 's/\\n//g'                                      |
grep -v 'p\s*$'                                     |
while IFS= read -r line; do                         #
  case "${line%% *}" in                             #
    */tr)      echo "$key date     $date"           #
               echo "$key category $category"       #
               echo "$key title    $title"          #
               echo "$key from     $from"           #
               echo "$key ref      $ref"            #
               key=''                               #
               date=''                              #
               from=''                              #
               category=''                          #
               title=''                             #
               ;;                                   #
    */p/span)  category=${line#* }                  #
               ;;                                   #
    */td/p)    if [ -z "$title" ]; then             #
                 title="${line#* }"                 #
               else                                 #
                 title="$title\\\\n${line#* }"      #
               fi                                   #
               ;;                                   #
    */tr/td)   if echo ${line#* }                   |
                  grep '[0-9]\{2\}/[0-9]\{2\}'      \
                  >/dev/null;                  then #
                 date="${line#* }"                  #
               else                                 #
                 from="${line#* }"                  #
               fi                                   #
               ;;                                   #
    */tr/@alt) key=${line#* }                       #
               ;;                                   #
  esac                                              #
done                                                >$Tmp/board
cp $Tmp/board "$Dir_log/LV3.resAjax.php.field"
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
cp $Tmp/news "$Dir_log/LV5.news.field"
# --- 2.最新の投稿一覧を保存
[ -n "${file:-}" ] && cp "$file" "$Dir_log/LV3.post_list.old"
if [ $dryrun -eq 0 -a -n "${file:-}" ]; then
  cat $Tmp/board  |
  cut -d ' ' -f 1 |
  sort            |
  uniq            >"$file"
fi
[ -n "${file:-}" ] && cp "$file" "$Dir_log/LV3.post_list.new"


# === 更新情報を出力 =================================================
cat $Tmp/news


######################################################################
# Finish
######################################################################

exit_trap 0

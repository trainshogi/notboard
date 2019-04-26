#!/bin/sh

######################################################################
#
# GETCSNEWS.SH : 情報科掲示板から新着情報を取得する
#
# Written by Shinichi Yanagido (s.yanagido@gmail.com) on 2019-04-22
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
	Version : 2019-04-22 15:01:00 JST
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
PATH="$Homedir/UTL:$Homedir/TOOL:$PATH" # for additional command
. "$Homedir/CONFIG/COMMON.SHLIB"        # account infomation

# === Confirm that the required commands exist =======================
# TODO: curl,wgetに対応
# TOOD: iconv,nkfに対応
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
date=''
title=''
category=''
from=''
ref=''
target=''


######################################################################
# Main Routine
######################################################################

# === 掲示板一覧を取得 ===============================================
# --- 0.パラメータ設定 -----------------------------------------------
chenc='Shift_JIS'                  # 文字コード
readonly url='board.cs.tuat.ac.jp' # 掲示板のURL

# --- 1.サイトを取得し解析用一時保存のための/tmpディレクトリ
trap 'exit_trap' EXIT HUP INT QUIT PIPE ALRM TERM
Tmp=`mktemp -d -t "_${0##*/}.$$.XXXXXXXXXXX"` || error_exit 1 'Failed to mktemp'

# --- 2.サイト情報の解析 ---------------------------------------------
# wget -q -O - --http-user="$CS_id" --http-passwd="$CS_pw" "https://$url/" |
# --- 掲示板のURL
board_url=$(curl -s -u "$CS_id:$CS_pw" "https://$url" |
            sed 's/\r//'                              |
            parsrx.sh                                 |
            grep 'new\.html'                          |
            cut -d ' ' -f 2                           )
# --- 掲示板の文字コード解析
charset=$(curl -sI -u "$CS_id:$CS_pw" "https://$url/$board_url" |
          sed 's/\r//'                                          |
          grep '^Content-Type:'                                 |
          sed 's/[; ]\{1,\}/\n/g'                               |
          grep '^charset'                                       |
          cut -d '=' -f 2                                       |
          awk '$0!="none"'                                      )
if [ -z "$charset" ]; then
    charset=$(curl -s -u "$CS_id:$CS_pw" "https://$url/$board_url" |
              sed 's/\r//'                                         |
              grep 'charset'                                       |
              sed 's/[\";]/\n/g'                                   |
              grep charset                                         |
              cut -d '=' -f 2                                      )
    [ -n "$charset" ] && chenc=$charset
fi
# --- 掲示板の保存
separator=''
echo '['
curl -s -u "$CS_id:$CS_pw" "https://$url/$board_url" |
sed 's/\r//'                                         |
iconv -f $chenc -t UTF-8                             |
grep -iv '<meta'                                     |
sed 's#<BR>#<BR/>#g'                                 |
sed 's#^\([^<]\{1,\}\)#<SPAN>\1</SPAN>#'             |
parsrx.sh                                            |
sed 's/\\n//g'                                       |
while IFS= read -r line; do                          #
    case "${line%% *}" in                            #
        */BR)   cat <<EOF                            #
  $separator{
    "date": "$date",
    "title": "$title",
    "category": "$category",
    "from": "$from",
    "ref": "$ref"
  }
EOF
                 separator=','                       #
                 date=''                             #
                 from=''                             #
                 category=''                         #
                 ref=''                              #
                 title=''                            #
                 ;;                                  #
        */SPAN)  date=$(echo ${line#* } |            #
                        sed 's/\[.*$//' )            #
                 from=$(echo ${line#*[}      |       #
                        sed 's/([^()]*)\]$//')       #
                 category=$(echo ${line##*(} |       #
                            sed 's/)\]$//'   )       #
                 ;;                                  #
        */@HREF) ref="${line#* }"                    #
                 ;;                                  #
        */A)     title="${line#* }"                  #
                 ;;                                  #
    esac                                             #
done
echo ']'


# # === 表示 ===========================================================
# cat $Tmp/board.json |
# grep '"ref": "'     |
# cut -d ':' -f 2     |
# cut -c 3-           |
# rev                 |
# cut -c 2-           |
# rev                 \
# >$Dir_tmp/newsDB


######################################################################
# Finish
######################################################################

exit_trap 0

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
# --- 1.cURL or Wget
if   type curl    >/dev/null 2>&1; then
  # CMD_CURL='curl'
  httpget() {
    # $1:url
    curl -s -u "$CS_id:$CS_pw" "$1" |
    sed 's/\r//'
  }
elif type wget    >/dev/null 2>&1; then
  #CMD_WGET='wget'
  httpget() {
    # $1:url
    wget -q -O - --http-user="$CS_id" --http-passwd="$CS_pw" "$1" |
    sed 's/\r//'
  }
else
  error_exit 1 'No HTTP-GET/POST command found.'
fi
# TOOD: iconv,nkfに対応
# --- 2.iconv or nkf
if   type iconv >/dev/null 2>&1; then
  convcharset() {
    # $1:from $2:to
    :
  }
elif type nkf   >/dev/null 2>&1; then
  convcharset() {
    # $1:from $2:to
    :
  }
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


######################################################################
# Main Routine
######################################################################

# === 掲示板情報を取得 ===============================================
# --- 0.パラメータおよびtmpディレクトリの設定 ------------------------
readonly url='board.cs.tuat.ac.jp' # 掲示板のURL
trap 'exit_trap' EXIT HUP INT QUIT PIPE ALRM TERM
Tmp=`mktemp -d -t "_${0##*/}.$$.XXXXXXXXXXX"` || error_exit 1 'Failed to mktemp'

# --- 1.サイト情報の解析 ---------------------------------------------
# --- 掲示板のURL
board_url=$(curl -s -u "$CS_id:$CS_pw" "https://$url" |
            sed 's/\r//'                              |
            parsrx.sh                                 |
            grep 'new\.html'                          |
            cut -d ' ' -f 2                           )
# --- 2.掲示板の更新確認 ---------------------------------------------
flg_changed=0
if [ -e $Dir_tmp/boardcs_Last-Modified ]; then
    # 前の変更日時と異なっていれば，更新扱い
    curl -sI -u "$CS_id:$CS_pw" "https://$url/$board_url" |
    grep '^Last-Modified:'                                >$Tmp/boardcs_Last-Modified.current
    if ! diff $Dir_tmp/boardcs_Last-Modified $Tmp/boardcs_Last-Modified.current; then
        mv $Tmp/boardcs_Last-Modified.current $Dir_tmp/boardcs_Last-Modified
        flg_changed=1
    fi
else
    # 初めての取得であれば，更新扱い
    curl -sI -u "$CS_id:$CS_pw" "https://$url/$board_url" |
    grep '^Last-Modified:'                                >$Dir_tmp/boardcs_Last-Modified
    flg_changed=1
fi

# === 更新した旨を連絡 ===============================================
echo $flg_changed
# message='学科掲示板が更新されました'
# if [ $flg_changed -eq 1 ]; then
#     cat $Dir_dat/subscriber |
#     cut -d ' ' -f 1         |
#     xargs -I @ dmtweet.sh -t @ "$message" 2>"$Dir_log/getcsnews.sh.log"
# fi


######################################################################
# Finish
######################################################################

exit_trap 0

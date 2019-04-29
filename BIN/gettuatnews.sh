#!/bin/sh

######################################################################
#
# GETTUATNEWS.SH : 学校掲示板に新着があるか確認する
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
	Version : 2019-04-29 16:13:00 JST
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


######################################################################
# Main Routine
######################################################################

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

# --- 1.掲示板の更新確認 ---------------------------------------------
flg_changed=0
if [ -e "$Dir_tmp/boardtuat_latest" ]; then
  # 前の変更日時と異なっていれば，更新扱い
  if   [ -n "${CMD_WGET:-}" ]; then                #
    "$CMD_WGET" -q -O - "$url" 2>&1                #
  elif [ -n "${CMD_CURL:-}" ]; then                #
    "$CMD_CURL" -s      "$url"                     #
  fi                                               |
  sed 's/\r//'                                     |
  sed 's#<img\([^>]*\)>#<img\1/>#g'                |
  parsrx.sh                                        |
  grep '^/table/tbody/tr/td [0-9]\{2\}/[0-9]\{2\}' >$Tmp/boardtuat_latest.current
  [ ! -s $Tmp/boardtuat_latest.current ] && error_exit 1 '掲示板の最終更新時刻が取得できません'
  if ! diff "$Dir_tmp/boardtuat_latest"   \
            $Tmp/boardtuat_latest.current >/dev/null; then
    mv $Tmp/boardtuat_latest.current "$Dir_tmp/boardtuat_latest"
    flg_changed=1
  fi
else
  # 初めての取得であれば，更新扱い
  if   [ -n "${CMD_WGET:-}" ]; then                #
    "$CMD_WGET" -q -O - "$url" 2>&1                #
  elif [ -n "${CMD_CURL:-}" ]; then                #
    "$CMD_CURL" -s      "$url"                     #
  fi                                               |
  sed 's/\r//'                                     |
  sed 's#<img\([^>]*\)>#<img\1/>#g'                |
  parsrx.sh                                        |
  grep '^/table/tbody/tr/td [0-9]\{2\}/[0-9]\{2\}' >"$Dir_tmp/boardtuat_latest"
  [ ! -s "$Dir_tmp/boardtuat_latest" ] && error_exit 1 '掲示板の最終更新時刻が取得できません'
  flg_changed=1
fi


# === 更新情報を返す =================================================
echo $flg_changed


######################################################################
# Finish
######################################################################

exit_trap 0

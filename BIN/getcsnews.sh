#!/bin/sh

######################################################################
#
# GETCSNEWS.SH : 情報科掲示板に新着があるか確認する
#
# Written by Shinichi Yanagido (s.yanagido@gmail.com) on 2019-04-28
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
	Version : 2019-04-28 12:29:00 JST
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
readonly url='board.cs.tuat.ac.jp' # 掲示板のURL
trap 'exit_trap' EXIT HUP INT QUIT PIPE ALRM TERM
Tmp=`mktemp -d -t "_${0##*/}.$$.XXXXXXXXXXX"` || error_exit 1 'Failed to mktemp'

# --- 1.サイト情報の解析 ---------------------------------------------
# --- 掲示板のパス
board_path=$(if   [ -n "${CMD_WGET:-}" ]; then       #
               "$CMD_WGET" -q -O -                   \
                           --http-user="$CS_id"      \
                           --http-password="$CS_pw"  \
                           "https://$url"            #
            elif [ -n "${CMD_CURL:-}" ]; then        #
               "$CMD_CURL" -s                        \
                           -u "$CS_id:$CS_pw"        \
                           "https://$url"            #
            fi                                       |
            sed 's/\r//'                             |
            parsrx.sh                                |
            grep 'new\.html'                         |
            cut -d ' ' -f 2                          )
[ -z "$board_path" ] && error_exit 1 '掲示一覧が見つかりません'
# --- 2.掲示板の更新確認 ---------------------------------------------
flg_changed=0
if [ -e $Dir_tmp/boardcs_Last-Modified ]; then
  # 前の変更日時と異なっていれば，更新扱い
  if   [ -n "${CMD_WGET:-}" ]; then        #
    "$CMD_WGET" -qS --spider -O -          \
                --http-user="$CS_id"       \
                --http-password="$CS_pw"   \
                "https://$url$board_path"  \
                2>&1                       #
  elif [ -n "${CMD_CURL:-}" ]; then        #
    "$CMD_CURL" -sI                        \
                -u "$CS_id:$CS_pw"         \
                "https://$url$board_path"  #
  fi                                       |
  sed 's/\r//'                             |
  grep '^Last-Modified:'                   >$Tmp/boardcs_Last-Modified.current
  [ ! -s $Tmp/boardcs_Last-Modified.current ] && error_exit 1 '掲示板の最終更新時刻が取得できません'
  if ! diff $Dir_tmp/boardcs_Last-Modified     \
            $Tmp/boardcs_Last-Modified.current >/dev/null; then
    mv $Tmp/boardcs_Last-Modified.current $Dir_tmp/boardcs_Last-Modified
    flg_changed=1
  fi
else
  # 初めての取得であれば，更新扱い
  if   [ -n "${CMD_WGET:-}" ]; then       #
    "$CMD_WGET" -qS --spider -O -         \
                --http-user="$CS_id"      \
                --http-password="$CS_pw"  \
                "https://$url$board_path" \
                2>&1                      |
    sed 's/^ *//'                         #
  elif [ -n "${CMD_CURL:-}" ]; then       #
    "$CMD_CURL" -sI                       \
                -u "$CS_id:$CS_pw"        \
                "https://$url$board_path" #
  fi                                      |
  sed 's/\r//'                            |
  grep '^Last-Modified:'                  >$Dir_tmp/boardcs_Last-Modified
  [ ! -s $Dir_tmp/boardcs_Last-Modified ] && error_exit 1 '掲示板の最終更新時刻が取得できません'
  flg_changed=1
fi

# === 更新した旨を連絡 ===============================================
echo $flg_changed


######################################################################
# Finish
######################################################################

exit_trap 0

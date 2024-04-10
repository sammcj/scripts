#!/bin/bash
# selector menu
# Author: Franck Jouvanceau

# Icons for -o filenames, can be overriden using env variables to fit terminal font
: ${SELECTOR_FOLDER_ICON:=} # 🖿 🗀 📁 📂 🖿         
: ${SELECTOR_FILE_ICON:=} #  🗎            🗋 🖹  


# no proper way to restore tty on trap
function _ctrl_c
{
  [ "$ZSH_VERSION" ] && {
    tput cuu1 >&2
    tput el >&2
  }
}

function _menuprompt
{
  typeset form filter="${3:-${_aitems[$_nsel]}}" nb="$_nsel/$2 " pl=""
  printf "\r"
  [ "$_powerline" = "y" ] && pl=""
  form="\e[30m\e[44m\e[97m $1 \e[0m\e[34m\e[44m\e[100m$pl\e[97m %s\e[0m\e[90m\e[100m\e[49m$pl\e[0m %s"
  printf "$form" "$nb" "$filter"
  tput el
  printf "\r"
}

function _showmenu 
{
  typeset prompt="$1" nsel="$2" nbitems="$3" filter="$4" item i min max sel lines icon fpath

  _menuprompt "$prompt" "$nbitems" "$filter"
  w=$nbitems;w=${#w}
  lines=${_maxlines:-$LINES}
  [ $lines -ge $LINES ] && lines=$(($LINES-1))
  min=$(($nsel-$lines+2))
  [ "$min" -le 0 ] && min=1
  max=$(($min+$lines-2))
  i=0
  sel="\n\e[30m\e[46m\e[97m %${w}s \e[0m\e[1;96m %s\e[0m"
  [ "$_powerline" = y ] && sel="\n\e[30m\e[46m\e[97m %${w}s \e[0m\e[36m\e[46m\e[49m\e[0m\e[1;96m%s\e[0m"
  while [ $i -lt $nbitems ]
  do
    i=$((i + 1))
    item="${_aitems[$i]}"
    [[ $i -ge $min ]] || continue
    [[ $i -le $max ]] || break
    icon=''
    [ "$_sel_option" = filenames ] && {
      [[ "$item" = \~/* ]] && fpath="$HOME/"${item#\~/} || fpath="$item"
      if [ -d "$fpath" ] ;then icon="$SELECTOR_FOLDER_ICON "
      else [ -e "$fpath" -o -L "$fpath" ] && icon="$SELECTOR_FILE_ICON ";fi
    }
    if [[ $nsel == "$i" ]]; then 
      printf "$sel" $i "$icon$item"
    else
      printf "\n\e[32m %${w}s  \e[94m%s\e[0m" $i "$icon$item"
    fi
    tput el #clear end of line
  done
  size=$((nbitems+1))
  [ "$size" -gt $lines ] && size=$lines
  # back to top of menu
  tput ed
  i=1;while [ $i -lt $size ];do
    echo cuu1
    i=$((i + 1))
  done | tput -S
  printf "\r" # begin of line
}

function _select
{
  typeset prompt="$1" newsel="$2" nbitems="$3" filter="$4" lines

  lines=${_maxlines:-$LINES}
  [ $lines -ge $LINES ] && lines=$(($LINES-1))
  _nsel=$(($newsel))
  [ $_nsel -lt 1 ] && _nsel=1
  [ $_nsel -ge $nbitems ] && _nsel=$nbitems
  _showmenu "$prompt" "$_nsel" "$nbitems" "$filter"
}

function _items_split
{
  typeset filter="$1" item IFS

  [ "$filter" ] && {
    _nsel=""
    [ "$filter" = . ] && filter=""
    [[ "$filter" =~ ^[0-9]+$ ]] && _nsel=$filter || _items="$(printf "%s" "$_items" |grep -F -- "$filter" 2>/dev/null|uniq)"
  }
  [ "$_nsel" ] && _items="${_aitems[$_nsel]}"
  _nsel=1
  IFS=$'\n'
  # ZSH array index starts at 1
  [ "$ZSH_VERSION" ] && _aitems=( ${=_items} ) || { _aitems=( _ $_items ); unset '_aitems[0]'; }
  IFS=$' \t\n'
}

function _readkey
{
  typeset o=${1:-n} k tmout=0.001
  [ "$KSH_VERSION" ] && tmout=0.01
  IFS= read -rs${o}1 key
  [ "$key" = $'\x1b' ] && key="" && while true
  do
    k=""
    read -rs${o}1 -t $tmout k 2>/dev/null
    [ $? = 1 ] && [ "$BASH" ] && read -rs${o}1 -t 1 k # old bash
    [ ! "$k" ] && key=${key:-$'\x1b'} && break
    key+="$k"
    case "$key" in
      '['[A-H]|'['*'~'|O[A-S]|'[1;2'[P-S]) break;;
    esac
  done
  printf "%s" "$key"
}

function _domenu 
{
  typeset prompt="$1" filter="$2" nbitems o=n

  printf "\r"
  tput el
  [ "$ZSH_VERSION" ] && o=k
  _items_split "$filter"
  [ "$_items" ] || return 1
  nbitems=${#_aitems[@]}
  [ "$nbitems" = 1 ] && {
    selected="${_aitems[1]}"
    unset _nsel
    return 0
  }
  _items_ori="$_items"
  tput civis
  stty -echo 2>/dev/null
  printf "\e[?7l" # nowrap
  : ${LINES:=$(tput lines)}
  [ "$_maxlines" -gt 2 ] || unset _maxlines
  _showmenu "$prompt" "$_nsel" "$nbitems" "$filter"
  while true
  do
    k="$(_readkey $o)"
    [ "$_keyfunc" ] && { # custom key control
      $_keyfunc "$k" # 0: already managed / 1: managed exit / 2: default / 3: skip default
      case "$?" in
        0) 
          _items_split "."
          filter=""
          nbitems=${#_aitems[@]}
          _select "$prompt" "${_force_nsel:-1}" "$nbitems" "$filter"
          unset _force_nsel
          continue;;
        1) break;;
        3) continue;;
      esac
    }
    case "$k" in
      '[A'|OA) #up
        filter="";_select "$prompt" "_nsel-1" "$nbitems" "$filter";;
      '[B'|OB) #down
        filter="";_select "$prompt" "_nsel+1" "$nbitems" "$filter";;
      '[H'|'[D'|OD) #home or arrowleft
        filter="";_select "$prompt" "1" "$nbitems" "$filter";;
      '[F'|'[C'|OC) #end or arrowright
        filter="";_select "$prompt" "nbitems" "$nbitems" "$filter";;
      '[6~'|$'\x06'|'[1;2B') #pagedn Ctl-F shift-down
        filter="";_select "$prompt" "_nsel+lines-1" "$nbitems" "$filter";;
      '[5~'|$'\x02'|'[1;2A') #pageup Ctl-B shift-up
        filter="";_select "$prompt" "_nsel-lines+1" "$nbitems" "$filter";;
      '[19~'|$'\x04'|'[3~') # F8 Ctl-D delete
        unset "_aitems[$_nsel]"
        [ "$ZSH_VERSION" ] && _aitems=("${(@)_aitems[1,$_nsel-1]}" "${(@)_aitems[$_nsel+1,$nbitems]}") ||\
          { _aitems=(_ "${_aitems[@]}") && unset '_aitems[0]'; }
        nbitems=${#_aitems[@]}
        tput ed
        [ "$nbitems" = 0 ] && break
        filter="";_select "$prompt" "$_nsel" "$nbitems" "$filter";;
      $'\x7f'|$'\x08') #backspace
        filter=${filter%?}
        _items="$_items_ori"
        _nsel=""
        _items_split "$filter"
        nbitems=${#_aitems[@]}
        [ $_autofilter = y ] && _showmenu "$prompt" "$_nsel" "$nbitems" "$filter" || \
          _menuprompt "$prompt" "$nbitems" "$filter"
        ;;
      $'\xf8') #meta (macos)
        break;;
      [[:graph:]]|" ") #text [a-zA-Z0-9/_?*\(\)\ .-]) 
        filter="$filter$k"
        [ "$_autofilter" = y ] && [[ ! "$filter" =~ ^[0-9]+$ ]] && {
          _items_split "$filter"
          [ ! "$_items" ] && {
            printf "Not found !"
            tput el
            read -rs${o}1 -t 0.5 k 2>/dev/null
            _items="$_items_ori"
            filter="${filter%?}"
            _nsel=""
            _items_split "$filter"
          }
          nbitems=${#_aitems[@]}
          _showmenu "$prompt" "$_nsel" "$nbitems" "$filter"
        }
        _menuprompt "$prompt" "$nbitems" "$filter";;
      $'\x0c') # Ctl-L => refresh
        _showmenu "$prompt" "$_nsel" "$nbitems" "$filter";;
      $'\x01') # Ctl-A => all
        unset _maxlines
        _showmenu "$prompt" "$_nsel" "$nbitems" "$filter";;
      $'\x0d'|''|$'\n') # enter
        [[ "$filter" =~ ^[0-9]+$ ]] && selected="${_aitems[$filter]}" || selected="${_aitems[$_nsel]}"
        break;;     
      $'\t') # tab
        _items_split "$filter"
        [ ! "$_items" ] && break
        nbitems=${#_aitems[@]}
        [ $nbitems = 1 ] && selected="${_aitems[1]}" && break
        _items_ori="$_items"
        filter=""
        tput ed
        _showmenu "$prompt" "$_nsel" "$nbitems" "$filter";;
      *) break;
    esac
  done
  unset _nsel
  unset _aitems
  unset _items_ori
  printf "\e[?7h" #wrap
  tput ed
  tput cnorm
}

function selector
{
  typeset prompt filter
  prompt="select"
  selected=""
  _maxlines=0
  _autofilter=y
  _powerline=y
  _keyfunc=""
  _sel_option=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -p|--prompt)
        [ "$2" ] && prompt="$2" || return 1
        ;;
      -i|--items)
        [ "$2" ] && _items="$2" || return 1
        ;;
      -f|--file)
        [ "$2" ] && _items="$(cat $2)" || return 1
        ;;
      -m|--max)
        [ "$2" ] && _maxlines="$(($2+1))" || return 1
        ;;
      -P|--powerline)
        [ "$2" ] && _powerline="$2" || return 1
        ;;
      -F|--filter)
        [ "$#" -ge 2 ] && filter="$2" || return 1
        ;;
      -a|--autofilter)
        [ "$2" ] && _autofilter="$2" || return 1
        ;;
      -k|--keyfunc)
        [ "$2" ] && _keyfunc="$2" || return 1
        ;;
      -o|--option)
        [ "$2" ] && _sel_option="$2" || return 1
        ;;
      *)
        printf "usage: selector [-p <prompt>] -i <items>|-f <itemfile> [-P <y|n>] [-k <keyfunc>]\n"
        printf "args :\n"
        printf "%s\n" "  -p, --prompt          menu prompt"
        printf "%s\n" "  -i, --items           menu items \n separated"
        printf "%s\n" "  -f, --file            file with items"
        printf "%s\n" "  -F, --filter          regexp pattern filter items"
        printf "%s\n" "  -P, --powerline       y or n, powerline symbol usage"
        printf "%s\n" "  -a, --autofilter      y or n, filter at keystrokes (default y)"
        printf "%s\n" "  -k, --keyfunc         Custom additional key function"
        return 1
        ;;
    esac
    shift 2
  done
  _stty_ori=$(stty -g 2>/dev/null)
  trap _ctrl_c INT
  LC_ALL=$__selector_lc _domenu "$prompt" "$filter" >&2
  trap - INT
  stty $_stty_ori 2>/dev/null
  unset _items _maxlines _autofilter _keufunc _sel_option
  [ "$selected" ] && printf "%s" "$selected" && return 0
  return 1
}

[[ "$LANG" = *UTF-8 ]] && __selector_lc="$LANG" || {
  type locale >/dev/null 2>/dev/null && locale -a |grep -iq "en_US.UTF-*8" && __selector_lc=en_US.UTF-8 || __selector_lc=C.UTF-8
}

[ "$1" ] && { selector "$@"; exit $?; }
:


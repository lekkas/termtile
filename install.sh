#!/usr/bin/env bash

is_yes() {
  yesses={y,Y,yes,Yes,YES}
  if [[ $yesses =~ $1 ]]; then
    echo 1
  fi
}

# ==============================================================================
# Check the platform
# ==============================================================================
platform="$(uname)"
if [[ "$platform" != 'Darwin' ]]; then
  echo "These scripts are only compatible with OS X."
  read -p "Are you sure that you want to continue? [y/N] " should_continue
  if [[ ! $(is_yes $should_continue) ]]; then
    exit
  fi
fi

# ==============================================================================
# Get the default terminal app
# ==============================================================================
current_app="$(osascript -e \
'tell application "System Events"
  item 1 of (get name of processes whose frontmost is true)
end tell'
)"

read -p "What is your default terminal app? [$current_app] " terminal_app

if [[ ! $terminal_app ]]; then
  terminal_app=$current_app
fi

# ==============================================================================
# Ask for install location
# ==============================================================================
read -p "Where should the scripts be installed? [~/.termtile/] " install_dir

if [[ ! $install_dir ]]; then
  install_dir="~/.termtile/"
else
  install_dir+="/"
fi

# ==============================================================================
# Compile sources
# ==============================================================================
echo "Compiling sources..."
mkdir -p build

# Insert app name into the config file
sed '4i\
set _config to _config & {terminalApp:"'$terminal_app'"}
' src/config.applescript.default > src/config.applescript

for script in src/*.applescript; do
  outname=${script#src/}
  outname=build/${outname/.applescript/}.scpt
  osacompile -o $outname $script
done
for utility in src/*.m; do
  outname=${utility#src/}
  outname=build/${outname/.m/}
  cc -framework AppKit -o $outname $utility
done

# ==============================================================================
# Compile sources
# ==============================================================================
echo "Copying files..."
bash -c "cp -r build/ $install_dir"

# ==============================================================================
# Setup aliases
# ==============================================================================

if [[ $(echo $SHELL | grep bash) ]]; then
  RC_FILE=$HOME/.termtilerc
fi

aliases[0]="tlf"   ;  arguments[0]="up left"
aliases[1]="trt"   ;  arguments[1]="up right"
aliases[2]="blf"   ;  arguments[2]="down left"
aliases[3]="brt"   ;  arguments[3]="down right"
aliases[4]="lf"   ;  arguments[4]="left"
aliases[5]="rt"   ;  arguments[5]="right"
aliases[6]="tp"   ;  arguments[6]="up"
aliases[7]="bm" ;  arguments[7]="down"


newline=$'\n'
create_alias() {
  local should_override
  local new_alias
  local alias=$alias_prefix$1
  local script=$2
  local args="${@:3}"
  type $alias >/dev/null 2>&1
  local alias_exists=$?
  if [[ $alias_exists -eq 0 ]]; then
    read -p "$alias is already in use! Do you want to override it? [y/N] " should_override
  fi
  if [[ $alias_exists -eq 0 ]] && [[ ! $(is_yes $should_override) ]]; then
    read -p "What alias should be used then (leave blank to omit)? " new_alias
    if [[ $new_alias ]]; then
      alias=$new_alias
      alias_exists=1
    fi
  fi
  if [[ ! $alias_exists -eq 0 ]] || [[ $(is_yes $should_override) ]]; then
    rc_append+="alias ${alias}='osascript ${install_dir}${script} ${args}'${newline}"
  fi
}

if [[ $RC_FILE ]]; then
  rc_append=$newline"# Added by termtile (https://github.com/apaszke/termtile)"$newline
  read -p "Do you want to add aliases to $RC_FILE? [y/N] " should_alias
  if [[ $(is_yes $should_alias) ]]; then
    echo "Configuring aliases..."
    # expand aliases in the scripts
    shopt -s expand_aliases
    # we only care about the aliases, so silence the warnings
    source $RC_FILE >/dev/null 2>&1

    # add aliases
    for i in ${!aliases[*]}; do
      create_alias ${aliases[$i]} "tile.scpt" ${arguments[$i]}
    done
    create_alias "big" "resize.scpt"
    create_alias "cen" "center.scpt"
    create_alias "max" "maximize.scpt"
    create_alias "sn" "changeScreen.scpt" "next"
    create_alias "fs" "fullscreen.scpt"
    echo "$rc_append" >> "$RC_FILE"
  fi
fi

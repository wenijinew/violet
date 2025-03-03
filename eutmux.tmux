#!/usr/bin/env bash
_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${_DIR}/utils.sh"


PLACE_HOLDERS=(
    "PALE_RED"
    "LIGHT_RED"
    "MIDDLE_RED"
    "STRONG_RED"
    "DARK_RED"
    "DEEP_RED"
    "PALE_PURPLE"
    "LIGHT_PURPLE"
    "MIDDLE_PURPLE"
    "STRONG_PURPLE"
    "DARK_PURPLE"
    "DEEP_PURPLE"
    "PALE_ORANGE"
    "LIGHT_ORANGE"
    "MIDDLE_ORANGE"
    "STRONG_ORANGE"
    "DARK_ORANGE"
    "DEEP_ORANGE"
    "PALE_GREEN"
    "LIGHT_GREEN"
    "MIDDLE_GREEN"
    "STRONG_GREEN"
    "DARK_GREEN"
    "DEEP_GREEN"
    "PALE_BLUE"
    "LIGHT_BLUE"
    "MIDDLE_BLUE"
    "STRONG_BLUE"
    "DARK_BLUE"
    "DEEP_BLUE"
    "PALE_GRAY"
    "LIGHT_GRAY"
    "MIDDLE_GRAY"
    "STRONG_GRAY"
    "DARK_GRAY"
    "DEEP_GRAY"
)

setup(){
    # constants
    THEME_FILE_EXTENSION=".theme.yaml"
    TMUX_COMMANDS_FILENAME="tmux_commands.txt"
    DEFAULT_PALETTE_FILENAME="default_palette.txt"
    DYNAMIC_PALETTE_FILENAME="dynamic_palette.txt"
    DEFAULT_TEMPLATE_THEME_FILENAME="template${THEME_FILE_EXTENSION}"
    # the option is configured in eutmux.yaml config file, and it's set in the last time theme and config generation by eutmux.py module
    # therefore, from 2nd time theme setting, this option could be visible and used.
    eutmux_template_name=$(tmux show-option -gqv "@eutmux_template_name")
    if [ -n "${eutmux_template_name}" ];then
       eutmux_template_name="${eutmux_template_name/%%${THEME_FILE_EXTENSION}*/}"
       # template theme file in ${XDG_CONFIG_HOME:-${HOME}/.config}/eutmux has higher priority
       # if it doesn't exist, then check in the project
       TEMPLATE_THEME_FILENAME="${eutmux_template_name}${THEME_FILE_EXTENSION}"
       TEMPLATE_THEME_FILENAME="${XDG_CONFIG_HOME:-${HOME}/.config}/eutmux/${TEMPLATE_THEME_FILENAME}"
       if [ ! -e "${TEMPLATE_THEME_FILENAME}" ];then
          TEMPLATE_THEME_FILENAME="${eutmux_template_name}${THEME_FILE_EXTENSION}"
       fi
    else
       TEMPLATE_THEME_FILENAME="${DEFAULT_TEMPLATE_THEME_FILENAME}"
    fi
    # if the template theme file name does not exist, print warning and cleanup the tmux option for it
    if [ ! -e "${TEMPLATE_THEME_FILENAME}" ];then
       _warn "Not found ${TEMPLATE_THEME_FILENAME}"
       tmux set-option -gq "@eutmux_template_name" ""
       exit ${EXIT_ABNORMAL}
    fi
    # otherwise, save the template theme file name in the tmux option
    tmux set-option -gq "@eutmux_template_filename" "${TEMPLATE_THEME_FILENAME}"

    DEFAULT_CONFIG_FILENAME="eutmux.yaml"
    DYNAMIC_THEME_NAME="dynamic"
    PALETTE_FILENAME="${DEFAULT_PALETTE_FILENAME}"
    TMUX_OPTION_NAME_DYNAMIC_CONFIG="@eutmux_dynamic_config_file_name"
    TMUX_OPTION_NAME_DYNAMIC_THEME="@eutmux_dynamic_theme_name"
    DELAY=3000

    # global variables, could be set by script arguments. see main.
    THEME_NAME=""
    NEW_THEME_NAME=""
    ROTATE_THEME=${FALSE}
    CREATE_DYNMIC_THEME=${FALSE}
    DARK_BASE_COLOR="" #23272e

    # set working directory to eutmux project path
    pushd "${_DIR}" >/dev/null 2>/dev/null || exit ${EXIT_ABNORMAL}

    # set config home and config file
    EUTMUX_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}/eutmux"
    mkdir -p "${EUTMUX_CONFIG_HOME}" >/dev/null 2>/dev/null

    # if config file not in $EUTMUX_CONFIG_HOME, then copy the default config file to $EUTMUX_CONFIG_HOME
    EUTMUX_CONFIG_FILE="${EUTMUX_CONFIG_HOME}/${DEFAULT_CONFIG_FILENAME}"
    if [ ! -e "${EUTMUX_CONFIG_FILE}" ];then
       cp "${DEFAULT_CONFIG_FILENAME}" "${EUTMUX_CONFIG_HOME}"
    fi
}

teardown(){
    popd >/dev/null 2>/dev/null || exit ${EXIT_ABNORMAL}
}


# function to replace legacy solution's placeholders with new solutions color
# name of palette colors
replace_legacy_placeholders(){
    index=0
    base_color_index=0
    for placeholder in "${PLACE_HOLDERS[@]}"
    do
        colormap_index="$(echo "${index} % 6" | bc)"
        if [ "${colormap_index}" -eq 0 ];then
           ((base_color_index++))
        fi
        color_name="C_${base_color_index}_${colormap_index}"

        find "${_DIR}" -maxdepth 1 -type f -exec sed -i "s/${placeholder}/${color_name}/g" '{}' \;
        sed -i "s/${placeholder}/${color_name}/g" "$HOME/.config/tmux/eutmux.yaml"

        ((index++))
    done
}

# call python module to generate palette file
# generate_palette_colors(){
#     palette=$(python3 -c "import peelee; palette = palette.generate_palette(); print(palette)")
#     echo "$palette" | grep -iEo 'C(_[[:digit:]]{1,}){2}\:#[[:alnum:]]{6}' > "${DYNAMIC_PALETTE_FILENAME}"
# }

generate_palette_colors(){
    local color_name min_color max_color dark_base_color
    # dark_base_color doesn't have default value but has higher priority than color_name
    color_name="${1:-color.ColorName.BLUE}"
    min_color="${2:-20}"
    max_color="${3:-40}"
    dark_base_color="${4:-${DARK_BASE_COLOR}}" # elite-dark-blue: #1a1b26, github-dimmed: #23272e
    install_python_modules="${5:-${FALSE}}"
    append_gray="${6:-${TRUE}}"
    token_min_color="${7:-60}"
    token_max_color="${8:-80}"
    colors_total="${9:-3}"
    dark_colors_total="${10:-3}"
    colors_gradations="${11:-15}"
    dark_colors_gradations="${12:-18}"

    PYTHON3="python3"
    if [ -n "$dark_base_color" ];then
        palette=$($PYTHON3 -c "from peelee import peelee, color, color_utils; (h,l,s) = color_utils.hex2hls('$dark_base_color'); palette = peelee.Palette(colors_total=$colors_total, dark_colors_total=$dark_colors_total,colors_gradations=$colors_gradations,dark_colors_gradations_total=$dark_colors_gradations, colors_min=$token_min_color,colors_max=$token_max_color,dark_base_color='$dark_base_color', dark_colors_hue=h, dark_colors_saturation=s, dark_colors_lightness=l).generate_palette(); print(palette)")
    else
        palette=$($PYTHON3 -c "from peelee import peelee, color, color_utils; dark_random_color=peelee.generate_random_hex_color_code(color_name=$color_name, min_color=$min_color, max_color=$max_color); (h,l,s) = color_utils.hex2hls(dark_random_color); palette = peelee.Palette(colors_total=$colors_total, dark_colors_total=$dark_colors_total, colors_gradations=$colors_gradations,dark_colors_gradations_total=$dark_colors_gradations, colors_min=$token_min_color,colors_max=$token_max_color,dark_base_color=dark_random_color, dark_colors_hue=h, dark_colors_saturation=s, dark_colors_lightness=l).generate_palette(); print(palette)")
    fi
    tf1="$(mktemp)"
    tf2="$(mktemp)"
    echo "$palette" | grep -iEo '[CDL]_([[:digit:]]{2}|[RGBYCVOA])_[[:digit:]]{2}' > "${tf1}"
    # tmux only accept lower case color code
    echo "$palette" | grep -iEo '#[[:alnum:]]{6,}' | tr 'A-Z' 'a-z' > "${tf2}"
    paste -d':' ${tf1} ${tf2} > $DYNAMIC_PALETTE_FILENAME
}
create_dynamic_theme_file(){
    dynamic_theme_file_name="${DYNAMIC_THEME_NAME}${THEME_FILE_EXTENSION}"
    tmux set-option -gq "${TMUX_OPTION_NAME_DYNAMIC_THEME}" "${DYNAMIC_THEME_NAME}"
    if [ -e "${dynamic_theme_file_name}" ];then
       rm -f "${dynamic_theme_file_name}"
    fi
    cp "${TEMPLATE_THEME_FILENAME}" "${dynamic_theme_file_name}"
    replace_color "${dynamic_theme_file_name}"
}

create_dynamic_config_file(){
    eutmux_dynamic_config_file_name="${DYNAMIC_THEME_NAME}.eutmux.yaml"
    tmux set-option -gq "${TMUX_OPTION_NAME_DYNAMIC_CONFIG}" "${eutmux_dynamic_config_file_name}"
    if [ -e "${eutmux_dynamic_config_file_name}" ];then
        rm -f "${eutmux_dynamic_config_file_name}"
    fi

    # if config file not in $EUTMUX_CONFIG_HOME, then copy the default config file to $EUTMUX_CONFIG_HOME
    config_file="${EUTMUX_CONFIG_HOME}/${DEFAULT_CONFIG_FILENAME}"
    if [ ! -e "${config_file}" ];then
       cp "${DEFAULT_CONFIG_FILENAME}" "${EUTMUX_CONFIG_HOME}"
    fi

    cp "${config_file}" "${eutmux_dynamic_config_file_name}"
    replace_color "${eutmux_dynamic_config_file_name}"
}

replace_color(){
    target_file="${1}"
    palette_file="${2:-${PALETTE_FILENAME}}"
    t="$(mktemp)"
    grep -iEo 'C(_[[:digit:]]{1,}){2}' ${target_file} > "${t}"
    while read -r _color;do
        color_name="$(echo "${_color}" | cut -d':' -f1)"
        grep -q ${color_name} "${t}"
        if [ $? -ne $TRUE ];then
            continue
        fi
        color_value="$(echo "${_color}" | cut -d':' -f2)"
        sed -i "s/${color_name}/${color_value}/g" "${target_file}"
    done < "${_DIR}/${palette_file}"
}

show_all_themes(){
    local _themes
    # except for template
    _themes=""
    for _path in ${_DIR} ${EUTMUX_CONFIG_HOME}; do
        _themes="${_themes} $(find "${_path}" -name "*${THEME_FILE_EXTENSION}*" | sed -e 's/.*\///' | sed -e "s/${THEME_FILE_EXTENSION}//g" | grep -v template)"
    done
    _themes="${_themes## }"
    echo "${_themes}" | env sed -e 's/ /\n/g'
}

save_dynamic_theme(){
    local new_theme_name
    new_theme_name="${1}"
    if [ -z "${new_theme_name}" ];then
       tmux command-prompt -p "New theme name:" "\
                           run-shell 'eutmux.tmux -T %1'
                           "
       exit $?
    fi
    new_theme_name="${new_theme_name/%%${THEME_FILE_EXTENSION}*/}"
    current_dynamic_theme=$(tmux show-option -gqv "${TMUX_OPTION_NAME_DYNAMIC_THEME}")
    current_dynamic_theme_filename="${current_dynamic_theme}${THEME_FILE_EXTENSION}"
    if [ -e "${current_dynamic_theme_filename}" ];then
       cp "${current_dynamic_theme_filename}" "${EUTMUX_CONFIG_HOME}/${new_theme_name}${THEME_FILE_EXTENSION}"
       if [ $? -eq $TRUE ];then
          tmux display-message -d "${DELAY}" "New theme saved: ${EUTMUX_CONFIG_HOME}/${new_theme_name}${THEME_FILE_EXTENSION}"
       fi
    fi
}

# apply the given theme. if the theme name is not given, prompt to ask user to provide.
apply_theme(){
    local theme_name
    theme_name="${1}"

    if [ -z "${theme_name}" ];then
       tmux command-prompt -p "Target theme name:" "\
                 run-shell 'eutmux.tmux -t %1'
                 "
       exit $?
    else
       themes=$(show_all_themes)
       echo "$themes" | grep -q "${theme_name}"
       if [ $? -ne $TRUE ];then
          tmux display-message -d "${DELAY}" "Not found theme: '${theme_name}'"
          exit ${EXIT_ABNORMAL}
       fi
    fi
    THEME_NAME="${theme_name}"
}


main(){
    # pre-check
    if [ -z "${TMUX}" ];then
       _warn "Not in Tmux."
       exit "${EXIT_ABNORMAL}"
    fi

    # python environment and requirements installation
    if [ ! "$(which pip)" ] ; then
        _warn "Python Environment:\t CHECK FAILED. 'pip' command not found."
        exit "$EXIT_ABNORMAL"
    fi
    test -e "${_DIR}/.requirements.installed.txt"
    is_installed=$?
    is_latest=$FALSE
    if [ ${is_installed} -eq $TRUE ];then
       diff "${_DIR}/.requirements.installed.txt" "${_DIR}/requirements.txt" >/dev/null 2>/dev/null
       is_latest=$?
    fi
    if [[ $is_installed -ne $TURE || $is_latest -ne $TRUE ]];then
       env pip install -q -r "${_DIR}/requirements.txt" 2>/dev/null
       cp "${_DIR}/requirements.txt" "${_DIR}/.requirements.installed.txt"
    fi
    if [ $? -ne $TRUE ];then
       _warn "Python Environment:\t Dependencies Installation Failure."
    fi

    local current_dynamic_theme
    current_dynamic_theme=$(tmux show-option -gqv "${TMUX_OPTION_NAME_DYNAMIC_THEME}")

    # create dynamic theme and config file
    if [ "$CREATE_DYNMIC_THEME" -eq $TRUE ];then
       PALETTE_FILENAME=${DYNAMIC_PALETTE_FILENAME}
       generate_palette_colors
       create_dynamic_theme_file
    elif [ -n "${THEME_NAME}" ];then
        tmux set-option -gq "${TMUX_OPTION_NAME_DYNAMIC_THEME}" "${THEME_NAME}"
    elif [ "${ROTATE_THEME}" -eq ${TRUE} ];then
        local themes found_current_dynamic_theme new_dynamic_theme first_theme
        themes="$(show_all_themes)"
        found_current_dynamic_theme=${FALSE}
        new_dynamic_theme=""
        first_theme=""
        for theme in ${themes}; do
            if [ -z "${first_theme}" ];then
               first_theme="${theme}"
            fi
            # if no current dynamic theme, then set the first theme as new dynamic theme
            if [ -z "${current_dynamic_theme}" ];then
               new_dynamic_theme="${theme}"
               break
            fi
            if [ "${theme}" == "${current_dynamic_theme}" ];then
               found_current_dynamic_theme=${TRUE}
               continue
            fi
            # set the next theme as current dynamic theme
            if [ "${found_current_dynamic_theme}" -eq ${TRUE} ];then
               new_dynamic_theme="${theme}"
               break
            fi
        done
        # if the current dynamic theme if the last theme, then new theme will be the first theme.
        if [ -z "${new_dynamic_theme}" ];then
           new_dynamic_theme="${first_theme}"
        fi
        tmux set-option -gq "${TMUX_OPTION_NAME_DYNAMIC_THEME}" "${new_dynamic_theme}"
    else
        tmux set-option -gq "${TMUX_OPTION_NAME_DYNAMIC_THEME}" "${current_dynamic_theme}"
    fi
    create_dynamic_config_file

    # set environment variables
    prepend_path "${_DIR}" "${EUTMUX_CONFIG_HOME}"
    prepend_pythonpath "${_DIR}"
    export EUTMUX_WORKDIR="${_DIR}"
    export PYTHONUTF8=1
    find "${_DIR}" -name "*.sh" -exec chmod u+x '{}' \;
    tmux set-environment -g 'EUTMUX_WORKDIR' "${_DIR}"
    tmux set-environment -g 'PATH' "${PATH}"
    tmux set-environment -g 'PYTHONPATH' "${PYTHONPATH}"

    # generate and execute tmux commands
    tmux_commands="$(python3 -c "import eutmux; tmux_commands = eutmux.init(); print(tmux_commands)")"
    echo "${tmux_commands}" | sed -e 's/True/on/g' | sed -e 's/False/off/g' | tr ';' '\n' > "${TMUX_COMMANDS_FILENAME}"
    tmux source "${TMUX_COMMANDS_FILENAME}"
}


usage(){
    echoh "./eutmux.tmux [-a] [-d] [-D] [-r] [-R] [-t] [-T new-theme-name]"
}

setup
while getopts "ac:dDrRt:T:" opt; do
    case $opt in
        a) show_all_themes; exit $? ;;
        c) DARK_BASE_COLOR="${OPTARG}" ;;
        d) CREATE_DYNMIC_THEME=${TRUE} ;;
        D) THEME_NAME="eutmux" ;;
        r) ROTATE_THEME=${TRUE} ;;
        R) replace_legacy_placeholders; exit $? ;;
        t) apply_theme "${OPTARG}" ;;
        T) NEW_THEME_NAME="$OPTARG"; save_dynamic_theme "${NEW_THEME_NAME}"; exit $? ;;
        *|?) usage; exit "${EXIT_SUCCESS}" ;;
    esac
done
main
teardown

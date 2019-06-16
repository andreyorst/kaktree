# ╭─────────────╥──────────────────────╮
# │ Author:     ║ File:                │
# │ Andrey Orst ║ filetree.kak         │
# ╞═════════════╩══════════════════════╡
# │ Filetree browser for Kakoune       │
# ╞════════════════════════════════════╡
# │ GitHub.com/andreyorst/filetree.kak │
# ╰────────────────────────────────────╯

declare-option -hidden str filetree__source %sh{printf "%s" "${kak_source%/rc/*}"}

define-command -docstring "filetree-enable: Create filetree window if not exist and enable related hooks." \
filetree-enable %{
    require-module filetree
    filetree-enable-impl
}

provide-module filetree %§

# Main configuration options
declare-option -docstring "name of the client that filetree will use to display itself." \
str filetreeclient 'filetreeclient'

declare-option -docstring "Choose how to split current pane to display filetree panel.
    Possible values: vertical, horizontal
    Default value: horizontal" \
str filetree_split "horizontal"

declare-option -docstring "Choose where to display filetree panel.
    Possible values: left, right
    Default value: left
When filetree_split is set to 'horizontal', 'left' and 'right' will make split above or below current pane respectively." \
str filetree_side "left"

declare-option -docstring "The size of filetree pane. Can be either a number of columns or size in percentage." \
str filetree_size '28'

declare-option -docstring "Icon of the closed directory displayed next to direname." \
str filetree_dir_icon_close '+'

declare-option -docstring "Icon of the opened directory displayed next to direname." \
str filetree_dir_icon_open '-'

declare-option -docstring "Icon of the file displayed next to filename." \
str filetree_file_icon '#'

declare-option -docstring "Amount of indentation for nested items." \
int filetree_indentation 2

# Helper options
declare-option -hidden str filetree__jumpclient
declare-option -hidden str filetree__last_client ''
declare-option -hidden str filetree__active 'false'
declare-option -hidden str filetree__onscreen 'false'
declare-option -hidden str filetree__current_indent ''

# add-highlighter shared/filetree group
# add-highlighter shared/filetree/category regex ^[^\s][^\n]+$ 0:keyword
# add-highlighter shared/filetree/info     regex (?<=:\h)(.*?)$   1:comment

hook -group filetree-syntax global WinSetOption filetype=filetree %{
    add-highlighter window/filetree ref filetree
    hook -always -once window WinSetOption filetype=.* %{
        remove-highlighter window/filetree
    }
}

define-command -hidden filetree-enable-impl %{
    evaluate-commands %sh{
        [ "${kak_opt_filetree__active}" = "true" ] && exit
        printf "%s\n" "set-option global filetree__jumpclient '${kak_client:-client0}'
                       set-option global filetree__active true
                       filetree-display
                       set-option global filetree__onscreen true"
    }
}

define-command -docstring "filetree-disable: Disable filetree, delete filetreeclient and remove filetree related hooks" \
filetree-disable %{
    set-option global filetree__active 'false'
    set-option global filetree__onscreen 'false'
    remove-hooks global filetree-watchers
    try %{ delete-buffer! *filetree* } catch %{ echo -debug "Can't delete *filetree* buffer. Error message: %val{error}" }
    try %{ evaluate-commands -client %opt{filetreeclient} quit } catch %{ echo -debug "Can't close %opt{filetreeclient}. Error message: %val{error}" }
}

define-command -docstring "filetree-toggle: Toggle filetree window on and off" \
filetree-toggle %{ evaluate-commands %sh{
    if [ "${kak_opt_filetree__active}" = "true" ]; then
        if [ "${kak_opt_filetree__onscreen}" = "true" ]; then
            printf "%s\n" "evaluate-commands -client %opt{filetreeclient} quit
                           set-option global filetree__onscreen false"
        else
            printf "%s\n" "evaluate-commands filetree-display
                           set-option global filetree__onscreen true"
        fi
    fi
}}

define-command -hidden filetree-display %{ nop %sh{
    [ "${kak_opt_filetree__onscreen}" = "true" ] && exit

    filetree_cmd="try %{ edit! -debug -scratch *filetree* } catch %{ buffer *filetree* }
                rename-client %opt{filetreeclient}
                hook -group filetree-watchers global FocusIn (?!${kak_opt_filetreeclient}).* %{ try %{ filetree-update 'focus' } }
                hook -group filetree-watchers global WinDisplay (?!\*filetree\*).* %{ try %{ filetree-update } }
                hook -group filetree-watchers global BufWritePost (?!\*filetree\*).* %{ try %{ filetree-update } }
                hook -group filetree-watchers global WinSetOption filetree_(sort|display_anon)=.* %{ try %{ filetree-update } }
                focus ${kak_client:-client0}"

    if [ -n "$TMUX" ]; then
        [ "${kak_opt_filetree_split}" = "vertical" ] && split="-v" || split="-h"
        [ "${kak_opt_filetree_side}" = "left" ] && side="-b" || side=
        [ -n "${kak_opt_filetree_size%%*%}" ] && measure="-l" || measure="-p"
        tmux split-window ${split} ${side} ${measure} ${kak_opt_filetree_size%%%*} kak -c ${kak_session} -e "${filetree_cmd}"
    elif [ -n "${kak_opt_termcmd}" ]; then
        ( ${kak_opt_termcmd} "sh -c 'kak -c ${kak_session} -e \"${filetree_cmd}\"'" ) > /dev/null 2>&1 < /dev/null &
    fi
}}

define-command -hidden filetree-update -params ..1 %{ evaluate-commands %sh{
    [ "${kak_opt_filetree__active}" != "true" ] && exit
    if [ "$1" = "focus" ] && [ "${kak_client}" = "${kak_opt_filetree__last_client}" ]; then
        exit
    else
        printf "%s\n" "set-option global filetree__last_client %{${kak_client}}"
    fi

    printf "%s\n" "set-option global filetree__jumpclient '${kak_client:-client0}'"

    tmp=$(mktemp -d "${TMPDIR:-/tmp}/kakoune-filetree.XXXXXXXX")
    tree="${tmp}/tree"
    fifo="${tmp}/fifo"
    mkfifo ${fifo}

    printf "%s\n" "hook global -always KakEnd .* %{ nop %sh{ rm -rf ${tmp} }}"

    basename() {
        filename=$1
        case "$filename" in
          */*[!/]*)
            trail=${filename##*[!/]}
            filename=${filename%%"$trail"}
            base=${filename##*/} ;;
          *[!/]*)
            trail=${filename##*[!/]}
            base=${filename%%"$trail"} ;;
          *) base="/" ;;
        esac
        printf "%s\n" "${base}"
    }

    # $kak_opt_filetree_dir_icon_open
    # $kak_opt_filetree_dir_icon_close
    # $kak_opt_filetree_file_icon
    # $kak_opt_filetree_indentation
    # $kak_opt_filetree__current_indent
    export filetree_root=$(basename $(pwd))

    command ls -1p $(pwd) | perl $kak_opt_filetree__source/perl/filetree.pl > ${tree}

    printf "%s\n" "evaluate-commands -client %opt{filetreeclient} %{ try %{
                       edit! -debug -fifo ${fifo} *filetree*
                       hook global BufCloseFifo .* %{ evaluate-commands -buffer *filetree* %{ set-option buffer readonly true }}
                       set-option buffer filetype filetree
                       map buffer normal '<ret>' ': filetree-ret-action<ret>'
                       map buffer normal '<tab>' ': filetree-tab-action<ret>'
                       try %{ set-option window tabstop 1 }
                       try %{ focus ${kak_client} }
                   }}"

    ( cat ${tree} > ${fifo}; rm -rf ${tmp} ) > /dev/null 2>&1 < /dev/null &
}}

define-command -hidden filetree-ret-action %{ evaluate-commands -save-regs 'a' %{
    try %{
        set-register a %opt{filetree_dir_icon_close}
        execute-keys -draft '<a-x>s\Q<c-r>a<ret>'
        filetree-change-root
    } catch %{
        set-register a %opt{filetree_dir_icon_open}
        execute-keys -draft '<a-x>s\Q<c-r>a<ret>'
        filetree-change-root
    } catch %{
        set-register a %opt{filetree_file_icon}
        execute-keys -draft '<a-x>s\Q<c-r>a<ret>'
        filetree-file-open
    } catch %{
        nop
    }
}}

define-command -hidden filetree-tab-action %{ evaluate-commands -save-regs 'a' %{
    try %{
        set-register a %opt{filetree_dir_icon_close}
        execute-keys -draft '<a-x>s\Q<c-r>a<ret>'
        filetree-dir-unfold
    } catch %{
        set-register a %opt{filetree_dir_icon_open}
        execute-keys -draft '<a-x>s\Q<c-r>a<ret>'
        filetree-dir-fold
    } catch %{
        nop
    }
}}

define-command -docstring "filetree-dir-unfold: unfold current directory." \
filetree-dir-unfold %{ evaluate-commands -save-regs 'abc"' %{
    # store currently expanded directory name into register 'a' 
    execute-keys -draft '<a-h><a-l>S\h*[+-]\h+<ret><space>"ay'

    # store current amount of indentation to the register 'b'
    try %{
        execute-keys -draft '<a-x>s^\h+<ret>"by'
        set-option global filetree__current_indent %reg{b}
    } catch %{
        set-option global filetree__current_indent ''
    }

    # store entire tree into register 'c' to build up path to currently expanded dir.
    execute-keys -draft '<a-x><a-h>Gk"cy'

    # build subtree
    evaluate-commands %sh{
        # Perl will need these variables:
        # $kak_opt_filetree_dir_icon_open
        # $kak_opt_filetree_dir_icon_close
        # $kak_opt_filetree_file_icon
        # $kak_opt_filetree_indentation
        # $kak_opt_filetree__current_indent

        tmp=$(mktemp -d "${TMPDIR:-/tmp}/kakoune-filetree.XXXXXXXX")
        tree="${tmp}/tree"

        dir=$(printf "%s\n" "$kak_reg_a" | sed "s/^'\|'$//g")
        export filetree_root=$(basename "$dir")
        [ "$dir" = "$(basename $(pwd))" ] && dir="."

        # build full path based on indentation to the currently expanded directory.
        current_path=$(printf "%s\n" "$kak_reg_c" | perl $kak_opt_filetree__source/perl/path_maker.pl)

        command ls -1p "./$current_path/$dir" | perl $kak_opt_filetree__source/perl/filetree.pl > $tree
        contents=$(cat $tree)
        printf "%s\n" "set-register '\"' %{$contents}"
    }
    execute-keys '<a-x>Ra<ret><esc><a-;><space>;'
}}

define-command -docstring "filetree-dir-fold: fold current directory." \
filetree-dir-fold %{
    execute-keys -draft 'j<a-i>idkI<space><esc><a-h>f-;r+i<backspace>'
}

define-command -docstring "filetree-file-open: open current file in %opt{filetree__jumpclient}." \
filetree-file-open %{}

hook global ClientClose .* %{ evaluate-commands -client %opt{filetreeclient} %sh{
    eval "set -- ${kak_client_list}"
    if [ $# -eq 1 ] && [ "$1" = "${kak_opt_filetreeclient}" ]; then
        printf "%s\n" "filetree-disable"
    fi
}}

§

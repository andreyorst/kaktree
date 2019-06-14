# ╭─────────────╥──────────────────────╮
# │ Author:     ║ File:                │
# │ Andrey Orst ║ filetree.kak         │
# ╞═════════════╩══════════════════════╡
# │ Filetree browser for Kakoune       │
# ╞════════════════════════════════════╡
# │ GitHub.com/andreyorst/filetree.kak │
# ╰────────────────────────────────────╯

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
    filetree_buffer="${tmp}/buffer"
    fifo="${tmp}/fifo"
    mkfifo ${fifo}

    printf "%s\n" "hook global -always KakEnd .* %{ nop %sh{ rm -rf ${tmp} }}"

    ls -1 --sort type > ${filetree_buffer}

    printf "%s\n" "evaluate-commands -client %opt{filetreeclient} %{ try %{
                       edit! -debug -fifo ${fifo} *filetree*
                       hook global BufCloseFifo .* %{ evaluate-commands -buffer *filetree* %{ set-option buffer readonly true }}
                       set-option buffer filetype filetree
                       map buffer normal '<ret>' ': filetree-action %{${kak_bufname}}<ret>'
                       try %{ set-option window tabstop 1 }
                       try %{ focus ${kak_client} }
                   }}"

    ( cat ${filetree_buffer} > ${fifo}; rm -rf ${tmp} ) > /dev/null 2>&1 < /dev/null &
}}

define-command -hidden filetree-action -params 1 %{
    execute-keys '<a-h>;/: <c-v><c-i><ret><a-h>2<s-l><a-l><a-;>'
    evaluate-commands -client %opt{filetree__jumpclient} %sh{
        printf "%s: \t%s\n" "${kak_selection}" "$1" | awk -F ': \t' '{
                keys = $2; gsub(/</, "<lt>", keys); gsub(/\t/, "<c-v><c-i>", keys);
                gsub("&", "&&", keys); gsub("#", "##", keys);
                select = $1; gsub(/</, "<lt>", select); gsub(/\t/, "<c-v><c-i>", select);
                gsub("&", "&&", select); gsub("#", "##", select);
                bufname = $3; gsub("&", "&&", bufname); gsub("#", "##", bufname);
                print "try %# buffer %&" bufname "&; execute-keys %&<esc>/\\Q" keys "<ret>vc& # catch %# echo -markup %&{Error}unable to find tag& #; try %# execute-keys %&s\\Q" select "<ret>& #"
            }'
    }
    try %{ focus %opt{filetree__jumpclient} }
}


try %{
    hook global ClientClose .* %{ evaluate-commands -client %opt{filetreeclient} %sh{
        eval "set -- ${kak_client_list}"
        if [ $# -eq 1 ] && [ "$1" = "${kak_opt_filetreeclient}" ]; then
            printf "%s\n" "filetree-disable"
        fi
    }}
} catch %{
    echo -debug "filetree.kak failed to declare 'ClientClose' hooks, consider using 'filetree-quit' to quit Kakoune properly"

    define-command -docstring \
    "filetree-quit [<exclamation mark>] [<exit status>]: quit current client, and the kakoune session, and close filetree only if two clients left, one of which is `%opt{filetreeclient}'.
    If `!' is specified as a first argument `quit!' is called. An optional integer parameter can set the client exit status" \
    filetree-quit -params .. %{ evaluate-commands %sh{
        ( eval "set -- ${kak_client_list}"
        if [ $# -eq 2 ] && [ $(expr "${kak_client_list}" : ".*${kak_opt_filetreeclient}.*") -ne 0 ]; then
            printf "%s\n" "filetree-disable"
        fi )
        if [ "$1" = '!' ]; then exclamation='!'; shift; fi
        printf "%s\n" "quit${exclamation} $@"
    }}

    define-command -docstring \
    "filetree-write-quit [<exclamation mark>] [-sync] [<exit status>]: write current buffer and quit current client, and close filetree only if two clients left, one of which is `%opt{filetreeclient}'.
    If `!' is specified as a first argument `write-quit!' is called. An optional integer parameter can set the client exit status.
    Switches:
        -sync  force the synchronization of the file onto the filesystem  " \
    filetree-write-quit -params .. %{ evaluate-commands %sh{
        ( eval "set -- ${kak_client_list}"
        if [ $# -eq 2 ] && [ $(expr "${kak_client_list}" : ".*${kak_opt_filetreeclient}.*") -ne 0 ]; then
            printf "%s\n" "filetree-disable"
        fi )
        if [ "$1" = '!' ]; then exclamation='!'; shift; fi
        printf "%s\n" "write-quit${exclamation} $@"
    }}
}

§

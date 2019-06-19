# ╭─────────────╥─────────────────────╮
# │ Author:     ║ File:               │
# │ Andrey Orst ║ kaktree.kak         │
# ╞═════════════╩═════════════════════╡
# │ Filetree browser for Kakoune      │
# ╞═══════════════════════════════════╡
# │ GitHub.com/andreyorst/kaktree.kak │
# ╰───────────────────────────────────╯

declare-option -hidden str kaktree__source %sh{printf "%s" "${kak_source%/rc/*}"}

define-command -docstring "kaktree-enable: Create kaktree window if not exist and enable related hooks." \
kaktree-enable %{
    require-module kaktree
    kaktree-enable-impl
}

provide-module kaktree %§

# Main configuration options
declare-option -docstring "name of the client that kaktree will use to display itself." \
str kaktreeclient 'kaktreeclient'

declare-option -docstring "Choose how to split current pane to display kaktree panel.
    Possible values: vertical, horizontal
    Default value: horizontal" \
str kaktree_split "horizontal"

declare-option -docstring "Choose where to display kaktree panel.
    Possible values: left, right
    Default value: left
When kaktree_split is set to 'horizontal', 'left' and 'right' will make split above or below current pane respectively." \
str kaktree_side "left"

declare-option -docstring "The size of kaktree pane. Can be either a number of columns or size in percentage." \
str kaktree_size '28'

declare-option -docstring "Icon of the closed directory displayed next to direname." \
str kaktree_dir_icon_close '+'

declare-option -docstring "Icon of the opened directory displayed next to direname." \
str kaktree_dir_icon_open '-'

declare-option -docstring "Icon of the file displayed next to filename." \
str kaktree_file_icon '#'

declare-option -docstring "Show hidden files." \
bool kaktree_show_hidden true

declare-option -docstring "Highlight current line in kaktree buffer." \
bool kaktree_hlline true

declare-option -docstring "Amount of indentation for nested items. Must be greater than zero." \
int kaktree_indentation 2

declare-option -docstring "command to provide list of files. Strongly recommended to use analogs of -1 and -d if changed to another program.
Default value:
    ls -1p" \
str kaktree_ls_command "ls -1p"

declare-option -hidden -docstring "Argument to pass to `kaktree_ls_command', to provide hidden files." \
str kaktree_hidden_arg "-a"

# Helper options
declare-option -hidden str kaktree__jumpclient
declare-option -hidden str kaktree__active 'false'
declare-option -hidden str kaktree__onscreen 'false'
declare-option -hidden str kaktree__current_indent ''

set-face global kaktree_icon_face default,default+b@comment
set-face global kaktree_hlline_face default,default+@SecondarySelection

add-highlighter shared/kaktree group
add-highlighter shared/kaktree/icon regex ^\h*(.) 1:kaktree_icon_face
add-highlighter shared/kaktree/empty regex ^\h+<empty> 0:comment

hook -group kaktree-syntax global WinSetOption filetype=kaktree %{
    add-highlighter window/kaktree ref kaktree
    hook -always -once window WinSetOption filetype=.* %{
        remove-highlighter window/kaktree
    }
}

define-command -hidden kaktree-hlline-update %{
    try %{ remove-highlighter buffer/hlline }
    try %{ add-highlighter buffer/hlline line %val{cursor_line} kaktree_hlline_face }
}


define-command -hidden kaktree-hlline-toggle %{ evaluate-commands -buffer *kaktree* %sh{
    if [ "$kak_opt_kaktree_hlline" = "true" ]; then
        printf "%s\n" "hook -group kaktree-hlline buffer RawKey '[jk]|<up>|<down>' kaktree-hlline-update
                       hook -group kaktree-hlline buffer NormalIdle .* kaktree-hlline-update"
    else
        printf "%s\n" "remove-hooks buffer kaktree-hlline
                       remove-highlighter buffer/hlline"
    fi
}}

hook global WinSetOption kaktree_hlline=.+ kaktree-hlline-toggle

define-command -hidden kaktree-hidden-toggle %{ evaluate-commands %sh{
    if [ "$kak_opt_kaktree_show_hidden" = "true" ]; then
        printf "%s\n" "set-option global kaktree_show_hidden false"
    else
        printf "%s\n" "set-option global kaktree_show_hidden true"
    fi
}}

hook global GlobalSetOption kaktree_show_hidden=.+ kaktree-refresh

define-command -hidden kaktree-enable-impl %{
    evaluate-commands %sh{
        [ "${kak_opt_kaktree__active}" = "true" ] && exit
        printf "%s\n" "set-option global kaktree__jumpclient '${kak_client:-client0}'
                       set-option global kaktree__active true
                       hook -group kaktree-watchers global FocusIn (?!${kak_opt_kaktreeclient}).* %{
                           set-option global kaktree__jumpclient %{${kak_client:-client0}}
                       }
                       kaktree-display
                       set-option global kaktree__onscreen true"
    }
}

define-command -docstring "kaktree-disable: Disable kaktree, delete kaktreeclient and remove kaktree related hooks" \
kaktree-disable %{
    set-option global kaktree__active 'false'
    set-option global kaktree__onscreen 'false'
    remove-hooks global kaktree-watchers
    try %{ delete-buffer! *kaktree* } catch %{ echo -debug "Can't delete *kaktree* buffer. Error message: %val{error}" }
    try %{ evaluate-commands -client %opt{kaktreeclient} quit } catch %{ echo -debug "Can't close %opt{kaktreeclient}. Error message: %val{error}" }
}

define-command -docstring "kaktree-toggle: Toggle kaktree window on and off" \
kaktree-toggle %{ evaluate-commands %sh{
    if [ "${kak_opt_kaktree__active}" = "true" ]; then
        if [ "${kak_opt_kaktree__onscreen}" = "true" ]; then
            printf "%s\n" "evaluate-commands -client %opt{kaktreeclient} quit
                           set-option global kaktree__onscreen false"
        else
            printf "%s\n" "evaluate-commands kaktree-display
                           set-option global kaktree__onscreen true"
        fi
    fi
}}

define-command -hidden kaktree-display %{ nop %sh{
    [ "${kak_opt_kaktree__onscreen}" = "true" ] && exit

    kaktree_cmd="try %{
                     buffer *kaktree*
                     rename-client %opt{kaktreeclient}
                 } catch %{
                     edit! -debug -scratch *kaktree*
                     set-option buffer filetype kaktree
                     rename-client %opt{kaktreeclient}
                     kaktree-refresh
                 }
                 focus ${kak_client:-client0}"

    if [ -n "$TMUX" ]; then
        [ "${kak_opt_kaktree_split}" = "vertical" ] && split="-v" || split="-h"
        [ "${kak_opt_kaktree_side}" = "left" ] && side="-b" || side=
        [ -n "${kak_opt_kaktree_size%%*%}" ] && measure="-l" || measure="-p"
        tmux split-window ${split} ${side} ${measure} ${kak_opt_kaktree_size%%%*} kak -c ${kak_session} -e "${kaktree_cmd}"
    elif [ -n "${kak_opt_termcmd}" ]; then
        ( ${kak_opt_termcmd} "sh -c 'kak -c ${kak_session} -e \"${kaktree_cmd}\"'" ) > /dev/null 2>&1 < /dev/null &
    fi
}}

define-command -hidden kaktree-refresh %{ evaluate-commands %sh{
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/kakoune-kaktree.XXXXXXXX")
    tree="${tmp}/tree"
    fifo="${tmp}/fifo"
    mkfifo ${fifo}

    printf "%s\n" "hook global -always KakEnd .* %{ nop %sh{ rm -rf ${tmp} }}"

    basename() {
        filename="$1"
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

    # $kak_opt_kaktree_dir_icon_open
    # $kak_opt_kaktree_dir_icon_close
    # $kak_opt_kaktree_file_icon
    # $kak_opt_kaktree_indentation
    # $kak_opt_kaktree__current_indent
    # $kak_opt_kaktree_show_hidden
    kak_opt_kaktree__current_indent=""
    export kaktree_root="$(basename $(pwd))"
    [ "$kak_opt_kaktree_show_hidden" = "true" ] && hidden="$kak_opt_kaktree_hidden_arg"
    command $kak_opt_kaktree_ls_command $hidden $(pwd) | perl $kak_opt_kaktree__source/perl/kaktree.pl > ${tree}

    printf "%s\n" "evaluate-commands -client %opt{kaktreeclient} %{ try %{
                       edit! -debug -fifo ${fifo} *kaktree*
                       map buffer normal '<ret>' ': kaktree-ret-action<ret>'
                       map buffer normal '<tab>' ': kaktree-tab-action<ret>'
                       map buffer normal 'u' ': kaktree-change-root up<ret>'
                       map buffer normal 'H' ': kaktree-hidden-toggle<ret>'
                       map buffer normal 'r' ': kaktree-refresh<ret>'
                       try %{ set-option window tabstop 1 }
                       try %{ focus ${kak_client} }
                   }}"

    ( cat ${tree} > ${fifo}; rm -rf ${tmp} ) > /dev/null 2>&1 < /dev/null &
}}

define-command -hidden kaktree-ret-action %{ evaluate-commands -save-regs 'a' %{
    try %{
        set-register a %opt{kaktree_dir_icon_close}
        execute-keys -draft '<a-x>s^\h*\Q<c-r>a<ret>'
        kaktree-change-root
    } catch %{
        set-register a %opt{kaktree_dir_icon_open}
        execute-keys -draft '<a-x>s^\h*\Q<c-r>a<ret>'
        kaktree-change-root
    } catch %{
        set-register a %opt{kaktree_file_icon}
        execute-keys -draft '<a-x>s^\h*\Q<c-r>a<ret>'
        kaktree-file-open
    }
}}

define-command -hidden kaktree-tab-action %{ evaluate-commands -save-regs 'a' %{
    try %{
        set-register a %opt{kaktree_dir_icon_close}
        execute-keys -draft '<a-x>s^\h*\Q<c-r>a\E<ret>'
        kaktree-dir-unfold
    } catch %{
        set-register a %opt{kaktree_dir_icon_open}
        execute-keys -draft '<a-x>s^\h*\Q<c-r>a\E<ret>'
        kaktree-dir-fold
    } catch %{
        nop
    }
}}

define-command -hidden kaktree-dir-unfold %{ evaluate-commands -save-regs 'abc"' %{
    # store currently expanded directory name into register 'a'
    execute-keys -draft '<a-h><a-l>"ay'

    # store current amount of indentation to the register 'b'
    try %{
        execute-keys -draft '<a-x>s^\h+<ret>"by'
        set-option global kaktree__current_indent %reg{b}
    } catch %{
        set-option global kaktree__current_indent ''
    }

    # store entire tree into register 'c' to build up path to currently expanded dir.
    execute-keys -draft '<a-x><a-h>Gk"cy'

    # build subtree
    evaluate-commands %sh{
        # Perl will need these variables:
        # $kak_opt_kaktree_dir_icon_open
        # $kak_opt_kaktree_dir_icon_close
        # $kak_opt_kaktree_file_icon
        # $kak_opt_kaktree_indentation
        # $kak_opt_kaktree__current_indent
        # $kak_opt_kaktree_show_hidden

        basename() {
            filename="$1"
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

        dir=$(printf "%s\n" "$kak_reg_a" | sed "s/^'\|'$//g;")
        dir=$(printf "%s\n" "$dir" | perl -pe "s/\s*(\Q$kak_opt_kaktree_dir_icon_open\E|\Q$kak_opt_kaktree_dir_icon_close\E) (.*)$/\$2/g;")
        export kaktree_root="$(basename "$dir")"
        [ "$dir" = "$(basename $(pwd))" ] && dir="."

        # build full path based on indentation to the currently expanded directory.
        current_path=$(printf "%s\n" "$kak_reg_c" | perl $kak_opt_kaktree__source/perl/path_maker.pl)

        [ "$kak_opt_kaktree_show_hidden" = "true" ] && hidden="$kak_opt_kaktree_hidden_arg"
        tree=$(command $kak_opt_kaktree_ls_command $hidden "./$current_path/$dir" | perl $kak_opt_kaktree__source/perl/kaktree.pl)
        printf "%s\n" "set-register '\"' %{$tree}"
    }
    execute-keys '<a-x>Ra<ret><esc><a-;><space>;'
}}

define-command -hidden kaktree-dir-fold %{ evaluate-commands -save-regs '"/' %sh{
    printf "%s\n" "execute-keys 'j<a-i>idkI<space><esc><a-h>;/\Q<space>${kak_opt_kaktree_dir_icon_open}\E<ret>c${kak_opt_kaktree_dir_icon_close}<esc>gh'"
}}

define-command -hidden kaktree-file-open %{ evaluate-commands -save-regs 'abc"' %{
    # store current file name into register 'a'
    execute-keys -draft '<a-h><a-l>"ay'

    # store current amount of indentation to the register 'b'
    try %{
        execute-keys -draft '<a-x>s^\h+<ret>"by'
        set-option global kaktree__current_indent %reg{b}
    } catch %{
        set-option global kaktree__current_indent ''
    }

    # store entire tree into register 'c' to build up path to current file
    execute-keys -draft '<a-x><a-h>Gk"cy'

    evaluate-commands -client %opt{kaktree__jumpclient} %sh{
        # Perl will need these variables:
        # $kak_opt_kaktree_dir_icon_open
        # $kak_opt_kaktree_dir_icon_close
        # $kak_opt_kaktree_file_icon
        # $kak_opt_kaktree_indentation
        # $kak_opt_kaktree__current_indent

        basename() {
            filename="$1"
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

        file=$(printf "%s\n" "$kak_reg_a" | sed "s/^'\|'$//g")
        file=$(printf "%s\n" "$file" | perl -pe "s/\s*(\Q$kak_opt_kaktree_file_icon\E) (.*)$/\$2/g;")

        # build full path based on indentation to the currently expanded directory.
        current_path=$(printf "%s\n" "$kak_reg_c" | perl $kak_opt_kaktree__source/perl/path_maker.pl)
        file_path=$(printf "%s\n" "$(pwd)/$current_path/$file" | sed "s/#/##/g")
        printf "%s\n" "edit -existing %#$file_path#"
        printf "%s\n" "focus %opt{kaktree__jumpclient}"
    }
}}

define-command -hidden kaktree-change-root -params ..1 %{ evaluate-commands -save-regs 'ab"' %{
    # store currently expanded directory name into register 'a'
    execute-keys -draft '<a-h><a-l>S\h*.\h+<ret><space>"ay'
    # store current amount of indentation to the register 'b'

    try %{
        execute-keys -draft '<a-x>s^\h+<ret>"by'
        set-option global kaktree__current_indent %reg{b}
    } catch %{
        set-option global kaktree__current_indent ''
    }

    # store entire tree into register 'c' to build up path to currently expanded dir.
    execute-keys -draft '<a-x><a-h>Gk"cy'

    evaluate-commands %sh{
        # Perl will need these variables:
        # $kak_opt_kaktree_dir_icon_open
        # $kak_opt_kaktree_dir_icon_close
        # $kak_opt_kaktree_file_icon
        # $kak_opt_kaktree_indentation
        # $kak_opt_kaktree__current_indent
        # $kak_opt_kaktree_show_hidden

        basename() {
            filename="$1"
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

        current_path=$(printf "%s\n" "$kak_reg_c" | perl $kak_opt_kaktree__source/perl/path_maker.pl)

        dir=$(printf "%s\n" "$kak_reg_a" | sed "s/^'\|'$//g;s/#/##/g")

        if [ "$(basename $dir)" = "$(basename $(pwd))" ] || [ "$1" = "up" ]; then
            cd ..
            dir=$(basename $(pwd))
            export kaktree_root="$(basename $dir)"
            current_path="$(pwd)/$current_path"
        else
            export kaktree_root="$(basename $dir)"
            current_path="$(pwd)/$current_path/$dir"
        fi

        escaped_path=$(printf "%s\n" "$current_path" | sed "s/#/##/g")
        printf "%s\n" "change-directory %#$escaped_path#"
        kak_opt_kaktree__current_indent=""
        [ "$kak_opt_kaktree_show_hidden" = "true" ] && hidden="$kak_opt_kaktree_hidden_arg"
        tree=$(command $kak_opt_kaktree_ls_command $hidden "$current_path" | perl $kak_opt_kaktree__source/perl/kaktree.pl | sed "s/#/##/g")
        printf "%s\n" "set-register '\"' %#$tree#; execute-keys '%Rgg'"
    }
}}

hook global ClientClose .* %{ evaluate-commands -client %opt{kaktreeclient} %sh{
    eval "set -- ${kak_client_list}"
    if [ $# -eq 1 ] && [ "$1" = "${kak_opt_kaktreeclient}" ]; then
        printf "%s\n" "kaktree-disable"
    fi
}}

§

hook global ModuleLoad powerline %§

# format modeline in filetree window
# requires `powerline.kak' plugin: https://github.com/andreyorst/powerline.kak
hook -group kaktree-powerline global WinSetOption filetype=kaktree %{
    declare-option str powerline_format
    set-option window powerline_format ""
}

§

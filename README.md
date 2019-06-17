# kaktree

![kaktree](https://user-images.githubusercontent.com/19470159/59591851-770a5b00-90f7-11e9-8a22-52fae3211829.png)

This plugin displays the interactive filetree. It requires Tmux and Perl, as well as `ls` command.

## Installation
## With [plug.kak](https://github.com/andreyorst/plug.kak)
Add this to your `kakrc`:

```sh
plug "andreyorst/kaktree" config %{
    map global user 'f' ": kaktree-toggle<ret>" -docstring "toggle filetree panel"
    hook global WinSetOption filetype=kaktree %{
        remove-highlighter buffer/numbers
        remove-highlighter buffer/matching
        remove-highlighter buffer/wrap
        remove-highlighter buffer/show-whitespaces
    }
    kaktree-enable
}
```

Restart Kakoune or re-source your `kakrc` and call `plug-install` command.

## Without plugin manager
Clone this repo to your autoload directory, or source `kaktree.kak` file from your `kakrc`.

It's better to disable line numbers and wrap highlighters as shown in the plug.kak example above.

# kaktree

![kaktree](https://user-images.githubusercontent.com/19470159/59667890-2d397780-91c0-11e9-9214-e32b04539e7a.png)

This plugin displays the interactive filetree. It requires Tmux and Perl, as
well as `ls` command.

## Installation
You need latest Kakoune build from master in order to use
this plugin. __*still waiting for new stable release with module system...*__

## With [plug.kak](https://github.com/andreyorst/plug.kak)
Add this to your `kakrc`:

```sh
plug "andreyorst/kaktree" defer kaktree %{
    # settings for fancy icons as on the screenshot above.
    set-option global kaktree_dir_icon_open  '▾ 🗁 ' # 📂 📁
    set-option global kaktree_dir_icon_close '▸ 🗀 '
    set-option global kaktree_file_icon      '⠀⠀🖹 ' # 🖺 🖻
                                            # ^^ these are not spaces. It is invisible characters.
                                            # This needed to make folding work correctly if you do
                                            # space alignment of icons.
} config %{
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

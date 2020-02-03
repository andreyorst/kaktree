# ╭─────────────╥─────────────────╮
# │ Author:     ║ File:           │
# │ Andrey Orst ║ kaktree.pl      │
# ╞═════════════╩═════════════════╡
# │ Perl core of kaktree plugin   │
# ╞═══════════════════════════════╡
# │ GitLab.com/andreyorst/kaktree │
# ╰───────────────────────────────╯
use strict;
use warnings;

# This subroutine builds tree based on output of `ls' command. It recieves
# current indentation level, and constructs tree node based on it.
sub build_tree {
    my $path = $_[0];
    my $root = $_[1];
    my $open_node = $ENV{"kak_opt_kaktree_dir_icon_open"};
    my $closed_node = $ENV{"kak_opt_kaktree_dir_icon_close"};
    my $file_node = $ENV{"kak_opt_kaktree_file_icon"};
    my $indent = $ENV{"kak_opt_kaktree_indentation"};
    my $current_indent = $ENV{"kak_opt_kaktree__current_indent"};
    my $hidden = $ENV{"kak_opt_kaktree_show_hidden"};
    my $expanded_paths = $ENV{"kak_quoted_opt_kaktree__expanded_paths"} || '';
    my $sort = $ENV{"kak_opt_kaktree_sort"};
    my $indent_str;

    my $extra_indent = (defined $_[2]) ? $_[2] : 1;

    for my $i (1 .. ($indent * $extra_indent)) {
        $indent_str .= " ";
    }
    my $hidden_arg = ($hidden eq "true") ? "-A" : "";
    my $real_path;

    if (`uname -s` =~ /Darwin.*/) {
        $real_path = `realpath -m -- $path`;
    } else {
        $real_path = `readlink -m -- $path`;
    }

    chomp(my @input = `ls -lF $hidden_arg $real_path`);

    # remove first line containing `total ...'
    if ($input[0] =~ /total\s+\d+/){
        shift(@input);
    }

    my $input_size = scalar @input;

    if ($root ne "") {
        print "$current_indent$open_node $root\n";
    }

    if ($input_size > 0) {
        my @dir_nodes;
        my @file_nodes;
        foreach my $item (@input) {
            if ($item =~ /(?:[^\s]+\s+){8}(.*)\/$/) {
                my $dir = $1;
                if ($dir =~ /(.*)\s+->\s+.*/) {
                    $dir = $1;
                }
                push(@dir_nodes, $dir);
            } else {
                $item =~ /(?:[^\s]+\s+){8}(.*)$/;
                my $file = $1;
                if ($file =~ /(.*)\s+->\s+.*/) {
                    $file = $1;
                }
                push(@file_nodes, $file);
            }
        }

        if ((defined $sort) && ($sort eq "true")) {
            @dir_nodes = sort @dir_nodes;
            @file_nodes = sort @file_nodes;
        }

        foreach my $item (@dir_nodes) {
            my $item_path = "$path/$item";
            if ($expanded_paths =~ /'$item_path'/) {
                print "$current_indent$indent_str$open_node $item\n";
                build_tree($item_path, "", $extra_indent + 1)
            } else {
                print "$current_indent$indent_str$closed_node $item\n";
            }
        }

        foreach my $item (@file_nodes) {
            print "$current_indent$indent_str$file_node $item\n"
        }
    } else {
        print "$current_indent$indent_str<empty>\n"
    }
}

# Kaktree doesn't store paths of listed directories and path yet. So
# `make_path' subroutine works in opposite direction of `build_tree'.
# It builds path based on indentation in the tree buffer in order
# to get the location of currently expanded directory in the tree.
sub make_path {
    my $indent = $ENV{"kak_opt_kaktree_indentation"};
    my $current_indent = length($ENV{"kak_opt_kaktree__current_indent"});
    my $open = $ENV{"kak_opt_kaktree_dir_icon_open"};
    my $close = $ENV{"kak_opt_kaktree_dir_icon_close"};
    my $indent_str = "";

    $current_indent -= $indent;
    for my $i (1 .. $current_indent) {
        $indent_str .= " ";
    }

    chomp(my @input = <>);

    my @dirs;
    foreach my $line (reverse @input) {
        if ($line =~ /^$indent_str(\Q$open\E|\Q$close\E) (.*)/) {
            push(@dirs, $2);
            $current_indent -= $indent;
            $indent_str = "";
            for my $i (1 .. $current_indent) {
                $indent_str .= " ";
            }
        }
    }

    my $path = join("/", reverse @dirs);

    print "$path\n";
}

1; # this is needed to call sobroutines directly from this file
# kak: indentwidth=4:tabstop=4

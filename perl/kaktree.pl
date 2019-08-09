use strict;
use warnings;

# This subroutine builds tree based on output of `ls' command. It recieves
# current indentation level, and constructs tree node based on it.
sub build_tree {
    my $root = $_[0];
    my $open_node = $ENV{"kak_opt_kaktree_dir_icon_open"};
    my $closed_node = $ENV{"kak_opt_kaktree_dir_icon_close"};
    my $file_node = $ENV{"kak_opt_kaktree_file_icon"};
    my $indent = $ENV{"kak_opt_kaktree_indentation"};
    my $current_indent = $ENV{"kak_opt_kaktree__current_indent"};
    my $hidden = $ENV{"kak_opt_kaktree_show_hidden"};
    my $indent_str;

    for my $i (1 .. $indent) {
        $indent_str .= " ";
    }

    chomp(my @input = <>);

    # remove first line containing total ...
    shift(@input);

    my $input_size = scalar @input;

    print "$current_indent$open_node $root\n";

    if ($input_size > 0) {
        my @items = sort @input;
        my @files;

        foreach my $item (@items) {
            if ($item =~ /([^\s]+\s+){8}(.*)\/$/) {
                if ($2 =~ /(.*)\s+->\s+.*/) {
                    print "$current_indent$indent_str$closed_node $1\n";
                } else {
                    print "$current_indent$indent_str$closed_node $2\n";
                }
            } else {
                push(@files, $item);
            }
        }

        foreach my $file (@files) {
            $file =~ /([^\s]+\s+){8}(.*)$/;
            if ($2 =~ /(.*)\s+->\s+.*/) {
                print "$current_indent$indent_str$file_node $1\n";
            } else {
                print "$current_indent$indent_str$file_node $2\n";
            }
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

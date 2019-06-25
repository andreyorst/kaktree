use strict;
use warnings;

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

    if ($hidden eq "true") {
        # remove `./' and `../' from tree
        @input = grep {$_ ne "../"} @input;
        @input = grep {$_ ne "./"} @input;
    }

    my $input_size = scalar @input;

    print "$current_indent$open_node $root\n";

    if ($input_size > 0) {
        my @items = sort @input;
        my @files;

        foreach my $item (@items) {
            if ($item =~ /(.*)\/$/) {
                print "$current_indent$indent_str$closed_node $1\n";
            } else {
                push(@files, $item);
            }
        }

        foreach my $file (@files) {
            print "$current_indent$indent_str$file_node $file\n"
        }
    } else {
        print "$current_indent$indent_str<empty>\n"
    }
}

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

sub add_path {
    my $path = $ENV{"kaktree_path"};
    my $nodes = $ENV{"kak_opt_kaktree__nodes"};
    my $hit = 0;

    if (index($nodes, "'$path'") != -1) {
        # we do not add same path twice
        print "set-option global kaktree__nodes $nodes\n";
        return;
    }

    (my $base = $path) =~ s(/[^/]*?$)();
    my @nodes = split(/' '|^'|'$/, $ENV{"kak_opt_kaktree__nodes"});
    shift(@nodes);

    # search for the base of current path. E.g. if we
    # adding './a/b' we first look for `./a` in the list
    for my $i (0 .. scalar(@nodes) - 1) {
        if ($base eq $nodes[$i]) {
            $hit = 1;
            if ($i < scalar(@nodes)) {
                splice @nodes, $i + 1, 0, $path;
            } else {
                push @nodes, $path;
            }
            last;
        }
    }

    # if nothing found we add this to the end of the list.
    if ($hit == 0) {
        push @nodes, $path;
    }

    # and compose the entire thing back together
    $nodes = @nodes ? join ' ', map { qq!'$_'! } @nodes : '';
    print "set-option global kaktree__nodes $nodes\n";
}

sub remove_path {
    my $path = $ENV{"kaktree_path"};
    my $hit = 0;
    my @nodes = split(/' '|^'|'$/, $ENV{"kak_opt_kaktree__nodes"});
    shift(@nodes);
    @nodes = grep {$_ ne "$path"} @nodes;
    my $nodes = @nodes ? join ' ', map { qq!'$_'! } @nodes : '';
    print "set-option global kaktree__nodes $nodes\n";
}

1; # this is needed to call sobroutines directly from this file

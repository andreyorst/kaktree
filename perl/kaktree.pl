use strict;
use warnings;

my $root = $ENV{"kaktree_root"};
my $open_node = $ENV{"kak_opt_kaktree_dir_icon_open"};
my $closed_node = $ENV{"kak_opt_kaktree_dir_icon_close"};
my $file_node = $ENV{"kak_opt_kaktree_file_icon"};
my $indent = $ENV{"kak_opt_kaktree_indentation"};
my $current_indent = $ENV{"kak_opt_kaktree__current_indent"};
my $indent_str;

for my $i (1 .. $indent) {
    $indent_str .= " ";
}

my @input;
my @files;

chomp(@input = <>);

@input = sort @input;

print "$current_indent$open_node $root\n";

if ($#input > 0) {
    for my $i (0 .. $#input) {
        if ($input[$i] =~ /(.*)\/$/) {
            print "$current_indent$indent_str$closed_node $1\n";
        } else {
            push(@files, $input[$i]);
        }
    }

    foreach my $file (@files) {
        print "$current_indent$indent_str$file_node $file\n"
    }
} else {
        print "$current_indent$indent_str<empty>\n"
}

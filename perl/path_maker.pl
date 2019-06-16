use strict;
use warnings;

my $indent = $ENV{"kak_opt_kaktree_indentation"};
my $current_indent = length($ENV{"kak_opt_kaktree__current_indent"});
my $open = $ENV{"kak_opt_kaktree_dir_icon_open"};
my $close = $ENV{"kak_opt_kaktree_dir_icon_close"};
my $indent_str = "";

$current_indent -= $indent;
for my $i (1 .. $current_indent) {
    $indent_str .= " ";
}

my @input;
chomp(@input = <>);

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

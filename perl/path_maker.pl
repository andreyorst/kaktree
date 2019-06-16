use strict;
use warnings;

my $indent = $ENV{"kak_opt_filetree_indentation"};
my $current_indent = length($ENV{"kak_opt_filetree__current_indent"});
my $indent_str = "";

$current_indent -= $indent;
for my $i (1 .. $current_indent) {
    $indent_str .= " ";
}

my @input;
chomp(@input = <>);

my @dirs;
foreach my $line (reverse @input) {
    if ($line =~ /^$indent_str[-+] (.*)/) {
        push(@dirs, $1);
        $current_indent -= $indent;
        $indent_str = "";
        for my $i (1 .. $current_indent) {
            $indent_str .= " ";
        }
    }
}

my $path = join("/", reverse @dirs);

print "$path\n";

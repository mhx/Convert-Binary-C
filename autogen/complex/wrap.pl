$text = do { local $/; <> };
$text =~ s/\s+//g;
$text =~ s/(.{2,159}(?:[\[\],]|=>|$))/$1\n/g;
print $text;

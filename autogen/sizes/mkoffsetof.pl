use strict;

print <<'END';

@offset = (
END

while( <> ) {
  my($type,$member,$offset) = 
  printf "['%s','%s',%d],\n", /([^,]+),([^=]+)=(\d+)/;
}

print ");\n";

#include <stdio.h>

int errors = 0;

main(argc, argv)
     char** argv;
{
    argc--; argv++; /* skip the progam-name */

    if(argc == 0) {
	name_space_init();
	yyparse(); /* parse stdin */
    }
    else  /* parse all files named in the command-line */
      for(; argc; argc--, argv++) {

	  FILE* fp = freopen(*argv, "r", stdin);
	  
	  if(fp == 0) {
	      perror(*argv);
	      errors++;
	  }
	  else {
	      name_space_init();
	      yyparse();
	  }
	  
      }

    return -(errors);
}

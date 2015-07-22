extern char* malloc();

/* Malloc that complains and exits when memory is used up.
 */
char* emalloc(size)
     int size;
{
    static char msg[] = "C-parser out of memory\n";
    char* retval = malloc((unsigned)size);

    if(retval == 0) {
	/* fprintf might call malloc(), so... */
	write(2, msg, sizeof(msg));
	exit(-1);
    }
    return retval;
}

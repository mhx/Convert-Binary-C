# Makefile for ucpp
#
# (c) Thomas Pornin 1999, 2000
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 4. The name of the authors may not be used to endorse or promote
#    products derived from this software without specific prior written
#    permission.
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR 
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

.POSIX:

# ----- user configurable part -----

# Edit the variables to suit your system.
#
#   use -DAUDIT to enable some internal sanity checks
#   use -DMEM_CHECK to check the return value of malloc()
#      (superseded by AUDIT)
#   use -DMEM_DEBUG to enable memory leak research (warning: this
#      slows down ucpp a bit, and greatly increases memory consumption)
#   use -DINLINE=foobar to enable use of the 'foobar'
#      non standard qualifier, as an equivalent to the C99 'inline'
#      qualifier. See tune.h for details.
#
# Two FLAGS lines are given for each system type; chose the first one for
# debug, the second one for a fast binary.

# for a generic compiler called cc
#CC = cc
#FLAGS = -DAUDIT
#FLAGS = -O -DMEM_CHECK

# for Minix-86
#CC = cc
#LDFLAGS = -i
#FLAGS = -m -DAUDIT
#FLAGS = -O -m -DMEM_CHECK

# for gcc
CC = gcc
FLAGS = -g -Wall -ansi -pedantic -DAUDIT -DMEM_DEBUG
#FLAGS = -O3 -Wall -ansi -pedantic -DMEM_CHECK

# for the Compaq C compiler on Alpha/Linux
#CC = ccc
#FLAGS = -w0 -g -DAUDIT
#FLAGS = -w0 -fast -DMEM_CHECK

# for the Sun Workshop C Compiler
#CC = cc
#FLAGS = -g -Xa -DAUDIT
#FLAGS = -Xa -fast -DMEM_CHECK

# flags for the link step
LIBS =
#LIBS = libefence.a
#LIBS = -lgc_dbg

# ----- nothing should be changed below this line -----

COBJ = mem.o hash.o cpp.o lexer.o assert.o macro.o eval.o
CFLAGS = $(FLAGS) -DSTAND_ALONE

all: ucpp

clean:
	rm -f *.o ucpp core

ucpp: $(COBJ)
	$(CC) $(LDFLAGS) -o ucpp $(COBJ) $(LIBS)

cpp.o: cpp.h ucppi.h mem.h hash.h tune.h
lexer.o: cpp.h ucppi.h mem.h tune.h
assert.o: cpp.h ucppi.h mem.h hash.h tune.h
macro.o: cpp.h ucppi.h mem.h hash.h tune.h
hash.o: hash.h mem.h
mem.o: mem.h
eval.o: cpp.h ucppi.h tune.h mem.h

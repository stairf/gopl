# MAKEFILE

CC      := gcc
LD      := gcc
CFLAGS  := -std=c99 -Wall -g -O -I. -Wextra
LDFLAGS :=
GOPL    := ../getopt.pl
RM      := rm -rf
PERL    := /usr/bin/perl
SHELL   ?= /bin/sh

TESTDIR = ./
SCRIPTDIR = ./scripts

T_IN    := $(wildcard $(TESTDIR)/*.in)
T_BIN   := $(sort $(T_IN:%.in=%.bin))
T_SRC   := $(T_BIN:%.bin=%.c)
G_SRC   := $(T_SRC:%.c=%.gopl.c)
G_HDR   := $(T_SRC:%.c=%.gopl.h)
G_DEP   := $(T_SRC:%.c=%.gopl.d)
G_OBJ   := $(G_SRC:%.c=%.o)
T_OBJ   := $(T_SRC:%.c=%.o)
HDR     := $(sort $(G_HDR) $(wildcard $(TESTDIR)/*.h))
DEPS    := $(G_DEP)

T_RUN   := $(T_IN:%.in=%.run)

.PHONY: all clean gopl tests objects check $(T_RUN)
check: $(T_RUN)
all: $(T_BIN)
gopl: $(G_SRC) $(G_HDR)
objects: $(T_OBJ) $(G_OBJ)
tests: $(T_SRC)

clean:
	@echo "RM   ALL"
	@$(RM) $(T_BIN) $(T_OBJ) $(T_SRC) $(G_SRC) $(G_HDR) $(G_DEP) $(G_OBJ)


%.bin: %.o %.gopl.o
	@echo "LD   $@"
	@$(LD) $(LDFLAGS) -o $@ $^

%.o: %.c $(HDR)
	@echo "CC   $<"
	@$(CC) $(CFLAGS) -c -o $@ $<

%.gopl.c %.gopl.h %.gopl.d: %.go.pl $(GOPL)
	@echo "GOPL $*"
	@$(GOPL) -c $*.gopl.c -h $*.gopl.h -d $*.gopl.d $(<:%=./%)

$(T_SRC): %.c: %.go.pl
	@echo "GEN  $@"
	@$(PERL) $(SCRIPTDIR)/mktest.pl $(<:%=./%) $@

$(T_RUN): %.run: %.bin
	@echo "RUN  $*"
	@$(PERL) $(SCRIPTDIR)/runtest.pl ./$< $(<:%.bin=%.in)

cleangoals = $(filter clean%, $(MAKECMDGOALS))
buildgoals = $(filter-out clean%, $(MAKECMDGOALS))
# include dependency files only if required
ifeq "$(strip $(cleangoals))" ""
  -include $(DEPS)
else
  ifneq "$(strip $(buildgoals))" ""
    $(error "error: build and clean targets specified together")
  endif
endif

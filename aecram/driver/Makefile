# Build: make -C <kernel dir> M=$PWD

MODULE = aecram

obj-m := $(MODULE).o
$(MODULE)-y := driver.o
ccflags-y := -I../include

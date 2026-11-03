ROOT := ../..
BUILD_DIR := $(ROOT)/build
CC ?= cc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Werror
TARGET := $(BUILD_DIR)/c_example

.PHONY: all run clean

all: $(TARGET)

$(TARGET): main.c $(ROOT)/include/flushtools.h $(BUILD_DIR)/libflushtools.so
	$(CC) $(CFLAGS) -I$(ROOT)/include main.c -L$(BUILD_DIR) -lflushtools \
		-Wl,-rpath,'$$ORIGIN' -o $(TARGET)

run: $(TARGET)
	LD_LIBRARY_PATH=$(BUILD_DIR):$$LD_LIBRARY_PATH $(TARGET)

clean:
	rm -f $(TARGET)

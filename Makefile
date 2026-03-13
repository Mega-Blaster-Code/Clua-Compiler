CC = gcc
LUA = C:/lua/lua.exe
FLAGS = -std=c11 -Wall -Wextra -O0 -g -Werror

CLUA_COMPILER = src/main.lua

CLUA_CODE = cluaCode
CLUA_C = cluaC
CLUA_OBJ = cluaObj

CLUA_SRC := $(wildcard $(CLUA_CODE)/*.clua)
C_FILES := $(patsubst $(CLUA_CODE)/%.clua,$(CLUA_C)/%.c,$(CLUA_SRC))
OBJ_FILES := $(patsubst $(CLUA_C)/%.c,$(CLUA_OBJ)/%.o,$(C_FILES))

TARGET = main

all: $(TARGET)

$(TARGET): $(OBJ_FILES)
	$(CC) $^ -o $@

$(CLUA_C)/%.c: $(CLUA_CODE)/%.clua
	@mkdir -p $(CLUA_C)
	$(LUA) $(CLUA_COMPILER) -f@$< -o@$@

$(CLUA_OBJ)/%.o: $(CLUA_C)/%.c
	@mkdir -p $(CLUA_OBJ)
	$(CC) $(FLAGS) -c $< -o $@

clean:
	rm -f $(CLUA_OBJ)/*.o
	rm -f $(TARGET)
CC = gcc
LUA = C:/lua/lua.exe
FLAGS = -std=c11 -Wall -Wextra -O0 -g -Werror

TEST_DIR = test

INPUT_FILE = $(TEST_DIR)/code.clua
PREPROCESSOR_FILE = $(TEST_DIR)/preprocessor.clua
AST_FILE = $(TEST_DIR)/ast.txt
TOKENS_FILE = $(TEST_DIR)/tokens.clua
OUT_FILE = out.c
GEN_TARGET = c

LUA_FLAGS = -f@$(INPUT_FILE) -pp@$(PREPROCESSOR_FILE) -ast@$(AST_FILE) -tt@$(TOKENS_FILE) -o@$(OUT_FILE) -target@$(GEN_TARGET)

SRC_PATH = src
OBJ_PATH = obj
ASM_PATH = asm

SRC := $(wildcard $(SRC_PATH)/*.c)
OBJ := $(patsubst $(SRC_PATH)/%.c,$(OBJ_PATH)/%.o,$(SRC))
ASM := $(patsubst $(SRC_PATH)/%.c,$(ASM_PATH)/%.s,$(SRC))

TARGET = main

LUA_TARGET = $(SRC_PATH)/main.lua

all: $(TARGET)

lua:
	@$(LUA) $(LUA_TARGET) $(LUA_FLAGS) > $(OUT_FILE)

luaP:
	@$(LUA) $(LUA_TARGET) -SS $(LUA_FLAGS) > $(OUT_FILE)

asm: $(ASM)

$(ASM_PATH)/%.s: $(SRC_PATH)/%.c
	@mkdir -p $(ASM_PATH)
	@$(CC) $(FLAGS) -S $< -o $@

$(TARGET): $(OBJ)
	@$(CC) $^ -o $@

$(OBJ_PATH)/%.o: $(SRC_PATH)/%.c
	@$(CC) $(FLAGS) -c $< -o $@

clean:
	rm -f $(OBJ_PATH)/*.o $(TARGET) $(ASM_PATH)/*.s
CC = gcc
FLAGS = -std=c11 -Wall -Wextra -O0 -g

SRC_PATH = src
OBJ_PATH = obj

SRC := $(wildcard $(SRC_PATH)/*.c)
OBJ := $(patsubst $(SRC_PATH)/%.c,$(OBJ_PATH)/%.o,$(SRC))

TARGET = main

all: $(TARGET)

$(TARGET): $(OBJ)
	@$(CC) $^ -o $@

$(OBJ_PATH)/%.o: $(SRC_PATH)/%.c
	@$(CC) $(FLAGS) -c $< -o $@

clean:
	rm -rf $(OBJ_PATH)/*.o $(TARGET)
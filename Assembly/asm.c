/*
 * Simple assembler for the current G7 MIPS32 processor.
 *
 * Build: gcc -std=c11 -Wall -Wextra -Wpedantic asm.c -o asm
 * Run:   ./asm test.asm -o test.mem -l
 *
 * Pass 1 records instruction addresses and labels.
 * Pass 2 replaces label references and encodes the instructions.
 * .org selects an aligned byte address. Gaps become NOPs.
 * Output is one 32-bit hexadecimal word per line, for $readmemh.
 */
#define _POSIX_C_SOURCE 200809L
#include <ctype.h>
#include <errno.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

enum { ROM_WORDS = 256, LINE_SIZE = 512, LABEL_SIZE = 64, MAX_LABELS = 128 };

typedef struct {
    char name[LABEL_SIZE];
    uint32_t address;
} Label;

typedef struct {
    char text[LINE_SIZE];
    uint32_t address;
    unsigned line;
} Instruction;

typedef struct {
    Label labels[MAX_LABELS];
    size_t label_count;
    Instruction instructions[ROM_WORDS];
    size_t instruction_count;
    uint32_t words[ROM_WORDS];
    size_t word_count;
} Program;

typedef enum {
    REGISTERS, SHIFT, JUMP_REGISTER, JUMP_LINK_REGISTER, SWAP_BYTES,
    IMMEDIATE, UPPER_IMMEDIATE, MEMORY, BRANCH_TWO, BRANCH_ONE, JUMP, NOP
} Format;

typedef struct {
    const char *name;
    Format format;
    unsigned operands;
    uint32_t opcode;
    uint32_t function;
} InstructionDefinition;

/* Operand order is the same as in Assembly/test.asm. */
static const InstructionDefinition instruction_set[] = {
    {"add",  REGISTERS,         3, 0x00, 0x20},
    {"sub",  REGISTERS,         3, 0x00, 0x22},
    {"and",  REGISTERS,         3, 0x00, 0x24},
    {"or",   REGISTERS,         3, 0x00, 0x25},
    {"xor",  REGISTERS,         3, 0x00, 0x26},
    {"slt",  REGISTERS,         3, 0x00, 0x2A},
    {"sll",  SHIFT,             3, 0x00, 0x00},
    {"srl",  SHIFT,             3, 0x00, 0x02},
    {"rotr", SHIFT,             3, 0x00, 0x02},
    {"jr",   JUMP_REGISTER,     1, 0x00, 0x08},
    {"jalr", JUMP_LINK_REGISTER, 2, 0x00, 0x09},
    {"wsbh", SWAP_BYTES,        2, 0x1F, 0x20},
    {"addi", IMMEDIATE,         3, 0x08, 0x00},
    {"lui",  UPPER_IMMEDIATE,   2, 0x0F, 0x00},
    {"lw",   MEMORY,            2, 0x23, 0x00},
    {"sw",   MEMORY,            2, 0x2B, 0x00},
    {"beq",  BRANCH_TWO,        3, 0x04, 0x00},
    {"bne",  BRANCH_TWO,        3, 0x05, 0x00},
    {"bltz", BRANCH_ONE,        2, 0x01, 0x00},
    {"bgez", BRANCH_ONE,        2, 0x01, 0x00},
    {"blez", BRANCH_ONE,        2, 0x06, 0x00},
    {"bgtz", BRANCH_ONE,        2, 0x07, 0x00},
    {"j",    JUMP,             1, 0x02, 0x00},
    {"jal",  JUMP,             1, 0x03, 0x00},
    {"nop",  NOP,              0, 0x00, 0x00}
};

static const char *input_path;
static unsigned current_line;

static _Noreturn void fail(const char *message, ...)
{
    va_list arguments;
    fprintf(stderr, "%s:%u: ", input_path, current_line);
    va_start(arguments, message);
    vfprintf(stderr, message, arguments);
    va_end(arguments);
    fputc('\n', stderr);
    exit(EXIT_FAILURE);
}

static char *trim(char *text)
{
    while (isspace((unsigned char)*text))
        text++;
    size_t length = strlen(text);
    while (length > 0 && isspace((unsigned char)text[length - 1]))
        text[--length] = '\0';
    return text;
}

static int valid_label(const char *name)
{
    if (!isalpha((unsigned char)*name) && *name != '_')
        return 0;
    for (const char *p = name + 1; *p; p++) {
        if (!isalnum((unsigned char)*p) && *p != '_')
            return 0;
    }
    return 1;
}

static const Label *find_label(const Program *program, const char *name)
{
    for (size_t i = 0; i < program->label_count; i++) {
        if (strcmp(program->labels[i].name, name) == 0)
            return &program->labels[i];
    }
    return NULL;
}

static int64_t number(const char *text)
{
    char *end;
    const char *digits = text;
    if (*digits == '+' || *digits == '-')
        digits++;
    int base = 10;
    if (digits[0] == '0' && (digits[1] == 'x' || digits[1] == 'X'))
        base = 16;
    errno = 0;
    long long value = strtoll(text, &end, base);
    if (errno == ERANGE || end == text || *end != '\0')
        fail("expected a decimal or hexadecimal number, got '%s'", text);
    return value;
}

/* Read the source once and assign byte addresses to instructions and labels. */
static void first_pass(FILE *source, Program *program)
{
    char buffer[LINE_SIZE];
    uint32_t address = 0;

    while (fgets(buffer, sizeof buffer, source)) {
        current_line++;
        if (!strchr(buffer, '\n') && strlen(buffer) == sizeof buffer - 1)
            fail("source line is too long (maximum %d characters)", LINE_SIZE - 2);

        buffer[strcspn(buffer, "#;")] = '\0';
        char *text = trim(buffer);
        char *colon;
        while ((colon = strchr(text, ':')) != NULL) {
            *colon = '\0';
            char *name = trim(text);
            if (!valid_label(name) || strlen(name) >= LABEL_SIZE)
                fail("invalid or too-long label '%s'", name);
            if (find_label(program, name))
                fail("duplicate label '%s'", name);
            if (program->label_count == MAX_LABELS)
                fail("too many labels (maximum %d)", MAX_LABELS);
            Label *label = &program->labels[program->label_count++];
            strcpy(label->name, name);
            label->address = address;
            text = trim(colon + 1);
        }
        if (*text == '\0')
            continue;

        if (strncmp(text, ".org", 4) == 0 &&
            (text[4] == '\0' || isspace((unsigned char)text[4]))) {
            int64_t origin = number(trim(text + 4));
            if (origin < address || origin >= ROM_WORDS * 4 || origin % 4 != 0)
                fail(".org must move forward to an aligned byte address in 0x00000000..0x000003FC");
            address = (uint32_t)origin;
            program->word_count = address / 4;
            continue;
        }

        if (address >= ROM_WORDS * 4)
            fail("program exceeds the current %d-word instruction ROM", ROM_WORDS);
        Instruction *instruction = &program->instructions[program->instruction_count++];
        strcpy(instruction->text, text);
        instruction->address = address;
        instruction->line = current_line;
        address += 4;
        program->word_count = address / 4;
    }
    if (ferror(source))
        fail("could not read source file");
    if (program->instruction_count == 0)
        fail("source contains no instructions");
}

static uint32_t register_number(const char *text)
{
    static const char *names[] = {
        "zero", "at", "v0", "v1", "a0", "a1", "a2", "a3",
        "t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7",
        "s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7",
        "t8", "t9", "k0", "k1", "gp", "sp", "fp", "ra"
    };
    if (*text != '$')
        fail("register must start with '$', got '%s'", text);
    text++;
    char name[LABEL_SIZE];
    size_t length = strlen(text);
    if (length >= sizeof name)
        fail("register name is too long");
    for (size_t i = 0; i <= length; i++)
        name[i] = (char)tolower((unsigned char)text[i]);
    for (uint32_t i = 0; i < 32; i++) {
        if (strcmp(name, names[i]) == 0)
            return i;
    }
    if (length > 0 && strspn(name, "0123456789") == length) {
        int64_t value = number(name);
        if (value >= 0 && value <= 31)
            return (uint32_t)value;
    }
    fail("unknown register '$%s'", text);
}

/* Permit signed immediates and raw 16-bit patterns, such as 0xFFFF for -1. */
static uint32_t immediate16(const char *text)
{
    int64_t value = number(text);
    if (value < -32768 || value > 65535)
        fail("immediate '%s' does not fit in 16 bits", text);
    return (uint32_t)value & 0xFFFF;
}

static int64_t target(const Program *program, const char *text, uint32_t pc,
                      int relative)
{
    const Label *label = find_label(program, text);
    if (label) {
        if (label->address >= ROM_WORDS * 4)
            fail("target label '%s' is outside the instruction ROM", text);
        if (relative)
            return ((int64_t)label->address - (pc + 4)) / 4;
        return label->address;
    }
    if (valid_label(text))
        fail("undefined label '%s'", text);
    return number(text);
}

static uint32_t encode(const Program *program, const Instruction *instruction)
{
    char buffer[LINE_SIZE];
    strcpy(buffer, instruction->text);
    char *mnemonic = buffer;
    char *rest = buffer;
    while (*rest && !isspace((unsigned char)*rest)) {
        *rest = (char)tolower((unsigned char)*rest);
        rest++;
    }
    if (*rest)
        *rest++ = '\0';
    rest = trim(rest);

    const InstructionDefinition *definition = NULL;
    for (size_t i = 0; i < sizeof instruction_set / sizeof instruction_set[0]; i++) {
        if (strcmp(mnemonic, instruction_set[i].name) == 0) {
            definition = &instruction_set[i];
            break;
        }
    }
    if (!definition)
        fail("unknown instruction '%s'", mnemonic);

    char *operands[3];
    unsigned count = 0;
    while (*rest) {
        if (count == 3)
            fail("too many operands for '%s'", mnemonic);
        char *comma = strchr(rest, ',');
        if (comma)
            *comma = '\0';
        operands[count++] = trim(rest);
        if (*operands[count - 1] == '\0')
            fail("empty operand in '%s'", mnemonic);
        if (!comma)
            break;
        rest = trim(comma + 1);
        if (*rest == '\0')
            fail("missing operand after comma");
    }
    if (count != definition->operands)
        fail("'%s' needs %u operands, got %u", mnemonic, definition->operands, count);

    uint32_t rs = 0, rt = 0, rd = 0, shamt = 0, immediate = 0;
    switch (definition->format) {
    case REGISTERS:
        rd = register_number(operands[0]);
        rs = register_number(operands[1]);
        rt = register_number(operands[2]);
        break;
    case SHIFT: {
        rd = register_number(operands[0]);
        rt = register_number(operands[1]);
        int64_t amount = number(operands[2]);
        if (amount < 0 || amount > 31)
            fail("shift amount must be in 0..31");
        shamt = (uint32_t)amount;
        rs = strcmp(mnemonic, "rotr") == 0 ? 1 : 0;
        break;
    }
    case JUMP_REGISTER:
        rs = register_number(operands[0]);
        break;
    case JUMP_LINK_REGISTER:
        rd = register_number(operands[0]);
        rs = register_number(operands[1]);
        break;
    case SWAP_BYTES:
        rd = register_number(operands[0]);
        rt = register_number(operands[1]);
        shamt = 2;
        break;
    case IMMEDIATE:
        rt = register_number(operands[0]);
        rs = register_number(operands[1]);
        immediate = immediate16(operands[2]);
        break;
    case UPPER_IMMEDIATE:
        rt = register_number(operands[0]);
        immediate = immediate16(operands[1]);
        break;
    case MEMORY: {
        rt = register_number(operands[0]);
        char *open = strchr(operands[1], '(');
        char *close = strchr(operands[1], ')');
        if (!open || !close || close <= open || close[1] != '\0')
            fail("memory operand must be offset($register)");
        *open = '\0';
        *close = '\0';
        char *offset = trim(operands[1]);
        immediate = *offset ? immediate16(offset) : 0;
        rs = register_number(trim(open + 1));
        break;
    }
    case BRANCH_TWO:
    case BRANCH_ONE: {
        rs = register_number(operands[0]);
        if (definition->format == BRANCH_TWO)
            rt = register_number(operands[1]);
        else
            rt = strcmp(mnemonic, "bgez") == 0 ? 1 : 0;
        int64_t offset = target(program, operands[count - 1], instruction->address, 1);
        if (offset < -32768 || offset > 32767)
            fail("branch offset must be in -32768..32767 words");
        immediate = (uint32_t)offset & 0xFFFF;
        break;
    }
    case JUMP: {
        int64_t address = target(program, operands[0], instruction->address, 0);
        if (address < 0 || address >= ROM_WORDS * 4 || address % 4 != 0)
            fail("jump target must be an aligned byte address in 0x00000000..0x000003FC");
        return (definition->opcode << 26) | ((uint32_t)address >> 2);
    }
    case NOP:
        return 0;
    }

    return (definition->opcode << 26) | (rs << 21) | (rt << 16) |
           (rd << 11) | (shamt << 6) | definition->function | immediate;
}

/* Complete assembly before replacing the output, so errors preserve old images. */
static void write_image(const char *path, const Program *program)
{
    char *temporary = malloc(strlen(path) + sizeof ".tmp.XXXXXX");
    if (!temporary)
        fail("out of memory");
    sprintf(temporary, "%s.tmp.XXXXXX", path);
    int descriptor = mkstemp(temporary);
    if (descriptor < 0)
        fail("cannot create output beside '%s': %s", path, strerror(errno));
    FILE *output = fdopen(descriptor, "w");
    if (!output) {
        int open_error = errno;
        close(descriptor);
        unlink(temporary);
        fail("cannot open temporary output: %s", strerror(open_error));
    }
    int failed = 0;
    for (size_t i = 0; i < program->word_count; i++) {
        if (fprintf(output, "%08" PRIX32 "\n", program->words[i]) < 0)
            failed = 1;
    }
    if (fclose(output) != 0)
        failed = 1;
    if (failed || rename(temporary, path) != 0) {
        unlink(temporary);
        fail("could not save output '%s'", path);
    }
    free(temporary);
}

int main(int argc, char **argv)
{
    const char *output_path = NULL;
    int listing = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            puts("Usage: asm input.asm [-o output.mem] [-l]");
            puts("G7 ISA, labels and .org byte addresses. Maximum image: 256 words (1 KiB).");
            return EXIT_SUCCESS;
        }
        if (strcmp(argv[i], "-l") == 0 || strcmp(argv[i], "--listing") == 0)
            listing = 1;
        else if (strcmp(argv[i], "-o") == 0 || strcmp(argv[i], "--output") == 0) {
            if (++i == argc) {
                fputs("Missing output filename after -o\n", stderr);
                return EXIT_FAILURE;
            }
            output_path = argv[i];
        } else if (argv[i][0] == '-' || input_path) {
            fprintf(stderr, "Unexpected argument '%s'\n", argv[i]);
            return EXIT_FAILURE;
        } else
            input_path = argv[i];
    }
    if (!input_path) {
        fputs("Usage: asm input.asm [-o output.mem] [-l]\n", stderr);
        return EXIT_FAILURE;
    }

    char *default_output = malloc(strlen(input_path) + sizeof ".mem");
    if (!default_output)
        fail("out of memory");
    strcpy(default_output, input_path);
    char *extension = strrchr(default_output, '.');
    char *slash = strrchr(default_output, '/');
    char *basename = slash ? slash + 1 : default_output;
    if (extension && extension > basename)
        *extension = '\0';
    strcat(default_output, ".mem");
    if (!output_path)
        output_path = default_output;
    if (strcmp(input_path, output_path) == 0)
        fail("input and output must have different names");

    FILE *source = fopen(input_path, "r");
    if (!source)
        fail("cannot open source: %s", strerror(errno));
    struct stat input_status, output_status;
    if (fstat(fileno(source), &input_status) == 0 &&
        stat(output_path, &output_status) == 0 &&
        input_status.st_dev == output_status.st_dev &&
        input_status.st_ino == output_status.st_ino)
        fail("input and output refer to the same file");

    Program program = {0};
    first_pass(source, &program);
    if (fclose(source) != 0)
        fail("could not close source file");

    if (listing)
        puts("Address   Word      Source");
    for (size_t i = 0; i < program.instruction_count; i++) {
        const Instruction *instruction = &program.instructions[i];
        current_line = instruction->line;
        uint32_t word = encode(&program, instruction);
        program.words[instruction->address / 4] = word;
        if (listing)
            printf("%08" PRIX32 "  %08" PRIX32 "  %s\n",
                   instruction->address, word, instruction->text);
    }
    write_image(output_path, &program);
    printf("Wrote %zu instructions in %zu ROM words to %s\n",
           program.instruction_count, program.word_count, output_path);
    free(default_output);
    return EXIT_SUCCESS;
}

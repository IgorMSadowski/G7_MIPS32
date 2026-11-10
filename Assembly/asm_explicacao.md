# Assembler do G7 MIPS32 em C

O assembler lê um ficheiro `.asm` e produz uma imagem `.mem` com uma palavra de
32 bits em hexadecimal por linha. A primeira passagem atribui endereços às
instruções e aos labels. A segunda codifica as instruções.

Na pasta principal do projeto, podes compilar e montar o programa de teste com
estes comandos. A opção `-l` mostra o endereço, a palavra hexadecimal e a
instrução original.

```bash
gcc -std=c11 -Wall -Wextra -Wpedantic Assembly/asm.c -o /tmp/g7-asm
/tmp/g7-asm Assembly/test.asm -o /tmp/g7-test.mem -l
```

## Bibliotecas e configuração

As notas acima de cada `#include` explicam quais as funções e os tipos usados pelo assembler.

```c
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
// Pede as declarações POSIX.1-2008 à biblioteca do sistema. Tem de aparecer
// antes dos includes para expor funções como mkstemp, fdopen e fileno.
#define _POSIX_C_SOURCE 200809L
// <ctype.h> classifica e converte caracteres. isspace reconhece espaços e
// mudanças de linha, isalpha reconhece letras, isalnum aceita letras ou
// dígitos e tolower converte uma letra para minúscula.
#include <ctype.h>
// <errno.h> fornece errno e ERANGE. O código usa errno para detetar ou
// descrever erros do sistema. ERANGE indica que um número saiu do intervalo.
#include <errno.h>
// <inttypes.h> fornece PRIX32 para imprimir um uint32_t em hexadecimal
// maiúsculo com o formato adequado ao tipo usado pelo compilador.
#include <inttypes.h>
// <stdarg.h> fornece va_list, va_start e va_end. Permitem que fail receba
// uma mensagem e uma quantidade variável de valores para formatar.
#include <stdarg.h>
// <stdint.h> fornece uint32_t, inteiro de 32 bits sem sinal, e int64_t,
// inteiro de 64 bits com sinal para ler valores e calcular offsets.
#include <stdint.h>
// <stdio.h> fornece FILE e as funções que abrem, leem, escrevem e fecham
// ficheiros. Inclui fprintf, fgets e fclose. No ambiente POSIX também
// declara fdopen e fileno. rename muda o nome ou substitui um ficheiro.
#include <stdio.h>
// <stdlib.h> fornece malloc e free para gerir memória, strtoll para
// converter números e exit para terminar. Em POSIX declara mkstemp.
#include <stdlib.h>
// <string.h> fornece funções para medir, pesquisar, copiar e comparar
// strings, além de strerror para traduzir um código de erro em texto.
#include <string.h>
// <sys/stat.h> fornece struct stat, stat e fstat. O assembler compara
// a identidade da entrada e da saída para evitar substituir o .asm.
#include <sys/stat.h>
// <unistd.h> declara close e unlink. O código usa close para fechar um
// descritor e unlink para retirar um ficheiro temporário após um erro.
#include <unistd.h>
```

## Limites e estruturas de dados

A ROM tem 64 palavras. Cada instrução ocupa 4 bytes, por isso o último endereço alinhado é 0xFC. Os restantes limites reservam espaço para ler uma linha, guardar um nome e registar até 128 labels.

```c
enum { ROM_WORDS = 64, LINE_SIZE = 512, LABEL_SIZE = 64, MAX_LABELS = 128 };

// Um Label associa um nome a um endereço em bytes. Um label como rotina:
// assinala uma posição no programa sem ocupar uma palavra na ROM.
typedef struct {
    char name[LABEL_SIZE];
    uint32_t address;
} Label;

// Uma Instruction guarda o texto, o endereço e o número da linha no .asm.
// O número de linha permite localizar o erro durante a codificação.
typedef struct {
    char text[LINE_SIZE];
    uint32_t address;
    unsigned line;
} Instruction;

// Program reúne a tabela de labels, o texto das instruções e a imagem
// final da ROM. instruction_count conta instruções reais. word_count
// inclui também as posições preenchidas com NOPs por causa de .org.
typedef struct {
    Label labels[MAX_LABELS];
    size_t label_count;
    Instruction instructions[ROM_WORDS];
    size_t instruction_count;
    uint32_t words[ROM_WORDS];
    size_t word_count;
} Program;

// Cada valor de Format diz ao codificador como ler os operandos. ADD
// usa REGISTERS, LW e SW usam MEMORY e J e JAL usam JUMP.
typedef enum {
    REGISTERS, SHIFT, JUMP_REGISTER, JUMP_LINK_REGISTER, SWAP_BYTES,
    IMMEDIATE, UPPER_IMMEDIATE, MEMORY, BRANCH_TWO, BRANCH_ONE, JUMP, NOP
} Format;

// Cada entrada da tabela indica o nome, o formato, a quantidade de
// operandos, o opcode e o campo funct. opcode ocupa os bits 31 a 26.
// Nas instruções que usam funct, este ocupa os bits 5 a 0.
typedef struct {
    const char *name;
    Format format;
    unsigned operands;
    uint32_t opcode;
    uint32_t function;
} InstructionDefinition;

// Tabela de instruções aceites pelo G7. A linha de ADD, por exemplo,
// pede três operandos e define opcode 0x00 e funct 0x20. SRL e ROTR
// partilham o funct 0x02. Mais abaixo, o codificador usa rs para os
// distinguir. BLTZ e BGEZ partilham opcode e distinguem-se pelo campo rt.
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

// input_path e current_line permitem a fail indicar o ficheiro e a linha.
// static limita estes nomes a asm.c. A inicialização é implícita a zero.
static const char *input_path;
static unsigned current_line;
```

## Mensagens de erro

fail imprime o caminho, o número da linha e a causa em stderr. Depois termina o processo com falha. _Noreturn descreve esse comportamento. Os três pontos em ... permitem valores adicionais para os formatos.

```c
static _Noreturn void fail(const char *message, ...)
{
    va_list arguments;
    fprintf(stderr, "%s:%u: ", input_path, current_line);
    // va_start prepara os argumentos após message. vfprintf escreve a
    // mensagem com esses valores, e va_end termina o acesso à lista.
    va_start(arguments, message);
    vfprintf(stderr, message, arguments);
    va_end(arguments);
    fputc('\n', stderr);
    exit(EXIT_FAILURE);
}
```

## Espaços no início e no fim

trim devolve um ponteiro para o primeiro carácter útil. Para retirar o espaço final, escreve o terminador '\0' dentro do próprio buffer. Em C, uma string acaba nesse carácter. O cast para unsigned char dá a isspace um valor válido mesmo com bytes acima de 127.

```c
static char *trim(char *text)
{
    while (isspace((unsigned char)*text))
        text++;
    size_t length = strlen(text);
    while (length > 0 && isspace((unsigned char)text[length - 1]))
        // --length diminui o comprimento antes de usar o índice.
        text[--length] = '\0';
    return text;
}
```

## Validação de labels

O primeiro carácter pode ser uma letra ou underscore. Os restantes também podem ser dígitos. O ciclo para quando *p chega a '\0'.

```c
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
```

## Pesquisa de labels

Percorre apenas as posições ocupadas. strcmp devolve 0 para nomes iguais. & obtém o endereço do elemento encontrado. NULL indica que a pesquisa chegou ao fim sem encontrar o nome.

```c
static const Label *find_label(const Program *program, const char *name)
{
    for (size_t i = 0; i < program->label_count; i++) {
        if (strcmp(program->labels[i].name, name) == 0)
            return &program->labels[i];
    }
    return NULL;
}
```

## Conversão de números

number lê um valor decimal ou hexadecimal, com sinal opcional. Escolhe a base pela presença do prefixo 0x ou 0X depois do sinal. A conversão recebe o texto original para preservar o sinal.

```c
static int64_t number(const char *text)
{
    char *end;
    const char *digits = text;
    if (*digits == '+' || *digits == '-')
        digits++;
    int base = 10;
    if (digits[0] == '0' && (digits[1] == 'x' || digits[1] == 'X'))
        base = 16;
    // Limpa errno antes de strtoll. &end permite à função indicar onde
    // parou. A condição seguinte recusa um valor fora do intervalo,
    // uma conversão vazia e texto que ficou por ler depois do número.
    errno = 0;
    long long value = strtoll(text, &end, base);
    if (errno == ERANGE || end == text || *end != '\0')
        fail("expected a decimal or hexadecimal number, got '%s'", text);
    return value;
}
```

## Primeira passagem e diretiva `.org`

Lê o .asm e guarda os labels e as instruções com os respetivos endereços de byte. Cada instrução faz avançar quatro bytes.

```c
/* Read the source once and assign byte addresses to instructions and labels. */
static void first_pass(FILE *source, Program *program)
{
    char buffer[LINE_SIZE];
    uint32_t address = 0;

    // fgets lê para o buffer e inclui o '\n' quando há espaço. Se encher
    // o buffer antes desse carácter, o programa recusa a linha comprida.
    while (fgets(buffer, sizeof buffer, source)) {
        current_line++;
        if (!strchr(buffer, '\n') && strlen(buffer) == sizeof buffer - 1)
            fail("source line is too long (maximum %d characters)", LINE_SIZE - 2);

        // strcspn encontra a primeira posição de # ou de ponto e vírgula.
        // Escrever '\0' nessa posição corta o comentário. Quando não encontra
        // nenhum separador, devolve o comprimento da string.
        buffer[strcspn(buffer, "#;")] = '\0';
        char *text = trim(buffer);
        char *colon;
        // strchr encontra o primeiro ':' e devolve um ponteiro para ele.
        // Trocar ':' por '\0' isola o nome. O código valida o nome e regista
        // o endereço atual. Pode haver vários labels antes de uma instrução.
        while ((colon = strchr(text, ':')) != NULL) {
            *colon = '\0';
            char *name = trim(text);
            if (!valid_label(name) || strlen(name) >= LABEL_SIZE)
                fail("invalid or too-long label '%s'", name);
            if (find_label(program, name))
                fail("duplicate label '%s'", name);
            if (program->label_count == MAX_LABELS)
                fail("too many labels (maximum %d)", MAX_LABELS);
            // O pós-incremento usa primeiro a posição livre e depois aumenta
            // label_count. strcpy copia a string inteira, incluindo '\0'.
            Label *label = &program->labels[program->label_count++];
            strcpy(label->name, name);
            label->address = address;
            text = trim(colon + 1);
        }
        if (*text == '\0')
            continue;

        // .org altera o endereço da próxima instrução. strncmp compara quatro
        // caracteres e o teste seguinte confirma o fim do nome da diretiva.
        // O novo endereço tem de estar alinhado, caber na ROM e ser igual ou
        // posterior ao atual. As posições saltadas ficam com palavras zero.
        if (strncmp(text, ".org", 4) == 0 &&
            (text[4] == '\0' || isspace((unsigned char)text[4]))) {
            int64_t origin = number(trim(text + 4));
            if (origin < address || origin >= ROM_WORDS * 4 || origin % 4 != 0)
                fail(".org must move forward to an aligned byte address in 0x00..0xFC");
            address = (uint32_t)origin;
            program->word_count = address / 4;
            continue;
        }

        // Uma instrução ocupa uma palavra. Guarda o texto e a linha para a
        // segunda passagem. address / 4 dá a quantidade de palavras até ao
        // endereço seguinte, incluindo os espaços reservados por .org.
        if (address >= ROM_WORDS * 4)
            fail("program exceeds the current %d-word instruction ROM", ROM_WORDS);
        Instruction *instruction = &program->instructions[program->instruction_count++];
        strcpy(instruction->text, text);
        instruction->address = address;
        instruction->line = current_line;
        address += 4;
        program->word_count = address / 4;
    }
    // ferror verifica se o ciclo acabou devido a um erro de leitura.
    if (ferror(source))
        fail("could not read source file");
    if (program->instruction_count == 0)
        fail("source contains no instructions");
}
```

## Números dos registos

Cada posição de names corresponde ao número de um registo. Por exemplo, $t0 tem índice 8, $zero tem índice 0 e $ra tem índice 31. A função exige '$', copia o nome em minúsculas e procura-o na tabela.

```c
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
    // strspn conta os caracteres iniciais que pertencem ao conjunto dado.
    // Se contar todos os caracteres, o nome só contém dígitos. Assim,
    // também podes escrever $8 para representar o mesmo registo que $t0.
    if (length > 0 && strspn(name, "0123456789") == length) {
        int64_t value = number(name);
        if (value >= 0 && value <= 31)
            return (uint32_t)value;
    }
    fail("unknown register '$%s'", text);
}
```

## Imediatos de 16 bits

Um imediato é um número escrito na própria instrução. Em `addi $t0, $zero, -1`, o campo de 16 bits guarda `FFFF`.

```c
// Preparar um imediato de 16 bits
// A função aceita -32768 a 65535 para permitir tanto valores com
// sinal como padrões brutos de 16 bits. & 0xFFFF guarda apenas os
// 16 bits inferiores. Por exemplo, -1 e 0xFFFF dão o mesmo campo.
/* Permit signed immediates and raw 16-bit patterns, such as 0xFFFF for -1. */
static uint32_t immediate16(const char *text)
{
    int64_t value = number(text);
    if (value < -32768 || value > 65535)
        fail("immediate '%s' does not fit in 16 bits", text);
    return (uint32_t)value & 0xFFFF;
}
```

## Destinos de branches e saltos

Se o operando for um label, consulta a tabela e obtém o endereço. Para branches, calcula (destino - (PC+4)) / 4, em palavras. Para J e JAL, devolve o endereço de byte. Um número escrito diretamente já representa o offset no branch ou o endereço no salto.

```c
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
```

## Codificação do mnemónico

A função trabalha numa cópia do texto. Converte o nome para minúsculas, separa-o dos operandos e procura a definição na tabela.

```c
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
        // *rest++ escreve na posição atual e só depois avança o ponteiro.
        *rest++ = '\0';
    rest = trim(rest);

    const InstructionDefinition *definition = NULL;
    // sizeof da tabela dá o total de bytes. Dividir por sizeof de uma
    // entrada dá o número de instruções que é preciso percorrer.
    for (size_t i = 0; i < sizeof instruction_set / sizeof instruction_set[0]; i++) {
        if (strcmp(mnemonic, instruction_set[i].name) == 0) {
            definition = &instruction_set[i];
            break;
        }
    }
    if (!definition)
        fail("unknown instruction '%s'", mnemonic);
```

## Separação dos operandos

Cada vírgula é trocada por '\0', o que divide a string em partes. O código guarda até três ponteiros para essas partes e verifica que cada operando existe e que a quantidade corresponde à tabela.

```c
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
```

## Campos da instrução

Os campos começam a zero. O switch decide quais usar. rs, rt e rd guardam índices de registo quando o formato assim o define. shamt guarda a quantidade de deslocamento. Os formatos com imediato usam os 16 bits inferiores para esse valor.

```c
    uint32_t rs = 0, rt = 0, rd = 0, shamt = 0, immediate = 0;
    switch (definition->format) {
    // ADD, SUB, AND, OR, XOR e SLT usam a ordem rd, rs, rt no assembly.
    case REGISTERS:
        rd = register_number(operands[0]);
        rs = register_number(operands[1]);
        rt = register_number(operands[2]);
        break;
    // SLL, SRL e ROTR usam rd, rt, shamt. shamt tem cinco bits e pode
    // ir de 0 a 31. Para ROTR, rs recebe 1. Para SRL e SLL, recebe 0.
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
    // JR obtém o endereço de rs. JALR também codifica rd, onde o G7
    // guarda PC+4 para permitir o retorno.
    case JUMP_REGISTER:
        rs = register_number(operands[0]);
        break;
    case JUMP_LINK_REGISTER:
        rd = register_number(operands[0]);
        rs = register_number(operands[1]);
        break;
    // WSBH usa rd e rt, e o seu encoding exige shamt igual a 2.
    case SWAP_BYTES:
        rd = register_number(operands[0]);
        rt = register_number(operands[1]);
        shamt = 2;
        break;
    // ADDI lê rt, rs e o imediato. LUI lê rt e o imediato, com rs a zero.
    // Em LUI, o CPU coloca o imediato nos 16 bits superiores de rt.
    case IMMEDIATE:
        rt = register_number(operands[0]);
        rs = register_number(operands[1]);
        immediate = immediate16(operands[2]);
        break;
    case UPPER_IMMEDIATE:
        rt = register_number(operands[0]);
        immediate = immediate16(operands[1]);
        break;
    // LW e SW usam rt, offset(rs). O código separa o offset do registo
    // base pelos parênteses. Quando não há offset escrito, usa zero.
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
    // BEQ e BNE comparam dois registos. BLTZ, BGEZ, BLEZ e BGTZ
    // comparam rs com zero. BGEZ usa rt=1 no encoding para se
    // distinguir de BLTZ. O offset do branch tem 16 bits com sinal.
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
    // J e JAL codificam o endereço alinhado dividido por quatro.
    // Por exemplo, 0x80 >> 2 dá 0x20. Com o opcode de JAL nos
    // bits 31 a 26, a palavra gerada é 0x0C000020.
    case JUMP: {
        int64_t address = target(program, operands[0], instruction->address, 0);
        if (address < 0 || address >= ROM_WORDS * 4 || address % 4 != 0)
            fail("jump target must be an aligned byte address in 0x00..0xFC");
        return (definition->opcode << 26) | ((uint32_t)address >> 2);
    }
    // NOP tem o mesmo encoding que SLL $zero, $zero, 0.
    case NOP:
        return 0;
    }
```

## Montagem da palavra de 32 bits

`<<` move cada campo para a sua posição e `|` junta os campos. Em `add $t3, $t1, $t2`, temos `rd=11`, `rs=9`, `rt=10` e `funct=0x20`. A palavra gerada é `012A5820`.

```c
    return (definition->opcode << 26) | (rs << 21) | (rt << 16) |
           (rd << 11) | (shamt << 6) | definition->function | immediate;
}
```

## Escrita do ficheiro `.mem`

Só chega aqui depois de codificar todas as instruções. Escreve num ficheiro temporário e substitui o destino após fechar a escrita com sucesso. Assim, um erro não deixa uma imagem parcial.

```c
/* Complete assembly before replacing the output, so errors preserve old images. */
static void write_image(const char *path, const Program *program)
{
    // malloc reserva espaço para o nome. sizeof do sufixo inclui '\0'.
    // sprintf escreve o caminho com o sufixo no buffer.
    char *temporary = malloc(strlen(path) + sizeof ".tmp.XXXXXX");
    if (!temporary)
        fail("out of memory");
    sprintf(temporary, "%s.tmp.XXXXXX", path);
    // mkstemp substitui os X por caracteres únicos, cria o ficheiro
    // na pasta de destino e devolve o descritor, um identificador inteiro.
    int descriptor = mkstemp(temporary);
    if (descriptor < 0)
        fail("cannot create output beside '%s': %s", path, strerror(errno));
    // fdopen transforma o descritor num fluxo FILE para usar fprintf.
    // Se falhar, guarda errno antes de fechar o descritor com close
    // e remover o nome temporário com unlink.
    FILE *output = fdopen(descriptor, "w");
    if (!output) {
        int open_error = errno;
        close(descriptor);
        unlink(temporary);
        fail("cannot open temporary output: %s", strerror(open_error));
    }
    int failed = 0;
    // Escreve uma palavra por linha. %08 com PRIX32 formata o valor
    // em hexadecimal maiúsculo e preenche com zeros à esquerda.
    for (size_t i = 0; i < program->word_count; i++) {
        if (fprintf(output, "%08" PRIX32 "\n", program->words[i]) < 0)
            failed = 1;
    }
    // fclose também pode detetar erros ao escrever dados que estavam
    // em buffer. Se failed for verdadeiro, || evita chamar rename.
    // Se rename tiver sucesso, o temporário passa a ser o .mem final.
    if (fclose(output) != 0)
        failed = 1;
    if (failed || rename(temporary, path) != 0) {
        unlink(temporary);
        fail("could not save output '%s'", path);
    }
    free(temporary);
}
```

## Opções da linha de comandos

`argc` conta os argumentos, incluindo o nome do executável em `argv[0]`. `argv` guarda os textos. `-h` mostra ajuda, `-l` liga a listagem e `-o` indica o destino do ficheiro.

```c
int main(int argc, char **argv)
{
    const char *output_path = NULL;
    int listing = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            puts("Usage: asm input.asm [-o output.mem] [-l]");
            puts("G7 ISA, labels and .org byte addresses. Maximum image: 64 words.");
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
```

## Nome do ficheiro de saída

strrchr procura a última ocorrência do ponto e da barra. Se o ponto estiver no nome e marcar uma extensão, corta-a com '\0'. strcat acrescenta .mem. -o permite escolher outro caminho.

```c
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
```

## Abertura do ficheiro de entrada

fopen abre a entrada em modo de leitura. fileno obtém o descritor dessa entrada. fstat consulta-o e stat consulta o caminho de saída. O par dispositivo e inode identifica o ficheiro. A comparação deteta caminhos diferentes que apontam para a mesma entrada.

```c
    FILE *source = fopen(input_path, "r");
    if (!source)
        fail("cannot open source: %s", strerror(errno));
    struct stat input_status, output_status;
    if (fstat(fileno(source), &input_status) == 0 &&
        stat(output_path, &output_status) == 0 &&
        input_status.st_dev == output_status.st_dev &&
        input_status.st_ino == output_status.st_ino)
        fail("input and output refer to the same file");
```

## Execução das duas passagens

Program program = {0} começa com as contagens e as palavras a zero. first_pass preenche a tabela de labels e a lista de instruções. A seguir, o ficheiro .asm pode ser fechado.

```c
    Program program = {0};
    first_pass(source, &program);
    if (fclose(source) != 0)
        fail("could not close source file");

    if (listing)
        puts("Address   Word      Source");
    // Na segunda passagem, encode traduz cada instrução. O resultado
    // vai para words[endereço / 4]. Por exemplo, o endereço 0x0C
    // vai para words[3], que corresponde à quarta linha do .mem.
    // Se -l foi pedido, a listagem também mostra o texto da instrução.
    for (size_t i = 0; i < program.instruction_count; i++) {
        const Instruction *instruction = &program.instructions[i];
        current_line = instruction->line;
        uint32_t word = encode(&program, instruction);
        program.words[instruction->address / 4] = word;
        if (listing)
            printf("%08" PRIX32 "  %08" PRIX32 "  %s\n",
                   instruction->address, word, instruction->text);
    }
    // Grava o .mem, mostra quantas instruções e palavras foram geradas,
    // liberta a memória do nome por defeito e termina com sucesso.
    write_image(output_path, &program);
    printf("Wrote %zu instructions in %zu ROM words to %s\n",
           program.instruction_count, program.word_count, output_path);
    free(default_output);
    return EXIT_SUCCESS;
}
```

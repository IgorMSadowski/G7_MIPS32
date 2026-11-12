# Testbenches do G7 MIPS32

## Base atual

O CPU está ligado diretamente à ROM e à RAM. A ROM carrega
[Assembly/test.mem](../Assembly/test.mem). Durante o stall de `LW`, o PC
e a ROM conservam a instrução. O CPU grava o dado da RAM e avança no
flanco de conclusão. A saída LD0 mostra o reset físico.

## Testes incluídos

| Testbench | Simulation Set | O que verifica |
| --- | --- | --- |
| `tb_alu` | `alu` | Operações aritméticas e lógicas, shifts, rotação e sinal zero. |
| `tb_bdu` | `bdu` | Condições de branch, casos com sinal e códigos sem condição associada. |
| `tb_control_unit` | `control_unit` | Descodificação de instruções suportadas e rejeição de encodings inválidos. |
| `tb_regfile` | `regfile` | Reset, leitura simultânea nas duas portas, escrita, proteção do registo zero e escritas consecutivas. |
| `tb_primitives` | `component_tests` | `mux2_32bit`, `mux2_5bit`, `sign_extend` e `shift_left_two`. |
| `tb_memories` | `component_tests` | Latência, enable e reset da ROM, escrita read-first, leitura e pausa da RAM; capacidade de 1 KiB e independência dos endereços 0x000, 0x100 e 0x3FC. |
| `tb_cpu_memory` | `cpu_memory` | CPU e datapath com RAM, loads e stores, pausa e retoma, branches, reset e instruções inválidas. |
| `tb_soc` | `soc` | Execução do programa completo a partir da ROM, hold do PC e da instrução durante o load e resultados dos registos. |

## Regressão comportamental no Vivado

1. Abre `G7_MIPS32.xpr` no Vivado.
2. Guarda o projeto e fecha qualquer simulação ativa.
3. Executa o comando na consola Tcl do Vivado.

~~~tcl
source {/home/igor/Documents/Vivado_Projects/G7_MIPS32/run_regression.tcl}
~~~

O [script de regressão](../run_regression.tcl) executa os oito testbenches.
Se alguma verificação falhar, o resumo identifica o teste e o script
termina com erro.

## Executar e observar um teste individual

No Flow Navigator, seleciona **Simulation → Run Simulation → Run
Behavioral Simulation**. Antes de iniciar, escolhe o conjunto e o
testbench da tabela. Em `component_tests`, define o top como
`tb_primitives` ou `tb_memories`.

Na janela **Scopes**, expande o testbench. Na janela **Objects**, acrescenta
à waveform os sinais de texto disponíveis nesse teste, como `test_name`,
`condition_name`, `operation`, `memory_phase` ou `cpu_phase`. Sob
`dut`, podes ver os sinais internos do bloco testado. A consola Tcl
mostra as mensagens de resultado e os nomes das verificações que falham.

O XSim gera os executáveis e as waveforms dentro de `G7_MIPS32.sim`.
Os comandos Tcl para um teste individual estão nas [notas](notes.md).

## Endereçamento desta base

O software usa endereços alinhados de `0x00000000` a `0x000000FC` para
as 64 palavras da RAM. A ligação direta usa `i_addr[7:2]` como índice.
Os outros bits são ignorados, pelo que um acesso fora da faixa ou
desalinhado pode selecionar uma palavra existente.

O RTL e os testbenches usam caminhos absolutos para
[Assembly/test.mem](../Assembly/test.mem). Se moveres a pasta do projeto,
atualiza os parâmetros de inicialização da ROM.

## Imagem de teste da capacidade de memória

`tb_memories` utiliza `Assembly/memory_capacity.mem`, gerado pelo assembler C a partir de `Assembly/memory_capacity.asm`. A imagem tem 256 palavras e marcadores distintos em 0x000, 0x004, 0x100 e 0x3FC. O SoC continua a utilizar `Assembly/test.mem`.

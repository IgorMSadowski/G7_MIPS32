# Testbenches do G7 MIPS32

## Base atual

O CPU está ligado diretamente à ROM e à RAM. A ROM carrega
[Assembly/test.mem](../Assembly/test.mem). Durante o stall de `LW`, o PC
e a ROM conservam a instrução. O CPU grava o dado da RAM e avança no
flanco de conclusão. LD0 guarda se o último dado escrito pela CPU na RAM no
endereço zero era diferente de zero. O reset apaga o LED.

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
| `tb_soc` | `soc` | Demonstração simples para estudar a waveform: gera clock/reset e deixa o programa da ROM executar durante 5 us. Não faz verificações automáticas nem declara PASS. |
| `tb_soc_timing` | `soc_timing` (via `setup_soc_timing.tcl`) | Teste externo para RTL e simulação com atrasos: a CPU acende LD0 através de uma escrita na RAM; reset apaga e o programa reinicia. Não usa hierarquia RTL interna. |

## Regressão comportamental no Vivado

1. Abre `G7_MIPS32.xpr` no Vivado.
2. Guarda o projeto e fecha qualquer simulação ativa.
3. Executa o comando na consola Tcl do Vivado.

~~~tcl
source {/home/igor/Documents/Vivado_Projects/G7_MIPS32/run_regression.tcl}
~~~

O [script de regressão](../run_regression.tcl) executa os sete testbenches de
verificação automática dos módulos e da interface CPU/memória. A demonstração
`tb_soc` é observada manualmente na waveform, sem uma task de verificação.
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

`tb_soc` é intencionalmente simples: clock externo de 125 MHz, reset durante
200 ns e execução até 5 us. O clock interno de 50 MHz vem do Clock Wizard.
Usa **Run All** para chegar ao fim. `Current PC` na waveform é `_pc_r`;
`ROM address (look-ahead)` é o endereço apresentado à ROM e pode já indicar
a instrução seguinte no ciclo de conclusão.

Como a nova `tb_soc` só liga portas externas e não faz verificações hierárquicas,
também pode estimular uma netlist de timing. Nesse caso, observa primeiro
`clk`, `rst` e `led`; os caminhos internos da waveform RTL podem mudar depois
da síntese. `tb_soc_timing` continua a ser a alternativa que verifica o LED
automaticamente. A demonstração simples nunca declara um PASS de regressão.

O XSim gera os executáveis e as waveforms dentro de `G7_MIPS32.sim`.
Os comandos Tcl para um teste individual estão nas [notas](notes.md).

## Endereçamento desta base

O software usa endereços alinhados de `0x00000000` a `0x000003FC` para
as 256 palavras da RAM de 1 KiB. A ligação direta usa `i_addr[9:2]` como índice.
Os outros bits são ignorados, pelo que um acesso fora da faixa ou
desalinhado pode selecionar uma palavra existente.

O RTL e os testbenches usam caminhos absolutos para
[Assembly/test.mem](../Assembly/test.mem). Se moveres a pasta do projeto,
atualiza os parâmetros de inicialização da ROM.

## Imagem de teste da capacidade de memória

`tb_memories` utiliza `Assembly/memory_capacity.mem`, gerado pelo assembler C a partir de `Assembly/memory_capacity.asm`. A imagem tem 256 palavras e marcadores distintos em 0x000, 0x004, 0x100 e 0x3FC. O SoC continua a utilizar `Assembly/test.mem`.

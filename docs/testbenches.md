# Testbenches do G7 MIPS32

## Base atual

O CPU está ligado diretamente à ROM e à RAM. A ROM carrega
[Assembly/test.mem](../Assembly/test.mem). Durante o stall de `LW`, o PC
e a ROM conservam a instrução. O CPU grava o dado da RAM e avança no
flanco de conclusão. LD0 acompanha diretamente o botão de reset: `o_led[0] = i_rst`.
O pedido de reset é `reset_request = i_rst | ~clock_locked`. No `soc.v`, dois
flip-flops (`reset_stage1` e `reset_stage2`) ativam o reset imediatamente e
sincronizam a libertação com dois flancos de subida de `clk_50mhz`. A saída
`reset_stage2` é `soc_reset`, usado pelo CPU e pelas duas memórias. Ambos os
estágios têm o atributo `ASYNC_REG`. O Clock Wizard recebe diretamente `i_rst`.

## Testes incluídos

| Testbench | Simulation Set | O que verifica |
| --- | --- | --- |
| `tb_alu` | `alu` | Operações aritméticas e lógicas, shifts, rotação e sinais zero, negativo, carry de ADD e overflow de ADD/SUB. |
| `tb_bdu` | `bdu` | Condições de branch, casos com sinal e códigos sem condição associada. |
| `tb_control_unit` | `control_unit` | Descodificação de instruções suportadas e rejeição de encodings inválidos. |
| `tb_regfile` | `regfile` | Reset, leitura simultânea nas duas portas, escrita, proteção do registo zero e escritas consecutivas. |
| `tb_memories` | `component_tests` | 8 verificações básicas: reset das saídas, leituras da ROM, pausa/retoma da ROM, escrita/leitura de uma palavra da RAM e manutenção da saída com enable desativado. |
| `tb_cpu_memory` | `cpu_memory` | 8 verificações básicas: reset, ADDI, SW, espera de LW com PC/ROM parados, escrita do valor carregado e execução da instrução seguinte. |
| `tb_soc` | `soc` | Demonstração simples para estudar a waveform: gera clock/reset e deixa o programa da ROM executar durante 5 us. Não faz verificações automáticas nem declara PASS. |

## Regressão comportamental no Vivado

1. Abre `G7_MIPS32.xpr` no Vivado.
2. Guarda o projeto e fecha qualquer simulação ativa.
3. Executa o comando na consola Tcl do Vivado.

~~~tcl
source {/home/igor/Documents/Vivado_Projects/G7_MIPS32/run_regression.tcl}
~~~

O [script de regressão](../run_regression.tcl) executa os seis testbenches de
verificação automática dos módulos e da interface CPU/memória. A demonstração
`tb_soc` é observada manualmente na waveform, sem uma task de verificação.
Se alguma verificação falhar, o resumo identifica o teste e o script
termina com erro.

## Executar e observar um teste individual

No Flow Navigator, seleciona **Simulation → Run Simulation → Run
Behavioral Simulation**. Antes de iniciar, escolhe o conjunto e o
testbench da tabela. Em `component_tests`, o top atual é `tb_memories`.

Na janela **Scopes**, expande o testbench. Na janela **Objects**, acrescenta
à waveform os sinais de texto disponíveis nesse teste, como `test_name`,
`condition_name`, `operation`, `memory_phase` ou `cpu_phase`. Sob
`dut`, podes ver os sinais internos do bloco testado. A consola Tcl
mostra as mensagens de resultado e os nomes das verificações que falham.

`tb_soc` é intencionalmente simples: clock externo de 125 MHz, reset durante
25 flancos de subida (libertado a 196 ns) e execução até cerca de 5 us. O clock interno de 50 MHz vem do Clock Wizard.
Usa **Run All** para chegar ao fim. `Current PC` na waveform é `_pc_r`;
`ROM address (look-ahead)` é o endereço apresentado à ROM e pode já indicar
a instrução seguinte no ciclo de conclusão.

Como a nova `tb_soc` só liga portas externas e não faz verificações hierárquicas,
também pode estimular uma netlist de timing. Nesse caso, observa primeiro
`clk`, `rst` e `led`; os caminhos internos da waveform RTL podem mudar depois
da síntese. O LED só mostra reset; não verifica a execução do CPU.
Confirma na netlist que o CPU e as memórias foram preservados antes de atribuir
resultados de timing ao processador. A demonstração simples nunca declara um PASS
de regressão.

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

## Imagem simples para o teste das memórias

`tb_memories` utiliza [Assembly/memory_basic.mem](../Assembly/memory_basic.mem).
O ficheiro contém quatro palavras conhecidas, sem precisar de assembler:

| Endereço em bytes | Valor hexadecimal |
| --- | --- |
| 0x00 | 11111111 |
| 0x04 | 22222222 |
| 0x08 | 33333333 |
| 0x0C | 44444444 |

A ROM só lê estes valores; não existe CPU a executá-los neste teste.
A RAM recebe `12345678` no endereço zero e depois lê-o para comparação.
O teste básico não verifica toda a capacidade nem o comportamento read-first.
O clock é 50 MHz; as entradas são preparadas 1 ns após um flanco de subida
para captura no seguinte, e os resultados são observados 1 ns após a captura.
XSim: 8 verificações passaram, terminando a 331 ns.
O SoC continua a utilizar `Assembly/test.mem`.


## Teste simples CPU + RAM

`tb_cpu_memory` fornece diretamente quatro instruções ao CPU, sem ROM ou ficheiro `.mem`:

```assembly
# PC 0x00
addi $t0, $zero, 5  # t0 = 5
# PC 0x04
sw   $t0, 0($zero)  # RAM[0] = 5
# PC 0x08
lw   $t1, 0($zero)  # t1 = 5, após o stall
# PC 0x0C
addi $t2, $t1, 1    # t2 = 6: execução retomada
```

A testbench conserva LW nas duas etapas: primeiro a RAM devolve o dado com
PC atual ainda em 0x08; depois o CPU escreve t1 e avança para 0x0C.
A waveform mostra as instruções em texto, a fase, PC/stall, os três registos
e os sinais da RAM. Clock de 50 MHz, estímulos/observações após o flanco de
subida. XSim: 8 verificações passaram, terminando a 171 ns.
Esta versão básica não inclui os antigos testes de branches, encodings
inválidos, loads consecutivos ou pausa global a meio de um load.

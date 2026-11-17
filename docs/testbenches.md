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
| `tb_alu` | `alu` | Operações aritméticas e lógicas, shifts, rotação e sinais zero, negativo, carry em ADD, empréstimo em SUB e overflow de ADD/SUB. |
| `tb_bdu` | `bdu` | Condições de branch, casos com sinal e códigos sem condição associada. |
| `tb_control_unit` | `control_unit` | 26 casos: uma verificação de cada uma das 24 instruções suportadas, mais um opcode e uma função R-type não suportados. Sem varrimentos exaustivos. |
| `tb_regfile` | `regfile` | Reset, leitura simultânea nas duas portas, escrita, proteção do registo zero e escritas consecutivas. |
| `tb_memories` | `component_tests` | 8 verificações básicas: reset das saídas, leituras da ROM, pausa/retoma da ROM, escrita/leitura de uma palavra da RAM e manutenção da saída com enable desativado. |
| `tb_datapath` | `datapath` | Controlos aplicados diretamente: muxes dos operandos/destino/write-back, extensão de sinal, shamt, PC sequencial, branch tomado/não tomado, JAL/JR/JALR, enable e stall de LW. A resposta de memória devolve 42 após um flanco de leitura. |
| `tb_cpu_memory` | `cpu_memory` | 8 verificações básicas: reset, ADDI, SW, espera de LW com PC/ROM parados, escrita do valor carregado e execução da instrução seguinte. |
| `tb_soc` | `soc` | Demonstração simples para estudar a waveform: gera clock/reset, espera `soc_reset=0` e observa mais 50 ciclos do CPU. Não faz verificações automáticas nem declara PASS. |

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
testbench da tabela. Em `component_tests`, o top atual é `tb_memories`.

Na janela **Scopes**, expande o testbench. Na janela **Objects**, acrescenta
à waveform os sinais de texto disponíveis nesse teste, como `test_name`,
`condition_name`, `operation`, `memory_phase` ou `cpu_phase`. Sob
`dut`, podes ver os sinais internos do bloco testado. A consola Tcl
mostra as mensagens de resultado e os nomes das verificações que falham.

### Datapath isolado

A regressão cria o conjunto `datapath` e acrescenta `tb_datapath.v` e
[tb_datapath_behav.wcfg](../tb_datapath_behav.wcfg) quando ainda não existem
nesse conjunto. Para adicionar manualmente no GUI, usa **Add Sources → Add
or Create Simulation Sources**, cria o conjunto `datapath` e seleciona
`G7_MIPS32.srcs/sim_1/new/tb_datapath.v`. Define `tb_datapath` como top.

Executa **Run Behavioral Simulation → Run All**. Usa **File → Simulation
Waveform → Open Configuration** para abrir a configuração, se necessário.
Os separadores são Test Status, Clock and Control, Mux Controls, Operands and
Writeback, PC and Load Stall e Register Results. Os nomes dos testes são ASCII.

É uma testbench comportamental de 50 MHz: os estímulos e as observações são
feitos depois dos flancos de subida. As instruções fornecem os campos, mas
os sinais de controlo são definidos explicitamente; não existe control unit
nem RAM real neste teste. O modelo devolve sempre 42 quando recebe um pedido
de leitura. A `tb_cpu_memory` continua a verificar a integração CPU/RAM.
As referências a sinais internos do RTL não são portáveis para uma netlist
de timing.

`tb_soc` é intencionalmente simples: clock externo de 125 MHz, reset durante
25 flancos de subida (libertado a 196 ns), espera por `dut.soc_reset=0` e
observa mais 50 flancos de subida do clock interno de 50 MHz. Depois espera
1 ns para as atualizações assentarem e termina.
Usa **Run All** para chegar ao fim. `Current PC` na waveform é `_pc_r`;
`ROM address (look-ahead)` é o endereço apresentado à ROM e pode já indicar
a instrução seguinte no ciclo de conclusão.

A versão atual de `tb_soc` refere sinais internos (`dut.soc_reset` e
`dut.clk_50mhz`) para mostrar explicitamente o arranque do RTL. Não se deve
assumir que esses caminhos existem numa netlist de timing: essa simulação
precisa de estímulos compatíveis com os nomes/portas da netlist.
A análise estática de timing não precisa de testbench. LD0 só mostra reset;
confirma que a síntese preservou CPU e memórias antes de atribuir o WNS ao CPU.
A demonstração simples não declara um PASS de regressão.

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

## Teste simples da unidade de controlo

`tb_control_unit` apresenta 26 instruções/casos, um de cada vez, durante 10 ns.
Não existe clock: a unidade de controlo é combinacional. Depois de mudar os
campos, a testbench espera 1 ns, verifica os controlos principais e espera mais
9 ns para tornar cada exemplo legível na waveform. Estes atrasos não são
uma medição do circuito físico. A testbench verifica a descodificação, não
executa as instruções nem decide se um branch será tomado.
A cobertura é representativa; foram removidos os ciclos que percorriam todos
os seletores inválidos e todas as funções não implementadas.

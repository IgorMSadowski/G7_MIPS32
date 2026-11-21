# Testbenches do G7 MIPS32

## Base atual

O CPU busca instruções na ROM e acede à RAM através do barramento de dados.
Seleciona [Assembly/soc_board_demo.mem](../Assembly/soc_board_demo.mem) para sintetizar para a placa e `soc_test.mem` para verificar o SoC. Durante o stall de `LW`, o PC
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
| `tb_data_bus` | `data_bus` | Descodificação de endereços, enables e seleção registada do destino de leitura. |
| `tb_soc` | `soc` | Executa `soc_test.mem` e verifica seis resultados escritos no endereço RAM `0x000003F8`. |

## Regressão comportamental no Vivado

1. Abre `G7_MIPS32.xpr` no Vivado.
2. Seleciona `soc_test.mem` em `soc.v`, guarda o projeto e fecha qualquer simulação ativa.
3. Executa o comando na consola Tcl do Vivado.

~~~tcl
source {/home/igor/Documents/Vivado_Projects/G7_MIPS32/run_regression.tcl}
~~~

O [script de regressão](../run_regression.tcl) executa os oito testbenches de
verificação automática dos módulos e do SoC.
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
de leitura. A `tb_soc` verifica a integração CPU, barramento e RAM através do programa em ROM.
As referências a sinais internos do RTL não são portáveis para uma netlist
de timing.

### Integração do SoC com a ROM de teste

A [`tb_soc`](../G7_MIPS32.srcs/sim_1/new/tb_soc.v) usa o ficheiro
que estiver selecionado em `MEM_INIT_FILE` no `soc.v`. Seleciona
[`soc_test.mem`](../Assembly/soc_test.mem) para correr o teste. O
[assembly](../Assembly/soc_test.asm) inclui o PC e a codificação de cada
instrução. A testbench verifica os valores 1 a 6 que o programa escreve
em `0x000003F8`. O valor 7 indica falha.

- **Simulação comportamental:** seleciona o conjunto `soc` e executa
  **Run Behavioral Simulation**. Para ver o PC, a instrução, `$t0` a
  `$t2` e os acessos à RAM, abre [tb_soc_registers.wcfg](../tb_soc_registers.wcfg).
- **Simulação de timing:** guarda o `soc.v`, volta a correr a síntese e
  seleciona **Run Post-Synthesis Timing Simulation**. Os atributos
  `KEEP` em `ram_write`, `_alu_out` e `_wdata` preservam os sinais que
  a testbench observa. A waveform padrão mostra os checkpoints.
- **Bitstream da placa:** seleciona `soc_board_demo.mem` em `soc.v`
  antes de voltar a sintetizar. A análise estática de timing usa o design
  implementado.

Em qualquer simulação, usa **Run All** se parar antes de aparecer o
resultado na consola.

O XSim gera os executáveis e as waveforms dentro de `G7_MIPS32.sim`.
Os comandos Tcl para um teste individual estão nas [notas](notes.md).

## Endereçamento desta base

O software usa endereços alinhados de `0x00000000` a `0x000003FC` para
as 256 palavras da RAM de 1 KiB. O barramento seleciona a RAM na faixa
de `0x00000000` a `0x000003FF`. A RAM usa `i_addr[9:2]` como índice,
pelo que os dois bits inferiores não alteram a palavra selecionada.

O SoC usa caminhos absolutos para os ficheiros de inicialização da ROM.
Se moveres o projeto, atualiza o caminho em `MEM_INIT_FILE`.

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


## Teste simples da unidade de controlo

`tb_control_unit` apresenta 26 instruções/casos, um de cada vez, durante 10 ns.
Não existe clock: a unidade de controlo é combinacional. Depois de mudar os
campos, a testbench espera 1 ns, verifica os controlos principais e espera mais
9 ns para tornar cada exemplo legível na waveform. Estes atrasos não são
uma medição do circuito físico. A testbench verifica a descodificação, não
executa as instruções nem decide se um branch será tomado.
A cobertura é representativa; foram removidos os ciclos que percorriam todos
os seletores inválidos e todas as funções não implementadas.

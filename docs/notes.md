# Notas de trabalho no Vivado

~~~tcl
source {/home/igor/Documents/Vivado_Projects/G7_MIPS32/run_regression.tcl}
~~~

## 1. Regressão comportamental

Cola o comando acima na consola Tcl do Vivado com G7_MIPS32.xpr
aberto e sem uma simulação ativa. A regressão corre 7 testbenches automáticos,
um de cada vez, e lê o contador errors de cada um no fim.
O resultado esperado é `PASS: all testbenches passed.`

Usa este comando para fechar uma simulação ativa.

~~~tcl
close_sim
~~~

## 2. Base de simulação atual

O topo `soc` liga o CPU diretamente à ROM e à RAM. A ROM de arranque
usa [Assembly/test.mem](../Assembly/test.mem). LD0 acompanha diretamente o botão
físico: `o_led[0] = i_rst`. Não indica resultados do programa.
O pedido de reset é `reset_request = i_rst | ~clock_locked`. No `soc.v`, dois
flip-flops (`reset_stage1` e `reset_stage2`) ativam o reset imediatamente e
sincronizam a libertação com dois flancos de subida de `clk_50mhz`. A saída
`reset_stage2` é `soc_reset`, usado pelo CPU e pelas duas memórias. Ambos os
estágios têm o atributo `ASYNC_REG`. O Clock Wizard recebe diretamente `i_rst`.
O clock externo é 125 MHz; o Clock Wizard gera os 50 MHz internos.

## 2.1. Waveform e simulação com atrasos

Usa `soc / tb_soc` para estudar a execução na simulação comportamental.
O teste gera clock de 8 ns e mantém reset durante 25 flancos de subida.
Depois usa `wait (dut.soc_reset === 1'b0)` para esperar pelo clock pronto e
pela libertação do reset interno. Observa mais 50 flancos de subida de
`dut.clk_50mhz`, espera 1 ns e termina. Não tem contador de erros nem declara PASS.
Guarda a waveform e fecha a simulação antes de iniciar outra.

Esta versão usa caminhos internos do RTL para a espera. Para uma simulação
com atrasos, os estímulos têm de ser compatíveis com a netlist gerada; não
assumas que `dut.soc_reset` ou `dut.clk_50mhz` mantêm os mesmos nomes após síntese.
Não existe um teste automático dedicado de timing nesta base. O LED só segue
reset, pelo que é necessário confirmar que CPU e memórias foram preservados
antes de interpretar resultados de timing como resultados do processador.

## 3. Relatório de timing estático

Para obter o WNS não é necessário executar nenhuma testbench nem simulação.
Com `soc` como topo de síntese: Run Synthesis → Run Implementation → Open
Implemented Design → Report Timing Summary → Design Timing Summary.
Na secção Setup, lê Worst Negative Slack (WNS). Valor negativo indica uma
violação; zero ou positivo cumpre os requisitos dos caminhos analisados.
Para investigar o caminho mais lento, abre os caminhos de Setup/Intra-Clock.

Abre Implemented Design no Flow Navigator e executa os comandos abaixo na consola Tcl.

~~~tcl
report_clocks
report_timing_summary
report_timing -delay_type max -max_paths 5
~~~

Confirma um período de 8 ns na entrada e 20 ns na saída do Clocking
Wizard. Na Timing Summary, WNS e WHS devem ser zero ou positivos.
Para medir timing do CPU e das memórias, confirma no relatório hierárquico que
a síntese os preserva. Como LD0 só depende do reset, a síntese pode eliminar
a lógica de execução; nesse caso, o WNS não caracteriza o CPU.

Estes comandos mostram o estado dos runs do projeto.

~~~tcl
get_property STATUS [get_runs synth_1]
get_property STATUS [get_runs impl_1]
~~~

## 4. Correr só um testbench comportamental

Para correr `tb_memories`, fecha qualquer simulação ativa e executa os comandos abaixo.

~~~tcl
current_fileset -simset [get_filesets component_tests]
set_property top tb_memories [get_filesets component_tests]
set_property xsim.simulate.runtime 0ns [get_filesets component_tests]
launch_simulation -simset component_tests -mode behavioral
run all
get_value -radix unsigned /tb_memories/errors
close_sim
~~~

A opção `0ns` deixa o simulador aberto no início. `run all` avança
até ao `$finish`. Para abrir uma waveform de um novo teste, acrescenta
os sinais na janela Objects e usa Restart antes de repetir o run.

Os oito testbenches atuais (sete automáticos e uma demonstração visual) e os respetivos conjuntos de simulação estão no [guia de testbenches](testbenches.md).

## Indicadores da ALU: carry e borrow

A saída `o_carry` tem dois significados conforme a operação:

- ADD: carry-out, o bit extra da soma sem sinal.
- SUB: borrow (empréstimo), igual a 1 quando `A < B` sem sinal.
- Restantes operações: zero.

`SUB` continua a calcular `A - B`; não subtrai um carry anterior como o `SUBB`
do 8051. Não foi acrescentado um registo de flags nem uma exceção.
Exemplos: `20 - 10` dá C=0; `10 - 20` dá C=1; `5 - 5` dá C=0.
Overflow continua independente: em ADD/SUB indica resultado com sinal fora do intervalo.

## Para o relatório — Endereço da ALU e acesso à memória

A arquitetura atual usa diretamente `o_alu_out` como endereço de byte da RAM
e do Data Bus. Em `LW` e `SW`, a ALU calcula `rs + offset`. A RAM síncrona usa
esse endereço no flanco em que recebe um pedido válido. O `LW` segura o PC e
a instrução durante a leitura e faz write-back no flanco seguinte. O `SW`
escreve no flanco de commit.

**Decisão de design.** Manter o caminho direto. Um registo entre a ALU e a
memória acrescentaria uma etapa ao acesso e exigiria preservar juntos o
endereço, o dado do `SW` e os sinais de controlo. É uma opção para separar as
etapas EX e MEM num pipeline ou para dividir um caminho crítico medido. Um
mux de endereço só se justifica se houver duas fontes a selecionar.

**Branches e efeitos na memória.** `o_alu_out` pode mudar durante um branch e o
decodificador de endereços pode reconhecer uma região válida. O acesso requer
`o_load_issue` para leitura ou `o_mem_write` para escrita. Ambos ficam a zero
durante o branch, tal como `o_rf_we`, que protege o banco de registos. O
`o_commit` permite avançar o PC e fazer o próximo fetch. A decisão do branch
vem da BDU.

**Verificação.** O XSim passou 48 casos que cruzam os seis tipos de branch,
tomados e não tomados, com as regiões RAM, IRQ, I²S e I/O de demonstração.
Os enables de leitura e escrita e a escrita no banco de registos ficaram
desativados. Um `SW` de controlo ativou a escrita da RAM. Esta verificação
cobre o comportamento funcional. O caminho físico deve ser avaliado com
timing pós-implementação.

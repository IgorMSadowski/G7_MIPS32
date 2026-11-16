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
usa [Assembly/test.mem](../Assembly/test.mem). LD0 guarda a indicação de uma
escrita normal da CPU na RAM no endereço de byte zero: dado diferente de zero
acende, dado zero apaga. O reset apaga o LED. A RAM continua a receber a escrita;
isto é uma saída de diagnóstico, sem um novo periférico ou mapa MMIO.

## 2.1. Preparar o teste externo para timing

Guarda a waveform e fecha a simulação ativa. Com o projeto aberto, executa uma vez:

~~~tcl
source {/home/igor/Documents/Vivado_Projects/G7_MIPS32/setup_soc_timing.tcl}
~~~

O script acrescenta e ativa `soc_timing / tb_soc_timing`, com uma waveform que só
usa os sinais externos e o estado do teste. Guarda o projeto no Vivado.

1. Run Simulation → Run Behavioral Simulation → Run All.
2. Run Synthesis novamente, pois `soc.v` mudou; depois Run Implementation.
3. Open Implemented Design → Report Timing Summary, para a análise estática.
4. Fecha qualquer simulação ativa. Run Simulation → Run Post-Implementation
   Timing Simulation → Run All, para simular os atrasos calculados.

O resultado esperado é `PASS: CPU RAM write drives LED; reset and restart work`.
O clock externo continua a ser 125 MHz; o Clock Wizard gera os 50 MHz internos.
Este teste usa a mesma `Assembly/test.mem` da síntese, espera o reset inicial do
FPGA e verifica LED apagado, resultado da CPU, reset e nova execução.
É um teste de integração observável, não uma prova de todas as instruções.
Usa `soc / tb_soc` para estudar a waveform sem tasks nem comparações.
A antiga `tb_soc_regression` foi retirada. A demonstração `tb_soc` é observada
manualmente e não faz parte dos sete testes automáticos.

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
a síntese os preserva. LD0 agora depende de uma escrita calculada pela CPU;
antes, a ligação exclusiva ao reset permitia eliminar a lógica de execução.

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

Os oito testes e os respetivos conjuntos de simulação estão no [guia de testbenches](testbenches.md).

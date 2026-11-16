# Notas de trabalho no Vivado

~~~tcl
source {/home/igor/Documents/Vivado_Projects/G7_MIPS32/run_regression.tcl}
~~~

## 1. Regressão comportamental

Cola o comando acima na consola Tcl do Vivado com G7_MIPS32.xpr
aberto e sem uma simulação ativa. A regressão corre 6 testbenches automáticos,
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
O teste gera clock de 8 ns, mantém reset durante 25 flancos de subida e termina
após mais 600 flancos, a 4996 ns. Não tem contador de erros nem declara PASS.
Guarda a waveform e fecha a simulação antes de iniciar outra.

Para simular os atrasos calculados, com `soc` como topo de síntese:

1. Executa Run Synthesis e Run Implementation para o RTL atual.
2. Seleciona `soc / tb_soc` como conjunto/topo de simulação.
3. Usa Run Simulation → Run Post-Implementation Timing Simulation → Run All.

A `tb_soc` só liga as portas externas, mas os sinais internos da netlist podem
ter nomes diferentes dos da waveform RTL. LD0 só segue reset. Antes de avaliar
o timing do processador, confirma que a síntese preservou CPU e memórias:
sem uma saída observável da execução, essa lógica pode ser eliminada.
Não existe um teste automático dedicado de timing nesta base.

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

Os sete testbenches atuais (seis automáticos e uma demonstração visual) e os respetivos conjuntos de simulação estão no [guia de testbenches](testbenches.md).

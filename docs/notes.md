# Notas de trabalho no Vivado

~~~tcl
source {/home/igor/Documents/Vivado_Projects/G7_MIPS32/run_regression.tcl}
~~~

## 1. Regressão comportamental

Cola o comando acima na consola Tcl do Vivado com G7_MIPS32.xpr
aberto e sem uma simulação ativa. A regressão corre 8 testbenches,
um de cada vez, e lê o contador errors de cada um no fim.
O resultado esperado é `PASS: all testbenches passed.`

Usa este comando para fechar uma simulação ativa.

~~~tcl
close_sim
~~~

## 2. Base de simulação atual

O topo `soc` liga o CPU diretamente à ROM e à RAM. A ROM de arranque
usa [Assembly/test.mem](../Assembly/test.mem). O antigo set de timing testava o demo de MMIO
e foi retirado com esse demo. A saída LD0 mostra o reset físico.

## 3. Relatório de timing estático

Abre Implemented Design no Flow Navigator e executa os comandos abaixo na consola Tcl.

~~~tcl
report_clocks
report_timing_summary
report_timing -delay_type max -max_paths 5
~~~

Confirma um período de 8 ns na entrada e 20 ns na saída do Clocking
Wizard. Na Timing Summary, WNS e WHS devem ser zero ou positivos.
Para medir timing do CPU e das memórias, confirma que a síntese os
preserva. Com LD0 ligado só ao reset, o cálculo interno não chega a
uma saída do topo.

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

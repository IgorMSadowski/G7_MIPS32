# G7 MIPS32 | Barramento de dados e interrupções

Este ficheiro complementa o [plano de trabalho](todo.md). A referência é o SoC de 16 bits do
Grupo 10, baseado no GR0040/GR0041. O G7 tem endereços e dados de 32 bits.

## 1. Interface entre o processador e o SoC

O CPU do Grupo 10 envia d_ad (endereço), cpu_do (dado de escrita) e
lw/lb/sw/sb (pedidos de acesso). Recebe cpu_di (dado de leitura) e rdy
(indicação de que o acesso pode terminar).

~~~text
CPU -> endereço, dado de escrita, pedido -> RAM ou periférico
CPU <- dado de leitura e rdy             <- mux do alvo selecionado
~~~

Cada destino produz a sua própria resposta. O mux escolhe uma resposta
e encaminha-a ao CPU. Assim o barramento interno funciona sem tri-state.

## 2. Descodificação em dois níveis

O trecho de `sources_1/new/m_soc.v` nas linhas 82–99 seleciona o destino.

~~~verilog
wire is_io = d_ad[15];
wire io_we = is_io & (sw | sb);
wire io_re = is_io & (lw | lb);
assign cpu_di = is_io ? io_rdata : mem_dout;
assign rdy    = is_io ? io_rdy   : mem_rdy;
~~~

Se d_ad[15] = 0, o caminho de dados seleciona a BRAM. Se d_ad[15] = 1,
seleciona o caminho de I/O e desativa os enables de escrita da BRAM.
O Grupo 10 usa uma BRAM de 1 KiB com duas portas. A porta A busca instruções
e a porta B trata os dados.

Em sources_1/new/m_periph_bus.v, linhas 26–40 e 124–139, o segundo nível
lê addr[11:8], gera um sel para cada periférico e escolhe as respostas
rdata e rdy do periférico selecionado. A tabela mostra as bases usadas no programa.

| Endereço base | Periférico |
| --- | --- |
| `0x8000` | Timer0 |
| `0x8100` | Timer1 |
| `0x8200` | ParIO |
| `0x8300` | UART (o mesmo periférico trata RX e TX) |
| `0x8F00` | Registos do controlador de interrupções |

Os bits [14:12] ficam fora dessa descodificação, pelo que outros endereços
podem selecionar os mesmos periféricos. Cada periférico usa os bits mais
baixos para escolher um registo. Sem seleção válida, o mux de periféricos
devolve rdata = 0 e rdy = 1.

## 3. Trace de um SW para o ParIO

O código em sw-programs/input.asm, linhas 119–129, escreve 0xF no ParIO.

~~~text
SW -> d_ad = 0x8200 e cpu_do = 0x000F
   -> is_io = 1, io_we = 1, escrita na RAM desativada
   -> addr[11:8] = 2, sel_pario = 1
   -> addr[1:0] = 0, seleciona o registo de saída do ParIO
   -> no posedge, o ParIO copia wdata[3:0] para a saída dos LEDs
~~~

O ParIO define rdy = sel. Numa leitura, devolve o valor das saídas em
0x8200 ou o estado das entradas em 0x8202. O dado percorre dois muxes
até ao CPU, primeiro no periph_bus e depois no soc. Ver m_pario.v,
linhas 18 e 29–49, na mesma pasta de RTL.

## 4. Trace de um LW da BRAM

Em m_soc.v, linhas 69–80, mem_rdy fica a 0 enquanto há um load e o bit
loaded ainda está a 0. O CPU usa esse rdy em m_gr0040.v, nas linhas 86–95.

~~~verilog
assign insn_ce = rst | ~(mem & ~rdy);
~~~

Fora do reset, se há um acesso a dados e rdy = 0, insn_ce = 0.
A porta de instruções fica desativada e a instrução em execução espera.
A porta de dados da BRAM continua a fazer a leitura. Após o flanco que
disponibiliza o dado, loaded passa a 1 e o CPU pode concluir o load.

## 5. Ideias para implementar no G7, por etapas

- [ ] Definir o mapa do G7. Usar nomes como RAM_BASE, PARIO_BASE e TIMER_BASE.
  Especificar intervalos, registos a múltiplos de quatro bytes e o que
  acontece num acesso desalinhado ou a um endereço não mapeado.
- [ ] Ligar primeiro a RAM. Começar com address, write_data, read_data,
  read_enable e write_enable. Confirmar que os programas existentes
  ainda passam e que um endereço reservado ao MMIO não altera a RAM.
- [ ] Adicionar ParIO. Descodificar a região, gerar o enable local e usar
  um mux para devolver RAM ou ParIO. Verificar escrita no registo de
  saída, leitura do registo de entrada e isolamento entre os destinos.
- [ ] Adicionar o Timer/Counter de 16 bits. Começar com controlo, contagem
  e reload. Testar por polling antes de ligar o pedido de interrupção.
- [ ] Definir quando read_data fica válido. Se todos os alvos entregarem
  o dado no mesmo flanco previsto para a RAM atual, o stall fixo pode
  ser suficiente. Se algum alvo demorar mais, devolver ready ao CPU
  e manter o acesso pendente até o dado ficar válido. Verificar que
  uma escrita só produz um efeito, mesmo se houver espera.

## 6. Colocar código num endereço fixo com o assembler

O assembler em C está em [Assembly/asm.c](../Assembly/asm.c). Para o compilar e experimentar,
executa os comandos abaixo na pasta principal do projeto.

~~~bash
gcc -std=c11 -Wall -Wextra -Wpedantic Assembly/asm.c -o /tmp/g7-asm
/tmp/g7-asm Assembly/test.asm -o /tmp/g7-test.mem -l
~~~

O assembler suporta as instruções atuais do G7 e faz duas passagens.
Na primeira, atribui endereços aos labels e instruções. Na segunda,
resolve os labels e gera uma palavra hexadecimal de 32 bits por linha.
A opção `-l` mostra o endereço, a palavra gerada e a instrução. O [guia do assembler](asm_explicacao.md) explica o código em C.

O exemplo usa as instruções atuais do G7.

~~~asm
main:
    jal rotina
fim:
    j fim

.org 0x80
rotina:
    addi $t0, $zero, 1
    jr $ra
~~~

.org 0x80 diz ao assembler que a próxima instrução começa no endereço
de byte 0x80. A ROM guarda palavras de quatro bytes, por isso 0x80 / 4
é o índice 32, ou seja, a linha 33 do .mem. O assembler preenche o espaço
entre fim e rotina com NOPs (00000000). A ROM do G7 tem 64 palavras e os endereços alinhados vão de 0x00 a 0xFC. .org só avança e não sobrepõe
código já colocado. Este exemplo usa uma imagem própria para a rotina
em 0x80. Em Assembly/test.asm, esse endereço já está ocupado.

O assembler resolve jal rotina para 0C000020. Quando o CPU executa esse
JAL em 0x00, guarda 0x04 em $ra e passa o PC para 0x80. O JR regressa ao
endereço em $ra. Para saltar sem guardar retorno, usa j rotina ou j 0x80.

## 7. Como usar um endereço fixo para uma interrupção no G7

Uma interrupção é um pedido de hardware que pode chegar enquanto o CPU
executa o programa. Para a primeira versão, usa uma fonte de teste, um
bit de pedido pendente, um enable global e um endereço fixo para a ISR
(rotina de serviço). Podes reservar 0x80 numa imagem de teste e pôr
.org 0x80 imediatamente antes de isr: no assembly. No RTL, configura
IRQ_ENTRY_ADDR = 32'h0000_0080 para o mesmo endereço.

~~~text
pedido -> pendente -> CPU aceita entre instruções -> PC = 0x80
~~~

1. A fonte faz o pedido. O CPU regista-o como pendente para o poder
   atender quando as interrupções estiverem ativadas.
2. O CPU termina a instrução atual. Se um LW estiver em espera, termina
   primeiro a escrita do dado no registo. Na aceitação, o EPC guarda
   o endereço da próxima instrução que deveria executar. Normalmente é
   PC+4. Se a instrução que acabou tomou um branch ou jump, guarda o
   destino desse branch ou jump.
3. O hardware guarda o enable anterior, bloqueia novas entradas e
   seleciona IRQ_ENTRY_ADDR para o PC e o endereço de fetch. O programa
   principal pode ser interrompido em vários pontos sem ter um JAL
   para a ISR em cada um deles.
4. A ISR trata e reconhece a causa. Antes de voltar, restaura os
   registos que usou. O ERET futuro deve carregar o PC a partir do EPC
   e restaurar o enable guardado. O G7 atual ainda não tem IRQ, EPC
   nem ERET. O exemplo da secção 6 é uma chamada normal que já se
   consegue montar e executar.

No Grupo 10, sw-programs/input.asm usa .org para colocar, por exemplo,
isr_timer em 0x0020 e isr_pario em 0x0060. Em sources_1/new/m_irq_ctrl.v,
linhas 113–127, o controlador escolhe esses mesmos endereços conforme a
fonte e envia irq_vector ao CPU. No primeiro G7, basta um endereço comum.
Se mais tarde houver várias fontes, a ISR comum pode ler a causa e
escolher o tratamento. A escolha de um endereço por fonte é uma etapa
separada, chamada interrupções vetorizadas.

## Referência local

Pasta entregue pelo Grupo 10

`/home/igor/Documents/MEEIC/GPT-Processor/Projects/Projects/Final Projects/Processor/Code/G10_Processor/fpga-final/fpga-final/`

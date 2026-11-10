# Programa de exemplo da ROM

Esta tabela descodifica as palavras de
[Assembly/imem_init.mem](../Assembly/imem_init.mem).

| Endereço | Assembly | Palavra de máquina | Efeito |
| --- | --- | --- | --- |
| `0x00` | `addi $t0, $zero, 3` | `20080003` | `$t0 = 3` |
| `0x04` | `addi $t1, $zero, 5` | `20090005` | `$t1 = 5` |
| `0x08` | `add $t2, $t0, $t1` | `01095020` | `$t2 = 8` |
| `0x0C` | `sw $t2, 0($zero)` | `AC0A0000` | Guarda `8` na RAM no endereço `0x00`. |
| `0x10` | `lw $t3, 0($zero)` | `8C0B0000` | Lê a palavra do endereço `0x00` para `$t3`. |
| `0x14` | `beq $t2, $t3, -6` | `114BFFFA` | Se os valores forem iguais, regressa a `0x00`. |
| `0x18` | `nop` | `00000000` | Nenhuma operação. |
| `0x1C` | `nop` | `00000000` | Nenhuma operação. |

O branch parte de `PC+4 = 0x18` e usa um deslocamento de seis palavras
para trás, pelo que o destino é `0x00`.

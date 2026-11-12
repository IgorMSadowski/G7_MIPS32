# G7 MIPS32 Project Checklist

Current implementation order: basic interrupt first, then the data bus and
peripherals. Keep nesting and additional exception mechanisms for later.

Current baseline:

- [x] ROM and RAM sized to 1 KiB each; C assembler limited to 256 words.
- [x] Behavioral regression passed 8/8 benches for the 1 KiB revision.
- [x] Memory plan documented: 960 bytes of data and 64 bytes of stack in RAM.
  IRQ/MMIO layout and stack initialization remain planned, not implemented.

## 1. Finish verification of the implemented ISA and all testbenches

- [ ] Build a coverage matrix from the encodings in `control_unit.v`.
  Check every supported instruction, its destinations and side effects,
  and taken/not-taken cases for each conditional branch.
- [ ] Verify reserved encodings, register zero, signed comparisons, shifts
  and rotations, PC+4 links, and the current no-delay-slot policy.
- [ ] Verify the RAM-only SoC. `SW` writes once. `LW` holds PC and the ROM word
  until write-back. Dependent instructions and consecutive loads resume.
  Check reset, pause/resume and the current address-aliasing behavior.
- [ ] Review tb_alu, tb_bdu, tb_control_unit, tb_regfile, tb_primitives,
  tb_memories, tb_cpu_memory and tb_soc. Record expected outcomes,
  waveforms, uncovered cases and the Vivado regression result.
- [ ] Keep behavioral pass, coverage review, routed timing and board
  validation as separate evidence.

## 2. Implement the basic interrupt first: one source, one common handler

- [ ] Finish the minimal interrupt specification before editing RTL:
  one simulated source, one pending request, a global enable and an
  active/in-handler flag. No priority preemption or nesting initially.
- [ ] Confirm the custom return instruction (RETI proposal), its available
  encoding under the class rules, and its exact behavior. Define the saved
  return-PC register and how software enables/disables interrupts. Do not
  assume an implemented CP0 or ERET mechanism.
- [ ] Prepare a dedicated test ROM image: reset entry at 0x00 jumps to main;
  the common IRQ entry at 0x04 jumps to irq_handler; main starts at 0x20.
  These are custom project entry addresses. The assembler places the ISR
  body elsewhere in the available ROM without overlap.
- [ ] Accept IRQs only at the defined instruction-completion boundary.
  Finish an in-flight LW write-back before entry. Save the selected next
  unexecuted address, including a taken branch/jump target where applicable,
  and redirect the PC and ROM coherently.
- [ ] Block new interrupt entries while servicing the handler, preserve
  pending requests according to the defined policy, and define exactly
  when the accepted request is acknowledged/cleared.
- [ ] Initialize $sp to 0x400 before enabling interrupts. Reserve RAM
  0x3C0..0x3FF for the 64-byte stack; decrement before SW and recover with
  LW before incrementing. First pushed word is at 0x3FC.
- [ ] Begin with a handler that executes NOPs and returns. Then test saving
  and restoring each general register that the useful ISR modifies.
  Preserve $ra if the ISR calls functions. Check the 16-word stack budget.
- [ ] Verify entry, saved return address, request acknowledgement and exact
  resumption for an ordinary instruction, a taken branch/jump and pending
  LW. Also test disabled IRQs, held/repeated requests and reset. Check that
  stores and RF writes are neither lost nor duplicated. Rerun regression.

## 3. Add the basic data bus and peripherals after the interrupt works

- [ ] Complete the timing contract and register definitions before RTL:
  memorymap.txt already reserves address windows, but decoding, register
  offsets, permissions and side effects are not implemented. Define
  alignment, invalid-address behavior and response timing.
- [ ] Add address decoding, exclusive target enables and a read-data mux.
  Use separate address, write-data and read-data signals. MMIO selects
  peripheral registers in the data address space; it does not occupy RAM.
- [ ] Start with RAM as the only data target and rerun the ISA regression.
  Preserve the tested load-hold contract; add a response/ready mechanism
  only if the target timing requires it.
- [ ] Implement ParIO input/output registers and verify reset, reads,
  writes and isolation from RAM and other targets.
- [ ] Implement a 16-bit timer/counter with basic enable, count and
  reload/period. Test by polling before adding sticky status/acknowledge
  and connecting its IRQ to the already verified interrupt system.
- [ ] Add a physical button IRQ with synchronization and debounce after
  the simulated path works. Decide whether this is a ParIO event source
  or a separate input, and avoid counting the same event twice.
- [ ] With multiple sources, keep one common entry initially. Define how
  irq_handler identifies pending sources, dispatches service routines and
  acknowledges each source. Multiple sources do not require nesting.

## 4. Extend interrupts to controlled nesting later

- [ ] Study Arm Cortex-M and RISC-V interrupt/context handling as references,
  while keeping this project's own ISA and documented return mechanism.
- [ ] Add priorities and allow only a strictly higher-priority request to
  preempt. Preserve pending equal/lower-priority sources.
- [ ] Save the return PC, interrupt-control state and required registers for
  every level. Choose software stack use versus additional hardware state;
  verify that the 64-byte stack budget fits, or resize it from measured use.
- [ ] Define a bounded nesting depth and overflow behavior. Test simultaneous
  requests, preemption, deferred requests and reverse-order return.

## 5. Extend synchronous exceptions after the baseline is stable

- [ ] Add signed ADD/ADDI/SUB overflow with write-back suppression and
  a saved faulting PC. Define trap, unsupported-instruction and alignment cases.
- [ ] Handle unsigned carry separately. Check 0xFFFFFFFF + 1 (carry without
  signed overflow) and 0x7FFFFFFF + 1 (signed overflow without carry).
  Evaluate ADDU and SLTU for a software multiword addition.

## 6. Verify each integrated increment and prepare the board demonstration

- [ ] Rerun the existing regression and add directed tests for each feature.
- [ ] Provide an observable CPU result before synthesis and board validation.
- [ ] Rebuild at 50 MHz, inspect setup/hold, simulate the routed build with
  a suitable test, and demonstrate the result on the Zybo Z7-10.

## 7. Synchronize the report and diagrams as the design evolves

- [ ] Replace the previous memory-map layout in REPORT-EDIT with the latest
  simplified Draw.io page 20 (instruction ROM and data address space).
- [ ] Update the report's interrupt design to state the agreed first step:
  one simulated source, common entry at 0x04, one handler, no nesting.
  Document the return-instruction choice once confirmed.
- [ ] Keep implemented RTL separate from proposals in the report and figures.
  Stack initialization, IRQ entry/return, source control and MMIO decoding
  are still pending, even though memory capacity is already implemented.
- [ ] After each implemented increment, update the source descriptions,
  schematics and actual verification evidence without claiming timing or
  board validation from a behavioral PASS.

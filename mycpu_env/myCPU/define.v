`define CSR_CRMD 0
`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE 2
`define CSR_CRMD_DA 3
`define CSR_CRMD_PG 4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7


`define CSR_PRMD 1
`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE 2


`define CSR_EUEN 2
`define CSR_EUEN_FPE 0


`define CSR_ECFG 3
`define CSR_ECFG_LIE 13:0


`define CSR_ESTAT 4
`define CSR_ESTAT_IS10 1:0

`define CSR_TICLR_CLR 11

`define ECODE_INT 6'h0
`define ECODE_PIL 6'h1
`define ECODE_PIS 6'h2
`define ECODE_PIF 6'h3
`define ECODE_PME 6'h4
`define ECODE_PPI 6'h7
`define ECODE_ADE 6'h8
`define ECODE_ALE 6'h9
`define ECODE_SYS 6'hB
`define ECODE_BRK 6'hC
`define ECODE_INE 6'hD
`define ECODE_IPE 6'hE
`define ECODE_FPD 6'hF
`define ECODE_FPE 6'h12
`define ECODE_TLBR 6'h3F

`define ESUBCODE_ADEF 0
`define ESUBCODE_ADEM 1


`define CSR_ERA 5
`define CSR_ERA_PC 31:0


`define CSR_BADV 6


`define CSR_EENTRY 7
`define CSR_EENTRY_VA 31:6


`define CPUID 8

`define CSR_SAVE0 9
`define CSR_SAVE1 10
`define CSR_SAVE2 11
`define CSR_SAVE3 12

`define CSR_SAVE_DATA 31:0


`define CSR_LLBCTL 13


`define CSR_TLBIDX 14


`define CSR_TLBEHI 15


`define CSR_TLBELO0 16
`define CSR_TLBELO1 17


`define CSR_ASID 18


`define CSR_PGDL 19


`define CSR_PGDH 20


`define CSR_PGD 21


`define CSR_TLBRENTRY 22


`define CSR_DMW0 23
`define CSR_DMW1 24


`define CSR_TID 25

`define CSR_TID_TID 31:0


`define CSR_TCFG 26

`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV 31:0 //


`define CSR_TVAL 27


`define CSR_TICLR 28

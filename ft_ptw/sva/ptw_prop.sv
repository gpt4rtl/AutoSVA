// This property file was autogenerated by AutoSVA on 2023-09-10
// to check the behavior of the original RTL module, whose interface is described below: 

module ptw_prop
 import ariane_pkg::*; #(
		parameter ASSERT_INPUTS = 0,
		parameter int ASID_WIDTH = 1,
		parameter ariane_pkg::ariane_cfg_t ArianeCfg = ariane_pkg::ArianeDefaultConfig
) (
		input  logic                    clk_i,                  // Clock
		input  logic                    rst_ni,                 // Asynchronous reset active low
		input  logic                    flush_i,                // flush everything, we need to do this because
		// actually everything we do is speculative at this stage
		// e.g.: there could be a CSR instruction that changes everything
		input  logic                    ptw_active_o, //output
		input  logic                    walking_instr_o,        // set when walking for TLB //output
		input  logic                    ptw_error_o,            // set when an error occurred //output
		input  logic                    ptw_access_exception_o, // set when an PMP access exception occured //output
		input  logic                    enable_translation_i,   // CSRs indicate to enable SV39
		input  logic                    en_ld_st_translation_i, // enable virtual memory translation for load/stores
		
		input  logic                    lsu_is_store_i,         // this translation was triggered by a store
		// PTW memory interface
		input  dcache_req_o_t           req_port_i,
		input  dcache_req_i_t           req_port_o, //output
		
		
		// to TLBs, update logic
		input  tlb_update_t             itlb_update_o, //output
		input  tlb_update_t             dtlb_update_o, //output
		
		input  logic [riscv::VLEN-1:0]  update_vaddr_o, //output
		
		input  logic [ASID_WIDTH-1:0]   asid_i,
		// from TLBs
		// did we miss?
		input  logic                    itlb_access_i,
		input  logic                    itlb_hit_i,
		input  logic [riscv::VLEN-1:0]  itlb_vaddr_i,
		
		input  logic                    dtlb_access_i,
		input  logic                    dtlb_hit_i,
		input  logic [riscv::VLEN-1:0]  dtlb_vaddr_i,
		// from CSR file
		input  logic [riscv::PPNW-1:0]  satp_ppn_i, // ppn from satp
		input  logic                    mxr_i,
		// Performance counters
		input  logic                    itlb_miss_o, //output
		input  logic                    dtlb_miss_o, //output
		// PMP
		
		input  riscv::pmpcfg_t [15:0]   pmpcfg_i,
		input  logic [15:0][53:0]       pmpaddr_i,
		input  logic [riscv::PLEN-1:0]  bad_paddr_o //output
	);

//==============================================================================
// Local Parameters
//==============================================================================

genvar j;
default clocking cb @(posedge clk_i);
endclocking
default disable iff (!rst_ni);

// Re-defined wires 
wire ptw_req_val;
wire ptw_req_rdy;
wire ptw_res_val;
wire itlb_iface_active;
wire itlb_val;
wire itlb_rdy;
wire [riscv::VLEN-1:0] itlb_stable;
wire [riscv::VLEN-1:0] itlb_data;
wire itlb_update_val;
wire [riscv::VLEN-1:0] itlb_update_data;
wire dtlb_iface_active;
wire dtlb_val;
wire dtlb_rdy;
wire [riscv::VLEN-1:0] dtlb_stable;
wire [riscv::VLEN-1:0] dtlb_data;
wire dtlb_update_val;
wire [riscv::VLEN-1:0] dtlb_update_data;

// Symbolics and Handshake signals
wire itlb_update_hsk = itlb_update_val;
wire itlb_hsk = itlb_val && itlb_rdy;
wire ptw_res_hsk = ptw_res_val;
wire ptw_req_hsk = ptw_req_val && ptw_req_rdy;
wire dtlb_update_hsk = dtlb_update_val;
wire dtlb_hsk = dtlb_val && dtlb_rdy;

//==============================================================================
// Modeling
//==============================================================================
/*
// Modeling incoming request for itlb_iface
// Generate sampling signals and model
reg [3:0] itlb_iface_transid_sampled;
wire itlb_iface_transid_set = itlb_hsk;
wire itlb_iface_transid_response = itlb_update_hsk;

always_ff @(posedge clk_i) begin
	if(!rst_ni) begin
		itlb_iface_transid_sampled <= '0;
	end else if (itlb_iface_transid_set || itlb_iface_transid_response ) begin
		itlb_iface_transid_sampled <= itlb_iface_transid_sampled + itlb_iface_transid_set - itlb_iface_transid_response;
	end
end
co__itlb_iface_transid_sampled: cover property (|itlb_iface_transid_sampled);
if (ASSERT_INPUTS) begin
	as__itlb_iface_transid_sample_no_overflow: assert property (itlb_iface_transid_sampled != '1 || !itlb_iface_transid_set);
end else begin
	am__itlb_iface_transid_sample_no_overflow: assume property (itlb_iface_transid_sampled != '1 || !itlb_iface_transid_set);
end

as__itlb_iface_transid_active: assert property (itlb_iface_transid_sampled > 0 |-> itlb_iface_active);

// Assume payload is stable and valid is non-dropping
if (ASSERT_INPUTS) begin
	as__itlb_iface_transid_stability: assert property (itlb_val && !itlb_rdy |=> itlb_val && $stable(itlb_stable) );
end else begin
	am__itlb_iface_transid_stability: assume property (itlb_val && !itlb_rdy |=> itlb_val && $stable(itlb_stable) );
end

// Assert that if valid eventually ready or dropped valid
as__itlb_iface_transid_hsk_or_drop: assert property (itlb_val |-> s_eventually(!itlb_val || itlb_rdy));
// Assert that every request has a response and that every reponse has a request
as__itlb_iface_transid_eventual_response: assert property (|itlb_iface_transid_sampled |-> s_eventually(itlb_update_val));
as__itlb_iface_transid_was_a_request: assert property (itlb_iface_transid_response |-> itlb_iface_transid_set || itlb_iface_transid_sampled);


// Modeling data integrity for itlb_iface_transid
reg [riscv::VLEN-1:0] itlb_iface_transid_data_model;
always_ff @(posedge clk_i) begin
	if(!rst_ni) begin
		itlb_iface_transid_data_model <= '0;
	end else if (itlb_iface_transid_set) begin
		itlb_iface_transid_data_model <= itlb_data;
	end
end

as__itlb_iface_transid_data_unique: assert property (|itlb_iface_transid_sampled |-> !itlb_iface_transid_set);
as__itlb_iface_transid_data_integrity: assert property (|itlb_iface_transid_sampled && itlb_iface_transid_response |-> (itlb_update_data == itlb_iface_transid_data_model));

// Modeling outstanding request for ptw_req
reg [1-1:0] ptw_req_outstanding_req_r;

always_ff @(posedge clk_i) begin
	if(!rst_ni) begin
		ptw_req_outstanding_req_r <= '0;
	end else begin
		if (ptw_req_hsk) begin
			ptw_req_outstanding_req_r <= 1'b1;
		end
		if (ptw_res_hsk) begin
			ptw_req_outstanding_req_r <= 1'b0;
		end
	end
end


generate
if (ASSERT_INPUTS) begin : ptw_req_gen
	as__ptw_req1: assert property (!ptw_req_outstanding_req_r |-> !(ptw_res_hsk));
	as__ptw_req2: assert property (ptw_req_outstanding_req_r |-> s_eventually(ptw_res_hsk));
end else begin : ptw_req_else_gen
	am__ptw_req_fairness: assume property (ptw_req_val |-> s_eventually(ptw_req_rdy));
	for ( j = 0; j < 1; j = j + 1) begin : ptw_req_for_gen
		co__ptw_req: cover property (ptw_req_outstanding_req_r[j]);
		am__ptw_req1: assume property (!ptw_req_outstanding_req_r[j] |-> !(ptw_res_val));
		am__ptw_req2: assume property (ptw_req_outstanding_req_r[j] |-> s_eventually(ptw_res_val));
	end
end
endgenerate

// Modeling incoming request for dtlb_iface
// Generate sampling signals and model
reg [3:0] dtlb_iface_transid_sampled;
wire dtlb_iface_transid_set = dtlb_hsk;
wire dtlb_iface_transid_response = dtlb_update_hsk;

always_ff @(posedge clk_i) begin
	if(!rst_ni) begin
		dtlb_iface_transid_sampled <= '0;
	end else if (dtlb_iface_transid_set || dtlb_iface_transid_response ) begin
		dtlb_iface_transid_sampled <= dtlb_iface_transid_sampled + dtlb_iface_transid_set - dtlb_iface_transid_response;
	end
end
co__dtlb_iface_transid_sampled: cover property (|dtlb_iface_transid_sampled);
if (ASSERT_INPUTS) begin
	as__dtlb_iface_transid_sample_no_overflow: assert property (dtlb_iface_transid_sampled != '1 || !dtlb_iface_transid_set);
end else begin
	am__dtlb_iface_transid_sample_no_overflow: assume property (dtlb_iface_transid_sampled != '1 || !dtlb_iface_transid_set);
end

as__dtlb_iface_transid_active: assert property (dtlb_iface_transid_sampled > 0 |-> dtlb_iface_active);

// Assume payload is stable and valid is non-dropping
if (ASSERT_INPUTS) begin
	as__dtlb_iface_transid_stability: assert property (dtlb_val && !dtlb_rdy |=> dtlb_val && $stable(dtlb_stable) );
end else begin
	am__dtlb_iface_transid_stability: assume property (dtlb_val && !dtlb_rdy |=> dtlb_val && $stable(dtlb_stable) );
end

// Assert that if valid eventually ready or dropped valid
as__dtlb_iface_transid_hsk_or_drop: assert property (dtlb_val |-> s_eventually(!dtlb_val || dtlb_rdy));
// Assert that every request has a response and that every reponse has a request
as__dtlb_iface_transid_eventual_response: assert property (|dtlb_iface_transid_sampled |-> s_eventually(dtlb_update_val));
as__dtlb_iface_transid_was_a_request: assert property (dtlb_iface_transid_response |-> dtlb_iface_transid_set || dtlb_iface_transid_sampled);


// Modeling data integrity for dtlb_iface_transid
reg [riscv::VLEN-1:0] dtlb_iface_transid_data_model;
always_ff @(posedge clk_i) begin
	if(!rst_ni) begin
		dtlb_iface_transid_data_model <= '0;
	end else if (dtlb_iface_transid_set) begin
		dtlb_iface_transid_data_model <= dtlb_data;
	end
end

as__dtlb_iface_transid_data_unique: assert property (|dtlb_iface_transid_sampled |-> !dtlb_iface_transid_set);
as__dtlb_iface_transid_data_integrity: assert property (|dtlb_iface_transid_sampled && dtlb_iface_transid_response |-> (dtlb_update_data == dtlb_iface_transid_data_model));

assign ptw_req_val = req_port_o.data_req;
assign dtlb_data = dtlb_vaddr_i;
assign itlb_update_val = itlb_update_o.valid || walking_instr_o && (ptw_access_exception_o || ptw_error_o || ptw_active_o && flush_i);
assign dtlb_update_val = dtlb_update_o.valid || !walking_instr_o && (ptw_access_exception_o || ptw_error_o || ptw_active_o && flush_i);
assign dtlb_val = en_ld_st_translation_i & dtlb_access_i & ~dtlb_hit_i & !flush_i;
assign dtlb_iface_active = ptw_active_o;
assign itlb_stable = itlb_vaddr_i;
assign dtlb_stable = dtlb_vaddr_i;
assign itlb_val = enable_translation_i & itlb_access_i & ~itlb_hit_i & ~dtlb_access_i & !flush_i;
assign ptw_req_rdy = req_port_i.data_gnt;
assign itlb_rdy = !ptw_active_o;
assign dtlb_rdy = !ptw_active_o;
assign dtlb_update_data = update_vaddr_o;
assign itlb_update_data = update_vaddr_o;
assign itlb_data = itlb_vaddr_i;
assign itlb_iface_active = ptw_active_o;
assign ptw_res_val = req_port_i.data_rvalid;

//X PROPAGATION ASSERTIONS
`ifdef XPROP
	 as__no_x_dtlb_update_val: assert property(!$isunknown(dtlb_update_val));
	 as__no_x_dtlb_update_data: assert property(dtlb_update_val |-> !$isunknown(dtlb_update_data));
	 as__no_x_dtlb_val: assert property(!$isunknown(dtlb_val));
	 as__no_x_dtlb_data: assert property(dtlb_val |-> !$isunknown(dtlb_data));
	 as__no_x_dtlb_stable: assert property(dtlb_val |-> !$isunknown(dtlb_stable));
	 as__no_x_itlb_update_val: assert property(!$isunknown(itlb_update_val));
	 as__no_x_itlb_update_data: assert property(itlb_update_val |-> !$isunknown(itlb_update_data));
	 as__no_x_itlb_val: assert property(!$isunknown(itlb_val));
	 as__no_x_itlb_stable: assert property(itlb_val |-> !$isunknown(itlb_stable));
	 as__no_x_itlb_data: assert property(itlb_val |-> !$isunknown(itlb_data));
`endif
*/
//====DESIGNER-ADDED-SVA====//

typedef enum logic [2:0] {
    IDLE,
    WAIT_GRANT,
    PTE_LOOKUP,
    WAIT_RVALID,
    PROPAGATE_ERROR,
    PROPAGATE_ACCESS_ERROR
} state_t;

// SV39 defines three levels of page tables
typedef enum logic [1:0] {
    LVL1, 
    LVL2, 
    LVL3
} level_t;

// Property File

// PROPERTY FILE

// When translation is enabled and there is an instruction TLB access without a hit and no data TLB access,
// it is expected that the module is preparing to access the translation table for instruction TLB.
as__instruction_tlb_miss: assert property (
    enable_translation_i & itlb_access_i & ~itlb_hit_i & ~dtlb_access_i |-> 
    ptw.ptw_pptr_n == {ptw.satp_ppn_i, ptw.itlb_vaddr_i[riscv::SV-1:30], 3'b0} &&
    ptw.is_instr_ptw_n == 1'b1 &&
    ptw.state_d == ptw.WAIT_GRANT
);

// When load-store translation is enabled and there's a data TLB access without a hit,
// it is expected that the module is preparing to access the translation table for data TLB.
as__data_tlb_miss: assert property (
    ptw.en_ld_st_translation_i & ptw.dtlb_access_i & ~ptw.dtlb_hit_i |-> 
    ptw.ptw_pptr_n == {ptw.satp_ppn_i, ptw.dtlb_vaddr_i[riscv::SV-1:30], 3'b0} &&
    ptw.state_d == ptw.WAIT_GRANT
);

// When a request to access the translation table is granted, the module is expected to begin PTE lookup.
as__data_request_granted: assert property (
    ptw.req_port_i.data_gnt |-> 
    ptw.tag_valid_n == 1'b1 &&
    ptw.state_d == ptw.PTE_LOOKUP
);

// If a valid PTE entry is found during lookup, and its 'g' bit is set, the global mapping is set.
as__global_mapping_set: assert property (
    ptw.data_rvalid_q & ptw.pte.g |-> ptw.global_mapping_n == 1'b1
);

// Check if the module correctly signals an error for invalid PTE entries.
as__pte_error: assert property (
    ptw.data_rvalid_q & (!ptw.pte.v || (!ptw.pte.r && ptw.pte.w)) |-> 
    ptw.state_d == ptw.PROPAGATE_ERROR
);

// When an instruction is not allowed access, it's expected to propagate an access error.
as__instruction_access_error: assert property (
    !ptw.allow_access & ptw.data_rvalid_q & ptw.is_instr_ptw_q |-> 
    ptw.itlb_update_o.valid == 1'b0 &&
    ptw.state_d == ptw.PROPAGATE_ACCESS_ERROR
);

// When a data operation is not allowed access, it's expected to propagate an access error.
as__data_access_error: assert property (
    !ptw.allow_access & ptw.data_rvalid_q & ~ptw.is_instr_ptw_q |-> 
    ptw.dtlb_update_o.valid == 1'b0 &&
    ptw.state_d == ptw.PROPAGATE_ACCESS_ERROR
);

// When a flush signal is received, the module is expected to reset its state to IDLE.
as__flush_signal: assert property (
    ptw.flush_i |-> ptw.state_d == ptw.IDLE
);

// The PTW should be marked as active only when it's not in the IDLE state.
as__ptw_activity: assert property (
    ptw.ptw_active_o == (ptw.state_q != ptw.IDLE)
);

// The address index being accessed in the cache should align with the PTW's current PPN and VPN.
as__address_index_alignment: assert property (
    ptw.req_port_o.address_index == ptw.ptw_pptr_q[DCACHE_INDEX_WIDTH-1:0]
);

// The address tag being accessed in the cache should align with the PTW's current PPN and VPN.
as__address_tag_alignment: assert property (
    ptw.req_port_o.address_tag == ptw.ptw_pptr_q[DCACHE_INDEX_WIDTH+DCACHE_TAG_WIDTH-1:DCACHE_INDEX_WIDTH]
);

// When PTW receives an access exception signal, bad physical address output should match PTW's current pointer.
as__bad_physical_address: assert property (
    ptw.ptw_access_exception_o |-> ptw.bad_paddr_o == ptw.ptw_pptr_q
);


// Property File

// Check if PTW is active when state is not IDLE.
asgpt__ptw_active_check: assert property (
    ptw.state_q != IDLE |-> ptw_active_o
);

// Check if instruction PTW is walking when 'is_instr_ptw_q' is high.
asgpt__walking_instr_check: assert property (
    ptw.is_instr_ptw_q |-> walking_instr_o
);

// Check that when there's a PTW error, the module is in the IDLE state in the next cycle and ptw_error_o is asserted.
asgpt__ptw_error_check: assert property (
    ptw.state_q == PROPAGATE_ERROR |=> (ptw.state_d == IDLE && ptw_error_o)
);

// Check that when there's a PTW access exception, the module is in the IDLE state in the next cycle and ptw_access_exception_o is asserted.
asgpt__ptw_access_exception_check: assert property (
    ptw.state_q == PROPAGATE_ACCESS_ERROR |=> (ptw.state_d == IDLE && ptw_access_exception_o)
);

// Validate correct PTE address update when PTW is in the IDLE state and there's an ITLB miss without any DTLB access.
asgpt__pte_address_update_itlb_miss: assert property (
    ptw.state_q == IDLE && enable_translation_i && itlb_access_i && !itlb_hit_i && !dtlb_access_i 
    |-> ptw.ptw_pptr_n == {satp_ppn_i, itlb_vaddr_i[riscv::SV-1:30], 3'b0}
);

// Validate correct PTE address update when PTW is in the IDLE state and there's a DTLB miss.
asgpt__pte_address_update_dtlb_miss: assert property (
    ptw.state_q == IDLE && en_ld_st_translation_i && dtlb_access_i && !dtlb_hit_i 
    |-> ptw.ptw_pptr_n == {satp_ppn_i, dtlb_vaddr_i[riscv::SV-1:30], 3'b0}
);

// Validate that when there's an ITLB miss without any DTLB access, the PTW transitions to the WAIT_GRANT state.
asgpt__state_transition_itlb_miss: assert property (
    ptw.state_q == IDLE && enable_translation_i && itlb_access_i && !itlb_hit_i && !dtlb_access_i 
    |-> ptw.state_d == WAIT_GRANT
);

// Validate that when there's a DTLB miss, the PTW transitions to the WAIT_GRANT state.
asgpt__state_transition_dtlb_miss: assert property (
    ptw.state_q == IDLE && en_ld_st_translation_i && dtlb_access_i && !dtlb_hit_i 
    |-> ptw.state_d == WAIT_GRANT
);

// Validate the data request signal during WAIT_GRANT state.
asgpt__data_req_during_wait_grant: assert property (
    ptw.state_q == WAIT_GRANT |-> req_port_o.data_req
);

// Validate the tag_valid signal when data is granted during WAIT_GRANT state.
asgpt__tag_valid_during_wait_grant: assert property (
    ptw.state_q == WAIT_GRANT && req_port_i.data_gnt |-> ptw.tag_valid_n
);

// Validate the transition to PTE_LOOKUP state when data is granted during WAIT_GRANT state.
asgpt__transition_to_pte_lookup: assert property (
    ptw.state_q == WAIT_GRANT && req_port_i.data_gnt |-> ptw.state_d == PTE_LOOKUP
);

// Ensure that whenever ptw_access_exception_o is set, the bad_paddr_o signal contains the value of ptw_pptr_q.
asgpt__bad_paddr_set_on_access_exception: assert property (
    ptw.ptw_access_exception_o |-> bad_paddr_o == ptw.ptw_pptr_q
);

// TODO: Add more assertions as needed to cover the rest of the functionality.





// Property file for ptw module

// Assert that when ITLB access is enabled and there is no ITLB hit, and no DTLB access, 
// then there's a request to the page table walker.
asgpt__itlb_ptw_request: assert property (
    enable_translation_i && itlb_access_i && ~itlb_hit_i && ~dtlb_access_i
    |-> ptw.ptw_pptr_n != '0 && ptw.is_instr_ptw_n == 1'b1
);

// Assert that when DTLB access is enabled and there's no DTLB hit, 
// then there's a request to the page table walker.
asgpt__dtlb_ptw_request: assert property (
    en_ld_st_translation_i && dtlb_access_i && ~dtlb_hit_i
    |-> ptw.ptw_pptr_n != '0
);

// When a data request is made and granted, the state should transition to PTE_LOOKUP.
asgpt__data_request_granted: assert property (
    ptw.req_port_o.data_req && req_port_i.data_gnt
    |=> ptw.state_d == PTE_LOOKUP
);

// Assert that if the data is ready and the page table entry is invalid or not readable but writable,
// the module should go to error propagation state.
asgpt__invalid_pte_data: assert property (
    ptw.data_rvalid_q && (!pte.v || (!pte.r && pte.w))
    |-> ptw.state_d == PROPAGATE_ERROR
);

// Assert that if the accessed page is an instruction and it's not executable, 
// then the module should propagate an error.
asgpt__non_executable_instr: assert property (
    ptw.data_rvalid_q && ptw.is_instr_ptw_q && (!pte.x || !pte.a)
    |-> ptw.state_d == PROPAGATE_ERROR
);

// Assert that if the page table walker is in LVL1 and receives a non-zero lower PPN or 
// in LVL2 and receives a non-zero lowest PPN, it should propagate an error.
asgpt__invalid_ppn_lvl1_lvl2: assert property (
    ((ptw.ptw_lvl_q == LVL1 && pte.ppn[17:0] != '0) || (ptw.ptw_lvl_q == LVL2 && pte.ppn[8:0] != '0))
    |-> ptw.state_d == PROPAGATE_ERROR
);

// Ensure that if the access is not allowed, the module should propagate an access error.
asgpt__unallowed_access_error: assert property (
    !ptw.allow_access
    |-> ptw.state_d == PROPAGATE_ACCESS_ERROR
);

// On a flush, if the module is in PTE_LOOKUP state without data ready, or in WAIT_GRANT state and data grant is received,
// it should transition to WAIT_RVALID.
asgpt__flush_behavior: assert property (
    flush_i && ((ptw.state_q == PTE_LOOKUP && !ptw.data_rvalid_q) || 
    (ptw.state_q == WAIT_GRANT && req_port_i.data_gnt))
    |=> ptw.state_d == WAIT_RVALID
);

// Assert that when in WAIT_RVALID state and data is ready, the module should transition to IDLE state.
asgpt__wait_rvalid_to_idle: assert property (
    ptw.state_q == WAIT_RVALID && ptw.data_rvalid_q
    |-> ptw.state_d == IDLE
);

// Ensure that if a store operation is attempted on a non-writable or clean page, an error is propagated.
asgpt__store_on_clean_page_error: assert property (
    ptw.lsu_is_store_i && (!pte.w || !pte.d)
    |-> ptw.state_d == PROPAGATE_ERROR
);

// If the ptw module is active, it indicates that either ITLB or DTLB misses have occurred.
asgpt__ptw_activity: assert property (
    ptw_active_o
    |-> itlb_miss_o || dtlb_miss_o
);

// Ensure that the page table walker is not active during reset.
asgpt__ptw_inactive_during_reset: assert property (
    !rst_ni
    |-> !ptw_active_o
);

// Additional checks can be written depending on the remaining internal logic and signals of the ptw module.



endmodule
// Copyright 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// - Matheus Cavalcante <matheusd@iis.ee.ethz.ch>
// - Andreas Kurth <akurth@iis.ee.ethz.ch>

`include "axi/typedef.svh"

module tb_axi_burst_undec #(
    // AXI Parameters
    parameter int unsigned TbAxiAddrWidth        = 64  ,
    parameter int unsigned TbAxiIdWidth          = 4   ,
    parameter int unsigned TbAxiSlvPortDataWidth = 128  ,
    parameter int unsigned TbAxiMstPortDataWidth = TbAxiSlvPortDataWidth  ,
    parameter int unsigned TbAxiUserWidth        = 8   ,
    // TB Parameters
    parameter time TbCyclTime                    = 10ns,
    parameter time TbApplTime                    = 2ns ,
    parameter time TbTestTime                    = 8ns
  );

  /*********************
   *  CLOCK GENERATOR  *
   *********************/

  logic clk;
  logic rst_n;
  logic eos;

  clk_rst_gen #(
    .ClkPeriod    (TbCyclTime),
    .RstClkCycles (5       )
  ) i_clk_rst_gen (
    .clk_o (clk  ),
    .rst_no(rst_n)
  );

  /*********
   *  AXI  *
   *********/
  typedef logic [TbAxiIdWidth-1:0] id_t;
  typedef logic [TbAxiAddrWidth-1:0] addr_t;
  typedef logic [TbAxiMstPortDataWidth-1:0] data_t;
  typedef logic [TbAxiMstPortDataWidth/8-1:0] strb_t;
  typedef logic [TbAxiUserWidth-1:0] user_t;

  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t)
  `AXI_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_resp_t, b_chan_t, r_chan_t)

  axi_req_t slv_req, mst_req;
  axi_resp_t slv_resp, mst_resp;

  /*********
   *  DUT  *
   *********/

  axi_burst_undec #(
    // the whole burst length in bit
    .TotalBurstLength ( 512 ),
    // AXI channel structs
    .aw_chan_t    ( aw_chan_t ),
    .w_chan_t     ( w_chan_t  ),
    .b_chan_t     ( b_chan_t  ),
    .ar_chan_t    ( ar_chan_t ),
    .r_chan_t     ( r_chan_t  ),
    // AXI request & response structs
    .axi_req_t     ( axi_req_t     ),
    .axi_resp_t    ( axi_resp_t    )
  ) i_dut (
    .clk_i        (clk     ),
    .rst_ni       (rst_n   ),
    // slave port
    .slv_req_i    (slv_req ),
    .slv_resp_o   (slv_resp ),
    // master port
    .mst_req_o    (mst_req),
    .mst_resp_i   (mst_resp)
  );

  /*************
   *  DRIVERS  *
   *************/

  initial begin
    slv_req  = '0;
    mst_resp = '0;
    # (TbCyclTime*11+TbCyclTime/2)
    slv_req.aw_valid = 1'b1;
    slv_req.aw.burst = 2'b11;
    # (TbCyclTime)
    slv_req.aw_valid = 1'b0;
    for(int i = 0; i < 4; i++) begin
      slv_req.w_valid = 1'b1;
      slv_req.w.data  = {64{i[1:0]}};
      if(i == 3) begin
        slv_req.w.last = 1'b1;
      end
      # (TbCyclTime);
    end

    # TbCyclTime
    slv_req.aw_valid  = 1'b0;
    slv_req.w_valid   = 1'b0;
    mst_resp.aw_ready = 1'b1;
    mst_resp.w_ready  = 1'b1;

    # (TbCyclTime*100)
    $finish;
  end

  /*************
   *  MONITOR  *
   *************/
// vsim -voptargs=+acc work.tb_axi_dw_upsizer
// 
endmodule

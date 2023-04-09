// Copyright (c) 2019 ETH Zurich and University of Bologna.
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
// - Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>
// - Andreas Kurth <akurth@iis.ee.ethz.ch>
// - Florian Zaruba <zarubaf@iis.ee.ethz.ch>

/// axi_xbar: Fully-connected AXI4+ATOP crossbar with an arbitrary number of slave and master ports.
/// See `doc/axi_xbar.md` for the documentation, including the definition of parameters and ports.
module axi_xbar
import cf_math_pkg::idx_width;
#(
  /// Configuration struct for the crossbar see `axi_pkg` for fields and definitions.
  parameter axi_pkg::xbar_cfg_t Cfg                                     = '0,
  /// Enable atomic operations support.
  parameter bit  ATOPs                                                  = 1'b1,
  /// Connectivity matrix
  parameter bit [Cfg.NumSlvPorts-1:0][Cfg.NumMstPorts-1:0] Connectivity = '1,
  /// AXI4+ATOP AW channel struct type for the slave ports.
  parameter type slv_aw_chan_t                                          = logic,
  /// AXI4+ATOP AW channel struct type for the master ports.
  parameter type mst_aw_chan_t                                          = logic,
  /// AXI4+ATOP W channel struct type for all ports.
  parameter type w_chan_t                                               = logic,
  /// AXI4+ATOP B channel struct type for the slave ports.
  parameter type slv_b_chan_t                                           = logic,
  /// AXI4+ATOP B channel struct type for the master ports.
  parameter type mst_b_chan_t                                           = logic,
  /// AXI4+ATOP AR channel struct type for the slave ports.
  parameter type slv_ar_chan_t                                          = logic,
  /// AXI4+ATOP AR channel struct type for the master ports.
  parameter type mst_ar_chan_t                                          = logic,
  /// AXI4+ATOP R channel struct type for the slave ports.
  parameter type slv_r_chan_t                                           = logic,
  /// AXI4+ATOP R channel struct type for the master ports.
  parameter type mst_r_chan_t                                           = logic,
  /// AXI4+ATOP request struct type for the slave ports.
  parameter type slv_port_axi_req_t                                     = logic,
  /// AXI4+ATOP response struct type for the slave ports.
  parameter type slv_port_axi_rsp_t                                     = logic,
  /// AXI4+ATOP request struct type for the master ports.
  parameter type mst_port_axi_req_t                                     = logic,
  /// AXI4+ATOP response struct type for the master ports
  parameter type mst_port_axi_rsp_t                                     = logic,
  /// Address rule type for the address decoders from `common_cells:addr_decode`.
  /// Example types are provided in `axi_pkg`.
  /// Required struct fields:
  /// ```
  /// typedef struct packed {
  ///   int unsigned idx;
  ///   axi_addr_t   start_addr;
  ///   axi_addr_t   end_addr;
  /// } rule_t;
  /// ```
  parameter type rule_t                                                 = axi_pkg::xbar_rule_64_t
`ifdef VCS
  , localparam int unsigned MstPortsIdxWidth =
      (Cfg.NumMstPorts == 32'd1) ? 32'd1 : unsigned'($clog2(Cfg.NumMstPorts))
`endif
) (
  /// Clock, positive edge triggered.
  input  logic                                                            clk_i,
  /// Asynchronous reset, active low.
  input  logic                                                            rst_ni,
  /// Testmode enable, active high.
  input  logic                                                            test_i,
  /// AXI4+ATOP requests to the slave ports.
  input  slv_port_axi_req_t [Cfg.NumSlvPorts-1:0]                         slv_ports_req_i,
  /// AXI4+ATOP responses of the slave ports.
  output slv_port_axi_rsp_t [Cfg.NumSlvPorts-1:0]                         slv_ports_rsp_o,
  /// AXI4+ATOP requests of the master ports.
  output mst_port_axi_req_t [Cfg.NumMstPorts-1:0]                         mst_ports_req_o,
  /// AXI4+ATOP responses to the master ports.
  input  mst_port_axi_rsp_t [Cfg.NumMstPorts-1:0]                         mst_ports_rsp_i,
  /// Address map array input for the crossbar. This map is global for the whole module.
  /// It is used for routing the transactions to the respective master ports.
  /// Each master port can have multiple different rules.
  input  rule_t     [Cfg.NumAddrRules-1:0]                                addr_map_i,
  /// Enable default master port.
  input  logic      [Cfg.NumSlvPorts-1:0]                                 en_default_mst_port_i,
`ifdef VCS
  /// Enables a default master port for each slave port. When this is enabled unmapped
  /// transactions get issued at the master port given by `default_mst_port_i`.
  /// When not used, tie to `'0`.
  input  logic      [Cfg.NumSlvPorts-1:0][MstPortsIdxWidth-1:0]           default_mst_port_i
`else
  /// Enables a default master port for each slave port. When this is enabled unmapped
  /// transactions get issued at the master port given by `default_mst_port_i`.
  /// When not used, tie to `'0`.
  input  logic      [Cfg.NumSlvPorts-1:0][idx_width(Cfg.NumMstPorts)-1:0] default_mst_port_i
`endif
);

  // Address tpye for inidvidual address signals
  typedef logic [Cfg.AddrWidth-1:0] addr_t;
  // to account for the decoding error slave
`ifdef VCS
  localparam int unsigned MstPortsIdxWidthOne =
      (Cfg.NumMstPorts == 32'd1) ? 32'd1 : unsigned'($clog2(Cfg.NumMstPorts + 1));
  typedef logic [MstPortsIdxWidthOne-1:0]           mst_port_idx_t;
`else
  typedef logic [idx_width(Cfg.NumMstPorts + 1)-1:0] mst_port_idx_t;
`endif

  // signals from the axi_demuxes, one index more for decode error
  slv_port_axi_req_t [Cfg.NumSlvPorts-1:0][Cfg.NumMstPorts:0]  slv_reqs;
  slv_port_axi_rsp_t [Cfg.NumSlvPorts-1:0][Cfg.NumMstPorts:0]  slv_rsps;

  // workaround for issue #133 (problem with vsim 10.6c)
  localparam int unsigned cfg_NumMstPorts = Cfg.NumMstPorts;

  // signals into the axi_muxes, are of type slave as the multiplexer extends the ID
  slv_port_axi_req_t [Cfg.NumMstPorts-1:0][Cfg.NumSlvPorts-1:0] mst_reqs;
  slv_port_axi_rsp_t [Cfg.NumMstPorts-1:0][Cfg.NumSlvPorts-1:0] mst_rsps;

  for (genvar i = 0; i < Cfg.NumSlvPorts; i++) begin : gen_slv_port_demux
`ifdef VCS
    logic [MstPortsIdxWidth-1:0]          dec_aw,        dec_ar;
`else
    logic [idx_width(Cfg.NumMstPorts)-1:0] dec_aw,        dec_ar;
`endif
    mst_port_idx_t                        slv_aw_select, slv_ar_select;
    logic                                 dec_aw_valid,  dec_aw_error;
    logic                                 dec_ar_valid,  dec_ar_error;

    addr_decode #(
      .NoIndices  ( Cfg.NumMstPorts  ),
      .NoRules    ( Cfg.NumAddrRules ),
      .addr_t     ( addr_t           ),
      .rule_t     ( rule_t           )
    ) i_axi_aw_decode (
      .addr_i           ( slv_ports_req_i[i].aw.addr ),
      .addr_map_i       ( addr_map_i                 ),
      .idx_o            ( dec_aw                     ),
      .dec_valid_o      ( dec_aw_valid               ),
      .dec_error_o      ( dec_aw_error               ),
      .en_default_idx_i ( en_default_mst_port_i[i]   ),
      .default_idx_i    ( default_mst_port_i[i]      )
    );

    addr_decode #(
      .NoIndices  ( Cfg.NumMstPorts  ),
      .addr_t     ( addr_t           ),
      .NoRules    ( Cfg.NumAddrRules ),
      .rule_t     ( rule_t           )
    ) i_axi_ar_decode (
      .addr_i           ( slv_ports_req_i[i].ar.addr ),
      .addr_map_i       ( addr_map_i                 ),
      .idx_o            ( dec_ar                     ),
      .dec_valid_o      ( dec_ar_valid               ),
      .dec_error_o      ( dec_ar_error               ),
      .en_default_idx_i ( en_default_mst_port_i[i]   ),
      .default_idx_i    ( default_mst_port_i[i]      )
    );

    assign slv_aw_select = (dec_aw_error) ?
        mst_port_idx_t'(Cfg.NumMstPorts) : mst_port_idx_t'(dec_aw);
    assign slv_ar_select = (dec_ar_error) ?
        mst_port_idx_t'(Cfg.NumMstPorts) : mst_port_idx_t'(dec_ar);

    // make sure that the default slave does not get changed, if there is an unserved Ax
    // pragma translate_off
    `ifndef VERILATOR
    `ifndef XSIM
    default disable iff (~rst_ni);
    default_aw_mst_port_en: assert property(
      @(posedge clk_i) (slv_ports_req_i[i].aw_valid && !slv_ports_rsp_o[i].aw_ready)
          |=> $stable(en_default_mst_port_i[i]))
        else $fatal (1, $sformatf("It is not allowed to change the default mst port\
                                   enable, when there is an unserved Aw beat. Slave Port: %0d", i));
    default_aw_mst_port: assert property(
      @(posedge clk_i) (slv_ports_req_i[i].aw_valid && !slv_ports_rsp_o[i].aw_ready)
          |=> $stable(default_mst_port_i[i]))
        else $fatal (1, $sformatf("It is not allowed to change the default mst port\
                                   when there is an unserved Aw beat. Slave Port: %0d", i));
    default_ar_mst_port_en: assert property(
      @(posedge clk_i) (slv_ports_req_i[i].ar_valid && !slv_ports_rsp_o[i].ar_ready)
          |=> $stable(en_default_mst_port_i[i]))
        else $fatal (1, $sformatf("It is not allowed to change the enable, when\
                                   there is an unserved Ar beat. Slave Port: %0d", i));
    default_ar_mst_port: assert property(
      @(posedge clk_i) (slv_ports_req_i[i].ar_valid && !slv_ports_rsp_o[i].ar_ready)
          |=> $stable(default_mst_port_i[i]))
        else $fatal (1, $sformatf("It is not allowed to change the default mst port\
                                   when there is an unserved Ar beat. Slave Port: %0d", i));
    `endif
    `endif
    // pragma translate_on
    axi_demux #(
      .IdWidth        ( Cfg.IdWidthSlvPorts ),  // ID Width
      .AtopSupport    ( ATOPs               ),
      .aw_chan_t      ( slv_aw_chan_t       ),  // AW Channel Type
      .w_chan_t       ( w_chan_t            ),  //  W Channel Type
      .b_chan_t       ( slv_b_chan_t        ),  //  B Channel Type
      .ar_chan_t      ( slv_ar_chan_t       ),  // AR Channel Type
      .r_chan_t       ( slv_r_chan_t        ),  //  R Channel Type
      .axi_req_t      ( slv_port_axi_req_t  ),
      .axi_rsp_t      ( slv_port_axi_rsp_t  ),
      .NumMstPorts    ( Cfg.NumMstPorts + 1 ),
      .MaxTrans       ( Cfg.MaxMstTrans     ),
      .LookBits       ( Cfg.IdUsedSlvPorts  ),
      .UniqueIds      ( Cfg.UniqueIds       ),
      .SpillAw        ( Cfg.LatencyMode[9]  ),
      .SpillW         ( Cfg.LatencyMode[8]  ),
      .SpillB         ( Cfg.LatencyMode[7]  ),
      .SpillAr        ( Cfg.LatencyMode[6]  ),
      .SpillR         ( Cfg.LatencyMode[5]  )
    ) i_axi_demux (
      .clk_i,   // Clock
      .rst_ni,  // Asynchronous reset active low
      .test_i,  // Testmode enable
      .slv_req_i       ( slv_ports_req_i[i] ),
      .slv_aw_select_i ( slv_aw_select      ),
      .slv_ar_select_i ( slv_ar_select      ),
      .slv_rsp_o       ( slv_ports_rsp_o[i] ),
      .mst_reqs_o      ( slv_reqs[i]        ),
      .mst_rsps_i      ( slv_rsps[i]        )
    );

    axi_err_slv #(
      .IdWidth     ( Cfg.IdWidthSlvPorts  ),
      .axi_req_t   ( slv_port_axi_req_t   ),
      .axi_rsp_t   ( slv_port_axi_rsp_t   ),
      .Resp        ( axi_pkg::RESP_DECERR ),
      .ATOPs       ( ATOPs                ),
      .MaxTrans    ( 4                    )   // Transactions terminate at this slave, so minimize
                                                // resource consumption by accepting only a few
                                                // transactions at a time.
    ) i_axi_err_slv (
      .clk_i,   // Clock
      .rst_ni,  // Asynchronous reset active low
      .test_i,  // Testmode enable
      // slave port
      .slv_req_i ( slv_reqs[i][Cfg.NumMstPorts]   ),
      .slv_rsp_o ( slv_rsps[i][cfg_NumMstPorts]  )
    );
  end

  // cross all channels
  for (genvar i = 0; i < Cfg.NumSlvPorts; i++) begin : gen_xbar_slv_cross
    for (genvar j = 0; j < Cfg.NumMstPorts; j++) begin : gen_xbar_mst_cross
      if (Connectivity[i][j]) begin : gen_connection
        axi_multicut #(
          .NumCuts   ( Cfg.PipelineStages ),
          .aw_chan_t ( slv_aw_chan_t      ),
          .w_chan_t  ( w_chan_t           ),
          .b_chan_t  ( slv_b_chan_t       ),
          .ar_chan_t ( slv_ar_chan_t      ),
          .r_chan_t  ( slv_r_chan_t       ),
          .axi_req_t ( slv_port_axi_req_t ),
          .axi_rsp_t ( slv_port_axi_rsp_t )
        ) i_axi_multicut_xbar_pipeline (
          .clk_i,
          .rst_ni,
          .slv_req_i ( slv_reqs[i][j] ),
          .slv_rsp_o ( slv_rsps[i][j] ),
          .mst_req_o ( mst_reqs[j][i] ),
          .mst_rsp_i ( mst_rsps[j][i] )
        );

      end else begin : gen_no_connection
        assign mst_reqs[j][i] = '0;
        axi_err_slv #(
          .IdWidth   ( Cfg.IdWidthSlvPorts  ),
          .axi_req_t ( slv_port_axi_req_t   ),
          .axi_rsp_t ( slv_port_axi_rsp_t   ),
          .Resp      ( axi_pkg::RESP_DECERR ),
          .ATOPs     ( ATOPs                ),
          .MaxTrans  ( 1                    )
        ) i_axi_err_slv (
          .clk_i,
          .rst_ni,
          .test_i,
          .slv_req_i ( slv_reqs[i][j] ),
          .slv_rsp_o ( slv_rsps[i][j] )
        );
      end
    end
  end

  for (genvar i = 0; i < Cfg.NumMstPorts; i++) begin : gen_mst_port_mux
    axi_mux #(
      .SlvIDWidth         ( Cfg.IdWidthSlvPorts ), // ID width of the slave ports
      .slv_aw_chan_t      ( slv_aw_chan_t       ), // AW Channel Type, slave ports
      .mst_aw_chan_t      ( mst_aw_chan_t       ), // AW Channel Type, master port
      .w_chan_t           ( w_chan_t            ), //  W Channel Type, all ports
      .slv_b_chan_t       ( slv_b_chan_t        ), //  B Channel Type, slave ports
      .mst_b_chan_t       ( mst_b_chan_t        ), //  B Channel Type, master port
      .slv_ar_chan_t      ( slv_ar_chan_t       ), // AR Channel Type, slave ports
      .mst_ar_chan_t      ( mst_ar_chan_t       ), // AR Channel Type, master port
      .slv_r_chan_t       ( slv_r_chan_t        ), //  R Channel Type, slave ports
      .mst_r_chan_t       ( mst_r_chan_t        ), //  R Channel Type, master port
      .slv_port_axi_req_t ( slv_port_axi_req_t  ),
      .slv_port_axi_rsp_t ( slv_port_axi_rsp_t  ),
      .mst_port_axi_req_t ( mst_port_axi_req_t  ),
      .mst_port_axi_rsp_t ( mst_port_axi_rsp_t  ),
      .NumSlvPorts        ( Cfg.NumSlvPorts     ), // Number of Masters for the module
      .MaxWTrans          ( Cfg.MaxSlvTrans     ),
      .FallThrough        ( Cfg.FallThrough     ),
      .SpillAw            ( Cfg.LatencyMode[4]  ),
      .SpillW             ( Cfg.LatencyMode[3]  ),
      .SpillB             ( Cfg.LatencyMode[2]  ),
      .SpillAr            ( Cfg.LatencyMode[1]  ),
      .SpillR             ( Cfg.LatencyMode[0]  )
    ) i_axi_mux (
      .clk_i,   // Clock
      .rst_ni,  // Asynchronous reset active low
      .test_i,  // Test Mode enable
      .slv_reqs_i ( mst_reqs[i]        ),
      .slv_rsps_o ( mst_rsps[i]        ),
      .mst_req_o  ( mst_ports_req_o[i] ),
      .mst_rsp_i  ( mst_ports_rsp_i[i] )
    );
  end

  // pragma translate_off
  `ifndef VERILATOR
  `ifndef XSIM
  initial begin : check_params
    id_slv_req_ports: assert ($bits(slv_ports_req_i[0].aw.id ) == Cfg.IdWidthSlvPorts) else
      $fatal(1, $sformatf("Slv_req and aw_chan id width not equal."));
    id_slv_rsp_ports: assert ($bits(slv_ports_rsp_o[0].r.id) == Cfg.IdWidthSlvPorts) else
      $fatal(1, $sformatf("Slv_req and aw_chan id width not equal."));
  end
  `endif
  `endif
  // pragma translate_on
endmodule

`include "axi/assign.svh"
`include "axi/typedef.svh"

module axi_xbar_intf
import cf_math_pkg::idx_width;
#(
  parameter int unsigned AXI_USER_WIDTH =  0,
  parameter axi_pkg::xbar_cfg_t Cfg     = '0,
  parameter bit ATOPS                   = 1'b1,
  parameter bit [Cfg.NumSlvPorts-1:0][Cfg.NumMstPorts-1:0] CONNECTIVITY = '1,
  parameter type rule_t                 = axi_pkg::xbar_rule_64_t
`ifdef VCS
  , localparam int unsigned MstPortsIdxWidth =
        (Cfg.NumMstPorts == 32'd1) ? 32'd1 : unsigned'($clog2(Cfg.NumMstPorts))
`endif
) (
  input  logic                                                      clk_i,
  input  logic                                                      rst_ni,
  input  logic                                                      test_i,
  AXI_BUS.Slave                                                     slv_ports [Cfg.NumSlvPorts-1:0],
  AXI_BUS.Master                                                    mst_ports [Cfg.NumMstPorts-1:0],
  input  rule_t [Cfg.NumAddrRules-1:0]                               addr_map_i,
  input  logic  [Cfg.NumSlvPorts-1:0]                                en_default_mst_port_i,
`ifdef VCS
  input  logic  [Cfg.NumSlvPorts-1:0][MstPortsIdxWidth-1:0]          default_mst_port_i
`else
  input  logic  [Cfg.NumSlvPorts-1:0][idx_width(Cfg.NumMstPorts)-1:0] default_mst_port_i
`endif
);

  localparam int unsigned IdWidthMstPorts = Cfg.IdWidthSlvPorts + $clog2(Cfg.NumSlvPorts);

  typedef logic [IdWidthMstPorts     -1:0] id_mst_t;
  typedef logic [Cfg.IdWidthSlvPorts -1:0] id_slv_t;
  typedef logic [Cfg.AddrWidth       -1:0] addr_t;
  typedef logic [Cfg.DataWidth       -1:0] data_t;
  typedef logic [Cfg.DataWidth/8     -1:0] strb_t;
  typedef logic [AXI_USER_WIDTH      -1:0] user_t;

  `AXI_TYPEDEF_AW_CHAN_T(mst_aw_chan_t, addr_t, id_mst_t, user_t)
  `AXI_TYPEDEF_AW_CHAN_T(slv_aw_chan_t, addr_t, id_slv_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(mst_b_chan_t, id_mst_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(slv_b_chan_t, id_slv_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(mst_ar_chan_t, addr_t, id_mst_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(slv_ar_chan_t, addr_t, id_slv_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(mst_r_chan_t, data_t, id_mst_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(slv_r_chan_t, data_t, id_slv_t, user_t)
  `AXI_TYPEDEF_REQ_T(mst_port_axi_req_t, mst_aw_chan_t, w_chan_t, mst_ar_chan_t)
  `AXI_TYPEDEF_REQ_T(slv_port_axi_req_t, slv_aw_chan_t, w_chan_t, slv_ar_chan_t)
  `AXI_TYPEDEF_RSP_T(mst_port_axi_rsp_t, mst_b_chan_t, mst_r_chan_t)
  `AXI_TYPEDEF_RSP_T(slv_port_axi_rsp_t, slv_b_chan_t, slv_r_chan_t)

  mst_port_axi_req_t  [Cfg.NumMstPorts-1:0]  mst_reqs;
  mst_port_axi_rsp_t  [Cfg.NumMstPorts-1:0]  mst_rsps;
  slv_port_axi_req_t  [Cfg.NumSlvPorts-1:0]  slv_reqs;
  slv_port_axi_rsp_t  [Cfg.NumSlvPorts-1:0]  slv_rsps;

  for (genvar i = 0; i < Cfg.NumMstPorts; i++) begin : gen_assign_mst
    `AXI_ASSIGN_FROM_REQ(mst_ports[i], mst_reqs[i])
    `AXI_ASSIGN_TO_RSP(mst_rsps[i], mst_ports[i])
  end

  for (genvar i = 0; i < Cfg.NumSlvPorts; i++) begin : gen_assign_slv
    `AXI_ASSIGN_TO_REQ(slv_reqs[i], slv_ports[i])
    `AXI_ASSIGN_FROM_RSP(slv_ports[i], slv_rsps[i])
  end

  axi_xbar #(
    .Cfg  (Cfg),
    .ATOPs              ( ATOPS              ),
    .Connectivity       ( CONNECTIVITY       ),
    .slv_aw_chan_t      ( slv_aw_chan_t      ),
    .mst_aw_chan_t      ( mst_aw_chan_t      ),
    .w_chan_t           ( w_chan_t           ),
    .slv_b_chan_t       ( slv_b_chan_t       ),
    .mst_b_chan_t       ( mst_b_chan_t       ),
    .slv_ar_chan_t      ( slv_ar_chan_t      ),
    .mst_ar_chan_t      ( mst_ar_chan_t      ),
    .slv_r_chan_t       ( slv_r_chan_t       ),
    .mst_r_chan_t       ( mst_r_chan_t       ),
    .slv_port_axi_req_t ( slv_port_axi_req_t ),
    .slv_port_axi_rsp_t ( slv_port_axi_rsp_t ),
    .mst_port_axi_req_t ( mst_port_axi_req_t ),
    .mst_port_axi_rsp_t ( mst_port_axi_rsp_t ),
    .rule_t             ( rule_t             )
  ) i_xbar (
    .clk_i,
    .rst_ni,
    .test_i,
    .slv_ports_req_i (slv_reqs),
    .slv_ports_rsp_o (slv_rsps),
    .mst_ports_req_o (mst_reqs),
    .mst_ports_rsp_i (mst_rsps),
    .addr_map_i,
    .en_default_mst_port_i,
    .default_mst_port_i
  );

endmodule

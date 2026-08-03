`timescale 1ns/1ps

package transaction_pkg;

    //============================================================
    // Global Parameters
    //============================================================

    parameter int DATA_WIDTH         = 32;
    parameter int BALANCE_WIDTH      = 16;
    parameter int PRODUCT_ID_WIDTH   = 5;
    parameter int PAYMENT_WIDTH      = 3;
    parameter int STATUS_WIDTH       = 4;
    parameter int ERROR_WIDTH        = 8;
    parameter int TRANSACTION_WIDTH  = 16;

    parameter int PRODUCT_COUNT      = 5;
    parameter int INVENTORY_WIDTH    = 8;
    parameter int PRICE_WIDTH        = 16;
    parameter int CRC_WIDTH          = 8;

    //============================================================
    // Payment Types
    //============================================================

    typedef enum logic [PAYMENT_WIDTH-1:0]
    {
        COIN   = 3'd0,
        NOTE   = 3'd1,
        RFID   = 3'd2,
        CARD   = 3'd3,
        UPI    = 3'd4,
        WALLET = 3'd5
    } payment_t;

    //============================================================
    // Controller States
    //============================================================

    typedef enum logic [4:0]
    {
        IDLE,
        RECEIVE_PAYMENT,
        AUTHENTICATE,
        CHECK_BALANCE,
        CHECK_INVENTORY,
        DISPENSE,
        REFUND,
        COMPLETE,
        ERROR_STATE
    } state_t;

    //============================================================
    // Status Codes
    //============================================================

    typedef enum logic [STATUS_WIDTH-1:0]
    {
        STATUS_IDLE,
        STATUS_BUSY,
        STATUS_SUCCESS,
        STATUS_FAILED,
        STATUS_TIMEOUT,
        STATUS_CANCELLED
    } status_t;

    //============================================================
    // Error Codes
    //============================================================

    typedef enum logic [ERROR_WIDTH-1:0]
    {
        ERR_NONE,
        ERR_TIMEOUT,
        ERR_INVALID_PRODUCT,
        ERR_CRC,
        ERR_AUTH,
        ERR_BALANCE,
        ERR_STOCK,
        ERR_DUPLICATE
    } error_t;

    //============================================================
    // Command Types
    //============================================================

    typedef enum logic [2:0]
    {
        CMD_PAYMENT,
        CMD_PURCHASE,
        CMD_REFUND,
        CMD_CANCEL,
        CMD_STATUS
    } command_t;

    //============================================================
    // Payment Request
    //============================================================

    typedef struct packed
    {
        payment_t                           payment_type;
        logic [BALANCE_WIDTH-1:0]           amount;
        logic [PRODUCT_ID_WIDTH-1:0]        product_id;
    } payment_request_t;

    //============================================================
    // Transaction Packet
    //============================================================

    typedef struct packed
    {
        payment_t                           payment_type;
        logic [BALANCE_WIDTH-1:0]           amount;
        logic [PRODUCT_ID_WIDTH-1:0]        product_id;
        logic [TRANSACTION_WIDTH-1:0]       transaction_id;
        //logic [CRC_WIDTH-1:0]               crc;
        logic [7:0] crc;
    } transaction_packet_t;

    //============================================================
    // Response Packet
    //============================================================

    typedef struct packed
    {
        status_t                            status;
        error_t                             error;
        logic [BALANCE_WIDTH-1:0]           refund;
        logic                               dispense;
    } response_packet_t;

    //============================================================
    // Inventory Entry
    //============================================================

    typedef struct packed
    {
        logic [PRICE_WIDTH-1:0]             price;
        logic [INVENTORY_WIDTH-1:0]         quantity;
    } inventory_entry_t;

endpackage
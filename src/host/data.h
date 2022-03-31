#ifndef PORT_H
#define PORT_H

#include <cstdint>
#include <ap_axi_sdata.h>
#include <ap_int.h>
#include <hls_stream.h>

#define CN_SIZE            128  // Buffer lenght of input and output data
#define CN_IN_WIDTH       2216  // Bit-width of input data (size of each buffer entry)
#define CN_OUT_WIDTH       256  // Bit-width of output data (size of each buffer entry)
#define CN_STREAM_WIDTH      8  // Each input buffer entry transfer is divided into this wide chunks

typedef ap_axiu<CN_STREAM_WIDTH, 0, 0, 0> pkt;

#endif
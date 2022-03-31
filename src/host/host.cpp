#include "cmdlineparser.h"
#include <iostream>
#include <cstring>

// XRT includes
#include "experimental/xrt_bo.h"
#include "experimental/xrt_device.h"
#include "experimental/xrt_kernel.h"

#include "data.h"
#include "interface.h"

#define KB 1024
#define MB (1024 * KB)
#define GB (1024UL * MB)

int main(int argc, char** argv) {

  // Command Line Arguments
  sda::utils::CmdLineParser parser;
  parser.addSwitch("--xclbin_file", "-x", "input binary file string", "");
  parser.addSwitch("--device_id", "-d", "device index", "0");
  parser.parse(argc, argv);

  // Read settings
  std::string binaryFile = parser.value("xclbin_file");
  int device_index = stoi(parser.value("device_id"));

  if (argc < 3) {
    parser.printHelp();
    return EXIT_FAILURE;
  }

  std::cout << "Open the device " << device_index << std::endl;
  auto device = xrt::device(device_index);
  std::cout << "Load the xclbin " << binaryFile << std::endl;
  auto uuid = device.load_xclbin(binaryFile);

  auto cn = xrt::kernel(device, uuid, "cryptonight:{cryptonight_1}", xrt::kernel::cu_access_mode::exclusive);

  std::cout << "Start Alloc" << std::endl;

  size_t hbm_size_bytes = 1*GB;
  auto hbm = xrt::bo(device, hbm_size_bytes, cn.group_id(0));
  uint64_t hbm_address = hbm.address();
  std::cout << "  hbm_address " << hbm_address << cn.read_register(CSR0) << std::endl;

  // Launch the cryptonight Kernel
  std::cout << "Launching cryptonight Kernel..." << std::endl;

  cn.write_register(HBML, hbm_address    );
  cn.write_register(HBMH, hbm_address>>32);
  // cn.write_register(HBML, 0);
  // cn.write_register(HBMH, 0);
  // cn.write_register(CSR0, 0);
  // cn.write_register(CSR1, 0);
  // cn.write_register(CSR2, 0);
  // cn.write_register(CSR3, 0);

  cn.write_register(CTRL, IP_START);

  std::cout << "  Launched." << std::endl;

  std::cout << "Press a Key for Submitting Exit to Kernel..." << std::endl;
  getchar();
  
  cn.write_register(CSR0, 1);

  auto axi_ctrl = 0;
  while ((axi_ctrl & IP_IDLE) != IP_IDLE) {
    axi_ctrl = cn.read_register(CTRL);
  }

  printf("CSR0: %08X\n", cn.read_register(CSR0));
  printf("CSR1: %08X\n", cn.read_register(CSR1));
  printf("CSR2: %08X\n", cn.read_register(CSR2));
  printf("CSR3: %08X\n", cn.read_register(CSR3));
  printf("CSR4: %08X\n", cn.read_register(CSR4));
  printf("CSR5: %08X\n", cn.read_register(CSR5));
  printf("CSR6: %08X\n", cn.read_register(CSR6));
  printf("CSR7: %08X\n", cn.read_register(CSR7));

  std::cout << "  Exited..." << std::endl;

  return EXIT_SUCCESS;
}

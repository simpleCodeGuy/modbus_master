/// This example sends 5 read commands
/// - Read Holding Register 6001
/// - Read Holding Register 6002
/// - Read Holding Register 6003
/// - Read Holding Register 6004
/// - Read Holding Register 6005

import 'package:modbus_master/modbus_master.dart';

void main() async {
  final modbusMaster = await ModbusMaster.start();

  int countResponseReceived = 0;
  modbusMaster.responseFromSlaveDevices.listen(
    (response) {
      ++countResponseReceived;
      print(response);

      if (countResponseReceived >= 5) {
        modbusMaster.stop();
      }
    },
  );

  for (int i = 1; i <= 5; ++i) {
    try {
      modbusMaster.read(
        ipAddress: '192.168.29.163', // change it as per your slave device
        portNumber: 502, // change it as per your slave device
        unitId: 1, // change it as per your slave device
        blockNumber: 4, // block number 4 means Holding Register
        elementNumber: 6000 + i,
        timeoutMilliseconds: 1000,
      );
    } catch (e, f) {
      print('EXCEPTION THROWN:-\n$e\n$f');
    }
    await Future.delayed(Duration(seconds: 2));
  }

  //  * Program must not be exited or killed immediately after this stop method.
  //    It takes sometime to close all resources including TCP sockets.
  //
  //  * Immediate exiting or killing program after stop method
  //    risk of program exit with open TCP socket.
  //
  //  * Programmer should use isStoppedAsync to know whether object has stopped.
  //    If isStoppedAsync returns Future of True, then program can be safely
  //    exited.
  final isModbusMasterStopped = await modbusMaster.isStoppedAsync;
  if (isModbusMasterStopped) {
    print("Modbus Master has stopped. Now, program can be safely exited.");
  } else {
    print("Modbus master has not stopped.");
  }
}

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
        ipAddress: '192.168.1.3',
        portNumber: 502,
        unitId: 1,
        blockNumber: 3, // FOR INPUT REGISTER, BLOCK NUMBER = 3
        elementNumber: 1,
        timeoutMilliseconds: 1000,
      );
    } catch (e, f) {
      print('EXCEPTION THROWN:-\n$e\n$f');
    }
    await Future.delayed(Duration(seconds: 2));
  }

  final isModbusMasterStopped = await modbusMaster.isStoppedAsync;
  if (isModbusMasterStopped) {
    print("Modbus Master has stopped.");
  }
}

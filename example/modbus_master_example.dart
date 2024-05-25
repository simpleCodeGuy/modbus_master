import 'package:modbus_master/modbus_master.dart';

void main() {
  testReadingCoil();
}

void testReadingCoil() async {
  final modbusMaster = await ModbusMaster.start();

  int countResponseReceived = 0;
  modbusMaster.responses().listen(
    (response) {
      ++countResponseReceived;
      print(response);
      if (countResponseReceived >= 3) {
        modbusMaster.close();
      }
    },
  );

  for (int i = 1; i <= 5; ++i) {
    print('-> Request $i');
    try {
      modbusMaster.readCoil(
        ipv4: '192.168.1.5',
        portNo: 502,
        elementNumberOneTo65536: 11,
      );
    } catch (e) {
      print('EXCEPTION THROWN WHILE READING $e');
    }
    await Future.delayed(Duration(seconds: 5));
  }
}

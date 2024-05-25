import 'package:modbus_master/modbus_master.dart';
import 'package:test/test.dart';

void main() {
  group('ModbusMaster object instantiation and closing', () {
    test(
        'GIVEN: a variable of type ModbusMaster, '
        'WHEN: it is instantiated using ModbusMaster, '
        'THEN: it should throw exception\n', () {
      void procedureWhichThrowsException() {
        ModbusMaster modbusMaster = ModbusMaster();
      }

      expect(procedureWhichThrowsException, throwsException);
    });

    test(
        'GIVEN: a variable of type ModbusMaster, '
        'WHEN: it is instantiated using await ModbusMaster.start(), '
        'THEN: it should return an object of ModbusMaster\n', () async {
      ModbusMaster modbusMaster = await ModbusMaster.start();

      expect(modbusMaster, isA<ModbusMaster>());

      modbusMaster.close();

      await Future.delayed(Duration(seconds: 2));
    });

    test(
        'GIVEN: a closed object of ModbusMaster,'
        'WHEN: read coil command is given,'
        'THEN: it throws exception\n', () async {
      void procedureWhichThrowsException() async {
        ModbusMaster modbusMaster = await ModbusMaster.start();
        modbusMaster.close();
        modbusMaster.readCoil(ipv4: '192.168.1.5', elementNumberOneTo65536: 1);
      }

      expect(procedureWhichThrowsException, throwsException);
    });
  });
}

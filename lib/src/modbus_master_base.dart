import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:async';

import 'package:equatable/equatable.dart';

enum ReadWrite {
  read,
  write,
}

enum ElementType {
  discreteInput,
  coil,
  inputRegister,
  holdingRegister,
}

typedef Address = ({
  String ip,
  int port,
});

typedef RequestWithTimeStamp = ({
  ModbusRequestData modbusRequestData,
  DateTime timeStampWhenSentToSlave,
});
typedef TransactionId = int;

typedef AddressAndTransactionId = ({
  Address address,
  TransactionId transactionId
});

extension IntegerExtension on int {
  Uint8List get toUint8List1byte {
    return Uint8List.fromList(<int>[this]);
  }

  Uint8List get toUint8List2bytes {
    int msb = this ~/ 256;
    return Uint8List.fromList(<int>[msb, this]);
  }
}

extension Uint8ListExtension on Uint8List {
  int get convertFirstTwoElementsToInteger {
    int msbInteger = this[0];
    int lsbInteger = this[1];

    return msbInteger * 256 + lsbInteger;
  }
}

typedef ModbusBlockIdPartII = ({
  ReadWrite readWrite,
  ElementType elementType,
  int elementNumber,
});

class ModbusBlockId extends Equatable {
  final String ip;
  final int port;
  final ReadWrite readWrite;
  final ElementType elementType;
  final int elementNumber;

  const ModbusBlockId({
    required this.ip,
    required this.port,
    required this.readWrite,
    required this.elementType,
    required this.elementNumber,
  });

  @override
  List<Object> get props => [ip, port, readWrite, elementType, elementNumber];

  static ModbusBlockId from({
    required Address address,
    required ModbusBlockIdPartII modbusBlockIdPartII,
  }) {
    return ModbusBlockId(
      ip: address.ip,
      port: address.port,
      readWrite: modbusBlockIdPartII.readWrite,
      elementType: modbusBlockIdPartII.elementType,
      elementNumber: modbusBlockIdPartII.elementNumber,
    );
  }

  ModbusBlockIdPartII get modbusBlockIdPartII {
    return (
      elementNumber: elementNumber,
      elementType: elementType,
      readWrite: readWrite,
    );
  }

  Address address() {
    Address address = (ip: ip, port: port);
    return address;
  }

  @override
  String toString() {
    return 'ip=$ip, port=$port, ${readWrite == ReadWrite.read ? 'READ' : 'WRITE'}, '
        '${elementTypeString[elementType]}, elementNumber=$elementNumber';
  }
}

Map<ElementType, String> elementTypeString = {
  ElementType.coil: 'COIL',
  ElementType.discreteInput: 'DISCRETE INPUT',
  ElementType.holdingRegister: 'HOLDING REGISTER',
  ElementType.inputRegister: 'INPUT REGISTER',
};

class Request {
  final ModbusBlockId modbusBlockId;
  final Duration timeout;
  final dynamic writeData;
  static const maximumElementNumber = 65536;
  static const maximumUnsignedIntegerValue16bitRegister = 65535;
  static const defaultTimeout = Duration(seconds: 1);

  const Request({
    required this.modbusBlockId,
    required this.writeData,
    required this.timeout,
  });

  @override
  String toString() {
    String writeDataString =
        writeData == null ? '' : 'valueToBeWritten:$writeData';
    return '-> Request: $modbusBlockId $writeDataString';
  }

  Address address() => modbusBlockId.address();

  static Request fromReadCoilValues({
    required String ipv4,
    required int port,
    required int elementNumberFrom1To65536,
    Duration timeout = Request.defaultTimeout,
  }) {
    if (elementNumberFrom1To65536 < 1 ||
        elementNumberFrom1To65536 > Request.maximumElementNumber) {
      throw Exception('element number should be from 1 to 65536.');
    }

    return Request(
      modbusBlockId: ModbusBlockId(
        ip: ipv4,
        port: port,
        readWrite: ReadWrite.read,
        elementType: ElementType.coil,
        elementNumber: elementNumberFrom1To65536,
      ),
      writeData: null,
      timeout: timeout,
    );
  }

  static Request fromReadDiscreteInputValues({
    required String ipv4,
    required int port,
    required int elementNumberFrom1To65536,
    Duration timeout = Request.defaultTimeout,
  }) {
    if (elementNumberFrom1To65536 < 1 ||
        elementNumberFrom1To65536 > Request.maximumElementNumber) {
      throw Exception('element number should be from 1 to 65536.');
    }

    return Request(
      modbusBlockId: ModbusBlockId(
        ip: ipv4,
        port: port,
        readWrite: ReadWrite.read,
        elementType: ElementType.discreteInput,
        elementNumber: elementNumberFrom1To65536,
      ),
      writeData: null,
      timeout: timeout,
    );
  }

  static Request fromReadHoldingRegisterValues({
    required String ipv4,
    required int port,
    required int elementNumberFrom1To65536,
    Duration timeout = Request.defaultTimeout,
  }) {
    if (elementNumberFrom1To65536 < 1 ||
        elementNumberFrom1To65536 > Request.maximumElementNumber) {
      throw Exception('element number should be from 1 to 65536.');
    }

    return Request(
      modbusBlockId: ModbusBlockId(
        ip: ipv4,
        port: port,
        readWrite: ReadWrite.read,
        elementType: ElementType.holdingRegister,
        elementNumber: elementNumberFrom1To65536,
      ),
      writeData: null,
      timeout: timeout,
    );
  }

  static Request fromReadInputRegisterValues({
    required String ipv4,
    required int port,
    required int elementNumberFrom1To65536,
    Duration timeout = Request.defaultTimeout,
  }) {
    if (elementNumberFrom1To65536 < 1 ||
        elementNumberFrom1To65536 > Request.maximumElementNumber) {
      throw Exception('element number should be from 1 to 65536.');
    }

    return Request(
      modbusBlockId: ModbusBlockId(
        ip: ipv4,
        port: port,
        readWrite: ReadWrite.read,
        elementType: ElementType.inputRegister,
        elementNumber: elementNumberFrom1To65536,
      ),
      writeData: null,
      timeout: timeout,
    );
  }

  static Request fromWriteCoilValues({
    required String ipv4,
    required int port,
    required int elementNumberFrom1To65536,
    required bool valueToBeWritten,
    Duration timeout = Request.defaultTimeout,
  }) {
    if (elementNumberFrom1To65536 < 1 ||
        elementNumberFrom1To65536 > Request.maximumElementNumber) {
      throw Exception('element number should be from 1 to 65536.');
    }

    return Request(
      modbusBlockId: ModbusBlockId(
        ip: ipv4,
        port: port,
        readWrite: ReadWrite.write,
        elementType: ElementType.coil,
        elementNumber: elementNumberFrom1To65536,
      ),
      writeData: valueToBeWritten,
      timeout: timeout,
    );
  }

  static Request fromWriteHoldingRegisterValues({
    required String ipv4,
    required int port,
    required int elementNumberFrom1To65536,
    required int valueToBeWritten,
    Duration timeout = Request.defaultTimeout,
  }) {
    if (elementNumberFrom1To65536 < 1 ||
        elementNumberFrom1To65536 > Request.maximumElementNumber) {
      throw Exception('element number should be from 1 to 65536.');
    }

    if (valueToBeWritten < 0 ||
        valueToBeWritten > Request.maximumUnsignedIntegerValue16bitRegister) {
      throw Exception('value to be written should be from 0 to 65535.');
    }

    return Request(
      modbusBlockId: ModbusBlockId(
        ip: ipv4,
        port: port,
        readWrite: ReadWrite.write,
        elementType: ElementType.holdingRegister,
        elementNumber: elementNumberFrom1To65536,
      ),
      writeData: valueToBeWritten,
      timeout: timeout,
    );
  }
}

class ReadData extends Equatable {
  const ReadData();

  @override
  List<Object> get props => [];
}

class ReadDataNotAvailable extends ReadData {
  const ReadDataNotAvailable();

  @override
  List<Object> get props => [];
}

class ReadDataInteger extends ReadData {
  final int value;
  const ReadDataInteger(this.value);

  @override
  List<Object> get props => [value];
}

class ReadDataBoolean extends ReadData {
  final bool value;
  const ReadDataBoolean(this.value);

  @override
  List<Object> get props => [value];
}

class Response extends Equatable {
  final ModbusBlockId modbusBlockId;
  final bool isSuccess;
  final ReadData readData;
  final int transactionId;

  const Response({
    required this.modbusBlockId,
    required this.isSuccess,
    required this.readData,
    required this.transactionId,
  });

  @override
  List<Object> get props {
    if (readData.runtimeType == ReadDataBoolean) {
      return modbusBlockId.props +
          [isSuccess, (readData as ReadDataBoolean).value, transactionId];
    } else if (readData.runtimeType == ReadDataInteger) {
      return modbusBlockId.props +
          [isSuccess, (readData as ReadDataInteger).value, transactionId];
    } else {
      return modbusBlockId.props + [isSuccess, Null, transactionId];
    }
  }

  @override
  String toString() {
    String readDataValue = '';
    if (readData.runtimeType == ReadDataBoolean) {
      readDataValue = (readData as ReadDataBoolean).value.toString();
    } else if (readData.runtimeType == ReadDataInteger) {
      readDataValue = (readData as ReadDataInteger).value.toString();
    }

    String readDataString = readData.runtimeType == ReadDataNotAvailable
        ? ''
        : ', data read=$readDataValue';
    return '<- Response: $modbusBlockId, transaction id=$transactionId, '
        '${isSuccess ? 'SUCCESS' : 'FAIL'}$readDataString';
  }

  static Response generateResponseAndEraseItsEntryFromChart({
    required ModbusResponseData modbusResponseData,
    required Table table,
  }) {
    ModbusBlockIdPartII modbusBlockIdPartII = table.getModbusBlockIdPartII(
      address: modbusResponseData.address,
      transactionId: modbusResponseData.transactionId,
    );

    table.eraseEntry(
      address: modbusResponseData.address,
      transactionId: modbusResponseData.transactionId,
    );

    return Response._fromModbusResponseData(
      modbusResponseData: modbusResponseData,
      modbusBlockId: ModbusBlockId.from(
        address: modbusResponseData.address,
        modbusBlockIdPartII: modbusBlockIdPartII,
      ),
    );
  }

  static Response _fromModbusResponseData({
    required ModbusResponseData modbusResponseData,
    required ModbusBlockId modbusBlockId,
  }) {
    int functionCode = modbusResponseData.pdu[0];
    bool isSuccess = functionCode < 128;
    // bool isWrite = false;
    ReadData readData;
    if (isSuccess) {
      switch (functionCode) {
        case 1:
          readData = ReadDataBoolean(modbusResponseData.pdu[2] > 0);
          break;
        case 2:
          readData = ReadDataBoolean(modbusResponseData.pdu[2] > 0);
          break;
        case 3:
          readData = ReadDataInteger(modbusResponseData.pdu
              .sublist(2, 4)
              .convertFirstTwoElementsToInteger);
          break;
        case 4:
          readData = ReadDataInteger(modbusResponseData.pdu
              .sublist(2, 4)
              .convertFirstTwoElementsToInteger);
          break;
        case 5:
          readData = ReadDataNotAvailable();
          break;
        case 6:
          readData = ReadDataNotAvailable();
          break;
        default:
          readData = ReadDataNotAvailable();
      }
    } else {
      switch (functionCode) {
        case 129:
          readData = ReadDataNotAvailable();
          break;
        case 130:
          readData = ReadDataNotAvailable();
          break;
        case 131:
          readData = ReadDataNotAvailable();
          break;
        case 132:
          readData = ReadDataNotAvailable();
          break;
        case 133:
          readData = ReadDataNotAvailable();
          break;
        case 134:
          readData = ReadDataNotAvailable();
          break;
        default:
          readData = ReadDataNotAvailable();
      }
    }

    return Response(
      modbusBlockId: modbusBlockId,
      isSuccess: isSuccess,
      readData: readData,
      transactionId: modbusResponseData.transactionId,
    );
  }
}

class ModbusRequestData {
  final String ipv4Slave;
  final int portSlave;
  final Duration timeout;
  final int transactionId;
  final Uint8List pdu;

  const ModbusRequestData({
    required this.ipv4Slave,
    required this.transactionId,
    required this.pdu,
    this.portSlave = 502,
    this.timeout = const Duration(milliseconds: 1000),
  });

  ModbusRequestData get copy => ModbusRequestData(
        ipv4Slave: ipv4Slave,
        transactionId: transactionId,
        pdu: pdu,
        portSlave: portSlave,
        timeout: timeout,
      );

  Address get address {
    Address adr;
    adr = (ip: ipv4Slave, port: portSlave);
    return adr;
  }

  Uint8List get modbusTcpAdu {
    Uint8List transId = transactionId.toUint8List2bytes;
    Uint8List protocolIdentifier = 0.toUint8List2bytes;
    Uint8List len = (1 + pdu.length).toUint8List2bytes;
    Uint8List unitIdentifier = Uint8List.fromList([0]);
    Uint8List adu = Uint8List.fromList(
        transId + protocolIdentifier + len + unitIdentifier + pdu);
    return adu;
  }

  static ModbusRequestData get dummy {
    return ModbusRequestData(
      ipv4Slave: '0.0.0.0',
      transactionId: 1,
      pdu: Uint8List.fromList([]),
    );
  }

  @override
  String toString() {
    return '$ipv4Slave:$portSlave, transactionId=$transactionId, timeout=$timeout, request pdu=$pdu\n';
  }

  static ModbusRequestData fromRequest({
    required Request request,
    required Table table,
  }) {
    TransactionId transactionId =
        table.appendToTableAndGetNewTransactionId(request);

    ModbusRequestData modbusRequestData;
    Uint8List functionCode;
    Uint8List firstCoilAddress;
    Uint8List coilCount;
    Uint8List registerCount;
    Uint8List coilValue;
    Uint8List pduBytes;

    ModbusRequestData _readCoil() {
      functionCode = 1.toUint8List1byte;
      firstCoilAddress =
          (request.modbusBlockId.elementNumber - 1).toUint8List2bytes;
      coilCount = (1).toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + coilCount);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.address().ip,
        transactionId: transactionId,
        pdu: pduBytes,
        portSlave: request.address().port,
        timeout: request.timeout,
      );
      return modbusRequestData;
    }

    ModbusRequestData _readDiscreteInput() {
      functionCode = 2.toUint8List1byte;
      firstCoilAddress =
          (request.modbusBlockId.elementNumber - 1).toUint8List2bytes;
      coilCount = 1.toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + coilCount);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.address().ip,
        transactionId: transactionId,
        pdu: pduBytes,
        portSlave: request.address().port,
        timeout: request.timeout,
      );
      return modbusRequestData;
    }

    ModbusRequestData _readHoldingRegister() {
      functionCode = 3.toUint8List1byte;
      firstCoilAddress =
          (request.modbusBlockId.elementNumber - 1).toUint8List2bytes;
      registerCount = 1.toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + registerCount);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.modbusBlockId.ip,
        portSlave: request.modbusBlockId.port,
        transactionId: transactionId,
        pdu: pduBytes,
        timeout: request.timeout,
      );
      return modbusRequestData;
    }

    ModbusRequestData _readInputRegister() {
      functionCode = 4.toUint8List1byte;
      firstCoilAddress =
          (request.modbusBlockId.elementNumber - 1).toUint8List2bytes;
      registerCount = 1.toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + registerCount);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.modbusBlockId.ip,
        portSlave: request.modbusBlockId.port,
        transactionId: transactionId,
        pdu: pduBytes,
        timeout: request.timeout,
      );
      return modbusRequestData;
    }

    ModbusRequestData _writeCoil() {
      functionCode = 5.toUint8List1byte;
      firstCoilAddress =
          (request.modbusBlockId.elementNumber - 1).toUint8List2bytes;

      coilValue =
          request.writeData ? 65280.toUint8List2bytes : 0.toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + coilValue);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.modbusBlockId.ip,
        portSlave: request.modbusBlockId.port,
        transactionId: transactionId,
        pdu: pduBytes,
        timeout: request.timeout,
      );

      return modbusRequestData;
    }

    ModbusRequestData _writeHoldingRegister() {
      functionCode = 6.toUint8List1byte;
      firstCoilAddress =
          (request.modbusBlockId.elementNumber - 1).toUint8List2bytes;

      coilValue = request.writeData.toUint8List2bytes;

      pduBytes =
          Uint8List.fromList(functionCode + firstCoilAddress + coilValue);

      modbusRequestData = ModbusRequestData(
        ipv4Slave: request.modbusBlockId.ip,
        portSlave: request.modbusBlockId.port,
        transactionId: transactionId,
        pdu: pduBytes,
        timeout: request.timeout,
      );

      return modbusRequestData;
    }

    bool validRequest = true;

    switch (request.modbusBlockId.readWrite) {
      case ReadWrite.read:
        switch (request.modbusBlockId.elementType) {
          case ElementType.coil:
            modbusRequestData = _readCoil();

            break;

          case ElementType.discreteInput:
            modbusRequestData = _readDiscreteInput();
            break;

          case ElementType.holdingRegister:
            modbusRequestData = _readHoldingRegister();
            break;

          case ElementType.inputRegister:
            modbusRequestData = _readInputRegister();
            break;

          default:
            modbusRequestData = ModbusRequestData.dummy;
            validRequest = false;
        }
        break;
      case ReadWrite.write:
        switch (request.modbusBlockId.elementType) {
          case ElementType.coil:
            modbusRequestData = _writeCoil();
            break;
          case ElementType.holdingRegister:
            modbusRequestData = _writeHoldingRegister();
            break;
          default:
            modbusRequestData = ModbusRequestData.dummy;
            validRequest = false;
        }
        break;
    }

    if (!validRequest) {
      throw Exception('wrong request');
    }

    return modbusRequestData;
  }
}

class ModbusResponseData {
  final String ipv4Slave;
  final int portSlave;
  final int transactionId;
  final Uint8List pdu;

  const ModbusResponseData({
    required this.ipv4Slave,
    required this.portSlave,
    required this.transactionId,
    required this.pdu,
  });

  ModbusResponseData get copy => ModbusResponseData(
        ipv4Slave: ipv4Slave,
        portSlave: portSlave,
        transactionId: transactionId,
        pdu: pdu,
      );

  Address get address {
    Address adr;
    adr = (ip: ipv4Slave, port: portSlave);
    return adr;
  }

  static ModbusResponseData generateResponseFrom({
    required Address address,
    required Uint8List responseAdu,
  }) {
    Uint8List transactionIdAsTwoBytes = responseAdu.sublist(0, 2);
    int transactionIdentifier =
        transactionIdAsTwoBytes.convertFirstTwoElementsToInteger;

    Uint8List responsePdu = responseAdu.sublist(7);

    return ModbusResponseData(
      ipv4Slave: address.ip,
      portSlave: address.port,
      transactionId: transactionIdentifier,
      pdu: responsePdu,
    );
  }

  @override
  String toString() =>
      '$ipv4Slave:$portSlave, transactionId=$transactionId, pdu=$pdu';
}

class Table {
  static const maximumTransactionIdLength = 500;
  static const maxmimumValueOfTransactionId = 65535;

  final Map<Address, Map<TransactionId, ModbusBlockIdPartII>> _chart = {};
  final Map<Address, TransactionId> _transactionIds = {};

  /// TransactionId one greater than previous is returned
  TransactionId _generateNewTransactionId({required Address address}) {
    if (_transactionIds.length > Table.maximumTransactionIdLength) {
      _transactionIds.clear();
    }

    if (_transactionIds[address] == null) {
      _transactionIds[address] = 0;
      return 0;
    } else {
      int newId = _transactionIds[address]! + 1;
      newId = newId > Table.maxmimumValueOfTransactionId ? 0 : newId;

      _transactionIds[address] = newId;
      return newId;
    }
  }

  void _append(Request request, TransactionId transactionId) {
    Address address = (
      ip: request.modbusBlockId.ip,
      port: request.modbusBlockId.port,
    );
    if (_chart[address] == null) {
      _chart[address] = <TransactionId, ModbusBlockIdPartII>{};
    }
    _chart[address]![transactionId] = request.modbusBlockId.modbusBlockIdPartII;
  }

  ModbusBlockIdPartII getModbusBlockIdPartII({
    required Address address,
    required TransactionId transactionId,
  }) {
    Map<TransactionId, ModbusBlockIdPartII>? transactionIdModbusBlockPartII;
    transactionIdModbusBlockPartII = _chart[address];

    ModbusBlockIdPartII? modbusBlockIdPartII;

    if (transactionIdModbusBlockPartII == null) {
      throw Exception('ModbusBlockDataPartII does not exist in chart');
    } else {
      modbusBlockIdPartII = transactionIdModbusBlockPartII[transactionId];
      if (modbusBlockIdPartII == null) {
        throw Exception('ModbusBlockDataPartII does not exist in chart');
      }
    }
    return modbusBlockIdPartII;
  }

  void eraseEntry({
    required Address address,
    required TransactionId transactionId,
  }) {
    Map<TransactionId, ModbusBlockIdPartII>? transactionIdModbusBlockPartII;
    transactionIdModbusBlockPartII = _chart[address];

    if (transactionIdModbusBlockPartII == null) {
      throw Exception(
          'Trying to delete, but ModbusBlockIdPartII does not exist');
    } else {
      if (transactionIdModbusBlockPartII[transactionId] == null) {
        throw Exception(
            'Trying to delete, but ModbusBlockIdPartII does not exist');
      } else {
        transactionIdModbusBlockPartII.remove(transactionId);

        if (transactionIdModbusBlockPartII ==
            <TransactionId, ModbusBlockIdPartII>{}) {
          _chart.remove(address);
        }
      }
    }
  }

  TransactionId appendToTableAndGetNewTransactionId(Request request) {
    TransactionId newTransactionId =
        _generateNewTransactionId(address: request.address());
    _append(request, newTransactionId);
    return newTransactionId;
  }
}

class AliveConnections {
  final Map<Address, Socket> _data = {};

  void removeAddress(Address address) {
    _data.remove(address);
  }

  Socket? socketAt(Address address) {
    return _data[address];
  }

  void insert({required Socket socket, required Address atAddress}) {}

  bool hasAddress(Address address) {
    bool addressFound = false;
    for (Address addressAlive in _data.keys) {
      if (address == addressAlive) {
        addressFound = true;
        break;
      }
    }
    return addressFound;
  }

  bool isEmpty() {
    return _data.isEmpty;
  }

  void copy({required dynamic copyTo, required Address atAddress}) {
    if (copyTo.runtimeType == RequestWithAliveConnection) {
    } else if (copyTo.runtimeType == RequestWithDeadConnection) {}
  }

  void addSocket({required Socket socket, required Address atAddress}) {
    _data[atAddress] = socket;
  }

  Future<void> destroyAllSocketsAndClear() async {
    List<Socket> sockets = [];

    sockets = _data.values.toList();

    for (Socket socket in sockets) {
      // await socket.close();
      socket.destroy();
    }

    _data.clear();
  }

  int length() => _data.length;

  void destroyEarliestConnection() {
    if (_data.isNotEmpty) {
      Address address = _data.keys.first;
      _data[address]!.destroy();
    }
  }

  @override
  String toString() {
    String msg = 'Socket: ';
    for (Address address in _data.keys) {
      msg = msg + '${address.ip}:${address.port}, ';
    }
    return msg;
  }
}

class Requests {
  final List<ModbusRequestData> _data = [];

  bool isEmpty() {
    return _data.isEmpty;
  }

  int get length => _data.length;

  Address addressAt(int index) => _data[index].address;

  void copy({required int index, required dynamic copyTo}) {
    ModbusRequestData item = _data[index];
    if (copyTo.runtimeType == RequestWithAliveConnection ||
        copyTo.runtimeType == RequestWithDeadConnection) {
      Map<Address, List<ModbusRequestData>> data = copyTo._data;
      Address adr = (ip: item.ipv4Slave, port: item.portSlave);
      if (data[item.address] == null) {
        data[adr] = <ModbusRequestData>[];
      }
      data[adr]!.add(item.copy);
    }
  }

  void clear() => _data.clear();

  void append(ModbusRequestData modbusRequestData) {
    _data.add(modbusRequestData);
  }

  @override
  String toString() {
    String msg = 'Requests:';
    for (ModbusRequestData modbusRequestData in _data) {
      msg = msg + '${modbusRequestData.transactionId},';
    }
    return msg;
  }
}

class RequestWithAliveConnection {
  final Map<Address, List<ModbusRequestData>> _data = {};

  Iterable<Address> addresses() {
    return _data.keys;
  }

  void copy({
    required Address atAddress,
    required dynamic to,
  }) {
    if (to.runtimeType == RequestSentToSlave) {
      List<ModbusRequestData>? li;
      li = _data[atAddress];
      if (li != null) {
        for (ModbusRequestData modbusRequestData in li) {
          int transId = modbusRequestData.transactionId;

          if (to._data[atAddress] == null) {
            to._data[atAddress] = <TransactionId, RequestWithTimeStamp>{};
          }
          RequestWithTimeStamp requestWithTimeStamp;

          requestWithTimeStamp = (
            modbusRequestData: modbusRequestData.copy,
            timeStampWhenSentToSlave: DateTime.now()
          );

          to._data[atAddress][transId] = requestWithTimeStamp;
        }
      }
    } else if (to.runtimeType == RequestWithDeadConnection) {
      List<ModbusRequestData>? li;
      li = _data[atAddress];
      Map<Address, List<ModbusRequestData>> data = to._data;
      if (li != null) {
        for (ModbusRequestData modbusRequestData in li) {
          if (data[atAddress] == null) {
            data[atAddress] = <ModbusRequestData>[];
          }
          data[atAddress]!.add(modbusRequestData.copy);
        }
      }
    }
  }

  void eraseAtAddress(Address address) {
    _data.remove(address);
  }

  void clear() => _data.clear();

  bool isEmpty() => _data.isEmpty;

  void sendToSlave({
    required Address atAddress,
    required AliveConnections aliveConnections,
  }) {
    List<ModbusRequestData>? modbusRequestDatas;
    modbusRequestDatas = _data[atAddress];

    if (modbusRequestDatas != null) {
      for (ModbusRequestData modbusRequestData in modbusRequestDatas) {
        String msg = String.fromCharCodes(modbusRequestData.modbusTcpAdu);

        aliveConnections.socketAt(atAddress)!.write(msg);
      }
    }
  }

  @override
  String toString() {
    String msg = 'Request Alive: ';
    for (Address address in _data.keys) {
      msg = msg + '${address.ip}:${address.port} [';
      List<ModbusRequestData>? modbusRequestDatas = _data[address];

      if (modbusRequestDatas != null) {
        for (ModbusRequestData modbusRequestData in modbusRequestDatas) {
          msg = msg + '${modbusRequestData.transactionId},';
        }
      }
      msg = msg + '] ';
    }
    return msg;
  }
}

class RequestWithDeadConnection {
  final Map<Address, List<ModbusRequestData>> _data = {};

  Iterable<Address> addresses() {
    return _data.keys;
  }

  void copy({
    required Address atAddress,
    required dynamic to,
  }) {
    if (to.runtimeType == RequestAttemptingToConnect ||
        to.runtimeType == RequestWithAliveConnection) {
      Map<Address, List<ModbusRequestData>> data = to._data;

      List<ModbusRequestData>? modbusRequestDatas = _data[atAddress];
      if (modbusRequestDatas != null) {
        for (ModbusRequestData modbusRequestData in modbusRequestDatas) {
          if (data[atAddress] == null) {
            data[atAddress] = <ModbusRequestData>[];
          }
          data[atAddress]!.add(modbusRequestData.copy);
        }
      }
    } else {
      throw Exception('data type of "to" argument should be either '
          'RequestAttemptingToConnect or RequestWithAliveConnection');
    }
  }

  void clear() => _data.clear();

  bool isEmpty() => _data.isEmpty;

  @override
  String toString() {
    String msg = 'Request Dead: ';
    for (Address address in _data.keys) {
      msg = msg + '${address.ip}:${address.port} [';
      List<ModbusRequestData>? modbusRequestDatas = _data[address];

      if (modbusRequestDatas != null) {
        for (ModbusRequestData modbusRequestData in modbusRequestDatas) {
          msg = msg + '${modbusRequestData.transactionId},';
        }
      }
      msg = msg + '] ';
    }
    return msg;
  }
}

class RequestAttemptingToConnect {
  Map<Address, List<ModbusRequestData>> _data = {};

  List<Address> addresses() {
    List<Address> addresses = [];
    for (Address address in _data.keys) {
      addresses.add(address);
    }
    return addresses;
  }

  void copy({
    required Address atAddress,
    required RequestWithAliveConnection to,
  }) {
    if (to._data[atAddress] == null) {
      to._data[atAddress] = <ModbusRequestData>[];
    }

    List<ModbusRequestData> li = [];

    List<ModbusRequestData>? listOfRequestData = _data[atAddress];
    if (listOfRequestData != null) {
      for (ModbusRequestData modbusRequestData in listOfRequestData) {
        li.add(modbusRequestData.copy);
      }
    }

    to._data[atAddress]?.addAll(li);
  }

  void eraseAtAddress(Address address) {
    _data.remove(address);
  }

  bool isEmpty() => _data.isEmpty;

  List<ModbusResponseData> getConnectionNotEstablishedErrorResponse(
      {required Address atAddress}) {
    List<ModbusRequestData>? modbusRequestDatas = _data[atAddress];
    List<ModbusResponseData> modbusResponseDatas = [];

    // print('TRYING TO GET ERROR RESPONSE AT ADDRESS ${atAddress}');

    if (modbusRequestDatas == null) {
      throw Exception('trying to access address, whose entry does not exist.');
    } else {
      for (var modbusRequestData in modbusRequestDatas) {
        List<int> responsePduAsInt = [128 + modbusRequestData.pdu[0], 4];
        Uint8List responsePdu = Uint8List.fromList(responsePduAsInt);

        modbusResponseDatas.add(
          ModbusResponseData(
            ipv4Slave: modbusRequestData.ipv4Slave,
            portSlave: modbusRequestData.portSlave,
            transactionId: modbusRequestData.transactionId,
            pdu: responsePdu,
          ),
        );
      }
    }

    return modbusResponseDatas;
  }

  @override
  String toString() {
    String msg = 'Request Attempting to Connect: ';
    for (Address address in _data.keys) {
      msg = msg + '${address.ip}:${address.port} [';
      List<ModbusRequestData>? modbusRequestDatas = _data[address];

      if (modbusRequestDatas != null) {
        for (ModbusRequestData modbusRequestData in modbusRequestDatas) {
          msg = msg + '${modbusRequestData.transactionId},';
        }
      }
      msg = msg + '] ';
    }
    return msg;
  }
}

class RequestSentToSlave {
  Map<Address, Map<TransactionId, RequestWithTimeStamp>> _data = {};

  List<AddressAndTransactionId> getIdentifier() {
    List<AddressAndTransactionId> identifiers = [];
    for (Address address in _data.keys) {
      for (TransactionId transactionId in _data[address]!.keys) {
        AddressAndTransactionId identifier =
            (address: address, transactionId: transactionId);
        identifiers.add(identifier);
      }
    }
    return identifiers;
  }

  bool hasIdentifier(AddressAndTransactionId id) {
    Address address = id.address;
    int transactionId = id.transactionId;

    bool found = false;

    if (_data[address] != null) {
      if (_data[address]![transactionId] != null) {
        found = true;
      }
    }

    return found;
  }

  bool hasTimeoutExceededOf(AddressAndTransactionId identifier) {
    RequestWithTimeStamp? requestWithTimeStamp =
        _data[identifier.address]![identifier.transactionId];

    bool timeOutExceeded = false;

    if (requestWithTimeStamp != null) {
      Duration timeDifference = DateTime.now()
          .difference(requestWithTimeStamp.timeStampWhenSentToSlave);

      if (timeDifference > requestWithTimeStamp.modbusRequestData.timeout) {
        timeOutExceeded = true;
      }
    }
    return timeOutExceeded;
  }

  ModbusRequestData getModbusRequestData(AddressAndTransactionId identifier) {
    return _data[identifier.address]![identifier.transactionId]!
        .modbusRequestData
        .copy;
  }

  void erase(AddressAndTransactionId identifier) {
    _data[identifier.address]!.remove(identifier.transactionId);
    if (_data[identifier.address]!.isEmpty) {
      _data.remove(identifier.address);
    }
  }

  bool isEmpty() => _data.isEmpty;

  ModbusResponseData getErrorResponseDueToTimeout(
    AddressAndTransactionId identifier,
  ) {
    Address address = identifier.address;
    TransactionId transactionId = identifier.transactionId;
    ModbusRequestData? modbusRequestData;
    ModbusResponseData modbusResponseData;

    if (_data[address] == null) {
      throw Exception('trying to access address, whose entry does not exist.');
    } else {
      if (_data[address]![transactionId] == null) {
        throw Exception(
            'trying to access address, whose entry does not exist.');
      } else {
        modbusRequestData = _data[address]?[transactionId]?.modbusRequestData;

        List<int> responsePduAsInt = [128 + modbusRequestData!.pdu[0], 6];
        Uint8List responsePdu = Uint8List.fromList(responsePduAsInt);

        modbusResponseData = ModbusResponseData(
          ipv4Slave: address.ip,
          portSlave: address.port,
          transactionId: transactionId,
          pdu: responsePdu,
        );
      }
    }

    return modbusResponseData;
  }

  @override
  String toString() {
    String msg = 'Request Sent to Slave: ';
    for (Address address in _data.keys) {
      msg = msg + '${address.ip}:${address.port} ';

      for (TransactionId transactionId in _data[address]!.keys) {
        msg = msg +
            '$transactionId(${_data[address]![transactionId]!.timeStampWhenSentToSlave})';
      }
    }
    return msg;
  }
}

class ResponseReceivedFromSlave {
  Map<Address, Map<TransactionId, ModbusResponseData>> _data = {};

  List<AddressAndTransactionId> getIdentifiers() {
    List<AddressAndTransactionId> identifiers = [];
    for (Address address in _data.keys) {
      for (TransactionId transactionId in _data[address]!.keys) {
        AddressAndTransactionId identifier =
            (address: address, transactionId: transactionId);
        identifiers.add(identifier);
      }
    }
    return identifiers;
  }

  bool isFound({
    required AddressAndTransactionId atAddressAndTransactionId,
    required RequestSentToSlave inRequestSentToSlave,
  }) {
    bool found = false;

    if (inRequestSentToSlave._data[atAddressAndTransactionId.address] != null) {
      if (inRequestSentToSlave._data[atAddressAndTransactionId.address]![
              atAddressAndTransactionId.transactionId] !=
          null) {
        found = true;
      }
    }

    return found;
  }

  ModbusResponseData? getElementAt(AddressAndTransactionId id) {
    Address address = id.address;
    int transactionId = id.transactionId;

    return _data[address]?[transactionId];
  }

  void clear() {
    _data.clear();
  }

  bool isEmpty() => _data.isEmpty;

  void append({
    required Uint8List modbusTcpAdu,
    required Address atAddress,
  }) {
    ModbusResponseData modbusResponseData =
        ModbusResponseData.generateResponseFrom(
      address: atAddress,
      responseAdu: modbusTcpAdu,
    );

    if (_data[atAddress] == null) {
      _data[atAddress] = <TransactionId, ModbusResponseData>{};
    }

    _data[atAddress]![modbusResponseData.transactionId] =
        modbusResponseData.copy;
  }

  @override
  String toString() {
    String msg = 'Response: ';
    for (Address address in _data.keys) {
      msg = '$msg${address.ip}:${address.port} ';

      for (TransactionId transactionId in _data[address]!.keys) {
        msg = '$msg$transactionId,';
      }
    }
    return msg;
  }
}

class ModbusMasterForWorker {
  late final Duration
      socketConnectionTimeout; // = Duration(milliseconds: 2000);
  static const int maximumSlaveConnectionsAtOneTime = 247;

  final _streamController = StreamController<ModbusResponseData>();

  final _aliveConnections = AliveConnections();
  final List<Address> _addressTryingToConnect = [];
  final _requests = Requests();
  final _requestWithAliveConnection = RequestWithAliveConnection();
  final _requestWithDeadConnection = RequestWithDeadConnection();
  final _requestSentToSlave = RequestSentToSlave();
  final _requestAttemptingToConnect = RequestAttemptingToConnect();
  final _responseReceivedFromSlave = ResponseReceivedFromSlave();
  bool _loopRunning = false;
  bool _closeRequested = false;
  int _countOfRequestForWhichResponsesNotReceived = 0;

  final ReceivePort _receivePort = ReceivePort();
  final SendPort sendPort;

  ModbusMasterForWorker({
    required this.sendPort,
    this.socketConnectionTimeout = const Duration(milliseconds: 2000),
  });

  void _sendRequest(ModbusRequestData modbusRequestData,
      {bool printRequest = false}) {
    if (!_loopRunning || _closeRequested) {
      throw Exception('"sendRequest" is called after "close"');
    }
    if (printRequest) {
      print(modbusRequestData);
    }
    ++_countOfRequestForWhichResponsesNotReceived;
    _requests.append(modbusRequestData);
  }

  void _start() async {
    _loopRunning = true;
    //infinite loop
    while (true) {
      _processRequestList();
      _processRequestWithAliveConnection();
      _processRequestWithDeadConnection();
      _processRequestAttemptingToConnect();
      _processResponseReceivedFromSlave();
      _checkTimeoutOfRequestSentToSlave();
      await Future.delayed(Duration.zero);

      if (_closeRequested && _countOfRequestForWhichResponsesNotReceived == 0) {
        // print('breaking loop');
        break;
      }
    }
    _loopRunning = false;

    //  DESTROY ALL SOCKETS AND CLEAR
    await _aliveConnections.destroyAllSocketsAndClear();

    _streamController.close();
  }

  void _close() {
    _closeRequested = true;
  }

  void _processRequestList() {
    for (int i = 0; i < _requests.length; ++i) {
      if (_aliveConnections.hasAddress(_requests.addressAt(i))) {
        _requests.copy(index: i, copyTo: _requestWithAliveConnection);
      } else {
        _requests.copy(index: i, copyTo: _requestWithAliveConnection);
      }
    }

    _requests.clear();
  }

  void _processRequestWithAliveConnection() {
    for (Address address in _requestWithAliveConnection.addresses()) {
      if (_aliveConnections.hasAddress(address)) {
        // send request to slave
        _requestWithAliveConnection.sendToSlave(
          atAddress: address,
          aliveConnections: _aliveConnections,
        );

        _requestWithAliveConnection.copy(
          atAddress: address,
          to: _requestSentToSlave,
        );
      } else {
        _requestWithAliveConnection.copy(
          atAddress: address,
          to: _requestWithDeadConnection,
        );
      }
    }

    _requestWithAliveConnection.clear();
  }

  void _processRequestWithDeadConnection() {
    for (Address address in _requestWithDeadConnection.addresses()) {
      if (_aliveConnections.hasAddress(address)) {
        _requestWithDeadConnection.copy(
          atAddress: address,
          to: _requestWithAliveConnection,
        );
      } else {
        _requestWithDeadConnection.copy(
          atAddress: address,
          to: _requestAttemptingToConnect,
        );
      }
    }

    _requestWithDeadConnection.clear();
  }

  void _processRequestAttemptingToConnect() {
    for (Address address in _requestAttemptingToConnect.addresses()) {
      if (!_addressTryingToConnect.contains(address)) {
        _connectToSocketAndSendData(address);
      }
    }
  }

  void _connectToSocketAndSendData(Address address) async {
    try {
      _addressTryingToConnect.add(address);

      Socket socket = await Socket.connect(
        address.ip,
        address.port,
        timeout: socketConnectionTimeout,
      );

      socket.listen(
        (uint8List) {
          _responseReceivedFromSlave.append(
            modbusTcpAdu: uint8List,
            atAddress: address,
          );
        },
        onError: (_) {
          socket.destroy();
          // socket.
        },
        onDone: () {
          // print('SOCKET CLOSED AT ADDRESS $address');
          // socket.close();

          _aliveConnections.removeAddress(address);
        },
      );

      if (_aliveConnections.length() >
          ModbusMasterForWorker.maximumSlaveConnectionsAtOneTime) {
        _aliveConnections.destroyEarliestConnection();
      }

      _aliveConnections.addSocket(socket: socket, atAddress: address);

      _requestAttemptingToConnect.copy(
        atAddress: address,
        to: _requestWithAliveConnection,
      );
    } catch (_, __) {
      List<ModbusResponseData> modbusResponseDatas = _requestAttemptingToConnect
          .getConnectionNotEstablishedErrorResponse(atAddress: address);

      for (ModbusResponseData modbusResponseData in modbusResponseDatas) {
        --_countOfRequestForWhichResponsesNotReceived;
        _streamController.sink.add(modbusResponseData);
      }
    }

    _addressTryingToConnect.remove(address);

    _requestAttemptingToConnect.eraseAtAddress(address);
  }

  void _processResponseReceivedFromSlave() {
    for (AddressAndTransactionId id
        in _responseReceivedFromSlave.getIdentifiers()) {
      if (_requestSentToSlave.hasIdentifier(id)) {
        ModbusResponseData? modbusResponseData =
            _responseReceivedFromSlave.getElementAt(id);

        if (modbusResponseData != null) {
          --_countOfRequestForWhichResponsesNotReceived;
          _streamController.sink.add(modbusResponseData);
        }

        // print('TRYING TO ERASE RESPONSE_RECEIVED_FROM_SLAVE');
        _requestSentToSlave.erase(id);
      }
    }

    _responseReceivedFromSlave.clear();
  }

  void _checkTimeoutOfRequestSentToSlave() {
    for (AddressAndTransactionId identifier
        in _requestSentToSlave.getIdentifier()) {
      if (_requestSentToSlave.hasTimeoutExceededOf(identifier)) {
        // print('TIMEOUT EXCEEDED');
        // SEND ERROR RESPONSE TO STREAM, DUE TO RESPONSE NOT RECEIVED IN TIME
        --_countOfRequestForWhichResponsesNotReceived;
        _streamController.sink.add(
          _requestSentToSlave.getErrorResponseDueToTimeout(identifier),
        );

        // DELETE AT IDENTIFIER
        _requestSentToSlave.erase(identifier);
        // print(_requestSentToSlave._data.length);
      }
    }
  }

  static void startWorker(SendPort sendPort) {
    ModbusMasterForWorker modbusMaster =
        ModbusMasterForWorker(sendPort: sendPort);
    modbusMaster._start();

    sendPort.send(modbusMaster._receivePort.sendPort);

    modbusMaster._streamController.stream.listen((modbusResponseData) {
      sendPort.send(modbusResponseData);
    }, onDone: () {
      // print('DONE RECEIVED ON STREAM CONTROLLER');
      modbusMaster._receivePort.close();
      sendPort.send(null);
      // sendPort.send();
      // Isolate.exit();
    });

    modbusMaster._receivePort.listen(
      (element) {
        if (element == null) {
          // print('NULL RECEIVED IN ISOLATE');
          modbusMaster._stepsAfterDoneReceived();
        } else {
          modbusMaster._sendRequest(element);
        }
      },
      onDone: () {
        // modbusMaster._stepsAfterDoneReceived();
      },
      onError: (_) {
        // modbusMaster._stepsAfterDoneReceived();
      },
    );
  }

  void _stepsAfterDoneReceived() {
    _close();
    // _receivePort.close();
  }
}

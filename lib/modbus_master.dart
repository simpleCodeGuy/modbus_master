/// 'modbus_master' is an easy to use package using which a dart program can work as a Modbus/TCP master device.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:modbus_master/src/network_isolate.dart';
import 'package:modbus_master/src/my_logging.dart';

class ModbusMaster {
  static const timeoutMillisecondsMinimum = 200;
  static const timeoutMillisecondsMaximum = 10000;
  static const socketConnectionTimeoutMilliseconds =
      NetworkIsolateData.socketConnectionTimeoutMilliseconds;

  int _transactionId = 0;
  bool _isShutdownRequested = false;
  bool _isNetworkIsolateRunning = false;
  ReceivePort? _receivePortOfMainIsolate;
  SendPort? _sendPortOfWorkerIsolate;
  StreamController<SlaveResponse>? _streamController;

  bool get isStoppedSync => !_isNetworkIsolateRunning;

  Future<bool> get isStoppedAsync async {
    while (true) {
      if (_isNetworkIsolateRunning) {
        await Future.delayed(Duration.zero);
      } else {
        return true;
      }
    }
  }

  bool get isRunning => _isNetworkIsolateRunning;

  Stream<SlaveResponse> get responseFromSlaveDevices {
    if (isStoppedSync) {
      throw Exception(
          "Response can only be obtained when modbus master is running."
          "Use start method of this class to start");
    } else {
      return _streamController!.stream;
    }
  }

  ModbusMaster() {
    throw Exception("Correct way of creating object of this class is\n"
        "final modbusMaster = await ModbusMaster.start();");
  }

  ModbusMaster._create();

  static Future<ModbusMaster> start() async {
    final modbusMaster = ModbusMaster._create();

    modbusMaster._streamController = StreamController<SlaveResponse>();

    // final receivePort = ReceivePort();
    modbusMaster._receivePortOfMainIsolate = ReceivePort();

    final workerIsolate = await Isolate.spawn(
      networkIsolateTask,
      modbusMaster._receivePortOfMainIsolate!.sendPort,
      onExit: modbusMaster._receivePortOfMainIsolate!.sendPort,
      onError: modbusMaster._receivePortOfMainIsolate!.sendPort,
    );

    Logging.i("WORKER ISOLATE SUCCESSFULLY SPAWNED");
    // print("WORKER ISOLATE SUCCESSFULLY SPAWNED");

    modbusMaster._receivePortOfMainIsolate!.listen((data) {
      Logging.i("MASTER ISOLATE RECEIVED : ${data.runtimeType}\n$data");
      switch (data) {
        case SlaveResponseDataReceived _:
          modbusMaster._streamController!.add(data);
          break;
        case SlaveResponseConnectionError _:
          modbusMaster._streamController!.add(data);
          break;
        case SlaveResponseTimeoutError _:
          modbusMaster._streamController!.add(data);
          break;
        case SendPort _:
          modbusMaster._sendPortOfWorkerIsolate = data;
          modbusMaster._isNetworkIsolateRunning = true;
          break;
        case SlaveResponseShutdownComplete _:
          modbusMaster._streamController!.close();
          break;
        default:
          if (data == null) {
            // Logging.i("");
            modbusMaster._receivePortOfMainIsolate?.close();
          }
      }
    }, onDone: () {
      workerIsolate.kill();
      modbusMaster._receivePortOfMainIsolate = null;
      modbusMaster._sendPortOfWorkerIsolate = null;
      modbusMaster._isShutdownRequested = false;
      modbusMaster._isNetworkIsolateRunning = false;
      Logging.i("MASTER ISOLATE RECEIVED : done event");
    }, onError: (e, f) {
      Logging.i("ERROR RECEIVED $e\n$f");
      modbusMaster._receivePortOfMainIsolate?.close();
      workerIsolate.kill();
      modbusMaster._receivePortOfMainIsolate = null;
      modbusMaster._sendPortOfWorkerIsolate = null;
      modbusMaster._isShutdownRequested = false;
      modbusMaster._isNetworkIsolateRunning = false;
      throw RemoteError(e, f);
    });

    while (modbusMaster._sendPortOfWorkerIsolate == null) {
      await Future.delayed(Duration.zero);
    }

    return modbusMaster;
  }

  void stop() {
    if (!_isNetworkIsolateRunning) {
      throw Exception("Cannot stop when it is already stopped");
    } else if (_isShutdownRequested) {
      // DO NOTHING BECAUSE SHUTDOWN HAS ALREADY BEEN REQUEST
    } else {
      _sendPortOfWorkerIsolate!.send(UserRequestShutdown());
      _isShutdownRequested = true;
    }
  }

  int read({
    // required bool isIpv4,
    // required bool isIpv6,
    required String ipAddress,
    required int portNumber,
    required int unitId,
    required int blockNumber,
    required int elementNumber,
    required int timeoutMilliseconds,
  }) {
    if (isStoppedSync) {
      throw Exception(
          "read method works after object of ModbusMaster class is started");
    }
    // if (isIpv4 && isIpv6) {
    //   throw Exception("address cannot be of both ipv4 & ipv6 type");
    // }
    if (unitId < 0 || unitId > 255) {
      throw Exception("unit id must be between 0 and 255");
    }
    if (!(blockNumber == 0 ||
        blockNumber == 1 ||
        blockNumber == 3 ||
        blockNumber == 4)) {
      throw Exception("block number must be either 0, 1, 3 or 4");
    }
    if (elementNumber < 1 || elementNumber > 65536) {
      throw Exception("unit id must be between 1 and 65536");
    }
    if (timeoutMilliseconds < ModbusMaster.timeoutMillisecondsMinimum ||
        timeoutMilliseconds > ModbusMaster.timeoutMillisecondsMaximum) {
      throw Exception("Timeout value should be between "
          "${ModbusMaster.timeoutMillisecondsMinimum} and "
          "${ModbusMaster.timeoutMillisecondsMaximum} milliseconds.");
    }

    _transactionId = _transactionId == 65535 ? 0 : _transactionId + 1;

    if (blockNumber == 0) {
      _sendPortOfWorkerIsolate?.send(_generateReadRequestStreamElementForCoil(
        // isIpv4: isIpv4,
        // isIpv6: isIpv6,
        ipAddress: ipAddress,
        portNumber: portNumber,
        unitId: unitId,
        blockNumber: blockNumber,
        elementNumber: elementNumber,
        timeoutMilliseconds: timeoutMilliseconds,
        transactionId: _transactionId,
      ));
    } else if (blockNumber == 1) {
      _sendPortOfWorkerIsolate
          ?.send(_generateReadRequestStreamElementForDiscreteInput(
        // isIpv4: isIpv4,
        // isIpv6: isIpv6,
        ipAddress: ipAddress,
        portNumber: portNumber,
        unitId: unitId,
        blockNumber: blockNumber,
        elementNumber: elementNumber,
        timeoutMilliseconds: timeoutMilliseconds,
        transactionId: _transactionId,
      ));
    } else if (blockNumber == 3) {
      _sendPortOfWorkerIsolate
          ?.send(_generateReadRequestStreamElementForInputRegister(
        // isIpv4: isIpv4,
        // isIpv6: isIpv6,
        ipAddress: ipAddress,
        portNumber: portNumber,
        unitId: unitId,
        blockNumber: blockNumber,
        elementNumber: elementNumber,
        timeoutMilliseconds: timeoutMilliseconds,
        transactionId: _transactionId,
      ));
    } else if (blockNumber == 4) {
      _sendPortOfWorkerIsolate
          ?.send(_generateReadRequestStreamElementForHoldingRegister(
        // isIpv4: isIpv4,
        // isIpv6: isIpv6,
        ipAddress: ipAddress,
        portNumber: portNumber,
        unitId: unitId,
        blockNumber: blockNumber,
        elementNumber: elementNumber,
        timeoutMilliseconds: timeoutMilliseconds,
        transactionId: _transactionId,
      ));
    }

    return _transactionId;
  }

  int write({
    // required bool isIpv4,
    // required bool isIpv6,
    required String ipAddress,
    required int portNumber,
    required int unitId,
    required int blockNumber,
    required int elementNumber,
    required int timeoutMilliseconds,
    required int valueToBeWritten,
  }) {
    if (isStoppedSync) {
      throw Exception(
          "read method works after object of ModbusMaster class is started");
    }
    // if (isIpv4 && isIpv6) {
    //   throw Exception("address cannot be of both ipv4 & ipv6 type");
    // }
    if (unitId < 0 || unitId > 255) {
      throw Exception("unit id must be between 0 and 255");
    }
    if (!(blockNumber == 0 ||
        blockNumber == 1 ||
        blockNumber == 3 ||
        blockNumber == 4)) {
      throw Exception("block number must be either 0, 1, 3 or 4");
    }
    if (elementNumber < 1 || elementNumber > 65536) {
      throw Exception("unit id must be between 1 and 65536");
    }
    if (timeoutMilliseconds < ModbusMaster.timeoutMillisecondsMinimum ||
        timeoutMilliseconds > ModbusMaster.timeoutMillisecondsMaximum) {
      throw Exception("Timeout value should be between "
          "${ModbusMaster.timeoutMillisecondsMinimum} and "
          "${ModbusMaster.timeoutMillisecondsMaximum} milliseconds.");
    }
    if (blockNumber == 0) {
      if ((valueToBeWritten == 0 || valueToBeWritten == 1)) {
        // DO NOTHING
      } else {
        throw Exception("For block no. 0 i.e. coil, value to be written should "
            "be either 0 or 1");
      }
    }
    if (blockNumber == 4) {
      if ((valueToBeWritten < 0 || valueToBeWritten > 65535)) {
        throw Exception("For block no. 4 i.e. holding register, value to be "
            "written should be between 0 and 65535");
      }
    }

    _transactionId = _transactionId == 65535 ? 0 : _transactionId + 1;

    if (blockNumber == 0) {
      _sendPortOfWorkerIsolate?.send(_generateWriteRequestStreamElementForCoil(
          // isIpv4: isIpv4,
          // isIpv6: isIpv6,
          ipAddress: ipAddress,
          portNumber: portNumber,
          unitId: unitId,
          blockNumber: blockNumber,
          elementNumber: elementNumber,
          timeoutMilliseconds: timeoutMilliseconds,
          transactionId: _transactionId,
          valueToBeWritten: valueToBeWritten));
    } else if (blockNumber == 4) {
      Logging.i("TRYING TO SEND WRITE REQUEST FOR HOLDING REGISTER");
      _sendPortOfWorkerIsolate
          ?.send(_generateWriteRequestStreamElementForHoldingRegister(
              // isIpv4: isIpv4,
              // isIpv6: isIpv6,
              ipAddress: ipAddress,
              portNumber: portNumber,
              unitId: unitId,
              blockNumber: blockNumber,
              elementNumber: elementNumber,
              timeoutMilliseconds: timeoutMilliseconds,
              transactionId: _transactionId,
              valueToBeWritten: valueToBeWritten));
    }

    return _transactionId;
  }

  UserRequestData _generateReadRequestStreamElementForCoil({
    // required bool isIpv4,
    // required bool isIpv6,
    required String ipAddress,
    required int portNumber,
    required int unitId,
    required int blockNumber,
    required int elementNumber,
    required int timeoutMilliseconds,
    required int transactionId,
  }) {
    final memoryAddress = elementNumber - 1;
    final memoryAddressLsb = memoryAddress % 256;
    final memoryAddressMsb = memoryAddress ~/ 256;
    final transactionIdLsb = transactionId % 256;
    final transactionIdMsb = transactionId ~/ 256;
    final mbap = Uint8List.fromList(
        [transactionIdMsb, transactionIdLsb, 0, 0, 0, 6, unitId]);
    final pdu =
        Uint8List.fromList([1, memoryAddressMsb, memoryAddressLsb, 0, 1]);
    return UserRequestData(
      // isIpv4: isIpv4,
      // isIpv6: isIpv6,
      ipAddress: ipAddress,
      portNumber: portNumber,
      unitId: unitId,
      blockNumber: blockNumber,
      elementNumber: elementNumber,
      transactionId: transactionId,
      timeoutMilliseconds: timeoutMilliseconds,
      mbap: mbap,
      pdu: pdu,
    );
  }

  UserRequestData _generateReadRequestStreamElementForDiscreteInput({
    // required bool isIpv4,
    // required bool isIpv6,
    required String ipAddress,
    required int portNumber,
    required int unitId,
    required int blockNumber,
    required int elementNumber,
    required int timeoutMilliseconds,
    required int transactionId,
  }) {
    final memoryAddress = elementNumber - 1;
    final memoryAddressLsb = memoryAddress % 256;
    final memoryAddressMsb = memoryAddress ~/ 256;
    final transactionIdLsb = transactionId % 256;
    final transactionIdMsb = transactionId ~/ 256;
    final mbap = Uint8List.fromList(
        [transactionIdMsb, transactionIdLsb, 0, 0, 0, 6, unitId]);
    final pdu =
        Uint8List.fromList([2, memoryAddressMsb, memoryAddressLsb, 0, 1]);
    return UserRequestData(
      // isIpv4: isIpv4,
      // isIpv6: isIpv6,
      ipAddress: ipAddress,
      portNumber: portNumber,
      unitId: unitId,
      blockNumber: blockNumber,
      elementNumber: elementNumber,
      transactionId: transactionId,
      timeoutMilliseconds: timeoutMilliseconds,
      mbap: mbap,
      pdu: pdu,
    );
  }

  UserRequestData _generateReadRequestStreamElementForInputRegister({
    // required bool isIpv4,
    // required bool isIpv6,
    required String ipAddress,
    required int portNumber,
    required int unitId,
    required int blockNumber,
    required int elementNumber,
    required int timeoutMilliseconds,
    required int transactionId,
  }) {
    final memoryAddress = elementNumber - 1;
    final memoryAddressLsb = memoryAddress % 256;
    final memoryAddressMsb = memoryAddress ~/ 256;
    final transactionIdLsb = transactionId % 256;
    final transactionIdMsb = transactionId ~/ 256;
    final mbap = Uint8List.fromList(
        [transactionIdMsb, transactionIdLsb, 0, 0, 0, 6, unitId]);
    final pdu =
        Uint8List.fromList([4, memoryAddressMsb, memoryAddressLsb, 0, 1]);
    return UserRequestData(
      // isIpv4: isIpv4,
      // isIpv6: isIpv6,
      ipAddress: ipAddress,
      portNumber: portNumber,
      unitId: unitId,
      blockNumber: blockNumber,
      elementNumber: elementNumber,
      transactionId: transactionId,
      timeoutMilliseconds: timeoutMilliseconds,
      mbap: mbap,
      pdu: pdu,
    );
  }

  UserRequestData _generateReadRequestStreamElementForHoldingRegister({
    // required bool isIpv4,
    // required bool isIpv6,
    required String ipAddress,
    required int portNumber,
    required int unitId,
    required int blockNumber,
    required int elementNumber,
    required int timeoutMilliseconds,
    required int transactionId,
  }) {
    final memoryAddress = elementNumber - 1;
    final memoryAddressLsb = memoryAddress % 256;
    final memoryAddressMsb = memoryAddress ~/ 256;
    final transactionIdLsb = transactionId % 256;
    final transactionIdMsb = transactionId ~/ 256;
    final mbap = Uint8List.fromList(
        [transactionIdMsb, transactionIdLsb, 0, 0, 0, 6, unitId]);
    final pdu =
        Uint8List.fromList([3, memoryAddressMsb, memoryAddressLsb, 0, 1]);
    return UserRequestData(
      // isIpv4: isIpv4,
      // isIpv6: isIpv6,
      ipAddress: ipAddress,
      portNumber: portNumber,
      unitId: unitId,
      blockNumber: blockNumber,
      elementNumber: elementNumber,
      transactionId: transactionId,
      timeoutMilliseconds: timeoutMilliseconds,
      mbap: mbap,
      pdu: pdu,
    );
  }

  UserRequestData _generateWriteRequestStreamElementForCoil({
    // required bool isIpv4,
    // required bool isIpv6,
    required String ipAddress,
    required int portNumber,
    required int unitId,
    required int blockNumber,
    required int elementNumber,
    required int timeoutMilliseconds,
    required int transactionId,
    required int valueToBeWritten,
  }) {
    final memoryAddress = elementNumber - 1;
    final memoryAddressLsb = memoryAddress % 256;
    final memoryAddressMsb = memoryAddress ~/ 256;
    final valueMsb = valueToBeWritten == 0 ? 0 : 255;
    final valueLsb = 0;
    final transactionIdLsb = transactionId % 256;
    final transactionIdMsb = transactionId ~/ 256;
    final mbap = Uint8List.fromList(
        [transactionIdMsb, transactionIdLsb, 0, 0, 0, 6, unitId]);
    final pdu = Uint8List.fromList(
        [5, memoryAddressMsb, memoryAddressLsb, valueMsb, valueLsb]);
    return UserRequestData(
      // isIpv4: isIpv4,
      // isIpv6: isIpv6,
      ipAddress: ipAddress,
      portNumber: portNumber,
      unitId: unitId,
      blockNumber: blockNumber,
      elementNumber: elementNumber,
      transactionId: transactionId,
      timeoutMilliseconds: timeoutMilliseconds,
      mbap: mbap,
      pdu: pdu,
    );
  }

  UserRequestData _generateWriteRequestStreamElementForHoldingRegister({
    // required bool isIpv4,
    // required bool isIpv6,
    required String ipAddress,
    required int portNumber,
    required int unitId,
    required int blockNumber,
    required int elementNumber,
    required int timeoutMilliseconds,
    required int transactionId,
    required int valueToBeWritten,
  }) {
    final memoryAddress = elementNumber - 1;
    final memoryAddressLsb = memoryAddress % 256;
    final memoryAddressMsb = memoryAddress ~/ 256;
    final valueLsb = valueToBeWritten % 256;
    final valueMsb = valueToBeWritten ~/ 256;
    final transactionIdLsb = transactionId % 256;
    final transactionIdMsb = transactionId ~/ 256;
    final mbap = Uint8List.fromList(
        [transactionIdMsb, transactionIdLsb, 0, 0, 0, 6, unitId]);
    final pdu = Uint8List.fromList(
        [6, memoryAddressMsb, memoryAddressLsb, valueMsb, valueLsb]);
    return UserRequestData(
      // isIpv4: isIpv4,
      // isIpv6: isIpv6,
      ipAddress: ipAddress,
      portNumber: portNumber,
      unitId: unitId,
      blockNumber: blockNumber,
      elementNumber: elementNumber,
      transactionId: transactionId,
      timeoutMilliseconds: timeoutMilliseconds,
      mbap: mbap,
      pdu: pdu,
    );
  }
}

//----------------------------DATA STRUCTURE------------------------------------
sealed class SlaveResponse extends Equatable {
  @override
  List<Object?> get props => [];
}

final class SlaveResponseDataReceived extends SlaveResponse {
  final int transactionId;
  final String ipAddress;
  final int portNumber;
  final int unitId;
  final int blockNumber;
  final int elementNumber;
  final String mbap;
  final String pdu;
  final bool isReadResponse;
  final int? readValue;
  final bool isWriteResponse;
  final int? writeValue;

  SlaveResponseDataReceived({
    required this.transactionId,
    // required this.isIpv4,
    // required this.isIpv6,
    required this.ipAddress,
    required this.portNumber,
    required this.unitId,
    required this.blockNumber,
    required this.elementNumber,
    required this.mbap,
    required this.pdu,
    required this.isReadResponse,
    required this.readValue,
    required this.isWriteResponse,
    required this.writeValue,
  });

  @override
  List<Object?> get props => [];

  @override
  String toString() => "SlaveResponseDataReceived\n"
      "{\n"
      // "    isIpv4:$isIpv4, isIpv6:$isIpv6, "
      "    ipAddress:$ipAddress, portNumber:$portNumber, unitId:$unitId,\n"
      "    mbap:$mbap, pdu:$pdu\n"
      "    isReadResponse:$isReadResponse, readValue:$readValue, "
      "isWriteResponse:$isWriteResponse, writeValue:$writeValue\n"
      "    blockNumber:$blockNumber, elementNumber:$elementNumber\n"
      "}";
}

final class SlaveResponseConnectionError extends SlaveResponse {
  final int transactionId;
  final String ipAddress;
  final int portNumber;
  final int unitId;
  final int blockNumber;
  final int elementNumber;

  SlaveResponseConnectionError({
    required this.transactionId,
    required this.ipAddress,
    required this.portNumber,
    required this.unitId,
    required this.blockNumber,
    required this.elementNumber,
  });

  @override
  List<Object?> get props => [
        ...super.props,
        // transactionId,
        // isIpv4,
        // isIpv6,
        // ipAddress,
        // portNumber,
        // unitId
      ];

  @override
  String toString() => "SlaveResponseConnectionError\n"
      "{\n"
      // "    isIpv4:$isIpv4, isIpv6:$isIpv6, "
      "    ipAddress:$ipAddress, portNumber:$portNumber, unitId:$unitId\n"
      "    blockNumber:$blockNumber, elementNumber:$elementNumber\n"
      "}";
}

final class SlaveResponseTimeoutError extends SlaveResponse {
  final int transactionId;
  final String ipAddress;
  final int portNumber;
  final int unitId;
  final int blockNumber;
  final int elementNumber;
  final int timeoutMilliseconds;

  SlaveResponseTimeoutError({
    required this.transactionId,
    // required this.isIpv4,
    // required this.isIpv6,
    required this.ipAddress,
    required this.portNumber,
    required this.unitId,
    required this.blockNumber,
    required this.elementNumber,
    required this.timeoutMilliseconds,
  });

  @override
  List<Object?> get props => [
        ...super.props,
        // transactionId,
        // isIpv4,
        // isIpv6,
        // ipAddress,
        // portNumber,
        // unitId,
        // timeoutMilliseconds
      ];

  @override
  String toString() => "SlaveResponseTimeoutError\n"
      "{\n"
      // "    isIpv4:$isIpv4, isIpv6:$isIpv6, "
      "    ipAddress:$ipAddress, portNumber:$portNumber, unitId:$unitId, \n"
      "    blockNumber:$blockNumber, elementNumber:$elementNumber, "
      "timeoutMilliseconds:$timeoutMilliseconds\n"
      "}";
}

final class SlaveResponseShutdownComplete extends SlaveResponse {
  @override
  List<Object?> get props => [];
}

/// "modbus_master" is an easy to use package using which a dart program can work as a Modbus/TCP master device.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:modbus_master/src/network_isolate.dart';
import 'package:modbus_master/src/my_logging.dart';

///## Features
/// - Currently users can use only these features of Modbus/TCP protocol:
///   - Read Single Coil
///   - Read Single Discrete Input
///   - Read Single Input Register
///   - Read Single Holding Register
///   - Write Single Coil
///   - Write Single Holding Register
///- This package handles socket networking part in a separate isolate so that main isolate is free to handle other tasks like UI part of flutter.
///- This package can be used on platforms which supports dart:io & dart:isolate i.e. WINDOWS, LINUX, MACOS, ANDROID, IOS.
///
///## Limitations
///- Tested with only ipv4.
///- Only single element can be read at once. Reading multiple coils or multiple registers is not implemented in this library, although reading multiple elements at once is specified in Modbus/TCP protocol.
///- Only single element can be written to at once. Writing to multiple coils or to multiple registers is not implemented in this library, although writing to multiple elements at once is specified in Modbus/TCP protocol.
///
///## How to use this library?
/// -  make an instance of ModbusMaster class
///    ```
///    final modbusMaster = await ModbusMaster.start();
///    ```
/// -  Listen to response from slave devices
///    ```
///    modbusMaster.responseFromSlaveDevices.listen(
///      (response) {
///        print(response);
///
///      },
///    );
///    ```
/// - Send read request to slave device
///   ```
///   modbusMaster.read(
///     ipAddress: '192.168.1.3',
///     portNumber: 502,
///     unitId: 1,
///     blockNumber: 4,
///     elementNumber: 6000,
///     timeoutMilliseconds: 1000,
///   );
///   ```
/// -  Send write request to slave device
///    ```
///    modbusMaster.write(
///      ipAddress: '192.168.1.3',
///      portNumber: 502,
///      unitId: 1,
///      blockNumber: 0,
///      elementNumber: 3001,
///      timeoutMilliseconds: 1000,
///      valueToBeWritten: i % 2,
///    );
///    ```
/// - Stop object so that all socket connections are disconnected and resources are released.
///   ```
///   modbusMaster.stop();
///   ```
///
/// - Wait to know that that all resources have been properly stopped
///   ```
///   final isProperlyStopped = await modbusMaster.isStoppedAsync;
///   ```
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

  ///```
  ///isStoppedSync
  ///```
  ///- A boolean field which tells whether ModbusMaster object is stopped.
  ///- When this is true, then it means that all resources of this object including TCP sockets have been properly stopped.
  ///```
  ///print(modbusMaster.isStoppedSync);
  ///```
  bool get isStoppedSync => !_isNetworkIsolateRunning;

  /// ```
  /// isStoppedAsync
  /// ```
  /// - A Future which is true when ModbusMaster object is stopped.
  /// - When this is Future of true, then it means that resources of this object including including TCP sockets have been properly stopped.
  /// ```
  /// print(await modbusMaster.isStoppedAsync);
  /// ```
  Future<bool> get isStoppedAsync async {
    while (true) {
      if (_isNetworkIsolateRunning) {
        await Future.delayed(Duration.zero);
      } else {
        return true;
      }
    }
  }

  ///   ```
  ///   isRunning
  ///   ```
  ///    - A boolean field which tells whether this object i.e. Modbus Master object is running
  ///    ```
  ///    print(modbusMaster.isRunning);
  ///    ```
  bool get isRunning => _isNetworkIsolateRunning;

  /// ```
  /// responseFromSlaveDevices
  /// ```
  /// - Returns a stream of type SlaveResponse. (Only 3 out of 4 subtypes of SlaveResponse are elements of this stream.)
  ///    - SlaveResponseDataReceived
  ///    - SlaveResponseConnectionError
  ///    - SlaveResponseTimeoutError
  /// ```
  /// modbusMaster.responseFromSlaveDevices.listen(
  ///   (response) {
  ///     print(response);
  ///   },
  /// );
  /// ```
  Stream<SlaveResponse> get responseFromSlaveDevices {
    if (isStoppedSync) {
      throw Exception(
          "Response can only be obtained when modbus master is running."
          "Use start method of this class to start");
    } else {
      return _streamController!.stream;
    }
  }

  /// #### Object of this class MUST NOT be created using
  /// ```
  /// final modbusMaster = ModbusMaster();
  /// ```
  ///
  /// #### CORRECT WAY of creating object of this class is:-
  /// ```
  /// final modbusMaster = await ModbusMaster.start();
  /// ```
  ///
  ModbusMaster() {
    throw Exception("Correct way of creating object of this class is\n"
        "final modbusMaster = await ModbusMaster.start();");
  }

  ModbusMaster._create();

  /// ```
  /// start
  /// ```
  /// - Initializes object by properly setting up all its required components.
  /// ```
  /// final modbusMaster = await ModbusMaster.start();
  /// ```
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
      if (data is List) {
        Logging.i("Length of list = ${data.length}");
        Logging.i(data);
        for (final item in data) {
          Logging.i("TYPE = ${item.runtimeType}\n ITEM = $item");
        }
      }

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
          modbusMaster._receivePortOfMainIsolate?.close();
          break;
        default:
          if (data == null) {
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

  /// ```stop```
  /// - Disconnects connection with all active slave devices & shuts down Modbus
  ///  TCP master object.
  ///   ```
  ///   modbusMaster.stop();
  ///   ```
  /// - Program must not be exited or killed immediately after this ```stop```
  /// method.  It takes sometime to close all resources
  /// including TCP sockets.
  /// - Immediate exiting or killing program after ```stop``` method risk of
  /// program exit with open TCP socket.
  /// -  Ideally, programmer should use ```isStoppedAsync``` to know whether
  /// object has stopped. If ```isStoppedAsync``` returns Future of true, then program can be safely exited.
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

  ///```read```
  ///- Sends a read request to a slave device.
  ///- Returns transaction id :- Transaction id is a unique number
  ///   between 0 and 65535 for a Modbus TCP request.  Request & response
  ///  have same transaction id, using which they are identified.
  ///- At present, this library only supports reading single element.
  ///- Arguments of this method are:-
  ///    1. ```ipAddress``` :- ip address of slave device
  ///    2. ```portNumber``` :- port number of slave device, usually it is 502
  ///    3. ```unitId``` :- For slave device, which is not a Modbus Gateway, its usual value is 0 or 1.  unitId is specified for slave device or slave software.
  ///    4. ```blockNumber``` :- usual block number as per Modbus protocol
  ///    5. ```elementNumber``` :- usual element number as per Modbus protocol
  ///    6. ```timeoutMilliseconds``` :- any value between 200 and 10000
  /// ```
  /// // Sends a read request to read Coil 2 of a slave device with
  /// // ip address '192.168.1.3', port number 502 and unit id 1
  /// // with a timeout of 1000 milliseconds
  /// final transactionId = modbusMaster.read(
  ///  ipAddress: '192.168.1.3',
  ///  portNumber: 502,
  ///  unitId: 1,
  ///  blockNumber: 0,
  ///  elementNumber: 2,
  ///  timeoutMilliseconds: 1000,
  /// );
  /// ```
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
        isReadRequest: true,
        isWriteRequest: false,
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
        isReadRequest: true,
        isWriteRequest: false,
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
        isReadRequest: true,
        isWriteRequest: false,
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
        isReadRequest: true,
        isWriteRequest: false,
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

  ///```write```
  ///- Sends a write request to a slave device.
  ///- Returns transaction id :- Transaction id is a unique number
  ///   between 0 and 65535 for a Modbus TCP request.  Request & response
  ///  have same transaction id, using which they are identified.
  ///- At present, this library only supports writing to a single element.
  ///- Arguments of this method are:-
  ///  1. ```ipAddress``` :- ip address of slave device
  ///  2. ```portNumber``` :- port number of slave device, usually it is 502
  ///  3. ```unitId``` :- For slave device, which is not a Modbus Gateway, its usual value is 0 or 1.  unitId is specified for slave device or slave software.
  ///  4. ```blockNumber``` :- usual block number as per Modbus protocol
  ///  5. ```elementNumber``` :- usual element number as per Modbus protocol
  ///  6. ```timeoutMilliseconds``` :- any value between 200 and 10000
  ///  7. ```valueToBeWritten``` :- Provide 0 or 1 for coil. Provide value between 0 & 65535 for holding register.
  ///```
  /// // Sends a write request of value 999 to Holding Register 45
  /// // of a slave device with ip address '192.168.1.3',
  /// // port number 502 and unit id 1 with a timeout of
  /// // 1000 milliseconds.
  ///final transactionId = modbusMaster.write(
  ///  ipAddress: '192.168.1.3',
  ///  portNumber: 502,
  ///  unitId: 1,
  ///  blockNumber: 4,
  ///  elementNumber: 45,
  ///  timeoutMilliseconds: 1000,
  ///  valueToBeWritten: 999,
  ///);
  ///```
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
        ipAddress: ipAddress,
        portNumber: portNumber,
        unitId: unitId,
        blockNumber: blockNumber,
        elementNumber: elementNumber,
        timeoutMilliseconds: timeoutMilliseconds,
        transactionId: _transactionId,
        valueToBeWritten: valueToBeWritten,
        isReadRequest: false,
        isWriteRequest: true,
      ));
    } else if (blockNumber == 4) {
      Logging.i("TRYING TO SEND WRITE REQUEST FOR HOLDING REGISTER");
      _sendPortOfWorkerIsolate
          ?.send(_generateWriteRequestStreamElementForHoldingRegister(
        isReadRequest: false,
        isWriteRequest: true,
        ipAddress: ipAddress,
        portNumber: portNumber,
        unitId: unitId,
        blockNumber: blockNumber,
        elementNumber: elementNumber,
        timeoutMilliseconds: timeoutMilliseconds,
        transactionId: _transactionId,
        valueToBeWritten: valueToBeWritten,
      ));
    }

    return _transactionId;
  }

  UserRequestData _generateReadRequestStreamElementForCoil({
    required String ipAddress,
    required int portNumber,
    required int unitId,
    required int blockNumber,
    required int elementNumber,
    required int timeoutMilliseconds,
    required int transactionId,
    required bool isReadRequest,
    required bool isWriteRequest,
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
      isReadRequest: isReadRequest,
      isWriteRequest: isWriteRequest,
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
    required bool isReadRequest,
    required bool isWriteRequest,
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
      isReadRequest: isReadRequest,
      isWriteRequest: isWriteRequest,
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
    required bool isReadRequest,
    required bool isWriteRequest,
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
      isReadRequest: isReadRequest,
      isWriteRequest: isWriteRequest,
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
    required bool isReadRequest,
    required bool isWriteRequest,
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
      isReadRequest: isReadRequest,
      isWriteRequest: isWriteRequest,
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
    required bool isReadRequest,
    required bool isWriteRequest,
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
      isReadRequest: isReadRequest,
      isWriteRequest: isWriteRequest,
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
    required bool isReadRequest,
    required bool isWriteRequest,
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
      isReadRequest: isReadRequest,
      isWriteRequest: isWriteRequest,
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
/// `SlaveResponse` is a sealed class, hence its object is not created,
/// rather object of its sub-types are created internally by library.
/// These subtypes are received as an element of
/// stream `responseFromSlaveDevices` of object of class `ModbusMaster`.
///
/// These sub-types are as follows:-
/// 1. SlaveResponseDataReceived
/// 2. SlaveResponseConnectionError
/// 3. SlaveResponseTimeoutError
/// 4. SlaveResponseShutdownComplete
sealed class SlaveResponse extends Equatable {
  @override
  List<Object?> get props => [];
}

/// `SlaveResponseDataReceived`
/// - When slave device responds with a data, then object of this type is received from the stream responseFromSlaveDevices
/// - Fields of its objects are:-
///   1. `int transactionId` :- Each modbus transaction has a unique number from 0 to 65535. Request & response have same transaction id, using which they are identified.
///   2. `String ipAddress` :- ip address of slave device
///   3. `int portNumber` :- port number of slave device
///   4. `int unitId` :- Commonly used in  Modbus Gateway (TCP to Serial):- Multiple Modbus RTU devices are connected to single Modbus TCP address. Each Modbus RTU device has same ip address and port number but different unit id.
///   5. `int blockNumber` :- block number is 0 for Coil, 1 for Discrete Input, 3 for Input Register, 4 for Holding Register
///   6. `int elementNumber` :- element number is an integer value from 1 to 65536
///   7. `String mbap` :- Hexidecimal string of actual MBAP (as per Modbus TCP protocol) which is responded by slave device.
///   8. `String pdu` :- Hexidecimal string of actual PDU (as per Modbus TCP protocol) which is responded by slave device.
///   9. `bool isReadResponse` :- If PDU contains a read response, then it is true.
///   10. `int? readValue` :- If PDU contains a read response, then it contains its value.
///   11. `bool isWriteResponse`:- If PDU contains a write response, then it is true.
///   12. `int? writeValue`:- If PDU contains a write response, then it contains its value.
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

/// `SlaveResponseConnectionError`
/// - When TCP connection is not established with a slave device, then this element is received from stream responseFromSlaveDevices
/// - Fields of its objects are:-
///   1. `int transactionId` :- Each modbus transaction has a unique number from 0 to 65535. Request & response have same transaction id, using which they are identified.
///   2. `String ipAddress` :- ip address of slave device
///   3. `int portNumber` :- port number of slave device
///   4. `int unitId` :- Commonly used in  Modbus Gateway (TCP to Serial):- Multiple Modbus RTU devices are connected to single Modbus TCP address. Each Modbus RTU device has same ip address and port number but different unit id.
///   5. `int blockNumber` :- block number is 0 for Coil, 1 for Discrete Input, 3 for Input Register, 4 for Holding Register
///   6. `int elementNumber`:- element number is an integer value from 1 to 65536
///   7. `bool isReadResponse` :- If request was a read request, then it is true
///   8. `bool isWriteResponse` :- If request was a write request, then it is true
final class SlaveResponseConnectionError extends SlaveResponse {
  final int transactionId;
  final String ipAddress;
  final int portNumber;
  final int unitId;
  final int blockNumber;
  final int elementNumber;
  final bool isReadResponse;
  final bool isWriteResponse;

  SlaveResponseConnectionError({
    required this.transactionId,
    required this.ipAddress,
    required this.portNumber,
    required this.unitId,
    required this.blockNumber,
    required this.elementNumber,
    required this.isReadResponse,
    required this.isWriteResponse,
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
      "    isReadResponse:$isReadResponse, isWriteResponse:$isWriteResponse\n"
      "}";
}

/// ```SlaveResponseTimeoutError```
/// - When slave device does not respond within timeout value provided during read or write request, then this element is received from stream responseFromSlaveDevices
/// - Fields of its objects are:-
///     1. `int transactionId` :- Each modbus transaction has a unique number from 0 to 65535. Request & response have same transaction id, using which they are identified.
///     2. `String ipAddress` :- ip address of slave device
///     3. ` int portNumber` :- port number of slave device
///     4. `int unitId` :- Commonly used in  Modbus Gateway (TCP to Serial):- Multiple Modbus RTU devices are connected to single Modbus TCP address. Each Modbus RTU device has same ip address and port number but different unit id.
///     5. `int blockNumber` :- block number is 0 for Coil, 1 for Discrete Input, 3 for Input Register, 4 for Holding Register
///     6. `int elementNumber` :- element number is an integer value from 1 to 65536
///     7. `int timeoutMilliseconds` :- Slave has not been able to respond within this time.
///     8. `bool isReadResponse` :- If request was a read request, then it is true
///     9. `bool isWriteResponse` :- If request was a write request, then it is true
final class SlaveResponseTimeoutError extends SlaveResponse {
  final int transactionId;
  final String ipAddress;
  final int portNumber;
  final int unitId;
  final int blockNumber;
  final int elementNumber;
  final int timeoutMilliseconds;
  final bool isReadResponse;
  final bool isWriteResponse;

  SlaveResponseTimeoutError({
    required this.transactionId,
    required this.ipAddress,
    required this.portNumber,
    required this.unitId,
    required this.blockNumber,
    required this.elementNumber,
    required this.timeoutMilliseconds,
    required this.isReadResponse,
    required this.isWriteResponse,
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
      "    timeoutMilliseconds:$timeoutMilliseconds\n"
      "    isReadResponse:$isReadResponse, isWriteResponse:$isWriteResponse\n"
      "}";
}

/// `SlaveResponseShutdownComplete`
/// - This type is used for internal function of this library.
/// - Stream `responseFromSlaveDevices` of object of class `ModbusMaster`
///   never emits an element of this type.
final class SlaveResponseShutdownComplete extends SlaveResponse {
  @override
  List<Object?> get props => [];
}

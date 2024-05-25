/// 'modbus_master' is an easy to use package using which a dart program can work as a Modbus/TCP master device.
library;

import 'dart:async';
import 'dart:isolate';
import 'package:modbus_master/src/modbus_master_base.dart';

/// ## Steps to use this library
/// -   mark function async where this object will be used
/// -   make an instance of ModbusMaster class like this only.
///     ```
///     final modbusMaster = await ModbusMaster.start();
///     ```
/// -   listen to stream of response using stream
///     ```
///     modbusMaster.responses().listen(
///       (response) {
///         print(response);
///       }
///     );
///     ```
/// - Send request to slave using these commands
///    -   read single coil of a slave
///        ```
///        modbusMaster.readCoil(
///          ipv4: '192.168.29.163',
///          portNo: 502,
///          elementNumberOneTo65536: 11,
///        );
///        ```
///
///    -   read single discrete input of a slave
///        ```
///        modbusMaster.readDiscreteInput(
///          ipv4: '192.168.1.5',
///          elementNumberOneTo65536: 11,
///        );
///        ```
///    -   read single holding register of a slave
///        ```
///        modbusMaster.readHoldingRegister(
///          ipv4: '192.168.1.5',
///          elementNumberOneTo65536: 11,
///        );
///        ```
///    -   read single input register of a slave
///        ```
///        modbusMaster.readInputRegister(
///          ipv4: '192.168.1.5',
///          elementNumberOneTo65536: 11,
///        );
///        ```
///    -   write single coil of a slave
///        ```
///        modbusMaster.writeCoil(
///          ipv4: '192.168.1.5',
///          elementNumberOneTo65536: 11,
///          valueToBeWritten: true,
///        );
///        ```
///    -   write single holding register of a slave
///        ```
///        modbusMaster.writeHoldingRegister(
///          ipv4: '192.168.1.5',
///          elementNumberOneTo65536: 11,
///          valueToBeWritten: 15525,
///        );
///        ```
/// -   close must be called at end to close all tcp connections and stop modbus master
///     ```
///     modbusMaster.close();
///     ```
class ModbusMaster {
  final _responseStreamController = StreamController<Response>();
  final _table = Table();
  late SendPort _sendPort;
  bool _requestAllowed = false;

  ModbusMaster() {
    throw Exception(
        'Object of ModbusMaster class should never be instantiated like this.\n'
        'Correct way of instantiating is\n'
        'final modbusMaster = await ModbusMaster.start();\n');
  }

  ModbusMaster._instantiate();

  /// This method is the only way using which an object of ModbusMaster should be created.
  static Future<ModbusMaster> start() async {
    final modbusMaster = ModbusMaster._instantiate();

    ReceivePort receivePort = ReceivePort();
    dynamic sendPortDataType = receivePort.sendPort.runtimeType;

    bool bidirectionalCommunicationEstablished = false;

    Isolate workerIsolate = await Isolate.spawn(
      ModbusMasterForWorker.startWorker,
      receivePort.sendPort,
    );

    workerIsolate.hashCode;

    receivePort.listen(
      (element) {
        // print('PRINTING RECEIVE PORT ELEMENT $element');
        if (element.runtimeType == sendPortDataType) {
          // print('RECEIVED ELEMENT IS SENDPORT');
          modbusMaster._sendPort = element;
          bidirectionalCommunicationEstablished = true;
        } else if (element == null) {
          // print('null received by main isolate');
          receivePort.close();

          // workerIsolate.kill(priority: Isolate.immediate);
        } else {
          // print(element.runtimeType);
          // print('RECEIVED ELEMENT IS NOT SENDPORT');
          modbusMaster._responseStreamController.sink.add(
            Response.generateResponseAndEraseItsEntryFromChart(
              modbusResponseData: element,
              table: modbusMaster._table,
            ),
          );
        }
      },
      onDone: () {
        // print('DONE RECEIVED BY MAIN ISOLATE');
        receivePort.close();
      },
      onError: (_) {
        // print('ERROR RECEIVED BY MAIN ISOLATE');
        receivePort.close();
      },
    );

    while (!bidirectionalCommunicationEstablished) {
      await Future.delayed(Duration.zero);
    }

    modbusMaster._requestAllowed = true;

    return modbusMaster;
  }

  /// - This method closes all resources & disconnects all connections.
  /// - If any request is made after close( ), then exception is thrown.
  void close() {
    if (_requestAllowed) {
      _sendPort.send(null);
    }
    _requestAllowed = false;
  }

  ///returns a Stream of Response. All responses from every slave is received
  ///from here.
  ///
  ///It can be used like example given below.
  ///```
  ///modbusMaster.responses().listen(
  ///  (response){
  ///    print(response);
  ///  }
  ///);
  /// ```
  Stream<Response> responses() {
    if (!_requestAllowed) {
      throw Exception(
          '"responses" is called, either before "start", or after "close"');
    }

    return _responseStreamController.stream;

    // return _streamController.stream.map((modbusResponseData) {
    //   return Response.generateResponseAndEraseItsEntryFromChart(
    //       modbusResponseData: modbusResponseData, table: _table);
    // });
  }

  /// Request is sent to a slave using this method, for example
  /// ```
  /// _sendRequest(Request(
  ///   ipv4: '192.168.1.5',
  ///   transactionId: 1,
  ///   isWrite: Request.REQUEST_READ,
  ///   elementType: Request.ELEMENT_TYPE_HOLDING_REGISTER,
  ///   elementNumber: 1,
  ///   valueToBeWritten: null,
  /// ));
  /// ```
  /// Higher level methods, the names of which are given below use _sendRequest for sending request.
  /// -  readCoil
  /// -  readDiscreteInput
  /// -  readHoldingRegister
  /// -  readInputRegister
  /// -  writeCoil
  /// -  writeHoldingRegister
  void _sendRequest(Request request, {bool printRequest = false}) {
    if (!_requestAllowed) {
      throw Exception(
          '"sendRequest" is called, either before "start", or after "close"');
    }

    if (printRequest) {
      print(request);
    }
    // _requests.addLast(_modbusRequestDataFromRequest(request));

    // ++_countOfRequestForWhichResponsesNotReceived;
    // _requests.append(ModbusRequestData.fromRequest(request));

    // print(_requests);

    final modbusRequestData =
        ModbusRequestData.fromRequest(request: request, table: _table);

    _sendPort.send(modbusRequestData);
  }

  /// To send request to a slave for reading single discrete input of a slave, use this command
  /// ```
  /// modbusMaster.readDiscreteInput(
  ///   ipv4: '192.168.1.5',
  ///   elementNumberOneTo65536: 11,
  /// );
  /// ```
  void readDiscreteInput({
    required String ipv4,
    int portNo = 502,
    required int elementNumberOneTo65536,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    final request = Request.fromReadDiscreteInputValues(
      ipv4: ipv4,
      port: portNo,
      elementNumberFrom1To65536: elementNumberOneTo65536,
      timeout: timeout,
    );

    _sendRequest(request, printRequest: printRequest);
  }

  /// To send request to a slave for reading single coil, use this command
  /// ```
  /// modbusMaster.readCoil(
  ///   ipv4: '192.168.1.5',
  ///   elementNumberOneTo65536: 11,
  /// );
  /// ```
  void readCoil({
    required String ipv4,
    int portNo = 502,
    required int elementNumberOneTo65536,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    final request = Request.fromReadCoilValues(
      ipv4: ipv4,
      port: portNo,
      elementNumberFrom1To65536: elementNumberOneTo65536,
      timeout: timeout,
    );

    _sendRequest(request, printRequest: printRequest);
  }

  /// To send request to a slave for reading single 16-bit input register, use this command
  /// ```
  /// modbusMaster.readInputRegister(
  ///   ipv4: '192.168.1.5',
  ///   elementNumberOneTo65536: 11,
  /// );
  /// ```
  void readInputRegister({
    required String ipv4,
    int portNo = 502,
    required int elementNumberOneTo65536,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    final request = Request.fromReadInputRegisterValues(
      ipv4: ipv4,
      port: portNo,
      elementNumberFrom1To65536: elementNumberOneTo65536,
      timeout: timeout,
    );

    _sendRequest(request, printRequest: printRequest);
  }

  /// To send request to a slave to read single 16-bit holding register, use this command
  /// ```
  /// modbusMaster.readHoldingRegister(
  ///   ipv4: '192.168.1.5',
  ///   elementNumberOneTo65536: 11,
  /// );
  /// ```
  void readHoldingRegister({
    required String ipv4,
    int portNo = 502,
    required int elementNumberOneTo65536,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    final request = Request.fromReadHoldingRegisterValues(
      ipv4: ipv4,
      port: portNo,
      elementNumberFrom1To65536: elementNumberOneTo65536,
      timeout: timeout,
    );

    _sendRequest(request, printRequest: printRequest);
  }

  /// To send request to a slave for writing single coil, use this command
  /// ```
  /// modbusMaster.writeCoil(
  ///   ipv4: '192.168.1.5',
  ///   elementNumberOneTo65536: 11,
  ///   valueToBeWritten: true,
  /// );
  /// ```
  void writeCoil({
    required String ipv4,
    int portNo = 502,
    required int elementNumberOneTo65536,
    required bool valueToBeWritten,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    final request = Request.fromWriteCoilValues(
      ipv4: ipv4,
      port: portNo,
      elementNumberFrom1To65536: elementNumberOneTo65536,
      timeout: timeout,
      valueToBeWritten: valueToBeWritten,
    );

    _sendRequest(request, printRequest: printRequest);
  }

  /// To send request to a slave for writing single 16-bit holding register, use this command
  /// ```
  /// modbusMaster.writeHoldingRegister(
  ///   ipv4: '192.168.1.5',
  ///   elementNumberOneTo65536: 11,
  ///   valueToBeWritten: 15525,
  /// );
  /// ```
  void writeHoldingRegister({
    required String ipv4,
    int portNo = 502,
    required int elementNumberOneTo65536,
    required int integerValueToBeWrittenZeroTo65535,
    Duration timeout = const Duration(milliseconds: 1000),
    bool printRequest = false,
  }) {
    final request = Request.fromWriteHoldingRegisterValues(
      ipv4: ipv4,
      port: portNo,
      elementNumberFrom1To65536: elementNumberOneTo65536,
      timeout: timeout,
      valueToBeWritten: integerValueToBeWrittenZeroTo65535,
    );

    _sendRequest(request, printRequest: printRequest);
  }
}

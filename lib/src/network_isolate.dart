import 'dart:async';
import 'dart:io';
import 'dart:isolate' as isolate;
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:modbus_master/modbus_master.dart';
import 'package:modbus_master/src/my_logging.dart';

/*--------------------------------DATA STRUCTURE-----------------------------*/
sealed class UserRequest extends Equatable {
  @override
  List<Object?> get props => [];
}

final class UserRequestData extends UserRequest {
  // final bool isIpv4;
  // final bool isIpv6;
  final String ipAddress;
  final int portNumber;
  final int unitId;
  final int blockNumber;
  final int elementNumber;
  final int transactionId;
  final int timeoutMilliseconds;
  final Uint8List mbap;
  final Uint8List pdu;

  UserRequestData({
    // required this.isIpv4,
    // required this.isIpv6,
    required this.ipAddress,
    required this.portNumber,
    required this.unitId,
    required this.blockNumber,
    required this.elementNumber,
    required this.transactionId,
    required this.timeoutMilliseconds,
    required this.mbap,
    required this.pdu,
  });

  @override
  String toString() {
    return "UserRequestData {\n"
        // "    isIpv4:$isIpv4, isIpv6:$isIpv6, "
        "    ipAddress:$ipAddress, "
        "portNumber:$portNumber, unitId:$unitId, transactionId:$transactionId,\n"
        "    timeoutMilliseconds:$timeoutMilliseconds, mbap:$mbap, pdu:$pdu\n"
        "    blockNumber:$blockNumber, elementNumber:$elementNumber\n"
        "}";
  }
}

final class UserRequestShutdown extends UserRequest {}

/*------------------------------------FUNCTIONS------------------------------ */
/// convers Uint8List to single hexadecimal string
/// e.g. [255,10,15] => "0xFF0A0F"
String hexadecimalFromUint8List(Uint8List uint8List) {
  String hexValue = '0x';
  for (final byte in uint8List) {
    hexValue = hexValue + hexadecimalFrom8bitInteger(byte);
  }
  return hexValue;
}

/// converts an integer from 0 to 255 into hexadecimal String i.e. 00 to FF
String hexadecimalFrom8bitInteger(int num) {
  final nibbleLower = num % 16;
  final nibbleHigher = num ~/ 16;
  return "${hexadecimalFrom4bitInteger(nibbleHigher)}"
      "${hexadecimalFrom4bitInteger(nibbleLower)}";
}

/// converts an integer from 0 to 15 into hexadecimal String i.e. 0 to F
String hexadecimalFrom4bitInteger(int num) {
  switch (num) {
    case 0:
      return '0';
    case 1:
      return '1';
    case 2:
      return '2';
    case 3:
      return '3';
    case 4:
      return '4';
    case 5:
      return '5';
    case 6:
      return '6';
    case 7:
      return '7';
    case 8:
      return '8';
    case 9:
      return '9';
    case 10:
      return 'A';
    case 11:
      return 'B';
    case 12:
      return 'C';
    case 13:
      return 'D';
    case 14:
      return 'E';
    case 15:
      return 'F';
    default:
      throw Exception("Expected argument to be an integer from 0 to 15");
  }
}

// int integerFrom16BitUint8List(Uint8List uint8List) {}

({bool isReadResponse, int? readValue, bool isWriteResponse, int? writeValue})
    getValueFromModbusPdu(Uint8List pdu) {
  final functionCode = pdu[0];

  final isReadResponse = functionCode == 1 ||
      functionCode == 2 ||
      functionCode == 3 ||
      functionCode == 4;
  int? readValue;
  if (functionCode == 1) {
    //BY DEFAULT READING SINGLE COIL
    readValue = pdu[1] == 1 ? pdu[2] : null;
  } else if (functionCode == 2) {
    // READING SINGLE COIL
    readValue = pdu[1] == 1 ? pdu[2] : null;
  } else if (functionCode == 3) {
    // READING SINGLE HOLDING REGISTER
    readValue = pdu[1] == 2 ? pdu[2] * 256 + pdu[3] : null;
  } else if (functionCode == 4) {
    // READING SINGLE INPUT REGISTER
    readValue = pdu[1] == 2 ? pdu[2] * 256 + pdu[3] : null;
  }

  final isWriteResponse = functionCode == 5 || functionCode == 6;
  int? writeValue;
  if (functionCode == 5) {
    writeValue = pdu[3] == 255 ? 1 : 0;
  } else if (functionCode == 6) {
    writeValue = pdu[3] * 256 + pdu[4];
  }

  return (
    isReadResponse: isReadResponse,
    readValue: readValue,
    isWriteResponse: isWriteResponse,
    writeValue: writeValue
  );
}

/*------------------------------DATA & PROCEDURES---------------------------- */

class NetworkIsolateData {
  static const int connectionLimit = 99;
  static const int limitRequestSent = 2000;
  static const int limitResponseReceived = 2000;
  static const int socketConnectionTimeoutMilliseconds = 1000;

  bool isShutdownRequestReceived = false;
  late isolate.ReceivePort receivePortOfWorkerIsolate;

  final Map<({String ipAddress, int portNumber}), Socket> tableAliveSockets =
      {};

  final Map<
      ({String ipAddress, int portNumber, int unitId, int transactionId}),
      ({
        // bool isIpv4,
        // bool isIpv6,
        int blockNumber,
        int elementNumber,
        int timeoutMilliseconds,
        DateTime timestampWhenMessageSentToSocket
      })> tableRequestSentToSocket = {};

  final Map<
      ({String ipAddress, int portNumber, int unitId, int transactionId}),
      ({
        Uint8List mbap,
        Uint8List pdu,
        DateTime timestampWhenMessageReceivedFromSocket
      })> tableMessageReceivedFromSocket = {};

  void checkTimeOutAndConnectionOfMessageSentToSocket(
      isolate.SendPort sendPort) {
    final List<
            ({String ipAddress, int portNumber, int unitId, int transactionId})>
        keysOfRowsToBeDeleted = [];

    final nowTimestamp = DateTime.now();

    for (final entry in tableRequestSentToSocket.entries) {
      if (nowTimestamp
              .difference(entry.value.timestampWhenMessageSentToSocket) >
          Duration(milliseconds: entry.value.timeoutMilliseconds)) {
        keysOfRowsToBeDeleted.add(entry.key);
        sendPort.send(SlaveResponseTimeoutError(
          transactionId: entry.key.transactionId,
          // isIpv4: entry.value.isIpv4,
          // isIpv6: entry.value.isIpv6,
          ipAddress: entry.key.ipAddress,
          portNumber: entry.key.portNumber,
          unitId: entry.key.unitId,
          blockNumber: entry.value.blockNumber,
          elementNumber: entry.value.elementNumber,
          timeoutMilliseconds: entry.value.timeoutMilliseconds,
        ));
      } else if (tableAliveSockets[(
            ipAddress: entry.key.ipAddress,
            portNumber: entry.key.portNumber
          )] !=
          null) {
        //  DO NOTHING BECAUSE
        //  - REQUEST HAS BEEN SENT & TIMEOUT HAS NOT OCCURED, AND
        //  - ITS SOCKET CONNECTION IS STILL ALIVE
      } else {
        keysOfRowsToBeDeleted.add(entry.key);
        sendPort.send(SlaveResponseConnectionError(
          transactionId: entry.key.transactionId,
          // isIpv4: entry.value.isIpv4,
          // isIpv6: entry.value.isIpv6,
          ipAddress: entry.key.ipAddress,
          portNumber: entry.key.portNumber,
          unitId: entry.key.unitId,
          blockNumber: entry.value.blockNumber,
          elementNumber: entry.value.elementNumber,
        ));
      }
    }

    for (final key in keysOfRowsToBeDeleted) {
      tableRequestSentToSocket.remove(key);
    }
  }

  void checkMessagesReceivedFromVariousSockets(isolate.SendPort sendPort) {
    final List<
            ({String ipAddress, int portNumber, int unitId, int transactionId})>
        keysOfRowsToBeDeleted = [];

    for (final entry in tableMessageReceivedFromSocket.entries) {
      final requestSentToSocket = tableRequestSentToSocket[entry.key];
      if (requestSentToSocket != null) {
        final valueFromPdu = getValueFromModbusPdu(entry.value.pdu);

        final slaveResponseDataReceived = SlaveResponseDataReceived(
            transactionId: entry.key.transactionId,
            // isIpv4: requestSentToSocket.isIpv4,
            // isIpv6: requestSentToSocket.isIpv6,
            ipAddress: entry.key.ipAddress,
            portNumber: entry.key.portNumber,
            unitId: entry.key.unitId,
            blockNumber: requestSentToSocket.blockNumber,
            elementNumber: requestSentToSocket.elementNumber,
            mbap: hexadecimalFromUint8List(entry.value.mbap),
            pdu: hexadecimalFromUint8List(entry.value.pdu),
            isReadResponse: valueFromPdu.isReadResponse,
            readValue: valueFromPdu.readValue,
            isWriteResponse: valueFromPdu.isWriteResponse,
            writeValue: valueFromPdu.writeValue);

        sendPort.send(slaveResponseDataReceived);

        Logging.i(
            "SLAVE RESPONSE DATA SENT TO MASTER ISOLATE:- $slaveResponseDataReceived");
      }
      keysOfRowsToBeDeleted.add(entry.key);
    }

    tableMessageReceivedFromSocket.clear();

    for (final key in keysOfRowsToBeDeleted) {
      tableRequestSentToSocket.remove(key);
    }
  }

  void listenToElementReceivedFromMainIsolate(
      UserRequest request,
      isolate.SendPort sendPort,
      isolate.ReceivePort receivePortWorkerIsolate) async {
    switch (request) {
      case UserRequestData _:
        final socket = tableAliveSockets[(
          ipAddress: request.ipAddress,
          portNumber: request.portNumber
        )];

        if (socket != null) {
          try {
            // socket.write(Uint8List.fromList(request.mbap + request.pdu));
            socket.add(request.mbap + request.pdu);
            // socket.
            final timeStampMessageSentToSocket = DateTime.now();

            // final isFullTableRequestSentToSocket =
            //     tableRequestSentToSocket.length >=
            //         NetworkIsolate.limitRequestSent;
            if (tableRequestSentToSocket.length >=
                NetworkIsolateData.limitRequestSent) {
              final keyOfMostPreviousRequest =
                  tableRequestSentToSocket.keys.first;

              tableRequestSentToSocket.remove(keyOfMostPreviousRequest);
            }

            tableRequestSentToSocket[(
              ipAddress: request.ipAddress,
              portNumber: request.portNumber,
              unitId: request.unitId,
              transactionId: request.transactionId
            )] = (
              // isIpv4: request.isIpv4,
              // isIpv6: request.isIpv6,
              blockNumber: request.blockNumber,
              elementNumber: request.elementNumber,
              timeoutMilliseconds: request.timeoutMilliseconds,
              timestampWhenMessageSentToSocket: timeStampMessageSentToSocket
            );
            Logging.i("SENT TO SOCKET :- ${request.mbap + request.pdu}");
          } catch (e, f) {
            Logging.i(e);
            Logging.i(f);
          }
        } else {
          try {
            final socketNew = await Socket.connect(
                request.ipAddress, request.portNumber,
                timeout: Duration(
                    milliseconds: NetworkIsolateData
                        .socketConnectionTimeoutMilliseconds));

            Logging.i(
                "SOCKET CONNECTION CREATED :- ${socketNew.remoteAddress.address}, "
                "${socketNew.remotePort}");
            // socketNew.remoteAddress..;

            _setUpSocketListenerAndDeletion(
                socketNew, request.ipAddress, request.portNumber);

            if (tableAliveSockets.length >=
                NetworkIsolateData.connectionLimit) {
              final keyToBeDeleted = tableAliveSockets.keys.first;
              final socketToBeDestroyed = tableAliveSockets[keyToBeDeleted];
              socketToBeDestroyed?.destroy();
              tableAliveSockets.remove(keyToBeDeleted);
            }

            tableAliveSockets[(
              ipAddress: request.ipAddress,
              portNumber: request.portNumber
            )] = socketNew;

            // socketNew.write(Uint8List.fromList(request.mbap + request.pdu));
            socketNew.add(request.mbap + request.pdu);
            final timeStampMessageSentToSocket = DateTime.now();

            // socketNew.

            // final isFullTableRequestSentToSocket =
            //     tableRequestSentToSocket.length >=
            //         NetworkIsolate.limitRequestSent;
            if (tableRequestSentToSocket.length >=
                NetworkIsolateData.limitRequestSent) {
              final keyOfMostPreviousRequest =
                  tableRequestSentToSocket.keys.first;

              tableRequestSentToSocket.remove(keyOfMostPreviousRequest);
            }

            tableRequestSentToSocket[(
              ipAddress: request.ipAddress,
              portNumber: request.portNumber,
              unitId: request.unitId,
              transactionId: request.transactionId
            )] = (
              // isIpv4: request.isIpv4,
              // isIpv6: request.isIpv6,
              blockNumber: request.blockNumber,
              elementNumber: request.elementNumber,
              timeoutMilliseconds: request.timeoutMilliseconds,
              timestampWhenMessageSentToSocket: timeStampMessageSentToSocket
            );
            Logging.i("SENT TO SOCKET :- ${request.mbap + request.pdu}");
          } catch (e, f) {
            Logging.i(e);
            Logging.i(f);
            sendPort.send(SlaveResponseConnectionError(
              transactionId: request.transactionId,
              // isIpv4: request.isIpv4,
              // isIpv6: request.isIpv6,
              ipAddress: request.ipAddress,
              portNumber: request.portNumber,
              unitId: request.unitId,
              blockNumber: request.blockNumber,
              elementNumber: request.elementNumber,
            ));
          }
        }
        break;
      case UserRequestShutdown _:
        isShutdownRequestReceived = true;

        while (tableAliveSockets.isNotEmpty) {
          final firstKey = tableAliveSockets.keys.first;
          final socket = tableAliveSockets[firstKey];
          socket?.destroy();
          socket?.close();
          tableAliveSockets.remove(firstKey);
        }

        tableAliveSockets.clear();
        tableRequestSentToSocket.clear();
        tableMessageReceivedFromSocket.clear();
        receivePortWorkerIsolate.close();
        Logging.i("CLOSE COMMAND GIVEN TO RECEIVE PORT OF WORKER");
        break;
    }
  }

  void _setUpSocketListenerAndDeletion(
      Socket socketNew, String ipAddress, int portNumber) {
    socketNew.listen((receivedMessage) {
      Logging.i("-------------------RECEIVED FROM SOCKET:-----------------\n"
          "$receivedMessage");
      final timeStampNow = DateTime.now();
      if (receivedMessage.length < 8 || receivedMessage.length > 260) {
        // DROP MESSAGE BECAUSE IT DOES NOT CONFORM TO MODBUS A.D.U. SIZE
        Logging.i(receivedMessage);
        Logging.i("DROPPED ADU DUE TO LENGTH < 8 OR LENGTH > 260");
      } else {
        if (receivedMessage[4] * 256 + receivedMessage[5] !=
            receivedMessage.length - 6) {
          // DROP MESSAGE BECAUSE LENGTH AS PER MBAP IS NOT EQUAL TO
          // PDU.LENGTH + 1
          Logging.i(receivedMessage);
          Logging.i("DROPPED ADU DUE TO LENGTH NOT AS PER M.B.A.P.");
        } else {
          if (tableMessageReceivedFromSocket.length >=
              NetworkIsolateData.limitResponseReceived) {
            final keyToBeDeleted = tableMessageReceivedFromSocket.keys.first;
            tableMessageReceivedFromSocket.remove(keyToBeDeleted);
          }
          final mbap = receivedMessage.sublist(0, 7);
          final pdu = receivedMessage.sublist(7);
          final transactionId = mbap[0] * 256 + mbap[1];
          final unitId = mbap[6];

          tableMessageReceivedFromSocket[(
            ipAddress: ipAddress,
            portNumber: portNumber,
            unitId: unitId,
            transactionId: transactionId
          )] = (
            mbap: mbap,
            pdu: pdu,
            timestampWhenMessageReceivedFromSocket: timeStampNow
          );
          Logging.i(receivedMessage);
          Logging.i("ADU INSERTED IN TABLE:- MESSAGE RECEIVED FROM SOCKET");
        }
      }
    }, onDone: () {
      Logging.i(
          "DONE RECEIVED IN SOCKET : $ipAddress , $portNumber, ${socketNew.remoteAddress.type}");
      socketNew.destroy();
      final keyToBeDeleted = (ipAddress: ipAddress, portNumber: portNumber);
      if (tableAliveSockets[keyToBeDeleted] != null) {
        tableAliveSockets.remove(keyToBeDeleted);
      }

      Logging.i("TABLE ALIVE SOCKETS : $tableAliveSockets");
    }, onError: (e) {
      socketNew.destroy();
      final keyToBeDeleted = (ipAddress: ipAddress, portNumber: portNumber);
      if (tableAliveSockets[keyToBeDeleted] != null) {
        tableAliveSockets.remove(keyToBeDeleted);
      }
      Logging.i("ERROR RECEIVED IN SOCKET : $ipAddress , $portNumber");
    });
  }
}

/*------------------------------ISOLATE TASK----------------------------------*/
void networkIsolateTask(isolate.SendPort sendPortWorkerIsolate) async {
  final networkIsolateData = NetworkIsolateData();

  networkIsolateData.receivePortOfWorkerIsolate = isolate.ReceivePort();

  sendPortWorkerIsolate
      .send(networkIsolateData.receivePortOfWorkerIsolate.sendPort);

  networkIsolateData.receivePortOfWorkerIsolate.listen((data) {
    Logging.i("WORKER RECEIVED:- \n$data");
    networkIsolateData.listenToElementReceivedFromMainIsolate(data,
        sendPortWorkerIsolate, networkIsolateData.receivePortOfWorkerIsolate);
  }, onDone: () {
    Logging.i("WORKER ISOLATE:- \nDONE RECEIVED.");
  }, onError: (e, f) {});

  while (true) {
    networkIsolateData
        .checkTimeOutAndConnectionOfMessageSentToSocket(sendPortWorkerIsolate);
    await Future.delayed(Duration.zero);
    networkIsolateData
        .checkMessagesReceivedFromVariousSockets(sendPortWorkerIsolate);
    await Future.delayed(Duration.zero);

    if (networkIsolateData.isShutdownRequestReceived &&
        networkIsolateData.tableAliveSockets.isEmpty &&
        networkIsolateData.tableMessageReceivedFromSocket.isEmpty &&
        networkIsolateData.tableRequestSentToSocket.isEmpty) {
      break;
    }
  }

  sendPortWorkerIsolate.send(SlaveResponseShutdownComplete());

  Logging.i("LAST STATEMENT OF WORKER ISOLATE");
}

// void networkIsolateTask(Sendport sendPort) async {
//   ;
//   //
// }

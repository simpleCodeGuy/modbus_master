**"modbus_master" is an easy to use package using which a dart program can work as a Modbus/TCP master device.**

# Features
- Currently users can use only these features of Modbus/TCP protocol:
  - Read Single Coil
  - Read Single Discrete Input
  - Read Single Input Register
  - Read Single Holding Register
  - Write Single Coil
  - Write Single Holding Register
- This package handles socket networking part in a separate isolate so that main isolate is free to handle other tasks like UI part of flutter.
- This package can be used on platforms which supports dart:io & dart:isolate i.e. WINDOWS, LINUX, MACOS, ANDROID, IOS.

# Limitations
- Tested with only ipv4.
- Only single element can be read at once. Reading multiple coils or multiple registers is not implemented in this library, although reading multiple elements at once is specified in Modbus/TCP protocol.
- Only single element can be written to at once. Writing to multiple coils or to multiple registers is not implemented in this library, although writing to multiple elements at once is specified in Modbus/TCP protocol.

# How to use this library?
-   make an instance of ModbusMaster class
    ```
    final modbusMaster = await ModbusMaster.start();
    ```
-   Listen to response from slave devices
    ```
    modbusMaster.responseFromSlaveDevices.listen(
      (response) {
        print(response);

      },
    );
    ```
- Send read request to slave device
  ```
  final transactionIdReadRequest = modbusMaster.read(
    ipAddress: '192.168.1.3',
    portNumber: 502,
    unitId: 1,
    blockNumber: 4,
    elementNumber: 6000,
    timeoutMilliseconds: 1000,
  );
  ```
-   Send write request to slave device
    ```
    final transactionIdWriteRequest = modbusMaster.write(
      ipAddress: '192.168.1.3',
      portNumber: 502,
      unitId: 1,
      blockNumber: 0,
      elementNumber: 3001,
      timeoutMilliseconds: 1000,
      valueToBeWritten: i % 2,
    );
    ```
- Stop object so that all socket connections are disconnected and resources are released.
    ```
    modbusMaster.stop();
    ```

- Wait to know that that all resources have been properly stopped
    ```
    final isProperlyStopped = await modbusMaster.isStoppedAsync;
    ```
# Example program:-  
### First start a Modbus TCP Slave Server. 
If you already have access to a Modbus TCP Slave device, then skip this.

* If you do not have access to a Modbus TCP Slave device, then a sample slave program is provided which can be found in "example/modbus_slave.py".

*  Requirements: 
    * python programming language 
    * pymodbus library


*  Steps to run sample Modbus TCP Slave Server
    * Open folder in terminal where file "modbus_slave.py" exists
    * Use below command in terminal to run sample Modbus TCP Slave Server
      
      `python modbus_slave.py`

### Start Modbus TCP Master object. Send read request to slave device for reading Holding Register 6001,6002,6003,6004,6005. When 5 responses are received from slave device, then object is stopped.

modbus_master_example.dart
```
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
        ipAddress: '192.168.29.166', // change it as per your slave device
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
```

# Class and its methods provided in this library
### (I) class ModbusMaster and its methods
1. `start`
    - Initializes object by properly setting up all its required components.
    ```
    final modbusMaster = await ModbusMaster.start();
    ```

2. `responseFromSlaveDevices`
    - Returns a stream of type SlaveResponse. (Only 3 out of 4 subtypes of SlaveResponse are elements of this stream.)
        - SlaveResponseDataReceived
        - SlaveResponseConnectionError
        - SlaveResponseTimeoutError
    ```
    modbusMaster.responseFromSlaveDevices.listen(
      (response) {
        print(response);
      },
    );
    ```
    
3. `isRunning`
    - A boolean field which tells whether this object i.e. Modbus Master object is running
    ```
    print(modbusMaster.isRunning);
    ```
4. `isStoppedSync`
    - A boolean field which tells whether ModbusMaster object is stopped.
    - When this is true, then it means that all resources of this object including TCP sockets have been properly stopped.
    ```
    print(modbusMaster.isStoppedSync);
    ```
5. `isStoppedAsync`
    - A Future which is true when ModbusMaster object is stopped.
    - When this is Future of true, then it means that resources of this object including including TCP sockets have been properly stopped.
    ```
    print(await modbusMaster.isStoppedAsync);
    ```
6. `timeoutMillisecondsMinimum`
    - A constant value of 200. 
This library supports minimum timeout of 200 milliseconds i.e. 0.2 seconds.
    ```
    print(ModbusMaster.timeoutMillisecondsMinimum);
    // 200
    ```
7. `timeoutMillisecondsMaximum`
   - A constant value of 10000. This library supports minimum timeout of 10000 milliseconds i.e. 10 seconds
   ```
   print(ModbusMaster.timeoutMillisecondsMaximum);
   // 10000
   ```
8. `socketConnectionTimeoutMilliseconds`
    - It is the timeout value for establishing TCP connection with slave device.
    ```
    print(ModbusMaster.socketConnectionTimeoutMilliseconds);
    // 1000
    ```
9. `read`
    - Sends a read request to a slave device.
    - Returns transaction id :- Transaction id is a unique number between 0 and 65535 for a Modbus TCP request.  Request & response have same transaction id, using which they are identified.
    - At present, this library only supports reading single element.
    - Arguments of this method are:-
        1. `ipAddress` :- ip address of slave device
        2. `portNumber` :- port number of slave device, usually it is 502
        3. `unitId` :- For slave device, which is not a Modbus Gateway, its usual value is 0 or 1.  unitId is specified for slave device or slave software.
        4. `blockNumber` :- usual block number as per Modbus protocol
        5. `elementNumber` :- usual element number as per Modbus protocol
        6. `timeoutMilliseconds` :- any value between 200 and 10000
    ```
    // Sends a read request to read Coil 2 of a slave device with 
    // ip address '192.168.1.3', port number 502 and unit id 1
    // with a timeout of 1000 milliseconds 
    final transactionId = modbusMaster.read(
      ipAddress: '192.168.1.3',
      portNumber: 502,
      unitId: 1,
      blockNumber: 0,
      elementNumber: 2,
      timeoutMilliseconds: 1000,
    );

    ```
10. `write`
    - Sends a write request to a slave device.
    - Returns transaction id :- Transaction id is a unique number between 0 and 65535 for a Modbus TCP request.  Request & response have same transaction id, using which they are identified.
    - At present, this library only supports writing to a single element.
    - Arguments of this method are:-
      1. `ipAddress` :- ip address of slave device
      2. `portNumber` :- port number of slave device, usually it is 502
      3. `unitId` :- For slave device, which is not a Modbus Gateway, its usual value is 0 or 1.  unitId is specified for slave device or slave software.
      4. `blockNumber` :- usual block number as per Modbus protocol
      5. `elementNumber` :- usual element number as per Modbus protocol
      6. `timeoutMilliseconds` :- any value between 200 and 10000
      7. `valueToBeWritten` :- Provide 0 or 1 for coil. Provide value between 0 & 65535 for holding register.
    ```
    // Sends a write request of value 999 to Holding Register 45
    // of a slave device with ip address '192.168.1.3', 
    // port number 502 and unit id 1 with a timeout of 
    // 1000 milliseconds.
    final transactionId = modbusMaster.write(
      ipAddress: '192.168.1.3',
      portNumber: 502,
      unitId: 1,
      blockNumber: 4,
      elementNumber: 45,
      timeoutMilliseconds: 1000,
      valueToBeWritten: 999,
    );
    ```

11. `stop`
    - Disconnects connection with all active slave devices & shuts down Modbus TCP master object.
      ```
      modbusMaster.stop();
      ```
    - Program must not be exited or killed immediately after this `stop` method.  It takes sometime to close all resources including TCP sockets.
    - Immediate exiting or killing program after `stop` method involves risk of program exit with open TCP socket.
    -  Ideally, programmer should use `isStoppedAsync` to know whether object has stopped. If `isStoppedAsync` returns Future of true, then program can be safely exited.

### (II) sealed class SlaveResponse class and its sub types
`SlaveResponse` is a sealed class, hence its object is not created, rather object of its sub-types are created internally by library. These subtypes are received as an element of stream `responseFromSlaveDevices` of object of class `ModbusMaster`. These sub-types are as follows:
1. `SlaveResponseConnectionError`
    - When TCP connection is not established with a slave device, then this element is received from stream responseFromSlaveDevices
    - Fields of its objects are:-
      1. `int transactionId` :- Each modbus transaction has a unique number from 0 to 65535. Request & response have same transaction id, using which they are identified.
      2. ` String ipAddress` :- ip address of slave device
      3. `int portNumber` :- port number of slave device
      4. `int unitId` :- Commonly used in  Modbus Gateway (TCP to Serial):- Multiple Modbus RTU devices are connected to single Modbus TCP address. Each Modbus RTU device has same ip address and port number but different unit id.
      5. `int blockNumber` :- block number is 0 for Coil, 1 for Discrete Input, 3 for Input Register, 4 for Holding Register
      6. `int elementNumber`:- element number is an integer value from 1 to 65536
      7. `bool isReadResponse` :- If request was a read request, then it is true
      8. `bool isWriteResponse` :- If request was a write request, then it is true
2. `SlaveResponseTimeoutError`
    - When slave device does not respond within timeout value provided during read or write request, then this element is received from stream responseFromSlaveDevices
    - Fields of its objects are:-
        1. `int transactionId` :- Each modbus transaction has a unique number from 0 to 65535. Request & response have same transaction id, using which they are identified.
        2. ` String ipAddress` :- ip address of slave device
        3. `int portNumber` :- port number of slave device
        4. `int unitId` :- Commonly used in  Modbus Gateway (TCP to Serial):- Multiple Modbus RTU devices are connected to single Modbus TCP address. Each Modbus RTU device has same ip address and port number but different unit id.
        5. `int blockNumber` :- block number is 0 for Coil, 1 for Discrete Input, 3 for Input Register, 4 for Holding Register
        6. `int elementNumber` :- element number is an integer value from 1 to 65536
        7. `int timeoutMilliseconds` :- Slave has not been able to respond within this time.
        8. `bool isReadResponse` :- If request was a read request, then it is true
        9. `bool isWriteResponse` :- If request was a write request, then it is true

3. `SlaveResponseDataReceived`
    - When slave device responds with a data, then object of this type is received from the stream responseFromSlaveDevices
    - Fields of its objects are:-
      1. `int transactionId` :- Each modbus transaction has a unique number from 0 to 65535. Request & response have same transaction id, using which they are identified.
      2. `String ipAddress` :- ip address of slave device
      3. `int portNumber` :- port number of slave device
      4. `int unitId` :- Commonly used in  Modbus Gateway (TCP to Serial):- Multiple Modbus RTU devices are connected to single Modbus TCP address. Each Modbus RTU device has same ip address and port number but different unit id.
      5. `int blockNumber` :- block number is 0 for Coil, 1 for Discrete Input, 3 for Input Register, 4 for Holding Register
      6. `int elementNumber` :- element number is an integer value from 1 to 65536
      7. `String mbap` :- Hexidecimal string of actual MBAP (as per Modbus TCP protocol) which is responded by slave device.
      8. `String pdu` :- Hexidecimal string of actual PDU (as per Modbus TCP protocol) which is responded by slave device.
      9. `bool isReadResponse` :- If PDU contains a read response, then it is true.
      10. `int? readValue` :- If PDU contains a read response, then it contains its value.
      11. `bool isWriteResponse`:- If PDU contains a write response, then it is true.
      12. `int? writeValue`:- If PDU contains a write response, then it contains its value.
  
  

4. `SlaveResponseShutdownComplete`
    - This type is used for internal function of this library.
    - Stream `responseFromSlaveDevices` of object of class `ModbusMaster` never emits an element of this type.
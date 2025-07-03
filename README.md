**'modbus_master' is an easy to use package using which a dart program can work as a Modbus/TCP master device.**

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
- Only single element can be read at once. Reading multiple coils or multiple registers is not implemented in this library, although reading multiple elements is specified in Modbus/TCP implementation.
- Only single element can be written to at once. Writing to multiple coils or to multiple registers is not implemented in this library, although writing to multiple elements is specified in Modbus/TCP protocol.

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
  modbusMaster.read(
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
    modbusMaster.write(
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
# Example program:-  
### Send read request to slave device for reading Holding Register 6001,6002,6003,6004,6005. When 5 responses are received from slave device, then object is stopped.
```
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
        blockNumber: 4,
        elementNumber: 6000 + i,
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

```

# Class and its methods provided in this library
### (I) class ModbusMaster and its methods
1. ```start```
    - Initializes object by properly setting up all its required components.
    ```
    final modbusMaster = await ModbusMaster.start();
    ```

2. ```responseFromSlaveDevices```
    - Returns a stream of type SlaveResponse. Only 3 of its subtypes are elements of this stream.
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
3. ```isRunning```
    - A boolean field which tells whether this object i.e. Modbus Master object is running
    ```
    print(modbusMaster.isRunning);
    ```
4. ```isStoppedSync```
    - A boolean field which tells whether ModbusMaster object is stopped.
    ```
    print(modbusMaster.isStoppedSync);
    ```
5. ```isStoppedAsync```
    - A Future which is true when ModbusMaster object is stopped.
    ```
    print(await modbusMaster.isStoppedAsync);
    ```
6. ```timeoutMillisecondsMinimum```
    - A constant value of 200. 
This library supports minimum timeout of 200 milliseconds i.e. 0.2 seconds.
    ```
    print(ModbusMaster.timeoutMillisecondsMinimum);
    // 200
    ```
7. ```timeoutMillisecondsMaximum```
   - A constant value of 10000. This library supports minimum timeout of 10000 milliseconds i.e. 10 seconds
   ```
   print(ModbusMaster.timeoutMillisecondsMaximum);
   // 10000
   ```
8. ```socketConnectionTimeoutMilliseconds```
    - It is the timeout value for establishing TCP connection with slave device.
    ```
    print(ModbusMaster.socketConnectionTimeoutMilliseconds);
    // 1000
    ```
9. ```read```
    - Sends a read request to a slave device.
    - At present, this library only supports reading single element.
    - Arguments of this method are:-
        1. ```ipAddress``` :- ip address of slave device
        2. ```portNumber``` :- port number of slave device, usually it is 502
        3. ```unitId``` :- For slave device, which is not a Modbus Gateway, its usual value is 0 or 1.  unitId is specified for slave device or slave software.
        4. ```blockNumber``` :- usual block number as per Modbus protocol
        5. ```elementNumber``` :- usual element number as per Modbus protocol
        6. ```timeoutMilliseconds``` :- any value between 200 and 10000
    ```
    // Sends a read request to read Coil 2 of a slave device with 
    // ip address '192.168.1.3', port number 502 and unit id 1
    // with a timeout of 1000 milliseconds 
    modbusMaster.read(
      ipAddress: '192.168.1.3',
      portNumber: 502,
      unitId: 1,
      blockNumber: 0,
      elementNumber: 2,
      timeoutMilliseconds: 1000,
    );

    ```
10. ```write```
    - Sends a write request to a slave device.
    - At present, this library only supports writing to a single element.
    - Arguments of this method are:-
      1. ```ipAddress``` :- ip address of slave device
      2. ```portNumber``` :- port number of slave device, usually it is 502
      3. ```unitId``` :- For slave device, which is not a Modbus Gateway, its usual value is 0 or 1.  unitId is specified for slave device or slave software.
      4. ```blockNumber``` :- usual block number as per Modbus protocol
      5. ```elementNumber``` :- usual element number as per Modbus protocol
      6. ```timeoutMilliseconds``` :- any value between 200 and 10000
      7. ```valueToBeWritten``` :- Provide 0 or 1 for coil. Provide value between 0 & 65535 for holding register.
    ```
    // Sends a write request of value 999 to Holding Register 45
    // of a slave device with ip address '192.168.1.3', 
    // port number 502 and unit id 1 with a timeout of 
    // 1000 milliseconds.
    modbusMaster.write(
      ipAddress: '192.168.1.3',
      portNumber: 502,
      unitId: 1,
      blockNumber: 4,
      elementNumber: 45,
      timeoutMilliseconds: 1000,
      valueToBeWritten: 999,
    );
    ```

11. ```close```
    - Disconnects connection with all active slave devices & shuts down Modbus TCP master object.
    ```
    modbusMaster.stop();
    ```

### (II) sealed class SlaveResponse class and its sub types
```SlaveResponse``` is a sealed class, hence its object is not created, rather object of its sub-types are created internally by library. These subtypes are received as an element of stream ```responseFromSlaveDevices```. These sub-types are as follows:
1. ```SlaveResponseDataReceived```
    - When TCP connection is not established with a slave device, then this element is received from stream responseFromSlaveDevices
    - Fields of its objects are:-
      1. ```int transactionId``` :- Each modbus transaction has a unique number from 0 to 65535. Request & response have same transaction id, using which they are identified.
      2. ``` String ipAddress``` :- ip address of slave device
      3. ``` int portNumber``` :- port number of slave device
      4. ``` int unitId``` :- Commonly used in  Modbus Gateway (TCP to Serial):- Multiple Modbus RTU devices are connected to single Modbus TCP address. Each Modbus RTU device has same ip address and port number but different unit id.
      5. ``` int blockNumber``` :- block number is 0 for Coil, 1 for Discrete Input, 3 for Input Register, 4 for Holding Register
      6. ```int elementNumber```:- element number is an integer value from 1 to 65536

2. ```SlaveResponseConnectionError```
    - When slave device responds with a data, then object of this type is received from the stream responseFromSlaveDevices
    - Fields of its objects are:-
      1. ```int transactionId``` :- Each modbus transaction has a unique number from 0 to 65535. Request & response have same transaction id, using which they are identified.
      2. ```String ipAddress``` :- ip address of slave device
      3. ```int portNumber``` :- port number of slave device
      4. ```int unitId``` :- Commonly used in  Modbus Gateway (TCP to Serial):- Multiple Modbus RTU devices are connected to single Modbus TCP address. Each Modbus RTU device has same ip address and port number but different unit id.
      5. ```int blockNumber``` :- block number is 0 for Coil, 1 for Discrete Input, 3 for Input Register, 4 for Holding Register
      6. ```int elementNumber``` :- element number is an integer value from 1 to 65536
      7. ```String mbap``` :- Hexidecimal string of actual MBAP (as per Modbus TCP protocol) which is responded by slave device.
      8. ```String pdu``` :- Hexidecimal string of actual PDU (as per Modbus TCP protocol) which is responded by slave device.
      9. ```bool isReadResponse``` :- If PDU contains a read response, then it is true.
      10. ```int? readValue``` :- If PDU contains a read response, then it contains its value.
      11. ```bool isWriteResponse```:- If PDU contains a write response, then it is true.
      12. ```int? writeValue```:- If PDU contains a write response, then it contains its value.
  
  
3. ```SlaveResponseTimeoutError```
    - When slave device does not respond within timeout value provided during read or write request, then this element is received from stream responseFromSlaveDevices
    - Fields of its objects are:-
        1. ```int transactionId``` :- Each modbus transaction has a unique number from 0 to 65535. Request & response have same transaction id, using which they are identified.
        2. ``` String ipAddress``` :- ip address of slave device
        3. ``` int portNumber``` :- port number of slave device
        4. ```int unitId``` :- Commonly used in  Modbus Gateway (TCP to Serial):- Multiple Modbus RTU devices are connected to single Modbus TCP address. Each Modbus RTU device has same ip address and port number but different unit id.
        5. ```int blockNumber``` :- block number is 0 for Coil, 1 for Discrete Input, 3 for Input Register, 4 for Holding Register
        6. ```int elementNumber``` :- element number is an integer value from 1 to 65536
        7. ```int timeoutMilliseconds``` :- Slave has not been able to respond within this time.
4. ```SlaveResponseShutdownComplete```
    - This type is used for internal function of this library.
    - Stream ```responseFromSlaveDevices``` never emits an element of this type.
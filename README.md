**'modbus_master' is an easy to use package using which a dart program can work as a Modbus/TCP master device.**
- Currently users can use only these features of Modbus/TCP:
    1. Discrete input
        - Read single discrete input
    2. Coil
        - Read single coil
        - Write single coil
    3. Input Register
        - Read single input register
    4. Holding Register
        - Read single holding register
        - Write single holding register
- Currently only TCP ipv4 is implemented.
- A single stream object is used for response received from all slave devices.
- This package handles socket networking part in a separate isolate so that main isolate is free to handle other tasks like UI part of flutter.
- This package can be used on all platforms which supports dart:io & dart:isolate i.e. WINDOWS, LINUX, MACOS, ANDROID, IOS.

## Important information to know about this package
### For each request, a response is always generated
- If response is not received from slave device within timeout, an error response is generated by library and is put to "responses()" stream
- When first request is sent to a slave device, connection is established and connection is kept alive.
- Whenever a request is sent to a slave device, first it checks whether connection is already established. 
  - If connection is already established, then sends request.
  - If connection is found to be broken, then tries to establish connection.
- If there are already 247 active connections, and request to a new address is sent. Then, earliest connection is broken, and this new connection is established.
- If close method is executed, then first responses for all pending requests are generated. After that, all active connections are closed.

### Timeout
An error response is produced by package, if slave response is not received within timeout. Duration of timeout differs in two different scenarios:
- Scenario 1: When connection is already established
    - if response is not produced within timeout(default 1000ms),
        - master produces error response
    > Timeout = request timeout (default 1000ms)
- Scenario 2: When connection is not established
    - master tries for connection
    - if connection is not established within socketConnectionTimeout(default 2000 ms)
        - master produces error response
    - if connection is established
        -   if response is not produced within timeout (default 1000ms)
            - master produces error response
    > Timeout (maximum) = socket connection timeout(default 2000ms) + request timeout(default 1000ms)

### Limitations
- works with only ipv4, ipv6 is not supported
- only 247 slaves can be connected at one time,
    - when more than 247 slave is connected, oldest slave connection is broken
- Only single element can be read at once, reading multiple coils or multiple registers is not implemented, although reading multiple elements is specified in modbus/tcp implementation
- Only single element can be written to at once, writing to multiple coils or to multiple registers is not implemented, although writing to multiple elements is specified in modbus/tcp implementation
- works with dart 3.0 and above because it uses dart records

## Steps to use this library
-   make function async where this object needs to be created
-   make an instance of ModbusMaster class like this only.

    ```
    final modbusMaster = await ModbusMaster.start();
    ```
-   listen to stream of response using stream
    ```
    modbusMaster.responses().listen(
      (response) {
        print(response);
      }
    );
    ```
-   Send request to slave using these commands
    -   read single coil of a slave
        ```
        modbusMaster.readCoil(
          ipv4: '192.168.29.163',
          portNo: 502,
          elementNumberOneTo65536: 11,
        );
        ```

    -   read single discrete input of a slave
        ```
        modbusMaster.readDiscreteInput(
          ipv4: '192.168.1.5',
          elementNumberOneTo65536: 11,
        );
        ```
    -   read single holding register of a slave
        ```
        modbusMaster.readHoldingRegister(
          ipv4: '192.168.1.5',
          elementNumberOneTo65536: 11,
        );
        ```
    -   read single input register of a slave
        ```
        modbusMaster.readInputRegister(
          ipv4: '192.168.1.5',
          elementNumberOneTo65536: 11,
        );
        ```
    -   write single coil of a slave
        ```
        modbusMaster.writeCoil(
          ipv4: '192.168.1.5',
          elementNumberOneTo65536: 11,
          valueToBeWritten: true,
        );
        ```
    -   write single holding register of a slave
        ```
        modbusMaster.writeHoldingRegister(
          ipv4: '192.168.1.5',
          elementNumberOneTo65536: 11,
          valueToBeWritten: 15525,
        );
        ```
-   close must be called at end to close all tcp connections and stop modbus master
    ```
    modbusMaster.close();
    ```
## Example Code

### 1. First start Modbus/TCP server i.e. slave device using pyModbusTCP library
```
from pyModbusTCP.server import ModbusServer
import time
import socket

# get ipv4 address
host_ip = socket.gethostbyname(socket.gethostname())
modbusServer = ModbusServer(host = host_ip, port =502, no_block =True)

try:
    print('Trying to start MODBUS/TCP SLAVE SERVER')
    modbusServer.start()
    print(f'MODBUS/TCP SLAVE SERVER is online at {host_ip}')
    
    set_coil = True
    while True:
        if set_coil:
            # coil address is coil number - 1, therefore 11-1 is written
            modbusServer.data_bank.set_coils(11-1,bit_list=[True])
            print('COIL-11 = SET')
        else:
            modbusServer.data_bank.set_coils(11-1,bit_list=[False])
            print('COIL-11 = RESET')

        print('WAITING FOR 5 SECONDS')
        time.sleep(5)
        set_coil = not set_coil

except Exception as error:
    print(error)
    print(f'Trying to stop MODBUS/TCP SLAVE SERVER at {host_ip}')
    modbusServer.stop()
    print('MODBUS/TCP SLAVE SERVER is offline')
```
### 2. Check whether Modbus/TCP server (slave) is online or not
- Check whether socket for Server is open or not using windows powershell command
  ```
  # use ip address of your device, which is printed by python script
  netstat -na | Select-String "192.168.29.163:502"
  ```
  - When socket is listening, netstat command shows this
    ```
    TCP    192.168.29.163:502   0.0.0.0:0    LISTENING
    ```
  - When socket is closed, netstat command shows nothing



### 3. Use dart code & ModbusMaster library to read value of coil of slave (pyModbusTCP server)
```
import 'modbus_master_isolate.dart';

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
        // close modbusMaster when 3 responses are received
        modbusMaster.close();
      }
    },
  );

  for (int i = 1; i <= 5; ++i) {
    print('-> Request $i');
    try {
      modbusMaster.readCoil(
        ipv4: '192.168.29.163',
        portNo: 502,
        elementNumberOneTo65536: 11,
      );
    } catch (e) {
      // When read request is executed after close command, exception is raised.
      print('EXCEPTION THROWN WHILE READING $e');
    }
    await Future.delayed(Duration(seconds: 5));
  }
}
```

### 4. Close python script by repeatedly pressing Ctrl+C in python interpreter
- Check whether socket is open or not using 'netstat' command given above.
- If python script has finished but socket is open, use python statement to close modbusServer
  ```
  modbusServer.stop()
  ```
- Recheck status of socket using 'netstat'.
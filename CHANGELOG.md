## 1.0.0
- Initial version.

## 2.0.0
- Simplified read and write method:- Now only two methods are provided for reading and writing (i.e. read and write) as opposed to 6 methods previously.
- Intuitive method names for object creation. "start" method creates object & initializes all resouces. "stop" method shuts down all resources & disconnects all TCP connections.
- Asynchronous ```isStoppedAsync``` method to check whether object is stopped.
- Bug fixes.

## 2.0.1
- Updated README.md file
- Provided docstrings
- updated modbus_slave.py file

## 2.1.0
- Updated README.md file
- Added two more fields `isReadResponse` and `isWriteResponse` in class `SlaveResponseConnectionError` as well as class `SlaveResponseTimeoutError`
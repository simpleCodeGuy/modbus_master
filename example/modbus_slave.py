"""
*   This program starts Modbus TCP Slave Server at the machine at port 502.
*   Total 5 No coils from Coil 1 to Coil 5 are cyclically made set and reset
    in a time period of 2 seconds.
"""
from datetime import datetime
from pyModbusTCP.server import ModbusServer
import time
import socket

# get ipv4 address
timeAfterWhichSlaveShutsDown = 10 # seconds
ipAddress = socket.gethostbyname(socket.gethostname())
portNumber = 502
modbusServer = ModbusServer(host = ipAddress, port =portNumber, no_block =True)


try:
    print(f'Trying to start MODBUS/TCP slave Server at {ipAddress}, port {portNumber}\n')
    modbusServer.start()
    print(f'MODBUS/TCP slave Server is online for {timeAfterWhichSlaveShutsDown} seconds\n')
    
    
    is_coil_set = False

    timeStampServerStart = datetime.now()

    while True:
        if not is_coil_set:
            modbusServer.data_bank.set_coils(0,bit_list=[True,True,True,True,True])
            print('Coil 1 to 5 has been made SET')
        else:
            modbusServer.data_bank.set_coils(0,bit_list=[False,False,False,False,False])
            print('Coil 1 to 5 has been made RESET')

        delayTime = 2
        print(f'Waiting for {delayTime} seconds')
        time.sleep(delayTime)
        is_coil_set = not is_coil_set

        timeStampNow = datetime.now()

        if (timeStampNow - timeStampServerStart).seconds > timeAfterWhichSlaveShutsDown:
            break
    modbusServer.stop()
    print(f'MODBUS/TCP slave Server stopped at {ipAddress}, port {portNumber}')

except Exception as error:
    print(error)
    print(f'Trying to stop MODBUS/TCP SLAVE SERVER at {ipAddress}, port {portNumber}')
    modbusServer.stop()
    print('MODBUS/TCP SLAVE SERVER is offline')
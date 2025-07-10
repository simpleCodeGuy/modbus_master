"""
*   This program starts Modbus TCP Slave Server at the machine at port 502.

*   Total 5 No Holding Registers from Holding Register 6001 to 6005 are 
    cyclically made 100,200,300,400,500 and 1,2,3,4,5 alternatively.

*   This Modbus Slave TCP Server automatically shuts itself down after 60 seconds.
"""
from datetime import datetime
from pyModbusTCP.server import ModbusServer
import time
import socket

# get ipv4 address
timeAfterWhichSlaveShutsDown = 60 # seconds
delayTime = 2 # seconds
ipAddress = socket.gethostbyname(socket.gethostname())
portNumber = 502
modbusServer = ModbusServer(host = ipAddress, port =portNumber, no_block =True)


try:
    print(f'\nTrying to start MODBUS/TCP slave Server at {ipAddress}, port {portNumber}\n')
    modbusServer.start()
    print(f'\nMODBUS/TCP slave Server is online for {timeAfterWhichSlaveShutsDown} seconds\n')
    print(f'\n********************Press "Ctrl+C" to STOP at any time*********************\n')
    
    is_coil_set = False

    timeStampServerStart = datetime.now()

    while True:
        if not is_coil_set:
            # Address 6000 means Element number 6001
            modbusServer.data_bank.set_holding_registers(6000,word_list=[100,200,300,400,500])
            print('Holding Register 6001,6002,6003,6004,6005 has been made 100,200,300,400,500')
        else:
            modbusServer.data_bank.set_holding_registers(6000,word_list=[1,2,3,4,5])
            print('Holding Register 6001,6002,6003,6004,6005 has been made   1,  2,  3,  4,  5')

        time.sleep(delayTime)
        is_coil_set = not is_coil_set

        timeStampNow = datetime.now()

        if (timeStampNow - timeStampServerStart).seconds > timeAfterWhichSlaveShutsDown:
            break
    modbusServer.stop()
    print(f'\nMODBUS/TCP SLAVE SERVER stopped automatically at {ipAddress}, port {portNumber} after {timeAfterWhichSlaveShutsDown} seconds\n')

except:
    print(f'\nTrying to stop MODBUS/TCP SLAVE SERVER at {ipAddress}, port {portNumber}')
    modbusServer.stop()
    print('\nMODBUS/TCP SLAVE SERVER is offline\n')
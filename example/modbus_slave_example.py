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
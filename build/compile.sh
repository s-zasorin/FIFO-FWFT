# Директория скрипта.

curdir=$(pwd)

# Директория артефактов симулятора.

mkdir -p ${curdir}/work

# Компиляция исходных файлов в Xcelium выполняется с помощью команды
# 'xrun -compile'. Исходные файлы передаются этой команде.

# Аргумент '-xmlibdirpath' используется для указания пути к директории
# артефактов симулятора.

# Аргумент '-l' указывает путь к лог-файлу компиляции.

xrun -compile -64bit ${curdir}/../rtl/multi_port_fifo.sv ${curdir}/../rtl/dual_port_ram.sv ${curdir}/../tb/tb_fifo.sv \
    -xmlibdirpath ${curdir}/work -l ${curdir}/compile.log -linedebug

import os, sys, time, json, socket, pwd, subprocess, glob, ctypes

def read_cpu():
    values = list(map(int, open('/proc/stat').readline().split()[1:9]))
    return sum(values), values[3] + values[4]

def processes():
    result = {}
    for path in glob.glob('/proc/[0-9]*'):
        try:
            stat = open(path + '/stat').read()
            fields = stat[stat.rfind(')') + 2:].split()
            pid = int(path.rsplit('/', 1)[1])
            result[pid] = (int(fields[11]) + int(fields[12]), int(fields[21]) * os.sysconf('SC_PAGE_SIZE'), stat[stat.find('(')+1:stat.rfind(')')], pwd.getpwuid(os.stat(path).st_uid).pw_name, fields[19])
        except (OSError, ValueError, KeyError):
            pass
    return result

def gpu():
    try:
        output = subprocess.check_output(['nvidia-smi', '--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu', '--format=csv,noheader,nounits'], timeout=2, stderr=subprocess.DEVNULL).decode().splitlines()[0]
        name, utilization, used, total, temperature = [s.strip() for s in output.split(',')]
        return dict(name=name, utilization=float(utilization), used=float(used), total=float(total), temperature=float(temperature))
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        return gpu_from_nvml()

class GPUUtilization(ctypes.Structure):
    _fields_ = [('gpu', ctypes.c_uint), ('memory', ctypes.c_uint)]

class GPUMemory(ctypes.Structure):
    _fields_ = [('total', ctypes.c_ulonglong), ('free', ctypes.c_ulonglong), ('used', ctypes.c_ulonglong)]

def gpu_from_nvml():
    library = None
    initialized = False
    try:
        library = ctypes.CDLL('libnvidia-ml.so.1')
        if library.nvmlInit_v2() != 0:
            return None
        initialized = True
        handle = ctypes.c_void_p()
        name = ctypes.create_string_buffer(96)
        utilization, memory, temperature = GPUUtilization(), GPUMemory(), ctypes.c_uint()
        if library.nvmlDeviceGetHandleByIndex_v2(0, ctypes.byref(handle)) != 0:
            return None
        results = [library.nvmlDeviceGetName(handle, name, 96),
                   library.nvmlDeviceGetUtilizationRates(handle, ctypes.byref(utilization)),
                   library.nvmlDeviceGetMemoryInfo(handle, ctypes.byref(memory)),
                   library.nvmlDeviceGetTemperature(handle, 0, ctypes.byref(temperature))]
        if any(results):
            return None
        return dict(name=name.value.decode(errors='replace'), utilization=utilization.gpu,
                    used=memory.used / 1048576, total=memory.total / 1048576,
                    temperature=temperature.value)
    except (OSError, AttributeError):
        return None
    finally:
        if initialized:
            library.nvmlShutdown()

def swap_usage():
    disk_used = disk_total = zram_used = zram_total = 0
    for line in open('/proc/swaps').read().splitlines()[1:]:
        name, kind, size, used, priority = line.split()
        if name.startswith('/dev/zram'):
            zram_used += int(used) / 1048576
            zram_total += int(size) / 1048576
        else:
            disk_used += int(used) / 1048576
            disk_total += int(size) / 1048576
    return dict(swapUsed=disk_used, swapTotal=disk_total,
                zramUsed=zram_used, zramTotal=zram_total)

system = 'Linux'
try:
    for line in open('/etc/os-release'):
        if line.startswith('PRETTY_NAME='):
            system = line.split('=', 1)[1].strip().strip('"')
except OSError:
    pass
previous_cpu, previous_processes, previous_time = read_cpu(), processes(), time.monotonic()
while True:
    time.sleep(2)
    current_cpu, current_processes, now = read_cpu(), processes(), time.monotonic()
    total_delta = current_cpu[0] - previous_cpu[0]
    cpu = 100 * (1 - (current_cpu[1] - previous_cpu[1]) / max(1, total_delta))
    memory = {line.split(':')[0]: int(line.split()[1]) for line in open('/proc/meminfo')}
    rows = []
    for pid, (ticks, rss, name, user, start) in current_processes.items():
        old = previous_processes.get(pid)
        usage = 100 * max(0, ticks - old[0]) / os.sysconf('SC_CLK_TCK') / (now - previous_time) if old and old[4] == start else 0
        rows.append(dict(pid=pid, name=name, user=user, cpu=usage, memory=rss / 1048576))
    print(json.dumps(dict(hostname=socket.gethostname(), user=pwd.getpwuid(os.getuid()).pw_name, system=system, cpu=cpu, cores=os.cpu_count(), memoryUsed=(memory['MemTotal']-memory['MemAvailable'])/1048576, memoryTotal=memory['MemTotal']/1048576, gpu=gpu(), processes=rows, **swap_usage())), flush=True)
    previous_cpu, previous_processes, previous_time = current_cpu, current_processes, now
